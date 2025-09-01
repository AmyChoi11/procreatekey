// Procreate Color Selector with Scrollball
#include <BLEDevice.h>
#include <BLEUtils.h>
#include <BLEServer.h>
#include <BLE2902.h>
#include <BLEHIDDevice.h>
#include <WiFi.h>  // Required for WiFi.mode

// Key codes
#define KEY_LEFT_GUI      0x08
#define KEY_LEFT_SHIFT    0x02
#define KEY_Z             0x1D
#define KEY_LEFT_BRACKET  0x2F
#define KEY_RIGHT_BRACKET 0x30
#define KEY_S             0x16      // For Procreate shortcuts
#define MOUSE_LEFT        0x01
#define MOUSE_RIGHT       0x02

// Scrollball pins - Update these to match your scrollball connections
#define SCROLLBALL_UP_PIN     40  // Scrollball UP direction pin
#define SCROLLBALL_DOWN_PIN   39  // Scrollball DOWN direction pin
#define SCROLLBALL_LEFT_PIN   38  // Scrollball LEFT direction pin
#define SCROLLBALL_RIGHT_PIN  37  // Scrollball RIGHT direction pin
#define SELECT_BTN_PIN        15  // External button for color selection
#define MODE_BTN_PIN          5   // External button for mode toggle
#define COLOR_PALETTE_BTN_PIN 17  // Button to open/close color palette

// Scrollball settings
#define SCROLLBALL_THRESHOLD  50   // Threshold for scrollball activation
#define MOUSE_DELAY           20   // Slightly faster updates
#define CURSOR_SPEED          8    // Base speed for cursor movement
#define LONG_PRESS_TIME       800  // Time to hold button for secondary function

// Direction-specific speed multipliers (adjust these to balance speeds)
#define RIGHT_SPEED_MULTIPLIER 1.0  // Right direction speed boost
#define LEFT_SPEED_MULTIPLIER  1.0  // Left direction speed boost
#define DOWN_SPEED_MULTIPLIER  3.5  // Down direction speed boost
#define UP_SPEED_MULTIPLIER    1.0  // Up direction is already fast

// X-axis sensitivity adjustment - lower values make it less sensitive
#define X_SENSITIVITY_FACTOR   0.3  // Reduced from 4.0 to make X less sensitive

// HID Report Map for Keyboard and Mouse
static const uint8_t hidReportMap[] = {
  // Keyboard Report Descriptor
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
  0xC0,              // End Collection
  
  // Mouse Report Descriptor
  0x05, 0x01,        // Usage Page (Generic Desktop)
  0x09, 0x02,        // Usage (Mouse)
  0xA1, 0x01,        // Collection (Application)
  0x85, 0x02,        //   Report ID (2)
  0x09, 0x01,        //   Usage (Pointer)
  0xA1, 0x00,        //   Collection (Physical)
  0x05, 0x09,        //     Usage Page (Button)
  0x19, 0x01,        //     Usage Minimum (Button 1)
  0x29, 0x03,        //     Usage Maximum (Button 3)
  0x15, 0x00,        //     Logical Minimum (0)
  0x25, 0x01,        //     Logical Maximum (1)
  0x95, 0x03,        //     Report Count (3)
  0x75, 0x01,        //     Report Size (1)
  0x81, 0x02,        //     Input (Data, Variable, Absolute)
  0x95, 0x01,        //     Report Count (1)
  0x75, 0x05,        //     Report Size (5)
  0x81, 0x01,        //     Input (Constant)
  0x05, 0x01,        //     Usage Page (Generic Desktop)
  0x09, 0x30,        //     Usage (X)
  0x09, 0x31,        //     Usage (Y)
  0x15, 0x81,        //     Logical Minimum (-127)
  0x25, 0x7F,        //     Logical Maximum (127)
  0x75, 0x08,        //     Report Size (8)
  0x95, 0x02,        //     Report Count (2)
  0x81, 0x06,        //     Input (Data, Variable, Relative)
  0x09, 0x38,        //     Usage (Wheel)
  0x15, 0x81,        //     Logical Minimum (-127)
  0x25, 0x7F,        //     Logical Maximum (127)
  0x75, 0x08,        //     Report Size (8)
  0x95, 0x01,        //     Report Count (1)
  0x81, 0x06,        //     Input (Data, Variable, Relative)
  0xC0,              //   End Collection
  0xC0               // End Collection
};

