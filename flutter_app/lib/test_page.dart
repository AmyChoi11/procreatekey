import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:flutter_blue_plus/flutter_blue_plus.dart';

class TestPage extends StatefulWidget {
  final BluetoothDevice device;

  const TestPage({super.key, required this.device});

  @override
  State<TestPage> createState() => _TestPageState();
}

class _TestPageState extends State<TestPage> {
  final List<String> _logs = [];
  bool _isConnected = false;
  List<BluetoothService> _services = [];

  @override
  void initState() {
    super.initState();
    _testConnection();
  }

  void _log(String message) {
    setState(() {
      _logs.insert(0, '[${DateTime.now().toString().substring(11, 19)}] $message');
      if (_logs.length > 50) _logs.removeLast();
    });
    print(message);
  }

  Future<void> _testConnection() async {
    _log('=== Starting Connection Test ===');
    
    try {
      _log('Step 1: Connecting to ${widget.device.platformName}...');
      await widget.device.connect(timeout: const Duration(seconds: 15));
      setState(() => _isConnected = true);
      _log('✓ Connected successfully!');

      _log('Step 2: Discovering services...');
      _services = await widget.device.discoverServices();
      _log('✓ Found ${_services.length} services');

      for (var service in _services) {
        _log('');
        _log('Service: ${service.uuid}');
        _log('  Characteristics: ${service.characteristics.length}');
        
        for (var char in service.characteristics) {
          final props = [];
          if (char.properties.read) props.add('READ');
          if (char.properties.write) props.add('WRITE');
          if (char.properties.writeWithoutResponse) props.add('WRITE_NO_RESP');
          if (char.properties.notify) props.add('NOTIFY');
          if (char.properties.indicate) props.add('INDICATE');
          
          _log('    - ${char.uuid}');
          _log('      Properties: ${props.join(", ")}');
        }
      }

      _log('');
      _log('=== Connection Test Complete ===');
      _log('Now you can try the test buttons below');

    } catch (e) {
      _log('❌ Error: $e');
      setState(() => _isConnected = false);
    }
  }

  Future<void> _testWrite() async {
    _log('');
    _log('=== Testing Config Write ===');

    try {
      // Try to find characteristic by partial UUID match
      BluetoothCharacteristic? configChar;
      
      for (var service in _services) {
        final svcUuid = service.uuid.toString().toLowerCase();
        if (svcUuid.contains('12345678') || svcUuid.contains('abcdef')) {
          _log('Found custom service: $svcUuid');
          
          for (var char in service.characteristics) {
            final charUuid = char.uuid.toString().toLowerCase();
            _log('  Checking characteristic: $charUuid');
            
            if (charUuid.contains('abcdef1') || charUuid.endsWith('def1')) {
              configChar = char;
              _log('  ✓ This looks like the config characteristic!');
              break;
            }
          }
        }
      }

      if (configChar == null) {
        _log('❌ Config characteristic not found!');
        _log('');
        _log('DIAGNOSIS:');
        _log('The device does not have the expected GATT service.');
        _log('Please flash xiao_ble_only.ino to your ESP32.');
        return;
      }

      final testConfig = {
        'buttons': {
          'button1': 3,
          'button2': 4,
          'button3': 3,
        }
      };

      final jsonStr = jsonEncode(testConfig);
      _log('Sending: $jsonStr');
      
      await configChar.write(utf8.encode(jsonStr));
      _log('✓ Write successful!');
      _log('Check your ESP32 serial monitor for confirmation.');

    } catch (e) {
      _log('❌ Write failed: $e');
    }
  }

  Future<void> _testWriteByFullUuid() async {
    _log('');
    _log('=== Testing Write by Full UUID ===');

    try {
      // Look for the exact UUID
      const targetUuid = '12345678-1234-5678-1234-56789abcdef1';
      BluetoothCharacteristic? configChar;
      
      for (var service in _services) {
        for (var char in service.characteristics) {
          if (char.uuid.toString().toLowerCase() == targetUuid.toLowerCase()) {
            configChar = char;
            _log('Found exact UUID match: ${char.uuid}');
            break;
          }
        }
      }

      if (configChar == null) {
        _log('❌ Characteristic $targetUuid not found');
        _log('Available characteristics:');
        for (var service in _services) {
          for (var char in service.characteristics) {
            _log('  - ${char.uuid}');
          }
        }
        return;
      }

      final testConfig = {
        'buttons': {
          'button1': 0,
          'button2': 1,
          'button3': 2,
        }
      };

      final jsonStr = jsonEncode(testConfig);
      _log('Sending: $jsonStr');
      
      await configChar.write(utf8.encode(jsonStr));
      _log('✓ Write successful!');

    } catch (e) {
      _log('❌ Write failed: $e');
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('BLE Connection Test'),
        actions: [
          Icon(_isConnected ? Icons.bluetooth_connected : Icons.bluetooth_disabled),
          const SizedBox(width: 16),
        ],
      ),
      body: Column(
        children: [
          Padding(
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                ElevatedButton.icon(
                  onPressed: _isConnected ? _testWrite : null,
                  icon: const Icon(Icons.send),
                  label: const Text('Test Config Write (Partial UUID Match)'),
                ),
                const SizedBox(height: 8),
                ElevatedButton.icon(
                  onPressed: _isConnected ? _testWriteByFullUuid : null,
                  icon: const Icon(Icons.send_outlined),
                  label: const Text('Test Config Write (Full UUID)'),
                ),
                const SizedBox(height: 8),
                ElevatedButton.icon(
                  onPressed: _testConnection,
                  icon: const Icon(Icons.refresh),
                  label: const Text('Reconnect & Re-test'),
                ),
              ],
            ),
          ),
          const Divider(),
          const Padding(
            padding: EdgeInsets.all(8.0),
            child: Text(
              'Test Log:',
              style: TextStyle(fontWeight: FontWeight.bold),
            ),
          ),
          Expanded(
            child: Container(
              color: Colors.black,
              child: ListView.builder(
                padding: const EdgeInsets.all(8),
                itemCount: _logs.length,
                itemBuilder: (context, index) {
                  final log = _logs[index];
                  final color = log.contains('✓') 
                      ? Colors.green 
                      : log.contains('❌') 
                          ? Colors.red 
                          : log.contains('===')
                              ? Colors.yellow
                              : Colors.white;
                  
                  return Padding(
                    padding: const EdgeInsets.symmetric(vertical: 2),
                    child: Text(
                      log,
                      style: TextStyle(
                        fontFamily: 'monospace',
                        fontSize: 12,
                        color: color,
                      ),
                    ),
                  );
                },
              ),
            ),
          ),
        ],
      ),
    );
  }

  @override
  void dispose() {
    widget.device.disconnect();
    super.dispose();
  }
}
