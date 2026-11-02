@echo off
setlocal
cd /d "%~dp0"
for %%I in (flutter.bat) do set "SILENTPING_FLUTTER_BIN=%%~dp$PATH:I"
if not defined SILENTPING_FLUTTER_BIN (
  echo Flutter was not found. Add Flutter's bin folder to PATH, then try again.
  pause
  exit /b 1
)
echo Connect your phone and this computer to the same Wi-Fi.
echo Open one of these addresses in Safari on iPhone or Chrome on Samsung:
powershell.exe -NoProfile -Command "[System.Net.NetworkInformation.NetworkInterface]::GetAllNetworkInterfaces() | Where-Object { $_.OperationalStatus -eq 'Up' } | ForEach-Object { $_.GetIPProperties().UnicastAddresses } | Where-Object { $_.Address.AddressFamily -eq 'InterNetwork' -and -not [System.Net.IPAddress]::IsLoopback($_.Address) -and $_.Address.IPAddressToString -notlike '169.254.*' } | ForEach-Object { 'http://' + $_.Address.IPAddressToString + ':7358' }"
echo Wait for Flutter to say the app is being served, then open the address.
echo Keep this window open. Press q to stop sharing the preview.
echo If Windows asks about firewall access, allow it on your private home network.
"%SILENTPING_FLUTTER_BIN%cache\dart-sdk\bin\dart.exe" "%SILENTPING_FLUTTER_BIN%cache\flutter_tools.snapshot" --no-version-check run --release --no-web-resources-cdn -d web-server --web-hostname 0.0.0.0 --web-port 7358
if errorlevel 1 (
  echo Phone preview could not start. Check the error above.
  pause
)
