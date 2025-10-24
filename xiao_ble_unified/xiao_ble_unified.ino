/*
 * XIAO ESP32-S3 BLE Keyboard - UNIFIED FIRMWARE
 * 
 * AUTO MODE SWITCHING:
 * - First boot: CONFIG MODE (30 seconds) → Configure via iOS app
 * - After config: KEYBOARD MODE (remembers on reboot)
 * - Hold RESET 5 seconds: Return to CONFIG MODE
 * 
 * HARDWARE:
 * - Button 1 (Pin 1): Configurable (Undo/Redo/Erase/Brush Size 5%)
 * - Button 2 (Pin 3): Configurable (Undo/Redo/Erase/Brush Size 5%)
 * - Button 1+2: Configurable (Color Palette/Brush Library)
 * - Dial (Pin 7/6): Configurable (Brush Size 5%/Brush Size 10%)
 * - Reset Button (Pin 15): Hold 5 sec to reconfigure
 * 
 * FUNCTION CODES:
 * 3 = Undo (Cmd+Z)
 * 4 = Redo (Cmd+Shift+Z)
 * 5 = Erase (E key)
 * 6 = Brush Size 5% ([ / ] keys)
 * 7 = Color Palette (Cmd+C)
 * 8 = Brush Library (Cmd+B)
 * 9 = Brush Size 10% (Up+] / Down+[)
 */

#include <BLEDevice.h>
#include <BLEUtils.h>
#include <BLEServer.h>
#include <BLE2902.h>
#include <Preferences.h>
#include <ArduinoJson.h>
#include <BLEHIDDevice.h>
#include <HIDKeyboardTypes.h>
#include <HIDTypes.h>

// ============= Pin Definitions =============
#define BUTTON1_PIN 4
#define BUTTON2_PIN 5
#define ENCODER_A   7
#define ENCODER_B   6
#define RESET_BTN   15
#define LED_PIN     2

// ============= Key Codes =============
#define KEY_LEFT_BRACKET  0x2F  // [
#define KEY_RIGHT_BRACKET 0x30  // ]
#define KEY_UP_ARROW      0x52  // Up arrow
#define KEY_DOWN_ARROW    0x51  // Down arrow

// ============= Mode Management =============
enum DeviceMode {
  MODE_CONFIG,    // Configuration mode - GATT service only, no HID
  MODE_KEYBOARD   // Keyboard mode - HID only, no config service
};

DeviceMode currentMode = MODE_CONFIG;
unsigned long configModeStartTime = 0;
const unsigned long CONFIG_MODE_TIMEOUT = 30000; // 30 seconds
bool isFirstBoot = true;  // Check if this is first boot or has been configured

// ============= Encoder Settings =============
volatile long encoderPos = 0;
volatile int lastEncoded = 0;
volatile unsigned long lastEncoderTime = 0;
const unsigned long ENCODER_DEBOUNCE = 5;

// ============= Button Configuration =============
struct ButtonConfig {
  int button1 = 3;  // Default: Undo
  int button2 = 3;  // Default: Undo
  int combo = 7;    // Default: Color Palette (button1+button2 together)
  int dial = 9;     // Default: Brush Size 10%
} config;

Preferences prefs;

// ============= BLE Objects =============
BLEServer* pServer = nullptr;
BLEHIDDevice* hid = nullptr;
BLECharacteristic* input = nullptr;

#define SERVICE_UUID        "12345678-1234-5678-1234-56789abcdef0"
#define CHAR_UUID_CONFIG    "12345678-1234-5678-1234-56789abcdef1"
BLEService* configService = nullptr;
BLECharacteristic* configChar = nullptr;

bool deviceConnected = false;
bool oldDeviceConnected = false;

// ============= Forward Declarations =============
void switchToKeyboardMode();
void startConfigMode();

// ============= BLE Security Callbacks =============
class SecurityCallbacks : public BLESecurityCallbacks {
  uint32_t onPassKeyRequest() {
    Serial.println("PassKeyRequest");
    return 123456;
  }
  
  void onPassKeyNotify(uint32_t pass_key) {
    Serial.printf("PassKeyNotify: %d\n", pass_key);
  }
  
