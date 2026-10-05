# Installation from scratch (Windows/WSL)

[繁體中文](INSTALL.md) | English

This guide starts with the download, completes local installation, then connects to ChatGPT. The normal path uses on-screen actions rather than commands you must copy. **“One-click” means one `Setup.cmd` entry point guides the process. You still approve installations, create an Ubuntu user, accept Docker terms and create your own OpenAI tunnel.**

The supported platform is Windows x64, WSL2 and Ubuntu 24.04 or newer. The new wizard installs `documents` mode. Docker worker restrictions apply only to the worker; they do not isolate the entire computer. The original personal Windows/WSL installation has successfully connected and read/written files. The new wizard's end-to-end flow on a clean computer still needs verification. See [security notes](../SECURITY.en.md) and [testing status](TESTING.en.md).

## 1. Download and extract everything

**Where: browser → Windows File Explorer.**

1. Open [this project on GitHub](https://github.com/oscar2012-dot/local-workspace-mcp-windows) and choose **Code → Download ZIP**, or use the [direct ZIP download](https://github.com/oscar2012-dot/local-workspace-mcp-windows/archive/refs/heads/main.zip).
2. Verify that it comes from the project above, and review the README and code. If the ZIP's right-click **Properties** dialog offers **Unblock**, select it and apply after reviewing and trusting the source.
3. Use **Extract All** on the ZIP and choose a local directory you can write to. Open the extracted directory until you can see `Setup.cmd`, `Connect.cmd` and `scripts`.
4. In File Explorer's **View** options, enable **File name extensions**. Confirm the launcher is named `Setup.cmd`, not `Setup.cmd.txt`.

**Expected:** A normal directory containing those files. Do not run them from inside the ZIP preview.

**If stuck:** If the download marker blocks a script, review the source again and unblock only that ZIP before extracting it again, or unblock only a specific reviewed script. Do not disable Defender or change global PowerShell policy to `Bypass`/`Unrestricted`. Follow administrator policies on managed computers.

## 2. Open the wizard and choose a language

**Where: Windows File Explorer → setup window.**

Double-click `Setup.cmd` and choose **Traditional Chinese** or **English**. Double-clicking `Install.cmd` without arguments opens the same wizard. Start as your normal user; you do not need to run the whole process as administrator in advance.

**Expected:** A language menu and numbered setup stages. The wizard reports checks and asks before installing missing components. Components that are ready are skipped.

**If stuck:** Confirm that everything is extracted, the computer is not ARM-based, and the download marker described above is not blocking execution. `SETUP_PAUSED=EXISTING_FULL_MODE` means the wizard detected an existing full-mode installation. It stops with guidance to use the existing connection or advanced entry point, avoiding a change to documents mode.

## 3. Complete WSL2 and Ubuntu setup

**Where: setup wizard, Windows UAC/restart screens and Ubuntu's first-run window.**

If WSL2 or a suitable Ubuntu distribution is not ready, review the wizard's installation explanation and choose whether to continue. Installation happens only after your approval. Windows may show UAC or require a restart. Save your other work before restarting yourself.

After restarting, return to the extracted directory and **double-click `Setup.cmd` again**. This rechecks progress; it is not a task scheduled to run at startup. The wizard does not restart Windows automatically or ask you to delete an existing Ubuntu distribution.

When Ubuntu starts for the first time, follow its prompts to create your own Linux username and password. This is your Ubuntu password, not an OpenAI API key. Password entry normally shows no characters or asterisks; type it and press Enter, then enter it again when asked to confirm.

**Expected:** Ubuntu first-run setup is complete and a normal non-root user is available. When Ubuntu shows its command prompt, type `exit` in that Ubuntu window and press Enter to return to the wizard's WSL2 check. Do this in **Ubuntu**, not Windows PowerShell.

**If stuck:** `SETUP_PAUSED=WSL_SETUP` means WSL installation or a restart still needs to be completed; do that before reopening the wizard. `SETUP_PAUSED=UBUNTU_USER` means the normal user is not ready. Open that Ubuntu from the Windows Start menu, complete setup, then enter `exit` to return. For Windows virtualization or WSL enablement failures, follow [Microsoft's official WSL guide](https://learn.microsoft.com/en-us/windows/wsl/install). Do not remove a distribution containing existing data.

## 4. Install Linux prerequisites

**Where: the Ubuntu installation flow started by the wizard.**

After you approve the listed Ubuntu packages, the wizard prepares Python, Git, ripgrep and other required tools, then obtains a pinned version of uv with hash verification. If Ubuntu requests a sudo password, enter the Linux password created above. Invisible password input is normal.

**Expected:** Package download/installation progress, followed by the next wizard stage. The normal path does not require you to paste `apt` commands or installation scripts.

**If stuck:** Restore connectivity after a network failure, then reopen `Setup.cmd` to recheck. For a password error, confirm you are entering the Ubuntu password. If hash verification fails, stop and report a redacted error summary; do not bypass verification or execute the downloaded file.

## 5. Install and start Docker Desktop

**Where: setup wizard → Windows installer → Docker Desktop.**

Documents mode requires Docker. If it is missing, the wizard asks whether to install Docker Desktop through WinGet. Review what you are approving before continuing. You decide on and complete Docker's license terms, sign-in and initial setup yourself; the wizard does not accept them for you.

After installation, open Docker Desktop from the Windows Start menu and wait for its engine to start. If a restart is required, save your work and restart yourself, then reopen Docker Desktop and `Setup.cmd`.

**Expected:** Docker Desktop is open and its engine is running.

**If stuck:** If WinGet is unavailable or installation fails, follow [Docker's official WSL2 instructions](https://docs.docker.com/desktop/features/wsl/) to install it manually, then return to the wizard. Do not select full mode's broader host permissions just to avoid fixing Docker.

## 6. Enable Docker integration for Ubuntu

**Where: Docker Desktop → setup wizard.**

Open Docker Desktop **Settings** and confirm that the WSL2 engine is selected. Under **Resources → WSL Integration**, enable the Ubuntu distribution selected by the wizard. Use **Apply/Apply & restart** as shown, wait for Docker to be ready, then return to the wizard's check. If labels differ with your version, consult the [official integration guide](https://docs.docker.com/desktop/features/wsl/).

**Expected:** The wizard confirms Docker is accessible inside Ubuntu and continues to MCP installation.

**If stuck:** Opening Docker on Windows is not enough; enable integration for the same Ubuntu distribution the wizard selected. Once Docker is ready, press Enter at the wizard's prompt to retry, or Q to quit and run `Setup.cmd` later. A Docker failure is not treated as completion.

## 7. Wait for local MCP installation and verification

**Where: setup wizard.**

When the wizard asks for the **workspace**, first-time users can press Enter to keep `~/LocalWorkspace` under the Ubuntu home. This is where files are made available to the MCP server, not where keys belong. An existing setup reuses the saved workspace. For a custom workspace, a Windows absolute path is accepted, but do not choose an entire drive or a directory containing private settings.

The wizard then obtains pinned upstream source, prepares its runtime environment and Docker worker, and starts the local MCP server for tool discovery and test-file reads and writes. Initial downloads and the container build can take time. Wait for an explicit completion or error message.

**Success markers:**

```text
LOCAL_INSTALL_READY=PASS
CHATGPT_CONNECTION=NOT_CONFIGURED
```

These mean local installation and read/write checks passed; **they do not mean ChatGPT is connected yet**. Verification retains a unique test file in the workspace and writes a local report to state. A matching existing installation is reused and verified rather than changed to another mode or having its workspace emptied.

**If stuck:** Resolve the last prerequisite error shown, then reopen the wizard. If existing settings differ, do not delete state, the workspace or an older personal installation. Preserve the old setup and use the advanced flow for a separate installation, or report a redacted summary.

## 8. Connect ChatGPT and perform a real read/write test

Follow the [step-by-step ChatGPT connection guide](CHATGPT.en.md) to create your private tunnel, enter a restricted key, add the connection in ChatGPT and test `hello.txt`. If the wizard offers to open the connection, you can accept or double-click `Connect.cmd` later.

| Stage | What it establishes |
| --- | --- |
| `LOCAL_INSTALL_READY=PASS` | Local MCP installation and test reads/writes passed |
| `WINDOWS_TUNNEL_READY=PASS` | This tunnel process reports startup readiness |
| ChatGPT reads the test content and you confirm its reply file | This actual ChatGPT tool path completed a read and write |

The setup wizard itself does not send model-inference API requests. This does not mean OpenAI accounts, tunnels, ChatGPT usage or Docker licensing are always free. Availability, quotas and terms depend on the services and your account settings.

## Daily use and file locations

- Start Docker Desktop, double-click `Connect.cmd`, and keep the connection window open while using it. Normal use does not require reinstalling or creating a new key.
- To stop, press **Ctrl+C** in the connection window and wait for cleanup. Use `Status.cmd` to inspect status.
- The default workspace is `LocalWorkspace` under your Ubuntu home. In Windows File Explorer, open **Linux → the Ubuntu used during setup → home → your Linux user directory → LocalWorkspace**. If you chose another workspace, follow the installation output and saved settings.
- Do not put state, runtime keys or raw logs in the workspace, GitHub or chat. See [TESTING.en.md](TESTING.en.md) for issue reports.

For a custom distribution, workspace or full mode, read [Advanced installation in the README](../README.en.md#advanced-installation). Advanced users can run the following in Windows PowerShell opened in the project directory. It checks without writing, installing, downloading or starting a stopped WSL distribution, and reports `SETUP_CHECK=PASS` or `SETUP_CHECK=NEEDS_ACTION`. Beginners do not need it for installation.

```powershell
.\Setup.cmd -CheckOnly
```
