import 'package:flutter/material.dart';

class HelpView extends StatefulWidget {
  const HelpView({super.key});

  @override
  State<HelpView> createState() => _HelpViewState();
}

class _HelpViewState extends State<HelpView> {
  bool isTutorialExpanded = false;
  bool isFaqExpanded = false;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Help'),
      ),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          _buildExpandableSection(
            title: 'First Time Tutorial',
            icon: Icons.school_outlined,
            isExpanded: isTutorialExpanded,
            onTap: () {
              setState(() {
                isTutorialExpanded = !isTutorialExpanded;
              });
            },
            child: _buildTutorialContent(),
          ),
          const SizedBox(height: 16),
          _buildExpandableSection(
            title: 'FAQ',
            icon: Icons.help_outline,
            isExpanded: isFaqExpanded,
            onTap: () {
              setState(() {
                isFaqExpanded = !isFaqExpanded;
              });
            },
            child: _buildFaqContent(context),
          ),
        ],
      ),
    );
  }

  Widget _buildExpandableSection({
    required String title,
    required IconData icon,
    required bool isExpanded,
    required VoidCallback onTap,
    required Widget child,
  }) {
    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.05),
            blurRadius: 4,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Column(
        children: [
          InkWell(
            onTap: onTap,
            borderRadius: BorderRadius.circular(12),
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Row(
                children: [
                  Icon(icon, color: const Color(0xFF663399), size: 28),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Text(
                      title,
                      style: const TextStyle(
                        fontSize: 20,
                        fontWeight: FontWeight.bold,
                        color: Color(0xFF663399),
                      ),
                    ),
                  ),
                  Icon(
                    isExpanded ? Icons.expand_less : Icons.expand_more,
                    color: const Color(0xFF663399),
                  ),
                ],
              ),
            ),
          ),
          if (isExpanded)
            Container(
              padding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
              child: child,
            ),
        ],
      ),
    );
  }

  Widget _buildTutorialContent() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Divider(),
        const SizedBox(height: 8),
        _buildTutorialStep(
          title: 'First Time Setup',
          steps: [
            'Power on your device',
            'Open Settings > Bluetooth on iPad',
            'Tap XIAO Keyboard to pair',
            'Wait for Connected status',
          ],
        ),
        const SizedBox(height: 24),
        _buildTutorialStep(
          title: 'Configure Your Buttons',
          steps: [
            'Tap scan icon in this app',
            'Select XIAO Keyboard from list',
            'Change button functions as needed',
            'Settings save automatically',
          ],
        ),
        const SizedBox(height: 24),
        _buildTutorialStep(
          title: 'Daily Use',
          steps: [
            'Check Settings > Bluetooth shows Connected',
            'Open Procreate and start drawing',
            'Use this app only to change settings',
            'Tap help icon for troubleshooting',
          ],
        ),
      ],
    );
  }

  Widget _buildTutorialStep({
    required String title,
    required List<String> steps,
  }) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          title,
          style: const TextStyle(
            fontSize: 18,
            fontWeight: FontWeight.bold,
            color: Color(0xFF663399),
          ),
        ),
        const SizedBox(height: 12),
        ...steps.asMap().entries.map((entry) {
          final index = entry.key;
          final step = entry.value;
          return Padding(
            padding: const EdgeInsets.only(bottom: 8),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Container(
                  width: 24,
                  height: 24,
                  decoration: const BoxDecoration(
                    color: Color(0xFF663399),
                    shape: BoxShape.circle,
                  ),
                  child: Center(
                    child: Text(
                      '${index + 1}',
                      style: const TextStyle(
                        color: Colors.white,
                        fontSize: 12,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Text(
                    step,
                    style: const TextStyle(fontSize: 15),
                  ),
                ),
              ],
            ),
          );
        }),
      ],
    );
  }

  Widget _buildFaqContent(BuildContext context) {
    return Column(
      children: [
        const Divider(),
        const SizedBox(height: 8),
        _buildCategoryTile(
          context,
          icon: Icons.wifi_find,
          title: 'Connection Issues',
          subtitle: 'Cannot find or connect to device',
          issues: [
            HelpIssue(
              title: 'Cannot find device when scanning',
              steps: [
                'Turn device off using power button',
                'Wait 10 seconds',
                'Turn device back on',
                'Move iPad within 3 feet of device',
                'Open Settings > Bluetooth and verify it is ON',
                'Return to app and tap scan icon',
                'Wait 10 seconds for device to appear',
              ],
            ),
            HelpIssue(
              title: 'Device in Settings but not in app',
              steps: [
                'Check Settings > Bluetooth shows XIAO Keyboard Connected',
                'In this app, tap scan icon',
                'Device should appear in list',
                'Tap device to connect',
              ],
            ),
            HelpIssue(
              title: 'App disconnects randomly',
              steps: [
                'Keep app in foreground while configuring',
                'Complete all changes quickly',
                'Tap X button to disconnect properly',
                'Close app after disconnecting',
                'Keyboard continues working in Settings',
              ],
            ),
          ],
        ),
        _buildCategoryTile(
          context,
          icon: Icons.touch_app,
          title: 'Button Problems',
          subtitle: 'Buttons not working in Procreate',
          issues: [
            HelpIssue(
              title: 'Physical buttons do nothing',
              steps: [
                'Open Settings > Bluetooth',
                'Find XIAO Keyboard in MY DEVICES',
                'Status must show Connected',
                'If Not Connected, tap device name',
                'Wait for Connected status',
                'Open Procreate and test buttons',
              ],
            ),
            HelpIssue(
              title: 'Dial does not change brush size',
              steps: [
                'Open this app and connect to device',
                'Check Dial setting shows Brush Size 10% or Brush Size 5%',
                'In Procreate, select brush tool',
                'Rotate dial clockwise to increase size',
                'Rotate dial counter-clockwise to decrease size',
              ],
            ),
          ],
        ),
        _buildCategoryTile(
          context,
          icon: Icons.settings,
          title: 'Configuration Issues',
          subtitle: 'Settings not saving or loading',
          issues: [
            HelpIssue(
              title: 'Settings revert after closing app',
              steps: [
                'Wait for Config saved successfully message',
                'Wait 3 seconds before testing',
                'Open Procreate and test button',
                'If still wrong, repeat configuration',
                'Settings save automatically to device memory',
              ],
            ),
            HelpIssue(
              title: 'App shows no configuration',
              steps: [
                'Wait 5 seconds after connection',
                'Tap X button to disconnect',
                'Wait 3 seconds',
                'Tap scan icon and reconnect',
                'Device sends configuration automatically',
              ],
            ),
          ],
        ),
        _buildCategoryTile(
          context,
          icon: Icons.bluetooth_disabled,
          title: 'Bluetooth Problems',
          subtitle: 'Pairing or permission issues',
          issues: [
            HelpIssue(
              title: 'Bluetooth is turned off',
              steps: [
                'Open Settings app',
                'Tap Bluetooth',
                'Toggle Bluetooth switch to ON',
                'Return to this app',
                'Tap scan icon',
              ],
            ),
            HelpIssue(
              title: 'No Bluetooth permission',
              steps: [
                'Open Settings app',
                'Tap Privacy & Security',
                'Tap Bluetooth',
                'Find eSketch Shortcuts in list',
                'Toggle switch to ON',
                'Return to this app',
                'Tap scan icon',
              ],
            ),
          ],
        ),
      ],
    );
  }

  Widget _buildCategoryTile(
    BuildContext context, {
    required IconData icon,
    required String title,
    required String subtitle,
    required List<HelpIssue> issues,
  }) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: ListTile(
        leading: Icon(icon, color: const Color(0xFF663399), size: 32),
        title: Text(
          title,
          style: const TextStyle(fontWeight: FontWeight.bold),
        ),
        subtitle: Text(subtitle),
        trailing: const Icon(Icons.chevron_right),
        onTap: () {
          Navigator.push(
            context,
            MaterialPageRoute(
              builder: (context) => IssueListView(
                category: title,
                issues: issues,
              ),
            ),
          );
        },
      ),
    );
  }
}

