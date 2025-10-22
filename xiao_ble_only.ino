// XIAO ESP32-S3 BLE-only Keyboard
// BLE HID keyboard + custom GATT for config/events/status
// This file is a BLE-only replacement for the WiFi + Web UI sketch.

#include <Arduino.h>
#include <BLEDevice.h>
#include <BLEUtils.h>
#include <BLEServer.h>
#include <BLE2902.h>
#include <BLEHIDDevice.h>
#include <ArduinoJson.h>
#include <Preferences.h>

// ============================================
// CONFIGURATION
// ============================================
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

// BLE custom service/characteristic UUIDs (change if needed)
static BLEUUID CUSTOM_SERVICE_UUID("12345678-1234-5678-1234-56789abcdef0");
static BLEUUID CONFIG_CHAR_UUID("12345678-1234-5678-1234-56789abcdef1");
static BLEUUID EVENT_CHAR_UUID("12345678-1234-5678-1234-56789abcdef2");
static BLEUUID STATUS_CHAR_UUID("12345678-1234-5678-1234-56789abcdef3");

// ============================================
// GLOBALS
// ============================================
int button1Function = 3; // Default: Undo
int button2Function = 3; // Default: Undo
int button3Function = 7; // Default: Color Palette
int dialFunction = 9;    // Default: Layers

bool lastBtn1 = HIGH;
bool lastBtn2 = HIGH;
bool lastBtn3 = HIGH;
unsigned long lastDebounce = 0;

// HID
BLEHIDDevice* hid;
BLECharacteristic* input; // HID input report
BLECharacteristic* output; // HID output report
bool bleConnected = false;

// GATT
BLECharacteristic* configChar;
BLECharacteristic* eventChar;
BLECharacteristic* statusChar;

// Preferences
Preferences prefs;

// Stats
unsigned long pressCount1 = 0;
unsigned long pressCount2 = 0;
unsigned long pressCount3 = 0;
unsigned long startTime = 0;
unsigned long lastAdvRestart = 0;

// HID report descriptor
static const uint8_t reportMap[] PROGMEM = {
  0x05, 0x01,
  0x09, 0x06,
  0xA1, 0x01,
  0x85, 0x01,

  // Modifiers
  0x05, 0x07,
  0x19, 0xE0,
  0x29, 0xE7,
  0x15, 0x00,
  0x25, 0x01,
  0x75, 0x01,
  0x95, 0x08,
  0x81, 0x02,

  // Reserved
  0x95, 0x01,
  0x75, 0x08,
  0x81, 0x01,

  // Keys
  0x95, 0x06,
  0x75, 0x08,
  0x15, 0x00,
  0x25, 0x65,
  0x05, 0x07,
  0x19, 0x00,
  0x29, 0x65,
  0x81, 0x00,

  0xC0
};

// Forward
void notifyEvent(const String &msg);
void executeFunction(int functionCode, int buttonNum);

// ============================================
// BLE CALLBACKS
// ============================================
class MyServerCallbacks : public BLEServerCallbacks {
  void onConnect(BLEServer* pServer) {
    bleConnected = true;
    Serial.println(F("BLE central connected"));
    // notify central
    if (eventChar) {
      String m = "{\"type\":\"ble_status\",\"connected\":true,\"timestamp\":" + String(millis()) + "}";
      eventChar->setValue(m.c_str());
      eventChar->notify();
    }

    // LED feedback
    for (int i = 0; i < 2; i++) {
      digitalWrite(LED_PIN, HIGH);
      delay(100);
      digitalWrite(LED_PIN, LOW);
      delay(100);
    }
  }

  void onDisconnect(BLEServer* pServer) {
    bleConnected = false;
    Serial.println(F("BLE central disconnected"));
    // notify central (best-effort - if disconnected it won't be received)
    if (eventChar) {
      String m = "{\"type\":\"ble_status\",\"connected\":false,\"timestamp\":" + String(millis()) + "}";
      eventChar->setValue(m.c_str());
      eventChar->notify();
    }
    // restart advertising
    BLEDevice::startAdvertising();
  }
};

