# ProcreateBLEConfig

Native iOS app for configuring ESP32 BLE keyboard for Procreate.

## Features
- ✅ Scan for BLE devices
- ✅ Connect to ESP32 with custom GATT service (UUID: 12345678-1234-5678-1234-56789abcdef0)
- ✅ Read current config from ESP32
- ✅ Configure three buttons with actions: Undo, Redo, Double Click, Left Click, Right Click
- ✅ Write config back to ESP32 and save permanently

## Requirements
- iOS 16.4+ (iPad or iPhone)
- Xcode 15+ (for building)
- ESP32 with BLE firmware (CONFIG_MODE = 1 for configuration)

## Setup Instructions

### 1. Open in Xcode
1. Double-click `ProcreateBLEConfig.xcodeproj` to open the project in Xcode
2. Wait for Xcode to index the project

### 2. Configure Signing
1. Select the project in the left sidebar
2. Select the target "ProcreateBLEConfig"
3. Go to "Signing & Capabilities" tab
4. Change "Team" to your Apple Developer account (or select your personal team)
5. Update "Bundle Identifier" if needed (e.g., `com.yourname.ProcreateBLEConfig`)

### 3. Connect Your iPad
1. Plug your iPad into your Mac via USB-C/Lightning cable
2. Unlock your iPad
3. Trust the computer if prompted on iPad
4. In Xcode, select your iPad from the device dropdown (top toolbar)

### 4. Build and Run
1. Click the ▶️ (Run) button in Xcode, or press `Cmd + R`
2. Xcode will build the app and install it on your iPad
3. If you see "Untrusted Developer" on iPad:
   - Go to Settings → General → VPN & Device Management
   - Trust your developer certificate
4. Launch the app from your iPad home screen

## Usage

### First Time Setup
1. Make sure ESP32 has `CONFIG_MODE = 1` in firmware
2. Upload firmware to ESP32
3. Power on ESP32 (it will advertise as "XIAO_Config")
4. Open ProcreateBLEConfig app on iPad
5. Tap "Scan for Devices"
6. Select "XIAO_Config" from the list
7. Wait for connection and config to load
8. Adjust button mappings as desired
9. Tap "Save Configuration"

### Daily Use (After Configuration)
1. Change ESP32 firmware to `CONFIG_MODE = 0`
2. Upload firmware
3. ESP32 now works as a keyboard with your saved button mappings!
4. Pair with iPad via Settings → Bluetooth if needed
5. Use buttons in Procreate 🎨

### Re-configuration
1. Change firmware back to `CONFIG_MODE = 1`
2. Upload firmware
3. Open ProcreateBLEConfig app
4. Connect and modify settings
5. Save
6. Switch back to `CONFIG_MODE = 0` for normal use

## Troubleshooting

### App won't install
- Make sure you're signed in with your Apple ID in Xcode
- Check "Signing & Capabilities" has no errors
- Try cleaning the build folder (Product → Clean Build Folder)

### Can't find ESP32
- Verify ESP32 is powered on and Serial Monitor shows "BLE started"
- Make sure `CONFIG_MODE = 1` in firmware
- Try restarting ESP32
- Check Bluetooth is enabled on iPad

### Connection fails
- Unpair "XIAO Keyboard" from iPad Bluetooth settings if present
- Restart the app
- Power cycle ESP32

### Save doesn't work
- Make sure you're connected (green "Connected" button)
- Check Serial Monitor on ESP32 for incoming data
- Verify config characteristic is readable/writable

## Technical Details

- **Service UUID**: `12345678-1234-5678-1234-56789abcdef0`
- **Config Characteristic**: `12345678-1234-5678-1234-56789abcdef1` (read/write)
- **Config Format**: JSON - `{"buttons": {"button1": 4, "button2": 1, "button3": 3}}`
- **Function Codes**:
  - 0 = Left Click
  - 1 = Right Click
  - 2 = Double Click
  - 3 = Undo (Cmd+Z)
  - 4 = Redo (Cmd+Shift+Z)

## Project Structure
```
ProcreateBLEConfig/
├── ProcreateBLEConfigApp.swift    # App entry point
├── ContentView.swift              # Main UI
├── BLEManager.swift               # Bluetooth logic
├── Info.plist                     # Bluetooth permissions
└── ProcreateBLEConfig.xcodeproj/  # Xcode project file
```

## License
MIT

