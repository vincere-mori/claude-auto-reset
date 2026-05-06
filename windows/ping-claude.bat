@echo off
if /i "%~1"=="schedule-install" goto schedule_install
if /i "%~1"=="schedule-remove" goto schedule_remove

chcp 65001 >nul
setlocal EnableDelayedExpansion

rem Путь к Claude Code CLI, если ниже дописанный PATH не помогает (взять из PowerShell: Get-Command claude → Source).
rem Убери "rem " в начале и подставь свой путь:
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

echo %date% %time%  claude не найден. Впиши вверху CLAUDE_EXE=полный путь ^(в PowerShell: Get-Command claude^)
exit /b 9009

:have_cc

set /a i=0
:loop
set /a i+=1
echo %date% %time%  попытка !i!

call "!cc!" -p "!msg!" --output-format text <nul
if not errorlevel 1 (
  echo норм, выходим
  exit /b 0
)

echo код ошибки !errorlevel!
if !i! geq %tries% exit /b 1
timeout /t %pause_sec% /nobreak >nul
goto loop

rem --- планировщик (вызывается из отдельного cmd если нужно) ---

:schedule_install
set "SELF=%~f0"
set "TN=claude-auto-reset"
echo создаём задачу "%TN%" - каждые 4 часа, под текущим юзером
schtasks /create /f /tn "%TN%" /sc HOURLY /mo 4 /rl LIMITED /tr "cmd.exe /c call \"%SELF%\"" || (
  echo не вышло. Запускай этот же батник с schedule-install из cmd от администратора или создай задачу вручную.
  exit /b 1
)
echo ок. Открой taskschd.msc и проверь "%TN%"
exit /b 0

:schedule_remove
set "TN=claude-auto-reset"
schtasks /delete /f /tn "%TN%" || (
  echo задача не удалена возможно уже нет: %TN%
  exit /b 1
)
echo ок, задача %TN% снята
exit /b 0
