# ASCII source for Windows PowerShell 5.1. Runtime data is UTF-8.
[CmdletBinding()]
param(
    [Parameter(Mandatory = $true)]
    [ValidateSet('Install', 'Connect', 'Status', 'Verify')]
    [string]$Action,
    [string]$Distro,
    [string]$Workspace,
    [ValidateSet('documents', 'full')]
    [string]$Mode = 'documents',
    [switch]$AcceptFullPermissions,
    [switch]$SkipWorker,
    [string]$State,
    [string]$TunnelId,
    [switch]$ReplaceKey,
    [switch]$InstallWSL
)
Set-StrictMode -Version 2.0
$ErrorActionPreference = 'Stop'

function Invoke-WslChecked {
    param([Parameter(Mandatory = $true)][string[]]$Arguments)
    # PowerShell 5.1 may present native stderr as an ErrorRecord. A warning on
    # stderr is not a failed command: decide success only from the exit code.
    $previousPreference = $ErrorActionPreference
    try {
        $ErrorActionPreference = 'Continue'
        & $script:WslCommand @Arguments
        $nativeExitCode = $LASTEXITCODE
    } finally {
        $ErrorActionPreference = $previousPreference
    }
    if ($nativeExitCode -ne 0) {
        throw "WSL command failed (exit $nativeExitCode). See the output above."
    }
}

function Convert-ToWslPath {
    param([Parameter(Mandatory = $true)][string]$WindowsPath)
    $absolute = [System.IO.Path]::GetFullPath($WindowsPath)
    $lines = @(Invoke-WslChecked -Arguments @('--distribution', $script:SelectedDistro, '--exec', 'wslpath', '-a', '-u', $absolute))
    if ($lines.Count -ne 1 -or -not ([string]$lines[0]).StartsWith('/')) {
        throw 'wslpath did not return one absolute Linux path.'
    }
    return ([string]$lines[0]).Trim()
}

