// Simple BLE keyboard example for Procreate undo/redo buttons

#include <BLEDevice.h>
#include <BLEUtils.h>
#include <BLEServer.h>
#include <BLE2902.h>
#include <BLEHIDDevice.h>

//========= BUTTON FUNCTION CONFIGURATION =========
// Change these values to set which function each button performs
// (See the FUNCTION_ constants below)
#define DEBUG_MODE true  // Set to true to test key codes
#define BUTTON1_FUNCTION  FUNCTION_HSB       // What BUTTON1_PIN button does
#define BUTTON2_FUNCTION  FUNCTION_EYE_DROPPER      // What BUTTON2_PIN button does

// Touch sensor configuration
#define TOUCH_SENSOR_PIN 35  // Change this to your touch sensor pin
#define TOUCH_ACTIVE_HIGH true  // TTP223 typically outputs HIGH when touched
//================================================

// Key codes
#define KEY_LEFT_GUI    0xE0  // Command key on iOS
#define KEY_LEFT_SHIFT  0xE1  // Shift key
#define KEY_L           0x0F  // L key (Layer panel)
#define KEY_B           0x05  // B key (Brush/Paint tool)
#define KEY_S           0x16  // S key (Selection)
#define KEY_C           0x06  // C key (Color popover)
#define KEY_V           0x19  // V key (Transform mode/Paste with Cmd)
#define KEY_Z           0x1D  // Z key (Undo/Redo with modifiers)
#define KEY_TILDE       0x35  // ~ key 
#define KEY_R           0x15  // R key 
#define KEY_A           0x04  // A key (Adjustments)
#define KEY_SPACE       0x2C  // Space key (QuickMenu)
#define KEY_TAB         0x2B  // Tab key for navigation
#define KEY_DOWN        0x51  // Down arrow key
#define KEY_ENTER       0x28  // Enter/Return key
#define KEY_X           0x1B  // X key (Previous color)
#define KEY_E           0x08  // E key (Erase popover)
#define KEY_J           0x0D  // J key (Duplicate selection with Cmd)
#define KEY_D           0x07  // D key (Deselect active selection with Cmd)
#define KEY_0           0x27  // 0 key (Full screen with Cmd)
#define KEY_U           0x18  // U key (Adjustments panel)
#define KEY_I           0x0C  // I key (Eye Dropper/Color picker)

// Function definitions (corrected shortcuts)
#define FUNCTION_UNDO          0  // Command+Z
#define FUNCTION_REDO          1  // Command+Shift+Z
#define FUNCTION_LAYERS        2  // L (just L key)
#define FUNCTION_BRUSHES       3  // B (just B key)
#define FUNCTION_COLORS        4  // C (just C key)
#define FUNCTION_SELECTION     5  // S (just S key)
#define FUNCTION_COPY          6  // Command+C
#define FUNCTION_PASTE         7  // Command+V
#define FUNCTION_ADJUSTMENTS   8  // Command+A
#define FUNCTION_QUICKMENU     9  // Space (just Space key)
#define FUNCTION_TRANSFORM    10  // V (just V key)
#define FUNCTION_LIQUIFY      11  // Opens Adjustments (Command+A) where Liquify is located
#define FUNCTION_ERASE        12  // E (just E key)
#define FUNCTION_PREV_COLOR   13  // X (just X key)
#define FUNCTION_FULLSCREEN   14  // Command+0
#define FUNCTION_DUPLICATE    15  // Command+J
#define FUNCTION_DESELECT     16  // Command+D
#define FUNCTION_COLOR_BALANCE 17 // Command+B (actual function of Command+B)
#define FUNCTION_HSB           18 // Command+U (Hue/Saturation/Brightness)
#define FUNCTION_EYE_DROPPER   19 // I key (Color picker/eye dropper)

// Pins - renamed for clarity
#define BUTTON1_PIN 4 
#define BUTTON2_PIN 5 

// HID Report Map for keyboard
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
bool eraserModeActive = false;  // Track current eraser/brush state
bool lastTouchState = false;    // Track previous touch state

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
  
  // Debug output
  if (DEBUG_MODE) {
    Serial.print("Sending key combo - Modifier: 0x");
    Serial.print(mod, HEX);
    Serial.print(", Key: 0x");
    Serial.println(key, HEX);
  }
  
  // Press keys with explicit format for iOS
  uint8_t msg[] = {mod, 0, key, 0, 0, 0, 0, 0};
  inputKeyboard->setValue(msg, sizeof(msg));
  inputKeyboard->notify();
  delay(200);  // Longer delay for iOS to process
  
  // Release keys
  uint8_t msg2[] = {0, 0, 0, 0, 0, 0, 0, 0};
  inputKeyboard->setValue(msg2, sizeof(msg2));
  inputKeyboard->notify();
  
  Serial.println("Sent keyboard command");
}

