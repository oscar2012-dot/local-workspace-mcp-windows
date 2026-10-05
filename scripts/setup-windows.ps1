# ASCII source: JSON Unicode escapes keep this file compatible with PowerShell 5.1.
[CmdletBinding()]
param(
    [switch]$CheckOnly,
    [ValidateSet('zh-TW', 'en')][string]$Language,
    [string]$Distro,
    [string]$Workspace
)
Set-StrictMode -Version 2.0
$ErrorActionPreference = 'Stop'
$script:SetupRoot = $PSScriptRoot
$script:SetupLanguage = 'en'
$script:SetupMessages = @'
{
  "en": {
    "title": "Local Workspace MCP - guided setup (documents mode)",
    "chooseLanguage": "Language: 1 = Traditional Chinese, 2 = English [1]",
    "step1": "[1/6] Check Windows and existing settings",
    "step2": "[2/6] Prepare WSL 2 and your Ubuntu user",
    "step3": "[3/6] Prepare Linux prerequisites",
    "step4": "[4/6] Check Docker and WSL integration",
    "step5": "[5/6] Install MCP and verify a workspace write/read",
    "step6": "[6/6] Finish local setup and connect your account",
    "x64": "This installer supports Windows x64 only.",
    "badSettings": "Existing settings cannot be read safely. Inspect {0}; setup stopped without changing them.",
    "fullSettings": "Your saved installation uses FULL mode. This beginner wizard installs documents mode only and will not replace that configuration. Use Connect.cmd for your existing setup, or the advanced installer for a separate configuration (README).",
    "modeInvalid": "Existing settings contain an unsupported mode or worker selection. Inspect them before continuing.",
    "wslUnavailable": "The system WSL executable is unavailable. Install Windows Subsystem for Linux using Microsoft's instructions, then rerun this setup: https://learn.microsoft.com/windows/wsl/install",
    "needWsl": "Ubuntu 24.04 is not installed. Installing WSL/Ubuntu may require a Windows administrator approval and a restart.",
    "confirmWsl": "Install WSL and Ubuntu 24.04 now? Windows may request administrator approval if system WSL components are missing",
    "machineWsl": "Windows system WSL components need administrator approval. Ubuntu will then install separately under your current Windows account.",
    "installWslGuide": "The Windows installer may ask you to create an Ubuntu username and password. When an Ubuntu shell appears, type exit to return here. Approve only the WSL installation you requested.",
    "restart": "WSL installation needs another step or a restart. Save your work, restart Windows if requested, then double-click the same Setup.cmd. Completed checks will be repeated and existing components reused.",
    "canceled": "Setup paused at your request. Rerun Setup.cmd when ready.",
    "distroMissing": "Requested/saved distribution '{0}' is unavailable. Setup will not silently switch your existing configuration. Start or repair that distribution, or explicitly pass -Distro with an installed Ubuntu name.",
    "distroPrompt": "Choose an Ubuntu distribution number",
    "noUbuntu": "No suitable Ubuntu distribution was selected. Ubuntu 24.04 or newer is required; rerun with -Distro if needed.",
    "chosenDistro": "Selected distribution: {0}",
    "stoppedCheck": "The selected distribution is stopped. CheckOnly will not start it. Open Ubuntu yourself and rerun Setup.cmd -CheckOnly.",
    "needUser": "Ubuntu needs a non-root default user. In the next Ubuntu window, complete username/password setup if prompted; then type exit. If it opens as root, finish setup in the Ubuntu app before retrying.",
    "confirmUser": "Open Ubuntu's interactive first-run window now",
    "userStillRoot": "Ubuntu still does not have a non-root default user. Finish its account setup, type exit, and rerun Setup.cmd.",
    "checkNeeds": "Prerequisites need attention. CheckOnly made no installations, downloads or configuration writes.",
    "linuxConsent": "Install missing Linux prerequisites in the selected Ubuntu? This may request your Ubuntu sudo password and downloads packages plus a checksum-verified uv binary",
    "linuxFail": "Linux prerequisites are not ready. Read the diagnostic above, resolve the issue, and rerun this same setup.",
    "linuxReady": "Linux prerequisites are ready.",
    "dockerNeed": "Docker is not accessible inside this Ubuntu distribution. Documents mode requires a running Docker engine.",
    "dockerConsent": "Install Docker Desktop from the official winget source? Its installer may request administrator approval and show license or organization terms",
    "wingetMissing": "A trusted Windows Package Manager was not found. Install/update Microsoft's App Installer, or install Docker Desktop yourself, then rerun Setup.cmd: https://docs.docker.com/desktop/setup/install/windows-install/",
    "dockerInstallFail": "Docker Desktop installation did not finish successfully. Review its installer message; setup will not accept terms or change policies on your behalf.",
    "dockerNotFound": "Docker Desktop's standard executable was not found. Open Docker Desktop yourself and follow the integration instructions below.",
    "dockerStart": "Open Docker Desktop now so you can review its terms and configure WSL integration",
    "dockerGuide": "In Docker Desktop: finish any terms/setup prompts, open Settings > Resources > WSL integration, enable '{0}', choose Apply & restart if shown, and wait until Docker is running.",
    "dockerRetry": "Press Enter to check Docker again, or Q to stop",
    "dockerNotReady": "Docker is still unavailable after these checks. Finish Docker setup and rerun Setup.cmd; no MCP installation was performed.",
    "dockerReady": "Docker is accessible from the selected Ubuntu.",
    "workspace": "Workspace: {0}",
    "workspacePrompt": "Workspace folder [~/LocalWorkspace] (Windows paths are also accepted)",
    "localFail": "MCP installation/verification failed. Read the message above and rerun Setup.cmd after resolving it. Existing installation files are not silently replaced.",
    "localReady": "Local setup passed. ChatGPT account connection is a separate step; it has not been configured or tested by this wizard.",
    "connectGuide": "Open docs/CHATGPT.en.md and prepare your own tunnel ID and restricted runtime key in your OpenAI account. Never paste the key into chat or a command. Connect.cmd requests it with hidden input.",
    "connectConsent": "I have prepared the account/tunnel details; start Connect now",
    "connectReturn": "The connection process has ended. Use Connect.cmd whenever you want to connect again.",
    "checkReady": "Prerequisite checks passed. CheckOnly did not install MCP or test a ChatGPT connection.",
    "trustedWsl": "The WSL executable could not be verified as a signed Microsoft system tool; automatic elevation was refused.",
    "unexpected": "Setup stopped: {0}",
    "yesNo": " [y/N]",
    "installSummary": "This setup installs documents mode, uses Docker for document work, and leaves existing client settings unregistered."
  },
  "zh-TW": {
    "title": "Local Workspace MCP - \u5f15\u5c0e\u5f0f\u5b89\u88dd\uff08\u6587\u4ef6\u6a21\u5f0f\uff09",
    "chooseLanguage": "Language / \u8a9e\u8a00\uff1a1 = \u7e41\u9ad4\u4e2d\u6587\uff0c2 = English [1]",
    "step1": "[1/6] \u6aa2\u67e5 Windows \u8207\u73fe\u6709\u8a2d\u5b9a",
    "step2": "[2/6] \u6e96\u5099 WSL 2 \u8207 Ubuntu \u4f7f\u7528\u8005",
    "step3": "[3/6] \u6e96\u5099 Linux \u5fc5\u8981\u5957\u4ef6",
    "step4": "[4/6] \u6aa2\u67e5 Docker \u8207 WSL \u6574\u5408",
    "step5": "[5/6] \u5b89\u88dd MCP \u4e26\u9a57\u8b49\u5de5\u4f5c\u8cc7\u6599\u593e\u8b80\u5beb",
    "step6": "[6/6] \u5b8c\u6210\u672c\u6a5f\u8a2d\u5b9a\u4e26\u9023\u63a5\u5e33\u865f",
    "x64": "\u6b64\u5b89\u88dd\u7a0b\u5f0f\u76ee\u524d\u53ea\u652f\u63f4 Windows x64\u3002",
    "badSettings": "\u7121\u6cd5\u5b89\u5168\u8b80\u53d6\u73fe\u6709\u8a2d\u5b9a\u3002\u8acb\u6aa2\u67e5 {0}\uff1b\u5b89\u88dd\u5df2\u505c\u6b62\uff0c\u672a\u8b8a\u66f4\u8a72\u8a2d\u5b9a\u3002",
    "fullSettings": "\u4f60\u5132\u5b58\u7684\u5b89\u88dd\u4f7f\u7528 FULL \u5b8c\u6574\u6a21\u5f0f\u3002\u6b64\u5165\u9580\u7cbe\u9748\u53ea\u5b89\u88dd documents \u6587\u4ef6\u6a21\u5f0f\uff0c\u4e0d\u6703\u53d6\u4ee3\u73fe\u6709\u8a2d\u5b9a\u3002\u8acb\u7528 Connect.cmd \u555f\u52d5\u539f\u6709\u5b89\u88dd\uff1b\u82e5\u8981\u53e6\u5916\u5efa\u7acb\u8a2d\u5b9a\uff0c\u8acb\u4f9d README \u4f7f\u7528\u9032\u968e\u5b89\u88dd\u65b9\u5f0f\u3002",
    "modeInvalid": "\u73fe\u6709\u8a2d\u5b9a\u7684\u6a21\u5f0f\u6216 worker \u9078\u9805\u4e0d\u53d7\u652f\u63f4\u3002\u8acb\u5148\u6aa2\u67e5\u8a2d\u5b9a\u518d\u7e7c\u7e8c\u3002",
    "wslUnavailable": "\u627e\u4e0d\u5230\u7cfb\u7d71\u7684 WSL \u57f7\u884c\u6a94\u3002\u8acb\u4f9d Microsoft \u6307\u5f15\u5b89\u88dd Windows Subsystem for Linux\uff0c\u518d\u91cd\u65b0\u57f7\u884c\uff1a https://learn.microsoft.com/windows/wsl/install",
    "needWsl": "\u5c1a\u672a\u5b89\u88dd Ubuntu 24.04\u3002\u5b89\u88dd WSL\uff0fUbuntu \u53ef\u80fd\u9700\u8981 Windows \u7cfb\u7d71\u7ba1\u7406\u54e1\u6388\u6b0a\u8207\u91cd\u65b0\u958b\u6a5f\u3002",
    "confirmWsl": "\u73fe\u5728\u5b89\u88dd WSL \u8207 Ubuntu 24.04\uff1f\u82e5\u7f3a\u5c11\u7cfb\u7d71 WSL \u5143\u4ef6\uff0cWindows \u53ef\u80fd\u8981\u6c42\u7ba1\u7406\u54e1\u6388\u6b0a",
    "machineWsl": "\u5b89\u88dd\u7cfb\u7d71 WSL \u5143\u4ef6\u53ef\u80fd\u9700\u8981 Windows \u7ba1\u7406\u54e1\u6388\u6b0a\uff1bUbuntu \u6703\u53e6\u5916\u5728\u4f60\u76ee\u524d\u7684 Windows \u5e33\u865f\u4e0b\u5b89\u88dd\u3002",
    "installWslGuide": "\u5b89\u88dd\u8996\u7a97\u53ef\u80fd\u8981\u6c42\u4f60\u5efa\u7acb Ubuntu \u4f7f\u7528\u8005\u540d\u7a31\u8207\u5bc6\u78bc\u3002\u51fa\u73fe Ubuntu \u547d\u4ee4\u63d0\u793a\u5b57\u5143\u5f8c\uff0c\u8f38\u5165 exit \u8fd4\u56de\u3002\u8acb\u53ea\u6279\u51c6\u9019\u6b21\u8981\u6c42\u7684 WSL \u5b89\u88dd\u3002",
    "restart": "WSL \u5b89\u88dd\u4ecd\u9700\u5f8c\u7e8c\u6b65\u9a5f\u6216\u91cd\u65b0\u958b\u6a5f\u3002\u8acb\u5148\u5132\u5b58\u5de5\u4f5c\uff0c\u4f9d\u756b\u9762\u8981\u6c42\u91cd\u958b Windows\uff0c\u518d\u96d9\u64ca\u540c\u4e00\u500b Setup.cmd\u3002\u7a0b\u5f0f\u6703\u91cd\u65b0\u6aa2\u67e5\u4e26\u6cbf\u7528\u5df2\u5099\u59a5\u7684\u5143\u4ef6\u3002",
    "canceled": "\u5df2\u4f9d\u4f60\u7684\u9078\u64c7\u66ab\u505c\u3002\u6e96\u5099\u597d\u5f8c\u91cd\u65b0\u57f7\u884c Setup.cmd \u5373\u53ef\u3002",
    "distroMissing": "\u627e\u4e0d\u5230\u6307\u5b9a\uff0f\u5132\u5b58\u7684\u767c\u884c\u7248\u300c{0}\u300d\u3002\u7a0b\u5f0f\u4e0d\u6703\u81ea\u52d5\u6539\u7528\u5176\u4ed6\u74b0\u5883\u3002\u8acb\u5148\u555f\u52d5\u6216\u4fee\u5fa9\u8a72\u767c\u884c\u7248\uff1b\u6216\u660e\u78ba\u4f7f\u7528 -Distro \u6307\u5b9a\u5df2\u5b89\u88dd\u7684 Ubuntu\u3002",
    "distroPrompt": "\u8acb\u8f38\u5165 Ubuntu \u767c\u884c\u7248\u7684\u7de8\u865f",
    "noUbuntu": "\u672a\u9078\u5230\u9069\u7528\u7684 Ubuntu \u767c\u884c\u7248\u3002\u9700\u8981 Ubuntu 24.04 \u4ee5\u4e0a\uff1b\u5fc5\u8981\u6642\u8acb\u4f7f\u7528 -Distro \u6307\u5b9a\u3002",
    "chosenDistro": "\u9078\u7528\u7684\u767c\u884c\u7248\uff1a{0}",
    "stoppedCheck": "\u9078\u7528\u7684\u767c\u884c\u7248\u76ee\u524d\u672a\u555f\u52d5\u3002CheckOnly \u4e0d\u6703\u555f\u52d5\u5b83\u3002\u8acb\u81ea\u884c\u958b\u555f Ubuntu\uff0c\u518d\u57f7\u884c Setup.cmd -CheckOnly\u3002",
    "needUser": "Ubuntu \u9700\u8981\u975e root \u7684\u9810\u8a2d\u4f7f\u7528\u8005\u3002\u8acb\u5728\u4e0b\u4e00\u500b Ubuntu \u8996\u7a97\u5b8c\u6210\u4f7f\u7528\u8005\u540d\u7a31\uff0f\u5bc6\u78bc\u8a2d\u5b9a\uff0c\u5b8c\u6210\u5f8c\u8f38\u5165 exit\u3002\u82e5\u76f4\u63a5\u9032\u5165 root\uff0c\u8acb\u5148\u5728 Ubuntu \u61c9\u7528\u7a0b\u5f0f\u5b8c\u6210\u9996\u6b21\u8a2d\u5b9a\u3002",
    "confirmUser": "\u73fe\u5728\u958b\u555f Ubuntu \u7684\u4e92\u52d5\u5f0f\u9996\u6b21\u8a2d\u5b9a\u8996\u7a97",
    "userStillRoot": "Ubuntu \u4ecd\u672a\u8a2d\u5b9a\u975e root \u7684\u9810\u8a2d\u4f7f\u7528\u8005\u3002\u8acb\u5b8c\u6210\u5e33\u865f\u8a2d\u5b9a\u3001\u8f38\u5165 exit\uff0c\u7136\u5f8c\u518d\u57f7\u884c Setup.cmd\u3002",
    "checkNeeds": "\u524d\u7f6e\u689d\u4ef6\u4ecd\u9700\u8655\u7406\u3002CheckOnly \u672a\u5b89\u88dd\u3001\u4e0b\u8f09\u6216\u5beb\u5165\u8a2d\u5b9a\u3002",
    "linuxConsent": "\u5728\u9078\u7528\u7684 Ubuntu \u5b89\u88dd\u7f3a\u5c11\u7684 Linux \u5957\u4ef6\uff1f\u904e\u7a0b\u53ef\u80fd\u8981\u6c42 Ubuntu sudo \u5bc6\u78bc\uff0c\u4e26\u4e0b\u8f09\u5957\u4ef6\u8207\u6838\u5c0d\u96dc\u6e4a\u7684 uv \u57f7\u884c\u6a94",
    "linuxFail": "Linux \u524d\u7f6e\u689d\u4ef6\u5c1a\u672a\u5099\u59a5\u3002\u8acb\u4f9d\u4e0a\u65b9\u8a0a\u606f\u8655\u7406\uff0c\u518d\u57f7\u884c\u540c\u4e00\u500b Setup.cmd\u3002",
    "linuxReady": "Linux \u5fc5\u8981\u5957\u4ef6\u5df2\u5099\u59a5\u3002",
    "dockerNeed": "\u6b64 Ubuntu \u5c1a\u7121\u6cd5\u4f7f\u7528 Docker\u3002\u6587\u4ef6\u6a21\u5f0f\u9700\u8981\u53ef\u904b\u4f5c\u7684 Docker \u5f15\u64ce\u3002",
    "dockerConsent": "\u5f9e\u5b98\u65b9 winget \u4f86\u6e90\u5b89\u88dd Docker Desktop\uff1f\u5176\u5b89\u88dd\u7a0b\u5f0f\u53ef\u80fd\u8981\u6c42\u7ba1\u7406\u54e1\u6388\u6b0a\uff0c\u4e26\u986f\u793a\u6388\u6b0a\u6216\u7d44\u7e54\u4f7f\u7528\u689d\u6b3e",
    "wingetMissing": "\u627e\u4e0d\u5230\u53ef\u4fe1\u7684 Windows \u5957\u4ef6\u7ba1\u7406\u54e1\u3002\u8acb\u5b89\u88dd\uff0f\u66f4\u65b0 Microsoft \u7684\u300cApp Installer\u300d\uff0c\u6216\u81ea\u884c\u5b89\u88dd Docker Desktop \u5f8c\u518d\u57f7\u884c\uff1a https://docs.docker.com/desktop/setup/install/windows-install/",
    "dockerInstallFail": "Docker Desktop \u672a\u5b8c\u6210\u5b89\u88dd\u3002\u8acb\u67e5\u770b\u5176\u5b89\u88dd\u8a0a\u606f\uff1b\u672c\u7a0b\u5f0f\u4e0d\u6703\u66ff\u4f60\u63a5\u53d7\u689d\u6b3e\u6216\u8b8a\u66f4\u653f\u7b56\u3002",
    "dockerNotFound": "\u672a\u5728\u6a19\u6e96\u4f4d\u7f6e\u627e\u5230 Docker Desktop\u3002\u8acb\u81ea\u884c\u958b\u555f Docker Desktop\uff0c\u4f9d\u4e0b\u65b9\u6307\u793a\u555f\u7528\u6574\u5408\u3002",
    "dockerStart": "\u73fe\u5728\u958b\u555f Docker Desktop\uff0c\u8b93\u4f60\u78ba\u8a8d\u689d\u6b3e\u4e26\u8a2d\u5b9a WSL \u6574\u5408",
    "dockerGuide": "\u5728 Docker Desktop \u5b8c\u6210\u689d\u6b3e\uff0f\u9996\u6b21\u8a2d\u5b9a\u5f8c\uff0c\u958b\u555f Settings > Resources > WSL integration\uff0c\u555f\u7528\u300c{0}\u300d\uff0c\u82e5\u986f\u793a Apply & restart \u8acb\u6309\u4e0b\uff0c\u4e26\u7b49\u5f85 Docker \u555f\u52d5\u5b8c\u6210\u3002",
    "dockerRetry": "\u6309 Enter \u518d\u6b21\u6aa2\u67e5 Docker\uff0c\u6216\u8f38\u5165 Q \u7d50\u675f",
    "dockerNotReady": "\u7d93\u904e\u9019\u5e7e\u6b21\u6aa2\u67e5\uff0cDocker \u4ecd\u7121\u6cd5\u4f7f\u7528\u3002\u8acb\u5b8c\u6210 Docker \u8a2d\u5b9a\u5f8c\u518d\u57f7\u884c Setup.cmd\uff1b\u5c1a\u672a\u9032\u884c MCP \u5b89\u88dd\u3002",
    "dockerReady": "\u9078\u7528\u7684 Ubuntu \u5df2\u53ef\u4f7f\u7528 Docker\u3002",
    "workspace": "\u5de5\u4f5c\u8cc7\u6599\u593e\uff1a{0}",
    "workspacePrompt": "\u5de5\u4f5c\u8cc7\u6599\u593e [~/LocalWorkspace]\uff08\u4e5f\u53ef\u8f38\u5165 Windows \u8def\u5f91\uff09",
    "localFail": "MCP \u5b89\u88dd\uff0f\u9a57\u8b49\u5931\u6557\u3002\u8acb\u4f9d\u4e0a\u65b9\u8a0a\u606f\u8655\u7406\u5f8c\uff0c\u518d\u57f7\u884c Setup.cmd\u3002\u7a0b\u5f0f\u4e0d\u6703\u76f4\u63a5\u53d6\u4ee3\u885d\u7a81\u7684\u73fe\u6709\u5b89\u88dd\u3002",
    "localReady": "\u672c\u6a5f\u5b89\u88dd\u5df2\u901a\u904e\u3002ChatGPT \u5e33\u865f\u9023\u7dda\u662f\u4e0b\u4e00\u500b\u7368\u7acb\u6b65\u9a5f\uff1b\u6b64\u7cbe\u9748\u5c1a\u672a\u5b8c\u6210\u6216\u9a57\u8b49\u5e33\u865f\u9023\u7dda\u3002",
    "connectGuide": "\u8acb\u958b\u555f docs/CHATGPT.md\uff0c\u5148\u5728\u4f60\u7684 OpenAI \u5e33\u865f\u6e96\u5099\u81ea\u5df1\u7684 tunnel ID \u8207\u53d7\u9650 runtime key\u3002\u4e0d\u8981\u628a key \u8cbc\u9032\u5c0d\u8a71\u6216\u547d\u4ee4\u5217\uff1bConnect.cmd \u6703\u4ee5\u96b1\u85cf\u8f38\u5165\u65b9\u5f0f\u63a5\u6536\u3002",
    "connectConsent": "\u6211\u5df2\u5099\u59a5\u5e33\u865f\u8207 tunnel \u8cc7\u8a0a\uff0c\u73fe\u5728\u958b\u59cb Connect",
    "connectReturn": "\u9023\u7dda\u7a0b\u5e8f\u5df2\u7d50\u675f\u3002\u4e4b\u5f8c\u9700\u8981\u9023\u7dda\u6642\uff0c\u57f7\u884c Connect.cmd\u3002",
    "checkReady": "\u524d\u7f6e\u689d\u4ef6\u6aa2\u67e5\u901a\u904e\u3002CheckOnly \u672a\u5b89\u88dd MCP\uff0c\u4e5f\u672a\u6e2c\u8a66 ChatGPT \u9023\u7dda\u3002",
    "trustedWsl": "\u7121\u6cd5\u9a57\u8b49 WSL \u70ba Microsoft \u7c3d\u7f72\u7684\u7cfb\u7d71\u7a0b\u5f0f\uff0c\u5df2\u62d2\u7d55\u81ea\u52d5\u63d0\u5347\u6b0a\u9650\u3002",
    "unexpected": "\u5b89\u88dd\u5df2\u505c\u6b62\uff1a{0}",
    "yesNo": " [y/N]",
    "installSummary": "\u6b64\u7cbe\u9748\u5b89\u88dd documents \u6587\u4ef6\u6a21\u5f0f\uff0c\u4f7f\u7528 Docker \u8655\u7406\u6587\u4ef6\uff0c\u4e26\u7dad\u6301\u4e0d\u81ea\u52d5\u8a3b\u518a\u65e2\u6709 client \u8a2d\u5b9a\u3002"
  }
}
'@ | ConvertFrom-Json

