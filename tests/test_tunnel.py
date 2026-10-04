"""Offline security and lifecycle tests. No credentials or network are used."""

from contextlib import contextmanager
import importlib.util
import io
import json
import os
from pathlib import Path
import signal
import stat
import subprocess
import sys
import tempfile
from types import SimpleNamespace
import unittest
from unittest import mock
import urllib.error
import zipfile


SOURCE = Path(__file__).resolve().parents[1] / "scripts" / "tunnel.py"
SPEC = importlib.util.spec_from_file_location("community_tunnel", SOURCE)
tunnel = importlib.util.module_from_spec(SPEC)
SPEC.loader.exec_module(tunnel)
FAKE_ID = "tunnel_" + "0" * 32
FAKE_KEY = "sk-" + "x" * 40


def make_zip(binary="tunnel-client-runtime", filename=None, mode=stat.S_IFREG | 0o755, data=b"sample"):
    buffer = io.BytesIO()
    with zipfile.ZipFile(buffer, "w") as archive:
        entry = zipfile.ZipInfo(filename or binary)
        entry.filename = filename or binary  # Preserve backslashes on Windows for malformed ZIP tests.
        entry.create_system = 3
        entry.external_attr = mode << 16
        archive.writestr(entry, data)
    return buffer.getvalue()


class ValidationTests(unittest.TestCase):
    def test_id_shape(self):
        self.assertEqual(tunnel.valid_tunnel_id(FAKE_ID), FAKE_ID)
        for invalid in (None, "", FAKE_ID + "\n", FAKE_ID + "extra", "https://example.invalid"):
            with self.subTest(invalid=invalid), self.assertRaises(tunnel.SafetyError):
                tunnel.valid_tunnel_id(invalid)

    def test_key_rejects_admin_and_newlines_without_echo(self):
        self.assertEqual(tunnel.valid_key(FAKE_KEY), FAKE_KEY)
        for invalid in ("sk-" + "admin-" + "x" * 30, "short", FAKE_KEY + "\n"):
            with self.subTest(invalid=invalid), self.assertRaises(tunnel.SafetyError) as error:
                tunnel.valid_key(invalid)
            self.assertNotIn(invalid, str(error.exception))

    def test_platform_rejects_windows(self):
        with mock.patch.object(tunnel.platform, "system", return_value="Windows"):
            with self.assertRaises(tunnel.SafetyError):
                tunnel.require_platform()

    def test_platform_rejects_root(self):
        with mock.patch.object(tunnel.platform, "system", return_value="Linux"), \
                mock.patch.object(tunnel.platform, "machine", return_value="x86_64"), \
                mock.patch.object(tunnel, "current_uid", return_value=0):
            with self.assertRaises(tunnel.SafetyError):
                tunnel.require_platform()

    def test_platform_requires_wsl(self):
        with mock.patch.object(tunnel.platform, "system", return_value="Linux"), \
                mock.patch.object(tunnel.platform, "machine", return_value="x86_64"), \
                mock.patch.object(tunnel, "current_uid", return_value=1000), \
                mock.patch.object(tunnel.platform, "release", return_value="generic-linux"):
            with self.assertRaises(tunnel.SafetyError):
                tunnel.require_platform()

    def test_canonical_rejects_relative_and_parent_segments(self):
        for invalid in ("relative", str(Path.cwd() / ".." / "escape"), "bad\npath", None):
            with self.subTest(invalid=invalid), self.assertRaises(tunnel.SafetyError):
                tunnel.canonical_path(invalid)

    def test_config_contains_file_reference_not_secret(self):
        content = tunnel.configuration(FAKE_ID, Path("private/runtime-key"),
                                       Path('state/space name/launch.sh'), Path("private")).decode()
        self.assertIn('"file:private', content)
        self.assertIn("listen_addr: 127.0.0.1:0", content)
        self.assertIn("open_browser: false", content)
        self.assertNotIn(FAKE_KEY, content)
        self.assertNotIn("codex", content)

    def test_config_quotes_yaml_values(self):
        value = Path('quoted" value')
        content = tunnel.configuration(FAKE_ID, value, value, Path("private")).decode()
        self.assertIn(json.dumps(str(value)), content)

    def test_private_metadata_rejects_symlink_hardlink_owner_and_modes(self):
        path = mock.Mock(spec=Path)
        valid = dict(st_mode=stat.S_IFREG | 0o600, st_uid=1000, st_nlink=1, st_size=20)
        with mock.patch.object(tunnel, "current_uid", return_value=1000):
            path.lstat.return_value = SimpleNamespace(**valid)
            tunnel.file_metadata(path, 100)
            changes = ({"st_mode": stat.S_IFLNK | 0o600}, {"st_nlink": 2}, {"st_uid": 1001},
                       {"st_mode": stat.S_IFREG | 0o644}, {"st_mode": stat.S_IFREG | 0o4600},
                       {"st_size": 101})
            for change in changes:
                with self.subTest(change=change), self.assertRaises(tunnel.SafetyError):
                    path.lstat.return_value = SimpleNamespace(**(valid | change))
                    tunnel.file_metadata(path, 100)

    def test_private_directory_modes(self):
        path = mock.Mock(spec=Path)
        with mock.patch.object(tunnel, "current_uid", return_value=1000):
            path.lstat.return_value = SimpleNamespace(st_mode=stat.S_IFDIR | 0o700, st_uid=1000)
            tunnel.checked_directory(path, private=True)
            path.lstat.return_value.st_mode = stat.S_IFDIR | 0o755
            tunnel.checked_directory(path, private=False)
            with self.assertRaises(tunnel.SafetyError):
                tunnel.checked_directory(path, private=True)


