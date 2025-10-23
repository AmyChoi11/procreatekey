/*
 * XIAO ESP32-S3 BLE Keyboard with Rotary Encoder
 * Combined firmware: Configuration system + Rotary encoder control
 * 
 * Features:
 * - BLE HID keyboard for iPad/Procreate
 * - 3 configurable buttons via iOS app
 * - Rotary encoder with adaptive sensitivity (6 zones)
 * - Reset button to reset brush size
 * - Persistent configuration storage
 * - Custom GATT service for iOS app communication
 * 
 * Hardware:
 * - XIAO ESP32-S3
 * - 3 buttons on GPIO1, 3, 4
 * - Rotary encoder on GPIO6, 7
 * - Reset button on GPIO2
 * - Built-in LED on GPIO21
 */

#include <BLEDevice.h>
#include <BLEUtils.h>
#include <BLEServer.h>
#include <BLE2902.h>
#include <BLEHIDDevice.h>
#include <HIDKeyboardTypes.h>
#include <HIDTypes.h>
#include <Preferences.h>
#include <ArduinoJson.h>

// ============= Pin Definitions =============
#define BUTTON1_PIN 1  // D0
#define BUTTON2_PIN 3  // D2
#define BUTTON3_PIN 4  // D3
#define ENCODER_A   7  // D6
#define ENCODER_B   6  // D5
#define RESET_BTN   15  // D1
#define LED_PIN     2 // Built-in RGB LED

// ============= Encoder Settings =============
volatile long encoderPos = 0;
volatile int lastEncoded = 0;
volatile unsigned long lastEncoderTime = 0;
const unsigned long ENCODER_DEBOUNCE = 5;

// Adaptive sensitivity zones
int currentZone = 0;
int stepsInZone = 0;
const int STEPS_PER_ZONE = 10;

const int zoneSensitivity[] = {
  25,  // Zone 0: Extreme fine (25 clicks per step)
  15,  // Zone 1: Very fine
  8,   // Zone 2: Fine
  4,   // Zone 3: Medium
  2,   // Zone 4: Coarse
  1    // Zone 5: Very coarse
};

// ============= Button Configuration =============
struct ButtonConfig {
  int button1 = 3;  // Default: Undo
  int button2 = 3;  // Default: Undo
  int button3 = 7;  // Default: Color Palette
  int dial = 9;     // Default: Layers (though encoder controls brush size)
} config;

Preferences prefs;

// ============= BLE Objects =============
BLEServer* pServer = nullptr;
BLEHIDDevice* hid = nullptr;
BLECharacteristic* input = nullptr;
BLECharacteristic* output = nullptr;

// Custom GATT Service
#define SERVICE_UUID        "12345678-1234-5678-1234-56789abcdef0"
#define CHAR_UUID_CONFIG    "12345678-1234-5678-1234-56789abcdef1"
#define CHAR_UUID_EVENTS    "12345678-1234-5678-1234-56789abcdef2"
#define CHAR_UUID_STATUS    "12345678-1234-5678-1234-56789abcdef3"

BLECharacteristic* configChar = nullptr;
BLECharacteristic* eventsChar = nullptr;
BLECharacteristic* statusChar = nullptr;

bool deviceConnected = false;
bool oldDeviceConnected = false;

// ============= BLE Server Callbacks =============
class ServerCallbacks : public BLEServerCallbacks {
  void onConnect(BLEServer* pServer) {
    deviceConnected = true;
    Serial.println("BLE Client connected");
  }
  
  void onDisconnect(BLEServer* pServer) {
    deviceConnected = false;
    Serial.println("BLE Client disconnected");
    delay(500);
    pServer->startAdvertising();
    Serial.println("Advertising restarted");
  }
};

