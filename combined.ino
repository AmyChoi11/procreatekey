// Procreate Combined Controller - Brush Size + Undo + Erase + Layer Navigation
#include <BLEDevice.h>
#include <BLEUtils.h>
#include <BLEServer.h>
#include <BLE2902.h>
#include <BLEHIDDevice.h>
#include <WiFi.h>  // Required for WiFi.mode setting

// Key codes
#define KEY_LEFT_GUI      0xE0  // Command key on iOS (updated to correct value)
#define KEY_LEFT_SHIFT    0xE1  // Shift key (updated to correct value)
#define KEY_Z             0x1D  // Z key (Undo with CMD modifier)
#define KEY_LEFT_BRACKET  0x2F  // [ key (decrease brush size)
#define KEY_RIGHT_BRACKET 0x30  // ] key (increase brush size)
#define KEY_S             0x16  // S key (selection tool)
#define KEY_E             0x08  // E key (eraser toggle in Procreate)

// Pins
#define UNDO_PIN          4     // Button for Undo function
#define ERASE_PIN         5     // Button for eraser toggle (was REDO_PIN)
#define ENCODER_PIN_A     7     // Rotary encoder pin A
#define ENCODER_PIN_B     6     // Rotary encoder pin B
#define RESET_PIN         15    // Reset brush size button
#define LED_PIN           2     // Built-in LED for feedback

// Timing settings
#define KEY_REPEAT_DELAY  50    // Delay between key presses (ms)
#define RESET_DELAY       2000  // Long press time for reset (ms)
#define DEBOUNCE_TIME     100   // Debounce time for buttons (ms)

// Brush size sensitivity settings
#define EXTREME_FINE_SPEED     25    // Very slow brush size change (1-3%)
#define VERY_FINE_SPEED        15    // Slow brush size change (4-8%)
#define FINE_SPEED             8     // Moderate brush size change (9-15%)
#define MEDIUM_SPEED           4     // Medium brush size change (16-30%)
#define COARSE_SPEED           2     // Fast brush size change (31-60%)
#define VERY_COARSE_SPEED      1     // Very fast brush size change (61-100%)

#define ZONE_CHANGE_THRESHOLD  8    // Number of brush steps before changing zone

// HID Report Map
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

// Global variables
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

// Button state variables
bool lastUndoState = HIGH;
bool lastEraseState = HIGH;
bool eraserMode = false; // Track whether eraser is active
bool undoPressProcessed = false; // Track if a button press has been processed

// Mode switching variables
bool modeSwitchProcessed = false; // Track if mode switch has been processed
unsigned long modeSwitchStartTime = 0; // Time when both buttons were pressed
#define MODE_SWITCH_DELAY 1000 // Hold both buttons for 1 second to switch modes

// Timing variables
unsigned long lastKeyPressTime = 0;
unsigned long resetPressStartTime = 0;
unsigned long lastUndoDebounceTime = 0;
unsigned long lastEraseDebounceTime = 0;

// Include layer handler after all necessary declarations
#include "layer_handler.h"  // Layer navigation functionality

// Layer handler function implementations
// Initialize layer handler
void initializeLayerHandler() {
  currentMode = BRUSH_MODE;
  lastLayerEncoderPos = encoderPos;
  lastLayerCommandTime = 0;
  layerModeProcessed = false;
  layerPanelOpened = false;
  currentLayerKeyMode = ARROW_KEYS;
  layerKeyAttempts = 0;
  
  Serial.println("Layer handler initialized - Starting in BRUSH_MODE");
}

// Send layer navigation command
void sendLayerCommand(uint8_t keyCode) {
  if (!connected) {
    Serial.println("ERROR: Cannot send layer command - not connected");
    return;
  }
  
  // Check timing to prevent too rapid commands
  unsigned long currentTime = millis();
  if (currentTime - lastLayerCommandTime < LAYER_NAVIGATION_DELAY) {
    return; // Too soon, skip this command
  }
  
  Serial.print("Sending layer command - Key: 0x");
  Serial.println(keyCode, HEX);
  
  // Send key press
  uint8_t msg[] = {0, 0, keyCode, 0, 0, 0, 0, 0};
  inputKeyboard->setValue(msg, sizeof(msg));
  inputKeyboard->notify();
  delay(50);
  
  // Send key release
  uint8_t msg2[] = {0, 0, 0, 0, 0, 0, 0, 0};
  inputKeyboard->setValue(msg2, sizeof(msg2));
  inputKeyboard->notify();
  
  lastLayerCommandTime = currentTime;
  Serial.println("Layer command sent successfully");
}

