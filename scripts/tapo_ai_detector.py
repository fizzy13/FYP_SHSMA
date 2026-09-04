"""Local YOLO detector for Tapo streams relayed by go2rtc.

Start go2rtc first, then run:
    python scripts/tapo_ai_detector.py

Set GOOGLE_APPLICATION_CREDENTIALS to an ignored Firebase service-account JSON
file before starting the detector.
"""

import argparse
import logging
import os
import time
import urllib.parse
import urllib.request
from collections import defaultdict
from dataclasses import dataclass
from typing import Iterable

import cv2
import firebase_admin
import numpy as np
from firebase_admin import credentials, firestore
from google.cloud.firestore_v1.base_query import FieldFilter
from ultralytics import YOLO

ALLOWED_CLASSES = {"person", "cat", "dog", "bird"}
ANIMAL_CLASSES = {"cat", "dog", "bird"}
MOTION_CHANGE_THRESHOLD = 0.035
SNAPSHOT_DIRECTORY = os.path.join(os.path.dirname(os.path.dirname(__file__)), "snapshots")


@dataclass(frozen=True)
class Camera:
    identifier: str
    label: str
    source_ip: str


DEFAULT_CAMERAS = (
    Camera("tapo1", "Front Camera", "192.168.1.17"),
    Camera("tapo2", "Back Camera", "192.168.1.18"),
)


def parse_args() -> argparse.Namespace:
    parser = argparse.ArgumentParser(description="Detect people, cats, dogs, and birds from Tapo cameras.")
    parser.add_argument("--model", default="yolo11n.pt", help="Ultralytics model name or local weights path.")
    parser.add_argument("--confidence", type=float, default=0.65, help="Minimum detection confidence (0-1).")
    parser.add_argument("--sample-seconds", type=float, default=2.0, help="Seconds between analyzed frames per camera.")
    parser.add_argument("--cooldown-seconds", type=float, default=30.0, help="Alert cooldown for each camera and class.")
    parser.add_argument("--confirmations", type=int, default=2, help="Matching samples needed before alerting.")
    parser.add_argument("--device", default=None, help="YOLO device, for example cpu or 0 for the first NVIDIA GPU.")
    parser.add_argument("--relay-url", default="http://127.0.0.1:8090", help="Local CORS proxy URL.")
    parser.add_argument("--snapshot-base-url", default="http://127.0.0.1:8090", help="Relay URL visible to the SHSMA app.")
    return parser.parse_args()


def initialize_firestore() -> firestore.Client:
    credential_path = os.environ.get("GOOGLE_APPLICATION_CREDENTIALS")
    if not credential_path:
        raise RuntimeError("Set GOOGLE_APPLICATION_CREDENTIALS to your Firebase service-account JSON file.")
    if not os.path.isfile(credential_path):
        raise RuntimeError(f"Firebase service-account file was not found: {credential_path}")

    firebase_admin.initialize_app(credentials.Certificate(credential_path))
    return firestore.client()


def get_camera_settings(database: firestore.Client) -> dict:
    owners = database.collection("Users").where(
        filter=FieldFilter("aiDetectorOwner", "==", True)
    ).get()
    if not owners:
        return {}
    latest_owner = max(
        owners,
        key=lambda owner: (
            owner.to_dict().get("aiDetectorUpdatedAt").timestamp()
            if hasattr(owner.to_dict().get("aiDetectorUpdatedAt"), "timestamp")
            else 0
        ),
    )
    return latest_owner.to_dict()


def get_managed_detection_options(database: firestore.Client) -> dict:
    settings = database.collection("ai_detection_settings").document("current").get()
    return settings.to_dict() if settings.exists else {}


def best_detections(results: Iterable, model: YOLO, confidence: float) -> dict[str, float]:
    detected: dict[str, float] = {}
    for result in results:
        for box in result.boxes:
            score = float(box.conf[0])
            label = model.names[int(box.cls[0])]
            if label in ALLOWED_CLASSES and score >= confidence:
                detected[label] = max(detected.get(label, 0.0), score)
    return detected


def save_detection_snapshot(camera: Camera, detected_class: str, frame: np.ndarray) -> str | None:
    camera_directory = os.path.join(SNAPSHOT_DIRECTORY, camera.identifier)
    os.makedirs(camera_directory, exist_ok=True)
    filename = f"{time.time_ns()}-{detected_class}.jpg"
    snapshot_path = os.path.join(camera_directory, filename)
    saved = cv2.imwrite(snapshot_path, frame, [cv2.IMWRITE_JPEG_QUALITY, 90])
    if not saved:
        logging.warning("Could not save the %s detection snapshot.", camera.label)
        return None
    return f"snapshots/{camera.identifier}/{filename}"


