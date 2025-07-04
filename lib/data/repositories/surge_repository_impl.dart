// lib/data/repositories/surge_repository_impl.dart

import 'dart:async';
import 'package:flutter/foundation.dart';
import '../../core/config/app_config.dart';
import '../../domain/entities/trade.dart';
import '../../domain/entities/surge.dart';
import '../../domain/repositories/surge_repository.dart';
import '../../domain/repositories/trade_repository.dart';

/// 🚀 급등/급락 데이터 클래스
class SurgeData {
  double? basePrice;      // 시간대 시작 가격
  double currentPrice = 0; // 현재 가격 (계속 업데이트)
  double changePercent = 0; // 변동률 (계속 재계산)

  SurgeData({this.basePrice, this.currentPrice = 0, this.changePercent = 0});

  void updatePrice(double price) {
    basePrice ??= price;
    currentPrice = price;
    changePercent = basePrice != null && basePrice! > 0 
        ? ((currentPrice - basePrice!) / basePrice!) * 100 
        : 0.0;
  }

  void reset(double price) {
    basePrice = price;
    currentPrice = price;
    changePercent = 0.0;
  }
}

/// 🏗️ SurgeRepositoryImpl - 데이터 처리 담당
class SurgeRepositoryImpl implements SurgeRepository {
  final TradeRepository _tradeRepository;

  // 📊 급등/급락 상태 관리
  final Map<String, Map<String, SurgeData>> _surgeByTimeFrame = {};
  final Set<String> _seenIds = {};
  
  // 🎯 급등/급락 스트림 컨트롤러들 (시간대별) - Surge 리스트 방출
  final Map<String, StreamController<List<Surge>>> _surgeControllers = {};
  
  // 🕐 시간대별 리셋 시간 추적
  final Map<String, DateTime> _timeFrameStartTimes = {};
  
  // 🎯 스트림 관리
  StreamSubscription<Trade>? _masterSubscription;
  Timer? _batchUpdateTimer;
  bool _disposed = false;
  
  // 성능 최적화 상수
  static const int _maxMarketsPerTimeFrame = 200;
  static const int _maxCacheSize = 1000;
  static const Duration _batchUpdateInterval = Duration(milliseconds: 100);

  SurgeRepositoryImpl(this._tradeRepository) {
    _initializeSurgeTracking();
  }

  /// 급등/급락 추적 초기화
  void _initializeSurgeTracking() {
    for (final timeFrameMinutes in AppConfig.timeFrames) {
      final timeFrameStr = '${timeFrameMinutes}m';
      
      // 빈 급등/급락 맵 초기화
      _surgeByTimeFrame[timeFrameStr] = <String, SurgeData>{};
      
      // 스트림 컨트롤러 생성 - List<Surge> 타입
      _surgeControllers[timeFrameStr] = StreamController<List<Surge>>.broadcast();
      
      // 시작 시간 설정
      _timeFrameStartTimes[timeFrameStr] = DateTime.now();
      
      // 정확한 리셋 타이밍 스케줄링
      _scheduleNextReset(timeFrameStr, timeFrameMinutes);
    }
    
    if (kDebugMode) {
      debugPrint('SurgeRepository: Surge tracking initialized for ${AppConfig.timeFrames.length} timeframes');
    }
  }

  /// 정확한 리셋 타이밍 스케줄링
  void _scheduleNextReset(String timeFrame, int minutes) {
    final now = DateTime.now();
    final startTime = _timeFrameStartTimes[timeFrame]!;
    final nextReset = startTime.add(Duration(minutes: minutes));
    final delay = nextReset.difference(now);
    
    if (delay.isNegative) {
      _resetTimeFrameData(timeFrame);
      _timeFrameStartTimes[timeFrame] = now;
      _scheduleNextReset(timeFrame, minutes);
    } else {
      Timer(delay, () {
        _resetTimeFrameData(timeFrame);
        _timeFrameStartTimes[timeFrame] = DateTime.now();
        _scheduleNextReset(timeFrame, minutes);
      });
    }
  }

  /// 메인 스트림 초기화 및 데이터 처리
  void _initializeProcessing(List<String> markets) {
    if (_masterSubscription != null) return;
    
    debugPrint('SurgeRepository: initializing processing for ${markets.length} markets');
    
    // TradeRepository의 순수 데이터 스트림 구독
    _masterSubscription = _tradeRepository.watchTrades(markets).listen(
      _processRawTradeData,
      onError: (error, stackTrace) {
        debugPrint('SurgeRepository processing error: $error');
        // 에러를 모든 컨트롤러에 전달
        for (final controller in _surgeControllers.values) {
          if (!controller.isClosed) {
            controller.addError(error, stackTrace);
          }
        }
      },
      onDone: () {
        debugPrint('SurgeRepository processing done');
      },
    );
  }

  @override
  Stream<List<Surge>> watchSurgeByTimeFrame(String timeFrame, List<String> markets) {
    if (_disposed) {
      throw StateError('Repository has been disposed');
    }

    // 처리 초기화
    _initializeProcessing(markets);
    
    // 해당 시간대의 급등/급락 스트림 직접 반환
    return _surgeControllers[timeFrame]?.stream ?? const Stream.empty();
  }

