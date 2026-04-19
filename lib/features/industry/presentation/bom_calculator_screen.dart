// lib/features/industry/presentation/bom_calculator_screen.dart
import 'package:flutter/material.dart';

/// BOM (Bill of Materials) Calculator screen
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
            onSubmitted: (value) {
              // TODO: Implement search functionality
              if (value.isNotEmpty) {
                ScaffoldMessenger.of(context).showSnackBar(
                  SnackBar(content: Text('Searching for: $value')),
                );
              }
            },
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
                  // TODO: Implement item browsing functionality
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(content: Text('Item browser to be implemented')),
                  );
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