// ============= Config Characteristic Callbacks =============
class ConfigCallbacks : public BLECharacteristicCallbacks {
  void onWrite(BLECharacteristic* pChar) {
    std::string value = pChar->getValue();
    if (value.length() > 0) {
      Serial.println("Received config write:");
      Serial.println(value.c_str());
      
      DynamicJsonDocument doc(512);
      DeserializationError error = deserializeJson(doc, value);
      
      if (error) {
        Serial.print("JSON parse failed: ");
        Serial.println(error.c_str());
        statusChar->setValue("{\"status\":\"error\",\"message\":\"Invalid JSON\"}");
        statusChar->notify();
        return;
      }
      
      if (doc.containsKey("buttons")) {
        JsonObject buttons = doc["buttons"];
        
        // Proper JSON deserialization with .as<int>()
        config.button1 = buttons["button1"].as<int>();
        config.button2 = buttons["button2"].as<int>();
        config.button3 = buttons["button3"].as<int>();
        config.dial = buttons["dial"].as<int>();
        
        // Clamp values to valid range (0-11)
        config.button1 = constrain(config.button1, 0, 11);
        config.button2 = constrain(config.button2, 0, 11);
        config.button3 = constrain(config.button3, 0, 11);
        config.dial = constrain(config.dial, 0, 11);
        
        // Save to preferences
        prefs.begin("config", false);
        prefs.putInt("button1", config.button1);
        prefs.putInt("button2", config.button2);
        prefs.putInt("button3", config.button3);
        prefs.putInt("dial", config.dial);
        prefs.end();
        
        Serial.printf("Config saved: b1=%d b2=%d b3=%d dial=%d\n",
                     config.button1, config.button2, config.button3, config.dial);
        
        statusChar->setValue("{\"status\":\"success\",\"message\":\"Config saved\"}");
        statusChar->notify();
        
        // Blink LED to confirm
        for(int i=0; i<3; i++) {
          digitalWrite(LED_PIN, HIGH);
          delay(100);
          digitalWrite(LED_PIN, LOW);
          delay(100);
        }
      }
    }
  }
  
  void onRead(BLECharacteristic* pChar) {
    DynamicJsonDocument doc(256);
    JsonObject buttons = doc.createNestedObject("buttons");
    buttons["button1"] = config.button1;
    buttons["button2"] = config.button2;
    buttons["button3"] = config.button3;
    buttons["dial"] = config.dial;
    
    String output;
    serializeJson(doc, output);
    pChar->setValue(output.c_str());
    Serial.println("Config read requested, returning:");
    Serial.println(output);
  }
};

// ============= Function Code to Key Mapping =============
void sendFunctionKey(int functionCode) {
  uint8_t report[8] = {0};
  
  switch(functionCode) {
    case 3:  // Undo
      report[0] = 0x08; // Left Command
      report[2] = 0x1D; // 'z'
      break;
    case 4:  // Redo
      report[0] = 0x09; // Left Command + Shift
      report[2] = 0x1D; // 'z'
      break;
    case 5:  // Erase
      report[2] = 0x08; // 'e'
      break;
    case 6:  // Brush Size (not used by buttons, encoder handles this)
      report[2] = 0x2F; // '['
      break;
    case 7:  // Color Palette
      report[0] = 0x08; // Left Command
      report[2] = 0x06; // 'c'
      break;
    case 8:  // Brush Library
      report[0] = 0x08; // Left Command
      report[2] = 0x05; // 'b'
      break;
    case 9:  // Layers
      report[0] = 0x08; // Left Command
      report[2] = 0x0F; // 'l'
      break;
    case 10: // Pen Opacity
      report[0] = 0x08; // Left Command
      report[2] = 0x12; // 'o'
      break;
    case 11: // Brush Size (alternate)
      report[2] = 0x30; // ']'
      break;
    default:
      Serial.printf("Unknown function code: %d\n", functionCode);
      return;
  }
  
  if (input) {
    input->setValue(report, 8);
    input->notify();
    delay(10);
    
    // Release
    memset(report, 0, 8);
    input->setValue(report, 8);
    input->notify();
  }
}

// ============= Encoder Interrupt Handler =============
void IRAM_ATTR handleEncoder() {
  unsigned long currentTime = millis();
  if (currentTime - lastEncoderTime < ENCODER_DEBOUNCE) {
    return;
  }
  lastEncoderTime = currentTime;
  
  int MSB = digitalRead(ENCODER_A);
  int LSB = digitalRead(ENCODER_B);
  
  int encoded = (MSB << 1) | LSB;
  int sum = (lastEncoded << 2) | encoded;
  
  if (sum == 0b1101 || sum == 0b0100 || sum == 0b0010 || sum == 0b1011) {
    encoderPos++;
  }
  if (sum == 0b1110 || sum == 0b0111 || sum == 0b0001 || sum == 0b1000) {
    encoderPos--;
  }
  
  lastEncoded = encoded;
}

