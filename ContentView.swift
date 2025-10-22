import SwiftUIimport SwiftUI

import CoreBluetoothimport CoreBluetooth



struct ContentView: View {struct ContentView: View {

    @StateObject private var bleManager = BLEManager()    @StateObject private var bleManager = BLEManager()

        @State private var selectedDevice: CBPeripheral?

    // Tool selections matching the Flutter UI    @State private var showDevicePicker = false

    @State private var circleButton1: String = "Undo"    @State private var config: [String: Int] = ["button1": 4, "button2": 1, "button3": 3]

    @State private var circleButton2: String = "Undo"

    @State private var buttons12: String = "Color Palette"    let actions = ["Left Click", "Right Click", "Double Click", "Undo", "Redo"]

    @State private var dial: String = "Layers"    

    @State private var showDeviceSheet = false    // Map action index to function code

        func actionToCode(_ index: Int) -> Int {

    // Tool options matching Flutter        return index // 0=Left, 1=Right, 2=Double, 3=Undo, 4=Redo

    let circleButton1Options = ["Undo", "Redo", "Erase", "Brush Size (saved presets only)"]    }

    let circleButton2Options = ["Undo", "Redo", "Erase", "Brush Size (saved presets only)"]    

    let buttons12Options = ["Color Palette", "Brush Library"]    // Map function code to action index

