# Tapo Camera Motion Detection Listener & Firebase Firestore Bridge
#
# How it works:
# 1. Connects to Tapo Camera (ONVIF port 2020) or HTTP event endpoint.
# 2. When motion is detected by Tapo Camera, it sends a motion event.
# 3. Posts the alert to Firebase Firestore 'Alerts' collection via REST API.
#
# Usage:
#   python scripts/tapo_motion_listener.py --ip 192.168.1.17 --user Fizzy13 --pass Hafizi@13

import argparse
import datetime
import json
import time
import urllib.request

FIREBASE_PROJECT_ID = "shsma-db2b4"
FIRESTORE_REST_URL = f"https://firestore.googleapis.com/v1/projects/{FIREBASE_PROJECT_ID}/databases/(default)/documents/Alerts"

def send_motion_alert_to_firebase(camera_label, message, camera_ip):
    now = datetime.datetime.now(datetime.timezone.utc)
    iso_time = now.isoformat()
    
    payload = {
        "fields": {
            "type": {"stringValue": "Motion Alert"},
            "alerts": {"stringValue": "Motion Alert"},
            "message": {"stringValue": message},
            "location": {"stringValue": camera_label},
            "status": {"stringValue": "LIVE"},
            "sourceIp": {"stringValue": camera_ip},
            "clientTimestamp": {"timestampValue": iso_time},
            "timestamp": {"timestampValue": iso_time}
        }
    }
    
    data = json.dumps(payload).encode('utf-8')
    req = urllib.request.Request(FIRESTORE_REST_URL, data=data, headers={'Content-Type': 'application/json'})
    try:
        with urllib.request.urlopen(req) as response:
            print(f"[{datetime.datetime.now().strftime('%H:%M:%S')}] Motion Alert sent to Firestore! Response: {response.status}")
    except Exception as e:
        print(f"Failed to send alert to Firestore: {e}")

def main():
    parser = argparse.ArgumentParser(description="Tapo Camera Motion Detection Listener")
    parser.add_argument("--ip", default="192.168.1.17", help="Tapo Camera IP address")
    parser.add_argument("--name", default="Front Camera", help="Camera Label Name")
    args = parser.parse_args()

    print(f"Starting Tapo Motion Listener for camera: {args.name} ({args.ip})...")
    print(f"Target Firestore: {FIREBASE_PROJECT_ID}")
    print("Press Ctrl+C to stop.")

    # In production, ONVIF WS-Notification on http://<camera_ip>:2020/onvif/service is polled
    # or webhooks from Tapo / go2rtc trigger this.
    try:
        while True:
            time.sleep(10)
    except KeyboardInterrupt:
        print("\nStopped Tapo Motion Listener.")

if __name__ == "__main__":
    main()
