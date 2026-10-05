# Local Workspace MCP — Windows／WSL 社群整合版

繁體中文 | [English](README.en.md)

**第一次安裝： [下載 ZIP](https://github.com/oscar2012-dot/local-workspace-mcp-windows/archive/refs/heads/main.zip) → 解壓 → 雙擊 `Setup.cmd`。** 請照 [從零開始逐步安裝指南](docs/INSTALL.md) 操作；一般流程不用自行貼指令。

讓 Windows 使用者透過 WSL2 執行 [Local Workspace MCP](https://github.com/arumwu/local-workspace-mcp)，再用自己的 OpenAI 私人 tunnel 連接 ChatGPT。本專案由 [oscar2012-dot](https://github.com/oscar2012-dot) 維護安裝入口與連線整合；MCP 伺服器來自上游，並非本專案原創，也不是 OpenAI 官方產品。

**目前為社群整合 alpha。** 原本的個人 Windows／WSL 安裝已實際完成 tunnel 連線及檔案讀寫，這些使用經驗有效。新加入的通用安裝精靈仍未在乾淨電腦完成端到端測試；ChatGPT Desktop 與 Docker 文件流程也尚未完成這個版本的端到端驗證。請先用測試資料；詳細範圍見 [測試紀錄與驗收方式](docs/TESTING.md)。

## 支援範圍

- Windows x64、WSL2、Ubuntu；MCP 與 tunnel-client 在 Linux 內執行，沒有原生 Windows 後端。
- 預設 `documents` 模式，需要已啟動的 Docker 與該 Ubuntu 發行版的 WSL 整合。
- `full` 模式須明確接受風險；另可選擇略過 Docker worker。
- 每位使用者自行建立私人 tunnel 與限制為 **Tunnels Read + Use** 的 runtime API key。帳號、工作區政策與功能可用性仍依 OpenAI 規定。

| 模式 | 用途 | 權限重點 |
| --- | --- | --- |
| `documents`（預設） | 工作目錄檔案操作及 Docker 文件 worker | 文件 worker 有容器邊界，仍須保護其可讀取的資料 |
| `full` | 增加主機程序與其他上游 host tools | 以 WSL 使用者的作業系統權限執行；workspace 不是沙箱 |
| `full` 並略過 worker | 不使用 Docker 文件 worker 的完整主機工具 | 仍具有 full 權限；不能使用 Docker `run_python` |

Full 模式可能存取 WSL 中的其他路徑及 `/mnt` 下的 Windows 磁碟。即使同時啟用 Docker，容器限制也只適用於 worker，不會隔離主機工具。請先閱讀 [SECURITY.md](SECURITY.md)。

## 新手安裝與每日使用

1. [下載 ZIP](https://github.com/oscar2012-dot/local-workspace-mcp-windows/archive/refs/heads/main.zip)，確認來源並閱讀程式後，視需要在 ZIP 的「內容 → 解除封鎖」，再完整解壓。
2. 雙擊 `Setup.cmd`，選擇繁體中文或 English。精靈依序檢查 WSL／Ubuntu、Linux 工具與 Docker；需要安裝時會先詢問。Ubuntu 使用者設定、Docker 授權與 WSL 整合仍需你依畫面完成。
3. 等到 `LOCAL_INSTALL_READY=PASS`，再依 [ChatGPT 私人連線步驟](docs/CHATGPT.md) 建立自己的 tunnel，執行 `Connect.cmd` 並在本機隱藏提示輸入 key。
4. 看到 `WINDOWS_TUNNEL_READY=PASS` 後，在 ChatGPT 加入自己的 Tunnel 連線，完成 [hello.txt 讀寫測試](docs/CHATGPT.md#5-用-hellotxt-確認真的連得上)。每日只需執行 `Connect.cmd`；停止時按 **Ctrl+C**。

[完整安裝指南](docs/INSTALL.md) 包含每一步的預期結果與卡住時的處理。`Install.cmd` 不帶參數時也會開啟精靈。精靈目前只安裝預設 documents 模式，不會在 Docker 出錯時切換成 full。

安裝可能要求 Windows UAC、Ubuntu 的 sudo 密碼或重新開機，均依確認流程處理；不會自動重新開機。重新開機後再次雙擊 `Setup.cmd`，會重新檢查並略過已就緒的項目，沒有新增開機自啟工作。符合設定的既有安裝會驗證重用，不會覆蓋成另一種模式。

## 進階安裝

以下指令在**專案資料夾中的 Windows PowerShell** 執行。`Install.cmd` 帶參數，以及 `scripts/windows.ps1`，使用進階入口，必須先自行備妥前置條件：Ubuntu 24.04 以上、Python 3.12 以上、Git、uv、ripgrep（`rg`）與可用的 Docker；full 另需 Node.js 20.9 以上與 npm。這個進階入口不會自動安裝全域套件。

官方參考：[Microsoft WSL](https://learn.microsoft.com/en-us/windows/wsl/install)、[Docker WSL2 整合](https://docs.docker.com/desktop/features/wsl/)、[uv 安裝](https://docs.astral.sh/uv/getting-started/installation/)。

直接呼叫各操作：

```powershell
.\scripts\windows.ps1 -Action Install
.\scripts\windows.ps1 -Action Connect
.\scripts\windows.ps1 -Action Status
.\scripts\windows.ps1 -Action Verify
```

例如，指定一個已安裝的 Ubuntu 與 Windows 工作目錄：

```powershell
.\Install.cmd -Distro Ubuntu-24.04 -Workspace "C:\MCP\Workspace"
```

請用 `wsl --list --verbose` 查看自己實際的發行版名稱。workspace 也可指定 WSL 絕對路徑；未指定時使用 WSL 的 `~/LocalWorkspace`。只有在已閱讀安全說明並接受主機權限後，才改用 full：

```powershell
.\Install.cmd -Mode full -AcceptFullPermissions -State "~/.local/state/local-workspace-mcp-windows-full" -Workspace "~/LocalWorkspaceFull"
```

若同時需要略過 Docker 文件 worker，另加 `-SkipWorker`：

```powershell
.\Install.cmd -Mode full -AcceptFullPermissions -SkipWorker -State "~/.local/state/local-workspace-mcp-windows-full-no-worker" -Workspace "~/LocalWorkspaceFullNoWorker"
```

`-SkipWorker` 不適用於 documents，也不是安裝失敗時自動採用的替代方案。既有 state 的模式與 workspace 不會被直接改寫；以上 full 範例使用獨立 state 與 workspace。安裝成功會保存最後一次的本機選項；再次執行 full 安裝仍須明確傳入 `-Mode full -AcceptFullPermissions`（及原本的 `-SkipWorker`）。

尚未安裝 WSL 時，可明確執行 `Install.cmd -InstallWSL -Distro Ubuntu-24.04` 要求呼叫 Windows 的 WSL 安裝程序；這一步不會自動提升權限，完成後仍須依 Windows 提示與 Ubuntu 首次設定再重跑安裝。

`Verify` 會在 workspace 建立並保留唯一的無敏感資料測試檔，以及在 state 寫入驗證結果；它不等於 ChatGPT 或 Docker 文件流程已端到端通過。每日使用時執行 `Connect.cmd`；停止連線請按 **Ctrl+C**，讓程序完成清理。不要以直接關閉終端視窗代替正常停止。

精靈只會在你同意對應安裝步驟後請求所需權限；不會變更全域 PowerShell execution policy、設定開機自啟或替任何 MCP client 註冊連線。OpenAI 帳號、tunnel 與 ChatGPT 連線仍由你建立。

若從 GitHub 下載 ZIP 後出現「未經數位簽署」或腳本遭封鎖，可能是 Windows 保留了下載來源標記（Mark-of-the-Web）。請先確認來源並檢閱程式，再於該 ZIP 的「內容／Properties → 解除封鎖／Unblock」解除封鎖，重新解壓到新的資料夾；也可只處理已檢閱的特定腳本。啟動器採用僅限當次程序的 `RemoteSigned`，不會自動解除封鎖。請勿為此將全域執行原則改為 `Unrestricted` 或 `Bypass`；公司裝置仍應遵守管理原則。

## 設定放在哪裡

| 位置 | 內容 |
| --- | --- |
| `%LOCALAPPDATA%\LocalWorkspaceMCPWindows\settings.json` | Windows 端本機設定 |
| `~/.local/state/local-workspace-mcp-windows`（WSL） | 安裝、連線與執行狀態；包括私密 runtime key |
| `~/.local/share/local-workspace-mcp-windows/upstream/`（WSL） | 固定 revision 的上游原始碼 |
| 安裝時選擇的 workspace | 使用者交給 MCP 處理的檔案 |

可用 `-State` 指定 WSL home 下的其他專用目錄（絕對路徑或 `~/` 路徑），私密狀態必須留在 Linux 檔案系統，不能位於 workspace、原始碼目錄或 `/mnt`。請勿將設定、WSL state、金鑰、實際 tunnel ID 或原始診斷輸出提交至 GitHub。安裝目錄與連線狀態留在本機，不會因為原始碼公開而成為公開服務。

## 固定版本與已知限制

- 上游來源固定於 [`ba42837e7aa54cd265e62023e5079f0e4affdf84`](https://github.com/arumwu/local-workspace-mcp/tree/ba42837e7aa54cd265e62023e5079f0e4affdf84)，保留其原始授權與 dependency lock。
- tunnel-client 使用 OpenAI 官方 `v0.0.15`；常駐連線使用 runtime-only 程式。設定由本整合腳本產生，完整 CLI 僅執行 `doctor`。本專案不夾帶第三方二進位檔。
- 上游 [PR #4](https://github.com/arumwu/local-workspace-mcp/pull/4) 記錄既有 npm audit 的 7 個問題（2 moderate、5 high），其中包括當時沒有修補版本的 `braces`。這是上游報告，不代表本版本已修正或完成新的安全稽核；正式用途前請重新評估。詳見 [安全說明](SECURITY.md)。
- 公開 GitHub 原始碼不等於公開託管 MCP endpoint，也不代表已通過 ChatGPT／Codex 市集審核。本版提供自行安裝與私人連線，未提供市集發佈或 Skill。
- 本專案不承諾 OpenAI 服務免費、無限額度，或所有帳號都能使用私人 tunnel。

## 文件與授權

- [從零開始安裝](docs/INSTALL.md)
- [ChatGPT 私人連線](docs/CHATGPT.md)
- [測試與回報方式](docs/TESTING.md)
- [安全邊界與漏洞回報](SECURITY.md)
- [第三方來源與授權](docs/THIRD_PARTY_NOTICES.zh-TW.md)

本專案新增的整合程式與文件採 [MIT License](LICENSE)。上游 Local Workspace MCP 與各第三方元件保留自己的著作權及授權。
