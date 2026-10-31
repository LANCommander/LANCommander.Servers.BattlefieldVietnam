#Requires -Modules Logging

# Write the BFV_* settings into mods/<BFV_MOD>/settings/<BFV_CONFIG>, and BFV_MAPS into
# settings/maplist.con. Files are edited through the merged view, so the edited copies land in
# Overlay/ and can be changed there; options without a BFV_* setting are never touched.

# bfv_linded lower-cases every path before opening it, but match case-insensitively anyway so
# mixed-case BFV_MOD/BFV_CONFIG values find the same files.
function Find-Path([string] $Parent, [string] $Name) {
    Get-ChildItem -Path $Parent -Force -ErrorAction SilentlyContinue |
        Where-Object { $_.Name -ieq $Name } | Select-Object -First 1 -ExpandProperty FullName
}

$mod      = Find-Path (Find-Path $Env:SERVER_ROOT 'Mods') $Env:BFV_MOD
$settings = if ($mod) { Find-Path $mod 'Settings' }

if (-not $settings) {
    Write-Log -Level Error "mods/$Env:BFV_MOD/settings not found in $Env:SERVER_ROOT; skipping server configuration"
    return
}

$file = Find-Path $settings $Env:BFV_CONFIG
if (-not $file) {
    $file = Join-Path $settings $Env:BFV_CONFIG.ToLowerInvariant()
    New-Item -ItemType File -Path $file | Out-Null
    Write-Log "Created $file"
}

$text    = [System.IO.File]::ReadAllText($file)
$newline = if ($text.Contains("`r`n")) { "`r`n" } else { "`n" }
$lines   = [System.Collections.Generic.List[string]]::new()
if ($text) { $lines.AddRange([string[]]($text.TrimEnd("`r", "`n") -split "\r?\n")) }

function ConvertTo-Quoted([string] $Value) { '"' + $Value.Replace('"', '') + '"' }

$internet = if ($Env:BFV_INTERNET -in 'true', '1', 'yes') { '1' } else { '0' }

$values = [ordered]@{
    'game.serverName'         = $(if ($Env:BFV_SERVER_NAME) { ConvertTo-Quoted $Env:BFV_SERVER_NAME })
    'game.serverPort'         = $Env:BFV_PORT
    'game.serverInternet'     = $internet
    'game.serverMaxPlayers'   = $Env:BFV_MAX_PLAYERS
    'game.serverPassword'     = $(if ($Env:BFV_PASSWORD) { ConvertTo-Quoted $Env:BFV_PASSWORD })
    'game.serverGamePlayMode' = $Env:BFV_GAME_MODE
}

# Replace each setting's line (console commands are case-insensitive), or append it
foreach ($key in $values.Keys) {
    if (-not $values[$key]) { continue }

    $line  = "$key $($values[$key])"
    $found = $false

    for ($i = 0; $i -lt $lines.Count; $i++) {
        if ($lines[$i] -imatch "^\s*$([regex]::Escape($key))(\s|$)") {
            $lines[$i] = $line
            $found = $true
        }
    }

    if (-not $found) { $lines.Add($line) }
}

[System.IO.File]::WriteAllText($file, ($lines -join $newline) + $newline)
chown "$($Env:UID):$($Env:GID)" $file

Write-Log "Applied BFV_* settings to $file"

# BFV_MAPS: comma- or space-separated level names, all played in BFV_GAME_MODE
if ($Env:BFV_MAPS) {
    $maps = $Env:BFV_MAPS -split '[,\s]+' | Where-Object { $_ }
    $tag  = $Env:BFV_MOD.ToLowerInvariant()
    $mode = if ($Env:BFV_GAME_MODE) { $Env:BFV_GAME_MODE } else { 'GPM_CQ' }

    $maplist = @($maps | ForEach-Object { "game.addLevel $_ $mode $tag" })
    $maplist += "game.setCurrentLevel $($maps[0]) $mode $tag"

    $mapFile = Find-Path $settings 'maplist.con'
    if (-not $mapFile) { $mapFile = Join-Path $settings 'maplist.con' }

    [System.IO.File]::WriteAllText($mapFile, ($maplist -join "`n") + "`n")
    chown "$($Env:UID):$($Env:GID)" $mapFile

    Write-Log "Wrote $($maps.Count) maps to $mapFile"
}
