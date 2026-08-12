import 'dart:io';
import 'package:flutter/material.dart';
import 'package:nfc_manager/nfc_manager.dart';
import 'package:nfc_manager/nfc_manager_android.dart';
import 'package:nfc_manager/nfc_manager_ios.dart';
import '../../../core/theme/app_theme.dart';

class NfcScannerSheet extends StatefulWidget {
  const NfcScannerSheet({super.key});

  static Future<String?> show(BuildContext context) {
    return showModalBottomSheet<String>(
      context: context,
      backgroundColor: AppTheme.surfaceDark,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      isDismissible: false,
      enableDrag: false,
      builder: (context) => const NfcScannerSheet(),
    );
  }

  @override
  State<NfcScannerSheet> createState() => _NfcScannerSheetState();
}

class _NfcScannerSheetState extends State<NfcScannerSheet> with SingleTickerProviderStateMixin {
  late AnimationController _pulseController;
  bool _isAvailable = false;
  bool _isScanning = false;
  String _statusMessage = 'Inicializando sensor NFC...';
  String? _scannedUid;

  @override
  void initState() {
    super.initState();
    _pulseController = AnimationController(
      vsync: this,
      duration: const Duration(seconds: 2),
    )..repeat(reverse: true);
    
    _initNfc();
  }

  @override
  void dispose() {
    _pulseController.dispose();
    if (_isScanning) {
      NfcManager.instance.stopSession();
    }
    super.dispose();
  }

  Future<void> _initNfc() async {
    final available = await NfcManager.instance.isAvailable();
    setState(() {
      _isAvailable = available;
      if (available) {
        _statusMessage = 'Coloca tu tarjeta en la parte posterior de tu teléfono...';
        _startNfcSession();
      } else {
        _statusMessage = 'El sensor NFC no está activado o no es compatible con este dispositivo.';
      }
    });
  }

  void _startNfcSession() {
    setState(() => _isScanning = true);
    
    NfcManager.instance.startSession(
      pollingOptions: {
        NfcPollingOption.iso14443,
        NfcPollingOption.iso15693,
        NfcPollingOption.iso18092,
      },
      onDiscovered: (NfcTag tag) async {
        try {
          String? uid;
          
          if (Platform.isAndroid) {
            final androidTag = NfcTagAndroid.from(tag);
            if (androidTag != null) {
              uid = _toHex(androidTag.id);
            }
          } else if (Platform.isIOS) {
            final mifare = MiFareIos.from(tag);
            if (mifare != null) {
              uid = _toHex(mifare.identifier);
            } else {
              final iso7816 = Iso7816Ios.from(tag);
              if (iso7816 != null) {
                uid = _toHex(iso7816.identifier);
              }
            }
          }

          if (uid != null) {
            setState(() {
              _scannedUid = uid;
              _statusMessage = '¡Tarjeta Escaneada con Éxito!';
              _isScanning = false;
            });
            
            // Stop NFC Session
            await NfcManager.instance.stopSession();
            
            // Wait 1.5s to show completion UI and return the UID
            await Future.delayed(const Duration(milliseconds: 1500));
            if (mounted) {
              Navigator.pop(context, uid);
            }
          } else {
            setState(() {
              _statusMessage = 'Tarjeta detectada, pero no pudimos leer su ID único. Intenta de nuevo.';
            });
          }
        } catch (e) {
          setState(() {
            _statusMessage = 'Error al leer tarjeta: $e';
          });
        }
      },
    );
  }

  String _toHex(List<int> bytes) {
    return bytes.map((b) => b.toRadixString(16).padLeft(2, '0').toUpperCase()).join(':');
  }

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 32),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              const Text(
                'Lector NFC Bancario',
                style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold, color: Colors.white),
              ),
              IconButton(
                icon: const Icon(Icons.close, color: Colors.white60),
                onPressed: () => Navigator.pop(context),
              ),
            ],
          ),
          const SizedBox(height: 32),
          
          // NFC Pulse Visualizer
          Center(
            child: AnimatedBuilder(
              animation: _pulseController,
              builder: (context, child) {
                final double pulse = _pulseController.value;
                return Container(
                  width: 140,
                  height: 140,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    color: _scannedUid != null
                        ? Colors.greenAccent.withOpacity(0.1)
                        : AppTheme.primaryDark.withOpacity(0.1),
                    border: Border.all(
                      color: _scannedUid != null
                          ? Colors.greenAccent.withOpacity(1 - pulse)
                          : AppTheme.primaryDark.withOpacity(1 - pulse),
                      width: 2 + (pulse * 6),
                    ),
                  ),
                  child: Center(
                    child: Container(
                      width: 100,
                      height: 100,
                      decoration: BoxDecoration(
                        shape: BoxShape.circle,
                        color: _scannedUid != null ? Colors.greenAccent : AppTheme.primaryDark,
                      ),
                      child: Icon(
                        _scannedUid != null 
                            ? Icons.check_circle_outline 
                            : Icons.contactless_outlined,
                        color: Colors.white,
                        size: 48,
                      ),
                    ),
                  ),
                );
              },
            ),
          ),
          
          const SizedBox(height: 32),
          
          // Status Text
          Text(
            _statusMessage,
            textAlign: TextAlign.center,
            style: const TextStyle(
              fontSize: 16,
              color: AppTheme.textSecondaryDark,
              height: 1.4,
            ),
          ),
          
          if (_scannedUid != null) ...[
            const SizedBox(height: 16),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
              decoration: BoxDecoration(
                color: Colors.black26,
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: Colors.white10),
              ),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  const Icon(Icons.credit_card_outlined, color: AppTheme.accentDark, size: 20),
                  const SizedBox(width: 10),
                  Text(
                    'UID: $_scannedUid',
                    style: const TextStyle(
                      fontFamily: 'monospace',
                      fontWeight: FontWeight.bold,
                      color: Colors.white,
                      fontSize: 14,
                    ),
                  ),
                ],
              ),
            ),
          ],
          
          const SizedBox(height: 24),
          
          // Actions
          if (_isAvailable && _scannedUid == null)
            ElevatedButton(
              onPressed: () {
                if (_isScanning) {
                  NfcManager.instance.stopSession();
                  setState(() {
                    _isScanning = false;
                    _statusMessage = 'Lectura cancelada. Haz clic en "Reintentar" para reactivar.';
                  });
                } else {
                  _startNfcSession();
                  setState(() {
                    _statusMessage = 'Coloca tu tarjeta en la parte posterior de tu teléfono...';
                  });
                }
              },
              style: ElevatedButton.styleFrom(
                backgroundColor: _isScanning ? Colors.redAccent.withOpacity(0.2) : AppTheme.primaryDark,
                foregroundColor: Colors.white,
                padding: const EdgeInsets.symmetric(vertical: 16),
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
              ),
              child: Text(
                _isScanning ? 'Detener Lector' : 'Reintentar Lectura',
                style: const TextStyle(fontWeight: FontWeight.bold),
              ),
            ),
        ],
      ),
    );
  }
}
