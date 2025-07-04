// lib/data/datasources/market_mood_remote_ds.dart
// 🌐 Data Layer: 원격 데이터 소스 (TradeRemoteDataSource 패턴 적용)

import 'dart:async';
import 'package:flutter/foundation.dart';
import '../../core/network/api_client_coingecko.dart';
import '../../core/utils/logger.dart';
import '../../data/models/market_mood_dto.dart';

/// 🌐 마켓무드 원격 데이터 소스 (개선된 버전)
class MarketMoodRemoteDataSource {
  final CoinGeckoApiClient _apiClient;
  
  // 🎯 핵심: 단순한 스트림 관리 (TradeRemoteDataSource 패턴)
  Stream<CoinGeckoGlobalDataDto>? _currentStream;
  Timer? _globalDataTimer;
  StreamController<CoinGeckoGlobalDataDto>? _globalDataController;
  bool _disposed = false;

  MarketMoodRemoteDataSource(this._apiClient);

  /// 🎯 핵심 메소드: 스트림이 없을 때만 새로 생성
  Stream<CoinGeckoGlobalDataDto> getGlobalMarketDataStream() {
    if (_disposed) {
      throw StateError('MarketMoodRemoteDataSource has been disposed');
    }

    // 이미 활성화된 스트림이 있으면 재사용
    if (_currentStream != null) {
      debugPrint('MarketMoodRemoteDataSource: Reusing existing stream');
      return _currentStream!;
    }

    debugPrint('MarketMoodRemoteDataSource: Creating new stream');
    _currentStream = _createGlobalDataStream();
    return _currentStream!;
  }

  /// 🔥 새로운 스트림 생성 (Timer 중복 방지)
  Stream<CoinGeckoGlobalDataDto> _createGlobalDataStream() {
    // 기존 Timer/Controller 정리
    _ensureCleanState();
    
    // 새로운 Controller 생성
    _globalDataController = StreamController<CoinGeckoGlobalDataDto>.broadcast();

    // 첫 호출
    _fetchGlobalData();

    // 30분마다 호출 (Timer 새로 생성)
    _globalDataTimer = Timer.periodic(
      const Duration(minutes: 30), 
      (_) => _fetchGlobalData()
    );

    // 스트림 취소 시 정리
    _globalDataController!.onCancel = () {
      debugPrint('MarketMoodRemoteDataSource: Stream cancelled, cleaning resources');
      _cleanupCurrentStream();
    };

    return _globalDataController!.stream;
  }

  /// 🎯 API 호출 및 데이터 파싱 (순수 함수)
  Future<void> _fetchGlobalData() async {
    if (_disposed || _globalDataController == null || _globalDataController!.isClosed) {
      return;
    }

    try {
      final responseDto = await _apiClient.getGlobalMarketData();
      final dataDto = responseDto.data;
      
      if (!_globalDataController!.isClosed) {
        _globalDataController!.add(dataDto);
        log.d('📊 글로벌 마켓 데이터 수신 성공: ${dataDto.totalVolumeUsd.toStringAsFixed(0)}B USD');
      }
    } catch (e, st) {
      if (!_globalDataController!.isClosed) {
        _globalDataController!.addError(e, st);
        log.e('❌ 글로벌 마켓 데이터 조회 실패: $e');
      }
    }
  }

  /// 🔧 기존 Timer/Controller 정리 (중복 방지)
  void _ensureCleanState() {
    _globalDataTimer?.cancel();
    _globalDataTimer = null;
    
    if (_globalDataController != null && !_globalDataController!.isClosed) {
      _globalDataController!.close();
    }
    _globalDataController = null;
  }

  /// 🔧 현재 스트림만 정리 (dispose와 구분)
  void _cleanupCurrentStream() {
    _globalDataTimer?.cancel();
    _globalDataTimer = null;
    
    if (_globalDataController != null && !_globalDataController!.isClosed) {
      _globalDataController!.close();
    }
    _globalDataController = null;
    _currentStream = null;
    
    debugPrint('MarketMoodRemoteDataSource: Current stream cleaned');
  }

  /// 🎯 단일 호출 API (스트림과 독립적)
  Future<CoinGeckoGlobalDataDto> getGlobalMarketData() async {
    if (_disposed) {
      throw StateError('MarketMoodRemoteDataSource has been disposed');
    }
    
    try {
      final responseDto = await _apiClient.getGlobalMarketData();
      log.d('📊 단일 글로벌 마켓 데이터 조회 성공');
      return responseDto.data;
    } catch (e) {
      log.e('❌ 단일 글로벌 마켓 데이터 조회 실패: $e');
      rethrow;
    }
  }

  /// 💱 환율 조회 (안전한 fallback)
  Future<double> getUsdToKrwRate() async {
    if (_disposed) {
      throw StateError('MarketMoodRemoteDataSource has been disposed');
    }
    
    try {
      final rate = await _apiClient.getUsdToKrwRate();
      log.d('💱 환율 조회 성공: $rate KRW');
      return rate;
    } catch (e) {
      log.w('💱 환율 조회 실패, 기본값 사용: $e');
      return 1400.0; // 안전한 fallback
    }
  }

  /// 🔍 API 헬스 체크
  Future<bool> checkApiHealth() async {
    if (_disposed) return false;
    
    try {
      await getGlobalMarketData();
      return true;
    } catch (_) {
      return false;
    }
  }

  /// 🧹 리소스 정리 (TradeRemoteDataSource 패턴)
  void dispose() {
    if (_disposed) return;
    
    debugPrint('MarketMoodRemoteDataSource: dispose() called');
    _disposed = true;
    
    // 모든 리소스 정리
    _ensureCleanState();
    _currentStream = null;
    
    log.d('🧹 MarketMoodRemoteDataSource 정리 완료');
  }
}