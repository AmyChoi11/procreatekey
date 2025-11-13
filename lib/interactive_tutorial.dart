import 'package:flutter/material.dart';

class InteractiveTutorial extends StatefulWidget {
  final VoidCallback onComplete;
  final GlobalKey? button1Key;
  final GlobalKey? button2Key;
  final GlobalKey? scrollKey;
  final GlobalKey? comboKey;

  const InteractiveTutorial({
    super.key,
    required this.onComplete,
    this.button1Key,
    this.button2Key,
    this.scrollKey,
    this.comboKey,
  });

  @override
  State<InteractiveTutorial> createState() => _InteractiveTutorialState();
}

class _InteractiveTutorialState extends State<InteractiveTutorial> {
  int currentStep = 0;
  bool isHighlightActive = false;

  final List<TutorialStep> steps = [
    // Step 1: Bluetooth Settings
    TutorialStep(
      title: 'First Time Setup',
      description: 'Open Settings > Bluetooth on your iPad and pair "XIAO Keyboard"',
      highlightArea: null,
      icon: Icons.bluetooth,
      actionRequired: false,
    ),
    // Step 2: Scan for Device
    TutorialStep(
      title: 'Connect Your Device',
      description: 'Tap the scan icon to find your device',
      highlightArea: HighlightArea.scanButton,
      icon: null,
      actionRequired: true,
    ),
    // Step 3: Button 1
    TutorialStep(
      title: 'Configure Button 1',
      description: 'Tap Button 1 (blue circle) to change its function. Try setting it to Undo!',
      highlightArea: HighlightArea.button1,
      icon: null,
      actionRequired: true,
    ),
    // Step 4: Button 2
    TutorialStep(
      title: 'Configure Button 2',
      description: 'Tap Button 2 (red circle) to set it to Redo',
      highlightArea: HighlightArea.button2,
      icon: null,
      actionRequired: true,
    ),
    // Step 5: Scroll
    TutorialStep(
      title: 'Configure Scroll Wheel',
      description: 'Tap the scroll wheel (purple pill) to control brush size',
      highlightArea: HighlightArea.scroll,
      icon: null,
      actionRequired: true,
    ),
    // Step 6: Combo Button
    TutorialStep(
      title: 'Configure Combo Action',
      description: 'Tap "Buttons 1 + 2 Combo" to set what happens when you press both buttons together',
      highlightArea: HighlightArea.combo,
      icon: null,
      actionRequired: true,
    ),
    // Step 7: Complete
    TutorialStep(
      title: 'You\'re All Set!',
      description: 'Open Procreate and start drawing. Your buttons are ready to use!',
      highlightArea: null,
      icon: Icons.check_circle,
      actionRequired: false,
    ),
  ];

  void _nextStep() {
    if (currentStep < steps.length - 1) {
      setState(() {
        currentStep++;
        isHighlightActive = true;
      });
    } else {
      widget.onComplete();
    }
  }

  void _skipTutorial() {
    widget.onComplete();
  }

