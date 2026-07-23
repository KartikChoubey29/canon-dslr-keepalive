# 📷 Canon DSLR Keep-Alive & Auto-Launch Automation

An automated background solution for **Canon DSLR cameras** used as live webcams via HDMI capture cards. Prevents the camera from hitting Canon's default **30-minute auto-shutdown / sleep limit** during long video calls, live streams, or broadcasts.

---

## 🎯 The Problem

When using a Canon DSLR for long-duration live streaming (e.g., Zoom, Teams, OBS, Google Meet):
* Video output is passed from the camera's **HDMI port** to a capture card / laptop.
* Even though HDMI video is streaming, the camera sensor receives no control inputs and considers itself idle.
* **Result:** The camera automatically turns off after 20–30 minutes.

---

## 💡 The Solution

By connecting a secondary **USB data cable** alongside the HDMI cable, this lightweight automation works with **[digiCamControl](https://github.com/dukus/digicamcontrol)** / **digiCamControl Virtual Webcam** to:

1. 🔌 **Auto-Detect USB Connection:** Listens for your Canon DSLR's USB hardware Vendor ID (`VID_04A9`).
2. 🚀 **Auto-Launch Application:** Automatically launches digiCamControl Virtual Webcam (`DSLRCam.exe`) or digiCamControl (`CameraControl.exe`) as soon as the camera turns on.
3. 💓 **Keep-Alive Heartbeat:** Sends a background HTTP API signal (`http://localhost:5513/?CMD=LiveViewWnd_Show`) every **15 minutes** to reset the camera's internal inactivity timer without interrupting your stream.
4. ⏸️ **Auto-Standby:** Automatically pauses when the camera is powered off or unplugged.

---

## 📂 Project Structure

```text
CanonKeepAlive/
├── AutoDetect-UsbAndRegisterTask.ps1 # Automated 1-click installer (auto-detects camera & event log)
├── CanonKeepAlive.ps1                # Core PowerShell monitoring & keep-alive service
├── Start-KeepAlive.bat               # One-click manual launcher batch file
├── Setup-TaskScheduler.ps1           # Automatic setup for Windows Logon startup task
├── README.md                         # Complete documentation & usage guide
└── keep_alive.log                    # Execution log file (auto-generated)
```

---

## 📋 Prerequisites

* **OS:** Windows 10 / 11
* **Software:** [digiCamControl](http://digicamcontrol.com/) or **digiCamControl Virtual Webcam** installed (`C:\Program Files (x86)\digiCamControl Virtual Webcam\DSLRCam.exe`)
* **Hardware Connections:**
  * **HDMI Cable:** Camera HDMI Out ➔ HDMI Capture Card ➔ Laptop (For Video)
  * **USB Data Cable:** Camera USB Out ➔ Laptop USB Port (For Keep-Alive Control)

---

## ⚙️ Initial Configuration (One-Time Setup)

1. Open **digiCamControl** (or Virtual Webcam).
2. Open **File** ➔ **Settings** ➔ **Web Server**.
3. Ensure **Enable Web Server** is checked (Default Port: `5513`).

---

## 🚀 How to Use

### Option 1: Automated 1-Click Setup (Recommended for Any User)

This is an setup script **`AutoDetect-UsbAndRegisterTask.ps1`** that automatically inspects your Windows system, finds your connected Canon camera, enables Windows Event Logging if needed, and registers Task Scheduler:

1. Open **PowerShell as Administrator**.
2. Run the automated installer:
   ```powershell
   powershell -ExecutionPolicy Bypass -File ".\AutoDetect-UsbAndRegisterTask.ps1"
   ```
3. **Done!** Windows Task Scheduler will now automatically launch the Keep-Alive script whenever your Canon camera is plugged in!

---

### Option 2: Run Automatically on Windows Logon

If you want the service running silently in the background whenever your PC turns on:

1. Right-click `Setup-TaskScheduler.ps1` and select **Run with PowerShell**.
2. It registers a task named `CanonKeepAliveAutomation` that starts hidden on logon.

---

### Option 3: Manual Quick Start

If you prefer launching it manually before your calls:

* Double-click `Start-KeepAlive.bat`.
* A terminal window will open, show status updates, and keep your camera alive.

---

## ⚙️ Customization Parameters

You can edit or pass custom parameters to `CanonKeepAlive.ps1`:

| Parameter | Default Value | Description |
| :--- | :--- | :--- |
| `-IntervalMinutes` | `15` | Time interval between keep-alive signals (in minutes). |
| `-ServerUrl` | `"http://localhost:5513/?CMD=LiveViewWnd_Show"` | Local digiCamControl web API endpoint. |
| `-WebcamAppPath` | `"C:\Program Files (x86)\... \DSLRCam.exe"` | Path to the Virtual Webcam executable. |

Example command with custom parameters:
```powershell
powershell -ExecutionPolicy Bypass -File ".\CanonKeepAlive.ps1" -IntervalMinutes 10
```

---

## 🔍 How Hardware Auto-Detection Works

### Event Log & PnP Scan
The automated installer checks Windows Event Viewer (`Microsoft-Windows-DriverFrameworks-UserMode/Operational`) and Windows PnP to detect:

* **Canon Vendor ID:** `VID_04A9` (Canon Inc.)
* **Event ID:** `2003` / `2004` (UMDF Host Driver Load Request)
* **Driver:** `WpdMtpDriver`

This ensures full compatibility across any Canon DSLR model or laptop port!

---

## 📊 Viewing Logs

All events are recorded in `keep_alive.log`:

```text
[2026-07-23 10:10:20] === Canon USB Auto-Detector & Keep-Alive Service Started ===
[2026-07-23 10:10:20] Monitoring for Canon USB Connection...
[2026-07-23 10:10:25] Canon Camera USB detected! Auto-launching Virtual Webcam...
[2026-07-23 10:10:30] SUCCESS: Sent keep-alive signal to digiCamControl.
```

---

## 📜 License

MIT License. Free to use, modify, and distribute for personal or commercial projects.
