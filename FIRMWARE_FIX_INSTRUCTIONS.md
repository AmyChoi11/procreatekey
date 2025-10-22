# ESP32 Firmware Fix Instructions

## Problem Identified

The ESP32 firmware had several critical bugs preventing configuration from being saved correctly:

### Issues Fixed:

1. **Incorrect JSON parsing**: Used `(int)buttons["button1"] | 0` which doesn't properly cast ArduinoJson values
2. **Missing dial support**: Only saved 3 buttons (button1, button2, button3) - ignored the dial field
3. **Limited value range**: Clamped values to 0-4, but app uses codes up to 11
4. **Incomplete read response**: Only returned 3 buttons when reading config back

## Changes Made to `xiao_ble_only.ino`:

### 1. Added Dial Variable (Line ~36)
```cpp
int dialFunction = 9;    // Default: Layers
```

### 2. Fixed onRead() - Include Dial (Line ~131)
```cpp
void onRead(BLECharacteristic* pChar) {
    String config = "{\"buttons\":{\"button1\":" + String(button1Function) + 
                    ",\"button2\":" + String(button2Function) + 
                    ",\"button3\":" + String(button3Function) + 
                    ",\"dial\":" + String(dialFunction) + "}}";
    pChar->setValue(config.c_str());
}
```

### 3. Fixed onWrite() - Proper JSON Parsing & Dial Support (Line ~150)
```cpp
// Fix: properly cast to int (the | 0 was doing nothing useful)
if (buttons.containsKey("button1")) newB1 = buttons["button1"].as<int>();
if (buttons.containsKey("button2")) newB2 = buttons["button2"].as<int>();
if (buttons.containsKey("button3")) newB3 = buttons["button3"].as<int>();
if (buttons.containsKey("dial")) newDial = buttons["dial"].as<int>();

// Validate and clamp values (expanded range for dial functions)
auto clamp = [](int v) { 
    if (v < 0) return 0; 
    if (v > 11) return 11;  // Support codes up to 11
    return v; 
};

// Save all 4 values
prefs.putInt("b1", newB1);
prefs.putInt("b2", newB2);
prefs.putInt("b3", newB3);
prefs.putInt("dial", newDial);
```

### 4. Load Dial from Preferences on Startup (Line ~333)
```cpp
dialFunction = prefs.getInt("dial", dialFunction);
Serial.printf("Loaded config from prefs: b1=%d b2=%d b3=%d dial=%d\n", 
              button1Function, button2Function, button3Function, dialFunction);
```

## How to Update Your ESP32:

1. **Open Arduino IDE**
2. **Load the updated `xiao_ble_only.ino` file**
3. **Select your board**: XIAO ESP32-S3
4. **Connect your XIAO via USB**
5. **Click Upload** (or press Ctrl+U)
6. **Wait for upload to complete**
7. **Open Serial Monitor** (115200 baud) to verify the new firmware is running

## Expected Serial Output After Update:

```
========================================
XIAO ESP32-S3 BLE-only Keyboard
========================================
Loaded config from prefs: b1=3 b2=3 b3=7 dial=9
BLE HID + GATT ready. Pair as 'XIAO Keyboard' or use a GATT client to configure.
Button functions: b1=3 b2=3 b3=7 dial=9
```

## Testing:

1. Flash the updated firmware
2. Run the iOS app
3. Connect to ESP32
4. Set all 4 buttons to specific values
5. Press Save
6. Check Serial Monitor - should show all 4 values being saved
7. Restart the app and reconnect
8. Verify all 4 configurations persist correctly

## Function Code Reference:

| Code | Function |
|------|----------|
| 3    | Undo |
| 4    | Redo |
| 5    | Erase |
| 6    | Brush Size (saved presets only) |
| 7    | Color Palette |
| 8    | Brush Library |
| 9    | Layers |
| 10   | Pen Opacity |
| 11   | Brush Size |

---

**Note**: Make sure to upload this firmware before testing the iOS app again. The app is working correctly - the bug was entirely in the ESP32 firmware!
