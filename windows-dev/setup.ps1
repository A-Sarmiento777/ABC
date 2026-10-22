#Requires -RunAsAdministrator
<#
.SYNOPSIS
  Sets up a Valet-like WordPress dev machine on Windows with Laravel Herd.

.DESCRIPTION
  Run once from an elevated PowerShell in this folder:
      Set-ExecutionPolicy -Scope Process Bypass
      .\setup.ps1

  Safe to run again: every step checks whether it is already done.

  What it does:
    1. Installs Git for Windows (Git Bash)
    2. Waits for you to install Laravel Herd, then parks ~\Sites and sets PHP 8.3
    3. Sets PHP limits to 512M and logs PHP errors to one file you can tail
    4. Installs MySQL 8.4 as a Windows service: root with no password, 127.0.0.1:3306
    5. Installs WP-CLI (wp in Git Bash, wp.bat in PowerShell) and the new-wp / check-dev commands
    6. Adds Windows Defender exclusions for Sites, Herd and MySQL
    7. Writes the Git Bash profile (PATH, aliases)
#>
[CmdletBinding()]
param(
    [string]$SitesPath    = (Join-Path $env:USERPROFILE 'Sites'),
    [string]$PhpVersion   = '8.3',
    [string]$MySqlVersion = '',        # empty = newest 8.4.x it can find
    [string]$MySqlZip     = '',        # path to a MySQL ZIP you downloaded yourself
    [string]$MySqlRoot    = 'C:\MySQL',
    [switch]$SkipMySql,
    [switch]$SkipDefender,
    [switch]$InstallNvm
)

$ErrorActionPreference = 'Stop'
$ProgressPreference    = 'SilentlyContinue'   # makes Invoke-WebRequest much faster
[Net.ServicePointManager]::SecurityProtocol = [Net.ServicePointManager]::SecurityProtocol -bor [Net.SecurityProtocolType]::Tls12

$RepoDir = $PSScriptRoot
$HerdDir = Join-Path $env:USERPROFILE '.config\herd'
$HerdBin = Join-Path $HerdDir 'bin'
$UserBin = Join-Path $env:USERPROFILE 'bin'
$PhpLog  = Join-Path $HerdDir 'Log\php-errors.log'

function Step($msg) { Write-Host "`n==> $msg" -ForegroundColor Cyan }
function Info($msg) { Write-Host "    $msg" }
function Warn($msg) { Write-Host "    ! $msg" -ForegroundColor Yellow }

function Add-UserPath([string]$dir) {
    $current = [Environment]::GetEnvironmentVariable('Path', 'User')
    if (-not $current) { $current = '' }
    if (($current -split ';') -notcontains $dir) {
        [Environment]::SetEnvironmentVariable('Path', ($current.TrimEnd(';') + ';' + $dir).TrimStart(';'), 'User')
        Info "Added to PATH: $dir"
    }
    if (($env:Path -split ';') -notcontains $dir) { $env:Path = "$env:Path;$dir" }
}

function Install-Winget([string]$id) {
    $ErrorActionPreference = 'Continue'
    winget list --id $id -e --accept-source-agreements *> $null
    $ErrorActionPreference = 'Stop'
    if ($LASTEXITCODE -eq 0) { Info "$id is already installed"; return }
    Info "Installing $id ..."
    winget install --id $id -e --silent --accept-package-agreements --accept-source-agreements
    if ($LASTEXITCODE -ne 0) { Warn "winget could not install $id (exit $LASTEXITCODE)" }
}

# Writes a text file with LF endings and no BOM, which bash needs.
function Write-UnixFile([string]$path, [string]$text) {
    [IO.File]::WriteAllText($path, ($text -replace "`r`n", "`n"), (New-Object Text.UTF8Encoding $false))
}

function Set-IniValue([string]$text, [string]$key, [string]$value) {
    $pattern = "(?m)^[ \t]*;?[ \t]*$([regex]::Escape($key))[ \t]*=.*$"
    $line = "$key = $value"
    $re = New-Object regex $pattern
    if ($re.IsMatch($text)) { return $re.Replace($text, $line, 1) }
    return $text.TrimEnd() + "`r`n$line`r`n"
}

