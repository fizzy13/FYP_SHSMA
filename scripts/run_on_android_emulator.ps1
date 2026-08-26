$ErrorActionPreference = 'Stop'

$projectRoot = Split-Path $PSScriptRoot -Parent
$androidSdk = Join-Path $env:LOCALAPPDATA 'Android\Sdk'
$emulatorExe = Join-Path $androidSdk 'emulator\emulator.exe'
$adbExe = Join-Path $androidSdk 'platform-tools\adb.exe'
$flutterBat = 'C:\flutter\bin\flutter.bat'
$avdName = 'Pixel_9_Pro'

if (-not (Test-Path $emulatorExe)) { throw "Android emulator not found at $emulatorExe" }
if (-not (Test-Path $adbExe)) { throw "ADB not found at $adbExe" }
if (-not (Test-Path $flutterBat)) { throw "Flutter not found at $flutterBat" }

$emulatorDevice = & $adbExe devices | Select-String -Pattern '^emulator-\d+\s+device' | Select-Object -First 1

if (-not $emulatorDevice) {
  Write-Host "Starting Android emulator: $avdName"
  Start-Process -FilePath $emulatorExe -ArgumentList @('-avd', $avdName) | Out-Null

  Write-Host 'Waiting for emulator to connect...'
  & $adbExe wait-for-device | Out-Null

  while ($true) {
    $bootState = (& $adbExe shell getprop sys.boot_completed 2>$null).Trim()
    if ($bootState -eq '1') { break }
    Start-Sleep -Seconds 2
  }
}

$emulatorDevice = & $adbExe devices | Select-String -Pattern '^emulator-\d+\s+device' | Select-Object -First 1
if (-not $emulatorDevice) {
  throw 'An Android emulator device was not detected after startup.'
}

$deviceId = ($emulatorDevice.Line -split '\s+')[0]
Write-Host "Running Flutter on emulator device: $deviceId"
Set-Location $projectRoot
& $flutterBat run -d $deviceId --target lib/main.dart