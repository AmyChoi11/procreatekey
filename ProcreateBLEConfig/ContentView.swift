import SwiftUI
import CoreBluetooth

struct ContentView: View {
    @StateObject private var bleManager = BLEManager()
    @Environment(\.scenePhase) private var scenePhase
    @AppStorage("hasCompletedOnboarding") private var hasCompletedOnboarding = false
    
    // Store configuration as numeric codes
    @State private var config: [String: Int] = ["button1": 3, "button2": 4, "combo": 7, "scroll": 9]  // Undo, Redo, Color Palette, Brush Size 10%
    @State private var showDeviceSheet = false
    @State private var hasShownInitialSheet = false
    @State private var showOnboarding = false
    @State private var showInteractiveTutorial = false
    @State private var showHelp = false
    
    // State for showing dropdowns
    @State private var showScrollDropdown = false
    @State private var showButton1Dropdown = false
    @State private var showButton2Dropdown = false
    @State private var showComboDropdown = false
    @State private var showPresetDropdown = false
    
    // Preset system
    @AppStorage("preset1") private var preset1Data: String = ""
    @AppStorage("preset2") private var preset2Data: String = ""
    @State private var showSavePresetAlert = false
    @State private var presetToSave: Int = 1
    
    // Combined options for all buttons (excluding brush size settings for buttons)
    let allButtonOptions = ["Undo", "Redo", "Erase", "Color Palette", "Brush Library"]
    var circleButton1Options: [String] { allButtonOptions }
    var circleButton2Options: [String] { allButtonOptions }
    var buttons12Options: [String] { allButtonOptions }
    let scrollOptions = ["Brush Size (5%)", "Brush Size (10%)"]
    
    // Preset structure
    struct Preset: Identifiable {
        let id: Int
        let name: String
        let config: [String: Int]
    }
    
    var presets: [Preset] {
        var availablePresets: [Preset] = []
        
        if let preset1 = loadPreset(from: preset1Data) {
            availablePresets.append(Preset(id: 1, name: "Preset 1", config: preset1))
        }
        
        if let preset2 = loadPreset(from: preset2Data) {
            availablePresets.append(Preset(id: 2, name: "Preset 2", config: preset2))
        }
        
        return availablePresets
    }
    
