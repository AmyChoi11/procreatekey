// BLE keyboard with rotary encoder for Procreate brush size control

#include <BLEDevice.h>
#include <BLEUtils.h>
#include <BLEServer.h>
#include <BLE2902.h>
#include <BLEHIDDevice.h>

// Key codes
#define KEY_LEFT_GUI      0x08  // Command key on iOS
#define KEY_LEFT_SHIFT    0x02  // Shift key
#define KEY_Z             0x1D  // Z key
#define KEY_LEFT_BRACKET  0x2F  // [ key - decrease brush size
#define KEY_RIGHT_BRACKET 0x30  // ] key - increase brush size

// Pins
#define UNDO_PIN          4     // Keep existing undo button
#define REDO_PIN          5     // Keep existing redo button
#define ENCODER_PIN_A     7     // Rotary Encoder pin A (CLK)
#define ENCODER_PIN_B     6     // Rotary Encoder pin B (DT)
#define RESET_PIN         15    // Reset button to set brush to minimum

// Encoder settings
#define KEY_REPEAT_DELAY  50    // Delay between key presses in milliseconds

// Reset parameters
#define RESET_DELAY       2000  // How long to hold button to reset to minimum
#define RESET_PIN         15    // Optional reset button to set brush to minimum size

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

// Variables for rotary encoder control
volatile int encoderPos = 0;      // Current encoder position
volatile int lastEncoded = 0;     // Last encoder reading
int lastEncoderPos = 0;           // Last processed encoder position
unsigned long lastEncoderTime = 0;// Last time encoder position was changed

// Interrupt handler for encoder
void IRAM_ATTR handleEncoder() {
  // Read the current state of encoder pins
  int MSB = digitalRead(ENCODER_PIN_A);
  int LSB = digitalRead(ENCODER_PIN_B);
  
  // Convert the 2 pin values to a single number
  int encoded = (MSB << 1) | LSB;
  
  // Compare to the previous reading to determine direction
  int sum = (lastEncoded << 2) | encoded;
  
  // Clockwise (increment) is 0b1101 or 0b0100 or 0b0010 or 0b1011
  if(sum == 0b1101 || sum == 0b0100 || sum == 0b0010 || sum == 0b1011) {
    encoderPos++;
  }
  // Counter-clockwise (decrement) is 0b1110 or 0b0111 or 0b0001 or 0b1000
  else if(sum == 0b1110 || sum == 0b0111 || sum == 0b0001 || sum == 0b1000) {
    encoderPos--;
  }
  
  // Save this reading for the next comparison
  lastEncoded = encoded;
}
unsigned long lastKeyPressTime = 0;
unsigned long resetPressStartTime = 0;

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
  delay(20); // Reduced from 100ms
  
  // Release keys
  uint8_t msg2[] = {0, 0, 0, 0, 0, 0, 0, 0};
  inputKeyboard->setValue(msg2, sizeof(msg2));
  inputKeyboard->notify();
  
  Serial.println("Sent keyboard command");
}

// Function to send a single key without modifiers
void sendSingleKey(uint8_t key) {
  sendKeyCombo(0, key);  // No modifier, just the key
}

void setup() {
  // Start serial connection at standard baud rate
  Serial.begin(115200);
  delay(100);
  
  // Basic initialization message
  Serial.println("Starting ProcreateKey...");
  
  // Configure pins
  pinMode(UNDO_PIN, INPUT_PULLUP);
  pinMode(REDO_PIN, INPUT_PULLUP);
  pinMode(RESET_PIN, INPUT_PULLUP);
  
  // Configure rotary encoder pins with pull-up resistors
  pinMode(ENCODER_PIN_A, INPUT_PULLUP);
  pinMode(ENCODER_PIN_B, INPUT_PULLUP);
  
  // Attach interrupts for rotary encoder
  attachInterrupt(digitalPinToInterrupt(ENCODER_PIN_A), handleEncoder, CHANGE);
  attachInterrupt(digitalPinToInterrupt(ENCODER_PIN_B), handleEncoder, CHANGE);
  
  // Initialize BLE
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
  
  Serial.println("BLE Keyboard Ready - Press Buttons for Undo/Redo and turn potentiometer for brush size");
  
  // Initialize the encoder values
  encoderPos = 0;
  lastEncoderPos = 0;
  lastEncoded = 0;
  
  // Basic initialization complete
  Serial.println("Initialization complete.");
  Serial.println("Basic controls: Turn encoder for brush size, hold reset button to set minimum size.");
  
  // Wait for BLE to initialize
  delay(300);
}

void loop() {
  // No status messages needed - keeping code simple and focused
  
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
  
  // REDO functionality
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
  
  // Rotary encoder for brush size control
  if (connected) {
    // Check if encoder position has changed
    if (encoderPos != lastEncoderPos) {
      // Determine direction of rotation
      int direction = (encoderPos > lastEncoderPos) ? 1 : -1;
      
      // Update last position
      lastEncoderPos = encoderPos;
      
      // Process only if enough time has passed since last key press
      if (millis() - lastKeyPressTime > KEY_REPEAT_DELAY) {
        // Send appropriate key based on direction
        if (direction > 0) {
          sendSingleKey(KEY_RIGHT_BRACKET); // Increase brush size (clockwise turn)
        } else {
          sendSingleKey(KEY_LEFT_BRACKET); // Decrease brush size (counter-clockwise turn)
        }
        
        // Update last key press time
        lastKeyPressTime = millis();
      }
    }
    
    // Check if reset button is pressed
    if (digitalRead(RESET_PIN) == LOW) {
      if (resetPressStartTime == 0) {
        // Button just pressed, record the time
        resetPressStartTime = millis();
      } else if (millis() - resetPressStartTime > RESET_DELAY) {
        // Button held long enough, reset to minimum brush size
        Serial.println("Resetting to minimum brush size");
        
        // Send 30 decrease commands to ensure we reach minimum size
        for (int i = 0; i < 30; i++) {
          sendSingleKey(KEY_LEFT_BRACKET);
          delay(50);
        }
        
        resetPressStartTime = 0; // Reset timer
      }
    } else {
      // Button not pressed
      resetPressStartTime = 0;
    }
  }
  
  delay(5); // Reduced main loop delay
}