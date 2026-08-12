import 'dart:convert';
import 'package:telephony/telephony.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';

@pragma('vm:entry-point')
void backpageMessageHandler(SmsMessage message) async {
  final body = message.body;
  if (body == null) return;

  // Regex to match bank expense messages
  // Captures words like: compra, consumo, retiro, cargo, debito, and parses the numerical amount
  final regex = RegExp(
    r'(?:compra|consumo|retiro|pago|debito|cargo|transferencia)[^\d]*\$?\s*([\d\.,]+)',
    caseSensitive: false,
  );
  final match = regex.firstMatch(body);
  
  if (match != null) {
    final amountStr = match.group(1)?.replaceAll(',', '');
    final amount = double.tryParse(amountStr ?? '');
    if (amount != null) {
      // Attempt to extract the merchant
      final merchantRegex = RegExp(r'en\s+([A-Za-z0-9\s\-]+?)(?:\s+el|\s+con|\.)', caseSensitive: false);
      final merchantMatch = merchantRegex.firstMatch(body);
      final merchant = merchantMatch?.group(1)?.trim() ?? 'Comercio Detectado';

      // Auto-categorize based on text keywords
      String category = 'Otros';
      final lowerBody = body.toLowerCase();
      if (lowerBody.contains('supermercado') || lowerBody.contains('walmart') || lowerBody.contains('exito') || lowerBody.contains('tienda')) {
        category = 'Supermercado';
      } else if (lowerBody.contains('restaurante') || lowerBody.contains('cafe') || lowerBody.contains('comida') || lowerBody.contains('mcdonald')) {
        category = 'Comida';
      } else if (lowerBody.contains('gasolinera') || lowerBody.contains('uber') || lowerBody.contains('taxi') || lowerBody.contains('didi')) {
        category = 'Transporte';
      } else if (lowerBody.contains('netflix') || lowerBody.contains('spotify') || lowerBody.contains('cine') || lowerBody.contains('disney')) {
        category = 'Entretenimiento';
      } else if (lowerBody.contains('luz') || lowerBody.contains('agua') || lowerBody.contains('telefono') || lowerBody.contains('internet')) {
        category = 'Servicios';
      }

      final txJson = jsonEncode({
        'id': 'sms_${DateTime.now().millisecondsSinceEpoch}',
        'amount': amount,
        'category': category,
        'description': '$merchant (SMS)',
        'date': DateTime.now().toIso8601String(),
      });

      // Write directly to shared secure storage key
      const storage = FlutterSecureStorage(
        aOptions: AndroidOptions(encryptedSharedPreferences: true),
      );
      
      const keyPendingSms = 'pending_sms_transactions';
      final existing = await storage.read(key: keyPendingSms);
      List<String> list = [];
      if (existing != null) {
        list = List<String>.from(jsonDecode(existing) as List);
      }
      list.add(txJson);
      await storage.write(key: keyPendingSms, value: jsonEncode(list));
    }
  }
}

class SmsParserService {
  final Telephony _telephony = Telephony.instance;

  Future<bool> initialize() async {
    try {
      final bool? permissionGranted = await _telephony.requestPhoneAndSmsPermissions;
      if (permissionGranted == true) {
        _telephony.listenIncomingSms(
          onNewMessage: (SmsMessage message) {
            backpageMessageHandler(message);
          },
          onBackgroundMessage: backpageMessageHandler,
        );
        return true;
      }
      return false;
    } catch (_) {
      return false;
    }
  }
}
