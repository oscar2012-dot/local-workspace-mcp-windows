# Offline tests for Windows PowerShell 5.1; no Pester or system changes.
Set-StrictMode -Version 2.0
$ErrorActionPreference = 'Stop'
. (Join-Path $PSScriptRoot '..\scripts\setup-windows.ps1')
$script:RealWslInstall = ${function:Invoke-SetupWslInstall}

$script:Passed = 0
$script:Calls = New-Object 'System.Collections.Generic.List[string]'
$script:Messages = New-Object 'System.Collections.Generic.List[string]'
$script:Scenario = @{}

function Assert-Setup {
    param([bool]$Condition, [string]$Because)
    if (-not $Condition) { throw ('ASSERTION FAILED: ' + $Because) }
}

function Reset-Scenario {
    $script:Calls.Clear()
    $script:Messages.Clear()
    $script:Scenario = @{
        Architecture = 'AMD64'; Settings = $null; WslAvailable = $true
        Distros = @('Ubuntu-24.04'); Running = @('Ubuntu-24.04')
        Uid = '1000'; UidAfterFirstRun = '1000'; BootstrapReady = $true
        BootstrapInstallExit = 0; BootstrapReadyAfterInstall = $true
        DockerReady = $true; DockerReadyAfterStart = $true; Desktop = $null
        Winget = 'C:\Example User\AppData\Local\Microsoft\WindowsApps\winget.exe'
        DockerInstallExit = 0; WslInstallExit = 0; AdvancedExit = 0; ConnectExit = 0
        Consents = @{}; Answers = (New-Object 'System.Collections.Generic.Queue[string]')
        LastAdvancedArgs = @(); LastWingetArgs = @()
        SignatureValid = $true; LastElevationArgs = @(); LastElevationFile = ''; LastElevationVerb = ''
        WslMachineReady = $false; WslMachineReadyAfterInstall = $true; WslMachineInstallExit = 0
    }
}

