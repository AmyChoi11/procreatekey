import Foundation
import CoreBluetooth

class BLEManager: NSObject, ObservableObject, CBCentralManagerDelegate, CBPeripheralDelegate {
    @Published var devices: [CBPeripheral] = []
    @Published var isConnected: Bool = false
    @Published var statusMessage: String = ""
    @Published var isScanning: Bool = false
    private var central: CBCentralManager!
    private var targetPeripheral: CBPeripheral?
    private let serviceUUID = CBUUID(string: "12345678-1234-5678-1234-56789abcdef0")
    private let configCharUUID = CBUUID(string: "12345678-1234-5678-1234-56789abcdef1")
    private var configChar: CBCharacteristic?
    private var scanTimer: Timer?

    override init() {
        super.init()
        central = CBCentralManager(delegate: self, queue: nil)
    }

    func startScan() {
        guard central.state == .poweredOn else {
            statusMessage = "Bluetooth not ready. Please enable Bluetooth."
            return
        }
        
        devices.removeAll()
        isScanning = true
        statusMessage = "Scanning for devices..."
        
        // Scan without service filter for better compatibility
        central.scanForPeripherals(withServices: nil, options: [CBCentralManagerScanOptionAllowDuplicatesKey: false])
        
        // Stop scan after 10 seconds
        scanTimer?.invalidate()
        scanTimer = Timer.scheduledTimer(withTimeInterval: 10.0, repeats: false) { [weak self] _ in
            self?.stopScan()
        }
    }
    
    func stopScan() {
        central.stopScan()
        isScanning = false
        scanTimer?.invalidate()
        if devices.isEmpty {
            statusMessage = "No devices found. Make sure ESP32 is powered on."
        } else {
            statusMessage = "Found \(devices.count) device(s). Tap to connect."
        }
    }

    func connect(to peripheral: CBPeripheral) {
        stopScan()
        targetPeripheral = peripheral
        peripheral.delegate = self
        central.connect(peripheral, options: nil)
        statusMessage = "Connecting to \(peripheral.name ?? "device")..."
    }
    
    func disconnect() {
        if let peripheral = targetPeripheral {
            central.cancelPeripheralConnection(peripheral)
        }
        isConnected = false
        statusMessage = "Disconnected"
    }

    func writeConfig(config: [String: Int]) {
        guard let char = configChar, let peripheral = targetPeripheral else { return }
        let json = try? JSONSerialization.data(withJSONObject: ["buttons": config], options: [])
        if let json = json {
            peripheral.writeValue(json, for: char, type: .withResponse)
            statusMessage = "Config sent!"
        }
    }

    // MARK: CBCentralManagerDelegate
    func centralManagerDidUpdateState(_ central: CBCentralManager) {
        switch central.state {
        case .poweredOn:
            statusMessage = "Bluetooth ready"
        case .poweredOff:
            statusMessage = "Please turn on Bluetooth"
        case .unauthorized:
            statusMessage = "Bluetooth permission denied"
        case .unsupported:
            statusMessage = "Bluetooth not supported"
        default:
            statusMessage = "Bluetooth not ready"
        }
    }

    func centralManager(_ central: CBCentralManager, didDiscover peripheral: CBPeripheral, advertisementData: [String : Any], rssi RSSI: NSNumber) {
        // Filter out devices with very weak signal
        guard RSSI.intValue > -90 else { return }
        
        // Only add if not already in list
        if !devices.contains(where: { $0.identifier == peripheral.identifier }) {
            print("📱 Found device: \(peripheral.name ?? "Unknown") - RSSI: \(RSSI)")
            devices.append(peripheral)
            statusMessage = "Found \(devices.count) device(s)..."
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
        if let error = error {
            statusMessage = "Disconnected with error: \(error.localizedDescription)"
        } else {
            statusMessage = "Disconnected"
        }
        print("🔌 Disconnected from: \(peripheral.name ?? "Unknown")")
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
        for service in services {
            print("  - Service: \(service.uuid)")
            if service.uuid == serviceUUID {
                statusMessage = "Found config service! Discovering characteristics..."
                peripheral.discoverCharacteristics(nil, for: service)
            } else {
                // Also try to discover characteristics for other services
                peripheral.discoverCharacteristics(nil, for: service)
            }
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
            if char.uuid == configCharUUID {
                configChar = char
                statusMessage = "✓ Ready to configure!"
                print("✓ Found config characteristic!")
                // Read current config from ESP32
                peripheral.readValue(for: char)
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
    }
}