def create_alert(
    database: firestore.Client,
    camera: Camera,
    detected_class: str,
    confidence: float,
    user_id: str | None,
    frame: np.ndarray,
    snapshot_base_url: str,
) -> None:
    category = "Person Detected" if detected_class == "person" else "Animal Detected"
    message = f"{detected_class.title()} detected at {camera.label} ({confidence:.0%} confidence)."
    alert = {
            "type": category,
            "alerts": category,
            "message": message,
            "location": camera.label,
            "status": "LIVE",
            "sourceIp": camera.source_ip,
            "cameraId": camera.identifier,
            "detectedClass": detected_class,
            "detectionCategory": "person" if detected_class == "person" else "animal",
            "confidence": round(confidence, 4),
            "timestamp": firestore.SERVER_TIMESTAMP,
            "clientTimestamp": firestore.SERVER_TIMESTAMP,
    }
    image_path = save_detection_snapshot(camera, detected_class, frame)
    if image_path is not None:
        alert["imagePath"] = image_path
        alert["imageUrl"] = f"{snapshot_base_url.rstrip('/')}/{image_path}"
    if user_id:
        alert["userId"] = user_id
    else:
        logging.warning("No SHSMA user has logged in yet; saving a shared alert.")
    database.collection("Alerts").add(alert)
    logging.info("Alert sent: %s on %s (%.0f%%)", detected_class, camera.label, confidence * 100)


def create_motion_alert(database: firestore.Client, camera: Camera, user_id: str | None) -> None:
    message = f"Motion detected at {camera.label}."
    alert = {
        "type": "Motion Alert",
        "alerts": "Motion Alert",
        "message": message,
        "location": camera.label,
        "status": "LIVE",
        "sourceIp": camera.source_ip,
        "cameraId": camera.identifier,
        "userId": user_id,
        "timestamp": firestore.SERVER_TIMESTAMP,
        "clientTimestamp": firestore.SERVER_TIMESTAMP,
    }
    database.collection("Alerts").add(alert)
    logging.info("Motion alert sent for %s", camera.label)


def get_frame(camera: Camera, relay_url: str):
    parameters = urllib.parse.urlencode({"src": camera.identifier, "cb": time.time_ns()})
    snapshot_url = f"{relay_url.rstrip('/')}/api/frame.jpeg?{parameters}"
    with urllib.request.urlopen(snapshot_url, timeout=8) as response:
        image = response.read()
    return cv2.imdecode(np.frombuffer(image, dtype=np.uint8), cv2.IMREAD_COLOR)


def main() -> None:
    args = parse_args()
    if not 0 < args.confidence <= 1:
        raise ValueError("--confidence must be greater than 0 and no more than 1.")
    if args.confirmations < 1 or args.sample_seconds <= 0 or args.cooldown_seconds < 0:
        raise ValueError("Sampling, cooldown, and confirmation values must be positive.")

    logging.basicConfig(level=logging.INFO, format="%(asctime)s %(levelname)s %(message)s")
    database = initialize_firestore()
    model = YOLO(args.model)
    confirmations: dict[tuple[str, str], int] = defaultdict(int)
    last_alert_at: dict[tuple[str, str], float] = defaultdict(float)
    previous_frames: dict[str, np.ndarray] = {}

    try:
        while True:
            cycle_started = time.monotonic()
            settings = get_camera_settings(database)
            motion_alerts_enabled = settings.get("motionAlertsEnabled", True)
            ai_detection_enabled = settings.get("aiDetectionEnabled", True)
            for camera in DEFAULT_CAMERAS:
                if not motion_alerts_enabled:
                    for detected_class in ALLOWED_CLASSES:
                        confirmations[(camera.identifier, detected_class)] = 0
                    continue

                try:
                    frame = get_frame(camera, args.relay_url)
                except Exception as error:
                    logging.warning("Could not read %s: %s", camera.label, error)
                    continue
                if frame is None:
                    logging.warning("Could not decode a frame from %s.", camera.label)
                    continue

                if not ai_detection_enabled:
                    grayscale = cv2.resize(cv2.cvtColor(frame, cv2.COLOR_BGR2GRAY), (160, 90))
                    previous = previous_frames.get(camera.identifier)
                    previous_frames[camera.identifier] = grayscale
                    if previous is None:
                        continue
                    changed_ratio = float(np.mean(cv2.absdiff(grayscale, previous) > 25))
                    key = (camera.identifier, "motion")
                    if changed_ratio >= MOTION_CHANGE_THRESHOLD and time.monotonic() - last_alert_at[key] >= args.cooldown_seconds:
                        create_motion_alert(database, camera, settings.get("uid"))
                        last_alert_at[key] = time.monotonic()
                    continue

                results = model.predict(frame, conf=args.confidence, verbose=False, device=args.device)
                classes = best_detections(results, model, args.confidence)
                managed_options = get_managed_detection_options(database)
                if not managed_options.get("humanDetectionEnabled", True):
                    classes.pop("person", None)
                if not managed_options.get("animalDetectionEnabled", True):
                    for animal in ANIMAL_CLASSES:
                        classes.pop(animal, None)
                for detected_class, score in classes.items():
                    key = (camera.identifier, detected_class)
                    confirmations[key] += 1
                    if confirmations[key] < args.confirmations:
                        continue
                    if time.monotonic() - last_alert_at[key] < args.cooldown_seconds:
                        continue
                    create_alert(
                        database,
                        camera,
                        detected_class,
                        score,
                        settings.get("uid"),
                        frame,
                        args.snapshot_base_url,
                    )
                    last_alert_at[key] = time.monotonic()
                    confirmations[key] = 0

                for detected_class in ALLOWED_CLASSES.difference(classes):
                    confirmations[(camera.identifier, detected_class)] = 0

            remaining = args.sample_seconds - (time.monotonic() - cycle_started)
            if remaining > 0:
                time.sleep(remaining)
    except KeyboardInterrupt:
        logging.info("AI detector stopped.")


if __name__ == "__main__":
    main()