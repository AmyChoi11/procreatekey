# XIAO ESP32-S3 BLE Keyboard - UNIFIED FIRMWARE

## 🎉 Production-Ready Version

This is the **final unified firmware** that combines all features from previous iterations:
- Auto mode switching (CONFIG → KEYBOARD)
- iOS app configuration via BLE GATT service
- Dual-encoder support (5% and 10% brush control)
- Multi-button configuration
- Persistent settings storage
- Full iOS BLE security compliance

## 📋 Features

### Hardware Configuration
- **Button 1** (Pin 1): Configurable (Undo/Redo/Erase)
- **Button 2** (Pin 3): Configurable (Undo/Redo/Erase)
- **Button 1+2 Combo**: Configurable (Color Palette/Brush Library)
- **Dial** (Pins 7, 6): Configurable (Brush Size 5% or 10%)
- **Reset Button** (Pin 15): Hold 5 seconds to return to CONFIG MODE

### Mode Switching

#### CONFIG MODE (First Boot)
1. **Initial startup**: Device shows up as "XIAO_Config"
2. **30-second window**: Use iOS app to configure buttons/dial
3. **Auto-switch**: After configuration, automatically switches to KEYBOARD MODE
4. **Persistent**: Configuration saved, won't show CONFIG MODE on next boot

#### KEYBOARD MODE (Normal Operation)
- Shows up as "XIAO Keyboard" in Bluetooth settings
- Sends HID keyboard commands to iPad
- Remembers configuration across reboots
- Automatically reconnects after disconnection

#### Return to CONFIG MODE
Hold the **RESET button** for **5 seconds** to reconfigure

### Function Mapping

