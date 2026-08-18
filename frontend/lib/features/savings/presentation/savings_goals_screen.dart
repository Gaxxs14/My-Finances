import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';
import 'package:sqflite_sqlcipher/sqflite.dart';
import '../../../../core/theme/app_theme.dart';
import '../../../../core/widgets/app_toast.dart';
import '../../../../core/database/db_helper.dart';
import '../../../../core/providers/global_providers.dart';
import '../../../../core/services/exchange_rate_service.dart';

final savingsGoalsProvider = FutureProvider.autoDispose<List<Map<String, dynamic>>>((ref) async {
  final db = ref.watch(dbHelperProvider).database;
  return await db.query('savings_goals', orderBy: 'created_at DESC');
});

class SavingsGoalsScreen extends ConsumerStatefulWidget {
  const SavingsGoalsScreen({super.key});

  @override
  ConsumerState<SavingsGoalsScreen> createState() => _SavingsGoalsScreenState();
}

class _SavingsGoalsScreenState extends ConsumerState<SavingsGoalsScreen> {
  bool _showInVes = true;

  @override
  Widget build(BuildContext context) {
    final goalsAsync = ref.watch(savingsGoalsProvider);
    final ratesState = ref.watch(exchangeRatesProvider);
    final double bcvRate = (ratesState.valueOrNull?.bcvUsd != null && ratesState.valueOrNull!.bcvUsd > 0)
        ? ratesState.valueOrNull!.bcvUsd
        : 764.35;

    final isDark = Theme.of(context).brightness == Brightness.dark;

    return Scaffold(
      appBar: AppBar(
        title: const Text('Metas de Ahorro', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 18)),
        actions: [
          IconButton(
            icon: Icon(_showInVes ? Icons.currency_exchange_rounded : Icons.attach_money_rounded),
            tooltip: _showInVes ? 'Ver en USD' : 'Ver en Bs.',
            onPressed: () => setState(() => _showInVes = !_showInVes),
          ),
        ],
      ),
      body: goalsAsync.when(
        loading: () => const Center(child: CircularProgressIndicator(color: AppTheme.primaryDark)),
        error: (err, _) => Center(child: Text('Error: $err')),
        data: (goals) {
          if (goals.isEmpty) {
            return Center(
              child: Padding(
                padding: const EdgeInsets.all(32),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Container(
                      padding: const EdgeInsets.all(24),
                      decoration: BoxDecoration(
                        color: AppTheme.primaryDark.withOpacity(0.15),
                        shape: BoxShape.circle,
                      ),
                      child: const Icon(Icons.savings_rounded, size: 64, color: AppTheme.primaryDark),
                    ),
                    const SizedBox(height: 20),
                    Text(
                      'No tienes metas de ahorro activas',
                      style: TextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.bold,
                        color: isDark ? Colors.white : AppTheme.textPrimaryLight,
                      ),
                    ),
                    const SizedBox(height: 8),
                    Text(
                      'Define tus objetivos financieros (un viaje, un teléfono, un fondo de emergencia) y ahorra paso a paso.',
                      style: TextStyle(fontSize: 13, color: isDark ? Colors.white60 : Colors.black54),
                      textAlign: TextAlign.center,
                    ),
                    const SizedBox(height: 24),
                    ElevatedButton.icon(
                      icon: const Icon(Icons.add_rounded, color: Colors.white),
                      label: const Text('Crear Primera Meta', style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: AppTheme.primaryDark,
                        padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 14),
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                      ),
                      onPressed: () => _showAddGoalDialog(),
                    ),
                  ],
                ),
              ),
            );
          }

          double totalTargetUsd = 0.0;
          double totalSavedUsd = 0.0;
          for (var g in goals) {
            totalTargetUsd += (g['target_amount'] as num).toDouble();
            totalSavedUsd += (g['current_amount'] as num).toDouble();
          }

          final overallProgress = totalTargetUsd > 0 ? (totalSavedUsd / totalTargetUsd).clamp(0.0, 1.0) : 0.0;

          return ListView(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
            children: [
              // Summary Banner
              Container(
                padding: const EdgeInsets.all(20),
                decoration: BoxDecoration(
                  gradient: const LinearGradient(
                    colors: [Color(0xFF0F766E), Color(0xFF06B6D4)],
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                  ),
                  borderRadius: BorderRadius.circular(24),
                  boxShadow: [
                    BoxShadow(
                      color: const Color(0xFF0F766E).withOpacity(0.3),
                      blurRadius: 16,
                      offset: const Offset(0, 8),
                    ),
                  ],
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        const Text(
                          'Total Ahorrado en Metas',
                          style: TextStyle(color: Colors.white70, fontSize: 13),
                        ),
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                          decoration: BoxDecoration(
                            color: Colors.white.withOpacity(0.2),
                            borderRadius: BorderRadius.circular(12),
                          ),
                          child: Text(
                            '${(overallProgress * 100).toStringAsFixed(1)}%',
                            style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 12),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 8),
                    Text(
                      _formatAmount(totalSavedUsd, bcvRate),
                      style: const TextStyle(color: Colors.white, fontSize: 26, fontWeight: FontWeight.bold),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      'Meta Total: ${_formatAmount(totalTargetUsd, bcvRate)}',
                      style: const TextStyle(color: Colors.white70, fontSize: 12),
                    ),
                    const SizedBox(height: 14),
                    ClipRRect(
                      borderRadius: BorderRadius.circular(8),
                      child: LinearProgressIndicator(
                        value: overallProgress,
                        backgroundColor: Colors.white.withOpacity(0.2),
                        valueColor: const AlwaysStoppedAnimation<Color>(Colors.white),
                        minHeight: 8,
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 20),

              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text(
                    'Tus Objetivos (${goals.length})',
                    style: TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.bold,
                      color: isDark ? Colors.white : AppTheme.textPrimaryLight,
                    ),
                  ),
                  TextButton.icon(
                    icon: const Icon(Icons.add_rounded, size: 18),
                    label: const Text('Nueva Meta', style: TextStyle(fontWeight: FontWeight.bold)),
                    onPressed: () => _showAddGoalDialog(),
                  ),
                ],
              ),
              const SizedBox(height: 8),

              ...goals.map((g) => _buildGoalCard(g, bcvRate, isDark)),
            ],
          );
        },
      ),
    );
  }

  Widget _buildGoalCard(Map<String, dynamic> goal, double bcvRate, bool isDark) {
    final String id = goal['id'] as String;
    final String name = goal['name'] as String;
    final double target = (goal['target_amount'] as num).toDouble();
    final double current = (goal['current_amount'] as num).toDouble();
    final String? targetDate = goal['target_date'] as String?;
    final double progress = target > 0 ? (current / target).clamp(0.0, 1.0) : 0.0;
    final bool isCompleted = current >= target;

    final colorHex = goal['color_hex'] as String? ?? '#10B981';
    final cardColor = Color(int.parse(colorHex.replaceAll('#', '0xFF')));

    return Container(
      margin: const EdgeInsets.only(bottom: 14),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: isDark ? const Color(0xFF1E293B) : Colors.white,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: isCompleted ? const Color(0xFF10B981) : (isDark ? Colors.white10 : Colors.black12), width: 1.2),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                padding: const EdgeInsets.all(10),
                decoration: BoxDecoration(
                  color: cardColor.withOpacity(0.15),
                  shape: BoxShape.circle,
                ),
                child: Icon(isCompleted ? Icons.check_circle_rounded : Icons.savings_rounded, color: cardColor, size: 22),
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
                    if (targetDate != null && targetDate.isNotEmpty)
                      Text(
                        'Fecha límite: $targetDate',
                        style: TextStyle(fontSize: 11, color: isDark ? Colors.white54 : Colors.black54),
                      ),
                  ],
                ),
              ),
              PopupMenuButton<String>(
                icon: const Icon(Icons.more_vert_rounded),
                onSelected: (val) {
                  if (val == 'deposit') _showDepositDialog(goal, isDeposit: true);
                  if (val == 'withdraw') _showDepositDialog(goal, isDeposit: false);
                  if (val == 'delete') _deleteGoal(id, name);
                },
                itemBuilder: (ctx) => [
                  const PopupMenuItem(value: 'deposit', child: Row(children: [Icon(Icons.add_rounded, color: Color(0xFF10B981), size: 18), SizedBox(width: 8), Text('Aportar Dinero')])),
                  if (current > 0)
                    const PopupMenuItem(value: 'withdraw', child: Row(children: [Icon(Icons.remove_rounded, color: Color(0xFFF59E0B), size: 18), SizedBox(width: 8), Text('Retirar Dinero')])),
                  const PopupMenuItem(value: 'delete', child: Row(children: [Icon(Icons.delete_outline_rounded, color: Colors.red, size: 18), SizedBox(width: 8), Text('Eliminar Meta')])),
                ],
              ),
            ],
          ),
          const SizedBox(height: 14),

          // Amounts row
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                _formatAmount(current, bcvRate),
                style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: cardColor),
              ),
              Text(
                'de ${_formatAmount(target, bcvRate)} (${(progress * 100).toStringAsFixed(0)}%)',
                style: TextStyle(fontSize: 12, fontWeight: FontWeight.w600, color: isDark ? Colors.white70 : Colors.black54),
              ),
            ],
          ),
          const SizedBox(height: 10),

          // Progress bar
          ClipRRect(
            borderRadius: BorderRadius.circular(6),
            child: LinearProgressIndicator(
              value: progress,
              backgroundColor: isDark ? Colors.white12 : Colors.grey[200],
              valueColor: AlwaysStoppedAnimation<Color>(cardColor),
              minHeight: 8,
            ),
          ),
          const SizedBox(height: 14),

          // Quick deposit button
          Row(
            children: [
              Expanded(
                child: OutlinedButton.icon(
                  icon: const Icon(Icons.add_rounded, size: 16),
                  label: const Text('Aportar a esta Meta', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 13)),
                  style: OutlinedButton.styleFrom(
                    foregroundColor: cardColor,
                    side: BorderSide(color: cardColor.withOpacity(0.5)),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                  ),
                  onPressed: () => _showDepositDialog(goal, isDeposit: true),
                ),
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

  Future<void> _showAddGoalDialog() async {
    final nameCtrl = TextEditingController();
    final amountCtrl = TextEditingController();
    final dateCtrl = TextEditingController();
    String currency = 'USD';

    final ratesState = ref.read(exchangeRatesProvider);
    final double bcvRate = (ratesState.valueOrNull?.bcvUsd != null && ratesState.valueOrNull!.bcvUsd > 0)
        ? ratesState.valueOrNull!.bcvUsd
        : 764.35;

    await showDialog(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setDialogState) {
          final isDark = Theme.of(ctx).brightness == Brightness.dark;
          return AlertDialog(
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(24)),
            title: const Row(
              children: [
                Icon(Icons.savings_rounded, color: AppTheme.primaryDark),
                SizedBox(width: 10),
                Text('Nueva Meta de Ahorro', style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
              ],
            ),
            content: SingleChildScrollView(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  TextField(
                    controller: nameCtrl,
                    decoration: InputDecoration(
                      labelText: 'Nombre de la Meta',
                      hintText: 'Ej: Comprar Teléfono, Vacaciones',
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
                            labelText: 'Monto Objetivo',
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
                  TextField(
                    controller: dateCtrl,
                    decoration: InputDecoration(
                      labelText: 'Fecha Límite (Opcional)',
                      hintText: 'DD/MM/AAAA',
                      border: OutlineInputBorder(borderRadius: BorderRadius.circular(14)),
                    ),
                  ),
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
                  if (name.isEmpty || rawAmount <= 0) {
                    AppToast.show(context, message: 'Ingresa un nombre y monto válido.', type: AppToastType.warning);
                    return;
                  }

                  final double targetUsd = currency == 'VES' ? (rawAmount / bcvRate) : rawAmount;
                  final db = ref.read(dbHelperProvider).database;

                  await db.insert('savings_goals', {
                    'id': 'goal_${DateTime.now().millisecondsSinceEpoch}',
                    'name': name,
                    'target_amount': targetUsd,
                    'current_amount': 0.0,
                    'target_date': dateCtrl.text.trim(),
                    'icon_name': 'savings',
                    'color_hex': '#10B981',
                    'is_completed': 0,
                    'created_at': DateTime.now().toIso8601String(),
                  });

                  if (mounted) {
                    Navigator.pop(ctx);
                    ref.invalidate(savingsGoalsProvider);
                    AppToast.show(context, message: '¡Meta "$name" creada con éxito!', type: AppToastType.success);
                  }
                },
                child: const Text('Crear Meta', style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
              ),
            ],
          );
        },
      ),
    );
  }

  Future<void> _showDepositDialog(Map<String, dynamic> goal, {required bool isDeposit}) async {
    final amountCtrl = TextEditingController();
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
            title: Text(
              isDeposit ? 'Aportar a "${goal['name']}"' : 'Retirar de "${goal['name']}"',
              style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
            ),
            content: SingleChildScrollView(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  if (accounts.isNotEmpty) ...[
                    const Text('Selecciona la Tarjeta / Cuenta:', style: TextStyle(fontSize: 12, fontWeight: FontWeight.w600)),
                    const SizedBox(height: 6),
                    DropdownButtonFormField<String>(
                      value: selectedAccountId,
                      decoration: InputDecoration(
                        border: OutlineInputBorder(borderRadius: BorderRadius.circular(14)),
                      ),
                      items: accounts.map((a) {
                        final b = (a['balance'] as num).toDouble();
                        return DropdownMenuItem<String>(
                          value: a['id'] as String,
                          child: Text('${a['name']} (${_formatAmount(b, bcvRate)})'),
                        );
                      }).toList(),
                      onChanged: (val) => setDialogState(() => selectedAccountId = val),
                    ),
                    const SizedBox(height: 14),
                  ],
                  Row(
                    children: [
                      Expanded(
                        flex: 2,
                        child: TextField(
                          controller: amountCtrl,
                          keyboardType: const TextInputType.numberWithOptions(decimal: true),
                          decoration: InputDecoration(
                            labelText: 'Monto a ${isDeposit ? 'Aportar' : 'Retirar'}',
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
                ],
              ),
            ),
            actions: [
              TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('Cancelar')),
              ElevatedButton(
                style: ElevatedButton.styleFrom(
                  backgroundColor: isDeposit ? const Color(0xFF10B981) : const Color(0xFFF59E0B),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                ),
                onPressed: () async {
                  final rawAmount = double.tryParse(amountCtrl.text.replaceAll(',', '.')) ?? 0.0;
                  if (rawAmount <= 0) {
                    AppToast.show(context, message: 'Ingresa un monto válido.', type: AppToastType.warning);
                    return;
                  }

                  final double amountUsd = currency == 'VES' ? (rawAmount / bcvRate) : rawAmount;
                  final String goalId = goal['id'] as String;
                  final double currentSaved = (goal['current_amount'] as num).toDouble();

                  if (!isDeposit && amountUsd > currentSaved) {
                    AppToast.show(context, message: 'No puedes retirar más de lo ahorrado.', type: AppToastType.warning);
                    return;
                  }

                  final double newSaved = isDeposit ? (currentSaved + amountUsd) : (currentSaved - amountUsd);

                  await db.transaction((txn) async {
                    // Update goal
                    await txn.update(
                      'savings_goals',
                      {
                        'current_amount': newSaved,
                        'is_completed': newSaved >= (goal['target_amount'] as num).toDouble() ? 1 : 0,
                      },
                      where: 'id = ?',
                      whereArgs: [goalId],
                    );

                    // Update account balance if selected
                    if (selectedAccountId != null) {
                      final accRes = await txn.query('accounts', where: 'id = ?', whereArgs: [selectedAccountId]);
                      if (accRes.isNotEmpty) {
                        final currentBal = (accRes.first['balance'] as num).toDouble();
                        final newBal = isDeposit ? (currentBal - amountUsd) : (currentBal + amountUsd);
                        await txn.update(
                          'accounts',
                          {'balance': newBal},
                          where: 'id = ?',
                          whereArgs: [selectedAccountId],
                        );

                        // Record transaction
                        await txn.insert('transactions', {
                          'id': 'tx_${DateTime.now().millisecondsSinceEpoch}',
                          'account_id': selectedAccountId,
                          'type': isDeposit ? 'expense' : 'income',
                          'amount': amountUsd,
                          'currency': currency,
                          'category': 'Ahorros',
                          'description': isDeposit ? 'Aporte a Meta: ${goal['name']}' : 'Retiro de Meta: ${goal['name']}',
                          'date': DateTime.now().toIso8601String(),
                          'is_synced': 0,
                        });
                      }
                    }
                  });

                  if (mounted) {
                    Navigator.pop(ctx);
                    ref.invalidate(savingsGoalsProvider);
                    ref.invalidate(dashboardSummaryProvider);
                    ref.invalidate(recentTransactionsProvider);
                    ref.invalidate(accountsListProvider);
                    AppToast.show(
                      context,
                      message: isDeposit ? '¡Aporte registrado con éxito!' : '¡Retiro registrado con éxito!',
                      type: AppToastType.success,
                    );
                  }
                },
                child: Text(isDeposit ? 'Confirmar Aporte' : 'Confirmar Retiro', style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
              ),
            ],
          );
        },
      ),
    );
  }

  Future<void> _deleteGoal(String id, String name) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        title: const Text('Eliminar Meta', style: TextStyle(fontWeight: FontWeight.bold)),
        content: Text('¿Deseas eliminar la meta "$name"? Los fondos no serán eliminados de tus tarjetas.'),
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
      await db.delete('savings_goals', where: 'id = ?', whereArgs: [id]);
      ref.invalidate(savingsGoalsProvider);
      if (mounted) {
        AppToast.show(context, message: 'Meta eliminada.', type: AppToastType.info);
      }
    }
  }
}
