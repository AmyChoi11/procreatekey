/*
 * TFT Image Display - XIAO ESP32-S3
 * Displays testingimage image FULL SCREEN
 */

#include <Adafruit_GFX.h>
#include <Adafruit_ST7789.h>
#include <SPI.h>
#include "testingimage_image.h"

// TFT pins (confirmed working from diagnostic)
#define TFT_CS   3
#define TFT_DC   1
#define TFT_RST  5
#define TFT_BL   6

// Initialize display
Adafruit_ST7789 tft = Adafruit_ST7789(TFT_CS, TFT_DC, TFT_RST);

void setup() {
  Serial.begin(115200);
  delay(2000);
  
  Serial.println("=== Full Screen TFT Image Display ===");
  Serial.println("Image: testingimage");
  
  // Initialize TFT with PERFECT configuration (from diagnostic results)
  pinMode(TFT_BL, OUTPUT);
  digitalWrite(TFT_BL, HIGH);
  
  tft.init(135, 240);  // Swapped initialization (working config)
  tft.setRotation(1);  // Rotation 1 = perfect 240x135 full screen
  tft.fillScreen(ST77XX_BLACK);
  
  Serial.println("TFT initialized - Full screen mode");
  
  // Show loading message
  tft.setTextColor(ST77XX_WHITE);
  tft.setTextSize(2);
  tft.setCursor(50, 50);
  tft.println("Loading...");
  
  delay(1000);
  
  // Display the image FULL SCREEN
  displayImageFullScreen();
  
  Serial.println("Image displayed full screen!");
}

void loop() {
  // Static display - image stays on screen
  delay(1000);
}

void displayImageFullScreen() {
  Serial.println("Drawing image to TFT FULL SCREEN...");
  
  // Display image data directly to TFT at position (0,0) - FULL SCREEN
  tft.drawRGBBitmap(0, 0, img_testingimage_data, 240, 135);
  
  // Optional: Add subtle image info overlay in corner
  showImageInfo();
}

void showImageInfo() {
  // Optional: Show image info in corner with semi-transparent background
  tft.fillRect(0, 0, 80, 25, ST77XX_BLACK);
  tft.setTextColor(ST77XX_WHITE);
  tft.setTextSize(1);
  tft.setCursor(5, 5);
  tft.print("testingimage");
  
  tft.setCursor(5, 15);
  tft.print("240x135 FULL");
}