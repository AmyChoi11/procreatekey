# 🚀 Deployment Guide: Procreate BLE Keyboard Config

Your Flutter web app has been built successfully! The production files are in:
```
finalize/flutter_app/build/web/
```

## 📱 Option 1: GitHub Pages (RECOMMENDED for iPad)

This gives you a permanent HTTPS URL that works perfectly with iPad Safari Web Bluetooth.

### Step 1: Create a new GitHub repository (or use existing)

1. Go to https://github.com/AmyChoi11/procreatekey
2. Navigate to the repository settings

### Step 2: Push the built web app

```powershell
# Navigate to the build folder
cd C:\Users\ISDL2404\procreatekey\finalize\flutter_app\build\web

# Initialize git (if not already)
git init

# Add all files
git add .

# Commit
git commit -m "Deploy Procreate BLE Config web app"

# Add remote (replace with your repo URL)
git remote add origin https://github.com/AmyChoi11/procreatekey.git

# Push to gh-pages branch
git push -f origin HEAD:gh-pages
```

### Step 3: Enable GitHub Pages

1. Go to repository settings → Pages
2. Source: Deploy from branch
3. Branch: `gh-pages` / `(root)`
4. Click Save

### Step 4: Access your app

Your app will be available at:
```
https://amychoi11.github.io/procreatekey/
```

⏱️ First deployment takes 2-3 minutes to go live.

---

## 🌐 Option 2: Ngrok (Quick Testing)

For immediate testing without GitHub setup, use ngrok to create a temporary HTTPS tunnel.

### Step 1: Install ngrok

Download from: https://ngrok.com/download

Or use Chocolatey:
```powershell
choco install ngrok
```

### Step 2: Serve the web app locally

```powershell
# Navigate to build folder
cd C:\Users\ISDL2404\procreatekey\finalize\flutter_app\build\web

# Start a simple HTTP server (Python required)
python -m http.server 8080
```

Or use PowerShell:
```powershell
# Start local server with Python
cd C:\Users\ISDL2404\procreatekey\finalize\flutter_app\build\web
python -m http.server 8080
```

### Step 3: Create HTTPS tunnel

Open a NEW terminal:
```powershell
ngrok http 8080
```

You'll see output like:
```
Forwarding   https://abc123.ngrok.io -> http://localhost:8080
```

### Step 4: Access on iPad

Open Safari on your iPad and go to:
```
https://abc123.ngrok.io
```

⚠️ **Note**: Ngrok free URLs expire when you close the tunnel. You'll get a new URL each time.

---

## 📋 Testing Checklist for iPad

### Before Testing:
- ✅ ESP32 firmware uploaded (CONFIG_MODE = 0)
- ✅ ESP32 paired with iPad (Settings → Bluetooth → "XIAO Keyboard")
- ✅ Web app deployed with HTTPS

### Testing Steps:

1. **Open Safari on iPad**
   - Go to your deployment URL (GitHub Pages or ngrok)

2. **Allow Bluetooth Permission**
   - Safari will ask for Bluetooth permission → Tap "Allow"

3. **Connect to Keyboard**
   - Tap the Bluetooth icon (Connect button)
   - Select "XIAO Keyboard" from the device picker
   - Wait for connection (should see current config loaded)

4. **Configure Buttons**
   - Button 1: Select "Undo" (or your preference)
   - Button 2: Select "Redo" (or your preference)
   - Button 3: Select "Double Click" (or your preference)

5. **Save Configuration**
   - Tap "Save" button
   - Wait for confirmation
   - Configuration is now stored permanently in ESP32

6. **Close the App**
   - Close Safari
   - Open Procreate

7. **Test Keyboard Buttons**
   - Press Button 1 → Should trigger Undo
   - Press Button 2 → Should trigger Redo
   - Press Button 3 → Should trigger Double Click
   - ✅ **Success!** Your keyboard is working!

---

## 🔧 Troubleshooting

### "No Bluetooth devices found"
- Make sure ESP32 is powered on
- Check that ESP32 is paired in Settings → Bluetooth
- Try unpairing and re-pairing the device

### "Connection failed"
- Ensure you're using HTTPS (not HTTP)
- Try refreshing the page
- Check ESP32 is not connected to another device

### "Permission denied"
- Go to Safari Settings → Privacy & Security
- Make sure Bluetooth is allowed for the website

### Buttons don't work in Procreate
- Verify CONFIG_MODE = 0 in firmware
- Check button pin wiring (D0, D2, D3)
- Open Serial Monitor to see debug messages

---

## 📝 Re-configuring Later

To change button mappings:

1. Open the web app on your iPad
2. Connect to "XIAO Keyboard"
3. Modify settings
4. Save
5. New configuration takes effect immediately!

No need to re-upload firmware or restart anything.

---

## 🎯 Quick Commands Reference

### Rebuild web app (after code changes):
```powershell
cd C:\Users\ISDL2404\procreatekey\finalize\flutter_app
flutter build web --release
```

### Deploy to GitHub Pages:
```powershell
cd C:\Users\ISDL2404\procreatekey\finalize\flutter_app\build\web
git add .
git commit -m "Update web app"
git push origin gh-pages
```

### Start ngrok tunnel:
```powershell
# Terminal 1: Start local server
cd C:\Users\ISDL2404\procreatekey\finalize\flutter_app\build\web
python -m http.server 8080

# Terminal 2: Start ngrok
ngrok http 8080
```

---

## 🎉 You're Done!

Your Procreate keyboard configurator is ready to use on your iPad!

**Workflow Summary:**
1. ⚡ Pair ESP32 with iPad (one time)
2. 🌐 Open web app in Safari
3. 🔧 Configure button mappings
4. 💾 Save
5. 🎨 Use in Procreate immediately!

Need to change settings? Just open the web app again - no firmware upload needed!
