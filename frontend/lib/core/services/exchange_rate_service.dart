import 'package:dio/dio.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

class ExchangeRates {
  final double bcvUsd;
  final double bcvEur;
  final double binanceUsd;
  final DateTime lastUpdated;

  ExchangeRates({
    required this.bcvUsd,
    required this.bcvEur,
    required this.binanceUsd,
    required this.lastUpdated,
  });

  factory ExchangeRates.fallback() {
    return ExchangeRates(
      bcvUsd: 764.35,
      bcvEur: 882.30,
      binanceUsd: 867.23,
      lastUpdated: DateTime.now(),
    );
  }
}

class ExchangeRateService {
  final Dio _dio = Dio(BaseOptions(
    connectTimeout: const Duration(seconds: 6),
    receiveTimeout: const Duration(seconds: 6),
  ));

  Future<ExchangeRates> fetchRates() async {
    double bcvUsd = 764.35;
    double bcvEur = 882.30;
    double binanceUsd = 867.23;

    try {
      // 1. Fetch BCV & Paralelo USD
      final usdRes = await _dio.get('https://ve.dolarapi.com/v1/dolares');
      if (usdRes.statusCode == 200 && usdRes.data is List) {
        final list = usdRes.data as List;
        for (var item in list) {
          if (item['fuente'] == 'oficial' && item['promedio'] != null) {
            bcvUsd = (item['promedio'] as num).toDouble();
          } else if (item['fuente'] == 'paralelo' && item['promedio'] != null) {
            binanceUsd = (item['promedio'] as num).toDouble();
          }
        }
      }

      // 2. Fetch BCV EUR
      final eurRes = await _dio.get('https://ve.dolarapi.com/v1/euros/oficial');
      if (eurRes.statusCode == 200 && eurRes.data is Map) {
        if (eurRes.data['promedio'] != null) {
          bcvEur = (eurRes.data['promedio'] as num).toDouble();
        }
      }
    } catch (_) {
      // Use latest fallback if network fails
    }

    return ExchangeRates(
      bcvUsd: bcvUsd,
      bcvEur: bcvEur,
      binanceUsd: binanceUsd,
      lastUpdated: DateTime.now(),
    );
  }
}

final exchangeRateServiceProvider = Provider<ExchangeRateService>((ref) {
  return ExchangeRateService();
});

final exchangeRatesProvider = FutureProvider<ExchangeRates>((ref) async {
  return await ref.watch(exchangeRateServiceProvider).fetchRates();
});
