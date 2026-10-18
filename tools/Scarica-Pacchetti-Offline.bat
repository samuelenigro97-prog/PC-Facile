@echo off
title PC Facile - Preparazione Pacchetti Offline
REM ============================================================
REM  tools/Scarica-Pacchetti-Offline.bat
REM  Scarica tutti i programmi di installazione (.exe / .msi)
REM  direttamente sulla chiavetta USB (cartella 'installers').
REM ============================================================

net session >nul 2>&1
if %errorlevel% neq 0 (
    powershell -NoProfile -ExecutionPolicy Bypass -Command "try { Start-Process -FilePath 'cmd.exe' -ArgumentList '/c \"\"%~f0\" elevated %*\"' -Verb RunAs } catch { exit 1 }"
    if %errorlevel% neq 0 (
        echo.
        echo   [!] Privilegi amministratore necessari per salvare sulla chiavetta USB.
        echo   Fai click destro e scegli "Esegui come amministratore".
        echo.
        pause
    )
    exit /b
)

set "SCRIPT_DIR=%~dp0"
set "ROOT_DIR=%SCRIPT_DIR%..\"

cls
echo.
echo ============================================================
echo   PC FACILE - DOWNLOAD PACCHETTI OFFLINE (WINDOWS)
echo   Unieuro | Kit Autonomo da Banco
echo ============================================================
echo.
echo Avvio download dei pacchetti offline...
echo.

powershell -NoProfile -ExecutionPolicy Bypass -Command "& '%ROOT_DIR%setup-pc.ps1' -PreparaUSB -TargetDir '%ROOT_DIR%'"

echo.
echo ============================================================
echo   Operazione completata.
echo ============================================================
echo.
pause
