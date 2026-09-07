import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../core/theme/eve_colors.dart';
import '../../../../core/widgets/eve_card.dart';
import '../../domain/invention_calculator.dart';

/// Form to calculate invention probability.
class InventionCalculatorPanel extends ConsumerStatefulWidget {
  const InventionCalculatorPanel({super.key});

  @override
  ConsumerState<InventionCalculatorPanel> createState() => _InventionCalculatorPanelState();
}

class _InventionCalculatorPanelState extends ConsumerState<InventionCalculatorPanel> {
  // Hardcoded for now. In a full implementation, these would auto-populate 
  // from the SdeService based on the selected Blueprint, and the skill levels 
  // would auto-populate from activeCharacterProvider's trained skills.
  double _baseProbability = 0.30;
  int _encryptionSkill = 4;
  int _datacore1Skill = 4;
  int _datacore2Skill = 4;
  double _decryptorMultiplier = 1.0;

  @override
  Widget build(BuildContext context) {
    final chance = InventionCalculator.calculateProbability(
      baseProbability: _baseProbability,
      encryptionSkillLevel: _encryptionSkill,
      datacoreSkill1Level: _datacore1Skill,
      datacoreSkill2Level: _datacore2Skill,
      decryptorMultiplier: _decryptorMultiplier,
    );

    return ListView(
      children: [
        EveCard(
          child: Padding(
            padding: const EdgeInsets.all(24.0),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.center,
              children: [
                Text(
                  'INVENTION CHANCE',
                  style: Theme.of(context).textTheme.titleSmall?.copyWith(
                    color: EveColors.textSecondary,
                    letterSpacing: 2,
                  ),
                ),
                const SizedBox(height: 16),
                Text(
                  '${(chance * 100).toStringAsFixed(1)}%',
                  style: Theme.of(context).textTheme.displayLarge?.copyWith(
                    color: chance > 0.5 ? EveColors.success : EveColors.warning,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                const SizedBox(height: 8),
                Text(
                  'With selected skills and decryptor',
                  style: Theme.of(context).textTheme.bodySmall?.copyWith(
                    color: EveColors.textSecondary,
                  ),
                ),
              ],
            ),
          ),
        ),
        const SizedBox(height: 16),
        EveCard(
          child: Padding(
            padding: const EdgeInsets.all(16.0),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    const Icon(Icons.school, color: EveColors.evePrimary, size: 20),
                    const SizedBox(width: 8),
                    Text(
                      'CHARACTER SKILLS',
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
                _buildSkillSlider('Encryption Skill', _encryptionSkill, (v) => setState(() => _encryptionSkill = v.toInt())),
                _buildSkillSlider('Datacore Skill 1', _datacore1Skill, (v) => setState(() => _datacore1Skill = v.toInt())),
                _buildSkillSlider('Datacore Skill 2', _datacore2Skill, (v) => setState(() => _datacore2Skill = v.toInt())),
              ],
            ),
          ),
        ),
        const SizedBox(height: 16),
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
                      'MODIFIERS',
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
                    SizedBox(
                      width: 150, 
                      child: Text('Base Probability:', style: Theme.of(context).textTheme.bodyMedium),
                    ),
                    Expanded(
                      child: Slider(
                        value: _baseProbability,
                        min: 0.1,
                        max: 0.9,
                        divisions: 80,
                        label: '${(_baseProbability * 100).toInt()}%',
                        onChanged: (v) => setState(() => _baseProbability = v),
                      ),
                    ),
                    SizedBox(
                      width: 40,
                      child: Text(
                        '${(_baseProbability * 100).toInt()}%',
                        textAlign: TextAlign.end,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 16),
                Row(
                  children: [
                    SizedBox(
                      width: 150, 
                      child: Text('Decryptor:', style: Theme.of(context).textTheme.bodyMedium),
                    ),
                    Expanded(
                      child: DropdownButtonFormField<double>(
                        isExpanded: true,
                        initialValue: _decryptorMultiplier,
                        decoration: const InputDecoration(
                          border: OutlineInputBorder(),
                          contentPadding: EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                        ),
                        items: const [
                          DropdownMenuItem(value: 1.0, child: Text('None (x1.0)')),
                          DropdownMenuItem(value: 1.1, child: Text('Symmetry Decryptor (x1.1)')),
                          DropdownMenuItem(value: 1.2, child: Text('Process Decryptor (x1.2)')),
                          DropdownMenuItem(value: 1.8, child: Text('Parity Decryptor (x1.8)')),
                          DropdownMenuItem(value: 0.6, child: Text('Optimized Decryptor (x0.6)')),
                        ],
                        onChanged: (v) {
                          if (v != null) setState(() => _decryptorMultiplier = v);
                        },
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildSkillSlider(String label, int value, ValueChanged<double> onChanged) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4.0),
      child: Row(
        children: [
          SizedBox(
            width: 150, 
            child: Text(label, style: Theme.of(context).textTheme.bodyMedium),
          ),
          Expanded(
            child: Slider(
              value: value.toDouble(),
              min: 1,
              max: 5,
              divisions: 4,
              label: 'Level $value',
              onChanged: onChanged,
            ),
          ),
          SizedBox(
            width: 40,
            child: Text(
              'Lv $value',
              textAlign: TextAlign.end,
              style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                fontWeight: FontWeight.bold,
                color: value == 5 ? EveColors.success : null,
              ),
            ),
          ),
        ],
      ),
    );
  }
}
