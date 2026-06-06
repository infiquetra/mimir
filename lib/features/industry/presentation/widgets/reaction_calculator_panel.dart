import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../core/theme/eve_colors.dart';
import '../../../../core/widgets/eve_card.dart';
import '../../domain/reaction_calculator.dart';

/// Form to calculate reaction yields.
class ReactionCalculatorPanel extends ConsumerStatefulWidget {
  const ReactionCalculatorPanel({super.key});

  @override
  ConsumerState<ReactionCalculatorPanel> createState() => _ReactionCalculatorPanelState();
}

class _ReactionCalculatorPanelState extends ConsumerState<ReactionCalculatorPanel> {
  int _runs = 1;
  double _facilityMaterialBonus = 0.0;
  
  // Dummy base inputs and outputs for testing
  final Map<int, int> _baseInputs = {
    16641: 100, // Sylramic Gels
    16642: 100, // Fullerides
    16643: 100, // Nanites
  };
  final Map<int, int> _baseOutputs = {
    16654: 10,  // Ferrogel
  };

  @override
  Widget build(BuildContext context) {
    final inputs = ReactionCalculator.calculateInputs(
      _baseInputs,
      _runs,
      facilityMaterialBonus: _facilityMaterialBonus,
    );
    final outputs = ReactionCalculator.calculateOutputs(_baseOutputs, _runs);

    return ListView(
      children: [
        EveCard(
          child: Padding(
            padding: const EdgeInsets.all(16.0),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    const Icon(Icons.settings, color: EveColors.evePrimary, size: 20),
                    const SizedBox(width: 8),
                    Text(
                      'JOB SETTINGS',
                      style: Theme.of(context).textTheme.titleSmall?.copyWith(
                        color: EveColors.evePrimary,
                        fontWeight: FontWeight.bold,
                        letterSpacing: 1,
                      ),
                    ),
                  ],
                ),
                const Divider(color: EveColors.borderSubtle),
                const SizedBox(height: 8),
                Row(
                  children: [
                    SizedBox(width: 150, child: Text('Runs:', style: Theme.of(context).textTheme.bodyMedium)),
                    Expanded(
                      child: Slider(
                        value: _runs.toDouble(),
                        min: 1,
                        max: 100,
                        divisions: 99,
                        label: '$_runs runs',
                        onChanged: (v) => setState(() => _runs = v.toInt()),
                      ),
                    ),
                    SizedBox(width: 40, child: Text('$_runs', textAlign: TextAlign.end)),
                  ],
                ),
                const SizedBox(height: 16),
                Row(
                  children: [
                    SizedBox(width: 150, child: Text('Facility Bonus:', style: Theme.of(context).textTheme.bodyMedium)),
                    Expanded(
                      child: DropdownButtonFormField<double>(
                        isExpanded: true,
                        value: _facilityMaterialBonus,
                        decoration: const InputDecoration(
                          border: OutlineInputBorder(),
                          contentPadding: EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                        ),
                        items: const [
                          DropdownMenuItem(value: 0.0, child: Text('No Bonus (0%)')),
                          DropdownMenuItem(value: 0.02, child: Text('Athanor (2%)')),
                          DropdownMenuItem(value: 0.024, child: Text('Athanor T1 Rig (2.4%)')),
                          DropdownMenuItem(value: 0.028, child: Text('Athanor T2 Rig (2.8%)')),
                          DropdownMenuItem(value: 0.04, child: Text('Tatara (4%)')),
                          DropdownMenuItem(value: 0.048, child: Text('Tatara T1 Rig (4.8%)')),
                          DropdownMenuItem(value: 0.056, child: Text('Tatara T2 Rig (5.6%)')),
                        ],
                        onChanged: (v) {
                          if (v != null) setState(() => _facilityMaterialBonus = v);
                        },
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ),
        const SizedBox(height: 16),
        Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Expanded(
              child: EveCard(
                child: Padding(
                  padding: const EdgeInsets.all(16.0),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          const Icon(Icons.arrow_downward, color: EveColors.error, size: 20),
                          const SizedBox(width: 8),
                          Expanded(
                            child: Text(
                              'INPUT MATERIALS',
                              style: Theme.of(context).textTheme.titleSmall?.copyWith(
                                    color: EveColors.error,
                                    fontWeight: FontWeight.bold,
                                    letterSpacing: 1,
                                  ),
                              overflow: TextOverflow.ellipsis,
                            ),
                          ),
                        ],
                      ),
                      const Divider(color: EveColors.borderSubtle),
                      ...inputs.entries.map((e) => Padding(
                            padding: const EdgeInsets.symmetric(vertical: 4.0),
                            child: Row(
                              mainAxisAlignment: MainAxisAlignment.spaceBetween,
                              children: [
                                Text('Item #${e.key}'),
                                Text(
                                  '${e.value}',
                                  style: const TextStyle(fontWeight: FontWeight.bold),
                                ),
                              ],
                            ),
                          )),
                    ],
                  ),
                ),
              ),
            ),
            const SizedBox(width: 16),
            Expanded(
              child: EveCard(
                child: Padding(
                  padding: const EdgeInsets.all(16.0),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          const Icon(Icons.arrow_upward, color: EveColors.success, size: 20),
                          const SizedBox(width: 8),
                          Expanded(
                            child: Text(
                              'OUTPUT PRODUCTS',
                              style: Theme.of(context).textTheme.titleSmall?.copyWith(
                                    color: EveColors.success,
                                    fontWeight: FontWeight.bold,
                                    letterSpacing: 1,
                                  ),
                              overflow: TextOverflow.ellipsis,
                            ),
                          ),
                        ],
                      ),
                      const Divider(color: EveColors.borderSubtle),
                      ...outputs.entries.map((e) => Padding(
                            padding: const EdgeInsets.symmetric(vertical: 4.0),
                            child: Row(
                              mainAxisAlignment: MainAxisAlignment.spaceBetween,
                              children: [
                                Text('Item #${e.key}'),
                                Text(
                                  '${e.value}',
                                  style: const TextStyle(fontWeight: FontWeight.bold),
                                ),
                              ],
                            ),
                          )),
                    ],
                  ),
                ),
              ),
            ),
          ],
        ),
      ],
    );
  }
}
