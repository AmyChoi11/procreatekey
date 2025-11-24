import SwiftUI
import CoreBluetooth

struct ContentView: View {
    @StateObject private var bleManager = BLEManager()
    @Environment(\.scenePhase) private var scenePhase
    @AppStorage("hasCompletedOnboarding") private var hasCompletedOnboarding = false
    
    // Store configuration as numeric codes - UPDATED DEFAULT SETTINGS
    @State private var config: [String: Int] = ["button1": 3, "button2": 5, "combo": 8, "scroll": 6]  // Undo, Erase, Brush Library, Brush Size 5%
    @State private var showDeviceSheet = false
    @State private var hasShownInitialSheet = false
    @State private var showOnboarding = false
    @State private var showInteractiveTutorial = false
    @State private var showHelp = false
    
    // Store actual view frames for tutorial
    @State private var button1Frame: CGRect = .zero
    @State private var button2Frame: CGRect = .zero
    @State private var scrollFrame: CGRect = .zero
    @State private var comboFrame: CGRect = .zero
    @State private var scanButtonFrame: CGRect = .zero
    
    // State for showing dropdowns
    @State private var showScrollDropdown = false
    @State private var showButton1Dropdown = false
    @State private var showButton2Dropdown = false
    @State private var showComboDropdown = false
    @State private var showCustomsDropdown = false
    @State private var showHelpDropdown = false
    
    // Preset system - RENAMED TO CUSTOMS
    @AppStorage("custom1") private var custom1Data: String = ""
    @AppStorage("custom2") private var custom2Data: String = ""
    @State private var showSaveCustomAlert = false
    @State private var customToSave: Int = 1
    
    // Combined options for all buttons (excluding brush size settings for buttons)
    let allButtonOptions = ["Undo", "Redo", "Erase", "Color Palette", "Brush Library"]
    var circleButton1Options: [String] { allButtonOptions }
    var circleButton2Options: [String] { allButtonOptions }
    var buttons12Options: [String] { allButtonOptions }
    
    // UPDATED SCROLL OPTIONS WITH NEW NAMES
    let scrollOptions = ["Brush Size ±5%", "Brush Size ±10%"]
    
    // Preset structure - RENAMED TO CUSTOM
    struct Custom: Identifiable {
        let id: Int
        let name: String
        let config: [String: Int]
    }
    
    var customs: [Custom] {
        var availableCustoms: [Custom] = []
        
        if let custom1 = loadCustom(from: custom1Data) {
            availableCustoms.append(Custom(id: 1, name: "Custom 1", config: custom1))
        }
        
        if let custom2 = loadCustom(from: custom2Data) {
            availableCustoms.append(Custom(id: 2, name: "Custom 2", config: custom2))
        }
        
        return availableCustoms
    }
    
    // DEFAULT CONFIGURATION
    private let defaultConfig: [String: Int] = ["button1": 3, "button2": 5, "combo": 8, "scroll": 6]  // Undo, Erase, Brush Library, Brush Size 5%
    
    var body: some View {
        ZStack {
            mainNavigationView
                .sheet(isPresented: $showDeviceSheet) {
                    DeviceSelectionSheet(bleManager: bleManager, showDeviceSheet: $showDeviceSheet)
                }
                .sheet(isPresented: $showOnboarding) {
                    OnboardingView(showOnboarding: $showOnboarding)
                }
                .sheet(isPresented: $showHelp) {
                    HelpView()
                        .environmentObject(bleManager)
                }
                .actionSheet(isPresented: $showSaveCustomAlert) {
                    saveCustomActionSheet
                }
                .onAppear {
                    handleOnAppear()
                }
                .onChange(of: scenePhase) { newPhase in
                    switch newPhase {
                    case .background:
                        print("📱 App going to background, disconnecting...")
                        if bleManager.isConnected {
                            bleManager.disconnect()
                        }
                    case .inactive:
                        print("📱 App inactive")
                    case .active:
                        print("📱 App active")
                    @unknown default:
                        break
                    }
                }
                .onChange(of: bleManager.detectedProblem) { problem in
                    if problem != nil {
                        showHelp = true
                    }
                }
            
            // Tutorial overlay at top level to cover navigation bar
            if showInteractiveTutorial {
                InteractiveTutorialView(
                    showTutorial: $showInteractiveTutorial,
                    hasCompletedOnboarding: $hasCompletedOnboarding,
                    scanButtonFrame: scanButtonFrame,
                    button1Frame: button1Frame,
                    button2Frame: button2Frame,
                    scrollFrame: scrollFrame,
                    comboFrame: comboFrame
                )
            }
        }
    }
    
    private var mainNavigationView: some View {
        NavigationStack {
            mainContentView
            .toolbar {
                toolbarContent
            }
            .toolbarBackground(Color(red: 0.4, green: 0.2, blue: 0.6), for: .navigationBar)
            .toolbarBackground(.visible, for: .navigationBar)
            .toolbarColorScheme(.dark, for: .navigationBar)
        }
        .onReceive(bleManager.$isConnected) { connected in
            if connected {
                showDeviceSheet = false
            }
        }
        .onReceive(bleManager.$currentConfig) { newConfig in
            print("📥 Loading configuration from device: \(newConfig)")
            self.config = newConfig
        }
    }
    