BLEHIDDevice* hid;
BLECharacteristic* inputKeyboard;
BLECharacteristic* inputMouse;
bool connected = false;

// Scrollball variables
bool colorSelectionMode = true;  // True for color selection, false for brush size
bool inColorPalette = false;     // Track if we're in color palette view

// Button debounce variables
unsigned long lastButtonTime = 0;
#define BUTTON_DEBOUNCE_TIME 200

class ServerCallbacks : public BLEServerCallbacks {
  void onConnect(BLEServer* server) { 
    connected = true; 
    Serial.println("Connected to iPad");
  }
  
  void onDisconnect(BLEServer* server) { 
    connected = false; 
    Serial.println("Disconnected from iPad"); 
    server->startAdvertising();
  }
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

// Send mouse movement and/or button press
void sendMouseAction(int8_t x, int8_t y, uint8_t buttons) {
  if (!connected) return;
  
  uint8_t msg[] = {buttons, x, y, 0};
  inputMouse->setValue(msg, sizeof(msg));
  inputMouse->notify();
  
  // Only release button if any were pressed
  if (buttons > 0) {
    delay(10);
    uint8_t msg2[] = {0, 0, 0, 0};
    inputMouse->setValue(msg2, sizeof(msg2));
    inputMouse->notify();
  }
}

// Read scrollball input and convert to mouse movement
void handleScrollball() {
  // Read digital values from scrollball
  int upValue = analogRead(SCROLLBALL_UP_PIN);
  int downValue = analogRead(SCROLLBALL_DOWN_PIN);
  int leftValue = analogRead(SCROLLBALL_LEFT_PIN);
  int rightValue = analogRead(SCROLLBALL_RIGHT_PIN);
  
  // Debug - print raw values periodically
  static unsigned long lastDebugTime = 0;
  if (millis() - lastDebugTime > 1000) {
    lastDebugTime = millis();
    Serial.println("\n====== Scrollball Diagnostic ======");
    Serial.print("UP: ");
    Serial.print(upValue);
    Serial.print(", DOWN: ");
    Serial.print(downValue);
    Serial.print(", LEFT: ");
    Serial.print(leftValue);
    Serial.print(", RIGHT: ");
    Serial.println(rightValue);
  }
  
  // Calculate X and Y movements
  int8_t mouseX = 0;
  int8_t mouseY = 0;
  
  // X-axis: Calculate direction and speed
  if (rightValue > SCROLLBALL_THRESHOLD) {
    // Right movement
    float normalizedValue = (float)rightValue / 4095.0;
    mouseX = (int8_t)(normalizedValue * CURSOR_SPEED * RIGHT_SPEED_MULTIPLIER * X_SENSITIVITY_FACTOR);
  } else if (leftValue > SCROLLBALL_THRESHOLD) {
    // Left movement
    float normalizedValue = (float)leftValue / 4095.0;
    mouseX = -(int8_t)(normalizedValue * CURSOR_SPEED * LEFT_SPEED_MULTIPLIER * X_SENSITIVITY_FACTOR);
  }
  
  // Y-axis: Calculate direction and speed
  if (downValue > SCROLLBALL_THRESHOLD) {
    // Down movement
    float normalizedValue = (float)downValue / 4095.0;
    mouseY = (int8_t)(normalizedValue * CURSOR_SPEED * DOWN_SPEED_MULTIPLIER);
  } else if (upValue > SCROLLBALL_THRESHOLD) {
    // Up movement
    float normalizedValue = (float)upValue / 4095.0;
    mouseY = -(int8_t)(normalizedValue * CURSOR_SPEED * UP_SPEED_MULTIPLIER);
  }
  
  // Apply non-linear response curve for better control
  if (abs(mouseX) > 0) {
    if (abs(mouseX) < 2) mouseX = (mouseX > 0) ? 2 : -2; // Minimum movement
    else if (abs(mouseX) > 100) mouseX = (mouseX > 0) ? 100 : -100; // Cap at 100
  }
  
  if (abs(mouseY) > 0) {
    if (abs(mouseY) < 2) mouseY = (mouseY > 0) ? 2 : -2; // Minimum movement
    else if (abs(mouseY) > 100) mouseY = (mouseY > 0) ? 100 : -100; // Cap at 100
  }
  
  // Only send if there's actual movement
  if (mouseX != 0 || mouseY != 0) {
    // Ensure cursor moves in the correct direction
    sendMouseAction(mouseX, mouseY, 0);
    
    // Debug output for significant mouse movements
    String dirX = mouseX > 0 ? "RIGHT" : (mouseX < 0 ? "LEFT" : "");
    String dirY = mouseY > 0 ? "DOWN" : (mouseY < 0 ? "UP" : "");
    
    Serial.print("Mouse: ");
    if (mouseX != 0) {
      Serial.print(dirX);
      Serial.print("(");
      Serial.print(mouseX);
      Serial.print(") ");
    }
    if (mouseY != 0) {
      Serial.print(dirY);
      Serial.print("(");
      Serial.print(mouseY);
      Serial.print(")");
    }
    Serial.println();
  }
}

// Toggle between color selection and brush size modes
void toggleMode() {
  colorSelectionMode = !colorSelectionMode;
  Serial.print("Mode changed to: ");
  Serial.println(colorSelectionMode ? "COLOR SELECTION" : "BRUSH SIZE");
  
  // Provide haptic feedback via double-click simulation
  sendMouseAction(0, 0, MOUSE_LEFT);
  delay(50);
  sendMouseAction(0, 0, MOUSE_LEFT);
}

// Toggle the color palette in Procreate
void toggleColorPalette() {
  if (millis() - lastButtonTime < BUTTON_DEBOUNCE_TIME) {
    return; // Debounce
  }
  lastButtonTime = millis();
  
  // In Procreate, the 'S' key toggles the color palette
  sendSingleKey(KEY_S);
  
  inColorPalette = !inColorPalette;
  Serial.print("Color Palette: ");
  Serial.println(inColorPalette ? "OPENED" : "CLOSED");
  
  delay(100);
}

void setup() {
  Serial.begin(115200);
  delay(1000); // Wait longer for serial to initialize
  
  Serial.println("\n\n=== Procreate Color Selector with Scrollball ===");
  Serial.println("1. Use scrollball to navigate color picker or canvas");
  Serial.println("2. Press SELECT button to choose a color or draw");
  Serial.println("3. Press MODE button to toggle between color/brush size modes");
  Serial.println("4. Press COLOR PALETTE button to open/close the color palette");
  
  // Configure button pins
  pinMode(SELECT_BTN_PIN, INPUT_PULLUP);
  pinMode(MODE_BTN_PIN, INPUT_PULLUP);
  pinMode(COLOR_PALETTE_BTN_PIN, INPUT_PULLUP);
  
  // Configure scrollball pins
  pinMode(SCROLLBALL_UP_PIN, INPUT);
  pinMode(SCROLLBALL_DOWN_PIN, INPUT);
  pinMode(SCROLLBALL_LEFT_PIN, INPUT);
  pinMode(SCROLLBALL_RIGHT_PIN, INPUT);
  
  // Initialize analog readings
  analogReadResolution(12); // 12-bit resolution (0-4095)
  
  // Disable WiFi to reduce ADC noise (ESP32 specific)
  WiFi.mode(WIFI_OFF);
  
  // Test scrollball pins and report basic readings
  Serial.println("\n===== SCROLLBALL CONNECTION TEST =====");
  
  // Test each direction
  Serial.println("Testing UP direction...");
  int upValue = analogRead(SCROLLBALL_UP_PIN);
  Serial.print("UP value: ");
  Serial.println(upValue);
  
  Serial.println("Testing DOWN direction...");
  int downValue = analogRead(SCROLLBALL_DOWN_PIN);
  Serial.print("DOWN value: ");
  Serial.println(downValue);
  
  Serial.println("Testing LEFT direction...");
  int leftValue = analogRead(SCROLLBALL_LEFT_PIN);
  Serial.print("LEFT value: ");
  Serial.println(leftValue);
  
  Serial.println("Testing RIGHT direction...");
  int rightValue = analogRead(SCROLLBALL_RIGHT_PIN);
  Serial.print("RIGHT value: ");
  Serial.println(rightValue);
  
  // Check if values are in a reasonable range
  if (upValue < 10 || downValue < 10 || leftValue < 10 || rightValue < 10) {
    Serial.println("WARNING: One or more scrollball values are very low. Check connections!");
  }
  
  // Initialize BLE
  BLEDevice::init("ProcreateScrollball");
  BLEServer* server = BLEDevice::createServer();
  server->setCallbacks(new ServerCallbacks());
  
  BLESecurity* security = new BLESecurity();
  security->setAuthenticationMode(ESP_LE_AUTH_BOND);
  security->setCapability(ESP_IO_CAP_NONE);
  security->setInitEncryptionKey(ESP_BLE_ENC_KEY_MASK | ESP_BLE_ID_KEY_MASK);
  
  hid = new BLEHIDDevice(server);
  inputKeyboard = hid->inputReport(1);
  inputMouse = hid->inputReport(2);
  
  hid->manufacturer()->setValue("ESP32");
  hid->pnp(0x02, 0xe502, 0xa111, 0x0210);
  hid->hidInfo(0x00, 0x01);
  hid->reportMap((uint8_t*)hidReportMap, sizeof(hidReportMap));
  hid->startServices();
  
  BLEAdvertising* advertising = server->getAdvertising();
  advertising->setAppearance(HID_KEYBOARD);
  advertising->addServiceUUID(hid->hidService()->getUUID());
  advertising->start();
  
  Serial.println("BLE device advertising. Connect from your iPad's Bluetooth settings.");
  Serial.println("Ready for Procreate color selection with scrollball!");
}

void loop() {
  // Handle SELECT button (for color selection)
  if(digitalRead(SELECT_BTN_PIN) == LOW) {
    if(connected) {
      if(colorSelectionMode) {
        Serial.println("Color selected");
      } else {
        Serial.println("Brush size/opacity adjusted");
      }
      sendMouseAction(0, 0, MOUSE_LEFT);
      delay(300);
    }
    while(digitalRead(SELECT_BTN_PIN) == LOW) delay(10); // Wait for button release
  }
  
  // Handle MODE button (toggle between color selection and brush size)
  if(digitalRead(MODE_BTN_PIN) == LOW) {
    if(connected) {
      toggleMode();
      delay(300);
    }
    while(digitalRead(MODE_BTN_PIN) == LOW) delay(10); // Wait for button release
  }
  
  // Handle COLOR PALETTE button (open/close the color palette in Procreate)
  if(digitalRead(COLOR_PALETTE_BTN_PIN) == LOW) {
    if(connected) {
      toggleColorPalette();
      delay(300);
    }
    while(digitalRead(COLOR_PALETTE_BTN_PIN) == LOW) delay(10); // Wait for button release
  }
  
  // Process scrollball movement for cursor control
  if(connected) {
    handleScrollball();
  }
  
  delay(MOUSE_DELAY);
}
