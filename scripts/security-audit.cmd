@echo off
setlocal
powershell -NoProfile -ExecutionPolicy Bypass -File "%~dp0security-audit.ps1"
set EXITCODE=%ERRORLEVEL%
endlocal & exit /b %EXITCODE%
