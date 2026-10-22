@echo off
set "DEMO=%~dp0dist\GETTOPIK-Teacher-Windows\gettopik_teacher_player.exe"
if exist "%DEMO%" (
  start "" "%DEMO%"
) else (
  cd /d "%~dp0player"
  flutter run -d windows
)
