@echo off
setlocal
for %%I in ("%~dp0..") do set "PROJECT_ROOT=%%~fI"

netstat -ano | findstr /r /c:":1984 .*LISTENING" >nul
if errorlevel 1 (
	start "go2rtc" /min /d "%PROJECT_ROOT%\go2rtc_win64" "%PROJECT_ROOT%\go2rtc_win64\go2rtc.exe"
) else (
	echo go2rtc is already running on port 1984.
)

netstat -ano | findstr /r /c:":8090 .*LISTENING" >nul
if errorlevel 1 (
	start "cors_proxy" /min /d "%PROJECT_ROOT%" "C:\flutter\bin\cache\dart-sdk\bin\dart.exe" run scripts/cors_proxy.dart
) else (
	echo CORS proxy is already running on port 8090.
)

endlocal