// Process encoder movement for layer navigation
void processLayerNavigation() {
  if (currentMode != LAYER_MODE) {
    return; // Not in layer mode, skip processing
  }
  
  int currentEncoderPos = encoderPos;
  int movement = currentEncoderPos - lastLayerEncoderPos;
  
  if (movement != 0) {
    Serial.print("Layer selection - Movement: ");
    Serial.print(movement);
    
    // Select appropriate keys based on current test mode
    uint8_t upKey, downKey;
    const char* keyName;
    
    switch (currentLayerKeyMode) {
      case ARROW_KEYS:
        upKey = KEY_UP_ARROW;
        downKey = KEY_DOWN_ARROW;
        keyName = "Arrow Keys";
        break;
      case BRACKET_KEYS:
        upKey = KEY_LEFT_BRACKET;   // [ for previous layer
        downKey = KEY_RIGHT_BRACKET; // ] for next layer
        keyName = "Bracket Keys";
        break;
      case COMMA_PERIOD:
        upKey = KEY_COMMA;          // , for previous layer
        downKey = KEY_PERIOD;       // . for next layer
        keyName = "Comma/Period";
        break;
      case SEMICOLON_QUOTE:
        upKey = KEY_SEMICOLON;      // ; for previous layer
        downKey = KEY_APOSTROPHE;   // ' for next layer
        keyName = "Semicolon/Quote";
        break;
      default:
        upKey = KEY_UP_ARROW;
        downKey = KEY_DOWN_ARROW;
        keyName = "Default Arrows";
        break;
    }
    
    Serial.print(" (testing ");
    Serial.print(keyName);
    Serial.println(")");
    
    // Process movement step by step for smooth navigation
    if (movement > 0) {
      // Clockwise = move to next layer (down in list)
      for (int i = 0; i < movement; i++) {
        sendLayerCommand(downKey);
        Serial.println("→ Next layer");
        layerKeyAttempts++;
        delay(100); // Small delay between layer changes
      }
    } else {
      // Counter-clockwise = move to previous layer (up in list) 
      for (int i = 0; i < abs(movement); i++) {
        sendLayerCommand(upKey);
        Serial.println("← Previous layer");
        layerKeyAttempts++;
        delay(100); // Small delay between layer changes
      }
    }
    
    // Auto-switch to next key mode after 5 attempts if current one doesn't work
    if (layerKeyAttempts >= 5) {
      layerKeyAttempts = 0;
      currentLayerKeyMode = (LayerKeyMode)((currentLayerKeyMode + 1) % 4);
      Serial.println("=================================");
      Serial.print("Auto-switching to: ");
      switch (currentLayerKeyMode) {
        case ARROW_KEYS: Serial.println("ARROW KEYS"); break;
        case BRACKET_KEYS: Serial.println("BRACKET KEYS [ ]"); break;
        case COMMA_PERIOD: Serial.println("COMMA/PERIOD KEYS , ."); break;
        case SEMICOLON_QUOTE: Serial.println("SEMICOLON/QUOTE KEYS ; '"); break;
      }
      Serial.println("=================================");
    }
    
    lastLayerEncoderPos = currentEncoderPos;
    
    // Visual feedback for layer navigation
    digitalWrite(LED_PIN, HIGH);
    delay(50);
    digitalWrite(LED_PIN, LOW);
  }
}