class ArchiveTests(unittest.TestCase):
    def test_valid_runtime_zip(self):
        self.assertEqual(tunnel.executable_from_zip(make_zip(), "tunnel-client-runtime"), b"sample")

    def test_missing_runtime_rejected(self):
        with self.assertRaises(tunnel.SafetyError):
            tunnel.executable_from_zip(make_zip("tunnel-client"), "tunnel-client-runtime")

    def test_zip_paths_symlinks_and_empty_rejected(self):
        cases = ({"filename": "../tunnel-client-runtime"},
                 {"filename": "/tunnel-client-runtime"},
                 {"filename": "directory\\tunnel-client-runtime"},
                 {"mode": stat.S_IFLNK | 0o777}, {"data": b""})
        for arguments in cases:
            with self.subTest(arguments=arguments), self.assertRaises(tunnel.SafetyError):
                tunnel.executable_from_zip(make_zip(**arguments), "tunnel-client-runtime")

    def test_duplicate_executables_rejected(self):
        content = io.BytesIO()
        with zipfile.ZipFile(content, "w") as archive:
            archive.writestr("a/tunnel-client-runtime", "one")
            archive.writestr("b/tunnel-client-runtime", "two")
        with self.assertRaises(tunnel.SafetyError):
            tunnel.executable_from_zip(content.getvalue(), "tunnel-client-runtime")

    def test_bounded_extraction(self):
        with mock.patch.object(tunnel, "MAX_BINARY", 4), self.assertRaises(tunnel.SafetyError):
            tunnel.executable_from_zip(make_zip(), "tunnel-client-runtime")

    def test_unknown_flavor_rejected(self):
        with self.assertRaises(tunnel.SafetyError):
            tunnel.install_client(Path("unused"), "arbitrary-command")

    def test_bad_download_checksum_never_written(self):
        private = mock.Mock()
        archive = mock.Mock()
        private.__truediv__ = mock.Mock(return_value=archive)
        archive.exists.return_value = False
        archive.is_symlink.return_value = False
        binary = "tunnel-client-runtime"
        manifest = (tunnel.ASSETS[binary] + "  " + binary + "-" + tunnel.RELEASE + "-linux-amd64.zip\n").encode()
        with mock.patch.object(tunnel, "download", side_effect=[manifest, b"untrusted"]), \
                mock.patch.object(tunnel, "private_write") as write:
            with self.assertRaises(tunnel.SafetyError):
                tunnel.install_client(private, binary)
            write.assert_not_called()

    def test_bad_manifest_never_downloads_executable(self):
        private = mock.MagicMock()
        private.__truediv__.return_value.exists.return_value = False
        private.__truediv__.return_value.is_symlink.return_value = False
        with mock.patch.object(tunnel, "download", return_value=b"wrong-checksum") as download:
            with self.assertRaises(tunnel.SafetyError):
                tunnel.install_client(private, "tunnel-client-runtime")
            self.assertEqual(download.call_count, 1)

    def test_bad_cached_archive_never_executes(self):
        private = mock.MagicMock()
        private.__truediv__.return_value.exists.return_value = True
        with mock.patch.object(tunnel, "read_private", return_value=b"changed"), \
                mock.patch.object(tunnel, "download") as download, \
                mock.patch.object(tunnel, "private_write") as write:
            with self.assertRaises(tunnel.SafetyError):
                tunnel.install_client(private, "tunnel-client-runtime")
            download.assert_not_called()
            write.assert_not_called()

    def test_nonofficial_download_disallowed(self):
        with self.assertRaises(tunnel.SafetyError):
            tunnel.download("https://example.invalid/client.zip", 10)

    def test_http_redirect_disallowed(self):
        with self.assertRaises(tunnel.SafetyError):
            tunnel.HTTPSRedirectOnly().redirect_request(None, None, 302, "redirect", {}, "http://example.invalid")


