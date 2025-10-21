// XIAO ESP32-S3 BLE Keyboard - Unified Version
// Combines configurable web interface with real-time monitoring
// Features: WiFi config UI + WebSocket monitoring + BLE keyboard

#include <BLEDevice.h>
#include <BLEUtils.h>
#include <BLEServer.h>
#include <BLE2902.h>
#include <BLEHIDDevice.h>
#include <Arduino.h>
#include <ArduinoJson.h>
#include <Preferences.h>

// ============================================
// CONFIGURATION
// ============================================
const char* ssid = "Amy";        // Change this!
const char* password = "Ayaymye1125"; // Change this!

// Hardware pins for XIAO ESP32-S3
#define BUTTON1_PIN 1   // D0 on XIAO (GPIO1)
#define BUTTON2_PIN 3   // D2 on XIAO (GPIO3)
#define BUTTON3_PIN 4   // D3 on XIAO (GPIO4)
#define LED_PIN 21      // Built-in RGB LED

// Keyboard key codes
#define KEY_LEFT_GUI      0x08  // Left Command key
#define KEY_RIGHT_GUI     0x80  // Right Command key
#define KEY_LEFT_SHIFT    0x02  // Left Shift key
#define KEY_Z             0x1D  // Z key
#define KEY_T             0x17  // T key

// ============================================
// GLOBAL VARIABLES
// ============================================
// Button configuration (0=LeftClick, 1=RightClick, 2=DoubleClick, 3=Undo, 4=Redo)
int button1Function = 3;    // Default: Undo
int button2Function = 4;    // Default: Redo
int button3Function = 3;    // Default: Undo (test)

// Button states
bool lastBtn1 = HIGH;
bool lastBtn2 = HIGH;
bool lastBtn3 = HIGH;
unsigned long lastDebounce = 0;

// BLE HID
BLEHIDDevice* hid;
BLECharacteristic* input;
BLECharacteristic* output;
bool bleConnected = false;

// BLE GATT for config/status/events
BLECharacteristic* configChar;
BLECharacteristic* eventChar;
BLECharacteristic* statusChar;
// Non-volatile storage for configuration
Preferences prefs;

// Statistics
unsigned long pressCount1 = 0;
unsigned long pressCount2 = 0;
unsigned long pressCount3 = 0;
unsigned long startTime = 0;

// ============================================
// HID REPORT DESCRIPTOR (PROGMEM to save flash)
// ============================================
static const uint8_t reportMap[] PROGMEM = {
  0x05, 0x01,        // Usage Page (Generic Desktop)
  0x09, 0x06,        // Usage (Keyboard)
  0xA1, 0x01,        // Collection (Application)
  0x85, 0x01,        // Report ID (1)
  
  // Modifier keys
  0x05, 0x07,        // Usage Page (Key Codes)
  0x19, 0xE0,        // Usage Minimum (224)
  0x29, 0xE7,        // Usage Maximum (231)
  0x15, 0x00,        // Logical Minimum (0)
  0x25, 0x01,        // Logical Maximum (1)
  0x75, 0x01,        // Report Size (1)
  0x95, 0x08,        // Report Count (8)
  0x81, 0x02,        // Input (Data, Variable, Absolute)
  
  // Reserved byte
  0x95, 0x01,        // Report Count (1)
  0x75, 0x08,        // Report Size (8)
  0x81, 0x01,        // Input (Constant)
  
  // Keys
  0x95, 0x06,        // Report Count (6)
  0x75, 0x08,        // Report Size (8)
  0x15, 0x00,        // Logical Minimum (0)
  0x25, 0x65,        // Logical Maximum (101)
  0x05, 0x07,        // Usage Page (Key Codes)
  0x19, 0x00,        // Usage Minimum (0)
  0x29, 0x65,        // Usage Maximum (101)
  0x81, 0x00,        // Input (Data, Array)
  
  0xC0               // End Collection
};

