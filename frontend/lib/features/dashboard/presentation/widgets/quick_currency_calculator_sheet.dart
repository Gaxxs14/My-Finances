import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';
import '../../../../core/theme/app_theme.dart';
import '../../../../core/widgets/app_toast.dart';
import '../../../../core/services/exchange_rate_service.dart';

class QuickCurrencyCalculatorSheet extends ConsumerStatefulWidget {
  final Function(double amount, String currency)? onUseAmount;

  const QuickCurrencyCalculatorSheet({super.key, this.onUseAmount});

  static Future<void> show(BuildContext context, {Function(double amount, String currency)? onUseAmount}) {
    return showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (ctx) => QuickCurrencyCalculatorSheet(onUseAmount: onUseAmount),
    );
  }

  @override
  ConsumerState<QuickCurrencyCalculatorSheet> createState() => _QuickCurrencyCalculatorSheetState();
}

class _QuickCurrencyCalculatorSheetState extends ConsumerState<QuickCurrencyCalculatorSheet> {
  final _amountController = TextEditingController(text: '10');
  final currencyFormatVes = NumberFormat.currency(locale: 'es_VE', symbol: 'Bs. ');
  String _selectedSource = 'USD'; // 'USD', 'VES', 'EUR', 'USDT'

  @override
  void dispose() {
    _amountController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final ratesState = ref.watch(exchangeRatesProvider);
    final rates = ratesState.valueOrNull;
    final double bcvUsd = (rates?.bcvUsd != null && rates!.bcvUsd > 0) ? rates.bcvUsd : 764.35;
    final double bcvEur = (rates?.bcvEur != null && rates!.bcvEur > 0) ? rates.bcvEur : 882.30;
    final double binanceUsd = (rates?.binanceUsd != null && rates!.binanceUsd > 0) ? rates.binanceUsd : 865.30;

    final double inputVal = double.tryParse(_amountController.text.replaceAll(',', '.')) ?? 0.0;

    // Convert inputVal to base USD
    double baseUsd = 0.0;
    switch (_selectedSource) {
      case 'USD':
        baseUsd = inputVal;
        break;
      case 'VES':
        baseUsd = bcvUsd > 0 ? (inputVal / bcvUsd) : 0.0;
        break;
      case 'EUR':
        baseUsd = (inputVal * bcvEur) / (bcvUsd > 0 ? bcvUsd : 1.0);
        break;
      case 'USDT':
        baseUsd = (inputVal * binanceUsd) / (bcvUsd > 0 ? bcvUsd : 1.0);
        break;
    }

    final double convertedVes = baseUsd * bcvUsd;
    final double convertedUsd = baseUsd;
    final double convertedEur = bcvEur > 0 ? (convertedVes / bcvEur) : 0.0;
    final double convertedUsdt = binanceUsd > 0 ? (convertedVes / binanceUsd) : 0.0;

    final isDark = Theme.of(context).brightness == Brightness.dark;

    return Container(
      padding: EdgeInsets.only(
        left: 20,
        right: 20,
        top: 16,
        bottom: MediaQuery.of(context).viewInsets.bottom + 24,
      ),
      decoration: BoxDecoration(
        color: isDark ? const Color(0xFF1E293B) : Colors.white,
        borderRadius: const BorderRadius.vertical(top: Radius.circular(32)),
        border: Border.all(color: isDark ? Colors.white10 : Colors.black12, width: 1.5),
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Center(
            child: Container(
              width: 40,
              height: 4,
              margin: const EdgeInsets.only(bottom: 16),
              decoration: BoxDecoration(
                color: isDark ? Colors.white24 : Colors.black26,
                borderRadius: BorderRadius.circular(2),
              ),
            ),
          ),
          Row(
            children: [
              Container(
                padding: const EdgeInsets.all(10),
                decoration: BoxDecoration(
                  color: AppTheme.primaryDark.withOpacity(0.15),
                  shape: BoxShape.circle,
                ),
                child: const Icon(Icons.calculate_rounded, color: AppTheme.primaryDark, size: 24),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Calculadora de Divisas',
                      style: TextStyle(
                        fontSize: 20,
                        fontWeight: FontWeight.bold,
                        color: isDark ? Colors.white : AppTheme.textPrimaryLight,
                      ),
                    ),
                    Text(
                      'Conversión al instante con tasas en vivo',
                      style: TextStyle(
                        fontSize: 12,
                        color: isDark ? Colors.white60 : AppTheme.textSecondaryLight,
                      ),
                    ),
                  ],
                ),
              ),
              IconButton(
                icon: const Icon(Icons.close_rounded),
                onPressed: () => Navigator.pop(context),
              ),
            ],
          ),
          const SizedBox(height: 16),

          // Source currency selectors
          Row(
            children: [
              _buildSourceChip('USD', '\$ Dólar', Icons.attach_money_rounded),
              const SizedBox(width: 8),
              _buildSourceChip('VES', '🇻🇪 Bolívares', Icons.money_rounded),
              const SizedBox(width: 8),
              _buildSourceChip('EUR', '€ Euro', Icons.euro_rounded),
              const SizedBox(width: 8),
              _buildSourceChip('USDT', 'Binance', Icons.currency_bitcoin_rounded),
            ],
          ),
          const SizedBox(height: 16),