class HelpIssue {
  final String title;
  final List<String> steps;

  const HelpIssue({
    required this.title,
    required this.steps,
  });
}

class IssueListView extends StatelessWidget {
  final String category;
  final List<HelpIssue> issues;

  const IssueListView({
    super.key,
    required this.category,
    required this.issues,
  });

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text(category),
      ),
      body: ListView.builder(
        itemCount: issues.length,
        itemBuilder: (context, index) {
          final issue = issues[index];
          return ListTile(
            title: Text(issue.title),
            trailing: const Icon(Icons.chevron_right),
            onTap: () {
              Navigator.push(
                context,
                MaterialPageRoute(
                  builder: (context) => SolutionView(issue: issue),
                ),
              );
            },
          );
        },
      ),
    );
  }
}

class SolutionView extends StatelessWidget {
  final HelpIssue issue;

  const SolutionView({
    super.key,
    required this.issue,
  });

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Solution'),
      ),
      body: Container(
        color: const Color(0xFFF2F2F7),
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              issue.title,
              style: const TextStyle(
                fontSize: 24,
                fontWeight: FontWeight.bold,
                color: Color(0xFF663399),
              ),
            ),
            const SizedBox(height: 24),
            ...issue.steps.asMap().entries.map((entry) {
              final index = entry.key;
              final step = entry.value;
              return Padding(
                padding: const EdgeInsets.only(bottom: 16),
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Container(
                      width: 24,
                      height: 24,
                      decoration: const BoxDecoration(
                        color: Color(0xFF663399),
                        shape: BoxShape.circle,
                      ),
                      child: Center(
                        child: Text(
                          '${index + 1}',
                          style: const TextStyle(
                            color: Colors.white,
                            fontSize: 14,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Text(
                        step,
                        style: const TextStyle(fontSize: 16),
                      ),
                    ),
                  ],
                ),
              );
            }),
          ],
        ),
      ),
    );
  }
}
