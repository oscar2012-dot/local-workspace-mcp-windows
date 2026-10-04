#!/usr/bin/env python3
"""Verify local stdio MCP with a unique, harmless workspace file; never starts a tunnel."""
import argparse
import asyncio
import json
import os
import stat
import subprocess
import sys
import tempfile
import uuid
from pathlib import Path

UPSTREAM_COMMIT = "ba42837e7aa54cd265e62023e5079f0e4affdf84"
STATE_DEFAULT = "~/.local/state/local-workspace-mcp-windows"


def no_symlinks(path):
    for ancestor in [*reversed(path.parents), path]:
        if ancestor.is_symlink():
            raise ValueError("Refusing symlink in verification path: " + str(ancestor))


def private_regular(path):
    info = path.lstat()
    if not stat.S_ISREG(info.st_mode) or info.st_nlink != 1:
        raise ValueError("Expected a regular single-link installation file: " + str(path))
    if os.name == "posix" and (info.st_uid != os.getuid() or stat.S_IMODE(info.st_mode) & 0o077):
        raise ValueError("Installation file must be private and owned by your user: " + str(path))


def load_receipt(state):
    if not state.is_absolute() or ".." in state.parts:
        raise ValueError("State must be an absolute Linux path without traversal.")
    no_symlinks(state)
    info = state.stat()
    if not stat.S_ISDIR(info.st_mode):
        raise ValueError("State must be a directory.")
    if os.name == "posix" and (info.st_uid != os.getuid() or stat.S_IMODE(info.st_mode) & 0o077):
        raise ValueError("State must be owned by you and private (chmod 700).")
    receipt_file = state / "install.json"
    no_symlinks(receipt_file)
    private_regular(receipt_file)
    receipt = json.loads(receipt_file.read_text(encoding="utf-8"))
    if receipt.get("schema_version") != 1 or receipt.get("upstream_commit") != UPSTREAM_COMMIT:
        raise ValueError("Unsupported installation receipt; rerun the matching community installer.")
    if receipt.get("mode") not in {"documents", "full"} or type(receipt.get("skip_worker")) is not bool:
        raise ValueError("Invalid mode or skip_worker in installation receipt.")
    if receipt["mode"] == "documents" and receipt["skip_worker"]:
        raise ValueError("Document mode requires its Docker worker.")
    if receipt.get("launch") != str(state / "launch.sh"):
        raise ValueError("Receipt launcher must be launch.sh in this private state directory.")
    for field in ("launch", "repo", "workspace"):
        path = Path(receipt[field])
        if not path.is_absolute() or ".." in path.parts:
            raise ValueError("Invalid absolute installation path: " + field)
        no_symlinks(path)
    private_regular(Path(receipt["launch"]))
    paths = [state, Path(receipt["workspace"]), Path(receipt["repo"])]
    for index, left in enumerate(paths):
        for right in paths[index + 1:]:
            if left == right or left in right.parents or right in left.parents:
                raise ValueError("Installation paths must not overlap.")
    workspace = Path(receipt["workspace"])
    if workspace == Path(workspace.anchor) or workspace == Path.home() or workspace in Path.home().parents or os.path.ismount(workspace):
        raise ValueError("Workspace must be a dedicated directory.")
    return receipt


def validate_tools(tools, mode, skip_worker):
    names = {tool.name for tool in tools}
    required = {"create_text", "read_text"}
    if mode == "full":
        required |= {"host_write_file", "host_read_file", "host_start_process"}
    if not skip_worker:
        required.add("run_python")
    if required - names:
        raise ValueError("Required tools missing: " + ", ".join(sorted(required - names)))
    if mode == "documents" and any(name.startswith("host_") for name in names):
        raise ValueError("Document mode unexpectedly exposed full-mode host tools.")
    if skip_worker and "run_python" in names:
        raise ValueError("Worker tool exposed despite the explicit skip_worker selection.")
    unsupported = {"ui", "ui/resourceUri", "openai/outputTemplate", "openai/widgetAccessible"}
    for tool in tools:
        if tool.name.startswith("host_") and unsupported.intersection(getattr(tool, "meta", None) or {}):
            raise ValueError("Unsupported host tool UI metadata: " + tool.name)


