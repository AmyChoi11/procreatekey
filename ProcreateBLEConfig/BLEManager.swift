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
    @Published var isConnectionStable: Bool = false
    @Published var isInitializing = true
    
    private var central: CBCentralManager!
    private var targetPeripheral: CBPeripheral?
    private let serviceUUID = CBUUID(string: "12345678-1234-5678-1234-56789abcdef0")
    private let configCharUUID = CBUUID(string: "12345678-1234-5678-1234-56789abcdef1")
    private let hidServiceUUID = CBUUID(string: "1812") // Standard HID Service UUID
    private var configChar: CBCharacteristic?
    private var scanTimer: Timer?
    private var noDevicesTimer: Timer?
    private var connectionTimeout: Timer?
    private var serviceDiscoveryRetryCount = 0
    private let maxServiceDiscoveryRetries = 3
    private var configPollTimer: Timer?  // Auto-poll config to detect hardware switch changes
    private var connectionCheckTimer: Timer?  // Periodic connection verification
    
    // App lifecycle state
    private var isAppActive = true
    private var shouldReconnectOnActive = false
    
    // Computed property to expose connected peripheral for UI
    var connectedPeripheral: CBPeripheral? {
        return isConnected ? targetPeripheral : nil
    }

    override init() {
        super.init()
        central = CBCentralManager(delegate: self, queue: nil)
        updateStatusMessage("Initializing Bluetooth...")
    }
    
    deinit {
        stopAllTimers()
    }
    
    // MARK: - Lifecycle Management
    
    func pauseBLEOperations() {
        print("⏸️ Pausing BLE operations")
        stopAllTimers()
        
        if isScanning {
            stopScan()
        }
    }
    
    func resumeBLEOperations() {
        print("▶️ Resuming BLE operations")
        
        guard isAppActive else {
            print("⚠️ App not active, not resuming")
            return
        }
        
        if isConnected {
            print("✅ Starting timers for connected device")
            startConfigPolling()
            startConnectionCheckTimer()
            
            // Read current state
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.5) { [weak self] in
                self?.pollCurrentConfig()
            }
        }
    }
    
    private func stopAllTimers() {
        scanTimer?.invalidate()
        scanTimer = nil
        noDevicesTimer?.invalidate()
        noDevicesTimer = nil
        connectionTimeout?.invalidate()
        connectionTimeout = nil
        stopConfigPolling()
        stopConnectionCheckTimer()
    }
    
    private func updateStatusMessage(_ message: String) {
        DispatchQueue.main.async {
            self.statusMessage = message
            print("📢 Status: \(message)")
        }
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
            if deviceName.hasPrefix("CliQ") && !devices.contains(where: { $0.identifier == peripheral.identifier }) {
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
        serviceDiscoveryRetryCount = 0  // Reset retry counter for new connection
        
        // Check if already connected (e.g., paired as keyboard)
        if peripheral.state == .connected {
            print("✅ Peripheral already connected - discovering services directly")
            statusMessage = "Already connected! Discovering services..."
            
            // Peripheral is already connected, just discover services
            peripheral.discoverServices(nil)
            
            DispatchQueue.main.async {
                self.isConnected = true
                self.isConnectionStable = true
            }
            
            // Start timers
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.5) {
                self.startConfigPolling()
                self.startConnectionCheckTimer()
            }
        } else {
            print("🔌 Connecting to peripheral...")
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
    }
    
    func disconnect() {
        if let peripheral = targetPeripheral {
            central.cancelPeripheralConnection(peripheral)
        }
        cleanupConnection()
        updateStatusMessage("Disconnected from CliQ Controller")
    }
    
    private func cleanupConnection() {
        DispatchQueue.main.async {
            self.isConnected = false
            self.isConnectionStable = false
        }
        targetPeripheral = nil
        configChar = nil
        stopAllTimers()
    }
    
    func verifyConnection() {
        guard let peripheral = targetPeripheral else {
            DispatchQueue.main.async {
                self.isConnected = false
                self.isConnectionStable = false
            }
            return
        }
        
        print("🔍 Verifying connection - Peripheral state: \(peripheral.state.rawValue)")
        
        switch peripheral.state {
        case .connected:
            DispatchQueue.main.async {
                self.isConnected = true
                self.isConnectionStable = true
            }
            print("✅ Peripheral is connected")
            
        case .connecting:
            print("⏳ Peripheral is connecting...")
            
        case .disconnected:
            print("⚠️ Peripheral is disconnected")
            DispatchQueue.main.async {
                self.isConnected = false
                self.isConnectionStable = false
            }
            
            if self.isConnected {
                updateStatusMessage("Disconnected from CliQ Controller")
                cleanupConnection()
            }
            
        case .disconnecting:
            print("⏳ Peripheral is disconnecting...")
            DispatchQueue.main.async {
                self.isConnected = false
                self.isConnectionStable = false
            }
            
        @unknown default:
            print("❓ Unknown peripheral state: \(peripheral.state.rawValue)")
        }
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
    
    func writeConfigToCustom(config: [String: Int], targetCustom: Int) {
        guard let char = configChar, let peripheral = targetPeripheral else {
            print("❌ Cannot write: characteristic or peripheral not available")
            statusMessage = "⚠️ Not connected to device"
            return
        }
        
        // Include targetCustom in the JSON so ESP32 knows which slot to save to
        let payload: [String: Any] = [
            "buttons": config,
            "targetCustom": targetCustom
        ]
        
        let json = try? JSONSerialization.data(withJSONObject: payload, options: [])
        if let json = json {
            let jsonString = String(data: json, encoding: .utf8) ?? "invalid"
            print("\n========================================")
            print("📤 WRITING CONFIG TO ESP32 CUSTOM \(targetCustom + 1)")
            print("========================================")
            print("JSON: \(jsonString)")
            print("Config dict: \(config)")
            print("Target Custom: \(targetCustom) (0=Custom1, 1=Custom2, 2=Custom3)")
            print("========================================\n")
            
            peripheral.writeValue(json, for: char, type: .withResponse)
            statusMessage = "Saving to Custom \(targetCustom + 1)..."
        } else {
            print("❌ Failed to serialize JSON")
            statusMessage = "⚠️ Failed to create config"
        }
    }

    // MARK: - CBCentralManagerDelegate
    func centralManagerDidUpdateState(_ central: CBCentralManager) {
        bluetoothState = central.state
        isInitializing = false
        
        #if targetEnvironment(simulator)
        statusMessage = "⚠️ Bluetooth not available in Simulator. Please test on a real device."
        return
        #endif
        
        switch central.state {
        case .poweredOn:
            print("✅ Bluetooth is powered on")
            updateStatusMessage("Bluetooth ready")
            
        case .poweredOff:
            print("❌ Bluetooth is powered off")
            cleanupConnection()
            updateStatusMessage("⚠️ Please turn on Bluetooth in Settings")
            detectedProblem = .bluetoothOff
            
        case .resetting:
            print("🔄 Bluetooth is resetting")
            cleanupConnection()
            updateStatusMessage("Bluetooth resetting...")
            
        case .unauthorized:
            print("❌ Bluetooth is unauthorized")
            cleanupConnection()
            updateStatusMessage("⚠️ Bluetooth permission denied. Check Settings.")
            detectedProblem = .noPermission
            
        case .unsupported:
            print("❌ Bluetooth is unsupported")
            cleanupConnection()
            updateStatusMessage("⚠️ Bluetooth not supported on this device")
            
        case .unknown:
            print("❓ Bluetooth state unknown")
            cleanupConnection()
            updateStatusMessage("Bluetooth initializing...")
            
        @unknown default:
            print("❓ Unknown Bluetooth state")
            cleanupConnection()
            updateStatusMessage("Bluetooth status unknown")
        }
    }

    func centralManager(_ central: CBCentralManager, didDiscover peripheral: CBPeripheral, advertisementData: [String : Any], rssi RSSI: NSNumber) {
        let deviceName = peripheral.name ?? "Unknown"
        let isConnectable = advertisementData[CBAdvertisementDataIsConnectable] as? Bool ?? false
        
        // FULL DEBUG: Log EVERYTHING
        print("🔍 FULL DISCOVERY INFO:")
        print("   Peripheral name: \(peripheral.name ?? "nil")")
        print("   RSSI: \(RSSI.intValue)")
        print("   Connectable: \(isConnectable)")
        print("   Advertisement data keys:")
        
        // Print all advertisement data
        for (key, value) in advertisementData {
            print("      \(key): \(value)")
        }
        
        // Check local name specifically
        var nameToCheck = deviceName
        if let localName = advertisementData[CBAdvertisementDataLocalNameKey] as? String {
            print("   ✅ Local Name in adv data: '\(localName)'")
            nameToCheck = localName
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
        
        // Check if device name is "CliQ Controller" or contains "CliQ"
        let isCliQDevice = nameToCheck == "CliQ Controller" || nameToCheck.contains("CliQ")
        
        guard isCliQDevice else {
            print("   ❌ Rejected: Name '\(nameToCheck)' doesn't match 'CliQ Controller' or contain 'CliQ'")
            return
        }
        
        print("   🎯 FOUND OUR DEVICE: \(nameToCheck)")
        
        // Accept device even if not advertising config service
        // (it might be paired as keyboard but still has config service available)
        if !devices.contains(where: { $0.identifier == peripheral.identifier }) {
            print("   ✅ ACCEPTED: Adding to device list")
            devices.append(peripheral)
            statusMessage = "Found \(devices.count) device(s)..."
        } else {
            print("   ℹ️ Already in list")
        }
    }

    func centralManager(_ central: CBCentralManager, didConnect peripheral: CBPeripheral) {
        print("✅ Connected to \(peripheral.name ?? "unknown device")")
        
        DispatchQueue.main.async {
            self.isConnected = true
            self.isConnectionStable = true
            self.updateStatusMessage("✓ Connected! Discovering services...")
        }
        
        targetPeripheral = peripheral
        peripheral.delegate = self
        
        peripheral.discoverServices(nil) // Discover all services
        
        // Start timers after connection established
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.5) {
            self.startConfigPolling()
            self.startConnectionCheckTimer()
        }
    }
    
    func centralManager(_ central: CBCentralManager, didFailToConnect peripheral: CBPeripheral, error: Error?) {
        isConnected = false
        statusMessage = "Connection failed: \(error?.localizedDescription ?? "Unknown error")"
        print("❌ Connection failed: \(error?.localizedDescription ?? "Unknown")")
    }
    
    func centralManager(_ central: CBCentralManager, didDisconnectPeripheral peripheral: CBPeripheral, error: Error?) {
        print("❌ Disconnected from \(peripheral.name ?? "unknown device")")
        
        cleanupConnection()
        
        if let error = error {
            let errorMessage = error.localizedDescription
            print("🔌 Disconnected with error: \(errorMessage)")
            
            // Check if it's a timeout (common when device restarts)
            if errorMessage.contains("timed out") || errorMessage.contains("time out") {
                updateStatusMessage("Disconnected (device may have restarted)")
                print("💡 This is normal if device is restarting into CONFIG mode")
            } else {
                updateStatusMessage("Disconnected: \(errorMessage)")
            }
        } else {
            updateStatusMessage("Disconnected")
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
            print("⚠️ No services found - trying to discover specific service...")
            
            if serviceDiscoveryRetryCount < maxServiceDiscoveryRetries {
                serviceDiscoveryRetryCount += 1
                // Sometimes iOS doesn't return services immediately for paired devices
                // Try discovering the specific service UUID
                DispatchQueue.main.asyncAfter(deadline: .now() + 1.0) {
                    print("🔄 Retrying service discovery (\(self.serviceDiscoveryRetryCount)/\(self.maxServiceDiscoveryRetries))...")
                    peripheral.discoverServices([self.serviceUUID])
                }
            } else {
                print("❌ Max retries reached - no services found")
                statusMessage = "⚠️ Could not find services. Try disconnecting and reconnecting."
                serviceDiscoveryRetryCount = 0
            }
            return
        }
        
        // Reset retry counter on successful service discovery
        serviceDiscoveryRetryCount = 0
        
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
    func peripheral(_ peripheral: CBPeripheral, didReadRSSI RSSI: NSNumber, error: Error?) {
        if let error = error {
            print("❌ Error reading RSSI: \(error.localizedDescription)")
            isConnectionStable = false
        } else {
            let rssiValue = RSSI.intValue
            print("📶 RSSI: \(rssiValue) dBm")
            
            isConnectionStable = rssiValue > -80
            
            if !isConnectionStable && rssiValue < -90 {
                updateStatusMessage("⚠️ Weak connection to CliQ Controller")
            }
        }
    }
    
    // MARK: - Config Polling
    private func startConfigPolling() {
        // Stop any existing timer
        stopConfigPolling()
        
        // Poll config every 0.5 seconds to detect hardware switch changes instantly
        configPollTimer = Timer.scheduledTimer(withTimeInterval: 0.5, repeats: true) { [weak self] _ in
            guard let self = self, self.isConnected, self.isAppActive else {
                print("⏸️ Config polling paused")
                return
            }
            self.pollCurrentConfig()
        }
        print("🔄 Started config polling (every 0.5 seconds)")
    }
    
    private func stopConfigPolling() {
        configPollTimer?.invalidate()
        configPollTimer = nil
        print("⏹️ Stopped config polling")
    }
    
    private func pollCurrentConfig() {
        guard let char = configChar, let peripheral = targetPeripheral else { return }
        peripheral.readValue(for: char)
    }
    
    private func startConnectionCheckTimer() {
        stopConnectionCheckTimer()
        
        connectionCheckTimer = Timer.scheduledTimer(withTimeInterval: 5.0, repeats: true) { [weak self] _ in
            guard let self = self, self.isConnected, self.isAppActive else {
                print("⏸️ Connection check timer paused")
                return
            }
            self.verifyConnection()
        }
    }
    
    private func stopConnectionCheckTimer() {
        connectionCheckTimer?.invalidate()
        connectionCheckTimer = nil
    }
}
