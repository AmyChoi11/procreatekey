// Procreate Color Selector usi// Direction-specific speed multipliers (adjust these to balance speeds)
#define RIGHT_SPEED_MULTIPLIER 1.0  // Right direction speed boost
#define LEFT_SPEED_MULTIPLIER  1.0  // Left direction speed boost
#define DOWN_SPEED_MULTIPLIER  3.0  // Down direction speed boost
#define UP_SPEED_MULTIPLIER    1.0  // Up direction is already fast

// X-axis sensitivity adjustment - lower values make it less sensitive
#define X_SENSITIVITY_FACTOR   0.3  // Reduced from 4.0 to make X less sensitive

// Axis inversion settings (change these if joystick directions are wrong)
#define INVERT_X_AXIS false    // Set to false to fix reversed left/right direction
#define INVERT_Y_AXIS false    // Set to true to invert up/down directionystick
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

// Pins
#define JOYSTICK_X_PIN    4  // Analog joystick X axis (ADC1_CH0)
#define JOYSTICK_Y_PIN    16  // Analog joystick Y axis (ADC1_CH3)
#define SELECT_BTN_PIN    15  // External button for color selection
#define MODE_BTN_PIN      5   // External button for mode toggle
#define COLOR_PALETTE_BTN_PIN 17  // Button to open/close color palette

// Joystick settings
#define JOYSTICK_DEADZONE 300  // Reduced dead zone (0-4095 ADC range)
#define MOUSE_DELAY       20   // Slightly faster updates
#define CURSOR_SPEED      8    // Base speed for cursor movement
#define LONG_PRESS_TIME   800  // Time to hold button for secondary function

// Direction-specific speed multipliers (adjust these to balance speeds)
#define RIGHT_SPEED_MULTIPLIER 1.0  // Right direction speed boost
#define LEFT_SPEED_MULTIPLIER  1.0  // Left direction speed boost
#define DOWN_SPEED_MULTIPLIER  3.5  // Down direction speed boost
#define UP_SPEED_MULTIPLIER    1.0  // Up direction is already fast

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

// Joystick variables
int joyXCenter = 2048;  // Center position calibration (will be updated in setup)
int joyYCenter = 2048;  // Center position calibration (will be updated in setup)
int joyX = 0;
int joyY = 0;
bool colorSelectionMode = true;  // True for color selection, false for brush size
bool inColorPalette = false;     // Track if we're in color palette view

// Button debounce variables
unsigned long lastButtonTime = 0;
#define BUTTON_DEBOUNCE_TIME 200

// Helper function to map joystick values to mouse movement with direction-specific speeds
int mapJoystickToMouse(int value, int center, bool isXAxis) {
  int mappedValue = 0;
  
  // Safety check for center value
  if (center < 100 || center > 4000) {
    // If center calibration is way off, use a reasonable default
    center = 2048;
    Serial.println("WARNING: Using default center value for joystick mapping");
  }
  
  // Calculate offset from center
  int offset = value - center;
  
  // Apply dead zone
  if (abs(offset) < JOYSTICK_DEADZONE) {
    return 0;
  }
  
  // Debugging for X-axis issues
  if (isXAxis) {
    static unsigned long lastXDebugTime = 0;
    if (abs(offset) > 500 && millis() - lastXDebugTime > 2000) {
      lastXDebugTime = millis();
      Serial.print("X-AXIS DEBUG: Raw=");
      Serial.print(value);
      Serial.print(", Offset=");
      Serial.print(offset);
      Serial.print(", Center=");
      Serial.println(center);
    }
  }
  
  // Apply non-linear mapping for better control
  float normalized = (float)offset / (4095.0 - JOYSTICK_DEADZONE);
  
  // Ensure normalized value is within range
  if (normalized > 1.0) normalized = 1.0;
  if (normalized < -1.0) normalized = -1.0;
  
  // Apply axis inversion settings based on defines
  if (isXAxis && INVERT_X_AXIS) {
    normalized = -normalized;
  } else if (!isXAxis && INVERT_Y_AXIS) {
    normalized = -normalized;
  }
  
  // Force X axis to be more sensitive (for debugging)
  if (isXAxis) {
    // Apply the X sensitivity factor
    normalized *= X_SENSITIVITY_FACTOR;
    
    // Cap the value again after boosting
    if (normalized > 1.0) normalized = 1.0;
    if (normalized < -1.0) normalized = -1.0;
  }
  
  // Direction-specific speed adjustments
  float speedMultiplier = 1.0;
  
  if (isXAxis) {
    // X-axis adjustments
    if (normalized > 0) {
      // Right movement
      speedMultiplier = RIGHT_SPEED_MULTIPLIER;
    } else {
      // Left movement
      speedMultiplier = LEFT_SPEED_MULTIPLIER;
    }
  } else {
    // Y-axis adjustments
    if (normalized > 0) {
      // Down movement - boost speed
      speedMultiplier = DOWN_SPEED_MULTIPLIER;
    } else {
      // Up movement
      speedMultiplier = UP_SPEED_MULTIPLIER;
    }
  }
  
  // Apply non-linear response curve with direction-specific adjustments
  if (abs(normalized) > 0.8) {
    // High speed for edge positions
    mappedValue = normalized * CURSOR_SPEED * 2 * speedMultiplier;
  } else if (abs(normalized) > 0.4) {
    // Medium speed
    mappedValue = normalized * CURSOR_SPEED * speedMultiplier;
  } else {
    // Low speed for fine control
    mappedValue = normalized * CURSOR_SPEED * 0.5 * speedMultiplier;
  }
  
  // Ensure we don't exceed mouse value limits (-127 to 127)
  if (mappedValue > 127) mappedValue = 127;
  if (mappedValue < -127) mappedValue = -127;
  
  // For X-axis, boost small values to ensure they register
  if (isXAxis && abs(mappedValue) > 0 && abs(mappedValue) < 10) {
    mappedValue = (mappedValue > 0) ? 10 : -10;
  }
  
  return (int)mappedValue;
}

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

