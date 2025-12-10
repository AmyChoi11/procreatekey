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
        
        if isBluetoothReady {
            iconName = "dot.radiowaves.left.and.right"
            iconColor = Color.blue
            backgroundColor = Color.blue.opacity(0.1)
            borderColor = Color.blue.opacity(0.5)
        } else if isSuccess {
            iconName = "checkmark.circle.fill"
            iconColor = Color.green
            backgroundColor = Color.green.opacity(0.1)
            borderColor = Color.green.opacity(0.5)
        } else if statusMessage.contains("error") || statusMessage.contains("failed") || statusMessage.contains("disconnected") {
            iconName = "xmark.octagon.fill"
            iconColor = Color.red
            backgroundColor = Color.red.opacity(0.1)
            borderColor = Color.red.opacity(0.5)
        } else {
            iconName = "info.circle.fill"
            iconColor = Color.orange
            backgroundColor = Color.orange.opacity(0.1)
            borderColor = Color.orange.opacity(0.5)
        }
        
        return HStack(alignment: .center, spacing: 10) {
            Image(systemName: iconName)
                .foregroundColor(iconColor)
                .font(.system(size: 16, weight: .medium))
            
            Text(statusMessage)
                .font(.system(size: 12, weight: .medium))
                .foregroundColor(.primary)
                .lineLimit(2)
                .multilineTextAlignment(.leading)
            
            Spacer(minLength: 0)
        }
        .padding(10)
        .background(backgroundColor)
        .cornerRadius(10)
        .overlay(
            RoundedRectangle(cornerRadius: 10)
                .stroke(borderColor, lineWidth: 1)
        )
        .padding(.horizontal)
    }
}

// MARK: - Problem Notification View
struct ProblemNotificationView: View {
    let problem: DetectedProblem?
    
    var body: some View {
        guard let problem = problem else {
            return AnyView(EmptyView())
        }
        
        return AnyView(
            VStack(alignment: .leading, spacing: 8) {
                HStack(spacing: 8) {
                    Image(systemName: "exclamationmark.triangle.fill")
                        .foregroundColor(.orange)
                        .font(.system(size: 16, weight: .bold))
                    Text(problem.title)
                        .font(.system(size: 14, weight: .semibold))
                        .foregroundColor(.orange)
                }
                
                Text(problem.steps.joined(separator: "\n"))
                    .font(.system(size: 12))
                    .foregroundColor(.primary)
                    .fixedSize(horizontal: false, vertical: true)
            }
            .padding(12)
            .background(Color.yellow.opacity(0.1))
            .cornerRadius(10)
            .overlay(
                RoundedRectangle(cornerRadius: 10)
                    .stroke(Color.yellow.opacity(0.5), lineWidth: 1)
            )
            .padding(.horizontal)
        )
    }
}

// MARK: - Help Bubble View
struct HelpBubbleView: View {
    let text: String
    
    var body: some View {
        HStack(alignment: .top, spacing: 8) {
            Image(systemName: "lightbulb.fill")
                .foregroundColor(Color.yellow)
                .font(.system(size: 14))
                .padding(.top, 2)
            
            Text(text)
                .font(.system(size: 12))
                .foregroundColor(.primary)
                .fixedSize(horizontal: false, vertical: true)
        }
        .padding(10)
        .background(Color.yellow.opacity(0.1))
        .cornerRadius(10)
        .overlay(
            RoundedRectangle(cornerRadius: 10)
                .stroke(Color.yellow.opacity(0.4), lineWidth: 1)
        )
        .padding(.horizontal)
    }
}

// MARK: - Popup Background View Modifier
struct PopupBackground<Content: View>: View {
    let content: Content
    
    init(@ViewBuilder content: () -> Content) {
        self.content = content()
    }
    