  bool onConfirmPIN(uint32_t pass_key) {
    Serial.printf("ConfirmPIN: %d\n", pass_key);
    return true;
  }
  
  bool onSecurityRequest() {
    Serial.println("SecurityRequest - accepting");
    return true;
  }
  
  void onAuthenticationComplete(esp_ble_auth_cmpl_t auth_cmpl) {
    if (auth_cmpl.success) {
      Serial.println("✓ Pairing successful!");
    } else {
      Serial.printf("✗ Pairing failed: %d\n", auth_cmpl.fail_reason);
    }
  }
};

// ============= BLE Server Callbacks =============
class ServerCallbacks : public BLEServerCallbacks {
  void onConnect(BLEServer* pServer) {
    deviceConnected = true;
    Serial.printf("✓ Client connected (Mode: %s)\n", currentMode == MODE_CONFIG ? "CONFIG" : "KEYBOARD");
    digitalWrite(LED_PIN, HIGH);
  }
  
  void onDisconnect(BLEServer* pServer) {
    deviceConnected = false;
    Serial.printf("✗ Client disconnected (Mode: %s)\n", currentMode == MODE_CONFIG ? "CONFIG" : "KEYBOARD");
    digitalWrite(LED_PIN, LOW);
    
    // In keyboard mode, restart advertising
    if (currentMode == MODE_KEYBOARD) {
      delay(500);
      BLEDevice::startAdvertising();
      Serial.println("→ Restarted advertising");
    } else if (currentMode == MODE_CONFIG) {
      Serial.println("→ Staying in CONFIG mode, ready for reconnection");
    }
  }
};

// ============= Config Callbacks =============
class ConfigCallbacks : public BLECharacteristicCallbacks {
  void onWrite(BLECharacteristic* pChar) {
    Serial.println("\n🔔 onWrite() callback triggered!");
    std::string value = pChar->getValue();
    Serial.printf("→ Received %d bytes\n", value.length());
    
    if (value.length() > 0) {
      Serial.println("\n========================================");
      Serial.println("📥 RECEIVED CONFIG FROM iOS APP");
      Serial.println("========================================");
      Serial.println(value.c_str());
      
      DynamicJsonDocument doc(512);
      DeserializationError error = deserializeJson(doc, value);
      
      if (error) {
        Serial.print("❌ JSON parse failed: ");
        Serial.println(error.c_str());
        return;
      }
      
      if (doc.containsKey("buttons")) {
        JsonObject buttons = doc["buttons"];
        
        config.button1 = buttons["button1"].as<int>();
        config.button2 = buttons["button2"].as<int>();
        config.combo = buttons["combo"].as<int>();
        config.dial = buttons["dial"].as<int>();
        
        config.button1 = constrain(config.button1, 0, 11);
        config.button2 = constrain(config.button2, 0, 11);
        config.combo = constrain(config.combo, 0, 11);
        config.dial = constrain(config.dial, 0, 11);
        
        prefs.begin("config", false);
        prefs.putInt("button1", config.button1);
        prefs.putInt("button2", config.button2);
        prefs.putInt("combo", config.combo);
        prefs.putInt("dial", config.dial);
        prefs.putBool("configured", true);  // Mark as configured
        prefs.end();
        
        Serial.printf("\n✓✓✓ CONFIG SAVED TO FLASH ✓✓✓\n");
        Serial.printf("  Button 1: %d\n", config.button1);
        Serial.printf("  Button 2: %d\n", config.button2);
        Serial.printf("  Combo (1+2): %d\n", config.combo);
        Serial.printf("  Dial: %d\n", config.dial);
        Serial.println("========================================\n");
        
        // Blink LED to confirm
        for(int i=0; i<5; i++) {
          digitalWrite(LED_PIN, HIGH);
          delay(100);
          digitalWrite(LED_PIN, LOW);
          delay(100);
        }
        
        // Switch to keyboard mode after 2 seconds
        Serial.println("→→→ SWITCHING TO KEYBOARD MODE IN 2 SECONDS...\n");
        delay(2000);
        switchToKeyboardMode();
      } else {
        Serial.println("⚠️ No 'buttons' key in JSON");
      }
    } else {
      Serial.println("⚠️ Received empty config write");
    }
  }
  