// ============================================
// BLE CALLBACKS
// ============================================
class MyServerCallbacks : public BLEServerCallbacks {
  void onConnect(BLEServer* pServer) {
    bleConnected = true;
    Serial.println(F("iPad/iOS CONNECTED via BLE!"));

    // Notify central via event characteristic
    if (eventChar) {
      String msg = "{\"type\":\"ble_status\",\"connected\":true,\"timestamp\":" + String(millis()) + "}";
      eventChar->setValue(msg.c_str());
      eventChar->notify();
    }

    // LED feedback
    for (int i = 0; i < 3; i++) {
      digitalWrite(LED_PIN, HIGH);
      delay(100);
      digitalWrite(LED_PIN, LOW);
      delay(100);
    }
  }

  void onDisconnect(BLEServer* pServer) {
    bleConnected = false;
    Serial.println(F("iPad/iOS DISCONNECTED"));
    
    // Notify central via event characteristic
    if (eventChar) {
      String msg = "{\"type\":\"ble_status\",\"connected\":false,\"timestamp\":" + String(millis()) + "}";
      eventChar->setValue(msg.c_str());
      eventChar->notify();
    }

    // Restart advertising
    BLEAdvertising* pAdvertising = BLEDevice::getAdvertising();
    pAdvertising->start();
    Serial.println(F("BLE advertising restarted"));
  }
};

// ============================================
// WEBSOCKET HANDLERS
// ============================================
// No WebSocket - BLE GATT will handle config and events

// Helper: send event notification (JSON string) over BLE
void notifyEvent(const String &msg) {
  if (eventChar) {
    eventChar->setValue(msg.c_str());
    eventChar->notify();
  }
  Serial.println("Event: " + msg);
}

// No web UI - configuration and events are handled over BLE GATT characteristics

// ============================================
// WEB SERVER HANDLERS
// ============================================
// BLE Config write callback
class ConfigCallbacks : public BLECharacteristicCallbacks {
  void onWrite(BLECharacteristic* pChar) {
    std::string val = pChar->getValue();
    if (val.length() == 0) return;
    String body = String((char*)val.c_str());
    Serial.println(F("Received configuration (BLE):"));
    Serial.println(body);

    DynamicJsonDocument doc(1024);
    DeserializationError error = deserializeJson(doc, body);
    if (error) {
      Serial.print(F("JSON parse error: "));
      Serial.println(error.c_str());
      return;
    }

    if (doc.containsKey("buttons")) {
      JsonObject buttons = doc["buttons"];
      bool changed = false;

      auto validateAndAssign = [&](const char* key, int &target) {
        if (buttons.containsKey(key)) {
          int v = buttons[key] | 0;
          if (v >= 0 && v <= 4) {
            if (target != v) {
              target = v;
              changed = true;
            }
          } else {
            Serial.printf("Invalid value for %s: %d\n", key, v);
          }
        }
      };

      validateAndAssign("button1", button1Function);
      validateAndAssign("button2", button2Function);
      validateAndAssign("button3", button3Function);

      if (changed) {
        prefs.putInt("b1", button1Function);
        prefs.putInt("b2", button2Function);
        prefs.putInt("b3", button3Function);
      }

      Serial.printf("Configuration updated: Btn1=%d, Btn2=%d, Btn3=%d\n", 
                    button1Function, button2Function, button3Function);

      // Notify central of update
      if (statusChar) {
        String resp = "{\"status\":\"success\",\"message\":\"Configuration applied\"}";
        statusChar->setValue(resp.c_str());
        statusChar->notify();
      }
    }
  }
};