    var body: some View {
        ZStack {
            // Dimmed background
            Color.black.opacity(0.3)
                .edgesIgnoringSafeArea(.all)
            
            content
        }
        .transition(.opacity)
        .animation(.easeInOut, value: UUID())
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
    ]
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
    @State private var showButtons12Dropdown = false
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
        var config: [String: Int]
    }
    
    // Load custom configuration from stored JSON string
    func loadCustom(from jsonString: String) -> Custom? {
        guard !jsonString.isEmpty else { return nil }
        
        guard let jsonData = jsonString.data(using: .utf8) else { return nil }
        
        do {
            if let dict = try JSONSerialization.jsonObject(with: jsonData, options: []) as? [String: Any] {
                if let name = dict["name"] as? String,
                   let configDict = dict["config"] as? [String: Int],
                   let id = dict["id"] as? Int {
                    return Custom(id: id, name: name, config: configDict)
                } else if let configDict = dict["config"] as? [String: Int] {
                    return Custom(id: 0, name: "Custom", config: configDict)
                } else if let configDict = dict as? [String: Int] {
                    return Custom(id: 0, name: "Custom", config: configDict)
                }
            } else if let configDict = try JSONSerialization.jsonObject(with: jsonData, options: []) as? [String: Int] {
                return Custom(id: 0, name: "Custom", config: configDict)
            }
        } catch {
            print("❌ Failed to parse custom: \(error)")
        }
        
        return nil
    }
    
    // Helper to get a readable name for stored custom from AppStorage
    func storedCustomName(for key: String) -> String {
        switch key {
        case "custom1":
            return UserDefaults.standard.string(forKey: "custom1Name") ?? "Custom 1"
        case "custom2":
            return UserDefaults.standard.string(forKey: "custom2Name") ?? "Custom 2"
        case "custom3":
            return UserDefaults.standard.string(forKey: "custom3Name") ?? "Custom 3"
        default:
            return "Custom"
        }
    }
    
    var customs: [Custom] {
        var availableCustoms: [Custom] = []
        
        if let custom1 = loadCustom(from: custom1Data) {
            let name = UserDefaults.standard.string(forKey: "custom1Name") ?? "Custom 1"
            availableCustoms.append(Custom(id: 1, name: name, config: custom1.config))
        }
        
        if let custom2 = loadCustom(from: custom2Data) {
            let name = UserDefaults.standard.string(forKey: "custom2Name") ?? "Custom 2"
            availableCustoms.append(Custom(id: 2, name: name, config: custom2.config))
        }
        
        if let custom3 = loadCustom(from: custom3Data) {
            let name = UserDefaults.standard.string(forKey: "custom3Name") ?? "Custom 3"
            availableCustoms.append(Custom(id: 3, name: name, config: custom3.config))
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
                // Determine device width for layout adjustments
                let isSmallDevice = geometry.size.width < 380
                
                // Background color matching original controllers mockup
                Color(hue: 0.6, saturation: 0.2, brightness: 0.15)
                    .ignoresSafeArea()
                
                VStack(spacing: isSmallDevice ? 10 : 15) {
                    // Title and description
                    VStack(spacing: 6) {
                        Text("CoBrush")
                            .font(.system(size: isSmallDevice ? 22 : 26, weight: .bold))
                            .foregroundColor(.white)
                        
                        Text("Set up your CoBrush controller to match your drawing style.")
                            .font(.system(size: isSmallDevice ? 12 : 14))
                            .foregroundColor(Color.white.opacity(0.8))
                            .multilineTextAlignment(.center)
                            .padding(.horizontal, isSmallDevice ? 20 : 40)
                    }
                    .padding(.top, isSmallDevice ? 10 : 20)
                    
                    // Buttons for onboarding and tutorial
                    HStack(spacing: 12) {
                        Button(action: {
                            showOnboarding = true
                        }) {
                            HStack(spacing: 6) {
                                Image(systemName: "questionmark.circle")
                                Text("How CoBrush works")
                            }
                            .font(.system(size: 12, weight: .medium))
                            .foregroundColor(.white)
                            .padding(.horizontal, 12)
                            .padding(.vertical, 8)
                            .background(Color.white.opacity(0.1))
                            .cornerRadius(8)
                        }
                        
                        Button(action: {
                            showInteractiveTutorial = true
                        }) {
                            HStack(spacing: 6) {
                                Image(systemName: "hand.draw")
                                Text("Interactive guide")
                            }
                            .font(.system(size: 12, weight: .medium))
                            .foregroundColor(.white)
                            .padding(.horizontal, 12)
                            .padding(.vertical, 8)
                            .background(Color.white.opacity(0.1))
                            .cornerRadius(8)
                        }
                    }
                    
                    // Main controller UI
                    ZStack {
                        // Background rounded rectangle behind controllers
                        RoundedRectangle(cornerRadius: 25)
                            .fill(Color.black.opacity(0.35))
                            .frame(width: geometry.size.width * (isSmallDevice ? 0.95 : 0.98),
                                   height: isSmallDevice ? 260 : 280)
                            .shadow(radius: 10)
                        
                        HStack(alignment: .center, spacing: isSmallDevice ? 70 : 120) {
                            // LEFT CONTROLLER
                            ZStack {
                                RoundedRectangle(cornerRadius: 30 * controllerScale)
                                    .fill(LinearGradient(
                                        gradient: Gradient(colors: [
                                            Color(hue: 0.6, saturation: 0.4, brightness: 0.3),
                                            Color(hue: 0.6, saturation: 0.4, brightness: 0.2)
                                        ]),
                                        startPoint: .top,
                                        endPoint: .bottom
                                    ))
                                    .frame(width: 90 * controllerScale, height: 180 * controllerScale)
                                    .overlay(
                                        RoundedRectangle(cornerRadius: 30 * controllerScale)
                                            .stroke(Color.white.opacity(0.1), lineWidth: 2)
                                    )
                                    .shadow(color: Color.black.opacity(0.6), radius: 10, x: 0, y: 6)
                                
                                // Side grip texture
                                RoundedRectangle(cornerRadius: 30 * controllerScale)
                                    .strokeBorder(
                                        LinearGradient(
                                            gradient: Gradient(colors: [Color.white.opacity(0.3), Color.white.opacity(0.1)]),
                                            startPoint: .top,
                                            endPoint: .bottom
                                        ),
                                        lineWidth: 1
                                    )
                                    .frame(width: 88 * controllerScale, height: 178 * controllerScale)
                                
                                VStack(spacing: isSmallDevice ? 18 : 22) {
                                    // TOP BUTTON (Button 1)
                                    ZStack {
                                        Circle()
                                            .fill(
                                                LinearGradient(
                                                    gradient: Gradient(colors: [
                                                        Color(red: 0.93, green: 0.93, blue: 0.96),
                                                        Color(red: 0.85, green: 0.85, blue: 0.90)
                                                    ]),
                                                    startPoint: .top,
                                                    endPoint: .bottom
                                                )
                                            )
                                            .frame(width: 42 * buttonScale, height: 42 * buttonScale)
                                            .shadow(color: Color.black.opacity(0.4), radius: 4, x: 0, y: 3)
                                        
                                        Circle()
                                            .stroke(Color.black.opacity(0.12), lineWidth: 1)
                                            .frame(width: 42 * buttonScale, height: 42 * buttonScale)
                                        
                                        VStack(spacing: 2) {
                                            Image(systemName: iconForButton(configKey: "button1"))
                                                .font(.system(size: 16, weight: .semibold))
                                                .foregroundColor(Color(red: 0.3, green: 0.3, blue: 0.35))
                                            
                                            Text(labelForButton(configKey: "button1"))
                                                .font(.system(size: 11, weight: .medium))
                                                .foregroundColor(Color(red: 0.25, green: 0.25, blue: 0.3))
                                        }
                                    }
                                    .overlay(
                                        GeometryReader { proxy in
                                            Color.clear
                                                .onAppear {
                                                    button1Frame = proxy.frame(in: .global)
                                                }
                                        }
                                    )
                                    
                                    // MIDDLE BUTTON (Button 2)
                                    ZStack {
                                        Circle()
                                            .fill(
                                                LinearGradient(
                                                    gradient: Gradient(colors: [
                                                        Color(red: 0.93, green: 0.93, blue: 0.96),
                                                        Color(red: 0.85, green: 0.85, blue: 0.90)
                                                    ]),
                                                    startPoint: .top,
                                                    endPoint: .bottom
                                                )
                                            )
                                            .frame(width: 42 * buttonScale, height: 42 * buttonScale)
                                            .shadow(color: Color.black.opacity(0.4), radius: 4, x: 0, y: 3)
                                        
                                        Circle()
                                            .stroke(Color.black.opacity(0.12), lineWidth: 1)
                                            .frame(width: 42 * buttonScale, height: 42 * buttonScale)
                                        
                                        VStack(spacing: 2) {
                                            Image(systemName: iconForButton(configKey: "button2"))
                                                .font(.system(size: 16, weight: .semibold))
                                                .foregroundColor(Color(red: 0.3, green: 0.3, blue: 0.35))
                                            
                                            Text(labelForButton(configKey: "button2"))
                                                .font(.system(size: 11, weight: .medium))
                                                .foregroundColor(Color(red: 0.25, green: 0.25, blue: 0.3))
                                        }
                                    }
                                    .overlay(
                                        GeometryReader { proxy in
                                            Color.clear
                                                .onAppear {
                                                    button2Frame = proxy.frame(in: .global)
                                                }
                                        }
                                    )
                                    
                                    // BOTTOM SPACER
                                    Spacer().frame(height: isSmallDevice ? 14 : 18)
                                }
                                .padding(.top, isSmallDevice ? 16 : 18)
                            }
                            
                            // RIGHT CONTROLLER
                            ZStack {
                                RoundedRectangle(cornerRadius: 30 * controllerScale)
                                    .fill(LinearGradient(
                                        gradient: Gradient(colors: [
                                            Color(hue: 0.6, saturation: 0.4, brightness: 0.3),
                                            Color(hue: 0.6, saturation: 0.4, brightness: 0.2)
                                        ]),
                                        startPoint: .top,
                                        endPoint: .bottom
                                    ))
                                    .frame(width: 90 * controllerScale, height: 180 * controllerScale)
                                    .overlay(
                                        RoundedRectangle(cornerRadius: 30 * controllerScale)
                                            .stroke(Color.white.opacity(0.1), lineWidth: 2)
                                    )
                                    .shadow(color: Color.black.opacity(0.6), radius: 10, x: 0, y: 6)
                                
                                RoundedRectangle(cornerRadius: 30 * controllerScale)
                                    .strokeBorder(
                                        LinearGradient(
                                            gradient: Gradient(colors: [Color.white.opacity(0.3), Color.white.opacity(0.1)]),
                                            startPoint: .top,
                                            endPoint: .bottom
                                        ),
                                        lineWidth: 1
                                    )
                                    .frame(width: 88 * controllerScale, height: 178 * controllerScale)
                                
                                VStack(spacing: isSmallDevice ? 10 : 12) {
                                    // TOP SCROLL WHEEL
                                    ZStack {
                                        Capsule()
                                            .fill(
                                                LinearGradient(
                                                    gradient: Gradient(colors: [
                                                        Color(red: 0.9, green: 0.9, blue: 0.95),
                                                        Color(red: 0.8, green: 0.8, blue: 0.9)
                                                    ]),
                                                    startPoint: .top,
                                                    endPoint: .bottom
                                                )
                                            )
                                            .frame(width: 40 * buttonScale, height: 68 * buttonScale)
                                            .shadow(color: Color.black.opacity(0.4), radius: 4, x: 0, y: 3)
                                        
                                        Capsule()
                                            .stroke(Color.black.opacity(0.15), lineWidth: 1)
                                            .frame(width: 40 * buttonScale, height: 68 * buttonScale)
                                        
                                        VStack(spacing: 8) {
                                            // Top arrow
                                            Image(systemName: "chevron.up")
                                                .font(.system(size: 12, weight: .bold))
                                                .foregroundColor(Color(red: 0.25, green: 0.25, blue: 0.3))
                                            
                                            // SCROLL GROOVE with textured ridges
                                            ZStack {
                                                RoundedRectangle(cornerRadius: 6)
                                                    .fill(
                                                        LinearGradient(
                                                            gradient: Gradient(colors: [
                                                                Color(red: 0.7, green: 0.7, blue: 0.75),
                                                                Color(red: 0.55, green: 0.55, blue: 0.6)
                                                            ]),
                                                            startPoint: .top,
                                                            endPoint: .bottom
                                                        )
                                                    )
                                                    .frame(width: 24, height: 18)
                                                    .shadow(color: Color.black.opacity(0.2), radius: 1, x: 0, y: 1)
                                                
                                                VStack(spacing: 1.5) {
                                                    ForEach(0..<5, id: \.self) { _ in
                                                        Capsule()
                                                            .fill(Color.white.opacity(0.7))
                                                            .frame(width: 18, height: 1)
                                                    }
                                                }
                                            }
                                            
                                            Image(systemName: "chevron.down")
                                                .font(.system(size: 12, weight: .bold))
                                                .foregroundColor(Color(red: 0.25, green: 0.25, blue: 0.3))
                                        }
                                    }
                                    .overlay(
                                        GeometryReader { proxy in
                                            Color.clear
                                                .onAppear {
                                                    scrollFrame = proxy.frame(in: .global)
                                                }
                                        }
                                    )
                                    
                                    // Middle empty space
                                    Spacer().frame(height: isSmallDevice ? 12 : 14)
                                    
                                    // BOTTOM BUTTONS 1+2 Combo
                                    ZStack {
                                        RoundedRectangle(cornerRadius: 18)
                                            .fill(
                                                LinearGradient(
                                                    gradient: Gradient(colors: [
                                                        Color(red: 0.93, green: 0.93, blue: 0.96),
                                                        Color(red: 0.85, green: 0.85, blue: 0.9)
                                                    ]),
                                                    startPoint: .top,
                                                    endPoint: .bottom
                                                )
                                            )
                                            .frame(width: 66 * buttonScale, height: 32 * buttonScale)
                                            .shadow(color: Color.black.opacity(0.4), radius: 4, x: 0, y: 3)
                                        
                                        RoundedRectangle(cornerRadius: 18)
                                            .stroke(Color.black.opacity(0.12), lineWidth: 1)
                                            .frame(width: 66 * buttonScale, height: 32 * buttonScale)
                                        
                                        HStack(spacing: 6) {
                                            Image(systemName: iconForButton(configKey: "combo"))
                                                .font(.system(size: 14, weight: .semibold))
                                                .foregroundColor(Color(red: 0.3, green: 0.3, blue: 0.35))
                                            
                                            Text(labelForButton(configKey: "combo"))
                                                .font(.system(size: 11, weight: .medium))
                                                .foregroundColor(Color(red: 0.25, green: 0.25, blue: 0.3))
                                        }
                                    }
                                    .overlay(
                                        GeometryReader { proxy in
                                            Color.clear
                                                .onAppear {
                                                    comboFrame = proxy.frame(in: .global)
                                                }
                                        }
                                    )
                                }
                                .padding(.top, isSmallDevice ? 16 : 18)
                            }
                        }
                    }
                    .padding(.top, isSmallDevice ? 8 : 12)
                    
                    // Configuration controls section
                    VStack(spacing: isSmallDevice ? 12 : 16) {
                        // STATUS/HELP AREA
                        if !bleManager.statusMessage.isEmpty {
                            StatusNotificationView(statusMessage: bleManager.statusMessage)
                        }
                        
                        if bleManager.detectedProblem != nil {
                            ProblemNotificationView(problem: bleManager.detectedProblem)
                        }
                        
                        // CONFIG ROWS
                        VStack(spacing: 10) {
                            // TOP ROW: Scroll and Click on Scroll
                            HStack(alignment: .top, spacing: 16) {
                                // Scroll Wheel config
                                VStack(alignment: .leading, spacing: 6) {
                                    Text("Scroll wheel")
                                        .font(.system(size: 12, weight: .semibold))
                                        .foregroundColor(.white)
                                    
                                    Text("Change brush size with scroll up/down.")
                                        .font(.system(size: 11))
                                        .foregroundColor(Color.white.opacity(0.8))
                                        .fixedSize(horizontal: false, vertical: true)
                                    
                                    HStack(spacing: 10) {
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
                                            }
                                            .buttonStyle(PlainButtonStyle())
                                            
                                            Text("Scroll up/down to adjust brush size.")
                                                .font(.system(size: 11))
                                                .foregroundColor(Color.white.opacity(0.7))
                                                .fixedSize(horizontal: false, vertical: true)
                                        }
                                        .popover(isPresented: $showScrollDropdown,
                                                 attachmentAnchor: .point(.bottom),
                                                 arrowEdge: .top) {
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
                                            .frame(width: 220)
                                        }
                                        
                                        Spacer()
                                    }
                                }
                                
                                // Click on Scroll config
                                VStack(alignment: .leading, spacing: 6) {
                                    Text("Click on Scroll")
                                        .font(.system(size: 12, weight: .semibold))
                                        .foregroundColor(.white)
                                    
                                    Text("Press down on the scroll wheel to trigger a shortcut.")
                                        .font(.system(size: 11))
                                        .foregroundColor(Color.white.opacity(0.8))
                                        .fixedSize(horizontal: false, vertical: true)
                                    
                                    HStack(spacing: 10) {
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
                                    }
                                    
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
                                        .font(.system(size: 14, weight: .medium))
                                        .foregroundColor(.white)
                                        .padding(.horizontal, 12)
                                        .padding(.vertical, 6)
                                        .background(Color(red: 0.7, green: 0.5, blue: 0.9).opacity(0.8))
                                        .cornerRadius(6)
                                }
                                .buttonStyle(PlainButtonStyle())
                                
                                Text("Press both buttons together for a secondary shortcut.")
                                    .font(.system(size: 11))
                                    .foregroundColor(Color.white.opacity(0.7))
                                    .fixedSize(horizontal: false, vertical: true)
                            }
                            .popover(isPresented: $showButtons12Dropdown,
                                     attachmentAnchor: .point(.bottom),
                                     arrowEdge: .top) {
                                VStack(spacing: 0) {
                                    ForEach(buttons12Options, id: \.self) { option in
                                        Button(action: {
                                            config["combo"] = optionToCode(option)
                                            saveConfigurationIfConnected()
                                            showButtons12Dropdown = false
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
                                .frame(width: 220)
                            }
                        }
                        
                        // BOTTOM ROW: Buttons 1 and 2
                        HStack(alignment: .top, spacing: 16) {
                            VStack(alignment: .leading, spacing: 8) {
                                Text("Button 1 (top)")
                                    .font(.system(size: 12, weight: .semibold))
                                    .foregroundColor(.white)
                                
                                Text("Assign undo, erase, or other tools to the top button.")
                                    .font(.system(size: 11))
                                    .foregroundColor(Color.white.opacity(0.8))
                                    .fixedSize(horizontal: false, vertical: true)
                                
                                Button(action: {
                                    showButton1Dropdown = true
                                }) {
                                    Text(getCurrentSelection(for: "button1"))
                                        .font(.system(size: 14, weight: .medium))
                                        .foregroundColor(.white)
                                        .padding(.horizontal, 12)
                                        .padding(.vertical, 6)
                                        .background(Color(red: 0.7, green: 0.5, blue: 0.9).opacity(0.8))
                                        .cornerRadius(6)
                                }
                                .buttonStyle(PlainButtonStyle())
                                .popover(isPresented: $showButton1Dropdown,
                                         attachmentAnchor: .point(.bottom),
                                         arrowEdge: .top) {
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
                                    .frame(width: 220)
                                }
                            }
                            
                            VStack(alignment: .leading, spacing: 8) {
                                Text("Button 2 (middle)")
                                    .font(.system(size: 12, weight: .semibold))
                                    .foregroundColor(.white)
                                
                                Text("Set up erase or other options for the middle button.")
                                    .font(.system(size: 11))
                                    .foregroundColor(Color.white.opacity(0.8))
                                    .fixedSize(horizontal: false, vertical: true)
                                
                                Button(action: {
                                    showButton2Dropdown = true
                                }) {
                                    Text(getCurrentSelection(for: "button2"))
                                        .font(.system(size: 14, weight: .medium))
                                        .foregroundColor(.white)
                                        .padding(.horizontal, 12)
                                        .padding(.vertical, 6)
                                        .background(Color(red: 0.7, green: 0.5, blue: 0.9).opacity(0.8))
                                        .cornerRadius(6)
                                }
                                .buttonStyle(PlainButtonStyle())
                                .popover(isPresented: $showButton2Dropdown,
                                         attachmentAnchor: .point(.bottom),
                                         arrowEdge: .top) {
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
                                    .frame(width: 220)
                                }
                            }
                        }
                    }
                    .padding(.horizontal)
                    
                    // SAVE / RESET / HELP SECTION
                    VStack(spacing: 10) {
                        HStack(spacing: 10) {
                            // Save preset button (RENAMED TO "Save custom")
                            Button(action: {
                                showSaveCustomDropdown = true
                            }) {
                                HStack(spacing: 6) {
                                    Image(systemName: "square.and.arrow.down")
                                    Text("Save custom")
                                }
                                .font(.system(size: 12, weight: .medium))
                                .foregroundColor(Color(red: 0.3, green: 0.2, blue: 0.5))
                                .padding(.horizontal, 10)
                                .padding(.vertical, 8)
                                .background(Color.white)
                                .cornerRadius(8)
                            }
                            .buttonStyle(PlainButtonStyle())
                            
                            // Load preset button (RENAMED TO "Load custom")
                            Button(action: {
                                showCustomsDropdown = true
                            }) {
                                HStack(spacing: 6) {
                                    Image(systemName: "folder")
                                    Text("Load custom")
                                }
                                .font(.system(size: 12, weight: .medium))
                                .foregroundColor(Color(red: 0.3, green: 0.2, blue: 0.5))
                                .padding(.horizontal, 10)
                                .padding(.vertical, 8)
                                .background(Color.white)
                                .cornerRadius(8)
                            }
                            .buttonStyle(PlainButtonStyle())
                            .popover(isPresented: $showCustomsDropdown,
                                     attachmentAnchor: .point(.bottom),
                                     arrowEdge: .top) {
                                customMenuView
                            }
                            
                            Button(action: {
                                resetToDefault()
                            }) {
                                HStack(spacing: 6) {
                                    Image(systemName: "arrow.uturn.backward")
                                    Text("Reset to default")
                                }
                                .font(.system(size: 12, weight: .medium))
                                .foregroundColor(Color(red: 0.6, green: 0.1, blue: 0.1))
                                .padding(.horizontal, 10)
                                .padding(.vertical, 8)
                                .background(Color.white)
                                .cornerRadius(8)
                            }
                            .buttonStyle(PlainButtonStyle())
                            
                            Spacer()
                            
                            Button(action: {
                                showHelpDropdown.toggle()
                            }) {
                                Image(systemName: "questionmark.circle")
                                    .font(.system(size: 16))
                                    .foregroundColor(.white)
                                    .padding(8)
                            }
                            .buttonStyle(PlainButtonStyle())
                            .popover(isPresented: $showHelpDropdown,
                                     attachmentAnchor: .point(.top),
                                     arrowEdge: .bottom) {
                                helpMenuView
                            }
                        }
                        
                        // Help bubble guidance
                        if showHelp {
                            HelpBubbleView(text: "Tip: Start with Undo on Button 1, Erase on Button 2, Brush Library on Buttons 1+2, and Brush Size ±5% on the scroll wheel.")
                        }
                    }
                    .padding(.horizontal)
                    .padding(.bottom, 10)
                }
                
                // Overlay: Save custom dropdown
                if showSaveCustomDropdown {
                    PopupBackground {
                        saveCustomDropdownView
                    }
                }
                
                // Overlay: Rename custom alert
                if showCustomRenameAlert {
                    PopupBackground {
                        renameCustomPopup()
                    }
                }
                
                // Overlay: Save confirmation
                if showSaveConfirmation {
                    PopupBackground {
                        saveConfirmationPopup()
                    }
                }
                
                // Device sheet (Bluetooth devices, connection)
                if showDeviceSheet {
                    VStack {
                        Spacer()
                        DeviceSheetView(bleManager: bleManager,
                                        isPresented: $showDeviceSheet,
                                        scanButtonFrame: $scanButtonFrame)
                            .transition(.move(edge: .bottom))
                    }
                    .edgesIgnoringSafeArea(.bottom)
                }
            }
            .onAppear {
                if !hasShownInitialSheet {
                    hasShownInitialSheet = true
                    showOnboarding = !hasCompletedOnboarding
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
            .sheet(isPresented: $showOnboarding) {
                OnboardingView(showOnboarding: $showOnboarding)
            }
            .sheet(isPresented: $showInteractiveTutorial) {
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
        VStack(alignment: .leading, spacing: 12) {
            Text("Need help?")
                .font(.system(size: 14, weight: .semibold))
                .foregroundColor(.primary)
            
            Text("• Try Undo on Button 1 and Erase on Button 2.\n• Use the scroll wheel for brush size adjustments.\n• Use Buttons 1+2 for less frequent tools like Brush Library.")
                .font(.system(size: 12))
                .foregroundColor(.primary)
            
            Divider()
            
            Text("If something feels off on the iPad (e.g. zoom or gestures), check your iPad Display settings and Zoom accessibility settings.")
                .font(.system(size: 11))
                .foregroundColor(.secondary)
                .fixedSize(horizontal: false, vertical: true)
        }
        .padding(12)
        .background(Color.white)
        .cornerRadius(12)
        .shadow(radius: 5)
        .frame(width: 260)
    }
    
    // MARK: - Save Custom Dropdown View
    var saveCustomDropdownView: some View {
        VStack(spacing: 12) {
            Text("Save Custom")
                .font(.system(size: 16, weight: .semibold))
                .foregroundColor(.primary)
            
            Text("Choose a slot to save your current configuration.")
                .font(.system(size: 12))
                .foregroundColor(.secondary)
                .multilineTextAlignment(.center)
            
            ForEach(1...3, id: \.self) { slot in
                Button(action: {
                    customToSave = slot
                    showSaveCustomDropdown = false
                    showSaveConfirmation = true
                }) {
                    HStack {
                        Text(getCustomNameForSlot(slot))
                            .font(.system(size: 14, weight: .medium))
                        Spacer()
                        if slotIsUsed(slot) {
                            Text("Overwrite")
                                .font(.system(size: 12))
                                .foregroundColor(.red)
                        } else {
                            Text("Empty")
                                .font(.system(size: 12))
                                .foregroundColor(.green)
                        }
                    }
                    .padding(.horizontal, 12)
                    .padding(.vertical, 8)
                    .background(Color.gray.opacity(0.1))
                    .cornerRadius(8)
                }
                .buttonStyle(PlainButtonStyle())
            }
            
            Button(action: {
                if let firstAvailable = findFirstAvailableSlot() {
                    customToSave = firstAvailable
                    showSaveCustomDropdown = false
                    showSaveConfirmation = true
                } else {
                    customToSave = 1
                    showSaveCustomDropdown = false
                    showSaveConfirmation = true
                }
            }) {
                Text("Save to first available")
                    .font(.system(size: 13, weight: .medium))
                    .foregroundColor(.white)
                    .padding(.horizontal, 16)
                    .padding(.vertical, 8)
                    .background(Color.blue)
                    .cornerRadius(8)
            }
            
            Button(action: {
                showSaveCustomDropdown = false
            }) {
                Text("Cancel")
                    .font(.system(size: 13))
                    .foregroundColor(.red)
                    .padding(.top, 4)
            }
        }
        .padding(16)
        .frame(width: 280)
        .background(Color.white)
        .cornerRadius(16)
        .shadow(radius: 8)
    }
    
    // MARK: - Save Confirmation Popup
    func saveConfirmationPopup() -> some View {
        VStack(spacing: 16) {
            Text("Save Custom")
                .font(.system(size: 16, weight: .semibold))
                .foregroundColor(.primary)
            
            Text("Save as '\(getCustomNameForSlot(customToSave))'?")
                .font(.system(size: 13))
                .foregroundColor(.secondary)
                .multilineTextAlignment(.center)
            
            HStack(spacing: 12) {
                Button(action: {
                    saveCustom(slot: customToSave)
                    saveCustomName(customToSave, name: getCustomNameForSlot(customToSave))
                    showSaveConfirmation = false
                }) {
                    Text("Save")
                        .font(.system(size: 14, weight: .medium))
                        .foregroundColor(.white)
                        .padding(.horizontal, 20)
                        .padding(.vertical, 8)
                        .background(Color.blue)
                        .cornerRadius(8)
                }
                
                Button(action: {
                    showSaveConfirmation = false
                }) {
                    Text("Cancel")
                        .font(.system(size: 14))
                        .foregroundColor(.red)
                }
            }
        }
        .padding(20)
        .frame(width: 280)
        .background(Color.white)
        .cornerRadius(16)
        .shadow(radius: 8)
    }
    
    // MARK: - Rename Custom Popup
    func renameCustomPopup() -> some View {
        VStack(spacing: 16) {
            Text("Rename Custom")
                .font(.system(size: 16, weight: .semibold))
                .foregroundColor(.primary)
            
            TextField("Enter name", text: $customRenameText)
                .textFieldStyle(RoundedBorderTextFieldStyle())
                .padding(.horizontal, 4)
            
            HStack(spacing: 12) {
                Button(action: {
                    saveCustomName(customToRename, name: customRenameText.isEmpty ? "Custom \(customToRename)" : customRenameText)
                    showCustomRenameAlert = false
                }) {
                    Text("Save")
                        .font(.system(size: 14, weight: .medium))
                        .foregroundColor(.white)
                        .padding(.horizontal, 20)
                        .padding(.vertical, 8)
                        .background(Color.blue)
                        .cornerRadius(8)
                }
                
                Button(action: {
                    showCustomRenameAlert = false
                }) {
                    Text("Cancel")
                        .font(.system(size: 14))
                        .foregroundColor(.red)
                }
            }
        }
        .padding(20)
        .frame(width: 280)
        .background(Color.white)
        .cornerRadius(16)
        .shadow(radius: 8)
    }
    
    // MARK: - Helper Methods for Customs
    func getCustomNameForSlot(_ slot: Int) -> String {
        switch slot {
        case 1:
            return UserDefaults.standard.string(forKey: "custom1Name") ?? "Custom 1"
        case 2:
            return UserDefaults.standard.string(forKey: "custom2Name") ?? "Custom 2"
        case 3:
            return UserDefaults.standard.string(forKey: "custom3Name") ?? "Custom 3"
        default:
            return "Custom \(slot)"
        }
    }
    
    func slotIsUsed(_ slot: Int) -> Bool {
        switch slot {
        case 1:
            return !custom1Data.isEmpty
        case 2:
            return !custom2Data.isEmpty
        case 3:
            return !custom3Data.isEmpty
        default:
            return false
        }
    }
    
    func findFirstAvailableSlot() -> Int? {
        if custom1Data.isEmpty { return 1 }
        if custom2Data.isEmpty { return 2 }
        if custom3Data.isEmpty { return 3 }
        return nil
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
            
            print("💾 Custom \(slot) saved: \(config)")
        } catch {
            print("❌ Failed to save custom: \(error)")
        }
    }
    
    func saveCustomName(_ slot: Int, name: String) {
        UserDefaults.standard.set(name, forKey: "custom\(slot)Name")
        print("🔤 Saved name for custom\(slot): \(name)")
    }
    
    func loadCustom(_ custom: Custom) {
        config = custom.config
        saveConfigurationIfConnected()
        print("📥 Loaded custom \(custom.id): \(custom.config)")
    }
    
    // MARK: - Reset Configuration
    func resetToDefault() {
        config = defaultConfig
        saveConfigurationIfConnected()
        print("🔄 Reset to default configuration: \(config)")
    }
    
    // MARK: - Mapping Functions
    func iconForButton(configKey: String) -> String {
        let option = getCurrentSelection(for: configKey)
        
        switch option {
        case "Undo":
            return "arrow.uturn.backward.circle.fill"
        case "Redo":
            return "arrow.uturn.forward.circle.fill"
        case "Erase":
            return "eraser.fill"
        case "Color Palette":
            return "paintpalette.fill"
        case "Brush Library":
            return "square.grid.2x2.fill"
        case "Brush Size ±5%", "Brush Size ±10%":
            return "slider.horizontal.3"
        default:
            return "circle"
        }
    }
    
    func labelForButton(configKey: String) -> String {
        let option = getCurrentSelection(for: configKey)
        
        switch option {
        case "Undo":
            return "Undo"
        case "Redo":
            return "Redo"
        case "Erase":
            return "Erase"
        case "Color Palette":
            return "Colors"
        case "Brush Library":
            return "Brushes"
        case "Brush Size ±5%":
            return "Size ±5%"
        case "Brush Size ±10%":
            return "Size ±10%"
        default:
            return "None"
        }
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
            // Click on scroll uses full button option set
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
        default: option = "None"
        }
        
        return validOptions.contains(option) ? option : validOptions.first ?? "None"
    }
    
    // MARK: - BLE Integration
    func saveConfigurationIfConnected() {
        if bleManager.isConnected {
            bleManager.writeConfig(config: config)
            print("📡 Sent config to device: \(config)")
        } else {
            print("ℹ️ Not connected, config will be sent when device connects.")
        }
    }
}

// MARK: - Device Sheet View
struct DeviceSheetView: View {
    @ObservedObject var bleManager: BLEManager
    @Binding var isPresented: Bool
    @Binding var scanButtonFrame: CGRect
    
    var body: some View {
        VStack(spacing: 0) {
            Capsule()
                .fill(Color.gray.opacity(0.5))
                .frame(width: 40, height: 5)
                .padding(.top, 8)
            
            HStack {
                Text("CoBrush Devices")
                    .font(.system(size: 16, weight: .semibold))
                    .foregroundColor(.primary)
                Spacer()
                Button(action: {
                    isPresented = false
                }) {
                    Image(systemName: "xmark")
                        .foregroundColor(.secondary)
                }
            }
            .padding([.top, .horizontal])
            
            Divider()
            
            deviceListSection
            
            Divider()
            
            scanButtonSection
        }
        .background(Color(UIColor.systemGroupedBackground))
        .cornerRadius(20)
        .shadow(radius: 20)
    }
    
    private var deviceListSection: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 12) {
                if bleManager.devices.isEmpty {
                    emptyStateView
                } else {
                    deviceListView
                }
            }
            .padding()
        }
    }
    
    private var emptyStateView: some View {
        Text("No devices found.\n\nMake sure your CoBrush controller is powered on and nearby, then tap Scan again.")
            .font(.system(size: 13))
            .foregroundColor(.secondary)
            .multilineTextAlignment(.leading)
            .padding(.top, 16)
    }
    
    private var deviceListView: some View {
        ForEach(bleManager.devices, id: \.identifier) { device in
            DeviceRowButton(
                device: device,
                isConnected: bleManager.isConnected,
                connectedDeviceId: bleManager.connectedDevice?.identifier,
                onTap: {
                    bleManager.connect(to: device)
                    isPresented = false
                }
            )
        }
    }
    
    private var scanButtonSection: some View {
        HStack {
            Spacer()
            Button(action: {
                if bleManager.isScanning {
                    bleManager.stopScan()
                } else {
                    bleManager.startScan()
                }
            }) {
                HStack(spacing: 6) {
                    Image(systemName: bleManager.isScanning ? "stop.circle.fill" : "magnifyingglass.circle.fill")
                    Text(bleManager.isScanning ? "Stop Scan" : "Scan for Devices")
                }
                .font(.system(size: 14, weight: .medium))
                .foregroundColor(.white)
                .padding(.horizontal, 16)
                .padding(.vertical, 10)
                .background(Color.blue)
                .cornerRadius(10)
            }
            Spacer()
        }
        .padding()
    }
}

