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
    @State private var config: [String: Int] = [
        "button1": 3,   // Undo
        "button2": 5,   // Erase
        "button3": 3,   // Click on Scroll -> Undo
        "combo": 8,     // Brush Library
        "scroll": 6     // Brush Size ±5%
    ]  // Undo, Erase, Brush Library, Brush Size 5%
    
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
    @State private var customToSave: Int = 1
    
    // Preset system - RENAMED TO CUSTOMS
    @AppStorage("custom1") private var custom1Data: String = ""
    @AppStorage("custom2") private var custom2Data: String = ""
    @AppStorage("custom3") private var custom3Data: String = ""
    
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
        return availableCustoms
    }
    
    // DEFAULT CONFIGURATION
    private let defaultConfig: [String: Int] = [
        "button1": 3,   // Undo
        "button2": 5,   // Erase
        "button3": 3,   // Click on Scroll -> Undo
        "combo": 8,     // Brush Library
        "scroll": 6     // Brush Size ±5%
    ]  // Undo, Erase, Brush Library, Brush Size 5%
    
    // SCALING CONSTANTS
    private let controllerScale: CGFloat = 1.5
    private let buttonScale: CGFloat = 1.5
    
    var body: some View {
        GeometryReader { geometry in
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
                
                // Tutorial overlay
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
                
                if showCustomRenameAlert {
                    popupBackground {
                        renameCustomPopup()
                    }
                }
                
                if showSaveConfirmation {
                    popupBackground {
                        saveConfirmationPopup()
                    }
                }
                
                if showSaveCustomDropdown {
                    Color.clear
                        .contentShape(Rectangle())
                        .onTapGesture {
                            showSaveCustomDropdown = false
                        }
                        .overlay(
                            VStack(spacing: 0) {
                                Text("Save Current Configuration")
                                    .font(.headline)
                                    .foregroundColor(Color(red: 0.4, green: 0.2, blue: 0.6))
                                    .padding()
                                    .frame(maxWidth: .infinity)
                                    .background(Color.gray.opacity(0.1))
                                
                                // Always show all 3 slots
                                ForEach(1...3, id: \.self) { slot in
                                    Button(action: {
                                        customToSave = slot
                                        showSaveConfirmation = true
                                        showSaveCustomDropdown = false
                                    }) {
                                        HStack {
                                            // Use custom name if it exists, otherwise "Custom X"
                                            Text(getCustomNameForSlot(slot))
                                                .font(.system(size: 16, weight: .semibold))
                                                .foregroundColor(.black)
                                            Spacer()
                                        }
                                        .padding()
                                        .background(Color.white)
                                    }
                                    
                                    if slot != 3 {
                                        Divider()
                                    }
                                }
                            }
                            .background(Color.white)
                            .cornerRadius(12)
                            .shadow(radius: 5)
                            .frame(width: 280)
                            .position(
                                x: UIScreen.main.bounds.width - 200, // Position near the right edge
                                y: UIScreen.main.bounds.height - 200 // Position near the bottom
                            )
                        )
                }
            }
        }
    }
    
    private func popupBackground<Content: View>(@ViewBuilder content: @escaping () -> Content) -> some View {
        Color.black.opacity(0.4)
            .ignoresSafeArea()
            .overlay(
                content()
                    .position(x: UIScreen.main.bounds.width / 2, y: UIScreen.main.bounds.height / 2)
            )
    }
    
    private func renameCustomPopup() -> some View {
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
    
    private func saveConfirmationPopup() -> some View {
        VStack(spacing: 16) {
            Text("Save Custom")
                .font(.headline)
                .fontWeight(.bold)
                .foregroundColor(.primary)
            
            Text("Save as '\(getCustomNameForSlot(customToSave))'?")
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
                        
                        VStack(spacing: 30) {
                            HStack(spacing: 10) {
                                // SCROLL AXIS CONFIG (top left)
                                VStack(spacing: 8) {
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
                                            .multilineTextAlignment(.center)
                                            .frame(width: 160, alignment: .center)
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
                                
                                // Button 1 - Larger
                                VStack(spacing: 8) {
                                    // INCREASED SIZE OF CURRENT CONFIG DISPLAY - NOW CLICKABLE
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
                                            .multilineTextAlignment(.center)
                                            .frame(width: 140, alignment: .center)
                                    }
                                    .buttonStyle(PlainButtonStyle())
                                    
                                    // Circle button 1 visual
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
                                    
                                    // Label
                                    Button(action: {
                                        showButton1Dropdown = true
                                    }) {
                                        Text("Button 1")
                                            .font(.system(size: 16, weight: .semibold))
                                            .foregroundColor(Color(red: 0.85, green: 0.4, blue: 0.7)) // PASTEL RED-PURPLE TEXT
                                    }
                                    .buttonStyle(PlainButtonStyle())
                                    .padding(.top, 10)
                                }
                                .offset(y: 205)
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
                                
                                // Button 2 - Larger
                                VStack(spacing: 8) {
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
                                            .multilineTextAlignment(.center)
                                            .frame(width: 140, alignment: .center)
                                    }
                                    .buttonStyle(PlainButtonStyle())
                                    
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
                                    
                                    Button(action: {
                                        showButton2Dropdown = true
                                    }) {
                                        Text("Button 2")
                                            .font(.system(size: 16, weight: .semibold))
                                            .foregroundColor(Color(red: 0.5, green: 0.4, blue: 0.9)) // PASTEL BLUE-PURPLE TEXT
                                    }
                                    .buttonStyle(PlainButtonStyle())
                                    .padding(.top, 10)
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
                
                // VERTICAL ARROW + CLICK ON SCROLL
                VStack(spacing: 0) {
                    // VERTICAL ARROW POINTING UP - HALVED LENGTH
                    GeometryReader { geometry in
                        ZStack {
                            // Calculate position for the vertical arrow (centered above click scroll button)
                            let clickScrollCenterX = geometry.size.width / 2 - 250 // Same X as click scroll
                            let clickScrollTopY = (geometry.size.height / 2) - (100 * buttonScale * 0.3) + 15
                            
                            let arrowY = clickScrollTopY - 60 + 120
                            
                            // Vertical line
                            Path { path in
                                let arrowLength: CGFloat = 30
                                path.move(to: CGPoint(x: clickScrollCenterX, y: arrowY + arrowLength))
                                path.addLine(to: CGPoint(x: clickScrollCenterX, y: arrowY))
                            }
                            .stroke(Color(red: 0.4, green: 0.2, blue: 0.6),
                                    style: StrokeStyle(lineWidth: 2, lineCap: .round))
                            
                            // Arrow head
                            Path { path in
                                let arrowSize: CGFloat = 8
                                path.move(to: CGPoint(x: clickScrollCenterX, y: arrowY))
                                path.addLine(to: CGPoint(x: clickScrollCenterX - arrowSize, y: arrowY + arrowSize))
                                path.move(to: CGPoint(x: clickScrollCenterX, y: arrowY))
                                path.addLine(to: CGPoint(x: clickScrollCenterX + arrowSize, y: arrowY + arrowSize))
                            }
                            .stroke(Color(red: 0.4, green: 0.2, blue: 0.6),
                                    style: StrokeStyle(lineWidth: 2, lineCap: .round))
                        }
                    }
                    
                    VStack(spacing: 8) {
                        // Config display for the click scroll button (uses button3)
                        Button(action: {
                            showClickScrollDropdown = true
                        }) {
                            Text(getCurrentSelection(for: "button3"))
                                .font(.system(size: 10, weight: .medium))
                                .foregroundColor(.white)
                                .padding(.horizontal, 6)
                                .padding(.vertical, 3)
                                .background(Color(red: 0.7, green: 0.5, blue: 0.8))
                                .cornerRadius(4)
                                .overlay(
                                    RoundedRectangle(cornerRadius: 4)
                                        .stroke(Color(red: 0.4, green: 0.2, blue: 0.6), lineWidth: 2)
                                )
                                .fixedSize(horizontal: false, vertical: true)
                        }
                        .buttonStyle(PlainButtonStyle())
                        
                        // Click scroll button with finger-clicking symbol
                        Button(action: {
                            showClickScrollDropdown = true
                        }) {
                            ZStack {
                                Capsule()
                                    .fill(Color(red: 0.7, green: 0.5, blue: 0.8))
                                    .frame(width: 36, height: 60)
                                
                                Capsule()
                                    .stroke(Color(red: 0.4, green: 0.2, blue: 0.6), lineWidth: 2)
                                    .frame(width: 36, height: 60)
                                
                                VStack(spacing: 2) {
                                    Image(systemName: "hand.tap.fill")
                                        .font(.system(size: 12, weight: .bold))
                                        .foregroundColor(.white)
                                        .padding(.top, 4)
                                    
                                    Circle()
                                        .fill(Color.white.opacity(0.3))
                                        .frame(width: 8, height: 8)
                                        .offset(y: 2)
                                }
                            }
                        }
                        .buttonStyle(PlainButtonStyle())
                        
                        Button(action: {
                            showClickScrollDropdown = true
                        }) {
                            Text("Click on Scroll")
                                .font(.system(size: 12, weight: .semibold))
                                .foregroundColor(Color(red: 0.7, green: 0.5, blue: 0.8))

                        }
                        .buttonStyle(PlainButtonStyle())
                    }
                    .offset(x: -250, y: 25)
                    .popover(isPresented: $showClickScrollDropdown,
                             attachmentAnchor: .point(.bottom),
                             arrowEdge: .top) {
                        VStack(spacing: 0) {
                            ForEach(circleButton1Options, id: \.self) { option in
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
                                if option != circleButton1Options.last {
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
                .frame(height: 200)
                
                // Buttons 1+2 combo config
                VStack(spacing: 8) {
                    Button(action: {
                        showComboDropdown = true
                    }) {
                        Text(getCurrentSelection(for: "combo"))
                            .font(.system(size: 16, weight: .medium))
                            .foregroundColor(.white)
                            .padding(.horizontal, 12)
                            .padding(.vertical, 6)
                            .background(Color(red: 0.7, green: 0.5, blue: 0.8))
                            .cornerRadius(6)
                            .overlay(
                                RoundedRectangle(cornerRadius: 6)
                                    .stroke(Color(red: 0.4, green: 0.2, blue: 0.6), lineWidth: 2)
                            )
                            .multilineTextAlignment(.center)
                            .frame(width: 160, alignment: .center)
                    }
                    .buttonStyle(PlainButtonStyle())
                    
                    Button(action: {
                        showComboDropdown = true
                    }) {
                        HStack(spacing: 6) {
                            ZStack {
                                Circle()
                                    .fill(Color(red: 0.85, green: 0.4, blue: 0.7).opacity(0.8))
                                    .frame(width: 28, height: 28)
                                
                                Circle()
                                    .stroke(Color.white, lineWidth: 1)
                                    .frame(width: 28, height: 28)
                                
                                Text("1")
                                    .font(.system(size: 12, weight: .bold))
                                    .foregroundColor(.white)
                            }
                            
                            Text("+")
                                .font(.system(size: 16, weight: .bold))
                                .foregroundColor(.white)
                            
                            ZStack {
                                Circle()
                                    .fill(Color(red: 0.5, green: 0.4, blue: 0.9).opacity(0.8))
                                    .frame(width: 28, height: 28)
                                
                                Circle()
                                    .stroke(Color.white, lineWidth: 1)
                                    .frame(width: 28, height: 28)
                                
                                Text("2")
                                    .font(.system(size: 12, weight: .bold))
                                    .foregroundColor(.white)
                            }
                        }
                        .padding(.horizontal, 16)
                        .padding(.vertical, 12)
                        .background(Color(red: 0.7, green: 0.5, blue: 0.8))
                        .cornerRadius(8)
                        .overlay(
                            RoundedRectangle(cornerRadius: 8)
                                .stroke(Color(red: 0.4, green: 0.2, blue: 0.6), lineWidth: 2)
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
                .offset(x: 130, y: -95)
                .popover(isPresented: $showComboDropdown,
                         attachmentAnchor: .point(.bottom),
                         arrowEdge: .top) {
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
                    VStack(spacing: 12) {
                        // Active Custom Indicator
                        VStack(spacing: 8) {
                            HStack(spacing: 8) {
                                Image(systemName: "dial.max.fill")
                                    .font(.system(size: 20))
                                    .foregroundColor(Color(red: 0.4, green: 0.2, blue: 0.6))
                                Text("Hardware Switch Position: Custom \(bleManager.currentCustom + 1)")
                                    .font(.system(size: 15, weight: .semibold))
                                    .foregroundColor(Color(red: 0.4, green: 0.2, blue: 0.6))
                            }
                            
                            Text("Any changes you make will be saved to Custom \(bleManager.currentCustom + 1). Move the 3-position switch on your device to switch between Custom 1, Custom 2, and Custom 3.")
                                .font(.caption)
                                .multilineTextAlignment(.center)
                                .foregroundColor(.secondary)
                                .padding(.horizontal, 8)
                        }
                        .padding()
                        .background(
                            RoundedRectangle(cornerRadius: 12)
                                .fill(Color.green.opacity(0.1))
                        )
                        .overlay(
                            RoundedRectangle(cornerRadius: 12)
                                .stroke(Color.green.opacity(0.3), lineWidth: 2)
                        )
                        
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
                        .background(
                            RoundedRectangle(cornerRadius: 12)
                                .fill(Color(red: 0.4, green: 0.2, blue: 0.6).opacity(0.1))
                        )
                    }
                    .padding(.horizontal)
                    .padding(.top, 30)
                }
                
                Spacer().frame(height: 30)
                
                if !bleManager.statusMessage.isEmpty {
                    StatusNotificationView(statusMessage: bleManager.statusMessage)
                        .offset(y: -90)
                }
                
                // Save Custom Button
                HStack {
                    Spacer()
                    Button(action: {
                        showSaveCustomDropdown = true
                    }) {
                        HStack(spacing: 8) {
                            Image(systemName: "square.and.arrow.down")
                                .font(.system(size: 16))
                                .foregroundColor(Color(red: 0.4, green: 0.2, blue: 0.6))
                            Text("Save as Custom")
                                .font(.system(size: 16, weight: .semibold))
                                .foregroundColor(Color(red: 0.4, green: 0.2, blue: 0.6))
                        }
                        .padding(.horizontal, 20)
                        .padding(.vertical, 12)
                        .background(Color.white)
                        .cornerRadius(10)
                        .overlay(
                            RoundedRectangle(cornerRadius: 10)
                                .stroke(Color(red: 0.4, green: 0.2, blue: 0.6), lineWidth: 2)
                        )
                    }
                    .padding(.trailing, 80)
                    .padding(.bottom, 100)
                    .offset(y: -300)
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
        
        ToolbarItemGroup(placement: .navigationBarTrailing) {
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
            .popover(isPresented: $showCustomsDropdown,
                     attachmentAnchor: .point(.bottom),
                     arrowEdge: .top) {
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
            
            ForEach(1...3, id: \.self) { slot in
                Button(action: {
                    customToSave = slot
                    showSaveConfirmation = true
                    showSaveCustomDropdown = false
                }) {
                    HStack {
                        Text(getCustomNameForSlot(slot))
                            .font(.system(size: 16, weight: .semibold))
                            .foregroundColor(.black)
                        Spacer()
                    }
                    .padding()
                    .background(Color.white)
                }
                
                if slot != 3 {
                    Divider()
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
        
        if !hasCompletedOnboarding {
            print("📱 🎓 Showing interactive tutorial for first time!")
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.1) {
                showInteractiveTutorial = true
                print("📱 ✅ showInteractiveTutorial set to true")
            }
        } else {
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
    
    // MARK: - Reset to Default
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
                                    Text("Scroll: \(codeToOption(custom.config["scroll"] ?? 0, validOptions: scrollOptions))")
                                        .font(.system(size: 12))
                                        .foregroundColor(.black)
                                    
                                    Text("Click on Scroll: \(codeToOption(custom.config["button3"] ?? 0, validOptions: circleButton1Options))")
                                        .font(.system(size: 12))
                                        .foregroundColor(.black)

                                    Text("Button 1: \(codeToOption(custom.config["button1"] ?? 0, validOptions: circleButton1Options))")
                                        .font(.system(size: 12))
                                        .foregroundColor(.black)
                                    
                                    Text("Button 2: \(codeToOption(custom.config["button2"] ?? 0, validOptions: circleButton2Options))")
                                        .font(.system(size: 12))
                                        .foregroundColor(.black)
                                    
                                    Text("Buttons 1 + 2: \(codeToOption(custom.config["combo"] ?? 0, validOptions: buttons12Options))")
                                        .font(.system(size: 12))
                                        .foregroundColor(.black)
                                }
                            }
                        }
                        .buttonStyle(PlainButtonStyle())
                        
                        Spacer()
                        
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
        guard (1...3).contains(slot) else {
            return "Custom"
        }
        
        if let existingName = UserDefaults.standard.string(forKey: "custom\(slot)Name"),
           !existingName.isEmpty {
            return existingName
        } else {
            return "Custom \(slot)"
        }
    }
    
    func findFirstAvailableSlot() -> Int {
        for slot in 2...3 {
            switch slot {
            case 2 where custom2Data.isEmpty:
                return 2
            case 3 where custom3Data.isEmpty:
                return 3
            default:
                continue
            }
        }
        return 2
    }
    
    func saveCustom(slot: Int) {
        do {
            let jsonData = try JSONSerialization.data(withJSONObject: config, options: [])
            let jsonString = String(data: jsonData, encoding: .utf8) ?? ""
            
            switch slot {
            case 1:
                custom1Data = jsonString
            case 2:
                custom2Data = jsonString
            case 3:
                custom3Data = jsonString
            default:
                break
            }
            
            print("💾 Custom \(slot) saved locally: \(config)")
            
            // CRITICAL: Also send to ESP32 with targetCustom parameter
            // This allows saving to any custom, not just the current one
            if bleManager.isConnected {
                let targetCustom = slot - 1  // Convert 1-based slot to 0-based index
                bleManager.writeConfigToCustom(config: config, targetCustom: targetCustom)
                print("📤 Sent to ESP32 targeting Custom \(slot)")
            } else {
                print("⚠️ Not connected - will sync when connected")
            }
        } catch {
            print("❌ Failed to save custom: \(error)")
        }
    }
    
    func saveCustomName(_ slot: Int, name: String) {
        let trimmedName = name.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmedName.isEmpty else { return }
        
        UserDefaults.standard.set(trimmedName, forKey: "custom\(slot)Name")
        print("💾 Custom \(slot) renamed to: '\(trimmedName)'")
        UserDefaults.standard.synchronize()
        
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
                    let bodyWidth: CGFloat = 480 * 1.3
                    let bodyHeight: CGFloat = (197.5 * 1.25) - 45
                    let cornerRadius: CGFloat = 23.5
                    
                    let bodyRect = CGRect(
                        x: centerX - bodyWidth / 2,
                        y: containerHeight / 2 - bodyHeight / 2 - 40,
                        width: bodyWidth,
                        height: bodyHeight
                    )
                    
                    path.addRoundedRect(
                        in: bodyRect,
                        cornerSize: CGSize(width: cornerRadius, height: cornerRadius)
                    )
                }
                .fill(Color.gray.opacity(0.4))
            }
        }
    }
    
    var connectionLines: some View {
        GeometryReader { geometry in
            ZStack {
                let containerWidth = geometry.size.width
                let centerX = containerWidth / 2
                let offset: CGFloat = 100
                
                let button1CenterX = centerX - 60 + offset
                let button2CenterX = centerX + 60 + offset
                
                let buttonBottomY: CGFloat = 308
                let horizontalLineY: CGFloat = 338
                let textTopY: CGFloat = 358
                
                let extensionAmount: CGFloat = 15      // how much longer the horizontal line gets
                let horizontalShift: CGFloat = -15     // shift everything left by 15

                let horizontalLineStartX = button1CenterX - 10 - extensionAmount / 2 + horizontalShift
                let horizontalLineEndX   = button2CenterX + 100 + extensionAmount / 2 + horizontalShift + 5

                Path { path in
                    path.move(to: CGPoint(x: horizontalLineStartX, y: buttonBottomY))
                    path.addLine(to: CGPoint(x: horizontalLineStartX, y: horizontalLineY))
                }
                .stroke(Color(red: 0.4, green: 0.2, blue: 0.6),
                        style: StrokeStyle(lineWidth: 2))
                
                Path { path in
                    path.move(to: CGPoint(x: horizontalLineEndX, y: buttonBottomY))
                    path.addLine(to: CGPoint(x: horizontalLineEndX, y: horizontalLineY))
                }
                .stroke(Color(red: 0.4, green: 0.2, blue: 0.6),
                        style: StrokeStyle(lineWidth: 2))
                
                Path { path in
                    path.move(to: CGPoint(x: horizontalLineStartX, y: horizontalLineY))
                    path.addLine(to: CGPoint(x: horizontalLineEndX, y: horizontalLineY))
                }
                .stroke(Color(red: 0.4, green: 0.2, blue: 0.6),
                        style: StrokeStyle(lineWidth: 2))
                
                Path { path in
                    let centerPointX = (horizontalLineStartX + horizontalLineEndX) / 2
                    path.move(to: CGPoint(x: centerPointX, y: horizontalLineY))
                    path.addLine(to: CGPoint(x: centerPointX, y: textTopY))
                }
                .stroke(Color(red: 0.4, green: 0.2, blue: 0.6),
                        style: StrokeStyle(lineWidth: 2))
                
                Path { path in
                    let arrowSize: CGFloat = 8
                    let tipX = horizontalLineStartX
                    let tipY = buttonBottomY
                    
                    path.move(to: CGPoint(x: tipX, y: tipY))
                    path.addLine(to: CGPoint(x: tipX - arrowSize, y: tipY + arrowSize))
                    path.move(to: CGPoint(x: tipX, y: tipY))
                    path.addLine(to: CGPoint(x: tipX + arrowSize, y: tipY + arrowSize))
                }
                .stroke(Color(red: 0.4, green: 0.2, blue: 0.6),
                        style: StrokeStyle(lineWidth: 2, lineCap: .round))
                
                Path { path in
                    let arrowSize: CGFloat = 8
                    let tipX = horizontalLineEndX
                    let tipY = buttonBottomY
                    
                    path.move(to: CGPoint(x: tipX, y: tipY))
                    path.addLine(to: CGPoint(x: tipX - arrowSize, y: tipY + arrowSize))
                    path.move(to: CGPoint(x: tipX, y: tipY))
                    path.addLine(to: CGPoint(x: tipX + arrowSize, y: tipY + arrowSize))
                }
                .stroke(Color(red: 0.4, green: 0.2, blue: 0.6),
                        style: StrokeStyle(lineWidth: 2, lineCap: .round))
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
            // Click on Scroll uses same options as Button 1
            return codeToOption(code, validOptions: circleButton1Options)
        case "combo":
            return codeToOption(code, validOptions: buttons12Options)
        default:
            return "Unknown"
        }
    }
    
    // Convert option string to numeric code
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
    
    // Convert numeric code to option string, with validation
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
                    }
                    .frame(maxHeight: .infinity)
                    .padding()
                } else if bleManager.devices.isEmpty {
                    VStack(spacing: 20) {
                        Image(systemName: "exclamationmark.triangle")
                            .font(.system(size: 50))
                            .foregroundColor(.orange)
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
                        
                        Button("Scan Again") {
                            bleManager.startScan()
                        }
                        .buttonStyle(.borderedProminent)
                        .tint(.orange)
                    }
                    .frame(maxHeight: .infinity)
                    .padding()
                } else {
                    List(bleManager.devices, id: \.identifier) { device in
                        Button(action: {
                            bleManager.connect(to: device)
                            showDeviceSheet = false
                        }) {
                            VStack(alignment: .leading, spacing: 4) {
                                Text(device.name ?? "Unknown Device").font(.headline)
                                Text(device.identifier.uuidString)
                                    .font(.caption)
                                    .foregroundColor(.gray)
                            }
                            .padding(.vertical, 8)
                        }
                    }
                    
                    Text("Found \(bleManager.devices.count) device(s)")
                        .font(.caption)
                        .foregroundColor(.gray)
                        .padding()
                }
            }
            .navigationTitle("Select Device")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button("Cancel") {
                        bleManager.stopScan()
                        showDeviceSheet = false
                    }
                }
            }
        }
    }
}