// Config write handler
class ConfigCallbacks : public BLECharacteristicCallbacks {
  void onRead(BLECharacteristic* pChar) {
    // Send current configuration when read - include all 4 buttons
    String config = "{\"buttons\":{\"button1\":" + String(button1Function) + 
                    ",\"button2\":" + String(button2Function) + 
                    ",\"button3\":" + String(button3Function) + 
                    ",\"dial\":" + String(dialFunction) + "}}";
    pChar->setValue(config.c_str());
    Serial.println("Config read request - sent: " + config);
  }

  void onWrite(BLECharacteristic* pChar) {
    std::string val = pChar->getValue();
    if (val.length() == 0) return;
    String body = String((char*)val.c_str());
    Serial.println(F("Received configuration via BLE:"));
    Serial.println(body);
    DynamicJsonDocument doc(1024);
    DeserializationError err = deserializeJson(doc, body);
    if (err) {
      Serial.print(F("JSON parse error: "));
      Serial.println(err.c_str());
      if (statusChar) {
        String r = "{\"status\":\"error\",\"message\":\"JSON parse failed\"}";
        statusChar->setValue(r.c_str());
        statusChar->notify();
      }
      return;
    }

    // Always attempt to write received values to Preferences and report back
    if (doc.containsKey("buttons")) {
      JsonObject buttons = doc["buttons"];

      int newB1 = button1Function;
      int newB2 = button2Function;
      int newB3 = button3Function;
      int newDial = dialFunction;

      // Fix: properly cast to int (the | 0 was doing nothing useful)
      if (buttons.containsKey("button1")) newB1 = buttons["button1"].as<int>();
      if (buttons.containsKey("button2")) newB2 = buttons["button2"].as<int>();
      if (buttons.containsKey("button3")) newB3 = buttons["button3"].as<int>();
      if (buttons.containsKey("dial")) newDial = buttons["dial"].as<int>();

      Serial.printf("About to save prefs - before: b1=%d b2=%d b3=%d dial=%d\n", 
                    button1Function, button2Function, button3Function, dialFunction);
      Serial.printf("New values received - b1=%d b2=%d b3=%d dial=%d\n", 
                    newB1, newB2, newB3, newDial);

      // Validate and clamp values (expanded range for dial functions)
      auto clamp = [](int v) { 
        if (v < 0) return 0; 
        if (v > 11) return 11;  // Support codes up to 11
        return v; 
      };
      newB1 = clamp(newB1);
      newB2 = clamp(newB2);
      newB3 = clamp(newB3);
      newDial = clamp(newDial);

      // Force write to preferences - add dial support
      prefs.putInt("b1", newB1);
      prefs.putInt("b2", newB2);
      prefs.putInt("b3", newB3);
      prefs.putInt("dial", newDial);

      // Read back immediately to verify
      int savedB1 = prefs.getInt("b1", -1);
      int savedB2 = prefs.getInt("b2", -1);
      int savedB3 = prefs.getInt("b3", -1);
      int savedDial = prefs.getInt("dial", -1);

      // Update runtime variables
      button1Function = savedB1 >= 0 ? savedB1 : newB1;
      button2Function = savedB2 >= 0 ? savedB2 : newB2;
      button3Function = savedB3 >= 0 ? savedB3 : newB3;
      dialFunction = savedDial >= 0 ? savedDial : newDial;

      Serial.printf("Prefs saved: b1=%d b2=%d b3=%d dial=%d\n", 
                    button1Function, button2Function, button3Function, dialFunction);

      if (statusChar) {
        String r = "{\"status\":\"success\",\"message\":\"Configuration applied and saved\"}";
        statusChar->setValue(r.c_str());
        statusChar->notify();
      }
    }
  }
};

