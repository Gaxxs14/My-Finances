import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import '../theme/app_theme.dart';
import '../services/exchange_rate_service.dart';
import 'app_toast.dart';

class BcvCalculatorSheet extends StatefulWidget {
  final ExchangeRates rates;
  final ValueChanged<double>? onAmountSelectedUsd;
  final ValueChanged<double>? onAmountSelectedVes;

  const BcvCalculatorSheet({
    super.key,
    required this.rates,
    this.onAmountSelectedUsd,
    this.onAmountSelectedVes,
  });

  static Future<void> show(
    BuildContext context,
    ExchangeRates rates, {
    ValueChanged<double>? onAmountSelectedUsd,
    ValueChanged<double>? onAmountSelectedVes,
  }) {
    return showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (context) => BcvCalculatorSheet(
        rates: rates,
        onAmountSelectedUsd: onAmountSelectedUsd,
        onAmountSelectedVes: onAmountSelectedVes,
      ),
    );
  }

  @override
  State<BcvCalculatorSheet> createState() => _BcvCalculatorSheetState();
}

class _BcvCalculatorSheetState extends State<BcvCalculatorSheet> {
  String _inputExpression = '0';
  String _selectedRateType = 'bcvUsd'; // 'bcvUsd', 'bcvEur', 'binance'
  
  final currencyVes = NumberFormat.currency(locale: 'es_VE', symbol: 'Bs. ');
  final currencyUsd = NumberFormat.currency(locale: 'en_US', symbol: '\$ ');

  double get _currentRate {
    switch (_selectedRateType) {
      case 'bcvEur':
        return widget.rates.bcvEur;
      case 'binance':
        return widget.rates.binanceUsd;
      default:
        return widget.rates.bcvUsd;
    }
  }

  double get _evaluatedResultVes {
    try {
      String expr = _inputExpression.replaceAll('×', '*').replaceAll('÷', '/');
      if (expr.isEmpty) return 0.0;
      // Basic split evaluation for addition/subtraction/multiplication/division
      double result = 0.0;
      // Evaluate simple numbers first if single number
      final parsed = double.tryParse(expr);
      if (parsed != null) return parsed;

      // Simple tokenizer for basic operations
      final RegExp regExp = RegExp(r'(\d+\.?\d*)|([\+\-\*/])');
      final matches = regExp.allMatches(expr).map((m) => m.group(0)!).toList();

      if (matches.isEmpty) return 0.0;
      result = double.tryParse(matches[0]) ?? 0.0;

      for (int i = 1; i < matches.length - 1; i += 2) {
        String op = matches[i];
        double nextNum = double.tryParse(matches[i + 1]) ?? 0.0;
        if (op == '+') result += nextNum;
        if (op == '-') result -= nextNum;
        if (op == '*') result *= nextNum;
        if (op == '/' && nextNum != 0) result /= nextNum;
      }
      return result;
    } catch (_) {
      return double.tryParse(_inputExpression) ?? 0.0;
    }
  }

  double get _calculatedUsd => _evaluatedResultVes / (_currentRate > 0 ? _currentRate : 1.0);

  void _onKeyPress(String key) {
    setState(() {
      if (key == 'C') {
        _inputExpression = '0';
      } else if (key == '⌫') {
        if (_inputExpression.length > 1) {
          _inputExpression = _inputExpression.substring(0, _inputExpression.length - 1);
        } else {
          _inputExpression = '0';
        }
      } else if (key == '=') {
        final res = _evaluatedResultVes;
        _inputExpression = res % 1 == 0 ? res.toInt().toString() : res.toStringAsFixed(2);
      } else {
        if (_inputExpression == '0' && key != '.' && key != '+' && key != '-' && key != '×' && key != '÷') {
          _inputExpression = key;
        } else {
          _inputExpression += key;
        }
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    final double vesTotal = _evaluatedResultVes;
    final double usdTotal = _calculatedUsd;

    return Container(
      padding: EdgeInsets.only(
        left: 20,
        right: 20,
        top: 16,
        bottom: MediaQuery.of(context).viewInsets.bottom + 20,
      ),
      decoration: BoxDecoration(
        color: AppTheme.surfaceDark,
        borderRadius: const BorderRadius.vertical(top: Radius.circular(32)),
        border: Border.all(color: Colors.white.withOpacity(0.15), width: 1.5),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.6),
            blurRadius: 32,
            spreadRadius: 4,
          ),
        ],
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          // Drag handle
          Center(
            child: Container(
              width: 40,
              height: 4,
              margin: const EdgeInsets.only(bottom: 12),
              decoration: BoxDecoration(
                color: Colors.white24,
                borderRadius: BorderRadius.circular(2),
              ),
            ),
          ),
          
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              const Row(
                children: [
                  Icon(Icons.calculate, color: AppTheme.primaryDark, size: 22),
                  SizedBox(width: 8),
                  Text(
                    'Calculadora en Bolívares (Bs.)',
                    style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: Colors.white),
                  ),
                ],
              ),
              IconButton(
                icon: const Icon(Icons.close, color: Colors.white60),
                onPressed: () => Navigator.pop(context),
              ),
            ],
          ),
          const SizedBox(height: 10),