    let dialOptions = ["Layers", "Pen Opacity", "Brush Size"]    func codeToAction(_ code: Int) -> Int {

            return code

    var body: some View {    }

        NavigationView {

            ScrollView {    var body: some View {

                VStack(spacing: 20) {        NavigationView {

                    // Tool dropdowns            VStack(spacing: 24) {

                    toolDropdown(                Text("Procreate BLE Config")

                        icon: "circle.fill",                    .font(.largeTitle)

                        title: "Circle Button 1",                    .bold()

                        selection: $circleButton1,                    .padding(.top)

                        options: circleButton1Options                

                    )                Text(bleManager.statusMessage)

                                        .foregroundColor(.gray)

                    toolDropdown(                    .multilineTextAlignment(.center)

                        icon: "circle.lefthalf.filled",                    .padding(.horizontal)

                        title: "Circle Button 2",                

                        selection: $circleButton2,                if !bleManager.isConnected {

                        options: circleButton2Options                    Button(action: { 

                    )                        bleManager.startScan()

                                            showDevicePicker = true 

                    toolDropdown(                    }) {

                        icon: "gamecontroller.fill",                        HStack {

                        title: "Buttons 1 + 2",                            if bleManager.isScanning {

                        selection: $buttons12,                                ProgressView()

                        options: buttons12Options                                    .progressViewStyle(CircularProgressViewStyle(tint: .white))

                    )                                Text("Scanning...")

                                                } else {

                    toolDropdown(                                Image(systemName: "antenna.radiowaves.left.and.right")

                        icon: "dial.medium.fill",                                Text("Scan for Devices")

                        title: "Dial",                            }

                        selection: $dial,                        }

                        options: dialOptions                        .frame(maxWidth: .infinity)

                    )                        .padding()

                                            .background(Color.blue)

                    // Status message                        .foregroundColor(.white)

                    if !bleManager.statusMessage.isEmpty {                        .cornerRadius(10)

                        VStack(spacing: 8) {                    }

                            Image(systemName: bleManager.statusMessage.contains("❌") ? "xmark.circle.fill" : "checkmark.circle.fill")                    .disabled(bleManager.isScanning)

                                .font(.system(size: 32))                    .padding(.horizontal)

                                .foregroundColor(bleManager.statusMessage.contains("❌") ? .red : .green)                } else {

                                                HStack {

                            Text(bleManager.statusMessage)                        Image(systemName: "checkmark.circle.fill")

                                .multilineTextAlignment(.center)                            .foregroundColor(.green)

                                .padding()                        Text("Connected")

                        }                            .foregroundColor(.green)

                        .frame(maxWidth: .infinity)                            .bold()

                        .background(                        Spacer()

                            RoundedRectangle(cornerRadius: 12)                        Button("Disconnect") {

                                .fill(bleManager.statusMessage.contains("❌") ? Color.red.opacity(0.1) : Color.green.opacity(0.1))                            bleManager.disconnect()

                        )                        }

                        .padding(.horizontal)                        .foregroundColor(.red)

                    }                    }

                }                    .padding()

                .padding()                    .background(Color.green.opacity(0.1))

            }                    .cornerRadius(10)

            .navigationTitle("eSketch Shortcuts")                    .padding(.horizontal)

            .navigationBarTitleDisplayMode(.inline)                }

            .toolbar {                

                // Bluetooth button in leading position                if showDevicePicker {

                ToolbarItem(placement: .navigationBarLeading) {                    VStack {

                    Button(action: {                        HStack {

                        if !bleManager.isScanning {                            Text("Available Devices (\(bleManager.devices.count))")

                            bleManager.startScan()                                .font(.headline)

                            showDeviceSheet = true                            Spacer()

                        }                            if bleManager.isScanning {

                    }) {                                ProgressView()

                        Image(systemName: bleManager.isScanning ? "antenna.radiowaves.left.and.right" : "bluetooth")                            } else {

                            .foregroundColor(.white)                                Button("Scan Again") {

                    }                                    bleManager.startScan()

                    .disabled(bleManager.isScanning)                                }

                }                                .font(.caption)

                                            }

                // Disconnect button (only show when connected)                        }

                ToolbarItem(placement: .navigationBarTrailing) {                        .padding(.horizontal)

                    if bleManager.isConnected {                        

                        Button(action: {                        if bleManager.devices.isEmpty {

                            bleManager.disconnect()                            VStack(spacing: 10) {

                        }) {                                Image(systemName: "wifi.slash")

                            Image(systemName: "link.slash")                                    .font(.largeTitle)

                                .foregroundColor(.white)                                    .foregroundColor(.gray)

                        }                                Text("No devices found")

                    }                                    .foregroundColor(.gray)

                }                                Text("Make sure ESP32 is powered on")

                                                    .font(.caption)

                // Save button                                    .foregroundColor(.gray)

                ToolbarItem(placement: .navigationBarTrailing) {                            }

                    Button(action: {                            .frame(height: 150)

                        saveConfiguration()                        } else {

                    }) {                            List(bleManager.devices, id: \.identifier) { device in

                        Image(systemName: "square.and.arrow.down")                                Button(action: {

                            .foregroundColor(.white)                                    bleManager.connect(to: device)

                    }                                    selectedDevice = device

                    .disabled(!bleManager.isConnected)                                    showDevicePicker = false

                }                                }) {

            }                                    HStack {

            .toolbarBackground(Color(red: 0.4, green: 0.2, blue: 0.6), for: .navigationBar)                                        VStack(alignment: .leading) {

            .toolbarBackground(.visible, for: .navigationBar)                                            Text(device.name ?? "Unknown Device")

            .toolbarColorScheme(.dark, for: .navigationBar)                                                .font(.headline)

        }                                            Text(device.identifier.uuidString)

        .sheet(isPresented: $showDeviceSheet) {                                                .font(.caption)

            DeviceSelectionSheet(bleManager: bleManager, showDeviceSheet: $showDeviceSheet)                                                .foregroundColor(.gray)

        }                                        }

        .onReceive(bleManager.$isConnected) { connected in                                        Spacer()

            if connected {                                        Image(systemName: "chevron.right")

                showDeviceSheet = false                                            .foregroundColor(.gray)

            }                                    }

        }                                    .padding(.vertical, 4)

    }                                }

                                }

    // Helper function to build tool dropdown cards                            .frame(maxHeight: 250)

    @ViewBuilder                        }

    func toolDropdown(icon: String, title: String, selection: Binding<String>, options: [String]) -> some View {                    }

        VStack(alignment: .leading, spacing: 12) {                }

            HStack {                

                Image(systemName: icon)                if bleManager.isConnected {

                    .foregroundColor(Color(red: 0.4, green: 0.2, blue: 0.6))                    VStack(spacing: 16) {

                    .font(.system(size: 20))                        Text("Button Configuration")

                Text(title)                            .font(.headline)

                    .font(.system(size: 18, weight: .bold))                        

                    .foregroundColor(Color(red: 0.4, green: 0.2, blue: 0.6))                        Form {

            }                            ForEach(["button1", "button2", "button3"], id: \.self) { key in

                                            Picker(key.replacingOccurrences(of: "button", with: "Button "), selection: Binding(

            Menu {                                    get: { codeToAction(config[key] ?? 0) },

                ForEach(options, id: \.self) { option in                                    set: { config[key] = actionToCode($0) }

                    Button(action: {                                )) {

                        selection.wrappedValue = option                                    ForEach(0..<actions.count, id: \.self) { i in

                        // Auto-save when connected                                        Text(actions[i]).tag(i)

                        if bleManager.isConnected {                                    }

                            saveConfiguration()                                }

                        }                                .pickerStyle(MenuPickerStyle())

                    }) {                            }

                        HStack {                        }

                            Text(option)                        .frame(height: 200)

                            if selection.wrappedValue == option {                        

                                Image(systemName: "checkmark")                        Button(action: {

                            }                            bleManager.writeConfig(config: config)

                        }                        }) {

                    }                            HStack {

                }                                Image(systemName: "square.and.arrow.down")

            } label: {                                Text("Save Configuration")

                HStack {                            }

                    Text(selection.wrappedValue)                            .frame(maxWidth: .infinity)

                        .foregroundColor(.black)                            .padding()

                        .fontWeight(.medium)                            .background(Color.orange)

                    Spacer()                            .foregroundColor(.white)

                    Image(systemName: "chevron.down")                            .cornerRadius(10)

                        .foregroundColor(Color(red: 0.4, green: 0.2, blue: 0.6))                        }

                }                        .padding(.horizontal)

                .padding()                    }

                .background(getToolColor(for: selection.wrappedValue))                }

                .cornerRadius(8)                

                .overlay(                Spacer()

                    RoundedRectangle(cornerRadius: 8)            }

                        .stroke(Color(red: 0.4, green: 0.2, blue: 0.6).opacity(0.3), lineWidth: 1)            .padding()

                )            .onReceive(bleManager.$isConnected) { connected in

            }                if !connected {

                                showDevicePicker = false

            Text("Selected: \(selection.wrappedValue)")                }

                .font(.system(size: 14))            }

                .foregroundColor(.gray)            .onReceive(bleManager.$currentConfig) { newConfig in

        }                // Update local config when device config is read

        .padding()                self.config = newConfig

        .background(            }

            RoundedRectangle(cornerRadius: 12)        }

                .fill(Color.white)    }

                .shadow(color: Color.black.opacity(0.1), radius: 4, x: 0, y: 2)}

        )
    }
    
    // Get background color based on selection
    func getToolColor(for option: String) -> Color {
        if option == "Undo" || option == "Erase" {
            return Color(red: 1.0, green: 0.76, blue: 0.8) // #FFC1CC pink
        }
        return Color.gray.opacity(0.2)
    }
    
    // Map UI options to firmware function codes
    func optionToFunctionCode(_ option: String) -> Int {
        switch option {
        case "Undo": return 3
        case "Redo": return 4
        case "Erase", "Brush Size (saved presets only)", 
             "Color Palette", "Brush Library", 
             "Layers", "Pen Opacity", "Brush Size":
            return 0 // Default to Left Click for unsupported options
        default: return 0
        }
    }
    
    // Save configuration to device
    func saveConfiguration() {
        // Map UI selections to firmware button codes
        var config: [String: Int] = [:]
        config["button1"] = optionToFunctionCode(circleButton1)
        config["button2"] = optionToFunctionCode(circleButton2)
        config["button3"] = optionToFunctionCode(buttons12)
        
        bleManager.writeConfig(config: config)
    }
}

