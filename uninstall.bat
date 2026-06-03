@echo off
:: Desinstalador de CopyKeeper (doble clic)
powershell.exe -NoProfile -ExecutionPolicy Bypass -File "%~dp0uninstall.ps1"
echo.
pause