    private var mainContentView: some View {
        ZStack {
                // Background color
                Color(red: 0.95, green: 0.95, blue: 0.97)
                    .ignoresSafeArea()
                
                ScrollView {
                    VStack(spacing: 30) {
                        // Simulator warning
                        #if targetEnvironment(simulator)
                        VStack(spacing: 12) {
                            Image(systemName: "exclamationmark.triangle.fill")
                                .font(.system(size: 40))
                                .foregroundColor(.orange)
                            Text("Simulator Limitation")
                                .font(.headline)
                                .foregroundColor(.orange)
                            Text("Bluetooth is not supported in the iOS Simulator. Please build and run this app on a real iPad or iPhone to test Bluetooth functionality.")
                                .font(.subheadline)
                                .foregroundColor(.secondary)
                                .multilineTextAlignment(.center)
                                .padding(.horizontal)
                        }
                        .padding()
                        .background(
                            RoundedRectangle(cornerRadius: 12)
                                .fill(Color.orange.opacity(0.1))
                        )
                        .padding(.horizontal)
                        #endif
                        
                        // Controller Diagram Section
                        VStack(spacing: 20) {
                            Text("Controller Configuration")
                                .font(.title2)
                                .fontWeight(.bold)
                                .foregroundColor(Color(red: 0.4, green: 0.2, blue: 0.6))
                            
                            ZStack {
                                // Controller Background - Made larger to take up 1/4 of section
                                RoundedRectangle(cornerRadius: 25)
                                    .fill(Color.white)
                                    .frame(height: 410) // Increased height for larger diagram
                                    .shadow(color: Color.black.opacity(0.1), radius: 8, x: 0, y: 4)
                                
                                // Orange connection lines - Positioned above the outline - MOVED TO BOTTOM
                                connectionLines
                                
                                // Nintendo Switch Controller Outline - With smaller cylindrical grips
                                controllerOutline
                                
                                VStack(spacing: 30) {
                                    // Top: Button 1 - Scroll - Button 2
                                    HStack(spacing: 10) { // CHANGED FROM 30 TO 10 (MOVED BUTTONS 20 CLOSER ON EACH SIDE)
                                        // Button 1 - Larger
                                        VStack(spacing: 8) {
                                            // INCREASED SIZE OF CURRENT CONFIG DISPLAY
                                            Text(getCurrentSelection(for: "button1"))
                                                .font(.system(size: 16, weight: .medium)) // Increased from 12 to 16
                                                .foregroundColor(.blue)
                                                .padding(.horizontal, 12) // Increased padding
                                                .padding(.vertical, 6) // Increased padding
                                                .background(Color.blue.opacity(0.1))
                                                .cornerRadius(6)
                                                .fixedSize(horizontal: false, vertical: true)
                                                .frame(maxWidth: 120) // Increased from 100 to 120
                                            
                                            Button(action: {
                                                showButton1Dropdown = true
                                            }) {
                                                Circle()
                                                    .fill(Color.blue.opacity(0.3))
                                                    .frame(width: 80, height: 80)
                                                    .overlay(
                                                        Text("1")
                                                            .font(.system(size: 24, weight: .bold))
                                                            .foregroundColor(.blue)
                                                    )
                                            }
                                            .buttonStyle(PlainButtonStyle())
                                            .background(GeometryReader { geo in
                                                Color.clear.preference(key: ViewFrameKey.self, value: geo.frame(in: .global))
                                            })
                                            .onPreferenceChange(ViewFrameKey.self) { frame in
                                                button1Frame = frame
                                            }
                                            .popover(isPresented: $showButton1Dropdown, attachmentAnchor: .point(.bottom), arrowEdge: .top) {
                                                VStack(spacing: 0) {
                                                    ForEach(circleButton1Options, id: \.self) { option in
                                                        Button(action: {
                                                            config["button1"] = optionToCode(option)
                                                            saveConfigurationIfConnected()
                                                            showButton1Dropdown = false
                                                        }) {
                                                            Text(option)
                                                                .foregroundColor(.primary)
                                                                .frame(maxWidth: .infinity, alignment: .leading)
                                                                .padding(.horizontal, 16)
                                                                .padding(.vertical, 12)
                                                        }
                                                        if option != circleButton1Options.last {
                                                            Divider()
                                                        }
                                                    }
                                                }
                                                .padding(.vertical, 8)
                                                .background(Color.white)
                                                .cornerRadius(12)
                                                .shadow(radius: 5)
                                                .frame(width: 150)
                                            }
                                            
                                            Text("Button 1")
                                                .font(.system(size: 16, weight: .semibold))
                                                .foregroundColor(.blue)
                                        }
                                        
                                        // Scroll - Pill/Capsule shape WITH UP/DOWN ARROWS
                                        VStack(spacing: 8) {
                                            // INCREASED SIZE OF CURRENT CONFIG DISPLAY WITH WIDER WIDTH
                                            Text(getCurrentSelection(for: "scroll"))
                                                .font(.system(size: 16, weight: .medium)) // Increased from 12 to 16
                                                .foregroundColor(Color(red: 0.4, green: 0.2, blue: 0.6))
                                                .padding(.horizontal, 12) // Increased padding
                                                .padding(.vertical, 6) // Increased padding
                                                .background(Color(red: 0.4, green: 0.2, blue: 0.6).opacity(0.1))
                                                .cornerRadius(6)
                                                .fixedSize(horizontal: false, vertical: true)
                                                .frame(maxWidth: 180) // INCREASED WIDTH from 140 to 180 to fit entire text
                                            
                                            Button(action: {
                                                showScrollDropdown = true
                                            }) {
                                                ZStack {
                                                    // Main pill-shaped body
                                                    Capsule()
                                                        .fill(Color(red: 0.4, green: 0.2, blue: 0.6).opacity(0.3))
                                                        .frame(width: 60, height: 100)
                                                    
                                                    // Outer border
                                                    Capsule()
                                                        .stroke(Color(red: 0.4, green: 0.2, blue: 0.6).opacity(0.5), lineWidth: 4)
                                                        .frame(width: 60, height: 100)
                                                    
                                                    // UP/DOWN ARROWS ADDED
                                                    VStack(spacing: 4) {
                                                        Image(systemName: "chevron.up")
                                                            .font(.system(size: 16, weight: .bold))
                                                            .foregroundColor(Color(red: 0.4, green: 0.2, blue: 0.6))
                                                        
                                                        Image(systemName: "chevron.down")
                                                            .font(.system(size: 16, weight: .bold))
                                                            .foregroundColor(Color(red: 0.4, green: 0.2, blue: 0.6))
                                                    }
                                                }
                                            }
                                            .buttonStyle(PlainButtonStyle())
                                            .background(GeometryReader { geo in
                                                Color.clear.preference(key: ScrollFrameKey.self, value: geo.frame(in: .global))
                                            })
                                            .onPreferenceChange(ScrollFrameKey.self) { frame in
                                                scrollFrame = frame
                                            }
                                            .popover(isPresented: $showScrollDropdown, attachmentAnchor: .point(.bottom), arrowEdge: .top) {
                                                VStack(spacing: 0) {
                                                    ForEach(scrollOptions, id: \.self) { option in
                                                        Button(action: {
                                                            config["scroll"] = optionToCode(option)
                                                            saveConfigurationIfConnected()
                                                            showScrollDropdown = false
                                                        }) {
                                                            Text(option)
                                                                .foregroundColor(.primary)
                                                                .frame(maxWidth: .infinity, alignment: .leading)
                                                                .padding(.horizontal, 16)
                                                                .padding(.vertical, 12)
                                                        }
                                                        if option != scrollOptions.last {
                                                            Divider()
                                                        }
                                                    }
                                                }
                                                .padding(.vertical, 8)
                                                .background(Color.white)
                                                .cornerRadius(12)
                                                .shadow(radius: 5)
                                                .frame(width: 200)
                                            }
                                            
                                            Text("Scroll")
                                                .font(.system(size: 16, weight: .semibold))
                                                .foregroundColor(Color(red: 0.4, green: 0.2, blue: 0.6))
                                        }
                                        
                                        // Button 2 - Larger
                                        VStack(spacing: 8) {
                                            // INCREASED SIZE OF CURRENT CONFIG DISPLAY
                                            Text(getCurrentSelection(for: "button2"))
                                                .font(.system(size: 16, weight: .medium)) // Increased from 12 to 16
                                                .foregroundColor(.red)
                                                .padding(.horizontal, 12) // Increased padding
                                                .padding(.vertical, 6) // Increased padding
                                                .background(Color.red.opacity(0.1))
                                                .cornerRadius(6)
                                                .fixedSize(horizontal: false, vertical: true)
                                                .frame(maxWidth: 120) // Increased from 100 to 120
                                            
                                            Button(action: {
                                                showButton2Dropdown = true
                                            }) {
                                                Circle()
                                                    .fill(Color.red.opacity(0.3))
                                                    .frame(width: 80, height: 80)
                                                    .overlay(
                                                        Text("2")
                                                            .font(.system(size: 24, weight: .bold))
                                                            .foregroundColor(.red)
                                                    )
                                            }
                                            .buttonStyle(PlainButtonStyle())
                                            .background(GeometryReader { geo in
                                                Color.clear.preference(key: Button2FrameKey.self, value: geo.frame(in: .global))
                                            })
                                            .onPreferenceChange(Button2FrameKey.self) { frame in
                                                button2Frame = frame
                                            }
                                            .popover(isPresented: $showButton2Dropdown, attachmentAnchor: .point(.bottom), arrowEdge: .top) {
                                                VStack(spacing: 0) {
                                                    ForEach(circleButton2Options, id: \.self) { option in
                                                        Button(action: {
                                                            config["button2"] = optionToCode(option)
                                                            saveConfigurationIfConnected()
                                                            showButton2Dropdown = false
                                                        }) {
                                                            Text(option)
                                                                .foregroundColor(.primary)
                                                                .frame(maxWidth: .infinity, alignment: .leading)
                                                                .padding(.horizontal, 16)
                                                                .padding(.vertical, 12)
                                                        }
                                                        if option != circleButton2Options.last {
                                                            Divider()
                                                        }
                                                    }
                                                }
                                                .padding(.vertical, 8)
                                                .background(Color.white)
                                                .cornerRadius(12)
                                                .shadow(radius: 5)
                                                .frame(width: 150)
                                            }
                                            
                                            Text("Button 2")
                                                .font(.system(size: 16, weight: .semibold))
                                                .foregroundColor(.red)
                                        }
                                    }
                                    .padding(.top, 20)
                                    
                                    // Bottom: Buttons 1+2 Combo Text - MOVED TO BOTTOM
                                    VStack(spacing: 8) {
                                        // SWITCHED ORDER: BUTTON NOW ABOVE CONFIG DISPLAY
                                        Button(action: {
                                            showComboDropdown = true
                                        }) {
                                            Text("Buttons 1 + 2 Combo")
                                                .font(.system(size: 18, weight: .semibold))
                                                .foregroundColor(.white)
                                                .padding(.horizontal, 24)
                                                .padding(.vertical, 12)
                                                .background(Color.orange)
                                                .cornerRadius(8)
                                        }
                                        .buttonStyle(PlainButtonStyle())
                                        .background(GeometryReader { geo in
                                            Color.clear.preference(key: ComboFrameKey.self, value: geo.frame(in: .global))
                                        })
                                        .onPreferenceChange(ComboFrameKey.self) { frame in
                                            comboFrame = frame
                                        }
                                        .popover(isPresented: $showComboDropdown, attachmentAnchor: .point(.top), arrowEdge: .bottom) {
                                            VStack(spacing: 0) {
                                                ForEach(buttons12Options, id: \.self) { option in
                                                    Button(action: {
                                                        config["combo"] = optionToCode(option)
                                                        saveConfigurationIfConnected()
                                                        showComboDropdown = false
                                                    }) {
                                                        Text(option)
                                                            .foregroundColor(.primary)
                                                            .frame(maxWidth: .infinity, alignment: .leading)
                                                            .padding(.horizontal, 16)
                                                            .padding(.vertical, 12)
                                                    }
                                                    if option != buttons12Options.last {
                                                        Divider()
                                                    }
                                                }
                                            }
                                            .padding(.vertical, 8)
                                            .background(Color.white)
                                            .cornerRadius(12)
                                            .shadow(radius: 5)
                                            .frame(width: 180)
                                        }
                                        
                                        // CONFIG DISPLAY NOW BELOW THE BUTTON
                                        Text(getCurrentSelection(for: "combo"))
                                            .font(.system(size: 16, weight: .medium))
                                            .foregroundColor(.orange)
                                            .padding(.horizontal, 12)
                                            .padding(.vertical, 6)
                                            .background(Color.orange.opacity(0.1))
                                            .cornerRadius(6)
                                            .fixedSize(horizontal: false, vertical: true)
                                            .frame(maxWidth: 180) // Wider to accommodate combo options
                                    }
                                    .offset(y: 20) // Adjusted position for bottom placement
                                }
                            }
                            .frame(height: 320)
                            
                            // Save Custom Button - RENAMED FROM PRESET
                            Button(action: {
                                showSaveCustomAlert = true
                            }) {
                                HStack(spacing: 8) {
                                    Image(systemName: "square.and.arrow.down")
                                        .font(.system(size: 16))
                                    Text("Save as Custom")
                                        .font(.system(size: 16, weight: .semibold))
                                }
                                .foregroundColor(.white)
                                .padding(.horizontal, 20)
                                .padding(.vertical, 12)
                                .background(Color.green)
                                .cornerRadius(10)
                            }
                            .padding(.top, 60)
                        }
                        .padding(.top, 15) // Added padding to move entire section down by 15
                        .padding(.horizontal)
                        
                        if bleManager.isConnected {
                            VStack(spacing: 8) {
                                Image(systemName: "info.circle.fill")
                                    .font(.system(size: 24))
                                    .foregroundColor(.blue)
                                Text("⚠️ While connected, do NOT press the RESET button on the device. It will disconnect and restart.")
                                    .font(.caption)
                                    .multilineTextAlignment(.center)
                                    .foregroundColor(.secondary)
                            }
                            .padding()
                            .background(RoundedRectangle(cornerRadius: 12).fill(Color.blue.opacity(0.1)))
                            .padding(.horizontal)
                            .padding(.top, 60)
                        }
                        
                        // Status Message with Red/Green styling
                        if !bleManager.statusMessage.isEmpty {
                            VStack(spacing: 8) {
                                Image(systemName: bleManager.statusMessage.contains("✓") || bleManager.statusMessage.contains("successfully") ? "checkmark.circle.fill" : "xmark.circle.fill")
                                    .font(.system(size: 32))
                                    .foregroundColor(bleManager.statusMessage.contains("✓") || bleManager.statusMessage.contains("successfully") ? .green : .red)
                                Text(bleManager.statusMessage).multilineTextAlignment(.center).padding()
                            }
                            .frame(maxWidth: .infinity)
                            .background(
                                RoundedRectangle(cornerRadius: 12)
                                    .fill((bleManager.statusMessage.contains("✓") || bleManager.statusMessage.contains("successfully")) ? Color.green.opacity(0.1) : Color.red.opacity(0.1))
                            )
                            .overlay(
                                RoundedRectangle(cornerRadius: 12)
                                    .stroke((bleManager.statusMessage.contains("✓") || bleManager.statusMessage.contains("successfully")) ? Color.green.opacity(0.3) : Color.red.opacity(0.3), lineWidth: 1)
                            )
                            .padding(.horizontal)
                        }
                    }
                    .padding(.vertical)
                }
            }
            .navigationTitle("eSketch Shortcuts")
            .navigationBarTitleDisplayMode(.inline)
    }
    
