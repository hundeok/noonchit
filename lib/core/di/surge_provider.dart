// lib/core/di/surge_provider.dart

import 'dart:async';
import 'dart:collection';
import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:rxdart/rxdart.dart'; // 🔥 추가: share() 메서드용
import '../config/app_config.dart';
import '../utils/logger.dart';
import 'trade_provider.dart' show marketsProvider, repoProvider;
import '../../domain/entities/surge.dart';
import '../../domain/entities/trade.dart';

// ══════════════════════════════════════════════════════════════════════════════
// 💎 Core Types (완전한 타입 안전성 + 불변성)
// ══════════════════════════════════════════════════════════════════════════════

/// 시간대 Enum (완전한 타입 안전성)
enum TimeFrame {
  min1(1, '1분'),
  min5(5, '5분'),
  min15(15, '15분'),
  min30(30, '30분'),
  min60(60, '1시간'),
  hour2(120, '2시간'),
  hour4(240, '4시간'),
  hour8(480, '8시간'),
  hour12(720, '12시간'),
  day1(1440, '1일');

  const TimeFrame(this.minutes, this.displayName);
  final int minutes;
  final String displayName;
  
  Duration get duration => Duration(minutes: minutes);
  String get key => '${minutes}m';
  
  /// AppConfig에서 TimeFrame 변환
  static List<TimeFrame> fromAppConfig() {
    return AppConfig.timeFrames.map((minutes) {
      return TimeFrame.values.firstWhere(
        (tf) => tf.minutes == minutes,
        orElse: () => TimeFrame.min1,
      );
    }).toList();
  }
}

/// 배치 처리 및 캐시 설정 (완전한 외부 주입)
@immutable
class SurgeProcessingConfig {
  final int maxCacheSize;
  final int maxMarketsPerTimeFrame;
  final Duration minBatchInterval;
  final Duration maxBatchInterval;
  final Duration defaultBatchInterval;
  final int highLoadThreshold;
  final int lowLoadThreshold;

  const SurgeProcessingConfig({
    this.maxCacheSize = 1000,
    this.maxMarketsPerTimeFrame = 200,
    this.minBatchInterval = const Duration(milliseconds: 50),
    this.maxBatchInterval = const Duration(milliseconds: 200),
    this.defaultBatchInterval = const Duration(milliseconds: 100),
    this.highLoadThreshold = 50,
    this.lowLoadThreshold = 10,
  });

  /// 적응형 배치 간격 계산
  Duration calculateBatchInterval(int bufferSize) {
    if (bufferSize > highLoadThreshold) return minBatchInterval;
    if (bufferSize < lowLoadThreshold) return maxBatchInterval;
    return defaultBatchInterval;
  }
}

/// 급등/급락 이벤트 (완전히 개선된 설계)
@immutable
class SurgeEvent {
  final List<Surge> surges;
  final TimeFrame timeFrame;
  final bool isReset;
  final DateTime? resetTime;
  final DateTime eventTime;

  const SurgeEvent({
    required this.surges,
    required this.timeFrame,
    this.isReset = false,
    this.resetTime,
    required this.eventTime,
  });

  /// 일반 데이터 이벤트 생성
  factory SurgeEvent.data({
    required List<Surge> surges,
    required TimeFrame timeFrame,
  }) {
    return SurgeEvent(
      surges: surges,
      timeFrame: timeFrame,
      isReset: false,
      eventTime: DateTime.now(),
    );
  }

  /// 리셋 이벤트 생성
  factory SurgeEvent.reset({
    required TimeFrame timeFrame,
    DateTime? resetTime,
  }) {
    final now = resetTime ?? DateTime.now();
    return SurgeEvent(
      surges: const [],
      timeFrame: timeFrame,
      isReset: true,
      resetTime: now,
      eventTime: now,
    );
  }
}

/// 가격 데이터 (불변)
@immutable
class PriceData {
  final double basePrice;
  final double currentPrice;
  final double changePercent;

  const PriceData({
    required this.basePrice,
    required this.currentPrice,
    required this.changePercent,
  });

  factory PriceData.initial(double price) {
    return PriceData(
      basePrice: price,
      currentPrice: price,
      changePercent: 0.0,
    );
  }

