import SwiftUIimport SwiftUIimport SwiftUIimport SwiftUI

import CoreBluetooth

import CoreBluetooth

struct ContentView: View {

    @StateObject private var bleManager = BLEManager()import CoreBluetoothimport CoreBluetooth

    

    // Tool selections matching the Flutter UIstruct ContentView: View {

    @State private var circleButton1: String = "Undo"

    @State private var circleButton2: String = "Undo"    @StateObject private var bleManager = BLEManager()

    @State private var buttons12: String = "Color Palette"

    @State private var dial: String = "Layers"    

    @State private var showDeviceSheet = false

        // Tool selections matching the Flutter UIstruct ContentView: View {struct ContentView: View {

    // Tool options matching Flutter

    let circleButton1Options = ["Undo", "Redo", "Erase", "Brush Size (saved presets only)"]    @State private var circleButton1: String = "Undo"

    let circleButton2Options = ["Undo", "Redo", "Erase", "Brush Size (saved presets only)"]

    let buttons12Options = ["Color Palette", "Brush Library"]    @State private var circleButton2: String = "Undo"    @StateObject private var bleManager = BLEManager()    @StateObject private var bleManager = BLEManager()

    let dialOptions = ["Layers", "Pen Opacity", "Brush Size"]

        @State private var buttons12: String = "Color Palette"

