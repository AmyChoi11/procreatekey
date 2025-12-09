import SwiftUI
import CoreBluetooth

// MARK: - Status Notification View
struct StatusNotificationView: View {
    let statusMessage: String
    
    var body: some View {
        let isSuccess = statusMessage.contains("✓") || statusMessage.contains("successfully")
        let isBluetoothReady = statusMessage.contains("Bluetooth ready")
        
        let iconName: String
        let iconColor: Color
        let backgroundColor: Color
        let borderColor: Color
        
        if isSuccess {
            iconName = "checkmark.circle.fill"
            iconColor = .green
            backgroundColor = Color.green.opacity(0.1)
            borderColor = Color.green.opacity(0.2)
        } else if isBluetoothReady {
            iconName = "exclamationmark.circle.fill"
            iconColor = Color(red: 1.0, green: 0.85, blue: 0.4) // PASTEL YELLOW
            backgroundColor = Color(red: 1.0, green: 0.85, blue: 0.4).opacity(0.1) // PASTEL YELLOW BACKGROUND
            borderColor = Color(red: 1.0, green: 0.85, blue: 0.4).opacity(0.2) // PASTEL YELLOW BORDER
        } else {
            iconName = "xmark.circle.fill"
            iconColor = .red
            backgroundColor = Color.red.opacity(0.1)
            borderColor = Color.red.opacity(0.2)
        }
        
        return HStack(alignment: .top, spacing: 12) {
            Image(systemName: iconName)
                .font(.system(size: 20))
                .foregroundColor(iconColor)
            
            Text(statusMessage)
                .font(.subheadline)
                .foregroundColor(.black)
                .multilineTextAlignment(.leading)
                .fixedSize(horizontal: false, vertical: true)
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 12)
        .background(
            RoundedRectangle(cornerRadius: 8)
                .fill(backgroundColor)
        )
        .overlay(
            RoundedRectangle(cornerRadius: 8)
                .stroke(borderColor, lineWidth: 1)
        )
        .padding(.horizontal)
    }
}

// MARK: - Content View
struct ContentView: View {
    @StateObject private var bleManager = BLEManager()
    @Environment(\.scenePhase) private var scenePhase
    @AppStorage("hasCompletedOnboarding") private var hasCompletedOnboarding = false
    
    // Store configuration as numeric codes - UPDATED DEFAULT SETTINGS
    @State private var config: [String: Int] = ["button1": 3, "button2": 5, "button3": 3, "combo": 8, "scroll": 6]  // Undo, Erase, Undo (click scroll), Brush Library, Brush Size 5%
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
    
    // State for showing dropdowns with anchor frames
    @State private var showScrollDropdown = false
    @State private var showButton1Dropdown = false
    @State private var showButton2Dropdown = false
    @State private var showComboDropdown = false
    @State private var showCustomsDropdown = false
    @State private var showHelpDropdown = false
    @State private var showClickScrollDropdown = false
    
    // New state variables for custom functionality
    @State private var showSaveCustomDropdown = false
    @State private var showCustomRenameAlert = false
    @State private var customToRename: Int = 0
    @State private var customRenameText: String = ""
    @State private var showSaveConfirmation = false
    @State private var savedCustomName = ""
    @State private var customToSave: Int = 0
    
