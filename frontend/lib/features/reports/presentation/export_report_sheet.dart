import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';
import 'package:share_plus/share_plus.dart';
import '../../../../core/theme/app_theme.dart';
import '../../../../core/widgets/app_toast.dart';
import '../../../../core/database/db_helper.dart';
import '../../../../core/providers/global_providers.dart';
import '../../../../core/services/exchange_rate_service.dart';
import '../services/pdf_report_service.dart';

class ExportReportSheet extends ConsumerStatefulWidget {
  const ExportReportSheet({super.key});

  static Future<void> show(BuildContext context) {
    return showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (ctx) => const ExportReportSheet(),
    );
  }

  @override
  ConsumerState<ExportReportSheet> createState() => _ExportReportSheetState();
}

class _ExportReportSheetState extends ConsumerState<ExportReportSheet> {
  String _selectedPeriod = 'this_month'; // 'this_month', 'last_month', 'all'
  bool _isGenerating = false;
  bool _includeVes = true;

  @override
  Widget build(BuildContext context) {
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
                child: const Icon(Icons.picture_as_pdf_rounded, color: AppTheme.primaryDark, size: 24),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Exportar Estado de Cuenta',
                      style: TextStyle(
                        fontSize: 20,
                        fontWeight: FontWeight.bold,
                        color: isDark ? Colors.white : AppTheme.textPrimaryLight,
                      ),
                    ),
                    Text(
                      'Genera reportes formales en PDF o Excel (CSV)',
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
          const SizedBox(height: 20),

          // Period selection
          Text(
            'Período del Reporte',
            style: TextStyle(
              fontSize: 14,
              fontWeight: FontWeight.w600,
              color: isDark ? Colors.white70 : Colors.black87,
            ),
          ),
          const SizedBox(height: 10),
          Row(
            children: [
              _buildPeriodOption('this_month', 'Este Mes', Icons.calendar_today_rounded),
              const SizedBox(width: 8),
              _buildPeriodOption('last_month', 'Mes Anterior', Icons.history_rounded),
              const SizedBox(width: 8),
              _buildPeriodOption('all', 'Historial Completo', Icons.all_inclusive_rounded),
            ],
          ),
          const SizedBox(height: 16),

          // Format toggle (VES vs USD)
          SwitchListTile(
            contentPadding: EdgeInsets.zero,
            title: const Text('Mostrar importes en Bolívares (Bs. BCV)', style: TextStyle(fontSize: 14)),
            subtitle: const Text('Si se desactiva, se mostrarán en Dólares (\$ USD)', style: TextStyle(fontSize: 11)),
            value: _includeVes,
            activeColor: AppTheme.primaryDark,
            onChanged: (val) => setState(() => _includeVes = val),
          ),
          const SizedBox(height: 24),

          // Actions
          if (_isGenerating)
            const Center(
              child: Padding(
                padding: EdgeInsets.all(12),
                child: CircularProgressIndicator(color: AppTheme.primaryDark),
              ),
            )
          else ...[
            ElevatedButton.icon(
              icon: const Icon(Icons.picture_as_pdf_rounded, color: Colors.white),
              label: const Text(
                'Generar y Compartir PDF',
                style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 16),
              ),
              style: ElevatedButton.styleFrom(
                backgroundColor: AppTheme.primaryDark,
                padding: const EdgeInsets.symmetric(vertical: 14),
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
              ),
              onPressed: () => _generateReport(isPdf: true),
            ),
            const SizedBox(height: 10),
            OutlinedButton.icon(
              icon: const Icon(Icons.table_view_rounded, color: Color(0xFF10B981)),
              label: const Text(
                'Exportar a Excel (CSV)',
                style: TextStyle(fontWeight: FontWeight.bold, fontSize: 15),
              ),
              style: OutlinedButton.styleFrom(
                padding: const EdgeInsets.symmetric(vertical: 14),
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                side: const BorderSide(color: Color(0xFF10B981), width: 1.5),
              ),
              onPressed: () => _generateReport(isPdf: false),
            ),
          ],
        ],
      ),
    );
  }

  Widget _buildPeriodOption(String key, String label, IconData icon) {
    final isSelected = _selectedPeriod == key;
    return Expanded(
      child: GestureDetector(
        onTap: () => setState(() => _selectedPeriod = key),
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 180),
          padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 8),
          decoration: BoxDecoration(
            color: isSelected ? AppTheme.primaryDark.withOpacity(0.15) : Colors.transparent,
            borderRadius: BorderRadius.circular(14),
            border: Border.all(
              color: isSelected ? AppTheme.primaryDark : Colors.grey.withOpacity(0.3),
              width: 1.5,
            ),
          ),
          child: Column(
            children: [
              Icon(icon, size: 20, color: isSelected ? AppTheme.primaryDark : Colors.grey),
              const SizedBox(height: 6),
              Text(
                label,
                style: TextStyle(
                  fontSize: 11,
                  fontWeight: isSelected ? FontWeight.bold : FontWeight.normal,
                  color: isSelected ? AppTheme.primaryDark : Colors.grey,
                ),
                textAlign: TextAlign.center,
              ),
            ],
          ),
        ),
      ),
    );
  }

  Future<void> _generateReport({required bool isPdf}) async {
    setState(() => _isGenerating = true);
    try {
      final db = ref.read(dbHelperProvider).database;
      final secureStorage = ref.read(secureStorageProvider);
      final username = await secureStorage.getUsername() ?? 'Usuario';

      final ratesState = ref.read(exchangeRatesProvider);
      final double bcvRate = (ratesState.valueOrNull?.bcvUsd != null && ratesState.valueOrNull!.bcvUsd > 0)
          ? ratesState.valueOrNull!.bcvUsd
          : 764.35;

      final now = DateTime.now();
      DateTime startDate;
      DateTime endDate = now;

      if (_selectedPeriod == 'this_month') {
        startDate = DateTime(now.year, now.month, 1);
      } else if (_selectedPeriod == 'last_month') {
        final lastMonthDate = DateTime(now.year, now.month - 1, 1);
        startDate = lastMonthDate;
        endDate = DateTime(now.year, now.month, 0, 23, 59, 59);
      } else {
        startDate = DateTime(2020, 1, 1);
      }

      // Fetch accounts
      final List<Map<String, dynamic>> accounts = await db.query('accounts');
      double totalBalance = 0.0;
      for (var acc in accounts) {
        totalBalance += (acc['balance'] as num).toDouble();
      }

      // Fetch transactions in date range
      final List<Map<String, dynamic>> transactions = await db.query(
        'transactions',
        where: 'date >= ? AND date <= ?',
        whereArgs: [startDate.toIso8601String(), endDate.toIso8601String()],
        orderBy: 'date DESC',
      );

      double totalIncome = 0.0;
      double totalExpense = 0.0;
      for (var tx in transactions) {
        final amt = (tx['amount'] as num).toDouble();
        if (tx['type'] == 'income') {
          totalIncome += amt;
        } else {
          totalExpense += amt;
        }
      }

      if (isPdf) {
        final pdfBytes = await PdfReportService.generateFinancialReportPdf(
          username: username,
          totalBalance: totalBalance,
          totalIncome: totalIncome,
          totalExpense: totalExpense,
          bcvRate: bcvRate,
          accounts: accounts,
          transactions: transactions,
          startDate: startDate,
          endDate: endDate,
          showInVes: _includeVes,
        );

        if (mounted) {
          Navigator.pop(context);
        }
        await PdfReportService.shareOrPrintPdf(
          pdfBytes: pdfBytes,
          filename: 'Reporte_Financiero_${DateFormat('yyyyMMdd').format(now)}.pdf',
        );
      } else {
        final csvString = PdfReportService.generateTransactionsCsv(
          transactions: transactions,
          bcvRate: bcvRate,
        );

        final filename = 'Movimientos_${DateFormat('yyyyMMdd').format(now)}.csv';
        if (mounted) {
          Navigator.pop(context);
        }
        await Share.share(
          csvString,
          subject: filename,
        );
      }
    } catch (e) {
      if (mounted) {
        AppToast.show(context, message: 'Error generando reporte: $e', type: AppToastType.error);
      }
    } finally {
      if (mounted) {
        setState(() => _isGenerating = false);
      }
    }
  }
}