# Every process/UI/file-settings boundary below is mocked. Tests never invoke
# wsl.exe, winget.exe, Docker, elevated processes, or the real installation.
function Write-Host { param([object]$Object) $script:Messages.Add([string]$Object) }
function Write-SetupMessage { param([string]$Key, [object[]]$Values = @()) $script:Messages.Add($Key) }
function Read-Host {
    param([string]$Prompt)
    $script:Calls.Add('prompt:' + $Prompt)
    if ($script:Scenario.Answers.Count -gt 0) { return $script:Scenario.Answers.Dequeue() }
    return ''
}
function Get-SetupArchitecture { return $script:Scenario.Architecture }
function Read-SetupSettings { $script:Calls.Add('read:settings'); return $script:Scenario.Settings }
function Get-SetupSystemTool {
    param([string]$Name)
    if ($Name -eq 'wsl') {
        if (-not $script:Scenario.WslAvailable) { return $null }
        return 'C:\Windows\System32\wsl.exe'
    }
    return 'C:\Windows\System32\WindowsPowerShell\v1.0\powershell.exe'
}
function Confirm-SetupAction {
    param([string]$Key)
    $script:Calls.Add('consent:' + $Key)
    return $script:Scenario.Consents.ContainsKey($Key) -and $script:Scenario.Consents[$Key]
}
function Get-SetupBootstrapPath {
    param([string]$Wsl, [string]$SelectedDistro)
    return '/mnt/c/Example User/source with spaces/scripts/bootstrap-wsl.sh'
}
function Invoke-SetupCapture {
    param([string]$FilePath, [string[]]$Arguments)
    $script:Calls.Add('read:' + ($Arguments -join '|'))
    if ($Arguments -contains '--status') {
        $code = 1
        if ($script:Scenario.WslMachineReady) { $code = 0 }
        return [pscustomobject]@{ ExitCode = $code; Output = '' }
    }
    if ($Arguments -contains '--list') {
        $names = $script:Scenario.Distros
        if ($Arguments -contains '--running') { $names = $script:Scenario.Running }
        return [pscustomobject]@{ ExitCode = 0; Output = ($names -join "`n") }
    }
    if ($Arguments -contains 'id') { return [pscustomobject]@{ ExitCode = 0; Output = $script:Scenario.Uid } }
    if ($Arguments -contains '--check') {
        if ($script:Scenario.BootstrapReady) { return [pscustomobject]@{ ExitCode = 0; Output = 'BOOTSTRAP_READY=PASS' } }
        return [pscustomobject]@{ ExitCode = 1; Output = 'BOOTSTRAP_READY=NOT_READY' }
    }
    if ($Arguments -contains 'docker') {
        if ($script:Scenario.DockerReady) { return [pscustomobject]@{ ExitCode = 0; Output = '28.0.0' } }
        return [pscustomobject]@{ ExitCode = 1; Output = '' }
    }
    throw ('Unexpected capture: ' + ($Arguments -join ' '))
}
function Invoke-SetupInteractive {
    param([string]$FilePath, [string[]]$Arguments)
    if ($Arguments -contains '--install' -and $Arguments -contains 'bash') {
        $script:Calls.Add('install:linux')
        $script:Scenario.BootstrapReady = $script:Scenario.BootstrapReadyAfterInstall
        return $script:Scenario.BootstrapInstallExit
    }
    if (($Arguments -join '|') -eq '--install|--distribution|Ubuntu-24.04') {
        $script:Calls.Add('install:distro-current-user')
        return $script:Scenario.WslInstallExit
    }
    if ($Arguments -contains 'Docker.DockerDesktop') {
        $script:Calls.Add('install:docker')
        $script:Scenario.LastWingetArgs = $Arguments
        if ($script:Scenario.DockerInstallExit -eq 0) { $script:Scenario.Desktop = 'C:\Program Files\Docker\Docker\Docker Desktop.exe' }
        return $script:Scenario.DockerInstallExit
    }
    if ($Arguments -contains '-Action') {
        if ($Arguments -contains 'Install') {
            $script:Calls.Add('advanced:install')
            $script:Scenario.LastAdvancedArgs = $Arguments
            return $script:Scenario.AdvancedExit
        }
        if ($Arguments -contains 'Connect') { $script:Calls.Add('connect:start'); return $script:Scenario.ConnectExit }
    }
    if ($Arguments.Count -eq 2 -and $Arguments[0] -eq '--distribution') {
        $script:Calls.Add('first-run:ubuntu')
        $script:Scenario.Uid = $script:Scenario.UidAfterFirstRun
        return 0
    }
    throw ('Unexpected interactive call: ' + ($Arguments -join ' '))
}
function Invoke-SetupWslInstall {
    param([string]$Wsl)
    $script:Calls.Add('install:wsl')
    if ($script:Scenario.WslInstallExit -eq 0) { $script:Scenario.Distros = @('Ubuntu-24.04') }
    return $script:Scenario.WslInstallExit
}
function Find-SetupDockerDesktop { return $script:Scenario.Desktop }
function Find-SetupWinget { return $script:Scenario.Winget }
function Get-AuthenticodeSignature {
    param([string]$LiteralPath)
    $status = 'Valid'
    if (-not $script:Scenario.SignatureValid) { $status = 'NotSigned' }
    return [pscustomobject]@{ Status = $status; SignerCertificate = [pscustomobject]@{ Subject = 'CN=Microsoft Windows, O=Microsoft Corporation, C=US' } }
}
function Start-Process {
    param([string]$FilePath, [string]$WindowStyle, [string[]]$ArgumentList, [string]$Verb, [switch]$Wait, [switch]$PassThru)
    if ($FilePath -eq 'C:\Windows\System32\wsl.exe') {
        $script:Calls.Add('elevate:wsl')
        $script:Scenario.LastElevationFile = $FilePath
        $script:Scenario.LastElevationArgs = $ArgumentList
        $script:Scenario.LastElevationVerb = $Verb
        $script:Scenario.WslMachineReady = $script:Scenario.WslMachineReadyAfterInstall
        return [pscustomobject]@{ ExitCode = $script:Scenario.WslMachineInstallExit }
    }
    if ($FilePath -notlike '*Docker Desktop.exe') { throw 'Unexpected process in offline test' }
    $script:Calls.Add('start:docker')
    $script:Scenario.DockerReady = $script:Scenario.DockerReadyAfterStart
}

function Test-NoMutations {
    $mutations = @($script:Calls | Where-Object { $_ -match '^(install:|start:|advanced:|connect:|first-run:|consent:|prompt:)' })
    Assert-Setup ($mutations.Count -eq 0) ('Read-only/paused flow performed an action: ' + ($mutations -join ', '))
}

function Complete-Case {
    param([string]$Name)
    $script:Passed++
    [Console]::WriteLine('PASS ' + $Name)
}

Reset-Scenario
$code = Invoke-SetupMain -CheckOnly -Language en
Assert-Setup ($code -eq 0) 'Ready CheckOnly should succeed'
Assert-Setup ($script:Messages -contains 'SETUP_CHECK=PASS') 'CheckOnly success marker missing'
Test-NoMutations
Complete-Case 'CheckOnly has no installations, downloads, prompts or writes'

