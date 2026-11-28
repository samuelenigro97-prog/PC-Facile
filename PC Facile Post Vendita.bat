@echo off
title PC Facile - Post Vendita
net session >nul 2>&1 || (
    powershell -NoProfile -ExecutionPolicy Bypass -Command "$p='%~f0'; $q=[char]34; Start-Process -FilePath 'cmd.exe' -ArgumentList ('/c ' + $q + $q + $p + $q + $q) -Verb RunAs"
    exit /b
)
cd /d "%~dp0" >nul 2>&1
call "%~dp0PC Facile Windows.bat" -PostVendita %*