// Switch between brush mode and layer mode
void switchControlMode() {
  if (currentMode == BRUSH_MODE) {
    currentMode = LAYER_MODE;
    Serial.println("****** SWITCHED TO LAYER MODE ******");
    Serial.println("Opening Procreate layer panel...");
    
    // Send L key to open layer panel in Procreate
    if (connected) {
      sendLayerCommand(KEY_L);
      layerPanelOpened = true;
      delay(200); // Give Procreate time to open the panel
      Serial.println("Layer panel opened with L key");
    }
    
    Serial.println("Rotary encoder now controls layer selection:");
    Serial.println("- Clockwise: Select next layer (down)");
    Serial.println("- Counter-clockwise: Select previous layer (up)");
    Serial.println("Panel should remain open during navigation");
    
    indicateLayerMode();
  } else {
    currentMode = BRUSH_MODE;
    Serial.println("****** SWITCHED TO BRUSH MODE ******");
    
    // Close layer panel by sending L key again
    if (connected && layerPanelOpened) {
      sendLayerCommand(KEY_L);
      layerPanelOpened = false;
      delay(200);
      Serial.println("Layer panel closed");
    }
    
    Serial.println("Rotary encoder now controls brush size");
    resetLayerState();
    
    // Single long blink for brush mode
    digitalWrite(LED_PIN, HIGH);
    delay(300);
    digitalWrite(LED_PIN, LOW);
  }
  
  Serial.print("Current mode: ");
  Serial.println(currentMode == BRUSH_MODE ? "BRUSH" : "LAYER");
}

// Visual indication for layer mode
void indicateLayerMode() {
  // Triple blink pattern for layer mode
  for (int i = 0; i < LAYER_MODE_BLINK_PATTERN; i++) {
    digitalWrite(LED_PIN, HIGH);
    delay(150);
    digitalWrite(LED_PIN, LOW);
    delay(150);
  }
}

// Reset layer state when switching back to brush mode
void resetLayerState() {
  lastLayerEncoderPos = encoderPos;
  lastLayerCommandTime = 0;
  layerModeProcessed = false;
  layerPanelOpened = false;
  currentLayerKeyMode = ARROW_KEYS;
  layerKeyAttempts = 0;
}

// Get current mode as string for debugging
const char* getCurrentModeString() {
  return (currentMode == BRUSH_MODE) ? "BRUSH" : "LAYER";
}

// Function prototypes
void updateBrushZone(int direction);

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
  void onConnect(BLEServer* server) { 
    connected = true; 
    Serial.println("==================================");
    Serial.println("CONNECTED TO iOS DEVICE!");
    Serial.println("Now able to send keyboard commands");
    Serial.println("==================================");
    
    // Visual feedback for connection
    digitalWrite(LED_PIN, HIGH);
    delay(500);
    digitalWrite(LED_PIN, LOW);
  }
  
  void onDisconnect(BLEServer* server) { 
    connected = false; 
    Serial.println("==================================");
    Serial.println("DISCONNECTED from iOS device");
    Serial.println("Waiting for reconnection...");
    Serial.println("==================================");
    
    // Flash LED to indicate disconnection
    for (int i = 0; i < 3; i++) {
      digitalWrite(LED_PIN, HIGH);
      delay(100);
      digitalWrite(LED_PIN, LOW);
      delay(100);
    }
    
    server->startAdvertising();
    Serial.println("Started advertising for new connections");
  }
};

// Send a key combination (modifier + key)
void sendKeyCombo(uint8_t mod, uint8_t key) {
  if (!connected) {
    Serial.println("ERROR: Cannot send key - not connected");
    return;
  }
  
  Serial.print("Sending key combo - Modifier: 0x");
  Serial.print(mod, HEX);
  Serial.print(", Key: 0x");
  Serial.println(key, HEX);
  
  uint8_t msg[] = {mod, 0, key, 0, 0, 0, 0, 0};
  inputKeyboard->setValue(msg, sizeof(msg));
  inputKeyboard->notify();
  delay(20);
  
  uint8_t msg2[] = {0, 0, 0, 0, 0, 0, 0, 0};
  inputKeyboard->setValue(msg2, sizeof(msg2));
  inputKeyboard->notify();
  
  Serial.println("Key sent successfully");
}

// Send a single key without modifiers
void sendSingleKey(uint8_t key) {
  sendKeyCombo(0, key);
}

// Get required clicks based on current zone
int getRequiredClicks() {
  switch(brushSizeZone) {
    case 0: return EXTREME_FINE_SPEED; // Extreme fine control
    case 1: return VERY_FINE_SPEED;    // Very fine control
    case 2: return FINE_SPEED;         // Fine control
    case 3: return MEDIUM_SPEED;       // Medium control
    case 4: return COARSE_SPEED;       // Coarse control
    case 5: return VERY_COARSE_SPEED;  // Very coarse control
    default: return FINE_SPEED;        // Default to fine control
  }
}

