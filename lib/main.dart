import 'package:flutter/material.dart';
import 'help_view.dart';
import 'interactive_tutorial.dart';

void main() {
  runApp(const ESketchApp());
}

class ESketchApp extends StatelessWidget {
  const ESketchApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'eSketch Shortcuts',
      debugShowCheckedModeBanner: false,
      theme: ThemeData(
        primaryColor: const Color(0xFF663399),
        scaffoldBackgroundColor: const Color(0xFFF2F2F7),
        appBarTheme: const AppBarTheme(
          backgroundColor: Color(0xFF663399),
          foregroundColor: Colors.white,
          elevation: 0,
        ),
      ),
      home: const MainView(),
    );
  }
}

class MainView extends StatefulWidget {
  const MainView({super.key});

  @override
  State<MainView> createState() => _MainViewState();
}

class _MainViewState extends State<MainView> {
  bool hasCompletedOnboarding = false;
  bool showInteractiveTutorial = false;
  bool isConnected = false;
  bool isScanning = false;
  String statusMessage = '';
  
  Map<String, int> config = {
    'button1': 3,  // Undo
    'button2': 4,  // Redo
    'combo': 7,    // Color Palette
    'dial': 9,     // Brush Size (10%)
  };

  // Preset storage (simulated with local state)
  Map<String, int>? preset1;
  Map<String, int>? preset2;
  
  // GlobalKeys for tutorial highlighting
  final GlobalKey button1Key = GlobalKey();
  final GlobalKey button2Key = GlobalKey();
  final GlobalKey scrollKey = GlobalKey();
  final GlobalKey comboKey = GlobalKey();

  @override
  void initState() {
    super.initState();
    Future.delayed(Duration.zero, () {
      if (!hasCompletedOnboarding) {
        setState(() {
          showInteractiveTutorial = true;
        });
      }
    });
  }

  void _showHelp() {
    Navigator.push(
      context,
      MaterialPageRoute(builder: (context) => const HelpView()),
    );
  }

  void _simulateConnect() {
    setState(() {
      isScanning = true;
      statusMessage = 'Scanning...';
    });
    
    Future.delayed(const Duration(seconds: 2), () {
      if (mounted) {
        setState(() {
          isScanning = false;
          isConnected = true;
          statusMessage = 'Connected to XIAO Keyboard';
        });
      }
    });
  }

  void _disconnect() {
    setState(() {
      isConnected = false;
      statusMessage = 'Disconnected';
    });
  }

