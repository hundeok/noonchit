// lib/data/repositories/market_mood_repository_impl.dart
// 🏗️ Data Layer: Repository 구현체 (API Fallback 추가)

import 'dart:async';
import 'package:rxdart/rxdart.dart';
import '../../core/utils/logger.dart';
import '../../domain/entities/market_mood.dart';
import '../../domain/repositories/market_mood_repository.dart';
import '../datasources/market_mood_local_ds.dart';
import '../datasources/market_mood_remote_ds.dart';
import '../models/market_mood_dto.dart';

/// 🏗️ 마켓무드 Repository 구현체 (API Fallback 강화)
/// Remote + Local DataSource를 통합하여 Domain Entity로 변환하여 제공
class MarketMoodRepositoryImpl implements MarketMoodRepository {
  final MarketMoodRemoteDataSource _remoteDataSource;
  final MarketMoodLocalDataSource _localDataSource;

  // 🔧 Fallback을 위한 캐시된 데이터
  MarketMoodData? _lastSuccessfulData;
  DateTime? _lastSuccessfulUpdate;
  static const Duration _cacheValidDuration = Duration(hours: 2);

  MarketMoodRepositoryImpl(this._remoteDataSource, this._localDataSource);

  // ═══════════════════════════════════════════════════════════
  // 🌐 원격 데이터 (CoinGecko API) - Fallback 강화
  // ═══════════════════════════════════════════════════════════

  @override
  Stream<MarketMoodData> getMarketDataStream() {
    return _remoteDataSource
        .getGlobalMarketDataStream()
        .doOnData((globalDataDto) async {
          try {
            // 🔧 성공한 데이터 캐시
            final marketData = _convertDtoToEntity(globalDataDto);
            _lastSuccessfulData = marketData;
            _lastSuccessfulUpdate = DateTime.now();
            
            // 로컬 저장
            final volumeDto = TimestampedVolume(
              timestamp: DateTime.fromMillisecondsSinceEpoch(globalDataDto.updatedAt * 1000),
              volumeUsd: globalDataDto.totalVolumeUsd,
            );
            await _localDataSource.addVolumeData(volumeDto);
            log.d('📊 스트림 데이터 로컬 저장 완료');
          } catch (e) {
            log.e('📊 스트림 데이터 로컬 저장 실패: $e');
          }
        })
        .map(_convertDtoToEntity)
        .onErrorResume((error, stackTrace) {
          log.w('📊 API 스트림 오류, Fallback 시도: $error');
          return _createFallbackStream();
        });
  }

  /// 🔧 Fallback 스트림 생성
  Stream<MarketMoodData> _createFallbackStream() {
    // 1. 캐시된 데이터가 유효하면 사용
    if (_isCacheValid()) {
      log.i('📊 캐시된 데이터 사용 ($_lastSuccessfulUpdate)');
      return Stream.value(_lastSuccessfulData!);
    }
    
    // 2. 로컬 데이터 기반으로 추정값 생성
    return _createEstimatedDataStream();
  }

  /// 🔧 추정 데이터 스트림 생성
  Stream<MarketMoodData> _createEstimatedDataStream() async* {
    try {
      // 최근 볼륨 데이터 조회
      final recent30min = await _localDataSource.getVolumeNMinutesAgo(30);
      final recent1hour = await _localDataSource.getVolumeNMinutesAgo(60);
      final recent2hour = await _localDataSource.getVolumeNMinutesAgo(120);
      
      if (recent30min != null || recent1hour != null || recent2hour != null) {
        // 가장 최근 데이터 사용
        final recentVolume = recent30min?.volumeUsd ?? 
                           recent1hour?.volumeUsd ?? 
                           recent2hour?.volumeUsd ?? 
                           50e9; // 기본값
        
        log.i('📊 로컬 데이터 기반 추정값 생성: ${recentVolume.toStringAsFixed(0)}B USD');
        
        yield MarketMoodData(
          totalMarketCapUsd: recentVolume * 20, // 추정 시가총액 (볼륨의 20배)
          totalVolumeUsd: recentVolume,
          btcDominance: 45.0, // 기본값
          marketCapChange24h: 0.0, // 변동률 불명
          updatedAt: DateTime.now(),
        );
      } else {
        // 완전 기본값
        log.w('📊 로컬 데이터 없음, 기본값 사용');
        yield _createDefaultData();
      }
    } catch (e) {
      log.e('📊 추정 데이터 생성 실패, 기본값 사용: $e');
      yield _createDefaultData();
    }
  }

