// Dramatically improved sensitivity control for Procreate brush size
#include <BLEDevice.h>
#include <BLEUtils.h>
#include <BLEServer.h>
#include <BLE2902.h>
#include <BLEHIDDevice.h>

// Key codes
#define KEY_LEFT_GUI      0x08
#define KEY_LEFT_SHIFT    0x02
#define KEY_Z             0x1D
#define KEY_LEFT_BRACKET  0x2F
#define KEY_RIGHT_BRACKET 0x30

// Pins
#define UNDO_PIN          4
#define REDO_PIN          5
#define ENCODER_PIN_A     7
#define ENCODER_PIN_B     6
#define RESET_PIN         15

// Encoder settings
#define KEY_REPEAT_DELAY  50
#define RESET_DELAY       2000

// DRAMATICALLY DIFFERENT SENSITIVITY LEVELS
#define EXTREME_FINE_RANGE     25    // 25 clicks for 1 brush step (1-3%)
#define VERY_FINE_RANGE        15    // 15 clicks for 1 brush step (4-8%)
#define FINE_RANGE             8     // 8 clicks for 1 brush step (9-15%)
#define MEDIUM_RANGE           4     // 4 clicks for 1 brush step (16-30%)
#define COARSE_RANGE           2     // 2 clicks for 1 brush step (31-60%)
#define VERY_COARSE_RANGE      1     // 1 click for 1 brush step (61-100%)

#define ZONE_CHANGE_THRESHOLD  10    // Number of brush steps before changing zone

// HID Report Map
static const uint8_t hidReportMap[] = {
  0x05, 0x01, 0x09, 0x06, 0xA1, 0x01, 0x85, 0x01, 0x05, 0x07, 0x19, 0xE0, 0x29, 0xE7, 0x15, 0x00,
  0x25, 0x01, 0x75, 0x01, 0x95, 0x08, 0x81, 0x02, 0x95, 0x01, 0x75, 0x08, 0x81, 0x01, 0x95, 0x06,
  0x75, 0x08, 0x15, 0x00, 0x25, 0x65, 0x05, 0x07, 0x19, 0x00, 0x29, 0x65, 0x81, 0x00, 0xC0
};

BLEHIDDevice* hid;
BLECharacteristic* inputKeyboard;
bool connected = false;

// Encoder variables
volatile int encoderPos = 0;
volatile int lastEncoded = 0;
int lastEncoderPos = 0;

// Brush control variables
int brushSizeZone = 0; // 0=extreme fine, 1=very fine, 2=fine, 3=medium, 4=coarse, 5=very coarse
int clickCounter = 0;
int brushStepCounter = 0; // Tracks how many brush steps we've taken in current zone

unsigned long lastKeyPressTime = 0;
unsigned long resetPressStartTime = 0;

// Interrupt handler for encoder
void IRAM_ATTR handleEncoder() {
  int MSB = digitalRead(ENCODER_PIN_A);
  int LSB = digitalRead(ENCODER_PIN_B);
  int encoded = (MSB << 1) | LSB;
  int sum = (lastEncoded << 2) | encoded;
  
  if(sum == 0b1101 || sum == 0b0100 || sum == 0b0010 || sum == 0b1011) {
    encoderPos++;
  }
  else if(sum == 0b1110 || sum == 0b0111 || sum == 0b0001 || sum == 0b1000) {
    encoderPos--;
  }
  
  lastEncoded = encoded;
}

class ServerCallbacks : public BLEServerCallbacks {
  void onConnect(BLEServer* server) { connected = true; Serial.println("Connected"); }
  void onDisconnect(BLEServer* server) { connected = false; Serial.println("Disconnected"); server->startAdvertising(); }
};

void sendKeyCombo(uint8_t mod, uint8_t key) {
  if (!connected) return;
  
  uint8_t msg[] = {mod, 0, key, 0, 0, 0, 0, 0};
  inputKeyboard->setValue(msg, sizeof(msg));
  inputKeyboard->notify();
  delay(20);
  
  uint8_t msg2[] = {0, 0, 0, 0, 0, 0, 0, 0};
  inputKeyboard->setValue(msg2, sizeof(msg2));
  inputKeyboard->notify();
}

void sendSingleKey(uint8_t key) {
  sendKeyCombo(0, key);
}

// Get required clicks based on current zone
int getRequiredClicks() {
  switch(brushSizeZone) {
    case 0: return EXTREME_FINE_RANGE;    // 1-3%
    case 1: return VERY_FINE_RANGE;       // 4-8%
    case 2: return FINE_RANGE;            // 9-15%
    case 3: return MEDIUM_RANGE;          // 16-30%
    case 4: return COARSE_RANGE;          // 31-60%
    case 5: return VERY_COARSE_RANGE;     // 61-100%
    default: return VERY_COARSE_RANGE;
  }
}

