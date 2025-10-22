import Foundation
import CoreBluetooth

class BLEManager: NSObject, ObservableObject, CBCentralManagerDelegate, CBPeripheralDelegate {
    @Published var devices: [CBPeripheral] = []
    @Published var isConnected: Bool = false
    @Published var statusMessage: String = ""
    @Published var currentConfig: [String: Int] = ["button1": 4, "button2": 1, "button3": 3]
    private var central: CBCentralManager!
    private var targetPeripheral: CBPeripheral?
    private let serviceUUID = CBUUID(string: "12345678-1234-5678-1234-56789abcdef0")
    private let configCharUUID = CBUUID(string: "12345678-1234-5678-1234-56789abcdef1")
    private var configChar: CBCharacteristic?

    override init() {
        super.init()
        central = CBCentralManager(delegate: self, queue: nil)
    }

    func startScan() {
        devices.removeAll()
        statusMessage = "Scanning..."
        central.scanForPeripherals(withServices: [serviceUUID], options: nil)
    }

    func connect(to peripheral: CBPeripheral) {
        central.stopScan()
        targetPeripheral = peripheral
        peripheral.delegate = self
        central.connect(peripheral, options: nil)
        statusMessage = "Connecting..."
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
        if central.state != .poweredOn {
            statusMessage = "Bluetooth not available"
        }
    }

    func centralManager(_ central: CBCentralManager, didDiscover peripheral: CBPeripheral, advertisementData: [String : Any], rssi RSSI: NSNumber) {
        if !devices.contains(peripheral) {
            devices.append(peripheral)
        }
    }

    func centralManager(_ central: CBCentralManager, didConnect peripheral: CBPeripheral) {
        isConnected = true
        statusMessage = "Connected! Discovering services..."
        peripheral.discoverServices([serviceUUID])
    }

    // MARK: CBPeripheralDelegate
    func peripheral(_ peripheral: CBPeripheral, didDiscoverServices error: Error?) {
        guard let services = peripheral.services else { return }
        for service in services {
            if service.uuid == serviceUUID {
                peripheral.discoverCharacteristics([configCharUUID], for: service)
            }
        }
    }

    func peripheral(_ peripheral: CBPeripheral, didDiscoverCharacteristicsFor service: CBService, error: Error?) {
        guard let chars = service.characteristics else { return }
        for char in chars {
            if char.uuid == configCharUUID {
                configChar = char
                statusMessage = "Ready to configure!"
                // Read current config from ESP32
                peripheral.readValue(for: char)
            }
        }
    }
    
    func peripheral(_ peripheral: CBPeripheral, didUpdateValueFor characteristic: CBCharacteristic, error: Error?) {
        if characteristic.uuid == configCharUUID, let data = characteristic.value {
            do {
                if let json = try JSONSerialization.jsonObject(with: data, options: []) as? [String: Any],
                   let buttons = json["buttons"] as? [String: Int] {
                    DispatchQueue.main.async {
                        self.currentConfig = buttons
                        self.statusMessage = "Config loaded from device!"
                    }
                }
            } catch {
                print("Failed to parse config: \(error)")
            }
        }
    }
    
    func peripheral(_ peripheral: CBPeripheral, didWriteValueFor characteristic: CBCharacteristic, error: Error?) {
        if error != nil {
            statusMessage = "Write failed!"
        } else {
            statusMessage = "Config saved successfully!"
        }
    }
}
