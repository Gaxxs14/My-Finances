import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';
import 'package:fl_chart/fl_chart.dart';
import 'package:dio/dio.dart';
import 'package:nfc_manager/nfc_manager.dart';
import 'package:nfc_manager/nfc_manager_android.dart';
import 'package:nfc_manager/nfc_manager_ios.dart';
import '../../../core/providers/global_providers.dart';
import '../../../core/theme/app_theme.dart';
import '../../../core/widgets/app_toast.dart';
import '../../../core/widgets/sweet_alert.dart';
import '../../../core/services/exchange_rate_service.dart';
import '../../../core/widgets/bcv_calculator_sheet.dart';
import '../../../core/widgets/gaxxs_loader.dart';
import '../../accounts/presentation/nfc_scanner_sheet.dart';
import 'widgets/quick_currency_calculator_sheet.dart';
import '../../reports/presentation/export_report_sheet.dart';
import '../../savings/presentation/savings_goals_screen.dart';
import '../../recurring/presentation/recurring_payments_screen.dart';

class DashboardScreen extends ConsumerStatefulWidget {
  const DashboardScreen({super.key});

  @override
  ConsumerState<DashboardScreen> createState() => _DashboardScreenState();
}

class _DashboardScreenState extends ConsumerState<DashboardScreen> {
  final currencyFormatUsd = NumberFormat.currency(locale: 'en_US', symbol: '\$ ');
  final currencyFormatVes = NumberFormat.currency(locale: 'es_VE', symbol: 'Bs. ');
  bool _isSyncing = false;
  bool _isPrivacyMode = false;
  bool _showInVes = true;

  @override
  void initState() {
    super.initState();
    _startBackgroundNfcListener();
  }

  @override
  void dispose() {
    try {
      NfcManager.instance.stopSession();
    } catch (_) {}
    super.dispose();
  }

  Future<void> _startBackgroundNfcListener() async {
    try {
      final available = await NfcManager.instance.isAvailable();
      if (!available) return;

      NfcManager.instance.startSession(
        pollingOptions: {
          NfcPollingOption.iso14443,
          NfcPollingOption.iso15693,
          NfcPollingOption.iso18092,
        },
        onDiscovered: (NfcTag tag) async {
          String? uid;
          if (Platform.isAndroid) {
            final androidTag = NfcTagAndroid.from(tag);
            if (androidTag != null) {
              uid = androidTag.id.map((b) => b.toRadixString(16).padLeft(2, '0').toUpperCase()).join(':');
            }
          } else if (Platform.isIOS) {
            final mifare = MiFareIos.from(tag);
            if (mifare != null) {
              uid = mifare.identifier.map((b) => b.toRadixString(16).padLeft(2, '0').toUpperCase()).join(':');
            }
          }

          if (uid != null && mounted) {
            _onNfcCardDetected(uid);
          }
        },
      );
    } catch (_) {}
  }