  void onRead(BLECharacteristic* pChar) {
    DynamicJsonDocument doc(256);
    JsonObject buttons = doc.createNestedObject("buttons");
    buttons["button1"] = config.button1;
    buttons["button2"] = config.button2;
    buttons["combo"] = config.combo;
    buttons["dial"] = config.dial;
    
    String output;
    serializeJson(doc, output);
    pChar->setValue(output.c_str());
    Serial.println("📤 Config read:");
    Serial.println(output);
  }
};

// ============= Keyboard Functions =============
void sendFunctionKey(int functionCode) {
  if (currentMode != MODE_KEYBOARD) {
    Serial.println("⚠️ Not in keyboard mode!");
    return;
  }
  if (!input) {
    Serial.println("⚠️ Input characteristic not initialized!");
    return;
  }
  if (!deviceConnected) {
    Serial.println("⚠️ Device not connected!");
    return;
  }
  
  Serial.printf("🎹 Sending function key: %d\n", functionCode);
  
  uint8_t modifier = 0;
  uint8_t key = 0;
  
  switch(functionCode) {
    case 3:  // Undo (Cmd+Z)
      Serial.println("   → Undo (Cmd+Z)");
      modifier = 0x08;  // Left GUI (Command)
      key = 0x1D;       // Z key
      break;
    case 4:  // Redo (Cmd+Shift+Z)
      Serial.println("   → Redo (Cmd+Shift+Z)");
      modifier = 0x0A;  // Left GUI + Left Shift (0x08 | 0x02)
      key = 0x1D;       // Z key
      break;
    case 5:  // Erase (E)
      Serial.println("   → Erase (E)");
      modifier = 0;
      key = 0x08;       // E key
      break;
    case 6:  // Brush Size 5% ([ / ])
      Serial.println("   → Brush Size 5% control activated");
      // Handled separately in sendBrushKey5
      return;
    case 7:  // Color Palette (Cmd+C)
      Serial.println("   → Color Palette (Cmd+C)");
      modifier = 0x08;  // Left GUI (Command)
      key = 0x06;       // C key
      break;
    case 8:  // Brush Library (Cmd+B)
      Serial.println("   → Brush Library (Cmd+B)");
      modifier = 0x08;  // Left GUI (Command)
      key = 0x05;       // B key
      break;
    case 9:  // Brush Size 10% control
      Serial.println("   → Brush Size 10% control activated");
      // Handled separately in sendBrushKey10
      return;
    default:
      Serial.printf("   → Unknown function code: %d\n", functionCode);
      return;
  }
  
  // Send key press
  uint8_t msg[] = {modifier, 0, key, 0, 0, 0, 0, 0};
  input->setValue(msg, sizeof(msg));
  input->notify();
  delay(20);
  
  // Send key release
  uint8_t msg2[] = {0, 0, 0, 0, 0, 0, 0, 0};
  input->setValue(msg2, sizeof(msg2));
  input->notify();
  
  Serial.println("   ✓ Sent");
}

// Send brush size adjustment 5% ([ / ])
void sendBrushKey5(bool increase) {
  if (currentMode != MODE_KEYBOARD || !input || !deviceConnected) return;
  
  Serial.printf("🖌️ Brush size 5%: %s\n", increase ? "INCREASE ]" : "DECREASE [");
  
  uint8_t key = increase ? KEY_RIGHT_BRACKET : KEY_LEFT_BRACKET;
  
  // Send key press
  uint8_t msg[] = {0, 0, key, 0, 0, 0, 0, 0};
  input->setValue(msg, sizeof(msg));
  input->notify();
  delay(20);
  
  // Send key release
  uint8_t msg2[] = {0, 0, 0, 0, 0, 0, 0, 0};
  input->setValue(msg2, sizeof(msg2));
  input->notify();
}