// Device selection sheet
struct DeviceSelectionSheet: View {
    @ObservedObject var bleManager: BLEManager
    @Binding var showDeviceSheet: Bool
    
    var body: some View {
        NavigationView {
            VStack {
                if bleManager.isScanning {
                    VStack(spacing: 20) {
                        ProgressView()
                            .scaleEffect(1.5)
                        Text("Scanning for devices...")
                            .font(.headline)
                        Text("Make sure your ESP32 is powered on")
                            .font(.caption)
                            .foregroundColor(.gray)
                    }
                    .frame(maxHeight: .infinity)
                } else if bleManager.devices.isEmpty {
                    VStack(spacing: 20) {
                        Image(systemName: "magnifyingglass")
                            .font(.system(size: 50))
                            .foregroundColor(.gray)
                        Text("No devices found")
                            .font(.headline)
                        Button("Scan Again") {
                            bleManager.startScan()
                        }
                        .buttonStyle(.bordered)
                    }
                    .frame(maxHeight: .infinity)
                } else {
                    List(bleManager.devices, id: \.identifier) { device in
                        Button(action: {
                            bleManager.connect(to: device)
                            showDeviceSheet = false
                        }) {
                            VStack(alignment: .leading, spacing: 4) {
                                Text(device.name ?? "Unknown Device")
                                    .font(.headline)
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
