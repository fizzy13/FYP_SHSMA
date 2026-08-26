@echo off
cd /d "C:\Users\User\Desktop\shsma\go2rtc_win64"
start "go2rtc" /min "C:\Users\User\Desktop\shsma\go2rtc_win64\go2rtc.exe"
cd /d "C:\Users\User\Desktop\shsma"
start "cors_proxy" /min "C:\flutter\bin\cache\dart-sdk\bin\dart.exe" run scripts/cors_proxy.dart