// ============================================
// BLE KEYBOARD FUNCTIONS
// ============================================
void sendKey(uint8_t modifiers, uint8_t key, int buttonNum, String action) {
  bool success = false;
  
  if (bleConnected) {
    // Press
    uint8_t msg[] = {modifiers, 0, key, 0, 0, 0, 0, 0};
    input->setValue(msg, sizeof(msg));
    input->notify();
    delay(100);
    
    // Release
    uint8_t msg2[] = {0, 0, 0, 0, 0, 0, 0, 0};
    input->setValue(msg2, sizeof(msg2));
    input->notify();
    delay(100);
    
    success = true;
  }
  
  // Broadcast to web clients
  String msg = "{\"type\":\"button_press\",\"button\":" + String(buttonNum) + 
               ",\"action\":\"" + action + 
               "\",\"modifier\":" + String(modifiers) + 
               ",\"key\":" + String(key) + 
               ",\"success\":" + String(success ? "true" : "false") + 
               ",\"timestamp\":" + String(millis()) + "}";
  webSocket.broadcastTXT(msg);
  
  // Serial output
  Serial.println("Button " + String(buttonNum) + ": " + action + 
                 " (Mod: 0x" + String(modifiers, HEX) + 
                 ", Key: 0x" + String(key, HEX) + ") " + 
                 (success ? "✅" : "❌"));
}

// Execute button function based on configuration
void executeFunction(int functionCode, int buttonNum) {
  String action = "";
  uint8_t modifier = 0;
  uint8_t key = 0;
  
  switch(functionCode) {
    case 0: // Left Click
      action = "Left Click";
      // No BLE action for clicks
      break;
    case 1: // Right Click
      action = "Right Click";
      // No BLE action for clicks
      break;
    case 2: // Double Click
      action = "Double Click";
      // No BLE action for clicks
      break;
    case 3: // Undo (Cmd+Z)
      action = "Undo (Cmd+Z)";
      modifier = KEY_LEFT_GUI;  // Use Left Command
      key = KEY_Z;
      break;
    case 4: // Redo (Cmd+Shift+Z)
      action = "Redo (Cmd+Shift+Z)";
      modifier = KEY_LEFT_GUI | KEY_LEFT_SHIFT;  // Left Command + Shift
      key = KEY_Z;
      break;
    default:
      action = "Unknown";
      break;
  }
  
  if (functionCode <= 2) {
    // For click functions, just log without sending BLE
    Serial.println("Button " + String(buttonNum) + ": " + action + " (no BLE action)");
    
    // Still broadcast to web clients
    String msg = "{\"type\":\"button_press\",\"button\":" + String(buttonNum) + 
                 ",\"action\":\"" + action + 
                 "\",\"modifier\":0,\"key\":0,\"success\":true,\"timestamp\":" + String(millis()) + "}";
    webSocket.broadcastTXT(msg);
  } else {
    // Send keyboard command
    sendKey(modifier, key, buttonNum, action);
  }
}