// ============================================
// GATT helpers
// ============================================
void notifyEvent(const String &msg) {
  if (eventChar) {
    eventChar->setValue(msg.c_str());
    eventChar->notify();
  }
  Serial.println("Event: " + msg);
}

// ============================================
// BUTTON / HID logic
// ============================================
void sendKey(uint8_t modifiers, uint8_t key, int buttonNum, String action) {
  bool success = false;
  if (bleConnected && input) {
    uint8_t report[] = {modifiers, 0, key, 0, 0, 0, 0, 0};
    input->setValue(report, sizeof(report));
    input->notify();
    delay(60);
    uint8_t release[] = {0,0,0,0,0,0,0,0};
    input->setValue(release, sizeof(release));
    input->notify();
    delay(30);
    success = true;
  }

  String msg = "{\"type\":\"button_press\",\"button\":" + String(buttonNum) +
               ",\"action\":\"" + action + "\",\"modifier\":" + String(modifiers) +
               ",\"key\":" + String(key) + ",\"success\":" + String(success ? "true" : "false") +
               ",\"timestamp\":" + String(millis()) + "}";
  notifyEvent(msg);
  Serial.println("Button " + String(buttonNum) + ": " + action + (success ? " (sent)" : " (not sent)"));
}

void executeFunction(int functionCode, int buttonNum) {
  String action = "";
  uint8_t modifier = 0;
  uint8_t key = 0;
  switch(functionCode) {
    case 0:
      action = "Left Click";
      break;
    case 1:
      action = "Right Click";
      break;
    case 2:
      action = "Double Click";
      break;
    case 3:
      action = "Undo (Cmd+Z)";
      modifier = KEY_LEFT_GUI;
      key = KEY_Z;
      break;
    case 4:
      action = "Redo (Cmd+Shift+Z)";
      modifier = KEY_LEFT_GUI | KEY_LEFT_SHIFT;
      key = KEY_Z;
      break;
    default:
      action = "Unknown";
      break;
  }

  if (functionCode <= 2) {
    Serial.println("Button " + String(buttonNum) + ": " + action + " (no HID)");
    String msg = "{\"type\":\"button_press\",\"button\":" + String(buttonNum) +
                 ",\"action\":\"" + action + "\",\"modifier\":0,\"key\":0,\"success\":true,\"timestamp\":" + String(millis()) + "}";
    notifyEvent(msg);
  } else {
    sendKey(modifier, key, buttonNum, action);
  }
}