  PriceData updatePrice(double newPrice) {
    final percent = basePrice > 0 
        ? ((newPrice - basePrice) / basePrice) * 100 
        : 0.0;
    
    return PriceData(
      basePrice: basePrice,
      currentPrice: newPrice,
      changePercent: percent,
    );
  }

  PriceData reset(double newPrice) {
    return PriceData(
      basePrice: newPrice,
      currentPrice: newPrice,
      changePercent: 0.0,
    );
  }
}

// ══════════════════════════════════════════════════════════════════════════════
// 🧠 Core Logic: SurgeTransformer (완전한 순수 함수형 + 최적화)
// ══════════════════════════════════════════════════════════════════════════════

/// 완전히 순수한 함수형 변환기 + 최적화된 메모리 관리
class SurgeTransformer extends StreamTransformerBase<Trade, SurgeEvent> {
  final TimeFrame timeFrame;
  final SurgeProcessingConfig config;
  final Function(TimeFrame, DateTime)? onResetTimeUpdate; // 🔥 동기 콜백 유지
  
  // 최적화된 메모리 관리
  LinkedHashSet<String> _seenIds = LinkedHashSet<String>();
  final Map<String, PriceData> _priceData = <String, PriceData>{};
  
  DateTime _lastResetTime = DateTime.now();
  
  // 배치 처리를 위한 버퍼와 타이머
  final List<Trade> _batchBuffer = [];
  Timer? _batchTimer;

  SurgeTransformer(
    this.timeFrame, {
    this.config = const SurgeProcessingConfig(),
    this.onResetTimeUpdate,
  });

  @override
  Stream<SurgeEvent> bind(Stream<Trade> stream) {
    late StreamController<SurgeEvent> controller;
    StreamSubscription<Trade>? subscription;
    Timer? resetTimer;
    
    // 🔥 배치 플러시 - 최적화된 처리
    void flushBatch() {
      if (_batchBuffer.isEmpty || controller.isClosed) return;
      
      // 버퍼에 쌓인 모든 거래를 한 번에 처리
      for (final trade in _batchBuffer) {
        _processTrade(trade);
      }
      _batchBuffer.clear();

      // 모든 처리 후, 최종 결과물 이벤트를 한 번만 발생
      final surges = _calculateSurges();
      if (!controller.isClosed) {
        controller.add(SurgeEvent.data(
          surges: surges,
          timeFrame: timeFrame,
        ));
      }
    }

    // 🔥 적응형 배치 타이머 리셋
    void resetBatchTimer() {
      _batchTimer?.cancel();
      final interval = config.calculateBatchInterval(_batchBuffer.length);
      _batchTimer = Timer(interval, () {
        flushBatch();
        resetBatchTimer();
      });
    }
    
    // 🔥 동기 콜백 기반 리셋 스케줄링 (안정성 보장)
    void scheduleNextReset(VoidCallback onReset) {
      final now = DateTime.now();
      final nextReset = _lastResetTime.add(timeFrame.duration);
      final delay = nextReset.difference(now);
      
      if (delay.isNegative) {
        onReset();
        _lastResetTime = now;
        // 🔥 동기 콜백으로 즉시 UI 업데이트
        onResetTimeUpdate?.call(timeFrame, _lastResetTime);
        scheduleNextReset(onReset);
      } else {
        resetTimer = Timer(delay, () {
          onReset();
          _lastResetTime = DateTime.now();
          // 🔥 동기 콜백으로 즉시 UI 업데이트
          onResetTimeUpdate?.call(timeFrame, _lastResetTime);
          scheduleNextReset(onReset);
        });
      }
    }
    
    controller = StreamController<SurgeEvent>(
      onListen: () {
        // 🔥 초기 리셋 시간 설정
        onResetTimeUpdate?.call(timeFrame, _lastResetTime);
        
        // 1. 시간대 리셋 타이머 설정
        scheduleNextReset(() {
          _resetData();
          if (!controller.isClosed) {
            controller.add(SurgeEvent.reset(
              timeFrame: timeFrame,
              resetTime: _lastResetTime,
            ));
          }
        });
        
        // 2. 배치 타이머 시작
        resetBatchTimer();

        // 3. 거래 데이터 구독
        subscription = stream.listen(
          (trade) {
            // 즉시 처리하지 않고 버퍼에 추가만
            _batchBuffer.add(trade);
          },
          onError: controller.addError,
          onDone: () {
            // 🔥 타이머 누수 방지
            resetTimer?.cancel();
            _batchTimer?.cancel();
            flushBatch(); // 마지막 배치 처리
            controller.close();
          },
        );
      },
      onCancel: () {
        // 모든 타이머와 구독 취소
        resetTimer?.cancel();
        _batchTimer?.cancel();
        subscription?.cancel();
      },
    );
    
    return controller.stream;
  }