class SecretTests(unittest.TestCase):
    def test_key_requires_tty(self):
        private = mock.MagicMock()
        private.__truediv__.return_value.exists.return_value = False
        private.__truediv__.return_value.is_symlink.return_value = False
        with mock.patch.object(tunnel.sys.stdin, "isatty", return_value=False), \
                mock.patch.object(tunnel.getpass, "getpass") as prompt:
            with self.assertRaises(tunnel.SafetyError):
                tunnel.ensure_key(private)
            prompt.assert_not_called()

    def test_hidden_key_saved_only_in_private_file(self):
        private = mock.MagicMock()
        private.__truediv__.return_value.exists.return_value = False
        private.__truediv__.return_value.is_symlink.return_value = False
        output = io.StringIO()
        with mock.patch.object(tunnel.sys.stdin, "isatty", return_value=True), \
                mock.patch.object(tunnel.getpass, "getpass", return_value=FAKE_KEY), \
                mock.patch.object(tunnel, "private_write") as write, \
                mock.patch("sys.stdout", output):
            result = tunnel.ensure_key(private)
            write.assert_called_once_with(result, (FAKE_KEY + "\n").encode())
            self.assertNotIn(FAKE_KEY, output.getvalue())

    def test_saved_key_does_not_prompt(self):
        private = mock.MagicMock()
        private.__truediv__.return_value.exists.return_value = True
        with mock.patch.object(tunnel, "read_private", return_value=FAKE_KEY.encode()), \
                mock.patch.object(tunnel.getpass, "getpass") as prompt:
            tunnel.ensure_key(private)
            prompt.assert_not_called()

    def test_environment_excludes_credentials_and_tunnel_overrides(self):
        identity = SimpleNamespace(pw_dir="/example", pw_name="example")
        fake_pwd = SimpleNamespace(getpwuid=mock.Mock(return_value=identity))
        with mock.patch.dict(sys.modules, {"pwd": fake_pwd}), \
                mock.patch.object(tunnel, "current_uid", return_value=1000), \
                mock.patch.dict(os.environ, {"OPENAI_API_KEY": FAKE_KEY, "CONTROL_PLANE_API_KEY": FAKE_KEY,
                                             "HTTPS_PROXY": "https://example.invalid", "HOME": "/wrong",
                                             "PATH": "/wrong", "LANG": "C.UTF-8"}, clear=True):
            environment = tunnel.client_environment()
            self.assertEqual(environment["HOME"], "/example")
            self.assertEqual(environment["LANG"], "C.UTF-8")
            self.assertNotIn(FAKE_KEY, repr(environment))
            self.assertNotIn("HTTPS_PROXY", environment)
            self.assertNotIn("/wrong", repr(environment))

    def test_tunnel_change_refused(self):
        private = mock.MagicMock()
        private.__truediv__.return_value.exists.return_value = True
        with mock.patch.object(tunnel, "read_private", return_value=json.dumps({"tunnel_id": FAKE_ID}).encode()), \
                mock.patch.object(tunnel, "private_write") as write:
            with self.assertRaises(tunnel.SafetyError):
                tunnel.load_tunnel(private, "tunnel_" + "1" * 32)
            write.assert_not_called()


class HealthTests(unittest.TestCase):
    def private(self):
        private = mock.MagicMock()
        private.__truediv__.return_value.exists.return_value = True
        return private

    def test_loopback_only_before_request(self):
        invalid = ("http://example.invalid:80", "https://127.0.0.1:80", "http://127.0.0.1:0",
                   "http://127.0.0.1:65536", "http://127.0.0.1:12/private", "http://localhost:80")
        with mock.patch.object(tunnel.urllib.request, "build_opener") as opener:
            for address in invalid:
                with self.subTest(address=address), \
                        mock.patch.object(tunnel, "read_private", return_value=address.encode()), \
                        self.assertRaises(tunnel.SafetyError):
                    tunnel.health_status(self.private())
            opener.assert_not_called()

    def test_readiness_requires_both_health_routes(self):
        opener = mock.MagicMock()
        opener.open.return_value.__enter__.return_value.status = 200
        with mock.patch.object(tunnel, "read_private", return_value=b"http://127.0.0.1:12345"), \
                mock.patch.object(tunnel.urllib.request, "build_opener", return_value=opener) as build:
            result = tunnel.health_status(self.private())
            self.assertEqual(result[1], [200, 200])
            self.assertEqual(opener.open.call_count, 2)
            self.assertEqual(build.call_args.args[0].proxies, {})
            self.assertIsInstance(build.call_args.args[1], tunnel.NoRedirect)

    def test_health_http_failure_is_not_ready(self):
        opener = mock.MagicMock()
        opener.open.side_effect = urllib.error.HTTPError("unused", 503, "not ready", {}, None)
        with mock.patch.object(tunnel, "read_private", return_value=b"http://127.0.0.1:12345"), \
                mock.patch.object(tunnel.urllib.request, "build_opener", return_value=opener):
            self.assertEqual(tunnel.health_status(self.private())[1], [503, 503])

    def test_health_redirects_not_followed(self):
        self.assertIsNone(tunnel.NoRedirect().redirect_request(None, None, 302, "redirect", {}, "http://example.invalid"))


