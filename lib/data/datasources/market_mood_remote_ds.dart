// lib/data/datasources/market_mood_remote_ds.dart
// 🌐 Data Layer: 원격 데이터 소스 (V2.0 실용적 개선)

import 'dart:async';
import 'package:flutter/foundation.dart';
import '../../core/network/api_client_coingecko.dart';
import '../../core/utils/logger.dart';
import '../../data/models/market_mood_dto.dart';

/// 🌐 마켓무드 원격 데이터 소스 V2.0
/// - 앱 상태 고려 (백그라운드 시 타이머 정지)
/// - 실패 시 스마트 재시도
/// - 메모리 최적화
class MarketMoodRemoteDataSource {
  final CoinGeckoApiClient _apiClient;

  // 🎯 핵심: 스트림 관리
  Stream<CoinGeckoGlobalDataDto>? _currentStream;
  Timer? _globalDataTimer;
  StreamController<CoinGeckoGlobalDataDto>? _globalDataController;
  bool _disposed = false;

  // 🔥 V2.0: 스마트 재시도 시스템
  int _consecutiveFailures = 0;
  DateTime? _lastSuccessTime;
  bool _isPaused = false;

  // 🎯 V2.0: 설정값들
  static const Duration _normalInterval = Duration(minutes: 30);
  static const Duration _maxRetryInterval = Duration(minutes: 15);
  static const int _maxConsecutiveFailures = 3;

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

  /// 🔥 V2.0: 스마트 타이머 시스템
  Stream<CoinGeckoGlobalDataDto> _createGlobalDataStream() {
    // 기존 Timer/Controller 정리
    _ensureCleanState();
    
    // 새로운 Controller 생성
    _globalDataController = StreamController<CoinGeckoGlobalDataDto>.broadcast();

    // 첫 호출
    _fetchGlobalData();

    // 🚀 V2.0: 적응형 타이머 시작
    _scheduleNextFetch();

    // 스트림 취소 시 정리
    _globalDataController!.onCancel = () {
      debugPrint('MarketMoodRemoteDataSource: Stream cancelled, cleaning resources');
      _cleanupCurrentStream();
    };

    return _globalDataController!.stream;
  }

  /// 🎯 V2.0: 스마트 스케줄링 (실패 횟수에 따른 적응)
  void _scheduleNextFetch() {
    if (_disposed || _isPaused) return;

    Duration interval;
    
    if (_consecutiveFailures == 0) {
      // 정상 상태: 30분 주기
      interval = _normalInterval;
    } else if (_consecutiveFailures <= _maxConsecutiveFailures) {
      // 실패 시: 5분 → 10분 → 15분 (점진적 증가)
      final retryMinutes = (_consecutiveFailures * 5).clamp(5, 15);
      interval = Duration(minutes: retryMinutes);
    } else {
      // 과도한 실패: 15분 고정
      interval = _maxRetryInterval;
    }

    debugPrint('MarketMoodRemoteDataSource: Next fetch in ${interval.inMinutes}m (failures: $_consecutiveFailures)');
    
    _globalDataTimer = Timer(interval, () {
      if (!_disposed && !_isPaused) {
        _fetchGlobalData();
      }
    });
  }

  /// 🎯 V2.0: API 호출 및 스마트 에러 처리
  Future<void> _fetchGlobalData() async {
    if (_disposed || _globalDataController == null || _globalDataController!.isClosed) {
      return;
    }

    try {
      final responseDto = await _apiClient.getGlobalMarketData();
      final dataDto = responseDto.data;
      
      if (!_globalDataController!.isClosed) {
        _globalDataController!.add(dataDto);
        
        // 🔥 V2.0: 성공 시 상태 초기화
        _consecutiveFailures = 0;
        _lastSuccessTime = DateTime.now();
        
        log.d('📊 글로벌 마켓 데이터 수신 성공: ${dataDto.totalVolumeUsd.toStringAsFixed(0)}B USD');
      }
    } catch (e, st) {
      // 🔥 V2.0: 실패 시 카운터 증가
      _consecutiveFailures++;
      
      if (!_globalDataController!.isClosed) {
        _globalDataController!.addError(e, st);
          // ignore: unnecessary_brace_in_string_interps
        log.e('❌ 글로벌 마켓 데이터 조회 실패 (${_consecutiveFailures}회): $e');
      }
    }
    
    // 🎯 V2.0: 다음 호출 스케줄링
    _scheduleNextFetch();
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

  /// 🎯 V2.0: 앱 상태 관리 (백그라운드 시 타이머 정지)
  void pauseTimer() {
    if (_isPaused) return;
    
    _isPaused = true;
    _globalDataTimer?.cancel();
    _globalDataTimer = null;
    
    debugPrint('MarketMoodRemoteDataSource: Timer paused');
  }

  /// 🎯 V2.0: 앱 포그라운드 복귀 시 타이머 재시작
  void resumeTimer() {
    if (!_isPaused || _disposed) return;
    
    _isPaused = false;
    
    // 마지막 성공 시점 확인
    if (_lastSuccessTime != null) {
      final timeSinceLastSuccess = DateTime.now().difference(_lastSuccessTime!);
      
      if (timeSinceLastSuccess > _normalInterval) {
        // 30분 이상 경과 → 즉시 호출
        debugPrint('MarketMoodRemoteDataSource: Immediate fetch after ${timeSinceLastSuccess.inMinutes}m');
        _fetchGlobalData();
      } else {
        // 아직 시간 남음 → 남은 시간 후 호출
        final remainingTime = _normalInterval - timeSinceLastSuccess;
        debugPrint('MarketMoodRemoteDataSource: Resume timer in ${remainingTime.inMinutes}m');
        _globalDataTimer = Timer(remainingTime, () => _fetchGlobalData());
      }
    } else {
      // 아직 성공한 적 없음 → 즉시 호출
      _fetchGlobalData();
    }
  }

  /// 🎯 V2.0: 상태 조회 (디버깅용)
  Map<String, dynamic> getStatus() {
    return {
      'isActive': _currentStream != null,
      'isPaused': _isPaused,
      'consecutiveFailures': _consecutiveFailures,
      'lastSuccessTime': _lastSuccessTime?.toIso8601String(),
      'disposed': _disposed,
    };
  }

  /// 🧹 리소스 정리 (V2.0 강화)
  void dispose() {
    if (_disposed) return;
    
    debugPrint('MarketMoodRemoteDataSource: dispose() called');
    _disposed = true;
    
    // 모든 리소스 정리
    _ensureCleanState();
    _currentStream = null;
    
    // V2.0: 상태 초기화
    _consecutiveFailures = 0;
    _lastSuccessTime = null;
    _isPaused = false;
    
    log.d('🧹 MarketMoodRemoteDataSource 정리 완료');
  }
}