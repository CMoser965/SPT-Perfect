<#
.SYNOPSIS
    Complete automated installer for SPT, Fika, and Mods.
#>

param (
    [string]$LiveTarkovPath = "C:\Battlestate Games\Escape from Tarkov",
    [string]$InstallPath,
    [string]$PatcherUrl = "https://spt-legacy.modd.in/Patcher_1.0.1.1.42751_to_16.1.3.35392.7z",
    [string]$SptUrl = "https://github.com/sp-tarkov/build/releases/download/3.11.4/SPT-3.11.4-35392-96e5b73.7z",
    [string]$FikaInstallerUrl = "https://github.com/project-fika/Fika-Installer/releases/download/1.1.3/Fika-Installer.exe",
    [string]$ModsUrl = "https://drive.usercontent.google.com/download?id=1N_yhNEqL8Xm1_KCU3knIwpkL-C4tPemf&export=download&authuser=0&confirm=t&uuid=17b304a6-bf1b-4988-82f7-98c9b2492be4&at=APcXIO1sStdVreJhaEHcKBuM_qxg:1769989445011",
    [string]$ConfigsUrl = "https://drive.google.com/uc?export=download&id=17mDmdyTOGniPY8eVdla_3KbKTfFAYOew"
)

$ErrorActionPreference = "Stop"

function Write-Log {
    param([string]$Message)
    Write-Host "[$((Get-Date).ToString('HH:mm:ss'))] $Message" -ForegroundColor Cyan
}

# --- PRE-CHECKS & SETUP ---

# Select Install Path if not provided
if ([string]::IsNullOrWhiteSpace($InstallPath)) {
    Write-Log "Prompting for installation directory..."
    Add-Type -AssemblyName System.Windows.Forms
    $FolderBrowser = New-Object System.Windows.Forms.FolderBrowserDialog
    $FolderBrowser.Description = "Select the folder where you want to install SPT-Fika-Mods"
    $FolderBrowser.ShowNewFolderButton = $true

    if ($FolderBrowser.ShowDialog() -eq [System.Windows.Forms.DialogResult]::OK) {
        $InstallPath = $FolderBrowser.SelectedPath
        Write-Log "Installation Path selected: $InstallPath"
    } else {
        Write-Error "No directory selected. Installation cancelled."
        exit 1
    }
}

# Check for 7-Zip
$7zPath = "$env:ProgramFiles\7-Zip\7z.exe"
if (-not (Test-Path $7zPath)) {
    if (Get-Command "7z" -ErrorAction SilentlyContinue) {
        $7zPath = "7z"
    } else {
        Write-Error "7-Zip not found. Please install 7-Zip."
        exit 1
    }
}

# 1. Create Folder
if (-not (Test-Path $InstallPath)) {
    Write-Log "Creating installation directory: $InstallPath"
    New-Item -ItemType Directory -Path $InstallPath | Out-Null
}

# --- SPT & FIKA INSTALLATION ---