// Send a sequence of key presses to navigate to Liquify
void sendLiquifyMacro() {
  if (!connected) return;
  
  // Step 1: Open Adjustments panel
  Serial.println("Opening Adjustments panel");
  sendKeyCombo(0, KEY_U);
  delay(800); // Wait for panel to open
  
  // Step 2: Navigate to Liquify (assuming it's the 3rd option down)
  // First down arrow press
  Serial.println("Navigating to Liquify...");
  
  // Send down arrow key twice
  for (int i = 0; i < 2; i++) { //change this number if needed
    // Press down arrow
    uint8_t msgDown[] = {0, 0, KEY_DOWN, 0, 0, 0, 0, 0};
    inputKeyboard->setValue(msgDown, sizeof(msgDown));
    inputKeyboard->notify();
    delay(150);
    
    // Release down arrow
    uint8_t msgRelease[] = {0, 0, 0, 0, 0, 0, 0, 0};
    inputKeyboard->setValue(msgRelease, sizeof(msgRelease));
    inputKeyboard->notify();
    delay(150);
  }
  
  // Step 3: Select Liquify with Enter key
  Serial.println("Selecting Liquify");
  
  // Press Enter
  uint8_t msgEnter[] = {0, 0, KEY_ENTER, 0, 0, 0, 0, 0};
  inputKeyboard->setValue(msgEnter, sizeof(msgEnter));
  inputKeyboard->notify();
  delay(100);
  
  // Release Enter
  uint8_t msgRelease[] = {0, 0, 0, 0, 0, 0, 0, 0};
  inputKeyboard->setValue(msgRelease, sizeof(msgRelease));
  inputKeyboard->notify();
  
  Serial.println("Liquify macro complete");
}

// Add this helper function before executeFunction()
void sendSingleKey(uint8_t key) {
  if (!connected) return;
  
  // Press key
  uint8_t msgPress[] = {0, 0, key, 0, 0, 0, 0, 0};
  inputKeyboard->setValue(msgPress, sizeof(msgPress));
  inputKeyboard->notify();
  delay(150);
  
  // Release key
  uint8_t msgRelease[] = {0, 0, 0, 0, 0, 0, 0, 0};
  inputKeyboard->setValue(msgRelease, sizeof(msgRelease));
  inputKeyboard->notify();
}

// Execute function based on function ID - with corrected shortcuts
void executeFunction(int functionId) {
  if (!connected) return;
  
  switch(functionId) {
    case FUNCTION_UNDO:
      Serial.println("Sending Undo (Command+Z)");
      sendKeyCombo(KEY_LEFT_GUI, KEY_Z);
      break;
      
    case FUNCTION_REDO:
      Serial.println("Sending Redo (Command+Shift+Z)");
      sendKeyCombo(KEY_LEFT_GUI | KEY_LEFT_SHIFT, KEY_Z);
      break;
      
    case FUNCTION_LAYERS:
      Serial.println("Opening Layers panel (L)");
      sendKeyCombo(0, KEY_L);  // No modifier, just L key
      break;
      
    case FUNCTION_BRUSHES:
      Serial.println("Activating Paint Tool (B)");
      sendKeyCombo(0, KEY_B);  // No modifier, just B key
      break;
      
    case FUNCTION_COLORS:
      Serial.println("Opening Color popover (C)");
      sendKeyCombo(0, KEY_C);  // No modifier, just C key
      break;
      
    case FUNCTION_SELECTION:
      Serial.println("Selection Mode (S)");
      sendKeyCombo(0, KEY_S);  // No modifier, just S key
      break;
      
    case FUNCTION_COPY:
      Serial.println("Copy (Command+C)");
      sendKeyCombo(KEY_LEFT_GUI, KEY_C);
      break;
      
    case FUNCTION_PASTE:
      Serial.println("Paste (Command+V)");
      sendKeyCombo(KEY_LEFT_GUI, KEY_V);
      break;
      
    case FUNCTION_ADJUSTMENTS:
    {
      Serial.println("Adjustments panel (U key)");
      // Use the helper function for a cleaner implementation
      sendSingleKey(KEY_U);
      break;
    }
      
    case FUNCTION_QUICKMENU:
      Serial.println("Quick Menu (Space)");
      sendKeyCombo(0, KEY_SPACE);  // No modifier, just Space key
      break;
      
    case FUNCTION_TRANSFORM:
      Serial.println("Transform Mode (V)");
      sendKeyCombo(0, KEY_V);  // No modifier, just V key
      break;
    
    case FUNCTION_LIQUIFY:
      Serial.println("Executing Liquify macro sequence");
      sendLiquifyMacro();
      break;
      
    case FUNCTION_ERASE:
      Serial.println("Erase Popover (E)");
      sendKeyCombo(0, KEY_E);  // No modifier, just E key
      break;
      
    case FUNCTION_PREV_COLOR:
      Serial.println("Previous Color (X)");
      sendKeyCombo(0, KEY_X);  // No modifier, just X key
      break;
      
    case FUNCTION_FULLSCREEN:
      Serial.println("Full Screen (Command+0)");
      sendKeyCombo(KEY_LEFT_GUI, KEY_0);
      break;
      
    case FUNCTION_DUPLICATE:
      Serial.println("Duplicate Selection (Command+J)");
      sendKeyCombo(KEY_LEFT_GUI, KEY_J);
      break;
      
    case FUNCTION_DESELECT:
      Serial.println("Deselect Active Selection (Command+D)");
      sendKeyCombo(KEY_LEFT_GUI, KEY_D);
      break;
      
    case FUNCTION_COLOR_BALANCE:
      Serial.println("Color Balance (Command+B)");
      sendKeyCombo(KEY_LEFT_GUI, KEY_B);
      break;

    case FUNCTION_HSB:
      Serial.println("Hue/Saturation/Brightness (Command+U)");
      sendKeyCombo(KEY_LEFT_GUI, KEY_U);
      break;
      
    case FUNCTION_EYE_DROPPER:
      Serial.println("Color Eye Dropper (I)");
      sendKeyCombo(0, KEY_I);  // Just I key, no modifier
      break;

    default:
      Serial.println("Unknown function");
      break;
  }
}

