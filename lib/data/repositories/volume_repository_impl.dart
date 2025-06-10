import 'dart:async';
import 'package:flutter/foundation.dart';
import '../../../core/config/app_config.dart';
import '../../domain/entities/trade.dart';
import '../../domain/entities/volume.dart';
import '../../domain/repositories/volume_repository.dart';
import '../datasources/trade_remote_ds.dart';

/// ♻️ 100ms 배치 시스템을 적용하여 최적화된 볼륨 Repository
class VolumeRepositoryImpl implements VolumeRepository {
  final TradeRemoteDataSource _remote;

  // 📊 볼륨 상태 관리 (실시간 누적)
  final Map<String, Map<String, double>> _volumeByTimeFrame = {};
  final Set<String> _seenIds = {};
  
  // 🎯 볼륨 스트림 컨트롤러들 (시간대별)
  final Map<String, StreamController<Map<String, double>>> _volumeControllers = {};
  
  // 🕐 시간대별 리셋 시간 추적
  final Map<String, DateTime> _timeFrameStartTimes = {};
  
  // 🔥 핵심: 브로드캐스트 스트림 관리
  Stream<Trade>? _volumeStream;
  StreamSubscription<Trade>? _volumeSubscription;
  
  // 🆕 배치 처리를 위한 타이머
  Timer? _batchUpdateTimer;

  // 성능 최적화 상수
  static const int _maxCacheSize = 1000;
  // 🆕 배치 업데이트 주기 (100ms)
  static const Duration _batchUpdateInterval = Duration(milliseconds: 100);

  VolumeRepositoryImpl(this._remote) {
    _initializeVolumeTracking();
    
    // 볼륨 리셋 체크 타이머 (15초마다)
    Timer.periodic(const Duration(seconds:15), (_) => _checkVolumeResets());
  }

  // ═══════════════════════════════════════════════════════════════════════════════
  // VOLUME 전용 메서드들
  // ═══════════════════════════════════════════════════════════════════════════════

  /// 볼륨 추적 초기화
  void _initializeVolumeTracking() {
    final now = DateTime.now();
    
    for (final timeFrameMinutes in AppConfig.timeFrames) {
      final timeFrameStr = '${timeFrameMinutes}m';
      
      _volumeByTimeFrame[timeFrameStr] = <String, double>{};
      _volumeControllers[timeFrameStr] = StreamController<Map<String, double>>.broadcast();
      _timeFrameStartTimes[timeFrameStr] = now;
    }
    
    if (kDebugMode) {
      debugPrint('🎯 Volume tracking initialized for ${AppConfig.timeFrames.length} timeframes');
    }
  }

  /// 브로드캐스트 스트림 초기화 (TradeRepository와 독립적)
  void _initializeVolumeStream(List<String> markets) {
    if (_volumeStream != null) return;
    
    debugPrint('VolumeRepositoryImpl: initializing volume stream for ${markets.length} markets');
    
    _volumeStream = _remote.watch(markets).asBroadcastStream();
    
    _volumeSubscription = _volumeStream!.listen(
      _processRawTradeForVolume,
      onError: (error, stackTrace) {
        debugPrint('Volume stream error: $error');
        debugPrint('StackTrace: $stackTrace');
      },
      onDone: () {
        debugPrint('Volume stream done');
      },
    );
  }

  /// Map<String, double>을 Volume 리스트로 변환 (정렬 포함)
  List<Volume> _createVolumeList(Map<String, double> volumeMap, String timeFrame) {
    final now = DateTime.now();
    final startTime = _timeFrameStartTimes[timeFrame] ?? now;
    
    final volumeList = volumeMap.entries
        .where((entry) => entry.value > 0)
        .map((entry) => Volume(
              market: entry.key,
              totalVolume: entry.value,
              lastUpdatedMs: now.millisecondsSinceEpoch,
              timeFrame: timeFrame,
              timeFrameStartMs: startTime.millisecondsSinceEpoch,
            ))
        .toList();

    volumeList.sort((a, b) => b.totalVolume.compareTo(a.totalVolume));
    
    return volumeList;
  }

  @override
  Stream<List<Volume>> watchVolumeByTimeFrame(String timeFrame, List<String> markets) {
    debugPrint('VolumeRepositoryImpl: watchVolumeByTimeFrame() - timeFrame: $timeFrame');
    
    _initializeVolumeStream(markets);
    
    return _volumeControllers[timeFrame]?.stream
        .map((volumeMap) => _createVolumeList(volumeMap, timeFrame))
        ?? const Stream.empty();
  }

  /// 📥 원시 거래 데이터를 볼륨으로 누적하고 업데이트 예약
  void _processRawTradeForVolume(Trade trade) {
    try {
      final key = '${trade.market}/${trade.sequentialId}';
      if (!_seenIds.add(key)) return;

      if (_seenIds.length > _maxCacheSize) {
        final removeCount = (_seenIds.length / 4).ceil();
        final toRemove = _seenIds.take(removeCount).toList();
        _seenIds.removeAll(toRemove);
      }

      // ♻️ 볼륨 누적 후, 즉시 업데이트 대신 '업데이트 예약'
      _accumulateVolumeAndScheduleUpdate(trade);
      
    } catch (e, stackTrace) {
      debugPrint('_processRawTradeForVolume error: $e');
      debugPrint('StackTrace: $stackTrace');
    }
  }

