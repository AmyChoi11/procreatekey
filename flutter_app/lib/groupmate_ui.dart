import 'package:flutter/material.dart';
import 'package:flutter_blue_plus/flutter_blue_plus.dart';
import 'dart:convert';

class GroupmateUI extends StatefulWidget {
  const GroupmateUI({super.key});

  @override
  State<GroupmateUI> createState() => _GroupmateUIState();
}

class _GroupmateUIState extends State<GroupmateUI> {
  bool _isSending = false;
  String _responseMessage = '';
  // BLE state
  bool _isScanning = false;
  BluetoothDevice? _device;
  BluetoothCharacteristic? _configChar;
  bool _isConnected = false;
  
  final Map<String, String?> _selectedTools = {
    'Circle Button 1': null,
    'Circle Button 2': null,
    'Buttons 1 + 2': null,
    'Dial': null,
  };

  final Map<String, List<String>> _toolOptionsMap = {
    'Circle Button 1': [
      'Undo',
      'Redo',
      'Erase',
      'Brush Size (saved presets only)'
    ],
    'Circle Button 2': [
      'Undo',
      'Redo',
      'Erase',
      'Brush Size (saved presets only)'
    ],
    'Buttons 1 + 2': [
      'Color Palette',
      'Brush Library',
    ],
    'Dial': [
      'Layers',
      'Pen Opacity',
      'Brush Size',
    ],
  };

  // Removed HTTP/IP controls - BLE-only UI

  @override
  void initState() {
    super.initState();
  }

  @override
  void dispose() {
    try {
      _device?.disconnect();
    } catch (e) {
      // log disconnect error
      print('Disconnect error: $e');
    }
    super.dispose();
  }

  // Map option strings to firmware function codes (0..4)
  int _optionToFunctionCode(String? option) {
    if (option == null) return 0;
    switch (option) {
      case 'Left Click':
        return 0;
      case 'Right Click':
        return 1;
      case 'Double Click':
        return 2;
      case 'Undo':
        return 3;
      case 'Redo':
        return 4;
      // For UI-specific options that don't map, choose sensible defaults
      case 'Erase':
      case 'Brush Size (saved presets only)':
      case 'Color Palette':
      case 'Brush Library':
      case 'Layers':
      case 'Pen Opacity':
      case 'Brush Size':
        return 0; // default to Left Click if not supported
      default:
        return 0;
    }
  }

  String _functionCodeToOption(int code) {
    switch (code) {
      case 0:
        return 'Left Click';
      case 1:
        return 'Right Click';
      case 2:
        return 'Double Click';
      case 3:
        return 'Undo';
      case 4:
        return 'Redo';
      default:
        return 'Left Click';
    }
  }

