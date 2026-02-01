<#
.SYNOPSIS
    Automated mod installer for SPT based on local README instructions.
#>

param (
    [string]$InstallPath
)

$ErrorActionPreference = "Stop"

function Write-Log {
    param([string]$Message)
    Write-Host "[$((Get-Date).ToString('HH:mm:ss'))] $Message" -ForegroundColor Cyan
}

# Select Install Path if not provided
if ([string]::IsNullOrWhiteSpace($InstallPath)) {
    Write-Log "Prompting for installation directory..."
    Add-Type -AssemblyName System.Windows.Forms
    $FolderBrowser = New-Object System.Windows.Forms.FolderBrowserDialog
    $FolderBrowser.Description = "Select the SPT installation folder"
    $FolderBrowser.ShowNewFolderButton = $false

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

# 1. Download mods.7z
$ModsUrl = "https://drive.usercontent.google.com/download?id=1N_yhNEqL8Xm1_KCU3knIwpkL-C4tPemf&export=download&authuser=0&confirm=t&uuid=17b304a6-bf1b-4988-82f7-98c9b2492be4&at=APcXIO1sStdVreJhaEHcKBuM_qxg:1769989445011"
$ModsArchive = Join-Path $InstallPath "mods.7z"

Write-Log "Downloading mods.7z..."
# Use Invoke-WebRequest with SilentlyContinue for speed/compatibility on GDrive
$OldProgress = $ProgressPreference
$ProgressPreference = 'SilentlyContinue'
try {
    Invoke-WebRequest -Uri $ModsUrl -OutFile $ModsArchive -UseBasicParsing
} catch {
    Write-Warning "Automatic download failed. You may need to download mods.7z manually."
} finally {
    $ProgressPreference = $OldProgress
}

# Verify download size (check for 0-byte or small HTML error pages)
if (-not (Test-Path $ModsArchive) -or (Get-Item $ModsArchive).Length -lt 1000000) {
    Write-Error "mods.7z failed to download correctly (File missing or too small).`nPlease download it manually from: $ModsUrl`nPlace it in: $InstallPath`nThen run this script again."
    exit 1
}

# 1.5 Download configs.7z
$ConfigsUrl = "https://drive.google.com/uc?export=download&id=17mDmdyTOGniPY8eVdla_3KbKTfFAYOew"
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

# 2. Extract into root
Write-Log "Extracting mods..."
$extractArgs = @("x", "`"$ModsArchive`"", "-o`"$InstallPath`"", "-y")
Start-Process -FilePath $7zPath -ArgumentList $extractArgs -Wait -NoNewWindow

Write-Log "Extracting configs..."
$extractArgs = @("x", "`"$ConfigsArchive`"", "-o`"$InstallPath`"", "-y")
Start-Process -FilePath $7zPath -ArgumentList $extractArgs -Wait -NoNewWindow

# 3. Copy configs
Write-Log "Copying configuration files..."
$RepoRoot = $InstallPath

# File Mappings
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

# SAIN Configs (Folder Copy)
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

Write-Log "Mod installation complete."