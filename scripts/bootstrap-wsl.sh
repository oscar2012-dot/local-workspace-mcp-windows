#!/usr/bin/env bash
set -euo pipefail
# The guided Windows installer invokes --install only after explicit consent.
# Ubuntu provides python3; do not download and execute a bootstrap shell script.
if ! command -v python3 >/dev/null 2>&1; then
    echo 'BOOTSTRAP_READY=NOT_READY'
    echo 'Python 3 is missing. Use Ubuntu 24.04 or newer with its default Python installation.' >&2
    exit 1
fi
exec python3 - "$@" <<'PY'
"""Opt-in, bounded prerequisite setup for the documents-mode Windows wizard."""
import argparse
import gzip
import hashlib
import io
import os
import platform
import shutil
import stat
import subprocess
import sys
import tarfile
import tempfile
import urllib.parse
import urllib.request
from pathlib import Path

UV_VERSION = "0.12.19"
UV_ARCHIVE = "uv-x86_64-unknown-linux-gnu.tar.gz"
UV_URL = "https://github.com/astral-sh/uv/releases/download/" + UV_VERSION + "/" + UV_ARCHIVE
UV_SHA256 = "23bf5552d220e0842b65c862097b2ebaeba0064b74eda5e565e77fd25969d8c8"
UV_MEMBER = "uv-x86_64-unknown-linux-gnu/uv"
MAX_DOWNLOAD = 64 * 1024 * 1024
MAX_EXPANDED = 160 * 1024 * 1024
MAX_EXECUTABLE = 128 * 1024 * 1024
APT_PACKAGES = ("python3", "python3-venv", "git", "ripgrep", "ca-certificates")
SYSTEM_PATH = "/usr/local/sbin:/usr/local/bin:/usr/sbin:/usr/bin:/sbin:/bin"


class BootstrapError(RuntimeError):
    """Only fixed, safe-to-display messages belong in this exception."""


def require_platform():
    if platform.system() != "Linux" or platform.machine().lower() not in {"x86_64", "amd64"}:
        raise BootstrapError("This bootstrap requires x64 Ubuntu inside WSL 2.")
    kernel = platform.release().lower()
    if "microsoft" not in kernel or "wsl2" not in kernel:
        raise BootstrapError("Use WSL 2, not WSL 1 or native Linux.")
    if os.getuid() == 0:
        raise BootstrapError("Run as your normal WSL user, without sudo; only apt commands request elevation.")
    release = platform.freedesktop_os_release()
    try:
        version = tuple(int(part) for part in release.get("VERSION_ID", "").split("."))
    except ValueError:
        raise BootstrapError("Ubuntu version could not be verified.") from None
    if release.get("ID") != "ubuntu" or version < (24, 4):
        raise BootstrapError("The guided installer requires Ubuntu 24.04 or newer; it does not upgrade your distribution.")
    if sys.version_info < (3, 12):
        raise BootstrapError("Python 3.12 or newer is required. Use the default Python in Ubuntu 24.04 or newer.")


def identity():
    import pwd
    return pwd.getpwuid(os.getuid())


def user_home():
    # Avoid accepting an inherited HOME override as an installation destination.
    return Path(identity().pw_dir)


def command_environment(home):
    user = identity()
    environment = {key: os.environ[key] for key in ("TERM", "COLORTERM") if key in os.environ}
    environment.update(HOME=str(home), USER=user.pw_name, LOGNAME=user.pw_name,
                       PATH=str(home / ".local/bin") + ":" + SYSTEM_PATH, LANG="C.UTF-8", LC_ALL="C.UTF-8")
    return environment


