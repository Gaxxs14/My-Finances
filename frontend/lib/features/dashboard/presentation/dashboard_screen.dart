import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';
import '../../../core/providers/global_providers.dart';
import '../../../core/theme/app_theme.dart';

class DashboardScreen extends ConsumerStatefulWidget {
  const DashboardScreen({super.key});

  @override
  ConsumerState<DashboardScreen> createState() => _DashboardScreenState();
}

class _DashboardScreenState extends ConsumerState<DashboardScreen> {
  final currencyFormat = NumberFormat.currency(locale: 'es_US', symbol: '\$');

  @override
  void initState() {
    super.initState();
    _checkInitialAccounts();
  }

  // Prepopulate with a default cash and bank account if none exists, just for UX demo
  Future<void> _checkInitialAccounts() async {
    final repo = ref.read(localTransactionRepositoryProvider);
    final accounts = await repo.getAccounts();
    if (accounts.isEmpty) {
      await repo.addAccount({
        'id': 'acc-1',
        'name': 'Efectivo Personal',
        'type': 'cash',
        'balance': 250.00,
        'currency': 'USD',
      });
      await repo.addAccount({
        'id': 'acc-2',
        'name': 'Cuenta de Ahorros',
        'type': 'bank',
        'balance': 1500.00,
        'currency': 'USD',
      });
      
      // Force riverpod refresh
      ref.invalidate(dashboardSummaryProvider);
      ref.invalidate(recentTransactionsProvider);
    }
  }