  bool _processTrade(Trade trade) {
    // 🔥 최적화된 중복 필터링 (LinkedHashSet + skip)
    final key = '${trade.market}/${trade.sequentialId}';
    if (_seenIds.contains(key)) return false;
    
    if (_seenIds.length >= config.maxCacheSize) {
      // 🔥 GC 최적화: skip() 사용으로 임시 리스트 생성 제거
      final removeCount = _seenIds.length ~/ 4;
      _seenIds = LinkedHashSet<String>.from(_seenIds.skip(removeCount));
    }
    _seenIds.add(key);

    // 가격 데이터 업데이트
    final existing = _priceData[trade.market];
    if (existing != null) {
      _priceData[trade.market] = existing.updatePrice(trade.price);
    } else {
      _priceData[trade.market] = PriceData.initial(trade.price);
    }

    // 메모리 관리
    if (_priceData.length > config.maxMarketsPerTimeFrame) {
      final sorted = _priceData.entries.toList()
        ..sort((a, b) => b.value.changePercent.abs().compareTo(a.value.changePercent.abs()));
      
      _priceData.clear();
      _priceData.addAll(Map.fromEntries(sorted.take(config.maxMarketsPerTimeFrame)));
    }

    return true;
  }

  void _resetData() {
    for (final entry in _priceData.entries) {
      _priceData[entry.key] = entry.value.reset(entry.value.currentPrice);
    }
  }

  List<Surge> _calculateSurges() {
    final now = DateTime.now();
    final surges = _priceData.entries
        .map((e) => Surge(
              market: e.key,
              changePercent: e.value.changePercent,
              basePrice: e.value.basePrice,
              currentPrice: e.value.currentPrice,
              lastUpdatedMs: now.millisecondsSinceEpoch,
              timeFrame: timeFrame.key,
              timeFrameStartMs: _lastResetTime.millisecondsSinceEpoch,
            ))
        .where((surge) => surge.hasChange)
        .toList();

    // 완전한 정렬 로직: + 먼저, - 나중에 (절댓값 기준)
    surges.sort((a, b) {
      if (a.isRising && b.isFalling) return -1;
      if (a.isFalling && b.isRising) return 1;
      if (a.isRising && b.isRising) return b.changePercent.compareTo(a.changePercent);
      if (a.isFalling && b.isFalling) return b.changePercent.compareTo(a.changePercent);
      return 0;
    });
    
    return surges;
  }
}

// ══════════════════════════════════════════════════════════════════════════════
// 🎯 Providers (완전한 타입 안전성 + 최적화된 아키텍처)
// ══════════════════════════════════════════════════════════════════════════════

/// 선택된 시간대
final selectedTimeFrameProvider = StateProvider<TimeFrame>((ref) => TimeFrame.min1);

/// 🔥 완전한 타입 안전성: TimeFrame enum 키 사용
final timeFrameResetTimesProvider = StateProvider<Map<TimeFrame, DateTime>>((ref) {
  final now = DateTime.now();
  final initialTimes = <TimeFrame, DateTime>{};
  
  // 모든 시간대 초기화
  for (final timeFrame in TimeFrame.fromAppConfig()) {
    initialTimes[timeFrame] = now;
  }
  
  return initialTimes;
});

