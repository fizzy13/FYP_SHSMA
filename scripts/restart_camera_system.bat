@echo off
setlocal

echo Stopping SHSMA camera relay and AI detector processes...
powershell -NoProfile -Command "$currentProcessId = $PID; $processes = Get-CimInstance Win32_Process; foreach ($process in $processes) { $command = $process.CommandLine; $isCameraWorker = ($process.Name -eq 'go2rtc.exe') -or (($process.Name -eq 'python.exe') -and ($command -like '*tapo_ai_detector.py*')) -or (($process.Name -eq 'dart.exe' -or $process.Name -eq 'dartvm.exe') -and ($command -like '*cors_proxy.dart*')); if (($process.ProcessId -ne $currentProcessId) -and $isCameraWorker) { Stop-Process -Id $process.ProcessId -Force -ErrorAction SilentlyContinue } }"
if errorlevel 1 (
  echo Could not reset the camera processes.
  exit /b 1
)

timeout /t 2 /nobreak >nul
echo Starting a fresh SHSMA camera system...
call "%~dp0run_ai_detection.bat"

endlocal