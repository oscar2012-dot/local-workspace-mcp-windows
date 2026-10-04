#!/usr/bin/env python3
"""Foreground WSL private MCP tunnel. No model inference requests are made here.

Run through Connect.cmd. State and credentials live in the WSL Linux filesystem,
outside the checkout and shared workspace. Only the official runtime-only client
is used for the long-running connection; the full client is used for doctor.
"""

import argparse
from contextlib import contextmanager
import getpass
import hashlib
import io
import json
import os
from pathlib import Path, PurePosixPath
import platform
import re
import signal
import stat
import subprocess
import sys
import tempfile
import threading
import urllib.error
import urllib.parse
import urllib.request
import warnings
import zipfile


RELEASE = "v0.0.15"
UPSTREAM_COMMIT = "ba42837e7aa54cd265e62023e5079f0e4affdf84"
DOWNLOAD_BASE = f"https://github.com/openai/tunnel-client/releases/download/{RELEASE}"
ASSETS = {
    "tunnel-client": "8c836dc5d68d68b663d9a5c5b28ff9fa780d9f7a3fffb1c306880b8f32fab5f1",
    "tunnel-client-runtime": "f26f8b3ee6c335e38fa5cfbe6ce5635f53738f08a26eecf07d6cebacab4a1abf",
}
MAX_ARCHIVE = 64 * 1024 * 1024
MAX_BINARY = 128 * 1024 * 1024
DEFAULT_STATE = Path.home() / ".local/state/local-workspace-mcp-windows"
TUNNEL_PATTERN = re.compile(r"tunnel_[0-9a-f]{32}\Z")


class SafetyError(RuntimeError):
    """Safe-to-display error with no supplied secrets or private path values."""


def current_uid():
    return os.getuid()


def require_platform():
    if platform.system() != "Linux" or platform.machine().lower() not in ("x86_64", "amd64"):
        raise SafetyError("This release requires x64 Linux inside WSL; run Connect.cmd on Windows.")
    if current_uid() == 0:
        raise SafetyError("Do not run the connector as root or with sudo.")
    # Linux alone is not evidence that Windows path/permission assumptions apply.
    kernel = platform.release().lower()
    if "microsoft" not in kernel or "wsl2" not in kernel:
        raise SafetyError("This integration requires WSL 2, not WSL 1 or native Linux.")


def is_within(path, parent):
    return path == parent or parent in path.parents


def canonical_path(value):
    if not isinstance(value, (str, Path)) or not str(value) or any(ord(c) < 32 for c in str(value)):
        raise SafetyError("A configured path is invalid.")
    path = Path(value)
    if not path.is_absolute() or ".." in path.parts or path.resolve() != path:
        raise SafetyError("Paths must be absolute, canonical, and free of symbolic links.")
    return path


def checked_directory(path, private=False):
    metadata = path.lstat()
    if not stat.S_ISDIR(metadata.st_mode) or metadata.st_uid != current_uid():
        raise SafetyError("Storage must be a real directory owned by the current WSL user.")
    mask = 0o077 if private else 0o022
    if stat.S_IMODE(metadata.st_mode) & mask:
        raise SafetyError("Storage permissions are too broad; use private WSL Linux storage.")


def validate_state(value):
    state = canonical_path(Path(value).expanduser())
    home = canonical_path(Path.home())
    if state == home or not is_within(state, home) or is_within(state, Path("/mnt")):
        raise SafetyError("State must be a dedicated directory under the WSL home, never /mnt.")
    for directory in (state, *state.parents):
        checked_directory(directory, private=directory == state)
        if directory == home:
            break
    return state


def file_metadata(path, maximum):
    metadata = path.lstat()
    if (not stat.S_ISREG(metadata.st_mode) or metadata.st_nlink != 1
            or metadata.st_uid != current_uid() or stat.S_IMODE(metadata.st_mode) & 0o6077):
        raise SafetyError("Refusing an unsafe file: require a private, owned, regular file with one link.")
    if metadata.st_size > maximum:
        raise SafetyError("A local file exceeded its expected size limit.")
    return metadata


def read_private(path, maximum):
    file_metadata(path, maximum)
    descriptor = os.open(path, os.O_RDONLY | getattr(os, "O_NOFOLLOW", 0))
    with os.fdopen(descriptor, "rb") as stream:
        metadata = os.fstat(stream.fileno())
        if (not stat.S_ISREG(metadata.st_mode) or metadata.st_nlink != 1
                or metadata.st_uid != current_uid() or stat.S_IMODE(metadata.st_mode) & 0o6077):
            raise SafetyError("Refusing an unsafe file opened from private storage.")
        content = stream.read(maximum + 1)
    if len(content) > maximum:
        raise SafetyError("A local file exceeded its expected size limit.")
    return content


