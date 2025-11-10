# Procreate BLE Configuration App

A Flutter app to configure your ESP32 Procreate keyboard via Bluetooth. This app connects to the `xiao_ble_only.ino` firmware and allows you to customize button functions wirelessly.

## Features

- 📱 Scan for and connect to your XIAO ESP32 keyboard
- ⚙️ Configure 3 buttons with 5 function options each:
  - Left Click
  - Right Click
  - Double Click
  - Undo (Cmd+Z)
  - Redo (Cmd+Shift+Z)
- 💾 Save configuration immediately to ESP32 (persists across reboots)
- 📊 Live event monitoring (see button presses in real-time)
- 🔄 Default functions work without configuration

## Prerequisites

1. **ESP32 Firmware**: Flash `xiao_ble_only.ino` to your XIAO ESP32-S3 (the BLE-only version)
2. **Flutter SDK**: Install Flutter (see setup instructions below)
3. **iOS Device**: iPad or iPhone for deployment
4. **Apple ID**: For code signing (free Apple ID works for local deployment)

## Setup Instructions

### 1. Install Flutter

If you haven't installed Flutter yet, run these PowerShell commands:

```powershell
# Install via VS Code (recommended)
# 1. Open VS Code
# 2. Press Ctrl+Shift+P
# 3. Type "Flutter: New Project"
# 4. Select "Download SDK" and choose install location
# 5. Click "Add SDK to PATH"

# OR install manually:
Set-Location C:\src
git clone https://github.com/flutter/flutter.git -b stable --depth 1
$env:PATH = "C:\src\flutter\bin;" + $env:PATH
flutter doctor
```

### 2. Install Dependencies

```powershell
# Navigate to the flutter_app folder
Set-Location C:\Users\ISDL2404\procreatekey\finalize\flutter_app

# Get dependencies
flutter pub get
```

### 3. Connect Your iPad

```powershell
# Connect iPad via USB and trust the computer on iPad
# Verify device is detected:
flutter devices
```

You should see your iPad listed (e.g., "Amy's iPad").

### 4. Configure Code Signing (First Time Only)

Open the iOS project in Xcode:

```powershell
# Open the iOS workspace
open ios/Runner.xcworkspace
```

In Xcode:
1. Select "Runner" in the project navigator
2. Go to "Signing & Capabilities" tab
3. Select your team (use your Apple ID)
4. Change the Bundle Identifier to something unique (e.g., `com.yourname.procreate-ble-config`)

### 5. Build and Deploy to iPad

```powershell
# Build and install on connected iPad
flutter run

# Or build a release version:
flutter build ios --release --no-codesign
```

If prompted on iPad, go to **Settings > General > VPN & Device Management** and trust the developer profile.

## Usage

1. **Flash ESP32**: Make sure `xiao_ble_only.ino` is flashed to your ESP32
2. **Power On ESP32**: The device will advertise as "XIAO Keyboard"
3. **Open the App** on your iPad
4. **Tap Scan** to find nearby devices
5. **Tap "XIAO Keyboard"** to connect
6. **Configure buttons**:
   - Select function for each button from the dropdown
   - Tap "Save Configuration"
   - Settings are applied immediately and saved to ESP32 flash
7. **Return to Procreate** and test the buttons!

## BLE Communication Details

The app communicates with these BLE GATT characteristics:

- **Service UUID**: `12345678-1234-5678-1234-56789abcdef0`
- **Config (Write)**: `...ef1` - Sends JSON config to ESP32
- **Event (Notify)**: `...ef2` - Receives button press events
- **Status (Read/Notify)**: `...ef3` - Receives status updates

### Configuration JSON Format

```json
{
  "buttons": {
    "button1": 3,
    "button2": 4,
    "button3": 3
  }
}
```

Values: 0=LeftClick, 1=RightClick, 2=DoubleClick, 3=Undo, 4=Redo

## Troubleshooting

### "No devices found"
- Make sure ESP32 is powered on and advertising
- Check that Bluetooth is enabled on iPad
- Try moving closer to the device

### "Connection failed"
- Power cycle the ESP32
- Restart the app
- Check that the ESP32 firmware is running (`xiao_ble_only.ino`)

### "Config characteristic not found"
- Make sure you flashed the BLE-only firmware (not the WiFi version)
- The firmware must include the custom GATT service with UUIDs matching the app

### Code signing errors
- Use a unique Bundle Identifier in Xcode
- Make sure your Apple ID is added in Xcode preferences
- Free Apple IDs work but apps expire after 7 days (just rebuild)

### App crashes on launch
- Run `flutter doctor` and fix any issues
- Check iOS deployment target is 12.0+ in Xcode
- Rebuild with `flutter clean && flutter run`

## Development

### Run in debug mode:
```powershell
flutter run
```

### Run tests:
```powershell
flutter test
```

### Build release:
```powershell
flutter build ios --release
```

## Files Structure

```
flutter_app/
├── lib/
│   └── main.dart          # Main app code (scanner + config UI)
├── ios/
│   └── Runner/
│       └── Info.plist     # iOS permissions
├── android/
│   └── app/src/main/
│       └── AndroidManifest.xml  # Android permissions
├── pubspec.yaml           # Dependencies
└── README.md             # This file
```

## License

This project is for personal use with your Procreate workflow.
