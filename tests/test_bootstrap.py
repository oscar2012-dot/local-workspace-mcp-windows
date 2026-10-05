"""Offline prerequisite-bootstrap tests. Never invoke apt, sudo or a network."""
import contextlib
import gzip
import hashlib
import io
import os
from pathlib import Path
import shutil
import stat
import subprocess
import tarfile
import tempfile
import types
import unittest
from unittest import mock
import uuid

ROOT = Path(__file__).resolve().parents[1]
shell_source = (ROOT / "scripts/bootstrap-wsl.sh").read_text(encoding="utf-8")
embedded = shell_source.split("<<'PY'\n", 1)[1].rsplit("\nPY", 1)[0]
bootstrap = types.ModuleType("bootstrap_under_test")
exec(compile(embedded, str(ROOT / "scripts/bootstrap-wsl.sh"), "exec"), bootstrap.__dict__)


@contextlib.contextmanager
def scratch_directory():
    # Restricted Windows tokens cannot use Python's private mkdtemp DACL; test
    # fixtures inherit the temp-root ACL there, not production Linux permissions.
    root = Path(tempfile.gettempdir()).resolve()
    path = root / ("lwmcp-bootstrap-test-" + uuid.uuid4().hex)
    path.mkdir(mode=0o700 if os.name == "posix" else 0o777)
    try:
        yield path
    finally:
        if path.parent.resolve() != root or not path.name.startswith("lwmcp-bootstrap-test-"):
            raise RuntimeError("Invalid test cleanup target")
        shutil.rmtree(path)


def archive_bytes(name=None, kind=tarfile.REGTYPE, content=b"fake-executable", duplicate=False):
    buffer = io.BytesIO()
    with tarfile.open(fileobj=buffer, mode="w:") as archive:
        entry = tarfile.TarInfo(name or bootstrap.UV_MEMBER)
        entry.type = kind
        if kind in (tarfile.SYMTYPE, tarfile.LNKTYPE):
            entry.linkname = "outside"
        entry.size = len(content) if kind == tarfile.REGTYPE else 0
        archive.addfile(entry, io.BytesIO(content) if entry.size else None)
        if duplicate:
            archive.addfile(entry, io.BytesIO(content) if entry.size else None)
    return gzip.compress(buffer.getvalue())


def fixture_pin(content):
    return mock.patch.object(bootstrap, "UV_SHA256", hashlib.sha256(content).hexdigest())


class PlatformTests(unittest.TestCase):
    @contextlib.contextmanager
    def supported(self):
        with mock.patch.object(bootstrap.platform, "system", return_value="Linux"), \
                mock.patch.object(bootstrap.platform, "machine", return_value="x86_64"), \
                mock.patch.object(bootstrap.platform, "release", return_value="6.6-microsoft-standard-WSL2"), \
                mock.patch.object(bootstrap.platform, "freedesktop_os_release", return_value={"ID": "ubuntu", "VERSION_ID": "24.04"}), \
                mock.patch.object(bootstrap.os, "getuid", return_value=1000, create=True), \
                mock.patch.object(bootstrap.sys, "version_info", (3, 12, 0)):
            yield

    def test_supported_platform(self):
        with self.supported():
            bootstrap.require_platform()

    def test_platform_rejections_before_mutation(self):
        cases = (("system", "Windows"), ("machine", "aarch64"),
                 ("release", "4.4-Microsoft"), ("release", "generic-linux"),
                 ("freedesktop_os_release", {"ID": "debian", "VERSION_ID": "13"}),
                 ("freedesktop_os_release", {"ID": "ubuntu", "VERSION_ID": "22.04"}),
                 ("freedesktop_os_release", {"ID": "ubuntu", "VERSION_ID": "unknown"}))
        for name, value in cases:
            with self.subTest(name=name, value=value), self.supported(), \
                    mock.patch.object(bootstrap.platform, name, return_value=value), \
                    self.assertRaises(bootstrap.BootstrapError):
                bootstrap.require_platform()

    def test_root_and_old_python_rejected(self):
        with self.supported(), mock.patch.object(bootstrap.os, "getuid", return_value=0):
            with self.assertRaises(bootstrap.BootstrapError):
                bootstrap.require_platform()
        with self.supported(), mock.patch.object(bootstrap.sys, "version_info", (3, 11, 9)):
            with self.assertRaises(bootstrap.BootstrapError):
                bootstrap.require_platform()