function Get-SetupText {
    param([string]$Key, [object[]]$Values = @())
    $locale = $script:SetupMessages.PSObject.Properties[$script:SetupLanguage].Value
    $text = [string]$locale.PSObject.Properties[$Key].Value
    if ($Values.Count -gt 0) { return ($text -f $Values) }
    return $text
}

function Write-SetupMessage {
    param([string]$Key, [object[]]$Values = @())
    Write-Host (Get-SetupText -Key $Key -Values $Values)
}

function Confirm-SetupAction {
    param([string]$Key)
    $answer = Read-Host ((Get-SetupText $Key) + (Get-SetupText 'yesNo'))
    return $answer.Trim().ToLowerInvariant() -in @('y', 'yes')
}

function Invoke-SetupCapture {
    param([string]$FilePath, [string[]]$Arguments)
    $previous = $ErrorActionPreference
    try {
        # Native stderr warnings in Windows PowerShell 5.1 are not fatal.
        $ErrorActionPreference = 'Continue'
        $lines = @(& $FilePath @Arguments)
        $code = $LASTEXITCODE
    } finally { $ErrorActionPreference = $previous }
    return [pscustomobject]@{ ExitCode = $code; Output = ($lines -join "`n") }
}

function Invoke-SetupInteractive {
    param([string]$FilePath, [string[]]$Arguments)
    $previous = $ErrorActionPreference
    try {
        $ErrorActionPreference = 'Continue'
        & $FilePath @Arguments | Out-Host
        $code = $LASTEXITCODE
    } finally { $ErrorActionPreference = $previous }
    return $code
}

