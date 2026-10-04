# Connecting to ChatGPT

[繁體中文](CHATGPT.md) | English

This guide uses each user's own **Secure MCP Tunnel**. The source code can be public while the actual MCP server runs in your WSL environment. This setup does not publish a public plugin or include a hosted service.

Official product pages change. These instructions were checked on 2026-10-04 against [Secure MCP Tunnel](https://developers.openai.com/api/docs/guides/secure-mcp-tunnels) and [Connect and test your plugin](https://developers.openai.com/plugins/deploy/connect-chatgpt). Availability depends on account and workspace policies.

## 1. Complete the local installation

Run `Install.cmd` as described in the [README](../README.en.md). Start with a workspace containing no sensitive data. The default documents mode requires Docker; see [SECURITY.en.md](../SECURITY.en.md) for full-mode host permissions.

This generalized version has not completed end-to-end verification in ChatGPT Desktop. The following workflow still needs real-world testing and is not a guarantee that it has passed on every Windows computer.

## 2. Create your own tunnel and runtime key

Create a private tunnel in the OpenAI Platform tunnel settings and associate it with the correct Platform organization and target ChatGPT workspace. Creating or managing a tunnel requires **Tunnels Read + Manage**; the runtime key only needs **Tunnels Read + Use**. ChatGPT developer-mode access is controlled separately by the workspace. See the [official tunnel permissions documentation](https://developers.openai.com/api/docs/guides/secure-mcp-tunnels#permissions-and-access) for roles and associations.

Keep your own tunnel ID and create a runtime key with the minimum required permissions. Do not use an administrative key or someone else's tunnel or key. The program cannot determine a key's actual permissions from its format alone.

**Do not paste the key into ChatGPT, Codex, GitHub, command-line arguments or logs.** Enter it only at the local hidden-input prompt in the next step.

## 3. Start the connection

Run `Connect.cmd`, or run the following from the project directory:

```powershell
.\scripts\windows.ps1 -Action Connect
```

Follow the local prompts to enter your own tunnel ID and runtime key. The connection uses private state under your WSL home and reuses saved settings on subsequent runs. The integration generates the configuration; the official `v0.0.15` full CLI only runs `doctor`, while the persistent process uses the runtime-only executable.

You do not need a new key for every normal launch. To replace it, run `Connect.cmd -ReplaceKey`, then enter a new restricted key at the hidden prompt. `-TunnelId` explicitly selects your own tunnel ID; it does not accept an API key.

Keep the connection window open. Run `Status.cmd` in another window to check local status. A healthy status still requires an actual ChatGPT tool call to prove the complete path works. Stop with **Ctrl+C** and wait for cleanup to finish.

## 4. Create a private connection in ChatGPT

Follow the [official connection flow](https://developers.openai.com/plugins/deploy/connect-chatgpt#add-the-mcp-server):

1. Enable Developer mode under Settings → Security and login. If the option is unavailable, check account and administrator policies first.
2. Open Plugins and select the plus button to create a connection. Choose a recognizable name and description.
3. Under Connection, choose **Tunnel**, then select your own tunnel or enter your own tunnel ID.
4. After creating the connection, review the discovered tools and confirm that they match the installed mode.
5. Start a new conversation, select the connection, and ask the model to read a test text file you placed in the workspace.

Do not enter a local file path or the GitHub project URL as a public MCP server URL. This project uses private tunnels; the [official documentation](https://developers.openai.com/api/docs/guides/secure-mcp-tunnels) distinguishes private testing connections from public plugin submission.

## Troubleshooting

| Symptom | Check first |
| --- | --- |
| WSL/Ubuntu does not start | Ubuntu first-run setup is complete, and the selected distribution and Linux user are correct |
| Documents installation or worker fails | Docker is running and WSL integration is enabled for that Ubuntu distribution |
| ChatGPT cannot find the tunnel | The target workspace association and the operator's Tunnels Read + Use permissions |
| Tunnel exists but tool discovery fails | The connection window is still running, plus the results of `Status.cmd` and `Verify.cmd` |
| Tool list does not match the new mode | Restart the local connection, refresh the tools in ChatGPT, then start a new conversation |

Share only redacted error summaries. Do not upload complete settings, state or raw logs. Follow [Testing and issue reports](TESTING.en.md) when providing reproducible information.