class PathTests(unittest.TestCase):
    def test_rejects_relative_parent_and_windows_mount_homes(self):
        for path in (Path("relative"), Path(tempfile.gettempdir()).resolve() / ".." / "home", Path("/mnt/example")):
            with self.subTest(path=path), self.assertRaises(bootstrap.BootstrapError):
                bootstrap.validate_target(path)

    def test_rejects_symlink_directory_metadata(self):
        home = Path(tempfile.gettempdir()).resolve() / "example-home"
        metadata = types.SimpleNamespace(st_mode=stat.S_IFLNK | 0o700, st_uid=1000)
        with mock.patch.object(Path, "resolve", lambda self: self), \
                mock.patch.object(Path, "lstat", return_value=metadata), \
                mock.patch.object(bootstrap.os, "getuid", return_value=1000, create=True):
            with self.assertRaisesRegex(bootstrap.BootstrapError, "symbolic link"):
                bootstrap.validate_target(home)

    def test_rejects_writable_directory_ancestors(self):
        home = Path(tempfile.gettempdir()).resolve() / "example-home"
        metadata = types.SimpleNamespace(st_mode=stat.S_IFDIR | 0o777, st_uid=1000)
        with mock.patch.object(Path, "resolve", lambda self: self), \
                mock.patch.object(Path, "lstat", return_value=metadata), \
                mock.patch.object(bootstrap.os, "getuid", return_value=1000, create=True):
            with self.assertRaisesRegex(bootstrap.BootstrapError, "permissions"):
                bootstrap.validate_target(home)

    def test_file_ownership_links_permissions_and_execution(self):
        path = mock.Mock(spec=Path)
        good = dict(st_mode=stat.S_IFREG | 0o700, st_nlink=1, st_uid=1000)
        with mock.patch.object(bootstrap.os, "getuid", return_value=1000, create=True), \
                mock.patch.object(bootstrap.os, "access", return_value=True):
            path.lstat.return_value = types.SimpleNamespace(**good)
            bootstrap.validate_uv_file(path)
            for change in ({"st_mode": stat.S_IFLNK | 0o700}, {"st_nlink": 2}, {"st_uid": 2000},
                           {"st_mode": stat.S_IFREG | 0o777}, {"st_mode": stat.S_IFREG | 0o4700}):
                with self.subTest(change=change), self.assertRaises(bootstrap.BootstrapError):
                    path.lstat.return_value = types.SimpleNamespace(**(good | change))
                    bootstrap.validate_uv_file(path)
            path.lstat.return_value = types.SimpleNamespace(**good)
            with mock.patch.object(bootstrap.os, "access", return_value=False):
                with self.assertRaisesRegex(bootstrap.BootstrapError, "not executable"):
                    bootstrap.validate_uv_file(path)

    def test_linux_filesystem_required_even_for_mount_beneath_home(self):
        home = Path(tempfile.gettempdir()).resolve() / "example-home"
        metadata = types.SimpleNamespace(st_mode=stat.S_IFDIR | 0o700, st_uid=1000)
        with mock.patch.object(Path, "resolve", lambda self: self), \
                mock.patch.object(Path, "lstat", return_value=metadata), \
                mock.patch.object(Path, "exists", return_value=True), \
                mock.patch.object(bootstrap.os, "getuid", return_value=1000, create=True), \
                mock.patch.object(bootstrap.subprocess, "run", return_value=types.SimpleNamespace(stdout="9p\n")):
            with self.assertRaisesRegex(bootstrap.BootstrapError, "Linux filesystem"):
                bootstrap.validate_target(home)

    def test_safe_linux_target_is_accepted_without_creating_directories(self):
        home = Path(tempfile.gettempdir()).resolve() / "example-home"
        metadata = types.SimpleNamespace(st_mode=stat.S_IFDIR | 0o700, st_uid=1000)
        with mock.patch.object(Path, "resolve", lambda self: self), \
                mock.patch.object(Path, "lstat", return_value=metadata), \
                mock.patch.object(Path, "exists", return_value=True), \
                mock.patch.object(Path, "mkdir") as mkdir, \
                mock.patch.object(bootstrap.os, "getuid", return_value=1000, create=True), \
                mock.patch.object(bootstrap.subprocess, "run", return_value=types.SimpleNamespace(stdout="ext2/ext3\n")):
            self.assertEqual(bootstrap.validate_target(home), home / ".local/bin/uv")
            mkdir.assert_not_called()

    def test_existing_local_uv_is_preserved(self):
        target = mock.Mock(spec=Path)
        target.exists.return_value = True
        with mock.patch.object(bootstrap, "validate_target", return_value=target), \
                mock.patch.object(bootstrap, "validate_uv_file") as check, \
                mock.patch.object(bootstrap.shutil, "which") as which:
            self.assertIs(bootstrap.existing_uv(Path("home"), {"PATH": "path"}), target)
            check.assert_called_once_with(target)
            which.assert_not_called()

    def test_broken_symlink_is_not_treated_as_missing(self):
        target = mock.Mock(spec=Path)
        target.exists.return_value = False
        target.is_symlink.return_value = True
        with mock.patch.object(bootstrap, "validate_target", return_value=target), \
                mock.patch.object(bootstrap, "validate_uv_file", side_effect=bootstrap.BootstrapError("unsafe")):
            with self.assertRaises(bootstrap.BootstrapError):
                bootstrap.existing_uv(Path("home"), {"PATH": "path"})

    def test_existing_system_uv_is_preserved(self):
        target = mock.Mock(spec=Path)
        target.exists.return_value = False
        target.is_symlink.return_value = False
        with mock.patch.object(bootstrap, "validate_target", return_value=target), \
                mock.patch.object(bootstrap, "validate_uv_file") as check, \
                mock.patch.object(bootstrap.shutil, "which", return_value="/usr/bin/uv"):
            self.assertEqual(bootstrap.existing_uv(Path("home"), {"PATH": "path"}), Path("/usr/bin/uv"))
            check.assert_called_once_with(Path("/usr/bin/uv"))


