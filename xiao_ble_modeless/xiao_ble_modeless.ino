/*
 * XIAO ESP32-S3 BLE Keyboard - MODELESS (No Config Mode)
 * 
 * DESIGN PHILOSOPHY: Config service is ALWAYS accessible
 * 
 * USER EXPERIENCE:
 * 1. First boot: Pair as keyboard on iPad
 * 2. Anytime: Open iOS app → reconfigure (no button press needed!)
 * 3. Config changes apply instantly (no restart)
 * 
 * HARDWARE:
 * - Button 1 (Pin 4): Configurable function
 * - Button 2 (Pin 5): Configurable function
 * - Button 1+2: Combo function
 * - Dial (Pin 7/6): Brush size control
 * - Reset Button (Pin 16): Not used (reserved for future features)
 * 
 * FUNCTION CODES:
 * 3 = Undo (Cmd+Z)
 * 4 = Redo (Cmd+Shift+Z)
 * 5 = Erase (E key) / Brush (B key) toggle
 * 6 = Brush Size 5% ([ / ] keys)
 * 7 = Color Palette (C key)
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
#define ENCODER_A   7  // Brush size encoder (active-low, uses GND)
#define ENCODER_B   6
#define ENCODER2_A  8  // Preset encoder (active-high, uses VCC)
#define ENCODER2_B  9
#define RESET_BTN   16  // Reserved for future use
#define LED_PIN     2

// ============= Key Codes =============
#define KEY_LEFT_BRACKET  0x2F  // [
#define KEY_RIGHT_BRACKET 0x30  // ]
#define KEY_UP_ARROW      0x52  // Up arrow
#define KEY_DOWN_ARROW    0x51  // Down arrow

// ============= Encoder Settings =============
// Encoder 1: Brush size control (active-low with GND)
volatile long encoderPos = 0;
volatile int lastEncoded = 0;
volatile unsigned long lastEncoderTime = 0;
const unsigned long ENCODER_DEBOUNCE = 5;

// Encoder 2: Preset switching (active-high with VCC)
volatile long encoder2Pos = 0;
volatile int lastEncoded2 = 0;
volatile unsigned long lastEncoder2Time = 0;
const unsigned long ENCODER2_DEBOUNCE = 5;

// ============= Button Configuration =============
struct ButtonConfig {
  int button1 = 3;  // Default: Undo
  int button2 = 3;  // Default: Undo
  int combo = 7;    // Default: Color Palette
  int dial = 9;     // Default: Brush Size 10%
} config;

// ============= Preset System =============
#define MAX_PRESETS 2
ButtonConfig presets[MAX_PRESETS];
int currentPreset = -1;  // -1 means no preset loaded (custom config)

// Erase toggle state tracking
bool isInEraseMode = false;

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
    uint16_t connCount = pServer->getConnectedCount();
    Serial.printf("✓ Client connected (total connections: %d)\n", connCount);
    digitalWrite(LED_PIN, HIGH);
    
    // CRITICAL: Keep advertising even when connected!
    // This allows iOS app to discover the device while iPad is paired
    // Note: BLE normally stops advertising after connection - we force it back on
    pServer->getAdvertising()->start();
    Serial.println("✓ Advertising restarted - device still discoverable");
  }
  
  void onDisconnect(BLEServer* pServer) {
    uint16_t connCount = pServer->getConnectedCount();
    Serial.printf("✗ Client disconnected (remaining connections: %d)\n", connCount);
    
    // ALWAYS restart advertising so new devices can discover us
    // This allows iOS app to reconnect even if iPad is still connected
    delay(500);
    BLEDevice::startAdvertising();
    Serial.println("→ Restarted advertising (device discoverable)");
    
    // Only update deviceConnected if NO connections remain
    if (connCount == 0) {
      deviceConnected = false;
      Serial.println("→ All connections closed");
    } else {
      Serial.printf("→ %d connection(s) still active\n", connCount);
    }
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
        
        // Constrain values
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
        
        // Reset current preset to custom (0) since config changed
        currentPreset = 0;
        Serial.println("  Preset: Custom (0)");
        Serial.println("========================================\n");
        
        // Visual confirmation - quick blink (non-blocking)
        // Note: Full LED control happens in loop(), this is just feedback
        digitalWrite(LED_PIN, LOW);
        delay(50);
        digitalWrite(LED_PIN, HIGH);
      }
      
      // Handle preset save
      if (doc.containsKey("preset")) {
        int presetNum = doc["preset"].as<int>();
        if (presetNum >= 1 && presetNum <= MAX_PRESETS) {
          int idx = presetNum - 1;
          
          // Save current config as preset
          presets[idx] = config;
          
          // Save to flash
          prefs.begin("config", false);
          String prefix = "preset" + String(idx) + "_";
          prefs.putInt((prefix + "b1").c_str(), config.button1);
          prefs.putInt((prefix + "b2").c_str(), config.button2);
          prefs.putInt((prefix + "combo").c_str(), config.combo);
          prefs.putInt((prefix + "dial").c_str(), config.dial);
          prefs.end();
          
          Serial.printf("\n💾 PRESET %d SAVED!\n", presetNum);
          Serial.printf("  Button 1: %d\n", config.button1);
          Serial.printf("  Button 2: %d\n", config.button2);
          Serial.printf("  Combo (1+2): %d\n", config.combo);
          Serial.printf("  Dial: %d\n", config.dial);
          Serial.println("========================================\n");
          
          // Visual confirmation - double blink
          for (int i = 0; i < 2; i++) {
            digitalWrite(LED_PIN, LOW);
            delay(100);
            digitalWrite(LED_PIN, HIGH);
            delay(100);
          }
        } else {
          Serial.printf("❌ Invalid preset number: %d (must be 1-%d)\n", presetNum, MAX_PRESETS);
        }
      } else {
        Serial.println("⚠️ No 'buttons' or 'preset' key in JSON");
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
    case 5:  // Erase - Toggle between brush and eraser
      if (isInEraseMode) {
        Serial.println("   → Switch to Brush (B)");
        isInEraseMode = false;
        modifier = 0;
        key = 0x05;  // B key (Brush)
      } else {
        Serial.println("   → Switch to Eraser (E)");
        isInEraseMode = true;
        modifier = 0;
        key = 0x08;  // E key (Eraser)
      }
      break;
    case 6:  // Brush Size 5%
      Serial.println("   → Brush Size 5%");
      return;
    case 7:  // Color Palette (C)
      Serial.println("   → Color Palette (C)");
      modifier = 0;
      key = 0x06;  // C key
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

// ============= Encoder Interrupts =============
// Encoder 1: Brush size (active-low with GND)
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

// Encoder 2: Preset switching (active-high with VCC)
// Note: Inverted logic compared to encoder 1 due to VCC connection
void IRAM_ATTR handleEncoder2() {
  unsigned long currentTime = millis();
  if (currentTime - lastEncoder2Time < ENCODER2_DEBOUNCE) return;
  lastEncoder2Time = currentTime;
  
  // Read pins - inverted logic for VCC connection
  int MSB = !digitalRead(ENCODER2_A);  // Invert for active-high
  int LSB = !digitalRead(ENCODER2_B);  // Invert for active-high
  int encoded = (MSB << 1) | LSB;
  int sum = (lastEncoded2 << 2) | encoded;
  
  if (sum == 0b1101 || sum == 0b0100 || sum == 0b0010 || sum == 0b1011) encoder2Pos++;
  if (sum == 0b1110 || sum == 0b0111 || sum == 0b0001 || sum == 0b1000) encoder2Pos--;
  
  lastEncoded2 = encoded;
}

// ============= Setup =============
void setup() {
  Serial.begin(115200);
  delay(1000);
  
  Serial.println("\n\n========================================");
  Serial.println("XIAO BLE KEYBOARD - MODELESS");
  Serial.println("========================================");
  Serial.println("Design: No mode switching required!");
  Serial.println("• Config service ALWAYS accessible");
  Serial.println("• Open iOS app anytime to reconfigure");
  Serial.println("• No button press needed");
  Serial.println("• Changes apply instantly");
  Serial.println("========================================\n");
  
  pinMode(BUTTON1_PIN, INPUT_PULLUP);
  pinMode(BUTTON2_PIN, INPUT_PULLUP);
  pinMode(ENCODER_A, INPUT_PULLUP);    // Encoder 1 (GND) - needs pullup
  pinMode(ENCODER_B, INPUT_PULLUP);
  pinMode(ENCODER2_A, INPUT_PULLDOWN); // Encoder 2 (VCC) - needs pulldown
  pinMode(ENCODER2_B, INPUT_PULLDOWN);
  pinMode(RESET_BTN, INPUT_PULLDOWN);  // Reserved for future
  pinMode(LED_PIN, OUTPUT);
  
  attachInterrupt(digitalPinToInterrupt(ENCODER_A), handleEncoder, CHANGE);
  attachInterrupt(digitalPinToInterrupt(ENCODER_B), handleEncoder, CHANGE);
  attachInterrupt(digitalPinToInterrupt(ENCODER2_A), handleEncoder2, CHANGE);
  attachInterrupt(digitalPinToInterrupt(ENCODER2_B), handleEncoder2, CHANGE);
  
  // Load config from flash
  prefs.begin("config", true);
  config.button1 = prefs.getInt("button1", 3);
  config.button2 = prefs.getInt("button2", 3);
  config.combo = prefs.getInt("combo", 7);
  config.dial = prefs.getInt("dial", 9);
  
  // Load presets
  for (int i = 0; i < MAX_PRESETS; i++) {
    String prefix = "preset" + String(i) + "_";
    presets[i].button1 = prefs.getInt((prefix + "b1").c_str(), -1);
    presets[i].button2 = prefs.getInt((prefix + "b2").c_str(), -1);
    presets[i].combo = prefs.getInt((prefix + "combo").c_str(), -1);
    presets[i].dial = prefs.getInt((prefix + "dial").c_str(), -1);
  }
  prefs.end();
  
  Serial.printf("Loaded config:\n");
  Serial.printf("  Button 1: %d\n", config.button1);
  Serial.printf("  Button 2: %d\n", config.button2);
  Serial.printf("  Combo (1+2): %d\n", config.combo);
  Serial.printf("  Dial: %d\n\n", config.dial);
  
  Serial.printf("Loaded presets:\n");
  for (int i = 0; i < MAX_PRESETS; i++) {
    if (presets[i].button1 != -1) {
      Serial.printf("  Preset %d: B1=%d B2=%d Combo=%d Dial=%d\n", 
        i+1, presets[i].button1, presets[i].button2, presets[i].combo, presets[i].dial);
    } else {
      Serial.printf("  Preset %d: Not set\n", i+1);
    }
  }
  Serial.println();
  
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
  pAdvertising->addServiceUUID(SERVICE_UUID);  // Advertise config service
  pAdvertising->setScanResponse(true);
  pAdvertising->setMinPreferred(0x06);
  pAdvertising->setMaxPreferred(0x0C);
  pAdvertising->start();
  
  Serial.println("\n========================================");
  Serial.println("✅ DEVICE READY");
  Serial.println("========================================");
  Serial.println("📱 iPad: Pair 'XIAO Keyboard' in Bluetooth");
  Serial.println("🔧 iOS App: Open anytime to reconfigure");
  Serial.println("   (No button press needed!)");
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
static long lastEncoderPos = 0;
static long lastEncoder2Pos = 0;
static unsigned long lastAdvertisingCheck = 0;
static unsigned long button1PressTime = 0;
static unsigned long button2PressTime = 0;
const unsigned long COMBO_WINDOW = 200;  // 200ms window for combo detection
const unsigned long BUTTON_DEBOUNCE = 50;  // 50ms debounce before individual button triggers

void loop() {
  // Check actual connection count first (more reliable than boolean flag)
  if (!pServer) {
    Serial.println("❌ ERROR: pServer is null!");
    delay(1000);
    return;
  }
  
  uint16_t connCount = pServer->getConnectedCount();
  bool hasConnections = (connCount > 0);
  
  // CRITICAL: Ensure advertising is ALWAYS on (even when connected)
  // Check every 5 seconds and restart advertising as failsafe
  if (millis() - lastAdvertisingCheck > 5000) {
    lastAdvertisingCheck = millis();
    // Just restart advertising periodically to ensure it stays on
    pServer->getAdvertising()->start();
    Serial.println("✓ Periodic advertising restart (keeping device discoverable)");
  }
  
  // Update deviceConnected based on actual connection count
  deviceConnected = hasConnections;
  
  // LED: ON when connected, OFF when disconnected
  digitalWrite(LED_PIN, hasConnections ? HIGH : LOW);
  
  // ========== KEYBOARD FUNCTIONS ==========
  // Always active when any device is connected
  if (hasConnections) {
    // Encoder 1: Brush size control
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
    
    // Encoder 2: Preset switching (1 degree = 1 preset change)
    long currentPos2 = encoder2Pos;
    if (currentPos2 != lastEncoder2Pos) {
      int direction = (currentPos2 > lastEncoder2Pos) ? 1 : -1;
      int steps = abs(currentPos2 - lastEncoder2Pos);
      
      // Each step switches preset
      for (int i = 0; i < steps; i++) {
        currentPreset += direction;
        
        // Wrap around: 0 -> Preset 1 -> Preset 2 -> 0 (custom)
        if (currentPreset > MAX_PRESETS) currentPreset = 0;
        if (currentPreset < 0) currentPreset = MAX_PRESETS;
        
        // Load preset or restore custom config
        if (currentPreset == 0) {
          // Restore custom config from flash
          prefs.begin("config", true);
          config.button1 = prefs.getInt("button1", 3);
          config.button2 = prefs.getInt("button2", 3);
          config.combo = prefs.getInt("combo", 7);
          config.dial = prefs.getInt("dial", 9);
          prefs.end();
          Serial.println("🔄 Switched to: Custom Config");
        } else {
          int idx = currentPreset - 1;
          if (presets[idx].button1 != -1) {
            config = presets[idx];
            Serial.printf("🔄 Switched to: Preset %d\n", currentPreset);
            Serial.printf("   B1=%d B2=%d Combo=%d Dial=%d\n", 
              config.button1, config.button2, config.combo, config.dial);
          } else {
            Serial.printf("⚠️ Preset %d not configured, staying on current\n", currentPreset);
            currentPreset -= direction;  // Revert
          }
        }
        
        // Visual feedback - quick blink
        digitalWrite(LED_PIN, LOW);
        delay(50);
        digitalWrite(LED_PIN, HIGH);
      }
      
      lastEncoder2Pos = currentPos2;
    }
    
    // Buttons
    bool btn1Low = (digitalRead(BUTTON1_PIN) == LOW);
    bool btn2Low = (digitalRead(BUTTON2_PIN) == LOW);
    unsigned long currentTime = millis();
    
    // Track when each button is first pressed
    if (btn1Low && !button1Pressed) {
      button1PressTime = currentTime;
      button1Pressed = true;  // Mark as pressed immediately to prevent retriggering
    }
    if (btn2Low && !button2Pressed) {
      button2PressTime = currentTime;
      button2Pressed = true;  // Mark as pressed immediately to prevent retriggering
    }
    
    // Reset pressed flags when buttons released
    if (!btn1Low) button1Pressed = false;
    if (!btn2Low) button2Pressed = false;
    
    // Check if both buttons pressed within timing window (combo detection)
    bool isCombo = (btn1Low && btn2Low) ||
                   (btn1Low && (currentTime - button2PressTime < COMBO_WINDOW)) ||
                   (btn2Low && (currentTime - button1PressTime < COMBO_WINDOW));
    
    // Combo (button1+2) - Execute when combo is detected
    if (isCombo && btn1Low && btn2Low && !button3Pressed) {
      Serial.println("🔘 COMBO PRESSED");
      Serial.printf("   Config.combo = %d\n", config.combo);
      button3Pressed = true;
      sendFunctionKey(config.combo);
    } else if (!btn1Low && !btn2Low) {
      // Both buttons released - reset combo flag
      button3Pressed = false;
    }
    
    // Individual buttons - Only trigger if:
    // 1. NOT in combo mode
    // 2. Button has been held for debounce time (to wait and see if it's a combo)
    // 3. Other button is not pressed
    if (!button3Pressed && !isCombo) {
      // Button 1 - only trigger if held long enough and button2 is not pressed
      if (btn1Low && !btn2Low && (currentTime - button1PressTime >= BUTTON_DEBOUNCE)) {
        static bool btn1Triggered = false;
        if (!btn1Triggered) {
          Serial.println("🔘 BUTTON 1");
          Serial.printf("   Config.button1 = %d\n", config.button1);
          btn1Triggered = true;
          
          if (config.button1 == 6) {
            sendBrushKey5(true);
          } else {
            sendFunctionKey(config.button1);
          }
        }
        if (!btn1Low) btn1Triggered = false;
      }
      
      // Button 2 - only trigger if held long enough and button1 is not pressed
      if (btn2Low && !btn1Low && (currentTime - button2PressTime >= BUTTON_DEBOUNCE)) {
        static bool btn2Triggered = false;
        if (!btn2Triggered) {
          Serial.println("🔘 BUTTON 2");
          Serial.printf("   Config.button2 = %d\n", config.button2);
          btn2Triggered = true;
          
          if (config.button2 == 6) {
            sendBrushKey5(false);
          } else {
            sendFunctionKey(config.button2);
          }
        }
        if (!btn2Low) btn2Triggered = false;
      }
    }
  }
  
  // Track connection state changes for logging
  if (hasConnections && !oldDeviceConnected) {
    oldDeviceConnected = true;
    Serial.printf("✓ Connection state: CONNECTED (total: %d)\n", connCount);
  }
  
  if (!hasConnections && oldDeviceConnected) {
    oldDeviceConnected = false;
    Serial.println("✗ Connection state: DISCONNECTED");
  }
  
  delay(10);
}