  /// 원시 거래 데이터 처리
  void _processRawTradeData(Trade trade) {
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

      // 데이터 저장 후 배치 업데이트 예약
      _storeDataAndScheduleUpdate(trade);
      
    } catch (e, stackTrace) {
      debugPrint('_processRawTradeData error: $e');
      debugPrint('StackTrace: $stackTrace');
      // 에러를 모든 컨트롤러에 전달
      for (final controller in _surgeControllers.values) {
        if (!controller.isClosed) {
          controller.addError(e, stackTrace);
        }
      }
    }
  }

  /// 거래 데이터 저장 후 배치 업데이트 예약
  void _storeDataAndScheduleUpdate(Trade trade) {
    final market = trade.market;
    final currentPrice = trade.price;
    
    for (final timeFrameStr in _surgeByTimeFrame.keys) {
      final surgeMap = _surgeByTimeFrame[timeFrameStr]!;
      
      // 크기 제한 (상위 200개만 유지)
      if (surgeMap.length > _maxMarketsPerTimeFrame) {
        final sorted = surgeMap.entries.toList()
          ..sort((a, b) => b.value.changePercent.abs().compareTo(a.value.changePercent.abs()));
        surgeMap.clear();
        surgeMap.addAll(Map.fromEntries(sorted.take(_maxMarketsPerTimeFrame)));
      }
      
      final surgeData = surgeMap[market] ??= SurgeData();
      surgeData.updatePrice(currentPrice);
    }
    
    // 배치 업데이트 예약
    _scheduleBatchUpdate();
  }

  /// 배치 업데이트 스케줄링
  void _scheduleBatchUpdate() {
    if (_disposed) return;
    
    _batchUpdateTimer?.cancel();
    _batchUpdateTimer = Timer(_batchUpdateInterval, () {
      _performBatchUpdate();
    });
  }

  /// 모든 시간대의 급등/급락 스트림 배치 업데이트
  void _performBatchUpdate() {
    if (_disposed) return;
    
    try {
      for (final entry in _surgeByTimeFrame.entries) {
        final timeFrameStr = entry.key;
        final surgeMap = entry.value;
        
        // Surge 리스트 생성
        final surgeList = _createSurgeList(surgeMap, timeFrameStr);
        
        // 해당 시간대 스트림에 Surge 리스트 전송
        final controller = _surgeControllers[timeFrameStr];
        if (controller != null && !controller.isClosed) {
          controller.add(surgeList);
        }
      }
      
      if (kDebugMode) {
        final totalMarkets = _surgeByTimeFrame.values.isNotEmpty 
            ? _surgeByTimeFrame.values.first.length 
            : 0;
        if (totalMarkets > 0) {
          debugPrint('SurgeRepository: Surge streams updated (batch): $totalMarkets markets');
        }
      }
    } catch (e, stackTrace) {
      debugPrint('_performBatchUpdate error: $e');
      debugPrint('StackTrace: $stackTrace');
      // 에러를 모든 컨트롤러에 전달
      for (final controller in _surgeControllers.values) {
        if (!controller.isClosed) {
          controller.addError(e, stackTrace);
        }
      }
    }
  }

  /// Surge 리스트 생성
  List<Surge> _createSurgeList(Map<String, SurgeData> surgeMap, String timeFrame) {
    final now = DateTime.now();
    final startTime = _timeFrameStartTimes[timeFrame] ?? now;
    
    final surgeList = surgeMap.entries
        .where((entry) => entry.value.basePrice != null && entry.value.changePercent != 0)
        .map((entry) => Surge(
              market: entry.key,
              changePercent: entry.value.changePercent,
              basePrice: entry.value.basePrice!,
              currentPrice: entry.value.currentPrice,
              lastUpdatedMs: now.millisecondsSinceEpoch,
              timeFrame: timeFrame,
              timeFrameStartMs: startTime.millisecondsSinceEpoch,
            ))
        .toList();

    // 변동률 실제값 기준으로 정렬 (급등이 위에, 급락이 아래에)
    surgeList.sort((a, b) => b.changePercent.compareTo(a.changePercent));
    
    return surgeList;
  }

  /// 특정 시간대 데이터 리셋
  void _resetTimeFrameData(String timeFrameStr) {
    // 변동률 리셋: 현재 가격을 새로운 basePrice로 설정
    final surgeMap = _surgeByTimeFrame[timeFrameStr];
    if (surgeMap != null) {
      for (final surgeData in surgeMap.values) {
        surgeData.reset(surgeData.currentPrice);
      }
    }
    
    // 리셋 후 Surge 리스트 전송
    final surgeList = _createSurgeList(surgeMap ?? {}, timeFrameStr);
    final controller = _surgeControllers[timeFrameStr];
    if (controller != null && !controller.isClosed) {
      controller.add(surgeList);
    }
    
    if (kDebugMode) {
      debugPrint('SurgeRepository: Reset completed for $timeFrameStr with ${surgeList.length} items');
    }
  }

  @override
  void resetTimeFrame(String timeFrame) {
    debugPrint('SurgeRepository: Manual reset timeFrame: $timeFrame');
    _resetTimeFrameData(timeFrame);
  }

  @override
  void resetAllTimeFrames() {
    debugPrint('SurgeRepository: Manual reset all timeFrames');
    for (final timeFrameStr in _surgeByTimeFrame.keys) {
      _resetTimeFrameData(timeFrameStr);
    }
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
    final activeFrames = AppConfig.timeFrames.map((tf) => '${tf}m').toList();
    return activeFrames.contains(timeFrame);
  }

  @override
  Future<void> dispose() async {
    if (_disposed) return;
    
    debugPrint('SurgeRepository: dispose() called');
    _disposed = true;
    
    // 타이머 정리
    _batchUpdateTimer?.cancel();
    
    // 스트림 구독 정리
    await _masterSubscription?.cancel();
    
    // 컨트롤러들 정리
    for (final controller in _surgeControllers.values) {
      await controller.close();
    }
    
    // 데이터 정리
    _surgeByTimeFrame.clear();
    _seenIds.clear();
    _timeFrameStartTimes.clear();
    
    debugPrint('SurgeRepository: dispose completed');
  }
}