// Send brush size adjustment 10% (Up+] / Down+[)
void sendBrushKey10(bool increase) {
  if (currentMode != MODE_KEYBOARD || !input || !deviceConnected) return;
  
  Serial.printf("🖌️ Brush size 10%: %s\n", increase ? "INCREASE (Up+])" : "DECREASE (Down+[)");
  
  uint8_t arrowKey = increase ? KEY_UP_ARROW : KEY_DOWN_ARROW;
  uint8_t bracketKey = increase ? KEY_RIGHT_BRACKET : KEY_LEFT_BRACKET;
  
  // Send arrow + bracket key press
  uint8_t msg[] = {0, 0, arrowKey, bracketKey, 0, 0, 0, 0};
  input->setValue(msg, sizeof(msg));
  input->notify();
  delay(20);
  
  // Send key release
  uint8_t msg2[] = {0, 0, 0, 0, 0, 0, 0, 0};
  input->setValue(msg2, sizeof(msg2));
  input->notify();
}

// ============= Encoder Interrupt =============
void IRAM_ATTR handleEncoder() {
  unsigned long currentTime = millis();
  if (currentTime - lastEncoderTime < ENCODER_DEBOUNCE) return;
  lastEncoderTime = currentTime;
  
  int MSB = digitalRead(ENCODER_A);
  int LSB = digitalRead(ENCODER_B);
  int encoded = (MSB << 1) | LSB;
  int sum = (lastEncoded << 2) | encoded;
  
  if (sum == 0b1101 || sum == 0b0100 || sum == 0b0010 || sum == 0b1011) encoderPos++;
  if (sum == 0b1110 || sum == 0b0111 || sum == 0b0001 || sum == 0b1000) encoderPos--;
  
  lastEncoded = encoded;
}

// ============= Mode Switching =============
void switchToKeyboardMode() {
  Serial.println("\n========================================");
  Serial.println("⚙️  SWITCHING TO KEYBOARD MODE");
  Serial.println("========================================");
  
  Serial.println("Step 1: Stopping advertising...");
  // Stop config mode advertising
  if (pServer) {
    BLEDevice::getAdvertising()->stop();
    delay(100);
  }
  
  Serial.println("Step 2: Deinitializing BLE...");
  // Deinitialize BLE completely
  BLEDevice::deinit(true);
  delay(500);
  
  Serial.println("Step 3: Reinitializing as keyboard...");
  // Reinitialize in keyboard mode
  BLEDevice::init("XIAO Keyboard");
  Serial.println("Step 4: Device initialized");
  
  Serial.println("Step 5: Creating server...");
  pServer = BLEDevice::createServer();
  pServer->setCallbacks(new ServerCallbacks());
  
  Serial.println("Step 6: Creating HID device...");
  hid = new BLEHIDDevice(pServer);
  input = hid->inputReport(1);
  
  Serial.println("Step 7: Setting device info...");
  // Set HID device info - CRITICAL for iOS to accept it
  hid->manufacturer()->setValue("XIAO");
  hid->pnp(0x02, 0x1234, 0x5678, 0x0110);  // BT SIG, vendor ID, product ID, version
  hid->hidInfo(0x00, 0x01);  // No remote wake, normally connectable
  
  Serial.println("Step 8: Setting up security...");
  // CRITICAL: Security settings - iOS requires this to accept keyboard input!
  BLESecurity* security = new BLESecurity();
  security->setAuthenticationMode(ESP_LE_AUTH_BOND);
  
  Serial.println("Step 9: Setting report map...");
  const uint8_t reportMap[] = {
    0x05, 0x01,        // Usage Page (Generic Desktop)
    0x09, 0x06,        // Usage (Keyboard)
    0xA1, 0x01,        // Collection (Application)
    0x85, 0x01,        //   Report ID (1)
    0x05, 0x07,        //   Usage Page (Key Codes)
    0x19, 0xE0,        //   Usage Minimum (224)
    0x29, 0xE7,        //   Usage Maximum (231)
    0x15, 0x00,        //   Logical Minimum (0)
    0x25, 0x01,        //   Logical Maximum (1)
    0x75, 0x01,        //   Report Size (1)
    0x95, 0x08,        //   Report Count (8)
    0x81, 0x02,        //   Input (Data, Variable, Absolute)
    0x95, 0x01,        //   Report Count (1)
    0x75, 0x08,        //   Report Size (8)
    0x81, 0x01,        //   Input (Constant)
    0x95, 0x06,        //   Report Count (6)
    0x75, 0x08,        //   Report Size (8)
    0x15, 0x00,        //   Logical Minimum (0)
    0x25, 0x65,        //   Logical Maximum (101)
    0x05, 0x07,        //   Usage Page (Key Codes)
    0x19, 0x00,        //   Usage Minimum (0)
    0x29, 0x65,        //   Usage Maximum (101)
    0x81, 0x00,        //   Input (Data, Array)
    0xC0               // End Collection
  };
  
  Serial.println("Step 10: Starting HID services...");
  hid->reportMap((uint8_t*)reportMap, sizeof(reportMap));
  hid->startServices();
  
  Serial.println("Step 11: Waiting for services to initialize...");
  // Important: Give HID services time to fully initialize
  delay(1000);
  
  Serial.println("Step 12: Setting up advertising...");
  BLEAdvertising* pAdvertising = BLEDevice::getAdvertising();
  pAdvertising->setAppearance(0x03C1);  // Keyboard appearance
  pAdvertising->addServiceUUID(hid->hidService()->getUUID());
  pAdvertising->setScanResponse(true);
  
  // Set connection interval preferences for iOS (in units of 1.25ms)
  // Min: 7.5ms (6 * 1.25ms), Max: 15ms (12 * 1.25ms)
  pAdvertising->setMinPreferred(0x06);  
  pAdvertising->setMaxPreferred(0x0C);
  
  Serial.println("Step 13: Starting advertising...");
  pAdvertising->start();  // Use pAdvertising->start() like combined.ino
  
  Serial.println("Step 14: Setting battery level...");
  hid->setBatteryLevel(100);
  
  Serial.println("Step 15: SETTING MODE TO KEYBOARD...");
  currentMode = MODE_KEYBOARD;
  Serial.println("Step 16: Mode changed successfully!");
  
  Serial.println("✓ BLE HID Keyboard started");
  Serial.println("→ Go to iPad Settings → Bluetooth");
  Serial.println("→ Tap 'XIAO Keyboard' to pair");
  Serial.println("========================================\n");
  
  // Flash LED rapidly to indicate mode change
  for(int i=0; i<10; i++) {
    digitalWrite(LED_PIN, HIGH);
    delay(50);
    digitalWrite(LED_PIN, LOW);
    delay(50);
  }
}

