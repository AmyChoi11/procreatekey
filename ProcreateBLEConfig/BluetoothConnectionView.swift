import SwiftUI
import CoreBluetooth

struct BluetoothConnectionView: View {
    @ObservedObject var bleManager: BLEManager
    @Environment(\.dismiss) var dismiss
    @State private var isAnimating = false
    
    var body: some View {
        ZStack {
            // Background color
            Color(red: 0.97, green: 0.94, blue: 1.0)
                .ignoresSafeArea()
            
            // Back button in top left
            VStack {
                HStack {
                    Button(action: {
                        dismiss()
                    }) {
                        HStack(spacing: 4) {
                            Image(systemName: "chevron.left")
                                .font(.system(size: 18, weight: .semibold))
                            Text("Back")
                                .font(.system(size: 16, weight: .semibold))
                        }
                        .foregroundColor(Color(red: 0.4, green: 0.2, blue: 0.6))
                        .padding(.horizontal, 16)
                        .padding(.vertical, 10)
                        .background(Color.white)
                        .cornerRadius(8)
                        .overlay(
                            RoundedRectangle(cornerRadius: 8)
                                .stroke(Color(red: 0.4, green: 0.2, blue: 0.6).opacity(0.3), lineWidth: 1)
                        )
                    }
                    .padding(.leading, 20)
                    .padding(.top, 60)
                    
                    Spacer()
                }
                Spacer()
            }
            
            // DISCONNECTED/SCANNING STATE
            VStack(spacing: 30) {
                Spacer()
                
                // Large Bluetooth icon that's tappable
                Button(action: {
                    handleTap()
                }) {
                    ZStack {
                        // Background circle
                        Circle()
                            .fill(iconBackgroundColor)
                            .frame(width: 180, height: 180)
                            .shadow(color: iconShadowColor, radius: 15, x: 0, y: 5)
                        
                        // Bluetooth icon
                        Image(systemName: iconName)
                            .font(.system(size: 80, weight: .semibold))
                            .foregroundColor(iconColor)
                            .scaleEffect(isAnimating ? 1.1 : 1.0)
                            .animation(isAnimating ?
                                Animation.easeInOut(duration: 0.5).repeatForever(autoreverses: true) :
                                .default,
                                value: isAnimating
                            )
                    }
                }
                .disabled(bleManager.isScanning || bleManager.isConnected)
                
                // Status text
                Text(statusText)
                    .font(.title2)
                    .fontWeight(.semibold)
                    .foregroundColor(.primary)
                    .padding(.top, 10)
                
                // Subtitle text
                Text(subtitleText)
                    .font(.body)
                    .foregroundColor(.secondary)
                    .multilineTextAlignment(.center)
                    .padding(.horizontal, 40)
                
                // Connection status details
                if bleManager.isConnected {
                    VStack(spacing: 15) {
                        HStack(spacing: 10) {
                            Image(systemName: "checkmark.circle.fill")
                                .foregroundColor(.green)
                            Text("Device Connected")
                                .font(.headline)
                                .foregroundColor(.green)
                        }
                        
                        if let peripheral = bleManager.connectedPeripheral {
                            VStack(spacing: 8) {
                                Text(peripheral.name ?? "Unknown Device")
                                    .font(.subheadline)
                                    .fontWeight(.medium)
                            }
                        }
                    }
                    .padding()
                    .background(Color.green.opacity(0.1))
                    .cornerRadius(12)
                    .padding(.horizontal, 40)
                }
                
                Spacer()
                
                // Scanning indicator (only shows when scanning)
                if bleManager.isScanning {
                    VStack(spacing: 10) {
                        ProgressView()
                            .scaleEffect(1.2)
                        
                        Text("Looking for XIAO devices...")
                            .font(.caption)
                            .foregroundColor(.orange)
                    }
                    .padding(.bottom, 40)
                }
            }
            .padding(.horizontal, 40)
        }
        .navigationBarHidden(true)
        .onAppear {
            // Start pulsing animation when disconnected (but NOT scanning)
            if !bleManager.isConnected && !bleManager.isScanning {
                withAnimation {
                    isAnimating = true
                }
            }
        }
        .onDisappear {
            isAnimating = false
        }
        .onChange(of: bleManager.isConnected) { newValue in
            print("🔄 BluetoothConnectionView: isConnected changed to \(newValue)")
            
            if newValue {
                // Stop animation when connected
                withAnimation {
                    isAnimating = false
                }
            } else if !bleManager.isScanning {
                // Start pulsing if disconnected and not scanning
                withAnimation {
                    isAnimating = true
                }
            }
        }
        .onChange(of: bleManager.isScanning) { newValue in
            if newValue {
                // Stop pulsing when scanning starts
                withAnimation {
                    isAnimating = false
                }
            } else if !bleManager.isConnected {
                // Start pulsing again if scanning stopped and not connected
                DispatchQueue.main.asyncAfter(deadline: .now() + 0.5) {
                    withAnimation {
                        isAnimating = true
                    }
                }
            }
        }
    }
    
    private func handleTap() {
        // Only start scanning if not already scanning and not connected
        if !bleManager.isScanning && !bleManager.isConnected {
            bleManager.startScan()
        }
    }
    
    // MARK: - Computed Properties
    
    private var iconName: String {
        if bleManager.isConnected {
            return "checkmark.circle.fill"
        } else if bleManager.isScanning {
            return "dot.radiowaves.left.and.right"
        } else {
            return "dot.radiowaves.left.and.right"
        }
    }
    
    private var iconColor: Color {
        if bleManager.isConnected {
            return .green
        } else if bleManager.isScanning {
            return .orange
        } else {
            return .red
        }
    }
    
    private var iconBackgroundColor: Color {
        if bleManager.isConnected {
            return Color.green.opacity(0.1)
        } else if bleManager.isScanning {
            return Color.orange.opacity(0.1)
        } else {
            return Color.red.opacity(0.1)
        }
    }
    
    private var iconShadowColor: Color {
        if bleManager.isConnected {
            return Color.green.opacity(0.3)
        } else if bleManager.isScanning {
            return Color.orange.opacity(0.3)
        } else {
            return Color.red.opacity(0.3)
        }
    }
    
    private var statusText: String {
        if bleManager.isConnected {
            return "Connected"
        } else if bleManager.isScanning {
            return "Searching..."
        } else {
            return "Tap to Connect"
        }
    }
    
    private var subtitleText: String {
        if bleManager.isConnected {
            return "Device is connected and ready"
        } else if bleManager.isScanning {
            return "Make sure XIAO is in CONFIG mode"
        } else {
            return "Tap the Bluetooth icon to search for XIAO"
        }
    }
}
