import Foundation
import CoreBluetooth
import SwiftUI

class BLEManager: NSObject, ObservableObject, CBCentralManagerDelegate, CBPeripheralDelegate {
    @Published var devices: [CBPeripheral] = []
    @Published var isConnected: Bool = false
    @Published var statusMessage: String = ""
    @Published var isScanning: Bool = false
    @Published var bluetoothState: CBManagerState = .unknown
    @Published var currentConfig: [String: Int] = ["button1": 3, "button2": 3, "button3": 3, "combo": 7, "scroll": 9]
    @Published var currentCustom: Int = 0  // 0 = Custom 1, 1 = Custom 2, 2 = Custom 3
    @Published var detectedProblem: DetectedProblem?
    
    private var central: CBCentralManager!
    private var targetPeripheral: CBPeripheral?
    private let serviceUUID = CBUUID(string: "12345678-1234-5678-1234-56789abcdef0")
    private let configCharUUID = CBUUID(string: "12345678-1234-5678-1234-56789abcdef1")
    private var configChar: CBCharacteristic?
    private var scanTimer: Timer?
    private var noDevicesTimer: Timer?
    private var connectionTimeout: Timer?

    override init() {
        super.init()
        central = CBCentralManager(delegate: self, queue: nil)
    }

    func startScan() {
        #if targetEnvironment(simulator)
        statusMessage = "Bluetooth not available in Simulator"
        return
        #endif
        
        guard central.state == .poweredOn else {
            switch central.state {
            case .poweredOff:
                statusMessage = "Bluetooth is off"
                detectedProblem = .bluetoothOff
            case .unauthorized:
                statusMessage = "No Bluetooth permission"
                detectedProblem = .noPermission
            case .unsupported:
                statusMessage = "Bluetooth not supported"
            default:
                statusMessage = "Bluetooth not ready"
            }
            return
        }
        
        devices.removeAll()
        isScanning = true
        statusMessage = "Scanning..."
        detectedProblem = nil
        
        print("🔍 Starting BLE scan")
        
        // CRITICAL: Check for already connected peripherals first
        // This finds devices already paired in iOS Settings (like the keyboard)
        let connectedPeripherals = central.retrieveConnectedPeripherals(withServices: [serviceUUID])
        print("📱 Found \(connectedPeripherals.count) already connected peripheral(s) with config service")
        
        for peripheral in connectedPeripherals {
            let deviceName = peripheral.name ?? "Unknown"
            print("   ✅ Already connected: \(deviceName)")
            if deviceName.hasPrefix("XIAO") && !devices.contains(where: { $0.identifier == peripheral.identifier }) {
                devices.append(peripheral)
                print("   ➕ Added to device list")
            }
        }
        
        // Also scan for new devices
        central.scanForPeripherals(withServices: nil, options: [CBCentralManagerScanOptionAllowDuplicatesKey: false])
        
        scanTimer?.invalidate()
        scanTimer = Timer.scheduledTimer(withTimeInterval: 10.0, repeats: false) { [weak self] _ in
            self?.stopScan()
        }
        
        // Detect if no devices found after 8 seconds
        noDevicesTimer?.invalidate()
        noDevicesTimer = Timer.scheduledTimer(withTimeInterval: 8.0, repeats: false) { [weak self] _ in
            guard let self = self else { return }
            if self.devices.isEmpty && self.isScanning {
                self.detectedProblem = .noDevicesFound
            }
        }
    }
    
    func stopScan() {
        central.stopScan()
        isScanning = false
        scanTimer?.invalidate()
        noDevicesTimer?.invalidate()
        
        print("⏹️ Scan stopped. Found \(devices.count) device(s)")
        
        if devices.isEmpty {
            statusMessage = "No devices found"
        } else {
            statusMessage = "Found \(devices.count) device(s)"
        }
    }

    func connect(to peripheral: CBPeripheral) {
        stopScan()
        targetPeripheral = peripheral
        peripheral.delegate = self
        central.connect(peripheral, options: nil)
        statusMessage = "Connecting..."
        
        connectionTimeout?.invalidate()
        connectionTimeout = Timer.scheduledTimer(withTimeInterval: 15.0, repeats: false) { [weak self] _ in
            guard let self = self else { return }
            if !self.isConnected {
                self.detectedProblem = .connectionFailed
                self.central.cancelPeripheralConnection(peripheral)
            }
        }
    }
    
    func disconnect() {
        if let peripheral = targetPeripheral {
            central.cancelPeripheralConnection(peripheral)
        }
        isConnected = false
        statusMessage = "Disconnected"
    }

