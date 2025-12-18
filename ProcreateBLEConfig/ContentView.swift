import SwiftUI
import CoreBluetooth

struct StatusNotificationView: View {
    let statusMessage: String
    let isInitializing: Bool  // Add this parameter
    
    var body: some View {
        let isSuccess = statusMessage.contains("✓") || statusMessage.contains("successfully") || statusMessage.contains("Connected") || statusMessage.contains("Reconnected")
        let isBluetoothReady = statusMessage.contains("Bluetooth ready")
        let isReconnected = statusMessage.contains("Reconnected")
        let isInitializingBluetooth = statusMessage.contains("Initializing Bluetooth") || isInitializing
        
        let iconName: String
        let iconColor: Color
        let backgroundColor: Color
        let borderColor: Color
        
        if isInitializingBluetooth {
            // Initializing state - PASTEL YELLOW
            iconName = "arrow.triangle.2.circlepath.circle"
            iconColor = Color(red: 1.0, green: 0.85, blue: 0.4) // PASTEL YELLOW
            backgroundColor = Color(red: 1.0, green: 0.85, blue: 0.4).opacity(0.1)
            borderColor = Color(red: 1.0, green: 0.85, blue: 0.4).opacity(0.2)
        } else if isSuccess {
            if isReconnected {
                iconName = "arrow.clockwise.circle.fill"
                iconColor = .blue
                backgroundColor = Color.blue.opacity(0.1)
                borderColor = Color.blue.opacity(0.2)
            } else {
                iconName = "checkmark.circle.fill"
                iconColor = .green
                backgroundColor = Color.green.opacity(0.1)
                borderColor = Color.green.opacity(0.2)
            }
        } else if isBluetoothReady {
            iconName = "exclamationmark.circle.fill"
            iconColor = Color(red: 1.0, green: 0.85, blue: 0.4) // PASTEL YELLOW
            backgroundColor = Color(red: 1.0, green: 0.85, blue: 0.4).opacity(0.1)
            borderColor = Color(red: 1.0, green: 0.85, blue: 0.4).opacity(0.2)
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
                .foregroundColor(.white)
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
    @State private var clickScrollFrame: CGRect = .zero
    
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
    
    // Connection management
    @State private var connectionCheckTimer: Timer?
    
    // Force UI refresh trigger
    @State private var customsRefreshTrigger = false
    @State private var isShowingBluetoothView = false
    
    // Splash screen state - SIMPLE VERSION
    @State private var splashActive = true
    @State private var appWasInBackground = false
    @State private var showSplashOnActive = false

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
        var isActive: Bool = false
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
        ZStack {
            if splashActive {
                SplashScreenView(isActive: $splashActive)
                    .zIndex(1000)
            }
            
            // Main content (always there, but behind splash when active)
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
                            startConnectionCheckTimer()
                        }
                        .onDisappear {
                            stopConnectionCheckTimer()
                        }
                        .onChange(of: bleManager.detectedProblem) { problem in
                            if problem != nil {
                                showHelp = true
                            }
                        }
                        .onChange(of: bleManager.currentConfig) { newConfig in
                            print("🔄 Config updated from device: \(newConfig)")
                            config = newConfig
                        }
                        .onChange(of: bleManager.currentCustom) { newCustom in
                            print("🔄 Active custom changed to: \(newCustom)")
                            customsRefreshTrigger.toggle()
                        }
                        .onChange(of: bleManager.isConnected) { connected in
                            if connected {
                                print("✅ Connected - refreshing customs")
                                customsRefreshTrigger.toggle()
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
                            clickScrollFrame: clickScrollFrame,
                            comboFrame: comboFrame
                        )
                        .ignoresSafeArea(.container)
                    }
                    
                    // SINGLE SET OF POPUPS - positioned correctly
                    if showCustomRenameAlert {
                        Color.black.opacity(0.4)
                            .ignoresSafeArea()
                            .overlay(
                                renameCustomPopup()
                                    .padding(20)
                            )
                    }
                    
                    if showSaveConfirmation {
                        Color.black.opacity(0.4)
                            .ignoresSafeArea()
                            .overlay(
                                saveConfirmationPopup()
                                    .padding(20)
                            )
                    }
                    
                    if showSaveCustomDropdown {
                        Color.black.opacity(0.4)
                            .ignoresSafeArea()
                            .overlay(
                                saveCustomDropdownView()
                                    .padding(20)
                            )
                            .onTapGesture {
                                showSaveCustomDropdown = false
                            }
                    }
                }
            }
        }
        .onAppear {
            // Only show splash on first launch
            if !showSplashOnActive {
                splashActive = true
                showSplashOnActive = true
            }
        }
        .onChange(of: scenePhase) { newPhase in
            handleScenePhaseChange(newPhase)
        }
    }
    
    private func saveCustomDropdownView() -> some View {
        VStack(spacing: 0) {
            Text("Save Current Configuration")
                .font(.headline)
                .foregroundColor(Color(red: 0.098, green: 0.208, blue: 0.357))
                .padding()
                .frame(maxWidth: .infinity)
                .background(Color(red: 0.81, green: 0.95, blue: 1.0))
            
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
    }
    
    private func popupBackground<Content: View>(@ViewBuilder content: @escaping () -> Content) -> some View {
        Color.black.opacity(0.4)
            .ignoresSafeArea()
            .overlay(
                content()
                    .padding(20)
            )
    }
    
    private func renameCustomPopup() -> some View {
        VStack(spacing: 16) {
            Text("Rename Custom")
                .font(.headline)
                .fontWeight(.bold)
                .foregroundColor(Color(red: 0.098, green: 0.208, blue: 0.357))
            
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
                .foregroundColor(Color(red: 0.098, green: 0.208, blue: 0.357))
            
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
    
    private func navigateToBluetoothView() {
        isShowingBluetoothView = true
    }
    
    private var mainNavigationView: some View {
        NavigationStack {
            ZStack {
                Color.clear
                    .ignoresSafeArea()
                
                mainContentView
                    .toolbar {
                        toolbarContent
                    }
                    .toolbarBackground(Color(red: 0.42, green: 0.64, blue: 0.80), for: .navigationBar)
                    .toolbarBackground(.visible, for: .navigationBar)
                    .toolbarColorScheme(.dark, for: .navigationBar)
                    .navigationBarTitleTextColor(.white)
                    .navigationTitle("cliq")
                    .navigationBarTitleDisplayMode(.inline)
            }
            .navigationDestination(isPresented: $isShowingBluetoothView) {
                BluetoothConnectionView(bleManager: bleManager)
            }
        }
        .onReceive(bleManager.$isConnected) { connected in
            if connected {
                showDeviceSheet = false
                isShowingBluetoothView = false  // Close Bluetooth page when connected
            }
        }
    }
    
    private var mainContentView: some View {
        ZStack {
            // Background image - SIMPLIFIED VERSION
            if let uiImage = UIImage(named: "blackver") ?? UIImage(named: "blackver.png") {
                Image(uiImage: uiImage)
                    .resizable()
                    .scaledToFill() // Fills the space, maintains aspect ratio
                    .frame(width: UIScreen.main.bounds.width) // Constrain width to screen
                    .frame(maxHeight: .infinity) // Allow height to expand
                    .clipped() // IMPORTANT: Cuts off excess
                    .offset(y: 70) // Move down by x points
                    .ignoresSafeArea()
            } else {
                // Fallback color if image not found
                Color(red: 0.97, green: 0.94, blue: 1.0)
                    .ignoresSafeArea()
            }
            
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
                    // REMOVED: Text("Controller Configuration")
                    // ADD: Spacer with same height as the text would have been
                    Spacer()
                        .frame(height: 20) // Approximate height of the title text with font .title2
                    
                    ZStack {
                        Spacer()
                            .frame(height: 150)
                        
                        connectionLines
                            .offset(x: 0, y: 260)
                        
                        VStack(spacing: 30) {
                            HStack(spacing: 10) {
                                // MARK: - SCROLL AXIS CONFIG SECTION (updated)
                                VStack(spacing: 8) {
                                    Button(action: {
                                        showScrollDropdown = true
                                    }) {
                                        Text(getCurrentSelection(for: "scroll"))
                                            .font(.system(size: 20, weight: .medium)) // Changed from 14 to 16
                                            .foregroundColor(.white)
                                            .multilineTextAlignment(.center)
                                            .frame(width: 160, alignment: .center)
                                        }
                                    
                                    Button(action: {
                                        showScrollDropdown = true
                                    }) {
                                        ZStack {
                                            Capsule()
                                                .fill(Color(red: 0.235, green: 0.329, blue: 0.569))
                                                .frame(width: 60 * buttonScale, height: 100 * buttonScale)
                                            
                                            Capsule()
                                                .stroke(Color.white, lineWidth: 2)
                                                .frame(width: 60 * buttonScale, height: 100 * buttonScale)
                                            
                                            VStack(spacing: 4) {
                                                Image(systemName: "chevron.up")
                                                    .font(.system(size: 16 * buttonScale, weight: .bold))
                                                    .foregroundColor(.white)
                                                
                                                Image(systemName: "chevron.down")
                                                    .font(.system(size: 16 * buttonScale, weight: .bold))
                                                    .foregroundColor(.white)
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
                                        dropdownContent(
                                            options: scrollOptions,
                                            selectedOption: getCurrentSelection(for: "scroll"),
                                            onSelect: { option in
                                                config["scroll"] = optionToCode(option)
                                                showScrollDropdown = false
                                            }
                                        )
                                        .frame(width: 200)
                                    }
                                }
                                .offset(x: -100, y: 205)

                                // Button 1
                                VStack(spacing: 8) {
                                    Button(action: {
                                        showButton1Dropdown = true
                                    }) {
                                        Text(getCurrentSelection(for: "button1"))
                                            .font(.system(size: 20, weight: .medium)) // Changed from 14 to 16
                                            .foregroundColor(.white)
                                            .multilineTextAlignment(.center)
                                            .frame(width: 140, alignment: .center)
                                            .offset(y: -15) // Move text up to align with scroll's text
                                        }
                                    
                                    Button(action: {
                                        showButton1Dropdown = true
                                    }) {
                                        ZStack {
                                            Circle()
                                                .fill(Color(red: 0.302, green: 0.475, blue: 0.769))
                                                .frame(width: 80 * buttonScale, height: 80 * buttonScale)
                                            
                                            Circle()
                                                .stroke(Color.white, lineWidth: 2)
                                                .frame(width: 80 * buttonScale, height: 80 * buttonScale)
                                            
                                            Text("1")
                                                .font(.system(size: 24 * buttonScale, weight: .bold))
                                                .foregroundColor(.white)
                                        }
                                    }
                                    .buttonStyle(PlainButtonStyle())
                                    .background(GeometryReader { geo in
                                        Color.clear.preference(key: ViewFrameKey.self, value: geo.frame(in: .global))
                                    })
                                    .onPreferenceChange(ViewFrameKey.self) { frame in
                                        button1Frame = frame
                                    }
                                    .popover(isPresented: $showButton1Dropdown, attachmentAnchor: .point(.bottom), arrowEdge: .top) {
                                        dropdownContent(
                                            options: circleButton1Options,
                                            selectedOption: getCurrentSelection(for: "button1"),
                                            onSelect: { option in
                                                config["button1"] = optionToCode(option)
                                                showButton1Dropdown = false
                                            }
                                        )
                                        .frame(width: 150)
                                    }
                                }
                                .offset(y: 205)

                                // MARK: - BUTTON 2 SECTION (updated)
                                VStack(spacing: 8) {
                                    Button(action: {
                                        showButton2Dropdown = true
                                    }) {
                                        Text(getCurrentSelection(for: "button2"))
                                            .font(.system(size: 20, weight: .medium)) // Changed from 14 to 16
                                            .foregroundColor(.white)
                                            .multilineTextAlignment(.center)
                                            .frame(width: 140, alignment: .center)
                                            .offset(y: -15) // Move text up to align with scroll's text
                                        }
                                    
                                    Button(action: {
                                        showButton2Dropdown = true
                                    }) {
                                        ZStack {
                                            Circle()
                                                .fill(Color(red: 0.098, green: 0.208, blue: 0.357))
                                                .frame(width: 80 * buttonScale, height: 80 * buttonScale)
                                            
                                            Circle()
                                                .stroke(Color.white, lineWidth: 2)
                                                .frame(width: 80 * buttonScale, height: 80 * buttonScale)
                                            
                                            Text("2")
                                                .font(.system(size: 24 * buttonScale, weight: .bold))
                                                .foregroundColor(.white)
                                        }
                                    }
                                    .buttonStyle(PlainButtonStyle())
                                    .background(GeometryReader { geo in
                                        Color.clear.preference(key: Button2FrameKey.self, value: geo.frame(in: .global))
                                    })
                                    .onPreferenceChange(Button2FrameKey.self) { frame in
                                        button2Frame = frame
                                    }
                                    .popover(isPresented: $showButton2Dropdown, attachmentAnchor: .point(.bottom), arrowEdge: .top) {
                                        dropdownContent(
                                            options: circleButton2Options,
                                            selectedOption: getCurrentSelection(for: "button2"),
                                            onSelect: { option in
                                                config["button2"] = optionToCode(option)
                                                showButton2Dropdown = false
                                            }
                                        )
                                        .frame(width: 150)
                                    }
                                }
                                .offset(x: 100, y: 205)
                            }
                            .padding(.top, 20)
                        }
                        .frame(height: 320 * controllerScale)
                    }
                }
                .padding(.top, 15)
                .padding(.horizontal)
                
                VStack(spacing: 0) {
                    // VERTICAL ARROW
                    VStack(spacing: 0) {
                        // Simple arrow that just points down from its container
                        ZStack {
                            // Draw the arrow line (20 points long)
                            Path { path in
                                path.move(to: CGPoint(x: 0, y: 20)) // Start at bottom
                                path.addLine(to: CGPoint(x: 0, y: 0)) // Go to top
                            }
                            .stroke(Color.white,
                                    style: StrokeStyle(lineWidth: 2, lineCap: .round))
                        }
                        .frame(width: 1, height: 30) // Just enough for the arrow
                    }
                    .frame(width: 1, height: 30)
                    .offset(x: -250, y: 50)

                    // CLICK ON SCROLL CONFIG DISPLAY
                    VStack(spacing: 10) {
                        Button(action: {
                            showClickScrollDropdown = true
                        }) {
                            Text(getCurrentSelection(for: "button3"))
                                .font(.system(size: 20, weight: .medium)) // Changed back to 20
                                .foregroundColor(.white)
                                .multilineTextAlignment(.center)
                                .frame(width: 160, alignment: .center)
                                .fixedSize(horizontal: false, vertical: true)
                        }
                        
                        Button(action: {
                            showClickScrollDropdown = true
                        }) {
                            ZStack {
                                Capsule()
                                    .fill(Color(red: 0.235, green: 0.329, blue: 0.569))
                                    .frame(width: 54, height: 90)
                                
                                Capsule()
                                    .stroke(Color.white, lineWidth: 2)
                                    .frame(width: 54, height: 90)
                                
                                VStack(spacing: 2) {
                                    Image(systemName: "hand.tap.fill")
                                        .font(.system(size: 20, weight: .bold))
                                        .foregroundColor(.white)
                                        .padding(.top, 4)
                                }
                            }
                        }
                        .buttonStyle(PlainButtonStyle())
                        .background(
                            GeometryReader { geo in
                                Color.clear.preference(key: FramePreferenceKey.self, value: geo.frame(in: .global))
                            }
                        )
                        .onPreferenceChange(FramePreferenceKey.self) { frame in
                            clickScrollFrame = frame
                        }
                        .popover(isPresented: $showClickScrollDropdown,
                                 attachmentAnchor: .point(.bottom),
                                 arrowEdge: .top) {
                            dropdownContent(
                                options: circleButton1Options,
                                selectedOption: getCurrentSelection(for: "button3"),
                                onSelect: { option in
                                    config["button3"] = optionToCode(option)
                                    showClickScrollDropdown = false
                                }
                            )
                            .frame(width: 200)
                        }
                    }
                    .offset(x: -250, y: 60)
                }
                .frame(height: 200) // Keep same total height as before
                
                // Combo Button - Already has correct structure
                VStack(spacing: 15) {
                    Button(action: {
                        showComboDropdown = true
                    }) {
                        Text(getCurrentSelection(for: "combo"))
                            .font(.system(size: 20, weight: .medium))
                            .foregroundColor(.white)
                            .multilineTextAlignment(.center)
                            .frame(width: 160, alignment: .center)
                    }
                    .buttonStyle(PlainButtonStyle())
                    
                    Button(action: {
                        showComboDropdown = true
                    }) {
                        HStack(spacing: 10) {
                            ZStack {
                                Circle()
                                    .fill(Color(red: 0.302, green: 0.475, blue: 0.769))
                                    .frame(width: 50, height: 50)
                                
                                Circle()
                                    .stroke(Color.white, lineWidth: 1)
                                    .frame(width: 50, height: 50)
                                
                                Text("1")
                                    .font(.system(size: 20, weight: .bold))
                                    .foregroundColor(.white)
                            }
                            
                            Text("+")
                                .font(.system(size: 20, weight: .bold))
                                .foregroundColor(.white)
                            
                            ZStack {
                                Circle()
                                    .fill(Color(red: 0.098, green: 0.208, blue: 0.357))
                                    .frame(width: 50, height: 50)
                                
                                Circle()
                                    .stroke(Color.white, lineWidth: 1)
                                    .frame(width: 50, height: 50)
                                
                                Text("2")
                                    .font(.system(size: 20, weight: .bold))
                                    .foregroundColor(.white)
                            }
                        }
                    }
                    .buttonStyle(PlainButtonStyle())
                    .background(GeometryReader { geo in
                        Color.clear.preference(key: ComboFrameKey.self, value: geo.frame(in: .global))
                    })
                    .onPreferenceChange(ComboFrameKey.self) { frame in
                        comboFrame = frame
                    }
                    .popover(isPresented: $showComboDropdown,
                             attachmentAnchor: .point(.bottom),
                             arrowEdge: .top) {
                        dropdownContent(
                            options: buttons12Options,
                            selectedOption: getCurrentSelection(for: "combo"),
                            onSelect: { option in
                                config["combo"] = optionToCode(option)
                                showComboDropdown = false
                            }
                        )
                        .frame(width: 180)
                    }
                }
                .offset(x: 130, y: -105)
                
                Spacer().frame(height: 30)
                
                // Status notification - positioned at bottom left, aligned with scan button
                if !bleManager.statusMessage.isEmpty {
                    GeometryReader { geometry in
                        StatusNotificationView(
                            statusMessage: bleManager.statusMessage,
                            isInitializing: bleManager.isInitializing
                        )
                        .frame(maxWidth: geometry.size.width * 0.5, alignment: .leading) // Max 50% of screen width, left aligned
                        .position(
                            x: scanButtonFrame.minX + (geometry.size.width * 0.25), // Align left edge with scan button
                            y: geometry.size.height - 100 // 100pt from bottom
                        )
                    }
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
                                .foregroundColor(.white)
                            Text("Save as Custom")
                                .font(.system(size: 16, weight: .semibold))
                                .foregroundColor(.white)
                        }
                        .padding(.horizontal, 20)
                        .padding(.vertical, 12)
                        .background(Color(red: 0.42, green: 0.64, blue: 0.80).opacity(0.5))
                        .cornerRadius(10)
                        .overlay(
                            RoundedRectangle(cornerRadius: 10)
                                .stroke(Color(red: 0.42, green: 0.64, blue: 0.80), lineWidth: 2)
                        )
                    }
                    .padding(.trailing, 50)
                    .padding(.bottom, 100)
                    .offset(y: -160)
                }
                .padding(.top, 20)
                
                Spacer()
            }
            .padding(.vertical)
            .padding(.bottom, 30)
        }
    }
    
    // MARK: - Dropdown Content Helper (Scrollable Version)
    private func dropdownContent(options: [String], selectedOption: String, onSelect: @escaping (String) -> Void) -> some View {
        VStack(spacing: 0) {
            // Add a scroll view with fixed height
            ScrollView {
                VStack(spacing: 0) {
                    ForEach(options, id: \.self) { option in
                        Button(action: {
                            onSelect(option)
                        }) {
                            HStack {
                                Text(option)
                                    .foregroundColor(.primary)
                                    .frame(maxWidth: .infinity, alignment: .leading)
                                    .padding(.vertical, 12)
                                
                                if option == selectedOption {
                                    Image(systemName: "checkmark")
                                        .font(.system(size: 14))
                                        .foregroundColor(.blue)
                                        .padding(.trailing, 8)
                                }
                            }
                            .padding(.horizontal, 16)
                            .frame(height: 44) // Fixed height for each option
                            .contentShape(Rectangle()) // Makes entire area tappable
                        }
                        .buttonStyle(PlainButtonStyle())
                        
                        if option != options.last {
                            Divider()
                        }
                    }
                }
            }
            .frame(maxHeight: min(CGFloat(options.count) * 44, 300)) // Max height of 300 points
        }
        .padding(.vertical, 8)
        .background(Color.white)
        .cornerRadius(12)
        .shadow(radius: 5)
    }
    
    @ToolbarContentBuilder
    var toolbarContent: some ToolbarContent {
        // Left toolbar - Bluetooth and Help buttons
        ToolbarItem(placement: .navigationBarLeading) {
            HStack(spacing: 10) {
                Button(action: {
                    isShowingBluetoothView = true
                }) {
                    Image(systemName: bluetoothIconName)
                        .foregroundColor(Color(red: 0.81, green: 0.95, blue: 1.0))
                        .font(.system(size: 18))
                }
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
                    .foregroundColor(Color(red: 0.81, green: 0.95, blue: 1.0))
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
                .foregroundColor(Color(red: 0.81, green: 0.95, blue: 1.0))
                .padding(.horizontal, 12)
                .padding(.vertical, 6)
            }
            
            Button(action: {
                showCustomsDropdown = true
                if bleManager.isConnected {
                    customsRefreshTrigger.toggle()
                }
            }) {
                HStack(spacing: 6) {
                    Image(systemName: "list.bullet")
                        .font(.system(size: 16, weight: .medium))
                    Text("Customs")
                        .font(.system(size: 15, weight: .semibold))
                }
                .foregroundColor(Color(red: 0.81, green: 0.95, blue: 1.0))
                .padding(.horizontal, 12)
                .padding(.vertical, 6)
            }
            .popover(isPresented: $showCustomsDropdown,
                     attachmentAnchor: .point(.bottom),
                     arrowEdge: .top) {
                customMenuView
            }
        }
    }

    private var bluetoothIconName: String {
        // Always return the same icon so it's always visible
        return "dot.radiowaves.left.and.right"
    }
    
    func handleOnAppear() {
        print("📱 ContentView appeared")
        print("📱 hasCompletedOnboarding: \(hasCompletedOnboarding)")
        print("📱 showInteractiveTutorial: \(showInteractiveTutorial)")
        
        if !hasCompletedOnboarding {
            print("📱 🎓 Showing interactive tutorial for first time!")
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.1) {
                showInteractiveTutorial = true
                print("📱 ✅ showInteractiveTutorial set to true")
            }
        } else {
            // This only runs AFTER onboarding/tutorial is completed
            print("📱 Onboarding/tutorial completed")
            
            // Check if we should automatically show Bluetooth view
            let shouldAutoShowBluetooth = UserDefaults.standard.bool(forKey: "shouldAutoShowBluetoothAfterOnboarding")
            
            if !bleManager.isConnected && shouldAutoShowBluetooth {
                print("📱 First launch after onboarding - showing Bluetooth view automatically")
                isShowingBluetoothView = true
                // Reset the flag so we don't show it again
                UserDefaults.standard.set(false, forKey: "shouldAutoShowBluetoothAfterOnboarding")
            }
        }
    }
    
    private func handleScenePhaseChange(_ newPhase: ScenePhase) {
        switch newPhase {
        case .background:
            print("📱 App going to background")
            appWasInBackground = true
            bleManager.pauseBLEOperations()
            
        case .inactive:
            print("📱 App inactive")
            
        case .active:
            print("📱 App active")
            
            // Only show splash if NOT returning from background
            // (i.e., only on cold start)
            if !appWasInBackground && !showSplashOnActive {
                splashActive = true
                showSplashOnActive = true
            }
            
            // Resume BLE operations when app becomes active
            bleManager.resumeBLEOperations()
            
            // Reset for next time
            appWasInBackground = false
            
            // Refresh UI after resuming
            DispatchQueue.main.asyncAfter(deadline: .now() + 1.0) {
                if self.bleManager.isConnected {
                    self.customsRefreshTrigger.toggle()
                }
            }
            
        @unknown default:
            break
        }
    }
    
    private func startConnectionCheckTimer() {
        stopConnectionCheckTimer()
        
        connectionCheckTimer = Timer.scheduledTimer(withTimeInterval: 5.0, repeats: true) { _ in
            if self.bleManager.isConnected {
                self.bleManager.verifyConnection()
            }
        }
    }
    
    private func stopConnectionCheckTimer() {
        connectionCheckTimer?.invalidate()
        connectionCheckTimer = nil
    }
    
    // MARK: - Reset to Default
    func resetToDefault() {
        self.config = defaultConfig
        print("🔄 Reset to default configuration: \(defaultConfig)")
    }
    
    // MARK: - Helper Functions
    func loadConfigFromJSON(_ jsonString: String) -> [String: Int]? {
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
        _ = customsRefreshTrigger
        
        var availableCustoms: [Custom] = []
        
        if let custom1Config = loadConfigFromJSON(custom1Data) {
            let name = UserDefaults.standard.string(forKey: "custom1Name") ?? "Custom 1"
            let isActive = bleManager.isConnected && bleManager.currentCustom == 0
            availableCustoms.append(Custom(id: 1, name: name, config: custom1Config, isActive: isActive))
        }
        
        if let custom2Config = loadConfigFromJSON(custom2Data) {
            let name = UserDefaults.standard.string(forKey: "custom2Name") ?? "Custom 2"
            let isActive = bleManager.isConnected && bleManager.currentCustom == 1
            availableCustoms.append(Custom(id: 2, name: name, config: custom2Config, isActive: isActive))
        }
        
        if let custom3Config = loadConfigFromJSON(custom3Data) {
            let name = UserDefaults.standard.string(forKey: "custom3Name") ?? "Custom 3"
            let isActive = bleManager.isConnected && bleManager.currentCustom == 2
            availableCustoms.append(Custom(id: 3, name: name, config: custom3Config, isActive: isActive))
        }
        return availableCustoms
    }
    
    // MARK: - Custom Menu View
    var customMenuView: some View {
        let _ = customsRefreshTrigger
        
        return VStack(spacing: 0) {
            Text("Saved Customs")
                .font(.headline)
                .foregroundColor(Color(red: 0.098, green: 0.208, blue: 0.357))
                .padding()
                .frame(maxWidth: .infinity)
                .background(Color(red: 0.81, green: 0.95, blue: 1.0))
            
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
                                HStack(spacing: 6) {
                                    Text(custom.name)
                                        .font(.system(size: 16, weight: .semibold))
                                        .foregroundColor(.black)
                                    
                                    if custom.isActive && bleManager.isConnected {
                                        Image(systemName: "checkmark.circle.fill")
                                            .font(.system(size: 12))
                                            .foregroundColor(.green)
                                            .padding(.leading, 4)
                                        
                                        Text("ACTIVE")
                                            .font(.system(size: 10, weight: .bold))
                                            .foregroundColor(.green)
                                            .padding(.horizontal, 6)
                                            .padding(.vertical, 2)
                                            .background(Color.green.opacity(0.1))
                                            .cornerRadius(4)
                                    }
                                }
                                
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
                    .background(custom.isActive ? Color.green.opacity(0.1) : Color.white)
                    .overlay(
                        RoundedRectangle(cornerRadius: 0)
                            .stroke(custom.isActive ? Color.green.opacity(0.3) : Color.clear, lineWidth: 2)
                    )
                    
                    if custom.id != customs.last?.id {
                        Divider()
                    }
                }
                
                if bleManager.isConnected {
                    VStack(spacing: 4) {
                        Divider()
                        Text("Device switch position: Custom \(bleManager.currentCustom + 1)")
                            .font(.system(size: 11))
                            .foregroundColor(.secondary)
                            .padding(.vertical, 8)
                    }
                }
            }
        }
        .background(Color.white)
        .cornerRadius(12)
        .shadow(radius: 5)
        .frame(width: 320)
    }
    
    var helpMenuView: some View {
        VStack(spacing: 0) {
            Text("Help")
                .font(.headline)
                .foregroundColor(Color(red: 0.42, green: 0.64, blue: 0.80))
                .padding()
                .frame(maxWidth: .infinity)
                .background(Color.gray.opacity(0.1))
            
            Button(action: {
                showHelpDropdown = false
                showHelp = true
            }) {
                HStack {
                    Image(systemName: "questionmark.circle")
                        .foregroundColor(Color(red: 0.42, green: 0.64, blue: 0.80))
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
                        .foregroundColor(Color(red: 0.42, green: 0.64, blue: 0.80))
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
            
            if bleManager.isConnected {
                let targetCustom = slot - 1
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
    }
    
    func loadCustom(_ custom: Custom) {
        self.config = custom.config
        print("📥 Loaded custom \(custom.id): \(custom.config)")
    }
    
    var connectionLines: some View {
        GeometryReader { geometry in
            ZStack {
                let containerWidth = geometry.size.width
                let centerX = containerWidth / 2
                let offset: CGFloat = 100
                
                let button1CenterX = centerX - 60 + offset
                let button2CenterX = centerX + 60 + offset
                
                let arrowTipY: CGFloat = 308
                let textTopY: CGFloat = 328  // Changed from 358 to 328 (20 points difference)
                
                let extensionAmount: CGFloat = 15
                let horizontalShift: CGFloat = -15
                
                let originalStartX = button1CenterX - 10 - extensionAmount / 2 + horizontalShift
                let originalEndX = button2CenterX + 100 + extensionAmount / 2 + horizontalShift + 5
                
                let centerPointX = (originalStartX + originalEndX) / 2
                
                let topSpacing: CGFloat = 50
                
                let verticalLineStartX = centerPointX - (topSpacing / 2)
                let verticalLineEndX = centerPointX + (topSpacing / 2)
                
                Path { path in
                    path.move(to: CGPoint(x: verticalLineStartX, y: arrowTipY))
                    path.addLine(to: CGPoint(x: centerPointX, y: textTopY))
                }
                .stroke(Color.white,
                        style: StrokeStyle(lineWidth: 2))
                
                Path { path in
                    path.move(to: CGPoint(x: verticalLineEndX, y: arrowTipY))
                    path.addLine(to: CGPoint(x: centerPointX, y: textTopY))
                }
                .stroke(Color.white,
                        style: StrokeStyle(lineWidth: 2))
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
            return codeToOption(code, validOptions: circleButton1Options)
        case "combo":
            return codeToOption(code, validOptions: buttons12Options)
        default:
            return "Unknown"
        }
    }
    
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

struct FramePreferenceKey: PreferenceKey {
    static var defaultValue: CGRect = .zero
    static func reduce(value: inout CGRect, nextValue: () -> CGRect) {
        value = nextValue()
    }
}

// MARK: - Navigation Bar Title Color Extension
extension View {
    func navigationBarTitleTextColor(_ color: Color) -> some View {
        let uiColor = UIColor(color)
        UINavigationBar.appearance().titleTextAttributes = [.foregroundColor: uiColor]
        UINavigationBar.appearance().largeTitleTextAttributes = [.foregroundColor: uiColor]
        return self
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
                        Text("Scanning for CliQ Controller...").font(.headline)
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
                        Text("No CliQ Controller Found").font(.headline)
                        VStack(alignment: .leading, spacing: 8) {
                            Text("To enter CONFIG MODE:").font(.subheadline).bold()
                            Text("1️⃣ First boot: Device starts in CONFIG mode automatically").font(.caption)
                            Text("2️⃣ After configuration: Hold RESET button for 5 seconds").font(.caption)
                            Text("3️⃣ LED will flash rapidly 10 times").font(.caption)
                            Text("4️⃣ Device shows as 'CliQ Controller'").font(.caption)
                            Text("").font(.caption)
                            Text("⚠️ If device was paired to iPad:").font(.subheadline).bold().foregroundColor(.red)
                            Text("Go to Settings → Bluetooth → Forget 'CliQ Controller'").font(.caption).foregroundColor(.red)
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