  @override
  Widget build(BuildContext context) {
    return Stack(
      children: [
        Scaffold(
          appBar: AppBar(
        title: const Text('eSketch Shortcuts'),
        leading: Padding(
          padding: const EdgeInsets.only(left: 8),
          child: Row(
            children: [
              // Bluetooth Scan/Connect button
              TextButton.icon(
                onPressed: isScanning ? null : (isConnected ? _disconnect : _simulateConnect),
                icon: Icon(
                  Icons.bluetooth,
                  color: isConnected ? Colors.green : const Color(0xFF663399),
                  size: 16,
                ),
                label: Text(
                  isConnected ? 'Connected' : 'Scan',
                  style: TextStyle(
                    color: isConnected ? Colors.green : const Color(0xFF663399),
                    fontSize: 15,
                    fontWeight: FontWeight.w600,
                  ),
                ),
                style: TextButton.styleFrom(
                  backgroundColor: Colors.white.withOpacity(0.9),
                  padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(8),
                    side: BorderSide(
                      color: isConnected 
                        ? Colors.green.withOpacity(0.6)
                        : const Color(0xFF663399).withOpacity(0.6),
                      width: 1.5,
                    ),
                  ),
                ),
              ),
              const SizedBox(width: 4),
              IconButton(
                icon: const Icon(Icons.help_outline),
                onPressed: _showHelp,
                tooltip: 'Help',
              ),
            ],
          ),
        ),
        leadingWidth: 170,
        actions: [
          // Presets button
          TextButton.icon(
            onPressed: () => _showPresetsMenu(context),
            icon: const Icon(Icons.list, color: Color(0xFF663399), size: 16),
            label: const Text(
              'Presets',
              style: TextStyle(color: Color(0xFF663399), fontSize: 15, fontWeight: FontWeight.w600),
            ),
            style: TextButton.styleFrom(
              backgroundColor: Colors.white.withOpacity(0.9),
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(8),
                side: BorderSide(color: const Color(0xFF663399).withOpacity(0.6), width: 1.5),
              ),
            ),
          ),
          const SizedBox(width: 8),
        ],
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.center,
          children: [
            // Controller Configuration Section
            const Text(
              'Controller Configuration',
              style: TextStyle(
                fontSize: 24,
                fontWeight: FontWeight.bold,
                color: Color(0xFF663399),
              ),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 20),
            
            // Controller Diagram
            Container(
              height: 350,
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(25),
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withOpacity(0.1),
                    blurRadius: 8,
                    offset: const Offset(0, 4),
                  ),
                ],
              ),
              child: Stack(
                children: [
                  // Controller outline
                  CustomPaint(
                    size: const Size(double.infinity, 350),
                    painter: ControllerOutlinePainter(),
                  ),
                  // Connection lines
                  CustomPaint(
                    size: const Size(double.infinity, 350),
                    painter: ConnectionLinesPainter(),
                  ),
                  // Interactive elements
                  Column(
                    children: [
                      const SizedBox(height: 50),
                      // Buttons 1+2 Combo button
                      ElevatedButton(
                        key: comboKey,
                        onPressed: () => _showOptionsMenu(context, 'combo'),
                        style: ElevatedButton.styleFrom(
                          backgroundColor: Colors.orange,
                          foregroundColor: Colors.white,
                          padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
                        ),
                        child: const Text('Buttons 1 + 2 Combo', style: TextStyle(fontSize: 18, fontWeight: FontWeight.w600)),
                      ),
                      const SizedBox(height: 50),
                      // Bottom row: Button 1, Scroll, Button 2
                      Row(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          // Button 1
                          _buildButton1Widget(),
                          const SizedBox(width: 30),
                          // Scroll
                          _buildScrollWidget(),
                          const SizedBox(width: 30),
                          // Button 2
                          _buildButton2Widget(),
                        ],
                      ),
                    ],
                  ),
                ],
              ),
            ),
            
            const SizedBox(height: 20),
            