def validate_target(home):
    if not home.is_absolute() or ".." in home.parts or home.resolve() != home:
        raise BootstrapError("The WSL home must be an absolute Linux directory without symbolic links.")
    if home == Path(home.anchor) or home == Path("/mnt") or Path("/mnt") in home.parents:
        raise BootstrapError("The WSL home must be on Linux storage, not a Windows/shared mount.")
    target = home / ".local/bin/uv"
    # Do not follow symlink ancestors or fix permissions on existing user folders.
    for directory in [*reversed(home.parents), home, home / ".local", target.parent]:
        try:
            info = directory.lstat()
        except FileNotFoundError:
            if directory == home:
                raise BootstrapError("The configured WSL home directory does not exist.") from None
            continue
        if not stat.S_ISDIR(info.st_mode):
            raise BootstrapError("An installation directory is a symbolic link or not a real directory.")
        if info.st_uid not in (0, os.getuid()) or stat.S_IMODE(info.st_mode) & 0o022:
            raise BootstrapError("Installation directory ancestors have unsafe ownership or permissions.")
        if directory == home or home in directory.parents:
            if info.st_uid != os.getuid() or stat.S_IMODE(info.st_mode) & 0o022:
                raise BootstrapError("Existing home/bin directories must be yours and not group/world writable.")
    probe = target.parent
    while not probe.exists():
        probe = probe.parent
    filesystem = subprocess.run(["/usr/bin/stat", "-f", "-c", "%T", str(probe)],
                                env={"PATH": SYSTEM_PATH, "LC_ALL": "C"},
                                stdin=subprocess.DEVNULL, stdout=subprocess.PIPE, stderr=subprocess.DEVNULL,
                                text=True, check=True, timeout=15).stdout.strip()
    if filesystem not in {"ext2/ext3", "ext2", "ext3", "ext4", "btrfs", "xfs", "f2fs", "zfs"}:
        raise BootstrapError("User-local executables must be on a supported Linux filesystem, not a shared mount.")
    return target


def validate_uv_file(path):
    info = path.lstat()
    if not stat.S_ISREG(info.st_mode) or info.st_nlink != 1:
        raise BootstrapError("An existing uv path is not a single-link regular file. It was not changed.")
    if info.st_uid not in (0, os.getuid()) or stat.S_IMODE(info.st_mode) & 0o6022:
        raise BootstrapError("An existing uv executable has unsafe ownership or permissions. It was not changed.")
    if not os.access(path, os.X_OK):
        raise BootstrapError("An existing uv file is not executable. It was not changed.")


def existing_uv(home, environment):
    local = validate_target(home)
    if local.exists() or local.is_symlink():
        validate_uv_file(local)
        return local
    found = shutil.which("uv", path=environment["PATH"])
    if found:
        path = Path(found)
        validate_uv_file(path)
        return path
    return None


def package_installed(package, environment):
    if package not in APT_PACKAGES:
        raise BootstrapError("Unknown prerequisite package.")
    result = subprocess.run(["/usr/bin/dpkg-query", "--show", "--showformat=${db:Status-Status}", package],
                            env=environment, stdin=subprocess.DEVNULL, stdout=subprocess.PIPE,
                            stderr=subprocess.DEVNULL, text=True, timeout=15, check=False)
    return result.returncode == 0 and result.stdout.strip() == "installed"


def dependencies(home, environment):
    installed = {name: package_installed(name, environment) for name in APT_PACKAGES}
    # Preserve usable hand-installed git/Python/ripgrep rather than installing an
    # apt alternative merely because no corresponding package is registered.
    commands = {"python3": "python3", "git": "git", "ripgrep": "rg"}
    missing = []
    broken = []
    for package in APT_PACKAGES:
        command = commands.get(package)
        available = bool(shutil.which(command, path=environment["PATH"])) if command else installed[package]
        if not available:
            if installed[package]:
                broken.append(package)
            else:
                missing.append(package)
    bundle = Path("/etc/ssl/certs/ca-certificates.crt")
    if installed["ca-certificates"] and (not bundle.is_file() or bundle.stat().st_size == 0):
        broken.append("ca-certificates")
    return {"missing_apt": missing, "broken": sorted(set(broken)),
            "uv": existing_uv(home, environment)}