// Update zone based on direction and current step count
void updateBrushZone(int direction) {
  brushStepCounter += direction;
  
  // Change zone if we've taken enough steps in current direction
  if (abs(brushStepCounter) >= ZONE_CHANGE_THRESHOLD) {
    if (direction > 0) {
      brushSizeZone = min(brushSizeZone + 1, 5); // Move to coarser control
    } else {
      brushSizeZone = max(brushSizeZone - 1, 0); // Move to finer control
    }
    brushStepCounter = 0;
    
    Serial.print("Changed to zone: ");
    Serial.println(brushSizeZone);
  }
}

void setup() {
  Serial.begin(115200);
  delay(100);
  
  Serial.println("Starting Ultra-Precise ProcreateKey...");
  Serial.println("Sensitivity zones: 0=ExtremeFine(25clicks) 1=VeryFine(15) 2=Fine(8) 3=Medium(4) 4=Coarse(2) 5=VeryCoarse(1)");
  
  pinMode(UNDO_PIN, INPUT_PULLUP);
  pinMode(REDO_PIN, INPUT_PULLUP);
  pinMode(RESET_PIN, INPUT_PULLUP);
  pinMode(ENCODER_PIN_A, INPUT_PULLUP);
  pinMode(ENCODER_PIN_B, INPUT_PULLUP);
  
  attachInterrupt(digitalPinToInterrupt(ENCODER_PIN_A), handleEncoder, CHANGE);
  attachInterrupt(digitalPinToInterrupt(ENCODER_PIN_B), handleEncoder, CHANGE);
  
  BLEDevice::init("ProcreateKey");
  BLEServer* server = BLEDevice::createServer();
  server->setCallbacks(new ServerCallbacks());
  
  BLESecurity* security = new BLESecurity();
  security->setAuthenticationMode(ESP_LE_AUTH_BOND);
  security->setCapability(ESP_IO_CAP_NONE);
  security->setInitEncryptionKey(ESP_BLE_ENC_KEY_MASK | ESP_BLE_ID_KEY_MASK);
  
  hid = new BLEHIDDevice(server);
  inputKeyboard = hid->inputReport(1);
  
  hid->manufacturer()->setValue("ESP32");
  hid->pnp(0x02, 0xe502, 0xa111, 0x0210);
  hid->hidInfo(0x00, 0x01);
  hid->reportMap((uint8_t*)hidReportMap, sizeof(hidReportMap));
  hid->startServices();
  
  BLEAdvertising* advertising = server->getAdvertising();
  advertising->setAppearance(HID_KEYBOARD);
  advertising->addServiceUUID(hid->hidService()->getUUID());
  advertising->start();
}

void loop() {
  // Handle undo/redo buttons
  if(digitalRead(UNDO_PIN) == LOW) {
    if(connected) { sendKeyCombo(KEY_LEFT_GUI, KEY_Z); delay(300); }
    while(digitalRead(UNDO_PIN) == LOW) delay(10);
  }
  
  if(digitalRead(REDO_PIN) == LOW) {
    if(connected) { sendKeyCombo(KEY_LEFT_GUI | KEY_LEFT_SHIFT, KEY_Z); delay(300); }
    while(digitalRead(REDO_PIN) == LOW) delay(10);
  }
  
  // Handle brush size control
  if (connected && encoderPos != lastEncoderPos) {
    int direction = (encoderPos > lastEncoderPos) ? 1 : -1;
    lastEncoderPos = encoderPos;
    
    int requiredClicks = getRequiredClicks();
    clickCounter += direction;
    
    // Send command only after accumulating enough clicks
    if (abs(clickCounter) >= requiredClicks) {
      int commandsToSend = abs(clickCounter) / requiredClicks;
      
      for (int i = 0; i < commandsToSend; i++) {
        if (direction > 0) {
          sendSingleKey(KEY_RIGHT_BRACKET);
        } else {
          sendSingleKey(KEY_LEFT_BRACKET);
        }
        delay(KEY_REPEAT_DELAY);
        
        // Update zone after each actual brush change
        updateBrushZone(direction);
      }
      
      clickCounter = 0;
      lastKeyPressTime = millis();
      
      Serial.print("Zone:");
      Serial.print(brushSizeZone);
      Serial.print(" Clicks:");
      Serial.print(requiredClicks);
      Serial.print(" Steps:");
      Serial.println(brushStepCounter);
    }
  }
  
  // Handle reset button
  if (digitalRead(RESET_PIN) == LOW) {
    if (resetPressStartTime == 0) {
      resetPressStartTime = millis();
    } else if (millis() - resetPressStartTime > RESET_DELAY) {
      // Reset to minimum and extreme fine control
      for (int i = 0; i < 40; i++) {
        sendSingleKey(KEY_LEFT_BRACKET);
        delay(40);
      }
      brushSizeZone = 0;
      clickCounter = 0;
      brushStepCounter = 0;
      resetPressStartTime = 0;
      Serial.println("Reset to extreme fine control");
    }
  } else {
    resetPressStartTime = 0;
  }
  
  delay(5);
}