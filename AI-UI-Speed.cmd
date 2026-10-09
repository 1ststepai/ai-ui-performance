@echo off
powershell.exe -NoProfile -ExecutionPolicy Bypass -File "%~dp0skills\ai-ui-performance\scripts\AI-UI-Performance.ps1" -Mode Speed -App Desktop
echo.
echo Restore using the same script with -Mode Restore -App All.
pause