// ============================================
// SETUP
// ============================================
void setup() {
  Serial.begin(115200);
  delay(1000);
  
  startTime = millis();
  
  Serial.println(F("========================================"));
  Serial.println(F("ESP32 BLE Controller - Unified Version"));
  Serial.println(F("========================================"));
  
  // Setup pins
  pinMode(BUTTON1_PIN, INPUT_PULLUP);
  pinMode(BUTTON2_PIN, INPUT_PULLUP);
  pinMode(BUTTON3_PIN, INPUT_PULLUP);
  pinMode(LED_PIN, OUTPUT);
  
  // LED startup
  for (int i = 0; i < 2; i++) {
    digitalWrite(LED_PIN, HIGH);
    delay(200);
    digitalWrite(LED_PIN, LOW);
    delay(200);
  }
  
  // Connect to WiFi
  Serial.print(F("Connecting to WiFi: "));
  Serial.println(ssid);
  WiFi.mode(WIFI_STA);
  WiFi.begin(ssid, password);
  
  int attempts = 0;
  while (WiFi.status() != WL_CONNECTED && attempts < 20) {
    delay(500);
    Serial.print(".");
    attempts++;
  }
  
  if (WiFi.status() == WL_CONNECTED) {
    Serial.println(F("WiFi connected!"));
    Serial.print(F("Web Interface: http://"));
    Serial.println(WiFi.localIP().toString());
  } else {
    Serial.println(F("WiFi connection failed - continuing without WiFi"));
  }
  
  // Start web server
  server.on("/", handleRoot);
  server.on("/status", handleStatus);
  server.on("/config", HTTP_POST, handleConfig);
  server.on("/config", HTTP_OPTIONS, handleOptions);
  server.begin();
  Serial.println(F("Web server started"));

  // Initialize Preferences and load stored button config
  prefs.begin("cfg", false);
  button1Function = prefs.getInt("b1", button1Function);
  button2Function = prefs.getInt("b2", button2Function);
  button3Function = prefs.getInt("b3", button3Function);
  
  // Start WebSocket
  webSocket.begin();
  webSocket.onEvent(webSocketEvent);
  Serial.println(F("WebSocket server started"));
  
  // Initialize BLE
  Serial.println(F("Initializing BLE Keyboard..."));
  BLEDevice::init("XIAO Keyboard");
  
  BLEServer* pServer = BLEDevice::createServer();
  pServer->setCallbacks(new MyServerCallbacks());
  
  hid = new BLEHIDDevice(pServer);
  input = hid->inputReport(1);
  output = hid->outputReport(1);
  
  // Set manufacturer and device info
  hid->manufacturer()->setValue("MakerEasy");
  hid->pnp(0x01, 0x02e5, 0xabcd, 0x0110);
  hid->hidInfo(0x00, 0x01);
  
  // Security settings
  BLESecurity* pSecurity = new BLESecurity();
  pSecurity->setAuthenticationMode(ESP_LE_AUTH_BOND);
  
  // Set report map
  hid->reportMap((uint8_t*)reportMap, sizeof(reportMap));
  hid->startServices();
  
  // Advertising setup
  BLEAdvertising* pAdvertising = pServer->getAdvertising();
  pAdvertising->setAppearance(HID_KEYBOARD);
  pAdvertising->addServiceUUID(hid->hidService()->getUUID());
  pAdvertising->start();
  
  Serial.println(F("BLE Keyboard ready!"));
  Serial.println(F("Pair from iPad: Settings > Bluetooth > 'XIAO Keyboard'"));
  
  Serial.println(F("========================================"));
  Serial.println(F("SYSTEM READY!"));
  Serial.println(F("========================================"));
  Serial.printf("Button 1: Function %d\n", button1Function);
  Serial.printf("Button 2: Function %d\n", button2Function);
  Serial.printf("Button 3: Function %d\n", button3Function);
  Serial.println(F("========================================"));
}

// ============================================
// MAIN LOOP
// ============================================
void loop() {
  // Handle web server & WebSocket
  server.handleClient();
  webSocket.loop();
  
  // Read buttons
  bool btn1 = digitalRead(BUTTON1_PIN);
  bool btn2 = digitalRead(BUTTON2_PIN);
  bool btn3 = digitalRead(BUTTON3_PIN);
  
  unsigned long now = millis();
  
  // Button 1
  if (btn1 == LOW && lastBtn1 == HIGH && (now - lastDebounce) > 200) {
    lastDebounce = now;
    pressCount1++;
    executeFunction(button1Function, 1);
    
    digitalWrite(LED_PIN, HIGH);
    delay(100);
    digitalWrite(LED_PIN, LOW);
  }
  lastBtn1 = btn1;
  
  // Button 2
  if (btn2 == LOW && lastBtn2 == HIGH && (now - lastDebounce) > 200) {
    lastDebounce = now;
    pressCount2++;
    executeFunction(button2Function, 2);
    
    digitalWrite(LED_PIN, HIGH);
    delay(100);
    digitalWrite(LED_PIN, LOW);
  }
  lastBtn2 = btn2;
  
  // Button 3
  if (btn3 == LOW && lastBtn3 == HIGH && (now - lastDebounce) > 200) {
    lastDebounce = now;
    pressCount3++;
    executeFunction(button3Function, 3);
    
    digitalWrite(LED_PIN, HIGH);
    delay(50);
    digitalWrite(LED_PIN, LOW);
  }
  lastBtn3 = btn3;
  
  delay(10);
}