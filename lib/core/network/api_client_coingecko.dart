import 'package:dio/dio.dart';
import 'package:flutter/foundation.dart';
import '../error/app_exception.dart';
import '../utils/logger.dart';

/// 🌐 CoinGecko API 클라이언트
class CoinGeckoApiClient {
  static const String _baseUrl = 'https://api.coingecko.com/api/v3';
  static const String _exchangeRateUrl = 'https://api.exchangerate-api.com/v4/latest/USD';
  static const Duration _timeout = Duration(seconds: 10);
  
  final Dio _dio;
  
  CoinGeckoApiClient({Dio? dio}) : _dio = dio ?? _createDio();
  
  static Dio _createDio() {
    final dio = Dio(BaseOptions(
      baseUrl: _baseUrl,
      connectTimeout: _timeout,
      receiveTimeout: _timeout,
      sendTimeout: _timeout,
      headers: {
        'Accept': 'application/json',
        'Content-Type': 'application/json',
      },
    ));
    
    // 로깅 인터셉터 추가 (디버그 모드에서만)
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
  Future<CoinGeckoGlobalResponse> getGlobalMarketData() async {
    try {
      log.d('[CoinGecko] Fetching global market data...');
      
      final response = await _dio.get('/global');
      
      if (response.statusCode == 200 && response.data != null) {
        log.d('[CoinGecko] Global market data fetched successfully');
        return CoinGeckoGlobalResponse.fromJson(response.data);
      } else {
        throw NetworkException(
          'Invalid response from CoinGecko API: ${response.statusCode}',
          statusCode: response.statusCode,
        );
      }
    } on DioException catch (e) {
      log.e('[CoinGecko] DioException: ${e.message}');
      throw NetworkException.fromDio(e);
    } catch (e, stackTrace) {
      log.e('[CoinGecko] Unexpected error: $e');
      throw AppException('Failed to fetch market data: $e');
    }
  }

  /// 💱 USD → KRW 환율 조회 (하루 2회 호출용)
  Future<double> getUsdToKrwRate() async {
    try {
      log.d('[ExchangeRate] Fetching USD to KRW rate...');
      
      final response = await _dio.get(
        _exchangeRateUrl,
        options: Options(
          headers: {
            'Accept': 'application/json',
            'Content-Type': 'application/json',
          },
        ),
      );
      
      if (response.statusCode == 200 && response.data != null) {
        final data = response.data as Map<String, dynamic>;
        final rates = data['rates'] as Map<String, dynamic>;
        final krwRate = (rates['KRW'] ?? 1400.0).toDouble();
        
        log.d('[ExchangeRate] USD to KRW rate fetched: $krwRate');
        return krwRate;
      } else {
        throw NetworkException(
          'Invalid response from Exchange Rate API: ${response.statusCode}',
          statusCode: response.statusCode,
        );
      }
    } on DioException catch (e) {
      log.w('[ExchangeRate] DioException: ${e.message}, using fallback rate 1400.0');
      return 1400.0; // 환율 API 실패 시 기본값
    } catch (e) {
      log.w('[ExchangeRate] Unexpected error: $e, using fallback rate 1400.0');
      return 1400.0; // 환율 API 실패 시 기본값
    }
  }
}

/// 📊 CoinGecko Global API 응답 모델
class CoinGeckoGlobalResponse {
  final CoinGeckoGlobalData data;
  
  CoinGeckoGlobalResponse({required this.data});
  
  factory CoinGeckoGlobalResponse.fromJson(Map<String, dynamic> json) {
    return CoinGeckoGlobalResponse(
      data: CoinGeckoGlobalData.fromJson(json['data'] ?? {}),
    );
  }
}

/// 📈 CoinGecko 글로벌 시장 데이터
class CoinGeckoGlobalData {
  final int activeCryptocurrencies;
  final Map<String, double> totalMarketCap;
  final Map<String, double> totalVolume;
  final Map<String, double> marketCapPercentage;
  final double marketCapChangePercentage24hUsd;
  final int updatedAt;
  
  CoinGeckoGlobalData({
    required this.activeCryptocurrencies,
    required this.totalMarketCap,
    required this.totalVolume,
    required this.marketCapPercentage,
    required this.marketCapChangePercentage24hUsd,
    required this.updatedAt,
  });
  
  factory CoinGeckoGlobalData.fromJson(Map<String, dynamic> json) {
    return CoinGeckoGlobalData(
      activeCryptocurrencies: json['active_cryptocurrencies'] ?? 0,
      totalMarketCap: _parseDoubleMap(json['total_market_cap']),
      totalVolume: _parseDoubleMap(json['total_volume']),
      marketCapPercentage: _parseDoubleMap(json['market_cap_percentage']),
      marketCapChangePercentage24hUsd: (json['market_cap_change_percentage_24h_usd'] ?? 0.0).toDouble(),
      updatedAt: json['updated_at'] ?? 0,
    );
  }
  
  /// 💰 USD 기준 총 시가총액
  double get totalMarketCapUsd => totalMarketCap['usd'] ?? 0.0;
  
  /// 📦 USD 기준 24시간 거래량
  double get totalVolumeUsd => totalVolume['usd'] ?? 0.0;
  
  /// ⚡ BTC 시장 지배력
  double get btcDominance => marketCapPercentage['btc'] ?? 0.0;
  
  /// 💎 ETH 시장 지배력
  double get ethDominance => marketCapPercentage['eth'] ?? 0.0;
  
  /// 📅 마지막 업데이트 시간
  DateTime get lastUpdated => DateTime.fromMillisecondsSinceEpoch(updatedAt * 1000);
  
  /// JSON Map을 Double Map으로 변환하는 헬퍼 함수
  static Map<String, double> _parseDoubleMap(dynamic json) {
    if (json == null || json is! Map) return {};
    
    return Map<String, double>.fromEntries(
      (json as Map<String, dynamic>).entries.map(
        (e) => MapEntry(e.key, (e.value ?? 0.0).toDouble()),
      ),
    );
  }
  
  @override
  String toString() {
    return 'CoinGeckoGlobalData('
        'marketCapUsd: \$${totalMarketCapUsd.toStringAsFixed(0)}, '
        'volumeUsd: \$${totalVolumeUsd.toStringAsFixed(0)}, '
        'changePercent24h: ${marketCapChangePercentage24hUsd.toStringAsFixed(2)}%, '
        'btcDominance: ${btcDominance.toStringAsFixed(2)}%, '
        'ethDominance: ${ethDominance.toStringAsFixed(2)}%'
        ')';
  }
}