# 2. Copy Tarkov game dir into new folder
if (-not (Test-Path "$InstallPath\EscapeFromTarkov.exe")) {
    Write-Log "Copying Live Tarkov files (This may take a while)..."
    $roboArgs = @("`"$LiveTarkovPath`"", "`"$InstallPath`"", "/E", "/XO", "/NFL", "/NDL", "/NJH", "/NJS")
    Start-Process -FilePath "robocopy" -ArgumentList $roboArgs -Wait -NoNewWindow
    Write-Log "Copy complete."
} else {
    Write-Log "Game files appear to already exist in destination. Skipping copy."
}

# 3. Patcher Download + extract + run patcher.exe
$PatcherArchive = Join-Path $InstallPath "Patcher.7z"
$PatcherExe = Join-Path $InstallPath "Patcher.exe"

if (-not (Test-Path $PatcherExe)) {
    Write-Log "Downloading Patcher..."
    Start-BitsTransfer -Source $PatcherUrl -Destination $PatcherArchive

    Write-Log "Extracting Patcher..."
    $extractArgs = @("x", "`"$PatcherArchive`"", "-o`"$InstallPath`"", "-y")
    Start-Process -FilePath $7zPath -ArgumentList $extractArgs -Wait -NoNewWindow
    
    Remove-Item $PatcherArchive -Force
}

Write-Log "Running Patcher.exe..."
Write-Warning "Please interact with the Patcher window if prompted."
Start-Process -FilePath $PatcherExe -WorkingDirectory $InstallPath -Wait

# 4. Download SPT, extract into root
$SptArchive = Join-Path $InstallPath "SPT.7z"
if (-not (Test-Path (Join-Path $InstallPath "SPT.Launcher.exe"))) {
    Write-Log "Downloading SPT..."
    Start-BitsTransfer -Source $SptUrl -Destination $SptArchive

    Write-Log "Extracting SPT..."
    $extractArgs = @("x", "`"$SptArchive`"", "-o`"$InstallPath`"", "-y")
    Start-Process -FilePath $7zPath -ArgumentList $extractArgs -Wait -NoNewWindow
    
    Remove-Item $SptArchive -Force
}

# 5. Copy Fika installer to directory root (Download)
$FikaExe = Join-Path $InstallPath "Fika-Installer.exe"
Write-Log "Downloading Fika Installer..."
Start-BitsTransfer -Source $FikaInstallerUrl -Destination $FikaExe

# 6. Run installer, choose option 1
Write-Log "Running Fika Installer..."
Write-Warning "Please manually select option '1' (Install SPT + Fika) in the installer window."

Push-Location -Path $InstallPath
try {
    Start-Process -FilePath ".\Fika-Installer.exe" -Wait
} finally {
    Pop-Location
}

# 7. Run the SPT.Server file
Write-Log "Running SPT Server to initialize files..."
Write-Warning "Please wait for the server to finish loading (look for 'Server is running'), then CLOSE the server window to proceed."
$ServerExe = Join-Path $InstallPath "SPT.Server.exe"
Start-Process -FilePath $ServerExe -WorkingDirectory $InstallPath -Wait

# 8. JSON edit for IPConfig (Fika)
$FikaConfigPath = Join-Path $InstallPath "user\mods\fika-server\assets\configs\fika.jsonc"

if (Test-Path $FikaConfigPath) {
    $UserIP = Read-Host "Enter the IP address for Fika (Default: 0.0.0.0)"
    if ([string]::IsNullOrWhiteSpace($UserIP)) {
        $UserIP = "0.0.0.0"
    }
    Write-Log "Configuring fika.jsonc ($UserIP)..."
    try {
        $content = Get-Content $FikaConfigPath -Raw
        $newContent = $content -replace '("ip":\s*")(.+?)(")', ('${1}' + $UserIP + '${3}')
        $newContent = $newContent -replace '("backendIp":\s*")(.+?)(")', ('${1}' + $UserIP + '${3}')
        
        if ($content -ne $newContent) {
            Set-Content -Path $FikaConfigPath -Value $newContent -Encoding UTF8
            Write-Log "IP configuration updated in fika.jsonc."
        } else {
            Write-Log "IP already configured correctly."
        }
    } catch {
        Write-Error "Failed to update fika.jsonc. $_"
    }
} else {
    Write-Warning "fika.jsonc not found at $FikaConfigPath."
}

# --- MOD INSTALLATION ---

# 9. Download mods.7z
$ModsArchive = Join-Path $InstallPath "mods.7z"
Write-Log "Downloading mods.7z..."
$OldProgress = $ProgressPreference
$ProgressPreference = 'SilentlyContinue'
try {
    Invoke-WebRequest -Uri $ModsUrl -OutFile $ModsArchive -UseBasicParsing
} catch {
    Write-Warning "Automatic download failed. You may need to download mods.7z manually."
} finally {
    $ProgressPreference = $OldProgress
}

if (-not (Test-Path $ModsArchive) -or (Get-Item $ModsArchive).Length -lt 1000000) {
    Write-Error "mods.7z failed to download correctly. Please download it manually."
    exit 1
}

# 10. Download configs.7z
$ConfigsArchive = Join-Path $InstallPath "configs.7z"
Write-Log "Downloading configs.7z..."
$OldProgress = $ProgressPreference
$ProgressPreference = 'SilentlyContinue'
try {
    Invoke-WebRequest -Uri $ConfigsUrl -OutFile $ConfigsArchive -UseBasicParsing
} catch {
    $ProgressPreference = $OldProgress
    Write-Error "Failed to download configs.7z. $_"
    exit 1
} finally {
    $ProgressPreference = $OldProgress
}

# 11. Extract mods and configs
Write-Log "Extracting mods..."
$extractArgs = @("x", "`"$ModsArchive`"", "-o`"$InstallPath`"", "-y")
Start-Process -FilePath $7zPath -ArgumentList $extractArgs -Wait -NoNewWindow

Write-Log "Extracting configs..."
$extractArgs = @("x", "`"$ConfigsArchive`"", "-o`"$InstallPath`"", "-y")
Start-Process -FilePath $7zPath -ArgumentList $extractArgs -Wait -NoNewWindow

# 12. Copy configs
Write-Log "Copying configuration files..."
$RepoRoot = $InstallPath

$FileMappings = @{
    "configs\questing_bots_config\config.json" = "user\mods\DanW-SPTQuestingBots\config\config.json"
    "configs\realism_config\config.json"       = "user\mods\SPT-Realism\config\config.json"
    "configs\svm_config\MainProfile.json"      = "user\mods\[SVM] Server Value Modifier\Presets\MainProfile.json"
}

foreach ($pair in $FileMappings.GetEnumerator()) {
    $Source = Join-Path $RepoRoot $pair.Key
    $Dest = Join-Path $InstallPath $pair.Value
    
    if (Test-Path $Source) {
        $DestDir = Split-Path $Dest
        if (-not (Test-Path $DestDir)) {
            New-Item -ItemType Directory -Path $DestDir -Force | Out-Null
        }
        Copy-Item -Path $Source -Destination $Dest -Force
        Write-Log "Copied: $($pair.Key)"
    } else {
        Write-Warning "Source config not found: $Source"
    }
}

# SAIN Configs
$SainSource = Join-Path $RepoRoot "configs\sain_config"
$SainDest = Join-Path $InstallPath "BepInEx\plugins\SAIN"

if (Test-Path $SainSource) {
    if (-not (Test-Path $SainDest)) {
        New-Item -ItemType Directory -Path $SainDest -Force | Out-Null
    }
    Copy-Item -Path "$SainSource\*" -Destination $SainDest -Recurse -Force
    Write-Log "Copied: SAIN configs"
} else {
    Write-Warning "SAIN configs not found at $SainSource"
}

Write-Log "Installation complete."
Write-Log "Launching SPT Launcher..."
$LauncherExe = Join-Path $InstallPath "SPT.Launcher.exe"
Start-Process -FilePath $LauncherExe -WorkingDirectory $InstallPath