  Future<void> _startBleScanAndPick() async {
    setState(() {
      _isScanning = true;
      _responseMessage = 'Starting scan...';
    });

    try {
      print('Stopping any existing scan...');
      await FlutterBluePlus.stopScan();
    } catch (e) {
      print('Stop scan error (safe to ignore): $e');
    }

    List<BluetoothDevice> devices = [];

    try {
      // Try scan without service filter (more compatible with Web Bluetooth on some browsers)
      print('Starting BLE scan (no service filter for wider compatibility)...');
      List<ScanResult> results = [];
      var sub = FlutterBluePlus.scanResults.listen((r) {
        print('Scan results updated: ${r.length} devices found');
        results = r;
      });

      try {
        print('[GroupmateUI] Requesting Web Bluetooth scan...');
        await FlutterBluePlus.startScan(
          timeout: const Duration(seconds: 8),
          // no withServices -> broader scan, better for Web Bluetooth
        ).timeout(const Duration(seconds: 10));
        print('[GroupmateUI] Scan request accepted');
      } catch (e) {
        print('[GroupmateUI] Start scan error or timeout: $e');
        setState(() { _responseMessage = 'Scan failed: $e\n\nCheck:\n1. Bluetooth permissions\n2. ESP32 is powered on\n3. Try reloading page'; });
        setState(() { _isScanning = false; });
        await sub.cancel();
        return;
      }

      print('[GroupmateUI] Waiting for scan to complete...');
      await Future.delayed(const Duration(seconds: 8));
      
      try {
        await FlutterBluePlus.stopScan();
      } catch (e) {
        print('[GroupmateUI] Stop scan error: $e');
      }
      
      await sub.cancel();

      print('[GroupmateUI] Scan complete. Total devices found: ${results.length}');
      
      // Map to BluetoothDevice list
      devices = results.map((r) => r.device).toList();
      
      print('Device list:');
      for (var d in devices) {
        print('  - ${d.platformName.isNotEmpty ? d.platformName : "unnamed"} (${d.id})');
      }

    } catch (e) {
      print('Fatal scan error: $e');
      setState(() { 
        _isScanning = false; 
        _responseMessage = 'Scan error: $e\n\nTry:\n1. Reload page\n2. Check Bluetooth is enabled\n3. Grant Bluetooth permissions'; 
      });
      return;
    }

    setState(() { _isScanning = false; });

    if (devices.isEmpty) {
      setState(() { _responseMessage = 'No devices found.\n\nMake sure:\n- ESP32 is powered on\n- Bluetooth is enabled\n- You granted Bluetooth permission in browser'; });
      return;
    }

    // Show a simple dialog for the user to pick a device
    if (!mounted) return;
    
    final BluetoothDevice? chosen = await showDialog<BluetoothDevice?>(
      context: context,
      builder: (ctx) {
        return SimpleDialog(
          title: const Text('Select Device'),
          children: devices.map((d) {
            final label = d.platformName.isNotEmpty ? d.platformName : 'Unnamed device';
            return SimpleDialogOption(
              child: Padding(
                padding: const EdgeInsets.symmetric(vertical: 8),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(label, style: const TextStyle(fontWeight: FontWeight.bold)),
                    Text(d.id.toString(), style: const TextStyle(fontSize: 12, color: Colors.grey)),
                  ],
                ),
              ),
              onPressed: () => Navigator.pop(ctx, d),
            );
          }).toList(),
        );
      },
    );

    if (chosen == null) {
      setState(() { _responseMessage = 'No device selected.'; });
      return;
    }

    await _connectToDevice(chosen);
  }

  Future<void> _connectToDevice(BluetoothDevice device) async {
    setState(() { _responseMessage = 'Connecting to ${device.platformName}...'; });
    try {
      await device.connect(timeout: const Duration(seconds: 20), autoConnect: false);
      _device = device;
      setState(() { _isConnected = true; _responseMessage = 'Connected to ${device.platformName}'; });

      // discover services
      final services = await device.discoverServices();
      for (var svc in services) {
        final sid = svc.uuid.toString().toLowerCase();
        if (sid.contains('12345678') || sid.contains('abcdef0')) {
          for (var ch in svc.characteristics) {
            final cu = ch.uuid.toString().toLowerCase();
            if (cu.contains('abcdef1')) {
              _configChar = ch;
            }
          }
        }
      }

      if (_configChar == null) {
        setState(() { _responseMessage = 'Connected but config characteristic not found.'; });
        return;
      }

      // Read current config
      try {
        final bytes = await _configChar!.read().timeout(const Duration(seconds: 3));
        if (bytes.isNotEmpty) {
          final jsonStr = utf8.decode(bytes);
          final cfg = jsonDecode(jsonStr);
          if (cfg['buttons'] != null) {
            final b1 = cfg['buttons']['button1'] ?? 3;
            final b2 = cfg['buttons']['button2'] ?? 4;
            final b3 = cfg['buttons']['button3'] ?? 3;
            setState(() {
              // map to UI controls
              _selectedTools['Circle Button 1'] = _functionCodeToOption(b1);
              _selectedTools['Circle Button 2'] = _functionCodeToOption(b2);
              _selectedTools['Buttons 1 + 2'] = _functionCodeToOption(b3);
            });
            setState(() { _responseMessage = 'Loaded config from device'; });
          }
        }
      } catch (e) {
        print('Read config failed: $e');
      }

    } catch (e) {
      setState(() { _responseMessage = 'Connection failed: $e'; });
      print('Connect error: $e');
    }
  }

  Future<void> _writeConfigToDevice() async {
    if (_configChar == null) {
      setState(() { _responseMessage = 'No config characteristic; connect first.'; });
      return;
    }

    final cfg = {
      'buttons': {
        // map UI controls to device button numbers
        'button1': _optionToFunctionCode(_selectedTools['Circle Button 1']),
        'button2': _optionToFunctionCode(_selectedTools['Circle Button 2']),
        'button3': _optionToFunctionCode(_selectedTools['Buttons 1 + 2']),
      }
    };
    final jsonStr = jsonEncode(cfg);
    setState(() { _isSending = true; _responseMessage = 'Sending config...'; });
    try {
      await _configChar!.write(utf8.encode(jsonStr));
      // read-back
      final rb = await _configChar!.read().timeout(const Duration(seconds: 3));
      final rbStr = rb.isNotEmpty ? utf8.decode(rb) : '';
      setState(() { _responseMessage = 'Saved. Device responded: $rbStr'; });
    } catch (e) {
      setState(() { _responseMessage = 'Save failed: $e'; });
    } finally {
      setState(() { _isSending = false; });
    }
  }

  // HTTP-specific controls removed — BLE-only flow below

  void _handleToolChange(String toolName, String? newValue) async {
    if (newValue != null) {
      setState(() {
        _selectedTools[toolName] = newValue;
      });
      // If connected, write updated config immediately
      if (_isConnected && _configChar != null) {
        await _writeConfigToDevice();
      } else {
        setState(() { _responseMessage = 'Change staged locally. Connect to device to save.'; });
      }
    }
  }

  Widget _buildToolDropdown(String toolName) {
    IconData toolIcon = Icons.radio_button_checked;
    switch (toolName) {
      case 'Circle Button 1':
        toolIcon = Icons.radio_button_checked;
        break;
      case 'Circle Button 2':
        toolIcon = Icons.touch_app;
        break;
      case 'Scroll Wheel':
        toolIcon = Icons.swipe;
        break;
      case 'Buttons 1 + 2':
        toolIcon = Icons.gamepad;
        break;
    }

    return Card(
      elevation: 4,
      margin: const EdgeInsets.symmetric(vertical: 8),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(toolIcon, color: Colors.deepPurple, size: 20),
                const SizedBox(width: 8),
                Text(
                  toolName,
                  style: const TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.bold,
                    color: Colors.deepPurple,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 12),
            Container(
              decoration: BoxDecoration(
                color: _getToolColor(_selectedTools[toolName]),
                border: Border.all(color: Colors.deepPurple.withAlpha(77)),
                borderRadius: BorderRadius.circular(8),
              ),
                child: Padding(
                padding: const EdgeInsets.symmetric(horizontal: 12),
                child: Builder(builder: (context) {
                  final options = _toolOptionsMap[toolName] ?? [];
                  final currentValue = _selectedTools[toolName] ?? (options.isNotEmpty ? options[0] : null);
                  return DropdownButton<String>(
                    value: currentValue,
                    isExpanded: true,
                    underline: const SizedBox(),
                    icon: const Icon(Icons.arrow_drop_down, color: Colors.deepPurple),
                    style: const TextStyle(
                      color: Colors.black,
                      fontSize: 16,
                      fontWeight: FontWeight.w500,
                    ),
                    dropdownColor: Colors.white,
                    onChanged: (newValue) => _handleToolChange(toolName, newValue),
                    items: options.map((String option) {
                      return DropdownMenuItem<String>(
                        value: option,
                        child: Container(
                          padding: const EdgeInsets.symmetric(vertical: 8),
                          child: Text(option),
                        ),
                      );
                    }).toList(),
                  );
                }),
              ),
            ),
            const SizedBox(height: 8),
            Text(
              'Selected: ${_selectedTools[toolName]}',
              style: TextStyle(
                color: Colors.grey[600],
                fontSize: 14,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Color _getToolColor(String? option) {
    switch (option) {
      case 'Undo':
        return const Color(0xFFFFC1CC);
      case 'Erase':
        return const Color(0xFFFFC1CC);
      default:
        return Colors.grey[200]!;
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        leading: IconButton(
          tooltip: 'Connect to XIAO',
          icon: const Icon(Icons.bluetooth_searching, color: Colors.white),
          onPressed: _isScanning ? null : _startBleScanAndPick,
        ),
        title: const Text('eSketch Shortcuts'),
        centerTitle: true,
        backgroundColor: Colors.deepPurple,
        foregroundColor: Colors.white,
        actions: [
          if (_isConnected)
            IconButton(
              tooltip: 'Disconnect',
              onPressed: () async {
                try {
                  await _device?.disconnect();
                } catch (e) {
                  print('Disconnect error: $e');
                }
                setState(() { _isConnected = false; _device = null; _configChar = null; _responseMessage = 'Disconnected'; });
              },
              icon: const Icon(Icons.link_off, color: Colors.white),
            ),
          IconButton(
            tooltip: 'Save to device',
            onPressed: _isSending ? null : _writeConfigToDevice,
            icon: const Icon(Icons.save, color: Colors.white),
          ),
          const SizedBox(width: 8),
        ],
      ),
      body: SingleChildScrollView(
        child: Padding(
          padding: const EdgeInsets.all(20),
          child: Column(
            children: [
              const SizedBox(height: 8),
              _buildToolDropdown('Circle Button 1'),
              _buildToolDropdown('Circle Button 2'),
              _buildToolDropdown('Buttons 1 + 2'),
              _buildToolDropdown('Dial'),
              const SizedBox(height: 24),
              if (_responseMessage.isNotEmpty)
                Card(
                  color: _responseMessage.contains('❌') ? 
                         Colors.red.shade50 : 
                         _responseMessage.contains('✅') ? Colors.green.shade50 : Colors.blue.shade50,
                  child: Padding(
                    padding: const EdgeInsets.all(16),
                    child: Column(
                      children: [
                        Icon(
                          _responseMessage.contains('❌') ? Icons.error : Icons.check_circle,
                          color: _responseMessage.contains('❌') ? Colors.red : Colors.green,
                          size: 32,
                        ),
                        const SizedBox(height: 8),
                        Text(
                          _responseMessage,
                          style: TextStyle(
                            fontSize: 16,
                            color: _responseMessage.contains('❌') ? 
                                   Colors.red : 
                                   _responseMessage.contains('✅') ? Colors.green : Colors.blue,
                          ),
                          textAlign: TextAlign.center,
                        ),
                      ],
                    ),
                  ),
                ),
            ],
          ),
        ),
      ),
    );
  }
}