| Code | Function | Keys Sent |
|------|----------|-----------|
| 3 | Undo | Cmd+Z |
| 4 | Redo | Cmd+Shift+Z |
| 5 | Erase | E |
| 6 | Brush Size (5%) | [ / ] |
| 7 | Color Palette | Cmd+C |
| 8 | Brush Library | Cmd+B |
| 9 | Brush Size (10%) | Up+] / Down+[ |

## 🔧 Hardware Setup

### Required Components
- XIAO ESP32-S3
- 2× Push buttons (for Button 1, Button 2)
- 1× Rotary encoder (for Dial)
- 1× Push button (for Reset)
- Resistors as needed (if not using internal pullups)

### Pin Connections
```
BUTTON1_PIN: GPIO 1
BUTTON2_PIN: GPIO 3
ENCODER_A:   GPIO 7
ENCODER_B:   GPIO 6
RESET_BTN:   GPIO 15
LED_PIN:     GPIO 2
```

## 📱 iOS App Usage

### First Time Setup
1. **Power on** the XIAO ESP32-S3
2. Device enters **CONFIG MODE** automatically (LED blinks)
3. **Open** the iOS app "eSketch Shortcuts"
4. **Tap scan** → Connect to "XIAO_Config"
5. **Configure** buttons:
   - Circle Button 1: Undo, Redo, or Erase
   - Circle Button 2: Undo, Redo, or Erase
   - Buttons 1+2: Color Palette or Brush Library
   - Dial: Brush Size (5%) or Brush Size (10%)
6. **Tap save** → Device automatically switches to KEYBOARD MODE
7. **Pair** in iPad Settings → Bluetooth → "XIAO Keyboard"

### Changing Configuration
1. **Hold RESET button** for 5 seconds
2. Device restarts in CONFIG MODE
3. **Reconnect** with iOS app and reconfigure
4. **Save** → Auto-switches back to KEYBOARD MODE

## 🔐 BLE Security

This firmware includes **critical iOS security settings**:
- Uses `ESP_LE_AUTH_BOND` authentication
- Implements proper HID device info
- Full iOS compatibility for keyboard input

**Note**: Without these security settings, iOS will connect but silently ignore all keystrokes!

## ⚙️ Compilation

### Arduino IDE
1. Install **ESP32 board support** (Espressif)
2. Install libraries:
   - `ArduinoJson` by Benoit Blanchon
   - ESP32 BLE libraries (included with board support)
3. Select board: **XIAO ESP32-S3**
4. Upload sketch

### PlatformIO
```ini
[env:seeed_xiao_esp32s3]
platform = espressif32
board = seeed_xiao_esp32s3
framework = arduino
lib_deps = 
    bblanchon/ArduinoJson@^7.0.0
```

## 🐛 Troubleshooting

### Device won't pair with iPad
- **Solution**: Make sure you're connecting in KEYBOARD MODE (device name: "XIAO Keyboard")
- CONFIG MODE is for configuration only

### Keys don't trigger iPad functions
- **Check**: BLE security is enabled (see line 352 in code)
- **Check**: Using 20ms delays between key press/release
- **Check**: Correct modifier codes (0x08 for Cmd, 0x0A for Cmd+Shift)

### Want to reconfigure buttons
- Hold **RESET button** for 5 seconds
- Device restarts in CONFIG MODE

### Encoder not working
- **Check**: Pins 7 and 6 are properly connected
- **Check**: Encoder has common ground
- **Test**: Monitor serial output for encoder position changes

### LED behavior
- **Slow blink**: CONFIG MODE, waiting for iOS app
- **Solid on**: Connected in CONFIG MODE
- **Off**: KEYBOARD MODE, not connected
- **Solid on**: KEYBOARD MODE, connected and ready
- **Rapid flash (10×)**: Mode change (CONFIG ↔ KEYBOARD)
- **3× blink**: Configuration saved

## 📊 Serial Monitor Output

Enable serial monitor at **115200 baud** to see:
- Boot mode (CONFIG or KEYBOARD)
- Configuration values
- Connection status
- Button presses
- Encoder movements
- Key codes sent

Example output:
```
========================================
XIAO ESP32-S3 BLE Keyboard - UNIFIED
========================================
Loaded config:
  Button 1: 3
  Button 2: 4
  Button 1+2: 7
  Dial: 9
First boot: NO (going straight to keyboard mode)

✓ Device already configured - starting in KEYBOARD MODE
========================================
⚙️  SWITCHING TO KEYBOARD MODE
========================================
✓ BLE HID Keyboard started
→ Go to iPad Settings → Bluetooth
→ Tap 'XIAO Keyboard' to pair
========================================

✓ Ready!
✓ Client connected
🔘 BUTTON 1 PRESSED
🎹 Sending function key: 3
   → Undo (Cmd+Z)
   ✓ Sent
```

## 📝 Version History

### v3.0 - UNIFIED (Current)
- Combined auto_mode + dual encoder support
- Changed to 10% brush control (Up+]/Down+[)
- Simplified iOS app options
- Production-ready with full BLE security

### v2.0 - Auto Mode
- Mode switching (CONFIG/KEYBOARD)
- iOS app configuration
- Persistent storage

### v1.0 - Basic
- Simple BLE HID keyboard
- No configuration interface

## 🎯 Use with Procreate

### Recommended Configuration
- **Button 1**: Undo (for quick corrections)
- **Button 2**: Redo (for undoing undos)
- **Button 1+2**: Color Palette (quick color changes)
- **Dial**: Brush Size (10%) (faster adjustments)

### Pro Tips
1. **Brush Size 5%** is better for fine detail work
2. **Brush Size 10%** is faster for rough sketching
3. Use **Button 1+2 combo** for frequently-accessed menus
4. **Erase** function is great for one-button eraser toggle

## 🔗 Related Files
- **iOS App**: `../ProcreateBLEConfig/`
- **Previous Versions**: 
  - `../xiao_ble_auto_mode/` - Mode switching version
  - `../combined_config.ino` - Multi-button source
  - `../xiao_ble_combined/` - Early BLE attempts

## 📜 License
MIT License - Feel free to use and modify!

## 👥 Credits
Developed for iPad + Procreate workflow
Built on ESP32 Arduino Core and ArduinoJson library
