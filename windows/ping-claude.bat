@echo off
chcp 65001 >nul 2>&1
if /i "%~1"=="schedule-install" goto schedule_install
if /i "%~1"=="schedule-remove" goto schedule_remove

setlocal EnableDelayedExpansion

rem Claude Code path if PATH is bare (PowerShell: Get-Command claude -> Source).
rem Uncomment and set CLAUDE_EXE=full path:
rem set "CLAUDE_EXE=%USERPROFILE%\AppData\Roaming\npm\claude.cmd"

set "PATH=%PATH%;%APPDATA%\npm;%LOCALAPPDATA%\Programs;%LOCALAPPDATA%\Microsoft\WindowsApps;%USERPROFILE%\.local\bin;%USERPROFILE%\scoop\shims;%USERPROFILE%\.cargo\bin"

set "msg=."
set tries=3
set pause_sec=30

if defined CLAUDE_EXE (
  set "cc=!CLAUDE_EXE!"
) else (
  set "cc=claude"
  where claude >nul 2>&1
  if errorlevel 1 if exist "%APPDATA%\npm\claude.cmd" set "cc=%APPDATA%\npm\claude.cmd"
)

where "!cc!" >nul 2>&1
if not errorlevel 1 goto have_cc
if exist "!cc!" goto have_cc

echo %date% %time%  claude not in PATH - set CLAUDE_EXE near top ^(PowerShell: Get-Command claude^)
exit /b 9009

:have_cc

powershell -NoProfile -ExecutionPolicy Bypass -File "%~dp0internal\cooldown.ps1" check
if errorlevel 1 exit /b 0

set "caf=%TEMP%\claude-auto-reset-out.txt"
set "cbf=%TEMP%\claude-auto-reset-err.txt"
set "ccf=%TEMP%\claude-auto-reset-combined.txt"

set /a i=0
:loop
set /a i+=1
echo %date% %time%  attempt !i!

del "%ccf%" >nul 2>&1
call "!cc!" -p "!msg!" --output-format text <nul 1>"%caf%" 2>"%cbf%"
set "cce=!errorlevel!"

type "%caf%" 2>nul
type "%cbf%" 2>nul
(type "%caf%" 2>nul & echo. & type "%cbf%" 2>nul) > "%ccf%" 2>nul

if "!cce!"=="0" (
  powershell -NoProfile -ExecutionPolicy Bypass -File "%~dp0internal\cooldown.ps1" clear
  echo ok, done
  exit /b 0
)

echo exit code !cce!

powershell -NoProfile -ExecutionPolicy Bypass -File "%~dp0internal\cooldown.ps1" set "-CombinedLogPath" "%ccf%"
set "cds=!errorlevel!"
if "!cds!"=="0" exit /b 0

if !i! geq %tries% exit /b 1
timeout /t %pause_sec% /nobreak >nul
goto loop

rem --- Task Scheduler helpers ---

:schedule_install
set "SELF=%~f0"
set "TN=claude-auto-reset"
echo creating task "%TN%" every 4 hours as current user
schtasks /create /f /tn "%TN%" /sc HOURLY /mo 4 /rl LIMITED /tr "cmd.exe /c call \"%SELF%\"" || (
  echo failed. Run schedule-install from cmd as admin or create task manually in taskschd.msc
  exit /b 1
)
echo ok. Open taskschd.msc and check "%TN%"
exit /b 0

:schedule_remove
set "TN=claude-auto-reset"
schtasks /delete /f /tn "%TN%" || (
  echo delete failed maybe task gone: %TN%
  exit /b 1
)
echo ok, removed task %TN%
exit /b 0