// MARK: - Device Row Button
struct DeviceRowButton: View {
    let device: CBPeripheral
    let isConnected: Bool
    let connectedDeviceId: UUID?
    let onTap: () -> Void
    
    private var isThisDeviceConnected: Bool {
        isConnected && connectedDeviceId == device.identifier
    }
    
    var body: some View {
        Button(action: onTap) {
            HStack {
                VStack(alignment: .leading, spacing: 4) {
                    Text(device.name ?? "Unknown Device")
                        .font(.system(size: 14, weight: .medium))
                        .foregroundColor(.primary)
                    
                    Text(device.identifier.uuidString)
                        .font(.system(size: 11))
                        .foregroundColor(.secondary)
                }
                Spacer()
                
                if isThisDeviceConnected {
                    Text("Connected")
                        .font(.system(size: 11, weight: .medium))
                        .foregroundColor(.green)
                        .padding(.horizontal, 8)
                        .padding(.vertical, 4)
                        .background(Color.green.opacity(0.1))
                        .cornerRadius(8)
                } else {
                    Text("Connect")
                        .font(.system(size: 11, weight: .medium))
                        .foregroundColor(.blue)
                        .padding(.horizontal, 8)
                        .padding(.vertical, 4)
                        .background(Color.blue.opacity(0.1))
                        .cornerRadius(8)
                }
            }
            .padding(.horizontal)
            .padding(.vertical, 8)
            .background(Color.white)
            .cornerRadius(10)
            .shadow(color: Color.black.opacity(0.05), radius: 2, x: 0, y: 1)
        }
        .buttonStyle(PlainButtonStyle())
    }
}

// MARK: - Preview
struct ContentView_Previews: PreviewProvider {
    static var previews: some View {
        ContentView()
    }
}
