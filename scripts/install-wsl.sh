#!/usr/bin/env bash
set -euo pipefail
# Python handles paths and subprocess argv; no interpolated shell commands.
exec python3 - --integration-script "${BASH_SOURCE[0]}" "$@" <<'PY'
"""Pinned, opt-in installer. This embedded module uses only Python's standard library."""
import argparse
import json
import os
import platform
import shutil
import stat
import subprocess
import sys
from pathlib import Path

UPSTREAM_URL = "https://github.com/arumwu/local-workspace-mcp.git"
UPSTREAM_COMMIT = "ba42837e7aa54cd265e62023e5079f0e4affdf84"
STATE_DEFAULT = "~/.local/state/local-workspace-mcp-windows"


def run(arguments, **kwargs):
    return subprocess.run([str(value) for value in arguments], check=True, **kwargs)


def output(arguments, **kwargs):
    return run(arguments, text=True, capture_output=True, **kwargs).stdout.strip()


def checked_path(value):
    path = Path(value).expanduser()
    if not path.is_absolute() or ".." in path.parts:
        raise ValueError("Use an absolute path without '..': " + str(path))
    for ancestor in [*reversed(path.parents), path]:
        if ancestor.is_symlink():
            raise ValueError("Symlinks are not accepted in installation paths: " + str(ancestor))
        if ancestor.exists() and not ancestor.is_dir():
            raise ValueError("An installation directory path is occupied by a file: " + str(ancestor))
    return path


def disjoint_paths(paths):
    for index, left in enumerate(paths):
        for right in paths[index + 1:]:
            if left == right or left in right.parents or right in left.parents:
                raise ValueError("Workspace, private state and source checkout must not overlap: %s / %s" % (left, right))


def dedicated_paths(paths, home):
    for path in paths:
        drive_root = len(path.parts) == 3 and path.parts[1] == "mnt" and len(path.parts[2]) == 1
        if path == Path(path.anchor) or path == home or path in home.parents or drive_root or path == Path("/mnt") or os.path.ismount(path):
            raise ValueError("Choose dedicated directories, not a home directory, its ancestors, or a filesystem/Windows drive root: " + str(path))


def private_regular(path):
    info = path.lstat()
    if not stat.S_ISREG(info.st_mode) or info.st_nlink != 1:
        raise ValueError("Installation files must be regular files with one link: " + str(path))
    if os.name == "posix" and (info.st_uid != os.getuid() or stat.S_IMODE(info.st_mode) & 0o077):
        raise ValueError("Installation files must be privately owned by your user: " + str(path))
    return info


def check_state_ancestors(state, home):
    for ancestor in state.parents:
        if ancestor.exists():
            info = ancestor.stat()
            if info.st_uid != os.getuid() or stat.S_IMODE(info.st_mode) & 0o022:
                raise ValueError("Private state ancestors must be owned by you and not writable by other users; inspect permissions before retrying: " + str(ancestor))
        if ancestor == home:
            break


def linux_filesystem(path):
    existing = path
    while not existing.exists():
        existing = existing.parent
    filesystem = output(["stat", "-f", "-c", "%T", existing])
    if filesystem not in {"ext2/ext3", "ext2", "ext3", "ext4", "btrfs", "xfs", "f2fs", "zfs"}:
        raise ValueError("Private state and source must be on a Linux filesystem, not a Windows/shared mount (%s): %s" % (filesystem, path))


def validate_options(mode, skip_worker, accept_full):
    if mode == "full" and not accept_full:
        raise ValueError("Full mode requires --accept-full-permissions; it can run commands and access files as your WSL user.")
    if skip_worker and mode != "full":
        raise ValueError("--skip-worker is only available with explicit full-mode acceptance.")