function Get-SetupArchitecture {
    if ($env:PROCESSOR_ARCHITEW6432) { return $env:PROCESSOR_ARCHITEW6432 }
    return $env:PROCESSOR_ARCHITECTURE
}

function Get-SetupSystemTool {
    param([ValidateSet('wsl', 'powershell')][string]$Name)
    $windows = [Environment]::GetFolderPath('Windows')
    $system = Join-Path $windows 'System32'
    if ($env:PROCESSOR_ARCHITEW6432) { $system = Join-Path $windows 'Sysnative' }
    $relative = 'wsl.exe'
    if ($Name -eq 'powershell') { $relative = 'WindowsPowerShell\v1.0\powershell.exe' }
    $candidate = [System.IO.Path]::GetFullPath((Join-Path $system $relative))
    if (-not (Test-Path -LiteralPath $candidate -PathType Leaf)) { return $null }
    return $candidate
}

function Read-SetupSettings {
    if (-not $env:LOCALAPPDATA) { throw 'LOCALAPPDATA is unavailable.' }
    $path = Join-Path $env:LOCALAPPDATA 'LocalWorkspaceMCPWindows\settings.json'
    if (-not (Test-Path -LiteralPath $path)) { return $null }
    try {
        $settings = Get-Content -LiteralPath $path -Raw -Encoding UTF8 | ConvertFrom-Json
        if (-not $settings -or -not $settings.PSObject.Properties['mode']) { throw 'Missing mode' }
        return $settings
    } catch { throw (Get-SetupText 'badSettings' @($path)) }
}

