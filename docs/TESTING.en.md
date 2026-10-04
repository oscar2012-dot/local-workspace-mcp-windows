# Testing status and acceptance checks

[繁體中文](TESTING.md) | English

## Current evidence

This is a generalized Windows/WSL integration alpha. An earlier single-computer prototype completed connection, tool-discovery and file read/write testing. It used machine-specific settings and the full-mode path with the Docker worker skipped, so it does not establish acceptance of this version or the default documents mode.

| Scope | Status |
| --- | --- |
| Earlier single-computer prototype | Completed end-to-end testing; not equivalent to this generalized version |
| Static and automated checks for the generalized installer | Refer to the CI and test output for the specific revision |
| Clean Windows x64 + WSL2 Ubuntu installation | End-to-end verification not completed |
| Generalized version's ChatGPT Desktop connection and actual tool calls | End-to-end verification not completed |
| Documents mode + Docker document-generation workflow | End-to-end verification not completed |
| Complete regression testing of full + Docker / full with worker skipped | End-to-end verification not completed |

Passing automated or mocked tests proves only the behavior they cover. It does not establish that WSL, Docker, networking, account authorization and ChatGPT UI integration all work together.

Historical initial-alpha checks (2026-10-04, before the bilingual documentation was added): 79 tests ran on Windows with Python 3.12; 72 passed and 7 were skipped because they required POSIX behavior or symbolic-link permissions. There were no failures. Python compilation, Windows PowerShell 5.1 syntax parsing, and privacy-rule scanning of the 21 source files staged at that time passed. This restricted environment could not start the Git Bash syntax check. Linux permissions, flock and Bash checks still need CI verification. CI is provided, but only actual run results count as passing.

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

1. Install WSL2/Ubuntu on Windows x64 and complete the Linux user's first-run setup. Record Windows, WSL, Ubuntu and PowerShell versions.
2. Start Docker, enable WSL integration for that Ubuntu distribution, and run the default `Install.cmd`. Confirm there is no automatic elevation, startup-at-login configuration, global policy change or client registration.
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
Action: Install | Connect | Status | Verify
Expected result:
Actual result (redacted):
Minimal reproduction using disposable files:
Checks completed / not completed:
```

Remove runtime keys, tunnel IDs, organization/workspace IDs, actual account and host names, private file paths and contents, and conversation URLs from public reports. Do not paste raw settings, environment variables, logs or support exports.
