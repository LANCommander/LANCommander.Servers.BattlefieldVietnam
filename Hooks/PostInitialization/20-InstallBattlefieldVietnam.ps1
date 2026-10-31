#Requires -Modules Logging
#Requires -Modules Hooks
#Requires -Modules OverlayFS

# Install the Linux dedicated server from BFV_SERVER_URL (a .tar.xz/.tar.gz/.zip with
# bfv_linded.dynamic at its root). Reinstalls when BFV_SERVER_URL changes; the URL of the
# installed package is kept in Server/.bfv-server-url.

Invoke-Hook "PreInstallBattlefieldVietnam"

$exe    = Join-Path $Env:SERVER_DIR 'bfv_linded.dynamic'
$marker = Join-Path $Env:SERVER_DIR '.bfv-server-url'
$installed = if (Test-Path -Path $marker) { (Get-Content -Path $marker -Raw).Trim() }

if ((Test-Path -Path $exe) -and (-not $Env:BFV_SERVER_URL -or $installed -eq $Env:BFV_SERVER_URL -or -not $installed)) {
    Write-Log "Battlefield Vietnam server found in $Env:SERVER_DIR"
} elseif (-not $Env:BFV_SERVER_URL) {
    Write-Log -Level Error "bfv_linded.dynamic not found in $Env:SERVER_DIR and BFV_SERVER_URL is empty"
} else {
    Write-Log "Downloading Battlefield Vietnam server from $Env:BFV_SERVER_URL"

    $file = '/tmp/bfv-server' + [System.IO.Path]::GetExtension(([uri] $Env:BFV_SERVER_URL).AbsolutePath)

    curl -fsSL --retry 3 --output $file "$Env:BFV_SERVER_URL"
    if ($LASTEXITCODE -ne 0) { throw "Download failed: $Env:BFV_SERVER_URL" }

    if ($Env:BFV_SERVER_SHA256) {
        $hash = (Get-FileHash -Path $file -Algorithm SHA256).Hash
        if ($hash -ne $Env:BFV_SERVER_SHA256) {
            Remove-Item -Force -Path $file
            throw "SHA256 mismatch for $Env:BFV_SERVER_URL`: got $hash, expected $Env:BFV_SERVER_SHA256"
        }
    }

    New-Item -ItemType Directory -Path $Env:SERVER_DIR -Force | Out-Null

    if ($file.EndsWith('.zip')) {
        unzip -q -o $file -d $Env:SERVER_DIR
    } else {
        tar -xf $file -C $Env:SERVER_DIR
    }
    if ($LASTEXITCODE -ne 0) { throw "Could not extract $file" }

    Remove-Item -Force -Path $file

    if (-not (Test-Path -Path $exe)) { throw "bfv_linded.dynamic not found in $Env:BFV_SERVER_URL" }

    chmod +x $exe (Join-Path $Env:SERVER_DIR 'bfv_linded.static')
    Set-Content -Path $marker -Value $Env:BFV_SERVER_URL
    chown -R "$($Env:UID):$($Env:GID)" $Env:SERVER_DIR

    # The overlay was mounted before Server/ was populated, and overlayfs doesn't reliably show
    # lower-dir changes made while mounted.
    mountpoint -q $Env:SERVER_ROOT
    if ($LASTEXITCODE -eq 0) {
        umount $Env:SERVER_ROOT
        Remove-Item -Path "$Env:WORK_DIR/*" -Recurse -Force -ErrorAction SilentlyContinue
        Mount-Overlay -MountPoint $Env:SERVER_ROOT -LowerDir $Env:SERVER_DIR -UpperDir $Env:OVERLAY_DIR -WorkDir $Env:WORK_DIR -RequireEmptyWorkDir -OverlayOption "xino=on"
        Write-Log "OverlayFS remounted"
    }

    Write-Log "Battlefield Vietnam server installed"
}

Invoke-Hook "PostInstallBattlefieldVietnam"

Set-Location $Env:SERVER_ROOT
