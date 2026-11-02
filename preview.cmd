@echo off
setlocal
cd /d "%~dp0"
for %%I in (flutter.bat) do set "SILENTPING_FLUTTER_BIN=%%~dp$PATH:I"
if not defined SILENTPING_FLUTTER_BIN (
  echo Flutter was not found. Add Flutter's bin folder to PATH, then try again.
  pause
  exit /b 1
)
echo Starting SilentPing in Chrome. Keep this window open while testing.
"%SILENTPING_FLUTTER_BIN%cache\dart-sdk\bin\dart.exe" "%SILENTPING_FLUTTER_BIN%cache\flutter_tools.snapshot" --no-version-check run --release --no-web-resources-cdn -d chrome --web-port 7357
if errorlevel 1 (
  echo Preview could not start. Check the error above. Chrome must be installed.
  pause
)