function Get-SetupSetting {
    param($Settings, [string]$Name)
    if ($null -ne $Settings -and $Settings.PSObject.Properties[$Name]) {
        return $Settings.PSObject.Properties[$Name].Value
    }
    return $null
}

function Get-SetupDistros {
    param([string]$Wsl, [switch]$Running)
    $arguments = @('--list', '--quiet')
    if ($Running) { $arguments += '--running' }
    $result = Invoke-SetupCapture $Wsl $arguments
    if ($result.ExitCode -ne 0) { return @() }
    return @($result.Output.Replace([string][char]0, '').Split("`n") | ForEach-Object { $_.Trim() } | Where-Object { $_ })
}

function Select-SetupDistro {
    param([string[]]$Names, [string]$Requested, [switch]$ReadOnly)
    if ($Requested) {
        if ($Names -notcontains $Requested) { return $null }
        return $Requested
    }
    if ($Names -contains 'Ubuntu-24.04') { return 'Ubuntu-24.04' }
    $ubuntu = @($Names | Where-Object { $_ -match '^Ubuntu(?:[- ]|$)' })
    if ($ubuntu.Count -eq 1) { return $ubuntu[0] }
    if ($ubuntu.Count -eq 0 -or $ReadOnly) { return $null }
    for ($i = 0; $i -lt $ubuntu.Count; $i++) { Write-Host ("  {0}: {1}" -f ($i + 1), $ubuntu[$i]) }
    $answer = Read-Host (Get-SetupText 'distroPrompt')
    $choice = 0
    if (-not [int]::TryParse($answer, [ref]$choice) -or $choice -lt 1 -or $choice -gt $ubuntu.Count) { return $null }
    return $ubuntu[$choice - 1]
}

