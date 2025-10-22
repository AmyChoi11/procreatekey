# 🎨 Flutter Branch - Web App for ESP32 BLE Configuration

This branch contains the **Flutter web application** for configuring your ESP32 Procreate keyboard via Bluetooth.

---

## 📦 What's Included

### Flutter App Structure
```
flutter_app/
├── lib/
│   ├── main.dart              # App entry point
│   ├── groupmate_ui.dart      # Main UI with eSketch Shortcuts interface
│   └── test_page.dart         # Test page
├── web/                       # Web deployment files
├── android/                   # Android platform support
├── ios/                       # iOS platform support
├── windows/                   # Windows platform support
├── pubspec.yaml              # Dependencies
└── README.md                 # Flutter app documentation
```

### Key Features
- ✅ **Purple "eSketch Shortcuts" UI** matching your design
- ✅ **BLE Web Bluetooth** integration via `flutter_blue_plus`
- ✅ **4 Configurable Controls**:
  - Circle Button 1 → Undo, Redo, Erase, Brush Size
  - Circle Button 2 → Undo, Redo, Erase, Brush Size
  - Buttons 1 + 2 → Color Palette, Brush Library
  - Dial → Layers, Pen Opacity, Brush Size
- ✅ **Auto-save** configuration to ESP32
- ✅ **Multi-platform** support (Web, iOS, Android, Windows)

---

## 🚀 Quick Start

### Prerequisites
- Flutter SDK 3.0+
- Chrome browser (for web testing)
- ESP32 with `CONFIG_MODE=1` firmware

### Setup
```bash
# Navigate to Flutter app directory
cd flutter_app

# Install dependencies
flutter pub get

# Run on Chrome (web)
flutter run -d chrome

# Or build for web deployment
flutter build web
```

---

## 🌐 Deployed Version

The Flutter web app is live at:
**https://amychoi11.github.io/procreatekey/**

This is deployed from the `gh-pages` branch using GitHub Pages.

---

## 📱 How to Use

### 1. Open the App
- Web: Visit https://amychoi11.github.io/procreatekey/
- Or run locally: `flutter run -d chrome`

### 2. Connect to ESP32
- Tap the **Bluetooth icon** (top left)
- Grant Bluetooth permissions when prompted
- Wait for devices to appear
- Select **"XIAO_Config"** from the list

### 3. Configure Buttons
- Change any dropdown to select function
- Configuration **saves automatically** when connected
- Purple dropdowns = available options
- Pink background = Undo/Erase selected

### 4. Done!
- Settings are saved to ESP32 flash memory
- Upload `CONFIG_MODE=0` firmware for keyboard mode
- Pair with iPad and use in Procreate!

---

## 🔧 Development

### File Structure
- **`lib/main.dart`**: App initialization and routing
- **`lib/groupmate_ui.dart`**: Main UI with BLE logic
- **`lib/test_page.dart`**: Testing utilities

### Key Dependencies
```yaml
dependencies:
  flutter:
    sdk: flutter
  flutter_blue_plus: ^1.32.12  # BLE communication
  cupertino_icons: ^1.0.6
```

### Testing
```bash
# Run tests
flutter test

# Check for issues
flutter analyze

# Format code
flutter format lib/
```

---

## 🎨 UI Components

### Navigation Bar
- **Title**: "eSketch Shortcuts" (purple background)
- **Left Icon**: Bluetooth - tap to scan
- **Right Icons**: Save (manual save) + Disconnect