// Send bracket key for brush size adjustment
void adjustBrushSize(bool increase) {
  if (!connected) return;
  
  if (increase) {
    sendSingleKey(KEY_RIGHT_BRACKET); // Increase brush size
    Serial.println("Increased brush size");
  } else {
    sendSingleKey(KEY_LEFT_BRACKET); // Decrease brush size
    Serial.println("Decreased brush size");
  }
  lastKeyPressTime = millis();
}

// Process encoder movement for brush size control
void processBrushSize() {
  int currentEncoderPos = encoderPos;
  int movement = currentEncoderPos - lastEncoderPos;
  
  if (movement != 0) {
    // Accumulate clicks
    clickCounter += abs(movement);
    
    // When we have enough clicks for the current sensitivity, send a key press
    int requiredClicks = getRequiredClicks();
    while (clickCounter >= requiredClicks) {
      clickCounter -= requiredClicks;
      adjustBrushSize(movement > 0);
      
      // Update zone counter
      if (movement > 0) {
        brushStepCounter++; // Moving toward larger brush
      } else {
        brushStepCounter--; // Moving toward smaller brush
      }
      
      // Check if we should change zones
      if (abs(brushStepCounter) >= ZONE_CHANGE_THRESHOLD) {
        updateBrushZone(movement > 0 ? 1 : -1);
      }
    }
    
    lastEncoderPos = currentEncoderPos;
  }
}

// Toggle between brush and eraser
void toggleEraser() {
  Serial.println("****** TOGGLE ERASER ******");
  
  // First, make sure we're connected
  if (connected) {
    // STEP 1: Press E key down for eraser
    Serial.println("STEP 1: Pressing E key for eraser...");
    uint8_t keyDown[] = {0, 0, KEY_E, 0, 0, 0, 0, 0}; // No modifier, just E key
    inputKeyboard->setValue(keyDown, sizeof(keyDown));
    inputKeyboard->notify();
    
    // Wait to ensure key is registered
    delay(100);
    
    // STEP 2: Release E key
    Serial.println("STEP 2: Releasing E key...");
    uint8_t keyUp[] = {0, 0, 0, 0, 0, 0, 0, 0};
    inputKeyboard->setValue(keyUp, sizeof(keyUp));
    inputKeyboard->notify();
    
    // Wait for key release to be processed
    delay(100);
    
    Serial.println("KEY SEQUENCE COMPLETED");
    
    // Toggle internal eraser mode state
    eraserMode = !eraserMode;
    Serial.print("Internal eraser mode toggled to: ");
    Serial.println(eraserMode ? "ON" : "OFF");
    
    // Visual feedback for eraser mode
    if (eraserMode) {
      // Double blink for eraser ON
      Serial.println("LED: Double blink for ERASER ON");
      digitalWrite(LED_PIN, HIGH);
      delay(100);
      digitalWrite(LED_PIN, LOW);
      delay(100);
      digitalWrite(LED_PIN, HIGH);
      delay(100);
      digitalWrite(LED_PIN, LOW);
    } else {
      // Single blink for eraser OFF
      Serial.println("LED: Single blink for ERASER OFF");
      digitalWrite(LED_PIN, HIGH);
      delay(200);
      digitalWrite(LED_PIN, LOW);
    }
  } else {
    Serial.println("ERROR: Not connected, cannot send key");
  }
  
  Serial.println("***************************");
}