function Invoke-SetupWslInstall {
    param([string]$Wsl)
    $expected = Get-SetupSystemTool 'wsl'
    if (-not $expected -or $Wsl -ne $expected) { throw (Get-SetupText 'trustedWsl') }
    $machine = Invoke-SetupCapture $Wsl @('--status')
    if ($machine.ExitCode -ne 0) {
        # Elevate machine components only. Registering a distro during RunAs
        # could assign it to a different admin account supplying UAC credentials.
        $signature = Get-AuthenticodeSignature -LiteralPath $Wsl
        if ($signature.Status -ne 'Valid' -or -not $signature.SignerCertificate -or $signature.SignerCertificate.Subject -notmatch 'O=Microsoft Corporation(?:,|$)') {
            throw (Get-SetupText 'trustedWsl')
        }
        Write-SetupMessage 'machineWsl'
        $process = Start-Process -FilePath $Wsl -ArgumentList @('--install', '--no-distribution') -Verb RunAs -WindowStyle Normal -Wait -PassThru
        if ($process.ExitCode -ne 0) { return $process.ExitCode }
        $machine = Invoke-SetupCapture $Wsl @('--status')
        if ($machine.ExitCode -ne 0) { return 3010 }
    }
    Write-SetupMessage 'installWslGuide'
    # Run in this unelevated process so Ubuntu belongs to the current user.
    return Invoke-SetupInteractive $Wsl @('--install', '--distribution', 'Ubuntu-24.04')
}