            // Save as Preset button
            ElevatedButton.icon(
              onPressed: () => _showSavePresetDialog(context),
              icon: const Icon(Icons.save, size: 16),
              label: const Text(
                'Save as Preset',
                style: TextStyle(fontSize: 16, fontWeight: FontWeight.w600),
              ),
              style: ElevatedButton.styleFrom(
                backgroundColor: Colors.green,
                foregroundColor: Colors.white,
                padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(10),
                ),
              ),
            ),
            
            const SizedBox(height: 30),
            
            // Status Message
            if (statusMessage.isNotEmpty)
              Container(
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: statusMessage.contains('successfully') || statusMessage.contains('Connected')
                      ? Colors.green.withOpacity(0.1)
                      : Colors.red.withOpacity(0.1),
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(
                    color: statusMessage.contains('successfully') || statusMessage.contains('Connected')
                        ? Colors.green.withOpacity(0.3)
                        : Colors.red.withOpacity(0.3),
                  ),
                ),
                child: Row(
                  children: [
                    Icon(
                      statusMessage.contains('successfully') || statusMessage.contains('Connected')
                          ? Icons.check_circle
                          : Icons.info,
                      color: statusMessage.contains('successfully') || statusMessage.contains('Connected')
                          ? Colors.green
                          : Colors.red,
                      size: 32,
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Text(
                        statusMessage,
                        style: TextStyle(
                          color: statusMessage.contains('successfully') || statusMessage.contains('Connected')
                              ? Colors.green.shade900
                              : Colors.red.shade900,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
          ],
        ),
      ),
    ),
    
    // Interactive Tutorial Overlay
    if (showInteractiveTutorial)
      InteractiveTutorial(
        button1Key: button1Key,
        button2Key: button2Key,
        scrollKey: scrollKey,
        comboKey: comboKey,
        onComplete: () {
          setState(() {
            showInteractiveTutorial = false;
            hasCompletedOnboarding = true;
          });
        },
      ),
    ],
  );
}

  Widget _buildButton1Widget() {
    return Column(
      key: button1Key,
      children: [
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
          decoration: BoxDecoration(
            color: Colors.blue.withOpacity(0.1),
            borderRadius: BorderRadius.circular(4),
          ),
          child: Text(
            _getCurrentSelection('button1'),
            style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w500, color: Colors.blue),
            textAlign: TextAlign.center,
          ),
        ),
        const SizedBox(height: 8),
        GestureDetector(
          onTap: () => _showOptionsMenu(context, 'button1'),
          child: Container(
            width: 80,
            height: 80,
            decoration: BoxDecoration(
              color: Colors.blue.withOpacity(0.3),
              shape: BoxShape.circle,
            ),
            child: const Center(
              child: Text('1', style: TextStyle(fontSize: 24, fontWeight: FontWeight.bold, color: Colors.blue)),
            ),
          ),
        ),
        const SizedBox(height: 8),
        const Text('Button 1', style: TextStyle(fontSize: 16, fontWeight: FontWeight.w600, color: Colors.blue)),
      ],
    );
  }

  Widget _buildButton2Widget() {
    return Column(
      key: button2Key,
      children: [
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
          decoration: BoxDecoration(
            color: Colors.red.withOpacity(0.1),
            borderRadius: BorderRadius.circular(4),
          ),
          child: Text(
            _getCurrentSelection('button2'),
            style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w500, color: Colors.red),
            textAlign: TextAlign.center,
          ),
        ),
        const SizedBox(height: 8),
        GestureDetector(
          onTap: () => _showOptionsMenu(context, 'button2'),
          child: Container(
            width: 80,
            height: 80,
            decoration: BoxDecoration(
              color: Colors.red.withOpacity(0.3),
              shape: BoxShape.circle,
            ),
            child: const Center(
              child: Text('2', style: TextStyle(fontSize: 24, fontWeight: FontWeight.bold, color: Colors.red)),
            ),
          ),
        ),
        const SizedBox(height: 8),
        const Text('Button 2', style: TextStyle(fontSize: 16, fontWeight: FontWeight.w600, color: Colors.red)),
      ],
    );
  }

  Widget _buildScrollWidget() {
    return Column(
      key: scrollKey,
      children: [
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
          decoration: BoxDecoration(
            color: const Color(0xFF663399).withOpacity(0.1),
            borderRadius: BorderRadius.circular(4),
          ),
          constraints: const BoxConstraints(maxWidth: 120),
          child: Text(
            _getCurrentSelection('dial'),
            style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w500, color: Color(0xFF663399)),
            textAlign: TextAlign.center,
          ),
        ),
        const SizedBox(height: 8),
        GestureDetector(
          onTap: () => _showOptionsMenu(context, 'dial'),
          child: Container(
            width: 60,
            height: 100,
            decoration: BoxDecoration(
              color: const Color(0xFF663399).withOpacity(0.3),
              borderRadius: BorderRadius.circular(30),
              border: Border.all(
                color: const Color(0xFF663399).withOpacity(0.5),
                width: 4,
              ),
            ),
          ),
        ),
        const SizedBox(height: 8),
        const Text('Scroll', style: TextStyle(fontSize: 16, fontWeight: FontWeight.w600, color: Color(0xFF663399))),
      ],
    );
  }

  String _getCurrentSelection(String configKey) {
    final code = config[configKey] ?? 0;
    final options = _getOptionsForKey(configKey);
    return _codeToOption(code, options);
  }

  List<String> _getOptionsForKey(String configKey) {
    switch (configKey) {
      case 'button1':
      case 'button2':
        return const ['Undo', 'Redo', 'Erase'];
      case 'combo':
        return const ['Color Palette', 'Brush Library', 'Undo', 'Redo', 'Erase'];
      case 'dial':
        return const ['Brush Size (5%)', 'Brush Size (10%)'];
      default:
        return const ['Undo'];
    }
  }

  void _showOptionsMenu(BuildContext context, String configKey) {
    final options = _getOptionsForKey(configKey);
    showModalBottomSheet(
      context: context,
      builder: (BuildContext context) {
        return Container(
          padding: const EdgeInsets.symmetric(vertical: 16),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: options.map((option) {
              return ListTile(
                title: Text(option, textAlign: TextAlign.center),
                onTap: () {
                  setState(() {
                    config[configKey] = _optionToCode(option);
                    if (isConnected) {
                      statusMessage = 'Config saved successfully';
                      Future.delayed(const Duration(seconds: 2), () {
                        if (mounted) {
                          setState(() {
                            statusMessage = 'Connected to XIAO Keyboard';
                          });
                        }
                      });
                    }
                  });
                  Navigator.pop(context);
                },
              );
            }).toList(),
          ),
        );
      },
    );
  }

  void _showPresetsMenu(BuildContext context) {
    final presets = <Map<String, dynamic>>[];
    
    if (preset1 != null) {
      presets.add({
        'name': 'Preset 1',
        'config': preset1,
        'slot': 1,
      });
    }
    
    if (preset2 != null) {
      presets.add({
        'name': 'Preset 2',
        'config': preset2,
        'slot': 2,
      });
    }

    showModalBottomSheet(
      context: context,
      builder: (BuildContext context) {
        return Container(
          padding: const EdgeInsets.all(16),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Container(
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: Colors.grey.withOpacity(0.1),
                  borderRadius: const BorderRadius.vertical(top: Radius.circular(12)),
                ),
                child: const Text(
                  'Saved Presets',
                  style: TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.bold,
                    color: Color(0xFF663399),
                  ),
                ),
              ),
              const SizedBox(height: 8),
              if (presets.isEmpty)
                const Padding(
                  padding: EdgeInsets.all(24),
                  child: Text(
                    'No presets saved',
                    style: TextStyle(color: Colors.grey),
                  ),
                )
              else
                ...presets.map((preset) {
                  final presetConfig = preset['config'] as Map<String, int>;
                  return ListTile(
                    title: Text(
                      preset['name'],
                      style: const TextStyle(fontWeight: FontWeight.w600),
                    ),
                    subtitle: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const SizedBox(height: 4),
                        Text('Button 1: ${_codeToOption(presetConfig['button1'] ?? 0, _getOptionsForKey('button1'))}', style: const TextStyle(fontSize: 12)),
                        Text('Button 2: ${_codeToOption(presetConfig['button2'] ?? 0, _getOptionsForKey('button2'))}', style: const TextStyle(fontSize: 12)),
                        Text('Buttons 1 + 2: ${_codeToOption(presetConfig['combo'] ?? 0, _getOptionsForKey('combo'))}', style: const TextStyle(fontSize: 12)),
                        Text('Scroll: ${_codeToOption(presetConfig['dial'] ?? 0, _getOptionsForKey('dial'))}', style: const TextStyle(fontSize: 12)),
                      ],
                    ),
                    onTap: () {
                      setState(() {
                        config = Map<String, int>.from(presetConfig);
                        if (isConnected) {
                          statusMessage = 'Preset ${preset['slot']} loaded successfully';
                          Future.delayed(const Duration(seconds: 2), () {
                            if (mounted) {
                              setState(() {
                                statusMessage = 'Connected to XIAO Keyboard';
                              });
                            }
                          });
                        }
                      });
                      Navigator.pop(context);
                    },
                  );
                }),
            ],
          ),
        );
      },
    );
  }

  void _showSavePresetDialog(BuildContext context) {
    showDialog(
      context: context,
      builder: (BuildContext context) {
        return AlertDialog(
          title: const Text('Save Current Configuration'),
          content: const Text('Choose a preset slot to save your current configuration'),
          actions: [
            TextButton(
              onPressed: () {
                setState(() {
                  preset1 = Map<String, int>.from(config);
                  statusMessage = 'Saved as Preset 1';
                });
                Navigator.pop(context);
                Future.delayed(const Duration(seconds: 2), () {
                  if (mounted && statusMessage == 'Saved as Preset 1') {
                    setState(() {
                      statusMessage = isConnected ? 'Connected to XIAO Keyboard' : '';
                    });
                  }
                });
              },
              child: const Text('Save as Preset 1'),
            ),
            TextButton(
              onPressed: () {
                setState(() {
                  preset2 = Map<String, int>.from(config);
                  statusMessage = 'Saved as Preset 2';
                });
                Navigator.pop(context);
                Future.delayed(const Duration(seconds: 2), () {
                  if (mounted && statusMessage == 'Saved as Preset 2') {
                    setState(() {
                      statusMessage = isConnected ? 'Connected to XIAO Keyboard' : '';
                    });
                  }
                });
              },
              child: const Text('Save as Preset 2'),
            ),
            TextButton(
              onPressed: () => Navigator.pop(context),
              child: const Text('Cancel'),
            ),
          ],
        );
      },
    );
  }

  int _optionToCode(String option) {
    switch (option) {
      case 'Undo': return 3;
      case 'Redo': return 4;
      case 'Erase': return 5;
      case 'Brush Size (5%)': return 6;
      case 'Color Palette': return 7;
      case 'Brush Library': return 8;
      case 'Brush Size (10%)': return 9;
      default: return 0;
    }
  }

  String _codeToOption(int code, List<String> validOptions) {
    String option;
    switch (code) {
      case 3: option = 'Undo'; break;
      case 4: option = 'Redo'; break;
      case 5: option = 'Erase'; break;
      case 6: option = 'Brush Size (5%)'; break;
      case 7: option = 'Color Palette'; break;
      case 8: option = 'Brush Library'; break;
      case 9: option = 'Brush Size (10%)'; break;
      default: option = validOptions.first;
    }
    return validOptions.contains(option) ? option : validOptions.first;
  }
}

