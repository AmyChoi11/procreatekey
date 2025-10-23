import SwiftUI
import CoreBluetooth

struct ContentView: View {
    @StateObject private var bleManager = BLEManager()
    
    // Store configuration as numeric codes
    // Note: "combo" refers to button1+2 pressed together
    @State private var config: [String: Int] = ["button1": 3, "button2": 3, "combo": 7, "dial": 9]
    @State private var showDeviceSheet = false
    @State private var hasShownInitialSheet = false
    
    let circleButton1Options = ["Undo", "Redo", "Erase"]
    let circleButton2Options = ["Undo", "Redo", "Erase"]
    let buttons12Options = ["Color Palette", "Brush Library"]
    let dialOptions = ["Brush Size (5%)", "Brush Size (10%)"]
    
    var body: some View {
        NavigationStack {
            ZStack {
                // Background color
                Color(red: 0.95, green: 0.95, blue: 0.97)
                    .ignoresSafeArea()
                
                ScrollView {
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
                        
                        toolDropdown(
                            icon: "circle.fill", 
                            title: "Circle Button 1", 
                            configKey: "button1",
                            options: circleButton1Options
                        )
                        toolDropdown(
                            icon: "circle.lefthalf.filled", 
                            title: "Circle Button 2", 
                            configKey: "button2",
                            options: circleButton2Options
                        )
                        toolDropdown(
                            icon: "gamecontroller.fill", 
                            title: "Buttons 1 + 2", 
                            configKey: "combo",
                            options: buttons12Options
                        )
                        toolDropdown(
                            icon: "dial.medium.fill", 
                            title: "Dial", 
                            configKey: "dial",
                            options: dialOptions
                        )
                        
                        if !bleManager.statusMessage.isEmpty {
                            VStack(spacing: 8) {
                                Image(systemName: bleManager.statusMessage.contains("⚠️") ? "exclamationmark.circle.fill" : "checkmark.circle.fill")
                                    .font(.system(size: 32))
                                    .foregroundColor(bleManager.statusMessage.contains("⚠️") ? .orange : .green)
                                Text(bleManager.statusMessage).multilineTextAlignment(.center).padding()
                            }
                            .frame(maxWidth: .infinity)
                            .background(RoundedRectangle(cornerRadius: 12).fill(bleManager.statusMessage.contains("⚠️") ? Color.orange.opacity(0.1) : Color.green.opacity(0.1)))
                            .padding(.horizontal)
                        }
                    }
                    .padding()
                }
            }
            .navigationTitle("eSketch Shortcuts")
            .navigationBarTitleDisplayMode(.large)
            .toolbar {
                ToolbarItem(placement: .navigationBarLeading) {
                    Button(action: { 
                        if !bleManager.isScanning { 
                            bleManager.startScan()
                            showDeviceSheet = true 
                        } 
                    }) {
                        // Use alternative icon for simulator compatibility
                        Image(systemName: bleManager.isScanning ? "antenna.radiowaves.left.and.right" : "wave.3.right")
                            .foregroundColor(.white)
                            .font(.system(size: 18))
                    }
                    .disabled(bleManager.isScanning)
                }
                ToolbarItem(placement: .navigationBarTrailing) {
                    HStack(spacing: 16) {
                        if bleManager.isConnected {
                            Button(action: { bleManager.disconnect() }) { 
                                Image(systemName: "xmark.circle")
                                    .foregroundColor(.white)
                            }
                        }
                        Button(action: { saveConfiguration() }) { 
                            Image(systemName: "arrow.down.circle")
                                .foregroundColor(.white)
                        }
                        .disabled(!bleManager.isConnected)
                    }
                }
            }
            .toolbarBackground(Color(red: 0.4, green: 0.2, blue: 0.6), for: .navigationBar)
            .toolbarBackground(.visible, for: .navigationBar)
            .toolbarColorScheme(.dark, for: .navigationBar)
        }
        .sheet(isPresented: $showDeviceSheet) { 
            DeviceSelectionSheet(bleManager: bleManager, showDeviceSheet: $showDeviceSheet) 
        }
        .onReceive(bleManager.$isConnected) { connected in 
            if connected { 
                showDeviceSheet = false 
            }
        }
        .onReceive(bleManager.$currentConfig) { newConfig in
            // Update local config when device config is read - exactly like the working version
            print("📥 Loading configuration from device: \(newConfig)")
            self.config = newConfig
        }
        .onAppear {
            // Automatically show device selection sheet on first launch
            if !hasShownInitialSheet && !bleManager.isConnected {
                hasShownInitialSheet = true
                DispatchQueue.main.asyncAfter(deadline: .now() + 0.3) {
                    bleManager.startScan()
                    showDeviceSheet = true
                }
            }
        }
    }
    
    @ViewBuilder
    func toolDropdown(icon: String, title: String, configKey: String, options: [String]) -> some View {
        let selection = Binding<String>(
            get: { 
                let code = config[configKey] ?? 0
                return codeToOption(code, validOptions: options)
            },
            set: { newValue in
                config[configKey] = optionToCode(newValue)
            }
        )
        
        VStack(alignment: .leading, spacing: 12) {
            HStack {
                Image(systemName: icon).foregroundColor(Color(red: 0.4, green: 0.2, blue: 0.6)).font(.system(size: 20))
                Text(title).font(.system(size: 18, weight: .bold)).foregroundColor(Color(red: 0.4, green: 0.2, blue: 0.6))
            }
            Menu {
                ForEach(options, id: \.self) { option in
                    Button(action: { 
                        selection.wrappedValue = option
                    }) {
                        HStack { Text(option); if selection.wrappedValue == option { Image(systemName: "checkmark") } }
                    }
                }
            } label: {
                HStack {
                    Text(selection.wrappedValue).foregroundColor(.black).fontWeight(.medium)
                    Spacer()
                    Image(systemName: "chevron.down").foregroundColor(Color(red: 0.4, green: 0.2, blue: 0.6))
                }
                .padding().background(getToolColor(for: selection.wrappedValue)).cornerRadius(8)
                .overlay(RoundedRectangle(cornerRadius: 8).stroke(Color(red: 0.4, green: 0.2, blue: 0.6).opacity(0.3), lineWidth: 1))
            }
            Text("Selected: \(selection.wrappedValue)").font(.system(size: 14)).foregroundColor(.gray)
        }
        .padding().background(RoundedRectangle(cornerRadius: 12).fill(Color.white).shadow(color: Color.black.opacity(0.1), radius: 4, x: 0, y: 2))
    }
    
    func getToolColor(for option: String) -> Color {
        // All options use the same neutral gray color
        return Color.gray.opacity(0.2)
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