function Get-SetupUid {
    param([string]$Wsl, [string]$SelectedDistro)
    $result = Invoke-SetupCapture $Wsl @('--distribution', $SelectedDistro, '--exec', 'id', '-u')
    if ($result.ExitCode -ne 0) { return $null }
    return $result.Output.Trim()
}

function Invoke-SetupFirstRun {
    param([string]$Wsl, [string]$SelectedDistro)
    # Native argv; the user interacts with the Ubuntu shell and types exit.
    return Invoke-SetupInteractive $Wsl @('--distribution', $SelectedDistro)
}

function Get-SetupBootstrapPath {
    param([string]$Wsl, [string]$SelectedDistro)
    $path = Join-Path $script:SetupRoot 'bootstrap-wsl.sh'
    if (-not (Test-Path -LiteralPath $path -PathType Leaf)) { throw 'bootstrap-wsl.sh is missing from this download.' }
    $result = Invoke-SetupCapture $Wsl @('--distribution', $SelectedDistro, '--exec', 'wslpath', '-a', '-u', $path)
    $linuxPath = $result.Output.Trim()
    if ($result.ExitCode -ne 0 -or -not $linuxPath.StartsWith('/') -or $linuxPath.Contains("`n")) { throw 'wslpath did not return one absolute script path.' }
    return $linuxPath
}

function Invoke-SetupBootstrap {
    param([string]$Wsl, [string]$SelectedDistro, [string]$ScriptPath, [switch]$Install)
    $flag = '--check'
    if ($Install) { $flag = '--install' }
    $arguments = @('--distribution', $SelectedDistro, '--exec', 'bash', $ScriptPath, $flag)
    if ($Install) { return Invoke-SetupInteractive $Wsl $arguments }
    $result = Invoke-SetupCapture $Wsl $arguments
    if ($result.Output) { Write-Host $result.Output }
    if ($result.ExitCode -eq 0 -and $result.Output -match '(?m)^BOOTSTRAP_READY=PASS\r?$') { return 0 }
    return 1
}

function Test-SetupDocker {
    param([string]$Wsl, [string]$SelectedDistro)
    # Bound a stalled daemon query; retry prompts cannot help if docker info hangs.
    $result = Invoke-SetupCapture $Wsl @('--distribution', $SelectedDistro, '--exec', '/usr/bin/timeout', '--signal=TERM', '--kill-after=5s', '30s', 'docker', 'info', '--format', '{{.ServerVersion}}')
    return $result.ExitCode -eq 0 -and -not [string]::IsNullOrWhiteSpace($result.Output)
}

function Find-SetupDockerDesktop {
    $programFiles = [Environment]::GetFolderPath('ProgramFiles')
    $candidates = @((Join-Path $programFiles 'Docker\Docker\Docker Desktop.exe'))
    if ($env:LOCALAPPDATA) { $candidates += Join-Path $env:LOCALAPPDATA 'Programs\DockerDesktop\Docker Desktop.exe' }
    foreach ($candidate in $candidates) {
        if (Test-Path -LiteralPath $candidate -PathType Leaf) { return [System.IO.Path]::GetFullPath($candidate) }
    }
    return $null
}

