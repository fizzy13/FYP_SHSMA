@echo off
setlocal

echo Stopping existing AI detector processes...
powershell -NoProfile -Command "$processes = Get-CimInstance Win32_Process -Filter 'Name = ''python.exe''' | Where-Object { $_.CommandLine -like '*tapo_ai_detector.py*' }; foreach ($process in $processes) { Stop-Process -Id $process.ProcessId -Force }; Write-Output ('Stopped ' + @($processes).Count + ' AI detector process(es).')"
if errorlevel 1 (
  echo Could not stop the existing AI detector.
  exit /b 1
)

call "%~dp0run_ai_detection.bat"

endlocal