// Process UNDO button
void processUndo() {
  // Skip undo processing if mode switching is in progress
  if (modeSwitchStartTime != 0) {
    return;
  }
  
  // Read the current state of the UNDO button
  bool currentUndoState = digitalRead(UNDO_PIN);
  
  // Debug the button state change - only log when state actually changes
  static bool lastDebugUndoState = HIGH;
  if (currentUndoState != lastDebugUndoState) {
    Serial.print("UNDO Button state changed: ");
    Serial.println(currentUndoState == HIGH ? "HIGH (released)" : "LOW (pressed)");
    lastDebugUndoState = currentUndoState;
    
    // If state changed, reset the debounce timer - but only log this once
    if (currentUndoState != lastUndoState) {
      Serial.println("Undo debounce timer reset");
      lastUndoDebounceTime = millis();
      lastUndoState = currentUndoState; // Update the state immediately to prevent multiple logs
    }
  }
  
  // If the state has been stable for longer than the debounce time
  unsigned long currentTime = millis();
  if ((currentTime - lastUndoDebounceTime) > DEBOUNCE_TIME) {
    // Button state is stable
    // Check if button is currently pressed (LOW) and was previously not recorded as pressed
    if (currentUndoState == LOW && !undoPressProcessed) {
      undoPressProcessed = true; // Mark that we've processed this press
      Serial.println("UNDO BUTTON PRESSED - DEBOUNCED");
      if (connected) {
        Serial.println("Sending Command+Z for Undo...");
        
        // Try using different bit for Command key (bit 3 = 0x08, bit 7 = 0x80)
        // On different BLE HID implementations, the modifier bits can vary
        uint8_t msg[] = {0x80, 0, KEY_Z, 0, 0, 0, 0, 0}; 
        inputKeyboard->setValue(msg, sizeof(msg));
        inputKeyboard->notify();
        delay(100); // Longer delay to ensure key is registered
        
        // Send key release
        uint8_t msg2[] = {0, 0, 0, 0, 0, 0, 0, 0};
        inputKeyboard->setValue(msg2, sizeof(msg2));
        inputKeyboard->notify();
        
        // Visual feedback
        digitalWrite(LED_PIN, HIGH);
        delay(100);
        digitalWrite(LED_PIN, LOW);
      } else {
        Serial.println("Not connected - cannot send Undo command");
      }
    }
    // Reset the flag when button is released
    if (currentUndoState == HIGH) {
      undoPressProcessed = false;
    }
  }
}

// Process ERASE button - completely rewritten for simplicity and reliability
void processErase() {
  // Skip erase processing if mode switching is in progress
  if (modeSwitchStartTime != 0) {
    return;
  }
  
  static bool buttonActive = false;
  static unsigned long buttonPressTime = 0;
  
  // Read the current state of the ERASE button
  bool currentState = digitalRead(ERASE_PIN);
  
  // Button is pressed (LOW)
  if (currentState == LOW) {
    // If this is a new press, record the time
    if (!buttonActive) {
      buttonActive = true;
      buttonPressTime = millis();
      Serial.println("ERASE button press detected");
    }
    
    // Check if button has been held down long enough (debounce)
    if (buttonActive && (millis() - buttonPressTime) > DEBOUNCE_TIME) {
      // Only toggle once per press
      if (lastEraseState == HIGH) {
        Serial.println("ERASE BUTTON PRESS CONFIRMED");
        if (connected) {
          toggleEraser();
        } else {
          Serial.println("Not connected - cannot toggle eraser");
        }
        lastEraseState = LOW; // Mark as processed
      }
    }
  } 
  // Button is released (HIGH)
  else {
    // Reset button state when released
    if (buttonActive) {
      buttonActive = false;
      lastEraseState = HIGH; // Ready for next press
      Serial.println("ERASE button released");
    }
  }
}

// Process reset button
void processReset() {
  if (digitalRead(RESET_PIN) == LOW) {
    if (resetPressStartTime == 0) {
      // Button just pressed
      resetPressStartTime = millis();
    } else if (millis() - resetPressStartTime > RESET_DELAY) {
      // Long press detected, reset to smallest brush size
      if (connected) {
        // Send multiple bracket key presses to ensure minimum brush size
        for (int i = 0; i < 20; i++) {
          sendSingleKey(KEY_LEFT_BRACKET);
          delay(50);
        }
        Serial.println("Reset to minimum brush size");
        
        // Visual feedback
        for (int i = 0; i < 3; i++) {
          digitalWrite(LED_PIN, HIGH);
          delay(200);
          digitalWrite(LED_PIN, LOW);
          delay(200);
        }
        
        // Reset brush zone to extreme fine for precise control
        brushSizeZone = 0;
        brushStepCounter = 0;
        clickCounter = 0;
        
        // Don't trigger again until button is released and pressed again
        resetPressStartTime = millis();
      }
    }
  } else {
    // Button released
    resetPressStartTime = 0;
  }
}

