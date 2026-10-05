# 逐步連接 ChatGPT

繁體中文 | [English](CHATGPT.en.md)

先完成 [從零開始安裝](INSTALL.md)，再做這一頁。本指南使用每位使用者自己的 **Secure MCP Tunnel**，不共用作者的帳號、tunnel 或 key。原始碼可以公開，實際 MCP 仍在你的 WSL 中執行。這個設定不會發佈公開 plugin，也不包含代管服務。

官方操作頁面會更新；以下於 2026-10-05 依 [Secure MCP Tunnel](https://developers.openai.com/api/docs/guides/secure-mcp-tunnels) 與 [Connect and test your plugin](https://developers.openai.com/plugins/deploy/connect-chatgpt) 核對。功能可用性由帳號與工作區政策決定，安裝程式不會自動取得帳號權限，也不承諾免費 API 用量或無限額度。

## 1. 先完成本機安裝

**操作位置：Windows 安裝精靈。**

`Setup.cmd` 完成後應顯示：

```text
LOCAL_INSTALL_READY=PASS
CHATGPT_CONNECTION=NOT_CONFIGURED
```

第一行代表本機安裝與讀寫檢查通過，第二行提醒你還要設定 ChatGPT。預設 documents 模式需要 Docker Desktop 持續執行，並已啟用正確 Ubuntu 的 WSL 整合。先使用沒有敏感資料的測試 workspace；full 的權限見 [SECURITY.md](../SECURITY.md)。

**卡住時：** 尚未看到本機成功標記，回到 [安裝指南](INSTALL.md) 的對應階段。原本個人 Windows／WSL 的實際連線及讀寫已成功；新精靈與通用版本的 ChatGPT Desktop 乾淨環境端到端驗證仍未完成，見 [測試狀態](TESTING.md)。

## 2. 建立自己的 tunnel 與 runtime key

**操作位置：瀏覽器中的 OpenAI Platform。**

1. 登入 [Platform 的 Tunnel 設定](https://platform.openai.com/settings/organization/tunnels)，確認選取的是你要使用的 Platform organization。
2. 建立自己的私人 tunnel，取一個容易辨識的名稱。確認它關聯到要使用的 ChatGPT workspace，不能只關聯 Platform organization。
3. 保存該頁提供的 **tunnel ID**，供下一步在本機使用；不要貼進公開 issue 或對話。
4. 依同一個 Platform organization 的金鑰與權限設定建立 runtime API key，限制為 **Tunnels Read + Use**。建立／管理 tunnel 的帳號需 **Tunnels Read + Manage**，與 runtime key 的執行權限不同。若看不到相關權限，依管理員／帳號流程取得權限，不要改用管理員 key。

**應該得到：** 自己的 tunnel ID 與受限制 runtime key。程式無法僅憑 key 的外觀驗證它的實際權限。權限細節見 [官方說明](https://developers.openai.com/api/docs/guides/secure-mcp-tunnels#permissions-and-access)。

**卡住時：** Platform 顯示沒有 Tunnel 存取權限時，先確認 organization，再由該 organization 管理員處理。ChatGPT developer mode 是另一個工作區權限，建立 tunnel 不代表它已啟用。

**不要把 key 貼進 ChatGPT、Codex、GitHub、命令列參數、截圖或任何紀錄。** 下一步只在本機隱藏輸入提示中輸入。這個 key 與 Ubuntu 密碼不同。

## 3. 啟動連線

**操作位置：Windows 解壓資料夾 → Connect 視窗。**

1. 確認 Docker Desktop 已啟動。
2. 雙擊 `Connect.cmd`；若精靈已替你開啟該連線視窗，繼續使用它，不必再開一次。
3. 第一次看到 tunnel ID 提示時，輸入上一步自己的 ID。
4. 看到 `Runtime key (hidden)` 提示時，貼上 runtime key 並按 Enter。畫面不回顯 key 是正常現象。
5. 等待官方程式下載／檢查與連線啟動，保持視窗開啟。

**應該看到：**

```text
WINDOWS_TUNNEL_READY=PASS
```

這是 tunnel 程序的啟動就緒標記，仍需完成後面的 ChatGPT 工具測試。連線使用 WSL home 下的私密狀態目錄；設定由本整合腳本產生，官方 `v0.0.15` 完整 CLI 僅執行 `doctor`，常駐程序使用 runtime-only 執行檔。

後續正常啟動不必每次更換 key。需要換 key 時使用 `Connect.cmd -ReplaceKey`，再於隱藏提示輸入新的限制權限 key。`-TunnelId` 可明確指定你自己的 tunnel ID，但它不接受 API key。

**卡住時：** 確認 tunnel ID、key 權限及網路，但不要把 key 貼給別人查錯。另開 `Status.cmd` 可查看本機狀態。若提示已有連線，使用原本視窗，或先在原視窗按 Ctrl+C 正常停止再重開。

## 4. 在 ChatGPT 建立私人連線

**操作位置：瀏覽器或支援此功能的 ChatGPT 介面。** 依 [官方連線流程](https://developers.openai.com/plugins/deploy/connect-chatgpt#add-the-mcp-server)：

1. 在 Settings → Security and login 啟用 Developer mode；若沒有此選項，先確認帳號及管理員政策。
2. 前往 [ChatGPT Plugins](https://chatgpt.com/plugins)，按加號建立連線，填寫你能辨識的名稱與說明，例如 `Local Workspace Windows`。
3. 在 Connection 選 **Tunnel**，選取自己的 tunnel 或填入自己的 tunnel ID。
4. 建立後檢查探索到的工具，確認與安裝模式相符。
5. 開啟新對話，從工具選單選用該連線，再完成下一節的讀寫測試。

**應該看到：** 連線建立成功且能探索工具。

**卡住時：** 找不到 tunnel，先查 ChatGPT workspace 的關聯與操作者的 Tunnels Read + Use 權限。能看到 tunnel 但無法探索工具，確認 `Connect.cmd` 視窗仍在執行。

不要把本機檔案路徑或 GitHub 專案網址填成公開 MCP server URL。此專案提供私人 tunnel 流程；[官方說明](https://developers.openai.com/api/docs/guides/secure-mcp-tunnels) 將私人測試連線與公開 plugin submission 分開處理。

## 5. 用 hello.txt 確認真的連得上

**操作位置：Windows 檔案總管／記事本 → ChatGPT → 回到檔案總管。**

1. 開啟 workspace。預設可在檔案總管依序開啟 **Linux → 安裝時使用的 Ubuntu → home → 自己的 Linux 使用者目錄 → LocalWorkspace**。若你指定其他 workspace，使用那個資料夾。
2. 新增文字檔 `hello.txt`，以記事本寫入下列文字並儲存。確認檔名沒有變成 `hello.txt.txt`。若原本已有同名檔，另取檔名並同步修改下面的請求，不要覆蓋。

```text
Hello from my Windows workspace.
```

3. 在已選用這個 MCP 連線的新 ChatGPT 對話中輸入：

> 請使用剛加入的 Local Workspace 連線讀取 workspace 裡的 hello.txt，逐字回報檔案內容。

4. 確認對話實際使用連線工具，回傳內容與上面相同。接著明確授權一次新增檔案：

> 請在同一個 workspace 新建 hello-reply.txt，內容為「Read/write test passed.」。如果檔案已存在，請停止，不要覆蓋。

5. 回到檔案總管，確認 `hello-reply.txt` 實際存在，內容為 `Read/write test passed.`。

**成功代表：** 這次 ChatGPT 到你這台電腦的工具路徑已完成實際讀寫。只有模型說「完成」，或只有 tunnel 就緒標記，都還不算這項測試通過。這個文字檔測試也不能替代 Docker 文件產出的驗收。

**卡住時：** 核對 workspace、檔名與新對話，確認已選用連線工具。找不到檔案時先在本機核對位置，不要授權搜尋整台電腦。

## 6. 日後啟動、停止與更換 key

- 每次使用先啟動 Docker Desktop，再雙擊 `Connect.cmd`，保持視窗開啟。正常啟動會重用已保存的設定與 key。
- 另開 `Status.cmd` 可查看本機健康／就緒狀態，不會替你完成 ChatGPT 工具呼叫。
- 停止時在 Connect 視窗按 **Ctrl+C**，等待清理完成。重新開機後需自行再啟動，沒有新增開機自啟。
- 若 key 已外洩，先在 Platform 撤銷它，再建立受限制的新 key。只有更換 key 時才需要以下進階操作：在**專案資料夾中的 Windows PowerShell** 執行下方指令，再於隱藏提示輸入新 key。

```powershell
.\Connect.cmd -ReplaceKey
```

## 排除問題與回報

| 現象 | 先檢查 |
| --- | --- |
| WSL／Ubuntu 無法啟動 | 已完成 Ubuntu 首次設定，選到正確發行版與 Linux 使用者 |
| documents 安裝或 worker 失敗 | Docker 已啟動，該 Ubuntu 已啟用 WSL 整合 |
| ChatGPT 找不到 tunnel | 目標 workspace 的關聯，以及操作者的 Tunnels Read + Use 權限 |
| 有 tunnel 但無法探索工具 | 連線視窗仍在執行，`Status.cmd` 與 `Verify.cmd` 的結果 |
| 工具清單與新模式不同 | 重新啟動本機連線，在 ChatGPT Refresh 工具後另開新對話 |

請只分享去識別化的錯誤摘要。不要上傳整個 settings、state 或原始 log。若要回報問題，依 [測試與回報方式](TESTING.md) 提供可重現資訊。