# ---------------------------------------------------------------------------
Step 'Git for Windows'
Install-Winget 'Git.Git'
$gitCmd = 'C:\Program Files\Git\cmd'
if (Test-Path $gitCmd) { if (($env:Path -split ';') -notcontains $gitCmd) { $env:Path = "$env:Path;$gitCmd" } }
if (Get-Command git -ErrorAction SilentlyContinue) {
    git config --global core.autocrlf false   # CRLF breaks bash scripts
    Info 'git core.autocrlf = false'
} else {
    Warn 'git is not on PATH yet. Run this script again after opening a new terminal.'
}

# ---------------------------------------------------------------------------
Step 'Laravel Herd'
$herd = Join-Path $HerdBin 'herd.bat'
if (-not (Test-Path $herd)) {
    Info 'Herd is not installed. Opening the download page.'
    Start-Process 'https://herd.laravel.com/windows'
    Read-Host '    Install Herd, open it once so it finishes setup, then press Enter here'
}
if (Test-Path $herd) {
    # herd.bat needs Herd's php on PATH; a fresh install isn't on this window's PATH yet.
    Add-UserPath $HerdBin
    $phpDir = Join-Path $HerdBin ('php' + ($PhpVersion -replace '\.', ''))
    if (-not (Test-Path $phpDir)) {
        $have = (Get-ChildItem $HerdBin -Directory -Filter 'php*' | ForEach-Object Name) -join ', '
        Warn "PHP $PhpVersion is not installed in Herd (found: $have)."
        Read-Host "    Open Herd > Settings > PHP, click Install next to $PhpVersion, wait until it's done, then press Enter"
    }
    New-Item -ItemType Directory -Force -Path $SitesPath | Out-Null
    Push-Location $SitesPath
    try {
        & $herd park
        if ($LASTEXITCODE -eq 0) { Info "Parked $SitesPath (every folder in it is served as <folder>.test)" }
        else { Warn "herd park failed. In Herd > Settings > General, add $SitesPath under Herd paths." }
        if (Test-Path $phpDir) {
            & $herd use $PhpVersion
            if ($LASTEXITCODE -eq 0) { Info "Default PHP: $PhpVersion" }
            else { Warn "herd use $PhpVersion failed. Pick PHP $PhpVersion as the global version in Herd > Settings > PHP." }
        } else {
            Warn "PHP $PhpVersion still missing; Herd keeps its current PHP. Run this script again after installing it."
        }
    } finally { Pop-Location }
} else {
    Warn "Herd still not found at $HerdBin. Skipping Herd steps; run this script again after installing it."
}

# ---------------------------------------------------------------------------
Step 'PHP settings (512M limits, error log)'
New-Item -ItemType Directory -Force -Path (Split-Path $PhpLog) | Out-Null
$iniFiles = @()
if (Test-Path $HerdBin) {
    $iniFiles = Get-ChildItem $HerdBin -Directory -Filter 'php*' |
        ForEach-Object { Join-Path $_.FullName 'php.ini' } |
        Where-Object { Test-Path $_ }
}
if (-not $iniFiles) { Warn 'No Herd php.ini found. Install PHP versions in Herd first, then run again.' }
foreach ($ini in $iniFiles) {
    $text = [IO.File]::ReadAllText($ini)
    if (-not (Test-Path "$ini.orig")) { Copy-Item $ini "$ini.orig" }
    $settings = [ordered]@{
        memory_limit        = '512M'
        upload_max_filesize = '512M'
        post_max_size       = '512M'
        max_execution_time  = '300'
        max_input_vars      = '5000'
        log_errors          = 'On'
        error_log           = '"' + $PhpLog + '"'
    }
    foreach ($k in $settings.Keys) { $text = Set-IniValue $text $k $settings[$k] }
    [IO.File]::WriteAllText($ini, $text)
    Info "Updated $ini"
}
Info "PHP errors go to $PhpLog (tail it with: phplog)"

