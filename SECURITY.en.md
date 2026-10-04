# Security

[繁體中文](SECURITY.md) | English

This project is currently a Windows/WSL community integration alpha. End-to-end validation of the general-purpose version on a clean machine has not yet been completed. This document describes the actual permission boundaries and known risks; it does not provide security certification or production guarantees.

## Modes and permissions

`documents` is the default mode. The Docker document worker's container restrictions apply only to the worker; files given to it may still be read, processed, and returned to the model as tool results.

`full` enables upstream host tools, which operate with the permissions of the WSL user who starts the process, including process execution, file reads and writes, and network access. The workspace is the default working directory, not an operating-system sandbox. Windows paths that WSL can mount (such as `/mnt`) may also be accessible to that account. Application path settings and model confirmation prompts do not provide permission isolation.

When `full` is selected, host tools retain these permissions even if Docker is also enabled. Choosing to skip the worker only disables Docker document processing capabilities; it does not reduce the host permissions of full mode.

Start with a dedicated test workspace containing no sensitive data, run as a regular user, and expose only the data you actually intend to provide to the tools. Do not treat documents, programs, or prompts from unknown sources as authorization to take action.

## Keys and local state

- Each user uses their own private tunnel, with the runtime key restricted to **Tunnels Read + Use**. Consider the account permissions used to create or manage tunnels separately from the runtime key.
- Enter keys only through the local hidden-input prompt. Do not put them in shell command lines, chats, issues, PRs, screenshots, documentation, or diagnostic logs.
- Private WSL state is stored at `~/.local/state/local-workspace-mcp-windows` and should be kept on the Linux filesystem with private directory and file permissions. Windows settings are stored at `%LOCALAPPDATA%\LocalWorkspaceMCPWindows\settings.json`.
- Restrictive permissions cannot prevent the same OS account, an administrator, or a process that has gained control of that account from reading the data. Also consider backups, synchronization, and terminal recordings.
- `full` host tools run under the same account, so these file permissions do not isolate the runtime key from full tools. Do not treat full mode as a sandbox for confidentiality.
- A string format check cannot prove that an API key actually has only the required permissions. Verify its permissions yourself in the Platform.

If a key is exposed, immediately revoke it in the Platform, stop the local connection, create a new key with the minimum required permissions, and review the relevant account activity. Do not send the old key to the maintainers.

## Dependencies and downloads

Upstream source is pinned to `ba42837e7aa54cd265e62023e5079f0e4affdf84`, and tunnel-client is pinned to the official `v0.0.15` release. Pinning versions helps reproducibility and review, but does not mean they are free of vulnerabilities. Installation still downloads third-party source code, packages, and container content required by the selected mode; this repository does not include third-party binaries.

Upstream [PR #4](https://github.com/arumwu/local-workspace-mcp/pull/4) reported 7 existing npm audit findings (2 moderate, 5 high), including `braces`, for which no patched version was available at the time. These are known inherited risks. This integration does not claim to fix these dependencies and does not independently alter the upstream lockfile. Audit counts and exploitability change with packages and vulnerability databases. Before production deployment, recheck upstream, security advisories, and the code paths actually used.

## Connections and data

Private tunnels send MCP requests and results through OpenAI. Keeping the server local does not mean all processing occurs locally. Understand your account and workspace data policies before providing files.

Publishing the source code does not create a common tunnel, shared key, or public MCP service for users. This project does not automatically change firewall settings, elevate privileges, enable startup at boot, or register a client. To stop a connection normally, use Ctrl+C and check its status.

## Reporting security issues

First check whether **Security → Advisories → Report a vulnerability** is available on this repository's GitHub page. If enabled, use private reporting first. If unavailable, open an issue without vulnerability details or sensitive data, asking the maintainers to provide a private reporting channel. Do not assume that a public issue is private.

Reports may include the affected version, mode, minimal reproduction steps, and a de-identified error summary. Remove keys, tunnel IDs, organization/workspace IDs, account names, hostnames, and private file paths and contents. For issues involving upstream, also follow upstream's reporting process.

This project does not commit to response or fix deadlines. The local integration, upstream MCP, tunnel-client, and OpenAI services are maintained by different parties.