          // Input field
          TextFormField(
            controller: _amountController,
            keyboardType: const TextInputType.numberWithOptions(decimal: true),
            style: TextStyle(
              fontSize: 24,
              fontWeight: FontWeight.bold,
              color: isDark ? Colors.white : AppTheme.textPrimaryLight,
            ),
            decoration: InputDecoration(
              labelText: 'Monto a Convertir ($_selectedSource)',
              prefixIcon: const Icon(Icons.price_change_outlined, color: AppTheme.primaryDark),
              filled: true,
              fillColor: isDark ? Colors.black26 : Colors.grey[100],
              border: OutlineInputBorder(borderRadius: BorderRadius.circular(16)),
              suffixIcon: IconButton(
                icon: const Icon(Icons.clear_rounded, size: 18),
                onPressed: () {
                  _amountController.clear();
                  setState(() {});
                },
              ),
            ),
            onChanged: (_) => setState(() {}),
          ),
          const SizedBox(height: 20),

          // Conversion Results Cards Grid
          Wrap(
            spacing: 10,
            runSpacing: 10,
            children: [
              _buildResultCard(
                label: 'Bolívares (Tasa BCV)',
                formattedValue: 'Bs. ${currencyFormatVes.format(convertedVes).replaceAll('Bs.', '').trim()}',
                rateInfo: '1 USD = Bs. ${bcvUsd.toStringAsFixed(2)}',
                color: const Color(0xFF10B981),
                isDark: isDark,
                onCopy: () => _copyToClipboard('Bs. ${convertedVes.toStringAsFixed(2)}'),
              ),
              _buildResultCard(
                label: 'Dólares (USD)',
                formattedValue: '\$ ${convertedUsd.toStringAsFixed(2)}',
                rateInfo: 'Moneda base de referencia',
                color: const Color(0xFF06B6D4),
                isDark: isDark,
                onCopy: () => _copyToClipboard('\$ ${convertedUsd.toStringAsFixed(2)}'),
              ),
              _buildResultCard(
                label: 'Euros (EUR)',
                formattedValue: '€ ${convertedEur.toStringAsFixed(2)}',
                rateInfo: '1 EUR = Bs. ${bcvEur.toStringAsFixed(2)}',
                color: const Color(0xFFA855F7),
                isDark: isDark,
                onCopy: () => _copyToClipboard('€ ${convertedEur.toStringAsFixed(2)}'),
              ),
              _buildResultCard(
                label: 'Binance (USDT P2P)',
                formattedValue: '${convertedUsdt.toStringAsFixed(2)} USDT',
                rateInfo: '1 USDT = Bs. ${binanceUsd.toStringAsFixed(2)}',
                color: const Color(0xFFF59E0B),
                isDark: isDark,
                onCopy: () => _copyToClipboard('${convertedUsdt.toStringAsFixed(2)} USDT'),
              ),
            ],
          ),
          const SizedBox(height: 20),

          // Use as Transaction Button
          if (widget.onUseAmount != null && inputVal > 0)
            ElevatedButton.icon(
              icon: const Icon(Icons.add_circle_outline_rounded, color: Colors.white),
              label: Text(
                'Registrar Gasto con $inputVal $_selectedSource',
                style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 15),
              ),
              style: ElevatedButton.styleFrom(
                backgroundColor: AppTheme.primaryDark,
                padding: const EdgeInsets.symmetric(vertical: 14),
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
              ),
              onPressed: () {
                Navigator.pop(context);
                widget.onUseAmount!(inputVal, _selectedSource);
              },
            ),
        ],
      ),
    );
  }

  Widget _buildSourceChip(String code, String label, IconData icon) {
    final isSelected = _selectedSource == code;
    return Expanded(
      child: GestureDetector(
        onTap: () => setState(() => _selectedSource = code),
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 180),
          padding: const EdgeInsets.symmetric(vertical: 10),
          decoration: BoxDecoration(
            color: isSelected ? AppTheme.primaryDark : Colors.transparent,
            borderRadius: BorderRadius.circular(12),
            border: Border.all(
              color: isSelected ? AppTheme.primaryDark : Colors.grey.withOpacity(0.3),
              width: 1.5,
            ),
          ),
          child: Column(
            children: [
              Icon(icon, size: 18, color: isSelected ? Colors.white : Colors.grey),
              const SizedBox(height: 4),
              Text(
                code,
                style: TextStyle(
                  fontSize: 12,
                  fontWeight: FontWeight.bold,
                  color: isSelected ? Colors.white : Colors.grey,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildResultCard({
    required String label,
    required String formattedValue,
    required String rateInfo,
    required Color color,
    required bool isDark,
    required VoidCallback onCopy,
  }) {
    return Container(
      width: (MediaQuery.of(context).size.width - 50) / 2,
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: isDark ? const Color(0xFF0F172A) : const Color(0xFFF8FAFC),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: color.withOpacity(0.3), width: 1.2),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Expanded(
                child: Text(
                  label,
                  style: TextStyle(
                    fontSize: 11,
                    fontWeight: FontWeight.w600,
                    color: isDark ? Colors.white60 : Colors.black54,
                  ),
                  overflow: TextOverflow.ellipsis,
                ),
              ),
              GestureDetector(
                onTap: onCopy,
                child: Icon(Icons.copy_rounded, size: 14, color: color),
              ),
            ],
          ),
          const SizedBox(height: 6),
          Text(
            formattedValue,
            style: TextStyle(
              fontSize: 16,
              fontWeight: FontWeight.bold,
              color: color,
            ),
            overflow: TextOverflow.ellipsis,
          ),
          const SizedBox(height: 4),
          Text(
            rateInfo,
            style: TextStyle(
              fontSize: 9,
              color: isDark ? Colors.white38 : Colors.black38,
            ),
            overflow: TextOverflow.ellipsis,
          ),
        ],
      ),
    );
  }

  void _copyToClipboard(String text) {
    Clipboard.setData(ClipboardData(text: text));
    AppToast.show(context, message: 'Copiado al portapapeles: $text', type: AppToastType.info);
  }
}