    @ToolbarContentBuilder
    private var toolbarContent: some ToolbarContent {
        // Left toolbar - Bluetooth Scan/Connect button styled like Customs
        ToolbarItem(placement: .navigationBarLeading) {
                    HStack(spacing: 10) {
                        // Bluetooth button styled like Customs
                        Button(action: {
                            if bleManager.isConnected {
                                bleManager.disconnect()
                            } else if !bleManager.isScanning {
                                bleManager.startScan()
                                showDeviceSheet = true
                            }
                        }) {
                            HStack(spacing: 8) {
                                Image(systemName: "dot.radiowaves.left.and.right")
                                    .font(.system(size: 16, weight: .semibold))
                                    .foregroundColor(bleManager.isConnected ? Color.green : Color(red: 0.4, green: 0.2, blue: 0.6))
                                Text(bleManager.isConnected ? "Connected" : "Scan")
                                    .font(.system(size: 15, weight: .semibold))
                                    .foregroundColor(bleManager.isConnected ? Color.green : Color(red: 0.4, green: 0.2, blue: 0.6))
                            }
                            .padding(.horizontal, 12)
                            .padding(.vertical, 6)
                            .background(Color.white.opacity(0.9))
                            .cornerRadius(8)
                            .overlay(
                                RoundedRectangle(cornerRadius: 8)
                                    .stroke(
                                        bleManager.isConnected
                                            ? Color.green.opacity(0.6)
                                            : Color(red: 0.4, green: 0.2, blue: 0.6).opacity(0.6),
                                        lineWidth: 1.5
                                    )
                            )
                        }
                        .disabled(bleManager.isScanning)
                        .overlay(
                            GeometryReader { geo in
                                Color.clear.preference(key: ScanButtonFrameKey.self, value: geo.frame(in: .global))
                            }
                        )
                        .onPreferenceChange(ScanButtonFrameKey.self) { frame in
                            scanButtonFrame = frame
                        }
                    }
                }
                
                // Help button in separate ToolbarItem for proper popover positioning
                ToolbarItem(placement: .navigationBarLeading) {
                    Button(action: {
                        showHelpDropdown = true
                    }) {
                        Image(systemName: "questionmark.circle")
                            .foregroundColor(.white)
                            .font(.system(size: 18))
                    }
                    .popover(isPresented: $showHelpDropdown, arrowEdge: .top) {
                        helpMenuView
                            .presentationCompactAdaptation(.popover)
                    }
                }
                
                // Right toolbar - Customs button and Reset to Default button
                ToolbarItemGroup(placement: .navigationBarTrailing) {
                    // Reset to Default Button - SAME SIZE AS OTHER BUTTONS
                    Button(action: {
                        resetToDefault()
                    }) {
                        HStack(spacing: 6) {
                            Image(systemName: "arrow.clockwise")
                                .font(.system(size: 16, weight: .medium))
                            Text("Reset to Default")
                                .font(.system(size: 15, weight: .semibold))
                        }
                        .foregroundColor(Color(red: 0.4, green: 0.2, blue: 0.6))
                        .padding(.horizontal, 12)
                        .padding(.vertical, 6)
                        .background(Color.white.opacity(0.9))
                        .cornerRadius(8)
                        .overlay(
                            RoundedRectangle(cornerRadius: 8)
                                .stroke(Color(red: 0.4, green: 0.2, blue: 0.6).opacity(0.6), lineWidth: 1.5)
                        )
                    }
                    
                    // Customs Menu Button - RENAMED FROM PRESETS
                    Button(action: {
                        showCustomsDropdown = true
                    }) {
                        HStack(spacing: 6) {
                            Image(systemName: "list.bullet")
                                .font(.system(size: 16, weight: .medium))
                            Text("Customs")
                                .font(.system(size: 15, weight: .semibold))
                        }
                        .foregroundColor(Color(red: 0.4, green: 0.2, blue: 0.6))
                        .padding(.horizontal, 12)
                        .padding(.vertical, 6)
                        .background(Color.white.opacity(0.9))
                        .cornerRadius(8)
                        .overlay(
                            RoundedRectangle(cornerRadius: 8)
                                .stroke(Color(red: 0.4, green: 0.2, blue: 0.6).opacity(0.6), lineWidth: 1.5)
                        )
                    }
                    .popover(isPresented: $showCustomsDropdown, attachmentAnchor: .point(.bottom), arrowEdge: .top) {
                        customMenuView
                    }
                }
        }
    
