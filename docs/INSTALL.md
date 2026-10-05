# 從零開始安裝（Windows／WSL）

繁體中文 | [English](INSTALL.en.md)

本指南從下載開始，帶你完成本機安裝，再接上 ChatGPT。一般路徑只需要按畫面操作，不必複製終端指令。**「一鍵」指同一個 `Setup.cmd` 入口引導整個流程，仍需要你同意安裝、建立 Ubuntu 使用者、接受 Docker 條款及建立自己的 OpenAI tunnel。**

目前支援 Windows x64、WSL2、Ubuntu 24.04 以上。新精靈安裝 `documents` 模式；Docker 文件 worker 的限制只適用於 worker，不能解讀為整台電腦都被隔離。原本個人 Windows／WSL 的實際連線與讀寫已經成功；新精靈在乾淨電腦上的端到端流程仍待驗證。詳見 [安全說明](../SECURITY.md) 與 [測試狀態](TESTING.md)。

## 1. 下載並完整解壓

**操作位置：瀏覽器 → Windows 檔案總管。**

1. 開啟 [本專案 GitHub](https://github.com/oscar2012-dot/local-workspace-mcp-windows)，按 **Code → Download ZIP**；也可使用 [直接下載 ZIP](https://github.com/oscar2012-dot/local-workspace-mcp-windows/archive/refs/heads/main.zip)。
2. 確認來源是上述專案，先閱讀 README 與程式。若 ZIP 的右鍵 **內容／Properties** 有 **解除封鎖／Unblock**，在信任並檢閱後勾選它，按套用。
3. 對 ZIP 使用 **全部解壓縮／Extract All**，選擇你有寫入權限的本機資料夾。開啟解壓完成的資料夾，直到能看見 `Setup.cmd`、`Connect.cmd` 和 `scripts`。
4. 在檔案總管的 **檢視／View** 開啟 **副檔名／File name extensions**，確認啟動檔叫 `Setup.cmd`，而不是 `Setup.cmd.txt`。

**應該看到：** 一個正常資料夾，裡面有上述檔案。不要直接在 ZIP 預覽中執行。

**卡住時：** 若腳本被標記為下載檔而封鎖，重新檢閱來源後，只解除封鎖該 ZIP 再重新解壓，或只解除封鎖已檢閱的特定腳本。不要停用 Defender，也不要把全域 PowerShell policy 改成 `Bypass`／`Unrestricted`。組織管理的電腦請依管理員政策處理。

## 2. 開啟精靈並選擇語言

**操作位置：Windows 檔案總管 → 安裝精靈視窗。**

雙擊 `Setup.cmd`，選 **繁體中文** 或 **English**。不帶參數雙擊 `Install.cmd` 也會進入相同精靈。先用一般使用者開啟，不必預先把整個流程以系統管理員執行。

**應該看到：** 語言選單與編號安裝階段。精靈會顯示檢查結果，在安裝缺少的元件前詢問同意。已符合條件的項目會略過。

**卡住時：** 確認已完整解壓、不是 ARM 電腦，且沒有被上一節的下載標記封鎖。若看到 `SETUP_PAUSED=EXISTING_FULL_MODE`，精靈偵測到既有 full 模式，會停止並提示使用既有連線或進階入口，避免把原設定改成 documents。

## 3. 完成 WSL2 與 Ubuntu

**操作位置：安裝精靈、Windows UAC／重新開機畫面、Ubuntu 首次設定視窗。**

若 WSL2 或適合的 Ubuntu 尚未就緒，閱讀精靈的安裝說明並選擇是否繼續。只有你同意後，才會執行相應安裝；Windows 可能出現 UAC，或要求重新開機。先保存其他工作，再自行重新開機。

重新開機後回到解壓資料夾，**再次雙擊 `Setup.cmd`**。這是重新檢查目前進度，不是開機自動執行工作。精靈不會自動重新開機，也不會要求刪除既有 Ubuntu。

Ubuntu 首次啟動時，依視窗建立自己的 Linux 使用者名稱與密碼。這是 Ubuntu 密碼，不是 OpenAI API key。輸入密碼時通常不顯示字元或星號，輸入完成後按 Enter；確認密碼時再輸入一次。

**應該看到：** Ubuntu 已完成首次設定，可使用一般非 root 帳號。當 Ubuntu 顯示可輸入指令的提示符號時，在該 Ubuntu 視窗輸入 `exit` 並按 Enter，返回精靈繼續檢查 WSL2。這一步在 **Ubuntu**，不是 Windows PowerShell。

**卡住時：** `SETUP_PAUSED=WSL_SETUP` 表示 WSL 安裝或重新開機仍需完成；完成後再開精靈。`SETUP_PAUSED=UBUNTU_USER` 表示一般使用者尚未就緒，從 Windows 開始功能表開啟該 Ubuntu 完成設定，再輸入 `exit` 返回。若 Windows 虛擬化／WSL 無法啟用，依 [Microsoft WSL 官方指南](https://learn.microsoft.com/en-us/windows/wsl/install) 處理；不要移除已有資料的發行版。

## 4. 安裝 Linux 前置工具

**操作位置：精靈啟動的 Ubuntu 安裝流程。**

同意精靈列出的 Ubuntu 套件安裝後，它會準備 Python、Git、ripgrep 等所需工具，並取得固定版本、經雜湊驗證的 uv。若 Ubuntu 要求 sudo 密碼，輸入上一步建立的 Linux 密碼；畫面不顯示密碼是正常現象。

**應該看到：** 套件下載／安裝進度，完成後精靈進入下一階段。正常路徑不需要自行貼上 `apt` 或安裝腳本。

**卡住時：** 網路失敗先恢復網路，再重開 `Setup.cmd` 重新檢查。若顯示密碼錯誤，確認輸入的是 Ubuntu 密碼。若雜湊驗證失敗，停止並回報去識別化的錯誤摘要，不要略過驗證或執行下載到的檔案。

## 5. 安裝並啟動 Docker Desktop

**操作位置：安裝精靈 → Windows 安裝程式 → Docker Desktop。**

documents 模式需要 Docker。尚未安裝時，精靈會詢問是否透過 WinGet 安裝 Docker Desktop；閱讀同意範圍後再繼續。Docker 的授權條款、登入與首次設定由你自行決定與完成，精靈不會代替你接受。

完成後，從 Windows 開始功能表開啟 Docker Desktop，等待引擎啟動。如果要求重新開機，保存工作並自行重新開機，再次開啟 Docker Desktop 與 `Setup.cmd`。

**應該看到：** Docker Desktop 已開啟，且引擎已在執行。

**卡住時：** 沒有 WinGet 或安裝未成功時，依 [Docker 官方 WSL2 安裝說明](https://docs.docker.com/desktop/features/wsl/) 手動安裝，再回到精靈。不要為了跳過 Docker 改用具有更大主機權限的 full 模式。

## 6. 開啟 Docker 的 Ubuntu 整合

**操作位置：Docker Desktop → 安裝精靈。**

在 Docker Desktop 開啟 **Settings**，確認使用 WSL2 引擎；接著到 **Resources → WSL Integration**，啟用精靈選中的 Ubuntu 發行版。依畫面按 **Apply／Apply & restart**，等待 Docker 就緒後回到精靈繼續檢查。若設定名稱與版本略有差異，參照 [官方整合說明](https://docs.docker.com/desktop/features/wsl/)。

**應該看到：** 精靈確認 Ubuntu 內可以使用 Docker，繼續安裝 MCP。

**卡住時：** 僅在 Windows 開啟 Docker 還不夠，請確認啟用的是精靈選中的同一個 Ubuntu。等 Docker 就緒後，依精靈提示按 Enter 重試，或按 Q 離開，稍後再執行 `Setup.cmd`。精靈不會把 Docker 失敗當作已完成。

## 7. 等待本機 MCP 安裝與驗證

**操作位置：安裝精靈。**

精靈詢問 **workspace／工作資料夾** 時，第一次使用可直接按 Enter，保留 Ubuntu home 下的 `~/LocalWorkspace`。這是提供給 MCP 處理檔案的位置，不是放金鑰的地方。既有設定會沿用已保存的 workspace；需要自訂時可以輸入 Windows 絕對路徑，但不要選整個磁碟或包含私人設定的資料夾。

接著精靈取得固定版本的上游原始碼、準備執行環境及 Docker worker，最後啟動本機 MCP 做工具探索與測試檔讀寫。首次下載與容器建置可能需要一段時間，請等明確的完成或錯誤訊息。

**成功標記：**

```text
LOCAL_INSTALL_READY=PASS
CHATGPT_CONNECTION=NOT_CONFIGURED
```

這表示本機安裝和讀寫檢查通過，**尚未代表 ChatGPT 已連線**。驗證會在 workspace 保留唯一的測試檔，並在 state 寫入本機驗證結果。符合相同設定的既有安裝會重用並驗證，不會覆蓋成另一種模式或清空 workspace。

**卡住時：** 先處理畫面最後指出的前置條件，再重開精靈。既有設定不相符時不要刪除 state、workspace 或舊版個人安裝；依訊息保留舊設定，使用進階流程建立分開的安裝，或回報去識別化摘要。

## 8. 接上 ChatGPT，再做一次真實讀寫

接著依 [ChatGPT 逐步連線指南](CHATGPT.md) 建立自己的私人 tunnel、輸入限制權限 key、在 ChatGPT 加入連線並測試 `hello.txt`。若精靈詢問是否開啟連線，你可以選擇開啟；也可稍後雙擊 `Connect.cmd`。

| 階段 | 能證明什麼 |
| --- | --- |
| `LOCAL_INSTALL_READY=PASS` | 本機 MCP 安裝與測試讀寫已通過 |
| `WINDOWS_TUNNEL_READY=PASS` | 這次 tunnel 程序回報啟動就緒 |
| ChatGPT 讀出測試內容，且你確認它建立的回覆檔 | 這次實際 ChatGPT 工具路徑已完成讀寫 |

安裝精靈本身不會發出模型推論 API 請求；這不表示 OpenAI 帳號、tunnel、ChatGPT 用量或 Docker 授權永遠免費。可用性、額度與條款以各服務及帳號設定為準。

## 日後使用與檔案位置

- 使用時啟動 Docker Desktop，再雙擊 `Connect.cmd`，保持視窗開啟。平常不必重裝或重建 key。
- 停止時在連線視窗按 **Ctrl+C**，等待清理；`Status.cmd` 可查看狀態。
- 預設 workspace 是 Ubuntu home 下的 `LocalWorkspace`。在 Windows 檔案總管開啟 **Linux → 安裝時使用的 Ubuntu → home → 自己的 Linux 使用者目錄 → LocalWorkspace**。若安裝時指定其他 workspace，以安裝畫面與設定為準。
- 不要把 state、runtime key 或原始 log 放進 workspace、GitHub 或聊天。問題回報方式見 [TESTING.md](TESTING.md)。

若需要自訂發行版、workspace 或 full 模式，閱讀 [README 的進階安裝](../README.md#進階安裝)。進階使用者可在專案資料夾的 Windows PowerShell 執行下方指令。這只做唯讀檢查，不安裝、不下載，也不啟動已停止的 WSL；輸出 `SETUP_CHECK=PASS` 或 `SETUP_CHECK=NEEDS_ACTION`。新手安裝不需要使用它。

```powershell
.\Setup.cmd -CheckOnly
```
