# 🎯 Quick Start Guide

## What You Have Now

✅ **ESP32 Firmware**: `xiao_ble_only.ino` (CONFIG_MODE = 0)
✅ **Flutter Web App**: Built and ready in `flutter_app/build/web/`
✅ **Deployment Scripts**: Easy one-click deployment

## 🚀 Two Ways to Deploy

### Option A: GitHub Pages (Permanent URL)
**Best for**: Long-term use, share with others, professional deployment

1. Open PowerShell in `finalize` folder
2. Run:
   ```powershell
   cd flutter_app\build\web
   .\..\..\deploy_to_github.ps1
   ```
3. If prompted, add your GitHub remote:
   ```powershell
   git remote add origin https://github.com/AmyChoi11/procreatekey.git
   ```
4. Run the script again
5. Wait 2-3 minutes
6. Open on iPad: `https://amychoi11.github.io/procreatekey/`

### Option B: Ngrok (Quick Testing)
**Best for**: Immediate testing, no GitHub setup needed

1. Install ngrok: https://ngrok.com/download
2. Open PowerShell in `finalize` folder
3. Run:
   ```powershell
   .\test_local_https.ps1
   ```
4. Copy the HTTPS URL (e.g., `https://abc123.ngrok.io`)
5. Open that URL in Safari on your iPad

## 📱 Using on iPad

### First Time Setup:
1. **Pair ESP32 with iPad**
   - Settings → Bluetooth
   - Look for "XIAO Keyboard"
   - Tap to pair

2. **Upload Firmware**
   - Make sure `CONFIG_MODE = 0` in `xiao_ble_only.ino`
   - Upload to ESP32 via Arduino IDE

3. **Open Web App**
   - Open Safari on iPad
   - Go to your deployment URL
   - Allow Bluetooth permission

4. **Configure Buttons**
   - Tap Bluetooth icon → Select "XIAO Keyboard"
   - Set Button 1: Undo
   - Set Button 2: Redo
   - Set Button 3: Double Click
   - Tap Save

5. **Use in Procreate**
   - Close Safari
   - Open Procreate
   - Press buttons → They work! 🎉

### Changing Settings Later:
1. Open the web app
2. Connect
3. Modify settings
4. Save
5. Done! (no firmware upload needed)

## 🔍 Troubleshooting

### Can't find device on iPad
- Check ESP32 is powered on
- Make sure it's paired in Settings → Bluetooth
- Try turning Bluetooth off/on

### Buttons don't work
- Verify `CONFIG_MODE = 0` in firmware
- Check wiring: Button 1 → D0, Button 2 → D2, Button 3 → D3
- Open Serial Monitor to see button presses

### Web app won't load
- Must use HTTPS (ngrok or GitHub Pages)
- HTTP won't work for Web Bluetooth

## 📂 File Structure

```
finalize/
├── xiao_ble_only/
│   └── xiao_ble_only.ino          ← ESP32 firmware
├── flutter_app/
│   ├── lib/
│   │   ├── main.dart              ← Scanner & Config pages
│   │   └── groupmate_ui.dart      ← BLE UI
│   └── build/web/                 ← Deployable web app
├── deploy_to_github.ps1           ← GitHub Pages deploy script
├── test_local_https.ps1           ← Ngrok quick test script
└── DEPLOYMENT_GUIDE.md            ← Full deployment docs
```

## ⚡ Quick Commands

### Rebuild web app:
```powershell
cd flutter_app
flutter build web --release
```

### Deploy to GitHub:
```powershell
cd flutter_app\build\web
git add . && git commit -m "Update" && git push origin gh-pages
```

### Test locally:
```powershell
cd flutter_app\build\web
python -m http.server 8080
# In another terminal:
ngrok http 8080
```

## 🎉 That's It!

You now have a complete BLE keyboard configurator that works on iPad!

**Remember**: 
- `CONFIG_MODE = 1` → Setup mode (buttons don't work)
- `CONFIG_MODE = 0` → Production mode (buttons work, config still accessible)

Always use `CONFIG_MODE = 0` for normal use!
