# 連接 ChatGPT

繁體中文 | [English](CHATGPT.en.md)

本指南使用每位使用者自己的 **Secure MCP Tunnel**。原始碼可以公開，實際 MCP 仍在你的 WSL 中執行。這個設定不會發佈公開 plugin，也不包含代管服務。

官方操作頁面會更新；以下於 2026-10-04 依 [Secure MCP Tunnel](https://developers.openai.com/api/docs/guides/secure-mcp-tunnels) 與 [Connect and test your plugin](https://developers.openai.com/plugins/deploy/connect-chatgpt) 核對。功能可用性由帳號與工作區政策決定。

## 1. 先完成本機安裝

依 [README](../README.md) 執行 `Install.cmd`。先使用沒有敏感資料的測試 workspace。預設 documents 模式需要可用的 Docker；full 模式的主機權限見 [SECURITY.md](../SECURITY.md)。

此通用版本尚未完成 ChatGPT Desktop 端到端驗證，以下也是待實測的操作流程，不能當成所有 Windows 電腦已通過的保證。

## 2. 建立自己的 tunnel 與 runtime key

在 OpenAI Platform 的 tunnel 設定中建立私人 tunnel，確認它關聯到正確的 Platform organization 及要使用的 ChatGPT workspace。建立／管理需要 **Tunnels Read + Manage**；執行連線所用的 key 只需 **Tunnels Read + Use**。ChatGPT developer mode 的權限另由工作區控制。這些角色與關聯條件見 [官方 tunnel 權限說明](https://developers.openai.com/api/docs/guides/secure-mcp-tunnels#permissions-and-access)。

保留自己的 tunnel ID，建立最小權限 runtime key。不要使用管理員 key，也不要使用其他人的 tunnel 或金鑰。程式無法僅憑 key 的外觀驗證它的實際權限。

**不要把 key 貼進 ChatGPT、Codex、GitHub、命令列參數或任何紀錄。** 下一步只在本機隱藏輸入提示中輸入。

## 3. 啟動連線

執行 `Connect.cmd`，或在專案資料夾執行：

```powershell
.\scripts\windows.ps1 -Action Connect
```

依本機提示輸入自己的 tunnel ID 與 runtime key。連線會使用 WSL home 下的私密狀態目錄；已保存的設定供後續使用。設定由本整合腳本產生，官方 `v0.0.15` 完整 CLI 僅執行 `doctor`，常駐程序使用 runtime-only 執行檔。

後續正常啟動不必每次更換 key。需要換 key 時使用 `Connect.cmd -ReplaceKey`，再於隱藏提示輸入新的限制權限 key。`-TunnelId` 可明確指定你自己的 tunnel ID，但它不接受 API key。

保持連線視窗開啟。另開視窗執行 `Status.cmd` 查看本機狀態；狀態正常仍需一次實際 ChatGPT 工具呼叫，才能證明整條路徑可用。用 **Ctrl+C** 停止連線並等待清理完成。

## 4. 在 ChatGPT 建立私人連線

依 [官方連線流程](https://developers.openai.com/plugins/deploy/connect-chatgpt#add-the-mcp-server)：

1. 在 Settings → Security and login 啟用 Developer mode；若沒有此選項，先確認帳號及管理員政策。
2. 前往 Plugins，按加號建立連線，填寫你能辨識的名稱與說明。
3. 在 Connection 選 **Tunnel**，選取自己的 tunnel 或填入自己的 tunnel ID。
4. 建立後檢查探索到的工具，確認與安裝模式相符。
5. 開啟新對話並選用該連線，請模型讀取你預先放入 workspace 的測試文字檔。

不要把本機檔案路徑或 GitHub 專案網址填成公開 MCP server URL。此專案提供私人 tunnel 流程；[官方說明](https://developers.openai.com/api/docs/guides/secure-mcp-tunnels) 將私人測試連線與公開 plugin submission 分開處理。

## 排除問題

| 現象 | 先檢查 |
| --- | --- |
| WSL／Ubuntu 無法啟動 | 已完成 Ubuntu 首次設定，選到正確發行版與 Linux 使用者 |
| documents 安裝或 worker 失敗 | Docker 已啟動，該 Ubuntu 已啟用 WSL 整合 |
| ChatGPT 找不到 tunnel | 目標 workspace 的關聯，以及操作者的 Tunnels Read + Use 權限 |
| 有 tunnel 但無法探索工具 | 連線視窗仍在執行，`Status.cmd` 與 `Verify.cmd` 的結果 |
| 工具清單與新模式不同 | 重新啟動本機連線，在 ChatGPT Refresh 工具後另開新對話 |

請只分享去識別化的錯誤摘要。不要上傳整個 settings、state 或原始 log。若要回報問題，依 [測試與回報方式](TESTING.md) 提供可重現資訊。
