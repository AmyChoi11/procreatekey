import SwiftUI
import CoreBluetooth

struct BluetoothConnectionView: View {
    @ObservedObject var bleManager: BLEManager
    @Environment(\.dismiss) var dismiss
    
    var body: some View {
        ZStack {
            // Clean white background
            Color.white
                .ignoresSafeArea()
            
            VStack(spacing: 30) {
                Spacer()
                
                // Bluetooth icon
                Image(systemName: bleManager.isConnected ? "checkmark.circle.fill" : 
                      bleManager.isScanning ? "antenna.radiowaves.left.and.right" : "bluetooth")
                    .font(.system(size: 80))
                    .foregroundColor(bleManager.isConnected ? .green : 
                                   bleManager.isScanning ? .blue : .gray)
                
                // Status text
                Text(bleManager.isConnected ? "Connected!" : 
                     bleManager.isScanning ? "Scanning..." : "Ready to Connect")
                    .font(.title2)
                    .fontWeight(.semibold)
                
                if !bleManager.statusMessage.isEmpty {
                    Text(bleManager.statusMessage)
                        .font(.subheadline)
                        .foregroundColor(.gray)
                        .multilineTextAlignment(.center)
                        .padding(.horizontal, 40)
                }
                
                Spacer()
                
                // Device list (if scanning or devices found)
                if !bleManager.devices.isEmpty {
                    VStack(spacing: 15) {
                        Text("Found Devices")
                            .font(.headline)
                            .foregroundColor(.gray)
                        
                        ForEach(bleManager.devices, id: \.identifier) { device in
                            Button(action: {
                                bleManager.connect(to: device)
                            }) {
                                HStack {
                                    Image(systemName: "dot.radiowaves.left.and.right")
                                        .foregroundColor(.blue)
                                    
                                    VStack(alignment: .leading, spacing: 4) {
                                        Text(device.name ?? "Unknown Device")
                                            .font(.headline)
                                            .foregroundColor(.primary)
                                        
                                        Text(device.identifier.uuidString)
                                            .font(.caption)
                                            .foregroundColor(.gray)
                                    }
                                    
                                    Spacer()
                                    
                                    Image(systemName: "chevron.right")
                                        .foregroundColor(.gray)
                                }
                                .padding()
                                .background(Color.gray.opacity(0.1))
                                .cornerRadius(12)
                            }
                        }
                    }
                    .padding(.horizontal, 30)
                }
                
                Spacer()
                
                // Main action button
                if bleManager.isConnected {
                    VStack(spacing: 15) {
                        Button(action: {
                            dismiss()
                        }) {
                            Text("Done")
                                .font(.headline)
                                .foregroundColor(.white)
                                .frame(maxWidth: .infinity)
                                .padding()
                                .background(Color.green)
                                .cornerRadius(12)
                        }
                        .padding(.horizontal, 30)
                        
                        Button(action: {
                            bleManager.disconnect()
                        }) {
                            Text("Disconnect")
                                .font(.subheadline)
                                .foregroundColor(.red)
                        }
                    }
                } else if bleManager.isScanning {
                    Button(action: {
                        bleManager.stopScan()
                    }) {
                        Text("Stop Scanning")
                            .font(.headline)
                            .foregroundColor(.white)
                            .frame(maxWidth: .infinity)
                            .padding()
                            .background(Color.orange)
                            .cornerRadius(12)
                    }
                    .padding(.horizontal, 30)
                } else {
                    Button(action: {
                        bleManager.startScan()
                    }) {
                        HStack {
                            Image(systemName: "antenna.radiowaves.left.and.right")
                            Text("Scan for Devices")
                        }
                        .font(.headline)
                        .foregroundColor(.white)
                        .frame(maxWidth: .infinity)
                        .padding()
                        .background(Color.blue)
                        .cornerRadius(12)
                    }
                    .padding(.horizontal, 30)
                }
                
                Spacer()
            }
        }
        .navigationTitle("Bluetooth")
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            ToolbarItem(placement: .navigationBarTrailing) {
                Button("Cancel") {
                    bleManager.stopScan()
                    dismiss()
                }
            }
        }
        .onDisappear {
            if !bleManager.isConnected {
                bleManager.stopScan()
            }
        }
    }
}