    private var saveCustomActionSheet: ActionSheet {
        ActionSheet(
            title: Text("Save Current Configuration"),
            message: Text("Choose a custom slot to save your current configuration"),
            buttons: [
                .default(Text("Save as Custom 1")) {
                    saveCustom(slot: 1)
                },
                .default(Text("Save as Custom 2")) {
                    saveCustom(slot: 2)
                },
                .cancel()
            ]
        )
    }
    
    // MARK: - Lifecycle Methods
    private func handleOnAppear() {
        print("📱 ContentView appeared")
        print("📱 hasCompletedOnboarding: \(hasCompletedOnboarding)")
        print("📱 showInteractiveTutorial: \(showInteractiveTutorial)")
        print("📱 showDeviceSheet: \(showDeviceSheet)")
        
        // Show interactive tutorial only on first launch
        if !hasCompletedOnboarding {
            print("📱 🎓 Showing interactive tutorial for first time!")
            // Delay slightly to ensure view is ready
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.1) {
                showInteractiveTutorial = true
                print("📱 ✅ showInteractiveTutorial set to true")
            }
        } else {
            // Only show device selection sheet if onboarding is complete
            if !hasShownInitialSheet && !bleManager.isConnected {
                hasShownInitialSheet = true
                DispatchQueue.main.asyncAfter(deadline: .now() + 0.5) {
                    bleManager.startScan()
                    showDeviceSheet = true
                    print("📱 📡 Device sheet shown")
                }
            }
        }
    }
    
    // MARK: - NEW FUNCTION: Reset to Default
    func resetToDefault() {
        self.config = defaultConfig
        saveConfigurationIfConnected()
        print("🔄 Reset to default configuration: \(defaultConfig)")
    }
    
    // MARK: - Custom Menu View - RENAMED FROM PRESET
    var customMenuView: some View {
        VStack(spacing: 0) {
            Text("Saved Customs")
                .font(.headline)
                .foregroundColor(Color(red: 0.4, green: 0.2, blue: 0.6))
                .padding()
                .frame(maxWidth: .infinity)
                .background(Color.gray.opacity(0.1))
            
            if customs.isEmpty {
                Text("No customs saved")
                    .foregroundColor(.secondary)
                    .padding()
            } else {
                ForEach(customs) { custom in
                    Button(action: {
                        loadCustom(custom)
                        showCustomsDropdown = false
                    }) {
                        VStack(alignment: .leading, spacing: 8) {
                            Text(custom.name)
                                .font(.system(size: 16, weight: .semibold))
                                .foregroundColor(.black)
                            
                            VStack(alignment: .leading, spacing: 4) {
                                Text("Button 1: \(codeToOption(custom.config["button1"] ?? 0, validOptions: circleButton1Options))")
                                    .font(.system(size: 12))
                                    .foregroundColor(.black)
                                Text("Button 2: \(codeToOption(custom.config["button2"] ?? 0, validOptions: circleButton2Options))")
                                    .font(.system(size: 12))
                                    .foregroundColor(.black)
                                Text("Buttons 1 + 2: \(codeToOption(custom.config["combo"] ?? 0, validOptions: buttons12Options))")
                                    .font(.system(size: 12))
                                    .foregroundColor(.black)
                                Text("Scroll: \(codeToOption(custom.config["scroll"] ?? 0, validOptions: scrollOptions))")
                                    .font(.system(size: 12))
                                    .foregroundColor(.black)
                            }
                        }
                        .padding()
                        .frame(maxWidth: .infinity, alignment: .leading)
                        .background(Color.white)
                    }
                    
                    if custom.id != customs.last?.id {
                        Divider()
                    }
                }
            }
        }
        .background(Color.white)
        .cornerRadius(12)
        .shadow(radius: 5)
        .frame(width: 280)
    }
    
    // MARK: - Help Menu View
    var helpMenuView: some View {
        VStack(spacing: 0) {
            Text("Help")
                .font(.headline)
                .foregroundColor(Color(red: 0.4, green: 0.2, blue: 0.6))
                .padding()
                .frame(maxWidth: .infinity)
                .background(Color.gray.opacity(0.1))
            
            Button(action: {
                showHelpDropdown = false
                showHelp = true
            }) {
                HStack {
                    Image(systemName: "questionmark.circle")
                        .foregroundColor(Color(red: 0.4, green: 0.2, blue: 0.6))
                    Text("FAQ")
                        .font(.system(size: 16, weight: .semibold))
                        .foregroundColor(.black)
                }
                .padding()
                .frame(maxWidth: .infinity, alignment: .leading)
                .background(Color.white)
            }
            
            Divider()
            
            Button(action: {
                showHelpDropdown = false
                showInteractiveTutorial = true
            }) {
                HStack {
                    Image(systemName: "book.circle")
                        .foregroundColor(Color(red: 0.4, green: 0.2, blue: 0.6))
                    Text("First Time Guide")
                        .font(.system(size: 16, weight: .semibold))
                        .foregroundColor(.black)
                }
                .padding()
                .frame(maxWidth: .infinity, alignment: .leading)
                .background(Color.white)
            }
        }
        .background(Color.white)
        .cornerRadius(12)
        .shadow(radius: 5)
        .frame(width: 200)
    }
    
    // MARK: - Custom Functions - RENAMED FROM PRESET
    func loadCustom(from jsonString: String) -> [String: Int]? {
        guard !jsonString.isEmpty,
              let jsonData = jsonString.data(using: .utf8) else {
            return nil
        }
        
        do {
            let config = try JSONSerialization.jsonObject(with: jsonData, options: []) as? [String: Int]
            return config
        } catch {
            print("❌ Failed to load custom: \(error)")
            return nil
        }
    }
    
    func saveCustom(slot: Int) {
        do {
            let jsonData = try JSONSerialization.data(withJSONObject: config, options: [])
            let jsonString = String(data: jsonData, encoding: .utf8) ?? ""
            
            if slot == 1 {
                custom1Data = jsonString
            } else {
                custom2Data = jsonString
            }
            
            print("💾 Custom \(slot) saved: \(config)")
        } catch {
            print("❌ Failed to save custom: \(error)")
        }
    }
    
    func loadCustom(_ custom: Custom) {
        self.config = custom.config
        saveConfigurationIfConnected()
        print("📥 Loaded custom \(custom.id): \(custom.config)")
    }
    
    // MARK: - Controller Outline (With smaller cylindrical grips) - EXTENDED LENGTH BY 30% AND HEIGHT BY 25%, THEN SHORTENED FROM BOTTOM BY 10
    var controllerOutline: some View {
        GeometryReader { geometry in
            ZStack {
                let containerWidth = geometry.size.width
                let containerHeight = geometry.size.height
                let centerX = containerWidth / 2
                
                // Nintendo Switch Joy-Con style outline with smaller cylindrical grips
                Path { path in
                    // Main rectangular body - EXTENDED LENGTH BY 30% AND HEIGHT BY 25%, THEN SHORTENED FROM BOTTOM BY 10
                    let bodyWidth: CGFloat = 480 * 1.3 // EXTENDED LENGTH BY 30% (from 480 to 624)
                    let bodyHeight: CGFloat = (197.5 * 1.25) - 10 // EXTENDED HEIGHT BY 25% THEN SHORTENED FROM BOTTOM BY 10 (from 246.875 to 236.875)
                    let cornerRadius: CGFloat = 23.5 // Keep current corners
                    
                    let bodyRect = CGRect(
                        x: centerX - bodyWidth / 2,
                        y: containerHeight / 2 - bodyHeight / 2 - 30, // MOVED UP BY ANOTHER 20 (from -10 to -30)
                        width: bodyWidth,
                        height: bodyHeight
                    )
                    
                    // Rounded rectangle for the main body
                    path.addRoundedRect(
                        in: bodyRect,
                        cornerSize: CGSize(width: cornerRadius, height: cornerRadius)
                    )
                    
                    // Left grip extension - 0.5x smaller
                    let leftGripRect = CGRect(
                        x: centerX - bodyWidth / 2 - 22.5, // 0.5x smaller offset (from 45 to 22.5)
                        y: containerHeight / 2 - 72.5, // MOVED UP BY ANOTHER 20 (from -52.5 to -72.5)
                        width: 45, // 0.5x smaller width (from 90 to 45)
                        height: 90 // 0.5x smaller height (from 180 to 90)
                    )
                    path.addRoundedRect(
                        in: leftGripRect,
                        cornerSize: CGSize(width: 22.5, height: 22.5) // 0.5x smaller corners (from 45 to 22.5)
                    )
                    
                    // Right grip extension - 0.5x smaller
                    let rightGripRect = CGRect(
                        x: centerX + bodyWidth / 2 - 22.5, // 0.5x smaller offset (from 45 to 22.5)
                        y: containerHeight / 2 - 72.5, // MOVED UP BY ANOTHER 20 (from -52.5 to -72.5)
                        width: 45, // 0.5x smaller width (from 90 to 45)
                        height: 90 // 0.5x smaller height (from 180 to 90)
                    )
                    path.addRoundedRect(
                        in: rightGripRect,
                        cornerSize: CGSize(width: 22.5, height: 22.5) // 0.5x smaller corners (from 45 to 22.5)
                    )
                }
                .stroke(Color.gray.opacity(0.3), lineWidth: 4)
            }
        }
    }
    
    var connectionLines: some View {
        GeometryReader { geometry in
            ZStack {
                let containerWidth = geometry.size.width
                let centerX = containerWidth / 2
                
                // Orange lines positioned above the outline - MOVED TO BOTTOM AND FLIPPED
                let buttonSpacing: CGFloat = 10 // Using the actual spacing between buttons
                let button1CenterX = centerX - 60 // Button 1 center position (adjusted for new spacing)
                let button2CenterX = centerX + 60 // Button 2 center position (adjusted for new spacing)
                
                // Position lines to match the text position - MOVED DOWN BY 25
                let buttonBottomY: CGFloat = 240 // MOVED DOWN BY 25 (from 215 to 240)
                let horizontalLineY: CGFloat = 270 // MOVED DOWN BY 25 (from 245 to 270)
                let textTopY: CGFloat = 290 // MOVED DOWN BY 25 (from 265 to 290)
                
                // Horizontal line endpoints - SHRUNK BY 10 ON EACH SIDE OF CENTER
                let horizontalLineStartX = button1CenterX - 110 // SHRUNK LEFT BY 10 (from 120 to 110)
                let horizontalLineEndX = button2CenterX + 110 // SHRUNK RIGHT BY 10 (from 120 to 110)
                
                // Vertical line from left endpoint down
                Path { path in
                    path.move(to: CGPoint(x: horizontalLineStartX, y: buttonBottomY))
                    path.addLine(to: CGPoint(x: horizontalLineStartX, y: horizontalLineY))
                }
                .stroke(Color.orange, style: StrokeStyle(lineWidth: 2))
                
                // Vertical line from right endpoint down
                Path { path in
                    path.move(to: CGPoint(x: horizontalLineEndX, y: buttonBottomY))
                    path.addLine(to: CGPoint(x: horizontalLineEndX, y: horizontalLineY))
                }
                .stroke(Color.orange, style: StrokeStyle(lineWidth: 2))
                
                // Horizontal line connecting both vertical lines - SHRUNK BY 10 ON EACH SIDE
                Path { path in
                    path.move(to: CGPoint(x: horizontalLineStartX, y: horizontalLineY))
                    path.addLine(to: CGPoint(x: horizontalLineEndX, y: horizontalLineY))
                }
                .stroke(Color.orange, style: StrokeStyle(lineWidth: 2))
                
                // Vertical line from horizontal line down to Buttons 1+2 text
                Path { path in
                    path.move(to: CGPoint(x: centerX, y: horizontalLineY))
                    path.addLine(to: CGPoint(x: centerX, y: textTopY))
                }
                .stroke(Color.orange, style: StrokeStyle(lineWidth: 2))
                
                // ADD ARROWS TO THE TIP OF VERTICAL ORANGE LINES POINTING UP AT BUTTONS 1 + 2
                // Left arrow
                Path { path in
                    let arrowSize: CGFloat = 8
                    let tipX = horizontalLineStartX
                    let tipY = buttonBottomY
                    
                    path.move(to: CGPoint(x: tipX, y: tipY))
                    path.addLine(to: CGPoint(x: tipX - arrowSize, y: tipY + arrowSize))
                    path.move(to: CGPoint(x: tipX, y: tipY))
                    path.addLine(to: CGPoint(x: tipX + arrowSize, y: tipY + arrowSize))
                }
                .stroke(Color.orange, style: StrokeStyle(lineWidth: 2, lineCap: .round))
                
                // Right arrow
                Path { path in
                    let arrowSize: CGFloat = 8
                    let tipX = horizontalLineEndX
                    let tipY = buttonBottomY
                    
                    path.move(to: CGPoint(x: tipX, y: tipY))
                    path.addLine(to: CGPoint(x: tipX - arrowSize, y: tipY + arrowSize))
                    path.move(to: CGPoint(x: tipX, y: tipY))
                    path.addLine(to: CGPoint(x: tipX + arrowSize, y: tipY + arrowSize))
                }
                .stroke(Color.orange, style: StrokeStyle(lineWidth: 2, lineCap: .round))
                
                // REMOVED THE BOTTOM ORANGE ARROW FACING DOWN (center arrow)
            }
        }
        .allowsHitTesting(false)
    }
    
    func getCurrentSelection(for configKey: String) -> String {
        let code = config[configKey] ?? 0
        switch configKey {
        case "scroll":
            return codeToOption(code, validOptions: scrollOptions)
        case "button1":
            return codeToOption(code, validOptions: circleButton1Options)
        case "button2":
            return codeToOption(code, validOptions: circleButton2Options)
        case "combo":
            return codeToOption(code, validOptions: buttons12Options)
        default:
            return "Unknown"
        }
    }
    
    // Convert option string to numeric code - UPDATED FOR NEW NAMES
    func optionToCode(_ option: String) -> Int {
        switch option {
        case "Undo": return 3
        case "Redo": return 4
        case "Erase": return 5
        case "Brush Size ±5%": return 6
        case "Color Palette": return 7
        case "Brush Library": return 8
        case "Brush Size ±10%": return 9
        default: return 0
        }
    }
    
    // Convert numeric code to option string, with validation - UPDATED FOR NEW NAMES
    func codeToOption(_ code: Int, validOptions: [String]) -> String {
        let option: String
        switch code {
        case 3: option = "Undo"
        case 4: option = "Redo"
        case 5: option = "Erase"
        case 6: option = "Brush Size ±5%"
        case 7: option = "Color Palette"
        case 8: option = "Brush Library"
        case 9: option = "Brush Size ±10%"
        default: option = validOptions.first ?? "Undo"
        }
        
        // Validate the option is valid for this button
        if validOptions.contains(option) {
            return option
        } else {
            print("⚠️ Invalid option '\(option)' for valid options: \(validOptions). Using first available.")
            return validOptions.first ?? "Undo"
        }
    }
    
    func saveConfigurationIfConnected() {
        if bleManager.isConnected {
            saveConfiguration()
        }
    }
    
    func saveConfiguration() {
        print("📤 Saving configuration:")
        print("  Full config: \(config)")
        bleManager.writeConfig(config: config)
    }
}

