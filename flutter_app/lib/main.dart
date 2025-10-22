import 'dart:async';
import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:flutter_blue_plus/flutter_blue_plus.dart';
import 'test_page.dart';
import 'groupmate_ui.dart';

void main() {
  runApp(const ProcreateConfigApp());
}

class ProcreateConfigApp extends StatelessWidget {
  const ProcreateConfigApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Procreate BLE Config',
      theme: ThemeData(
        primarySwatch: Colors.blue,
        useMaterial3: true,
      ),
      home: const ScannerPage(),
    );
  }
}

class ScannerPage extends StatefulWidget {
  const ScannerPage({super.key});

  @override
  State<ScannerPage> createState() => _ScannerPageState();
}

class _ScannerPageState extends State<ScannerPage> {
  List<ScanResult> _scanResults = [];
  bool _isScanning = false;
  StreamSubscription<List<ScanResult>>? _scanSubscription;

  @override
  void initState() {
    super.initState();
    // Don't auto-scan on web - requires user interaction
    // _requestPermissions();
  }

  // _requestPermissions was unused in the current flow (web requires user action),
  // remove to clean analyzer warnings. If you want auto-permission flow, we can add it back.

  void _startScan() async {
    print('[Scanner] Starting BLE scan...');
    
    setState(() {
      _scanResults.clear();
      _isScanning = true;
    });

    try {
      // Stop any existing scan first
      await FlutterBluePlus.stopScan();
      print('[Scanner] Stopped previous scan');
      
      await Future.delayed(const Duration(milliseconds: 300));

      _scanSubscription = FlutterBluePlus.scanResults.listen((results) {
        print('[Scanner] Found ${results.length} devices');
        setState(() {
          _scanResults = results;
        });
      });

      print('[Scanner] Starting scan with service filter...');
      
      // For web/Chrome, we need to specify the service UUID we want to access
      await FlutterBluePlus.startScan(
        timeout: const Duration(seconds: 8),
        withServices: [
          Guid('12345678-1234-5678-1234-56789abcdef0'), // Our custom GATT service
        ],
      );

      print('[Scanner] Scan started successfully');

      Timer(const Duration(seconds: 8), () {
        print('[Scanner] Scan timeout reached');
        setState(() => _isScanning = false);
        FlutterBluePlus.stopScan();
        
        if (_scanResults.isEmpty && mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('No devices found. Make sure ESP32 is powered on and nearby.'),
              backgroundColor: Colors.orange,
              duration: Duration(seconds: 4),
            ),
          );
        }
      });
    } catch (e) {
      print('[Scanner] Scan error: $e');
      setState(() {
        _isScanning = false;
      });
      
      // Show error to user
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Scan failed: $e\n\nTip: Check Bluetooth permissions in Safari settings'),
            backgroundColor: Colors.red,
            duration: const Duration(seconds: 6),
          ),
        );
      }
    }
  }

  @override
  void dispose() {
    _scanSubscription?.cancel();
    FlutterBluePlus.stopScan();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Find XIAO Keyboard'),
        actions: [
          IconButton(
            icon: const Icon(Icons.dashboard_customize),
            tooltip: 'Open Groupmate UI',
            onPressed: () {
              Navigator.push(
                context,
                MaterialPageRoute(builder: (context) => const GroupmateUI()),
              );
            },
          ),
          IconButton(
            icon: const Icon(Icons.delete_forever),
            tooltip: 'Clear all paired devices',
            onPressed: () {
              // This will force a fresh pairing next time
              showDialog(
                context: context,
                builder: (context) => AlertDialog(
                  title: const Text('Clear Pairing'),
                  content: const Text('To fix connection issues:\n\n1. Close this app\n2. Go to browser Settings → Bluetooth\n3. Remove "XIAO Keyboard"\n4. Reload the webpage\n\nThis forces a fresh pairing.'),
                  actions: [
                    TextButton(
                      onPressed: () => Navigator.pop(context),
                      child: const Text('OK'),
                    ),
                  ],
                ),
              );
            },
          ),
        ],
      ),
      body: Column(
        children: [
          if (_isScanning)
            const LinearProgressIndicator()
          else
            Padding(
              padding: const EdgeInsets.all(16.0),
              child: Column(
                children: [
                  ElevatedButton.icon(
                    onPressed: _startScan,
                    icon: const Icon(Icons.bluetooth_searching),
                    label: const Text('Scan for Devices'),
                    style: ElevatedButton.styleFrom(
                      minimumSize: const Size(double.infinity, 50),
                      textStyle: const TextStyle(fontSize: 16),
                    ),
                  ),
                  const SizedBox(height: 8),
                  Text(
                    'Click to open Bluetooth device picker',
                    style: TextStyle(
                      fontSize: 12,
                      color: Colors.grey[600],
                    ),
                  ),
                ],
              ),
            ),
          Expanded(
            child: ListView.builder(
              itemCount: _scanResults.length,
              itemBuilder: (context, index) {
                final result = _scanResults[index];
                final deviceName = result.device.platformName.isNotEmpty
                    ? result.device.platformName
                    : 'Unknown Device';
                
                // Filter to show only XIAO Keyboard or devices with our service UUID
                final hasCustomService = result.advertisementData.serviceUuids
                    .any((uuid) => uuid.toString().toLowerCase().contains('12345678-1234-5678-1234-56789abcdef0'));
                
                final isRelevantDevice = deviceName.toUpperCase().contains('XIAO') || 
                                        deviceName.toUpperCase().contains('KEYBOARD') ||
                                        hasCustomService;
                
                if (!isRelevantDevice) {
                  return const SizedBox.shrink();
                }

                return ListTile(
                  leading: const Icon(Icons.bluetooth),
                  title: Text(deviceName),
                  subtitle: Text(result.device.remoteId.toString()),
                  trailing: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Text('${result.rssi} dBm'),
                      const SizedBox(width: 8),
                      IconButton(
                        icon: const Icon(Icons.bug_report, color: Colors.orange),
                        tooltip: 'Test Mode',
                        onPressed: () {
                          Navigator.push(
                            context,
                            MaterialPageRoute(
                              builder: (context) => TestPage(device: result.device),
                            ),
                          );
                        },
                      ),
                    ],
                  ),
                  onTap: () {
                    Navigator.push(
                      context,
                      MaterialPageRoute(
                        builder: (context) => ConfigPage(device: result.device),
                      ),
                    );
                  },
                );
              },
            ),
          ),
        ],
      ),
    );
  }
}

