// lib/core/network/api_client_coingecko.dart

import 'package:dio/dio.dart';
import 'package:flutter/foundation.dart';
import '../../data/models/market_mood_dto.dart';
import '../error/app_exception.dart';
import '../utils/logger.dart';

/// 🌐 CoinGecko API 클라이언트
class CoinGeckoApiClient {
  static const String _baseUrl = 'https://api.coingecko.com/api/v3';
  static const String _pathGlobal = '/global';
  static const String _exchangeRateUrl = 'https://api.exchangerate-api.com/v4/latest/USD';
  static const String _keyRates = 'rates';
  static const String _keyKrw = 'KRW';

  static const Duration _timeout = Duration(seconds: 10);
  
  final Dio _dio;
  
  CoinGeckoApiClient({Dio? dio}) : _dio = dio ?? _createDio();
  
  static Dio _createDio() {
    final dio = Dio(BaseOptions(
      baseUrl: _baseUrl,
      connectTimeout: _timeout,
      receiveTimeout: _timeout,
      sendTimeout: _timeout,
      headers: { 'Accept': 'application/json', 'Content-Type': 'application/json' },
    ));
    
    if (kDebugMode) {
      dio.interceptors.add(LogInterceptor(
        requestBody: false,
        responseBody: false,
        logPrint: (object) => log.d('[CoinGecko API] $object'),
      ));
    }
    
    return dio;
  }
  
  /// 🎯 전체 시장 데이터 조회
  Future<CoinGeckoGlobalResponseDto> getGlobalMarketData() async {
    try {
      final response = await _dio.get(_pathGlobal);
      if (response.statusCode == 200 && response.data != null) {
        return CoinGeckoGlobalResponseDto.fromJson(response.data);
      } else {
        throw NetworkException(
          'Invalid response from CoinGecko API: ${response.statusCode}',
          statusCode: response.statusCode,
        );
      }
    } on DioException catch (e) {
      log.e('[CoinGecko] DioException: ${e.message}', e);
      throw NetworkException.fromDio(e);
    } catch (e, stackTrace) {
      log.e('[CoinGecko] Unexpected error: $e', e, stackTrace);
      throw AppException('Failed to fetch market data: $e');
    }
  }

  /// 💱 USD → KRW 환율 조회
  Future<double> getUsdToKrwRate() async {
    try {
      final response = await _dio.get(_exchangeRateUrl);
      if (response.statusCode == 200 && response.data != null) {
        final data = response.data as Map<String, dynamic>;
        final rates = data[_keyRates] as Map<String, dynamic>;
        final krwRate = (rates[_keyKrw] ?? 1400.0).toDouble();
        return krwRate;
      } else {
        throw NetworkException('Invalid response from Exchange Rate API: ${response.statusCode}',
          statusCode: response.statusCode,
        );
      }
    } on DioException {
      log.w('[ExchangeRate] DioException, using fallback rate 1400.0');
      return 1400.0;
    } catch (e) {
      log.w('[ExchangeRate] Unexpected error: $e, using fallback rate 1400.0');
      return 1400.0;
    }
  }
}