Reset-Scenario
$script:Scenario.Running = @()
$code = Invoke-SetupMain -CheckOnly -Language en
Assert-Setup ($code -eq 2) 'Stopped WSL should need action'
Assert-Setup (-not (@($script:Calls | Where-Object { $_ -match '\|--exec\|' }).Count)) 'CheckOnly must not start a stopped distribution'
Test-NoMutations
Complete-Case 'CheckOnly leaves stopped WSL stopped'

Reset-Scenario
$script:Scenario.BootstrapReady = $false
$code = Invoke-SetupMain -CheckOnly -Language en
Assert-Setup ($code -eq 2) 'Missing dependencies should need action'
Test-NoMutations
Complete-Case 'CheckOnly does not install missing dependencies'

Reset-Scenario
$script:Scenario.DockerReady = $false
$code = Invoke-SetupMain -CheckOnly -Language en
Assert-Setup ($code -eq 2) 'Missing Docker should need action'
Test-NoMutations
Complete-Case 'CheckOnly does not install or start Docker'

Reset-Scenario
$script:Scenario.Architecture = 'ARM64'
$code = Invoke-SetupMain -CheckOnly -Language en
Assert-Setup ($code -eq 1) 'Unsupported architecture should fail'
Assert-Setup ($script:Messages -contains 'SETUP_CHECK=NEEDS_ACTION') 'CheckOnly needs-action marker missing'
Test-NoMutations
Complete-Case 'Unsupported architecture has a consistent diagnostic marker'

Reset-Scenario
$script:Scenario.Settings = [pscustomobject]@{ mode = 'full'; distro = 'Ubuntu'; workspace = '~/Existing'; skip_worker = $true }
$code = Invoke-SetupMain -Language en
Assert-Setup ($code -eq 2) 'Existing full installation should be preserved'
Assert-Setup ($script:Messages -contains 'SETUP_PAUSED=EXISTING_FULL_MODE') 'Full-mode pause marker missing'
Test-NoMutations
Complete-Case 'Existing full configuration is preserved before any bootstrap'

Reset-Scenario
$script:Scenario.Settings = [pscustomobject]@{ mode = 'documents'; distro = 'Ubuntu-24.04'; workspace = '/mnt/c/Example User/Existing Workspace'; skip_worker = $false }
$code = Invoke-SetupMain -Language en
Assert-Setup ($code -eq 0) 'Ready saved documents installation should succeed'
Assert-Setup ($script:Scenario.LastAdvancedArgs -contains '/mnt/c/Example User/Existing Workspace') 'Saved workspace must be forwarded as one argument'
Assert-Setup ($script:Scenario.LastAdvancedArgs -contains 'documents') 'Wizard must explicitly use documents mode'
Assert-Setup ($script:Messages -contains 'LOCAL_INSTALL_READY=PASS') 'Local installation marker missing'
Assert-Setup ($script:Messages -contains 'CHATGPT_CONNECTION=NOT_CONFIGURED') 'Account configuration must remain distinct'
Assert-Setup ($script:Calls -notcontains 'connect:start') 'Connect requires separate consent'
Complete-Case 'Ready setup preserves saved choices and reports local-only success'

Reset-Scenario
$script:Scenario.Settings = [pscustomobject]@{ mode = 'documents'; distro = 'Ubuntu-22.04'; workspace = '~/Existing'; skip_worker = $false }
$code = Invoke-SetupMain -Language en
Assert-Setup ($code -eq 2) 'Missing saved distro should stop'
Test-NoMutations
Complete-Case 'Missing saved distribution is not silently replaced'

Reset-Scenario
$script:Scenario.Distros = @('Ubuntu-22.04', 'Ubuntu-26.04')
$script:Scenario.Answers.Enqueue('999')
$code = Invoke-SetupMain -Language en
Assert-Setup ($code -eq 2) 'Invalid distribution menu selection should pause'
Assert-Setup ($script:Calls -notcontains 'consent:confirmWsl') 'Invalid selection must not offer a different installation'
Assert-Setup ($script:Calls -notcontains 'install:wsl') 'Invalid selection must not install WSL'
Complete-Case 'Invalid distribution choice cannot fall through to installation'

Reset-Scenario
$script:Scenario.BootstrapReady = $false
$code = Invoke-SetupMain -Language en -Workspace '~/LocalWorkspace'
Assert-Setup ($code -eq 2) 'Declined Linux prerequisites should pause'
Assert-Setup ($script:Calls -notcontains 'install:linux') 'No Linux installation without consent'
Assert-Setup ($script:Calls -notcontains 'advanced:install') 'No MCP installation after prerequisite refusal'
Complete-Case 'Linux prerequisite installation requires consent'

