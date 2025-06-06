// lib/data/repositories/volume_repository_impl.dart

import 'dart:async';
import 'package:flutter/foundation.dart';
import '../../../core/config/app_config.dart';
import '../../domain/entities/trade.dart';
import '../../domain/entities/volume.dart'; // 🆕 Volume 엔티티 import
import '../../domain/repositories/volume_repository.dart';
import '../datasources/trade_remote_ds.dart';

/// 볼륨 전용 Repository - 브로드캐스트 스트림으로 TradeRemoteDataSource 공유
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
  
  // 성능 최적화 상수
  static const int _maxCacheSize = 1000;

  VolumeRepositoryImpl(this._remote) {
    // 🆕 볼륨 관련 초기화
    _initializeVolumeTracking();
    
    // 🆕 볼륨 리셋 체크 타이머 (15초마다)
    Timer.periodic(const Duration(seconds:15), (_) => _checkVolumeResets());
  }

  // ═══════════════════════════════════════════════════════════════════════════════
  // 🆕 VOLUME 전용 메서드들
  // ═══════════════════════════════════════════════════════════════════════════════

  /// 볼륨 추적 초기화
  void _initializeVolumeTracking() {
    final now = DateTime.now();
    
    for (final timeFrameMinutes in AppConfig.timeFrames) {
      final timeFrameStr = '${timeFrameMinutes}m';
      
      // 빈 볼륨 맵 초기화
      _volumeByTimeFrame[timeFrameStr] = <String, double>{};
      
      // 스트림 컨트롤러 생성
      _volumeControllers[timeFrameStr] = StreamController<Map<String, double>>.broadcast();
      
      // 시작 시간 설정
      _timeFrameStartTimes[timeFrameStr] = now;
    }
    
    if (kDebugMode) {
      debugPrint('🎯 Volume tracking initialized for ${AppConfig.timeFrames.length} timeframes');
    }
  }

  /// 🔥 핵심: 브로드캐스트 스트림 초기화 (TradeRepository와 독립적)
  void _initializeVolumeStream(List<String> markets) {
    if (_volumeStream != null) return; // 이미 초기화됨
    
    debugPrint('VolumeRepositoryImpl: initializing volume stream for ${markets.length} markets');
    
    // 🎯 TradeRemoteDataSource 브로드캐스트 스트림 구독
    _volumeStream = _remote.watch(markets).asBroadcastStream();
    
    // 🎯 볼륨 전용 구독 (원시 데이터 바로 처리)
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
        .where((entry) => entry.value > 0) // 볼륨이 0보다 큰 것만
        .map((entry) => Volume(
              market: entry.key,
              totalVolume: entry.value,
              lastUpdatedMs: now.millisecondsSinceEpoch,
              timeFrame: timeFrame,
              timeFrameStartMs: startTime.millisecondsSinceEpoch,
            ))
        .toList();

    // 볼륨 순으로 정렬 (높은 순)
    volumeList.sort((a, b) => b.totalVolume.compareTo(a.totalVolume));
    
    return volumeList;
  }

  @override
  Stream<List<Volume>> watchVolumeByTimeFrame(String timeFrame, List<String> markets) {
    debugPrint('VolumeRepositoryImpl: watchVolumeByTimeFrame() - timeFrame: $timeFrame');
    
    // 볼륨 스트림 초기화
    _initializeVolumeStream(markets);
    
    // 해당 시간대의 볼륨 스트림 반환 (Volume 리스트로)
    return _volumeControllers[timeFrame]?.stream
        .map((volumeMap) => _createVolumeList(volumeMap, timeFrame))
        ?? const Stream.empty();
  }

  /// 📥 원시 거래 데이터를 볼륨으로 즉시 누적 (배치 없음!)
  void _processRawTradeForVolume(Trade trade) {
    try {
      final key = '${trade.market}/${trade.sequentialId}';

      // 중복 처리 방지
      if (!_seenIds.add(key)) return;

      // 메모리 관리
      if (_seenIds.length > _maxCacheSize) {
        final removeCount = (_seenIds.length / 4).ceil();
        final toRemove = _seenIds.take(removeCount).toList();
        _seenIds.removeAll(toRemove);
      }

      // 🆕 볼륨 즉시 누적 (배치 없이 실시간!)
      _accumulateVolumeInstantly(trade);
      
    } catch (e, stackTrace) {
      debugPrint('_processRawTradeForVolume error: $e');
      debugPrint('StackTrace: $stackTrace');
    }
  }

  /// 거래 데이터를 받을 때마다 볼륨 즉시 누적 (실시간!)
  void _accumulateVolumeInstantly(Trade trade) {
    final market = trade.market;
    final totalAmount = trade.total;
    
    // 모든 시간대에 동시 누적
    for (final timeFrameStr in _volumeByTimeFrame.keys) {
      final currentVolume = _volumeByTimeFrame[timeFrameStr]![market] ?? 0.0;
      _volumeByTimeFrame[timeFrameStr]![market] = currentVolume + totalAmount;
    }
    
    // 🚀 즉시 UI 업데이트 (배치 없음!)
    _updateVolumeStreamsInstantly();
  }

  /// 모든 시간대의 볼륨 스트림 즉시 업데이트 (실시간!)
  void _updateVolumeStreamsInstantly() {
    try {
      for (final entry in _volumeByTimeFrame.entries) {
        final timeFrameStr = entry.key;
        final volumeMap = Map<String, double>.from(entry.value);
        
        // 해당 시간대 스트림에 데이터 즉시 전송
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
          debugPrint('⚡ Volume streams updated instantly: $totalMarkets markets');
        }
      }
    } catch (e, stackTrace) {
      debugPrint('_updateVolumeStreamsInstantly error: $e');
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
        
        // 해당 시간대가 지나면 리셋
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
    _updateVolumeStreamsInstantly(); // 리셋 후 빈 데이터 즉시 전송
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
    _updateVolumeStreamsInstantly();
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
    
    // 볼륨 구독 정리
    await _volumeSubscription?.cancel();
    _volumeStream = null;
    
    // 볼륨 컨트롤러들 정리
    for (final controller in _volumeControllers.values) {
      await controller.close();
    }
    
    debugPrint('VolumeRepositoryImpl: dispose completed');
  }
}