// ============================================
// SETUP
// ============================================
void setup() {
  Serial.begin(115200);
  delay(200);
  startTime = millis();

  Serial.println(F("========================================"));
  Serial.println(F("XIAO ESP32-S3 BLE-only Keyboard"));
  Serial.println(F("========================================"));

  pinMode(BUTTON1_PIN, INPUT_PULLUP);
  pinMode(BUTTON2_PIN, INPUT_PULLUP);
  pinMode(BUTTON3_PIN, INPUT_PULLUP);
  pinMode(LED_PIN, OUTPUT);

  // LED blink
  for (int i = 0; i < 2; i++) { digitalWrite(LED_PIN, HIGH); delay(150); digitalWrite(LED_PIN, LOW); delay(150); }

  // Preferences
  prefs.begin("cfg", false);
  button1Function = prefs.getInt("b1", button1Function);
  button2Function = prefs.getInt("b2", button2Function);
  button3Function = prefs.getInt("b3", button3Function);
  dialFunction = prefs.getInt("dial", dialFunction);

  Serial.printf("Loaded config from prefs: b1=%d b2=%d b3=%d dial=%d\n", 
                button1Function, button2Function, button3Function, dialFunction);

  // Initialize BLE
  BLEDevice::init("XIAO Keyboard");
  BLEServer* pServer = BLEDevice::createServer();
  pServer->setCallbacks(new MyServerCallbacks());

  // HID
  hid = new BLEHIDDevice(pServer);
  input = hid->inputReport(1);
  output = hid->outputReport(1);
  hid->manufacturer()->setValue("MakerEasy");
  hid->pnp(0x01, 0x02e5, 0xabcd, 0x0110);
  hid->hidInfo(0x00, 0x01);

  BLESecurity* pSecurity = new BLESecurity();
  pSecurity->setAuthenticationMode(ESP_LE_AUTH_BOND);

  hid->reportMap((uint8_t*)reportMap, sizeof(reportMap));
  hid->startServices();

  // Custom GATT service
  BLEService* customService = pServer->createService(CUSTOM_SERVICE_UUID);

  configChar = customService->createCharacteristic(CONFIG_CHAR_UUID, 
    BLECharacteristic::PROPERTY_READ | BLECharacteristic::PROPERTY_WRITE);
  configChar->setCallbacks(new ConfigCallbacks());

  eventChar = customService->createCharacteristic(EVENT_CHAR_UUID, BLECharacteristic::PROPERTY_NOTIFY);
  eventChar->addDescriptor(new BLE2902());

  statusChar = customService->createCharacteristic(STATUS_CHAR_UUID, BLECharacteristic::PROPERTY_READ | BLECharacteristic::PROPERTY_NOTIFY);
  statusChar->addDescriptor(new BLE2902());

  customService->start();

  // Advertising (HID + custom)
  BLEAdvertising* pAdvertising = pServer->getAdvertising();
  pAdvertising->setAppearance(HID_KEYBOARD);
  pAdvertising->addServiceUUID(hid->hidService()->getUUID());
  pAdvertising->addServiceUUID(customService->getUUID());
  pAdvertising->start();

  Serial.println(F("BLE HID + GATT ready. Pair as 'XIAO Keyboard' or use a GATT client to configure."));
  Serial.printf("Button functions: b1=%d b2=%d b3=%d dial=%d\n", 
                button1Function, button2Function, button3Function, dialFunction);
}

// ============================================
// MAIN LOOP
// ============================================
void loop() {
  // Read buttons
  bool btn1 = digitalRead(BUTTON1_PIN);
  bool btn2 = digitalRead(BUTTON2_PIN);
  bool btn3 = digitalRead(BUTTON3_PIN);
  unsigned long now = millis();

  if (btn1 == LOW && lastBtn1 == HIGH && (now - lastDebounce) > 200) {
    lastDebounce = now;
    pressCount1++;
    executeFunction(button1Function, 1);
    digitalWrite(LED_PIN, HIGH); delay(80); digitalWrite(LED_PIN, LOW);
  }
  lastBtn1 = btn1;

  if (btn2 == LOW && lastBtn2 == HIGH && (now - lastDebounce) > 200) {
    lastDebounce = now;
    pressCount2++;
    executeFunction(button2Function, 2);
    digitalWrite(LED_PIN, HIGH); delay(80); digitalWrite(LED_PIN, LOW);
  }
  lastBtn2 = btn2;

  if (btn3 == LOW && lastBtn3 == HIGH && (now - lastDebounce) > 200) {
    lastDebounce = now;
    pressCount3++;
    executeFunction(button3Function, 3);
    digitalWrite(LED_PIN, HIGH); delay(40); digitalWrite(LED_PIN, LOW);
  }
  lastBtn3 = btn3;

  delay(10);

  // Keep advertising alive in case host OS auto-connects the HID and
  // the device becomes non-discoverable. When not connected, periodically
  // restart advertising so Web Bluetooth scanners can find the device
  if (!bleConnected) {
    unsigned long now = millis();
    if (now - lastAdvRestart > 5000) { // every 5 seconds
      Serial.println("Restarting advertising to remain discoverable...");
      BLEDevice::startAdvertising();
      lastAdvRestart = now;
    }
  }
}
