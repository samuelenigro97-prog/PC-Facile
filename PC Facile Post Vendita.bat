@echo off
title PC Facile - Post Vendita
net session >nul 2>&1 || (
    powershell -NoProfile -ExecutionPolicy Bypass -Command "Start-Process -FilePath 'cmd.exe' -ArgumentList '/c \"\"%~f0\"\"' -Verb RunAs"
    exit /b
)
call "%~dp0PC Facile Windows.bat" -PostVendita %*
