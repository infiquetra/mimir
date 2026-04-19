// lib/core/window/window_types.dart
import 'package:flutter/material.dart';

/// Abstract base class for all window types in the application
abstract class WindowType {
  final String id;
  final String title;
  final IconData icon;

  WindowType({
    required this.id,
    required this.title,
    required this.icon,
  });

  /// Build the content widget for this window
  Widget buildContent(BuildContext context);

  /// Called when the window is opened
  void onOpen() {}

  /// Called when the window is closed
  void onClose() {}

  /// Whether this window supports tabs
  bool get supportsTabs => false;

  /// Whether this window supports pop-out functionality
  bool get supportsPopOut => false;
}

/// Industry window type implementation
class IndustryWindow extends WindowType {
  IndustryWindow()
      : super(
          id: 'industry',
          title: 'Industry',
          icon: Icons.factory_outlined,
        );

  @override
  bool get supportsTabs => true;

  @override
  bool get supportsPopOut => true;

  @override
  Widget buildContent(BuildContext context) {
    return const IndustryScreen();
  }
}

/// Base screen widget for the Industry window
class IndustryScreen extends StatefulWidget {
  const IndustryScreen({super.key});

  @override
  State<IndustryScreen> createState() => _IndustryScreenState();
}

class _IndustryScreenState extends State<IndustryScreen> {
  @override
  Widget build(BuildContext context) {
    return DefaultTabController(
      length: 2,
      child: Scaffold(
        appBar: AppBar(
          title: const Text('Industry'),
          bottom: const TabBar(
            tabs: [
              Tab(text: 'BOM Calculator'),
              Tab(text: 'Jobs'),
            ],
          ),
          actions: [
            IconButton(
              icon: const Icon(Icons.open_in_new),
              onPressed: () {
                // TODO: Implement pop-out functionality
              },
            ),
          ],
        ),
        body: const TabBarView(
          children: [
            BomCalculatorScreen(),
            Text('Jobs content will be implemented in a separate task'),
          ],
        ),
      ),
    );
  }
}

/// BOM Calculator screen widget
class BomCalculatorScreen extends StatefulWidget {
  const BomCalculatorScreen({super.key});

  @override
  State<BomCalculatorScreen> createState() => _BomCalculatorScreenState();
}

class _BomCalculatorScreenState extends State<BomCalculatorScreen> {
  final TextEditingController _searchController = TextEditingController();

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        Padding(
          padding: const EdgeInsets.all(16.0),
          child: TextField(
            controller: _searchController,
            decoration: const InputDecoration(
              labelText: 'Search for item...',
              border: OutlineInputBorder(),
              prefixIcon: Icon(Icons.search),
            ),
          ),
        ),
        Expanded(
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              const Icon(
                Icons.account_tree,
                size: 100,
                color: Colors.grey,
              ),
              const SizedBox(height: 16),
              const Text(
                'BOM Calculator',
                style: TextStyle(fontSize: 24, fontWeight: FontWeight.bold),
              ),
              const SizedBox(height: 8),
              const Text(
                'Select an item to calculate its bill of materials',
                style: TextStyle(color: Colors.grey),
              ),
              const SizedBox(height: 32),
              ElevatedButton.icon(
                onPressed: () {
                  // TODO: Implement item search functionality
                },
                icon: const Icon(Icons.search),
                label: const Text('Browse Items'),
              ),
              const SizedBox(height: 16),
              const Divider(),
              const SizedBox(height: 16),
              const Text(
                'Shopping List',
                style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
              ),
              const SizedBox(height: 8),
              const Text(
                'Calculated materials will appear here',
                style: TextStyle(color: Colors.grey),
              ),
              const SizedBox(height: 16),
              OutlinedButton.icon(
                onPressed: null, // Disable until items are selected
                icon: const Icon(Icons.content_copy),
                label: const Text('Copy to Clipboard'),
              ),
            ],
          ),
        ),
      ],
    );
  }

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }
}