def check_dependencies(mode, skip_worker):
    needed = ["git", "uv", "rg", "stat"]
    if mode == "full":
        needed += ["node", "npm"]
    if not skip_worker:
        needed += ["docker"]
    missing = [name for name in needed if not shutil.which(name)]
    if missing:
        raise ValueError("Missing prerequisites: %s. Prepare these inside this WSL distribution using README.md, then rerun. No global tools are installed automatically." % ", ".join(missing))
    if mode == "full":
        version = output(["node", "--version"]).lstrip("v").split(".")
        if tuple(int(value) for value in version[:2]) < (20, 9):
            raise ValueError("Full mode requires Node.js 20.9 or newer inside WSL.")
    if not skip_worker:
        try:
            run(["docker", "info"], stdout=subprocess.DEVNULL, stderr=subprocess.DEVNULL, timeout=30)
        except (subprocess.CalledProcessError, subprocess.TimeoutExpired):
            raise ValueError("Docker is not running or not accessible in this WSL distribution. Enable its WSL integration/start the daemon, then retry.") from None


def validate_checkout(repo):
    if (repo / ".git").is_symlink() or not (repo / ".git").is_dir():
        raise ValueError("Existing checkout must have its own regular .git directory.")
    if output(["git", "-C", repo, "rev-parse", "HEAD"]) != UPSTREAM_COMMIT:
        raise ValueError("Existing checkout is not the pinned upstream commit; refusing to replace it.")
    if output(["git", "-C", repo, "status", "--porcelain", "--untracked-files=all"]):
        raise ValueError("Existing upstream checkout has local changes; refusing to use or replace it.")
    if output(["git", "-C", repo, "remote", "get-url", "origin"]) != UPSTREAM_URL:
        raise ValueError("Existing upstream checkout has an unexpected origin.")


def expected_receipt(repo, state, workspace, mode, skip_worker):
    return {"schema_version": 1, "upstream_commit": UPSTREAM_COMMIT,
            "launch": str(state / "launch.sh"), "workspace": str(workspace),
            "repo": str(repo), "mode": mode, "skip_worker": skip_worker}


def existing_install(state, expected):
    receipt_path = state / "install.json"
    for name in ("install.json", "launch.sh", "mcp-server.json"):
        target = state / name
        if target.is_symlink():
            raise ValueError("Installation files must not be symlinks: " + str(target))
    if receipt_path.exists():
        private_regular(receipt_path)
        actual = json.loads(receipt_path.read_text(encoding="utf-8"))
        if actual != expected:
            raise ValueError("An installation receipt already exists with different choices. Use a separate --state and workspace; this installer does not perform silent upgrades.")
        if not (state / "launch.sh").is_file() or not (state / "mcp-server.json").is_file():
            raise ValueError("Existing installation is incomplete. Inspect its state before repairing; no existing files were replaced.")
        private_regular(state / "launch.sh")
        private_regular(state / "mcp-server.json")
        return True
    if (state / "launch.sh").exists() or (state / "mcp-server.json").exists():
        raise ValueError("Existing launcher/configuration has no matching install.json receipt; refusing to replace it.")
    return False


def write_receipt(state, receipt):
    # Exclusive creation: never overwrite a receipt created by another process.
    fd = os.open(state / "install.json", os.O_WRONLY | os.O_CREAT | os.O_EXCL, 0o600)
    with os.fdopen(fd, "w", encoding="utf-8") as stream:
        json.dump(receipt, stream, indent=2)
        stream.write("\n")