  Future<void> _onNfcCardDetected(String uid) async {
    final repo = ref.read(localTransactionRepositoryProvider);
    final accounts = await repo.getAccounts();
    
    Map<String, dynamic>? matchedAccount;
    for (var acc in accounts) {
      if (acc['id'] == uid) {
        matchedAccount = acc;
        break;
      }
    }

    if (matchedAccount != null) {
      if (mounted) {
        AppToast.show(
          context,
          message: '⚡ ¡Tarjeta "${matchedAccount['name']}" detectada por proximidad! Registrando gasto...',
          type: AppToastType.success,
        );
        _showAddTransactionDialog(preselectedAccountId: uid);
      }
    } else {
      if (mounted) {
        AppToast.show(
          context,
          message: '💳 Nueva Tarjeta NFC detectada. Asigna un nombre para registrarla.',
          type: AppToastType.info,
        );
        _showCreateAccountDialog(scannedNfcUid: uid);
      }
    }
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

  Future<String?> _promptPasswordDialog(String username) async {
    final passCtrl = TextEditingController();
    return showDialog<String>(
      context: context,
      builder: (ctx) {
        final isDark = Theme.of(ctx).brightness == Brightness.dark;
        return AlertDialog(
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(24)),
          title: Row(
            children: [
              const Icon(Icons.cloud_sync_rounded, color: AppTheme.primaryDark),
              const SizedBox(width: 10),
              const Expanded(
                child: Text('Conectar con Render', style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
              ),
            ],
          ),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'Ingresa la contraseña de tu usuario "$username" para vincular tu dispositivo con tu backend en Render:',
                style: TextStyle(fontSize: 13, color: isDark ? Colors.white70 : Colors.black87),
              ),
              const SizedBox(height: 16),
              TextField(
                controller: passCtrl,
                obscureText: true,
                decoration: InputDecoration(
                  labelText: 'Contraseña Maestra',
                  prefixIcon: const Icon(Icons.lock_outline, color: AppTheme.primaryDark),
                  border: OutlineInputBorder(borderRadius: BorderRadius.circular(16)),
                  filled: true,
                ),
              ),
            ],
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(ctx, null),
              child: const Text('Cancelar'),
            ),
            ElevatedButton(
              style: ElevatedButton.styleFrom(
                backgroundColor: AppTheme.primaryDark,
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
              ),
              onPressed: () => Navigator.pop(ctx, passCtrl.text.trim()),
              child: const Text('Conectar y Sincronizar', style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
            ),
          ],
        );
      },
    );
  }

  Future<void> _triggerSync() async {
    setState(() => _isSyncing = true);
    try {
      final storage = ref.read(secureStorageProvider);
      String? token = await storage.getJwtToken();
      String? username = await storage.getUsername();
      String? masterPass = await storage.readData('master_pass');

      // If token is missing, attempt auto-login using saved credentials
      if ((token == null || token.isEmpty) && username != null && masterPass != null) {
        if (mounted) {
          AppToast.show(context, message: 'Conectando con tu servidor Render (https://my-finances-9kah.onrender.com)...', type: AppToastType.info);
        }
        await ref.read(authServiceProvider).loginOnServer(username, masterPass);
        token = await storage.getJwtToken();
      }

      // If token is still missing, prompt user for password in a clean modal!
      if (token == null || token.isEmpty) {
        username ??= 'usuario';
        final enteredPass = await _promptPasswordDialog(username);
        if (enteredPass == null || enteredPass.isEmpty) {
          return;
        }
        masterPass = enteredPass;
        await storage.saveData('master_pass', masterPass);
        if (mounted) {
          AppToast.show(context, message: 'Conectando con https://my-finances-9kah.onrender.com...', type: AppToastType.info);
        }
        final loginRes = await ref.read(authServiceProvider).loginOnServerDetailed(username, masterPass);
        if (loginRes['success'] != true) {
          if (mounted) {
            AppToast.show(context, message: loginRes['message'] as String? ?? 'Credenciales inválidas.', type: AppToastType.error);
          }
          return;
        }
        token = await storage.getJwtToken();
      }

      AppToast.show(context, message: 'Sincronizando con tu servidor Render...', type: AppToastType.info);

      try {
        await ref.read(syncServiceProvider).triggerFullSync();
      } on DioException catch (de) {
        // If 401 Unauthorized occurs, try renewing token automatically with masterPass
        if (de.response?.statusCode == 401 && username != null && masterPass != null) {
          final renewed = await ref.read(authServiceProvider).loginOnServer(username, masterPass);
          if (renewed) {
            await ref.read(syncServiceProvider).triggerFullSync();
          } else {
            rethrow;
          }
        } else {
          rethrow;
        }
      }

      ref.invalidate(dashboardSummaryProvider);
      ref.invalidate(recentTransactionsProvider);
      ref.invalidate(categorySummaryProvider);
      ref.invalidate(accountsListProvider);

      if (mounted) {
        AppToast.show(context, message: '¡Sincronización con tu backend en Render completada con éxito!', type: AppToastType.success);
      }
    } catch (e) {
      String userFriendlyMessage = 'No se pudo conectar a tu backend en Render.';
      if (e is DioException) {
        if (e.type == DioExceptionType.connectionTimeout || 
            e.type == DioExceptionType.receiveTimeout || 
            e.type == DioExceptionType.sendTimeout) {
          userFriendlyMessage = 'El servidor Render está despertando. Reintenta en 15 segundos.';
        } else if (e.response?.statusCode == 401) {
          userFriendlyMessage = 'Token de Render expirado.';
        } else if (e.type == DioExceptionType.connectionError || e.error is SocketException) {
          userFriendlyMessage = 'Servidor Render no accesible. Comprueba tu conexión a internet.';
        }
      }
      if (mounted) {
        AppToast.show(context, message: userFriendlyMessage, type: AppToastType.warning);
      }
    } finally {
      if (mounted) {
        setState(() => _isSyncing = false);
      }
    }
  }

  Future<void> _handleNfcScan() async {
    final uid = await NfcScannerSheet.show(context);
    if (uid == null) return;

    final repo = ref.read(localTransactionRepositoryProvider);
    final accounts = await repo.getAccounts();
    
    Map<String, dynamic>? matchedAccount;
    for (var acc in accounts) {
      if (acc['id'] == uid) {
        matchedAccount = acc;
        break;
      }
    }

    if (matchedAccount != null) {
      // Card ALREADY registered -> Open NFC Express Dialog for this card!
      if (mounted) {
        AppToast.show(
          context,
          message: '⚡ Tarjeta "${matchedAccount['name']}" reconocida! Registro rápido activado.',
          type: AppToastType.success,
        );
        _showNfcExpressDialog(matchedAccount);
      }
    } else {
      // New card -> Open Create Account Dialog pre-filled with NFC UID
      if (mounted) {
        AppToast.show(
          context,
          message: 'Tarjeta NFC no registrada. Créala a continuación.',
          type: AppToastType.info,
        );
        _showCreateAccountDialog(scannedNfcUid: uid);
      }
    }
  }

  void _showAddTransactionDialog({String? preselectedAccountId}) async {
    final repo = ref.read(localTransactionRepositoryProvider);
    final accounts = await repo.getAccounts();

    if (accounts.isEmpty) {
      _showCreateAccountDialog();
      return;
    }

    String type = 'expense';
    double amount = 0.0;
    String currency = 'VES';
    String category = 'Comida';
    String description = '';
    String accountId = preselectedAccountId ?? (accounts.first['id'] as String);
    final amountController = TextEditingController();
    final formKey = GlobalKey<FormState>();

    // Currency options for multi-currency support
    const currencies = [
      {'code': 'VES', 'label': 'Bs. VES', 'symbol': 'Bs.', 'flag': '🇻🇪'},
      {'code': 'USD', 'label': '\$ USD', 'symbol': '\$', 'flag': '🇺🇸'},
      {'code': 'EUR', 'label': '€ EUR', 'symbol': '€', 'flag': '🇪🇺'},
      {'code': 'COP', 'label': 'COP', 'symbol': 'COP', 'flag': '🇨🇴'},
    ];

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (ctx) {
        return StatefulBuilder(
          builder: (context, setModalState) {
            return Container(
              padding: EdgeInsets.only(
                left: 24,
                right: 24,
                top: 16,
                bottom: MediaQuery.of(context).viewInsets.bottom + 24,
              ),
              decoration: BoxDecoration(
                color: Theme.of(context).cardColor,
                borderRadius: const BorderRadius.vertical(top: Radius.circular(32)),
                border: Border.all(color: Theme.of(context).brightness == Brightness.dark ? Colors.white.withOpacity(0.12) : Colors.black12, width: 1.5),
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withOpacity(0.3),
                    blurRadius: 32,
                    spreadRadius: 4,
                  ),
                ],
              ),
              child: Form(
                key: formKey,
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    // Handle bar
                    Center(
                      child: Container(
                        width: 40,
                        height: 4,
                        margin: const EdgeInsets.only(bottom: 20),
                        decoration: BoxDecoration(
                          color: Theme.of(context).brightness == Brightness.dark ? Colors.white24 : Colors.black26,
                          borderRadius: BorderRadius.circular(2),
                        ),
                      ),
                    ),
                    Text(
                      'Nuevo Movimiento',
                      style: TextStyle(
                        fontSize: 22,
                        fontWeight: FontWeight.bold,
                        color: Theme.of(context).brightness == Brightness.dark ? Colors.white : AppTheme.textPrimaryLight,
                      ),
                    ),
                    const SizedBox(height: 18),
                    
                    // Transaction Type Selector Pills
                    Builder(builder: (context) {
                      final isDark = Theme.of(context).brightness == Brightness.dark;
                      return Container(
                        padding: const EdgeInsets.all(4),
                        decoration: BoxDecoration(
                          color: isDark ? Colors.black38 : Colors.grey[200],
                          borderRadius: BorderRadius.circular(16),
                        ),
                        child: Row(
                          children: [
                            Expanded(
                              child: GestureDetector(
                                onTap: () => setModalState(() => type = 'expense'),
                                child: AnimatedContainer(
                                  duration: const Duration(milliseconds: 200),
                                  padding: const EdgeInsets.symmetric(vertical: 12),
                                  decoration: BoxDecoration(
                                    color: type == 'expense' ? const Color(0xFFEF4444) : Colors.transparent,
                                    borderRadius: BorderRadius.circular(12),
                                  ),
                                  child: Row(
                                    mainAxisAlignment: MainAxisAlignment.center,
                                    children: [
                                      Icon(Icons.arrow_upward_rounded,
                                          color: type == 'expense' ? Colors.white : (isDark ? Colors.white60 : Colors.black54), size: 18),
                                      const SizedBox(width: 6),
                                      Text('Gasto',
                                          style: TextStyle(
                                              fontWeight: FontWeight.bold,
                                              color: type == 'expense' ? Colors.white : (isDark ? Colors.white60 : Colors.black54))),
                                    ],
                                  ),
                                ),
                              ),
                            ),
                            Expanded(
                              child: GestureDetector(
                                onTap: () => setModalState(() => type = 'income'),
                                child: AnimatedContainer(
                                  duration: const Duration(milliseconds: 200),
                                  padding: const EdgeInsets.symmetric(vertical: 12),
                                  decoration: BoxDecoration(
                                    color: type == 'income' ? const Color(0xFF10B981) : Colors.transparent,
                                    borderRadius: BorderRadius.circular(12),
                                  ),
                                  child: Row(
                                    mainAxisAlignment: MainAxisAlignment.center,
                                    children: [
                                      Icon(Icons.arrow_downward_rounded,
                                          color: type == 'income' ? Colors.white : (isDark ? Colors.white60 : Colors.black54), size: 18),
                                      const SizedBox(width: 6),
                                      Text('Ingreso',
                                          style: TextStyle(
                                              fontWeight: FontWeight.bold,
                                              color: type == 'income' ? Colors.white : (isDark ? Colors.white60 : Colors.black54))),
                                    ],
                                  ),
                                ),
                              ),
                            ),
                          ],
                        ),
                      );
                    }),
                    const SizedBox(height: 20),

                    // Account Selector
                    Builder(builder: (context) {
                      final isDark = Theme.of(context).brightness == Brightness.dark;
                      return DropdownButtonFormField<String>(
                        value: accountId,
                        decoration: InputDecoration(
                          labelText: 'Cuenta asociada',
                          prefixIcon: const Icon(Icons.account_balance_wallet_outlined, color: AppTheme.primaryDark),
                          filled: true,
                          fillColor: isDark ? Colors.black26 : Colors.grey[100],
                          border: OutlineInputBorder(borderRadius: BorderRadius.circular(16)),
                          labelStyle: TextStyle(color: isDark ? Colors.white70 : AppTheme.textSecondaryLight),
                        ),
                        dropdownColor: isDark ? AppTheme.surfaceDark : Colors.white,
                        style: TextStyle(color: isDark ? Colors.white : AppTheme.textPrimaryLight, fontSize: 14),
                        items: accounts.map((acc) {
                          return DropdownMenuItem<String>(
                            value: acc['id'] as String,
                            child: Text(acc['name'] as String),
                          );
                        }).toList(),
                        onChanged: (val) => setModalState(() => accountId = val!),
                      );
                    }),
                    const SizedBox(height: 14),

                    // Amount Input with Currency Selector
                    Builder(builder: (context) {
                      final isDark = Theme.of(context).brightness == Brightness.dark;
                      return Column(
                        crossAxisAlignment: CrossAxisAlignment.stretch,
                        children: [
                          // Currency Selector Pills
                          SingleChildScrollView(
                            scrollDirection: Axis.horizontal,
                            child: Row(
                              children: currencies.map((cur) {
                                final isSelected = currency == cur['code'];
                                return GestureDetector(
                                  onTap: () => setModalState(() => currency = cur['code'] as String),
                                  child: AnimatedContainer(
                                    duration: const Duration(milliseconds: 180),
                                    margin: const EdgeInsets.only(right: 8, bottom: 8),
                                    padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 7),
                                    decoration: BoxDecoration(
                                      color: isSelected ? AppTheme.primaryDark : (isDark ? Colors.black26 : Colors.grey[200]),
                                      borderRadius: BorderRadius.circular(20),
                                      border: Border.all(
                                        color: isSelected ? AppTheme.primaryDark : (isDark ? Colors.white12 : Colors.black12),
                                      ),
                                    ),
                                    child: Text(
                                      '${cur['flag']} ${cur['label']}',
                                      style: TextStyle(
                                        color: isSelected ? Colors.white : (isDark ? Colors.white60 : Colors.black54),
                                        fontWeight: isSelected ? FontWeight.bold : FontWeight.normal,
                                        fontSize: 13,
                                      ),
                                    ),
                                  ),
                                );
                              }).toList(),
                            ),
                          ),
                          TextFormField(
                            controller: amountController,
                            decoration: InputDecoration(
                              labelText: 'Monto en ${currencies.firstWhere((c) => c['code'] == currency)['label']}',
                              prefixText: '${currencies.firstWhere((c) => c['code'] == currency)['symbol']} ',
                              prefixStyle: const TextStyle(color: AppTheme.primaryDark, fontWeight: FontWeight.bold, fontSize: 18),
                              suffixIcon: currency == 'VES' ? IconButton(
                                icon: const Icon(Icons.calculate_outlined, color: AppTheme.primaryDark),
                                tooltip: 'Calculadora BCV',
                                onPressed: () {
                                  final rates = ref.read(exchangeRatesProvider).valueOrNull;
                                  if (rates != null) {
                                    BcvCalculatorSheet.show(
                                      context,
                                      rates,
                                      onAmountSelectedVes: (calculatedVes) {
                                        amountController.text = calculatedVes.toStringAsFixed(2);
                                        setModalState(() => amount = calculatedVes);
                                      },
                                    );
                                  }
                                },
                              ) : null,
                              filled: true,
                              fillColor: isDark ? Colors.black26 : Colors.grey[100],
                              border: OutlineInputBorder(borderRadius: BorderRadius.circular(16)),
                              labelStyle: TextStyle(color: isDark ? Colors.white70 : AppTheme.textSecondaryLight),
                            ),
                            style: TextStyle(color: isDark ? Colors.white : AppTheme.textPrimaryLight, fontSize: 18, fontWeight: FontWeight.bold),
                            keyboardType: const TextInputType.numberWithOptions(decimal: true),
                            onChanged: (val) => setModalState(() => amount = double.tryParse(val) ?? 0.0),
                            validator: (value) {
                              if (value == null || value.isEmpty) return 'Introduce un monto';
                              if (double.tryParse(value) == null) return 'Monto inválido';
                              return null;
                            },
                            onSaved: (val) => amount = double.tryParse(val!) ?? 0.0,
                          ),
                          // Live conversion preview (only for non-VES)
                          if (currency != 'VES') ...[
                            const SizedBox(height: 8),
                            Builder(builder: (context) {
                              final isDark2 = Theme.of(context).brightness == Brightness.dark;
                              final rates = ref.watch(exchangeRatesProvider).valueOrNull;
                              final double rate = currency == 'USD'
                                  ? (rates?.bcvUsd ?? 1.0)
                                  : currency == 'EUR'
                                      ? (rates?.bcvEur ?? 1.0)
                                      : 1.0;
                              final double vesEquiv = amount * rate;
                              return Container(
                                padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
                                decoration: BoxDecoration(
                                  color: const Color(0xFF10B981).withOpacity(0.1),
                                  borderRadius: BorderRadius.circular(12),
                                  border: Border.all(color: const Color(0xFF10B981).withOpacity(0.3)),
                                ),
                                child: Row(
                                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                  children: [
                                    Text('Equivalente en Bs. (BCV):',
                                        style: TextStyle(color: isDark2 ? Colors.white70 : AppTheme.textSecondaryLight, fontSize: 12)),
                                    Text('Bs. ${vesEquiv.toStringAsFixed(2)}',
                                        style: const TextStyle(color: Color(0xFF10B981), fontWeight: FontWeight.bold, fontSize: 13)),
                                  ],
                                ),
                              );
                            }),
                          ],
                        ],
                      );
                    }),
                    const SizedBox(height: 14),

                    // Live VES conversion preview (only when currency is VES)
                    Builder(
                      builder: (context) {
                        if (currency != 'VES') return const SizedBox.shrink();
                        final isDark = Theme.of(context).brightness == Brightness.dark;
                        final rates = ref.watch(exchangeRatesProvider).valueOrNull;
                        final double rate = rates?.bcvUsd ?? 764.35;
                        final double usdVal = amount / (rate > 0 ? rate : 1.0);
                        return Container(
                          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
                          decoration: BoxDecoration(
                            color: const Color(0xFF10B981).withOpacity(0.1),
                            borderRadius: BorderRadius.circular(12),
                            border: Border.all(color: const Color(0xFF10B981).withOpacity(0.3)),
                          ),
                          child: Row(
                            mainAxisAlignment: MainAxisAlignment.spaceBetween,
                            children: [
                              Text('Equiv. en USD (BCV):',
                                  style: TextStyle(color: isDark ? Colors.white70 : AppTheme.textSecondaryLight, fontSize: 12)),
                              Text('\$ ${usdVal.toStringAsFixed(2)} USD',
                                  style: const TextStyle(color: Color(0xFF10B981), fontWeight: FontWeight.bold, fontSize: 13)),
                            ],
                          ),
                        );
                      },
                    ),
                    const SizedBox(height: 16),

                    // Category Icon Grid
                    Builder(builder: (context) {
                      final isDark = Theme.of(context).brightness == Brightness.dark;
                      return Text('Categoría del Movimiento',
                          style: TextStyle(
                              color: isDark ? AppTheme.textSecondaryDark : AppTheme.textSecondaryLight,
                              fontSize: 13,
                              fontWeight: FontWeight.w600));
                    }),
                    const SizedBox(height: 10),
                    GridView.count(
                      crossAxisCount: 4,
                      shrinkWrap: true,
                      physics: const NeverScrollableScrollPhysics(),
                      mainAxisSpacing: 10,
                      crossAxisSpacing: 10,
                      childAspectRatio: 1.0,
                      children: [
                        {'name': 'Comida', 'icon': Icons.restaurant_rounded, 'color': const Color(0xFFF97316)},
                        {'name': 'Transporte', 'icon': Icons.directions_car_rounded, 'color': const Color(0xFF6366F1)},
                        {'name': 'Servicios', 'icon': Icons.lightbulb_rounded, 'color': const Color(0xFFF43F5E)},
                        {'name': 'Cine/Ocio', 'icon': Icons.movie_rounded, 'color': const Color(0xFFA855F7)},
                        {'name': 'Salud', 'icon': Icons.medical_services_rounded, 'color': const Color(0xFF10B981)},
                        {'name': 'Sueldo', 'icon': Icons.account_balance_wallet_rounded, 'color': const Color(0xFF059669)},
                        {'name': 'Compras', 'icon': Icons.shopping_bag_rounded, 'color': const Color(0xFF06B6D4)},
                        {'name': 'Otros', 'icon': Icons.grid_view_rounded, 'color': const Color(0xFFF59E0B)},
                      ].map((catItem) {
                        final catName = catItem['name'] as String;
                        final icon = catItem['icon'] as IconData;
                        final color = catItem['color'] as Color;
                        final isSelected = category == catName;
                        final isDark = Theme.of(context).brightness == Brightness.dark;

                        return GestureDetector(
                          onTap: () => setModalState(() => category = catName),
                          child: AnimatedContainer(
                            duration: const Duration(milliseconds: 180),
                            decoration: BoxDecoration(
                              color: isSelected ? color.withOpacity(0.2) : (isDark ? Colors.black26 : Colors.grey[100]),
                              borderRadius: BorderRadius.circular(16),
                              border: Border.all(
                                color: isSelected ? color : (isDark ? Colors.white.withOpacity(0.08) : Colors.black12),
                                width: isSelected ? 2 : 1,
                              ),
                            ),
                            child: Column(
                              mainAxisAlignment: MainAxisAlignment.center,
                              children: [
                                Icon(icon, color: isSelected ? color : (isDark ? Colors.white60 : Colors.black45), size: 22),
                                const SizedBox(height: 4),
                                Text(
                                  catName,
                                  style: TextStyle(
                                    fontSize: 10,
                                    fontWeight: isSelected ? FontWeight.bold : FontWeight.normal,
                                    color: isSelected ? (isDark ? Colors.white : AppTheme.textPrimaryLight) : (isDark ? Colors.white60 : Colors.black54),
                                  ),
                                  textAlign: TextAlign.center,
                                ),
                              ],
                            ),
                          ),
                        );
                      }).toList(),
                    ),
                    const SizedBox(height: 16),

                    // Description Input
                    Builder(builder: (context) {
                      final isDark = Theme.of(context).brightness == Brightness.dark;
                      return TextFormField(
                        decoration: InputDecoration(
                          labelText: 'Detalles u observaciones',
                          prefixIcon: const Icon(Icons.description_outlined, color: AppTheme.primaryDark),
                          filled: true,
                          fillColor: isDark ? Colors.black26 : Colors.grey[100],
                          border: OutlineInputBorder(borderRadius: BorderRadius.circular(16)),
                          labelStyle: TextStyle(color: isDark ? Colors.white70 : AppTheme.textSecondaryLight),
                        ),
                        style: TextStyle(color: isDark ? Colors.white : AppTheme.textPrimaryLight),
                        onSaved: (val) => description = val ?? '',
                      );
                    }),
                    const SizedBox(height: 24),

                    // Submit Button
                    ElevatedButton(
                      onPressed: () async {
                        if (formKey.currentState!.validate()) {
                          formKey.currentState!.save();
                          final rates = ref.read(exchangeRatesProvider).valueOrNull;
                          final double currentRate = (rates?.bcvUsd != null && rates!.bcvUsd > 0) ? rates.bcvUsd : 764.35;

                          // Convert input amount to USD base if entered in VES or EUR
                          double amountInUsd;
                          if (currency == 'VES') {
                            amountInUsd = amount / currentRate;
                          } else if (currency == 'EUR') {
                            final eurRate = rates?.bcvEur ?? currentRate;
                            amountInUsd = (amount * eurRate) / currentRate;
                          } else {
                            amountInUsd = amount;
                          }

                          final String currencyNote = currency == 'VES'
                              ? 'Tasa BCV: Bs. ${currentRate.toStringAsFixed(2)}'
                              : 'Moneda: $currency | Monto: $amount';
                          final String finalDesc = description.isNotEmpty ? '$description ($currencyNote)' : currencyNote;

                          final transaction = {
                            'id': DateTime.now().millisecondsSinceEpoch.toString(),
                            'account_id': accountId,
                            'type': type,
                            'amount': amountInUsd,
                            'currency': currency,
                            'category': category,
                            'description': finalDesc,
                            'date': DateTime.now().toIso8601String(),
                            'is_synced': 0,
                          };

                          await repo.addTransaction(transaction);
                          ref.invalidate(dashboardSummaryProvider);
                          ref.invalidate(recentTransactionsProvider);
                          ref.invalidate(categorySummaryProvider);
                          ref.invalidate(accountsListProvider);
                          if (context.mounted) {
                            Navigator.pop(ctx);
                            AppToast.show(context, message: '¡Movimiento registrado con éxito!', type: AppToastType.success);
                          }
                        }
                      },
                      style: ElevatedButton.styleFrom(
                        backgroundColor: AppTheme.primaryDark,
                        padding: const EdgeInsets.symmetric(vertical: 16),
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                        elevation: 4,
                      ),
                      child: const Text('Guardar Movimiento', style: TextStyle(color: Colors.white, fontSize: 16, fontWeight: FontWeight.bold)),
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

  void _showCreateAccountDialog({String? scannedNfcUid}) {
    final formKey = GlobalKey<FormState>();
    final nameController = TextEditingController(
      text: scannedNfcUid != null
          ? 'Tarjeta NFC (${scannedNfcUid.length > 8 ? scannedNfcUid.substring(0, 8) : scannedNfcUid})'
          : '',
    );
    final cardDescController = TextEditingController();
    final balanceController = TextEditingController();
    String accountType = scannedNfcUid != null ? 'card' : 'bank';
    String selectedColorHex = '#1E40AF';
    double initialBalance = 0.0;
    String? nfcUid = scannedNfcUid;

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (ctx) {
        return StatefulBuilder(
          builder: (context, setStateDialog) {
            return Container(
              padding: EdgeInsets.only(
                left: 24,
                right: 24,
                top: 16,
                bottom: MediaQuery.of(context).viewInsets.bottom + 24,
              ),
              decoration: BoxDecoration(
                color: Theme.of(context).cardColor,
                borderRadius: const BorderRadius.vertical(top: Radius.circular(32)),
                border: Border.all(color: Theme.of(context).brightness == Brightness.dark ? Colors.white.withOpacity(0.12) : Colors.black12, width: 1.5),
              ),
              child: Form(
                key: formKey,
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    Center(
                      child: Container(
                        width: 40,
                        height: 4,
                        margin: const EdgeInsets.only(bottom: 20),
                        decoration: BoxDecoration(color: Theme.of(context).brightness == Brightness.dark ? Colors.white24 : Colors.black26, borderRadius: BorderRadius.circular(2)),
                      ),
                    ),
                    Text(
                      'Nueva Cuenta / Tarjeta',
                      style: TextStyle(
                        fontSize: 22,
                        fontWeight: FontWeight.bold,
                        color: Theme.of(context).brightness == Brightness.dark ? Colors.white : AppTheme.textPrimaryLight,
                      ),
                    ),
                    const SizedBox(height: 16),

                    // Live Interactive Credit Card Preview
                    Center(
                      child: _CreditCardVisual(
                        bankName: nameController.text.isEmpty ? 'NOMBRE DEL BANCO' : nameController.text,
                        alias: cardDescController.text.isEmpty ? 'ALIAS DE LA TARJETA' : cardDescController.text,
                        type: accountType,
                        balanceText: balanceController.text.isEmpty ? 'Bs. 0,00' : 'Bs. ${balanceController.text}',
                        colorHex: selectedColorHex,
                      ),
                    ),
                    const SizedBox(height: 18),

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
                      icon: const Icon(Icons.contactless_outlined, color: AppTheme.accentDark),
                      label: Text(
                        nfcUid != null ? 'Vincular otra tarjeta (Vinculada: $nfcUid)' : 'Vincular Tarjeta NFC por Proximidad',
                        style: const TextStyle(color: Colors.white, fontWeight: FontWeight.w600),
                      ),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: AppTheme.primaryDark,
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
                      ),
                    ),
                    const SizedBox(height: 16),

                    // Bank / Name Input
                    TextFormField(
                      controller: nameController,
                      decoration: InputDecoration(
                        labelText: 'Nombre del Banco o Entidad (ej. BNC, Mercantil)',
                        prefixIcon: const Icon(Icons.account_balance_outlined, color: AppTheme.primaryDark),
                        filled: true,
                        fillColor: Theme.of(context).brightness == Brightness.dark ? Colors.black26 : Colors.grey[100],
                        border: OutlineInputBorder(borderRadius: BorderRadius.circular(16)),
                        labelStyle: TextStyle(color: Theme.of(context).brightness == Brightness.dark ? Colors.white70 : AppTheme.textSecondaryLight),
                      ),
                      style: TextStyle(color: Theme.of(context).brightness == Brightness.dark ? Colors.white : AppTheme.textPrimaryLight),
                      onChanged: (_) => setStateDialog(() {}),
                      validator: (val) => (val == null || val.isEmpty) ? 'Requerido' : null,
                    ),
                    const SizedBox(height: 14),

                    // Card Alias / Custom Identification Input
                    TextFormField(
                      controller: cardDescController,
                      decoration: InputDecoration(
                        labelText: 'Alias o Identificador (ej. Débito Principal, Visa 4321)',
                        prefixIcon: const Icon(Icons.style_outlined, color: AppTheme.primaryDark),
                        filled: true,
                        fillColor: Theme.of(context).brightness == Brightness.dark ? Colors.black26 : Colors.grey[100],
                        border: OutlineInputBorder(borderRadius: BorderRadius.circular(16)),
                        labelStyle: TextStyle(color: Theme.of(context).brightness == Brightness.dark ? Colors.white70 : AppTheme.textSecondaryLight),
                      ),
                      style: TextStyle(color: Theme.of(context).brightness == Brightness.dark ? Colors.white : AppTheme.textPrimaryLight),
                      onChanged: (_) => setStateDialog(() {}),
                    ),
                    const SizedBox(height: 14),

                    // Type pills
                    const Text('Tipo de Producto', style: TextStyle(color: AppTheme.textSecondaryDark, fontSize: 13, fontWeight: FontWeight.w600)),
                    const SizedBox(height: 8),
                    Wrap(
                      spacing: 8,
                      children: [
                        {'type': 'bank', 'label': 'Banco', 'icon': Icons.account_balance},
                        {'type': 'card', 'label': 'Tarjeta', 'icon': Icons.credit_card},
                        {'type': 'cash', 'label': 'Efectivo', 'icon': Icons.payments_outlined},
                        {'type': 'savings', 'label': 'Ahorros', 'icon': Icons.savings_outlined},
                      ].map((item) {
                        final isSelected = accountType == item['type'];
                        return ChoiceChip(
                          avatar: Icon(item['icon'] as IconData, size: 18, color: isSelected ? Colors.white : AppTheme.primaryDark),
                          label: Text(item['label'] as String),
                          selected: isSelected,
                          selectedColor: AppTheme.primaryDark,
                          backgroundColor: Colors.black26,
                          labelStyle: TextStyle(color: isSelected ? Colors.white : Colors.white70, fontWeight: isSelected ? FontWeight.bold : FontWeight.normal),
                          onSelected: (selected) {
                            if (selected) setStateDialog(() => accountType = item['type'] as String);
                          },
                        );
                      }).toList(),
                    ),
                    const SizedBox(height: 14),

                    // Custom Card Color Palette Picker
                    const Text('Color Personalizado de la Tarjeta', style: TextStyle(color: AppTheme.textSecondaryDark, fontSize: 13, fontWeight: FontWeight.w600)),
                    const SizedBox(height: 8),
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        {'hex': '#1E40AF', 'color': const Color(0xFF1E40AF)},
                        {'hex': '#047857', 'color': const Color(0xFF047857)},
                        {'hex': '#6D28D9', 'color': const Color(0xFF6D28D9)},
                        {'hex': '#C2410C', 'color': const Color(0xFFC2410C)},
                        {'hex': '#B91C1C', 'color': const Color(0xFFB91C1C)},
                        {'hex': '#1F2937', 'color': const Color(0xFF1F2937)},
                        {'hex': '#B45309', 'color': const Color(0xFFB45309)},
                        {'hex': '#BE185D', 'color': const Color(0xFFBE185D)},
                      ].map((item) {
                        final isSelected = selectedColorHex == item['hex'];
                        return GestureDetector(
                          onTap: () => setStateDialog(() => selectedColorHex = item['hex'] as String),
                          child: AnimatedContainer(
                            duration: const Duration(milliseconds: 200),
                            width: 32,
                            height: 32,
                            decoration: BoxDecoration(
                              color: item['color'] as Color,
                              shape: BoxShape.circle,
                              border: Border.all(color: isSelected ? Colors.white : Colors.transparent, width: 2.5),
                              boxShadow: isSelected ? [BoxShadow(color: (item['color'] as Color).withOpacity(0.6), blurRadius: 8)] : [],
                            ),
                            child: isSelected ? const Icon(Icons.check, color: Colors.white, size: 16) : null,
                          ),
                        );
                      }).toList(),
                    ),
                    const SizedBox(height: 14),

                    TextFormField(
                      controller: balanceController,
                      decoration: InputDecoration(
                        labelText: 'Saldo Inicial en Bolívares (Bs. VES)',
                        prefixIcon: const Icon(Icons.price_change_outlined, color: AppTheme.primaryDark),
                        filled: true,
                        fillColor: Theme.of(context).brightness == Brightness.dark ? Colors.black26 : Colors.grey[100],
                        border: OutlineInputBorder(borderRadius: BorderRadius.circular(16)),
                        labelStyle: TextStyle(color: Theme.of(context).brightness == Brightness.dark ? Colors.white70 : AppTheme.textSecondaryLight),
                      ),
                      style: TextStyle(
                        color: Theme.of(context).brightness == Brightness.dark ? Colors.white : AppTheme.textPrimaryLight,
                        fontSize: 16,
                        fontWeight: FontWeight.bold,
                      ),
                      keyboardType: const TextInputType.numberWithOptions(decimal: true),
                      onChanged: (_) => setStateDialog(() {}),
                      validator: (val) => (val == null || double.tryParse(val.trim()) == null) ? 'Ingresa un monto válido en Bs.' : null,
                      onSaved: (val) {
                        final inputVes = double.tryParse(val?.trim() ?? '0') ?? 0.0;
                        final rates = ref.read(exchangeRatesProvider).valueOrNull;
                        final double rate = rates?.bcvUsd ?? 764.35;
                        initialBalance = inputVes / rate;
                      },
                    ),
                    const SizedBox(height: 24),

                    ElevatedButton(
                      style: ElevatedButton.styleFrom(
                        backgroundColor: AppTheme.primaryDark,
                        padding: const EdgeInsets.symmetric(vertical: 16),
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                      ),
                      child: const Text('Crear Cuenta / Tarjeta', style: TextStyle(color: Colors.white, fontSize: 16, fontWeight: FontWeight.bold)),
                      onPressed: () async {
                        if (formKey.currentState!.validate()) {
                          formKey.currentState!.save();
                          final String rawName = nameController.text.trim();
                          final String rawAlias = cardDescController.text.trim();
                          final fullName = rawAlias.isNotEmpty ? '$rawName | $rawAlias' : rawName;

                          try {
                            await ref.read(localTransactionRepositoryProvider).addAccount({
                              'id': nfcUid ?? DateTime.now().millisecondsSinceEpoch.toString(),
                              'name': fullName,
                              'type': accountType,
                              'balance': initialBalance,
                              'currency': 'VES',
                              'color': selectedColorHex,
                              'is_active': 1,
                            });

                            ref.invalidate(dashboardSummaryProvider);
                            ref.invalidate(recentTransactionsProvider);
                            ref.invalidate(categorySummaryProvider);
                            ref.invalidate(accountsListProvider);
                            
                            if (context.mounted) {
                              Navigator.pop(ctx);
                              AppToast.show(context, message: '¡Cuenta / Tarjeta registrada exitosamente!', type: AppToastType.success);
                            }
                          } catch (e) {
                            if (context.mounted) {
                              SweetAlert.show(
                                context,
                                title: 'Error al Crear',
                                description: 'Ocurrió un error al guardar la tarjeta: $e',
                                icon: SweetAlertIcon.error,
                              );
                            }
                          }
                        }
                      },
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

  void _confirmDeleteAccount(Map<String, dynamic> account) {
    final accId = account['id'] as String;
    final accName = account['name'] as String;

    SweetAlert.show(
      context,
      title: '¿Eliminar tarjeta?',
      description: 'Se eliminará la cuenta "$accName" y sus movimientos asociados.',
      icon: SweetAlertIcon.warning,
      confirmButtonText: 'Sí, Eliminar',
      cancelButtonText: 'Cancelar',
      onConfirm: () async {
        await ref.read(localTransactionRepositoryProvider).deleteAccount(accId);
        ref.invalidate(dashboardSummaryProvider);
        ref.invalidate(recentTransactionsProvider);
        ref.invalidate(categorySummaryProvider);
        ref.invalidate(accountsListProvider);
        if (mounted) {
          AppToast.show(context, message: 'Tarjeta "$accName" eliminada.', type: AppToastType.info);
        }
      },
    );
  }

  void _confirmDeleteTransaction(String transactionId) {
    SweetAlert.show(
      context,
      title: '¿Eliminar movimiento?',
      description: 'El saldo de la cuenta se reajustará automáticamente.',
      icon: SweetAlertIcon.warning,
      confirmButtonText: 'Sí, Eliminar',
      cancelButtonText: 'Cancelar',
      onConfirm: () async {
        await ref.read(localTransactionRepositoryProvider).deleteTransaction(transactionId);
        ref.invalidate(dashboardSummaryProvider);
        ref.invalidate(recentTransactionsProvider);
        ref.invalidate(categorySummaryProvider);
        ref.invalidate(accountsListProvider);
        if (mounted) {
          AppToast.show(context, message: 'Movimiento eliminado y saldo restaurado.', type: AppToastType.info);
        }
      },
    );
  }

  /// NFC Express Dialog — quick amount entry when NFC card is detected
  void _showNfcExpressDialog(Map<String, dynamic> account) {
    final amountController = TextEditingController();
    final formKey = GlobalKey<FormState>();
    final accName = account['name'] as String;
    final nameParts = accName.split(' | ');
    final isDark = Theme.of(context).brightness == Brightness.dark;
    String currency = 'VES';
    const currencies = [
      {'code': 'VES', 'label': 'Bs. VES', 'flag': '🇻🇪'},
      {'code': 'USD', 'label': '\$ USD', 'flag': '🇺🇸'},
    ];

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (ctx) => StatefulBuilder(
        builder: (context, setNfcState) => Container(
          padding: EdgeInsets.only(
            left: 24, right: 24, top: 20,
            bottom: MediaQuery.of(context).viewInsets.bottom + 28,
          ),
          decoration: BoxDecoration(
            color: Theme.of(context).cardColor,
            borderRadius: const BorderRadius.vertical(top: Radius.circular(32)),
            border: Border.all(
              color: isDark ? Colors.white12 : Colors.black12, width: 1.5,
            ),
          ),
          child: Form(
            key: formKey,
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                // Handle
                Center(
                  child: Container(
                    width: 40, height: 4,
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
                      child: const Icon(Icons.contactless_rounded, color: AppTheme.primaryDark, size: 22),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            'Registro Rápido NFC',
                            style: TextStyle(
                              fontWeight: FontWeight.bold, fontSize: 18,
                              color: isDark ? Colors.white : AppTheme.textPrimaryLight,
                            ),
                          ),
                          Text(
                            nameParts[0],
                            style: TextStyle(color: isDark ? Colors.white60 : AppTheme.textSecondaryLight, fontSize: 13),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 20),
                // Currency selector
                Row(
                  children: currencies.map((cur) {
                    final isSelected = currency == cur['code'];
                    return GestureDetector(
                      onTap: () => setNfcState(() => currency = cur['code'] as String),
                      child: AnimatedContainer(
                        duration: const Duration(milliseconds: 180),
                        margin: const EdgeInsets.only(right: 10),
                        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
                        decoration: BoxDecoration(
                          color: isSelected ? AppTheme.primaryDark : (isDark ? Colors.black26 : Colors.grey[200]),
                          borderRadius: BorderRadius.circular(20),
                          border: Border.all(color: isSelected ? AppTheme.primaryDark : Colors.transparent),
                        ),
                        child: Text(
                          '${cur['flag']} ${cur['label']}',
                          style: TextStyle(
                            color: isSelected ? Colors.white : (isDark ? Colors.white60 : Colors.black54),
                            fontWeight: isSelected ? FontWeight.bold : FontWeight.normal,
                            fontSize: 13,
                          ),
                        ),
                      ),
                    );
                  }).toList(),
                ),
                const SizedBox(height: 16),
                // Big amount field
                TextFormField(
                  controller: amountController,
                  autofocus: true,
                  decoration: InputDecoration(
                    labelText: 'Monto del gasto',
                    prefixText: currency == 'VES' ? 'Bs. ' : '\$ ',
                    prefixStyle: const TextStyle(color: AppTheme.primaryDark, fontWeight: FontWeight.bold, fontSize: 22),
                    filled: true,
                    fillColor: isDark ? Colors.black26 : Colors.grey[100],
                    border: OutlineInputBorder(borderRadius: BorderRadius.circular(16)),
                    labelStyle: TextStyle(color: isDark ? Colors.white70 : AppTheme.textSecondaryLight),
                  ),
                  style: TextStyle(
                    color: isDark ? Colors.white : AppTheme.textPrimaryLight,
                    fontSize: 28, fontWeight: FontWeight.bold,
                  ),
                  keyboardType: const TextInputType.numberWithOptions(decimal: true),
                  validator: (val) {
                    if (val == null || val.isEmpty) return 'Ingresa el monto';
                    if (double.tryParse(val) == null) return 'Monto inválido';
                    return null;
                  },
                ),
                const SizedBox(height: 20),
                SizedBox(
                  width: double.infinity,
                  child: ElevatedButton.icon(
                    icon: const Icon(Icons.save_rounded, color: Colors.white),
                    label: const Text('Registrar Gasto', style: TextStyle(color: Colors.white, fontSize: 16, fontWeight: FontWeight.bold)),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: Colors.redAccent,
                      padding: const EdgeInsets.symmetric(vertical: 14),
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                    ),
                    onPressed: () async {
                      if (formKey.currentState!.validate()) {
                        final amt = double.parse(amountController.text);
                        final rates = ref.read(exchangeRatesProvider).valueOrNull;
                        final double bcvRate = (rates?.bcvUsd != null && rates!.bcvUsd > 0) ? rates.bcvUsd : 764.35;

                        // Convert input amount to USD base if entered in VES
                        final double amountInUsd = currency == 'VES' ? (amt / bcvRate) : amt;

                        final String note = currency == 'VES'
                            ? 'NFC Express • Tasa BCV: ${bcvRate.toStringAsFixed(2)}'
                            : 'NFC Express • Moneda: $currency';

                        await ref.read(localTransactionRepositoryProvider).addTransaction({
                          'id': DateTime.now().millisecondsSinceEpoch.toString(),
                          'account_id': account['id'] as String,
                          'type': 'expense',
                          'amount': amountInUsd,
                          'currency': currency,
                          'category': 'Otros',
                          'description': note,
                          'date': DateTime.now().toIso8601String(),
                          'is_synced': 0,
                        });

                        ref.invalidate(dashboardSummaryProvider);
                        ref.invalidate(recentTransactionsProvider);
                        ref.invalidate(categorySummaryProvider);
                        ref.invalidate(accountsListProvider);

                        if (ctx.mounted) Navigator.pop(ctx);
                        if (mounted) {
                          AppToast.show(context,
                              message: '⚡ Gasto NFC registrado en ${nameParts[0]}',
                              type: AppToastType.success);
                        }
                      }
                    },
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  /// Show all transactions for a specific account
  void _showAccountTransactions(Map<String, dynamic> account) {
    final accId = account['id'] as String;
    final accName = account['name'] as String;
    final accColor = account['color'] as String? ?? '#1E40AF';
    final accType = account['type'] as String;
    final accBalance = (account['balance'] as num).toDouble();
    final nameParts = accName.split(' | ');
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final double bcvRate = ref.read(exchangeRatesProvider).valueOrNull?.bcvUsd ?? 764.35;

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (ctx) => DraggableScrollableSheet(
        initialChildSize: 0.75,
        minChildSize: 0.5,
        maxChildSize: 0.95,
        builder: (context, scrollController) => Container(
          decoration: BoxDecoration(
            color: Theme.of(context).cardColor,
            borderRadius: const BorderRadius.vertical(top: Radius.circular(32)),
            border: Border.all(color: isDark ? Colors.white12 : Colors.black12, width: 1.5),
          ),
          child: Column(
            children: [
              // Handle
              Center(
                child: Container(
                  width: 40, height: 4,
                  margin: const EdgeInsets.symmetric(vertical: 12),
                  decoration: BoxDecoration(
                    color: isDark ? Colors.white24 : Colors.black26,
                    borderRadius: BorderRadius.circular(2),
                  ),
                ),
              ),
              // Card mini preview
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 16),
                child: _CreditCardVisual(
                  bankName: nameParts[0],
                  alias: nameParts.length > 1 ? nameParts[1] : '',
                  type: accType,
                  balanceText: _formatAmount(accBalance, bcvRate),
                  colorHex: accColor,
                ),
              ),
              const SizedBox(height: 8),
              // Header + add button
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 8),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Text(
                      'Movimientos',
                      style: TextStyle(
                        fontSize: 18, fontWeight: FontWeight.bold,
                        color: isDark ? Colors.white : AppTheme.textPrimaryLight,
                      ),
                    ),
                    ElevatedButton.icon(
                      icon: const Icon(Icons.add_rounded, color: Colors.white, size: 18),
                      label: const Text('Agregar', style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: AppTheme.primaryDark,
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
                      ),
                      onPressed: () {
                        Navigator.pop(ctx);
                        _showAddTransactionDialog(preselectedAccountId: accId);
                      },
                    ),
                  ],
                ),
              ),
              const Divider(height: 1),
              // Transactions list
              Expanded(
                child: ref.watch(recentTransactionsProvider).when(
                  data: (txList) {
                    final filtered = txList.where((tx) => tx['account_id'] == accId).toList();
                    if (filtered.isEmpty) {
                      return Center(
                        child: Column(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            Icon(Icons.receipt_long_outlined, size: 52, color: isDark ? Colors.white24 : Colors.black26),
                            const SizedBox(height: 12),
                            Text(
                              'Sin movimientos en esta cuenta',
                              style: TextStyle(color: isDark ? Colors.white54 : Colors.black45),
                            ),
                          ],
                        ),
                      );
                    }
                    return ListView.builder(
                      controller: scrollController,
                      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                      itemCount: filtered.length,
                      itemBuilder: (context, index) {
                        final tx = filtered[index];
                        final isIncome = tx['type'] == 'income';
                        final amt = (tx['amount'] as num).toDouble();
                        final txCurrency = tx['currency'] as String? ?? 'VES';
                        final DateTime date = DateTime.parse(tx['date'] as String);
                        final fmtDate = DateFormat.yMMMd('es_VE').format(date);
                        String displayAmt;
                        if (txCurrency == 'VES') {
                          displayAmt = currencyFormatVes.format(amt);
                        } else if (txCurrency == 'USD') {
                          displayAmt = '\$ ${amt.toStringAsFixed(2)}';
                        } else {
                          displayAmt = '$txCurrency ${amt.toStringAsFixed(2)}';
                        }

                        return Card(
                          margin: const EdgeInsets.symmetric(vertical: 4),
                          child: ListTile(
                            leading: CircleAvatar(
                              backgroundColor: isIncome
                                  ? AppTheme.accentDark.withOpacity(0.12)
                                  : Colors.redAccent.withOpacity(0.12),
                              child: Icon(
                                isIncome ? Icons.arrow_downward_rounded : Icons.arrow_upward_rounded,
                                color: isIncome ? AppTheme.accentDark : Colors.redAccent,
                                size: 20,
                              ),
                            ),
                            title: Text(
                              tx['category'] as String,
                              style: const TextStyle(fontWeight: FontWeight.bold),
                            ),
                            subtitle: Text(fmtDate, style: TextStyle(color: isDark ? Colors.white54 : Colors.black45, fontSize: 12)),
                            trailing: Row(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                Text(
                                  '${isIncome ? '+' : '-'}${_formatAmount(amt, bcvRate)}',
                                  style: TextStyle(
                                    fontWeight: FontWeight.bold, fontSize: 15,
                                    color: isIncome ? AppTheme.accentDark : Colors.redAccent,
                                  ),
                                ),
                                const SizedBox(width: 4),
                                GestureDetector(
                                  onTap: () {
                                    Navigator.pop(ctx);
                                    _confirmDeleteTransaction(tx['id'] as String);
                                  },
                                  child: Container(
                                    padding: const EdgeInsets.all(6),
                                    child: const Icon(Icons.delete_outline, color: Colors.redAccent, size: 18),
                                  ),
                                ),
                              ],
                            ),
                          ),
                        );
                      },
                    );
                  },
                  loading: () => const Center(child: CircularProgressIndicator()),
                  error: (_, __) => const SizedBox.shrink(),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildExchangeRatesCard() {
    final ratesAsync = ref.watch(exchangeRatesProvider);
    return ratesAsync.when(
      data: (rates) {
        return GestureDetector(
          onTap: () => QuickCurrencyCalculatorSheet.show(context),
          child: Container(
            margin: const EdgeInsets.only(bottom: 16),
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
            decoration: BoxDecoration(
              color: Theme.of(context).cardColor,
              borderRadius: BorderRadius.circular(18),
              border: Border.all(color: Theme.of(context).brightness == Brightness.dark ? Colors.white.withOpacity(0.1) : Colors.black.withOpacity(0.08)),
              boxShadow: Theme.of(context).brightness == Brightness.light ? [BoxShadow(color: Colors.black.withOpacity(0.04), blurRadius: 10, offset: const Offset(0, 4))] : [],
            ),
            child: Column(
              children: [
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Row(
                      children: [
                        const Icon(Icons.currency_exchange, color: AppTheme.primaryDark, size: 18),
                        const SizedBox(width: 6),
                        Text(
                          'Tasas del Día VZLA',
                          style: TextStyle(
                            color: Theme.of(context).brightness == Brightness.dark ? Colors.white70 : AppTheme.textPrimaryLight,
                            fontSize: 12,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      ],
                    ),
                    const Row(
                      children: [
                        Text('Calculadora', style: TextStyle(fontSize: 11, color: AppTheme.primaryDark, fontWeight: FontWeight.w600)),
                        SizedBox(width: 2),
                        Icon(Icons.chevron_right_rounded, color: AppTheme.primaryDark, size: 16),
                      ],
                    ),
                  ],
                ),
                const SizedBox(height: 10),
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    _buildRateBadge('BCV \$', 'Bs. ${rates.bcvUsd.toStringAsFixed(2)}', Colors.blueAccent),
                    _buildRateBadge('BCV €', 'Bs. ${rates.bcvEur.toStringAsFixed(2)}', Colors.purpleAccent),
                    _buildRateBadge('Binance', 'Bs. ${rates.binanceUsd.toStringAsFixed(2)}', Colors.amberAccent),
                  ],
                ),
              ],
            ),
          ),
        );
      },
      loading: () => const SizedBox.shrink(),
      error: (_, __) => const SizedBox.shrink(),
    );
  }

  Widget _buildQuickActionTool({
    required IconData icon,
    required String label,
    required Color color,
    required VoidCallback onTap,
  }) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    return Expanded(
      child: GestureDetector(
        onTap: onTap,
        child: Container(
          padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 4),
          decoration: BoxDecoration(
            color: isDark ? const Color(0xFF1E293B) : Colors.white,
            borderRadius: BorderRadius.circular(16),
            border: Border.all(
              color: isDark ? Colors.white10 : Colors.black12,
              width: 1.2,
            ),
            boxShadow: [
              BoxShadow(
                color: color.withOpacity(0.08),
                blurRadius: 8,
                offset: const Offset(0, 3),
              ),
            ],
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: color.withOpacity(0.15),
                  shape: BoxShape.circle,
                ),
                child: Icon(icon, color: color, size: 20),
              ),
              const SizedBox(height: 6),
              Text(
                label,
                style: TextStyle(
                  fontSize: 11,
                  fontWeight: FontWeight.bold,
                  color: isDark ? Colors.white70 : Colors.black87,
                ),
                textAlign: TextAlign.center,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildRateBadge(String label, String value, Color color) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 3),
      decoration: BoxDecoration(
        color: color.withOpacity(0.12),
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: color.withOpacity(0.35), width: 1),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(label, style: TextStyle(color: color, fontSize: 8, fontWeight: FontWeight.bold)),
          Text(
            value,
            style: TextStyle(
              color: isDark ? Colors.white : AppTheme.textPrimaryLight,
              fontSize: 10,
              fontWeight: FontWeight.bold,
            ),
          ),
        ],
      ),
    );
  }

  String _formatAmount(double amountInUsd, double bcvRate) {
    if (_isPrivacyMode) return '••••••';
    if (_showInVes) {
      return currencyFormatVes.format(amountInUsd * bcvRate);
    }
    return currencyFormatUsd.format(amountInUsd);
  }

  @override
  Widget build(BuildContext context) {
    final summaryAsync = ref.watch(dashboardSummaryProvider);
    final transactionsAsync = ref.watch(recentTransactionsProvider);
    final categorySummaryAsync = ref.watch(categorySummaryProvider);
    final ratesAsync = ref.watch(exchangeRatesProvider);
    final double bcvRate = ratesAsync.valueOrNull?.bcvUsd ?? 764.35;

    return Scaffold(
      appBar: AppBar(
        title: Row(
          children: [
            const GaxxsIconMark(size: 28),
            const SizedBox(width: 10),
            Text(
              'My Finances',
              style: TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.bold,
                letterSpacing: 0.5,
                color: Theme.of(context).brightness == Brightness.dark ? Colors.white : AppTheme.textPrimaryLight,
              ),
            ),
          ],
        ),
        backgroundColor: Colors.transparent,
        elevation: 0,
        actions: [
          // Privacy Mode toggle (Eye icon) - adapts to theme
          IconButton(
            icon: Icon(
              _isPrivacyMode ? Icons.visibility_off_outlined : Icons.visibility_outlined,
              color: _isPrivacyMode
                  ? AppTheme.accentDark
                  : (Theme.of(context).brightness == Brightness.dark ? Colors.white70 : AppTheme.textSecondaryLight),
            ),
            onPressed: () {
              setState(() => _isPrivacyMode = !_isPrivacyMode);
              AppToast.show(context, message: _isPrivacyMode ? '🙈 Saldos ocultos' : '👁️ Saldos visibles', type: AppToastType.info);
            },
            tooltip: 'Ocultar / Mostrar Saldos',
          ),
          IconButton(
            icon: _isSyncing
                ? const SizedBox(width: 24, height: 24, child: GaxxsLoader(size: 20, showBrandName: false))
                : Icon(Icons.sync_rounded,
                    color: Theme.of(context).brightness == Brightness.dark ? Colors.white70 : AppTheme.textSecondaryLight),
            onPressed: _isSyncing ? null : _triggerSync,
            tooltip: 'Recargar tasas BCV',
          ),
          IconButton(
            icon: Icon(Icons.lock_outline_rounded,
                color: Theme.of(context).brightness == Brightness.dark ? Colors.white70 : AppTheme.textSecondaryLight),
            onPressed: () {
              SweetAlert.show(
                context,
                title: '¿Cerrar sesión?',
                description: 'Tu bóveda cifrada se bloqueará de forma segura.',
                icon: SweetAlertIcon.warning,
                confirmButtonText: 'Sí, Bloquear',
                cancelButtonText: 'Cancelar',
                onConfirm: () async {
                  AppToast.show(context, message: '🔒 Bóveda bloqueada. Sesión cerrada.', type: AppToastType.info);
                  await ref.read(authStateProvider.notifier).logout();
                },
              );
            },
            tooltip: 'Cerrar sesión y Bloquear',
          ),
        ],
      ),
      body: LayoutBuilder(
        builder: (context, constraints) {
          final hPad = constraints.maxWidth > 600 ? 40.0 : 16.0;
          return SingleChildScrollView(
            child: Padding(
              padding: EdgeInsets.symmetric(horizontal: hPad, vertical: 16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  // Venezuelan Exchange Rates Ticker Card
                  _buildExchangeRatesCard(),

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
                          colors: [AppTheme.primaryDark, Color(0xFF1E3A8A)],
                          begin: Alignment.topLeft,
                          end: Alignment.bottomRight,
                        ),
                        borderRadius: BorderRadius.circular(20),
                        boxShadow: [
                          BoxShadow(
                            color: AppTheme.primaryDark.withOpacity(0.3),
                            blurRadius: 16,
                            offset: const Offset(0, 6),
                          ),
                        ],
                      ),
                      padding: const EdgeInsets.all(22.0),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Row(
                            mainAxisAlignment: MainAxisAlignment.spaceBetween,
                            children: [
                              const Text(
                                'SALDO NETO TOTAL',
                                style: TextStyle(
                                  color: Colors.white70,
                                  fontSize: 11,
                                  fontWeight: FontWeight.bold,
                                  letterSpacing: 1.5,
                                ),
                              ),
                              // Currency Switcher Button ($ USD vs. Bs. VES)
                              GestureDetector(
                                onTap: () {
                                  setState(() => _showInVes = !_showInVes);
                                  AppToast.show(
                                    context,
                                    message: _showInVes ? '🇻🇪 Moneda cambiada a Bolívares (Bs. BCV)' : '💵 Moneda cambiada a Dólares (\$ USD)',
                                    type: AppToastType.info,
                                  );
                                },
                                child: Container(
                                  padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                                  decoration: BoxDecoration(
                                    color: Colors.white.withOpacity(0.2),
                                    borderRadius: BorderRadius.circular(12),
                                    border: Border.all(color: Colors.white30),
                                  ),
                                  child: Row(
                                    children: [
                                      Text(
                                        _showInVes ? '🇻🇪 Bs.' : '💵 USD',
                                        style: const TextStyle(color: Colors.white, fontSize: 11, fontWeight: FontWeight.bold),
                                      ),
                                      const SizedBox(width: 4),
                                      const Icon(Icons.swap_horiz, color: Colors.white, size: 14),
                                    ],
                                  ),
                                ),
                              ),
                            ],
                          ),
                          const SizedBox(height: 8),
                          Text(
                            _formatAmount(totalBalance, bcvRate),
                            style: const TextStyle(
                              color: Colors.white,
                              fontSize: 34,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                          const SizedBox(height: 20),
                          Row(
                            mainAxisAlignment: MainAxisAlignment.spaceBetween,
                            children: [
                              Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  const Row(
                                    children: [
                                      Icon(Icons.arrow_downward, color: Colors.greenAccent, size: 14),
                                      SizedBox(width: 4),
                                      Text('INGRESOS DEL MES', style: TextStyle(color: Colors.white70, fontSize: 10, fontWeight: FontWeight.w600)),
                                    ],
                                  ),
                                  const SizedBox(height: 4),
                                  Text(
                                    _formatAmount(income, bcvRate),
                                    style: const TextStyle(color: Colors.white, fontSize: 15, fontWeight: FontWeight.bold),
                                  ),
                                ],
                              ),
                              Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  const Row(
                                    children: [
                                      Icon(Icons.arrow_upward, color: Colors.redAccent, size: 14),
                                      SizedBox(width: 4),
                                      Text('GASTOS DEL MES', style: TextStyle(color: Colors.white70, fontSize: 10, fontWeight: FontWeight.w600)),
                                    ],
                                  ),
                                  const SizedBox(height: 4),
                                  Text(
                                    _formatAmount(expense, bcvRate),
                                    style: const TextStyle(color: Colors.white, fontSize: 15, fontWeight: FontWeight.bold),
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
              const SizedBox(height: 18),

              // 4 Executive Financial Tools Grid
              Row(
                children: [
                  _buildQuickActionTool(
                    icon: Icons.calculate_rounded,
                    label: 'Calculadora',
                    color: const Color(0xFF10B981),
                    onTap: () => QuickCurrencyCalculatorSheet.show(context),
                  ),
                  const SizedBox(width: 8),
                  _buildQuickActionTool(
                    icon: Icons.picture_as_pdf_rounded,
                    label: 'Reportes',
                    color: const Color(0xFF06B6D4),
                    onTap: () => ExportReportSheet.show(context),
                  ),
                  const SizedBox(width: 8),
                  _buildQuickActionTool(
                    icon: Icons.savings_rounded,
                    label: 'Metas',
                    color: const Color(0xFFA855F7),
                    onTap: () => Navigator.push(context, MaterialPageRoute(builder: (_) => const SavingsGoalsScreen())),
                  ),
                  const SizedBox(width: 8),
                  _buildQuickActionTool(
                    icon: Icons.event_repeat_rounded,
                    label: 'Fijos / Subs',
                    color: const Color(0xFFF59E0B),
                    onTap: () => Navigator.push(context, MaterialPageRoute(builder: (_) => const RecurringPaymentsScreen())),
                  ),
                ],
              ),

              const SizedBox(height: 20),

              // Row: "Mis Cuentas" + NFC Scanner Button + Plus Button
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text(
                    'Mis Cuentas',
                    style: Theme.of(context).textTheme.titleLarge?.copyWith(
                          fontWeight: FontWeight.bold,
                        ),
                  ),
                  Row(
                    children: [
                      IconButton(
                        icon: const Icon(Icons.contactless_outlined, color: AppTheme.accentDark),
                        onPressed: _handleNfcScan,
                        tooltip: 'Escanear Tarjeta NFC registrada',
                      ),
                      IconButton(
                        icon: const Icon(Icons.add_circle_outline, color: AppTheme.primaryDark),
                        onPressed: _showCreateAccountDialog,
                        tooltip: 'Agregar nueva cuenta',
                      ),
                    ],
                  ),
                ],
              ),
              const SizedBox(height: 8),

              // Horizontal list of accounts cards (Using _CreditCardVisual for realistic digital credit card design)
              ref.watch(accountsListProvider).when(
                data: (accounts) {
                  if (accounts.isEmpty) return const SizedBox.shrink();
                  return SizedBox(
                    height: 160,
                    child: ListView.builder(
                      scrollDirection: Axis.horizontal,
                      itemCount: accounts.length,
                      itemBuilder: (context, index) {
                        final acc = accounts[index];
                        final type = acc['type'] as String;
                        final String accName = acc['name'] as String;
                        final double balance = (acc['balance'] as num).toDouble();
                        final String colorHex = (acc['color'] as String?) ?? '#1E40AF';

                        final nameParts = accName.split(' | ');
                        final cardTitle = nameParts[0];
                        final cardSub = nameParts.length > 1 ? nameParts[1] : '';

                        return _CreditCardVisual(
                          bankName: cardTitle,
                          alias: cardSub,
                          type: type,
                          balanceText: _formatAmount(balance, bcvRate),
                          colorHex: colorHex,
                          onDelete: () => _confirmDeleteAccount(acc),
                          onTap: () => _showAccountTransactions(acc),
                        );
                      },
                    ),
                  );
                },
                loading: () => const Center(child: CircularProgressIndicator()),
                error: (_, __) => const SizedBox.shrink(),
              ),

              const SizedBox(height: 24),

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
                                    title: '${entry.key}\n${_formatAmount(entry.value, bcvRate)}',
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
                          trailing: Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Column(
                                mainAxisAlignment: MainAxisAlignment.center,
                                crossAxisAlignment: CrossAxisAlignment.end,
                                children: [
                                  Text(
                                    '${isIncome ? '+' : '-'}${_formatAmount((tx['amount'] as num).toDouble(), bcvRate)}',
                                    style: TextStyle(
                                      fontWeight: FontWeight.bold,
                                      fontSize: 15,
                                      color: isIncome ? AppTheme.accentDark : Colors.redAccent,
                                    ),
                                  ),
                                  Text(
                                    formattedDate,
                                    style: TextStyle(fontSize: 10, color: Theme.of(context).brightness == Brightness.dark ? Colors.white38 : Colors.black38),
                                  ),
                                ],
                              ),
                              const SizedBox(width: 4),
                              IconButton(
                                icon: const Icon(Icons.delete_outline, color: Colors.redAccent, size: 18),
                                onPressed: () => _confirmDeleteTransaction(tx['id'] as String),
                                tooltip: 'Eliminar movimiento',
                              ),
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
              // Extra bottom padding so FAB doesn't cover last items
              const SizedBox(height: 90),
            ],
          ),
        ),
      );
        },
      ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: _showAddTransactionDialog,
        backgroundColor: AppTheme.primaryDark,
        elevation: 6,
        icon: const Icon(Icons.add_rounded, color: Colors.white, size: 22),
        label: const Text('Nuevo Movimiento', style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
      ),
      floatingActionButtonLocation: FloatingActionButtonLocation.centerFloat,
    );
  }

  Widget _buildEmptyStateCard() {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    return Card(
      elevation: isDark ? 0 : 2,
      color: Theme.of(context).cardColor,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(16),
        side: BorderSide(color: isDark ? AppTheme.primaryDark.withOpacity(0.1) : Colors.black12),
      ),
      child: Padding(
        padding: const EdgeInsets.all(32.0),
        child: Column(
          children: [
            const Icon(Icons.account_balance_wallet_outlined, size: 64, color: AppTheme.primaryDark),
            const SizedBox(height: 16),
            Text(
              'No tienes cuentas creadas',
              style: TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.bold,
                color: isDark ? Colors.white : AppTheme.textPrimaryLight,
              ),
            ),
            const SizedBox(height: 8),
            Text(
              'Crea una cuenta en efectivo, banco o tarjeta bancaria para registrar tus saldos reales y movimientos.',
              textAlign: TextAlign.center,
              style: TextStyle(
                color: isDark ? AppTheme.textSecondaryDark : AppTheme.textSecondaryLight,
              ),
            ),
            const SizedBox(height: 24),
            ElevatedButton.icon(
              icon: const Icon(Icons.add, color: Colors.white),
              label: const Text('Crear Primera Cuenta', style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
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

class _CreditCardVisual extends StatelessWidget {
  final String bankName;
  final String alias;
  final String type;
  final String balanceText;
  final String colorHex;
  final VoidCallback? onDelete;
  final VoidCallback? onTap;

  const _CreditCardVisual({
    required this.bankName,
    required this.alias,
    required this.type,
    required this.balanceText,
    required this.colorHex,
    this.onDelete,
    this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    List<Color> gradientColors;
    switch (type) {
      case 'card':
        gradientColors = const [Color(0xFF1E1B4B), Color(0xFF312E81)];
        break;
      case 'bank':
        gradientColors = const [Color(0xFF0F172A), Color(0xFF1E40AF)];
        break;
      case 'cash':
        gradientColors = const [Color(0xFF064E3B), Color(0xFF047857)];
        break;
      default:
        gradientColors = const [Color(0xFF78350F), Color(0xFFB45309)];
    }

    if (colorHex.startsWith('#')) {
      try {
        final hexStr = colorHex.replaceAll('#', '');
        final baseColor = Color(int.parse('FF$hexStr', radix: 16));
        final hsl = HSLColor.fromColor(baseColor);
        final darkerColor = hsl.withLightness((hsl.lightness - 0.15).clamp(0.0, 1.0)).toColor();
        gradientColors = [baseColor, darkerColor];
      } catch (_) {}
    }

    String badgeLabel;
    switch (type) {
      case 'card':
        badgeLabel = 'TARJETA';
        break;
      case 'bank':
        badgeLabel = 'BANCO';
        break;
      case 'cash':
        badgeLabel = 'EFECTIVO';
        break;
      default:
        badgeLabel = 'AHORROS';
    }

    return GestureDetector(
      onTap: onTap,
      child: Container(
        width: 250,
        height: 155,
        margin: const EdgeInsets.only(right: 12),
        child: Stack(
          children: [
            // Base Card Container with metallic gradient & gloss
            Container(
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  colors: gradientColors,
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                ),
                borderRadius: BorderRadius.circular(20),
                border: Border.all(color: Colors.white.withOpacity(0.25), width: 1.2),
                boxShadow: [
                  BoxShadow(
                    color: gradientColors.first.withOpacity(0.45),
                    blurRadius: 14,
                    offset: const Offset(0, 6),
                  ),
                ],
              ),
            ),

            // Diagonal Gloss Overlay effect
            ClipRRect(
              borderRadius: BorderRadius.circular(20),
              child: Container(
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    colors: [
                      Colors.white.withOpacity(0.18),
                      Colors.white.withOpacity(0.0),
                      Colors.white.withOpacity(0.08),
                    ],
                    begin: Alignment.topRight,
                    end: Alignment.bottomLeft,
                  ),
                ),
              ),
            ),

            // Card Content Layout
            Padding(
              padding: const EdgeInsets.all(16.0),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  // Header Row: Bank Name + Product Badge + Delete Button
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Expanded(
                        child: Text(
                          bankName.isEmpty ? 'MI TARJETA' : bankName.toUpperCase(),
                          style: const TextStyle(
                            color: Colors.white,
                            fontSize: 12,
                            fontWeight: FontWeight.w900,
                            letterSpacing: 1.2,
                          ),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                      const SizedBox(width: 6),
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 2),
                        decoration: BoxDecoration(
                          color: Colors.white.withOpacity(0.2),
                          borderRadius: BorderRadius.circular(6),
                          border: Border.all(color: Colors.white.withOpacity(0.3), width: 0.8),
                        ),
                        child: Text(
                          badgeLabel,
                          style: const TextStyle(
                            color: Colors.white,
                            fontSize: 9,
                            fontWeight: FontWeight.bold,
                            letterSpacing: 0.8,
                          ),
                        ),
                      ),
                      if (onDelete != null) ...[
                        const SizedBox(width: 6),
                        GestureDetector(
                          onTap: onDelete,
                          child: Container(
                            padding: const EdgeInsets.all(3),
                            decoration: BoxDecoration(
                              color: Colors.black.withOpacity(0.25),
                              shape: BoxShape.circle,
                            ),
                            child: const Icon(Icons.close_rounded, color: Colors.white70, size: 14),
                          ),
                        ),
                      ],
                    ],
                  ),

                  // Middle Row: Metallic EMV Chip + Contactless Wave Icon
                  Row(
                    children: [
                      // Gold Metallic EMV Chip
                      Container(
                        width: 30,
                        height: 22,
                        decoration: BoxDecoration(
                          gradient: const LinearGradient(
                            colors: [Color(0xFFFDE047), Color(0xFFCA8A04)],
                            begin: Alignment.topLeft,
                            end: Alignment.bottomRight,
                          ),
                          borderRadius: BorderRadius.circular(5),
                          border: Border.all(color: const Color(0xFFA16207), width: 0.8),
                          boxShadow: [
                            BoxShadow(
                              color: Colors.black.withOpacity(0.3),
                              blurRadius: 2,
                              offset: const Offset(1, 1),
                            ),
                          ],
                        ),
                        child: CustomPaint(
                          painter: _ChipLinesPainter(),
                        ),
                      ),
                      const SizedBox(width: 8),
                      // Contactless Payment Wave Icon
                      const Icon(Icons.contactless_rounded, color: Colors.white70, size: 18),
                    ],
                  ),

                  // Bottom Row: Alias / Cardholder Name (Left) & Balance / Brand Logo (Right)
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    crossAxisAlignment: CrossAxisAlignment.end,
                    children: [
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            if (alias.isNotEmpty)
                              Text(
                                alias.toUpperCase(),
                                style: TextStyle(
                                  color: Colors.white.withOpacity(0.8),
                                  fontSize: 10,
                                  fontWeight: FontWeight.w600,
                                  letterSpacing: 0.8,
                                ),
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                              ),
                            const SizedBox(height: 2),
                            Text(
                              balanceText,
                              style: const TextStyle(
                                color: Colors.white,
                                fontSize: 18,
                                fontWeight: FontWeight.w800,
                                letterSpacing: 0.5,
                              ),
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                            ),
                          ],
                        ),
                      ),
                      // Dual-circle Credit Card Network Logo Graphic (MasterCard / Visa aesthetic)
                      SizedBox(
                        width: 32,
                        height: 20,
                        child: Stack(
                          children: [
                            Positioned(
                              left: 0,
                              child: Container(
                                width: 20,
                                height: 20,
                                decoration: BoxDecoration(
                                  color: const Color(0xFFEF4444).withOpacity(0.85),
                                  shape: BoxShape.circle,
                                ),
                              ),
                            ),
                            Positioned(
                              right: 0,
                              child: Container(
                                width: 20,
                                height: 20,
                                decoration: BoxDecoration(
                                  color: const Color(0xFFF59E0B).withOpacity(0.85),
                                  shape: BoxShape.circle,
                                ),
                              ),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

// Custom Painter for chip grid lines to give exact EMV chip realism
class _ChipLinesPainter extends CustomPainter {
  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = const Color(0xFF854D0E)
      ..strokeWidth = 0.7
      ..style = PaintingStyle.stroke;

    final path = Path();
    // Center horizontal line
    path.moveTo(0, size.height * 0.5);
    path.lineTo(size.width, size.height * 0.5);
    // Vertical left line
    path.moveTo(size.width * 0.35, 0);
    path.lineTo(size.width * 0.35, size.height);
    // Vertical right line
    path.moveTo(size.width * 0.65, 0);
    path.lineTo(size.width * 0.65, size.height);

    canvas.drawPath(path, paint);
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}
