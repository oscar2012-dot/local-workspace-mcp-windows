"""Standard-library tests; these never start WSL, Docker, a server or a tunnel."""
import asyncio
import contextlib
import importlib.util
import json
import os
import shutil
import stat
import tempfile
import types
import unittest
import uuid
from pathlib import Path
from unittest import mock

ROOT = Path(__file__).resolve().parents[1]
shell_source = (ROOT / "scripts/install-wsl.sh").read_text(encoding="utf-8")
embedded = shell_source.split("<<'PY'\n", 1)[1].rsplit("\nPY", 1)[0]
installer = types.ModuleType("installer_under_test")
exec(compile(embedded, str(ROOT / "scripts/install-wsl.sh"), "exec"), installer.__dict__)
spec = importlib.util.spec_from_file_location("verify_under_test", ROOT / "scripts/verify_mcp.py")
verifier = importlib.util.module_from_spec(spec)
spec.loader.exec_module(verifier)


@contextlib.contextmanager
def scratch_directory():
    # Python's Windows mode-0700 mkdtemp ACL omits restricted sandbox tokens.
    # Inherit the test temp root ACL on Windows; retain POSIX private mode.
    root = Path(tempfile.gettempdir()).resolve()
    path = root / ("lwmcp-test-" + uuid.uuid4().hex)
    path.mkdir(mode=0o700 if os.name == "posix" else 0o777)
    try:
        yield str(path)
    finally:
        if path.parent.resolve() != root or not path.name.startswith("lwmcp-test-"):
            raise RuntimeError("Invalid test cleanup target")
        shutil.rmtree(path)