def result_text(result):
    if result.isError:
        raise ValueError("MCP probe operation returned an error.")
    return "\n".join(block.text for block in result.content if block.type == "text")


async def exercise(session, receipt, probe_name, marker):
    await session.initialize()
    tools = []
    cursor = None
    seen = set()
    for _ in range(100):
        page = await session.list_tools(cursor=cursor)
        tools.extend(page.tools)
        cursor = page.nextCursor
        if not cursor:
            break
        if cursor in seen:
            raise ValueError("Repeated cursor in MCP tool listing.")
        seen.add(cursor)
    else:
        raise ValueError("Too many MCP tool pages.")
    validate_tools(tools, receipt["mode"], receipt["skip_worker"])
    # create_text uses exclusive creation and confines paths to the workspace.
    result_text(await session.call_tool("create_text", {"path": probe_name, "content": marker + "\n"}))
    text = result_text(await session.call_tool("read_text", {"path": probe_name}))
    if text.strip() != marker:
        try:
            decoded = json.loads(text)
        except ValueError:
            decoded = None
        if decoded != marker + "\n" and decoded != marker:
            raise ValueError("MCP probe read-back did not match the written content.")
    return len(tools)


async def verify(receipt):
    # Imported only under the installed upstream virtual environment.
    from mcp import ClientSession, StdioServerParameters
    from mcp.client.stdio import stdio_client

    probe_name = "mcp-verification-" + uuid.uuid4().hex + ".txt"
    marker = "LOCAL_WORKSPACE_MCP_VERIFIED_" + uuid.uuid4().hex
    async with asyncio.timeout(90):
        async with stdio_client(StdioServerParameters(command=receipt["launch"], args=[])) as streams:
            async with ClientSession(*streams) as session:
                count = await exercise(session, receipt, probe_name, marker)
    probe = Path(receipt["workspace"]) / probe_name
    no_symlinks(probe)
    info = probe.stat()
    if not stat.S_ISREG(info.st_mode) or info.st_nlink != 1 or probe.read_text(encoding="utf-8") != marker + "\n":
        raise ValueError("Local workspace file does not match the MCP write/read test.")
    return {"local_verified": True, "tool_count": count, "mode": receipt["mode"],
            "skip_worker": receipt["skip_worker"], "probe": str(probe),
            "probe_retained": True, "chatgpt_connection": "not_tested"}


def save_verification(state, report):
    fd, temporary = tempfile.mkstemp(prefix=".verification-", suffix=".json", dir=state)
    try:
        with os.fdopen(fd, "w", encoding="utf-8") as stream:
            json.dump(report, stream, indent=2)
            stream.write("\n")
        os.chmod(temporary, 0o600)
        os.replace(temporary, state / "verification.json")
    finally:
        if os.path.exists(temporary):
            os.unlink(temporary)


def main(argv=None):
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--state", default=STATE_DEFAULT)
    args = parser.parse_args(argv)
    if sys.version_info < (3, 12):
        raise ValueError("Python 3.12 or newer is required inside WSL.")
    if sys.platform != "linux" or not hasattr(os, "getuid") or os.getuid() == 0:
        raise ValueError("Verification must run as your non-root WSL user.")
    state = Path(args.state).expanduser()
    receipt = load_receipt(state)
    info = state.stat()
    if info.st_uid != os.getuid() or stat.S_IMODE(info.st_mode) & 0o077:
        raise ValueError("State must be owned by you and private (chmod 700).")
    venv = Path(receipt["repo"]) / ".venv"
    no_symlinks(venv)
    if Path(sys.prefix).resolve() != venv.resolve():
        interpreter = venv / "bin/python"
        if not interpreter.is_file():
            raise ValueError("The upstream Python environment is missing. Inspect the installation.")
        # Explicit argv preserves spaces and shell metacharacters in both paths.
        return subprocess.run([str(interpreter), str(Path(__file__).absolute()), "--state", str(state)]).returncode
    report = asyncio.run(verify(receipt))
    save_verification(state, report)
    print(json.dumps(report, indent=2))
    return 0


if __name__ == "__main__":
    try:
        sys.exit(main())
    except Exception as exc:
        print(json.dumps({"local_verified": False, "chatgpt_connection": "not_tested", "error": str(exc)}), file=sys.stderr)
        sys.exit(1)