try {
    $architecture = $env:PROCESSOR_ARCHITECTURE
    if ($env:PROCESSOR_ARCHITEW6432) { $architecture = $env:PROCESSOR_ARCHITEW6432 }
    if ($architecture -ne 'AMD64') { throw 'This release supports Windows x64 only.' }
    if ($InstallWSL -and $Action -ne 'Install') { throw '-InstallWSL is only valid for Install.' }
    if ($SkipWorker -and ($Action -ne 'Install' -or $Mode -ne 'full')) {
        throw '-SkipWorker requires Install -Mode full -AcceptFullPermissions.'
    }
    if ($Action -eq 'Install' -and $Mode -eq 'full' -and -not $AcceptFullPermissions) {
        throw 'Full mode can run commands and access files with your WSL account permissions. Rerun with -Mode full -AcceptFullPermissions only if you accept this access.'
    }
    if (($TunnelId -or $ReplaceKey) -and $Action -ne 'Connect') {
        throw '-TunnelId and -ReplaceKey are only valid for Connect.'
    }

    $wslInfo = Get-Command wsl.exe -ErrorAction SilentlyContinue
    if (-not $wslInfo) {
        throw 'WSL is not available. Install Windows Subsystem for Linux from Microsoft, then run Install.cmd -InstallWSL. See README.md.'
    }
    $script:WslCommand = $wslInfo.Source
    if ($InstallWSL) {
        $installDistro = 'Ubuntu-24.04'
        if ($Distro) { $installDistro = $Distro }
        Write-Host "Installing WSL distribution $installDistro by explicit request. Windows may require administrator access or a restart."
        Invoke-WslChecked -Arguments @('--install', '--distribution', $installDistro)
        Write-Host 'Finish Ubuntu first-run setup, create a non-root default user, and prepare prerequisites before running Install.cmd again.'
        exit 0
    }

    if (-not $env:LOCALAPPDATA) { throw 'LOCALAPPDATA is unavailable.' }
    $settingsDirectory = Join-Path $env:LOCALAPPDATA 'LocalWorkspaceMCPWindows'
    $settingsPath = Join-Path $settingsDirectory 'settings.json'
    $settings = $null
    if (Test-Path -LiteralPath $settingsPath) {
        $settings = Get-Content -LiteralPath $settingsPath -Raw -Encoding UTF8 | ConvertFrom-Json
        if (-not $Distro -and $settings.PSObject.Properties['distro']) { $Distro = [string]$settings.distro }
        if (-not $State -and $settings.PSObject.Properties['state']) { $State = [string]$settings.state }
        if ($Action -eq 'Install' -and -not $Workspace -and $settings.PSObject.Properties['workspace']) {
            $Workspace = [string]$settings.workspace
        }
    }
    if (-not $State) { $State = '~/.local/state/local-workspace-mcp-windows' }
    if (-not ($State.StartsWith('/') -or $State.StartsWith('~/'))) {
        throw '-State must be a Linux absolute path or a ~/ path on the private WSL filesystem.'
    }

    $availableDistros = @(Invoke-WslChecked -Arguments @('--list', '--quiet') |
        ForEach-Object { ([string]$_).Replace([string][char]0, '').Trim() } |
        Where-Object { $_ })
    if ($availableDistros.Count -eq 0) {
        throw 'No WSL distribution is installed. Explicitly run Install.cmd -InstallWSL, finish Ubuntu setup, then rerun Install.cmd.'
    }
    if (-not $Distro) {
        if ($availableDistros -contains 'Ubuntu-24.04') { $Distro = 'Ubuntu-24.04' }
        elseif ($availableDistros.Count -eq 1) { $Distro = $availableDistros[0] }
        else {
            Write-Host 'Installed WSL distributions:'
            for ($i = 0; $i -lt $availableDistros.Count; $i++) { Write-Host ("  {0}: {1}" -f ($i + 1), $availableDistros[$i]) }
            $choice = Read-Host 'Select a distribution number (Ubuntu 24.04 or newer recommended)'
            $index = 0
            if (-not [int]::TryParse($choice, [ref]$index) -or $index -lt 1 -or $index -gt $availableDistros.Count) {
                throw 'Invalid distribution choice. You can also pass -Distro with an installed distribution name.'
            }
            $Distro = $availableDistros[$index - 1]
        }
    }
    if ($availableDistros -notcontains $Distro) { throw "Distribution '$Distro' is not installed. Use wsl --list --quiet to see names." }
    $script:SelectedDistro = $Distro
    $userId = @(Invoke-WslChecked -Arguments @('--distribution', $Distro, '--exec', 'id', '-u'))
    if ($userId.Count -ne 1 -or ([string]$userId[0]).Trim() -notmatch '^[1-9][0-9]*$') {
        throw 'The selected distribution needs a non-root default user. Complete Ubuntu user setup and configure that default user first.'
    }
    $scriptDirectory = Convert-ToWslPath -WindowsPath $PSScriptRoot
    $wslPrefix = @('--distribution', $Distro, '--exec')
    if ($Action -eq 'Install') {
        if ($Workspace -and -not ($Workspace.StartsWith('/') -or $Workspace.StartsWith('~/'))) {
            $Workspace = Convert-ToWslPath -WindowsPath $Workspace
        }
        $arguments = $wslPrefix + @('bash', "$scriptDirectory/install-wsl.sh", '--state', $State, '--mode', $Mode)
        if ($Workspace) { $arguments += @('--workspace', $Workspace) }
        if ($AcceptFullPermissions) { $arguments += '--accept-full-permissions' }
        if ($SkipWorker) { $arguments += '--skip-worker' }
        Invoke-WslChecked -Arguments $arguments
        # Save only non-secret choices after installation and verification succeed.
        New-Item -ItemType Directory -Force -Path $settingsDirectory | Out-Null
        $saved = [ordered]@{ distro = $Distro; state = $State; workspace = $Workspace; mode = $Mode; skip_worker = [bool]$SkipWorker }
        $utf8 = New-Object System.Text.UTF8Encoding($false)
        [System.IO.File]::WriteAllText($settingsPath, ($saved | ConvertTo-Json) + [Environment]::NewLine, $utf8)
        Write-Host "Saved non-secret Windows settings to $settingsPath"
    } elseif ($Action -eq 'Verify') {
        Invoke-WslChecked -Arguments ($wslPrefix + @('python3', "$scriptDirectory/verify_mcp.py", '--state', $State))
    } else {
        $arguments = $wslPrefix + @('python3', "$scriptDirectory/tunnel.py", '--state', $State)
        if ($Action -eq 'Status') { $arguments += '--status' }
        if ($TunnelId) { $arguments += @('--tunnel-id', $TunnelId) }
        if ($ReplaceKey) { $arguments += '--replace-key' }
        Invoke-WslChecked -Arguments $arguments
    }
    exit 0
} catch {
    [Console]::Error.WriteLine($_.Exception.Message)
    exit 1
}
