# 🚀 Quick Setup Guide for Xcode

## What You Have
A complete native iOS app that can:
- Scan for your ESP32 via Bluetooth
- Connect and read current button configuration
- Let you change button mappings
- Save configuration to ESP32 permanently

## Step-by-Step Setup

### 1️⃣ Prepare ESP32 Firmware
```arduino
// In xiao_ble_only.ino, line 20:
#define CONFIG_MODE 1  // ← Must be 1 for configuration
```
Upload this to ESP32. It will advertise as "XIAO_Config".

### 2️⃣ Open Project in Xcode
1. Open **Finder** on your Mac
2. Navigate to the project folder
3. **Double-click** `ProcreateBLEConfig.xcodeproj`
4. Xcode will open

### 3️⃣ Configure Signing (IMPORTANT!)
1. In Xcode left sidebar, click the **blue project icon** at the top
2. Under "TARGETS", select **ProcreateBLEConfig**
3. Click **"Signing & Capabilities"** tab
4. Under "Team":
   - If you have Apple Developer account → Select your team
   - If not → Select your Apple ID (Personal Team)
5. **Bundle Identifier** might show an error:
   - Change it to something unique like: `com.yourname.procreate-config`

### 4️⃣ Connect Your iPad
1. **Plug iPad into Mac** (USB-C or Lightning cable)
2. **Unlock iPad**
3. If prompted "Trust This Computer?" → Tap **Trust**
4. In Xcode top bar, click the device dropdown (says "Any iOS Device")
5. Select **your iPad's name**

### 5️⃣ Build & Run
1. Click the **▶️ Play button** (or press `Cmd + R`)
2. Xcode will:
   - Build the app
   - Install on iPad
   - Launch automatically

### 6️⃣ Trust Developer Certificate (First Time Only)
If you see "Untrusted Developer" error on iPad:
1. Go to **Settings** → **General**
2. Scroll to **VPN & Device Management**
3. Tap your Apple ID under "Developer App"
4. Tap **Trust "[Your Name]"**
5. Confirm
6. Return to home screen and open the app

---

## ✅ Using the App

### Scan & Connect:
1. Open the app
2. Tap **"Scan for Devices"**
3. Look for **"XIAO_Config"** in the list
4. Tap it to connect
5. Wait for "Config loaded from device!"

### Configure Buttons:
1. Use the dropdown menus to select actions:
   - **Button 1** → Undo / Redo / etc.
   - **Button 2** → Undo / Redo / etc.
   - **Button 3** → Undo / Redo / etc.
2. Tap **"Save Configuration"**
3. Wait for confirmation

### Switch to Normal Mode:
1. Change firmware: `#define CONFIG_MODE 0`
2. Upload to ESP32
3. Now buttons work in Procreate! 🎨

---

## 🔧 Troubleshooting

### "No matching provisioning profiles found"
- Go to Signing & Capabilities
- Change Bundle Identifier to something unique
- Make sure Team is selected

### "Could not launch [app]"
- Check that iPad is trusted (Settings → VPN & Device Management)
- Try running again

### Can't find ESP32 in scan
- Make sure ESP32 is powered on
- Verify `CONFIG_MODE = 1` in firmware
- Check Serial Monitor shows "BLE started"
- Restart ESP32

### App crashes on launch
- Check Xcode console for errors
- Make sure Info.plist has Bluetooth permissions (already included)
- Try cleaning build: Product → Clean Build Folder

---

## 📱 Expected Result

When everything works:
- App shows "Scan for Devices" button
- Tapping it shows a list of nearby BLE devices
- "XIAO_Config" appears in the list
- After connecting: shows current button config
- You can change settings and save
- ESP32 Serial Monitor shows: "Config write request"

---

## 🎉 Success!

Once configured:
1. Change firmware to `CONFIG_MODE = 0`
2. Upload
3. Use your keyboard in Procreate with saved button mappings!

Need to change settings later? Switch back to `CONFIG_MODE = 1`, reconnect, modify, save, then back to `CONFIG_MODE = 0`.
