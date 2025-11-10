/*
 * XIAO ESP32-S3 BLE Keyboard - DUAL SERVICE (Simplified UX)
 * 
 * APPROACH 2: HID + Config services running simultaneously
 * 
 * USER EXPERIENCE:
 * 1. First boot: Pair as keyboard on iPad
 * 2. Anytime: Open iOS app → reconfigure (no unpair!)
 * 3. Press reset 5 sec: Enter config-ready mode (LED blinks)
 * 4. Config changes apply instantly (no restart)
 * 
 * HARDWARE:
 * - Button 1 (Pin 4): Configurable function
 * - Button 2 (Pin 5): Configurable function
 * - Button 1+2: Combo function
 * - Dial (Pin 7/6): Brush size control
 * - Reset Button (Pin 16): Hold 5 sec to enable config mode
 * 
 * FUNCTION CODES:
 * 3 = Undo (Cmd+Z)
 * 4 = Redo (Cmd+Shift+Z)
 * 5 = Erase (E key)
 * 6 = Brush Size 5% ([ / ] keys)
 * 7 = Color Palette (Cmd+C)
 * 8 = Brush Library (B key)
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
#define RESET_BTN   16
#define LED_PIN     2

// ============= Key Codes =============
#define KEY_LEFT_BRACKET  0x2F  // [
#define KEY_RIGHT_BRACKET 0x30  // ]
#define KEY_UP_ARROW      0x52  // Up arrow
#define KEY_DOWN_ARROW    0x51  // Down arrow

// ============= Config Mode =============
bool configModeActive = false;  // True when config mode is enabled (LED blinks)

// ============= Encoder Settings =============
volatile long encoderPos = 0;
volatile int lastEncoded = 0;
volatile unsigned long lastEncoderTime = 0;
const unsigned long ENCODER_DEBOUNCE = 5;

// ============= Button Configuration =============
struct ButtonConfig {
  int button1 = 3;  // Default: Undo
  int button2 = 3;  // Default: Undo
  int combo = 7;    // Default: Color Palette
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

// ============= BLE Server Callbacks =============
class ServerCallbacks : public BLEServerCallbacks {
  void onConnect(BLEServer* pServer) {
    deviceConnected = true;
    Serial.println("✓ Client connected");
    digitalWrite(LED_PIN, HIGH);
  }
  
  void onDisconnect(BLEServer* pServer) {
    deviceConnected = false;
    Serial.println("✗ Client disconnected");
    digitalWrite(LED_PIN, LOW);
    
    // Restart advertising
    delay(500);
    BLEDevice::startAdvertising();
    Serial.println("→ Restarted advertising");
  }
};

// ============= Config Callbacks =============
class ConfigCallbacks : public BLECharacteristicCallbacks {
  void onWrite(BLECharacteristic* pChar) {
    Serial.println("\n🔔 Config write received!");
    std::string value = pChar->getValue();
    
    if (value.length() > 0) {
      Serial.println("========================================");
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
        
        // Update in-memory config
        config.button1 = buttons["button1"].as<int>();
        config.button2 = buttons["button2"].as<int>();
        config.combo = buttons["combo"].as<int>();
        config.dial = buttons["dial"].as<int>();
        
        config.button1 = constrain(config.button1, 0, 11);
        config.button2 = constrain(config.button2, 0, 11);
        config.combo = constrain(config.combo, 0, 11);
        config.dial = constrain(config.dial, 0, 11);
        
        // Save to flash
        prefs.begin("config", false);
        prefs.putInt("button1", config.button1);
        prefs.putInt("button2", config.button2);
        prefs.putInt("combo", config.combo);
        prefs.putInt("dial", config.dial);
        prefs.end();
        
        Serial.println("\n✅ CONFIG SAVED & APPLIED INSTANTLY!");
        Serial.printf("  Button 1: %d\n", config.button1);
        Serial.printf("  Button 2: %d\n", config.button2);
        Serial.printf("  Combo (1+2): %d\n", config.combo);
        Serial.printf("  Dial: %d\n", config.dial);
        Serial.println("========================================\n");
        
        // Visual confirmation - triple blink
        for(int i=0; i<3; i++) {
          digitalWrite(LED_PIN, LOW);
          delay(100);
          digitalWrite(LED_PIN, HIGH);
          delay(100);
        }
        
        // Exit config mode automatically
        configModeActive = false;
        Serial.println("✓ Config mode disabled - keyboard fully active");
      } else {
        Serial.println("⚠️ No 'buttons' key in JSON");
      }
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
  if (!input || !deviceConnected) return;
  
  Serial.printf("🎹 Function: %d\n", functionCode);
  
  uint8_t modifier = 0;
  uint8_t key = 0;
  
  switch(functionCode) {
    case 3:  // Undo (Cmd+Z)
      Serial.println("   → Undo (Cmd+Z)");
      modifier = 0x08;
      key = 0x1D;
      break;
    case 4:  // Redo (Cmd+Shift+Z)
      Serial.println("   → Redo (Cmd+Shift+Z)");
      modifier = 0x0A;
      key = 0x1D;
      break;
    case 5:  // Erase (E)
      Serial.println("   → Erase (E)");
      modifier = 0;
      key = 0x08;
      break;
    case 6:  // Brush Size 5%
      Serial.println("   → Brush Size 5%");
      return;
    case 7:  // Color Palette (Cmd+C)
      Serial.println("   → Color Palette (Cmd+C)");
      modifier = 0x08;
      key = 0x06;
      break;
    case 8:  // Brush Library (B)
      Serial.println("   → Brush Library (B)");
      modifier = 0;
      key = 0x05;
      break;
    case 9:  // Brush Size 10%
      Serial.println("   → Brush Size 10%");
      return;
    default:
      Serial.printf("   → Unknown: %d\n", functionCode);
      return;
  }
  
  uint8_t msg[] = {modifier, 0, key, 0, 0, 0, 0, 0};
  input->setValue(msg, sizeof(msg));
  input->notify();
  delay(20);
  
  uint8_t msg2[] = {0, 0, 0, 0, 0, 0, 0, 0};
  input->setValue(msg2, sizeof(msg2));
  input->notify();
}

void sendBrushKey5(bool increase) {
  if (!input || !deviceConnected) return;
  
  uint8_t key = increase ? KEY_RIGHT_BRACKET : KEY_LEFT_BRACKET;
  
  uint8_t msg[] = {0, 0, key, 0, 0, 0, 0, 0};
  input->setValue(msg, sizeof(msg));
  input->notify();
  delay(20);
  
  uint8_t msg2[] = {0, 0, 0, 0, 0, 0, 0, 0};
  input->setValue(msg2, sizeof(msg2));
  input->notify();
}

void sendBrushKey10(bool increase) {
  if (!input || !deviceConnected) return;
  
  uint8_t arrowKey = increase ? KEY_UP_ARROW : KEY_DOWN_ARROW;
  uint8_t bracketKey = increase ? KEY_RIGHT_BRACKET : KEY_LEFT_BRACKET;
  
  uint8_t msg[] = {0, 0, arrowKey, bracketKey, 0, 0, 0, 0};
  input->setValue(msg, sizeof(msg));
  input->notify();
  delay(20);
  
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

// ============= Setup =============
void setup() {
  Serial.begin(115200);
  delay(1000);
  
  Serial.println("\n\n========================================");
  Serial.println("XIAO BLE KEYBOARD - DUAL SERVICE MODE");
  Serial.println("========================================");
  Serial.println("Features:");
  Serial.println("• HID + Config services always active");
  Serial.println("• No restart needed for reconfiguration");
  Serial.println("• No unpair/forget device needed");
  Serial.println("• Instant config changes");
  Serial.println("========================================\n");
  
  pinMode(BUTTON1_PIN, INPUT_PULLUP);
  pinMode(BUTTON2_PIN, INPUT_PULLUP);
  pinMode(ENCODER_A, INPUT_PULLUP);
  pinMode(ENCODER_B, INPUT_PULLUP);
  pinMode(RESET_BTN, INPUT_PULLDOWN);
  pinMode(LED_PIN, OUTPUT);
  
  attachInterrupt(digitalPinToInterrupt(ENCODER_A), handleEncoder, CHANGE);
  attachInterrupt(digitalPinToInterrupt(ENCODER_B), handleEncoder, CHANGE);
  
  // Load config
  prefs.begin("config", true);
  config.button1 = prefs.getInt("button1", 3);
  config.button2 = prefs.getInt("button2", 3);
  config.combo = prefs.getInt("combo", 7);
  config.dial = prefs.getInt("dial", 9);
  prefs.end();
  
  Serial.printf("Loaded config:\n");
  Serial.printf("  Button 1: %d\n", config.button1);
  Serial.printf("  Button 2: %d\n", config.button2);
  Serial.printf("  Combo (1+2): %d\n", config.combo);
  Serial.printf("  Dial: %d\n\n", config.dial);
  
  // ===== INITIALIZE BLE WITH BOTH SERVICES =====
  Serial.println("🔵 Initializing BLE...");
  BLEDevice::init("XIAO Keyboard");
  
  pServer = BLEDevice::createServer();
  pServer->setCallbacks(new ServerCallbacks());
  
  // ===== SERVICE 1: HID KEYBOARD (for iPad to use as keyboard) =====
  Serial.println("⌨️  Creating HID keyboard service...");
  hid = new BLEHIDDevice(pServer);
  input = hid->inputReport(1);
  
  hid->manufacturer()->setValue("XIAO");
  hid->pnp(0x02, 0x1234, 0x5678, 0x0110);
  hid->hidInfo(0x00, 0x01);
  
  // Security for HID (required by iOS)
  BLESecurity* security = new BLESecurity();
  security->setAuthenticationMode(ESP_LE_AUTH_BOND);
  
  const uint8_t reportMap[] = {
    0x05, 0x01, 0x09, 0x06, 0xA1, 0x01, 0x85, 0x01, 0x05, 0x07,
    0x19, 0xE0, 0x29, 0xE7, 0x15, 0x00, 0x25, 0x01, 0x75, 0x01,
    0x95, 0x08, 0x81, 0x02, 0x95, 0x01, 0x75, 0x08, 0x81, 0x01,
    0x95, 0x06, 0x75, 0x08, 0x15, 0x00, 0x25, 0x65, 0x05, 0x07,
    0x19, 0x00, 0x29, 0x65, 0x81, 0x00, 0xC0
  };
  
  hid->reportMap((uint8_t*)reportMap, sizeof(reportMap));
  hid->startServices();
  hid->setBatteryLevel(100);
  Serial.println("✅ HID service active");
  
  // ===== SERVICE 2: CONFIG (for iOS app to change settings) =====
  Serial.println("⚙️  Creating config service...");
  configService = pServer->createService(SERVICE_UUID);
  
  configChar = configService->createCharacteristic(
    CHAR_UUID_CONFIG,
    BLECharacteristic::PROPERTY_READ | BLECharacteristic::PROPERTY_WRITE
  );
  configChar->setCallbacks(new ConfigCallbacks());
  configChar->addDescriptor(new BLE2902());
  
  configService->start();
  Serial.println("✅ Config service active");
  
  // ===== START ADVERTISING BOTH SERVICES =====
  Serial.println("📡 Starting advertising...");
  BLEAdvertising* pAdvertising = BLEDevice::getAdvertising();
  pAdvertising->setAppearance(0x03C1);  // Keyboard appearance
  pAdvertising->addServiceUUID(hid->hidService()->getUUID());
  pAdvertising->addServiceUUID(SERVICE_UUID);  // Also advertise config service
  pAdvertising->setScanResponse(true);
  pAdvertising->setMinPreferred(0x06);
  pAdvertising->setMaxPreferred(0x0C);
  pAdvertising->start();
  
  Serial.println("\n========================================");
  Serial.println("✅ DEVICE READY");
  Serial.println("========================================");
  Serial.println("📱 iPad: Pair 'XIAO Keyboard' in Bluetooth");
  Serial.println("🔧 iOS App: Can connect anytime to reconfigure");
  Serial.println("🔘 Reset: Hold 5 sec to enable config mode");
  Serial.println("========================================\n");
  
  // Startup LED pattern
  for(int i=0; i<3; i++) {
    digitalWrite(LED_PIN, HIGH);
    delay(100);
    digitalWrite(LED_PIN, LOW);
    delay(100);
  }
}

// ============= Loop =============
static bool button1Pressed = false;
static bool button2Pressed = false;
static bool button3Pressed = false;
static bool resetPressed = false;
static unsigned long resetPressTime = 0;
static long lastEncoderPos = 0;
static unsigned long lastConfigBlink = 0;

void loop() {
  // Config mode LED blink (when enabled)
  if (configModeActive) {
    if (millis() - lastConfigBlink > 200) {
      digitalWrite(LED_PIN, !digitalRead(LED_PIN));
      lastConfigBlink = millis();
    }
  } else if (!deviceConnected) {
    digitalWrite(LED_PIN, LOW);
  } else {
    digitalWrite(LED_PIN, HIGH);
  }
  
  // Reset button - hold for 5 seconds to enable config mode
  if (digitalRead(RESET_BTN) == HIGH) {
    if (!resetPressed) {
      resetPressed = true;
      resetPressTime = millis();
      Serial.println("🔘 RESET button pressed...");
    } else if (millis() - resetPressTime > 5000) {
      configModeActive = !configModeActive;
      
      if (configModeActive) {
        Serial.println("\n🔧 CONFIG MODE ENABLED");
        Serial.println("→ LED will blink rapidly");
        Serial.println("→ Open iOS app to reconfigure");
        Serial.println("→ Changes apply instantly");
        
        // Restart advertising to make device more discoverable
        Serial.println("📡 Restarting BLE advertising...");
        pServer->getAdvertising()->stop();
        delay(100);
        
        BLEAdvertising* pAdvertising = pServer->getAdvertising();
        pAdvertising->addServiceUUID(SERVICE_UUID);  // Ensure config service is advertised
        pAdvertising->setScanResponse(true);
        pAdvertising->start();
        
        Serial.println("✅ Device name: XIAO Keyboard");
        Serial.println("✅ Advertising service UUID: 12345678-1234-5678-1234-56789abcdef0");
        Serial.println("→ iOS app should now discover this device\n");
      } else {
        Serial.println("\n⌨️  CONFIG MODE DISABLED");
        Serial.println("→ Keyboard fully active\n");
      }
      
      // Visual feedback
      for(int i=0; i<5; i++) {
        digitalWrite(LED_PIN, HIGH);
        delay(50);
        digitalWrite(LED_PIN, LOW);
        delay(50);
      }
      
      resetPressed = false;
    }
  } else {
    if (resetPressed) {
      Serial.println("🔘 RESET button released (held < 5 seconds)");
    }
    resetPressed = false;
  }
  
  // ========== KEYBOARD FUNCTIONS ==========
  // Only process keyboard inputs when NOT in config mode
  if (!configModeActive && deviceConnected) {
    // Encoder
    long currentPos = encoderPos;
    if (currentPos != lastEncoderPos) {
      bool increase = (currentPos > lastEncoderPos);
      
      if (config.dial == 6) {
        sendBrushKey5(increase);
      } else if (config.dial == 9) {
        sendBrushKey10(increase);
      }
      
      lastEncoderPos = currentPos;
    }
    
    // Buttons
    bool btn1Low = (digitalRead(BUTTON1_PIN) == LOW);
    bool btn2Low = (digitalRead(BUTTON2_PIN) == LOW);
    bool bothPressed = btn1Low && btn2Low;
    
    // Combo (button1+2)
    if (bothPressed && !button3Pressed) {
      Serial.println("🔘 COMBO PRESSED");
      button3Pressed = true;
      sendFunctionKey(config.combo);
      button1Pressed = true;
      button2Pressed = true;
    } else if (!bothPressed && button3Pressed) {
      button3Pressed = false;
    }
    
    // Button 1
    if (btn1Low && !button1Pressed && !bothPressed) {
      Serial.println("🔘 BUTTON 1");
      button1Pressed = true;
      
      if (config.button1 == 6) {
        sendBrushKey5(true);
      } else {
        sendFunctionKey(config.button1);
      }
    } else if (!btn1Low) {
      button1Pressed = false;
    }
    
    // Button 2
    if (btn2Low && !button2Pressed && !bothPressed) {
      Serial.println("🔘 BUTTON 2");
      button2Pressed = true;
      
      if (config.button2 == 6) {
        sendBrushKey5(false);
      } else {
        sendFunctionKey(config.button2);
      }
    } else if (!btn2Low) {
      button2Pressed = false;
    }
  }
  
  // Handle reconnection
  if (deviceConnected && !oldDeviceConnected) {
    oldDeviceConnected = deviceConnected;
    Serial.println("✓ Device connected - keyboard active");
  }
  
  if (!deviceConnected && oldDeviceConnected) {
    oldDeviceConnected = deviceConnected;
    delay(500);
    pServer->startAdvertising();
    Serial.println("→ Restarted advertising");
  }
  
  delay(10);
}