def main(argv=None):
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--integration-script", required=True)
    parser.add_argument("--workspace", default="~/LocalWorkspace")
    parser.add_argument("--state", default=STATE_DEFAULT)
    parser.add_argument("--mode", choices=["documents", "full"], default="documents")
    parser.add_argument("--accept-full-permissions", action="store_true")
    parser.add_argument("--skip-worker", action="store_true")
    args = parser.parse_args(argv)
    validate_options(args.mode, args.skip_worker, args.accept_full_permissions)
    if sys.version_info < (3, 12):
        raise ValueError("Python 3.12 or newer is required. Ubuntu 24.04 or newer is recommended.")
    if platform.system() != "Linux" or "microsoft" not in platform.release().lower():
        raise ValueError("Run this installer inside WSL on Windows x64.")
    if "wsl2" not in platform.release().lower():
        raise ValueError("WSL 2 is required. Check wsl --list --verbose and explicitly convert your distribution with wsl --set-version <Distro> 2.")
    if platform.machine().lower() not in {"x86_64", "amd64"}:
        raise ValueError("This release supports x64 WSL only.")
    if os.getuid() == 0:
        raise ValueError("Use your non-root default WSL user, without sudo.")
    os.umask(0o077)
    os.environ["PATH"] = str(Path.home() / ".local/bin") + os.pathsep + os.environ.get("PATH", "")
    workspace = checked_path(args.workspace)
    state = checked_path(args.state)
    if Path.home() not in state.parents:
        raise ValueError("Private state must be a dedicated directory under your WSL home.")
    check_state_ancestors(state, Path.home())
    repo = checked_path(str(Path.home() / ".local/share/local-workspace-mcp-windows/upstream" / UPSTREAM_COMMIT))
    dedicated_paths([workspace, state, repo], Path.home())
    disjoint_paths([workspace, state, repo])
    integration_root = checked_path(str(Path(args.integration_script).absolute().parent.parent))
    disjoint_paths([state, workspace, integration_root])
    check_dependencies(args.mode, args.skip_worker)
    linux_filesystem(state)
    linux_filesystem(repo)
    receipt = expected_receipt(repo, state, workspace, args.mode, args.skip_worker)
    if state.exists() and state.stat().st_uid != os.getuid():
        raise ValueError("The private state directory is owned by another user.")
    state.mkdir(parents=True, mode=0o700, exist_ok=True)
    state.chmod(0o700)
    # Serialize operations for this state, without a stale PID lock file.
    import fcntl
    lock_fd = os.open(state / ".install.lock", os.O_CREAT | os.O_RDWR | os.O_NOFOLLOW, 0o600)
    with os.fdopen(lock_fd, "r+") as lock:
        info = os.fstat(lock.fileno())
        if not stat.S_ISREG(info.st_mode) or info.st_nlink != 1 or info.st_uid != os.getuid():
            raise ValueError("Installation lock must be a regular single-link file owned by your user.")
        fcntl.flock(lock, fcntl.LOCK_EX | fcntl.LOCK_NB)
        installed = existing_install(state, receipt)
        if repo.exists():
            validate_checkout(repo)
        else:
            repo.parent.mkdir(parents=True, exist_ok=True)
            # Git operations never delete/replace an existing user checkout.
            run(["git", "clone", "--no-checkout", "--", UPSTREAM_URL, repo])
            run(["git", "-C", repo, "checkout", "--detach", UPSTREAM_COMMIT])
            validate_checkout(repo)
        if not installed:
            workspace.mkdir(parents=True, exist_ok=True)
            command = [sys.executable, str(repo / "scripts/install.py"), "--workspace", str(workspace),
                       "--state", str(state), "--mode", args.mode, "--no-register"]
            if args.skip_worker:
                command.append("--skip-worker")
            run(command, cwd=repo)
            write_receipt(state, receipt)
        else:
            print("Matching installation found; verifying without replacing its launcher or configuration.", flush=True)
        verifier = Path(args.integration_script).absolute().parent / "verify_mcp.py"
        run([repo / ".venv/bin/python", verifier, "--state", state])
    print("Local installation verified. ChatGPT connection: NOT TESTED.")
    print("Launcher: " + str(state / "launch.sh"))
    print("No client configuration was registered. Next: Connect.cmd and docs/CHATGPT.md.")


if __name__ == "__main__":
    try:
        main()
    except (OSError, ValueError, subprocess.CalledProcessError, subprocess.TimeoutExpired) as exc:
        print("Installation stopped: " + str(exc), file=sys.stderr)
        sys.exit(1)
PY