void startConfigMode() {
  Serial.println("\n========================================");
  Serial.println("⚙️  STARTING CONFIG MODE");
  Serial.println("========================================");
  
  BLEDevice::init("XIAO_Config");
  
  // No security needed for config mode
  
  pServer = BLEDevice::createServer();
  pServer->setCallbacks(new ServerCallbacks());
  
  configService = pServer->createService(SERVICE_UUID);
  
  configChar = configService->createCharacteristic(
    CHAR_UUID_CONFIG,
    BLECharacteristic::PROPERTY_READ | BLECharacteristic::PROPERTY_WRITE
  );
  configChar->setCallbacks(new ConfigCallbacks());
  configChar->addDescriptor(new BLE2902());
  
  configService->start();
  
  BLEAdvertising* pAdvertising = BLEDevice::getAdvertising();
  pAdvertising->addServiceUUID(SERVICE_UUID);
  pAdvertising->setScanResponse(true);
  pAdvertising->setMinPreferred(0x06);
  pAdvertising->setMaxPreferred(0x12);
  
  BLEDevice::startAdvertising();
  
  currentMode = MODE_CONFIG;
  configModeStartTime = millis();
  
  Serial.println("✓ BLE Config Service started");
  Serial.println("→ Open iOS app to configure buttons");
  Serial.println("→ Will auto-switch to Keyboard Mode in 30 seconds");
  Serial.println("========================================\n");
}

