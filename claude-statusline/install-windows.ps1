# install-windows.ps1
# Installs a custom two-line, color-coded status line for Claude Code on Windows.
#
# Usage:
#   powershell -NoProfile -ExecutionPolicy Bypass -File .\install-windows.ps1
#
# What it does:
#   1. Writes the renderer to  %USERPROFILE%\.claude\statusline-command.ps1
#   2. Merges a "statusLine" block into %USERPROFILE%\.claude\settings.json,
#      preserving every other key already in that file.
#
# This is a USER-LEVEL (machine-wide) setting: it applies to every Claude Code
# project on this machine, not just the current folder. It is additive and
# reversible -- delete the "statusLine" key from settings.json to revert.
#
# Optional flag:
#   -Force   Replace an existing statusLine without prompting.

param(
    [switch]$Force
)

$ErrorActionPreference = 'Stop'

$claudeDir = Join-Path $env:USERPROFILE '.claude'
New-Item -ItemType Directory -Force -Path $claudeDir | Out-Null

$scriptPath   = Join-Path $claudeDir 'statusline-command.ps1'
$settingsPath = Join-Path $claudeDir 'settings.json'

# --- 1. The status line renderer (written verbatim) ---
$statusline = @'
$ErrorActionPreference = 'SilentlyContinue'

$raw = [Console]::In.ReadToEnd()
$d = $raw | ConvertFrom-Json

$esc = [char]27
$reset = "$esc[0m"
$dim  = "$esc[38;2;150;150;150m"
$blue = "$esc[38;2;0;153;255m"
$mag  = "$esc[38;2;200;130;230m"
$sep  = " $dim|$reset "

function Get-PctColor($pct) {
    if ($null -eq $pct) { return $dim }
    $p = [double]$pct
    if ($p -ge 90) { return "$esc[38;2;255;85;85m" }
    if ($p -ge 70) { return "$esc[38;2;255;176;85m" }
    if ($p -ge 50) { return "$esc[38;2;240;220;90m" }
    return "$esc[38;2;120;220;120m"
}

function Format-Reset($epoch) {
    if ($null -eq $epoch) { return "" }
    $t = [DateTimeOffset]::FromUnixTimeSeconds([long]$epoch).LocalDateTime
    if ($t.Date -eq (Get-Date).Date) {
        return $t.ToString("h:mmtt").ToLower()
    }
    return $t.ToString("MMM d, h:mmtt").ToLower()
}

$line1 = @()
$line2 = @()

$model = $d.model.display_name
if ($model) { $line1 += "$blue$model$reset" }

$cwSize = $d.context_window.context_window_size
$totalIn = $d.context_window.total_input_tokens
$pct = $d.context_window.used_percentage
if ($null -ne $cwSize -and $null -ne $totalIn) {
    $usedK = [math]::Round([double]$totalIn / 1000, 1)
    $maxK  = [math]::Round([double]$cwSize / 1000)
    $c = Get-PctColor $pct
    $p = if ($null -ne $pct) { [math]::Round([double]$pct) } else { 0 }
    $line1 += "$c${usedK}k/${maxK}k ($p%)$reset"
} elseif ($null -ne $pct) {
    $c = Get-PctColor $pct
    $p = [math]::Round([double]$pct)
    $line1 += "${c}ctx $p%$reset"
}

if ($d.effort.level) {
    $line1 += "$mag$($d.effort.level)$reset"
}

$five = $d.rate_limits.five_hour
if ($five -and $null -ne $five.used_percentage) {
    $p = [math]::Round([double]$five.used_percentage)
    $c = Get-PctColor $five.used_percentage
    $seg = "${c}5h $p%$reset"
    $rs = Format-Reset $five.resets_at
    if ($rs) { $seg += "$dim@$rs$reset" }
    $line2 += $seg
}

$seven = $d.rate_limits.seven_day
if ($seven -and $null -ne $seven.used_percentage) {
    $p = [math]::Round([double]$seven.used_percentage)
    $c = Get-PctColor $seven.used_percentage
    $seg = "${c}7d $p%$reset"
    $rs = Format-Reset $seven.resets_at
    if ($rs) { $seg += "$dim@$rs$reset" }
    $line2 += $seg
}

if ($line1.Count -eq 0 -and $line2.Count -eq 0) {
    [Console]::Out.Write("${dim}claude$reset")
    return
}

if ($line1.Count -eq 0) {
    $out = ($line2 -join $sep)
} elseif ($line2.Count -eq 0) {
    $out = ($line1 -join $sep)
} else {
    $out = ($line1 -join $sep) + "`n" + ($line2 -join $sep)
}
[Console]::Out.Write($out)
'@

# Write the renderer as UTF-8 without BOM.
$utf8NoBom = New-Object System.Text.UTF8Encoding($false)
[System.IO.File]::WriteAllText($scriptPath, $statusline, $utf8NoBom)

# --- 2. Merge the statusLine block into settings.json ---
if (Test-Path $settingsPath) {
    # Back up first -- cheap insurance against a malformed merge.
    Copy-Item $settingsPath "$settingsPath.bak" -Force
    $settings = Get-Content $settingsPath -Raw | ConvertFrom-Json
} else {
    $settings = [PSCustomObject]@{}
}

$cmd = "powershell -NoProfile -ExecutionPolicy Bypass -File `"$scriptPath`""
$sl  = [PSCustomObject]@{ type = 'command'; command = $cmd }

if ($settings.PSObject.Properties.Name -contains 'statusLine') {
    if (-not $Force) {
        Write-Host "A statusLine is already configured in $settingsPath :"
        Write-Host "  $($settings.statusLine.command)"
        $answer = Read-Host "Replace it? (y/N)"
        if ($answer -notmatch '^(y|yes)$') {
            Write-Host "Aborted. Renderer was written to $scriptPath but settings.json was not changed."
            return
        }
    }
    $settings.statusLine = $sl
} else {
    $settings | Add-Member -NotePropertyName statusLine -NotePropertyValue $sl
}

$json = $settings | ConvertTo-Json -Depth 20
[System.IO.File]::WriteAllText($settingsPath, $json, $utf8NoBom)

Write-Host "Status line installed."
Write-Host "  Renderer: $scriptPath"
Write-Host "  Settings: $settingsPath"
if (Test-Path "$settingsPath.bak") { Write-Host "  Backup:   $settingsPath.bak" }
Write-Host "Restart Claude Code (or open a new session) to see it."
