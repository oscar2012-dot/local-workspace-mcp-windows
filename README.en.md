# Local Workspace MCP — Windows/WSL Community Integration

[繁體中文](README.md) | English

**First installation: [download the ZIP](https://github.com/oscar2012-dot/local-workspace-mcp-windows/archive/refs/heads/main.zip) → extract it → double-click `Setup.cmd`.** Follow the [step-by-step installation guide](docs/INSTALL.en.md). The normal path does not require copying commands yourself.

Run [Local Workspace MCP](https://github.com/arumwu/local-workspace-mcp) on Windows through WSL2, then connect it to ChatGPT using your own OpenAI private tunnel. [oscar2012-dot](https://github.com/oscar2012-dot) maintains this project's installation entry points and connection integration. The MCP server comes from upstream; it is not an original server created by this project, and this is not an official OpenAI product.

**This community integration is currently an alpha.** The original personal Windows/WSL installation successfully connected through a tunnel and performed real file reads and writes; that experience remains valid. The new generalized setup wizard has not yet completed end-to-end testing on a clean computer. This version also lacks end-to-end verification of ChatGPT Desktop and the Docker document workflow. Start with test data; see [Testing status and acceptance checks](docs/TESTING.en.md) for the exact scope.

## Supported scope

- Windows x64, WSL2 and Ubuntu. The MCP server and tunnel-client run inside Linux; there is no native Windows backend.
- The default `documents` mode requires Docker to be running and WSL integration enabled for the selected Ubuntu distribution.
- `full` mode requires explicit acceptance of its permissions. Skipping the Docker worker is a separate option.
- Each user creates their own private tunnel and runtime API key restricted to **Tunnels Read + Use**. OpenAI account requirements, workspace policies and feature availability still apply.

| Mode | Purpose | Permission boundary |
| --- | --- | --- |
| `documents` (default) | Workspace file operations and the Docker document worker | The document worker has a container boundary; its readable data still needs protection |
| `full` | Adds host processes and other upstream host tools | Runs with the WSL user's operating-system permissions; the workspace is not a sandbox |
| `full` with the worker skipped | Full host tools without the Docker document worker | Still has full-mode permissions; Docker `run_python` is unavailable |

Full mode may access other WSL paths and Windows drives under `/mnt`. Enabling Docker alongside it only confines the worker; it does not isolate the host tools. Read [SECURITY.en.md](SECURITY.en.md) before proceeding.

## Beginner setup and daily use

1. [Download the ZIP](https://github.com/oscar2012-dot/local-workspace-mcp-windows/archive/refs/heads/main.zip). Verify its source and review the code; if needed, use **Properties → Unblock** on the ZIP before extracting it completely.
2. Double-click `Setup.cmd` and choose Traditional Chinese or English. The wizard checks WSL/Ubuntu, Linux tools and Docker in order, asking before installing missing components. You still complete the Ubuntu user setup, Docker license acceptance and WSL integration shown on screen.
3. Wait for `LOCAL_INSTALL_READY=PASS`, then follow the [private ChatGPT connection steps](docs/CHATGPT.en.md) to create your own tunnel. Run `Connect.cmd` and enter the key at the local hidden prompt.
4. After `WINDOWS_TUNNEL_READY=PASS` appears, add your own Tunnel connection in ChatGPT and complete the [hello.txt read/write test](docs/CHATGPT.en.md#5-confirm-the-connection-with-hellotxt). For daily use, run `Connect.cmd`; stop with **Ctrl+C**.

The [complete installation guide](docs/INSTALL.en.md) explains the expected result and what to do if each stage gets stuck. Running `Install.cmd` without arguments also opens the wizard. The wizard currently installs only the default documents mode; it does not switch to full mode when Docker fails.

Installation may require Windows UAC, your Ubuntu sudo password or a restart, through the relevant confirmation steps. It does not restart Windows automatically. After restarting, double-click `Setup.cmd` again; it rechecks the environment and skips components that are ready, without adding a startup task. A matching existing installation is verified and reused, not overwritten with a different mode.

## Advanced installation

Run the following commands in **Windows PowerShell opened in the project directory**. `Install.cmd` with arguments and `scripts/windows.ps1` use the advanced entry point. Prepare its prerequisites yourself first: Ubuntu 24.04 or newer, Python 3.12 or newer, Git, uv, ripgrep (`rg`) and working Docker; full mode also requires Node.js 20.9 or newer and npm. This advanced entry point does not automatically install global packages.

Official references: [Microsoft WSL](https://learn.microsoft.com/en-us/windows/wsl/install), [Docker WSL2 integration](https://docs.docker.com/desktop/features/wsl/) and [uv installation](https://docs.astral.sh/uv/getting-started/installation/).

Invoke individual actions directly:

```powershell
.\scripts\windows.ps1 -Action Install
.\scripts\windows.ps1 -Action Connect
.\scripts\windows.ps1 -Action Status
.\scripts\windows.ps1 -Action Verify
```

For example, select an installed Ubuntu distribution and a Windows workspace:

```powershell
.\Install.cmd -Distro Ubuntu-24.04 -Workspace "C:\MCP\Workspace"
```

Use `wsl --list --verbose` to find your actual distribution name. The workspace can also be an absolute WSL path; when omitted, it defaults to `~/LocalWorkspace` inside WSL. Choose full mode only after reading the security notes and accepting its host permissions:

```powershell
.\Install.cmd -Mode full -AcceptFullPermissions -State "~/.local/state/local-workspace-mcp-windows-full" -Workspace "~/LocalWorkspaceFull"
```

To also skip the Docker document worker, add `-SkipWorker`:

```powershell
.\Install.cmd -Mode full -AcceptFullPermissions -SkipWorker -State "~/.local/state/local-workspace-mcp-windows-full-no-worker" -Workspace "~/LocalWorkspaceFullNoWorker"
```

`-SkipWorker` is not available in documents mode and is not an automatic fallback after installation failure. An existing state's mode and workspace are not silently replaced; the full-mode examples above use separate state and workspace directories. A successful installation saves the latest local choices. Reinstalling full mode still requires explicit `-Mode full -AcceptFullPermissions`, plus `-SkipWorker` if that was the original choice.

If WSL is not installed, you can explicitly run `Install.cmd -InstallWSL -Distro Ubuntu-24.04` to invoke the Windows WSL installation process. This does not automatically elevate privileges. Follow the Windows prompts and complete Ubuntu's first-run setup before running the installer again.

`Verify` creates and retains a uniquely named test file containing no sensitive data in the workspace, and writes a verification report to the state directory. It does not prove that ChatGPT or the Docker document workflow works end to end. For daily use, run `Connect.cmd`. Stop the connection with **Ctrl+C** and allow cleanup to finish; do not substitute closing the terminal window for a normal stop.

The wizard requests required privileges only after you agree to the corresponding installation step. It does not change the global PowerShell execution policy, enable startup at login or register a connection with an MCP client. You still create your OpenAI account setup, tunnel and ChatGPT connection.

If scripts extracted from a GitHub ZIP are blocked or reported as unsigned, Windows may have retained the download's Mark-of-the-Web. First verify the source and review the code, then use **Properties → Unblock** on that ZIP and extract it again into a new directory; alternatively, unblock only a specific script you have reviewed. The launchers use process-scoped `RemoteSigned` and do not unblock files automatically. Do not change the global policy to `Unrestricted` or `Bypass` to work around this. Continue to follow management policies on organization-managed devices.

## Where settings are stored

| Location | Contents |
| --- | --- |
| `%LOCALAPPDATA%\LocalWorkspaceMCPWindows\settings.json` | Local Windows settings |
| `~/.local/state/local-workspace-mcp-windows` inside WSL | Installation, connection and runtime state, including the private runtime key |
| `~/.local/share/local-workspace-mcp-windows/upstream/` inside WSL | Upstream source at the pinned revision |
| The workspace selected during installation | Files the user makes available to the MCP server |

Use `-State` to select another dedicated directory under the WSL home, using an absolute path or `~/` path. Private state must stay on the Linux filesystem, outside the workspace, source directory and `/mnt`. Do not commit settings, WSL state, keys, actual tunnel IDs or raw diagnostic output to GitHub. The installation and connection state remain local; publishing source code does not turn them into a public service.

## Pinned versions and known limitations

- Upstream source is pinned to [`ba42837e7aa54cd265e62023e5079f0e4affdf84`](https://github.com/arumwu/local-workspace-mcp/tree/ba42837e7aa54cd265e62023e5079f0e4affdf84), preserving its original license and dependency lock.
- tunnel-client uses the official OpenAI `v0.0.15` release. The persistent connection uses the runtime-only executable. This integration generates the configuration; the full CLI only runs `doctor`. This repository does not vendor third-party binaries.
- Upstream [PR #4](https://github.com/arumwu/local-workspace-mcp/pull/4) records 7 existing npm audit findings: 2 moderate and 5 high, including `braces`, which had no patched version at the time. This is an upstream report, not a claim that this version fixes those findings or has completed a new security audit. Reassess before production use; see the [security notes](SECURITY.en.md).
- Public GitHub source does not mean a publicly hosted MCP endpoint or approval for the ChatGPT/Codex marketplace. This version provides self-installation and private connections; it does not provide marketplace publication or a Skill.
- This project does not promise free OpenAI services, unlimited quotas, or private-tunnel availability for every account.

## Documentation and licensing

- [Installation from scratch](docs/INSTALL.en.md)
- [Private ChatGPT connection](docs/CHATGPT.en.md)
- [Testing and issue reports](docs/TESTING.en.md)
- [Security boundaries and vulnerability reports](SECURITY.en.md)
- [Third-party sources and licenses](THIRD_PARTY_NOTICES.md)

This project's integration code and documentation are available under the [MIT License](LICENSE). Upstream Local Workspace MCP and other third-party components retain their own copyrights and licenses.
