import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../core/theme/eve_colors.dart';
import '../../../../core/widgets/eve_card.dart';
import '../../domain/production_chain_builder.dart';

/// Visualizes a production chain either as a hierarchical tree or 2D canvas.
class ProductionChainVisualizer extends ConsumerStatefulWidget {
  const ProductionChainVisualizer({super.key});

  @override
  ConsumerState<ProductionChainVisualizer> createState() => _ProductionChainVisualizerState();
}

class _ProductionChainVisualizerState extends ConsumerState<ProductionChainVisualizer> {
  bool _useCanvasView = false;
  
  // Dummy tree for testing the UI
  final ProductionNode _dummyRoot = ProductionNode(
    typeId: 28606, // Paladin
    name: 'Paladin',
    quantityRequired: 1,
    productionActivityId: 1,
    dependencies: [
      ProductionNode(
        typeId: 2004, // Apocalypse
        name: 'Apocalypse',
        quantityRequired: 1,
        productionActivityId: 1,
        dependencies: [
          ProductionNode(typeId: 34, name: 'Tritanium', quantityRequired: 12000000),
          ProductionNode(typeId: 35, name: 'Pyerite', quantityRequired: 2500000),
        ],
      ),
      ProductionNode(
        typeId: 11475, // Nanomechanical Microprocessor
        name: 'Nanomechanical Microprocessor',
        quantityRequired: 600,
        productionActivityId: 1,
        dependencies: [
          ProductionNode(
            typeId: 16650, 
            name: 'Platinum Technite', 
            quantityRequired: 3000, 
            productionActivityId: 11,
            dependencies: [
              ProductionNode(typeId: 16641, name: 'Sylramic Gels', quantityRequired: 30000),
            ],
          ),
        ],
      ),
    ],
  );

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Row(
              children: [
                const Icon(Icons.account_tree, color: EveColors.evePrimary),
                const SizedBox(width: 8),
                Text(
                  'PRODUCTION CHAIN',
                  style: Theme.of(context).textTheme.titleMedium?.copyWith(
                    color: EveColors.evePrimary,
                    fontWeight: FontWeight.bold,
                    letterSpacing: 1,
                  ),
                ),
              ],
            ),
            Row(
              children: [
                Text(
                  'Tree',
                  style: TextStyle(
                    color: !_useCanvasView ? EveColors.textPrimary : EveColors.textSecondary,
                    fontWeight: !_useCanvasView ? FontWeight.bold : FontWeight.normal,
                  ),
                ),
                Switch(
                  value: _useCanvasView,
                  activeColor: EveColors.evePrimary,
                  onChanged: (v) => setState(() => _useCanvasView = v),
                ),
                Text(
                  '2D Canvas',
                  style: TextStyle(
                    color: _useCanvasView ? EveColors.textPrimary : EveColors.textSecondary,
                    fontWeight: _useCanvasView ? FontWeight.bold : FontWeight.normal,
                  ),
                ),
              ],
            ),
          ],
        ),
        const SizedBox(height: 16),
        Expanded(
          child: _useCanvasView ? _buildCanvasView() : _buildTreeView(_dummyRoot),
        ),
      ],
    );
  }
  
  Widget _buildTreeView(ProductionNode root) {
    final flatList = <Widget>[];
    _flattenTree(root, 0, flatList);
    
    return ListView.builder(
      itemCount: flatList.length,
      itemBuilder: (context, index) => flatList[index],
    );
  }

  void _flattenTree(ProductionNode node, int depth, List<Widget> list) {
    list.add(
      Padding(
        padding: EdgeInsets.only(left: depth * 24.0, bottom: 8.0, right: 8.0),
        child: EveCard(
          child: ListTile(
            leading: Icon(
              node.isRawMaterial ? Icons.category : Icons.precision_manufacturing,
              color: node.isRawMaterial ? EveColors.textSecondary : EveColors.evePrimary,
            ),
            title: Text(
              node.name,
              style: const TextStyle(fontWeight: FontWeight.bold),
            ),
            subtitle: Text('x${node.quantityRequired} required'),
            trailing: node.productionActivityId != null
                ? Chip(
                    label: Text(
                      node.productionActivityId == 11 ? 'Reaction' : 'Manufacturing',
                      style: const TextStyle(fontSize: 12),
                    ),
                    backgroundColor: node.productionActivityId == 11 
                        ? Colors.deepPurple.withAlpha(50) 
                        : EveColors.evePrimary.withAlpha(50),
                    side: BorderSide(
                      color: node.productionActivityId == 11 
                          ? Colors.deepPurple 
                          : EveColors.evePrimary,
                    ),
                  )
                : const Chip(
                    label: Text('Raw Material', style: TextStyle(fontSize: 12)),
                    backgroundColor: Colors.transparent,
                  ),
          ),
        ),
      ),
    );
    
    for (final child in node.dependencies) {
      _flattenTree(child, depth + 1, list);
    }
  }

  Widget _buildCanvasView() {
    return Container(
      decoration: BoxDecoration(
        color: EveColors.backgroundBase,
        border: Border.all(color: EveColors.borderSubtle),
        borderRadius: BorderRadius.circular(4),
      ),
      child: Stack(
        children: [
          // Background grid
          Positioned.fill(
            child: CustomPaint(
              painter: _GridPainter(),
            ),
          ),
          const Center(
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Icon(Icons.architecture, size: 48, color: EveColors.textSecondary),
                SizedBox(height: 16),
                Text(
                  '2D Canvas Interactive Node View',
                  style: TextStyle(color: EveColors.textSecondary, fontSize: 18),
                ),
                Text(
                  'Drag and drop functionality coming in next iteration.',
                  style: TextStyle(color: EveColors.textSecondary),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _GridPainter extends CustomPainter {
  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = EveColors.borderSubtle.withAlpha(50)
      ..strokeWidth = 1.0;

    const double spacing = 40.0;
    
    for (double i = 0; i < size.width; i += spacing) {
      canvas.drawLine(Offset(i, 0), Offset(i, size.height), paint);
    }
    for (double i = 0; i < size.height; i += spacing) {
      canvas.drawLine(Offset(0, i), Offset(size.width, i), paint);
    }
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}
