import 'dart:io';
import 'dart:typed_data';
import 'package:intl/intl.dart';
import 'package:path_provider/path_provider.dart';
import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;
import 'package:share_plus/share_plus.dart';
import 'package:csv/csv.dart';

class PdfReportService {
  static Future<Uint8List> generateFinancialReportPdf({
    required String username,
    required double totalBalance,
    required double totalIncome,
    required double totalExpense,
    required double bcvRate,
    required List<Map<String, dynamic>> accounts,
    required List<Map<String, dynamic>> transactions,
    required DateTime startDate,
    required DateTime endDate,
    bool showInVes = true,
  }) async {
    final pdf = pw.Document();
    final dateFormat = DateFormat('dd/MM/yyyy HH:mm');
    final rangeFormat = DateFormat('dd/MM/yyyy');

    final primaryColor = PdfColor.fromHex('#10B981');
    final secondaryColor = PdfColor.fromHex('#06B6D4');
    final darkBg = PdfColor.fromHex('#1E293B');
    final lightBg = PdfColor.fromHex('#F8FAFC');
    final expenseColor = PdfColor.fromHex('#EF4444');
    final incomeColor = PdfColor.fromHex('#10B981');

    String formatAmount(double amtInUsd) {
      if (showInVes) {
        final ves = amtInUsd * bcvRate;
        return 'Bs. ${NumberFormat.currency(locale: 'es_VE', symbol: '', decimalDigits: 2).format(ves).trim()}';
      } else {
        return '\$ ${amtInUsd.toStringAsFixed(2)}';
      }
    }

    pdf.addPage(
      pw.MultiPage(
        pageFormat: PdfPageFormat.a4,
        margin: const pw.EdgeInsets.all(32),
        build: (pw.Context context) {
          return [
            // Header
            pw.Container(
              padding: const pw.EdgeInsets.all(16),
              decoration: pw.BoxDecoration(
                color: darkBg,
                borderRadius: pw.BorderRadius.circular(12),
              ),
              child: pw.Row(
                mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
                children: [
                  pw.Column(
                    crossAxisAlignment: pw.CrossAxisAlignment.start,
                    children: [
                      pw.Text(
                        'MY FINANCES',
                        style: pw.TextStyle(
                          color: primaryColor,
                          fontSize: 22,
                          fontWeight: pw.FontWeight.bold,
                        ),
                      ),
                      pw.SizedBox(height: 4),
                      pw.Text(
                        'Estado de Cuenta & Reporte Financiero',
                        style: const pw.TextStyle(color: PdfColors.white, fontSize: 12),
                      ),
                      pw.SizedBox(height: 2),
                      pw.Text(
                        'Usuario: ${username.toUpperCase()}',
                        style: pw.TextStyle(color: secondaryColor, fontSize: 10, fontWeight: pw.FontWeight.bold),
                      ),
                    ],
                  ),
                  pw.Column(
                    crossAxisAlignment: pw.CrossAxisAlignment.end,
                    children: [
                      pw.Text(
                        'Generado: ${dateFormat.format(DateTime.now())}',
                        style: const pw.TextStyle(color: PdfColors.white, fontSize: 9),
                      ),
                      pw.SizedBox(height: 4),
                      pw.Text(
                        'Período: ${rangeFormat.format(startDate)} - ${rangeFormat.format(endDate)}',
                        style: const pw.TextStyle(color: PdfColors.grey400, fontSize: 9),
                      ),
                      pw.Text(
                        'Tasa BCV Aplicada: Bs. ${bcvRate.toStringAsFixed(2)}',
                        style: pw.TextStyle(color: primaryColor, fontSize: 9, fontWeight: pw.FontWeight.bold),
                      ),
                    ],
                  ),
                ],
              ),
            ),
            pw.SizedBox(height: 20),

            // Summary Metrics Box
            pw.Row(
              children: [
                pw.Expanded(
                  child: pw.Container(
                    padding: const pw.EdgeInsets.all(12),
                    decoration: pw.BoxDecoration(
                      color: lightBg,
                      borderRadius: pw.BorderRadius.circular(8),
                      border: pw.Border.all(color: PdfColors.grey300),
                    ),
                    child: pw.Column(
                      crossAxisAlignment: pw.CrossAxisAlignment.start,
                      children: [
                        pw.Text('SALDO NETO TOTAL', style: const pw.TextStyle(fontSize: 9, color: PdfColors.grey700)),
                        pw.SizedBox(height: 4),
                        pw.Text(
                          formatAmount(totalBalance),
                          style: pw.TextStyle(fontSize: 14, fontWeight: pw.FontWeight.bold, color: darkBg),
                        ),
                      ],
                    ),
                  ),
                ),
                pw.SizedBox(width: 10),
                pw.Expanded(
                  child: pw.Container(
                    padding: const pw.EdgeInsets.all(12),
                    decoration: pw.BoxDecoration(
                      color: lightBg,
                      borderRadius: pw.BorderRadius.circular(8),
                      border: pw.Border.all(color: incomeColor),
                    ),
                    child: pw.Column(
                      crossAxisAlignment: pw.CrossAxisAlignment.start,
                      children: [
                        pw.Text('INGRESOS DEL PERÍODO', style: const pw.TextStyle(fontSize: 9, color: PdfColors.grey700)),
                        pw.SizedBox(height: 4),
                        pw.Text(
                          '+${formatAmount(totalIncome)}',
                          style: pw.TextStyle(fontSize: 14, fontWeight: pw.FontWeight.bold, color: incomeColor),
                        ),
                      ],
                    ),
                  ),
                ),
                pw.SizedBox(width: 10),
                pw.Expanded(
                  child: pw.Container(
                    padding: const pw.EdgeInsets.all(12),
                    decoration: pw.BoxDecoration(
                      color: lightBg,
                      borderRadius: pw.BorderRadius.circular(8),
                      border: pw.Border.all(color: expenseColor),
                    ),
                    child: pw.Column(
                      crossAxisAlignment: pw.CrossAxisAlignment.start,
                      children: [
                        pw.Text('GASTOS DEL PERÍODO', style: const pw.TextStyle(fontSize: 9, color: PdfColors.grey700)),
                        pw.SizedBox(height: 4),
                        pw.Text(
                          '-${formatAmount(totalExpense)}',
                          style: pw.TextStyle(fontSize: 14, fontWeight: pw.FontWeight.bold, color: expenseColor),
                        ),
                      ],
                    ),
                  ),
                ),
              ],
            ),
            pw.SizedBox(height: 24),

            // Accounts Breakdown
            pw.Text(
              'Cuentas y Tarjetas Registradas',
              style: pw.TextStyle(fontSize: 14, fontWeight: pw.FontWeight.bold, color: darkBg),
            ),
            pw.SizedBox(height: 8),
            pw.Table(
              border: pw.TableBorder.all(color: PdfColors.grey300),
              children: [
                pw.TableRow(
                  decoration: pw.BoxDecoration(color: PdfColors.grey200),
                  children: [
                    pw.Padding(padding: const pw.EdgeInsets.all(6), child: pw.Text('Nombre', style: pw.TextStyle(fontWeight: pw.FontWeight.bold, fontSize: 10))),
                    pw.Padding(padding: const pw.EdgeInsets.all(6), child: pw.Text('Tipo', style: pw.TextStyle(fontWeight: pw.FontWeight.bold, fontSize: 10))),
                    pw.Padding(padding: const pw.EdgeInsets.all(6), child: pw.Text('Saldo Actual', style: pw.TextStyle(fontWeight: pw.FontWeight.bold, fontSize: 10))),
                  ],
                ),
                ...accounts.map((acc) {
                  final bal = (acc['balance'] as num).toDouble();
                  return pw.TableRow(
                    children: [
                      pw.Padding(padding: const pw.EdgeInsets.all(6), child: pw.Text(acc['name'] as String, style: const pw.TextStyle(fontSize: 9))),
                      pw.Padding(padding: const pw.EdgeInsets.all(6), child: pw.Text((acc['type'] as String).toUpperCase(), style: const pw.TextStyle(fontSize: 9))),
                      pw.Padding(padding: const pw.EdgeInsets.all(6), child: pw.Text(formatAmount(bal), style: pw.TextStyle(fontSize: 9, fontWeight: pw.FontWeight.bold))),
                    ],
                  );
                }),
              ],
            ),
            pw.SizedBox(height: 24),

            // Transactions Table
            pw.Text(
              'Detalle de Movimientos Realizados (${transactions.length})',
              style: pw.TextStyle(fontSize: 14, fontWeight: pw.FontWeight.bold, color: darkBg),
            ),
            pw.SizedBox(height: 8),
            if (transactions.isEmpty)
              pw.Container(
                padding: const pw.EdgeInsets.all(16),
                alignment: pw.Alignment.center,
                child: pw.Text('No se encontraron transacciones en el período seleccionado.', style: const pw.TextStyle(color: PdfColors.grey600, fontSize: 10)),
              )
            else
              pw.Table(
                border: pw.TableBorder.all(color: PdfColors.grey300),
                children: [
                  pw.TableRow(
                    decoration: pw.BoxDecoration(color: PdfColors.grey200),
                    children: [
                      pw.Padding(padding: const pw.EdgeInsets.all(6), child: pw.Text('Fecha', style: pw.TextStyle(fontWeight: pw.FontWeight.bold, fontSize: 9))),
                      pw.Padding(padding: const pw.EdgeInsets.all(6), child: pw.Text('Categoría', style: pw.TextStyle(fontWeight: pw.FontWeight.bold, fontSize: 9))),
                      pw.Padding(padding: const pw.EdgeInsets.all(6), child: pw.Text('Descripción', style: pw.TextStyle(fontWeight: pw.FontWeight.bold, fontSize: 9))),
                      pw.Padding(padding: const pw.EdgeInsets.all(6), child: pw.Text('Tipo', style: pw.TextStyle(fontWeight: pw.FontWeight.bold, fontSize: 9))),
                      pw.Padding(padding: const pw.EdgeInsets.all(6), child: pw.Text('Monto', style: pw.TextStyle(fontWeight: pw.FontWeight.bold, fontSize: 9))),
                    ],
                  ),
                  ...transactions.map((tx) {
                    final isInc = tx['type'] == 'income';
                    final amt = (tx['amount'] as num).toDouble();
                    final DateTime d = DateTime.parse(tx['date'] as String);
                    return pw.TableRow(
                      children: [
                        pw.Padding(padding: const pw.EdgeInsets.all(6), child: pw.Text(rangeFormat.format(d), style: const pw.TextStyle(fontSize: 8))),
                        pw.Padding(padding: const pw.EdgeInsets.all(6), child: pw.Text(tx['category'] as String, style: const pw.TextStyle(fontSize: 8))),
                        pw.Padding(padding: const pw.EdgeInsets.all(6), child: pw.Text(tx['description'] as String? ?? '', style: const pw.TextStyle(fontSize: 8))),
                        pw.Padding(
                          padding: const pw.EdgeInsets.all(6),
                          child: pw.Text(
                            isInc ? 'INGRESO' : 'GASTO',
                            style: pw.TextStyle(fontSize: 8, color: isInc ? incomeColor : expenseColor, fontWeight: pw.FontWeight.bold),
                          ),
                        ),
                        pw.Padding(
                          padding: const pw.EdgeInsets.all(6),
                          child: pw.Text(
                            '${isInc ? '+' : '-'}${formatAmount(amt)}',
                            style: pw.TextStyle(fontSize: 8, fontWeight: pw.FontWeight.bold, color: isInc ? incomeColor : expenseColor),
                          ),
                        ),
                      ],
                    );
                  }),
                ],
              ),
            pw.SizedBox(height: 30),

            // Footer / Disclaimer
            pw.Divider(color: PdfColors.grey300),
            pw.Row(
              mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
              children: [
                pw.Text('My Finances - Bóveda Cifrada y Control Financiero Personal', style: const pw.TextStyle(fontSize: 8, color: PdfColors.grey600)),
                pw.Text('Página 1 de 1', style: const pw.TextStyle(fontSize: 8, color: PdfColors.grey600)),
              ],
            ),
          ];
        },
      ),
    );

    return pdf.save();
  }

  static String generateTransactionsCsv({
    required List<Map<String, dynamic>> transactions,
    required double bcvRate,
  }) {
    final List<List<dynamic>> rows = [
      ['ID', 'Fecha', 'Categoria', 'Tipo', 'Monto USD', 'Monto VES (Tasa: $bcvRate)', 'Moneda Original', 'Descripcion']
    ];

    for (var tx in transactions) {
      final amt = (tx['amount'] as num).toDouble();
      final amtVes = amt * bcvRate;
      rows.add([
        tx['id'],
        tx['date'],
        tx['category'],
        tx['type'],
        amt.toStringAsFixed(2),
        amtVes.toStringAsFixed(2),
        tx['currency'] ?? 'VES',
        tx['description'] ?? '',
      ]);
    }

    return const ListToCsvConverter().convert(rows);
  }

  static Future<void> shareOrPrintPdf({
    required Uint8List pdfBytes,
    required String filename,
  }) async {
    final tempDir = await getTemporaryDirectory();
    final file = File('${tempDir.path}/$filename');
    await file.writeAsBytes(pdfBytes);
    await Share.shareXFiles([XFile(file.path)], subject: filename);
  }
}