def private_write(path, content, mode=0o600):
    checked_directory(path.parent, private=True)
    if path.exists() or path.is_symlink():
        file_metadata(path, max(MAX_ARCHIVE, MAX_BINARY))
    descriptor, temporary = tempfile.mkstemp(prefix=".new-", dir=path.parent)
    try:
        with os.fdopen(descriptor, "wb") as stream:
            stream.write(content)
            stream.flush()
            os.fsync(stream.fileno())
            os.fchmod(stream.fileno(), mode)
        os.replace(temporary, path)
    finally:
        if os.path.exists(temporary):
            os.unlink(temporary)


def load_receipt(state):
    try:
        receipt = json.loads(read_private(state / "install.json", 65536))
    except (ValueError, UnicodeError):
        raise SafetyError("Installation receipt is invalid. Run Install.cmd first.") from None
    if not isinstance(receipt, dict):
        raise SafetyError("Installation receipt is invalid. Run Install.cmd first.")
    if receipt.get("schema_version") != 1:
        raise SafetyError("Unsupported installation receipt version. Run Install.cmd first.")
    if receipt.get("upstream_commit") != UPSTREAM_COMMIT:
        raise SafetyError("The installation receipt does not match this release's reviewed upstream commit.")
    launch = canonical_path(receipt.get("launch"))
    workspace = canonical_path(receipt.get("workspace"))
    repo = canonical_path(receipt.get("repo"))
    if launch != state / "launch.sh":
        raise SafetyError("The receipt must use the launch.sh inside this installation state.")
    file_metadata(launch, 1024 * 1024)
    if not os.access(launch, os.X_OK):
        raise SafetyError("The installation launcher is not executable.")
    if not workspace.is_dir() or not repo.is_dir():
        raise SafetyError("The configured workspace or upstream checkout no longer exists.")
    for directory in (workspace, repo):
        if is_within(state, directory) or is_within(directory, state):
            raise SafetyError("Private state must not overlap the workspace or upstream checkout.")
    integration = Path(__file__).resolve().parents[1]
    for directory in (workspace, state):
        if is_within(integration, directory) or is_within(directory, integration):
            raise SafetyError("Neither private state nor the shared workspace may overlap this integration checkout.")
    if is_within(repo, workspace) or is_within(workspace, repo):
        raise SafetyError("The shared workspace must not overlap the upstream checkout.")
    if receipt.get("mode") not in ("documents", "full") or type(receipt.get("skip_worker")) is not bool:
        raise SafetyError("The installation receipt has an invalid mode or worker setting.")
    if receipt["mode"] == "documents" and receipt["skip_worker"]:
        raise SafetyError("Documents mode requires its Docker worker.")
    return receipt


def private_directory(state, create):
    private = state / "tunnel"
    if create:
        private.mkdir(mode=0o700, exist_ok=True)
    checked_directory(private, private=True)
    return private


def valid_tunnel_id(value):
    if not isinstance(value, str) or not TUNNEL_PATTERN.fullmatch(value):
        raise SafetyError("Enter a valid tunnel ID from your own OpenAI tunnel settings.")
    return value


def load_tunnel(private, supplied=None):
    settings = private / "connection.json"
    existing = None
    if settings.exists() or settings.is_symlink():
        try:
            data = json.loads(read_private(settings, 4096))
            existing = valid_tunnel_id(data.get("tunnel_id") if isinstance(data, dict) else None)
        except (ValueError, UnicodeError):
            raise SafetyError("Saved tunnel metadata is invalid.") from None
    if supplied:
        supplied = valid_tunnel_id(supplied)
        if existing and supplied != existing:
            raise SafetyError("This state already belongs to another tunnel; use a separate installation state.")
    tunnel_id = supplied or existing
    if tunnel_id is None:
        if not sys.stdin.isatty():
            raise SafetyError("Run Connect.cmd in an interactive terminal for first-time setup.")
        tunnel_id = valid_tunnel_id(input("Your Windows tunnel ID: ").strip())
    if existing is None:
        private_write(settings, (json.dumps({"tunnel_id": tunnel_id}) + "\n").encode("utf-8"))
    return tunnel_id


def valid_key(key):
    if not re.fullmatch(r"sk-[A-Za-z0-9_-]{16,1000}", key) or key.startswith("sk-admin-"):
        raise SafetyError("A runtime key is required; administrative keys are not accepted.")
    return key