  @override
  Future<MarketMoodData?> getCurrentMarketData() async {
    try {
      // 1차: API 시도
      final dataDto = await _remoteDataSource.getGlobalMarketData();
      final marketData = _convertDtoToEntity(dataDto);
      
      // 성공 시 캐시 업데이트
      _lastSuccessfulData = marketData;
      _lastSuccessfulUpdate = DateTime.now();
      
      log.d('📊 현재 마켓 데이터 조회 성공');
      return marketData;
    } catch (e) {
      log.w('📊 API 조회 실패, Fallback 시도: $e');
      
      // 2차: 캐시된 데이터 시도
      if (_isCacheValid()) {
        log.i('📊 캐시된 데이터 반환');
        return _lastSuccessfulData;
      }
      
      // 3차: 로컬 데이터 기반 추정
      try {
        final estimated = await _createEstimatedData();
        log.i('📊 추정 데이터 반환');
        return estimated;
      } catch (estimateError) {
        log.e('📊 추정 데이터 생성 실패: $estimateError');
        return null;
      }
    }
  }

  // ═══════════════════════════════════════════════════════════
  // 🔧 Fallback 헬퍼 메서드들
  // ═══════════════════════════════════════════════════════════

  /// DTO → Entity 변환
  MarketMoodData _convertDtoToEntity(CoinGeckoGlobalDataDto dto) {
    return MarketMoodData(
      totalMarketCapUsd: dto.totalMarketCapUsd,
      totalVolumeUsd: dto.totalVolumeUsd,
      btcDominance: dto.btcDominance,
      marketCapChange24h: dto.marketCapChangePercentage24hUsd,
      updatedAt: DateTime.fromMillisecondsSinceEpoch(dto.updatedAt * 1000),
    );
  }

  /// 캐시 유효성 검사
  bool _isCacheValid() {
    return _lastSuccessfulData != null &&
           _lastSuccessfulUpdate != null &&
           DateTime.now().difference(_lastSuccessfulUpdate!) < _cacheValidDuration;
  }

  /// 추정 데이터 생성 (Future 버전)
  Future<MarketMoodData> _createEstimatedData() async {
    final recent30min = await _localDataSource.getVolumeNMinutesAgo(30);
    final recent1hour = await _localDataSource.getVolumeNMinutesAgo(60);
    final recent2hour = await _localDataSource.getVolumeNMinutesAgo(120);
    
    final recentVolume = recent30min?.volumeUsd ?? 
                       recent1hour?.volumeUsd ?? 
                       recent2hour?.volumeUsd ?? 
                       50e9;
    
    return MarketMoodData(
      totalMarketCapUsd: recentVolume * 20,
      totalVolumeUsd: recentVolume,
      btcDominance: 45.0,
      marketCapChange24h: 0.0,
      updatedAt: DateTime.now(),
    );
  }

  /// 기본 데이터 생성
  MarketMoodData _createDefaultData() {
    return MarketMoodData(
      totalMarketCapUsd: 1000e9, // 1조 달러
      totalVolumeUsd: 50e9,      // 500억 달러
      btcDominance: 45.0,
      marketCapChange24h: 0.0,
      updatedAt: DateTime.now(),
    );
  }

  @override
  Future<double> getExchangeRate() async {
    try {
      final cachedRate = await _localDataSource.getCachedExchangeRate();
      if (cachedRate != null) {
        return cachedRate;
      }
      final rate = await _remoteDataSource.getUsdToKrwRate();
      await _localDataSource.cacheExchangeRate(rate);
      return rate;
    } catch (e) {
      log.e('💱 환율 조회 실패, 기본값 사용: $e');
      return 1400.0;
    }
  }