def report(status):
    if status["missing_apt"]:
        print("MISSING_APT_PACKAGES=" + " ".join(status["missing_apt"]), flush=True)
    if status["broken"]:
        print("BROKEN_APT_PACKAGES=" + " ".join(status["broken"]), flush=True)
        print("Installed package files appear missing. Repair them manually; this bootstrap will not overwrite them.", flush=True)
    if status["uv"] is None:
        print("MISSING_UV=YES", flush=True)
    else:
        print("UV_SOURCE=EXISTING_PRESERVED", flush=True)
    ready = not status["missing_apt"] and not status["broken"] and status["uv"] is not None
    print("BOOTSTRAP_READY=" + ("PASS" if ready else "NOT_READY"), flush=True)
    return ready


def install_apt(packages, environment):
    if not packages:
        return
    if any(package not in APT_PACKAGES for package in packages) or len(set(packages)) != len(packages):
        raise BootstrapError("Refusing an unexpected prerequisite package list.")
    if not Path("/usr/bin/sudo").is_file() or not Path("/usr/bin/apt-get").is_file():
        raise BootstrapError("Ubuntu sudo/apt-get is unavailable; prepare these prerequisites manually.")
    print("Installing only missing Ubuntu prerequisites. sudo may ask for your WSL password.", flush=True)
    # Python's stdin contains this script. sudo reads /dev/tty by default, and the
    # explicit terminal FD also keeps apt's stdin separate from the script stream.
    try:
        terminal = open("/dev/tty", "rb", buffering=0)
    except OSError:
        raise BootstrapError("Open the guided installer in an interactive Windows terminal to use sudo.") from None
    with terminal:
        if not os.isatty(terminal.fileno()):
            raise BootstrapError("An interactive terminal is required for sudo.")
        for arguments in (["/usr/bin/sudo", "/usr/bin/apt-get", "update"],
                          ["/usr/bin/sudo", "/usr/bin/apt-get", "install", "--no-upgrade", "--no-install-recommends", "-y", *packages]):
            subprocess.run(arguments, env=environment, stdin=terminal, check=True)


class HTTPSOnlyRedirect(urllib.request.HTTPRedirectHandler):
    def redirect_request(self, req, fp, code, msg, headers, newurl):
        if urllib.parse.urlsplit(newurl).scheme != "https":
            raise BootstrapError("Refusing an insecure uv download redirect.")
        return super().redirect_request(req, fp, code, msg, headers, newurl)


def download_uv():
    request = urllib.request.Request(UV_URL, headers={"User-Agent": "local-workspace-mcp-windows-bootstrap/0.1"})
    opener = urllib.request.build_opener(urllib.request.ProxyHandler({}), HTTPSOnlyRedirect())
    with opener.open(request, timeout=60) as response:
        if urllib.parse.urlsplit(response.url).scheme != "https":
            raise BootstrapError("Refusing an insecure uv download.")
        content = response.read(MAX_DOWNLOAD + 1)
    if len(content) > MAX_DOWNLOAD:
        raise BootstrapError("The uv download exceeded its size limit.")
    if hashlib.sha256(content).hexdigest() != UV_SHA256:
        raise BootstrapError("The uv release SHA256 did not match. Nothing from the download was installed.")
    return content


def verified_uv_bytes(archive):
    # Check again at the extraction boundary, including when download_uv is mocked.
    if len(archive) > MAX_DOWNLOAD or hashlib.sha256(archive).hexdigest() != UV_SHA256:
        raise BootstrapError("The uv release SHA256 did not match; extraction was refused.")
    # Bound the decompressed TAR too, before walking any attacker-controlled size
    # headers. No extract/extractall operation is ever used.
    with gzip.GzipFile(fileobj=io.BytesIO(archive)) as compressed:
        expanded = compressed.read(MAX_EXPANDED + 1)
    if len(expanded) > MAX_EXPANDED:
        raise BootstrapError("The expanded uv archive exceeded its size limit.")
    with tarfile.open(fileobj=io.BytesIO(expanded), mode="r:") as bundle:
        matches = [entry for entry in bundle.getmembers() if entry.name == UV_MEMBER]
        if len(matches) != 1:
            raise BootstrapError("The uv archive did not contain exactly the expected executable.")
        member = matches[0]
        if not member.isfile() or member.issym() or member.islnk() or member.sparse is not None:
            raise BootstrapError("The uv executable is not a normal regular archive member.")
        if not 0 < member.size <= MAX_EXECUTABLE:
            raise BootstrapError("The uv executable has an unexpected size.")
        with bundle.extractfile(member) as source:
            content = source.read(MAX_EXECUTABLE + 1)
        if len(content) != member.size or len(content) > MAX_EXECUTABLE:
            raise BootstrapError("The uv executable has an unexpected extracted size.")
    return content


