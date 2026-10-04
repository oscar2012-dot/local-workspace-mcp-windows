# 測試狀態與驗收

繁體中文 | [English](TESTING.en.md)

## 目前證據

這是通用 Windows／WSL 整合 alpha。早期單機原型曾完成連線、工具探索與檔案讀寫，但它使用特定電腦設定及 full／略過 Docker worker 的路徑，不能視為本版本或預設 documents 模式的驗收。

| 範圍 | 狀態 |
| --- | --- |
| 早期單機原型 | 曾完成端到端測試；不等同通用版本 |
| 通用安裝器的靜態／自動化檢查 | 以此 revision 的 CI 與測試輸出為準 |
| 乾淨 Windows x64 + WSL2 Ubuntu 安裝 | 尚未完成端到端驗證 |
| 通用版 ChatGPT Desktop 連線及實際工具呼叫 | 尚未完成端到端驗證 |
| documents + Docker 文件產出流程 | 尚未完成端到端驗證 |
| full + Docker／full 略過 worker 的完整回歸 | 尚未完成端到端驗證 |

自動化測試或 mock 通過只能證明其覆蓋的行為，不代表 WSL、Docker、網路、帳號授權與 ChatGPT UI 的整合都已通過。

初始 alpha 檢查紀錄（2026-10-04，雙語文件新增前）：Windows／Python 3.12 執行 79 項測試，72 項通過、7 項因 POSIX 或符號連結權限而略過，沒有失敗。Python 編譯檢查、Windows PowerShell 5.1 語法解析與當時 21 份 staged source 的隱私規則掃描通過。此受限環境無法啟動 Git Bash 語法檢查；Linux 權限、flock 與 Bash 檢查仍須由 CI 驗證。CI 已提供，但只有實際執行結果才算通過。

## 本機快速檢查

在安裝後執行：

```powershell
.\scripts\windows.ps1 -Action Verify
.\scripts\windows.ps1 -Action Status
```

`Verify` 檢查本機安裝，會在 workspace 建立並保留唯一的無敏感資料測試檔，並在 state 寫入 `verification.json`；`Status` 檢查連線狀態。尚未啟動連線時，未連線是正常結果。不要為了讓檢查通過而切換到權限更大的模式。

若執行第三方相依性檢查，請保留上游 lockfile，在獨立測試安裝中記錄 audit 結果。上游已知 npm audit 風險見 [SECURITY.md](../SECURITY.md)；測試成功不會消除依賴風險。

## 公開原始碼檢查

維護者應先審閱變更，將要公開的檔案加入 Git staging area，再在專案根目錄執行：

```powershell
python scripts/check_public_source.py
```

此檢查針對 staged blobs，也就是下一次 commit 的確切內容，不會掃描全部歷史。它使用啟發式規則尋找不應公開的資料；通過不是安全認證，也不能取代人工檢查、歷史檢查與真正的秘密掃描。公開 GitHub 帳號 `oscar2012-dot` 是刻意保留的作者身分；私人姓名、email、路徑與連線資料不應因此被放行。

## 乾淨電腦驗收清單

每個案例使用可丟棄的 workspace，記錄版本與結果。以下是待執行的驗收計畫，不是已完成紀錄。

1. 在 Windows x64 安裝 WSL2／Ubuntu，完成 Linux 使用者首次設定。記錄 Windows、WSL、Ubuntu、PowerShell 版本。
2. 啟動 Docker、啟用該 Ubuntu 的 WSL 整合，執行預設 `Install.cmd`。確認沒有自動提升權限、開機自啟、全域 policy 變更或 client 註冊。
3. 重跑同樣安裝設定，確認既有使用者檔案與不相關設定保留；錯誤可辨識且沒有洩漏秘密。
4. 測試 workspace 路徑包含空白與繁體中文字元；測試不只一個 WSL 發行版時的選擇。
5. 使用自己的 tunnel 與受限制 key 執行 `Connect.cmd`。確認 key 未回顯，Windows settings 不含 key，Linux 私密檔案權限正確。
6. 完成本機 Status／Verify 與 ChatGPT 工具探索；在新對話讀取測試檔，明確授權建立另一個測試檔，再在本機確認內容。
7. 在 documents 模式完成一個 Docker worker 文件任務，驗證輸出可開啟、位置正確，並記錄失敗輸入的處理結果。
8. 按 Ctrl+C 停止，確認相關連線程序退出。重啟時使用已保存設定；重複啟動不得產生意外的第二條常駐連線。
9. 測試 Docker 未啟動、缺少前置套件、無效 tunnel、無效 key、離線及下載失敗等情境。只記錄去識別化摘要。
10. 在另外的測試設定中明確選擇 full，分別測試有 worker 與略過 worker。確認 host tools 只有在已接受風險的模式才出現，略過 worker 時不宣稱 Docker 文件能力可用。

ChatGPT Desktop、瀏覽器版及不同帳號／工作區政策請分別記錄，不能用其中一項結果代表其他項目。

## 回報格式

一般問題請提供以下資訊；安全問題請依 [安全回報流程](../SECURITY.md#回報安全問題)。

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

公開回報必須移除 runtime key、tunnel ID、組織／工作區 ID、真實帳號與主機名稱、私人檔案路徑、檔案內容及對話網址。不要直接貼原始 settings、環境變數、log 或支援匯出檔。
