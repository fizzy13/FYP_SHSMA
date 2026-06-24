# Arduino Setup Guide — ESP32-CAM Project

All 4 modules are **AI-Thinker ESP32-CAM**.
Uploading is done using the **ESP32-CAM MB** programmer board.

---

## Hardware You Have

| Item | Qty | Purpose |
|---|---|---|
| AI-Thinker ESP32-CAM | 4 | Camera modules |
| ESP32-CAM MB (programmer board) | 1 | Uploading code to each camera |
| HC-SR04 Ultrasonic Sensor | 1 | Distance measurement on host camera |
| Breadboard + Jumper Wires | — | Testing and connections |
| USB cable (Micro-USB) | 1 | Powers the MB and uploads code |
| USB charger / power bank | 3 | Powers the 3 other cameras during testing |

---

## How the ESP32-CAM MB Works

The MB is a programmer board with a built-in USB-to-serial chip.
You plug one ESP32-CAM into it at a time to upload code.

```
  ┌─────────────────────────────┐
  │       ESP32-CAM MB          │
  │  ┌──────────────────────┐   │
  │  │   ESP32-CAM sits here│   │
  │  │   (camera faces out) │   │
  │  └──────────────────────┘   │
  │  [RESET]  [BOOT]            │
  │         [Micro-USB]         │
  └─────────────────────────────┘
```

- **RESET button** — restarts the board
- **BOOT button** — holds IO0 LOW (download mode) — needed on some MB versions
- **Micro-USB** — connects to PC for uploading, also provides power

---

## Step 1 — Install Arduino IDE + ESP32 Board Package

1. Download and install Arduino IDE from **https://www.arduino.cc/en/software**
2. Open Arduino IDE → **File > Preferences**
3. Paste this into **"Additional Boards Manager URLs"**:
   ```
   https://raw.githubusercontent.com/espressif/arduino-esp32/gh-pages/package_esp32_index.json
   ```
4. Go to **Tools > Board > Boards Manager**
5. Search `esp32`, install **esp32 by Espressif Systems**

---

## Step 2 — Arduino IDE Settings (same for all 4 cameras)

| Setting | Value |
|---|---|
| Board | **AI Thinker ESP32-CAM** |
| Upload Speed | 115200 |
| Flash Mode | QIO |
| Port | whichever COM port appears when MB is plugged in |

---

## Step 3 — How to Upload Using the MB Board

Do this once for each ESP32-CAM module.

1. Plug the ESP32-CAM into the MB socket
   - Camera lens faces **away** from the MB board
   - Press it down firmly until it seats
2. Connect MB to PC using Micro-USB cable
3. Select the correct COM port in **Tools > Port**
4. Click **Upload** in Arduino IDE
5. **If upload gets stuck** at `Connecting........`:
   - Press and hold the **BOOT** button on the MB
   - Click Upload again
   - Release BOOT once upload starts
6. After upload finishes, press **RESET** on the MB
7. Open **Serial Monitor** at **115200 baud**
8. Write down the IP address that appears

Repeat for all 4 ESP32-CAM modules — upload `esp32cam_basic.ino` to 3 of them,
and `esp32cam_host.ino` to the host one.

---

## Step 4 — Powering All 4 Cameras at the Same Time

Each ESP32-CAM needs its own 5V power source to run simultaneously.

**Option A — Easiest: USB chargers / power banks**
- Plug each ESP32-CAM MB into a USB charger or power bank
- One MB is connected to your PC (for monitoring via Serial)
- The other 3 are on chargers — they just need power, no PC connection needed

**Option B — Breadboard shared power rail (for testing)**
- Use a 5V breadboard power supply module on the breadboard
- Connect the 5V and GND rails
- Run jumper wires from the power rail to each ESP32-CAM's 5V and GND pins

```
Power Rail (5V)  ─────┬──── ESP32-CAM #1  5V
                      ├──── ESP32-CAM #2  5V
                      ├──── ESP32-CAM #3  5V
                      └──── ESP32-CAM #4  5V

Power Rail (GND) ─────┬──── ESP32-CAM #1  GND
                      ├──── ESP32-CAM #2  GND
                      ├──── ESP32-CAM #3  GND
                      └──── ESP32-CAM #4  GND
```

> **Important:** Powering through the 5V pin bypasses the onboard regulator.
> Use exactly 5V — do not exceed 5.5V or you will damage the board.

---

## Step 5 — Host Camera + HC-SR04 Wiring on Breadboard

