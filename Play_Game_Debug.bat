@echo off
setlocal enabledelayedexpansion

title Diabloid ARPG - Debug Console
cd /d "%~dp0"
set "PROJECT_DIR=%CD%"

set "GODOT_EXE="

:: 1. Search in WinGet packages directory for console binary
if exist "%LOCALAPPDATA%\Microsoft\WinGet\Packages\GodotEngine.GodotEngine_Microsoft.Winget.Source_8wekyb3d8bbwe\Godot_v4.7.2-stable_win64_console.exe" (
    set "GODOT_EXE=%LOCALAPPDATA%\Microsoft\WinGet\Packages\GodotEngine.GodotEngine_Microsoft.Winget.Source_8wekyb3d8bbwe\Godot_v4.7.2-stable_win64_console.exe"
)

if not defined GODOT_EXE (
    for /r "%LOCALAPPDATA%\Microsoft\WinGet\Packages" %%F in (Godot*_win64_console.exe) do (
        if not defined GODOT_EXE set "GODOT_EXE=%%F"
    )
)

if not defined GODOT_EXE (
    for /r "%LOCALAPPDATA%\Microsoft\WinGet\Packages" %%F in (Godot*_win64.exe) do (
        if not defined GODOT_EXE set "GODOT_EXE=%%F"
    )
)

if not defined GODOT_EXE (
    for %%X in (godot.exe Godot.exe) do (
        set "CHECK_PATH=%%~$PATH:X"
        if defined CHECK_PATH set "GODOT_EXE=!CHECK_PATH!"
    )
)

if not defined GODOT_EXE (
    echo [ERROR] Godot Engine executable not found on this computer!
    pause
    exit /b 1
)

echo [DEBUG] Launching Diabloid ARPG with console logging...
"%GODOT_EXE%" --path "%PROJECT_DIR%"
pause
