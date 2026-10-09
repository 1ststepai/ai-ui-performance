@echo off
powershell.exe -NoProfile -ExecutionPolicy Bypass -File "%~dp0skills\codex-performance\scripts\Codex-Performance.ps1" -Mode Speed
echo.
echo Restore with the same PowerShell script using -Mode Restore.
pause