/// 처리 설정 Provider (외부 주입 가능)
final surgeProcessingConfigProvider = Provider<SurgeProcessingConfig>((ref) {
  return const SurgeProcessingConfig(
    // 프로덕션 최적화 설정
    maxCacheSize: 1000,
    maxMarketsPerTimeFrame: 200,
    minBatchInterval: Duration(milliseconds: 50),
    maxBatchInterval: Duration(milliseconds: 200),
    defaultBatchInterval: Duration(milliseconds: 100),
    highLoadThreshold: 50,
    lowLoadThreshold: 10,
  );
});

/// 시간대별 StreamController 관리 (멀티스트림)
final timeFrameControllersProvider = Provider<Map<TimeFrame, StreamController<SurgeEvent>>>((ref) {
  final controllers = <TimeFrame, StreamController<SurgeEvent>>{};
  final availableTimeFrames = TimeFrame.fromAppConfig();
  
  for (final timeFrame in availableTimeFrames) {
    controllers[timeFrame] = StreamController<SurgeEvent>.broadcast();
  }

  ref.onDispose(() {
    for (final controller in controllers.values) {
      if (!controller.isClosed) {
        controller.close();
      }
    }
    controllers.clear();
    
    if (AppConfig.enableTradeLog) {
      log.i('🛑 TimeFrame controllers disposed');
    }
  });

  return controllers;
});

/// 🔥 최적화된 원시 거래 스트림 (단일 WS + 브로드캐스트)
final tradeStreamProvider = StreamProvider<Trade>((ref) async* {
  final markets = await ref.watch(marketsProvider.future);
  final repo = ref.read(repoProvider);
  
  if (AppConfig.enableTradeLog) {
    log.i('🔥 Single WS Trade stream started: ${markets.length} markets');
  }
  
  // 🔥 핵심 최적화: 단일 WS 스트림 + share()로 브로드캐스트
  yield* repo.watchTrades(markets).share();
});

/// 🔥 시간대별 스트림 연결 (최적화된 팬-아웃 방식)
final surgeStreamBinderProvider = Provider((ref) async {
  // ✅ 비동기로 마켓 데이터 대기
  final markets = await ref.read(marketsProvider.future);
  final repo = ref.read(repoProvider);
  final controllers = ref.read(timeFrameControllersProvider);
  final availableTimeFrames = TimeFrame.fromAppConfig();
  final config = ref.read(surgeProcessingConfigProvider);
  
  // ✅ 마스터 스트림을 binder에서 직접 생성 (WS 1개 유지)
  final masterStream = repo.watchTrades(markets).share();
  
  // 🔥 동기 콜백 기반 리셋 시간 업데이트 (타이밍 이슈 제거)
  void updateResetTime(TimeFrame timeFrame, DateTime resetTime) {
    final currentTimes = ref.read(timeFrameResetTimesProvider);
    ref.read(timeFrameResetTimesProvider.notifier).state = {
      ...currentTimes,
      timeFrame: resetTime,
    };
  }
  
  // 🔥 각 시간대별로 마스터 스트림을 팬-아웃
  for (final timeFrame in availableTimeFrames) {
    final controller = controllers[timeFrame];
    if (controller != null) {
      // 🔥 마스터 스트림 → 시간대별 독립 변환 → 각 컨트롤러로 전송
      masterStream
          .transform(SurgeTransformer(
            timeFrame,
            config: config,
            onResetTimeUpdate: updateResetTime, // 🔥 동기 콜백으로 안정성 보장
          ))
          .listen(
            controller.add,
            onError: controller.addError,
          );
    }
  }

  if (AppConfig.enableTradeLog) {
    log.i('🔥 Fan-out stream binding completed: ${availableTimeFrames.length} timeframes');
  }
  
  return controllers;
});

/// 메인 급등/급락 데이터 스트림
final surgeDataProvider = StreamProvider<SurgeEvent>((ref) async* {
  ref.keepAlive();
  
  final selectedTimeFrame = ref.watch(selectedTimeFrameProvider);
  final controllers = ref.read(timeFrameControllersProvider);
  
  // 스트림 바인더 활성화
  await ref.read(surgeStreamBinderProvider);
  
  final controller = controllers[selectedTimeFrame];
  if (controller == null) {
    log.e('💥 Controller not found for $selectedTimeFrame');
    return;
  }

  if (AppConfig.enableTradeLog) {
    log.i('🔥 Surge stream started: $selectedTimeFrame');
  }

  yield* controller.stream;
});