// Update zone based on direction and current step count
void updateBrushZone(int direction) {
  brushStepCounter = 0;
  
  // Change zone if we've taken enough steps in current direction
  if (direction > 0) {
    brushSizeZone = min(brushSizeZone + 1, 5); // Move to coarser control
  } else {
    brushSizeZone = max(brushSizeZone - 1, 0); // Move to finer control
  }
  
  Serial.print("Changed to zone: ");
  Serial.println(brushSizeZone);
}

// Process mode switching (hold UNDO + ERASE buttons simultaneously)
void processModeSwitch() {
  bool undoPressed = (digitalRead(UNDO_PIN) == LOW);
  bool erasePressed = (digitalRead(ERASE_PIN) == LOW);
  
  // Both buttons pressed
  if (undoPressed && erasePressed) {
    if (modeSwitchStartTime == 0) {
      // Buttons just pressed together
      modeSwitchStartTime = millis();
      modeSwitchProcessed = false;
      Serial.println("Both buttons pressed - hold to switch modes...");
      
      // Start visual feedback - quick blink to show detection
      digitalWrite(LED_PIN, HIGH);
      delay(50);
      digitalWrite(LED_PIN, LOW);
    } else if (!modeSwitchProcessed && (millis() - modeSwitchStartTime >= MODE_SWITCH_DELAY)) {
      // Long press detected, switch modes
      Serial.println("Mode switch delay reached - switching modes!");
      
      // Visual feedback before switching
      for (int i = 0; i < 2; i++) {
        digitalWrite(LED_PIN, HIGH);
        delay(100);
        digitalWrite(LED_PIN, LOW);
        delay(100);
      }
      
      switchControlMode();
      modeSwitchProcessed = true;
      Serial.println("Mode switch activated!");
    } else {
      // Show progress during hold - blink every 250ms
      static unsigned long lastProgressBlink = 0;
      if (millis() - lastProgressBlink > 250) {
        digitalWrite(LED_PIN, HIGH);
        delay(25);
        digitalWrite(LED_PIN, LOW);
        lastProgressBlink = millis();
      }
    }
  } else {
    // Reset mode switch state when buttons are released
    if (modeSwitchStartTime != 0) {
      unsigned long holdTime = millis() - modeSwitchStartTime;
      if (!modeSwitchProcessed && holdTime < MODE_SWITCH_DELAY) {
        Serial.print("Buttons released too early (held for ");
        Serial.print(holdTime);
        Serial.print("ms, needed ");
        Serial.print(MODE_SWITCH_DELAY);
        Serial.println("ms)");
        
        // Visual feedback for failed attempt
        digitalWrite(LED_PIN, HIGH);
        delay(200);
        digitalWrite(LED_PIN, LOW);
      }
      modeSwitchStartTime = 0;
      modeSwitchProcessed = false;
    }
  }
}

