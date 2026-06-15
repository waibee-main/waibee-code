# install.ps1 — install waibee from GitHub Releases.
#
#   irm https://raw.githubusercontent.com/waibee-main/waibee-code/main/install.ps1 | iex
#   $env:WAIBEE_VERSION = "v1.2.3"; .\install.ps1   # pin a version
#   .\install.ps1 -Uninstall                         # remove the binary
#
# Install dir: $env:WAIBEE_INSTALL_DIR > $env:LOCALAPPDATA\Programs\waibee
[CmdletBinding()]
param([switch]$Uninstall)

$ErrorActionPreference = 'Stop'

# Windows PowerShell 5.1 may default to TLS 1.0/1.1 (GitHub rejects it), and its
# progress bar slows Invoke-WebRequest to a crawl.
try {
    [Net.ServicePointManager]::SecurityProtocol =
        [Net.ServicePointManager]::SecurityProtocol -bor [Net.SecurityProtocolType]::Tls12
} catch {}
$ProgressPreference = 'SilentlyContinue'

$Repo   = 'waibee-main/waibee-code'
$Binary = 'waibee.exe'

function Say  { param([string]$Msg) Write-Host "==> $Msg" -ForegroundColor Green }
function Warn { param([string]$Msg) Write-Warning $Msg }
function Die  { param([string]$Msg) throw $Msg }

# PROCESSOR_ARCHITEW6432 is set inside a 32-bit (WOW64) shell on 64-bit Windows.
$RawArch = if ($env:PROCESSOR_ARCHITEW6432) { $env:PROCESSOR_ARCHITEW6432 } else { $env:PROCESSOR_ARCHITECTURE }
switch ($RawArch) {
    'AMD64' { $ArchPart = 'x86_64' }
    'ARM64' { $ArchPart = 'aarch64' }
    default { Die "Unsupported architecture: $RawArch" }
}
$Target = "${ArchPart}-pc-windows-msvc"

$InstallDir = if ($env:WAIBEE_INSTALL_DIR) {
    $env:WAIBEE_INSTALL_DIR
} else {
    Join-Path $env:LOCALAPPDATA 'Programs\waibee'
}

if ($Uninstall) {
    $BinPath = Join-Path $InstallDir $Binary
    if (Test-Path $BinPath) {
        Remove-Item $BinPath -Force
        Say "Removed $BinPath"
        Say "Note: config/data files are NOT removed (typically %APPDATA%\waibee, %LOCALAPPDATA%\waibee)."
    } else {
        Warn "Binary not found at $BinPath — nothing to remove."
    }
    return
}

try {
    if ($env:WAIBEE_VERSION) {
        $Version = $env:WAIBEE_VERSION
        Say "Using pinned version: $Version"
    } else {
        Say "Resolving latest release..."
        $Headers = @{ 'User-Agent' = 'waibee-installer' }
        if ($env:GITHUB_TOKEN) { $Headers['Authorization'] = "Bearer $env:GITHUB_TOKEN" }
        try {
            $Version = (Invoke-RestMethod "https://api.github.com/repos/$Repo/releases/latest" -Headers $Headers).tag_name
        } catch {
            if ($_.Exception.Response.StatusCode.value__ -eq 403) {
                Die "GitHub API rate limit hit — set `$env:GITHUB_TOKEN or pin `$env:WAIBEE_VERSION."
            }
            Die "Could not resolve the latest release: $($_.Exception.Message)"
        }
        if (-not $Version) { Die "GitHub API returned an empty tag_name." }
        Say "Latest version: $Version"
    }

    $VersionBare = $Version -replace '^v', ''
    $ArchiveName = "waibee-${VersionBare}-${Target}.zip"
    $BaseUrl     = "https://github.com/$Repo/releases/download/$Version"

    $WorkDir = Join-Path ([System.IO.Path]::GetTempPath()) ([System.Guid]::NewGuid().ToString())
    New-Item -ItemType Directory -Path $WorkDir | Out-Null

    try {
        $ArchivePath = Join-Path $WorkDir $ArchiveName
        Say "Downloading $ArchiveName..."
        try {
            Invoke-WebRequest -Uri "$BaseUrl/$ArchiveName" -OutFile $ArchivePath -UseBasicParsing
        } catch {
            Die "No prebuilt binary for '$Target' in $Version.`n  Your platform may not be supported yet — see https://github.com/$Repo/releases"
        }

        $Sha256Path = "$ArchivePath.sha256"
        $HaveSha = $true
        try {
            Invoke-WebRequest -Uri "$BaseUrl/$ArchiveName.sha256" -OutFile $Sha256Path -UseBasicParsing
        } catch {
            $HaveSha = $false
            Warn "No .sha256 sidecar found — skipping checksum verification."
        }
        if ($HaveSha) {
            Say "Verifying checksum..."
            # Sidecar is "<hash>  <filename>"; the hash is the first whitespace token.
            $Expected = (-split (Get-Content $Sha256Path -Raw))[0].ToLower()
            $Actual   = (Get-FileHash -Path $ArchivePath -Algorithm SHA256).Hash.ToLower()
            if ($Actual -ne $Expected) { Die "Checksum mismatch!`n  expected: $Expected`n  actual:   $Actual" }
            Say "Checksum OK."
        }

        Say "Extracting..."
        Expand-Archive -Path $ArchivePath -DestinationPath $WorkDir -Force
        # Locate the binary anywhere in the archive — don't assume the wrapping dir name.
        $BinSrc = Get-ChildItem -Path $WorkDir -Filter $Binary -Recurse -File | Select-Object -First 1
        if (-not $BinSrc) { Die "Binary '$Binary' not found inside the archive." }

        if (-not (Test-Path $InstallDir)) { New-Item -ItemType Directory -Path $InstallDir | Out-Null }
        $BinDest = Join-Path $InstallDir $Binary
        Copy-Item $BinSrc.FullName $BinDest -Force
        Say "Installed waibee $Version to $BinDest"

        # Put waibee on PATH: persist to User scope (new terminals) + this session
        # (run it right away). Read/write User scope only — never the expanded
        # process PATH, which would bloat/duplicate entries. Opt out to manage PATH yourself.
        $UserPath = [Environment]::GetEnvironmentVariable('Path', 'User')
        if (-not $UserPath) { $UserPath = '' }
        $OnPath = ($UserPath -split ';') -contains $InstallDir
        if ($env:WAIBEE_NO_MODIFY_PATH) {
            if (-not $OnPath) {
                Warn "$InstallDir is not on your PATH. Add it with:"
                Warn "  [Environment]::SetEnvironmentVariable('Path', ([Environment]::GetEnvironmentVariable('Path','User').TrimEnd(';') + ';$InstallDir'), 'User')"
            }
        } else {
            if (-not $OnPath) {
                [Environment]::SetEnvironmentVariable('Path', $UserPath.TrimEnd(';') + ";$InstallDir", 'User')
                Say "Added $InstallDir to your PATH (effective in new terminals)."
            }
            if (($env:Path -split ';') -notcontains $InstallDir) {
                $env:Path = $env:Path.TrimEnd(';') + ";$InstallDir"
            }
        }

        Say ""
        Say "Next: configure your API key →  waibee config set-api-key"
        Say "Or just run ``waibee`` — it walks you through setup on first launch."
    } finally {
        Remove-Item -Recurse -Force $WorkDir -ErrorAction SilentlyContinue
    }
} catch {
    Write-Host "ERROR: $($_.Exception.Message)" -ForegroundColor Red
    exit 1
}