    var body: some View {

        NavigationView {    @State private var dial: String = "Layers"        @State private var selectedDevice: CBPeripheral?

            ScrollView {

                VStack(spacing: 20) {    @State private var showDeviceSheet = false

                    // Tool dropdowns

                    toolDropdown(        // Tool selections matching the Flutter UI    @State private var showDevicePicker = false

                        icon: "circle.fill",

                        title: "Circle Button 1",    // Tool options matching Flutter

                        selection: $circleButton1,

                        options: circleButton1Options    let circleButton1Options = ["Undo", "Redo", "Erase", "Brush Size (saved presets only)"]    @State private var circleButton1: String = "Undo"    @State private var config: [String: Int] = ["button1": 4, "button2": 1, "button3": 3]

                    )

                        let circleButton2Options = ["Undo", "Redo", "Erase", "Brush Size (saved presets only)"]

                    toolDropdown(

                        icon: "circle.lefthalf.filled",    let buttons12Options = ["Color Palette", "Brush Library"]    @State private var circleButton2: String = "Undo"

                        title: "Circle Button 2",

                        selection: $circleButton2,    let dialOptions = ["Layers", "Pen Opacity", "Brush Size"]

                        options: circleButton2Options

                    )        @State private var buttons12: String = "Color Palette"    let actions = ["Left Click", "Right Click", "Double Click", "Undo", "Redo"]

                    

                    toolDropdown(    var body: some View {

                        icon: "gamecontroller.fill",

                        title: "Buttons 1 + 2",        NavigationView {    @State private var dial: String = "Layers"    

                        selection: $buttons12,

                        options: buttons12Options            ScrollView {

                    )

                                    VStack(spacing: 20) {    @State private var showDeviceSheet = false    // Map action index to function code

                    toolDropdown(

                        icon: "dial.medium.fill",                    // Tool dropdowns

                        title: "Dial",

                        selection: $dial,                    toolDropdown(        func actionToCode(_ index: Int) -> Int {

                        options: dialOptions

                    )                        icon: "circle.fill",

                    

                    // Status message                        title: "Circle Button 1",    // Tool options matching Flutter        return index // 0=Left, 1=Right, 2=Double, 3=Undo, 4=Redo

                    if !bleManager.statusMessage.isEmpty {

                        VStack(spacing: 8) {                        selection: $circleButton1,

                            Image(systemName: bleManager.statusMessage.contains("❌") ? "xmark.circle.fill" : "checkmark.circle.fill")

                                .font(.system(size: 32))                        options: circleButton1Options    let circleButton1Options = ["Undo", "Redo", "Erase", "Brush Size (saved presets only)"]    }

                                .foregroundColor(bleManager.statusMessage.contains("❌") ? .red : .green)

                                                )

                            Text(bleManager.statusMessage)

                                .multilineTextAlignment(.center)                        let circleButton2Options = ["Undo", "Redo", "Erase", "Brush Size (saved presets only)"]    

                                .padding()

                        }                    toolDropdown(

                        .frame(maxWidth: .infinity)

                        .background(                        icon: "circle.lefthalf.filled",    let buttons12Options = ["Color Palette", "Brush Library"]    // Map function code to action index

                            RoundedRectangle(cornerRadius: 12)

                                .fill(bleManager.statusMessage.contains("❌") ? Color.red.opacity(0.1) : Color.green.opacity(0.1))                        title: "Circle Button 2",

                        )

                        .padding(.horizontal)                        selection: $circleButton2,    let dialOptions = ["Layers", "Pen Opacity", "Brush Size"]    func codeToAction(_ code: Int) -> Int {

                    }

                }                        options: circleButton2Options

                .padding()

            }                    )            return code

            .navigationTitle("eSketch Shortcuts")

            .navigationBarTitleDisplayMode(.inline)                    

            .toolbar {

                // Bluetooth button in leading position                    toolDropdown(    var body: some View {    }

                ToolbarItem(placement: .navigationBarLeading) {

                    Button(action: {                        icon: "gamecontroller.fill",

                        if !bleManager.isScanning {

                            bleManager.startScan()                        title: "Buttons 1 + 2",        NavigationView {

                            showDeviceSheet = true

                        }                        selection: $buttons12,

                    }) {

                        Image(systemName: bleManager.isScanning ? "antenna.radiowaves.left.and.right" : "bluetooth")                        options: buttons12Options            ScrollView {    var body: some View {

                            .foregroundColor(.white)

                    }                    )

                    .disabled(bleManager.isScanning)

                }                                    VStack(spacing: 20) {        NavigationView {

                

                // Disconnect button (only show when connected)                    toolDropdown(

                ToolbarItem(placement: .navigationBarTrailing) {

                    if bleManager.isConnected {                        icon: "dial.medium.fill",                    // Tool dropdowns            VStack(spacing: 24) {

                        Button(action: {

                            bleManager.disconnect()                        title: "Dial",

                        }) {

                            Image(systemName: "link.slash")                        selection: $dial,                    toolDropdown(                Text("Procreate BLE Config")

                                .foregroundColor(.white)

                        }                        options: dialOptions

                    }

                }                    )                        icon: "circle.fill",                    .font(.largeTitle)

                

                // Save button                    

                ToolbarItem(placement: .navigationBarTrailing) {

                    Button(action: {                    // Status message                        title: "Circle Button 1",                    .bold()

                        saveConfiguration()

                    }) {                    if !bleManager.statusMessage.isEmpty {

                        Image(systemName: "square.and.arrow.down")

                            .foregroundColor(.white)                        VStack(spacing: 8) {                        selection: $circleButton1,                    .padding(.top)

                    }

                    .disabled(!bleManager.isConnected)                            Image(systemName: bleManager.statusMessage.contains("❌") ? "xmark.circle.fill" : "checkmark.circle.fill")

                }

            }                                .font(.system(size: 32))                        options: circleButton1Options                

            .toolbarBackground(Color(red: 0.4, green: 0.2, blue: 0.6), for: .navigationBar)

            .toolbarBackground(.visible, for: .navigationBar)                                .foregroundColor(bleManager.statusMessage.contains("❌") ? .red : .green)

            .toolbarColorScheme(.dark, for: .navigationBar)

        }                                                )                Text(bleManager.statusMessage)

        .sheet(isPresented: $showDeviceSheet) {

            DeviceSelectionSheet(bleManager: bleManager, showDeviceSheet: $showDeviceSheet)                            Text(bleManager.statusMessage)

        }

        .onReceive(bleManager.$isConnected) { connected in                                .multilineTextAlignment(.center)                                        .foregroundColor(.gray)

            if connected {

                showDeviceSheet = false                                .padding()

            }

        }                        }                    toolDropdown(                    .multilineTextAlignment(.center)

    }

                            .frame(maxWidth: .infinity)

    // Helper function to build tool dropdown cards

    @ViewBuilder                        .background(                        icon: "circle.lefthalf.filled",                    .padding(.horizontal)

    func toolDropdown(icon: String, title: String, selection: Binding<String>, options: [String]) -> some View {

        VStack(alignment: .leading, spacing: 12) {                            RoundedRectangle(cornerRadius: 12)

            HStack {

                Image(systemName: icon)                                .fill(bleManager.statusMessage.contains("❌") ? Color.red.opacity(0.1) : Color.green.opacity(0.1))                        title: "Circle Button 2",                

                    .foregroundColor(Color(red: 0.4, green: 0.2, blue: 0.6))

                    .font(.system(size: 20))                        )

                Text(title)

                    .font(.system(size: 18, weight: .bold))                        .padding(.horizontal)                        selection: $circleButton2,                if !bleManager.isConnected {

                    .foregroundColor(Color(red: 0.4, green: 0.2, blue: 0.6))

            }                    }

            

            Menu {                }                        options: circleButton2Options                    Button(action: { 

                ForEach(options, id: \.self) { option in

                    Button(action: {                .padding()

                        selection.wrappedValue = option

                        // Auto-save when connected            }                    )                        bleManager.startScan()

                        if bleManager.isConnected {

                            saveConfiguration()            .navigationTitle("eSketch Shortcuts")

                        }

                    }) {            .navigationBarTitleDisplayMode(.inline)                                            showDevicePicker = true 

                        HStack {

                            Text(option)            .toolbar {

                            if selection.wrappedValue == option {

                                Image(systemName: "checkmark")                // Bluetooth button in leading position                    toolDropdown(                    }) {

                            }

                        }                ToolbarItem(placement: .navigationBarLeading) {

                    }

                }                    Button(action: {                        icon: "gamecontroller.fill",                        HStack {

            } label: {

                HStack {                        if !bleManager.isScanning {

                    Text(selection.wrappedValue)

                        .foregroundColor(.black)                            bleManager.startScan()                        title: "Buttons 1 + 2",                            if bleManager.isScanning {

                        .fontWeight(.medium)

                    Spacer()                            showDeviceSheet = true

                    Image(systemName: "chevron.down")

                        .foregroundColor(Color(red: 0.4, green: 0.2, blue: 0.6))                        }                        selection: $buttons12,                                ProgressView()

                }

                .padding()                    }) {

                .background(getToolColor(for: selection.wrappedValue))

                .cornerRadius(8)                        Image(systemName: bleManager.isScanning ? "antenna.radiowaves.left.and.right" : "bluetooth")                        options: buttons12Options                                    .progressViewStyle(CircularProgressViewStyle(tint: .white))

                .overlay(

                    RoundedRectangle(cornerRadius: 8)                            .foregroundColor(.white)

                        .stroke(Color(red: 0.4, green: 0.2, blue: 0.6).opacity(0.3), lineWidth: 1)

                )                    }                    )                                Text("Scanning...")

            }

                                .disabled(bleManager.isScanning)

            Text("Selected: \(selection.wrappedValue)")

                .font(.system(size: 14))                }                                                } else {

                .foregroundColor(.gray)

        }                

        .padding()

        .background(                // Disconnect button (only show when connected)                    toolDropdown(                                Image(systemName: "antenna.radiowaves.left.and.right")

            RoundedRectangle(cornerRadius: 12)

                .fill(Color.white)                ToolbarItem(placement: .navigationBarTrailing) {

                .shadow(color: Color.black.opacity(0.1), radius: 4, x: 0, y: 2)

        )                    if bleManager.isConnected {                        icon: "dial.medium.fill",                                Text("Scan for Devices")

    }

                            Button(action: {

    // Get background color based on selection

    func getToolColor(for option: String) -> Color {                            bleManager.disconnect()                        title: "Dial",                            }

        if option == "Undo" || option == "Erase" {

            return Color(red: 1.0, green: 0.76, blue: 0.8) // #FFC1CC pink                        }) {

        }

        return Color.gray.opacity(0.2)                            Image(systemName: "link.slash")                        selection: $dial,                        }

    }

                                    .foregroundColor(.white)

    // Map UI options to firmware function codes

    func optionToFunctionCode(_ option: String) -> Int {                        }                        options: dialOptions                        .frame(maxWidth: .infinity)

        switch option {

        case "Undo": return 3                    }

        case "Redo": return 4

        case "Erase", "Brush Size (saved presets only)",                 }                    )                        .padding()

             "Color Palette", "Brush Library", 

             "Layers", "Pen Opacity", "Brush Size":                

            return 0 // Default to Left Click for unsupported options

        default: return 0                // Save button                                            .background(Color.blue)

        }

    }                ToolbarItem(placement: .navigationBarTrailing) {

    

    // Save configuration to device                    Button(action: {                    // Status message                        .foregroundColor(.white)

    func saveConfiguration() {

        // Map UI selections to firmware button codes                        saveConfiguration()

        var config: [String: Int] = [:]

        config["button1"] = optionToFunctionCode(circleButton1)                    }) {                    if !bleManager.statusMessage.isEmpty {                        .cornerRadius(10)

        config["button2"] = optionToFunctionCode(circleButton2)

        config["button3"] = optionToFunctionCode(buttons12)                        Image(systemName: "square.and.arrow.down")

        

        bleManager.writeConfig(config: config)                            .foregroundColor(.white)                        VStack(spacing: 8) {                    }

    }

}                    }



// Device selection sheet                    .disabled(!bleManager.isConnected)                            Image(systemName: bleManager.statusMessage.contains("❌") ? "xmark.circle.fill" : "checkmark.circle.fill")                    .disabled(bleManager.isScanning)

struct DeviceSelectionSheet: View {

    @ObservedObject var bleManager: BLEManager                }

    @Binding var showDeviceSheet: Bool

                }                                .font(.system(size: 32))                    .padding(.horizontal)

    var body: some View {

        NavigationView {            .toolbarBackground(Color(red: 0.4, green: 0.2, blue: 0.6), for: .navigationBar)

            VStack {

                if bleManager.isScanning {            .toolbarBackground(.visible, for: .navigationBar)                                .foregroundColor(bleManager.statusMessage.contains("❌") ? .red : .green)                } else {

                    VStack(spacing: 20) {

                        ProgressView()            .toolbarColorScheme(.dark, for: .navigationBar)

                            .scaleEffect(1.5)

                        Text("Scanning for devices...")        }                                                HStack {

                            .font(.headline)

                        Text("Make sure your ESP32 is powered on")        .sheet(isPresented: $showDeviceSheet) {

                            .font(.caption)

                            .foregroundColor(.gray)            DeviceSelectionSheet(bleManager: bleManager, showDeviceSheet: $showDeviceSheet)                            Text(bleManager.statusMessage)                        Image(systemName: "checkmark.circle.fill")

                    }

                    .frame(maxHeight: .infinity)        }

                } else if bleManager.devices.isEmpty {

                    VStack(spacing: 20) {        .onReceive(bleManager.$isConnected) { connected in                                .multilineTextAlignment(.center)                            .foregroundColor(.green)

                        Image(systemName: "magnifyingglass")

                            .font(.system(size: 50))            if connected {

                            .foregroundColor(.gray)

                        Text("No devices found")                showDeviceSheet = false                                .padding()                        Text("Connected")

                            .font(.headline)

                        Button("Scan Again") {            }

                            bleManager.startScan()

                        }        }                        }                            .foregroundColor(.green)

                        .buttonStyle(.bordered)

                    }    }

                    .frame(maxHeight: .infinity)

                } else {                            .frame(maxWidth: .infinity)                            .bold()

                    List(bleManager.devices, id: \.identifier) { device in

                        Button(action: {    // Helper function to build tool dropdown cards

                            bleManager.connect(to: device)

                            showDeviceSheet = false    @ViewBuilder                        .background(                        Spacer()

                        }) {

                            VStack(alignment: .leading, spacing: 4) {    func toolDropdown(icon: String, title: String, selection: Binding<String>, options: [String]) -> some View {

                                Text(device.name ?? "Unknown Device")

                                    .font(.headline)        VStack(alignment: .leading, spacing: 12) {                            RoundedRectangle(cornerRadius: 12)                        Button("Disconnect") {

                                Text(device.identifier.uuidString)

                                    .font(.caption)            HStack {

                                    .foregroundColor(.gray)

                            }                Image(systemName: icon)                                .fill(bleManager.statusMessage.contains("❌") ? Color.red.opacity(0.1) : Color.green.opacity(0.1))                            bleManager.disconnect()

                            .padding(.vertical, 8)

                        }                    .foregroundColor(Color(red: 0.4, green: 0.2, blue: 0.6))

                    }

                                        .font(.system(size: 20))                        )                        }

                    Text("Found \(bleManager.devices.count) device(s)")

                        .font(.caption)                Text(title)

                        .foregroundColor(.gray)

                        .padding()                    .font(.system(size: 18, weight: .bold))                        .padding(.horizontal)                        .foregroundColor(.red)

                }

            }                    .foregroundColor(Color(red: 0.4, green: 0.2, blue: 0.6))

            .navigationTitle("Select Device")

            .navigationBarTitleDisplayMode(.inline)            }                    }                    }

            .toolbar {

                ToolbarItem(placement: .navigationBarTrailing) {            

                    Button("Cancel") {

                        bleManager.stopScan()            Menu {                }                    .padding()

                        showDeviceSheet = false

                    }                ForEach(options, id: \.self) { option in

                }

            }                    Button(action: {                .padding()                    .background(Color.green.opacity(0.1))

        }

    }                        selection.wrappedValue = option

}

                        // Auto-save when connected            }                    .cornerRadius(10)

                        if bleManager.isConnected {

                            saveConfiguration()            .navigationTitle("eSketch Shortcuts")                    .padding(.horizontal)

                        }

                    }) {            .navigationBarTitleDisplayMode(.inline)                }

                        HStack {

                            Text(option)            .toolbar {                

                            if selection.wrappedValue == option {

                                Image(systemName: "checkmark")                // Bluetooth button in leading position                if showDevicePicker {

                            }

                        }                ToolbarItem(placement: .navigationBarLeading) {                    VStack {

                    }

                }                    Button(action: {                        HStack {

            } label: {

                HStack {                        if !bleManager.isScanning {                            Text("Available Devices (\(bleManager.devices.count))")

                    Text(selection.wrappedValue)

                        .foregroundColor(.black)                            bleManager.startScan()                                .font(.headline)

                        .fontWeight(.medium)

                    Spacer()                            showDeviceSheet = true                            Spacer()

                    Image(systemName: "chevron.down")

                        .foregroundColor(Color(red: 0.4, green: 0.2, blue: 0.6))                        }                            if bleManager.isScanning {

                }

                .padding()                    }) {                                ProgressView()

                .background(getToolColor(for: selection.wrappedValue))

                .cornerRadius(8)                        Image(systemName: bleManager.isScanning ? "antenna.radiowaves.left.and.right" : "bluetooth")                            } else {

                .overlay(

                    RoundedRectangle(cornerRadius: 8)                            .foregroundColor(.white)                                Button("Scan Again") {

                        .stroke(Color(red: 0.4, green: 0.2, blue: 0.6).opacity(0.3), lineWidth: 1)

                )                    }                                    bleManager.startScan()

            }

                                .disabled(bleManager.isScanning)                                }

            Text("Selected: \(selection.wrappedValue)")

                .font(.system(size: 14))                }                                .font(.caption)

                .foregroundColor(.gray)

        }                                            }

        .padding()

        .background(                // Disconnect button (only show when connected)                        }

            RoundedRectangle(cornerRadius: 12)

                .fill(Color.white)                ToolbarItem(placement: .navigationBarTrailing) {                        .padding(.horizontal)

                .shadow(color: Color.black.opacity(0.1), radius: 4, x: 0, y: 2)

        )                    if bleManager.isConnected {                        

    }

                            Button(action: {                        if bleManager.devices.isEmpty {

    // Get background color based on selection

    func getToolColor(for option: String) -> Color {                            bleManager.disconnect()                            VStack(spacing: 10) {

        if option == "Undo" || option == "Erase" {

            return Color(red: 1.0, green: 0.76, blue: 0.8) // #FFC1CC pink                        }) {                                Image(systemName: "wifi.slash")

        }

        return Color.gray.opacity(0.2)                            Image(systemName: "link.slash")                                    .font(.largeTitle)

    }

                                    .foregroundColor(.white)                                    .foregroundColor(.gray)

    // Map UI options to firmware function codes

    func optionToFunctionCode(_ option: String) -> Int {                        }                                Text("No devices found")

        switch option {

        case "Undo": return 3                    }                                    .foregroundColor(.gray)

        case "Redo": return 4

        case "Erase", "Brush Size (saved presets only)",                 }                                Text("Make sure ESP32 is powered on")

             "Color Palette", "Brush Library", 

             "Layers", "Pen Opacity", "Brush Size":                                                    .font(.caption)

            return 0 // Default to Left Click for unsupported options

        default: return 0                // Save button                                    .foregroundColor(.gray)

        }

    }                ToolbarItem(placement: .navigationBarTrailing) {                            }

    

    // Save configuration to device                    Button(action: {                            .frame(height: 150)

    func saveConfiguration() {

        // Map UI selections to firmware button codes                        saveConfiguration()                        } else {

        var config: [String: Int] = [:]

        config["button1"] = optionToFunctionCode(circleButton1)                    }) {                            List(bleManager.devices, id: \.identifier) { device in

        config["button2"] = optionToFunctionCode(circleButton2)

        config["button3"] = optionToFunctionCode(buttons12)                        Image(systemName: "square.and.arrow.down")                                Button(action: {

        

        bleManager.writeConfig(config: config)                            .foregroundColor(.white)                                    bleManager.connect(to: device)

    }

}                    }                                    selectedDevice = device



// Device selection sheet                    .disabled(!bleManager.isConnected)                                    showDevicePicker = false

struct DeviceSelectionSheet: View {

    @ObservedObject var bleManager: BLEManager                }                                }) {

    @Binding var showDeviceSheet: Bool

                }                                    HStack {

    var body: some View {

        NavigationView {            .toolbarBackground(Color(red: 0.4, green: 0.2, blue: 0.6), for: .navigationBar)                                        VStack(alignment: .leading) {

            VStack {

                if bleManager.isScanning {            .toolbarBackground(.visible, for: .navigationBar)                                            Text(device.name ?? "Unknown Device")

                    VStack(spacing: 20) {

                        ProgressView()            .toolbarColorScheme(.dark, for: .navigationBar)                                                .font(.headline)

                            .scaleEffect(1.5)

                        Text("Scanning for devices...")        }                                            Text(device.identifier.uuidString)

                            .font(.headline)

                        Text("Make sure your ESP32 is powered on")        .sheet(isPresented: $showDeviceSheet) {                                                .font(.caption)

                            .font(.caption)

                            .foregroundColor(.gray)            DeviceSelectionSheet(bleManager: bleManager, showDeviceSheet: $showDeviceSheet)                                                .foregroundColor(.gray)

                    }

                    .frame(maxHeight: .infinity)        }                                        }

                } else if bleManager.devices.isEmpty {

                    VStack(spacing: 20) {        .onReceive(bleManager.$isConnected) { connected in                                        Spacer()

                        Image(systemName: "magnifyingglass")

                            .font(.system(size: 50))            if connected {                                        Image(systemName: "chevron.right")

                            .foregroundColor(.gray)

                        Text("No devices found")                showDeviceSheet = false                                            .foregroundColor(.gray)

                            .font(.headline)

                        Button("Scan Again") {            }                                    }

                            bleManager.startScan()

                        }        }                                    .padding(.vertical, 4)

                        .buttonStyle(.bordered)

                    }    }                                }

                    .frame(maxHeight: .infinity)

                } else {                                }

                    List(bleManager.devices, id: \.identifier) { device in

                        Button(action: {    // Helper function to build tool dropdown cards                            .frame(maxHeight: 250)

                            bleManager.connect(to: device)

                            showDeviceSheet = false    @ViewBuilder                        }

                        }) {

                            VStack(alignment: .leading, spacing: 4) {    func toolDropdown(icon: String, title: String, selection: Binding<String>, options: [String]) -> some View {                    }

                                Text(device.name ?? "Unknown Device")

                                    .font(.headline)        VStack(alignment: .leading, spacing: 12) {                }

                                Text(device.identifier.uuidString)

                                    .font(.caption)            HStack {                

                                    .foregroundColor(.gray)

                            }                Image(systemName: icon)                if bleManager.isConnected {

                            .padding(.vertical, 8)

                        }                    .foregroundColor(Color(red: 0.4, green: 0.2, blue: 0.6))                    VStack(spacing: 16) {

                    }

                                        .font(.system(size: 20))                        Text("Button Configuration")

                    Text("Found \(bleManager.devices.count) device(s)")

                        .font(.caption)                Text(title)                            .font(.headline)

                        .foregroundColor(.gray)

                        .padding()                    .font(.system(size: 18, weight: .bold))                        

                }

            }                    .foregroundColor(Color(red: 0.4, green: 0.2, blue: 0.6))                        Form {

            .navigationTitle("Select Device")

            .navigationBarTitleDisplayMode(.inline)            }                            ForEach(["button1", "button2", "button3"], id: \.self) { key in

            .toolbar {

                ToolbarItem(placement: .navigationBarTrailing) {                                            Picker(key.replacingOccurrences(of: "button", with: "Button "), selection: Binding(

                    Button("Cancel") {

                        bleManager.stopScan()            Menu {                                    get: { codeToAction(config[key] ?? 0) },

                        showDeviceSheet = false

                    }                ForEach(options, id: \.self) { option in                                    set: { config[key] = actionToCode($0) }

                }

            }                    Button(action: {                                )) {

        }

    }                        selection.wrappedValue = option                                    ForEach(0..<actions.count, id: \.self) { i in

}

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
