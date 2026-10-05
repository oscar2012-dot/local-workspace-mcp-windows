# Testing status and acceptance checks

[繁體中文](TESTING.md) | English

## Current evidence

This is a Windows/WSL community integration alpha. Connection, tool discovery, and file read/write operations were tested on the maintainer's real Windows/WSL computer, not in a cloud simulation. That test used the earlier configuration and full mode with the Docker worker skipped. This remains valid real-machine evidence; the new guided installer's clean-computer flow and the default documents/Docker workflow require separate acceptance checks.

| Scope | Status |
| --- | --- |
| Maintainer's earlier Windows/WSL configuration | Real-machine connection, tool discovery, and file read/write testing completed |
| Static and automated checks for the generalized installer | Refer to the CI and test output for the specific revision |
| Clean Windows x64 + WSL2 Ubuntu installation | End-to-end verification not completed |
| Generalized version's ChatGPT Desktop connection and actual tool calls | End-to-end verification not completed |
| Documents mode + Docker document-generation workflow | End-to-end verification not completed |
| Complete regression testing of full + Docker / full with worker skipped | End-to-end verification not completed |

Passing automated or mocked tests proves only the behavior they cover. It does not establish that WSL, Docker, networking, account authorization and ChatGPT UI integration all work together.

The initial public source passed all four Windows/Ubuntu × Python 3.12/3.14 combinations in the [2026-10-04 CI run](https://github.com/oscar2012-dot/local-workspace-mcp-windows/actions/runs/37210176002). For the new wizard, inspect Actions for its specific commit; the initial result does not establish later revisions' results.

Historical initial-alpha checks (2026-10-04, before the bilingual documentation was added): 79 tests ran on Windows with Python 3.12; 72 passed and 7 were skipped because they required POSIX behavior or symbolic-link permissions. There were no failures. Python compilation, Windows PowerShell 5.1 syntax parsing, and privacy-rule scanning of the 21 source files staged at that time passed. This restricted environment could not start Git Bash; the subsequent CI run above covered Linux permissions, flock, and Bash checks.

## Guided installer checks without installation

Local wizard-update results (2026-10-05): Windows/Python 3.12 ran 122 tests, with 115 passing and 7 platform/permission-dependent skips, and no failures. Windows PowerShell 5.1 and PowerShell 7 each passed 23 offline wizard scenarios. Bash syntax checks passed. These checks did not actually install WSL/Docker or start a ChatGPT connection.

From Windows PowerShell in the project directory:

```powershell
.\Setup.cmd -Language en -CheckOnly
```

`SETUP_CHECK=PASS` means prerequisites passed inspection; `SETUP_CHECK=NEEDS_ACTION` means preparation is still needed. This mode does not download, install, save settings, or prompt for keys. If the selected WSL distribution is stopped, it asks you to open Ubuntu yourself and rerun the check instead of starting it. It is not an MCP or ChatGPT end-to-end check.

Maintainer offline regression tests do not perform real package installation or account authorization:

```powershell
python -m unittest discover -s tests -v
powershell.exe -NoProfile -ExecutionPolicy RemoteSigned -File .\tests\test_setup_windows.ps1
```

CI also parses all PowerShell scripts, checks both Bash entry points, and tests wizard behavior on Windows PowerShell 5.1 and PowerShell 7. Mock tests do not replace real UAC, restart, Ubuntu first-run, or WinGet/Docker UI acceptance checks.

## Quick local checks

After installation, run:

```powershell
.\scripts\windows.ps1 -Action Verify
.\scripts\windows.ps1 -Action Status
```

`Verify` checks the local installation, creates and retains a uniquely named workspace test file containing no sensitive data, and writes `verification.json` in the state directory. `Status` checks connection state. A disconnected result is expected before the connection has started. Do not switch to a more privileged mode just to make a check pass.

When checking third-party dependencies, preserve the upstream lockfile and record audit results in a separate test installation. See [SECURITY.en.md](../SECURITY.en.md) for known upstream npm audit risks; passing tests does not remove dependency risks.

## Public-source checks

Maintainers should review changes, add the intended public files to the Git staging area, and then run this from the project root:

```powershell
python scripts/check_public_source.py
```

The check examines staged blobs: the exact contents intended for the next commit. It does not scan the entire history. Its heuristic rules look for data that should not be published. Passing is not a security certification and does not replace manual review, history inspection or dedicated secret scanning. The public GitHub account `oscar2012-dot` is intentionally retained as the author's identity; that does not allow private names, email addresses, paths or connection data to be published.

## Clean-computer acceptance checklist

Use a disposable workspace for each case and record versions and results. The following is a plan for tests still to be performed, not a record of completed tests.

1. On a Windows x64 test machine without this integration, follow the [step-by-step guide](INSTALL.en.md) to download, unblock, extract, and double-click `Setup.cmd`. Test both languages and record Windows, WSL, Ubuntu, and PowerShell versions.
2. Follow the prompts to approve WSL installation, restart if required and reopen Setup, create the Ubuntu account, and approve prerequisite and Docker installation. Check that declining or cancelling stops safely; UAC/sudo appears only after consent. There must be no automatic reboot, login-startup setup, global policy change, or ChatGPT connection registration. After enabling Docker's WSL integration, confirm `LOCAL_INSTALL_READY=PASS` while ChatGPT is still reported as not configured.
3. Repeat installation with the same settings. Confirm existing user files and unrelated settings are preserved, errors are understandable, and no secrets are disclosed.
4. Test workspace paths containing spaces and Traditional Chinese characters, and distribution selection when more than one WSL distribution exists.
5. Run `Connect.cmd` with your own tunnel and restricted key. Confirm the key is not echoed, Windows settings contain no key, and private Linux file permissions are correct.
6. Complete local Status/Verify checks and ChatGPT tool discovery. Read a test file in a new conversation, explicitly authorize creation of another test file, and verify its contents locally.
7. Complete a Docker worker document task in documents mode. Verify the output opens correctly and is saved in the expected location; record how failing inputs are handled.
8. Stop with Ctrl+C and confirm the associated connection processes exit. Restart using saved settings. A duplicate launch must not create an unintended second persistent connection.
9. Test Docker not running, missing prerequisites, invalid tunnel IDs, invalid keys, offline operation and download failures. Record only redacted summaries.
10. Explicitly select full mode in separate test settings, testing both with the worker enabled and with it skipped. Confirm host tools appear only in the mode whose permissions were accepted, and that skipping the worker does not claim Docker document capabilities are available.

Record ChatGPT Desktop, browser use and different account/workspace policies separately. Results from one do not establish results for the others.

## Issue report format

For ordinary issues, provide the following information. For security issues, follow the [vulnerability reporting process](../SECURITY.en.md#reporting-security-issues).

```text
Integration commit or release:
Windows / WSL / Ubuntu / PowerShell versions:
Mode: documents | full
Docker worker: enabled | skipped
Docker version, if applicable:
Client surface: ChatGPT Desktop | browser | other
Action: Setup | CheckOnly | Install | Connect | Status | Verify
Expected result:
Actual result (redacted):
Minimal reproduction using disposable files:
Checks completed / not completed:
```

Remove runtime keys, tunnel IDs, organization/workspace IDs, actual account and host names, private file paths and contents, and conversation URLs from public reports. Do not paste raw settings, environment variables, logs or support exports.