class ArchiveTests(unittest.TestCase):
    def test_hash_checked_before_tar_or_gzip(self):
        with mock.patch.object(bootstrap.gzip, "GzipFile") as decompress:
            with self.assertRaisesRegex(bootstrap.BootstrapError, "SHA256"):
                bootstrap.verified_uv_bytes(b"untrusted")
            decompress.assert_not_called()

    def test_exact_regular_uv_extracted(self):
        content = archive_bytes()
        with fixture_pin(content):
            self.assertEqual(bootstrap.verified_uv_bytes(content), b"fake-executable")

    def test_wrong_paths_and_duplicates_rejected(self):
        cases = ({"name": "../uv"}, {"name": "/uv"}, {"name": "uv"},
                 {"name": "uv-x86_64-unknown-linux-gnu/../uv"},
                 {"name": "uv-x86_64-unknown-linux-gnu\\uv"}, {"duplicate": True})
        for arguments in cases:
            content = archive_bytes(**arguments)
            with self.subTest(arguments=arguments), fixture_pin(content), self.assertRaises(bootstrap.BootstrapError):
                bootstrap.verified_uv_bytes(content)

    def test_links_and_special_files_rejected(self):
        for kind in (tarfile.SYMTYPE, tarfile.LNKTYPE, tarfile.DIRTYPE, tarfile.FIFOTYPE, tarfile.CHRTYPE):
            content = archive_bytes(kind=kind)
            with self.subTest(kind=kind), fixture_pin(content), self.assertRaises(bootstrap.BootstrapError):
                bootstrap.verified_uv_bytes(content)

    def test_empty_or_oversized_executable_rejected(self):
        empty = archive_bytes(content=b"")
        with fixture_pin(empty), self.assertRaises(bootstrap.BootstrapError):
            bootstrap.verified_uv_bytes(empty)
        content = archive_bytes()
        with fixture_pin(content), mock.patch.object(bootstrap, "MAX_EXECUTABLE", 4):
            with self.assertRaisesRegex(bootstrap.BootstrapError, "size"):
                bootstrap.verified_uv_bytes(content)

    def test_expanded_and_compressed_size_caps(self):
        content = archive_bytes()
        with fixture_pin(content), mock.patch.object(bootstrap, "MAX_EXPANDED", 10):
            with self.assertRaisesRegex(bootstrap.BootstrapError, "expanded"):
                bootstrap.verified_uv_bytes(content)
        with fixture_pin(content), mock.patch.object(bootstrap, "MAX_DOWNLOAD", 10):
            with self.assertRaises(bootstrap.BootstrapError):
                bootstrap.verified_uv_bytes(content)

    def test_no_archive_extractall_or_shell_installer(self):
        self.assertNotIn(".extractall(", embedded)
        self.assertNotIn(".extract(", embedded)
        self.assertNotIn("curl", shell_source)
        self.assertNotIn("shell=True", embedded)