### Dropdown Cards
Each card has:
- Icon + title in purple
- Dropdown menu with options
- Color-coded background:
  - Pink (#FFC1CC) = Undo/Erase
  - Gray = Other options
- "Selected: [option]" text

### Device Selection
- Modal sheet slides up when scanning
- Shows device names and UUIDs
- "Scan Again" if no devices found
- Auto-closes when connected

---

## 📊 BLE Protocol

### Service UUID
```
12345678-1234-5678-1234-56789abcdef0
```

### Config Characteristic
```
12345678-1234-5678-1234-56789abcdef1
```

### JSON Format
```json
{
  "buttons": {
    "button1": 3,  // 0-4 function code
    "button2": 4,
    "button3": 0
  }
}
```

### Function Codes
- `0` = Left Click (default for unsupported features)
- `1` = Right Click
- `2` = Double Click
- `3` = Undo
- `4` = Redo

---

## 🔄 Branch Structure

### Related Branches
- **`flutter`** (this branch) → Flutter web app source code
- **`gh-pages`** → Built web app (deployed to GitHub Pages)
- **`app`** → Native iOS app (Xcode project)
- **`master`** → ESP32 firmware and original files

### Workflow
1. **Development**: Edit code in `flutter` branch
2. **Build**: `flutter build web`
3. **Deploy**: Copy `build/web/` to `gh-pages` branch
4. **Live**: Changes appear at GitHub Pages URL

---

## 📝 Deployment Guide

### Deploy to GitHub Pages

1. **Build the web app**:
```bash
cd flutter_app
flutter build web --base-href /procreatekey/
```

2. **Copy to gh-pages branch**:
```bash
# Switch to gh-pages branch
git checkout gh-pages

# Copy built files
cp -r flutter_app/build/web/* .

# Commit and push
git add .
git commit -m "Update web app"
git push origin gh-pages
```

3. **Verify**: Visit https://amychoi11.github.io/procreatekey/

See `DEPLOYMENT_GUIDE.md` for detailed instructions.

---

## 🐛 Troubleshooting

### Web Bluetooth Not Working
- ✅ Use Chrome or Edge browser
- ✅ Enable Web Bluetooth: `chrome://flags/#enable-web-bluetooth`
- ✅ ESP32 must have `CONFIG_MODE=1` (no HID mode)
- ❌ Safari on iPad doesn't support Web Bluetooth

### No Devices Found
- Check ESP32 is powered on
- Verify Serial Monitor shows "BLE started successfully"
- ESP32 must be in config mode (`CONFIG_MODE=1`)
- Try reloading the page

### Connection Failed
- Make sure ESP32 is not bonded to other devices
- Reset ESP32 and try again
- Check console for error messages

### Can't Save Config
- Verify device is connected (green status)
- Check ESP32 Serial Monitor for received data
- Try manual save button (disk icon)

---

## 🎯 Next Steps

### For Users
1. Open web app: https://amychoi11.github.io/procreatekey/
2. Connect to ESP32
3. Configure buttons
4. Upload keyboard firmware
5. Use with iPad!

### For Developers
1. Clone this branch: `git clone -b flutter https://github.com/AmyChoi11/procreatekey.git`
2. Install Flutter: https://flutter.dev/docs/get-started/install
3. Run: `cd flutter_app && flutter pub get && flutter run -d chrome`
4. Edit `lib/groupmate_ui.dart` for UI changes
5. Build and deploy!

---

## 📚 Documentation

- **DEPLOYMENT_GUIDE.md**: Detailed deployment instructions
- **QUICK_START.md**: Quick setup guide
- **flutter_app/README.md**: Flutter-specific documentation

---

## 🎉 Features

✅ Beautiful purple UI matching your design  
✅ BLE Web Bluetooth communication  
✅ Auto-save configuration  
✅ Multi-platform support  
✅ Responsive design  
✅ Real-time status updates  
✅ Error handling and recovery  
✅ Device scanning with UUIDs  
✅ Color-coded dropdowns  
✅ Professional appearance  

---

## 🤝 Contributing

This is a personal project, but feel free to:
- Report issues
- Suggest features
- Fork and customize
- Share improvements

---

## 📄 License

MIT License - Use freely for your projects!

---

## ✨ Credits

- **UI Design**: Your groupmate's eSketch Shortcuts concept
- **Flutter Framework**: Google
- **BLE Plugin**: flutter_blue_plus
- **Deployment**: GitHub Pages

---

**Happy configuring! 🎨🚀**

*For iOS native app, see the `app` branch*  
*For ESP32 firmware, see the `master` branch*