  @override
  Widget build(BuildContext context) {
    final step = steps[currentStep];
    final screenWidth = MediaQuery.of(context).size.width;
    final screenHeight = MediaQuery.of(context).size.height;
    
    // Get actual widget positions if keys are provided
    RenderBox? getBox(GlobalKey? key) {
      if (key?.currentContext != null) {
        return key!.currentContext!.findRenderObject() as RenderBox?;
      }
      return null;
    }
    
    Offset? getPosition(GlobalKey? key) {
      final box = getBox(key);
      if (box != null) {
        return box.localToGlobal(Offset.zero);
      }
      return null;
    }
    
    Size? getSize(GlobalKey? key) {
      final box = getBox(key);
      return box?.size;
    }
    
    return Material(
      color: Colors.transparent,
      child: Stack(
        children: [
          // Dark overlay
          Container(
            color: Colors.black.withOpacity(0.85),
          ),
          
          // Highlight area with tooltip (if specified)
          if (step.highlightArea != null)
            _buildHighlightWithTooltip(
              step.highlightArea!,
              step.title,
              step.description,
              getPosition,
              getSize,
              screenWidth,
              screenHeight,
            ),
          
          // Tutorial content card (only for non-interactive steps)
          if (step.highlightArea == null)
            Positioned(
              bottom: 80,
              left: 20,
              right: 20,
              child: Container(
                padding: const EdgeInsets.all(24),
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(16),
                  boxShadow: [
                    BoxShadow(
                      color: Colors.black.withOpacity(0.3),
                      blurRadius: 20,
                      offset: const Offset(0, 10),
                    ),
                  ],
                ),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    // Progress indicator
                    Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: List.generate(
                        steps.length,
                        (index) => Container(
                          margin: const EdgeInsets.symmetric(horizontal: 4),
                          width: 8,
                          height: 8,
                          decoration: BoxDecoration(
                            shape: BoxShape.circle,
                            color: currentStep == index
                                ? const Color(0xFF663399)
                                : Colors.grey.shade300,
                          ),
                        ),
                      ),
                    ),
                    const SizedBox(height: 20),
                    
                    // Icon (if provided)
                    if (step.icon != null)
                      Container(
                        height: 80,
                        width: 80,
                        decoration: BoxDecoration(
                          color: const Color(0xFF663399).withOpacity(0.1),
                          shape: BoxShape.circle,
                        ),
                        child: Icon(
                          step.icon!,
                          size: 48,
                          color: const Color(0xFF663399),
                        ),
                      ),
                    
                    const SizedBox(height: 16),
                    
                    // Title
                    Text(
                      step.title,
                      style: const TextStyle(
                        fontSize: 22,
                        fontWeight: FontWeight.bold,
                        color: Color(0xFF663399),
                      ),
                      textAlign: TextAlign.center,
                    ),
                    const SizedBox(height: 12),
                    
                    // Description
                    Text(
                      step.description,
                      style: const TextStyle(
                        fontSize: 15,
                        color: Colors.black87,
                      ),
                      textAlign: TextAlign.center,
                    ),
                    const SizedBox(height: 20),
                    
                    // Action button
                    ElevatedButton(
                      onPressed: _nextStep,
                      style: ElevatedButton.styleFrom(
                        backgroundColor: const Color(0xFF663399),
                        foregroundColor: Colors.white,
                        padding: const EdgeInsets.symmetric(
                          horizontal: 40,
                          vertical: 16,
                        ),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(12),
                        ),
                      ),
                      child: Text(
                        currentStep == steps.length - 1 ? 'Get Started' : 'Next',
                        style: const TextStyle(fontSize: 18, fontWeight: FontWeight.w600),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          
          // Skip button
          Positioned(
            top: 50,
            right: 20,
            child: TextButton(
              onPressed: _skipTutorial,
              style: TextButton.styleFrom(
                backgroundColor: Colors.white.withOpacity(0.2),
                foregroundColor: Colors.white,
                padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 10),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(20),
                ),
              ),
              child: const Text(
                'Skip',
                style: TextStyle(fontSize: 16, fontWeight: FontWeight.w600),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildHighlightWithTooltip(
    HighlightArea area,
    String title,
    String description,
    Offset? Function(GlobalKey?) getPosition,
    Size? Function(GlobalKey?) getSize,
    double screenWidth,
    double screenHeight,
  ) {
    // Get actual positions from keys
    Offset? position;
    Size? size;
    GlobalKey? targetKey;
    
    switch (area) {
      case HighlightArea.button1:
        targetKey = widget.button1Key;
        break;
      case HighlightArea.button2:
        targetKey = widget.button2Key;
        break;
      case HighlightArea.scroll:
        targetKey = widget.scrollKey;
        break;
      case HighlightArea.combo:
        targetKey = widget.comboKey;
        break;
      case HighlightArea.scanButton:
        // Use fixed position for scan button
        position = const Offset(8, 50);
        size = const Size(48, 48);
        break;
    }
    
    if (targetKey != null) {
      position = getPosition(targetKey);
      size = getSize(targetKey);
    }
    
    // Fallback if position not found
    if (position == null || size == null) {
      position = Offset(screenWidth / 2 - 50, screenHeight / 2 - 50);
      size = const Size(100, 100);
    }
    
    // Calculate tooltip position (above or below the highlighted element)
    final tooltipWidth = screenWidth - 40.0;
    final tooltipLeft = 20.0;
    final spaceAbove = position.dy;
    final spaceBelow = screenHeight - (position.dy + size.height);
    
    // Place tooltip above if there's more space, otherwise below
    final bool placeAbove = spaceAbove > spaceBelow && spaceAbove > 150;
    final double tooltipTop = placeAbove
        ? position.dy - 140  // Above the element
        : position.dy + size.height + 20;  // Below the element
    
    return Stack(
      children: [
        // Highlight border around actual element
        Positioned(
          left: position.dx - 8,
          top: position.dy - 8,
          child: GestureDetector(
            onTap: _nextStep,
            child: Container(
              width: size.width + 16,
              height: size.height + 16,
              decoration: BoxDecoration(
                color: Colors.transparent,
                border: Border.all(
                  color: const Color(0xFF663399),
                  width: 3,
                ),
                borderRadius: BorderRadius.circular(
                  area == HighlightArea.button1 || area == HighlightArea.button2
                      ? 50
                      : 12,
                ),
                boxShadow: [
                  BoxShadow(
                    color: const Color(0xFF663399).withOpacity(0.6),
                    blurRadius: 20,
                    spreadRadius: 5,
                  ),
                ],
              ),
            ),
          ),
        ),
        
        // Compact tooltip near the element
        Positioned(
          left: tooltipLeft,
          top: tooltipTop,
          child: GestureDetector(
            onTap: _nextStep,
            child: Container(
              width: tooltipWidth,
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: const Color(0xFF663399),
                borderRadius: BorderRadius.circular(12),
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withOpacity(0.3),
                    blurRadius: 15,
                    offset: const Offset(0, 5),
                  ),
                ],
              ),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // Progress dots
                  Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: List.generate(
                      steps.length,
                      (index) => Container(
                        margin: const EdgeInsets.symmetric(horizontal: 3),
                        width: 6,
                        height: 6,
                        decoration: BoxDecoration(
                          shape: BoxShape.circle,
                          color: currentStep == index
                              ? Colors.white
                              : Colors.white.withOpacity(0.3),
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(height: 12),
                  
                  // Title
                  Text(
                    title,
                    style: const TextStyle(
                      fontSize: 18,
                      fontWeight: FontWeight.bold,
                      color: Colors.white,
                    ),
                  ),
                  const SizedBox(height: 6),
                  
                  // Description
                  Text(
                    description,
                    style: const TextStyle(
                      fontSize: 14,
                      color: Colors.white,
                      height: 1.3,
                    ),
                  ),
                  const SizedBox(height: 12),
                  
                  // Tap instruction
                  Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      const Icon(Icons.touch_app, color: Colors.white, size: 18),
                      const SizedBox(width: 6),
                      Text(
                        'Tap to continue',
                        style: TextStyle(
                          fontSize: 13,
                          color: Colors.white.withOpacity(0.9),
                          fontStyle: FontStyle.italic,
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ),
        ),
      ],
    );
  }
}

class TutorialStep {
  final String title;
  final String description;
  final HighlightArea? highlightArea;
  final IconData? icon;
  final bool actionRequired;

  TutorialStep({
    required this.title,
    required this.description,
    this.highlightArea,
    this.icon,
    required this.actionRequired,
  });
}

enum HighlightArea {
  scanButton,
  button1,
  button2,
  scroll,
  combo,
}
