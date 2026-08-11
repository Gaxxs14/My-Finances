import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';
import 'package:fl_chart/fl_chart.dart';
import '../../../core/providers/global_providers.dart';
import '../../../core/theme/app_theme.dart';
import '../../accounts/presentation/nfc_scanner_sheet.dart';

class DashboardScreen extends ConsumerStatefulWidget {
  const DashboardScreen({super.key});

  @override
  ConsumerState<DashboardScreen> createState() => _DashboardScreenState();
}

class _DashboardScreenState extends ConsumerState<DashboardScreen> {
  final currencyFormat = NumberFormat.currency(locale: 'es_US', symbol: '\$');
  bool _isSyncing = false;

  @override
  void initState() {
    super.initState();
    // No mock data prepopulation. Starts clean at $0.00.
  }

  Color _getColorForCategory(String category) {
    switch (category.toLowerCase()) {
      case 'comida':
        return Colors.orangeAccent;
      case 'transporte':
        return Colors.blueAccent;
      case 'entretenimiento':
        return Colors.purpleAccent;
      case 'sueldo':
        return Colors.greenAccent;
      case 'servicios':
        return Colors.redAccent;
      default:
        return Colors.tealAccent;
    }
  }

  Future<void> _triggerSync() async {
    setState(() => _isSyncing = true);
    try {
      await ref.read(syncServiceProvider).triggerFullSync();
      ref.invalidate(dashboardSummaryProvider);
      ref.invalidate(recentTransactionsProvider);
      ref.invalidate(categorySummaryProvider);
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Sincronización con la nube exitosa.'), backgroundColor: AppTheme.accentDark),
      );
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Error de sincronización: $e'), backgroundColor: Colors.redAccent),
      );
    } finally {
      setState(() => _isSyncing = false);
    }
  }

  void _showAddTransactionDialog() async {
    final repo = ref.read(localTransactionRepositoryProvider);
    final accounts = await repo.getAccounts();

    if (accounts.isEmpty) {
      _showCreateAccountDialog();
      return;
    }

    String type = 'expense';
    double amount = 0.0;
    String category = 'Comida';
    String description = '';
    String accountId = accounts.first['id'] as String;
    
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
                      style: Theme.of(context).textTheme.titleLarge,
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

                    // Account Selector
                    DropdownButtonFormField<String>(
                      value: accountId,
                      decoration: const InputDecoration(
                        labelText: 'Cuenta asociada',
                        prefixIcon: Icon(Icons.account_balance_wallet_outlined),
                      ),
                      dropdownColor: AppTheme.surfaceDark,
                      items: accounts.map((acc) {
                        return DropdownMenuItem<String>(
                          value: acc['id'] as String,
                          child: Text(acc['name'] as String),
                        );
                      }).toList(),
                      onChanged: (val) => setModalState(() => accountId = val!),
                    ),
                    const SizedBox(height: 12),

                    // Amount Input
                    TextFormField(
                      decoration: const InputDecoration(
                        labelText: 'Monto (\$)',
                        prefixIcon: Icon(Icons.attach_money),
                      ),
                      keyboardType: const TextInputType.numberWithOptions(decimal: true),
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

                          await repo.addTransaction(transaction);
                          
                          // Refresh lists
                          ref.invalidate(dashboardSummaryProvider);
                          ref.invalidate(recentTransactionsProvider);
                          ref.invalidate(categorySummaryProvider);
                          
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

  void _showCreateAccountDialog() {
    final formKey = GlobalKey<FormState>();
    final nameController = TextEditingController();
    String accountType = 'bank';
    double initialBalance = 0.0;
    String? nfcUid;

    showDialog(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (context, setStateDialog) => AlertDialog(
          backgroundColor: AppTheme.surfaceDark,
          title: const Text('Crear Nueva Cuenta'),
          content: SingleChildScrollView(
            child: Form(
              key: formKey,
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  // NFC Scan Button
                  ElevatedButton.icon(
                    onPressed: () async {
                      final uid = await NfcScannerSheet.show(ctx);
                      if (uid != null) {
                        setStateDialog(() {
                          nfcUid = uid;
                          accountType = 'card';
                          nameController.text = 'Tarjeta NFC (${uid.length > 8 ? uid.substring(0, 8) : uid})';
                        });
                      }
                    },
                    icon: const Icon(Icons.contactless_outlined, color: Colors.white),
                    label: const Text('Escanear Tarjeta NFC', style: TextStyle(color: Colors.white)),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: Colors.tealAccent.withOpacity(0.2),
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                    ),
                  ),
                  const SizedBox(height: 16),
                  TextFormField(
                    controller: nameController,
                    decoration: const InputDecoration(labelText: 'Nombre de Cuenta'),
                    validator: (val) => (val == null || val.isEmpty) ? 'Requerido' : null,
                  ),
                  const SizedBox(height: 12),
                  DropdownButtonFormField<String>(
                    value: accountType,
                    decoration: const InputDecoration(labelText: 'Tipo de Cuenta'),
                    dropdownColor: AppTheme.surfaceDark,
                    items: const [
                      DropdownMenuItem(value: 'bank', child: Text('Banco')),
                      DropdownMenuItem(value: 'cash', child: Text('Efectivo')),
                      DropdownMenuItem(value: 'card', child: Text('Tarjeta')),
                      DropdownMenuItem(value: 'savings', child: Text('Ahorros')),
                    ],
                    onChanged: (val) => setStateDialog(() => accountType = val!),
                  ),
                  const SizedBox(height: 12),
                  TextFormField(
                    decoration: const InputDecoration(labelText: 'Saldo Inicial (\$)', prefixIcon: Icon(Icons.attach_money)),
                    keyboardType: const TextInputType.numberWithOptions(decimal: true),
                    validator: (val) => (val == null || double.tryParse(val) == null) ? 'Monto inválido' : null,
                    onSaved: (val) => initialBalance = double.parse(val!),
                  ),
                ],
              ),
            ),
          ),
          actions: [
            TextButton(
              child: const Text('Cancelar'),
              onPressed: () => Navigator.pop(ctx),
            ),
            ElevatedButton(
              style: ElevatedButton.styleFrom(backgroundColor: AppTheme.primaryDark),
              child: const Text('Crear', style: TextStyle(color: Colors.white)),
              onPressed: () async {
                if (formKey.currentState!.validate()) {
                  formKey.currentState!.save();
                  
                  await ref.read(localTransactionRepositoryProvider).addAccount({
                    'id': nfcUid ?? DateTime.now().millisecondsSinceEpoch.toString(),
                    'name': nameController.text,
                    'type': accountType,
                    'balance': initialBalance,
                    'currency': 'USD',
                    'is_active': 1,
                  });

                  ref.invalidate(dashboardSummaryProvider);
                  ref.invalidate(recentTransactionsProvider);
                  ref.invalidate(categorySummaryProvider);
                  
                  Navigator.pop(ctx);
                }
              },
            ),
          ],
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final summaryAsync = ref.watch(dashboardSummaryProvider);
    final transactionsAsync = ref.watch(recentTransactionsProvider);
    final categorySummaryAsync = ref.watch(categorySummaryProvider);

    return Scaffold(
      appBar: AppBar(
        title: const Text('My Finances', style: TextStyle(fontWeight: FontWeight.bold)),
        backgroundColor: Colors.transparent,
        elevation: 0,
        actions: [
          IconButton(
            icon: _isSyncing 
                ? const SizedBox(width: 24, height: 24, child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white))
                : const Icon(Icons.sync),
            onPressed: _isSyncing ? null : _triggerSync,
            tooltip: 'Sincronizar con la nube',
          ),
          IconButton(
            icon: const Icon(Icons.logout),
            onPressed: () async {
              await ref.read(authStateProvider.notifier).logout();
            },
            tooltip: 'Cerrar sesión y Bloquear',
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
                data: (summary) {
                  final totalBalance = summary['totalBalance'] ?? 0.0;
                  final income = summary['income'] ?? 0.0;
                  final expense = summary['expense'] ?? 0.0;

                  // If total balance is 0 and no income/expense, show invite to create account
                  if (totalBalance == 0.0 && income == 0.0 && expense == 0.0) {
                    return _buildEmptyStateCard();
                  }

                  return Card(
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
                            currencyFormat.format(totalBalance),
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
                                      Text('INGRESOS DEL MES', style: TextStyle(color: Colors.white70, fontSize: 10)),
                                    ],
                                  ),
                                  const SizedBox(height: 4),
                                  Text(
                                    currencyFormat.format(income),
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
                                      Text('GASTOS DEL MES', style: TextStyle(color: Colors.white70, fontSize: 10)),
                                    ],
                                  ),
                                  const SizedBox(height: 4),
                                  Text(
                                    currencyFormat.format(expense),
                                    style: const TextStyle(color: Colors.white, fontSize: 16, fontWeight: FontWeight.bold),
                                  ),
                                ],
                              ),
                            ],
                          ),
                        ],
                      ),
                    ),
                  );
                },
                loading: () => const Center(child: CircularProgressIndicator()),
                error: (err, stack) => Text('Error: $err'),
              ),
              
              const SizedBox(height: 20),

              // 2. Interactive Expenses Pie Chart (Only if expenses exist)
              categorySummaryAsync.when(
                data: (categorySummary) {
                  if (categorySummary.isEmpty) return const SizedBox.shrink();
                  
                  return Card(
                    child: Padding(
                      padding: const EdgeInsets.all(16.0),
                      child: Column(
                        children: [
                          const Text(
                            'Distribución de Gastos Mensuales',
                            style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
                          ),
                          const SizedBox(height: 20),
                          SizedBox(
                            height: 180,
                            child: PieChart(
                              PieChartData(
                                sectionsSpace: 2,
                                centerSpaceRadius: 40,
                                sections: categorySummary.entries.map((entry) {
                                  return PieChartSectionData(
                                    color: _getColorForCategory(entry.key),
                                    value: entry.value,
                                    title: '${entry.key}\n${currencyFormat.format(entry.value)}',
                                    radius: 50,
                                    titleStyle: const TextStyle(
                                      fontSize: 10,
                                      fontWeight: FontWeight.bold,
                                      color: Colors.white,
                                    ),
                                  );
                                }).toList(),
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                  );
                },
                loading: () => const SizedBox.shrink(),
                error: (err, stack) => const SizedBox.shrink(),
              ),

              const SizedBox(height: 24),

              // 3. Section Header
              Text(
                'Transacciones Recientes',
                style: Theme.of(context).textTheme.titleLarge?.copyWith(
                      fontWeight: FontWeight.bold,
                    ),
              ),
              const SizedBox(height: 12),

              // 4. Transactions List
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

  Widget _buildEmptyStateCard() {
    return Card(
      elevation: 0,
      color: AppTheme.surfaceDark.withOpacity(0.5),
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(16),
        side: BorderSide(color: AppTheme.primaryDark.withOpacity(0.1)),
      ),
      child: Padding(
        padding: const EdgeInsets.all(32.0),
        child: Column(
          children: [
            const Icon(Icons.account_balance_wallet_outlined, size: 64, color: AppTheme.primaryDark),
            const SizedBox(height: 16),
            const Text(
              'No tienes cuentas creadas',
              style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: Colors.white),
            ),
            const SizedBox(height: 8),
            const Text(
              'Crea una cuenta en efectivo, banco o tarjeta bancaria para registrar tus saldos reales y movimientos.',
              textAlign: TextAlign.center,
              style: TextStyle(color: AppTheme.textSecondaryDark),
            ),
            const SizedBox(height: 24),
            ElevatedButton.icon(
              icon: const Icon(Icons.add, color: Colors.white),
              label: const Text('Crear Primera Cuenta', style: TextStyle(color: Colors.white)),
              style: ElevatedButton.styleFrom(
                backgroundColor: AppTheme.primaryDark,
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
              ),
              onPressed: _showCreateAccountDialog,
            )
          ],
        ),
      ),
    );
  }
}
