@echo off
title PC Facile - Post Vendita
set "SCRIPT_DIR=%~dp0"
set "SCRIPT_PATH=%~f0"
cd /d "%SCRIPT_DIR%" >nul 2>&1

if exist "%SCRIPT_PATH%.nuovo" (
    move /y "%SCRIPT_PATH%.nuovo" "%SCRIPT_PATH%" >nul 2>&1 && "%SCRIPT_PATH%" %*
)

if /i "%~1"=="elevated" (
    shift /1
    goto :elevato
)
net session >nul 2>&1
if %errorlevel% equ 0 goto :elevato
fltmc >nul 2>&1
if %errorlevel% equ 0 goto :elevato

powershell -NoProfile -ExecutionPolicy Bypass -Command "$p='%SCRIPT_PATH%'; $q=[char]34; try { Start-Process -FilePath 'cmd.exe' -ArgumentList ('/c ' + $q + $q + $p + $q + ' elevated' + $q) -Verb RunAs -ErrorAction Stop } catch { Start-Process -FilePath $p -ArgumentList 'elevated' -Verb RunAs }"
exit

:elevato
cd /d "%SCRIPT_DIR%" >nul 2>&1
call "%SCRIPT_DIR%PC Facile Windows.bat" elevated -PostVendita
