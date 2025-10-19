@echo off
REM Discord Tools Suite Launcher
REM Starts the launcher with optimal window size

REM Check if Windows Terminal is available
where wt.exe >nul 2>&1
if %ERRORLEVEL% EQU 0 (
    REM Use Windows Terminal with fixed size
    wt.exe --size 79,35 --title "Discord Tools Suite" pwsh.exe -NoExit -ExecutionPolicy Bypass -File "%~dp0DiscordToolsLauncher.ps1"
) else (
    REM Fallback to PowerShell (will use classic console or default terminal)
    pwsh.exe -NoExit -ExecutionPolicy Bypass -File "%~dp0DiscordToolsLauncher.ps1"
)