// Custom painter for controller outline
class ControllerOutlinePainter extends CustomPainter {
  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = Colors.grey.withOpacity(0.3)
      ..style = PaintingStyle.stroke
      ..strokeWidth = 4;

    final bodyWidth = size.width * 0.7;
    final bodyHeight = 197.5;
    final centerX = size.width / 2;
    final centerY = size.height / 2 + 40;

    // Main body
    final bodyRect = RRect.fromRectAndRadius(
      Rect.fromCenter(
        center: Offset(centerX, centerY),
        width: bodyWidth,
        height: bodyHeight,
      ),
      const Radius.circular(23.5),
    );
    canvas.drawRRect(bodyRect, paint);

    // Left grip
    final leftGripRect = RRect.fromRectAndRadius(
      Rect.fromLTWH(
        centerX - bodyWidth / 2 - 22.5,
        centerY - 45,
        45,
        90,
      ),
      const Radius.circular(22.5),
    );
    canvas.drawRRect(leftGripRect, paint);

    // Right grip
    final rightGripRect = RRect.fromRectAndRadius(
      Rect.fromLTWH(
        centerX + bodyWidth / 2 - 22.5,
        centerY - 45,
        45,
        90,
      ),
      const Radius.circular(22.5),
    );
    canvas.drawRRect(rightGripRect, paint);
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}

