# ============================================================
#  Desinstalador de CopyKeeper
#  - Quita la app del PATH del usuario
#  - Borra la carpeta del programa
#  - Pregunta si tambien borrar la config/datos
# ============================================================

$ErrorActionPreference = 'Stop'
try { [Console]::OutputEncoding = [System.Text.Encoding]::UTF8 } catch {}

$App        = 'CopyKeeper'
$installDir = Join-Path $env:LOCALAPPDATA "Programs\$App"
$dataDir    = Join-Path $env:APPDATA $App

Write-Host "============================================================" -ForegroundColor Cyan
Write-Host "               DESINSTALANDO $App" -ForegroundColor Cyan
Write-Host "============================================================" -ForegroundColor Cyan

# --- Quitar del PATH del usuario ---
$userPath = [Environment]::GetEnvironmentVariable('Path', 'User')
if ($userPath) {
    $partes = @($userPath -split ';' | Where-Object {
        $_ -and ($_.TrimEnd('\') -ine $installDir.TrimEnd('\'))
    })
    [Environment]::SetEnvironmentVariable('Path', ($partes -join ';'), 'User')
    Write-Host " Quitado del PATH del usuario." -ForegroundColor Green
}

# --- Borrar carpeta del programa ---
if (Test-Path -LiteralPath $installDir) {
    # Evitar borrar la carpeta si se ejecuta desde adentro
    Set-Location $env:USERPROFILE
    Remove-Item -LiteralPath $installDir -Recurse -Force
    Write-Host " Carpeta del programa eliminada." -ForegroundColor Green
} else {
    Write-Host " La carpeta del programa no existe (ya estaba desinstalado)." -ForegroundColor DarkGray
}

# --- Preguntar por la config/datos ---
if (Test-Path -LiteralPath $dataDir) {
    Write-Host ""
    Write-Host (" Tu configuracion esta en: {0}" -f $dataDir) -ForegroundColor Yellow
    $r = (Read-Host " Queres borrar tambien la configuracion? (S/N)").Trim().ToUpper()
    if ($r -eq 'S') {
        Remove-Item -LiteralPath $dataDir -Recurse -Force
        Write-Host " Configuracion eliminada." -ForegroundColor Green
    } else {
        Write-Host " Configuracion conservada." -ForegroundColor DarkGray
    }
}

Write-Host ""
Write-Host " Listo. (El cambio de PATH se aplica en consolas nuevas.)" -ForegroundColor Green
Write-Host ""