  void _showAddTransactionDialog() {
    String type = 'expense';
    double amount = 0.0;
    String category = 'Comida';
    String description = '';
    String accountId = 'acc-1';
    
    final formKey = GlobalKey<FormState>();

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: AppTheme.surfaceDark,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      builder: (ctx) {
        return StatefulBuilder(
          builder: (context, setModalState) {
            return Padding(
              padding: EdgeInsets.only(
                left: 20,
                right: 20,
                top: 24,
                bottom: MediaQuery.of(context).viewInsets.bottom + 24,
              ),
              child: Form(
                key: formKey,
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    Text(
                      'Nuevo Registro',
                      style: Theme.of(context).textTheme.headlineMedium?.copyWith(
                            fontSize: 20,
                          ),
                    ),
                    const SizedBox(height: 16),
                    
                    // Transaction Type Selector
                    Row(
                      children: [
                        Expanded(
                          child: ChoiceChip(
                            label: const Text('Gasto'),
                            selected: type == 'expense',
                            onSelected: (selected) {
                              if (selected) setModalState(() => type = 'expense');
                            },
                          ),
                        ),
                        const SizedBox(width: 8),
                        Expanded(
                          child: ChoiceChip(
                            label: const Text('Ingreso'),
                            selected: type == 'income',
                            onSelected: (selected) {
                              if (selected) setModalState(() => type = 'income');
                            },
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 16),

                    // Amount Input
                    TextFormField(
                      decoration: const InputDecoration(
                        labelText: 'Monto (\$)',
                        prefixIcon: Icon(Icons.attach_money),
                      ),
                      keyboardType: TextInputType.numberWithOptions(decimal: true),
                      validator: (value) {
                        if (value == null || value.isEmpty) return 'Introduce un monto';
                        if (double.tryParse(value) == null) return 'Formato inválido';
                        return null;
                      },
                      onSaved: (val) => amount = double.parse(val!),
                    ),
                    const SizedBox(height: 12),

                    // Category Selector
                    DropdownButtonFormField<String>(
                      value: category,
                      decoration: const InputDecoration(
                        labelText: 'Categoría',
                        prefixIcon: Icon(Icons.category_outlined),
                      ),
                      dropdownColor: AppTheme.surfaceDark,
                      items: <String>['Comida', 'Transporte', 'Entretenimiento', 'Sueldo', 'Servicios', 'Otros']
                          .map((String cat) {
                        return DropdownMenuItem<String>(
                          value: cat,
                          child: Text(cat),
                        );
                      }).toList(),
                      onChanged: (val) => setModalState(() => category = val!),
                    ),
                    const SizedBox(height: 12),

                    // Description Input
                    TextFormField(
                      decoration: const InputDecoration(
                        labelText: 'Detalles',
                        prefixIcon: Icon(Icons.description_outlined),
                      ),
                      onSaved: (val) => description = val ?? '',
                    ),
                    const SizedBox(height: 24),

                    // Submit Button
                    ElevatedButton(
                      onPressed: () async {
                        if (formKey.currentState!.validate()) {
                          formKey.currentState!.save();
                          
                          final transaction = {
                            'id': DateTime.now().millisecondsSinceEpoch.toString(),
                            'account_id': accountId,
                            'type': type,
                            'amount': amount,
                            'category': category,
                            'description': description,
                            'date': DateTime.now().toIso8601String(),
                            'is_synced': 0,
                          };

                          await ref.read(localTransactionRepositoryProvider).addTransaction(transaction);
                          
                          // Refresh lists
                          ref.invalidate(dashboardSummaryProvider);
                          ref.invalidate(recentTransactionsProvider);
                          
                          Navigator.pop(ctx);
                        }
                      },
                      style: ElevatedButton.styleFrom(
                        backgroundColor: AppTheme.primaryDark,
                        padding: const EdgeInsets.symmetric(vertical: 16),
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                      ),
                      child: const Text('Guardar Registro', style: TextStyle(color: Colors.white, fontSize: 16)),
                    ),
                  ],
                ),
              ),
            );
          },
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    final summaryAsync = ref.watch(dashboardSummaryProvider);
    final transactionsAsync = ref.watch(recentTransactionsProvider);

    return Scaffold(
      appBar: AppBar(
        title: const Text('My Finances', style: TextStyle(fontWeight: FontWeight.bold)),
        backgroundColor: Colors.transparent,
        elevation: 0,
        actions: [
          IconButton(
            icon: const Icon(Icons.logout),
            onPressed: () async {
              await ref.read(authStateProvider.notifier).logout();
            },
          )
        ],
      ),
      body: SingleChildScrollView(
        child: Padding(
          padding: const EdgeInsets.all(16.0),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              // 1. Total Balance Summary Card
              summaryAsync.when(
                data: (summary) => Card(
                  child: Container(
                    decoration: BoxDecoration(
                      gradient: const LinearGradient(
                        colors: [AppTheme.primaryDark, Color(0xFF818CF8)],
                        begin: Alignment.topLeft,
                        end: Alignment.bottomRight,
                      ),
                      borderRadius: BorderRadius.circular(16),
                    ),
                    padding: const EdgeInsets.all(24.0),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Text(
                          'SALDO NETO TOTAL',
                          style: TextStyle(
                            color: Colors.white70,
                            fontSize: 12,
                            fontWeight: FontWeight.bold,
                            letterSpacing: 1.5,
                          ),
                        ),
                        const SizedBox(height: 8),
                        Text(
                          currencyFormat.format(summary['totalBalance'] ?? 0.0),
                          style: const TextStyle(
                            color: Colors.white,
                            fontSize: 36,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                        const SizedBox(height: 24),
                        Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                const Row(
                                  children: [
                                    Icon(Icons.arrow_downward, color: Colors.greenAccent, size: 16),
                                    SizedBox(width: 4),
                                    Text('INGRESOS', style: TextStyle(color: Colors.white70, fontSize: 10)),
                                  ],
                                ),
                                const SizedBox(height: 4),
                                Text(
                                  currencyFormat.format(summary['income'] ?? 0.0),
                                  style: const TextStyle(color: Colors.white, fontSize: 16, fontWeight: FontWeight.bold),
                                ),
                              ],
                            ),
                            Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                const Row(
                                  children: [
                                    Icon(Icons.arrow_upward, color: Colors.redAccent, size: 16),
                                    SizedBox(width: 4),
                                    Text('GASTOS', style: TextStyle(color: Colors.white70, fontSize: 10)),
                                  ],
                                ),
                                const SizedBox(height: 4),
                                Text(
                                  currencyFormat.format(summary['expense'] ?? 0.0),
                                  style: const TextStyle(color: Colors.white, fontSize: 16, fontWeight: FontWeight.bold),
                                ),
                              ],
                            ),
                          ],
                        ),
                      ],
                    ),
                  ),
                ),
                loading: () => const Center(child: CircularProgressIndicator()),
                error: (err, stack) => Text('Error: $err'),
              ),
              
              const SizedBox(height: 24),

              // 2. Section Header
              Text(
                'Transacciones Recientes',
                style: Theme.of(context).textTheme.titleLarge?.copyWith(
                      fontWeight: FontWeight.bold,
                    ),
              ),
              const SizedBox(height: 12),

              // 3. Transactions List
              transactionsAsync.when(
                data: (txList) {
                  if (txList.isEmpty) {
                    return const Padding(
                      padding: EdgeInsets.symmetric(vertical: 24.0),
                      child: Center(
                        child: Text(
                          'No hay transacciones registradas este mes.',
                          style: TextStyle(color: AppTheme.textSecondaryDark),
                        ),
                      ),
                    );
                  }
                  return ListView.builder(
                    shrinkWrap: true,
                    physics: const NeverScrollableScrollPhysics(),
                    itemCount: txList.length,
                    itemBuilder: (context, index) {
                      final tx = txList[index];
                      final isIncome = tx['type'] == 'income';
                      final DateTime date = DateTime.parse(tx['date'] as String);
                      final formattedDate = DateFormat.yMMMd('es_US').format(date);

                      return Card(
                        margin: const EdgeInsets.symmetric(vertical: 6),
                        child: ListTile(
                          leading: CircleAvatar(
                            backgroundColor: isIncome
                                ? AppTheme.accentDark.withOpacity(0.1)
                                : Colors.redAccent.withOpacity(0.1),
                            child: Icon(
                              isIncome ? Icons.arrow_downward : Icons.arrow_upward,
                              color: isIncome ? AppTheme.accentDark : Colors.redAccent,
                            ),
                          ),
                          title: Text(
                            tx['category'] as String,
                            style: const TextStyle(fontWeight: FontWeight.bold),
                          ),
                          subtitle: Text(
                            tx['description'] != null && (tx['description'] as String).isNotEmpty
                                ? tx['description'] as String
                                : formattedDate,
                          ),
                          trailing: Column(
                            mainAxisAlignment: MainAxisAlignment.center,
                            crossAxisAlignment: CrossAxisAlignment.end,
                            children: [
                              Text(
                                '${isIncome ? '+' : '-'}${currencyFormat.format(tx['amount'])}',
                                style: TextStyle(
                                  fontWeight: FontWeight.bold,
                                  fontSize: 16,
                                  color: isIncome ? AppTheme.accentDark : Colors.redAccent,
                                ),
                              ),
                              if (tx['is_synced'] == 0)
                                const Icon(Icons.sync_problem, size: 12, color: Colors.amberAccent)
                              else
                                const Icon(Icons.done_all, size: 12, color: Colors.blueAccent),
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
            ],
          ),
        ),
      ),
      floatingActionButton: FloatingActionButton(
        onPressed: _showAddTransactionDialog,
        backgroundColor: AppTheme.primaryDark,
        child: const Icon(Icons.add, color: Colors.white),
      ),
    );
  }
}
