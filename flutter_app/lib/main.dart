import 'package:flutter/material.dart';
import 'package:flutter_blue_plus/flutter_blue_plus.dart';
import 'package:permission_handler/permission_handler.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'dart:convert';
import 'dart:async';
import 'dart:io';
import 'package:flutter/foundation.dart';
import 'esp32_simulator.dart';

void main() {
  runApp(const MainApp());
}

class MainApp extends StatelessWidget {
  const MainApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'eSketch Controller',
      theme: ThemeData(
        colorScheme: ColorScheme.fromSeed(seedColor: Colors.deepPurple),
        useMaterial3: true,
      ),
      home: const MyHomePage(),
      debugShowCheckedModeBanner: false,
    );
  }
}

class MyHomePage extends StatefulWidget {
  const MyHomePage({super.key});

  @override
  State<MyHomePage> createState() => _MyHomePageState();
}

class _MyHomePageState extends State<MyHomePage> {
  String _selectedOption = '';
  
  // Simulator mode toggle
  bool _simulatorMode = false;
  ESP32Simulator? _simulator;
  
  // Bluetooth variables
  BluetoothDevice? _connectedDevice;
  BluetoothCharacteristic? _configCharacteristic;
  StreamSubscription<List<ScanResult>>? _scanSubscription;
  StreamSubscription<BluetoothConnectionState>? _connectionSubscription;
  StreamSubscription<List<int>>? _characteristicSubscription;
  bool _isScanning = false;
  bool _isConnected = false;
  List<ScanResult> _scanResults = [];
  String _connectionStatus = 'Disconnected';
  
  // Button configurations
  Map<String, int> _buttonConfig = {
    'button1': 0, // Undo
    'button2': 1, // Redo
    'button3': 2, // Clear Layer
  };
  
  // Encoder configuration
  Map<String, int> _encoderConfig = {
    'function': 0, // Brush Size
    'press': 0,    // Reset to Default
    'sensitivity': 1, // Normal
  };
  
  // Function names
  final List<String> _functionNames = [
    'Undo', 'Redo', 'Clear Layer', 'New Layer', 'Eyedropper',
    'Eraser', 'Brush', 'Smudge', 'Selection', 'Transform', 'None'
  ];
  
  // Encoder function names
  final List<String> _encoderFunctionNames = [
    'Brush Size', 'Brush Opacity', 'Layer Selection', 'Zoom Level',
    'Canvas Rotation', 'Color Picker Hue', 'Undo/Redo History', 'Tool Selection'
  ];
  
  final List<String> _encoderPressNames = [
    'Reset to Default', 'Toggle Function', 'Quick Select', 'Lock/Unlock',
    'Confirm Selection', 'Cancel Action', 'Open Context Menu'
  ];
  
  final List<String> _encoderSensitivityNames = [
    'Low (Fine Control)', 'Normal', 'High (Fast Control)'
  ];

  @override
  void initState() {
    super.initState();
    _initializeBluetooth();
    _loadSettings();
    _initializeSimulator();
  }

  @override
  void dispose() {
    _scanSubscription?.cancel();
    _connectionSubscription?.cancel();
    _characteristicSubscription?.cancel();
    _disconnect();
    _simulator?.dispose();
    super.dispose();
  }

  Future<void> _initializeBluetooth() async {
    // Check if Bluetooth is supported
    if (await FlutterBluePlus.isSupported == false) {
      print("Bluetooth not supported by this device");
      return;
    }

    // Request permissions (skip on web)
    if (!kIsWeb && Platform.isAndroid) {
      await _requestPermissions();
    }

    // Listen to Bluetooth state changes
    FlutterBluePlus.adapterState.listen((BluetoothAdapterState state) {
      setState(() {
        if (state == BluetoothAdapterState.on) {
          _connectionStatus = 'Bluetooth Ready';
        } else {
          _connectionStatus = 'Bluetooth Off';
          _isConnected = false;
          _connectedDevice = null;
        }
      });
    });
  }

