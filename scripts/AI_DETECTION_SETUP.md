# Tapo AI Detection Setup

This detector identifies `person`, `cat`, `dog`, and `bird` from the two Tapo streams already exposed by `go2rtc`.

## One-time setup

1. Install Python 3.10 or later.
2. In PowerShell at the project root, create and activate a virtual environment:

   ```powershell
   py -m venv .venv-ai
   .\.venv-ai\Scripts\Activate.ps1
   pip install -r scripts\requirements-ai-detector.txt
   ```

3. In Firebase Console, create a service account key for the `shsma-db2b4` project. Save it as `secrets\firebase-service-account.json`; this path is ignored by Git.
4. Set the credential path in the PowerShell session:

   ```powershell
   $env:GOOGLE_APPLICATION_CREDENTIALS = "$PWD\secrets\firebase-service-account.json"
   ```

## Run the detector

Run this one command. It starts the camera relays and the AI detector, and creates the virtual environment and installs dependencies on its first run:

```powershell
scripts\run_ai_detection.bat
```

The first execution downloads the compact `yolo11n.pt` model. The script analyzes each camera once every two seconds from the local relay snapshots, requires two consecutive matching samples, and suppresses duplicate alerts for 30 seconds per camera and detected class. Do not start a second copy of this script.

After starting the detector, run `flutter run -d chrome` in a separate terminal and log into the SHSMA account that should receive the camera alerts. Each successful login makes that account the active owner for AI alerts. Use Ctrl+C to stop the detector.

Do not run `start_camera_relays.bat` separately: `run_ai_detection.bat` starts it for you.

If an older AI detector process is already running after a code update, use `scripts\restart_ai_detection.bat` to replace it with the current version.

If the camera preview freezes, use `scripts\restart_camera_system.bat`. It restarts only SHSMA's go2rtc relay, CORS proxy, and AI detector.

## Local AI snapshots

Person and animal detection images are saved on this laptop in `snapshots\`. The detector stores a local relay URL in the matching Firestore `Alerts` document, and the SHSMA Alerts page displays it. Firebase Storage is not required.

Keep the laptop and the device viewing SHSMA on the same reachable Wi-Fi network. When the laptop changes Wi-Fi, restart `scripts\restart_camera_system.bat` so the detector records the new local network address in future snapshot URLs.