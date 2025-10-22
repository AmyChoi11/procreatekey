import 'dart:async';
import 'dart:convert';
import 'dart:math';

/// ESP32 Simulator for testing Flutter app without hardware
/// This class simulates the ESP32 BLE behavior for development and testing
class ESP32Simulator {
  static final ESP32Simulator _instance = ESP32Simulator._internal();
  factory ESP32Simulator() => _instance;
  ESP32Simulator._internal();

  // Simulated device state
  bool _isAdvertising = false;
  bool _isConnected = false;
  final Map<String, int> _buttonConfig = {
    'button1': 0, // Undo
    'button2': 1, // Redo  
    'button3': 2, // Clear Layer
  };
  
  // Simulation timers
  Timer? _buttonSimulationTimer;
  Timer? _statusUpdateTimer;
  
  // Callbacks for Flutter app
  void Function(List<int>)? onDataReceived;
  Function(bool)? onConnectionChanged;
  
  final List<String> _functionNames = [
    'Undo', 'Redo', 'Clear Layer', 'New Layer', 'Eyedropper',
    'Eraser', 'Brush', 'Smudge', 'Selection', 'Transform', 'None'
  ];

  /// Start advertising (simulate ESP32 being discoverable)
  void startAdvertising() {
    _isAdvertising = true;
    print('🤖 ESP32 Simulator: Started advertising as "Procreate Controller App"');
  }

  /// Stop advertising
  void stopAdvertising() {
    _isAdvertising = false;
    print('🤖 ESP32 Simulator: Stopped advertising');
  }

  /// Check if simulator is advertising
  bool get isAdvertising => _isAdvertising;

  /// Simulate connection from Flutter app
  Future<bool> connect() async {
    if (!_isAdvertising) return false;
    
    print('🤖 ESP32 Simulator: Connection attempt...');
    
    // Simulate connection delay
    await Future.delayed(const Duration(milliseconds: 1500));
    
    _isConnected = true;
    onConnectionChanged?.call(true);
    
    print('🤖 ESP32 Simulator: Connected successfully!');
    
    // Send initial status after connection
    _sendStatusUpdate();
    
    // Start periodic status updates
    _startStatusUpdates();
    
    // Start random button simulation
    _startButtonSimulation();
    
    return true;
  }

  /// Simulate disconnection
  void disconnect() {
    _isConnected = false;
    _stopTimers();
    onConnectionChanged?.call(false);
    print('🤖 ESP32 Simulator: Disconnected');
  }

  /// Check if simulator is connected
  bool get isConnected => _isConnected;

  /// Simulate receiving configuration from Flutter app
  void receiveConfiguration(String jsonData) {
    if (!_isConnected) return;
    
    try {
      Map<String, dynamic> config = jsonDecode(jsonData);
      
      // Update simulated button configuration
      if (config.containsKey('button1')) _buttonConfig['button1'] = config['button1'];
      if (config.containsKey('button2')) _buttonConfig['button2'] = config['button2'];
      if (config.containsKey('button3')) _buttonConfig['button3'] = config['button3'];
      
      print('🤖 ESP32 Simulator: Configuration received');
      print('   Button 1: ${_functionNames[_buttonConfig['button1']!]}');
      print('   Button 2: ${_functionNames[_buttonConfig['button2']!]}');
      print('   Button 3: ${_functionNames[_buttonConfig['button3']!]}');
      
      // Send acknowledgment
      _sendConfigAck();
      
    } catch (e) {
      print('🤖 ESP32 Simulator: JSON parsing error: $e');
    }
  }

  /// Simulate button press manually
  void simulateButtonPress(String buttonName) {
    if (!_isConnected) return;
    
    _sendButtonEvent(buttonName, true);
    
    // Send button release after short delay
    Timer(const Duration(milliseconds: 200), () {
      _sendButtonEvent(buttonName, false);
    });
  }

  /// Simulate encoder rotation
  void simulateEncoderRotation(bool clockwise) {
    if (!_isConnected) return;
    
    Map<String, dynamic> data = {
      'type': 'encoderEvent',
      'pressed': false,
      'rotation': clockwise ? 'cw' : 'ccw',
      'timestamp': DateTime.now().millisecondsSinceEpoch,
    };
    
    onDataReceived?.call(utf8.encode(jsonEncode(data)));
    print('🤖 ESP32 Simulator: Encoder ${clockwise ? "CW" : "CCW"}');
  }