// Function to toggle between brush and eraser
void toggleBrushEraser(bool activateEraser) {
  if (!connected) return;
  
  if (activateEraser && !eraserModeActive) {
    // Switch to eraser
    Serial.println("Switching to Eraser");
    sendKeyCombo(0, KEY_E);  // E key for eraser
    eraserModeActive = true;
  } 
  else if (!activateEraser && eraserModeActive) {
    // Switch back to brush
    Serial.println("Switching back to Brush");
    sendKeyCombo(0, KEY_B);  // B key for brush
    eraserModeActive = false;
  }
}

// Update setup() and loop() to use the new pin names
void setup() {
  Serial.begin(115200);
  
  // Configure button pins
  pinMode(BUTTON1_PIN, INPUT_PULLUP);
  pinMode(BUTTON2_PIN, INPUT_PULLUP);
  pinMode(TOUCH_SENSOR_PIN, INPUT);  // Set up touch sensor pin
  
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
  
  // Print current button configuration
  Serial.println("BLE Keyboard Ready - Current Configuration:");
  Serial.print("Button 1 (Pin ");
  Serial.print(BUTTON1_PIN);
  Serial.print("): Function ");
  Serial.println(BUTTON1_FUNCTION);
  
  Serial.print("Button 2 (Pin ");
  Serial.print(BUTTON2_PIN);
  Serial.print("): Function ");
  Serial.println(BUTTON2_FUNCTION);
  
  Serial.print("Touch Sensor (Pin ");
  Serial.print(TOUCH_SENSOR_PIN);
  Serial.println("): Toggle between Brush and Eraser");
  Serial.print("Touch Sensor Configuration: Expecting ");
  Serial.print(TOUCH_ACTIVE_HIGH ? "HIGH" : "LOW");
  Serial.println(" when touched");
  
  // Initial touch sensor reading
  bool initialTouchState = digitalRead(TOUCH_SENSOR_PIN);
  Serial.print("Initial touch sensor reading: ");
  Serial.println(initialTouchState ? "HIGH" : "LOW");
}

void loop() {
  // Read touch sensor state (TTP223 typically outputs HIGH when touched)
  bool rawTouchState = digitalRead(TOUCH_SENSOR_PIN);
  bool touchState = TOUCH_ACTIVE_HIGH ? rawTouchState : !rawTouchState;
  
  // Print touch state for debugging
  static bool lastDebugTouchState = false;
  if (touchState != lastDebugTouchState) {
    Serial.print("Touch sensor state changed: ");
    Serial.println(touchState ? "TOUCHED" : "RELEASED");
    lastDebugTouchState = touchState;
  }
  
  // Check if touch state has changed
  if (touchState != lastTouchState) {
    if (connected) {
      // Toggle between brush and eraser based on touch state
      toggleBrushEraser(touchState);
    }
    lastTouchState = touchState;  // Update last touch state
    delay(50);  // Small debounce delay
  }
  
  // Button 1 functionality
  if(digitalRead(BUTTON1_PIN) == LOW) {
    if(connected) {
      executeFunction(BUTTON1_FUNCTION);
      delay(300);
    } else {
      Serial.println("Not connected");
    }
    
    // Debounce
    while(digitalRead(BUTTON1_PIN) == LOW) {
      delay(10);
    }
  }
  
  // Button 2 functionality
  if(digitalRead(BUTTON2_PIN) == LOW) {
    if(connected) {
      executeFunction(BUTTON2_FUNCTION);
      delay(300);
    } else {
      Serial.println("Not connected");
    }
    
    // Debounce
    while(digitalRead(BUTTON2_PIN) == LOW) {
      delay(10);
    }
  }
  
  delay(10);
}