# ---------------------------------------------------------------------------
if (-not $SkipMySql) {
    Step 'MySQL 8.4'
    $svcName = 'MySQL84'
    $dataDir = Join-Path $MySqlRoot 'data'
    $myIni   = Join-Path $MySqlRoot 'my.ini'
    $existing = Get-ChildItem $MySqlRoot -Directory -Filter 'mysql-8.4*-winx64' -ErrorAction SilentlyContinue | Select-Object -First 1
    $baseDir = if ($existing) { $existing.FullName } else { $null }

    if (Get-Service $svcName -ErrorAction SilentlyContinue) {
        Info "Service $svcName already exists"
    } else {
        Install-Winget 'Microsoft.VCRedist.2015+.x64'
        New-Item -ItemType Directory -Force -Path $MySqlRoot | Out-Null
        if (-not $baseDir) {
            $zip = $MySqlZip
            if (-not $zip) {
                # Try the given version, or the newest 8.4.x first. Current releases are on the CDN,
                # older ones move to the archive.
                $versions = if ($MySqlVersion) { @($MySqlVersion) } else { 25..0 | ForEach-Object { "8.4.$_" } }
                $zip = Join-Path $env:TEMP 'mysql-8.4-winx64.zip'
                $ok = $false
                Info 'Looking for the newest MySQL 8.4 download (this can take a minute)'
                foreach ($v in $versions) {
                    foreach ($u in @("https://cdn.mysql.com/Downloads/MySQL-8.4/mysql-$v-winx64.zip",
                                     "https://downloads.mysql.com/archives/get/p/23/file/mysql-$v-winx64.zip")) {
                        try {
                            Invoke-WebRequest $u -OutFile $zip -UseBasicParsing -UserAgent 'Mozilla/5.0'
                            if ((Get-Item $zip).Length -gt 50MB) { Info "Downloaded MySQL $v"; $ok = $true; break }
                        } catch { $lastError = $_.Exception.Message }
                    }
                    if ($ok) { break }
                }
                if (-not $ok) {
                    Warn "Last error: $lastError"
                    throw ("Could not download MySQL 8.4 automatically. Download it yourself: dev.mysql.com/downloads/mysql > " +
                           "version 8.4 LTS > Windows (x86, 64-bit), ZIP Archive (the big one, not 'Debug Binaries'). Then run: " +
                           ".\setup.ps1 -MySqlZip `"$env:USERPROFILE\Downloads\mysql-8.4.x-winx64.zip`"")
                }
            }
            if (-not (Test-Path $zip)) { throw "ZIP not found: $zip" }
            Info "Unpacking to $MySqlRoot"
            Expand-Archive $zip -DestinationPath $MySqlRoot -Force
            if (-not $MySqlZip) { Remove-Item $zip }
            $baseDir = (Get-ChildItem $MySqlRoot -Directory -Filter 'mysql-8.4*-winx64' | Select-Object -First 1).FullName
            if (-not $baseDir) { throw "No mysql-8.4.x-winx64 folder found in $MySqlRoot after unpacking. Is it an 8.4 ZIP?" }
        }

        $fwd = { param($p) $p -replace '\\', '/' }
        $iniText = @"
[mysqld]
basedir=$(& $fwd $baseDir)
datadir=$(& $fwd $dataDir)
port=3306
bind-address=127.0.0.1
character-set-server=utf8mb4
collation-server=utf8mb4_unicode_ci
max_allowed_packet=512M
innodb_buffer_pool_size=512M

[client]
port=3306
max_allowed_packet=512M
"@
        [IO.File]::WriteAllText($myIni, $iniText)

        if (-not (Test-Path $dataDir)) {
            Info 'Initializing data directory (root with no password)'
            & (Join-Path $baseDir 'bin\mysqld.exe') "--defaults-file=$myIni" --initialize-insecure --console
            if ($LASTEXITCODE -ne 0) { throw 'mysqld --initialize-insecure failed' }
        }
        & (Join-Path $baseDir 'bin\mysqld.exe') --install $svcName "--defaults-file=$myIni"
        Set-Service $svcName -StartupType Automatic
        Start-Service $svcName
        Info "Service $svcName installed and started (starts automatically)"
    }

    Add-UserPath (Join-Path $baseDir 'bin')

    # root@localhost is created by --initialize-insecure. Also allow root over 127.0.0.1 / ::1
    # so DB_HOST 127.0.0.1 works the same way it does on the Mac.
    $mysql = Join-Path $baseDir 'bin\mysql.exe'
    $sql = "CREATE USER IF NOT EXISTS 'root'@'127.0.0.1' IDENTIFIED BY ''; GRANT ALL PRIVILEGES ON *.* TO 'root'@'127.0.0.1' WITH GRANT OPTION; " +
           "CREATE USER IF NOT EXISTS 'root'@'::1' IDENTIFIED BY ''; GRANT ALL PRIVILEGES ON *.* TO 'root'@'::1' WITH GRANT OPTION; FLUSH PRIVILEGES;"
    # Windows PowerShell turns redirected stderr into errors, so don't stop on them here.
    $ErrorActionPreference = 'Continue'
    for ($i = 0; $i -lt 10; $i++) {
        & $mysql -uroot -hlocalhost -e $sql 2>$null
        if ($LASTEXITCODE -eq 0) { break }
        Start-Sleep -Seconds 2
    }
    $ErrorActionPreference = 'Stop'
    if ($LASTEXITCODE -eq 0) { Info 'root can connect with no password' } else { Warn 'Could not connect as root. Check the MySQL84 service and C:\MySQL\data\*.err' }
}

# ---------------------------------------------------------------------------
Step 'WP-CLI and scripts in ~\bin'
New-Item -ItemType Directory -Force -Path $UserBin | Out-Null
$phar = Join-Path $UserBin 'wp-cli.phar'
if (-not (Test-Path $phar)) {
    Invoke-WebRequest 'https://raw.githubusercontent.com/wp-cli/builds/gh-pages/phar/wp-cli.phar' -OutFile $phar -UseBasicParsing
    Info 'Downloaded wp-cli.phar'
}
Write-UnixFile (Join-Path $UserBin 'wp') "#!/bin/sh`nexec php `"`$HOME/bin/wp-cli.phar`" `"`$@`"`n"
[IO.File]::WriteAllText((Join-Path $UserBin 'wp.bat'), "@php `"%USERPROFILE%\bin\wp-cli.phar`" %*`r`n")
Get-ChildItem (Join-Path $RepoDir 'bin') -File | ForEach-Object {
    Write-UnixFile (Join-Path $UserBin $_.Name) ([IO.File]::ReadAllText($_.FullName))
    Info "Installed $($_.Name)"
}
Add-UserPath $UserBin

# Templates used by new-headless
$tplDest = Join-Path $env:USERPROFILE '.windows-dev\templates'
New-Item -ItemType Directory -Force -Path $tplDest | Out-Null
Copy-Item (Join-Path $RepoDir 'templates\*') $tplDest -Recurse -Force
Info "Installed templates to $tplDest"

# ---------------------------------------------------------------------------
if ($InstallNvm) {
    Step 'nvm-windows'
    Install-Winget 'CoreyButler.NVMforWindows'
    Info 'Open a new terminal and run: nvm install 26; nvm use 26'
}

# ---------------------------------------------------------------------------
if (-not $SkipDefender) {
    Step 'Windows Defender exclusions'
    $paths = @($SitesPath, $HerdDir, $UserBin)
    if (-not $SkipMySql) { $paths += $MySqlRoot }
    try {
        Add-MpPreference -ExclusionPath $paths
        $paths | ForEach-Object { Info "Excluded $_" }
    } catch { Warn "Could not add exclusions: $_" }
}

# ---------------------------------------------------------------------------
Step 'Git Bash profile'
$bashrc  = Join-Path $env:USERPROFILE '.bashrc'
$bashProfile = Join-Path $env:USERPROFILE '.bash_profile'
$marker  = '# >>> windows-dev >>>'
$snippet = [IO.File]::ReadAllText((Join-Path $RepoDir 'bashrc-snippet.sh'))
$current = if (Test-Path $bashrc) { [IO.File]::ReadAllText($bashrc) } else { '' }
if ($current -notmatch [regex]::Escape($marker)) {
    Write-UnixFile $bashrc ($current.TrimEnd() + "`n`n" + $snippet)
    Info "Added the windows-dev block to $bashrc"
} else {
    Info "$bashrc already has the windows-dev block"
}
if (-not (Test-Path $bashProfile)) {
    Write-UnixFile $bashProfile "test -f ~/.bashrc && . ~/.bashrc`n"
    Info "Created $bashProfile"
}

# ---------------------------------------------------------------------------
Step 'Done'
Info 'Next:'
Info '  1. Open a NEW Git Bash window and run: check-dev'
Info '  2. Make a site: new-wp mysite   (opens at http://mysite.test)'
