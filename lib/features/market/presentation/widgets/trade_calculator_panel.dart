import 'package:flutter/material.dart';

import '../../../../core/theme/eve_colors.dart';
import '../../../../core/utils/formatters.dart';
import '../../../../core/widgets/eve_card.dart';
import '../../domain/trade_calculator.dart';

/// Panel for calculating trade margins with broker fee and sales tax.
class TradeCalculatorPanel extends StatefulWidget {
  const TradeCalculatorPanel({super.key});

  @override
  State<TradeCalculatorPanel> createState() => _TradeCalculatorPanelState();
}

class _TradeCalculatorPanelState extends State<TradeCalculatorPanel> {
  final _buyController = TextEditingController();
  final _sellController = TextEditingController();
  double _brokerFee = 1.0;
  double _salesTax = 2.0;
  TradeMargin? _result;

  @override
  void dispose() {
    _buyController.dispose();
    _sellController.dispose();
    super.dispose();
  }

  void _calculate() {
    final buy = double.tryParse(_buyController.text.replaceAll(',', ''));
    final sell = double.tryParse(_sellController.text.replaceAll(',', ''));
    if (buy == null || sell == null || buy <= 0 || sell <= 0) {
      setState(() => _result = null);
      return;
    }

    setState(() {
      _result = TradeCalculator.calculateMargin(
        buyPrice: buy,
        sellPrice: sell,
        brokerFeePercent: _brokerFee,
        salesTaxPercent: _salesTax,
      );
    });
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return ListView(
      padding: const EdgeInsets.all(16),
      children: [
        // Inputs
        EveCard(
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    const Icon(
                      Icons.calculate_outlined,
                      size: 18,
                      color: Color(0xFF4FC3F7),
                    ),
                    const SizedBox(width: 8),
                    Text(
                      'Trade Calculator',
                      style: theme.textTheme.titleMedium?.copyWith(
                        fontWeight: FontWeight.bold,
                        color: EveColors.textPrimary,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 16),

                // Buy / Sell price row
                Row(
                  children: [
                    Expanded(
                      child: _buildPriceInput(
                        label: 'Buy Price (ISK)',
                        controller: _buyController,
                        color: Colors.blue.shade300,
                      ),
                    ),
                    const SizedBox(width: 16),
                    Expanded(
                      child: _buildPriceInput(
                        label: 'Sell Price (ISK)',
                        controller: _sellController,
                        color: Colors.orange.shade300,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 20),

                // Broker fee slider
                _buildSlider(
                  label: 'Broker Fee',
                  value: _brokerFee,
                  min: 0.0,
                  max: 5.0,
                  color: Colors.purple.shade300,
                  onChanged: (v) => setState(() {
                    _brokerFee = v;
                    _calculate();
                  }),
                ),
                const SizedBox(height: 12),

                // Sales tax slider
                _buildSlider(
                  label: 'Sales Tax',
                  value: _salesTax,
                  min: 0.0,
                  max: 8.0,
                  color: Colors.red.shade300,
                  onChanged: (v) => setState(() {
                    _salesTax = v;
                    _calculate();
                  }),
                ),
                const SizedBox(height: 16),

                // Calculate button
                SizedBox(
                  width: double.infinity,
                  child: ElevatedButton.icon(
                    onPressed: _calculate,
                    icon: const Icon(Icons.calculate, size: 18),
                    label: const Text('Calculate'),
                    style: ElevatedButton.styleFrom(
                      padding: const EdgeInsets.symmetric(vertical: 12),
                      backgroundColor: const Color(0xFF4FC3F7),
                      foregroundColor: Colors.black,
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
        const SizedBox(height: 16),

        // Results
        if (_result != null) _buildResults(_result!),

        // Break-even helper
        if (_result != null) ...[const SizedBox(height: 16), _buildBreakEven()],
      ],
    );
  }

  Widget _buildPriceInput({
    required String label,
    required TextEditingController controller,
    required Color color,
  }) {
    return TextField(
      controller: controller,
      decoration: InputDecoration(
        labelText: label,
        labelStyle: TextStyle(color: color, fontSize: 12),
        border: OutlineInputBorder(borderRadius: BorderRadius.circular(8)),
        contentPadding: const EdgeInsets.symmetric(
          horizontal: 12,
          vertical: 10,
        ),
        filled: true,
        fillColor: EveColors.surfaceElevated,
        prefixText: 'ISK ',
        prefixStyle: const TextStyle(
          color: EveColors.textSecondary,
          fontSize: 12,
        ),
      ),
      keyboardType: const TextInputType.numberWithOptions(decimal: true),
      style: TextStyle(color: color, fontWeight: FontWeight.bold),
      onChanged: (_) => _calculate(),
    );
  }

  Widget _buildSlider({
    required String label,
    required double value,
    required double min,
    required double max,
    required Color color,
    required ValueChanged<double> onChanged,
  }) {
    return Row(
      children: [
        SizedBox(
          width: 90,
          child: Text(
            label,
            style: const TextStyle(
              color: EveColors.textSecondary,
              fontSize: 12,
            ),
          ),
        ),
        Expanded(
          child: SliderTheme(
            data: SliderThemeData(
              activeTrackColor: color,
              thumbColor: color,
              inactiveTrackColor: color.withValues(alpha: 0.2),
              overlayColor: color.withValues(alpha: 0.1),
              trackHeight: 3,
            ),
            child: Slider(
              value: value,
              min: min,
              max: max,
              divisions: ((max - min) * 10).toInt(),
              onChanged: onChanged,
            ),
          ),
        ),
        SizedBox(
          width: 50,
          child: Text(
            '${value.toStringAsFixed(1)}%',
            style: TextStyle(
              color: color,
              fontSize: 12,
              fontWeight: FontWeight.bold,
            ),
            textAlign: TextAlign.right,
          ),
        ),
      ],
    );
  }

  Widget _buildResults(TradeMargin result) {
    final theme = Theme.of(context);
    final profitColor = result.isProfitable
        ? const Color(0xFF81C784)
        : EveColors.error;

    return EveCard(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          children: [
            // Profit headline
            Text(
              result.isProfitable ? 'PROFITABLE' : 'LOSS',
              style: TextStyle(
                color: profitColor,
                fontSize: 12,
                fontWeight: FontWeight.w800,
                letterSpacing: 1.5,
              ),
            ),
            const SizedBox(height: 8),
            Text(
              formatIsk(result.profit),
              style: theme.textTheme.headlineMedium?.copyWith(
                fontWeight: FontWeight.bold,
                color: profitColor,
              ),
            ),
            Text(
              '${result.marginPercent.toStringAsFixed(1)}% margin',
              style: TextStyle(color: profitColor, fontSize: 14),
            ),
            const SizedBox(height: 20),

            // Breakdown table
            _ResultRow(label: 'Buy Price', value: formatIsk(result.buyPrice)),
            _ResultRow(
              label: '+ Broker Fee (buy)',
              value: formatIsk(result.buyPrice * _brokerFee / 100),
            ),
            _ResultRow(
              label: '= Total Cost',
              value: formatIsk(result.buyTotal),
              isBold: true,
            ),
            const Divider(height: 20, color: EveColors.textSecondary),
            _ResultRow(label: 'Sell Price', value: formatIsk(result.sellPrice)),
            _ResultRow(
              label: '- Broker Fee (sell)',
              value: formatIsk(result.sellPrice * _brokerFee / 100),
            ),
            _ResultRow(label: '- Sales Tax', value: formatIsk(result.salesTax)),
            _ResultRow(
              label: '= Net Revenue',
              value: formatIsk(result.sellNet),
              isBold: true,
            ),
            const Divider(height: 20, color: EveColors.textSecondary),
            _ResultRow(
              label: 'Profit / Unit',
              value: formatIsk(result.profit),
              valueColor: profitColor,
              isBold: true,
            ),
            _ResultRow(
              label: 'Total Fees',
              value: formatIsk(result.brokerFee + result.salesTax),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildBreakEven() {
    final buy = double.tryParse(_buyController.text.replaceAll(',', ''));
    if (buy == null || buy <= 0) return const SizedBox.shrink();

    final breakEven = TradeCalculator.breakEvenSellPrice(
      buyPrice: buy,
      brokerFeePercent: _brokerFee,
      salesTaxPercent: _salesTax,
    );

    return EveCard(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Row(
          children: [
            const Icon(Icons.balance, size: 20, color: Colors.amber),
            const SizedBox(width: 12),
            Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text(
                  'Break-Even Sell Price',
                  style: TextStyle(
                    color: EveColors.textSecondary,
                    fontSize: 12,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  formatIsk(breakEven),
                  style: const TextStyle(
                    color: Colors.amber,
                    fontSize: 18,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

class _ResultRow extends StatelessWidget {
  final String label;
  final String value;
  final Color? valueColor;
  final bool isBold;

  const _ResultRow({
    required this.label,
    required this.value,
    this.valueColor,
    this.isBold = false,
  });

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 3),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(
            label,
            style: TextStyle(
              color: EveColors.textSecondary,
              fontSize: 12,
              fontWeight: isBold ? FontWeight.w600 : FontWeight.normal,
            ),
          ),
          Text(
            value,
            style: TextStyle(
              color: valueColor ?? EveColors.textPrimary,
              fontSize: 12,
              fontWeight: isBold ? FontWeight.bold : FontWeight.normal,
            ),
          ),
        ],
      ),
    );
  }
}