class LifecycleTests(unittest.TestCase):
    @contextmanager
    def lifecycle_mocks(self, wait_result=0):
        child = mock.Mock(pid=424242)
        child.wait.return_value = wait_result
        with mock.patch.object(tunnel.subprocess, "Popen", return_value=child) as spawn, \
                mock.patch.object(tunnel.signal, "signal") as set_signal, \
                mock.patch.object(tunnel.signal, "SIGHUP", 1, create=True), \
                mock.patch.object(tunnel, "terminate_group") as terminate, \
                mock.patch.object(tunnel.threading, "Thread") as thread, \
                mock.patch.object(tunnel, "clear_health") as clear:
            yield child, spawn, set_signal, terminate, thread, clear

    def test_runtime_cleanup_and_no_key_argv(self):
        with self.lifecycle_mocks() as (child, spawn, signals, terminate, thread, clear):
            result = tunnel.run_client(Path("tunnel-client-runtime"), Path("connection.yaml"), {}, Path("private"))
            self.assertEqual(result, 0)
            self.assertEqual(spawn.call_args.args[0][1], "run")
            self.assertTrue(spawn.call_args.kwargs["start_new_session"])
            self.assertEqual(spawn.call_args.kwargs["stdin"], subprocess.DEVNULL)
            self.assertNotIn(FAKE_KEY, repr(spawn.call_args))
            terminate.assert_called_once_with(child)
            clear.assert_called_once_with(Path("private"))
            thread.return_value.start.assert_called_once()
            thread.return_value.join.assert_called_once_with(timeout=5)
            self.assertEqual(signals.call_count, 9)

    def test_doctor_is_not_long_running_and_suppresses_console(self):
        with self.lifecycle_mocks() as (child, spawn, _, terminate, thread, _):
            tunnel.run_client(Path("tunnel-client"), Path("connection.yaml"), {}, timeout=90)
            self.assertEqual(spawn.call_args.args[0][1], "doctor")
            self.assertEqual(spawn.call_args.kwargs["stdout"], subprocess.DEVNULL)
            self.assertEqual(spawn.call_args.kwargs["stderr"], subprocess.DEVNULL)
            child.wait.assert_called_once_with(timeout=90)
            terminate.assert_called_once_with(child)
            thread.assert_not_called()

    def test_interrupt_still_cleans_children(self):
        with self.lifecycle_mocks() as (child, _, signals, terminate, _, clear):
            child.wait.side_effect = KeyboardInterrupt
            with self.assertRaises(KeyboardInterrupt):
                tunnel.run_client(Path("runtime"), Path("config"), {}, Path("private"))
            terminate.assert_called_once_with(child)
            clear.assert_called_once()
            self.assertEqual(signals.call_count, 9)

    def test_spawn_failure_restores_signals_without_unknown_pid(self):
        with self.lifecycle_mocks() as (_, spawn, signals, terminate, _, _):
            spawn.side_effect = OSError
            with self.assertRaises(OSError):
                tunnel.run_client(Path("runtime"), Path("config"), {})
            terminate.assert_not_called()
            self.assertEqual(signals.call_count, 9)

    def test_signal_during_spawn_still_tracks_child(self):
        with self.lifecycle_mocks() as (child, spawn, signals, terminate, _, _):
            def spawn_with_interrupt(*args, **kwargs):
                handler = signals.call_args_list[0].args[1]
                handler(signal.SIGINT, None)
                return child
            spawn.side_effect = spawn_with_interrupt
            with self.assertRaises(KeyboardInterrupt):
                tunnel.run_client(Path("runtime"), Path("config"), {})
            terminate.assert_called_once_with(child)

    def test_process_group_cleanup_is_bounded(self):
        child = mock.Mock(pid=424242)
        child.wait.side_effect = [subprocess.TimeoutExpired("fake", 10), 0]
        with mock.patch.object(tunnel.os, "killpg", create=True) as kill, \
                mock.patch.object(tunnel.signal, "SIGKILL", 9, create=True):
            tunnel.terminate_group(child)
            self.assertEqual(kill.call_count, 2)
            self.assertEqual(kill.call_args_list[0].args, (child.pid, signal.SIGTERM))
            self.assertEqual(child.wait.call_args_list, [mock.call(timeout=10), mock.call(timeout=5)])

    def test_status_never_downloads_prompts_or_creates_state(self):
        with mock.patch.object(tunnel, "require_platform"), \
                mock.patch.object(tunnel, "validate_state", return_value=Path("state")), \
                mock.patch.object(tunnel, "load_receipt", return_value={}), \
                mock.patch.object(tunnel, "private_directory", side_effect=FileNotFoundError) as directory, \
                mock.patch.object(tunnel, "install_client") as install, \
                mock.patch.object(tunnel, "ensure_key") as key, \
                mock.patch.object(tunnel, "load_tunnel") as settings:
            self.assertEqual(tunnel.main(["--status"]), 1)
            directory.assert_called_once_with(Path("state"), create=False)
            install.assert_not_called()
            key.assert_not_called()
            settings.assert_not_called()


