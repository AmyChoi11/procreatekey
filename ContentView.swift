import SwiftUI
import CoreBluetooth

struct ContentView: View {
    @StateObject private var bleManager = BLEManager()
    @State private var selectedDevice: CBPeripheral?
    @State private var showDevicePicker = false
    @State private var config: [String: Int] = ["button1": 4, "button2": 1, "button3": 3]

    let actions = ["Left Click", "Right Click", "Double Click", "Undo", "Redo"]
    
    // Map action index to function code
    func actionToCode(_ index: Int) -> Int {
        return index // 0=Left, 1=Right, 2=Double, 3=Undo, 4=Redo
    }
    
    // Map function code to action index
    func codeToAction(_ code: Int) -> Int {
        return code
    }

    var body: some View {
        NavigationView {
            VStack(spacing: 24) {
                Text("Procreate BLE Config")
                    .font(.largeTitle)
                    .bold()
                    .padding(.top)
                
                Text(bleManager.statusMessage)
                    .foregroundColor(.gray)
                    .multilineTextAlignment(.center)
                    .padding(.horizontal)
                
                Button(action: { 
                    bleManager.startScan()
                    showDevicePicker = true 
                }) {
                    HStack {
                        Image(systemName: bleManager.isConnected ? "checkmark.circle.fill" : "antenna.radiowaves.left.and.right")
                        Text(bleManager.isConnected ? "Connected" : "Scan for Devices")
                    }
                    .frame(maxWidth: .infinity)
                    .padding()
                    .background(bleManager.isConnected ? Color.green : Color.blue)
                    .foregroundColor(.white)
                    .cornerRadius(10)
                }
                .disabled(bleManager.isConnected)
                .padding(.horizontal)
                
                if showDevicePicker && !bleManager.devices.isEmpty {
                    VStack {
                        Text("Select Device:")
                            .font(.headline)
                        List(bleManager.devices, id: \.identifier) { device in
                            Button(action: {
                                bleManager.connect(to: device)
                                selectedDevice = device
                                showDevicePicker = false
                            }) {
                                HStack {
                                    Image(systemName: "dot.radiowaves.left.and.right")
                                    Text(device.name ?? "Unknown Device")
                                    Spacer()
                                    Image(systemName: "chevron.right")
                                        .foregroundColor(.gray)
                                }
                            }
                        }
                        .frame(maxHeight: 200)
                    }
                }
                
                if bleManager.isConnected {
                    VStack(spacing: 16) {
                        Text("Button Configuration")
                            .font(.headline)
                        
                        Form {
                            ForEach(["button1", "button2", "button3"], id: \.self) { key in
                                Picker(key.replacingOccurrences(of: "button", with: "Button "), selection: Binding(
                                    get: { codeToAction(config[key] ?? 0) },
                                    set: { config[key] = actionToCode($0) }
                                )) {
                                    ForEach(0..<actions.count, id: \.self) { i in
                                        Text(actions[i]).tag(i)
                                    }
                                }
                                .pickerStyle(MenuPickerStyle())
                            }
                        }
                        .frame(height: 200)
                        
                        Button(action: {
                            bleManager.writeConfig(config: config)
                        }) {
                            HStack {
                                Image(systemName: "square.and.arrow.down")
                                Text("Save Configuration")
                            }
                            .frame(maxWidth: .infinity)
                            .padding()
                            .background(Color.orange)
                            .foregroundColor(.white)
                            .cornerRadius(10)
                        }
                        .padding(.horizontal)
                    }
                }
                
                Spacer()
            }
            .padding()
            .onReceive(bleManager.$isConnected) { connected in
                if !connected {
                    showDevicePicker = false
                }
            }
            .onReceive(bleManager.$currentConfig) { newConfig in
                // Update local config when device config is read
                self.config = newConfig
            }
        }
    }
}
