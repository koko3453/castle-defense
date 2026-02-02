@echo off
set PATH=C:\odin\dist;%PATH%
cd /d "%~dp0"
odin run src -out:rightward_hold.exe
pause
