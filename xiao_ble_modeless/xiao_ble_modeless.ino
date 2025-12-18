/*
 * CliQ Controller - ESP32-S3 BLE Keyboard with Custom Preset Switch
 * 
 * DESIGN PHILOSOPHY: Config service is ALWAYS accessible
 * 
 * USER EXPERIENCE:
 * 1. First boot: Pair as keyboard on iPad
 * 2. Anytime: Open iOS app → reconfigure (no button press needed!)
 * 3. Config changes apply instantly (no restart)
 * 4. Use 3-position switch to swap between 3 custom presets
 * 
 * HARDWARE:
 * - Button 1 (Pin 4): Configurable function
 * - Button 2 (Pin 5): Configurable function
 * - Button 3 (Pin 9): Click on Scroll - Independent button (configurable)
 * - Button 1+2: Combo function
 * - Scroll Wheel (Pin 7/6): Brush size control (rotate to adjust)
 * - 3-Position Switch:
 *   • Left Pin (Pin 1): Custom 1
 *   • Middle Pin (VCC): Common power
 *   • Right Pin (Pin 3): Custom 3
 *   • Middle position: Custom 2
 * 
 * CUSTOM PRESETS:
 * - Custom 1: User-defined configuration (switch left)
 * - Custom 2: User-defined configuration (switch middle)
 * - Custom 3: User-defined configuration (switch right)
 * 
 * FUNCTION CODES:
 * 3 = Undo (Cmd+Z)
 * 4 = Redo (Cmd+Shift+Z)
 * 5 = Erase (E key)
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
#define BUTTON3_PIN 9
#define ENCODER_A   7
#define ENCODER_B   6
#define SWITCH_LEFT  1  // 3-position switch left (Custom 1)
#define SWITCH_RIGHT 3  // 3-position switch right (Custom 3)

// ============= Key Codes =============
#define KEY_LEFT_BRACKET  0x2F  // [
#define KEY_RIGHT_BRACKET 0x30  // ]
#define KEY_UP_ARROW      0x52  // Up arrow
#define KEY_DOWN_ARROW    0x51  // Down arrow

// ============= Encoder Settings =============
volatile long encoderPos = 0;
volatile int lastEncoded = 0;
volatile unsigned long lastEncoderTime = 0;
const unsigned long ENCODER_DEBOUNCE = 5;

// ============= Switch Settings =============
#define SWITCH_DEBOUNCE_DELAY 100  // 100ms debounce
#define SWITCH_DEBUG_INTERVAL 2000 // Debug every 2 seconds

// ============= Button Configuration =============
struct ButtonConfig {
  int button1 = 3;  // Default: Undo
  int button2 = 3;  // Default: Undo
  int button3 = 3;  // Default: Undo
  int combo = 7;    // Default: Color Palette
  int scroll = 9;   // Default: Brush Size 10%
} config;

// ============= Custom Preset System =============
#define MAX_CUSTOMS 3
ButtonConfig customs[MAX_CUSTOMS];
int currentCustom = 0;  // 0 = Custom 1, 1 = Custom 2, 2 = Custom 3
int lastSwitchMode = -1;  // Track last switch position

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

// ============= Switch Timing =============
unsigned long lastSwitchCheck = 0;
unsigned long lastConfigBroadcast = 0;
unsigned long lastDebugTime = 0;
#define CONFIG_BROADCAST_INTERVAL 1000  // Send config every second

// ============= Helper Functions =============
const char* getCustomName(int customNum) {
  switch(customNum) {
    case 0: return "Custom 1";
    case 1: return "Custom 2";
    case 2: return "Custom 3";
    default: return "Unknown";
  }
}

void sendCurrentConfigToApp();

// ============= Switch Mode Detection =============
int getSwitchMode() {
  int leftState = digitalRead(SWITCH_LEFT);
  int rightState = digitalRead(SWITCH_RIGHT);
  
  // IMPORTANT: Check if using PULLDOWN or PULLUP resistors!
  // With INPUT_PULLDOWN (default):
  // - LOW = not pressed
  // - HIGH = pressed (connected to 3.3V)
  
  // Custom 1: Left=HIGH, Right=LOW (switch to left)
  if (leftState == HIGH && rightState == LOW) return 0;
  
  // Custom 2: Left=LOW, Right=LOW (switch in middle)
  if (leftState == LOW && rightState == LOW) return 1;
  
  // Custom 3: Left=LOW, Right=HIGH (switch to right)
  if (leftState == LOW && rightState == HIGH) return 2;
  
  // Default to Custom 2 if invalid state
  return 1;
}

// ============= Test Switch Function =============
void testSwitch() {
  Serial.println("\n🔧 TESTING 3-POSITION SWITCH:");
  Serial.println("Move switch through positions:");
  Serial.println("1. Left (Custom 1)");
  Serial.println("2. Middle (Custom 2)");
  Serial.println("3. Right (Custom 3)");
  Serial.println("Reading values for 10 seconds...");
  
  for (int i = 0; i < 10; i++) {
    int leftState = digitalRead(SWITCH_LEFT);
    int rightState = digitalRead(SWITCH_RIGHT);
    int mode = getSwitchMode();
    
    Serial.printf("  Left=%d, Right=%d, Mode=%d (%s)\n",
                  leftState, rightState, mode, getCustomName(mode));
    delay(1000);
  }
  Serial.println("Test complete!\n");
}

// ============= Load Custom Function =============
void loadCustom(int customNum) {
  if (customNum < 0 || customNum >= MAX_CUSTOMS) return;
  
  // Load custom preset from flash
  prefs.begin("customs", true);
  String prefix = "c" + String(customNum) + "_";
  
  int b1 = prefs.getInt((prefix + "b1").c_str(), -1);
  
  // Only load if custom exists (button1 != -1)
  if (b1 != -1) {
    config.button1 = b1;
    config.button2 = prefs.getInt((prefix + "b2").c_str(), 3);
    config.button3 = prefs.getInt((prefix + "b3").c_str(), 3);
    config.combo = prefs.getInt((prefix + "combo").c_str(), 7);
    config.scroll = prefs.getInt((prefix + "scroll").c_str(), 9);
    
    Serial.printf("✅ Loaded %s\n", getCustomName(customNum));
    Serial.printf("   Button 1: %d, Button 2: %d, Button 3: %d, Combo: %d, Scroll: %d\n",
                  config.button1, config.button2, config.button3, config.combo, config.scroll);
  } else {
    // Custom not saved yet - keep current config (inherit from previous)
    Serial.printf("⚠️ %s not saved - keeping current config\n", getCustomName(customNum));
    Serial.printf("   Button 1: %d, Button 2: %d, Button 3: %d, Combo: %d, Scroll: %d\n",
                  config.button1, config.button2, config.button3, config.combo, config.scroll);
  }
  
  prefs.end();
  currentCustom = customNum;
  
  // Notify iOS app about the change
  sendCurrentConfigToApp();
}

// ============= Send Config to iOS App =============
void sendCurrentConfigToApp() {
  if (!configChar || !deviceConnected) return;
  
  DynamicJsonDocument doc(256);
  JsonObject buttons = doc.createNestedObject("buttons");
  buttons["button1"] = config.button1;
  buttons["button2"] = config.button2;
  buttons["button3"] = config.button3;
  buttons["combo"] = config.combo;
  buttons["scroll"] = config.scroll;
  doc["currentCustom"] = currentCustom;  // Critical: Tell iOS which custom is active
  
  String output;
  serializeJson(doc, output);
  configChar->setValue(output.c_str());
  configChar->notify();  // Actively notify iOS of the change
  
  Serial.println("📤 Notified iOS app of switch change:");
  Serial.println(output);
}

// ============= BLE Server Callbacks =============
class ServerCallbacks : public BLEServerCallbacks {
  void onConnect(BLEServer* pServer) {
    deviceConnected = true;
    Serial.println("✓ Client connected");
    // Send current config immediately when connected
    delay(100);
    sendCurrentConfigToApp();
  }
  
  void onDisconnect(BLEServer* pServer) {
    deviceConnected = false;
    Serial.println("✗ Client disconnected");
    
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
      
      // Check for command first
      if (doc.containsKey("command")) {
        String command = doc["command"].as<String>();
        
        if (command == "getSwitch") {
          Serial.println("📱 iOS requested switch position");
          sendCurrentConfigToApp();
        }
        return;
      }
      
      if (doc.containsKey("buttons")) {
        JsonObject buttons = doc["buttons"];
        
        // Check if iOS is specifying which custom to save to
        int targetCustom = currentCustom;  // Default to current custom
        if (doc.containsKey("targetCustom")) {
          targetCustom = doc["targetCustom"].as<int>();
          targetCustom = constrain(targetCustom, 0, MAX_CUSTOMS - 1);
          Serial.printf("📍 iOS specified target: %s\n", getCustomName(targetCustom));
        } else {
          Serial.printf("📍 No target specified, using current: %s\n", getCustomName(currentCustom));
        }
        
        // Create config to save
        ButtonConfig configToSave;
        configToSave.button1 = buttons["button1"].as<int>();
        configToSave.button2 = buttons["button2"].as<int>();
        configToSave.button3 = buttons["button3"].as<int>();
        configToSave.combo = buttons["combo"].as<int>();
        configToSave.scroll = buttons["scroll"].as<int>();
        
        // Constrain values
        configToSave.button1 = constrain(configToSave.button1, 0, 11);
        configToSave.button2 = constrain(configToSave.button2, 0, 11);
        configToSave.button3 = constrain(configToSave.button3, 0, 11);
        configToSave.combo = constrain(configToSave.combo, 0, 11);
        configToSave.scroll = constrain(configToSave.scroll, 0, 11);
        
        // Save to target custom preset (may be different from current!)
        prefs.begin("customs", false);
        String prefix = "c" + String(targetCustom) + "_";
        prefs.putInt((prefix + "b1").c_str(), configToSave.button1);
        prefs.putInt((prefix + "b2").c_str(), configToSave.button2);
        prefs.putInt((prefix + "b3").c_str(), configToSave.button3);
        prefs.putInt((prefix + "combo").c_str(), configToSave.combo);
        prefs.putInt((prefix + "scroll").c_str(), configToSave.scroll);
        prefs.end();
        
        // Update in-memory custom
        customs[targetCustom] = configToSave;
        
        // If saving to the current custom, also update running config
        if (targetCustom == currentCustom) {
          config = configToSave;
          Serial.println("\n✅ CONFIG SAVED & APPLIED!");
        } else {
          Serial.println("\n✅ CONFIG SAVED!");
          Serial.printf("  (Not applied - you're on %s)\n", getCustomName(currentCustom));
        }
        
        Serial.printf("  Saved to: %s\n", getCustomName(targetCustom));
        Serial.printf("  Button 1: %d\n", configToSave.button1);
        Serial.printf("  Button 2: %d\n", configToSave.button2);
        Serial.printf("  Button 3: %d\n", configToSave.button3);
        Serial.printf("  Combo (1+2): %d\n", configToSave.combo);
        Serial.printf("  Scroll: %d\n", configToSave.scroll);
        Serial.println("========================================\n");
        
        // Send updated config back to iOS
        sendCurrentConfigToApp();
      } else {
        Serial.println("⚠️ No 'buttons' key in JSON");
      }
    }
  }
  
  void onRead(BLECharacteristic* pChar) {
    Serial.println("📤 iOS requested config via read");
    
    DynamicJsonDocument doc(256);
    JsonObject buttons = doc.createNestedObject("buttons");
    buttons["button1"] = config.button1;
    buttons["button2"] = config.button2;
    buttons["button3"] = config.button3;
    buttons["combo"] = config.combo;
    buttons["scroll"] = config.scroll;
    doc["currentCustom"] = currentCustom;  // Tell iOS which custom is active (0, 1, or 2)
    
    String output;
    serializeJson(doc, output);
    pChar->setValue(output.c_str());
    
    Serial.println("Sent to iOS:");
    Serial.println(output);
  }
};

// ============= Erase Toggle Tracking =============
static int eraseButtonPressCount = 0;

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
    case 5: {  // Erase Toggle (E / B)
      eraseButtonPressCount++;
      
      if (eraseButtonPressCount % 2 == 1) {
        // Odd press - send E (erase mode)
        Serial.println("   → Erase (E)");
        modifier = 0;
        key = 0x08;  // E key
      } else {
        // Even press - send B (brush mode)
        Serial.println("   → Brush (B) - return to brush");
        modifier = 0;
        key = 0x05;  // B key
      }
      break;
    }
    case 6:  // Brush Size 5%
      Serial.println("   → Brush Size 5%");
      return;
    case 7:  // Color Palette (C)
      Serial.println("   → Color Palette (C)");
      modifier = 0;
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
  Serial.println("CLIQ CONTROLLER - MODELESS");
  Serial.println("========================================");
  Serial.println("Design: No mode switching required!");
  Serial.println("• Config service ALWAYS accessible");
  Serial.println("• Open iOS app anytime to reconfigure");
  Serial.println("• No button press needed");
  Serial.println("• Changes apply instantly");
  Serial.println("========================================\n");
  
  pinMode(BUTTON1_PIN, INPUT_PULLUP);
  pinMode(BUTTON2_PIN, INPUT_PULLUP);
  pinMode(BUTTON3_PIN, INPUT_PULLUP);
  pinMode(ENCODER_A, INPUT_PULLUP);
  pinMode(ENCODER_B, INPUT_PULLUP);
  
  // IMPORTANT: Try INPUT_PULLDOWN first. If switch readings are wrong, try INPUT_PULLUP
  pinMode(SWITCH_LEFT, INPUT_PULLDOWN);   // 3-position switch left (Custom 1)
  pinMode(SWITCH_RIGHT, INPUT_PULLDOWN);  // 3-position switch right (Custom 3)
  
  // Test switch at startup
  testSwitch();
  
  attachInterrupt(digitalPinToInterrupt(ENCODER_A), handleEncoder, CHANGE);
  attachInterrupt(digitalPinToInterrupt(ENCODER_B), handleEncoder, CHANGE);
  
  // Load all customs from flash
  prefs.begin("customs", true);
  for (int i = 0; i < MAX_CUSTOMS; i++) {
    String prefix = "c" + String(i) + "_";
    customs[i].button1 = prefs.getInt((prefix + "b1").c_str(), -1);
    customs[i].button2 = prefs.getInt((prefix + "b2").c_str(), 3);
    customs[i].button3 = prefs.getInt((prefix + "b3").c_str(), 3);
    customs[i].combo = prefs.getInt((prefix + "combo").c_str(), 7);
    customs[i].scroll = prefs.getInt((prefix + "scroll").c_str(), 9);
    
    if (customs[i].button1 != -1) {
      Serial.printf("%s: B1=%d B2=%d B3=%d Combo=%d Scroll=%d\n",
        getCustomName(i), customs[i].button1, customs[i].button2, customs[i].button3,
        customs[i].combo, customs[i].scroll);
    } else {
      Serial.printf("%s: Not configured\n", getCustomName(i));
    }
  }
  prefs.end();
  Serial.println();
  
  // Load initial custom based on switch position
  int initialMode = getSwitchMode();
  loadCustom(initialMode);
  lastSwitchMode = initialMode;
  Serial.printf("Initial custom: %s\n\n", getCustomName(initialMode));
  
  // ===== INITIALIZE BLE WITH BOTH SERVICES =====
  Serial.println("🔵 Initializing BLE...");
  BLEDevice::init("CliQ Controller");
  
  pServer = BLEDevice::createServer();
  pServer->setCallbacks(new ServerCallbacks());
  
  // ===== SERVICE 1: HID KEYBOARD (for iPad to use as keyboard) =====
  Serial.println("⌨️  Creating HID keyboard service...");
  hid = new BLEHIDDevice(pServer);
  input = hid->inputReport(1);
  
  hid->manufacturer()->setValue("CliQ");
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
    BLECharacteristic::PROPERTY_READ | BLECharacteristic::PROPERTY_WRITE | BLECharacteristic::PROPERTY_NOTIFY
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
  Serial.println("📱 iPad: Pair 'CliQ Controller' in Bluetooth");
  Serial.println("🔧 iOS App: Open anytime to reconfigure");
  Serial.println("   (No button press needed!)");
  Serial.println("========================================\n");
}

// ============= Loop =============
static bool button1Pressed = false;
static bool button2Pressed = false;
static bool button3Pressed = false;
static bool comboPressed = false;
static long lastEncoderPos = 0;
static unsigned long button1PressTime = 0;
static unsigned long button2PressTime = 0;
const unsigned long COMBO_DETECTION_DELAY = 50;  // 50ms window to detect combo press

void loop() {
  unsigned long currentTime = millis();
  
  // ========== SWITCH DEBUG OUTPUT (every 2 seconds) ==========
  if (currentTime - lastDebugTime > SWITCH_DEBUG_INTERVAL) {
    lastDebugTime = currentTime;
    int leftState = digitalRead(SWITCH_LEFT);
    int rightState = digitalRead(SWITCH_RIGHT);
    int mode = getSwitchMode();
    Serial.printf("🔌 Switch Status: Left=%d, Right=%d, Mode=%d (%s)\n", 
                  leftState, rightState, mode, getCustomName(mode));
  }
  
  // ========== CUSTOM PRESET SWITCHING (with debounce) ==========
  if (currentTime - lastSwitchCheck > SWITCH_DEBOUNCE_DELAY) {
    lastSwitchCheck = currentTime;
    
    int currentMode = getSwitchMode();
    if (currentMode != lastSwitchMode) {
      // Double-check after debounce
      delay(20);
      int verifiedMode = getSwitchMode();
      
      if (verifiedMode != lastSwitchMode) {
        Serial.println("\n========================================");
        Serial.printf("🔄 CUSTOM SWITCH DETECTED\n");
        Serial.printf("   Previous: %s\n", getCustomName(lastSwitchMode));
        Serial.printf("   New: %s\n", getCustomName(verifiedMode));
        
        loadCustom(verifiedMode);
        lastSwitchMode = verifiedMode;
        
        Serial.println("========================================\n");
      }
    }
  }
  
  // ========== BROADCAST CONFIG TO iOS (every second when connected) ==========
  if (deviceConnected && currentTime - lastConfigBroadcast > CONFIG_BROADCAST_INTERVAL) {
    lastConfigBroadcast = currentTime;
    sendCurrentConfigToApp();
  }
  
  // ========== KEYBOARD FUNCTIONS ==========
  // Always active - no mode switching!
  if (deviceConnected) {
    // Encoder
    long currentPos = encoderPos;
    if (currentPos != lastEncoderPos) {
      bool increase = (currentPos > lastEncoderPos);
      
      if (config.scroll == 6) {
        sendBrushKey5(increase);
      } else if (config.scroll == 9) {
        sendBrushKey10(increase);
      }
      
      lastEncoderPos = currentPos;
    }
    
    // Buttons - IMPROVED COMBO DETECTION
    bool btn1Low = (digitalRead(BUTTON1_PIN) == LOW);
    bool btn2Low = (digitalRead(BUTTON2_PIN) == LOW);
    bool btn3Low = (digitalRead(BUTTON3_PIN) == LOW);
    bool bothPressed = btn1Low && btn2Low;
    
    // Track button press times - ONLY SET ONCE on first press
    if (btn1Low && !button1Pressed && button1PressTime == 0) {
      button1PressTime = currentTime;
    }
    if (btn2Low && !button2Pressed && button2PressTime == 0) {
      button2PressTime = currentTime;
    }
    
    // Combo (button1+2) - Highest priority
    if (bothPressed && !comboPressed) {
      Serial.println("🔘 COMBO PRESSED");
      comboPressed = true;
      sendFunctionKey(config.combo);
      button1Pressed = true;
      button2Pressed = true;
      button1PressTime = 0;
      button2PressTime = 0;
    } else if (!bothPressed && comboPressed) {
      comboPressed = false;
    }
    
    // Button 1 - Only trigger if button2 wasn't pressed within combo window
    if (btn1Low && !button1Pressed && !bothPressed && !comboPressed) {
      // Wait to see if button2 is also being pressed (combo detection)
      if (button1PressTime > 0 && (currentTime - button1PressTime >= COMBO_DETECTION_DELAY)) {
        // Check one more time if button2 is pressed
        if (digitalRead(BUTTON2_PIN) == HIGH) {
          Serial.println("🔘 BUTTON 1");
          button1Pressed = true;
          
          if (config.button1 == 6) {
            sendBrushKey5(true);
          } else {
            sendFunctionKey(config.button1);
          }
          button1PressTime = 0;
        }
      }
    } else if (!btn1Low) {
      button1Pressed = false;
      button1PressTime = 0;
    }
    
    // Button 2 - Only trigger if button1 wasn't pressed within combo window
    if (btn2Low && !button2Pressed && !bothPressed && !comboPressed) {
      // Wait to see if button1 is also being pressed (combo detection)
      if (button2PressTime > 0 && (currentTime - button2PressTime >= COMBO_DETECTION_DELAY)) {
        // Check one more time if button1 is pressed
        if (digitalRead(BUTTON1_PIN) == HIGH) {
          Serial.println("🔘 BUTTON 2");
          button2Pressed = true;
          
          if (config.button2 == 6) {
            sendBrushKey5(false);
          } else {
            sendFunctionKey(config.button2);
          }
          button2PressTime = 0;
        }
      }
    } else if (!btn2Low) {
      button2Pressed = false;
      button2PressTime = 0;
    }
    
    // Button 3 - Independent, no combo
    if (btn3Low && !button3Pressed) {
      Serial.println("🔘 BUTTON 3");
      button3Pressed = true;
      
      if (config.button3 == 6) {
        sendBrushKey5(true);
      } else {
        sendFunctionKey(config.button3);
      }
    } else if (!btn3Low) {
      button3Pressed = false;
    }
  }
  
  // Handle reconnection
  if (deviceConnected && !oldDeviceConnected) {
    oldDeviceConnected = deviceConnected;
    Serial.println("✓ Device connected - keyboard active");
    delay(100);
    sendCurrentConfigToApp();  // Send config immediately on connection
  }
  
  if (!deviceConnected && oldDeviceConnected) {
    oldDeviceConnected = deviceConnected;
    delay(500);
    pServer->startAdvertising();
    Serial.println("→ Restarted advertising");
  }
  
  delay(10);
}