// Custom painter for connection lines
class ConnectionLinesPainter extends CustomPainter {
  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = Colors.orange
      ..style = PaintingStyle.stroke
      ..strokeWidth = 2;

    final centerX = size.width / 2;
    const buttonSpacing = 30.0;
    const button1CenterX = buttonSpacing;
    const button2CenterX = -buttonSpacing;
    
    const buttonTopY = 130.0;
    const horizontalLineY = 90.0;
    const textBottomY = 70.0;
    
    const horizontalLineStartX = button1CenterX - 40;
    const horizontalLineEndX = button2CenterX + 40;

    // Vertical lines from buttons
    canvas.drawLine(
      Offset(centerX + horizontalLineStartX, buttonTopY),
      Offset(centerX + horizontalLineStartX, horizontalLineY),
      paint,
    );
    canvas.drawLine(
      Offset(centerX + horizontalLineEndX, buttonTopY),
      Offset(centerX + horizontalLineEndX, horizontalLineY),
      paint,
    );

    // Horizontal line
    canvas.drawLine(
      Offset(centerX + horizontalLineStartX, horizontalLineY),
      Offset(centerX + horizontalLineEndX, horizontalLineY),
      paint,
    );

    // Vertical line to text
    canvas.drawLine(
      Offset(centerX, horizontalLineY),
      Offset(centerX, textBottomY),
      paint,
    );
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}
