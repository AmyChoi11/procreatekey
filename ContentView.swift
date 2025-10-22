import SwiftUI
import CoreBluetooth

struct ContentView: View {
    @StateObject private var bleManager = BLEManager()
    
    @State private var circleButton1: String = "Undo"
    @State private var circleButton2: String = "Undo"
    @State private var buttons12: String = "Color Palette"
    @State private var dial: String = "Layers"
    @State private var showDeviceSheet = false
    @State private var hasShownInitialSheet = false
    
    let circleButton1Options = ["Undo", "Redo", "Erase", "Brush Size (saved presets only)"]
    let circleButton2Options = ["Undo", "Redo", "Erase", "Brush Size (saved presets only)"]
    let buttons12Options = ["Color Palette", "Brush Library"]
    let dialOptions = ["Layers", "Pen Opacity", "Brush Size"]
    
    var body: some View {
        NavigationStack {
            ZStack {
                // Background color
                Color(red: 0.95, green: 0.95, blue: 0.97)
                    .ignoresSafeArea()
                
                ScrollView {
                    VStack(spacing: 20) {
                        toolDropdown(icon: "circle.fill", title: "Circle Button 1", selection: $circleButton1, options: circleButton1Options)
                        toolDropdown(icon: "circle.lefthalf.filled", title: "Circle Button 2", selection: $circleButton2, options: circleButton2Options)
                        toolDropdown(icon: "gamecontroller.fill", title: "Buttons 1 + 2", selection: $buttons12, options: buttons12Options)
                        toolDropdown(icon: "dial.medium.fill", title: "Dial", selection: $dial, options: dialOptions)
                        
                        if !bleManager.statusMessage.isEmpty {
                            VStack(spacing: 8) {
                                Image(systemName: bleManager.statusMessage.contains("") ? "xmark.circle.fill" : "checkmark.circle.fill")
                                    .font(.system(size: 32))
                                    .foregroundColor(bleManager.statusMessage.contains("") ? .red : .green)
                                Text(bleManager.statusMessage).multilineTextAlignment(.center).padding()
                            }
                            .frame(maxWidth: .infinity)
                            .background(RoundedRectangle(cornerRadius: 12).fill(bleManager.statusMessage.contains("") ? Color.red.opacity(0.1) : Color.green.opacity(0.1)))
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
                        Image(systemName: bleManager.isScanning ? "antenna.radiowaves.left.and.right" : "bluetooth")
                            .foregroundColor(.white)
                            .font(.system(size: 18))
                    }
                    .disabled(bleManager.isScanning)
                }
                ToolbarItem(placement: .navigationBarTrailing) {
                    HStack(spacing: 16) {
                        if bleManager.isConnected {
                            Button(action: { bleManager.disconnect() }) { 
                                Image(systemName: "link.slash")
                                    .foregroundColor(.white)
                            }
                        }
                        Button(action: { saveConfiguration() }) { 
                            Image(systemName: "square.and.arrow.down")
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
    func toolDropdown(icon: String, title: String, selection: Binding<String>, options: [String]) -> some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack {
                Image(systemName: icon).foregroundColor(Color(red: 0.4, green: 0.2, blue: 0.6)).font(.system(size: 20))
                Text(title).font(.system(size: 18, weight: .bold)).foregroundColor(Color(red: 0.4, green: 0.2, blue: 0.6))
            }
            Menu {
                ForEach(options, id: \.self) { option in
                    Button(action: { selection.wrappedValue = option; if bleManager.isConnected { saveConfiguration() } }) {
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
        if option == "Undo" || option == "Erase" { return Color(red: 1.0, green: 0.76, blue: 0.8) }
        return Color.gray.opacity(0.2)
    }
    
    func optionToFunctionCode(_ option: String) -> Int {
        switch option {
        case "Undo": return 3
        case "Redo": return 4
        case "Erase", "Brush Size (saved presets only)", "Color Palette", "Brush Library", "Layers", "Pen Opacity", "Brush Size": return 0
        default: return 0
        }
    }
    
    func saveConfiguration() {
        var config: [String: Int] = [:]
        config["button1"] = optionToFunctionCode(circleButton1)
        config["button2"] = optionToFunctionCode(circleButton2)
        config["button3"] = optionToFunctionCode(buttons12)
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
                        Text("Scanning for devices...").font(.headline)
                        Text("Make sure your ESP32 is powered on").font(.caption).foregroundColor(.gray)
                    }.frame(maxHeight: .infinity)
                } else if bleManager.devices.isEmpty {
                    VStack(spacing: 20) {
                        Image(systemName: "magnifyingglass").font(.system(size: 50)).foregroundColor(.gray)
                        Text("No devices found").font(.headline)
                        Button("Scan Again") { bleManager.startScan() }.buttonStyle(.bordered)
                    }.frame(maxHeight: .infinity)
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
