@echo off
cd /d "%~dp0"
call "%~dp0ping-claude.bat" schedule-install
if errorlevel 1 (
  echo.
  pause
  exit /b 1
)
echo.
pause
exit /b 0