// ============= Setup =============
void setup() {
  Serial.begin(115200);
  delay(1000);
  
  Serial.println("\n\n========================================");
  Serial.println("XIAO ESP32-S3 BLE Keyboard - UNIFIED");
  Serial.println("========================================");
  
  pinMode(BUTTON1_PIN, INPUT_PULLUP);
  pinMode(BUTTON2_PIN, INPUT_PULLUP);
  pinMode(ENCODER_A, INPUT_PULLUP);
  pinMode(ENCODER_B, INPUT_PULLUP);
  pinMode(RESET_BTN, INPUT_PULLUP);
  pinMode(LED_PIN, OUTPUT);
  
  attachInterrupt(digitalPinToInterrupt(ENCODER_A), handleEncoder, CHANGE);
  attachInterrupt(digitalPinToInterrupt(ENCODER_B), handleEncoder, CHANGE);
  
  // Load config
  prefs.begin("config", true);
  config.button1 = prefs.getInt("button1", 3);
  config.button2 = prefs.getInt("button2", 3);
  config.combo = prefs.getInt("combo", 7);
  config.dial = prefs.getInt("dial", 9);
  isFirstBoot = !prefs.getBool("configured", false);  // Check if configured before
  prefs.end();
  
  Serial.printf("Loaded config:\n");
  Serial.printf("  Button 1: %d\n", config.button1);
  Serial.printf("  Button 2: %d\n", config.button2);
  Serial.printf("  Button 1+2 Combo: %d\n", config.combo);
  Serial.printf("  Dial: %d\n", config.dial);
  Serial.printf("First boot: %s\n\n", isFirstBoot ? "YES (will show config mode)" : "NO (going straight to keyboard mode)");
  
  // If already configured, skip config mode and go straight to keyboard mode
  if (!isFirstBoot) {
    Serial.println("✓ Device already configured - starting in KEYBOARD MODE");
    switchToKeyboardMode();
  } else {
    Serial.println("⚠ First boot - starting in CONFIG MODE");
    // Start in config mode
    startConfigMode();
  }
  
  // LED startup sequence
  for(int i=0; i<3; i++) {
    digitalWrite(LED_PIN, HIGH);
    delay(100);
    digitalWrite(LED_PIN, LOW);
    delay(100);
  }
  
  Serial.println("✓ Ready!");
}

// ============= Loop =============
static bool button1Pressed = false;
static bool button2Pressed = false;
static bool button3Pressed = false;
static bool resetPressed = false;
static unsigned long resetPressTime = 0;
static long lastEncoderPos = 0;
static unsigned long lastButtonCheck = 0;

