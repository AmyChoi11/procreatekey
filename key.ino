// Simple BLE keyboard example for Procreate undo/redo buttons

#include <BLEDevice.h>
#include <BLEUtils.h>
#include <BLEServer.h>
#include <BLE2902.h>
#include <BLEHIDDevice.h>

// Key codes
#define KEY_LEFT_GUI  0x08  // Command key on iOS
#define KEY_LEFT_SHIFT 0x02 // Shift key
#define KEY_Z         0x1D  // Z key

// Pins
#define UNDO_PIN 4
#define REDO_PIN 5  // Change this to your preferred GPIO

// HID Report Map for keyboard - UNCHANGED from original
static const uint8_t hidReportMap[] = {
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

BLEHIDDevice* hid;
BLECharacteristic* inputKeyboard;
bool connected = false;

class ServerCallbacks : public BLEServerCallbacks {
  void onConnect(BLEServer* server) {
    connected = true;
    Serial.println("Connected");
  }
  
  void onDisconnect(BLEServer* server) {
    connected = false;
    Serial.println("Disconnected");
    server->startAdvertising();
  }
};

void sendKeyCombo(uint8_t mod, uint8_t key) {
  if (!connected) return;
  
  // Press keys
  uint8_t msg[] = {mod, 0, key, 0, 0, 0, 0, 0};
  inputKeyboard->setValue(msg, sizeof(msg));
  inputKeyboard->notify();
  delay(100);
  
  // Release keys
  uint8_t msg2[] = {0, 0, 0, 0, 0, 0, 0, 0};
  inputKeyboard->setValue(msg2, sizeof(msg2));
  inputKeyboard->notify();
  
  Serial.println("Sent keyboard command");
}

void setup() {
  Serial.begin(115200);
  
  // Configure button pins
  pinMode(UNDO_PIN, INPUT_PULLUP);
  pinMode(REDO_PIN, INPUT_PULLUP); // Add second button
  
  // Initialize BLE - UNCHANGED from original
  BLEDevice::init("ProcreateKey");
  BLEServer* server = BLEDevice::createServer();
  server->setCallbacks(new ServerCallbacks());
  
  // Set up security for iOS compatibility
  BLESecurity* security = new BLESecurity();
  security->setAuthenticationMode(ESP_LE_AUTH_BOND);
  security->setCapability(ESP_IO_CAP_NONE);
  security->setInitEncryptionKey(ESP_BLE_ENC_KEY_MASK | ESP_BLE_ID_KEY_MASK);
  
  // Create HID device
  hid = new BLEHIDDevice(server);
  inputKeyboard = hid->inputReport(1); // Report ID 1
  
  // Set manufacturer and device info
  hid->manufacturer()->setValue("ESP32");
  hid->pnp(0x02, 0xe502, 0xa111, 0x0210);
  hid->hidInfo(0x00, 0x01);
  
  // Set HID report map
  hid->reportMap((uint8_t*)hidReportMap, sizeof(hidReportMap));
  hid->startServices();
  
  // Advertising
  BLEAdvertising* advertising = server->getAdvertising();
  advertising->setAppearance(HID_KEYBOARD);
  advertising->addServiceUUID(hid->hidService()->getUUID());
  advertising->start();
  
  Serial.println("BLE Keyboard Ready - Press Buttons for Undo/Redo");
}

void loop() {
  // Original UNDO functionality
  if(digitalRead(UNDO_PIN) == LOW) {
    if(connected) {
      Serial.println("Undo button pressed - sending Command+Z");
      sendKeyCombo(KEY_LEFT_GUI, KEY_Z);
      delay(300);
    } else {
      Serial.println("Not connected");
    }
    
    // Debounce
    while(digitalRead(UNDO_PIN) == LOW) {
      delay(10);
    }
  }
  
  // New REDO functionality
  if(digitalRead(REDO_PIN) == LOW) {
    if(connected) {
      Serial.println("Redo button pressed - sending Command+Shift+Z");
      sendKeyCombo(KEY_LEFT_GUI | KEY_LEFT_SHIFT, KEY_Z);
      delay(300);
    } else {
      Serial.println("Not connected");
    }
    
    // Debounce
    while(digitalRead(REDO_PIN) == LOW) {
      delay(10);
    }
  }
  
  delay(10);
}