class InstallerTests(unittest.TestCase):
    def test_documents_rejects_skipping_worker(self):
        with self.assertRaisesRegex(ValueError, "only available"):
            installer.validate_options("documents", True, True)

    def test_full_requires_explicit_acceptance(self):
        with self.assertRaisesRegex(ValueError, "accept-full-permissions"):
            installer.validate_options("full", False, False)
        installer.validate_options("documents", False, False)
        installer.validate_options("full", True, True)

    def test_paths_reject_ancestors_but_allow_similar_names(self):
        base = Path(tempfile.gettempdir()).resolve()
        with self.assertRaisesRegex(ValueError, "overlap"):
            installer.disjoint_paths([base / "workspace", base / "workspace/state"])
        with self.assertRaisesRegex(ValueError, "overlap"):
            installer.disjoint_paths([base / "same", base / "same"])
        installer.disjoint_paths([base / "workspace", base / "workspace-state"])

    def test_paths_reject_traversal(self):
        path = Path(tempfile.gettempdir()).resolve() / "child/../state"
        with self.assertRaisesRegex(ValueError, "without"):
            installer.checked_path(path)

    def test_dedicated_paths_reject_home_ancestors_and_windows_roots(self):
        home = Path(tempfile.gettempdir()).resolve() / "home/user"
        with mock.patch.object(installer.os.path, "ismount", return_value=False):
            for path in (home, home.parent, Path("/mnt"), Path("/mnt/c")):
                with self.subTest(path=path), self.assertRaisesRegex(ValueError, "dedicated"):
                    installer.dedicated_paths([path], home)
            installer.dedicated_paths([home / "MCP Workspace"], home)

    def test_installation_files_reject_hardlinks(self):
        info = types.SimpleNamespace(st_mode=stat.S_IFREG | 0o600, st_nlink=2, st_uid=0)
        with mock.patch.object(Path, "lstat", return_value=info):
            with self.assertRaisesRegex(ValueError, "one link"):
                installer.private_regular(Path("receipt.json"))
            with self.assertRaisesRegex(ValueError, "single-link"):
                verifier.private_regular(Path("receipt.json"))

    def test_state_ancestors_reject_group_writable_directories(self):
        home = Path(tempfile.gettempdir()).resolve() / "home/user"
        state = home / ".local/state/private"
        info = types.SimpleNamespace(st_mode=stat.S_IFDIR | 0o775, st_uid=123)
        with mock.patch.object(Path, "exists", return_value=True), mock.patch.object(Path, "stat", return_value=info), mock.patch.object(installer.os, "getuid", return_value=123, create=True):
            with self.assertRaisesRegex(ValueError, "not writable"):
                installer.check_state_ancestors(state, home)

    def test_paths_reject_a_file_in_directory_position(self):
        with scratch_directory() as folder:
            file = Path(folder) / "file"
            file.write_text("original", encoding="utf-8")
            with self.assertRaisesRegex(ValueError, "occupied"):
                installer.checked_path(file / "state")
            self.assertEqual(file.read_text(), "original")

    def test_existing_install_rejects_unreceipted_launcher(self):
        with scratch_directory() as folder:
            state = Path(folder)
            launch = state / "launch.sh"
            launch.write_text("original", encoding="utf-8")
            receipt = installer.expected_receipt(state / "repo", state, state / "work", "documents", False)
            with self.assertRaisesRegex(ValueError, "no matching"):
                installer.existing_install(state, receipt)
            self.assertEqual(launch.read_text(), "original")

    def test_existing_install_rejects_changed_choices(self):
        with scratch_directory() as folder:
            state = Path(folder)
            receipt = installer.expected_receipt(state / "repo", state, state / "work", "documents", False)
            (state / "launch.sh").write_text("original", encoding="utf-8")
            (state / "mcp-server.json").write_text("{}", encoding="utf-8")
            (state / "launch.sh").chmod(0o700)
            (state / "mcp-server.json").chmod(0o600)
            installer.write_receipt(state, receipt)
            self.assertTrue(installer.existing_install(state, receipt))
            changed = {**receipt, "mode": "full", "skip_worker": True}
            with self.assertRaisesRegex(ValueError, "different choices"):
                installer.existing_install(state, changed)
            with self.assertRaises(FileExistsError):
                installer.write_receipt(state, changed)
            self.assertEqual(json.loads((state / "install.json").read_text()), receipt)

    def test_existing_install_detects_missing_launcher(self):
        with scratch_directory() as folder:
            state = Path(folder)
            receipt = installer.expected_receipt(state / "repo", state, state / "work", "documents", False)
            installer.write_receipt(state, receipt)
            with self.assertRaisesRegex(ValueError, "incomplete"):
                installer.existing_install(state, receipt)

    def test_rejects_symlink_directory_if_os_allows_symlinks(self):
        with scratch_directory() as folder:
            base = Path(folder)
            target = base / "target"
            target.mkdir()
            link = base / "link"
            try:
                link.symlink_to(target, target_is_directory=True)
            except OSError:
                self.skipTest("OS account cannot create symlinks")
            with self.assertRaisesRegex(ValueError, "Symlinks"):
                installer.checked_path(link / "state")

    def test_dirty_or_wrong_checkout_is_refused(self):
        with scratch_directory() as folder:
            repo = Path(folder)
            (repo / ".git").mkdir()
            with mock.patch.object(installer, "output", return_value="wrong-commit"):
                with self.assertRaisesRegex(ValueError, "pinned"):
                    installer.validate_checkout(repo)
            with mock.patch.object(installer, "output", side_effect=[installer.UPSTREAM_COMMIT, " M file.py"]):
                with self.assertRaisesRegex(ValueError, "local changes"):
                    installer.validate_checkout(repo)
            with mock.patch.object(installer, "output", side_effect=[installer.UPSTREAM_COMMIT, "", "https://invalid.example/repo"]):
                with self.assertRaisesRegex(ValueError, "unexpected origin"):
                    installer.validate_checkout(repo)

    def test_windows_filesystem_refused_for_private_state(self):
        with mock.patch.object(installer, "output", return_value="9p"):
            with self.assertRaisesRegex(ValueError, "Linux filesystem"):
                installer.linux_filesystem(Path(tempfile.gettempdir()))

    def test_missing_dependencies_stop_before_installing(self):
        with mock.patch.object(installer.shutil, "which", return_value=None):
            with self.assertRaisesRegex(ValueError, "Missing prerequisites: git, uv, rg, stat, docker"):
                installer.check_dependencies("documents", False)


def tool(name, meta=None):
    return types.SimpleNamespace(name=name, meta=meta)


def result(text, error=False):
    return types.SimpleNamespace(isError=error, content=[types.SimpleNamespace(type="text", text=text)])