Reset-Scenario
$script:Scenario.BootstrapReady = $false
$script:Scenario.Consents['linuxConsent'] = $true
$code = Invoke-SetupMain -Language en -Workspace '~/LocalWorkspace'
Assert-Setup ($code -eq 0) 'Approved successful bootstrap should continue'
Assert-Setup ($script:Calls -contains 'install:linux') 'Approved Linux install was not run'
Assert-Setup (@($script:Calls | Where-Object { $_ -match '\|--check$' }).Count -eq 2) 'Bootstrap must be rechecked after installation'
Complete-Case 'Approved Linux installation is checked again before continuing'

Reset-Scenario
$script:Scenario.BootstrapReady = $false
$script:Scenario.Consents['linuxConsent'] = $true
$script:Scenario.BootstrapInstallExit = 1
$code = Invoke-SetupMain -Language en -Workspace '~/LocalWorkspace'
Assert-Setup ($code -eq 1) 'Failed prerequisite install should fail'
Assert-Setup ($script:Calls -notcontains 'advanced:install') 'Failed bootstrap must not reach MCP installation'
Complete-Case 'Linux bootstrap failure stops the workflow'

Reset-Scenario
$script:Scenario.Distros = @()
$script:Scenario.Consents['confirmWsl'] = $true
$script:Scenario.WslInstallExit = 3010
$code = Invoke-SetupMain -Language en
Assert-Setup ($code -eq 2) 'A restart request should pause'
Assert-Setup ($script:Calls -contains 'install:wsl') 'Consented WSL installation missing'
Assert-Setup ($script:Messages -contains 'SETUP_PAUSED=WSL_SETUP') 'WSL pause marker missing'
Assert-Setup ($script:Calls -notcontains 'advanced:install') 'Restart must not be treated as ready'
Complete-Case 'Restart-needed WSL installation pauses without auto reboot'

Reset-Scenario
$script:Scenario.Uid = '0'
$script:Scenario.Consents['confirmUser'] = $true
$code = Invoke-SetupMain -Language en -Workspace '~/LocalWorkspace'
Assert-Setup ($code -eq 0) 'User initialization should be checked again'
Assert-Setup ($script:Calls -contains 'first-run:ubuntu') 'Interactive Ubuntu user setup missing'
Complete-Case 'Ubuntu first-run remains interactive and is rechecked'

Reset-Scenario
$script:Scenario.DockerReady = $false
$script:Scenario.Consents['dockerConsent'] = $true
$script:Scenario.Consents['dockerStart'] = $true
$code = Invoke-SetupMain -Language en -Workspace '~/LocalWorkspace'
Assert-Setup ($code -eq 0) 'Approved Docker setup should continue once ready'
Assert-Setup ($script:Scenario.LastWingetArgs -contains '--interactive') 'Docker installer must stay interactive'
Assert-Setup ($script:Scenario.LastWingetArgs -notcontains '--accept-package-agreements') 'No automatic package agreement acceptance'
Assert-Setup ($script:Scenario.LastWingetArgs -notcontains '--accept-source-agreements') 'No automatic source agreement acceptance'
Assert-Setup ($script:Scenario.LastWingetArgs -contains 'Docker.DockerDesktop') 'Wrong Docker package'
Complete-Case 'Docker installation retains visible agreements and explicit consent'

Reset-Scenario
$script:Scenario.DockerReady = $false
$script:Scenario.DockerReadyAfterStart = $false
$script:Scenario.Desktop = 'C:\Program Files\Docker\Docker\Docker Desktop.exe'
$script:Scenario.Consents['dockerStart'] = $true
$code = Invoke-SetupMain -Language en -Workspace '~/LocalWorkspace'
Assert-Setup ($code -eq 2) 'Docker integration not ready should pause'
Assert-Setup (@($script:Calls | Where-Object { $_ -match '^prompt:' }).Count -eq 3) 'Docker retries must be bounded'
Assert-Setup ($script:Calls -notcontains 'advanced:install') 'Unavailable Docker must not reach installation'
$dockerQueries = @($script:Calls | Where-Object { $_ -match '\|docker\|info\|' })
Assert-Setup ($dockerQueries.Count -eq 4) 'Initial Docker check plus three retries expected'
foreach ($query in $dockerQueries) {
    Assert-Setup ($query -match '\|--exec\|/usr/bin/timeout\|--signal=TERM\|--kill-after=5s\|30s\|docker\|info\|') 'Each Docker daemon query must have a 30-second timeout and 5-second kill grace'
}
Complete-Case 'Docker integration retries are bounded'

