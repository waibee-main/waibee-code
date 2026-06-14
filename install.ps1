# install.ps1 — Install waibee from GitHub Releases (waibee-main/waibee-code).
#
# Usage:
#   irm https://raw.githubusercontent.com/waibee-main/waibee-code/main/install.ps1 | iex
#   $env:WAIBEE_VERSION = "v1.2.3"; .\install.ps1     # pin a specific version
#   .\install.ps1 -Uninstall                           # remove the binary
#
# Install directory (in order of precedence):
#   $env:WAIBEE_INSTALL_DIR  >  $env:LOCALAPPDATA\Programs\waibee
#
[CmdletBinding()]
param(
    [switch]$Uninstall
)

$ErrorActionPreference = 'Stop'

$Repo    = 'waibee-main/waibee-code'
$Binary  = 'waibee.exe'

# ── helpers ────────────────────────────────────────────────────────────────────

function Say  { param([string]$Msg) Write-Host "==> $Msg" -ForegroundColor Green }
function Warn { param([string]$Msg) Write-Warning $Msg }
function Die  { param([string]$Msg) Write-Error $Msg; exit 1 }

# ── detect architecture ────────────────────────────────────────────────────────

$RawArch = [System.Runtime.InteropServices.RuntimeInformation]::ProcessArchitecture
switch ($RawArch) {
    'X64'   { $ArchPart = 'x86_64' }
    'Arm64' { $ArchPart = 'aarch64' }
    default { Die "Unsupported architecture: $RawArch" }
}

$Target = "${ArchPart}-pc-windows-msvc"

# ── install directory ──────────────────────────────────────────────────────────

$InstallDir = if ($env:WAIBEE_INSTALL_DIR) {
    $env:WAIBEE_INSTALL_DIR
} else {
    Join-Path $env:LOCALAPPDATA 'Programs\waibee'
}

# ── uninstall path ─────────────────────────────────────────────────────────────

if ($Uninstall) {
    $BinPath = Join-Path $InstallDir $Binary
    if (Test-Path $BinPath) {
        Remove-Item $BinPath -Force
        Say "Removed $BinPath"
        Say "Note: configuration and data files are NOT removed."
        Say "They typically live in $env:APPDATA\waibee or $env:LOCALAPPDATA\waibee."
    } else {
        Warn "Binary not found at $BinPath — nothing to remove."
    }
    exit 0
}

# ── resolve version ────────────────────────────────────────────────────────────

if ($env:WAIBEE_VERSION) {
    $Version = $env:WAIBEE_VERSION
    Say "Using pinned version: $Version"
} else {
    Say "Resolving latest release..."
    try {
        $Release = Invoke-RestMethod "https://api.github.com/repos/$Repo/releases/latest"
        $Version = $Release.tag_name
    } catch {
        Die "Could not resolve latest release tag from GitHub API: $_"
    }
    if (-not $Version) { Die "GitHub API returned an empty tag_name." }
    Say "Latest version: $Version"
}

# Strip leading 'v' for archive filename
$VersionBare = $Version -replace '^v', ''

$ArchiveName = "waibee-${VersionBare}-${Target}.zip"
$BaseUrl     = "https://github.com/$Repo/releases/download/$Version"
$ArchiveUrl  = "$BaseUrl/$ArchiveName"
$Sha256Url   = "$ArchiveUrl.sha256"

# ── temp workspace ─────────────────────────────────────────────────────────────

$WorkDir = Join-Path ([System.IO.Path]::GetTempPath()) ([System.Guid]::NewGuid().ToString())
New-Item -ItemType Directory -Path $WorkDir | Out-Null

try {

# ── download ───────────────────────────────────────────────────────────────────

$ArchivePath = Join-Path $WorkDir $ArchiveName
Say "Downloading $ArchiveName..."
try {
    Invoke-WebRequest -Uri $ArchiveUrl -OutFile $ArchivePath -UseBasicParsing
} catch {
    Die "No prebuilt binary for '$Target' in $Version.`n  Your platform may not be supported yet. See https://github.com/$Repo/releases"
}

# Download sha256 sidecar (best-effort)
$Sha256Path      = "$ArchivePath.sha256"
$Sha256Available = $false
try {
    Invoke-WebRequest -Uri $Sha256Url -OutFile $Sha256Path -UseBasicParsing -ErrorAction Stop
    $Sha256Available = $true
} catch {
    Warn "No .sha256 sidecar found — skipping checksum verification."
}

# ── checksum verification ──────────────────────────────────────────────────────

if ($Sha256Available) {
    Say "Verifying checksum..."
    $Expected = (Get-Content $Sha256Path -Raw).Trim().Split()[0]
    $Actual   = (Get-FileHash -Path $ArchivePath -Algorithm SHA256).Hash.ToLower()
    $Expected = $Expected.ToLower()
    if ($Actual -ne $Expected) {
        Die "Checksum mismatch!`n  expected: $Expected`n  actual:   $Actual"
    }
    Say "Checksum OK."
}

# ── extract ────────────────────────────────────────────────────────────────────

Say "Extracting..."
Expand-Archive -Path $ArchivePath -DestinationPath $WorkDir -Force

# The archive contains a directory: waibee-<version>-<target>\waibee.exe
$StagingDir = Join-Path $WorkDir "waibee-${VersionBare}-${Target}"
$BinSrc     = Join-Path $StagingDir $Binary
if (-not (Test-Path $BinSrc)) {
    Die "Binary not found inside archive at $BinSrc"
}

# ── install ────────────────────────────────────────────────────────────────────

if (-not (Test-Path $InstallDir)) {
    New-Item -ItemType Directory -Path $InstallDir | Out-Null
}

$BinDest = Join-Path $InstallDir $Binary
Copy-Item $BinSrc $BinDest -Force

Say "Installed waibee $Version to $BinDest"

# ── PATH hint ──────────────────────────────────────────────────────────────────

$CurrentPath = [System.Environment]::GetEnvironmentVariable('Path', 'User')
if ($CurrentPath -notlike "*$InstallDir*") {
    Warn "$InstallDir is not in your PATH."
    Warn "To add it permanently, run:"
    Warn ""
    Warn "  [System.Environment]::SetEnvironmentVariable('Path', `$env:Path + ';$InstallDir', 'User')"
    Warn ""
    Warn "Then restart your terminal."
}

# ── next steps ─────────────────────────────────────────────────────────────────

Say ""
Say "Next step: configure your API key"
Say ""
Say "  waibee config set-api-key"
Say ""
Say "Or run the interactive setup wizard:"
Say ""
Say "  waibee config wizard"
Say ""

} finally {
    Remove-Item -Recurse -Force $WorkDir -ErrorAction SilentlyContinue
}