class ConfigPage extends StatefulWidget {
  final BluetoothDevice device;

  const ConfigPage({super.key, required this.device});

  @override
  State<ConfigPage> createState() => _ConfigPageState();
}

class _ConfigPageState extends State<ConfigPage> {
  bool _isConnected = false;
  bool _isConnecting = false;
  bool _isReady = false;
  
  BluetoothCharacteristic? _configChar;
  // _eventChar and _statusChar are reserved for future use (notifications).
  // ignore: unused_field
  BluetoothCharacteristic? _eventChar;
  // ignore: unused_field
  BluetoothCharacteristic? _statusChar;

  int _button1Function = 3; // Default: Undo
  int _button2Function = 4; // Default: Redo
  int _button3Function = 3; // Default: Undo

  final List<String> _functionNames = [
    'Left Click',
    'Right Click',
    'Double Click',
    'Undo (Cmd+Z)',
    'Redo (Cmd+Shift+Z)',
  ];

  String _statusMessage = 'Connecting...';
  final List<String> _events = [];

  @override
  void initState() {
    super.initState();
    _connectToDevice();
  }

  Future<void> _connectToDevice() async {
    setState(() {
      _isConnecting = true;
      _statusMessage = 'Connecting...';
      _isReady = false;
    });

    try {
      // First, disconnect if already connected
      try {
        await widget.device.disconnect();
        await Future.delayed(const Duration(milliseconds: 500));
      } catch (e) {
        print('Device was not connected: $e');
      }

      // Now connect fresh
      print('Attempting to connect to ${widget.device.platformName}...');
      await widget.device.connect(
        timeout: const Duration(seconds: 20),
        autoConnect: false,
      );
      
      print('✓ Connected!');
      setState(() {
        _isConnected = true;
        _statusMessage = 'Connected - Discovering services...';
      });

      // Wait for connection to stabilize
      await Future.delayed(const Duration(milliseconds: 800));

      // Discover services
      List<BluetoothService> services = await widget.device.discoverServices();
      
      print('Total services found: ${services.length}');
      
      // Find our custom service
      bool foundCustomService = false;
      for (var service in services) {
        final serviceUuid = service.uuid.toString().toLowerCase();
        print('Service UUID: $serviceUuid');
        
        if (serviceUuid.contains('12345678') || serviceUuid.contains('abcdef0')) {
          foundCustomService = true;
          print('✓ Found custom GATT service!');
          print('Characteristics in this service: ${service.characteristics.length}');
          
          for (var char in service.characteristics) {
            final uuid = char.uuid.toString().toLowerCase();
            print('  Characteristic: $uuid');
            
            if (uuid.contains('abcdef1')) {
              _configChar = char;
              print('  ✓ Config char assigned');
            } else if (uuid.contains('abcdef2')) {
              _eventChar = char;
              print('  ✓ Event char assigned');
              // Skip notification setup for faster connection
            } else if (uuid.contains('abcdef3')) {
              _statusChar = char;
              print('  ✓ Status char assigned');
              // Skip notification setup for faster connection
            }
          }
        }
      }
      
      if (!foundCustomService) {
        print('❌ Custom GATT service NOT FOUND!');
        print('This device might not have xiao_ble_only.ino firmware.');
        setState(() {
          _statusMessage = 'Error: This device does not have the custom GATT service. Please flash xiao_ble_only.ino firmware.';
        });
      } else if (_configChar == null) {
        print('❌ Config characteristic NOT FOUND in custom service!');
        setState(() {
          _statusMessage = 'Error: Config characteristic not found. Check ESP32 firmware.';
        });
      } else {
        print('✓ All characteristics found successfully!');
        
        // Read current config from device
        await _readCurrentConfig();
        
        setState(() {
          _statusMessage = 'Connected - Ready to configure';
        });
      }

    } catch (e) {
      print('❌ Error during connection: $e');
      setState(() {
        _isConnecting = false;
        _isConnected = false;
        _isReady = false;
        _statusMessage = 'Connection failed. Try these steps:\n1. Go back to scan page\n2. Wait 3 seconds\n3. Scan again\n4. Select device';
      });
      
      // Try to disconnect to clean up
      try {
        await widget.device.disconnect();
      } catch (e2) {
        print('Cleanup disconnect failed: $e2');
      }
      
      return;
    }

    setState(() {
      _isConnecting = false;
    });

    // Wait a shorter time for device to stabilize
    await Future.delayed(const Duration(milliseconds: 300));
    
    setState(() {
      _isReady = true;
      _statusMessage = 'Ready! You can now configure buttons.';
    });
  }

