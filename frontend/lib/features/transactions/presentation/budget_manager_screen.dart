import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:intl/intl.dart';
import '../../../core/providers/global_providers.dart';
import '../../../core/theme/app_theme.dart';

class BudgetManagerScreen extends ConsumerStatefulWidget {
  const BudgetManagerScreen({super.key});

  @override
  ConsumerState<BudgetManagerScreen> createState() => _BudgetManagerScreenState();
}

class _BudgetManagerScreenState extends ConsumerState<BudgetManagerScreen> {
  final currencyFormat = NumberFormat.currency(locale: 'es_US', symbol: '\$');
  final _storage = const FlutterSecureStorage();
  
  static const String _keyBudgets = 'category_budgets';
  Map<String, double> _budgets = {};
  bool _isLoading = true;

  final List<String> _categories = ['Comida', 'Transporte', 'Entretenimiento', 'Servicios', 'Otros'];

  @override
  void initState() {
    super.initState();
    _loadBudgets();
  }

  Future<void> _loadBudgets() async {
    try {
      final jsonStr = await _storage.read(key: _keyBudgets);
      if (jsonStr != null) {
        final Map<String, dynamic> decoded = jsonDecode(jsonStr);
        setState(() {
          _budgets = decoded.map((key, value) => MapEntry(key, double.parse(value.toString())));
        });
      }
    } catch (_) {}
    setState(() => _isLoading = false);
  }

  Future<void> _saveBudgets() async {
    final Map<String, String> toSave = _budgets.map((key, value) => MapEntry(key, value.toString()));
    await _storage.write(key: _keyBudgets, value: jsonEncode(toSave));
    ref.invalidate(categorySummaryProvider);
  }

  void _showSetLimitDialog(String category) {
    final controller = TextEditingController(
      text: _budgets.containsKey(category) ? _budgets[category]!.toStringAsFixed(2) : '',
    );
    final formKey = GlobalKey<FormState>();

    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: AppTheme.surfaceDark,
        title: Text('Presupuesto para $category'),
        content: Form(
          key: formKey,
          child: TextFormField(
            controller: controller,
            decoration: const InputDecoration(labelText: 'Límite Mensual (\$)', prefixIcon: Icon(Icons.attach_money)),
            keyboardType: const TextInputType.numberWithOptions(decimal: true),
            validator: (val) {
              if (val == null || val.isEmpty) return 'Por favor ingresa un monto';
              if (double.tryParse(val) == null) return 'Monto inválido';
              return null;
            },
          ),
        ),
        actions: [
          TextButton(
            child: const Text('Cancelar'),
            onPressed: () => Navigator.pop(ctx),
          ),
          ElevatedButton(
            style: ElevatedButton.styleFrom(backgroundColor: AppTheme.primaryDark),
            child: const Text('Guardar', style: TextStyle(color: Colors.white)),
            onPressed: () {
              if (formKey.currentState!.validate()) {
                setState(() {
                  _budgets[category] = double.parse(controller.text);
                });
                _saveBudgets();
                Navigator.pop(ctx);
              }
            },
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final categorySummaryAsync = ref.watch(categorySummaryProvider);

    return Scaffold(
      appBar: AppBar(
        title: const Text('Presupuestos Mensuales', style: TextStyle(fontWeight: FontWeight.bold)),
        backgroundColor: Colors.transparent,
        elevation: 0,
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : Padding(
              padding: const EdgeInsets.all(16.0),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  // Info Card
                  Card(
                    color: AppTheme.primaryDark.withOpacity(0.1),
                    child: const Padding(
                      padding: EdgeInsets.all(16.0),
                      child: Row(
                        children: [
                          Icon(Icons.info_outline, color: AppTheme.primaryDark),
                          SizedBox(width: 12),
                          Expanded(
                            child: Text(
                              'Define límites mensuales para tus gastos y mantén tu salud financiera bajo control. Te alertaremos cuando te acerques a tus límites.',
                              style: TextStyle(color: AppTheme.textSecondaryDark, height: 1.4),
                            ),
                          )
                        ],
                      ),
                    ),
                  ),
                  const SizedBox(height: 20),

                  // List of Category Budgets
                  Expanded(
                    child: categorySummaryAsync.when(
                      data: (summary) {
                        return ListView.builder(
                          itemCount: _categories.length,
                          itemBuilder: (context, index) {
                            final category = _categories[index];
                            final double spent = summary[category] ?? 0.0;
                            final double? limit = _budgets[category];
                            final double percent = limit != null && limit > 0 ? (spent / limit) : 0.0;

                            Color progressColor = Colors.greenAccent;
                            if (percent >= 1.0) {
                              progressColor = Colors.redAccent;
                            } else if (percent >= 0.8) {
                              progressColor = Colors.amberAccent;
                            }

                            return Card(
                              margin: const EdgeInsets.symmetric(vertical: 8),
                              child: Padding(
                                padding: const EdgeInsets.all(16.0),
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.stretch,
                                  children: [
                                    Row(
                                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                      children: [
                                        Text(
                                          category,
                                          style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
                                        ),
                                        IconButton(
                                          icon: const Icon(Icons.edit_outlined, color: AppTheme.primaryDark, size: 20),
                                          onPressed: () => _showSetLimitDialog(category),
                                        ),
                                      ],
                                    ),
                                    const SizedBox(height: 8),
                                    Row(
                                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                      children: [
                                        Text(
                                          'Gastado: ${currencyFormat.format(spent)}',
                                          style: const TextStyle(color: AppTheme.textSecondaryDark, fontSize: 13),
                                        ),
                                        Text(
                                          limit != null 
                                              ? 'Límite: ${currencyFormat.format(limit)}' 
                                              : 'Sin presupuesto',
                                          style: const TextStyle(color: AppTheme.textSecondaryDark, fontSize: 13),
                                        ),
                                      ],
                                    ),
                                    if (limit != null) ...[
                                      const SizedBox(height: 12),
                                      ClipRRect(
                                        borderRadius: BorderRadius.circular(4),
                                        child: LinearProgressIndicator(
                                          value: percent > 1.0 ? 1.0 : percent,
                                          backgroundColor: Colors.white10,
                                          color: progressColor,
                                          minHeight: 8,
                                        ),
                                      ),
                                      const SizedBox(height: 8),
                                      Row(
                                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                        children: [
                                          Text(
                                            '${(percent * 100).toStringAsFixed(0)}% del límite',
                                            style: TextStyle(
                                              color: progressColor,
                                              fontWeight: FontWeight.bold,
                                              fontSize: 12,
                                            ),
                                          ),
                                          if (percent >= 1.0)
                                            const Text(
                                              '¡Presupuesto Superado!',
                                              style: TextStyle(
                                                color: Colors.redAccent,
                                                fontWeight: FontWeight.bold,
                                                fontSize: 12,
                                              ),
                                            )
                                          else if (percent >= 0.8)
                                            const Text(
                                              'Límite cercano',
                                              style: TextStyle(
                                                color: Colors.amberAccent,
                                                fontWeight: FontWeight.bold,
                                                fontSize: 12,
                                              ),
                                            ),
                                        ],
                                      ),
                                    ],
                                  ],
                                ),
                              ),
                            );
                          },
                        );
                      },
                      loading: () => const Center(child: CircularProgressIndicator()),
                      error: (err, stack) => Text('Error: $err'),
                    ),
                  ),
                ],
              ),
            ),
    );
  }
}