// PreferenceKey for tracking view frames
struct ViewFrameKey: PreferenceKey {
    static var defaultValue: CGRect = .zero
    static func reduce(value: inout CGRect, nextValue: () -> CGRect) {
        value = nextValue()
    }
}

struct ComboFrameKey: PreferenceKey {
    static var defaultValue: CGRect = .zero
    static func reduce(value: inout CGRect, nextValue: () -> CGRect) {
        value = nextValue()
    }
}

struct ScrollFrameKey: PreferenceKey {
    static var defaultValue: CGRect = .zero
    static func reduce(value: inout CGRect, nextValue: () -> CGRect) {
        value = nextValue()
    }
}

struct Button2FrameKey: PreferenceKey {
    static var defaultValue: CGRect = .zero
    static func reduce(value: inout CGRect, nextValue: () -> CGRect) {
        value = nextValue()
    }
}

struct ScanButtonFrameKey: PreferenceKey {
    static var defaultValue: CGRect = .zero
    static func reduce(value: inout CGRect, nextValue: () -> CGRect) {
        value = nextValue()
    }
}

struct DeviceSelectionSheet: View {
    @ObservedObject var bleManager: BLEManager
    @Binding var showDeviceSheet: Bool
    
    var body: some View {
        NavigationView {
            VStack {
                if bleManager.isScanning {
                    VStack(spacing: 20) {
                        ProgressView().scaleEffect(1.5)
                        Text("Scanning for XIAO_Config...").font(.headline)
                        VStack(alignment: .leading, spacing: 8) {
                            Text("Device must be in CONFIG MODE:").font(.caption).foregroundColor(.gray).bold()
                            Text("• First boot: Automatic").font(.caption).foregroundColor(.gray)
                            Text("• Otherwise: Hold RESET 5 seconds").font(.caption).foregroundColor(.gray)
                        }
                        .padding()
                        .background(Color.orange.opacity(0.1))
                        .cornerRadius(8)
                    }.frame(maxHeight: .infinity).padding()
                } else if bleManager.devices.isEmpty {
                    VStack(spacing: 20) {
                        Image(systemName: "exclamationmark.triangle").font(.system(size: 50)).foregroundColor(.orange)
                        Text("No XIAO_Config Found").font(.headline)
                        VStack(alignment: .leading, spacing: 8) {
                            Text("To enter CONFIG MODE:").font(.subheadline).bold()
                            Text("1️⃣ First boot: Device starts in CONFIG mode automatically").font(.caption)
                            Text("2️⃣ After configuration: Hold RESET button for 5 seconds").font(.caption)
                            Text("3️⃣ LED will flash rapidly 10 times").font(.caption)
                            Text("4️⃣ Device shows as 'XIAO_Config'").font(.caption)
                            Text("").font(.caption)
                            Text("⚠️ If device was paired to iPad:").font(.subheadline).bold().foregroundColor(.red)
                            Text("Go to Settings → Bluetooth → Forget 'XIAO Keyboard'").font(.caption).foregroundColor(.red)
                            Text("Then hold RESET button again").font(.caption).foregroundColor(.red)
                        }
                        .padding()
                        .background(Color.orange.opacity(0.1))
                        .cornerRadius(8)
                        Button("Scan Again") { bleManager.startScan() }.buttonStyle(.borderedProminent).tint(.orange)
                    }.frame(maxHeight: .infinity).padding()
                } else {
                    List(bleManager.devices, id: \.identifier) { device in
                        Button(action: { bleManager.connect(to: device); showDeviceSheet = false }) {
                            VStack(alignment: .leading, spacing: 4) {
                                Text(device.name ?? "Unknown Device").font(.headline)
                                Text(device.identifier.uuidString).font(.caption).foregroundColor(.gray)
                            }.padding(.vertical, 8)
                        }
                    }
                    Text("Found \(bleManager.devices.count) device(s)").font(.caption).foregroundColor(.gray).padding()
                }
            }
            .navigationTitle("Select Device")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar { ToolbarItem(placement: .navigationBarTrailing) { Button("Cancel") { bleManager.stopScan(); showDeviceSheet = false } } }
        }
    }
}