    var body: some View {
        NavigationStack {
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
                                    .frame(height: 350) // Increased height for larger diagram
                                    .shadow(color: Color.black.opacity(0.1), radius: 8, x: 0, y: 4)
                                
                                // Orange connection lines - Positioned above the outline
                                connectionLines
                                
                                // Nintendo Switch Controller Outline - With smaller cylindrical grips
                                controllerOutline
                                
                                VStack(spacing: 30) {
                                    // Top: Buttons 1+2 Combo Text
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
                                    .popover(isPresented: $showComboDropdown, attachmentAnchor: .point(.bottom), arrowEdge: .top) {
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
                                    .offset(y: -20)
                                    
                                    // Bottom: Button 1 - Scroll - Button 2
                                    HStack(spacing: 30) { // Changed from 60 to 30 (15 closer on each side)
                                        // Button 1 - Larger
                                        VStack(spacing: 8) {
                                            Text(getCurrentSelection(for: "button1"))
                                                .font(.system(size: 12, weight: .medium))
                                                .foregroundColor(.blue)
                                                .padding(.horizontal, 8)
                                                .padding(.vertical, 4)
                                                .background(Color.blue.opacity(0.1))
                                                .cornerRadius(4)
                                                .fixedSize(horizontal: false, vertical: true)
                                                .frame(maxWidth: 100)
                                            
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
                                        
                                        // Scroll - Pill/Capsule shape
                                        VStack(spacing: 8) {
                                            Text(getCurrentSelection(for: "scroll"))
                                                .font(.system(size: 12, weight: .medium))
                                                .foregroundColor(Color(red: 0.4, green: 0.2, blue: 0.6))
                                                .padding(.horizontal, 8)
                                                .padding(.vertical, 4)
                                                .background(Color(red: 0.4, green: 0.2, blue: 0.6).opacity(0.1))
                                                .cornerRadius(4)
                                                .fixedSize(horizontal: false, vertical: true)
                                                .frame(maxWidth: 120)
                                            
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
                                                }
                                            }
                                            .buttonStyle(PlainButtonStyle())
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
                                            Text(getCurrentSelection(for: "button2"))
                                                .font(.system(size: 12, weight: .medium))
                                                .foregroundColor(.red)
                                                .padding(.horizontal, 8)
                                                .padding(.vertical, 4)
                                                .background(Color.red.opacity(0.1))
                                                .cornerRadius(4)
                                                .fixedSize(horizontal: false, vertical: true)
                                                .frame(maxWidth: 100)
                                            
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
                                }
                            }
                            .frame(height: 320)
                            
                            // Save Preset Button - Moved down by 10
                            Button(action: {
                                showSavePresetAlert = true
                            }) {
                                HStack(spacing: 8) {
                                    Image(systemName: "square.and.arrow.down")
                                        .font(.system(size: 16))
                                    Text("Save as Preset")
                                        .font(.system(size: 16, weight: .semibold))
                                }
                                .foregroundColor(.white)
                                .padding(.horizontal, 20)
                                .padding(.vertical, 12)
                                .background(Color.green)
                                .cornerRadius(10)
                            }
                            .padding(.top, 10) // Changed from 5 to 10 to move button down by 10
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
            .toolbar {
                // Left toolbar - Bluetooth Scan/Connect button styled like Presets
                ToolbarItem(placement: .navigationBarLeading) {
                    HStack(spacing: 10) {
                        // Bluetooth button styled like Presets
                        Button(action: {
                            if bleManager.isConnected {
                                bleManager.disconnect()
                            } else if !bleManager.isScanning {
                                bleManager.startScan()
                                showDeviceSheet = true
                            }
                        }) {
                            HStack(spacing: 6) {
                                Image(systemName: "bluetooth")
                                    .font(.system(size: 16, weight: .medium))
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
                        
                        // Help button
                        Button(action: { showHelp = true }) {
                            Image(systemName: "questionmark.circle")
                                .foregroundColor(.white)
                                .font(.system(size: 18))
                        }
                        .simultaneousGesture(
                            LongPressGesture(minimumDuration: 2.0)
                                .onEnded { _ in
                                    // Long press to show interactive tutorial again
                                    showInteractiveTutorial = true
                                }
                        )
                    }
                }
                
                // Right toolbar - Presets button
                ToolbarItem(placement: .navigationBarTrailing) {
                    // Preset Menu Button
                    Button(action: {
                        showPresetDropdown = true
                    }) {
                        HStack(spacing: 6) {
                            Image(systemName: "list.bullet")
                                .font(.system(size: 16, weight: .medium))
                            Text("Presets")
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
                    .popover(isPresented: $showPresetDropdown, attachmentAnchor: .point(.bottom), arrowEdge: .top) {
                        presetMenuView
                    }
                }
            }
            .toolbarBackground(Color(red: 0.4, green: 0.2, blue: 0.6), for: .navigationBar)
            .toolbarBackground(.visible, for: .navigationBar)
            .toolbarColorScheme(.dark, for: .navigationBar)
        }
        .fullScreenCover(isPresented: $showInteractiveTutorial) {
            InteractiveTutorialView(
                showTutorial: $showInteractiveTutorial,
                hasCompletedOnboarding: $hasCompletedOnboarding
            )
        }
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
        .actionSheet(isPresented: $showSavePresetAlert) {
            ActionSheet(
                title: Text("Save Current Configuration"),
                message: Text("Choose a preset slot to save your current configuration"),
                buttons: [
                    .default(Text("Save as Preset 1")) {
                        savePreset(slot: 1)
                    },
                    .default(Text("Save as Preset 2")) {
                        savePreset(slot: 2)
                    },
                    .cancel()
                ]
            )
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
        .onAppear {
            print("📱 ContentView appeared")
            print("📱 hasCompletedOnboarding: \(hasCompletedOnboarding)")
            
            // Show interactive tutorial only on first launch
            if !hasCompletedOnboarding {
                print("📱 🎓 Showing interactive tutorial for first time!")
                // Show tutorial immediately on first launch
                showInteractiveTutorial = true
            } else {
                // Only show device selection sheet if onboarding is complete
                if !hasShownInitialSheet && !bleManager.isConnected {
                    hasShownInitialSheet = true
                    DispatchQueue.main.asyncAfter(deadline: .now() + 0.3) {
                        bleManager.startScan()
                        showDeviceSheet = true
                    }
                }
            }
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
    }
    
    // MARK: - Preset Menu View
    var presetMenuView: some View {
        VStack(spacing: 0) {
            Text("Saved Presets")
                .font(.headline)
                .foregroundColor(Color(red: 0.4, green: 0.2, blue: 0.6))
                .padding()
                .frame(maxWidth: .infinity)
                .background(Color.gray.opacity(0.1))
            
            if presets.isEmpty {
                Text("No presets saved")
                    .foregroundColor(.secondary)
                    .padding()
            } else {
                ForEach(presets) { preset in
                    Button(action: {
                        loadPreset(preset)
                        showPresetDropdown = false
                    }) {
                        VStack(alignment: .leading, spacing: 8) {
                            Text(preset.name)
                                .font(.system(size: 16, weight: .semibold))
                                .foregroundColor(.black)
                            
                            VStack(alignment: .leading, spacing: 4) {
                                Text("Button 1: \(codeToOption(preset.config["button1"] ?? 0, validOptions: circleButton1Options))")
                                    .font(.system(size: 12))
                                    .foregroundColor(.black)
                                Text("Button 2: \(codeToOption(preset.config["button2"] ?? 0, validOptions: circleButton2Options))")
                                    .font(.system(size: 12))
                                    .foregroundColor(.black)
                                Text("Buttons 1 + 2: \(codeToOption(preset.config["combo"] ?? 0, validOptions: buttons12Options))")
                                    .font(.system(size: 12))
                                    .foregroundColor(.black)
                                Text("Scroll: \(codeToOption(preset.config["scroll"] ?? 0, validOptions: scrollOptions))")
                                    .font(.system(size: 12))
                                    .foregroundColor(.black)
                            }
                        }
                        .padding()
                        .frame(maxWidth: .infinity, alignment: .leading)
                        .background(Color.white)
                    }
                    
                    if preset.id != presets.last?.id {
                        Divider()
                    }
                }
            }
            
            Divider()
            
            // Show Tutorial button
            Button(action: {
                showPresetDropdown = false
                DispatchQueue.main.asyncAfter(deadline: .now() + 0.3) {
                    showInteractiveTutorial = true
                }
            }) {
                HStack {
                    Image(systemName: "lightbulb.fill")
                        .foregroundColor(Color(red: 0.4, green: 0.2, blue: 0.6))
                    Text("Show Tutorial")
                        .font(.system(size: 16, weight: .semibold))
                        .foregroundColor(Color(red: 0.4, green: 0.2, blue: 0.6))
                }
                .padding()
                .frame(maxWidth: .infinity)
            }
        }
        .background(Color.white)
        .cornerRadius(12)
        .shadow(radius: 5)
        .frame(width: 280)
    }
    
    // MARK: - Preset Functions
    func loadPreset(from jsonString: String) -> [String: Int]? {
        guard !jsonString.isEmpty,
              let jsonData = jsonString.data(using: .utf8) else {
            return nil
        }
        
        do {
            let config = try JSONSerialization.jsonObject(with: jsonData, options: []) as? [String: Int]
            return config
        } catch {
            print("❌ Failed to load preset: \(error)")
            return nil
        }
    }
    
    func savePreset(slot: Int) {
        do {
            let jsonData = try JSONSerialization.data(withJSONObject: config, options: [])
            let jsonString = String(data: jsonData, encoding: .utf8) ?? ""
            
            if slot == 1 {
                preset1Data = jsonString
            } else {
                preset2Data = jsonString
            }
            
            print("💾 Preset \(slot) saved: \(config)")
        } catch {
            print("❌ Failed to save preset: \(error)")
        }
    }
    
    func loadPreset(_ preset: Preset) {
        self.config = preset.config
        saveConfigurationIfConnected()
        print("📥 Loaded preset \(preset.id): \(preset.config)")
    }
    
    // MARK: - Controller Outline (With smaller cylindrical grips)
    var controllerOutline: some View {
        GeometryReader { geometry in
            ZStack {
                let containerWidth = geometry.size.width
                let containerHeight = geometry.size.height
                let centerX = containerWidth / 2
                
                // Nintendo Switch Joy-Con style outline with smaller cylindrical grips
                Path { path in
                    // Main rectangular body - increased height by 20 from center
                    let bodyWidth: CGFloat = 480 // Keep current length
                    let bodyHeight: CGFloat = 197.5 // Increased by 20 from 177.5 (total +40 from original)
                    let cornerRadius: CGFloat = 23.5 // Keep current corners
                    
                    let bodyRect = CGRect(
                        x: centerX - bodyWidth / 2,
                        y: containerHeight / 2 - bodyHeight / 2 + 40, // Positioned lower to surround icons
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
                        y: containerHeight / 2 - 22.5, // 0.5x smaller position adjustment (from 45 to 22.5)
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
                        y: containerHeight / 2 - 22.5, // 0.5x smaller position adjustment (from 45 to 22.5)
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
                
                // Orange lines positioned above the outline - moved up by 15
                let buttonSpacing: CGFloat = 30
                let button1CenterX = centerX - buttonSpacing
                let button2CenterX = centerX + buttonSpacing
                
                // Position lines to match the text position - moved up by 15
                let buttonTopY: CGFloat = 130
                let horizontalLineY: CGFloat = 90
                let textBottomY: CGFloat = 70
                
                // Horizontal line endpoints - EXTENDED by 40 on each side (additional 20 from previous)
                let horizontalLineStartX = button1CenterX - 40 // EXTENDED left by 40 (was 20)
                let horizontalLineEndX = button2CenterX + 40 // EXTENDED right by 40 (was 20)
                
                // Vertical line from left endpoint up
                Path { path in
                    path.move(to: CGPoint(x: horizontalLineStartX, y: buttonTopY))
                    path.addLine(to: CGPoint(x: horizontalLineStartX, y: horizontalLineY))
                }
                .stroke(Color.orange, style: StrokeStyle(lineWidth: 2))
                
                // Vertical line from right endpoint up
                Path { path in
                    path.move(to: CGPoint(x: horizontalLineEndX, y: buttonTopY))
                    path.addLine(to: CGPoint(x: horizontalLineEndX, y: horizontalLineY))
                }
                .stroke(Color.orange, style: StrokeStyle(lineWidth: 2))
                
                // Horizontal line connecting both vertical lines - EXTENDED by 40 on each side (additional 20)
                Path { path in
                    path.move(to: CGPoint(x: horizontalLineStartX, y: horizontalLineY))
                    path.addLine(to: CGPoint(x: horizontalLineEndX, y: horizontalLineY))
                }
                .stroke(Color.orange, style: StrokeStyle(lineWidth: 2))
                
                // Vertical line from horizontal line up to Buttons 1+2 text
                Path { path in
                    path.move(to: CGPoint(x: centerX, y: horizontalLineY))
                    path.addLine(to: CGPoint(x: centerX, y: textBottomY))
                }
                .stroke(Color.orange, style: StrokeStyle(lineWidth: 2))
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
    
    // Convert option string to numeric code
    func optionToCode(_ option: String) -> Int {
        switch option {
        case "Undo": return 3
        case "Redo": return 4
        case "Erase": return 5
        case "Brush Size (5%)": return 6
        case "Color Palette": return 7
        case "Brush Library": return 8
        case "Brush Size (10%)": return 9
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
        case 6: option = "Brush Size (5%)"
        case 7: option = "Color Palette"
        case 8: option = "Brush Library"
        case 9: option = "Brush Size (10%)"
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