// Read joystick position and return mouse movement values
void handleJoystick() {
  // Read analog values from joystick
  int rawX = analogRead(JOYSTICK_X_PIN);
  int rawY = analogRead(JOYSTICK_Y_PIN);
  
  // Apply software filtering (simple moving average)
  static int lastXValues[5] = {0};
  static int lastYValues[5] = {0};
  static int filterIndex = 0;
  
  // Store new values
  lastXValues[filterIndex] = rawX;
  lastYValues[filterIndex] = rawY;
  filterIndex = (filterIndex + 1) % 5;
  
  // Calculate average
  joyX = 0;
  joyY = 0;
  for (int i = 0; i < 5; i++) {
    joyX += lastXValues[i];
    joyY += lastYValues[i];
  }
  joyX /= 5;
  joyY /= 5;
  
  // Enhanced debugging - print raw values periodically
  static unsigned long lastDebugTime = 0;
  if (millis() - lastDebugTime > 1000) {
    lastDebugTime = millis();
    Serial.println("\n====== Joystick Diagnostic ======");
    Serial.print("X-PIN: ");
    Serial.print(JOYSTICK_X_PIN);
    Serial.print(", Y-PIN: ");
    Serial.println(JOYSTICK_Y_PIN);
    
    Serial.print("X Raw: ");
    Serial.print(rawX);
    Serial.print(", Filtered: ");
    Serial.print(joyX);
    Serial.print(", Diff from center: ");
    Serial.println(joyX - joyXCenter);
    
    Serial.print("Y Raw: ");
    Serial.print(rawY);
    Serial.print(", Filtered: ");
    Serial.print(joyY);
    Serial.print(", Diff from center: ");
    Serial.println(joyY - joyYCenter);
    
    // Check if values are changing
    static int lastReportedX = 0;
    static int lastReportedY = 0;
    if (abs(lastReportedX - joyX) < 100 && abs(lastReportedY - joyY) < 100) {
      Serial.println("WARNING: Joystick values not changing much. Check connections!");
    }
    lastReportedX = joyX;
    lastReportedY = joyY;
  }
  
  // Force X-axis movement test every 10 seconds
  static unsigned long lastForceTest = 0;
  if (millis() - lastForceTest > 10000) {
    lastForceTest = millis();
    Serial.println("\n*** TESTING X-AXIS MOVEMENT ***");
    
    // Test horizontal movement (with corrected directions)
    Serial.println("Sending RIGHT cursor movement...");
    sendMouseAction(-50, 0, 0);  // Inverted to correct direction
    delay(100);
    
    Serial.println("Sending LEFT cursor movement...");
    sendMouseAction(50, 0, 0);  // Inverted to correct direction
    delay(100);
  }
  
  // Map to mouse movement (-127 to 127)
  int8_t mouseX = mapJoystickToMouse(joyX, joyXCenter, true);  // true for X-axis
  int8_t mouseY = mapJoystickToMouse(joyY, joyYCenter, false); // false for Y-axis
  
  // Force X value if it's not changing but should be
  if (abs(joyX - joyXCenter) > 500 && mouseX == 0) {
    // X-axis seems to be moving but not being registered
    mouseX = (joyX > joyXCenter) ? 20 : -20;
    Serial.println("Forcing X movement based on raw readings");
  }
  
  // Only send if there's actual movement
  if (mouseX != 0 || mouseY != 0) {
    // Directly invert X-axis to fix direction issue
    mouseX = -mouseX;
    
    // Ensure cursor moves in the correct direction
    sendMouseAction(mouseX, mouseY, 0);
    
    // Debug output for significant mouse movements with direction indicators
    if (abs(mouseX) > 2 || abs(mouseY) > 2) {
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
  
  Serial.println("\n\n=== Procreate Color Selector with Joystick ===");
  Serial.println("1. Move joystick to navigate color picker or canvas");
  Serial.println("2. Press SELECT button to choose a color or draw");
  Serial.println("3. Press MODE button to toggle between color/brush size modes");
  Serial.println("4. Press COLOR PALETTE button to open/close the color palette");
  
  // Configure pins
  pinMode(SELECT_BTN_PIN, INPUT_PULLUP);
  pinMode(MODE_BTN_PIN, INPUT_PULLUP);
  pinMode(COLOR_PALETTE_BTN_PIN, INPUT_PULLUP);
  
  // Configure analog pins (not necessary for input, but shown for clarity)
  pinMode(JOYSTICK_X_PIN, INPUT);
  pinMode(JOYSTICK_Y_PIN, INPUT);
  
  // Initialize analog readings
  analogReadResolution(12); // 12-bit resolution (0-4095)
  
  // Disable WiFi to reduce ADC noise (ESP32 specific)
  WiFi.mode(WIFI_OFF);
  
  // Test joystick pins and report basic readings
  Serial.println("\n===== JOYSTICK CONNECTION TEST =====");
  
  // Test X-axis multiple times
  Serial.print("X-axis (Pin ");
  Serial.print(JOYSTICK_X_PIN);
  Serial.println("):");
  
  int xSum = 0;
  int xMin = 4095;
  int xMax = 0;
  
  for (int i = 0; i < 10; i++) {
    int testX = analogRead(JOYSTICK_X_PIN);
    xSum += testX;
    xMin = min(xMin, testX);
    xMax = max(xMax, testX);
    
    Serial.print("  Reading ");
    Serial.print(i+1);
    Serial.print(": ");
    Serial.println(testX);
    delay(100);
  }
  
  int xAvg = xSum / 10;
  Serial.print("X-axis average: ");
  Serial.print(xAvg);
  Serial.print(", range: ");
  Serial.print(xMin);
  Serial.print(" to ");
  Serial.println(xMax);
  
  if (xMax - xMin < 100) {
    Serial.println("WARNING: X-axis shows little variation. Check connections!");
  }
  
  // Test Y-axis multiple times
  Serial.print("Y-axis (Pin ");
  Serial.print(JOYSTICK_Y_PIN);
  Serial.println("):");
  
  int ySum = 0;
  int yMin = 4095;
  int yMax = 0;
  
  for (int i = 0; i < 10; i++) {
    int testY = analogRead(JOYSTICK_Y_PIN);
    ySum += testY;
    yMin = min(yMin, testY);
    yMax = max(yMax, testY);
    
    Serial.print("  Reading ");
    Serial.print(i+1);
    Serial.print(": ");
    Serial.println(testY);
    delay(100);
  }
  
  int yAvg = ySum / 10;
  Serial.print("Y-axis average: ");
  Serial.print(yAvg);
  Serial.print(", range: ");
  Serial.print(yMin);
  Serial.print(" to ");
  Serial.println(yMax);
  
  if (yMax - yMin < 100) {
    Serial.println("WARNING: Y-axis shows little variation. Check connections!");
  }
  
  Serial.print("Y-axis (Pin ");
  Serial.print(JOYSTICK_Y_PIN);
  Serial.print("): ");
  int testY = analogRead(JOYSTICK_Y_PIN);
  Serial.print(testY);
  Serial.print(" - ");
  Serial.println(testY > 500 && testY < 3500 ? "OK" : "CHECK WIRING");
  
  // Calibrate joystick center position
  Serial.println("\nCalibrating joystick. Keep it centered...");
  delay(500);
  
  // Take multiple readings to average the center position
  joyXCenter = 0;
  joyYCenter = 0;
  for (int i = 0; i < 10; i++) {
    joyXCenter += analogRead(JOYSTICK_X_PIN);
    joyYCenter += analogRead(JOYSTICK_Y_PIN);
    delay(50);
  }
  joyXCenter /= 10;
  joyYCenter /= 10;
  
  Serial.print("Joystick calibrated. Center: X=");
  Serial.print(joyXCenter);
  Serial.print(" Y=");
  Serial.println(joyYCenter);
  
  // Validate calibration values
  if (joyXCenter < 500 || joyXCenter > 3500) {
    Serial.println("WARNING: X-axis center value seems unusual. Check joystick connections!");
  }
  if (joyYCenter < 500 || joyYCenter > 3500) {
    Serial.println("WARNING: Y-axis center value seems unusual. Check joystick connections!");
  }
  
  // Initialize BLE
  BLEDevice::init("ProcreateColorPicker");
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
  Serial.println("Ready for Procreate color selection!");
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
  
  // Process joystick movement for cursor control
  if(connected) {
    handleJoystick();
  }
  
  delay(MOUSE_DELAY);
}