// ============= Update Brush Size Zone =============
void updateBrushZone(int direction) {
  stepsInZone++;
  
  if (stepsInZone >= STEPS_PER_ZONE) {
    if (direction > 0 && currentZone < 5) {
      currentZone++;
      stepsInZone = 0;
      Serial.printf("Zone increased to %d (sensitivity: %d clicks/step)\n", 
                   currentZone, zoneSensitivity[currentZone]);
    } else if (direction < 0 && currentZone > 0) {
      currentZone--;
      stepsInZone = 0;
      Serial.printf("Zone decreased to %d (sensitivity: %d clicks/step)\n", 
                   currentZone, zoneSensitivity[currentZone]);
    }
  }
}

// ============= Send Brush Size Key =============
void sendBrushKey(bool increase) {
  uint8_t report[8] = {0};
  report[2] = increase ? 0x30 : 0x2F; // ']' or '['
  
  if (input) {
    input->setValue(report, 8);
    input->notify();
    delay(10);
    
    memset(report, 0, 8);
    input->setValue(report, 8);
    input->notify();
  }
}

// ============= Setup =============
void setup() {
  Serial.begin(115200);
  delay(1000);
  
  Serial.println("========================================");
  Serial.println("XIAO ESP32-S3 BLE Keyboard + Encoder");
  Serial.println("========================================");
  Serial.println("Encoder sensitivity zones:");
  Serial.println("0=ExtremeFine(25clicks) 1=VeryFine(15) 2=Fine(8)");
  Serial.println("3=Medium(4) 4=Coarse(2) 5=VeryCoarse(1)");
  
  // Pin setup
  pinMode(BUTTON1_PIN, INPUT_PULLUP);
  pinMode(BUTTON2_PIN, INPUT_PULLUP);
  pinMode(BUTTON3_PIN, INPUT_PULLUP);
  pinMode(ENCODER_A, INPUT_PULLUP);
  pinMode(ENCODER_B, INPUT_PULLUP);
  pinMode(RESET_BTN, INPUT_PULLUP);
  pinMode(LED_PIN, OUTPUT);
  
  // Encoder interrupts
  attachInterrupt(digitalPinToInterrupt(ENCODER_A), handleEncoder, CHANGE);
  attachInterrupt(digitalPinToInterrupt(ENCODER_B), handleEncoder, CHANGE);
  
  // Load config from preferences
  prefs.begin("config", true);
  config.button1 = prefs.getInt("button1", 3);
  config.button2 = prefs.getInt("button2", 3);
  config.button3 = prefs.getInt("button3", 7);
  config.dial = prefs.getInt("dial", 9);
  prefs.end();
  
  Serial.printf("Loaded config from prefs: b1=%d b2=%d b3=%d dial=%d\n",
               config.button1, config.button2, config.button3, config.dial);
  
  // Initialize BLE
  BLEDevice::init("XIAO Keyboard");
  pServer = BLEDevice::createServer();
  pServer->setCallbacks(new ServerCallbacks());
  
  // Create HID Device
  hid = new BLEHIDDevice(pServer);
  input = hid->inputReport(1);
  output = hid->outputReport(1);
  
  // HID descriptor for keyboard
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
  
  hid->reportMap((uint8_t*)reportMap, sizeof(reportMap));
  hid->startServices();
  
  // Create custom GATT service for iOS app
  BLEService* customService = pServer->createService(SERVICE_UUID);
  
  configChar = customService->createCharacteristic(
    CHAR_UUID_CONFIG,
    BLECharacteristic::PROPERTY_READ | BLECharacteristic::PROPERTY_WRITE
  );
  configChar->setCallbacks(new ConfigCallbacks());
  configChar->addDescriptor(new BLE2902());
  
  eventsChar = customService->createCharacteristic(
    CHAR_UUID_EVENTS,
    BLECharacteristic::PROPERTY_NOTIFY
  );
  eventsChar->addDescriptor(new BLE2902());
  
  statusChar = customService->createCharacteristic(
    CHAR_UUID_STATUS,
    BLECharacteristic::PROPERTY_NOTIFY
  );
  statusChar->addDescriptor(new BLE2902());
  
  customService->start();
  
  // Start advertising
  BLEAdvertising* pAdvertising = BLEDevice::getAdvertising();
  pAdvertising->setAppearance(0x03C1); // Keyboard appearance
  pAdvertising->addServiceUUID(hid->hidService()->getUUID());
  pAdvertising->addServiceUUID(SERVICE_UUID);
  pAdvertising->start();
  
  hid->setBatteryLevel(100);
  
  Serial.println("BLE HID + GATT ready. Pair as 'XIAO Keyboard' or use app to configure.");
  Serial.printf("Button functions: b1=%d b2=%d b3=%d dial=%d\n",
               config.button1, config.button2, config.button3, config.dial);
  
  // LED startup sequence
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
static int lastDirection = 0;

void loop() {
  // Handle encoder rotation
  long currentPos = encoderPos;
  if (currentPos != lastEncoderPos) {
    long diff = currentPos - lastEncoderPos;
    int sensitivity = zoneSensitivity[currentZone];
    
    if (abs(diff) >= sensitivity) {
      int direction = (diff > 0) ? 1 : -1;
      sendBrushKey(direction > 0);
      
      // Update zone if moving in same direction
      if (direction == lastDirection) {
        updateBrushZone(direction);
      } else {
        stepsInZone = 0;
        lastDirection = direction;
      }
      
      lastEncoderPos = currentPos;
      Serial.printf("Brush %s (zone %d)\n", direction > 0 ? "+" : "-", currentZone);
    }
  }
  
  // Handle reset button (hold for 2 seconds)
  if (digitalRead(RESET_BTN) == LOW) {
    if (!resetPressed) {
      resetPressed = true;
      resetPressTime = millis();
    } else if (millis() - resetPressTime > 2000) {
      // Reset brush size
      Serial.println("Reset brush size to minimum");
      currentZone = 0;
      stepsInZone = 0;
      encoderPos = 0;
      lastEncoderPos = 0;
      
      // Blink rapidly
      for(int i=0; i<5; i++) {
        digitalWrite(LED_PIN, HIGH);
        delay(50);
        digitalWrite(LED_PIN, LOW);
        delay(50);
      }
      
      resetPressed = false; // Prevent repeat
      delay(500);
    }
  } else {
    resetPressed = false;
  }
  
  // Handle button 1
  if (digitalRead(BUTTON1_PIN) == LOW && !button1Pressed) {
    button1Pressed = true;
    Serial.printf("Button 1 pressed (function %d)\n", config.button1);
    sendFunctionKey(config.button1);
    
    digitalWrite(LED_PIN, HIGH);
    delay(50);
    digitalWrite(LED_PIN, LOW);
    
    if (eventsChar && deviceConnected) {
      String event = "{\"button\":1,\"function\":" + String(config.button1) + "}";
      eventsChar->setValue(event.c_str());
      eventsChar->notify();
    }
  } else if (digitalRead(BUTTON1_PIN) == HIGH) {
    button1Pressed = false;
  }
  
  // Handle button 2
  if (digitalRead(BUTTON2_PIN) == LOW && !button2Pressed) {
    button2Pressed = true;
    Serial.printf("Button 2 pressed (function %d)\n", config.button2);
    sendFunctionKey(config.button2);
    
    digitalWrite(LED_PIN, HIGH);
    delay(50);
    digitalWrite(LED_PIN, LOW);
    
    if (eventsChar && deviceConnected) {
      String event = "{\"button\":2,\"function\":" + String(config.button2) + "}";
      eventsChar->setValue(event.c_str());
      eventsChar->notify();
    }
  } else if (digitalRead(BUTTON2_PIN) == HIGH) {
    button2Pressed = false;
  }
  
  // Handle button 3
  if (digitalRead(BUTTON3_PIN) == LOW && !button3Pressed) {
    button3Pressed = true;
    Serial.printf("Button 3 pressed (function %d)\n", config.button3);
    sendFunctionKey(config.button3);
    
    digitalWrite(LED_PIN, HIGH);
    delay(50);
    digitalWrite(LED_PIN, LOW);
    
    if (eventsChar && deviceConnected) {
      String event = "{\"button\":3,\"function\":" + String(config.button3) + "}";
      eventsChar->setValue(event.c_str());
      eventsChar->notify();
    }
  } else if (digitalRead(BUTTON3_PIN) == HIGH) {
    button3Pressed = false;
  }
  
  // Handle BLE connection state changes
  if (deviceConnected && !oldDeviceConnected) {
    oldDeviceConnected = deviceConnected;
    Serial.println("Device connected via HID");
  }
  
  if (!deviceConnected && oldDeviceConnected) {
    delay(500);
    pServer->startAdvertising();
    Serial.println("Disconnected, restarting advertising");
    oldDeviceConnected = deviceConnected;
  }
  
  delay(10);
}
