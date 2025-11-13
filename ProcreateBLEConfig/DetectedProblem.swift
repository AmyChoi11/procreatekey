import Foundation

enum DetectedProblem: Identifiable {
    case bluetoothOff
    case noPermission
    case noDevicesFound
    case connectionFailed
    case serviceNotFound
    case configNotLoading
    
    var id: String {
        switch self {
        case .bluetoothOff: return "btOff"
        case .noPermission: return "noPermission"
        case .noDevicesFound: return "noDevices"
        case .connectionFailed: return "connFailed"
        case .serviceNotFound: return "noService"
        case .configNotLoading: return "noConfig"
        }
    }
    
    var title: String {
        switch self {
        case .bluetoothOff: return "Bluetooth is Off"
        case .noPermission: return "No Bluetooth Permission"
        case .noDevicesFound: return "Cannot Find Device"
        case .connectionFailed: return "Connection Failed"
        case .serviceNotFound: return "Device Not Ready"
        case .configNotLoading: return "Configuration Not Loading"
        }
    }
    
    var steps: [String] {
        switch self {
        case .bluetoothOff:
            return [
                "Open Settings app",
                "Tap Bluetooth",
                "Toggle switch to ON",
                "Return to this app"
            ]
            
        case .noPermission:
            return [
                "Open Settings app",
                "Tap Privacy & Security",
                "Tap Bluetooth",
                "Find 'eSketch Shortcuts'",
                "Toggle switch to ON",
                "Return to this app"
            ]
            
        case .noDevicesFound:
            return [
                "Turn device off using power button",
                "Wait 10 seconds",
                "Turn device back on",
                "Move iPad within 3 feet of device",
                "Tap scan icon again"
            ]
            
        case .connectionFailed:
            return [
                "Turn device off using power button",
                "Wait 10 seconds",
                "Turn device back on",
                "Wait 5 seconds",
                "Tap scan icon",
                "Try connecting again"
            ]
            
        case .serviceNotFound:
            return [
                "Turn device off using power button",
                "Wait 10 seconds",
                "Turn device back on",
                "Disconnect from this app",
                "Tap scan icon",
                "Connect again"
            ]
            
        case .configNotLoading:
            return [
                "Wait 10 seconds",
                "If still blank, disconnect",
                "Wait 5 seconds",
                "Connect again"
            ]
        }
    }
}