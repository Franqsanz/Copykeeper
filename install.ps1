# ============================================================
#  Instalador de CopyKeeper
#  - Copia el programa a %LOCALAPPDATA%\Programs\CopyKeeper
#  - Lo agrega al PATH del usuario (comando: copykeeper)
#  - Deja la config en %APPDATA%\CopyKeeper
#  No requiere permisos de administrador.
# ============================================================

$ErrorActionPreference = 'Stop'
try { [Console]::OutputEncoding = [System.Text.Encoding]::UTF8 } catch {}

$App        = 'CopyKeeper'
$src        = $PSScriptRoot
$installDir = Join-Path $env:LOCALAPPDATA "Programs\$App"
$dataDir    = Join-Path $env:APPDATA $App

Write-Host "============================================================" -ForegroundColor Cyan
Write-Host "                 INSTALANDO $App" -ForegroundColor Cyan
Write-Host "============================================================" -ForegroundColor Cyan

# --- Verificar que estan los archivos necesarios junto al instalador ---
$necesarios = @('backup.ps1', 'copyFolders.ps1')
foreach ($f in $necesarios) {
    if (-not (Test-Path -LiteralPath (Join-Path $src $f))) {
        Write-Host "ERROR: no se encontro '$f' junto al instalador." -ForegroundColor Red
        Write-Host "Asegurate de ejecutar install.bat desde la carpeta del proyecto." -ForegroundColor Red
        return
    }
}

# --- Crear carpetas ---
New-Item -Path $installDir -ItemType Directory -Force | Out-Null
New-Item -Path $dataDir    -ItemType Directory -Force | Out-Null
Write-Host (" Carpeta de programa: {0}" -f $installDir)
Write-Host (" Carpeta de datos   : {0}" -f $dataDir)

# --- Copiar archivos del programa ---
Copy-Item -LiteralPath (Join-Path $src 'backup.ps1')      -Destination $installDir -Force
Copy-Item -LiteralPath (Join-Path $src 'copyFolders.ps1') -Destination $installDir -Force
if (Test-Path -LiteralPath (Join-Path $src 'uninstall.ps1')) {
    Copy-Item -LiteralPath (Join-Path $src 'uninstall.ps1') -Destination $installDir -Force
}
Write-Host " Archivos copiados." -ForegroundColor Green

# --- Sembrar la config (solo si todavia no existe una) ---
$cfgDest = Join-Path $dataDir 'backup-config.json'
$cfgSrc  = Join-Path $src 'backup-config.json'
$cfgExample = Join-Path $src 'backup-config.example.json'
if (-not (Test-Path -LiteralPath $cfgDest)) {
    if (Test-Path -LiteralPath $cfgSrc) {
        Copy-Item -LiteralPath $cfgSrc -Destination $cfgDest -Force
        Write-Host " Config inicial copiada desde el proyecto." -ForegroundColor Green
    } elseif (Test-Path -LiteralPath $cfgExample) {
        Copy-Item -LiteralPath $cfgExample -Destination $cfgDest -Force
        Write-Host " Config inicial creada desde el ejemplo (ajustala en el menu)." -ForegroundColor Yellow
    } else {
        Write-Host " (Se creara una config nueva al abrir el programa)" -ForegroundColor DarkGray
    }
} else {
    Write-Host " Config existente conservada." -ForegroundColor Green
}

# --- Crear el lanzador 'copykeeper.cmd' ---
$cmdPath = Join-Path $installDir 'copykeeper.cmd'
$cmdBody = "@echo off`r`npowershell.exe -NoProfile -ExecutionPolicy Bypass -File ""%~dp0backup.ps1"" %*`r`n"
Set-Content -LiteralPath $cmdPath -Value $cmdBody -Encoding ASCII
Write-Host " Lanzador 'copykeeper' creado." -ForegroundColor Green

# --- Agregar al PATH del usuario (si no esta) ---
$userPath = [Environment]::GetEnvironmentVariable('Path', 'User')
$yaEsta = $false
if ($userPath) {
    foreach ($p in ($userPath -split ';')) {
        if ($p -and ($p.TrimEnd('\') -ieq $installDir.TrimEnd('\'))) { $yaEsta = $true; break }
    }
}
if (-not $yaEsta) {
    $nuevoPath = if ([string]::IsNullOrWhiteSpace($userPath)) { $installDir }
                 else { $userPath.TrimEnd(';') + ';' + $installDir }
    [Environment]::SetEnvironmentVariable('Path', $nuevoPath, 'User')
    Write-Host " Agregado al PATH del usuario." -ForegroundColor Green
} else {
    Write-Host " Ya estaba en el PATH." -ForegroundColor DarkGray
}

Write-Host ""
Write-Host "============================================================" -ForegroundColor Green
Write-Host "  INSTALACION COMPLETADA" -ForegroundColor Green
Write-Host "============================================================" -ForegroundColor Green
Write-Host ""
Write-Host " Abri una NUEVA consola (CMD o PowerShell) y escribi:" -ForegroundColor Yellow
Write-Host "     copykeeper" -ForegroundColor White
Write-Host ""
Write-Host " Para desinstalar, ejecuta uninstall.bat (o uninstall.ps1)." -ForegroundColor DarkGray
Write-Host ""