void setup() {
  Serial.begin(115200);
  delay(1000); // Longer delay to ensure serial is ready
  
  // Print a test message to verify serial is working
  Serial.println("**************************");
  Serial.println("SERIAL MONITOR TEST");
  Serial.println("**************************");
  
  Serial.println("\n\n=== Procreate Combined Controller ===");
  Serial.println("Features:");
  Serial.println("1. Rotary encoder - Adjust brush size");
  Serial.println("2. UNDO button - Performs undo command (CMD+Z)");
  Serial.println("3. ERASE button - Toggles between brush and eraser (E key)");
  Serial.println("4. RESET button - Long press to reset to minimum brush size");
  
  Serial.println("\n** IMPORTANT **");
  Serial.println("Make sure in Procreate:");
  Serial.println("1. The app is open and active");
  Serial.println("2. You are in the drawing mode (not selection mode)");
  Serial.println("3. The E key is set to toggle eraser (standard shortcut)");
  Serial.println("**************");
  Serial.println("\nBrush size sensitivity zones:");
  Serial.println("- 0: Extreme Fine (25 clicks per step)");
  Serial.println("- 1: Very Fine (15 clicks per step)");
  Serial.println("- 2: Fine (8 clicks per step)");
  Serial.println("- 3: Medium (4 clicks per step)");
  Serial.println("- 4: Coarse (2 clicks per step)");
  Serial.println("- 5: Very Coarse (1 click per step)");
  Serial.println("Sensitivity automatically adjusts based on how quickly you're turning the knob");
  Serial.println("\n** NEW LAYER NAVIGATION **");
  Serial.println("Hold UNDO + ERASE buttons for 1 second to switch modes:");
  Serial.println("- BRUSH MODE: Encoder controls brush size (default)");
  Serial.println("- LAYER MODE: Encoder navigates through layers");
  Serial.println("***************************");
  
  // Configure pins
  pinMode(UNDO_PIN, INPUT_PULLUP);
  pinMode(ERASE_PIN, INPUT_PULLUP);
  pinMode(RESET_PIN, INPUT_PULLUP);
  pinMode(ENCODER_PIN_A, INPUT_PULLUP);
  pinMode(ENCODER_PIN_B, INPUT_PULLUP);
  pinMode(LED_PIN, OUTPUT);
  
  // Setup encoder interrupt handlers
  attachInterrupt(digitalPinToInterrupt(ENCODER_PIN_A), handleEncoder, CHANGE);
  attachInterrupt(digitalPinToInterrupt(ENCODER_PIN_B), handleEncoder, CHANGE);
  
  // Show startup pattern
  for (int i = 0; i < 2; i++) {
    digitalWrite(LED_PIN, HIGH);
    delay(100);
    digitalWrite(LED_PIN, LOW);
    delay(100);
  }
  
  // Initialize BLE
  BLEDevice::init("ProcreateKey");
  BLEServer* server = BLEDevice::createServer();
  server->setCallbacks(new ServerCallbacks());
  
  hid = new BLEHIDDevice(server);
  inputKeyboard = hid->inputReport(1); // Report ID 1
  
  // Set manufacturer name
  hid->manufacturer()->setValue("MakerEasy");
  hid->pnp(0x01, 0x02e5, 0xabcd, 0x0110);
  hid->hidInfo(0x00,0x01);
  
  // Security settings
  BLESecurity* security = new BLESecurity();
  security->setAuthenticationMode(ESP_LE_AUTH_BOND);
  
  // Set report map
  hid->reportMap((uint8_t*)hidReportMap, sizeof(hidReportMap));
  hid->startServices();
  
  // Advertise the device
  BLEAdvertising* advertising = server->getAdvertising();
  advertising->setAppearance(HID_KEYBOARD);
  advertising->addServiceUUID(hid->hidService()->getUUID());
  advertising->start();
  
  Serial.println("Waiting for connection...");
  
  // Initialize layer handler
  initializeLayerHandler();
  
  // Disable WiFi to reduce ADC noise (ESP32 specific)
  WiFi.mode(WIFI_OFF);
}

// Debug variables
unsigned long lastDebugTime = 0;
const unsigned long DEBUG_INTERVAL = 5000; // Print debug info every 5 seconds

void loop() {
  // Process mode switching first (hold both buttons)
  processModeSwitch();
  
  // Process encoder input based on current mode
  if (currentMode == BRUSH_MODE) {
    processBrushSize();
  } else {
    processLayerNavigation();
  }
  
  // Process button inputs (only if not switching modes)
  // Note: The individual button functions now check modeSwitchStartTime internally
  processUndo();
  processErase();
  processReset();
  
  // Debug output periodically
  unsigned long currentMillis = millis();
  if (currentMillis - lastDebugTime > DEBUG_INTERVAL) {
    lastDebugTime = currentMillis;
    Serial.println("--------------------------------");
    Serial.print("DEBUG: Time: ");
    Serial.print(currentMillis / 1000);
    Serial.print("s, Connected: ");
    Serial.print(connected ? "YES" : "NO");
    Serial.print(", Mode: ");
    Serial.print(getCurrentModeString());
    Serial.print(", Eraser: ");
    Serial.print(eraserMode ? "ON" : "OFF");
    Serial.print(", Encoder: ");
    Serial.print(encoderPos);
    Serial.print(", Zone: ");
    Serial.println(brushSizeZone);
    Serial.println("--------------------------------");
  }
  
  // Small delay to prevent excessive CPU usage
  delay(5);
}