def publish_uv(home, content):
    target = validate_target(home)
    if target.exists() or target.is_symlink():
        raise BootstrapError("The uv destination already exists. No existing file was replaced.")
    for directory in (home / ".local", target.parent):
        directory.mkdir(mode=0o700, exist_ok=True)
        validate_target(home)
    descriptor, temporary_name = tempfile.mkstemp(prefix=".uv-bootstrap-", dir=target.parent)
    temporary = Path(temporary_name)
    try:
        with os.fdopen(descriptor, "wb") as stream:
            stream.write(content)
            stream.flush()
            os.fsync(stream.fileno())
            os.fchmod(stream.fileno(), 0o700)
        validate_uv_file(temporary)
        # Atomic no-clobber publication. os.replace/rename could overwrite a user
        # file created after the earlier existence check, so neither is used.
        os.link(temporary, target, follow_symlinks=False)
    except FileExistsError:
        raise BootstrapError("Another process created the uv destination. It was not overwritten.") from None
    finally:
        # This is one exact mkstemp-created file, not a recursively deleted folder.
        temporary.unlink()
    validate_uv_file(target)
    return target


def install_uv(home, environment):
    found = existing_uv(home, environment)
    if found is not None:
        print("Existing uv preserved; no version change was attempted.", flush=True)
        return found
    print("Downloading the pinned official uv " + UV_VERSION + " release...", flush=True)
    archive = download_uv()
    content = verified_uv_bytes(archive)
    target = publish_uv(home, content)
    print("UV_RELEASE_SHA256=PASS\nUV_INSTALLED_VERSION=" + UV_VERSION, flush=True)
    return target


def main(argv=None):
    parser = argparse.ArgumentParser(description=__doc__)
    action = parser.add_mutually_exclusive_group(required=True)
    action.add_argument("--check", action="store_true", help="Read-only prerequisite check; never prompts or downloads.")
    action.add_argument("--install", action="store_true", help="Explicitly opt in to missing apt packages and pinned user-local uv.")
    options = parser.parse_args(argv)
    require_platform()
    home = user_home()
    validate_target(home)
    environment = command_environment(home)
    status = dependencies(home, environment)
    if options.check:
        return 0 if report(status) else 1
    if status["broken"]:
        report(status)
        raise BootstrapError("Repair the listed existing packages before rerunning; no automatic reinstall was attempted.")
    if not status["missing_apt"] and status["uv"] is not None:
        report(status)
        return 0
    os.umask(0o077)
    install_apt(status["missing_apt"], environment)
    if status["uv"] is None:
        install_uv(home, environment)
    ready = report(dependencies(home, environment))
    if ready:
        print("Prerequisites ready. No shell profile, global PATH, Docker, Node.js, or MCP connection was changed.", flush=True)
    return 0 if ready else 1


if __name__ == "__main__":
    try:
        sys.exit(main())
    except BootstrapError as error:
        print("BOOTSTRAP_READY=NOT_READY\nPreparation stopped: " + str(error), file=sys.stderr)
        sys.exit(1)
    except (KeyboardInterrupt, EOFError):
        print("\nPreparation cancelled. Rerunning will check what is already installed.", file=sys.stderr)
        sys.exit(130)
    except (OSError, ValueError, subprocess.SubprocessError, tarfile.TarError):
        print("BOOTSTRAP_READY=NOT_READY\nPreparation failed. Check terminal, Ubuntu package access, disk permissions, and HTTPS connectivity. No raw exception or credentials are logged.", file=sys.stderr)
        sys.exit(1)
PY
