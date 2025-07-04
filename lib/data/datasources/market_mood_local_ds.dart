// lib/data/datasources/market_mood_local_ds.dart
// 💾 Data Layer: 로컬 데이터 소스 (Hive 기반, DI 패턴, Box 상태 체크 추가)

import 'package:hive_flutter/hive_flutter.dart';
import '../../core/services/hive_service.dart';
import '../../core/utils/logger.dart';
import '../models/market_mood_dto.dart'; // 🔥 TimestampedVolume이 여기 있음

/// 💾 마켓무드 로컬 데이터 소스
/// HiveService를 통한 볼륨 데이터 저장/조회, 환율 캐싱 (DI 패턴)
class MarketMoodLocalDataSource {
  final HiveService _hiveService;
  
  static const String _exchangeRateKey = 'exchange_rate';
  static const String _appStartTimeKey = 'app_start_time';

  MarketMoodLocalDataSource(this._hiveService);

  /// Volume Box 접근 (상태 체크 추가)
  Box<TimestampedVolume> get _volumeBox {
    final box = _hiveService.marketMoodVolumeBox;
    if (!box.isOpen) {
      throw StateError('Volume box is not open. Please ensure HiveService is properly initialized.');
    }
    return box;
  }
  
  /// Cache Box 접근 (상태 체크 추가)
  Box get _cacheBox {
    final box = _hiveService.marketMoodCacheBox;
    if (!box.isOpen) {
      throw StateError('Cache box is not open. Please ensure HiveService is properly initialized.');
    }
    return box;
  }

  // ═══════════════════════════════════════════════════════════
  // 📈 볼륨 데이터 관리 (안전한 Box 접근)
  // ═══════════════════════════════════════════════════════════

  /// 볼륨 데이터 추가 (30분 슬롯)
  Future<void> addVolumeData(TimestampedVolume volume) async {
    try {
      // Box 상태 체크는 getter에서 처리
      final box = _volumeBox;
      
      // 30분 단위로 정규화된 키 생성
      final slotKey = _getSlotKey(volume.timestamp);
      
      await box.put(slotKey, volume);
      log.d('📈 볼륨 데이터 저장: $slotKey -> ${volume.volumeUsd.toStringAsFixed(0)}B');
    } catch (e, st) {
      log.e('📈 볼륨 데이터 저장 실패', e, st);
      rethrow;
    }
  }

  /// N분 전 볼륨 데이터 조회
  Future<TimestampedVolume?> getVolumeNMinutesAgo(int minutes) async {
    try {
      final box = _volumeBox;
      final targetTime = DateTime.now().subtract(Duration(minutes: minutes));
      final slotKey = _getSlotKey(targetTime);
      
      final volume = box.get(slotKey);
      if (volume != null) {
        log.d('📈 $minutes분 전 볼륨 조회 성공: ${volume.volumeUsd.toStringAsFixed(0)}B');
      } else {
        log.d('📈 $minutes분 전 볼륨 데이터 없음');
      }
      
      return volume;
    } catch (e, st) {
      log.e('📈 $minutes분 전 볼륨 조회 실패', e, st);
      return null;
    }
  }

  /// 특정 기간의 평균 볼륨 계산
  Future<double?> getAverageVolume(int days) async {
    try {
      final box = _volumeBox;
      final now = DateTime.now();
      final cutoffTime = now.subtract(Duration(days: days));
      
      final volumes = box.values
          .where((volume) => volume.timestamp.isAfter(cutoffTime))
          .map((volume) => volume.volumeUsd)
          .toList();
      
      if (volumes.isEmpty) {
        log.d('📊 $days일 평균 볼륨: 데이터 없음');
        return null;
      }
      
      final average = volumes.reduce((a, b) => a + b) / volumes.length;
      log.d('📊 $days일 평균 볼륨: ${average.toStringAsFixed(0)}B (${volumes.length}개 데이터)');
      
      return average;
    } catch (e, st) {
      log.e('📊 $days일 평균 볼륨 계산 실패', e, st);
      return null;
    }
  }

  /// 수집된 데이터 개수 확인
  Future<int> getCollectedDataCount() async {
    try {
      final box = _volumeBox;
      final count = box.length;
      log.d('📊 총 데이터 개수: $count');
      return count;
    } catch (e, st) {
      log.e('📊 데이터 개수 조회 실패', e, st);
      return 0;
    }
  }

  /// 누락된 30분 슬롯 확인 및 보정
  Future<void> checkAndFillMissingSlots() async {
    try {
      final box = _volumeBox;
      final appStartTime = getAppStartTime();
      final now = DateTime.now();
      final totalMinutes = now.difference(appStartTime).inMinutes;
      final expectedSlots = (totalMinutes / 30).floor();
      
      log.i('🔄 슬롯 체크: 예상 $expectedSlots개, 실제 ${box.length}개');
      
      if (box.length < expectedSlots) {
        final missing = expectedSlots - box.length;
        log.w('⚠️ $missing개 슬롯 누락 감지');
        // 실제 보정 로직은 필요 시 구현
      }
    } catch (e, st) {
      log.e('🔄 슬롯 체크 실패', e, st);
    }
  }

  // ═══════════════════════════════════════════════════════════
  // 💱 환율 캐싱 (안전한 Box 접근)
  // ═══════════════════════════════════════════════════════════

  /// 환율 캐시 저장
  Future<void> cacheExchangeRate(double rate) async {
    try {
      final box = _cacheBox;
      await box.put(_exchangeRateKey, {
        'rate': rate,
        'timestamp': DateTime.now().millisecondsSinceEpoch,
      });
      log.d('💱 환율 캐시 저장: $rate KRW');
    } catch (e, st) {
      log.e('💱 환율 캐시 저장 실패', e, st);
      rethrow;
    }
  }

