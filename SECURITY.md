# 安全說明

繁體中文 | [English](SECURITY.en.md)

本專案目前是 Windows／WSL 社群整合 alpha，尚未完成通用版本的乾淨電腦端到端驗證。這裡記錄實際權限邊界與已知風險，不提供安全認證或正式環境保證。

## 模式與權限

`documents` 是預設模式。Docker 文件 worker 的容器限制僅適用於 worker；交給它的檔案仍可能被讀取、處理並作為工具結果傳回模型。

`full` 會啟用上游 host tools，以啟動程序的 WSL 使用者權限執行操作，包括程序執行、檔案讀寫與網路存取。workspace 是預設工作目錄，不是作業系統沙箱。WSL 可掛載的 Windows 路徑（例如 `/mnt`）也可能在這個帳號的可存取範圍內。應用程式的路徑設定與模型的確認提示不等於權限隔離。

選擇 `full` 時，即使另外啟用 Docker，主機工具仍保持上述權限。選擇略過 worker 只會停用 Docker 文件工作能力，不會降低 full 的主機權限。

請從沒有敏感資料的專用測試 workspace 開始，使用一般使用者執行，並讓工具只接觸你確實打算交付的資料。不要把來源不明的文件、程式或提示當成操作授權。

## 金鑰與本機狀態

- 每位使用者使用自己的私人 tunnel，runtime key 限制為 **Tunnels Read + Use**。建立／管理 tunnel 的帳號權限與執行時金鑰應分開考量。
- 金鑰只透過本機隱藏提示輸入。不要放進 shell 命令列、聊天、issue、PR、截圖、文件或診斷紀錄。
- WSL 私密狀態位於 `~/.local/state/local-workspace-mcp-windows`，應保存在 Linux 檔案系統，使用私有目錄／檔案權限。Windows 設定位於 `%LOCALAPPDATA%\LocalWorkspaceMCPWindows\settings.json`。
- 限制權限無法防止同一 OS 帳號、管理員或已取得該帳號控制權的程序讀取資料。請一併考量備份、同步與終端錄影。
- `full` 主機工具也在同一帳號下執行，因此上述檔案權限不會把 runtime key 與 full 工具隔離；不要將 full 模式視為保密沙箱。
- 字串格式檢查不能證明 API key 實際只具有所需權限；請自行在 Platform 確認。

若金鑰外洩，立即在 Platform 撤銷它，停止本機連線，建立最小權限的新 key，並檢查相關帳號活動。不要把舊 key 寄給維護者。

## 依賴與下載

`Setup.cmd` 是互動式安裝精靈，不是零提示的背景安裝。新增 WSL／Ubuntu、透過 Ubuntu 套件管理器補齊工具、安裝 Docker Desktop，以及最後啟動連線，均需先確認。WSL 的系統管理員提示只用於該次安裝；Linux 套件透過 `sudo` 安裝，密碼由本機終端處理。精靈不儲存密碼、不變更全域 PowerShell 執行原則，也不自行重開機或設定開機自啟。Docker 條款由使用者審閱，企業裝置須遵守管理政策。

缺少 uv 時，bootstrap 下載 Astral 官方 `0.12.19` 的 Linux x64 封存檔，先核對內建 SHA-256，再取出預期的一般檔案；已有工具不會被強制替換。Ubuntu 套件與 WinGet 的 Docker Desktop 版本取自使用者當時信任的套件來源，並非全部固定版本；不會略過套件簽章／雜湊檢查。新版精靈採 documents 模式，遇到既有 full 設定會停止並說明，不會默默改變權限或工作目錄。

上游程式固定於 `ba42837e7aa54cd265e62023e5079f0e4affdf84`，tunnel-client 固定於官方 `v0.0.15`。固定版本有助於重現與審查，但不代表不存在漏洞。安裝仍會取得第三方原始碼、套件與所選模式需要的容器內容；本倉庫不夾帶第三方二進位檔。

上游 [PR #4](https://github.com/arumwu/local-workspace-mcp/pull/4) 曾報告既有 npm audit 的 7 個問題（2 moderate、5 high），包括當時沒有修補版本的 `braces`。這是已知繼承風險；本整合版未宣稱修正這些相依性，也不擅自改動上游 lockfile。audit 數量與可利用性會隨套件與漏洞資料庫改變，請在正式部署前重新檢查上游、安全公告與實際使用路徑。

## 連線與資料

私人 tunnel 會把 MCP 請求與結果送經 OpenAI。伺服器留在本機不代表所有處理都只在本機。請先理解帳號及工作區的資料政策，再交付檔案。

公開原始碼不會替使用者建立共同 tunnel、共享金鑰或公開 MCP 服務。本專案不自行開放入站防火牆、不在未確認時提升權限、不啟用開機自啟，也不自動替 ChatGPT 註冊連線。第三方安裝器可能依其自身流程設定服務或 Windows 元件，請閱讀其提示。正常停止連線請使用 Ctrl+C 並確認狀態。

## 回報安全問題

先查看本倉庫 GitHub 的 **Security → Advisories → Report a vulnerability** 是否可用；若已啟用，優先使用私人回報。若不可用，請只建立不含漏洞細節或敏感資料的 issue，要求維護者提供私人回報管道。不要假設公開 issue 是私密的。

回報可包含受影響版本、模式、最小化重現步驟與已去識別化的錯誤摘要。請移除金鑰、tunnel ID、組織／工作區 ID、帳號名稱、主機名稱、私人檔案路徑與內容。涉及上游問題時，也應遵循上游的回報方式。

本專案沒有承諾回應或修補時限；本機整合、上游 MCP、tunnel-client 與 OpenAI 服務由不同維護者負責。
