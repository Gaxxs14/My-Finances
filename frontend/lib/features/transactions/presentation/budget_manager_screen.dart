import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:intl/intl.dart';
import '../../../core/providers/global_providers.dart';
import '../../../core/services/exchange_rate_service.dart';
import '../../../core/theme/app_theme.dart';
import '../../../core/widgets/bcv_calculator_sheet.dart';
import '../../../core/widgets/app_toast.dart';

class BudgetManagerScreen extends ConsumerStatefulWidget {
  const BudgetManagerScreen({super.key});

  @override
  ConsumerState<BudgetManagerScreen> createState() => _BudgetManagerScreenState();
}

class _BudgetManagerScreenState extends ConsumerState<BudgetManagerScreen> {
  final currencyFormat = NumberFormat.currency(locale: 'es_VE', symbol: 'Bs. ');
  final _storage = const FlutterSecureStorage();
  
  static const String _keyBudgets = 'category_budgets';
  static const String _keyCustomCategories = 'custom_categories';
  Map<String, double> _budgets = {};
  bool _isLoading = true;

  List<String> _categories = ['Comida', 'Transporte', 'Entretenimiento', 'Servicios', 'Otros'];

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

      final customCatStr = await _storage.read(key: _keyCustomCategories);
      if (customCatStr != null) {
        final List<dynamic> loaded = jsonDecode(customCatStr);
        final customList = loaded.map((e) => e.toString()).toList();
        for (var cat in customList) {
          if (!_categories.contains(cat)) {
            _categories.add(cat);
          }
        }
      }
    } catch (_) {}
    setState(() => _isLoading = false);
  }

  Future<void> _saveBudgets() async {
    final Map<String, String> toSave = _budgets.map((key, value) => MapEntry(key, value.toString()));
    await _storage.write(key: _keyBudgets, value: jsonEncode(toSave));
    ref.invalidate(categorySummaryProvider);
  }

  Future<void> _saveCustomCategories() async {
    await _storage.write(key: _keyCustomCategories, value: jsonEncode(_categories));
  }

  Future<void> _deleteBudget(String category) async {
    setState(() {
      _budgets.remove(category);
    });
    await _saveBudgets();
    if (mounted) {
      AppToast.show(context, message: 'Presupuesto de "$category" eliminado', type: AppToastType.info);
    }
  }

  Future<void> _deleteCategory(String category) async {
    // Default categories can't be deleted, only their budgets can
    final defaultCategories = ['Comida', 'Transporte', 'Entretenimiento', 'Servicios', 'Otros'];
    if (defaultCategories.contains(category)) {
      // Just remove the budget limit, keep the category
      await _deleteBudget(category);
      return;
    }
    // Custom category: remove category + budget
    setState(() {
      _categories.remove(category);
      _budgets.remove(category);
    });
    await _saveBudgets();
    await _saveCustomCategories();
    if (mounted) {
      AppToast.show(context, message: 'Categoría "$category" eliminada', type: AppToastType.info);
    }
  }

  void _showAddCategoryDialog() {
    final controller = TextEditingController();
    final formKey = GlobalKey<FormState>();

    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: Theme.of(context).cardColor,
        title: const Text('Nueva Categoría de Presupuesto'),
        content: Form(
          key: formKey,
          child: TextFormField(
            controller: controller,
            decoration: const InputDecoration(
              labelText: 'Nombre de la Categoría (ej. Mascotas, Salud)',
              prefixIcon: Icon(Icons.category_outlined),
            ),
            validator: (val) {
              if (val == null || val.trim().isEmpty) return 'Ingresa un nombre';
              if (_categories.contains(val.trim())) return 'Esta categoría ya existe';
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
            child: const Text('Crear Categoría', style: TextStyle(color: Colors.white)),
            onPressed: () {
              if (formKey.currentState!.validate()) {
                final newCat = controller.text.trim();
                setState(() {
                  _categories.add(newCat);
                });
                _saveCustomCategories();
                Navigator.pop(ctx);
                AppToast.show(context, message: '✨ Categoría "$newCat" añadida con éxito', type: AppToastType.success);
              }
            },
          ),
        ],
      ),
    );
  }

  void _showSetLimitDialog(String category) {
    final controller = TextEditingController(
      text: _budgets.containsKey(category) ? _budgets[category]!.toStringAsFixed(2) : '',
    );
    final formKey = GlobalKey<FormState>();

    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: Theme.of(context).cardColor,
        title: Text('Presupuesto para $category'),
        content: Form(
          key: formKey,
          child: TextFormField(
            controller: controller,
            decoration: InputDecoration(
              labelText: 'Límite Mensual en Bolívares (Bs. VES)',
              prefixIcon: const Icon(Icons.price_change_outlined),
              suffixIcon: IconButton(
                icon: const Icon(Icons.calculate_outlined, color: AppTheme.primaryDark),
                tooltip: 'Calculadora BCV',
                onPressed: () {
                  final rates = ref.read(exchangeRatesProvider).valueOrNull;
                  if (rates != null) {
                    BcvCalculatorSheet.show(
                      context,
                      rates,
                      onAmountSelectedVes: (calculatedVes) {
                        controller.text = calculatedVes.toStringAsFixed(2);
                      },
                    );
                  }
                },
              ),
            ),
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
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return Scaffold(
      appBar: AppBar(
        title: const Text('Presupuestos Mensuales', style: TextStyle(fontWeight: FontWeight.bold)),
        backgroundColor: Colors.transparent,
        elevation: 0,
        actions: [
          IconButton(
            icon: const Icon(Icons.add_circle_outline, size: 26),
            tooltip: 'Crear Nueva Categoría',
            onPressed: _showAddCategoryDialog,
          ),
        ],
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
                    color: AppTheme.primaryDark.withOpacity(0.12),
                    child: Padding(
                      padding: const EdgeInsets.all(16.0),
                      child: Row(
                        children: [
                          const Icon(Icons.info_outline, color: AppTheme.primaryDark),
                          const SizedBox(width: 12),
                          Expanded(
                            child: Text(
                              'Define límites mensuales para tus gastos y mantén tu salud financiera bajo control. Te alertaremos cuando te acerques a tus límites.',
                              style: TextStyle(
                                color: isDark ? AppTheme.textSecondaryDark : AppTheme.textSecondaryLight,
                                height: 1.4,
                              ),
                            ),
                          )
                        ],
                      ),
                    ),
                  ),
                  const SizedBox(height: 16),

                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Text(
                        'Categorías (${_categories.length})',
                        style: TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.bold,
                          color: isDark ? Colors.white : AppTheme.textPrimaryLight,
                        ),
                      ),
                      TextButton.icon(
                        icon: const Icon(Icons.add, size: 18),
                        label: const Text('Nueva Categoría'),
                        onPressed: _showAddCategoryDialog,
                      ),
                    ],
                  ),
                  const SizedBox(height: 8),

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

                            Color progressColor = Colors.green;
                            if (percent >= 1.0) {
                              progressColor = Colors.redAccent;
                            } else if (percent >= 0.8) {
                              progressColor = Colors.orangeAccent;
                            }

                            return Container(
                              margin: const EdgeInsets.symmetric(vertical: 8),
                              decoration: BoxDecoration(
                                color: Theme.of(context).cardColor,
                                borderRadius: BorderRadius.circular(20),
                                border: Border.all(
                                  color: percent >= 1.0 
                                      ? Colors.redAccent.withOpacity(0.5) 
                                      : (percent >= 0.8 ? Colors.orangeAccent.withOpacity(0.5) : (isDark ? Colors.white.withOpacity(0.08) : Colors.black12)),
                                  width: 1.2,
                                ),
                                boxShadow: [
                                  BoxShadow(
                                    color: progressColor.withOpacity(0.12),
                                    blurRadius: 12,
                                    offset: const Offset(0, 4),
                                  ),
                                ],
                              ),
                              padding: const EdgeInsets.all(18.0),
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.stretch,
                                children: [
                                  Row(
                                    crossAxisAlignment: CrossAxisAlignment.center,
                                    children: [
                                      Expanded(
                                        child: Row(
                                          children: [
                                            Container(
                                              padding: const EdgeInsets.all(8),
                                              decoration: BoxDecoration(
                                                color: progressColor.withOpacity(0.15),
                                                shape: BoxShape.circle,
                                              ),
                                              child: Icon(Icons.pie_chart_outline_rounded, color: progressColor, size: 20),
                                            ),
                                            const SizedBox(width: 10),
                                            Flexible(
                                              child: Text(
                                                category,
                                                style: TextStyle(
                                                  fontWeight: FontWeight.bold,
                                                  fontSize: 17,
                                                  color: isDark ? Colors.white : AppTheme.textPrimaryLight,
                                                ),
                                                overflow: TextOverflow.ellipsis,
                                              ),
                                            ),
                                          ],
                                        ),
                                      ),
                                      IconButton(
                                        icon: const Icon(Icons.edit_outlined, color: AppTheme.primaryDark, size: 22),
                                        onPressed: () => _showSetLimitDialog(category),
                                        tooltip: 'Editar presupuesto',
                                        constraints: const BoxConstraints(),
                                        padding: const EdgeInsets.all(6),
                                      ),
                                       PopupMenuButton<String>(
                                         icon: Icon(
                                           Icons.more_vert_rounded,
                                           color: isDark ? Colors.white54 : Colors.black38,
                                           size: 20,
                                         ),
                                         color: Theme.of(context).cardColor,
                                         shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                                         onSelected: (value) async {
                                           if (value == 'delete_budget') {
                                             await _deleteBudget(category);
                                           } else if (value == 'delete_category') {
                                             await _deleteCategory(category);
                                           }
                                         },
                                         itemBuilder: (ctx) => [
                                           if (_budgets.containsKey(category))
                                             PopupMenuItem(
                                               value: 'delete_budget',
                                               child: Row(
                                                 children: [
                                                   const Icon(Icons.money_off_rounded, color: Colors.orangeAccent, size: 18),
                                                   const SizedBox(width: 10),
                                                   Text(
                                                     'Quitar límite',
                                                     style: TextStyle(color: isDark ? Colors.white : AppTheme.textPrimaryLight),
                                                   ),
                                                 ],
                                               ),
                                             ),
                                           PopupMenuItem(
                                             value: 'delete_category',
                                             child: Row(
                                               children: [
                                                 const Icon(Icons.delete_outline_rounded, color: Colors.redAccent, size: 18),
                                                 const SizedBox(width: 10),
                                                 Text(
                                                   ['Comida', 'Transporte', 'Entretenimiento', 'Servicios', 'Otros'].contains(category)
                                                       ? 'Limpiar presupuesto'
                                                       : 'Eliminar categoría',
                                                   style: const TextStyle(color: Colors.redAccent),
                                                 ),
                                               ],
                                             ),
                                           ),
                                         ],
                                       ),
                                    ],
                                  ),
                                  const SizedBox(height: 12),
                                  Row(
                                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                    children: [
                                      Text(
                                        'Gastado: ${currencyFormat.format(spent)}',
                                        style: TextStyle(
                                          color: isDark ? Colors.white70 : AppTheme.textSecondaryLight,
                                          fontSize: 13,
                                          fontWeight: FontWeight.w600,
                                        ),
                                      ),
                                      Text(
                                        limit != null 
                                            ? 'Límite: ${currencyFormat.format(limit)}' 
                                            : 'Sin presupuesto',
                                        style: TextStyle(
                                          color: isDark ? AppTheme.textSecondaryDark : AppTheme.textSecondaryLight,
                                          fontSize: 13,
                                        ),
                                      ),
                                    ],
                                  ),
                                  if (limit != null) ...[
                                    const SizedBox(height: 14),
                                    ClipRRect(
                                      borderRadius: BorderRadius.circular(8),
                                      child: LinearProgressIndicator(
                                        value: percent > 1.0 ? 1.0 : percent,
                                        backgroundColor: isDark ? Colors.white10 : Colors.black12,
                                        color: progressColor,
                                        minHeight: 10,
                                      ),
                                    ),
                                    const SizedBox(height: 10),
                                    Row(
                                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                      children: [
                                        Text(
                                          '${(percent * 100).toStringAsFixed(0)}% consumido',
                                          style: TextStyle(
                                            color: progressColor,
                                            fontWeight: FontWeight.bold,
                                            fontSize: 12,
                                          ),
                                        ),
                                        Container(
                                          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                                          decoration: BoxDecoration(
                                            color: progressColor.withOpacity(0.15),
                                            borderRadius: BorderRadius.circular(10),
                                            border: Border.all(color: progressColor.withOpacity(0.4)),
                                          ),
                                          child: Text(
                                            percent >= 1.0
                                                ? '🔴 Excedido'
                                                : (percent >= 0.8 ? '🟡 Alerta Límite' : '🟢 Seguro'),
                                            style: TextStyle(
                                              color: progressColor,
                                              fontWeight: FontWeight.bold,
                                              fontSize: 11,
                                            ),
                                          ),
                                        ),
                                      ],
                                    ),
                                  ],
                                ],
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
