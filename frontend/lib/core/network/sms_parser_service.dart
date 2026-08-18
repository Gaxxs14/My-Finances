import 'dart:convert';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';

// SMS Parser Service — background SMS detection disabled.
// The telephony package (discontinued) was removed because it triggered
// Infinix XOS security to block APK installation due to SMS permissions.
// The transaction parser logic is preserved for future reimplementation
// with a maintained package (e.g., another_telephony or sms_advanced).

class SmsParserService {
  Future<bool> initialize() async {
    // SMS background listening is currently disabled.
    // Returns false gracefully without crashing the app.
    return false;
  }

  // Parse an SMS body manually (kept for future use)
  static Map<String, dynamic>? parseSmsBody(String body) {
    double? amount;
    String merchant = 'Comercio Detectado';
    String category = 'Otros';

    final lowerBody = body.toLowerCase();

    final banescoRegex = RegExp(
      r'Banesco:\s*(?:Pago\s*Movil|Consumo|Compra|Debito)[^\d]*(?:Bs\.|Bs)?\s*([\d\.,]+)\s+(?:a|en|al)\s+([A-Za-z0-9\s]+?)(?:\s+el|\s+la|\.|\s+con)',
      caseSensitive: false,
    );
    final bdvRegex = RegExp(
      r'BDV:\s*(?:Pago\s*Movil|Compra|Debito|Consumo)[^\d]*(?:Bs\.|Bs)?\s*([\d\.,]+)(?:\s+exitoso)?\s+(?:a|en|al|de)\s+([A-Za-z0-9\s]+?)(?:\s+el|\s+la|\.|\s+con)',
      caseSensitive: false,
    );
    final mercantilRegex = RegExp(
      r'Mercantil:\s*(?:Pago\s*Movil|Debito|Compra|Consumo)[^\d]*(?:Bs\.|Bs)?\s*([\d\.,]+)\s+(?:a|en|al)\s+([A-Za-z0-9\s]+?)(?:\s+el|\s+la|\.|\s+con)',
      caseSensitive: false,
    );

    RegExpMatch? match;
    if (lowerBody.contains('banesco')) {
      match = banescoRegex.firstMatch(body);
    } else if (lowerBody.contains('bdv') || lowerBody.contains('venezuela')) {
      match = bdvRegex.firstMatch(body);
    } else if (lowerBody.contains('mercantil')) {
      match = mercantilRegex.firstMatch(body);
    }

    if (match == null) {
      final generalRegex = RegExp(
        r'(?:compra|consumo|retiro|pago|debito|cargo|transferencia)[^\d]*\$?\s*([\d\.,]+)',
        caseSensitive: false,
      );
      final genMatch = generalRegex.firstMatch(body);
      if (genMatch != null) {
        final amountStr = genMatch.group(1);
        if (amountStr != null) {
          amount = _parseAmount(amountStr);
        }
      }
    } else {
      final amountStr = match.group(1);
      merchant = match.group(2)?.trim() ?? 'Comercio Detectado';
      if (amountStr != null) {
        amount = _parseAmount(amountStr);
      }
    }

    if (amount == null) return null;

    if (lowerBody.contains('supermercado') || lowerBody.contains('tienda') || lowerBody.contains('bodega') || lowerBody.contains('abasto')) {
      category = 'Supermercado';
    } else if (lowerBody.contains('restaurante') || lowerBody.contains('comida') || lowerBody.contains('panaderia')) {
      category = 'Comida';
    } else if (lowerBody.contains('gasolinera') || lowerBody.contains('uber') || lowerBody.contains('taxi') || lowerBody.contains('didi')) {
      category = 'Transporte';
    } else if (lowerBody.contains('netflix') || lowerBody.contains('spotify') || lowerBody.contains('cine')) {
      category = 'Entretenimiento';
    } else if (lowerBody.contains('luz') || lowerBody.contains('agua') || lowerBody.contains('internet') || lowerBody.contains('movistar')) {
      category = 'Servicios';
    } else if (lowerBody.contains('farmacia') || lowerBody.contains('clinica') || lowerBody.contains('farmatodo')) {
      category = 'Salud';
    }

    return {
      'id': 'sms_${DateTime.now().millisecondsSinceEpoch}',
      'amount': amount,
      'category': category,
      'description': '$merchant (SMS)',
      'date': DateTime.now().toIso8601String(),
    };
  }

  static double? _parseAmount(String amountStr) {
    if (amountStr.contains(',') && amountStr.contains('.')) {
      return double.tryParse(amountStr.replaceAll('.', '').replaceAll(',', '.'));
    } else if (amountStr.contains(',')) {
      return double.tryParse(amountStr.replaceAll(',', '.'));
    }
    return double.tryParse(amountStr);
  }

  // Save a parsed transaction to pending queue (called manually or from other sources)
  static Future<void> savePendingTransaction(Map<String, dynamic> tx) async {
    const storage = FlutterSecureStorage(
      aOptions: AndroidOptions(encryptedSharedPreferences: true),
    );
    const keyPendingSms = 'pending_sms_transactions';
    final existing = await storage.read(key: keyPendingSms);
    List<String> list = [];
    if (existing != null) {
      list = List<String>.from(jsonDecode(existing) as List);
    }
    list.add(jsonEncode(tx));
    await storage.write(key: keyPendingSms, value: jsonEncode(list));
  }
}