Reset-Scenario
$script:Scenario.AdvancedExit = 1
$code = Invoke-SetupMain -Language en -Workspace '~/LocalWorkspace'
Assert-Setup ($code -eq 1) 'MCP verification failure should fail setup'
Assert-Setup ($script:Messages -notcontains 'LOCAL_INSTALL_READY=PASS') 'Failed verification must not report local success'
Complete-Case 'MCP failure cannot emit a success marker'

Reset-Scenario
$script:Scenario.Consents['connectConsent'] = $true
$code = Invoke-SetupMain -Language en -Workspace '~/LocalWorkspace'
Assert-Setup ($code -eq 0) 'Explicit connection should return its result'
Assert-Setup ($script:Calls -contains 'connect:start') 'Explicit Connect consent was not followed'
Complete-Case 'Connect starts only after its separate explicit choice'

if ([Environment]::OSVersion.Platform -eq [PlatformID]::Win32NT) {
    Reset-Scenario
    Assert-Setup (Test-SetupWingetPath 'C:\Example User\AppData\Local\Microsoft\WindowsApps\winget.exe' 'C:\Example User\AppData\Local' 'C:\Program Files') 'Official execution alias should be accepted'
    Assert-Setup (-not (Test-SetupWingetPath 'C:\Untrusted\winget.exe' 'C:\Example User\AppData\Local' 'C:\Program Files')) 'Untrusted PATH replacement must be refused'
    Assert-Setup (-not (Test-SetupWingetPath 'C:\Program Files\WindowsApps\UnknownPackage\winget.exe' 'C:\Example User\AppData\Local' 'C:\Program Files')) 'Unrelated Store package must be refused'
    Complete-Case 'winget source path validation rejects unrelated executables'
} else { [Console]::WriteLine('SKIP Windows-native winget path semantics (non-Windows host)') }

Reset-Scenario
$code = & $script:RealWslInstall 'C:\Windows\System32\wsl.exe'
Assert-Setup ($code -eq 0) 'Validated system WSL should reach the mocked UAC call'
Assert-Setup ($script:Scenario.LastElevationVerb -eq 'RunAs') 'WSL should request UAC only for explicit installation'
Assert-Setup (($script:Scenario.LastElevationArgs -join '|') -eq '--install|--no-distribution') 'Elevation must install only machine WSL components'
Assert-Setup ($script:Calls -contains 'install:distro-current-user') 'Ubuntu must install in the current unelevated user process'
Assert-Setup ($script:Calls.IndexOf('elevate:wsl') -lt $script:Calls.IndexOf('install:distro-current-user')) 'Machine readiness must precede current-user distro installation'
Complete-Case 'Only WSL machine components elevate; Ubuntu registration stays in the current account'

Reset-Scenario
$script:Scenario.WslMachineReady = $true
$code = & $script:RealWslInstall 'C:\Windows\System32\wsl.exe'
Assert-Setup ($code -eq 0) 'Ready machine WSL should allow current-user Ubuntu installation'
Assert-Setup ($script:Calls -notcontains 'elevate:wsl') 'Existing working WSL must not be elevated unnecessarily'
Assert-Setup ($script:Calls -contains 'install:distro-current-user') 'Ubuntu still needs current-user registration'
Complete-Case 'Existing WSL skips machine elevation'

Reset-Scenario
$script:Scenario.WslMachineInstallExit = 3010
$code = & $script:RealWslInstall 'C:\Windows\System32\wsl.exe'
Assert-Setup ($code -eq 3010) 'Machine restart requirement should be preserved'
Assert-Setup ($script:Calls -notcontains 'install:distro-current-user') 'Ubuntu registration must wait until machine WSL is ready'
Complete-Case 'Machine restart requirement postpones user distro registration'

Reset-Scenario
$refused = $false
try { $null = & $script:RealWslInstall 'C:\Untrusted\wsl.exe' } catch { $refused = $true }
Assert-Setup $refused 'Untrusted WSL executable must be refused'
Assert-Setup ($script:Calls -notcontains 'elevate:wsl') 'Untrusted path must not elevate'
$script:Scenario.SignatureValid = $false
$refused = $false
try { $null = & $script:RealWslInstall 'C:\Windows\System32\wsl.exe' } catch { $refused = $true }
Assert-Setup $refused 'Unsigned WSL executable must be refused'
Assert-Setup ($script:Calls -notcontains 'elevate:wsl') 'Invalid signature must not elevate'
Complete-Case 'Untrusted or unsigned WSL cannot trigger elevation'

[Console]::WriteLine(('SETUP_OFFLINE_TESTS=PASS ({0} cases)' -f $script:Passed))
exit 0