/// 현재 시간대의 Surge 리스트 (UI용)
final currentSurgeListProvider = Provider<List<Surge>>((ref) {
  final surgeEvent = ref.watch(surgeDataProvider).valueOrNull;
  return surgeEvent?.surges ?? [];
});

// ══════════════════════════════════════════════════════════════════════════════
// 🎛️ TimeFrame Controller (완전한 타입 안전성)
// ══════════════════════════════════════════════════════════════════════════════

final timeFrameControllerProvider = Provider((ref) => TimeFrameController(ref));

class TimeFrameController {
  final Ref _ref;
  
  TimeFrameController(this._ref);

  /// 시간대 변경 (TimeFrame enum 기반)
  void setTimeFrame(TimeFrame timeFrame) {
    _ref.read(selectedTimeFrameProvider.notifier).state = timeFrame;
    
    if (AppConfig.enableTradeLog) {
      log.i('🔄 TimeFrame changed: ${timeFrame.displayName}');
    }
  }

  /// 현재 시간대 수동 리셋
  void resetCurrentTimeFrame() {
    final currentTimeFrame = _ref.read(selectedTimeFrameProvider);
    final controllers = _ref.read(timeFrameControllersProvider);
    final controller = controllers[currentTimeFrame];
    
    if (controller != null && !controller.isClosed) {
      final now = DateTime.now();
      
      // 리셋 이벤트 발생
      controller.add(SurgeEvent.reset(
        timeFrame: currentTimeFrame,
        resetTime: now,
      ));
      
      // 🔥 완전한 타입 안전성: TimeFrame enum 키 사용
      final currentTimes = _ref.read(timeFrameResetTimesProvider);
      _ref.read(timeFrameResetTimesProvider.notifier).state = {
        ...currentTimes,
        currentTimeFrame: now,
      };
      
      if (AppConfig.enableTradeLog) {
        log.i('🔄 Manual reset: ${currentTimeFrame.displayName}');
      }
    }
  }

  /// 모든 시간대 리셋
  void resetAllTimeFrames() {
    final controllers = _ref.read(timeFrameControllersProvider);
    final availableTimeFrames = TimeFrame.fromAppConfig();
    final now = DateTime.now();
    
    for (final timeFrame in availableTimeFrames) {
      final controller = controllers[timeFrame];
      if (controller != null && !controller.isClosed) {
        controller.add(SurgeEvent.reset(
          timeFrame: timeFrame,
          resetTime: now,
        ));
      }
    }
    
    // 🔥 완전한 타입 안전성: TimeFrame enum 키 사용
    final resetTimes = <TimeFrame, DateTime>{};
    for (final timeFrame in availableTimeFrames) {
      resetTimes[timeFrame] = now;
    }
    _ref.read(timeFrameResetTimesProvider.notifier).state = resetTimes;
    
    if (AppConfig.enableTradeLog) {
      log.i('🔄 Manual reset: all timeframes');
    }
  }

  /// 🔥 완전한 타입 안전성으로 다음 리셋 시간 계산
  DateTime? getNextResetTime() {
    final currentTimeFrame = _ref.read(selectedTimeFrameProvider);
    final resetTimes = _ref.read(timeFrameResetTimesProvider);
    final lastResetTime = resetTimes[currentTimeFrame];
    
    if (lastResetTime == null) return null;
    
    return lastResetTime.add(currentTimeFrame.duration);
  }

  /// Getters
  TimeFrame get currentTimeFrame => _ref.read(selectedTimeFrameProvider);
  
  int get currentIndex {
    final availableTimeFrames = TimeFrame.fromAppConfig();
    return availableTimeFrames.indexOf(currentTimeFrame);
  }
  
  List<TimeFrame> get availableTimeFrames => TimeFrame.fromAppConfig();
  
  String get currentTimeFrameName => currentTimeFrame.displayName;
  
  String getTimeFrameName(TimeFrame timeFrame) => timeFrame.displayName;
}