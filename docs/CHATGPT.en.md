# Connecting to ChatGPT step by step

[繁體中文](CHATGPT.md) | English

Complete [Installation from scratch](INSTALL.en.md) first. This guide uses each user's own **Secure MCP Tunnel**; do not share the author's account, tunnel or key. The source code can be public while the actual MCP server runs in your WSL environment. This setup does not publish a public plugin or include a hosted service.

Official product pages change. These instructions were checked on 2026-10-05 against [Secure MCP Tunnel](https://developers.openai.com/api/docs/guides/secure-mcp-tunnels) and [Connect and test your plugin](https://developers.openai.com/plugins/deploy/connect-chatgpt). Availability depends on account and workspace policies. Installation does not grant account permissions or promise free API usage or unlimited quotas.

## 1. Complete the local installation

**Where: the Windows setup wizard.**

After `Setup.cmd` finishes, it should show:

```text
LOCAL_INSTALL_READY=PASS
CHATGPT_CONNECTION=NOT_CONFIGURED
```

The first line confirms local installation and read/write checks. The second reminds you to configure ChatGPT next. Default documents mode requires Docker Desktop to remain running, with WSL integration enabled for the correct Ubuntu distribution. Start with a workspace containing no sensitive data; see [SECURITY.en.md](../SECURITY.en.md) for full-mode permissions.

**If stuck:** If the local success marker has not appeared, return to the relevant stage of the [installation guide](INSTALL.en.md). The original personal Windows/WSL connection and real reads/writes worked; the new wizard and generalized ChatGPT Desktop flow still lack clean-environment end-to-end verification. See [testing status](TESTING.en.md).

## 2. Create your own tunnel and runtime key

**Where: OpenAI Platform in your browser.**

1. Sign in to [Platform Tunnel settings](https://platform.openai.com/settings/organization/tunnels) and confirm that the intended Platform organization is selected.
2. Create your own private tunnel with a recognizable name. Associate it with the ChatGPT workspace you will use, not only the Platform organization.
3. Save the **tunnel ID** provided on that page for local use in the next step. Do not paste it into a public issue or conversation.
4. Create a runtime API key through the same Platform organization's key and permission settings, restricted to **Tunnels Read + Use**. The account creating/managing tunnels needs **Tunnels Read + Manage**, which differs from the runtime key's execution permissions. If the relevant permissions are unavailable, follow the administrator/account process rather than using an administrative key.

**Expected:** Your own tunnel ID and restricted runtime key. The program cannot determine a key's actual permissions from its format alone. See the [official permissions documentation](https://developers.openai.com/api/docs/guides/secure-mcp-tunnels#permissions-and-access).

**If stuck:** If Platform reports missing Tunnel access, check the organization and ask its administrator to handle permissions. ChatGPT developer mode is a separate workspace permission; creating a tunnel does not enable it.

**Do not paste the key into ChatGPT, Codex, GitHub, command-line arguments, screenshots or logs.** Enter it only at the local hidden-input prompt in the next step. This key is different from your Ubuntu password.

## 3. Start the connection

**Where: the extracted Windows project directory → Connect window.**

1. Confirm Docker Desktop is running.
2. Double-click `Connect.cmd`. If the wizard already opened that connection window, keep using it rather than opening a second copy.
3. At the first tunnel ID prompt, enter your own ID from the preceding step.
4. At `Runtime key (hidden)`, paste the runtime key and press Enter. The key not appearing on screen is normal.
5. Wait for official-client downloads/checks and connection startup, keeping the window open.

**Expected:**

```text
WINDOWS_TUNNEL_READY=PASS
```

This is the tunnel process's startup-readiness marker; the ChatGPT tool test below is still required. The connection uses private state under your WSL home. The integration generates the configuration; the official `v0.0.15` full CLI only runs `doctor`, while the persistent process uses the runtime-only executable.

You do not need a new key for every normal launch. To replace it, run `Connect.cmd -ReplaceKey`, then enter a new restricted key at the hidden prompt. `-TunnelId` explicitly selects your own tunnel ID; it does not accept an API key.

**If stuck:** Check the tunnel ID, key permissions and connectivity without sharing the key. Open `Status.cmd` separately to inspect local status. If a connection is already running, use its existing window or stop it normally with Ctrl+C before restarting.

## 4. Create a private connection in ChatGPT

**Where: your browser or a ChatGPT interface that supports this feature.** Follow the [official connection flow](https://developers.openai.com/plugins/deploy/connect-chatgpt#add-the-mcp-server):

1. Enable Developer mode under Settings → Security and login. If the option is unavailable, check account and administrator policies first.
2. Open [ChatGPT Plugins](https://chatgpt.com/plugins) and select the plus button to create a connection. Choose a recognizable name and description, such as `Local Workspace Windows`.
3. Under Connection, choose **Tunnel**, then select your own tunnel or enter your own tunnel ID.
4. After creating the connection, review the discovered tools and confirm that they match the installed mode.
5. Start a new conversation, select the connection from the tools menu, and complete the read/write test below.

**Expected:** The connection is created and its tools can be discovered.

**If stuck:** If the tunnel is missing, check the ChatGPT workspace association and the operator's Tunnels Read + Use permissions. If the tunnel is visible but tool discovery fails, confirm that the `Connect.cmd` window is still running.

Do not enter a local file path or the GitHub project URL as a public MCP server URL. This project uses private tunnels; the [official documentation](https://developers.openai.com/api/docs/guides/secure-mcp-tunnels) distinguishes private testing connections from public plugin submission.

## 5. Confirm the connection with hello.txt

**Where: Windows File Explorer/Notepad → ChatGPT → back to File Explorer.**

1. Open the workspace. For the default location, navigate in File Explorer through **Linux → the Ubuntu used during installation → home → your Linux user directory → LocalWorkspace**. If you selected another workspace, use that directory.
2. Create `hello.txt`, enter the following in Notepad and save. Check that its name is not `hello.txt.txt`. If it already exists, choose another name and update the prompts below rather than overwriting it.

```text
Hello from my Windows workspace.
```

3. In a new ChatGPT conversation with this MCP connection selected, enter:

> Use the Local Workspace connection I just added to read hello.txt in the workspace and report its exact contents.

4. Confirm the conversation actually uses the connection's tools and returns the text above. Then explicitly authorize one file creation:

> Create hello-reply.txt in the same workspace containing "Read/write test passed." If the file already exists, stop and do not overwrite it.

5. Return to File Explorer and confirm that `hello-reply.txt` actually exists and contains `Read/write test passed.`.

**Success means:** This actual ChatGPT-to-computer tool path completed a read and write. A model merely saying "done," or a tunnel-readiness marker alone, does not pass this test. This text-file test does not replace acceptance testing of Docker document generation either.

**If stuck:** Check the workspace, filename and new conversation, and confirm that the connection's tools are selected. For a missing file, check its location locally first rather than authorizing a search of the entire computer.

## 6. Daily startup, shutdown and key replacement

- Start Docker Desktop, double-click `Connect.cmd`, and leave the window open. Normal launches reuse saved settings and the key.
- Open `Status.cmd` separately to inspect local health/readiness. It does not perform a ChatGPT tool call for you.
- Stop by pressing **Ctrl+C** in the Connect window and waiting for cleanup. Start it yourself again after a reboot; no startup task is added.
- If the key is exposed, revoke it in Platform first and create a new restricted key. Only key replacement requires this advanced step: open **Windows PowerShell in the project directory**, run the following, then enter the new key at the hidden prompt.

```powershell
.\Connect.cmd -ReplaceKey
```

## Troubleshooting and reports

| Symptom | Check first |
| --- | --- |
| WSL/Ubuntu does not start | Ubuntu first-run setup is complete, and the selected distribution and Linux user are correct |
| Documents installation or worker fails | Docker is running and WSL integration is enabled for that Ubuntu distribution |
| ChatGPT cannot find the tunnel | The target workspace association and the operator's Tunnels Read + Use permissions |
| Tunnel exists but tool discovery fails | The connection window is still running, plus the results of `Status.cmd` and `Verify.cmd` |
| Tool list does not match the new mode | Restart the local connection, refresh the tools in ChatGPT, then start a new conversation |

Share only redacted error summaries. Do not upload complete settings, state or raw logs. Follow [Testing and issue reports](TESTING.en.md) when providing reproducible information.