  Future<void> _requestPermissions() async {
    Map<Permission, PermissionStatus> permissions = await [
      Permission.bluetoothScan,
      Permission.bluetoothConnect,
      Permission.bluetoothAdvertise,
      Permission.location,
      Permission.locationWhenInUse,
    ].request();

    // Check individual permissions and provide feedback
    for (var entry in permissions.entries) {
      if (entry.value.isGranted) {
        print("✓ ${entry.key} permission granted");
      } else if (entry.value.isDenied) {
        print("✗ ${entry.key} permission denied");
      } else if (entry.value.isPermanentlyDenied) {
        print("✗ ${entry.key} permission permanently denied - open app settings");
      }
    }

    bool allGranted = permissions.values.every((status) => status.isGranted);
    if (!allGranted) {
      setState(() {
        _connectionStatus = 'Bluetooth permissions required - check settings';
      });
      print("Some permissions were denied - Bluetooth functionality may be limited");
    } else {
      setState(() {
        _connectionStatus = 'Bluetooth permissions granted';
      });
    }
  }

  Future<void> _loadSettings() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      String? configString = prefs.getString('button_config');
      if (configString != null) {
        Map<String, dynamic> config = jsonDecode(configString);
        setState(() {
          _buttonConfig = {
            'button1': config['button1'] ?? 0,
            'button2': config['button2'] ?? 1,
            'button3': config['button3'] ?? 2,
          };
        });
      }
      
      // Load encoder configuration
      String? encoderConfigString = prefs.getString('encoder_config');
      if (encoderConfigString != null) {
        Map<String, dynamic> encoderConfig = jsonDecode(encoderConfigString);
        setState(() {
          _encoderConfig = {
            'function': encoderConfig['function'] ?? 0,
            'press': encoderConfig['press'] ?? 0,
            'sensitivity': encoderConfig['sensitivity'] ?? 1,
          };
        });
      }
      
