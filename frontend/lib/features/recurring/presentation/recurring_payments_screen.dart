import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';
import 'package:sqflite_sqlcipher/sqflite.dart';
import '../../../../core/theme/app_theme.dart';
import '../../../../core/widgets/app_toast.dart';
import '../../../../core/database/db_helper.dart';
import '../../../../core/providers/global_providers.dart';
import '../../../../core/services/exchange_rate_service.dart';

final recurringPaymentsProvider = FutureProvider.autoDispose<List<Map<String, dynamic>>>((ref) async {
  final db = ref.watch(dbHelperProvider).database;
  return await db.query('recurring_payments', orderBy: 'due_day ASC');
});

class RecurringPaymentsScreen extends ConsumerStatefulWidget {
  const RecurringPaymentsScreen({super.key});

  @override
  ConsumerState<RecurringPaymentsScreen> createState() => _RecurringPaymentsScreenState();
}

class _RecurringPaymentsScreenState extends ConsumerState<RecurringPaymentsScreen> {
  bool _showInVes = true;

  @override
  Widget build(BuildContext context) {
    final subscriptionsAsync = ref.watch(recurringPaymentsProvider);
    final ratesState = ref.watch(exchangeRatesProvider);
    final double bcvRate = (ratesState.valueOrNull?.bcvUsd != null && ratesState.valueOrNull!.bcvUsd > 0)
        ? ratesState.valueOrNull!.bcvUsd
        : 764.35;

    final isDark = Theme.of(context).brightness == Brightness.dark;
    final now = DateTime.now();
    final currentMonthStr = '${now.year}-${now.month.toString().padLeft(2, '0')}';

    return Scaffold(
      appBar: AppBar(
        title: const Text('Pagos Fijos y Suscripciones', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 18)),
        actions: [
          IconButton(
            icon: Icon(_showInVes ? Icons.currency_exchange_rounded : Icons.attach_money_rounded),
            tooltip: _showInVes ? 'Ver en USD' : 'Ver en Bs.',
            onPressed: () => setState(() => _showInVes = !_showInVes),
          ),
        ],
      ),
      body: subscriptionsAsync.when(
        loading: () => const Center(child: CircularProgressIndicator(color: AppTheme.primaryDark)),
        error: (err, _) => Center(child: Text('Error: $err')),
        data: (subs) {
          if (subs.isEmpty) {
            return Center(
              child: Padding(
                padding: const EdgeInsets.all(32),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Container(
                      padding: const EdgeInsets.all(24),
                      decoration: BoxDecoration(
                        color: const Color(0xFFF59E0B).withOpacity(0.15),
                        shape: BoxShape.circle,
                      ),
                      child: const Icon(Icons.event_repeat_rounded, size: 64, color: Color(0xFFF59E0B)),
                    ),
                    const SizedBox(height: 20),
                    Text(
                      'Sin Pagos Fijos ni Suscripciones',
                      style: TextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.bold,
                        color: isDark ? Colors.white : AppTheme.textPrimaryLight,
                      ),
                    ),
                    const SizedBox(height: 8),
                    Text(
                      'Lleva el control de tus servicios recurrentes (Netflix, Internet, Alquiler, Condominio) y no olvides ninguna fecha de pago.',
                      style: TextStyle(fontSize: 13, color: isDark ? Colors.white60 : Colors.black54),
                      textAlign: TextAlign.center,
                    ),
                    const SizedBox(height: 24),
                    ElevatedButton.icon(
                      icon: const Icon(Icons.add_rounded, color: Colors.white),
                      label: const Text('Agregar Servicio / Suscripción', style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: AppTheme.primaryDark,
                        padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 14),
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                      ),
                      onPressed: () => _showAddSubscriptionDialog(),
                    ),
                  ],
                ),
              ),
            );
          }

          double totalMonthlyUsd = 0.0;
          int pendingCount = 0;
          for (var s in subs) {
            totalMonthlyUsd += (s['amount'] as num).toDouble();
            final lastPaid = s['last_paid_month'] as String?;
            if (lastPaid != currentMonthStr) {
              pendingCount++;
            }
          }

          return ListView(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
            children: [
              // Monthly commitment card
              Container(
                padding: const EdgeInsets.all(20),
                decoration: BoxDecoration(
                  gradient: const LinearGradient(
                    colors: [Color(0xFF1E293B), Color(0xFF0F172A)],
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                  ),
                  borderRadius: BorderRadius.circular(24),
                  border: Border.all(color: AppTheme.primaryDark.withOpacity(0.3), width: 1.5),
                ),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Text(
                          'Compromiso Mensual Fijo',
                          style: TextStyle(color: Colors.white70, fontSize: 12),
                        ),
                        const SizedBox(height: 6),
                        Text(
                          _formatAmount(totalMonthlyUsd, bcvRate),
                          style: const TextStyle(color: Colors.white, fontSize: 24, fontWeight: FontWeight.bold),
                        ),
                        const SizedBox(height: 4),
                        Text(
                          '$pendingCount pagos pendientes este mes',
                          style: TextStyle(
                            color: pendingCount > 0 ? const Color(0xFFF59E0B) : const Color(0xFF10B981),
                            fontSize: 12,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                      ],
                    ),
                    Container(
                      padding: const EdgeInsets.all(12),
                      decoration: BoxDecoration(
                        color: AppTheme.primaryDark.withOpacity(0.2),
                        shape: BoxShape.circle,
                      ),
                      child: const Icon(Icons.receipt_long_rounded, color: AppTheme.primaryDark, size: 28),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 20),

              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text(
                    'Servicios Registrados (${subs.length})',
                    style: TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.bold,
                      color: isDark ? Colors.white : AppTheme.textPrimaryLight,
                    ),
                  ),
                  TextButton.icon(
                    icon: const Icon(Icons.add_rounded, size: 18),
                    label: const Text('Agregar', style: TextStyle(fontWeight: FontWeight.bold)),
                    onPressed: () => _showAddSubscriptionDialog(),
                  ),
                ],
              ),
              const SizedBox(height: 8),

              ...subs.map((s) => _buildSubscriptionCard(s, bcvRate, isDark, currentMonthStr)),
            ],
          );
        },
      ),
    );
  }

  Widget _buildSubscriptionCard(Map<String, dynamic> sub, double bcvRate, bool isDark, String currentMonthStr) {
    final String id = sub['id'] as String;
    final String name = sub['name'] as String;
    final double amount = (sub['amount'] as num).toDouble();
    final String category = sub['category'] as String;
    final int dueDay = sub['due_day'] as int;
    final String? lastPaid = sub['last_paid_month'] as String?;
    final bool isPaidThisMonth = lastPaid == currentMonthStr;

    final now = DateTime.now();
    int daysUntilDue = dueDay - now.day;
    if (daysUntilDue < 0) {
      daysUntilDue += 30;
    }

    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: isDark ? const Color(0xFF1E293B) : Colors.white,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(
          color: isPaidThisMonth ? const Color(0xFF10B981).withOpacity(0.4) : (daysUntilDue <= 3 ? Colors.orange.withOpacity(0.5) : (isDark ? Colors.white10 : Colors.black12)),
          width: 1.2,
        ),
      ),
      child: Column(
        children: [
          Row(
            children: [
              Container(
                padding: const EdgeInsets.all(10),
                decoration: BoxDecoration(
                  color: isPaidThisMonth ? const Color(0xFF10B981).withOpacity(0.15) : const Color(0xFF06B6D4).withOpacity(0.15),
                  shape: BoxShape.circle,
                ),
                child: Icon(
                  isPaidThisMonth ? Icons.check_circle_rounded : Icons.calendar_month_rounded,
                  color: isPaidThisMonth ? const Color(0xFF10B981) : const Color(0xFF06B6D4),
                  size: 22,
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      name,
                      style: TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.bold,
                        color: isDark ? Colors.white : AppTheme.textPrimaryLight,
                      ),
                    ),
                    Text(
                      '$category • Vence el día $dueDay de cada mes',
                      style: TextStyle(fontSize: 11, color: isDark ? Colors.white54 : Colors.black54),
                    ),
                  ],
                ),
              ),
              Text(
                _formatAmount(amount, bcvRate),
                style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
              ),
              PopupMenuButton<String>(
                icon: const Icon(Icons.more_vert_rounded),
                onSelected: (val) {
                  if (val == 'delete') _deleteSubscription(id, name);
                },
                itemBuilder: (ctx) => [
                  const PopupMenuItem(value: 'delete', child: Row(children: [Icon(Icons.delete_outline_rounded, color: Colors.red, size: 18), SizedBox(width: 8), Text('Eliminar')])),
                ],
              ),
            ],
          ),
          const SizedBox(height: 12),

          // Action row
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                decoration: BoxDecoration(
                  color: isPaidThisMonth ? const Color(0xFF10B981).withOpacity(0.15) : const Color(0xFFF59E0B).withOpacity(0.15),
                  borderRadius: BorderRadius.circular(10),
                ),
                child: Text(
                  isPaidThisMonth ? '✓ Pagado este mes' : 'Pendiente (en $daysUntilDue días)',
                  style: TextStyle(
                    fontSize: 11,
                    fontWeight: FontWeight.bold,
                    color: isPaidThisMonth ? const Color(0xFF10B981) : const Color(0xFFF59E0B),
                  ),
                ),
              ),
              if (!isPaidThisMonth)
                ElevatedButton.icon(
                  icon: const Icon(Icons.check_rounded, size: 16, color: Colors.white),
                  label: const Text('Pagar Ahora', style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold, color: Colors.white)),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: AppTheme.primaryDark,
                    padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                  ),
                  onPressed: () => _paySubscription(sub, currentMonthStr),
                ),
            ],
          ),
        ],
      ),
    );
  }

  String _formatAmount(double usd, double bcvRate) {
    if (_showInVes) {
      final ves = usd * bcvRate;
      return 'Bs. ${NumberFormat.currency(locale: 'es_VE', symbol: '', decimalDigits: 2).format(ves).trim()}';
    } else {
      return '\$ ${usd.toStringAsFixed(2)}';
    }
  }

  Future<void> _showAddSubscriptionDialog() async {
    final nameCtrl = TextEditingController();
    final amountCtrl = TextEditingController();
    final dayCtrl = TextEditingController(text: '15');
    String category = 'Servicios';
    String currency = 'USD';
    String? selectedAccountId;

    final db = ref.read(dbHelperProvider).database;
    final List<Map<String, dynamic>> accounts = await db.query('accounts');
    if (accounts.isNotEmpty) {
      selectedAccountId = accounts.first['id'] as String;
    }

    final ratesState = ref.read(exchangeRatesProvider);
    final double bcvRate = (ratesState.valueOrNull?.bcvUsd != null && ratesState.valueOrNull!.bcvUsd > 0)
        ? ratesState.valueOrNull!.bcvUsd
        : 764.35;

    await showDialog(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setDialogState) {
          return AlertDialog(
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(24)),
            title: const Row(
              children: [
                Icon(Icons.event_repeat_rounded, color: AppTheme.primaryDark),
                SizedBox(width: 10),
                Text('Nuevo Pago Recurrente', style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
              ],
            ),
            content: SingleChildScrollView(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  TextField(
                    controller: nameCtrl,
                    decoration: InputDecoration(
                      labelText: 'Nombre del Servicio',
                      hintText: 'Ej: Netflix, Internet Fibra, Alquiler',
                      border: OutlineInputBorder(borderRadius: BorderRadius.circular(14)),
                    ),
                  ),
                  const SizedBox(height: 14),
                  Row(
                    children: [
                      Expanded(
                        flex: 2,
                        child: TextField(
                          controller: amountCtrl,
                          keyboardType: const TextInputType.numberWithOptions(decimal: true),
                          decoration: InputDecoration(
                            labelText: 'Monto Mensual',
                            border: OutlineInputBorder(borderRadius: BorderRadius.circular(14)),
                          ),
                        ),
                      ),
                      const SizedBox(width: 8),
                      Expanded(
                        flex: 1,
                        child: DropdownButtonFormField<String>(
                          value: currency,
                          decoration: InputDecoration(
                            border: OutlineInputBorder(borderRadius: BorderRadius.circular(14)),
                          ),
                          items: const [
                            DropdownMenuItem(value: 'USD', child: Text('\$ USD')),
                            DropdownMenuItem(value: 'VES', child: Text('Bs.')),
                          ],
                          onChanged: (val) => setDialogState(() => currency = val ?? 'USD'),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 14),
                  Row(
                    children: [
                      Expanded(
                        child: TextField(
                          controller: dayCtrl,
                          keyboardType: TextInputType.number,
                          decoration: InputDecoration(
                            labelText: 'Día de Cobro (1-31)',
                            hintText: 'Ej: 5, 15, 28',
                            border: OutlineInputBorder(borderRadius: BorderRadius.circular(14)),
                          ),
                        ),
                      ),
                      const SizedBox(width: 8),
                      Expanded(
                        child: DropdownButtonFormField<String>(
                          value: category,
                          decoration: InputDecoration(
                            labelText: 'Categoría',
                            border: OutlineInputBorder(borderRadius: BorderRadius.circular(14)),
                          ),
                          items: const [
                            DropdownMenuItem(value: 'Servicios', child: Text('Servicios')),
                            DropdownMenuItem(value: 'Entretenimiento', child: Text('Streaming')),
                            DropdownMenuItem(value: 'Hogar', child: Text('Hogar')),
                            DropdownMenuItem(value: 'Salud', child: Text('Salud')),
                            DropdownMenuItem(value: 'Educación', child: Text('Educación')),
                            DropdownMenuItem(value: 'Otros', child: Text('Otros')),
                          ],
                          onChanged: (val) => setDialogState(() => category = val ?? 'Servicios'),
                        ),
                      ),
                    ],
                  ),
                  if (accounts.isNotEmpty) ...[
                    const SizedBox(height: 14),
                    DropdownButtonFormField<String>(
                      value: selectedAccountId,
                      decoration: InputDecoration(
                        labelText: 'Tarjeta / Cuenta para Pagar',
                        border: OutlineInputBorder(borderRadius: BorderRadius.circular(14)),
                      ),
                      items: accounts.map((a) {
                        return DropdownMenuItem<String>(
                          value: a['id'] as String,
                          child: Text(a['name'] as String),
                        );
                      }).toList(),
                      onChanged: (val) => setDialogState(() => selectedAccountId = val),
                    ),
                  ],
                ],
              ),
            ),
            actions: [
              TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('Cancelar')),
              ElevatedButton(
                style: ElevatedButton.styleFrom(
                  backgroundColor: AppTheme.primaryDark,
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                ),
                onPressed: () async {
                  final name = nameCtrl.text.trim();
                  final rawAmount = double.tryParse(amountCtrl.text.replaceAll(',', '.')) ?? 0.0;
                  final dueDay = int.tryParse(dayCtrl.text.trim()) ?? 15;

                  if (name.isEmpty || rawAmount <= 0) {
                    AppToast.show(context, message: 'Ingresa un nombre y monto válido.', type: AppToastType.warning);
                    return;
                  }

                  final double amountUsd = currency == 'VES' ? (rawAmount / bcvRate) : rawAmount;

                  await db.insert('recurring_payments', {
                    'id': 'sub_${DateTime.now().millisecondsSinceEpoch}',
                    'account_id': selectedAccountId,
                    'name': name,
                    'amount': amountUsd,
                    'currency': currency,
                    'category': category,
                    'due_day': dueDay.clamp(1, 31),
                    'icon_name': 'receipt',
                    'is_active': 1,
                    'last_paid_month': null,
                  });

                  if (mounted) {
                    Navigator.pop(ctx);
                    ref.invalidate(recurringPaymentsProvider);
                    AppToast.show(context, message: '¡Pago fijo "$name" registrado!', type: AppToastType.success);
                  }
                },
                child: const Text('Guardar', style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
              ),
            ],
          );
        },
      ),
    );
  }

  Future<void> _paySubscription(Map<String, dynamic> sub, String currentMonthStr) async {
    final db = ref.read(dbHelperProvider).database;
    final String subId = sub['id'] as String;
    final String name = sub['name'] as String;
    final double amountUsd = (sub['amount'] as num).toDouble();
    final String? accountId = sub['account_id'] as String?;
    final String category = sub['category'] as String;

    await db.transaction((txn) async {
      // Mark subscription as paid for current month
      await txn.update(
        'recurring_payments',
        {'last_paid_month': currentMonthStr},
        where: 'id = ?',
        whereArgs: [subId],
      );

      // Record transaction and deduct from account if assigned
      if (accountId != null) {
        final accRes = await txn.query('accounts', where: 'id = ?', whereArgs: [accountId]);
        if (accRes.isNotEmpty) {
          final currentBal = (accRes.first['balance'] as num).toDouble();
          await txn.update(
            'accounts',
            {'balance': currentBal - amountUsd},
            where: 'id = ?',
            whereArgs: [accountId],
          );
        }

        await txn.insert('transactions', {
          'id': 'tx_${DateTime.now().millisecondsSinceEpoch}',
          'account_id': accountId,
          'type': 'expense',
          'amount': amountUsd,
          'currency': sub['currency'] ?? 'VES',
          'category': category,
          'description': 'Pago de Suscripción: $name',
          'date': DateTime.now().toIso8601String(),
          'is_synced': 0,
        });
      }
    });

    ref.invalidate(recurringPaymentsProvider);
    ref.invalidate(dashboardSummaryProvider);
    ref.invalidate(recentTransactionsProvider);
    ref.invalidate(accountsListProvider);
    if (mounted) {
      AppToast.show(context, message: '¡Pago de "$name" registrado con éxito!', type: AppToastType.success);
    }
  }

  Future<void> _deleteSubscription(String id, String name) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        title: const Text('Eliminar Suscripción', style: TextStyle(fontWeight: FontWeight.bold)),
        content: Text('¿Deseas eliminar el pago fijo de "$name"?'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('Cancelar')),
          ElevatedButton(
            style: ElevatedButton.styleFrom(backgroundColor: Colors.red),
            onPressed: () => Navigator.pop(ctx, true),
            child: const Text('Eliminar', style: TextStyle(color: Colors.white)),
          ),
        ],
      ),
    );

    if (confirmed == true) {
      final db = ref.read(dbHelperProvider).database;
      await db.delete('recurring_payments', where: 'id = ?', whereArgs: [id]);
      ref.invalidate(recurringPaymentsProvider);
      if (mounted) {
        AppToast.show(context, message: 'Suscripción eliminada.', type: AppToastType.info);
      }
    }
  }
}