  Future<void> _readCurrentConfig() async {
    if (_configChar == null) {
      print('⚠️ Config characteristic not available for reading');
      return;
    }

    try {
      print('Reading current configuration from device...');
      
      // Add timeout for reading
      final value = await _configChar!.read().timeout(
        const Duration(seconds: 3),
        onTimeout: () {
          print('⚠️ Config read timeout - using defaults');
          return [];
        }
      );
      
      if (value.isNotEmpty) {
        final jsonStr = utf8.decode(value);
        print('Received config: $jsonStr');
        
        final config = jsonDecode(jsonStr);
        if (config.containsKey('buttons')) {
          setState(() {
            _button1Function = config['buttons']['button1'] ?? 3;
            _button2Function = config['buttons']['button2'] ?? 4;
            _button3Function = config['buttons']['button3'] ?? 3;
          });
          print('✓ Loaded config from device: b1=$_button1Function b2=$_button2Function b3=$_button3Function');
        }
      } else {
        print('⚠️ No config data received - using defaults');
      }
    } catch (e) {
      print('⚠️ Could not read config from device: $e');
      // Not critical - just use defaults
    }
  }

  Future<void> _saveConfiguration() async {
    if (_configChar == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Config characteristic not found')),
      );
      return;
    }

    if (!_isReady) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Please wait, device is still connecting...')),
      );
      return;
    }

    setState(() {
      _statusMessage = 'Saving configuration...';
    });

    final config = {
      'buttons': {
        'button1': _button1Function,
        'button2': _button2Function,
        'button3': _button3Function,
      }
    };

    try {
      final jsonStr = jsonEncode(config);
      print('Sending config: $jsonStr');
      await _configChar!.write(utf8.encode(jsonStr));
      
      setState(() {
        _statusMessage = 'Configuration saved successfully!';
      });
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Configuration saved!'),
            backgroundColor: Colors.green,
            duration: Duration(seconds: 2),
          ),
        );
      }
    } catch (e) {
      print('Save error: $e');
      setState(() {
        _statusMessage = 'Save failed: $e';
      });
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Save failed: $e'),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
  }

  @override
  void dispose() {
    // Disconnect on page close
    try {
      widget.device.disconnect();
    } catch (e) {
      print('Error disconnecting: $e');
    }
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text(widget.device.platformName),
        actions: [
          Icon(_isConnected ? Icons.bluetooth_connected : Icons.bluetooth_disabled),
          const SizedBox(width: 16),
        ],
      ),
      body: _isConnecting
          ? const Center(child: CircularProgressIndicator())
          : !_isConnected
              ? Center(
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      const Icon(Icons.error, size: 64, color: Colors.red),
                      const SizedBox(height: 16),
                      Text(_statusMessage),
                      const SizedBox(height: 16),
                      ElevatedButton(
                        onPressed: _connectToDevice,
                        child: const Text('Retry'),
                      ),
                    ],
                  ),
                )
              : SingleChildScrollView(
                  padding: const EdgeInsets.all(16),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      Card(
                        child: Padding(
                          padding: const EdgeInsets.all(16),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              const Text(
                                'Status',
                                style: TextStyle(
                                  fontSize: 18,
                                  fontWeight: FontWeight.bold,
                                ),
                              ),
                              const SizedBox(height: 8),
                              Text(_statusMessage),
                            ],
                          ),
                        ),
                      ),
                      const SizedBox(height: 16),
                      Card(
                        child: Padding(
                          padding: const EdgeInsets.all(16),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              const Text(
                                'Button Configuration',
                                style: TextStyle(
                                  fontSize: 18,
                                  fontWeight: FontWeight.bold,
                                ),
                              ),
                              const SizedBox(height: 16),
                              _buildButtonConfig('Button 1', _button1Function, (val) {
                                setState(() => _button1Function = val ?? 3);
                              }),
                              const SizedBox(height: 12),
                              _buildButtonConfig('Button 2', _button2Function, (val) {
                                setState(() => _button2Function = val ?? 4);
                              }),
                              const SizedBox(height: 12),
                              _buildButtonConfig('Button 3', _button3Function, (val) {
                                setState(() => _button3Function = val ?? 3);
                              }),
                              const SizedBox(height: 24),
                              SizedBox(
                                width: double.infinity,
                                child: ElevatedButton(
                                  onPressed: _isReady ? _saveConfiguration : null,
                                  style: ElevatedButton.styleFrom(
                                    padding: const EdgeInsets.symmetric(vertical: 16),
                                    backgroundColor: _isReady ? null : Colors.grey,
                                  ),
                                  child: Text(
                                    _isReady ? 'Save Configuration' : 'Please wait...',
                                    style: const TextStyle(fontSize: 16),
                                  ),
                                ),
                              ),
                            ],
                          ),
                        ),
                      ),
                      const SizedBox(height: 16),
                      Card(
                        child: Padding(
                          padding: const EdgeInsets.all(16),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              const Text(
                                'Live Events',
                                style: TextStyle(
                                  fontSize: 18,
                                  fontWeight: FontWeight.bold,
                                ),
                              ),
                              const SizedBox(height: 8),
                              SizedBox(
                                height: 200,
                                child: ListView.builder(
                                  itemCount: _events.length,
                                  itemBuilder: (context, index) {
                                    return Padding(
                                      padding: const EdgeInsets.symmetric(vertical: 4),
                                      child: Text(
                                        _events[index],
                                        style: const TextStyle(fontSize: 12),
                                      ),
                                    );
                                  },
                                ),
                              ),
                            ],
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
    );
  }

  Widget _buildButtonConfig(String label, int currentValue, ValueChanged<int?> onChanged) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          label,
          style: const TextStyle(fontWeight: FontWeight.w500),
        ),
        const SizedBox(height: 8),
        DropdownButtonFormField<int>(
          initialValue: currentValue,
          decoration: const InputDecoration(
            border: OutlineInputBorder(),
            contentPadding: EdgeInsets.symmetric(horizontal: 12, vertical: 8),
          ),
          items: List.generate(
            _functionNames.length,
            (index) => DropdownMenuItem(
              value: index,
              child: Text(_functionNames[index]),
            ),
          ),
          onChanged: onChanged,
        ),
      ],
    );
  }
}