  @override
  Future<void> refreshExchangeRate() async {
    try {
      log.i('💱 환율 수동 새로고침 시작');
      final rate = await _remoteDataSource.getUsdToKrwRate();
      await _localDataSource.cacheExchangeRate(rate);
      log.i('💱 환율 새로고침 완료: $rate KRW');
    } catch (e) {
      log.e('💱 환율 새로고침 실패: $e');
      rethrow;
    }
  }

  // ═══════════════════════════════════════════════════════════
  // 💾 로컬 데이터 (볼륨 버퍼) - Domain Entity 사용
  // ═══════════════════════════════════════════════════════════

  @override
  Future<void> addVolumeData(VolumeData volume) async {
    try {
      final volumeDto = TimestampedVolume.fromEntity(volume);
      await _localDataSource.addVolumeData(volumeDto);
    } catch (e) {
      log.e('📈 볼륨 데이터 추가 실패: $e');
      rethrow;
    }
  }

  @override
  Future<VolumeData?> getVolumeNMinutesAgo(int minutes) async {
    try {
      final volumeDto = await _localDataSource.getVolumeNMinutesAgo(minutes);
      return volumeDto?.toEntity();
    } catch (e) {
      log.e('📈 $minutes분 전 볼륨 조회 실패: $e');
      return null;
    }
  }

  @override
  Future<double?> getAverageVolume(int days) async {
    return _localDataSource.getAverageVolume(days);
  }

  @override
  Future<int> getCollectedDataCount() async {
    return _localDataSource.getCollectedDataCount();
  }

  @override
  DateTime getAppStartTime() {
    return _localDataSource.getAppStartTime();
  }

  // ═══════════════════════════════════════════════════════════
  // 🧹 관리 기능
  // ═══════════════════════════════════════════════════════════

  @override
  Future<void> syncMissingData() async {
    await _localDataSource.checkAndFillMissingSlots();
  }

  @override
  Future<void> clearOldData() async {
    await _localDataSource.trimOldData(keepCount: 336); // 7일 * 48슬롯/일
  }

  @override
  Future<Map<String, dynamic>> getSystemHealth() async {
    final localInfo = _localDataSource.getDebugInfo();
    final remoteHealth = await _remoteDataSource.checkApiHealth();
    final dataCount = await getCollectedDataCount();
    final appStartTime = getAppStartTime();
    final elapsedMinutes = DateTime.now().difference(appStartTime).inMinutes;

    return {
      'status': 'healthy',
      'local_storage': localInfo,
      'remote_api': {'healthy': remoteHealth, 'status': remoteHealth ? 'ok' : 'error'},
      'data_count': dataCount,
      'app_start_time': appStartTime.toIso8601String(),
      'elapsed_minutes': elapsedMinutes,
      'last_check': DateTime.now().toIso8601String(),
      'fallback_cache': {
        'has_cache': _lastSuccessfulData != null,
        'cache_age_minutes': _lastSuccessfulUpdate != null 
            ? DateTime.now().difference(_lastSuccessfulUpdate!).inMinutes 
            : null,
        'cache_valid': _isCacheValid(),
      },
    };
  }

  @override
  Future<void> logCurrentStatus() async {
    final health = await getSystemHealth();
    _localDataSource.logStatus();
    log.i('📊 마켓무드 시스템 상태: $health');
  }

  // ═══════════════════════════════════════════════════════════
  // 🛠️ 개발/테스트용 기능
  // ═══════════════════════════════════════════════════════════

  @override
  Future<void> injectTestVolumeData(List<VolumeData> testData) async {
    if (testData.isEmpty) return;
    for (final volume in testData) {
      await addVolumeData(volume);
    }
  }

  // ═══════════════════════════════════════════════════════════
  // 🧹 리소스 정리
  // ═══════════════════════════════════════════════════════════

  @override
  Future<void> dispose() async {
    log.i('🧹 MarketMoodRepository 리소스 정리 시작');
    _remoteDataSource.dispose();
    await _localDataSource.dispose();
    
    // Fallback 캐시 정리
    _lastSuccessfulData = null;
    _lastSuccessfulUpdate = null;
    
    log.i('🧹 MarketMoodRepository 리소스 정리 완료');
  }
}