  /// 캐시된 환율 조회 (12시간 유효)
  Future<double?> getCachedExchangeRate() async {
    try {
      final box = _cacheBox;
      final cached = box.get(_exchangeRateKey);
      if (cached == null) return null;
      
      final timestamp = DateTime.fromMillisecondsSinceEpoch(cached['timestamp']);
      final rate = cached['rate'] as double;
      
      // 12시간 이내인지 확인 (Provider와 동일한 캐시 정책)
      if (DateTime.now().difference(timestamp).inHours < 12) {
        log.d('💱 캐시된 환율 사용: $rate KRW');
        return rate;
      } else {
        log.d('💱 캐시된 환율 만료');
        return null;
      }
    } catch (e, st) {
      log.e('💱 캐시된 환율 조회 실패', e, st);
      return null;
    }
  }

  // ═══════════════════════════════════════════════════════════
  // 🕰️ 시간 관리 (안전한 Box 접근)
  // ═══════════════════════════════════════════════════════════

  /// 앱 시작 시간 조회
  DateTime getAppStartTime() {
    try {
      final box = _cacheBox;
      final cached = box.get(_appStartTimeKey);
      if (cached != null) {
        return cached as DateTime;
      }
      
      // 최초 실행 시 현재 시간으로 설정
      final now = DateTime.now();
      box.put(_appStartTimeKey, now);
      log.i('🕰️ 앱 시작 시간 설정: ${now.toIso8601String()}');
      return now;
    } catch (e, st) {
      log.e('🕰️ 앱 시작 시간 조회 실패', e, st);
      return DateTime.now(); // fallback
    }
  }

  /// 30분 슬롯 키 생성 (정규화)
  String _getSlotKey(DateTime timestamp) {
    // 30분 단위로 정규화: 예) 14:23 -> 14:00, 14:47 -> 14:30
    final normalized = DateTime(
      timestamp.year,
      timestamp.month,
      timestamp.day,
      timestamp.hour,
      (timestamp.minute ~/ 30) * 30, // 30분 단위로 내림
    );
    
    return normalized.toIso8601String();
  }

  // ═══════════════════════════════════════════════════════════
  // 🔧 유틸리티 (안전한 Box 접근)
  // ═══════════════════════════════════════════════════════════

  /// 디버깅용 정보 반환
  Map<String, Object> getDebugInfo() {
    try {
      final volumeBox = _volumeBox;
      final cacheBox = _cacheBox;
      
      final volumeInfo = {
        'total_count': volumeBox.length,
        'box_open': volumeBox.isOpen,
        'first_entry': volumeBox.isNotEmpty 
            ? volumeBox.values.first.timestamp.toIso8601String() 
            : 'none',
        'last_entry': volumeBox.isNotEmpty 
            ? volumeBox.values.last.timestamp.toIso8601String() 
            : 'none',
      };
      
      final cacheInfo = {
        'cache_keys': cacheBox.keys.toList(),
        'app_start_time': getAppStartTime().toIso8601String(),
        'has_exchange_rate': cacheBox.containsKey(_exchangeRateKey),
        'box_open': cacheBox.isOpen,
      };

      return {
        'volume_storage': volumeInfo,
        'cache_storage': cacheInfo,
        'hive_service': 'injected',
        'status': 'healthy',
      };
    } catch (e) {
      return {
        'status': 'error',
        'error': e.toString(),
      };
    }
  }

  /// Box 상태 검증 (추가 안전장치)
  bool _isBoxesReady() {
    try {
      return _hiveService.marketMoodVolumeBox.isOpen && 
             _hiveService.marketMoodCacheBox.isOpen;
    } catch (e) {
      log.w('Box 상태 체크 실패: $e');
      return false;
    }
  }

  /// 상태 로깅 (Box 상태 포함)
  void logStatus() {
    try {
      final isReady = _isBoxesReady();
      final info = getDebugInfo();
      log.i('💾 MarketMoodLocalDataSource 상태 (Ready: $isReady): $info');
    } catch (e, st) {
      log.e('💾 상태 로깅 실패', e, st);
    }
  }

  /// 리소스 정리
  Future<void> dispose() async {
    try {
      // HiveService가 Box 관리하므로 여기서는 정리 안함
      log.i('🧹 MarketMoodLocalDataSource 정리 완료');
    } catch (e, st) {
      log.e('🧹 리소스 정리 중 오류 발생', e, st);
    }
  }

  /// 개발용: 모든 데이터 삭제 (안전한 Box 접근)
  Future<void> clearAllData() async {
    try {
      final volumeBox = _volumeBox;
      final cacheBox = _cacheBox;
      
      await volumeBox.clear();
      await cacheBox.clear();
      log.w('🗑️ 모든 로컬 데이터 삭제 완료');
    } catch (e, st) {
      log.e('🗑️ 데이터 삭제 실패', e, st);
      rethrow;
    }
  }

  /// 개발용: 최근 N개 데이터만 유지 (안전한 Box 접근)
  Future<void> trimOldData({int keepCount = 100}) async {
    try {
      final volumeBox = _volumeBox;
      if (volumeBox.length <= keepCount) return;

      final allEntries = volumeBox.values.toList()
        ..sort((a, b) => b.timestamp.compareTo(a.timestamp)); // 최신순

      final toKeep = allEntries.take(keepCount).toList();
      
      await volumeBox.clear();
      for (final volume in toKeep) {
        await addVolumeData(volume);
      }
      
      log.i('🧹 오래된 데이터 정리: ${allEntries.length} -> $keepCount개');
    } catch (e, st) {
      log.e('🧹 데이터 정리 실패', e, st);
      rethrow;
    }
  }
}