def ensure_key(private, replace=False):
    key_file = private / "runtime-key"
    if key_file.exists() or key_file.is_symlink():
        # Validate the existing file even before replacement: do not replace links.
        saved = read_private(key_file, 1024)
        if not replace:
            try:
                valid_key(saved.decode("ascii").strip())
            except UnicodeError:
                raise SafetyError("The saved key is invalid; use --replace-key.") from None
            return key_file
        del saved
    if not sys.stdin.isatty():
        raise SafetyError("Run Connect.cmd in an interactive terminal to enter the key safely.")
    print("Paste a runtime key restricted to Tunnels Read + Use. Input is hidden.", flush=True)
    print("Do not paste the key into chat, source files, or command arguments.", flush=True)
    with warnings.catch_warnings():
        warnings.simplefilter("error", getpass.GetPassWarning)
        key = valid_key(getpass.getpass("Runtime key (hidden): ").strip())
    private_write(key_file, (key + "\n").encode("ascii"))
    del key
    print("Runtime key stored privately in WSL (0600).", flush=True)
    return key_file


class NoRedirect(urllib.request.HTTPRedirectHandler):
    def redirect_request(self, req, fp, code, msg, headers, newurl):
        return None


class HTTPSRedirectOnly(urllib.request.HTTPRedirectHandler):
    def redirect_request(self, req, fp, code, msg, headers, newurl):
        if urllib.parse.urlsplit(newurl).scheme != "https":
            raise SafetyError("Refusing an insecure release redirect.")
        return super().redirect_request(req, fp, code, msg, headers, newurl)


def download(url, maximum):
    if not url.startswith(DOWNLOAD_BASE + "/"):
        raise SafetyError("Only the pinned official release download is supported.")
    request = urllib.request.Request(url, headers={"User-Agent": "local-workspace-mcp-windows/0.1"})
    opener = urllib.request.build_opener(urllib.request.ProxyHandler({}), HTTPSRedirectOnly())
    with opener.open(request, timeout=60) as response:
        if urllib.parse.urlsplit(response.url).scheme != "https":
            raise SafetyError("Refusing an insecure release download.")
        content = response.read(maximum + 1)
    if len(content) > maximum:
        raise SafetyError("The official release download exceeded its size limit.")
    return content


def executable_from_zip(content, binary):
    with zipfile.ZipFile(io.BytesIO(content)) as bundle:
        candidates = [entry for entry in bundle.infolist()
                      if entry.filename == binary and not entry.is_dir()]
        if len(candidates) != 1:
            raise SafetyError("The official release archive has an unexpected executable layout.")
        entry = candidates[0]
        member_path = PurePosixPath(entry.filename)
        kind = stat.S_IFMT(entry.external_attr >> 16)
        if (member_path.is_absolute() or ".." in member_path.parts or "\\" in entry.filename
                or kind not in (0, stat.S_IFREG) or entry.flag_bits & 1
                or not 0 < entry.file_size <= MAX_BINARY):
            raise SafetyError("Refusing an unsafe or oversized executable in the release archive.")
        # Read one reviewed basename into an exact destination; never extract paths.
        with bundle.open(entry) as source:
            result = source.read(MAX_BINARY + 1)
        if len(result) != entry.file_size or len(result) > MAX_BINARY:
            raise SafetyError("The extracted executable has an unexpected size.")
        return result


def install_client(private, binary):
    if binary not in ASSETS:
        raise SafetyError("Unknown tunnel client flavor.")
    expected = ASSETS[binary]
    archive_name = f"{binary}-{RELEASE}-linux-amd64.zip"
    archive = private / archive_name
    if archive.exists() or archive.is_symlink():
        content = read_private(archive, MAX_ARCHIVE)
    else:
        print(f"Downloading official {binary} {RELEASE}...", flush=True)
        manifest = download(DOWNLOAD_BASE + "/SHA256SUMS.txt", 2 * 1024 * 1024).decode("utf-8")
        pattern = re.compile(r"^" + expected + r"\s+\*?" + re.escape(archive_name) + r"$", re.M)
        if not pattern.search(manifest.replace("\r\n", "\n")):
            raise SafetyError("The published checksum differs from the reviewed release pin.")
        content = download(DOWNLOAD_BASE + "/" + archive_name, MAX_ARCHIVE)
    if hashlib.sha256(content).hexdigest() != expected:
        raise SafetyError("Release SHA256 verification failed; nothing was executed.")
    executable_content = executable_from_zip(content, binary)
    if not archive.exists():
        private_write(archive, content)
    executable = private / binary
    # Restore bytes from the verified archive on every connection, not an unchecked cache.
    private_write(executable, executable_content, 0o700)
    print(f"OFFICIAL_{binary.upper().replace('-', '_')}_SHA256=PASS", flush=True)
    return executable