    // Preset system - RENAMED TO CUSTOMS
    @AppStorage("custom1") private var custom1Data: String = ""
    @AppStorage("custom2") private var custom2Data: String = ""
    @AppStorage("custom3") private var custom3Data: String = ""
    @AppStorage("custom4") private var custom4Data: String = ""
    @AppStorage("custom5") private var custom5Data: String = ""
    
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
        var name: String
        let config: [String: Int]
    }
    
    // MARK: - Custom Functions - RENAMED FROM PRESET (MOVED BEFORE customs PROPERTY)
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
    
    var customs: [Custom] {
        var availableCustoms: [Custom] = []
        
        if let custom1 = loadCustom(from: custom1Data) {
            let name = UserDefaults.standard.string(forKey: "custom1Name") ?? "Custom 1"
            availableCustoms.append(Custom(id: 1, name: name, config: custom1))
        }
        
        if let custom2 = loadCustom(from: custom2Data) {
            let name = UserDefaults.standard.string(forKey: "custom2Name") ?? "Custom 2"
            availableCustoms.append(Custom(id: 2, name: name, config: custom2))
        }
        
        if let custom3 = loadCustom(from: custom3Data) {
            let name = UserDefaults.standard.string(forKey: "custom3Name") ?? "Custom 3"
            availableCustoms.append(Custom(id: 3, name: name, config: custom3))
        }
        
        if let custom4 = loadCustom(from: custom4Data) {
            let name = UserDefaults.standard.string(forKey: "custom4Name") ?? "Custom 4"
            availableCustoms.append(Custom(id: 4, name: name, config: custom4))
        }
        
        if let custom5 = loadCustom(from: custom5Data) {
            let name = UserDefaults.standard.string(forKey: "custom5Name") ?? "Custom 5"
            availableCustoms.append(Custom(id: 5, name: name, config: custom5))
        }
        
        return availableCustoms
    }
    
    // DEFAULT CONFIGURATION
    private let defaultConfig: [String: Int] = ["button1": 3, "button2": 5, "button3": 3, "combo": 8, "scroll": 6]  // Undo, Erase, Undo (click), Brush Library, Brush Size 5%
    
    // SCALING CONSTANTS
    private let controllerScale: CGFloat = 1.5
    private let buttonScale: CGFloat = 1.5
    
    var body: some View {
        GeometryReader { geometry in
            // Replace the entire main ZStack structure with:
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
                
                // Centered Rename Custom Popup Overlay (OLD STYLE)
                if showCustomRenameAlert {
                    Color.black.opacity(0.4)
                        .edgesIgnoringSafeArea(.all)
                        .onTapGesture {
                            showCustomRenameAlert = false
                            customRenameText = ""
                        }
                    
                    VStack(spacing: 16) {
                        Text("Rename Custom")
                            .font(.headline)
                            .fontWeight(.bold)
                            .foregroundColor(.primary)
                        
                        TextField("Enter name", text: $customRenameText)
                            .textFieldStyle(RoundedBorderTextFieldStyle())
                            .padding(.horizontal)
                        
                        HStack(spacing: 20) {
                            Button("Cancel") {
                                showCustomRenameAlert = false
                                customRenameText = ""
                            }
                            .foregroundColor(.red)
                            .padding(.horizontal, 20)
                            .padding(.vertical, 8)
                            .background(Color.red.opacity(0.1))
                            .cornerRadius(8)
                            
                            Button("Save") {
                                print("💾 Saving custom name: \(customRenameText) for slot \(customToRename)")
                                saveCustomName(customToRename, name: customRenameText)
                                showCustomRenameAlert = false
                                customRenameText = ""
                            }
                            .foregroundColor(.white)
                            .padding(.horizontal, 20)
                            .padding(.vertical, 8)
                            .background(
                                customRenameText.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty ?
                                Color.gray : Color.blue
                            )
                            .cornerRadius(8)
                            .disabled(customRenameText.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty)
                        }
                        .padding(.top, 10)
                    }
                    .padding(.vertical, 24)
                    .padding(.horizontal, 20)
                    .frame(width: 300)
                    .background(Color(UIColor.systemBackground))
                    .cornerRadius(12)
                    .shadow(radius: 20)
                    .overlay(
                        RoundedRectangle(cornerRadius: 12)
                            .stroke(Color.gray.opacity(0.2), lineWidth: 1)
                    )
                }
                
                // Centered Save Confirmation Popup Overlay (OLD STYLE)
                if showSaveConfirmation {
                    Color.black.opacity(0.4)
                        .edgesIgnoringSafeArea(.all)
                        .onTapGesture {
                            showSaveConfirmation = false
                        }
                    
                    VStack(spacing: 16) {
                        Text("Save Custom")
                            .font(.headline)
                            .fontWeight(.bold)
                            .foregroundColor(.primary)
                        
                        Text("Overwrite existing custom '\(getCustomNameForSlot(customToSave))'?")
                            .multilineTextAlignment(.center)
                            .foregroundColor(.secondary)
                            .padding(.horizontal)
                        
                        HStack(spacing: 20) {
                            Button("Cancel") {
                                showSaveConfirmation = false
                            }
                            .foregroundColor(.red)
                            .padding(.horizontal, 20)
                            .padding(.vertical, 8)
                            .background(Color.red.opacity(0.1))
                            .cornerRadius(8)
                            
                            Button("Confirm") {
                                saveCustom(slot: customToSave)
                                showSaveConfirmation = false
                                
                                // Show a quick success message
                                savedCustomName = getCustomNameForSlot(customToSave)
                                DispatchQueue.main.asyncAfter(deadline: .now() + 0.5) {
                                    // You could add a toast notification here if desired
                                }
                            }
                            .foregroundColor(.white)
                            .padding(.horizontal, 20)
                            .padding(.vertical, 8)
                            .background(Color.blue)
                            .cornerRadius(8)
                        }
                        .padding(.top, 10)
                    }
                    .padding(.vertical, 24)
                    .padding(.horizontal, 20)
                    .frame(width: 300)
                    .background(Color(UIColor.systemBackground))
                    .cornerRadius(12)
                    .shadow(radius: 20)
                    .overlay(
                        RoundedRectangle(cornerRadius: 12)
                            .stroke(Color.gray.opacity(0.2), lineWidth: 1)
                    )
                }
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
            // Background color - ADJUSTED LIGHT PURPLE (LESS SATURATED)
            Color(red: 0.97, green: 0.94, blue: 1.0) // LIGHTER, LESS SATURATED PURPLE
                .ignoresSafeArea()
            
            // REMOVED ScrollView - replaced with fixed VStack
            VStack(spacing: 20) {
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
                        .foregroundColor(.black) // BLACK TEXT
                        .offset(y: 275) // MOVED DOWN BY 250
                    
                    ZStack {
                        // Controller outline first (bottom layer) - SCALED BY 1.5x AND MOVED UP BY 100
                        controllerOutline
                            .scaleEffect(controllerScale, anchor: .top) // Scale from top
                            .offset(y: 150) // MOVED DOWN BY 250 (-100 + 250 = 150)
                        
                        connectionLines
                            .offset(x: 0, y: 255)
                        
                        // Buttons and labels on top of everything
                        VStack(spacing: 30) {
                            // Top: Scroll - Button 1 - Button 2 (REORDERED) - MOVED UP BY 60
                            HStack(spacing: 10) {
                                // Scroll - Pill/Capsule shape WITH UP/DOWN ARROWS - REVERSED COLORS - RESTORE ORIGINAL SIZE
                                VStack(spacing: 8) {
                                    // INCREASED SIZE OF CURRENT CONFIG DISPLAY WITH WIDER WIDTH - NOW CLICKABLE - REVERSED COLORS
                                    Button(action: {
                                        showScrollDropdown = true
                                    }) {
                                        Text(getCurrentSelection(for: "scroll"))
                                            .font(.system(size: 16, weight: .medium))
                                            .foregroundColor(.white) // WHITE TEXT
                                            .padding(.horizontal, 12)
                                            .padding(.vertical, 6)
                                            .background(Color(red: 0.7, green: 0.5, blue: 0.9).opacity(0.8)) // PASTEL PURPLE BACKGROUND
                                            .cornerRadius(6)
                                            .overlay(
                                                RoundedRectangle(cornerRadius: 6)
                                                    .stroke(Color.white, lineWidth: 1) // WHITE BORDER
                                            )
                                            .fixedSize(horizontal: false, vertical: true)
                                            .frame(maxWidth: 180)
                                    }
                                    .buttonStyle(PlainButtonStyle())
                                    
                                    Button(action: {
                                        showScrollDropdown = true
                                    }) {
                                        ZStack {
                                            // Main pill-shaped body - PASTEL PURPLE FILL - SCALED BY 1.5x (RESTORE ORIGINAL SIZE)
                                            Capsule()
                                                .fill(Color(red: 0.7, green: 0.5, blue: 0.9).opacity(0.8)) // PASTEL PURPLE FILL
                                                .frame(width: 60 * buttonScale, height: 100 * buttonScale) // SCALED BY 1.5x
                                            
                                            // Outer border - WHITE OUTLINE
                                            Capsule()
                                                .stroke(Color.white, lineWidth: 2)
                                                .frame(width: 60 * buttonScale, height: 100 * buttonScale) // SCALED BY 1.5x
                                            
                                            // UP/DOWN ARROWS ADDED - WHITE - SCALED
                                            VStack(spacing: 4) {
                                                Image(systemName: "chevron.up")
                                                    .font(.system(size: 16 * buttonScale, weight: .bold)) // SCALED
                                                    .foregroundColor(.white) // WHITE
                                                
                                                Image(systemName: "chevron.down")
                                                    .font(.system(size: 16 * buttonScale, weight: .bold)) // SCALED
                                                    .foregroundColor(.white) // WHITE
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
                                    
                                    // Make the label clickable - PASTEL PURPLE TEXT - MOVED DOWN
                                    Button(action: {
                                        showScrollDropdown = true
                                    }) {
                                        Text("Scroll")
                                            .font(.system(size: 16, weight: .semibold))
                                            .foregroundColor(Color(red: 0.7, green: 0.5, blue: 0.9)) // PASTEL PURPLE TEXT
                                    }
                                    .buttonStyle(PlainButtonStyle())
                                    .padding(.top, 10) // MOVED DOWN BY 10 POINTS
                                }
                                .offset(x: -100, y: 205)
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
                                
                                // Button 1 - Larger - MOVED BACK TO ORIGINAL POSITION - PASTEL RED-PURPLE REVERSED COLORS
                                VStack(spacing: 8) {
                                    // INCREASED SIZE OF CURRENT CONFIG DISPLAY - NOW CLICKABLE - REVERSED COLORS
                                    Button(action: {
                                        showButton1Dropdown = true
                                    }) {
                                        Text(getCurrentSelection(for: "button1"))
                                            .font(.system(size: 16, weight: .medium))
                                            .foregroundColor(.white) // WHITE TEXT
                                            .padding(.horizontal, 12)
                                            .padding(.vertical, 6)
                                            .background(Color(red: 0.85, green: 0.4, blue: 0.7).opacity(0.8)) // PASTEL RED-PURPLE BACKGROUND
                                            .cornerRadius(6)
                                            .overlay(
                                                RoundedRectangle(cornerRadius: 6)
                                                    .stroke(Color.white, lineWidth: 1) // WHITE BORDER
                                            )
                                            .fixedSize(horizontal: false, vertical: true)
                                            .frame(maxWidth: 120)
                                    }
                                    .buttonStyle(PlainButtonStyle())
                                    
                                    // Make the button name clickable - REVERSED COLORS - SCALED BY 1.5x
                                    Button(action: {
                                        showButton1Dropdown = true
                                    }) {
                                        ZStack {
                                            Circle()
                                                .fill(Color(red: 0.85, green: 0.4, blue: 0.7).opacity(0.8)) // PASTEL RED-PURPLE BACKGROUND
                                                .frame(width: 80 * buttonScale, height: 80 * buttonScale) // SCALED BY 1.5x
                                            
                                            Circle()
                                                .stroke(Color.white, lineWidth: 2) // WHITE BORDER
                                                .frame(width: 80 * buttonScale, height: 80 * buttonScale) // SCALED BY 1.5x
                                            
                                            Text("1")
                                                .font(.system(size: 24 * buttonScale, weight: .bold)) // SCALED
                                                .foregroundColor(.white) // WHITE TEXT
                                        }
                                    }
                                    .buttonStyle(PlainButtonStyle())
                                    .background(GeometryReader { geo in
                                        Color.clear.preference(key: ViewFrameKey.self, value: geo.frame(in: .global))
                                    })
                                    .onPreferenceChange(ViewFrameKey.self) { frame in
                                        button1Frame = frame
                                    }
                                    
                                    // Make the label clickable - PASTEL RED-PURPLE TEXT - MOVED DOWN
                                    Button(action: {
                                        showButton1Dropdown = true
                                    }) {
                                        Text("Button 1")
                                            .font(.system(size: 16, weight: .semibold))
                                            .foregroundColor(Color(red: 0.85, green: 0.4, blue: 0.7)) // PASTEL RED-PURPLE TEXT
                                    }
                                    .buttonStyle(PlainButtonStyle())
                                    .padding(.top, 10) // MOVED DOWN BY 10 POINTS
                                }
                                .offset(y: 205) // MOVED DOWN BY 250 (-45 + 250 = 205)
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
                                
                                // Button 2 - Larger - MOVED BACK TO ORIGINAL POSITION - PASTEL BLUE-PURPLE REVERSED COLORS
                                VStack(spacing: 8) {
                                    // INCREASED SIZE OF CURRENT CONFIG DISPLAY - NOW CLICKABLE - REVERSED COLORS
                                    Button(action: {
                                        showButton2Dropdown = true
                                    }) {
                                        Text(getCurrentSelection(for: "button2"))
                                            .font(.system(size: 16, weight: .medium))
                                            .foregroundColor(.white) // WHITE TEXT
                                            .padding(.horizontal, 12)
                                            .padding(.vertical, 6)
                                            .background(Color(red: 0.5, green: 0.4, blue: 0.9).opacity(0.8)) // PASTEL BLUE-PURPLE BACKGROUND
                                            .cornerRadius(6)
                                            .overlay(
                                                RoundedRectangle(cornerRadius: 6)
                                                    .stroke(Color.white, lineWidth: 1) // WHITE BORDER
                                            )
                                            .fixedSize(horizontal: false, vertical: true)
                                            .frame(maxWidth: 120)
                                    }
                                    .buttonStyle(PlainButtonStyle())
                                    
                                    // Make the button name clickable - REVERSED COLORS - SCALED BY 1.5x
                                    Button(action: {
                                        showButton2Dropdown = true
                                    }) {
                                        ZStack {
                                            Circle()
                                                .fill(Color(red: 0.5, green: 0.4, blue: 0.9).opacity(0.8)) // PASTEL BLUE-PURPLE BACKGROUND
                                                .frame(width: 80 * buttonScale, height: 80 * buttonScale) // SCALED BY 1.5x
                                            
                                            Circle()
                                                .stroke(Color.white, lineWidth: 2) // WHITE BORDER
                                                .frame(width: 80 * buttonScale, height: 80 * buttonScale) // SCALED BY 1.5x
                                            
                                            Text("2")
                                                .font(.system(size: 24 * buttonScale, weight: .bold)) // SCALED
                                                .foregroundColor(.white) // WHITE TEXT
                                        }
                                    }
                                    .buttonStyle(PlainButtonStyle())
                                    .background(GeometryReader { geo in
                                        Color.clear.preference(key: Button2FrameKey.self, value: geo.frame(in: .global))
                                    })
                                    .onPreferenceChange(Button2FrameKey.self) { frame in
                                        button2Frame = frame
                                    }
                                    
                                    // Make the label clickable - PASTEL BLUE-PURPLE TEXT - MOVED DOWN
                                    Button(action: {
                                        showButton2Dropdown = true
                                    }) {
                                        Text("Button 2")
                                            .font(.system(size: 16, weight: .semibold))
                                            .foregroundColor(Color(red: 0.5, green: 0.4, blue: 0.9)) // PASTEL BLUE-PURPLE TEXT
                                    }
                                    .buttonStyle(PlainButtonStyle())
                                    .padding(.top, 10) // MOVED DOWN BY 10 POINTS
                                }
                                .offset(x: 100, y: 205)
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
                            }
                            .padding(.top, 20)
                        }
                        .frame(height: 320 * controllerScale) // SCALED HEIGHT
                    }
                }
                .padding(.top, 15)
                .padding(.horizontal)
                
                // VERTICAL ARROW
                VStack(spacing: 0) {
                    // VERTICAL ARROW POINTING UP - HALVED LENGTH
                    GeometryReader { geometry in
                        ZStack {
                            // Calculate position for the vertical arrow (centered above click scroll button)
                            let clickScrollCenterX = geometry.size.width / 2 - 230 // Same X as click scroll
                            let clickScrollTopY = (geometry.size.height / 2) - (100 * buttonScale * 0.3) + 15 // Position of click scroll minus height
                            
                            // Position arrow 20 points above click scroll button, then MOVED DOWN BY 300
                            let arrowY = clickScrollTopY - 60 + 120 //
                            
                            // Vertical arrow line (halved length) pointing UP
                            Path { path in
                                let arrowLength: CGFloat = 30
                                path.move(to: CGPoint(x: clickScrollCenterX, y: arrowY + arrowLength))
                                path.addLine(to: CGPoint(x: clickScrollCenterX, y: arrowY)) // Pointing UP
                            }
                            .stroke(Color(red: 0.4, green: 0.2, blue: 0.6), style: StrokeStyle(lineWidth: 2, lineCap: .round))
                            
                            // Arrow head (pointing up)
                            Path { path in
                                let arrowSize: CGFloat = 8
                                path.move(to: CGPoint(x: clickScrollCenterX, y: arrowY))
                                path.addLine(to: CGPoint(x: clickScrollCenterX - arrowSize, y: arrowY + arrowSize))
                                path.move(to: CGPoint(x: clickScrollCenterX, y: arrowY))
                                path.addLine(to: CGPoint(x: clickScrollCenterX + arrowSize, y: arrowY + arrowSize))
                            }
                            .stroke(Color(red: 0.4, green: 0.2, blue: 0.6), style: StrokeStyle(lineWidth: 2, lineCap: .round))
                        }
                    }
                    
                    // CLICK SCROLL BUTTON SECTION - POSITIONED UNDER ARROW
                    VStack(spacing: 8) {
                        // Config display for the click scroll button
                        Button(action: {
                            showClickScrollDropdown = true
                        }) {
                            Text(getCurrentSelection(for: "button3"))
                                .font(.system(size: 10, weight: .medium))
                                .foregroundColor(.white) // WHITE TEXT
                                .padding(.horizontal, 6)
                                .padding(.vertical, 3)
                                .background(Color(red: 0.7, green: 0.5, blue: 0.9).opacity(0.8)) // PASTEL PURPLE BACKGROUND
                                .cornerRadius(4)
                                .overlay(
                                    RoundedRectangle(cornerRadius: 4)
                                        .stroke(Color(red: 0.4, green: 0.2, blue: 0.6), lineWidth: 2) // DARK PURPLE OUTLINE
                                )
                                .fixedSize(horizontal: false, vertical: true)
                                .frame(maxWidth: 120)
                        }
                        .buttonStyle(PlainButtonStyle())
                        
                        // Click scroll button with finger-clicking symbol
                        Button(action: {
                            showClickScrollDropdown = true
                        }) {
                            ZStack {
                                // Main pill-shaped body - PASTEL PURPLE FILL
                                Capsule()
                                    .fill(Color(red: 0.7, green: 0.5, blue: 0.9).opacity(0.8)) // PASTEL PURPLE FILL
                                    .frame(width: 36, height: 60) // Smaller size
                                
                                // Outer border
                                Capsule()
                                    .stroke(Color(red: 0.4, green: 0.2, blue: 0.6), lineWidth: 2)
                                    .frame(width: 36, height: 60)
                                
                                // FINGER-CLICKING SYMBOL
                                VStack(spacing: 2) {
                                    Image(systemName: "hand.tap.fill")
                                        .font(.system(size: 12, weight: .bold))
                                        .foregroundColor(.white) // WHITE
                                        .padding(.top, 4)
                                    
                                    Circle()
                                        .fill(Color.white.opacity(0.3))
                                        .frame(width: 8, height: 8)
                                        .offset(y: 2)
                                }
                            }
                        }
                        .buttonStyle(PlainButtonStyle())
                        
                        // Make the label clickable
                        Button(action: {
                            showClickScrollDropdown = true
                        }) {
                            Text("Click on Scroll")
                                .font(.system(size: 12, weight: .semibold))
                                .foregroundColor(Color(red: 0.7, green: 0.5, blue: 0.9)) // PASTEL PURPLE TEXT
                        }
                        .buttonStyle(PlainButtonStyle())
                    }
                    .offset(x: -230, y: 25) // Position under original scroll button, MOVED DOWN BY 25
                    .popover(isPresented: $showClickScrollDropdown, attachmentAnchor: .point(.bottom), arrowEdge: .top) {
                        VStack(spacing: 0) {
                            ForEach(allButtonOptions, id: \.self) { option in
                                Button(action: {
                                    config["button3"] = optionToCode(option)
                                    saveConfigurationIfConnected()
                                    showClickScrollDropdown = false
                                }) {
                                    Text(option)
                                        .foregroundColor(.primary)
                                        .frame(maxWidth: .infinity, alignment: .leading)
                                        .padding(.horizontal, 16)
                                        .padding(.vertical, 12)
                                }
                                if option != allButtonOptions.last {
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
                }
                .frame(height: 200) // Give it some height
                
                VStack(spacing: 8) {
                    Button(action: {
                        showComboDropdown = true
                    }) {
                        Text(getCurrentSelection(for: "combo"))
                            .font(.system(size: 16 * 1.0, weight: .medium)) // ORIGINAL SIZE
                            .foregroundColor(.white) // WHITE TEXT
                            .padding(.horizontal, 12 * 1.0) // ORIGINAL PADDING
                            .padding(.vertical, 6 * 1.0) // ORIGINAL PADDING
                            .background(Color(red: 0.7, green: 0.5, blue: 0.8)) // PURPLE BACKGROUND
                            .cornerRadius(6 * 1.0) // ORIGINAL CORNER RADIUS
                            .overlay(
                                RoundedRectangle(cornerRadius: 6 * 1.0)
                                    .stroke(Color(red: 0.4, green: 0.2, blue: 0.6), lineWidth: 2) // DARK PURPLE OUTLINE
                            )
                            .fixedSize(horizontal: false, vertical: true)
                            .frame(maxWidth: 180 * 1.0) // ORIGINAL WIDTH
                    }
                    .buttonStyle(PlainButtonStyle())
                    
                    Button(action: {
                        showComboDropdown = true
                    }) {
                        HStack(spacing: 6) {
                            // Button 1 - MATCHES ACTUAL BUTTON 1 (PASTEL RED-PURPLE REVERSED SCHEME)
                            ZStack {
                                Circle()
                                    .fill(Color(red: 0.85, green: 0.4, blue: 0.7).opacity(0.8)) // PASTEL RED-PURPLE BACKGROUND
                                    .frame(width: 28 * 1.0, height: 28 * 1.0) // ORIGINAL SIZE
                                
                                Circle()
                                    .stroke(Color.white, lineWidth: 1) // WHITE BORDER
                                    .frame(width: 28 * 1.0, height: 28 * 1.0)
                                
                                Text("1")
                                    .font(.system(size: 12 * 1.0, weight: .bold)) // ORIGINAL SIZE
                                    .foregroundColor(.white) // WHITE TEXT
                            }
                            
                            // Plus sign - WHITE
                            Text("+")
                                .font(.system(size: 16 * 1.0, weight: .bold)) // ORIGINAL SIZE
                                .foregroundColor(.white)
                            
                            // Button 2 - MATCHES ACTUAL BUTTON 2 (PASTEL BLUE-PURPLE REVERSED SCHEME)
                            ZStack {
                                Circle()
                                    .fill(Color(red: 0.5, green: 0.4, blue: 0.9).opacity(0.8)) // PASTEL BLUE-PURPLE BACKGROUND
                                    .frame(width: 28 * 1.0, height: 28 * 1.0)
                                
                                Circle()
                                    .stroke(Color.white, lineWidth: 1) // WHITE BORDER
                                    .frame(width: 28 * 1.0, height: 28 * 1.0)
                                
                                Text("2")
                                    .font(.system(size: 12 * 1.0, weight: .bold))
                                    .foregroundColor(.white) // WHITE TEXT
                            }
                        }
                        .padding(.horizontal, 16 * 1.0) // ORIGINAL PADDING
                        .padding(.vertical, 12 * 1.0) // ORIGINAL PADDING
                        .background(Color(red: 0.7, green: 0.5, blue: 0.8)) // PURPLE BACKGROUND
                        .cornerRadius(8 * 1.0) // ORIGINAL CORNER RADIUS
                        .overlay(
                            RoundedRectangle(cornerRadius: 8 * 1.0)
                                .stroke(Color(red: 0.4, green: 0.2, blue: 0.6), lineWidth: 2) // DARK PURPLE OUTLINE
                        )
                    }
                    .buttonStyle(PlainButtonStyle())
                    .background(GeometryReader { geo in
                        Color.clear.preference(key: ComboFrameKey.self, value: geo.frame(in: .global))
                    })
                    .onPreferenceChange(ComboFrameKey.self) { frame in
                        comboFrame = frame
                    }
                }
                .offset(x: 145, y: -95)
                .popover(isPresented: $showComboDropdown, attachmentAnchor: .point(.trailing), arrowEdge: .trailing) {
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
                    .presentationCompactAdaptation(.popover)
                }
                
                if bleManager.isConnected {
                    VStack(spacing: 8) {
                        Image(systemName: "info.circle.fill")
                            .font(.system(size: 24))
                            .foregroundColor(Color(red: 0.4, green: 0.2, blue: 0.6))
                        Text("⚠️ While connected, do NOT press the RESET button on the device. It will disconnect and restart.")
                            .font(.caption)
                            .multilineTextAlignment(.center)
                            .foregroundColor(.black)
                    }
                    .padding()
                    .background(RoundedRectangle(cornerRadius: 12).fill(Color(red: 0.4, green: 0.2, blue: 0.6).opacity(0.1)))
                    .padding(.horizontal)
                    .padding(.top, 30)
                }
                
                // ADDED SPACING BEFORE NOTIFICATION SECTION
                Spacer().frame(height: 30)
                
                // EXTRACTED AND MOVED Status Message Section
                if !bleManager.statusMessage.isEmpty {
                    StatusNotificationView(statusMessage: bleManager.statusMessage)
                        .offset(y: -100) // MOVED UP BY 150
                }
                
                // Save Custom Button - NOW INSIDE THE MAIN VSTACK
                HStack {
                    Spacer()
                    Button(action: {
                        showSaveCustomDropdown = true
                    }) {
                        HStack(spacing: 8) {
                            Image(systemName: "square.and.arrow.down")
                                .font(.system(size: 16))
                                .foregroundColor(Color(red: 0.4, green: 0.2, blue: 0.6)) // PURPLE ICON
                            Text("Save as Custom")
                                .font(.system(size: 16, weight: .semibold))
                                .foregroundColor(Color(red: 0.4, green: 0.2, blue: 0.6)) // PURPLE TEXT
                        }
                        .padding(.horizontal, 20)
                        .padding(.vertical, 12)
                        .background(Color.white) // WHITE BACKGROUND
                        .cornerRadius(10)
                        .overlay(
                            RoundedRectangle(cornerRadius: 10)
                                .stroke(Color(red: 0.4, green: 0.2, blue: 0.6), lineWidth: 2) // PURPLE BORDER
                        )
                    }
                    .padding(.trailing, 80)
                    .padding(.bottom, 100)
                    .offset(y: -300)
                    .popover(isPresented: $showSaveCustomDropdown, attachmentAnchor: .point(.bottom), arrowEdge: .top) {
                        saveCustomMenuView
                    }
                }
                .padding(.top, 20)
                
                Spacer()
            }
            .padding(.vertical)
            .padding(.bottom, 30)
        }
        .navigationTitle("eSketch Shortcuts")
        .navigationBarTitleDisplayMode(.inline)
    }
    
    @ToolbarContentBuilder
    var toolbarContent: some ToolbarContent {
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
            // Reset to Default Button - SAME HEIGHT AS OTHER BUTTONS
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
    
    // MARK: - Save Custom Menu View
    var saveCustomMenuView: some View {
        VStack(spacing: 0) {
            Text("Save Current Configuration")
                .font(.headline)
                .foregroundColor(Color(red: 0.4, green: 0.2, blue: 0.6))
                .padding()
                .frame(maxWidth: .infinity)
                .background(Color.gray.opacity(0.1))
            
            // Always show Custom 1 as the first option - USE ACTUAL CUSTOM NAME
            Button(action: {
                customToSave = 1
                showSaveConfirmation = true
                showSaveCustomDropdown = false
            }) {
                HStack {
                    // FIX: Use the actual custom name if it exists
                    if let custom1 = customs.first(where: { $0.id == 1 }) {
                        Text(custom1.name)
                            .font(.system(size: 16, weight: .semibold))
                            .foregroundColor(.black)
                    } else {
                        Text("Custom 1")
                            .font(.system(size: 16, weight: .semibold))
                            .foregroundColor(.black)
                    }
                    Spacer()
                }
                .padding()
                .background(Color.white)
            }
            
            Divider()
            
            // Show other existing customs - USE ACTUAL CUSTOM NAMES
            ForEach(customs.filter { $0.id != 1 }) { custom in
                Button(action: {
                    customToSave = custom.id
                    showSaveConfirmation = true
                    showSaveCustomDropdown = false
                }) {
                    HStack {
                        Text(custom.name)
                            .font(.system(size: 16, weight: .semibold))
                            .foregroundColor(.black)
                        Spacer()
                    }
                    .padding()
                    .background(Color.white)
                }
                
                if custom.id != customs.last?.id {
                    Divider()
                }
            }
            
            // Show "Add New Custom" option if we have less than 5 slots
            if customs.count < 5 {
                Button(action: {
                    // Find the first available slot (2-5, since 1 is always shown)
                    let nextSlot = findFirstAvailableSlot()
                    customToSave = nextSlot
                    showSaveConfirmation = true
                    showSaveCustomDropdown = false
                }) {
                    HStack {
                        Text("Add New Custom")
                            .font(.system(size: 16, weight: .semibold))
                            .foregroundColor(.green)
                        Spacer()
                        Image(systemName: "plus.circle.fill")
                            .foregroundColor(.green)
                    }
                    .padding()
                    .background(Color.white)
                }
            }
        }
        .background(Color.white)
        .cornerRadius(12)
        .shadow(radius: 5)
        .frame(width: 280)
    }
    
    // MARK: - Lifecycle Methods
    func handleOnAppear() {
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
    
    // MARK: - Custom Menu View
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
                    HStack {
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
                                    Text("Click on Scroll: \(codeToOption(custom.config["button3"] ?? 0, validOptions: allButtonOptions))")
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
                        }
                        .buttonStyle(PlainButtonStyle())
                        
                        Spacer()
                        
                        // Only show rename button (delete button removed)
                        Button(action: {
                            customToRename = custom.id
                            customRenameText = custom.name
                            print("🔄 Rename button tapped for custom \(custom.id)")
                            print("🔄 Setting showCustomRenameAlert to true")
                            showCustomRenameAlert = true
                            showCustomsDropdown = false
                        }) {
                            Image(systemName: "pencil")
                                .font(.system(size: 14))
                                .foregroundColor(.blue)
                                .padding(6)
                                .background(Color.blue.opacity(0.1))
                                .cornerRadius(4)
                        }
                        .buttonStyle(PlainButtonStyle())
                    }
                    .padding()
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .background(Color.white)
                    
                    if custom.id != customs.last?.id {
                        Divider()
                    }
                }
            }
        }
        .background(Color.white)
        .cornerRadius(12)
        .shadow(radius: 5)
        .frame(width: 320)
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
    
    // MARK: - Helper Functions
    func getCustomNameForSlot(_ slot: Int) -> String {
        // Ensure slot is valid (1-5)
        guard (1...5).contains(slot) else {
            return "Custom"
        }
        
        if let existingName = UserDefaults.standard.string(forKey: "custom\(slot)Name"), !existingName.isEmpty {
            return existingName
        } else {
            return "Custom \(slot)"
        }
    }
    
    func findFirstAvailableSlot() -> Int {
        // Check which custom slots are available (2-5, since 1 is always shown)
        for slot in 2...5 {
            switch slot {
            case 2 where custom2Data.isEmpty:
                return 2
            case 3 where custom3Data.isEmpty:
                return 3
            case 4 where custom4Data.isEmpty:
                return 4
            case 5 where custom5Data.isEmpty:
                return 5
            default:
                continue
            }
        }
        // If all slots 2-5 are full, return 2 (this shouldn't happen due to the UI logic)
        return 2
    }
    
    func saveCustom(slot: Int) {
        do {
            let jsonData = try JSONSerialization.data(withJSONObject: config, options: [])
            let jsonString = String(data: jsonData, encoding: .utf8) ?? ""
            
            switch slot {
            case 1:
                custom1Data = jsonString
                // Set default name if not already set
                if UserDefaults.standard.string(forKey: "custom1Name") == nil {
                    UserDefaults.standard.set("Custom 1", forKey: "custom1Name")
                }
            case 2:
                custom2Data = jsonString
                if UserDefaults.standard.string(forKey: "custom2Name") == nil {
                    UserDefaults.standard.set("Custom 2", forKey: "custom2Name")
                }
            case 3:
                custom3Data = jsonString
                if UserDefaults.standard.string(forKey: "custom3Name") == nil {
                    UserDefaults.standard.set("Custom 3", forKey: "custom3Name")
                }
            case 4:
                custom4Data = jsonString
                if UserDefaults.standard.string(forKey: "custom4Name") == nil {
                    UserDefaults.standard.set("Custom 4", forKey: "custom4Name")
                }
            case 5:
                custom5Data = jsonString
                if UserDefaults.standard.string(forKey: "custom5Name") == nil {
                    UserDefaults.standard.set("Custom 5", forKey: "custom5Name")
                }
            default:
                break
            }
            
            print("💾 Custom \(slot) saved: \(config)")
        } catch {
            print("❌ Failed to save custom: \(error)")
        }
    }
    
    func saveCustomName(_ slot: Int, name: String) {
        let trimmedName = name.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmedName.isEmpty else { return }
        
        UserDefaults.standard.set(trimmedName, forKey: "custom\(slot)Name")
        print("💾 Custom \(slot) renamed to: '\(trimmedName)'")
        
        // Force UserDefaults to save immediately
        UserDefaults.standard.synchronize()
        
        // Verify it was saved
        let savedName = UserDefaults.standard.string(forKey: "custom\(slot)Name")
        print("💾 Verified saved name: '\(savedName ?? "nil")'")
    }
    
    func loadCustom(_ custom: Custom) {
        self.config = custom.config
        saveConfigurationIfConnected()
        print("📥 Loaded custom \(custom.id): \(custom.config)")
    }
    
    var controllerOutline: some View {
        GeometryReader { geometry in
            ZStack {
                let containerWidth = geometry.size.width
                let containerHeight = geometry.size.height
                let centerX = containerWidth / 2
                
                Path { path in
                    let bodyWidth: CGFloat = 480 * 1.3 // EXTENDED LENGTH BY 30% (from 480 to 624)
                    let bodyHeight: CGFloat = (197.5 * 1.25) - 45 // EXTENDED HEIGHT BY 25% THEN SHORTENED FROM BOTTOM BY 10, THEN CUT 30 MORE
                    let cornerRadius: CGFloat = 23.5 // Keep current corners
                    
                    let bodyRect = CGRect(
                        x: centerX - bodyWidth / 2,
                        y: containerHeight / 2 - bodyHeight / 2 - 40, // MOVED UP BY ANOTHER 20 (from -30 to -50)
                        width: bodyWidth,
                        height: bodyHeight
                    )
                    
                    // Rounded rectangle for the main body - CHANGED TO DARK GRAY
                    path.addRoundedRect(
                        in: bodyRect,
                        cornerSize: CGSize(width: cornerRadius, height: cornerRadius)
                    )
                }
                .fill(Color.gray.opacity(0.4)) // DARK GRAY FILL (CHANGED FROM BLACK)
            }
        }
    }
    
    var connectionLines: some View {
        GeometryReader { geometry in
            ZStack {
                let containerWidth = geometry.size.width
                let centerX = containerWidth / 2
                
                // SHIFT EVERYTHING RIGHT BY 80 TOTAL
                let offset: CGFloat = 100
                
                // DARK PURPLE lines positioned above the outline - MOVED UP BY 100 (from 438 to 338)
                // UPDATED POSITIONS FOR NEW LAYOUT: Scroll ~> Button 1 ~> Button 2
                let button1CenterX = centerX - 60 + offset // Button 1 center position (left of center) + offset
                let button2CenterX = centerX + 60 + offset // Button 2 center position (right of center) + offset

                // Position lines MOVED UP BY 100
                let buttonBottomY: CGFloat = 308 // MOVED UP BY 100 (from 408 to 308)
                let horizontalLineY: CGFloat = 338 // MOVED UP BY 100 (from 438 to 338)
                let textTopY: CGFloat = 358 // MOVED UP BY 100 (from 458 to 358)

                // EXTEND LEFT ENDPOINT BY 10, EXTEND RIGHT ENDPOINT BY 100
                let horizontalLineStartX = button1CenterX - 10 // Extended left by 10
                let horizontalLineEndX = button2CenterX + 100   // Extended right by 100
                
                // FIXED: Vertical line from EXTENDED LEFT ENDPOINT down (under Button 1)
                Path { path in
                    path.move(to: CGPoint(x: horizontalLineStartX, y: buttonBottomY))
                    path.addLine(to: CGPoint(x: horizontalLineStartX, y: horizontalLineY))
                }
                .stroke(Color(red: 0.4, green: 0.2, blue: 0.6), style: StrokeStyle(lineWidth: 2))
                
                // Vertical line from EXTENDED RIGHT ENDPOINT down (under Button 2)
                Path { path in
                    path.move(to: CGPoint(x: horizontalLineEndX, y: buttonBottomY))
                    path.addLine(to: CGPoint(x: horizontalLineEndX, y: horizontalLineY))
                }
                .stroke(Color(red: 0.4, green: 0.2, blue: 0.6), style: StrokeStyle(lineWidth: 2))
                
                // EXTENDED Horizontal line connecting both vertical lines
                Path { path in
                    path.move(to: CGPoint(x: horizontalLineStartX, y: horizontalLineY))
                    path.addLine(to: CGPoint(x: horizontalLineEndX, y: horizontalLineY))
                }
                .stroke(Color(red: 0.4, green: 0.2, blue: 0.6), style: StrokeStyle(lineWidth: 2))
                
                // Vertical line from horizontal line down to Buttons 1+2 text (CENTERED WITH OFFSET)
                Path { path in
                    let centerPointX = (horizontalLineStartX + horizontalLineEndX) / 2
                    path.move(to: CGPoint(x: centerPointX, y: horizontalLineY))
                    path.addLine(to: CGPoint(x: centerPointX, y: textTopY))
                }
                .stroke(Color(red: 0.4, green: 0.2, blue: 0.6), style: StrokeStyle(lineWidth: 2))
                
                // ADD ARROWS TO THE TIP OF VERTICAL DARK PURPLE LINES POINTING UP AT BUTTONS
                // FIXED: Left arrow at EXTENDED LEFT ENDPOINT (under Button 1)
                Path { path in
                    let arrowSize: CGFloat = 8
                    let tipX = horizontalLineStartX
                    let tipY = buttonBottomY
                    
                    path.move(to: CGPoint(x: tipX, y: tipY))
                    path.addLine(to: CGPoint(x: tipX - arrowSize, y: tipY + arrowSize))
                    path.move(to: CGPoint(x: tipX, y: tipY))
                    path.addLine(to: CGPoint(x: tipX + arrowSize, y: tipY + arrowSize))
                }
                .stroke(Color(red: 0.4, green: 0.2, blue: 0.6), style: StrokeStyle(lineWidth: 2, lineCap: .round))
                
                // Right arrow at EXTENDED RIGHT ENDPOINT (under Button 2)
                Path { path in
                    let arrowSize: CGFloat = 8
                    let tipX = horizontalLineEndX
                    let tipY = buttonBottomY
                    
                    path.move(to: CGPoint(x: tipX, y: tipY))
                    path.addLine(to: CGPoint(x: tipX - arrowSize, y: tipY + arrowSize))
                    path.move(to: CGPoint(x: tipX, y: tipY))
                    path.addLine(to: CGPoint(x: tipX + arrowSize, y: tipY + arrowSize))
                }
                .stroke(Color(red: 0.4, green: 0.2, blue: 0.6), style: StrokeStyle(lineWidth: 2, lineCap: .round))
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
        case "button3":
            return codeToOption(code, validOptions: allButtonOptions)
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

// MARK: - PreferenceKey for tracking view frames
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

// MARK: - Device Selection Sheet
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