void loop() {
  // Debug: Check reset button state every 2 seconds
  if (millis() - lastButtonCheck > 2000) {
    int resetState = digitalRead(RESET_BTN);
    Serial.printf("[DEBUG] RESET_BTN (GPIO%d) state: %s, Mode: %s\n", 
                  RESET_BTN, 
                  resetState == LOW ? "PRESSED" : "RELEASED",
                  currentMode == MODE_CONFIG ? "CONFIG" : "KEYBOARD");
    lastButtonCheck = millis();
  }
  
  // Check for config mode timeout (only if in config mode and not yet configured)
  if (currentMode == MODE_CONFIG && !deviceConnected && isFirstBoot) {
    if (millis() - configModeStartTime > CONFIG_MODE_TIMEOUT) {
      Serial.println("⏰ Config mode timeout - switching to keyboard mode");
      
      // Mark as configured so next boot goes straight to keyboard
      prefs.begin("config", false);
      prefs.putBool("configured", true);
      prefs.end();
      
      switchToKeyboardMode();
    }
  }
  
  // Reset button - hold for 5 seconds
  // In KEYBOARD MODE: Switch to CONFIG MODE
  // In CONFIG MODE: Switch to KEYBOARD MODE (force exit config)
  if (digitalRead(RESET_BTN) == LOW) {
    if (!resetPressed) {
      resetPressed = true;
      resetPressTime = millis();
      Serial.println("🔘 RESET button pressed...");
    } else if (millis() - resetPressTime > 5000) {
      
      if (currentMode == MODE_KEYBOARD) {
        // From KEYBOARD → CONFIG
        Serial.println("🔄 RESET BUTTON HELD - RESTARTING IN CONFIG MODE");
        Serial.println("→ Clearing 'configured' flag...");
        prefs.begin("config", false);
        prefs.putBool("configured", false);
        bool saved = prefs.getBool("configured", true);  // Read back to verify
        prefs.end();
        Serial.printf("→ Verified: configured = %s\n", saved ? "true (ERROR!)" : "false (OK)");
      } else {
        // From CONFIG → KEYBOARD
        Serial.println("🔄 RESET BUTTON HELD - SWITCHING TO KEYBOARD MODE");
        // Don't clear configured flag, just switch mode
      }
      
      // Visual feedback
      for(int i=0; i<10; i++) {
        digitalWrite(LED_PIN, HIGH);
        delay(50);
        digitalWrite(LED_PIN, LOW);
        delay(50);
      }
      
      ESP.restart();
    }
  } else {
    resetPressed = false;
  }
  
  // ========== KEYBOARD MODE ONLY ==========
  if (currentMode == MODE_KEYBOARD) {
    // Encoder - handle dial function
    long currentPos = encoderPos;
    if (currentPos != lastEncoderPos) {
      bool increase = (currentPos > lastEncoderPos);
      
      // Execute dial function
      if (config.dial == 6) {
        // Brush Size 5%
        sendBrushKey5(increase);
      } else if (config.dial == 9) {
        // Brush Size 10%
        sendBrushKey10(increase);
      }
      
      lastEncoderPos = currentPos;
    }
    
    // Check if both buttons pressed together (button3 = button1+2 combo)
    bool btn1Low = (digitalRead(BUTTON1_PIN) == LOW);
    bool btn2Low = (digitalRead(BUTTON2_PIN) == LOW);
    bool bothPressed = btn1Low && btn2Low;
    
    // Button 1+2 Combo (has priority over individual buttons)
    if (bothPressed && !button3Pressed) {
      Serial.println("🔘 BUTTON 1+2 COMBO PRESSED");
      button3Pressed = true;
      sendFunctionKey(config.combo);
      digitalWrite(LED_PIN, HIGH);
      delay(50);
      digitalWrite(LED_PIN, LOW);
      
      // Mark both as pressed to prevent individual button triggers
      button1Pressed = true;
      button2Pressed = true;
    } else if (!bothPressed && button3Pressed) {
      button3Pressed = false;
    }
    
    // Button 1 (only if not part of combo)
    if (btn1Low && !button1Pressed && !bothPressed) {
      Serial.println("🔘 BUTTON 1 PRESSED");
      button1Pressed = true;
      
      if (config.button1 == 6) {
        sendBrushKey5(true);  // For button press, default to increase
      } else {
        sendFunctionKey(config.button1);
      }
      
      digitalWrite(LED_PIN, HIGH);
      delay(50);
      digitalWrite(LED_PIN, LOW);
    } else if (!btn1Low) {
      button1Pressed = false;
    }
    
    // Button 2 (only if not part of combo)
    if (btn2Low && !button2Pressed && !bothPressed) {
      Serial.println("🔘 BUTTON 2 PRESSED");
      button2Pressed = true;
      
      if (config.button2 == 6) {
        sendBrushKey5(false);  // For button press, default to decrease
      } else {
        sendFunctionKey(config.button2);
      }
      
      digitalWrite(LED_PIN, HIGH);
      delay(50);
      digitalWrite(LED_PIN, LOW);
    } else if (!btn2Low) {
      button2Pressed = false;
    }
  }
  
  // ========== CONFIG MODE ONLY ==========
  if (currentMode == MODE_CONFIG && deviceConnected) {
    // Blink LED slowly when connected in config mode
    static unsigned long lastBlink = 0;
    if (millis() - lastBlink > 500) {
      digitalWrite(LED_PIN, !digitalRead(LED_PIN));
      lastBlink = millis();
    }
  }
  
  // Handle reconnection
  if (deviceConnected && !oldDeviceConnected) {
    oldDeviceConnected = deviceConnected;
  }
  
  if (!deviceConnected && oldDeviceConnected) {
    delay(500);
    if (currentMode == MODE_KEYBOARD) {
      pServer->startAdvertising();
    }
    oldDeviceConnected = deviceConnected;
  }
  
  delay(10);
}
