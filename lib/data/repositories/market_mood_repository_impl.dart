// lib/data/repositories/market_mood_repository_impl.dart
// 🏗️ Data Layer: Repository 구현체 (Domain 인터페이스 완전 매칭)

import 'dart:async';
import 'package:rxdart/rxdart.dart';
import '../../core/utils/logger.dart';
import '../../domain/entities/market_mood.dart';
import '../../domain/repositories/market_mood_repository.dart';
import '../datasources/market_mood_local_ds.dart';
import '../datasources/market_mood_remote_ds.dart';
import '../models/market_mood_dto.dart';

/// 🏗️ 마켓무드 Repository 구현체
/// Remote + Local DataSource를 통합하여 Domain Entity로 변환하여 제공
class MarketMoodRepositoryImpl implements MarketMoodRepository {
  final MarketMoodRemoteDataSource _remoteDataSource;
  final MarketMoodLocalDataSource _localDataSource;

  // [리팩토링] 수동 스트림 관리가 필요 없으므로 변수 삭제
  // StreamController<MarketMoodData>? _marketDataController;
  // StreamSubscription? _remoteSubscription;

  MarketMoodRepositoryImpl(this._remoteDataSource, this._localDataSource);

  // ═══════════════════════════════════════════════════════════
  // 🌐 원격 데이터 (CoinGecko API)
  // ═══════════════════════════════════════════════════════════

  @override
  Stream<MarketMoodData> getMarketDataStream() {
    // [리팩토링] listen-add 대신, stream 연산자를 사용한 선언적 방식으로 변경
    return _remoteDataSource
        .getGlobalMarketDataStream()
        .doOnData((globalDataDto) async {
          try {
            final volumeDto = TimestampedVolume(
              timestamp: DateTime.fromMillisecondsSinceEpoch(globalDataDto.updatedAt * 1000),
              volumeUsd: globalDataDto.totalVolumeUsd,
            );
            await _localDataSource.addVolumeData(volumeDto);
            log.d('📊 스트림 데이터 로컬 저장 완료');
          } catch (e, st) {
            log.e('📊 스트림 데이터 로컬 저장 실패', e, st);
          }
        })
        .map((globalDataDto) {
          log.d('📊 DTO -> Entity 변환 완료');
          return MarketMoodData(
            totalMarketCapUsd: globalDataDto.totalMarketCapUsd,
            totalVolumeUsd: globalDataDto.totalVolumeUsd,
            btcDominance: globalDataDto.btcDominance,
            marketCapChange24h: globalDataDto.marketCapChangePercentage24hUsd,
            updatedAt: DateTime.fromMillisecondsSinceEpoch(globalDataDto.updatedAt * 1000),
          );
        });
  }

  @override
  Future<MarketMoodData?> getCurrentMarketData() async {
    try {
      // [수정] remoteDataSource는 이제 DTO를 반환
      final dataDto = await _remoteDataSource.getGlobalMarketData();
      
      final marketData = MarketMoodData(
        totalMarketCapUsd: dataDto.totalMarketCapUsd,
        totalVolumeUsd: dataDto.totalVolumeUsd,
        btcDominance: dataDto.btcDominance,
        marketCapChange24h: dataDto.marketCapChangePercentage24hUsd,
        updatedAt: DateTime.fromMillisecondsSinceEpoch(dataDto.updatedAt * 1000),
      );
      
      log.d('📊 현재 마켓 데이터 조회 성공');
      return marketData;
    } catch (e, st) {
      log.e('📊 현재 마켓 데이터 조회 실패', e, st);
      return null;
    }
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
    } catch (e, st) {
      log.e('💱 환율 조회 실패, 기본값 사용', e, st);
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
    } catch (e, st) {
      log.e('💱 환율 새로고침 실패', e, st);
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
    } catch (e, st) {
      log.e('📈 볼륨 데이터 추가 실패', e, st);
      rethrow;
    }
  }

  @override
  Future<VolumeData?> getVolumeNMinutesAgo(int minutes) async {
    try {
      final volumeDto = await _localDataSource.getVolumeNMinutesAgo(minutes);
      return volumeDto?.toEntity();
    } catch (e, st) {
      log.e('📈 $minutes분 전 볼륨 조회 실패', e, st);
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
    log.i('🧹 MarketMoodRepository 리소스 정리 완료');
  }
}