    func writeConfig(config: [String: Int]) {
        guard let char = configChar, let peripheral = targetPeripheral else {
            print("❌ Cannot write: characteristic or peripheral not available")
            statusMessage = "⚠️ Not connected to device"
            return
        }
        
        let json = try? JSONSerialization.data(withJSONObject: ["buttons": config], options: [])
        if let json = json {
            let jsonString = String(data: json, encoding: .utf8) ?? "invalid"
            print("\n========================================")
            print("📤 WRITING CONFIG TO ESP32")
            print("========================================")
            print("JSON: \(jsonString)")
            print("Config dict: \(config)")
            print("========================================\n")
            
            peripheral.writeValue(json, for: char, type: .withResponse)
            statusMessage = "Sending config..."
        } else {
            print("❌ Failed to serialize JSON")
            statusMessage = "⚠️ Failed to create config"
        }
    }

    // MARK: CBCentralManagerDelegate
    func centralManagerDidUpdateState(_ central: CBCentralManager) {
        bluetoothState = central.state
        
        #if targetEnvironment(simulator)
        statusMessage = "⚠️ Bluetooth not available in Simulator. Please test on a real device."
        return
        #endif
        
        switch central.state {
        case .poweredOn:
            statusMessage = "Bluetooth ready"
        case .poweredOff:
            statusMessage = "⚠️ Please turn on Bluetooth in Settings"
        case .unauthorized:
            statusMessage = "⚠️ Bluetooth permission denied. Check Settings."
        case .unsupported:
            statusMessage = "⚠️ Bluetooth not supported on this device"
        default:
            statusMessage = "Bluetooth initializing..."
        }
    }

    func centralManager(_ central: CBCentralManager, didDiscover peripheral: CBPeripheral, advertisementData: [String : Any], rssi RSSI: NSNumber) {
        let deviceName = peripheral.name ?? "Unknown"
        let isConnectable = advertisementData[CBAdvertisementDataIsConnectable] as? Bool ?? false
        
        // Debug: Log ALL discovered devices
        print("🔍 Discovered: \(deviceName) - RSSI: \(RSSI.intValue) - Connectable: \(isConnectable)")
        if let localName = advertisementData[CBAdvertisementDataLocalNameKey] as? String {
            print("   Local Name: \(localName)")
        }
        if let serviceUUIDs = advertisementData[CBAdvertisementDataServiceUUIDsKey] as? [CBUUID] {
            print("   Services: \(serviceUUIDs.map { $0.uuidString })")
        } else {
            print("   Services: None advertised (may be paired as keyboard)")
        }
        
        // Filter out devices with very weak signal
        guard RSSI.intValue > -90 else {
            print("   ❌ Rejected: Signal too weak")
            return
        }
        
        // Check if device name starts with "XIAO"
        guard deviceName.hasPrefix("XIAO") else {
            print("   ❌ Rejected: Name doesn't start with 'XIAO'")
            return
        }
        
        // Accept device even if not advertising config service
        // (it might be paired as keyboard but still has config service available)
        if !devices.contains(where: { $0.identifier == peripheral.identifier }) {
            print("   ✅ ACCEPTED: Adding to device list (may be paired as keyboard)")
            devices.append(peripheral)
            statusMessage = "Found \(devices.count) device(s)..."
        } else {
            print("   ℹ️ Already in list")
        }
    }

    func centralManager(_ central: CBCentralManager, didConnect peripheral: CBPeripheral) {
        isConnected = true
        statusMessage = "✓ Connected! Discovering services..."
        print("✓ Connected to: \(peripheral.name ?? "Unknown")")
        peripheral.discoverServices(nil) // Discover all services
    }
    
    func centralManager(_ central: CBCentralManager, didFailToConnect peripheral: CBPeripheral, error: Error?) {
        isConnected = false
        statusMessage = "Connection failed: \(error?.localizedDescription ?? "Unknown error")"
        print("❌ Connection failed: \(error?.localizedDescription ?? "Unknown")")
    }
    
    func centralManager(_ central: CBCentralManager, didDisconnectPeripheral peripheral: CBPeripheral, error: Error?) {
        isConnected = false
        configChar = nil  // Clear the characteristic
        if let error = error {
            let errorMessage = error.localizedDescription
            print("🔌 Disconnected with error: \(errorMessage)")
            
            // Check if it's a timeout (common when device restarts)
            if errorMessage.contains("timed out") || errorMessage.contains("time out") {
                statusMessage = "Disconnected (device may have restarted)"
                print("💡 This is normal if device is restarting into CONFIG mode")
            } else {
                statusMessage = "Disconnected: \(errorMessage)"
            }
        } else {
            statusMessage = "Disconnected"
            print("🔌 Disconnected from: \(peripheral.name ?? "Unknown")")
        }
    }