def configuration(tunnel_id, key_file, launch, private):
    quote = json.dumps  # JSON-quoted scalars are also valid YAML strings.
    return (
        "config_version: 1\ncontrol_plane:\n"
        "  base_url: https://api.openai.com\n"
        f"  tunnel_id: {quote(valid_tunnel_id(tunnel_id))}\n"
        f"  api_key: {quote('file:' + str(key_file))}\n"
        "mcp:\n  commands:\n    - channel: main\n"
        f"      command: {quote(str(launch))}\n"
        "health:\n  listen_addr: 127.0.0.1:0\n"
        f"  url_file: {quote(str(private / 'health.url'))}\n"
        "admin_ui:\n  open_browser: false\n"
        "log:\n  level: info\n  format: json\n"
    ).encode("utf-8")


def client_environment():
    keep = {"TERM", "COLORTERM", "LANG", "LC_ALL", "LC_CTYPE", "TZ"}
    environment = {name: value for name, value in os.environ.items() if name in keep}
    # Derive identity from the OS rather than inherited USER/HOME overrides.
    import pwd
    identity = pwd.getpwuid(current_uid())
    environment.update(HOME=identity.pw_dir, USER=identity.pw_name, LOGNAME=identity.pw_name,
                       SHELL="/bin/bash", PATH=identity.pw_dir + "/.local/bin:/usr/local/bin:/usr/bin:/bin")
    return environment


def health_status(private):
    address_file = private / "health.url"
    if not address_file.exists() and not address_file.is_symlink():
        return None
    try:
        address = read_private(address_file, 256).decode("ascii").strip().rstrip("/")
    except UnicodeError:
        raise SafetyError("The local status address is invalid.") from None
    match = re.fullmatch(r"http://127\.0\.0\.1:([0-9]{1,5})", address)
    if not match or not 1 <= int(match[1]) <= 65535:
        raise SafetyError("The status address must use the IPv4 loopback interface and a valid port.")
    opener = urllib.request.build_opener(urllib.request.ProxyHandler({}), NoRedirect())
    statuses = []
    for route in ("healthz", "readyz"):
        try:
            with opener.open(address + "/" + route, timeout=2) as response:
                statuses.append(response.status)
        except urllib.error.HTTPError as error:
            statuses.append(error.code)
        except (urllib.error.URLError, OSError):
            statuses.append(None)
    return address, statuses


def monitor(private, stop):
    while not stop.wait(2):
        try:
            result = health_status(private)
            if result and result[1] == [200, 200]:
                print("\nWINDOWS_TUNNEL_READY=PASS\n"
                      "Startup readiness only; ChatGPT tool access still needs a real test.\n"
                      "Keep this window open while using ChatGPT.\n"
                      "Local status page: " + result[0] + "/ui\n", flush=True)
                return
        except (OSError, SafetyError):
            pass


@contextmanager
def state_lock(private):
    import fcntl
    lock_path = private / "launcher.lock"
    if lock_path.exists() or lock_path.is_symlink():
        file_metadata(lock_path, 4096)
    descriptor = os.open(lock_path, os.O_CREAT | os.O_RDWR | os.O_NOFOLLOW, 0o600)
    with os.fdopen(descriptor, "a+") as lock:
        file_metadata(lock_path, 4096)
        try:
            fcntl.flock(lock, fcntl.LOCK_EX | fcntl.LOCK_NB)
        except BlockingIOError:
            raise SafetyError("This installation is already connecting or running. Use Status.cmd.") from None
        yield


def is_running(private):
    import fcntl
    lock_path = private / "launcher.lock"
    if not lock_path.exists() and not lock_path.is_symlink():
        return False
    file_metadata(lock_path, 4096)
    descriptor = os.open(lock_path, os.O_RDONLY | os.O_NOFOLLOW)
    with os.fdopen(descriptor, "rb") as lock:
        try:
            fcntl.flock(lock, fcntl.LOCK_EX | fcntl.LOCK_NB)
        except BlockingIOError:
            return True
        fcntl.flock(lock, fcntl.LOCK_UN)
    return False


def clear_health(private):
    path = private / "health.url"
    if path.exists() or path.is_symlink():
        file_metadata(path, 256)
        path.unlink()


def terminate_group(child):
    # The child starts in a new session. Signals never target the parent terminal
    # group, other installations, or an arbitrary PID loaded from a state file.
    try:
        os.killpg(child.pid, signal.SIGTERM)
    except ProcessLookupError:
        pass
    try:
        child.wait(timeout=10)
    except subprocess.TimeoutExpired:
        pass
    try:
        os.killpg(child.pid, signal.SIGKILL)
    except ProcessLookupError:
        pass
    child.wait(timeout=5)