class DownloadTests(unittest.TestCase):
    def mock_download(self, content, url="https://release-assets.githubusercontent.com/example"):
        opener = mock.MagicMock()
        response = opener.open.return_value.__enter__.return_value
        response.url = url
        response.read.return_value = content
        return opener

    def test_pinned_official_url_and_sha(self):
        self.assertEqual(bootstrap.UV_VERSION, "0.12.19")
        self.assertTrue(bootstrap.UV_URL.startswith("https://github.com/astral-sh/uv/releases/download/0.12.19/"))
        self.assertEqual(len(bootstrap.UV_SHA256), 64)
        content = b"download-fixture"
        opener = self.mock_download(content)
        with fixture_pin(content), mock.patch.object(bootstrap.urllib.request, "build_opener", return_value=opener) as build:
            self.assertEqual(bootstrap.download_uv(), content)
            self.assertEqual(opener.open.call_args.args[0].full_url, bootstrap.UV_URL)
            self.assertEqual(opener.open.call_args.kwargs["timeout"], 60)
            self.assertEqual(build.call_args.args[0].proxies, {})

    def test_download_hash_size_and_tls_fail_closed(self):
        cases = ((b"wrong", "https://example.invalid", None),
                 (b"12345", "https://example.invalid", 4),
                 (b"whatever", "http://example.invalid", None))
        for content, url, maximum in cases:
            opener = self.mock_download(content, url)
            with self.subTest(url=url, maximum=maximum), \
                    mock.patch.object(bootstrap.urllib.request, "build_opener", return_value=opener), \
                    mock.patch.object(bootstrap, "MAX_DOWNLOAD", maximum or 100), \
                    self.assertRaises(bootstrap.BootstrapError):
                bootstrap.download_uv()

    def test_insecure_redirect_rejected(self):
        with self.assertRaises(bootstrap.BootstrapError):
            bootstrap.HTTPSOnlyRedirect().redirect_request(None, None, 302, "redirect", {}, "http://example.invalid")