  /// Simulate encoder button press
  void simulateEncoderPress() {
    if (!_isConnected) return;
    
    Map<String, dynamic> pressData = {
      'type': 'encoderEvent',
      'pressed': true,
      'timestamp': DateTime.now().millisecondsSinceEpoch,
    };
    
    onDataReceived?.call(utf8.encode(jsonEncode(pressData)));
    print('🤖 ESP32 Simulator: Encoder button pressed');
    
    // Send release after delay
    Timer(const Duration(milliseconds: 300), () {
      Map<String, dynamic> releaseData = {
        'type': 'encoderEvent',
        'pressed': false,
        'timestamp': DateTime.now().millisecondsSinceEpoch,
      };
      onDataReceived?.call(utf8.encode(jsonEncode(releaseData)));
    });
  }

  /// Start automatic button simulation for testing
  void _startButtonSimulation() {
    _buttonSimulationTimer = Timer.periodic(const Duration(seconds: 8), (timer) {
      if (!_isConnected) return;
      
      // Randomly press one of the buttons
      List<String> buttons = ['button1', 'button2', 'button3'];
      String randomButton = buttons[Random().nextInt(buttons.length)];
      
      print('🤖 ESP32 Simulator: Auto-simulating $randomButton press');
      simulateButtonPress(randomButton);
    });
  }

  /// Start periodic status updates
  void _startStatusUpdates() {
    _statusUpdateTimer = Timer.periodic(const Duration(seconds: 10), (timer) {
      if (_isConnected) {
        _sendStatusUpdate();
      }
    });
  }

  /// Send status update to Flutter app
  void _sendStatusUpdate() {
    Map<String, dynamic> data = {
      'type': 'status',
      'connected': _isConnected,
      'configConnected': _isConnected,
      'button1': _buttonConfig['button1'],
      'button2': _buttonConfig['button2'],
      'button3': _buttonConfig['button3'],
      'button1Name': _functionNames[_buttonConfig['button1']!],
      'button2Name': _functionNames[_buttonConfig['button2']!],
      'button3Name': _functionNames[_buttonConfig['button3']!],
      'encoderPosition': Random().nextInt(100),
    };
    
    onDataReceived?.call(utf8.encode(jsonEncode(data)));
    print('🤖 ESP32 Simulator: Status update sent');
  }

  /// Send button event to Flutter app
  void _sendButtonEvent(String button, bool pressed) {
    Map<String, dynamic> data = {
      'type': 'buttonEvent',
      'button': button,
      'pressed': pressed,
      'timestamp': DateTime.now().millisecondsSinceEpoch,
    };
    
    onDataReceived?.call(utf8.encode(jsonEncode(data)));
    
    if (pressed) {
      String functionName = _functionNames[_buttonConfig[button]!];
      print('🤖 ESP32 Simulator: $button pressed - $functionName');
    }
  }

  /// Send configuration acknowledgment
  void _sendConfigAck() {
    Map<String, dynamic> data = {
      'type': 'configAck',
      'timestamp': DateTime.now().millisecondsSinceEpoch,
      'button1': _buttonConfig['button1'],
      'button2': _buttonConfig['button2'],
      'button3': _buttonConfig['button3'],
    };
    
    onDataReceived?.call(utf8.encode(jsonEncode(data)));
    print('🤖 ESP32 Simulator: Configuration acknowledged');
  }

  /// Stop all timers
  void _stopTimers() {
    _buttonSimulationTimer?.cancel();
    _statusUpdateTimer?.cancel();
  }

  /// Clean up simulator
  void dispose() {
    _stopTimers();
    _isConnected = false;
    _isAdvertising = false;
    onDataReceived = null;
    onConnectionChanged = null;
  }

  /// Get simulator device info (for scan results)
  Map<String, dynamic> getDeviceInfo() {
    return {
      'name': 'Procreate Controller App (Simulator)',
      'id': 'ESP32-SIMULATOR-${Random().nextInt(9999)}',
      'rssi': -45 + Random().nextInt(20), // -45 to -65 dBm
      'isSimulator': true,
    };
  }
}