function Test-SetupWingetPath {
    param([string]$Path, [string]$LocalAppData, [string]$ProgramFiles)
    if (-not $Path -or -not $LocalAppData -or -not $ProgramFiles) { return $false }
    try {
        $absolute = [System.IO.Path]::GetFullPath($Path)
        $alias = [System.IO.Path]::GetFullPath((Join-Path $LocalAppData 'Microsoft\WindowsApps\winget.exe'))
        $store = [System.IO.Path]::GetFullPath((Join-Path $ProgramFiles 'WindowsApps')) + '\'
        if ($absolute.Equals($alias, [StringComparison]::OrdinalIgnoreCase)) { return $true }
        if (-not $absolute.StartsWith($store, [StringComparison]::OrdinalIgnoreCase)) { return $false }
        return $absolute.Substring($store.Length) -match '^Microsoft\.DesktopAppInstaller_[^\\]+\\winget\.exe$'
    } catch { return $false }
}

function Find-SetupWinget {
    $command = Get-Command winget.exe -CommandType Application -ErrorAction SilentlyContinue
    if (-not $command) { return $null }
    if (Test-SetupWingetPath $command.Source $env:LOCALAPPDATA ([Environment]::GetFolderPath('ProgramFiles'))) {
        return $command.Source
    }
    return $null
}

function Ensure-SetupDocker {
    param([string]$Wsl, [string]$SelectedDistro, [switch]$ReadOnly)
    if (Test-SetupDocker $Wsl $SelectedDistro) { Write-SetupMessage 'dockerReady'; return $true }
    Write-SetupMessage 'dockerNeed'
    if ($ReadOnly) { return $false }
    $desktop = Find-SetupDockerDesktop
    if (-not $desktop) {
        if (-not (Confirm-SetupAction 'dockerConsent')) { Write-SetupMessage 'canceled'; return $false }
        $winget = Find-SetupWinget
        if (-not $winget) { Write-SetupMessage 'wingetMissing'; return $false }
        $code = Invoke-SetupInteractive $winget @('install', '--id', 'Docker.DockerDesktop', '--exact', '--source', 'winget', '--interactive')
        if ($code -ne 0) { Write-SetupMessage 'dockerInstallFail'; return $false }
        $desktop = Find-SetupDockerDesktop
    }
    if ($desktop) {
        if (-not (Confirm-SetupAction 'dockerStart')) { Write-SetupMessage 'canceled'; return $false }
        Start-Process -FilePath $desktop -WindowStyle Normal | Out-Null
    } else { Write-SetupMessage 'dockerNotFound' }
    Write-SetupMessage 'dockerGuide' @($SelectedDistro)
    for ($attempt = 0; $attempt -lt 3; $attempt++) {
        $answer = Read-Host (Get-SetupText 'dockerRetry')
        if ($answer.Trim().ToLowerInvariant() -eq 'q') { return $false }
        if (Test-SetupDocker $Wsl $SelectedDistro) { Write-SetupMessage 'dockerReady'; return $true }
        Write-SetupMessage 'dockerNeed'
    }
    Write-SetupMessage 'dockerNotReady'
    return $false
}

function Invoke-SetupAdvanced {
    param([string]$SelectedDistro, [string]$SelectedWorkspace)
    $powershell = Get-SetupSystemTool 'powershell'
    if (-not $powershell) { throw 'Windows PowerShell is unavailable.' }
    $runner = Join-Path $script:SetupRoot 'windows.ps1'
    return Invoke-SetupInteractive $powershell @('-NoLogo', '-NoProfile', '-ExecutionPolicy', 'RemoteSigned', '-File', $runner, '-Action', 'Install', '-Distro', $SelectedDistro, '-Workspace', $SelectedWorkspace, '-Mode', 'documents')
}

function Invoke-SetupConnect {
    param([string]$SelectedDistro)
    $powershell = Get-SetupSystemTool 'powershell'
    $runner = Join-Path $script:SetupRoot 'windows.ps1'
    return Invoke-SetupInteractive $powershell @('-NoLogo', '-NoProfile', '-ExecutionPolicy', 'RemoteSigned', '-File', $runner, '-Action', 'Connect', '-Distro', $SelectedDistro)
}