The host ESP32-CAM has the HC-SR04 ultrasonic sensor connected to it.

### AI-Thinker ESP32-CAM Pin Positions

```
              [Camera Lens]
        ┌────────────────────┐
   5V  ●│                    │● 3.3V
  GND  ●│                    │● GND
  IO12 ●│   ESP32-CAM        │● IO1 (TX)
  IO13 ●│                    │● IO3 (RX)
  IO15 ●│                    │● IO0  ← BOOT pin
  IO14 ●│                    │● GND
   IO2 ●│                    │
   IO4 ●│   [SD card slot]   │
        └────────────────────┘
```

IO14 and IO15 are on the **left side**, 3rd and 4th from the bottom.

### HC-SR04 → ESP32-CAM Host Wiring

```
HC-SR04          ESP32-CAM (Host)
-------          ----------------
 VCC    ────────  5V
 GND    ────────  GND
 TRIG   ────────  IO14
 ECHO   ────────  IO15
```

### Breadboard Layout

```
        [ESP32-CAM HOST]
        ┌─────────────┐         [HC-SR04]
   5V  ─┤●            │         ┌───────┐
  GND  ─┤●            │    ┌────┤ VCC   │
  IO12  ┤●            │    │ ┌──┤ GND   │
  IO13  ┤●            │    │ │  ├───────┤
  IO15 ─┼─────────────┼────┼─┼──┤ ECHO  │
  IO14 ─┼─────────────┼────┼─┼──┤ TRIG  │
   IO2  ┤●            │    │ │  └───────┘
   IO4  ┤●            │    │ │
        └─────────────┘    │ │
              │             │ │
              5V ───────────┘ │
              GND ────────────┘
```

> **Note on ECHO voltage:** HC-SR04 ECHO outputs 5V but ESP32 GPIO is 3.3V.
> For a quick breadboard test this usually works fine.
> For a permanent build, add a voltage divider on ECHO:
> `ECHO → 1kΩ → IO15`, and `IO15 → 2kΩ → GND`

---

## Step 6 — Test in Browser Before Running Flutter

Your PC and phones must be on the **same WiFi** as the ESP32-CAMs.

| URL | Expected result |
|---|---|
| `http://[IP]/snapshot` | Shows a photo (refresh to update) |
| `http://[IP]/stream` | Live video (may take 2–5 sec) |
| `http://[HOST_IP]/sensor` | `{"distance_cm": 23.4, "status": "ok"}` |

Test each camera one at a time. Once all 4 show a snapshot, you're ready for Flutter.

---

## Step 7 — Update Flutter App with IPs

Open `flutter_app/lib/main.dart` and update the IPs at the top of the file:

```dart
const String HOST_IP = '192.168.x.x'; // Camera 1 — host (has sensor)
const String CAM2_IP = '192.168.x.x'; // Camera 2
const String CAM3_IP = '192.168.x.x'; // Camera 3
const String CAM4_IP = '192.168.x.x'; // Camera 4
```

---

## Troubleshooting

### Upload stuck at "Connecting........"
- Press and hold **BOOT** button on MB, then click Upload, release BOOT once it starts
- Make sure correct COM port is selected in Tools > Port

### "Camera init FAILED" in Serial Monitor
- The ESP32-CAM is not seated properly in the MB socket — remove and re-insert firmly
- Press RESET after upload

### WiFi not connecting
- `ssid` and `password` are case-sensitive — check spelling
- ESP32-CAM only supports **2.4 GHz WiFi** — won't connect to 5 GHz networks
- All cameras must be on the same network as the Flutter app device

### Camera shows snapshot once then fails
- Press RESET on the board — this clears any stuck state

### Sensor always returns -1
- Check HC-SR04 VCC is on 5V (not 3.3V)
- Check TRIG on IO14 and ECHO on IO15
- Point sensor at a surface within 4 meters

### Two cameras get the same IP
- Unplug all cameras, wait 30 seconds
- Power them on one at a time and note each IP before powering the next

---

## Quick Reference

### Endpoints
| Endpoint | Returns | Who has it |
|---|---|---|
| `/snapshot` | Single JPEG image | All 4 cameras |
| `/stream` | MJPEG live video | All 4 cameras |
| `/sensor` | `{"distance_cm": 23.4}` | Host only |

### Sensor Pins (Host Camera Only)
| HC-SR04 | ESP32-CAM Pin |
|---|---|
| VCC | 5V |
| GND | GND |
| TRIG | IO14 |
| ECHO | IO15 |