  /// ♻️ 거래 데이터를 받아 볼륨 누적 후, 배치 업데이트 예약
  void _accumulateVolumeAndScheduleUpdate(Trade trade) {
    final market = trade.market;
    final totalAmount = trade.total;
    
    for (final timeFrameStr in _volumeByTimeFrame.keys) {
      final currentVolume = _volumeByTimeFrame[timeFrameStr]![market] ?? 0.0;
      _volumeByTimeFrame[timeFrameStr]![market] = currentVolume + totalAmount;
    }
    
    // ♻️ 즉시 UI 업데이트 대신, 배치 업데이트 예약
    _scheduleBatchUpdate();
  }

  /// 🆕 배치 업데이트 스케줄링
  void _scheduleBatchUpdate() {
    // 이미 예약된 타이머가 있으면 취소 (디바운싱)
    _batchUpdateTimer?.cancel();
    
    // 지정된 시간(100ms) 후에 업데이트 실행
    _batchUpdateTimer = Timer(_batchUpdateInterval, _performBatchUpdate);
  }

  /// ♻️ 모든 시간대의 볼륨 스트림을 '배치' 업데이트 (타이머에 의해 호출됨)
  void _performBatchUpdate() {
    try {
      for (final entry in _volumeByTimeFrame.entries) {
        final timeFrameStr = entry.key;
        final volumeMap = Map<String, double>.from(entry.value);
        
        final controller = _volumeControllers[timeFrameStr];
        if (controller != null && !controller.isClosed) {
          controller.add(volumeMap);
        }
      }
      
      if (kDebugMode) {
        final totalMarkets = _volumeByTimeFrame.values.isNotEmpty 
            ? _volumeByTimeFrame.values.first.length 
            : 0;
        if (totalMarkets > 0) {
          debugPrint('⚡⚡ Volume batch update: $totalMarkets markets (every 100ms)');
        }
      }
    } catch (e, stackTrace) {
      debugPrint('_performBatchUpdate error: $e');
      debugPrint('StackTrace: $stackTrace');
    }
  }

  /// 시간대별 리셋 체크 (15초마다 호출)
  void _checkVolumeResets() {
    final now = DateTime.now();
    
    for (final timeFrameMinutes in AppConfig.timeFrames) {
      final timeFrameStr = '${timeFrameMinutes}m';
      final startTime = _timeFrameStartTimes[timeFrameStr];
      
      if (startTime != null) {
        final elapsed = now.difference(startTime).inMinutes;
        
        if (elapsed >= timeFrameMinutes) {
          _resetTimeFrame(timeFrameStr);
          _timeFrameStartTimes[timeFrameStr] = now;
          
          if (kDebugMode) {
            debugPrint('🔄 Volume reset: $timeFrameStr (after ${elapsed}min)');
          }
        }
      }
    }
  }

  /// 특정 시간대 리셋
  void _resetTimeFrame(String timeFrameStr) {
    _volumeByTimeFrame[timeFrameStr]?.clear();
    // ♻️ 리셋 후에도 즉시 UI에 반영되도록 배치 업데이트 함수 직접 호출
    _performBatchUpdate(); 
  }

  @override
  void resetTimeFrame(String timeFrame) {
    debugPrint('🔄 Manual reset timeFrame: $timeFrame');
    _resetTimeFrame(timeFrame);
  }

  @override
  void resetAllTimeFrames() {
    debugPrint('🔄 Manual reset all timeFrames');
    for (final timeFrameStr in _volumeByTimeFrame.keys) {
      _volumeByTimeFrame[timeFrameStr]?.clear();
    }
    // ♻️ 리셋 후에도 즉시 UI에 반영되도록 배치 업데이트 함수 직접 호출
    _performBatchUpdate();
  }

  @override
  DateTime? getNextResetTime(String timeFrame) {
    final startTime = _timeFrameStartTimes[timeFrame];
    if (startTime == null) return null;
    
    final timeFrameMinutes = int.tryParse(timeFrame.replaceAll('m', ''));
    if (timeFrameMinutes == null) return null;
    
    return startTime.add(Duration(minutes: timeFrameMinutes));
  }

  @override
  List<String> getActiveTimeFrames() {
    return AppConfig.timeFrames.map((tf) => '${tf}m').toList();
  }

  @override
  bool isTimeFrameActive(String timeFrame) {
    return getActiveTimeFrames().contains(timeFrame);
  }

  @override
  Future<void> dispose() async {
    debugPrint('VolumeRepositoryImpl: dispose() called');
    
    // 🆕 배치 타이머 정리
    _batchUpdateTimer?.cancel();
    
    await _volumeSubscription?.cancel();
    _volumeStream = null;
    
    for (final controller in _volumeControllers.values) {
      await controller.close();
    }
    
    debugPrint('VolumeRepositoryImpl: dispose completed');
  }
}