          // Tasa Pill Selector
          Row(
            children: [
              _buildRateTab('bcvUsd', 'BCV \$ (${widget.rates.bcvUsd.toStringAsFixed(2)})', Colors.blueAccent),
              const SizedBox(width: 6),
              _buildRateTab('bcvEur', 'BCV € (${widget.rates.bcvEur.toStringAsFixed(2)})', Colors.purpleAccent),
              const SizedBox(width: 6),
              _buildRateTab('binance', 'Binance (${widget.rates.binanceUsd.toStringAsFixed(2)})', Colors.amberAccent),
            ],
          ),
          const SizedBox(height: 14),

          // Calculator Screen Output
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
            decoration: BoxDecoration(
              color: Colors.black45,
              borderRadius: BorderRadius.circular(20),
              border: Border.all(color: AppTheme.primaryDark.withOpacity(0.4), width: 1.2),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.end,
              children: [
                SingleChildScrollView(
                  scrollDirection: Axis.horizontal,
                  reverse: true,
                  child: Text(
                    'Bs. $_inputExpression',
                    style: const TextStyle(color: Colors.white, fontSize: 32, fontWeight: FontWeight.bold, fontFamily: 'monospace'),
                  ),
                ),
                const SizedBox(height: 6),
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Text(
                      'Tasa: 1 \$ = Bs. ${_currentRate.toStringAsFixed(2)}',
                      style: const TextStyle(color: Colors.white60, fontSize: 11),
                    ),
                    Text(
                      '= \$ ${usdTotal.toStringAsFixed(2)} USD',
                      style: const TextStyle(color: Colors.greenAccent, fontSize: 15, fontWeight: FontWeight.bold),
                    ),
                  ],
                ),
              ],
            ),
          ),
          const SizedBox(height: 16),

          // Real Calculator Keypad Grid
          Column(
            children: [
              _buildKeyRow(['C', '⌫', '÷', '×'], isOpRow: true),
              const SizedBox(height: 8),
              _buildKeyRow(['7', '8', '9', '-']),
              const SizedBox(height: 8),
              _buildKeyRow(['4', '5', '6', '+']),
              const SizedBox(height: 8),
              _buildKeyRow(['1', '2', '3', '=']),
              const SizedBox(height: 8),
              Row(
                children: [
                  _buildKeyButton('0', flex: 1),
                  const SizedBox(width: 8),
                  _buildKeyButton('.', flex: 1),
                  const SizedBox(width: 8),
                  _buildKeyButton('00', flex: 1),
                  const SizedBox(width: 8),
                  Expanded(
                    flex: 2,
                    child: ElevatedButton(
                      style: ElevatedButton.styleFrom(
                        backgroundColor: AppTheme.primaryDark,
                        padding: const EdgeInsets.symmetric(vertical: 14),
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                      ),
                      onPressed: () {
                        if (widget.onAmountSelectedUsd != null) {
                          widget.onAmountSelectedUsd!(usdTotal);
                        }
                        if (widget.onAmountSelectedVes != null) {
                          widget.onAmountSelectedVes!(vesTotal);
                        }
                        Navigator.pop(context);
                        AppToast.show(
                          context,
                          message: '¡Cargado: Bs. ${vesTotal.toStringAsFixed(2)} (\$ ${usdTotal.toStringAsFixed(2)})!',
                          type: AppToastType.success,
                        );
                      },
                      child: const Text('Usar Bs.', style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 15)),
                    ),
                  ),
                ],
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildRateTab(String id, String label, Color color) {
    final isSelected = _selectedRateType == id;
    return Expanded(
      child: GestureDetector(
        onTap: () => setState(() => _selectedRateType = id),
        child: Container(
          padding: const EdgeInsets.symmetric(vertical: 8),
          decoration: BoxDecoration(
            color: isSelected ? color.withOpacity(0.25) : Colors.black26,
            borderRadius: BorderRadius.circular(12),
            border: Border.all(color: isSelected ? color : Colors.white10),
          ),
          child: Text(
            label,
            textAlign: TextAlign.center,
            style: TextStyle(
              fontSize: 10,
              fontWeight: isSelected ? FontWeight.bold : FontWeight.normal,
              color: isSelected ? Colors.white : Colors.white60,
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildKeyRow(List<String> keys, {bool isOpRow = false}) {
    return Row(
      children: keys.map((key) {
        final isOp = ['+', '-', '×', '÷', '='].contains(key);
        final isClear = ['C', '⌫'].contains(key);
        return Expanded(
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 4),
            child: _buildKeyButton(key, isOp: isOp, isClear: isClear),
          ),
        );
      }).toList(),
    );
  }

  Widget _buildKeyButton(String key, {bool isOp = false, bool isClear = false, int flex = 1}) {
    Color bg = Colors.black26;
    Color fg = Colors.white;
    if (isOp) {
      bg = AppTheme.primaryDark.withOpacity(0.3);
      fg = AppTheme.primaryDark;
    } else if (isClear) {
      bg = Colors.redAccent.withOpacity(0.2);
      fg = Colors.redAccent;
    }

    return ElevatedButton(
      style: ElevatedButton.styleFrom(
        backgroundColor: bg,
        foregroundColor: fg,
        padding: const EdgeInsets.symmetric(vertical: 14),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(14),
          side: BorderSide(color: isOp || isClear ? fg.withOpacity(0.4) : Colors.white10),
        ),
        elevation: 0,
      ),
      onPressed: () => _onKeyPress(key),
      child: Text(
        key,
        style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: fg),
      ),
    );
  }
}