class AptTests(unittest.TestCase):
    def test_package_query_is_read_only_and_allowlisted(self):
        result = types.SimpleNamespace(returncode=0, stdout="installed")
        with mock.patch.object(bootstrap.subprocess, "run", return_value=result) as run:
            self.assertTrue(bootstrap.package_installed("git", {}))
            self.assertEqual(run.call_args.args[0][0], "/usr/bin/dpkg-query")
            self.assertFalse(run.call_args.kwargs["check"])
            with self.assertRaises(bootstrap.BootstrapError):
                bootstrap.package_installed("arbitrary-package", {})
            self.assertEqual(run.call_count, 1)

    def test_apt_only_installs_allowlist_missing_packages(self):
        terminal = mock.MagicMock()
        terminal.__enter__.return_value = terminal
        with mock.patch.object(Path, "is_file", return_value=True), \
                mock.patch("builtins.open", return_value=terminal) as open_tty, \
                mock.patch.object(bootstrap.os, "isatty", return_value=True), \
                mock.patch.object(bootstrap.subprocess, "run") as run:
            bootstrap.install_apt(["git", "ripgrep"], {"PATH": "test"})
            open_tty.assert_called_once_with("/dev/tty", "rb", buffering=0)
            self.assertEqual(run.call_count, 2)
            self.assertEqual(run.call_args_list[0].args[0], ["/usr/bin/sudo", "/usr/bin/apt-get", "update"])
            command = run.call_args_list[1].args[0]
            self.assertIn("--no-upgrade", command)
            self.assertEqual(command[-2:], ["git", "ripgrep"])
            self.assertNotIn("-S", command)
            self.assertIs(run.call_args.kwargs["stdin"], terminal)
            self.assertNotIn("upgrade", command)

    def test_empty_package_list_never_elevates(self):
        with mock.patch.object(bootstrap.subprocess, "run") as run, mock.patch("builtins.open") as tty:
            bootstrap.install_apt([], {})
            run.assert_not_called()
            tty.assert_not_called()

    def test_unexpected_packages_or_duplicates_rejected(self):
        for packages in (["docker.io"], ["nodejs"], ["git", "git"], ["--remove"]):
            with self.subTest(packages=packages), self.assertRaises(bootstrap.BootstrapError):
                bootstrap.install_apt(packages, {})

    def test_no_tty_never_launches_sudo(self):
        with mock.patch.object(Path, "is_file", return_value=True), \
                mock.patch("builtins.open", side_effect=OSError), \
                mock.patch.object(bootstrap.subprocess, "run") as run:
            with self.assertRaisesRegex(bootstrap.BootstrapError, "interactive"):
                bootstrap.install_apt(["git"], {})
            run.assert_not_called()

    def test_existing_non_apt_commands_avoid_replacement(self):
        with mock.patch.object(bootstrap, "package_installed", return_value=False), \
                mock.patch.object(bootstrap.shutil, "which", return_value="/trusted/command"), \
                mock.patch.object(bootstrap, "existing_uv", return_value=Path("uv")):
            status = bootstrap.dependencies(Path("home"), {"PATH": "path"})
            self.assertEqual(status["missing_apt"], ["python3-venv", "ca-certificates"])
            self.assertEqual(status["broken"], [])

    def test_installed_but_missing_commands_not_silently_reinstalled(self):
        with mock.patch.object(bootstrap, "package_installed", return_value=True), \
                mock.patch.object(bootstrap.shutil, "which", return_value=None), \
                mock.patch.object(Path, "is_file", return_value=False), \
                mock.patch.object(bootstrap, "existing_uv", return_value=None):
            status = bootstrap.dependencies(Path("home"), {"PATH": "path"})
            self.assertEqual(status["missing_apt"], [])
            self.assertEqual(status["broken"], ["ca-certificates", "git", "python3", "ripgrep"])


class MainTests(unittest.TestCase):
    @contextlib.contextmanager
    def base(self, status):
        with mock.patch.object(bootstrap, "require_platform"), \
                mock.patch.object(bootstrap, "user_home", return_value=Path("home")), \
                mock.patch.object(bootstrap, "validate_target"), \
                mock.patch.object(bootstrap, "command_environment", return_value={}), \
                mock.patch.object(bootstrap, "dependencies", return_value=status) as dependencies, \
                mock.patch.object(bootstrap, "install_apt") as apt, \
                mock.patch.object(bootstrap, "install_uv") as uv, \
                mock.patch.object(bootstrap.os, "umask") as umask:
            yield dependencies, apt, uv, umask

    def test_check_missing_never_writes_installs_or_downloads(self):
        status = {"missing_apt": ["git"], "broken": [], "uv": None}
        with self.base(status) as (_, apt, uv, umask), mock.patch("sys.stdout", new_callable=io.StringIO) as output:
            self.assertEqual(bootstrap.main(["--check"]), 1)
            self.assertIn("BOOTSTRAP_READY=NOT_READY", output.getvalue())
            apt.assert_not_called()
            uv.assert_not_called()
            umask.assert_not_called()

    def test_ready_check_passes_and_rerun_does_nothing(self):
        status = {"missing_apt": [], "broken": [], "uv": Path("uv")}
        with self.base(status) as (_, apt, uv, umask):
            self.assertEqual(bootstrap.main(["--check"]), 0)
            self.assertEqual(bootstrap.main(["--install"]), 0)
            apt.assert_not_called()
            uv.assert_not_called()
            umask.assert_not_called()

    def test_install_runs_only_needed_steps_and_rechecks(self):
        missing = {"missing_apt": ["git"], "broken": [], "uv": None}
        ready = {"missing_apt": [], "broken": [], "uv": Path("uv")}
        with self.base(missing) as (dependencies, apt, uv, _):
            dependencies.side_effect = [missing, ready]
            self.assertEqual(bootstrap.main(["--install"]), 0)
            apt.assert_called_once_with(["git"], {})
            uv.assert_called_once_with(Path("home"), {})
            self.assertEqual(dependencies.call_count, 2)

    def test_existing_uv_not_upgraded_when_apt_needed(self):
        missing = {"missing_apt": ["git"], "broken": [], "uv": Path("uv")}
        ready = {"missing_apt": [], "broken": [], "uv": Path("uv")}
        with self.base(missing) as (dependencies, _, uv, _):
            dependencies.side_effect = [missing, ready]
            self.assertEqual(bootstrap.main(["--install"]), 0)
            uv.assert_not_called()

    def test_broken_packages_stop_before_any_install(self):
        status = {"missing_apt": ["git"], "broken": ["ca-certificates"], "uv": None}
        with self.base(status) as (_, apt, uv, umask):
            with self.assertRaises(bootstrap.BootstrapError):
                bootstrap.main(["--install"])
            apt.assert_not_called()
            uv.assert_not_called()
            umask.assert_not_called()

    def test_explicit_action_required(self):
        with mock.patch("sys.stderr", new_callable=io.StringIO):
            with self.assertRaises(SystemExit):
                bootstrap.main([])