      // Load simulator mode preference
      bool simulatorMode = prefs.getBool('simulator_mode') ?? false;
      setState(() {
        _simulatorMode = simulatorMode;
        if (_simulatorMode) {
          _connectionStatus = 'Simulator Mode Enabled';
          _simulator?.startAdvertising();
        }
        // Ensure UI updates with loaded configuration
      });
    } catch (e) {
      print('Error loading settings: $e');
    }
  }

  Future<void> _saveSettings() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      String configString = jsonEncode(_buttonConfig);
      await prefs.setString('button_config', configString);
      
      // Save encoder configuration
      String encoderConfigString = jsonEncode(_encoderConfig);
      await prefs.setString('encoder_config', encoderConfigString);
      
      await prefs.setBool('simulator_mode', _simulatorMode);
    } catch (e) {
      print('Error saving settings: $e');
    }
  }

  void _initializeSimulator() {
    _simulator = ESP32Simulator();
    _simulator!.onDataReceived = _handleIncomingData;
    _simulator!.onConnectionChanged = (connected) {
      setState(() {
        _isConnected = connected;
        _connectionStatus = connected ? 'Connected to Simulator' : 'Disconnected from Simulator';
      });
    };
  }

  void _toggleSimulatorMode() {
    setState(() {
      _simulatorMode = !_simulatorMode;
      if (_simulatorMode) {
        _connectionStatus = 'Simulator Mode Enabled';
        _simulator?.startAdvertising();
      } else {
        _connectionStatus = 'Simulator Mode Disabled';
        _simulator?.stopAdvertising();
        if (_isConnected) _simulator?.disconnect();
      }
    });
    _saveSettings();
  }

  void _connectToSimulator() {
    if (!_simulatorMode) return;
    
    setState(() {
      _connectionStatus = 'Connecting to simulator...';
    });
    
    _simulator?.connect().then((success) {
      if (success) {
        setState(() {
          _connectionStatus = 'Connected to ESP32 Simulator';
          _isConnected = true;
        });
      } else {
        setState(() {
          _connectionStatus = 'Simulator connection failed';
        });
      }
    });
  }

  void _debugScanAllDevices() async {
    if (_isScanning) return;
    
    setState(() {
      _isScanning = true;
      _connectionStatus = 'Debug scanning all devices...';
    });

    try {
      await FlutterBluePlus.startScan(timeout: const Duration(seconds: 15));

      _scanSubscription = FlutterBluePlus.scanResults.listen((results) {
        print('\n=== DEBUG SCAN RESULTS ===');
        for (var result in results) {
          print('Device Name: "${result.device.name}"');
          print('Device ID: ${result.device.id}');
          print('RSSI: ${result.rssi}');
          print('Connectable: ${result.advertisementData.connectable}');
          print('Service UUIDs: ${result.advertisementData.serviceUuids}');
          print('Manufacturer Data: ${result.advertisementData.manufacturerData}');
          print('---');
        }
        print('=========================\n');
        
        setState(() {
          // Show ALL devices for debugging
          _scanResults = results.toList();
        });
      });

      await Future.delayed(const Duration(seconds: 15));
      await FlutterBluePlus.stopScan();
      
      setState(() {
        _isScanning = false;
        _connectionStatus = 'Debug scan complete - check console for details';
      });
    } catch (e) {
      setState(() {
        _isScanning = false;
        _connectionStatus = 'Debug scan error: $e';
      });
    }
  }

  void _startScan() async {
    if (_isScanning) return;
    
    setState(() {
      _isScanning = true;
      _scanResults.clear();
      _connectionStatus = _simulatorMode ? 'Scanning (Simulator Mode)...' : 'Scanning...';
    });

    try {
      if (_simulatorMode) {
        // Simulate scan with simulator device
        await Future.delayed(const Duration(seconds: 2));
        
        // Add simulator device to scan results
        if (_simulator?.isAdvertising == true) {
          setState(() {
            _scanResults = []; // Clear real devices in simulator mode
            _connectionStatus = 'Found ESP32 Simulator';
          });
        } else {
          setState(() {
            _connectionStatus = 'No simulator devices found';
          });
        }
      } else {
        // Real Bluetooth scan
        await FlutterBluePlus.startScan(
          timeout: const Duration(seconds: 10),
          // Remove name filter to discover all devices, then filter by name
        );

        _scanSubscription = FlutterBluePlus.scanResults.listen((results) {
          setState(() {
            _scanResults = results
                .where((result) => 
                  result.device.name.isNotEmpty && 
                  (result.device.name.contains('Procreate') || 
                   result.device.name.contains('Controller') ||
                   result.device.name == 'Procreate Controller App'))
                .toList();
            
            // Debug: Print all discovered devices
            print('Discovered devices:');
            for (var result in results) {
              print('Name: ${result.device.name}, ID: ${result.device.id}, RSSI: ${result.rssi}');
            }
          });
        });

        await Future.delayed(const Duration(seconds: 10));
        await FlutterBluePlus.stopScan();
        
        setState(() {
          if (_scanResults.isEmpty) {
            _connectionStatus = 'No ESP32 devices found - check device is powered on and advertising';
          } else {
            _connectionStatus = 'Found ${_scanResults.length} ESP32 device(s)';
          }
        });
        
        print("Scan completed. Total devices found: ${_scanResults.length}");
      }
      
      setState(() {
        _isScanning = false;
      });
    } catch (e) {
      setState(() {
        _isScanning = false;
        _connectionStatus = 'Scan error: $e';
      });
    }
  }

  void _connect(BluetoothDevice device) async {
    setState(() {
      _connectionStatus = 'Connecting...';
    });

    try {
      await device.connect(timeout: const Duration(seconds: 10));
      
      _connectionSubscription = device.connectionState.listen((state) {
        setState(() {
          _isConnected = (state == BluetoothConnectionState.connected);
          if (_isConnected) {
            _connectedDevice = device;
            _connectionStatus = 'Connected to ${device.name}';
          } else {
            _connectedDevice = null;
            _connectionStatus = 'Disconnected';
          }
        });
      });

      if (_isConnected) {
        await _discoverServices(device);
      }
    } catch (e) {
      setState(() {
        _connectionStatus = 'Connection failed: $e';
      });
    }
  }

  Future<void> _discoverServices(BluetoothDevice device) async {
    try {
      List<BluetoothService> services = await device.discoverServices();
      
      for (BluetoothService service in services) {
        if (service.uuid.toString().toLowerCase() == "12345678-1234-5678-9abc-123456789abc") {
          for (BluetoothCharacteristic characteristic in service.characteristics) {
            if (characteristic.uuid.toString().toLowerCase() == "87654321-4321-8765-cba9-987654321abc") {
              _configCharacteristic = characteristic;
              
              // Subscribe to notifications
              await characteristic.setNotifyValue(true);
              _characteristicSubscription = characteristic.lastValueStream.listen((value) {
                _handleIncomingData(value);
              });
              
              // Send initial configuration
              await _sendConfiguration();
              
              setState(() {
                _connectionStatus = 'Ready - Services discovered';
              });
              return;
            }
          }
        }
      }
      
      setState(() {
        _connectionStatus = 'Configuration service not found';
      });
    } catch (e) {
      setState(() {
        _connectionStatus = 'Service discovery failed: $e';
      });
    }
  }

  void _handleIncomingData(List<int> value) {
    try {
      String dataString = utf8.decode(value);
      Map<String, dynamic> data = jsonDecode(dataString);
      
      if (data['type'] == 'buttonEvent') {
        String button = data['button'];
        bool pressed = data['pressed'];
        
        if (pressed) {
          String functionName = '';
          if (button == 'button1') functionName = _functionNames[_buttonConfig['button1']!];
          if (button == 'button2') functionName = _functionNames[_buttonConfig['button2']!];
          if (button == 'button3') functionName = _functionNames[_buttonConfig['button3']!];
          
          setState(() {
            _selectedOption = functionName;
            _connectionStatus = '$button pressed: $functionName';
          });
        }
      } else if (data['type'] == 'status') {
        setState(() {
          _connectionStatus = 'Status update received';
        });
      }
    } catch (e) {
      print('Error parsing incoming data: $e');
    }
  }

  Future<void> _sendConfiguration() async {
    if (_simulatorMode && _simulator != null) {
      // Send to simulator
      Map<String, dynamic> config = {
        'button1': _buttonConfig['button1'],
        'button2': _buttonConfig['button2'],
        'button3': _buttonConfig['button3'],
      };
      
      String configString = jsonEncode(config);
      _simulator!.receiveConfiguration(configString);
      return;
    }
    
    if (_configCharacteristic == null) return;
    
    try {
      Map<String, dynamic> config = {
        'button1': _buttonConfig['button1'],
        'button2': _buttonConfig['button2'],
        'button3': _buttonConfig['button3'],
      };
      
      String configString = jsonEncode(config);
      List<int> bytes = utf8.encode(configString);
      
      await _configCharacteristic!.write(bytes);
      print('Configuration sent: $configString');
    } catch (e) {
      print('Error sending configuration: $e');
    }
  }

  void _disconnect() async {
    if (_simulatorMode) {
      _simulator?.disconnect();
      return;
    }
    
    _characteristicSubscription?.cancel();
    _connectionSubscription?.cancel();
    
    if (_connectedDevice != null) {
      await _connectedDevice!.disconnect();
    }
    
    setState(() {
      _isConnected = false;
      _connectedDevice = null;
      _configCharacteristic = null;
      _connectionStatus = 'Disconnected';
    });
  }

  void _selectOption(String option) {
    setState(() {
      _selectedOption = option;
    });
    print('Selected: $option');
  }

  void _showBluetoothSettings() {
    showModalBottomSheet(
      context: context,
      builder: (context) => Container(
        padding: const EdgeInsets.all(16),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text('Bluetooth Connection', 
                style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
            const SizedBox(height: 16),
            
            // Simulator Mode Toggle
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: _simulatorMode ? Colors.orange.shade50 : Colors.grey.shade50,
                borderRadius: BorderRadius.circular(8),
                border: Border.all(
                  color: _simulatorMode ? Colors.orange : Colors.grey,
                  width: 1,
                ),
              ),
              child: Row(
                children: [
                  Icon(
                    _simulatorMode ? Icons.android : Icons.bluetooth,
                    color: _simulatorMode ? Colors.orange : Colors.grey,
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'Simulator Mode',
                          style: TextStyle(
                            fontWeight: FontWeight.bold,
                            color: _simulatorMode ? Colors.orange.shade800 : Colors.grey.shade800,
                          ),
                        ),
                        Text(
                          'Test without ESP32 hardware',
                          style: TextStyle(
                            fontSize: 12,
                            color: _simulatorMode ? Colors.orange.shade600 : Colors.grey.shade600,
                          ),
                        ),
                      ],
                    ),
                  ),
                  Switch(
                    value: _simulatorMode,
                    onChanged: (value) {
                      Navigator.pop(context);
                      _toggleSimulatorMode();
                    },
                    activeThumbColor: Colors.orange,
                  ),
                ],
              ),
            ),
            const SizedBox(height: 16),
            
            // Debug scan button
            if (!_simulatorMode) ...[
              ElevatedButton.icon(
                onPressed: _debugScanAllDevices,
                icon: const Icon(Icons.search),
                label: const Text('Debug: Scan All Devices'),
                style: ElevatedButton.styleFrom(
                  backgroundColor: Colors.orange,
                  foregroundColor: Colors.white,
                ),
              ),
              const SizedBox(height: 8),
            ],
            
            Text('Status: $_connectionStatus'),
            const SizedBox(height: 16),
            
            if (_simulatorMode) ...[
              // Simulator Controls
              if (!_isConnected) ...[
                ElevatedButton(
                  onPressed: _connectToSimulator,
                  style: ElevatedButton.styleFrom(backgroundColor: Colors.orange),
                  child: const Text('Connect to Simulator'),
                ),
                const SizedBox(height: 8),
                const Text('🤖 Simulator will automatically generate button presses for testing',
                    style: TextStyle(fontSize: 12, fontStyle: FontStyle.italic)),
              ] else ...[
                Text('Connected to: ESP32 Simulator'),
                const SizedBox(height: 16),
                
                // Manual simulator controls
                const Text('Manual Controls:', style: TextStyle(fontWeight: FontWeight.bold)),
                const SizedBox(height: 8),
                Wrap(
                  spacing: 8,
                  children: [
                    ElevatedButton(
                      onPressed: () => _simulator?.simulateButtonPress('button1'),
                      child: const Text('Btn 1'),
                    ),
                    ElevatedButton(
                      onPressed: () => _simulator?.simulateButtonPress('button2'),
                      child: const Text('Btn 2'),
                    ),
                    ElevatedButton(
                      onPressed: () => _simulator?.simulateButtonPress('button3'),
                      child: const Text('Btn 3'),
                    ),
                    ElevatedButton(
                      onPressed: () => _simulator?.simulateEncoderRotation(true),
                      child: const Text('Enc ↻'),
                    ),
                    ElevatedButton(
                      onPressed: () => _simulator?.simulateEncoderRotation(false),
                      child: const Text('Enc ↺'),
                    ),
                    ElevatedButton(
                      onPressed: () => _simulator?.simulateEncoderPress(),
                      child: const Text('Enc Btn'),
                    ),
                  ],
                ),
                const SizedBox(height: 16),
                ElevatedButton(
                  onPressed: _disconnect,
                  style: ElevatedButton.styleFrom(backgroundColor: Colors.red),
                  child: const Text('Disconnect'),
                ),
              ],
            ] else ...[
              // Real Bluetooth Controls
              if (!_isConnected) ...[
                ElevatedButton(
                  onPressed: _isScanning ? null : _startScan,
                  child: Text(_isScanning ? 'Scanning...' : 'Scan for Devices'),
                ),
                const SizedBox(height: 16),
                
                if (_scanResults.isNotEmpty) ...[
                  const Text('Found Devices:', style: TextStyle(fontWeight: FontWeight.bold)),
                  const SizedBox(height: 8),
                  ..._scanResults.map((result) => ListTile(
                    title: Text(result.device.name.isNotEmpty 
                        ? result.device.name 
                        : 'Unknown Device'),
                    subtitle: Text(result.device.id.toString()),
                    trailing: Text('${result.rssi} dBm'),
                    onTap: () {
                      Navigator.pop(context);
                      _connect(result.device);
                    },
                  )),
                ],
              ] else ...[
                Text('Connected to: ${_connectedDevice?.name ?? 'Unknown'}'),
                const SizedBox(height: 16),
                ElevatedButton(
                  onPressed: _disconnect,
                  style: ElevatedButton.styleFrom(backgroundColor: Colors.red),
                  child: const Text('Disconnect'),
                ),
              ],
            ],
          ],
        ),
      ),
    );
  }

  void _showConfiguration() {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      builder: (context) => Container(
        height: MediaQuery.of(context).size.height * 0.7,
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text('Button Configuration', 
                style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
            const SizedBox(height: 16),
            
            _buildButtonConfig('Button 1', 'button1'),
            const SizedBox(height: 16),
            _buildButtonConfig('Button 2', 'button2'),
            const SizedBox(height: 16),
            _buildButtonConfig('Button 3', 'button3'),
            const SizedBox(height: 24),
            
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceEvenly,
              children: [
                ElevatedButton(
                  onPressed: () async {
                    await _saveSettings();
                    if (_isConnected) {
                      await _sendConfiguration();
                    }
                    Navigator.pop(context);
                    // Force UI update to reflect new configuration
                    setState(() {});
                    ScaffoldMessenger.of(context).showSnackBar(
                      const SnackBar(content: Text('Configuration saved!')),
                    );
                  },
                  child: const Text('Save'),
                ),
                ElevatedButton(
                  onPressed: () => Navigator.pop(context),
                  style: ElevatedButton.styleFrom(backgroundColor: Colors.grey),
                  child: const Text('Cancel'),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildButtonConfig(String buttonLabel, String buttonKey) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(buttonLabel, style: const TextStyle(fontWeight: FontWeight.bold)),
        const SizedBox(height: 8),
        DropdownButton<int>(
          value: _buttonConfig[buttonKey],
          isExpanded: true,
          items: _functionNames.asMap().entries.map((entry) {
            return DropdownMenuItem<int>(
              value: entry.key,
              child: Text(entry.value),
            );
          }).toList(),
          onChanged: (int? newValue) {
            if (newValue != null) {
              setState(() {
                _buttonConfig[buttonKey] = newValue;
              });
            }
          },
        ),
      ],
    );
  }

  Widget _buildButtonDisplay(String buttonLabel, String buttonKey) {
    String currentFunction = _functionNames[_buttonConfig[buttonKey] ?? 0];
    bool isSelected = _selectedOption == currentFunction;
    
    return Container(
      width: double.infinity,
      child: ElevatedButton(
        onPressed: () => _selectOption(currentFunction),
        style: ElevatedButton.styleFrom(
          backgroundColor: isSelected
              ? const Color.fromRGBO(255, 182, 193, 1)
              : Colors.grey.shade200,
          foregroundColor: isSelected ? Colors.black : Colors.grey.shade800,
          padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(8),
          ),
          elevation: isSelected ? 4 : 1,
        ),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Text(
              currentFunction, 
              style: TextStyle(
                fontSize: 16,
                fontWeight: isSelected ? FontWeight.bold : FontWeight.normal,
              ),
            ),
            if (isSelected)
              Icon(Icons.check_circle, size: 20),
            if (!isSelected)
              Icon(Icons.arrow_drop_down, color: Colors.grey.shade600),
          ],
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        backgroundColor: Theme.of(context).colorScheme.inversePrimary,
        title: const Text('eSketch Shortcuts'),
        actions: [
          IconButton(
            icon: Icon(_isConnected ? Icons.bluetooth_connected : Icons.bluetooth),
            color: _isConnected ? Colors.green : Colors.grey,
            onPressed: _showBluetoothSettings,
            tooltip: 'Bluetooth Settings',
          ),
          IconButton(
            icon: const Icon(Icons.settings),
            onPressed: _showConfiguration,
            tooltip: 'Configure Buttons',
          ),
        ],
      ),
      body: SafeArea(
        child: LayoutBuilder(
          builder: (context, constraints) {
            // Responsive layout for iPad
            double maxWidth = constraints.maxWidth > 600 ? 600 : constraints.maxWidth;
            
            return Center(
              child: SingleChildScrollView(
                child: Container(
                  width: maxWidth,
                  padding: const EdgeInsets.all(24),
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: <Widget>[
                      // Connection Status Card
                      Container(
                        width: double.infinity,
                        padding: const EdgeInsets.all(20),
                        decoration: BoxDecoration(
                          color: _isConnected 
                              ? Colors.green.shade50 
                              : (_simulatorMode ? Colors.orange.shade50 : Colors.red.shade50),
                          borderRadius: BorderRadius.circular(12),
                          border: Border.all(
                            color: _isConnected 
                                ? Colors.green 
                                : (_simulatorMode ? Colors.orange : Colors.red),
                            width: 2,
                          ),
                        ),
                        child: Row(
                          mainAxisSize: MainAxisSize.min,
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            Icon(
                              _isConnected 
                                  ? Icons.bluetooth_connected 
                                  : (_simulatorMode ? Icons.android : Icons.bluetooth_disabled),
                              color: _isConnected 
                                  ? Colors.green 
                                  : (_simulatorMode ? Colors.orange : Colors.red),
                              size: 32,
                            ),
                            const SizedBox(width: 12),
                            Flexible(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  Text(
                                    _connectionStatus,
                                    style: TextStyle(
                                      fontSize: 16,
                                      color: _isConnected 
                                          ? Colors.green.shade800 
                                          : (_simulatorMode ? Colors.orange.shade800 : Colors.red.shade800),
                                      fontWeight: FontWeight.bold,
                                    ),
                                  ),
                                  if (_simulatorMode && !_isConnected)
                                    Text(
                                      'Simulator Mode - No Hardware Needed',
                                      style: TextStyle(
                                        fontSize: 14,
                                        color: Colors.orange.shade600,
                                        fontStyle: FontStyle.italic,
                                      ),
                                    ),
                                ],
                              ),
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(height: 32),
                      
                      // Prominent Bluetooth Scan Button
                      if (!_isConnected) ...[
                        SizedBox(
                          width: double.infinity,
                          height: 60,
                          child: ElevatedButton.icon(
                            onPressed: _simulatorMode ? _connectToSimulator : _showBluetoothSettings,
                            icon: Icon(
                              _simulatorMode ? Icons.android : Icons.bluetooth_searching,
                              size: 28,
                            ),
                            label: Text(
                              _simulatorMode ? 'Connect to Simulator' : 'Scan for ESP32 Device',
                              style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                            ),
                            style: ElevatedButton.styleFrom(
                              backgroundColor: _simulatorMode ? Colors.orange : Colors.blue,
                              foregroundColor: Colors.white,
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(12),
                              ),
                              elevation: 4,
                            ),
                          ),
                        ),
                        const SizedBox(height: 32),
                      ],
                      
                      // Button Controls Section
                      Container(
                        width: double.infinity,
                        padding: const EdgeInsets.all(20),
                        decoration: BoxDecoration(
                          color: Colors.grey.shade50,
                          borderRadius: BorderRadius.circular(12),
                          border: Border.all(color: Colors.grey.shade300),
                        ),
                        child: Column(
                          children: [
                            // Circle Button 1
                            Row(
                              children: [
                                Container(
                                  width: 40,
                                  height: 40,
                                  decoration: BoxDecoration(
                                    color: Colors.deepPurple,
                                    shape: BoxShape.circle,
                                  ),
                                  child: Center(
                                    child: Text('1', style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 18)),
                                  ),
                                ),
                                const SizedBox(width: 12),
                                Expanded(
                                  child: Column(
                                    crossAxisAlignment: CrossAxisAlignment.start,
                                    children: [
                                      const Text('Circle Button 1', style: TextStyle(fontSize: 14, fontWeight: FontWeight.w600)),
                                      const SizedBox(height: 4),
                                      _buildButtonDisplay('Button 1', 'button1'),
                                    ],
                                  ),
                                ),
                              ],
                            ),
                            const SizedBox(height: 20),
                            
                            // Circle Button 2
                            Row(
                              children: [
                                Container(
                                  width: 40,
                                  height: 40,
                                  decoration: BoxDecoration(
                                    color: Colors.deepPurple,
                                    shape: BoxShape.circle,
                                  ),
                                  child: Center(
                                    child: Text('2', style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 18)),
                                  ),
                                ),
                                const SizedBox(width: 12),
                                Expanded(
                                  child: Column(
                                    crossAxisAlignment: CrossAxisAlignment.start,
                                    children: [
                                      const Text('Circle Button 2', style: TextStyle(fontSize: 14, fontWeight: FontWeight.w600)),
                                      const SizedBox(height: 4),
                                      _buildButtonDisplay('Button 2', 'button2'),
                                    ],
                                  ),
                                ),
                              ],
                            ),
                            const SizedBox(height: 20),
                            
                            // Buttons 1 + 2
                            Row(
                              children: [
                                Container(
                                  width: 40,
                                  height: 40,
                                  decoration: BoxDecoration(
                                    color: Colors.deepPurple,
                                    borderRadius: BorderRadius.circular(8),
                                  ),
                                  child: Icon(Icons.gamepad, color: Colors.white, size: 24),
                                ),
                                const SizedBox(width: 12),
                                Expanded(
                                  child: Column(
                                    crossAxisAlignment: CrossAxisAlignment.start,
                                    children: [
                                      const Text('Buttons 1 + 2', style: TextStyle(fontSize: 14, fontWeight: FontWeight.w600)),
                                      const SizedBox(height: 4),
                                      _buildButtonDisplay('Button 3', 'button3'),
                                    ],
                                  ),
                                ),
                              ],
                            ),
                            const SizedBox(height: 20),
                            
                            // Dial
                            Row(
                              children: [
                                Container(
                                  width: 40,
                                  height: 40,
                                  decoration: BoxDecoration(
                                    color: Colors.deepPurple,
                                    borderRadius: BorderRadius.circular(8),
                                  ),
                                  child: Icon(Icons.settings, color: Colors.white, size: 24),
                                ),
                                const SizedBox(width: 12),
                                Expanded(
                                  child: Column(
                                    crossAxisAlignment: CrossAxisAlignment.start,
                                    children: [
                                      const Text('Dial', style: TextStyle(fontSize: 14, fontWeight: FontWeight.w600)),
                                      const SizedBox(height: 4),
                                      Container(
                                        width: double.infinity,
                                        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                                        decoration: BoxDecoration(
                                          color: Colors.grey.shade200,
                                          borderRadius: BorderRadius.circular(8),
                                          border: Border.all(color: Colors.grey.shade400),
                                        ),
                                        child: Row(
                                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                          children: [
                                            Text(
                                              'Layers',
                                              style: TextStyle(fontSize: 16, color: Colors.grey.shade700),
                                            ),
                                            Icon(Icons.arrow_drop_down, color: Colors.grey.shade700),
                                          ],
                                        ),
                                      ),
                                    ],
                                  ),
                                ),
                              ],
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(height: 24),
                      
                      // Current Selection Display
                      Container(
                        width: double.infinity,
                        padding: const EdgeInsets.all(16),
                        decoration: BoxDecoration(
                          color: Colors.blue.shade50,
                          borderRadius: BorderRadius.circular(12),
                          border: Border.all(color: Colors.blue.shade200),
                        ),
                        child: Column(
                          children: [
                            Text(
                              _selectedOption.isNotEmpty
                                  ? 'Selected: $_selectedOption'
                                  : 'No option selected',
                              style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                              textAlign: TextAlign.center,
                            ),
                          ],
                        ),
                      ),
                      
                      if (_simulatorMode && _isConnected) ...[
                        const SizedBox(height: 24),
                        Container(
                          padding: const EdgeInsets.all(16),
                          decoration: BoxDecoration(
                            color: Colors.orange.shade50,
                            borderRadius: BorderRadius.circular(12),
                            border: Border.all(color: Colors.orange, width: 2),
                          ),
                          child: Column(
                            children: [
                              Row(
                                mainAxisAlignment: MainAxisAlignment.center,
                                children: [
                                  Icon(Icons.android, color: Colors.orange.shade800),
                                  const SizedBox(width: 8),
                                  Text('Simulator Active', 
                                      style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16, color: Colors.orange.shade800)),
                                ],
                              ),
                              const SizedBox(height: 8),
                              const Text('Automatic button presses every 8 seconds', 
                                  style: TextStyle(fontSize: 14)),
                              const Text('Manual controls available in Bluetooth settings', 
                                  style: TextStyle(fontSize: 14)),
                            ],
                          ),
                        ),
                      ],
                    ],
                  ),
                ),
              ),
            );
          },
        ),
      ),
    );
  }
}