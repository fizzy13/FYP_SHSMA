@echo off
setlocal

for %%I in ("%~dp0..") do set "PROJECT_ROOT=%%~fI"
set "VENV_DIR=%PROJECT_ROOT%\.venv-ai"
set "CREDENTIAL_FILE=%PROJECT_ROOT%\secrets\firebase-service-account.json"
for /f %%I in ('powershell -NoProfile -ExecutionPolicy Bypass -File "%PROJECT_ROOT%\scripts\get_local_relay_ip.ps1"') do set "RELAY_IP=%%I"
if "%RELAY_IP%"=="" set "RELAY_IP=127.0.0.1"

if not exist "%CREDENTIAL_FILE%" (
  echo Firebase service-account file not found:
  echo %CREDENTIAL_FILE%
  echo Create this file by following scripts\AI_DETECTION_SETUP.md.
  echo The detector needs this credential to save alerts to your Firebase project.
  exit /b 1
)

where python >nul 2>nul
if errorlevel 1 (
  echo Python 3.10 or later is required but was not found on PATH.
  echo Install Python from https://www.python.org/downloads/ and select "Add python.exe to PATH".
  exit /b 1
)

echo Starting camera relays...
call "%PROJECT_ROOT%\scripts\start_camera_relays.bat"

curl.exe --silent --show-error --fail --max-time 10 "http://127.0.0.1:8090/api/frame.jpeg?src=tapo1" -o NUL
if errorlevel 1 (
  echo Camera relay did not start. Check that go2rtc and the CORS proxy can use ports 1984 and 8090.
  exit /b 1
)

powershell -NoProfile -Command "$running = $false; foreach ($process in Get-CimInstance Win32_Process -Filter 'Name = ''python.exe''') { if ($process.CommandLine -like '*tapo_ai_detector.py*') { $running = $true; break } }; if ($running) { exit 0 } else { exit 1 }"
if errorlevel 2 (
  echo Could not check whether AI detection is already running.
  exit /b 1
)
if not errorlevel 1 (
  echo AI detection is already running. Do not start a second copy.
  exit /b 0
)

if not exist "%VENV_DIR%\Scripts\python.exe" (
  echo Creating the AI detector virtual environment...
  python -m venv "%VENV_DIR%"
  if errorlevel 1 exit /b 1
)

echo Installing or updating AI detector dependencies...
"%VENV_DIR%\Scripts\python.exe" -m pip install -r "%PROJECT_ROOT%\scripts\requirements-ai-detector.txt"
if errorlevel 1 exit /b 1

set "GOOGLE_APPLICATION_CREDENTIALS=%CREDENTIAL_FILE%"
echo Starting AI detection. Sign into SHSMA to select the account that receives alerts.
echo Press Ctrl+C to stop.
"%VENV_DIR%\Scripts\python.exe" "%PROJECT_ROOT%\scripts\tapo_ai_detector.py" --snapshot-base-url "http://%RELAY_IP%:8090"

endlocal