class PublicationTests(unittest.TestCase):
    def test_existing_uv_skips_download_and_publish(self):
        with mock.patch.object(bootstrap, "existing_uv", return_value=Path("existing")), \
                mock.patch.object(bootstrap, "download_uv") as download, \
                mock.patch.object(bootstrap, "publish_uv") as publish:
            self.assertEqual(bootstrap.install_uv(Path("home"), {}), Path("existing"))
            download.assert_not_called()
            publish.assert_not_called()

    def test_existing_destination_never_overwritten(self):
        target = mock.Mock(spec=Path)
        target.exists.return_value = True
        with mock.patch.object(bootstrap, "validate_target", return_value=target), \
                mock.patch.object(bootstrap.os, "link") as link, \
                self.assertRaises(bootstrap.BootstrapError):
            bootstrap.publish_uv(Path("home"), b"bytes")
        link.assert_not_called()

    def test_no_shell_profile_or_global_path_changes(self):
        for name in (".bashrc", ".profile", "/etc/environment", "os.replace(", "os.rename("):
            self.assertNotIn(name, embedded)
        self.assertIn("os.link(temporary, target, follow_symlinks=False)", embedded)

    def test_publication_race_preserves_new_user_file_and_cleans_only_temp(self):
        with scratch_directory() as home:
            local = home / ".local"
            local.mkdir()
            binary = local / "bin"
            binary.mkdir()
            target = binary / "uv"

            def inherited_acl_temp(*, prefix, dir):
                path = Path(dir) / (prefix + uuid.uuid4().hex)
                descriptor = os.open(path, os.O_WRONLY | os.O_CREAT | os.O_EXCL,
                                     0o600 if os.name == "posix" else 0o666)
                return descriptor, str(path)

            def competing_publication(source, destination, **kwargs):
                self.assertFalse(kwargs["follow_symlinks"])
                self.assertEqual(destination, target)
                target.write_bytes(b"user-created-file")
                raise FileExistsError

            with mock.patch.object(bootstrap, "validate_target", return_value=target), \
                    mock.patch.object(bootstrap, "validate_uv_file"), \
                    mock.patch.object(bootstrap.tempfile, "mkstemp", side_effect=inherited_acl_temp), \
                    mock.patch.object(bootstrap.os, "fchmod", create=True), \
                    mock.patch.object(bootstrap.os, "link", side_effect=competing_publication):
                with self.assertRaisesRegex(bootstrap.BootstrapError, "not overwritten"):
                    bootstrap.publish_uv(home, b"verified-payload")
            self.assertEqual(target.read_bytes(), b"user-created-file")
            self.assertFalse(list(binary.glob(".uv-bootstrap-*")))

    def test_environment_drops_credentials(self):
        user = types.SimpleNamespace(pw_name="example", pw_dir="/example")
        secret = "sk-" + "x" * 40
        with mock.patch.object(bootstrap, "identity", return_value=user), \
                mock.patch.dict(os.environ, {"OPENAI_API_KEY": secret, "HOME": "/wrong", "PATH": "/wrong", "TERM": "xterm"}, clear=True):
            environment = bootstrap.command_environment(Path("/example"))
            self.assertNotIn(secret, repr(environment))
            self.assertNotIn("/wrong", repr(environment))
            self.assertEqual(environment["TERM"], "xterm")


if __name__ == "__main__":
    unittest.main()
