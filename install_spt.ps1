<#
.SYNOPSIS
    Automated installer for SPT and Fika based on local README instructions.

.DESCRIPTION
    1. Creates install directory.
    2. Copies Live Tarkov files.
    3. Downloads and extracts the Downgrade Patcher.
    4. Runs the Patcher.
    5. Downloads and runs the Fika Installer.
    6. Configures HTTP JSON for Fika (0.0.0.0).

.NOTES
    Run this script as Administrator to ensure permission to write to directories.
    Requires 7-Zip installed at default location or in PATH.
#>

param (
    [string]$LiveTarkovPath = "C:\Battlestate Games\Escape from Tarkov",
    [string]$InstallPath,
    [string]$PatcherUrl = "https://spt-legacy.modd.in/Patcher_1.0.1.1.42751_to_16.1.3.35392.7z",
    [string]$SptUrl = "https://github.com/sp-tarkov/build/releases/download/3.11.4/SPT-3.11.4-35392-96e5b73.7z",
    [string]$FikaInstallerUrl = "https://github.com/project-fika/Fika-Installer/releases/download/1.1.3/Fika-Installer.exe"
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
    $FolderBrowser.Description = "Select the folder where you want to install SPT-Fika"
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
    # Try to find in path
    if (Get-Command "7z" -ErrorAction SilentlyContinue) {
        $7zPath = "7z"
    } else {
        Write-Error "7-Zip not found. Please install 7-Zip to extract the patcher."
        exit 1
    }
}

# 1. Create Folder
if (-not (Test-Path $InstallPath)) {
    Write-Log "Creating installation directory: $InstallPath"
    New-Item -ItemType Directory -Path $InstallPath | Out-Null
}

# 2. Copy Tarkov game dir into new folder
if (-not (Test-Path "$InstallPath\EscapeFromTarkov.exe")) {
    Write-Log "Copying Live Tarkov files (This may take a while)..."
    # Robocopy is faster and more reliable for large directories than Copy-Item
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
    
    # Clean up archive
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
    
    # Clean up archive
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

# 8. JSON edit for IPConfig (Fika), get IP from prompt
# Located in user\mods\fika-server\assets\configs\fika.jsonc
$FikaConfigPath = Join-Path $InstallPath "user\mods\fika-server\assets\configs\fika.jsonc"

if (Test-Path $FikaConfigPath) {
    $UserIP = Read-Host "Enter the IP address for Fika (Default: 0.0.0.0)"
    if ([string]::IsNullOrWhiteSpace($UserIP)) {
        $UserIP = "0.0.0.0"
    }
    Write-Log "Configuring fika.jsonc ($UserIP)..."
    try {
        $content = Get-Content $FikaConfigPath -Raw
        # Regex to replace "ip": "..." with "ip": "$UserIP"
        $newContent = $content -replace '("ip":\s*")(.+?)(")', ('${1}' + $UserIP + '${3}')
        # Also replace "backendIp": "..." with "backendIp": "$UserIP"
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
    Write-Warning "fika.jsonc not found at $FikaConfigPath. The installer may not have created it yet."
}

Write-Log "Installation script complete."
Write-Log "Launching SPT Launcher..."
$LauncherExe = Join-Path $InstallPath "SPT.Launcher.exe"
Start-Process -FilePath $LauncherExe -WorkingDirectory $InstallPath