function Invoke-SetupMain {
    param([switch]$CheckOnly, [string]$Language, [string]$Distro, [string]$Workspace)
    if (-not $Language) {
        if ($CheckOnly) { $Language = 'en' }
        else {
            $script:SetupLanguage = 'zh-TW'
            $choice = Read-Host (Get-SetupText 'chooseLanguage')
            $Language = 'zh-TW'
            if ($choice.Trim() -eq '2') { $Language = 'en' }
        }
    }
    $script:SetupLanguage = $Language
    Write-SetupMessage 'title'
    Write-SetupMessage 'installSummary'
    Write-SetupMessage 'step1'
    if ((Get-SetupArchitecture) -ne 'AMD64') {
        Write-SetupMessage 'x64'
        if ($CheckOnly) { Write-Host 'SETUP_CHECK=NEEDS_ACTION' }
        return 1
    }
    $settings = Read-SetupSettings
    $savedMode = Get-SetupSetting $settings 'mode'
    if ($savedMode -eq 'full') {
        Write-SetupMessage 'fullSettings'; Write-Host 'SETUP_PAUSED=EXISTING_FULL_MODE'
        if ($CheckOnly) { Write-Host 'SETUP_CHECK=NEEDS_ACTION' }
        return 2
    }
    if ($settings -and ($savedMode -ne 'documents' -or (Get-SetupSetting $settings 'skip_worker') -eq $true)) {
        Write-SetupMessage 'modeInvalid'
        if ($CheckOnly) { Write-Host 'SETUP_CHECK=NEEDS_ACTION' }
        return 1
    }
    if (-not $Distro) { $Distro = [string](Get-SetupSetting $settings 'distro') }
    if (-not $Workspace) { $Workspace = [string](Get-SetupSetting $settings 'workspace') }
    $wsl = Get-SetupSystemTool 'wsl'
    if (-not $wsl) { Write-SetupMessage 'wslUnavailable'; Write-Host 'SETUP_CHECK=NEEDS_ACTION'; return 2 }

    Write-SetupMessage 'step2'
    $names = @(Get-SetupDistros $wsl)
    $selected = Select-SetupDistro -Names $names -Requested $Distro -ReadOnly:$CheckOnly
    if (-not $selected) {
        if ($Distro -and ($Distro -ne 'Ubuntu-24.04' -or $settings)) {
            Write-SetupMessage 'distroMissing' @($Distro)
            if ($CheckOnly) { Write-Host 'SETUP_CHECK=NEEDS_ACTION' }
            return 2
        }
        if (-not $Distro -and @($names | Where-Object { $_ -match '^Ubuntu(?:[- ]|$)' }).Count -gt 0) {
            Write-SetupMessage 'noUbuntu'
            if ($CheckOnly) { Write-Host 'SETUP_CHECK=NEEDS_ACTION' }
            return 2
        }
        Write-SetupMessage 'needWsl'
        if ($CheckOnly) { Write-SetupMessage 'checkNeeds'; Write-Host 'SETUP_CHECK=NEEDS_ACTION'; return 2 }
        if (-not (Confirm-SetupAction 'confirmWsl')) { Write-SetupMessage 'canceled'; return 2 }
        $code = Invoke-SetupWslInstall $wsl
        if ($code -ne 0) { Write-SetupMessage 'restart'; Write-Host 'SETUP_PAUSED=WSL_SETUP'; return 2 }
        $names = @(Get-SetupDistros $wsl)
        $selected = Select-SetupDistro -Names $names -Requested 'Ubuntu-24.04' -ReadOnly
        if (-not $selected) { Write-SetupMessage 'restart'; Write-Host 'SETUP_PAUSED=WSL_SETUP'; return 2 }
    }
    Write-SetupMessage 'chosenDistro' @($selected)
    if ($CheckOnly -and (@(Get-SetupDistros $wsl -Running) -notcontains $selected)) {
        Write-SetupMessage 'stoppedCheck'; Write-Host 'SETUP_CHECK=NEEDS_ACTION'; return 2
    }
    $uid = Get-SetupUid $wsl $selected
    if (-not $uid -or $uid -notmatch '^[1-9][0-9]*$') {
        Write-SetupMessage 'needUser'
        if ($CheckOnly) { Write-SetupMessage 'checkNeeds'; Write-Host 'SETUP_CHECK=NEEDS_ACTION'; return 2 }
        if (-not (Confirm-SetupAction 'confirmUser')) { Write-SetupMessage 'canceled'; return 2 }
        $null = Invoke-SetupFirstRun $wsl $selected
        $uid = Get-SetupUid $wsl $selected
        if (-not $uid -or $uid -notmatch '^[1-9][0-9]*$') { Write-SetupMessage 'userStillRoot'; Write-Host 'SETUP_PAUSED=UBUNTU_USER'; return 2 }
    }

    Write-SetupMessage 'step3'
    $bootstrap = Get-SetupBootstrapPath $wsl $selected
    $ready = Invoke-SetupBootstrap $wsl $selected $bootstrap
    if ($ready -ne 0) {
        if ($CheckOnly) { Write-SetupMessage 'checkNeeds'; Write-Host 'SETUP_CHECK=NEEDS_ACTION'; return 2 }
        if (-not (Confirm-SetupAction 'linuxConsent')) { Write-SetupMessage 'canceled'; return 2 }
        if ((Invoke-SetupBootstrap $wsl $selected $bootstrap -Install) -ne 0 -or (Invoke-SetupBootstrap $wsl $selected $bootstrap) -ne 0) {
            Write-SetupMessage 'linuxFail'; return 1
        }
    }
    Write-SetupMessage 'linuxReady'
    Write-SetupMessage 'step4'
    if (-not (Ensure-SetupDocker $wsl $selected -ReadOnly:$CheckOnly)) {
        if ($CheckOnly) { Write-SetupMessage 'checkNeeds'; Write-Host 'SETUP_CHECK=NEEDS_ACTION' }
        return 2
    }
    if ($CheckOnly) { Write-SetupMessage 'checkReady'; Write-Host 'SETUP_CHECK=PASS'; return 0 }

    Write-SetupMessage 'step5'
    if (-not $Workspace) {
        $Workspace = Read-Host (Get-SetupText 'workspacePrompt')
        if (-not $Workspace) { $Workspace = '~/LocalWorkspace' }
    }
    Write-SetupMessage 'workspace' @($Workspace)
    if ((Invoke-SetupAdvanced $selected $Workspace) -ne 0) { Write-SetupMessage 'localFail'; return 1 }
    Write-Host 'LOCAL_INSTALL_READY=PASS'
    Write-Host 'CHATGPT_CONNECTION=NOT_CONFIGURED'
    Write-SetupMessage 'step6'
    Write-SetupMessage 'localReady'
    Write-SetupMessage 'connectGuide'
    if (Confirm-SetupAction 'connectConsent') {
        $code = Invoke-SetupConnect $selected
        Write-SetupMessage 'connectReturn'
        return $code
    }
    return 0
}

# Dot-sourcing exposes functions to offline tests without running the wizard.
if ($MyInvocation.InvocationName -ne '.') {
    try { exit (Invoke-SetupMain -CheckOnly:$CheckOnly -Language $Language -Distro $Distro -Workspace $Workspace) }
    catch {
        Write-SetupMessage 'unexpected' @($_.Exception.Message)
        if ($CheckOnly) { Write-Host 'SETUP_CHECK=NEEDS_ACTION' }
        exit 1
    }
}
