// lib/features/industry/presentation/industry_screen.dart
import 'package:flutter/material.dart';
import 'package:mimir/core/window/window_types.dart';

/// Main screen for the Industry window
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
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(content: Text('Pop-out functionality to be implemented')),
                );
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