def run_client(executable, config, environment, private=None, timeout=None):
    child = None
    stop_requested = False
    watcher = None
    stop = threading.Event()
    handlers = {}

    def request_stop(_signum, _frame):
        nonlocal stop_requested
        if child is None:
            # A signal arriving during Popen must not lose the newly created PID
            # before assignment. Complete assignment, then enter normal cleanup.
            stop_requested = True
            return
        raise KeyboardInterrupt

    try:
        for signum in (signal.SIGINT, signal.SIGTERM, signal.SIGHUP):
            handlers[signum] = signal.signal(signum, request_stop)
        command = "run" if private is not None else "doctor"
        output = None if private is not None else subprocess.DEVNULL
        child = subprocess.Popen([str(executable), command, "--config", str(config)],
                                 env=environment, stdin=subprocess.DEVNULL,
                                 stdout=output, stderr=output, start_new_session=True)
        if stop_requested:
            raise KeyboardInterrupt
        if private is not None:
            watcher = threading.Thread(target=monitor, args=(private, stop), daemon=True)
            watcher.start()
        return child.wait(timeout=timeout)
    finally:
        stop.set()
        for signum in handlers:
            signal.signal(signum, signal.SIG_IGN)
        try:
            if child is not None:
                terminate_group(child)
            if watcher is not None:
                watcher.join(timeout=5)
            if private is not None:
                clear_health(private)
        finally:
            for signum, handler in handlers.items():
                signal.signal(signum, handler)


def main(argv=None):
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--state", type=Path, default=DEFAULT_STATE)
    parser.add_argument("--tunnel-id", help="Use your own dedicated Windows tunnel; never share another machine's ID.")
    parser.add_argument("--status", action="store_true", help="Read local readiness without downloading or prompting.")
    parser.add_argument("--replace-key", action="store_true", help="Prompt for a replacement key with hidden input.")
    options = parser.parse_args(argv)
    if options.status and (options.tunnel_id or options.replace_key):
        parser.error("--status cannot be combined with setup options")
    require_platform()
    state = validate_state(options.state)
    receipt = load_receipt(state)
    if options.status:
        try:
            private = private_directory(state, create=False)
        except FileNotFoundError:
            print("WINDOWS_TUNNEL_READY=NOT_RUNNING")
            return 1
        result = health_status(private) if is_running(private) else None
        if result is None:
            print("WINDOWS_TUNNEL_READY=NOT_RUNNING")
            return 1
        print(f"Local UI: {result[0]}/ui\nHEALTH_HTTP={result[1][0]}\nREADY_HTTP={result[1][1]}")
        print("CHATGPT_CONNECTION=NOT_TESTED_BY_STATUS")
        return 0 if result[1] == [200, 200] else 1
    os.umask(0o077)
    private = private_directory(state, create=True)
    with state_lock(private):
        tunnel_id = load_tunnel(private, options.tunnel_id)
        full_client = install_client(private, "tunnel-client")
        runtime_client = install_client(private, "tunnel-client-runtime")
        key_file = ensure_key(private, options.replace_key)
        config = private / "connection.yaml"
        private_write(config, configuration(tunnel_id, key_file, Path(receipt["launch"]), private))
        environment = client_environment()
        print("Checking the private profile with the official doctor...", flush=True)
        if run_client(full_client, config, environment, timeout=90):
            raise SafetyError("Official doctor failed. Check account permissions, tunnel ID, key, and network access.")
        clear_health(private)
        print("Starting the runtime-only private tunnel. Ctrl+C stops this connection.\n"
              "Waiting for WINDOWS_TUNNEL_READY=PASS...", flush=True)
        return run_client(runtime_client, config, environment, private=private)


if __name__ == "__main__":
    try:
        raise SystemExit(main())
    except SafetyError as error:
        print(f"Connection stopped: {error}", file=sys.stderr)
        raise SystemExit(1)
    except (KeyboardInterrupt, EOFError):
        print("\nCancelled. This launcher's child processes were stopped.")
        raise SystemExit(130)
    except (OSError, ValueError, subprocess.SubprocessError, zipfile.BadZipFile, getpass.GetPassWarning):
        # Do not echo exception text: file/network errors can contain private paths
        # or remote response contents. The helper does not create a transcript.
        print("Connection stopped: a local file, download, or client check failed. "
              "Check permissions and network connectivity; never share keys in logs.", file=sys.stderr)
        raise SystemExit(1)