    // MARK: CBPeripheralDelegate
    func peripheral(_ peripheral: CBPeripheral, didDiscoverServices error: Error?) {
        if let error = error {
            statusMessage = "Service discovery failed: \(error.localizedDescription)"
            print("❌ Service discovery error: \(error)")
            return
        }
        
        guard let services = peripheral.services else {
            statusMessage = "No services found"
            return
        }
        
        print("🔍 Found \(services.count) services:")
        var foundConfigService = false
        for service in services {
            let serviceUUIDString = service.uuid.uuidString
            print("  - Service UUID: \(serviceUUIDString)")
            
            // Compare UUIDs (case-insensitive)
            if serviceUUIDString.uppercased() == serviceUUID.uuidString.uppercased() {
                print("  ✓✓✓ FOUND OUR CONFIG SERVICE! ✓✓✓")
                foundConfigService = true
                statusMessage = "Found config service! Discovering characteristics..."
                peripheral.discoverCharacteristics(nil, for: service)
            } else {
                // Also discover characteristics for debugging
                peripheral.discoverCharacteristics(nil, for: service)
            }
        }
        
        // Check if our service was NOT found
        if !foundConfigService {
            statusMessage = "⚠️ Device is in KEYBOARD mode. Hold RESET button 5 seconds to enter CONFIG mode."
            print("❌ Config service NOT found!")
            print("   Expected: \(serviceUUID.uuidString)")
            print("   💡 Device must be in CONFIG MODE to configure")
        }
    }

    func peripheral(_ peripheral: CBPeripheral, didDiscoverCharacteristicsFor service: CBService, error: Error?) {
        if let error = error {
            statusMessage = "Characteristic discovery failed: \(error.localizedDescription)"
            print("❌ Characteristic discovery error: \(error)")
            return
        }
        
        guard let chars = service.characteristics else { return }
        
        print("🔍 Service \(service.uuid) has \(chars.count) characteristics:")
        for char in chars {
            print("  - Characteristic: \(char.uuid)")
            print("    Properties: \(char.properties)")
            if char.uuid == configCharUUID {
                configChar = char
                statusMessage = "✓ Ready to configure!"
                print("✓ Found config characteristic!")
                // Wait a moment before reading to ensure device is ready
                DispatchQueue.main.asyncAfter(deadline: .now() + 0.5) {
                    print("📖 Reading current config from ESP32...")
                    peripheral.readValue(for: char)
                }
            }
        }
    }
    
    func peripheral(_ peripheral: CBPeripheral, didUpdateValueFor characteristic: CBCharacteristic, error: Error?) {
        if let error = error {
            print("❌ Read error: \(error)")
            statusMessage = "Failed to read config"
            return
        }
        
        if characteristic.uuid == configCharUUID, let data = characteristic.value {
            print("📥 Received config data: \(String(data: data, encoding: .utf8) ?? "invalid")")
            do {
                if let json = try JSONSerialization.jsonObject(with: data, options: []) as? [String: Any],
                   let buttons = json["buttons"] as? [String: Int] {
                    DispatchQueue.main.async {
                        self.currentConfig = buttons
                        // Extract currentCustom if provided (0 = Custom 1, 1 = Custom 2, 2 = Custom 3)
                        if let custom = json["currentCustom"] as? Int {
                            self.currentCustom = custom
                            print("✓ Current custom preset: \(custom + 1)")
                        }
                        self.statusMessage = "✓ Config loaded from device!"
                        print("✓ Parsed config: \(buttons)")
                    }
                } else {
                    statusMessage = "Invalid config format"
                    print("❌ Invalid JSON structure")
                }
            } catch {
                print("❌ JSON parse error: \(error)")
                statusMessage = "Failed to parse config"
            }
        }
    }
    
    func peripheral(_ peripheral: CBPeripheral, didWriteValueFor characteristic: CBCharacteristic, error: Error?) {
        if let error = error {
            statusMessage = "❌ Write failed: \(error.localizedDescription)"
            print("❌ Write error: \(error)")
        } else {
            statusMessage = "✓ Config saved successfully!"
            print("✓ Config written to device")
        }
    }
    
    deinit {
        scanTimer?.invalidate()
        noDevicesTimer?.invalidate()
        connectionTimeout?.invalidate()
    }
}