class VerifierTests(unittest.TestCase):
    def test_tool_count_is_not_hardcoded(self):
        tools = [tool("create_text"), tool("read_text"), tool("run_python")]
        verifier.validate_tools(tools, "documents", False)
        verifier.validate_tools(tools + [tool("future_extra_tool")], "documents", False)

    def test_full_mode_requires_host_tools(self):
        with self.assertRaisesRegex(ValueError, "host_"):
            verifier.validate_tools([tool("create_text"), tool("read_text")], "full", True)

    def test_documents_rejects_unexpected_host_access(self):
        tools = [tool(name) for name in ["create_text", "read_text", "run_python", "host_start_process"]]
        with self.assertRaisesRegex(ValueError, "unexpectedly exposed"):
            verifier.validate_tools(tools, "documents", False)

    def test_skip_worker_rejects_worker_tool(self):
        tools = [tool(name) for name in ["create_text", "read_text", "run_python", "host_write_file", "host_read_file", "host_start_process"]]
        with self.assertRaisesRegex(ValueError, "skip_worker"):
            verifier.validate_tools(tools, "full", True)

    def test_unsupported_ui_metadata_is_refused(self):
        tools = [tool(name) for name in ["create_text", "read_text", "host_write_file", "host_read_file", "host_start_process"]]
        tools[-1].meta = {"openai/outputTemplate": "ui://unsupported"}
        with self.assertRaisesRegex(ValueError, "UI metadata"):
            verifier.validate_tools(tools, "full", True)

    def test_probe_uses_exact_relative_name_and_readback(self):
        tools = [tool(name) for name in ["create_text", "read_text", "run_python"]]
        session = types.SimpleNamespace(
            initialize=mock.AsyncMock(),
            list_tools=mock.AsyncMock(side_effect=[
                types.SimpleNamespace(tools=tools[:1], nextCursor="next"),
                types.SimpleNamespace(tools=tools[1:], nextCursor=None),
            ]),
            call_tool=mock.AsyncMock(side_effect=[result('{}'), result('TEST_MARKER\n')]),
        )
        count = asyncio.run(verifier.exercise(session, {"mode": "documents", "skip_worker": False}, "mcp-verification-unique.txt", "TEST_MARKER"))
        self.assertEqual(count, 3)
        self.assertEqual(session.call_tool.call_args_list, [
            mock.call("create_text", {"path": "mcp-verification-unique.txt", "content": "TEST_MARKER\n"}),
            mock.call("read_text", {"path": "mcp-verification-unique.txt"}),
        ])

    def test_probe_rejects_mismatched_read(self):
        session = types.SimpleNamespace(
            initialize=mock.AsyncMock(),
            list_tools=mock.AsyncMock(return_value=types.SimpleNamespace(
                tools=[tool("create_text"), tool("read_text"), tool("run_python")], nextCursor=None)),
            call_tool=mock.AsyncMock(side_effect=[result('{}'), result('WRONG')]),
        )
        with self.assertRaisesRegex(ValueError, "did not match"):
            asyncio.run(verifier.exercise(session, {"mode": "documents", "skip_worker": False}, "probe.txt", "EXPECTED"))

    def test_write_error_is_not_verified(self):
        with self.assertRaisesRegex(ValueError, "returned an error"):
            verifier.result_text(result("failure", error=True))

    def test_repeated_tool_cursor_is_refused(self):
        session = types.SimpleNamespace(
            initialize=mock.AsyncMock(),
            list_tools=mock.AsyncMock(return_value=types.SimpleNamespace(tools=[], nextCursor="repeat")),
        )
        with self.assertRaisesRegex(ValueError, "Repeated cursor"):
            asyncio.run(verifier.exercise(session, {}, "probe.txt", "EXPECTED"))

    def test_verification_report_preserves_chatgpt_not_tested(self):
        with scratch_directory() as folder:
            state = Path(folder)
            report = {"local_verified": True, "tool_count": 7, "chatgpt_connection": "not_tested"}
            verifier.save_verification(state, report)
            self.assertEqual(json.loads((state / "verification.json").read_text()), report)
            self.assertFalse(list(state.glob(".verification-*")))


class LauncherContractTests(unittest.TestCase):
    def test_cmd_arguments_forwarded_and_policy_process_only(self):
        for name in ("Install", "Connect", "Status", "Verify"):
            text = (ROOT / (name + ".cmd")).read_text(encoding="ascii")
            self.assertIn("-Action " + name + " %*", text)
            self.assertIn("-ExecutionPolicy RemoteSigned", text)
            self.assertNotIn("Set-ExecutionPolicy", text)

    def test_powershell_preserves_argv_and_ascii_ps51_source(self):
        text = (ROOT / "scripts/windows.ps1").read_text(encoding="ascii")
        self.assertIn("'wslpath', '-a', '-u', $absolute", text)
        self.assertIn("'--exec'", text)
        self.assertIn("& $script:WslCommand @Arguments", text)
        self.assertNotIn("Invoke-Expression", text)
        self.assertNotIn("bash -c", text)
        self.assertIn("$ErrorActionPreference = 'Continue'", text)
        self.assertIn("if ($nativeExitCode -ne 0)", text)

    def test_installer_never_registers_or_downloads_pipe_to_shell(self):
        self.assertIn('"--no-register"', embedded)
        self.assertNotIn('"--register-local-client"', embedded)
        self.assertNotIn("curl", shell_source)


if __name__ == "__main__":
    unittest.main()
