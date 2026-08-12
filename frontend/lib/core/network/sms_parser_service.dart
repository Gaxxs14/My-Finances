import 'dart:convert';
import 'package:telephony/telephony.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';

@pragma('vm:entry-point')
void backpageMessageHandler(SmsMessage message) async {
  final body = message.body;
  if (body == null) return;

  double? amount;
  String merchant = 'Comercio Detectado';
  String category = 'Otros';

  // 1. Banesco Pago Móvil / Consumos
  final banescoRegex = RegExp(
    r'Banesco:\s*(?:Pago\s*Movil|Consumo|Compra|Debito)[^\d]*(?:Bs\.|Bs)?\s*([\d\.,]+)\s+(?:a|en|al)\s+([A-Za-z0-9\s]+?)(?:\s+el|\s+la|\.|\s+con)',
    caseSensitive: false,
  );

  // 2. BDV (Banco de Venezuela) Pago Móvil / Compras
  final bdvRegex = RegExp(
    r'BDV:\s*(?:Pago\s*Movil|Compra|Debito|Consumo)[^\d]*(?:Bs\.|Bs)?\s*([\d\.,]+)(?:\s+exitoso)?\s+(?:a|en|al|de)\s+([A-Za-z0-9\s]+?)(?:\s+el|\s+la|\.|\s+con)',
    caseSensitive: false,
  );

  // 3. Mercantil Pago Móvil / Débitos
  final mercantilRegex = RegExp(
    r'Mercantil:\s*(?:Pago\s*Movil|Debito|Compra|Consumo)[^\d]*(?:Bs\.|Bs)?\s*([\d\.,]+)\s+(?:a|en|al)\s+([A-Za-z0-9\s]+?)(?:\s+el|\s+la|\.|\s+con)',
    caseSensitive: false,
  );

  RegExpMatch? match;
  final lowerBody = body.toLowerCase();
  
  if (lowerBody.contains('banesco')) {
    match = banescoRegex.firstMatch(body);
  } else if (lowerBody.contains('bdv') || lowerBody.contains('venezuela')) {
    match = bdvRegex.firstMatch(body);
  } else if (lowerBody.contains('mercantil')) {
    match = mercantilRegex.firstMatch(body);
  }

  if (match == null) {
    // Fallback general regex
    final generalRegex = RegExp(
      r'(?:compra|consumo|retiro|pago|debito|cargo|transferencia)[^\d]*\$?\s*([\d\.,]+)',
      caseSensitive: false,
    );
    final genMatch = generalRegex.firstMatch(body);
    if (genMatch != null) {
      final amountStr = genMatch.group(1);
      if (amountStr != null) {
        if (amountStr.contains(',') && amountStr.contains('.')) {
          amount = double.tryParse(amountStr.replaceAll('.', '').replaceAll(',', '.'));
        } else if (amountStr.contains(',')) {
          amount = double.tryParse(amountStr.replaceAll(',', '.'));
        } else {
          amount = double.tryParse(amountStr);
        }
      }
    }
  } else {
    final amountStr = match.group(1);
    merchant = match.group(2)?.trim() ?? 'Comercio Detectado';
    if (amountStr != null) {
      if (amountStr.contains(',') && amountStr.contains('.')) {
        amount = double.tryParse(amountStr.replaceAll('.', '').replaceAll(',', '.'));
      } else if (amountStr.contains(',')) {
        amount = double.tryParse(amountStr.replaceAll(',', '.'));
      } else {
        amount = double.tryParse(amountStr);
      }
    }
  }

  if (amount != null) {
    // Auto-categorize using Venezuelan context
    if (lowerBody.contains('supermercado') || lowerBody.contains('walmart') || lowerBody.contains('exito') || lowerBody.contains('tienda') || lowerBody.contains('bodega') || lowerBody.contains('abasto') || lowerBody.contains('central madeirense') || lowerBody.contains('gama')) {
      category = 'Supermercado';
    } else if (lowerBody.contains('restaurante') || lowerBody.contains('cafe') || lowerBody.contains('comida') || lowerBody.contains('mcdonald') || lowerBody.contains('panaderia') || lowerBody.contains('arturo')) {
      category = 'Comida';
    } else if (lowerBody.contains('gasolinera') || lowerBody.contains('uber') || lowerBody.contains('taxi') || lowerBody.contains('didi') || lowerBody.contains('yummy') || lowerBody.contains('ridery') || lowerBody.contains('bomba')) {
      category = 'Transporte';
    } else if (lowerBody.contains('netflix') || lowerBody.contains('spotify') || lowerBody.contains('cine') || lowerBody.contains('disney')) {
      category = 'Entretenimiento';
    } else if (lowerBody.contains('luz') || lowerBody.contains('agua') || lowerBody.contains('telefono') || lowerBody.contains('cantv') || lowerBody.contains('internet') || lowerBody.contains('simpletv') || lowerBody.contains('movistar') || lowerBody.contains('digitel')) {
      category = 'Servicios';
    } else if (lowerBody.contains('farmacia') || lowerBody.contains('clinica') || lowerBody.contains('doctor') || lowerBody.contains('farmatodo') || lowerBody.contains('locatel')) {
      category = 'Salud';
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