@unittest.skipUnless(os.name == "posix", "real POSIX ownership/flock tests run on Linux CI")
class PosixStorageTests(unittest.TestCase):
    def setUp(self):
        self.temporary = tempfile.TemporaryDirectory()
        self.addCleanup(self.temporary.cleanup)
        self.root = Path(self.temporary.name).resolve()
        self.root.chmod(0o700)

    def test_atomic_private_write_and_read(self):
        target = self.root / "file"
        tunnel.private_write(target, b"one")
        tunnel.private_write(target, b"two")
        self.assertEqual(tunnel.read_private(target, 3), b"two")
        self.assertEqual(stat.S_IMODE(target.stat().st_mode), 0o600)

    def test_symlink_never_overwritten(self):
        target = self.root / "target"
        tunnel.private_write(target, b"original")
        link = self.root / "link"
        link.symlink_to(target)
        with self.assertRaises(tunnel.SafetyError):
            tunnel.private_write(link, b"changed")
        self.assertEqual(target.read_bytes(), b"original")

    def test_hardlink_never_overwritten(self):
        target = self.root / "target"
        tunnel.private_write(target, b"original")
        link = self.root / "link"
        os.link(target, link)
        with self.assertRaises(tunnel.SafetyError):
            tunnel.private_write(link, b"changed")
        self.assertEqual(target.read_bytes(), b"original")

    def test_flock_prevents_second_launcher(self):
        self.assertFalse(tunnel.is_running(self.root))
        with tunnel.state_lock(self.root):
            self.assertTrue(tunnel.is_running(self.root))
            with self.assertRaises(tunnel.SafetyError):
                with tunnel.state_lock(self.root):
                    self.fail("Second launcher acquired the lock")
        self.assertFalse(tunnel.is_running(self.root))

    def test_state_rejects_home_and_symlink(self):
        home = self.root / "home"
        home.mkdir(mode=0o700)
        state = home / "state"
        state.mkdir(mode=0o700)
        with mock.patch.object(tunnel.Path, "home", return_value=home):
            self.assertEqual(tunnel.validate_state(state), state)
            with self.assertRaises(tunnel.SafetyError):
                tunnel.validate_state(home)
            link = home / "redirect"
            link.symlink_to(state, target_is_directory=True)
            with self.assertRaises(tunnel.SafetyError):
                tunnel.validate_state(link)

    def test_receipt_rejects_workspace_overlap(self):
        state = self.root / "state"
        state.mkdir(mode=0o700)
        repo = self.root / "source"
        repo.mkdir(mode=0o700)
        tunnel.private_write(state / "launch.sh", b"#!/bin/sh\n", 0o700)
        receipt = dict(schema_version=1, upstream_commit=tunnel.UPSTREAM_COMMIT,
                       launch=str(state / "launch.sh"), workspace=str(self.root),
                       repo=str(repo), mode="full", skip_worker=True)
        tunnel.private_write(state / "install.json", json.dumps(receipt).encode())
        with self.assertRaises(tunnel.SafetyError):
            tunnel.load_receipt(state)


if __name__ == "__main__":
    unittest.main()
