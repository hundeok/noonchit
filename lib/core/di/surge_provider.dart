import 'dart:async';
import 'dart:collection';
import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../config/app_config.dart';
import '../utils/logger.dart';
import '../common/time_frame_manager.dart'; // 🔥 간소화된 TimeFrame 시스템 사용
import '../common/time_frame_types.dart';   // 🔥 공통 타입 사용
import 'trade_provider.dart' show masterTradeStreamProvider;
import '../../domain/entities/surge.dart';
import '../../domain/entities/trade.dart';

// ══════════════════════════════════════════════════════════════════════════════
// 💎 Surge Event Types (기존 유지)
// ══════════════════════════════════════════════════════════════════════════════

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
// 🧠 Core Logic: SurgeTransformer (간소화된 TimeFrame 연동)
// ══════════════════════════════════════════════════════════════════════════════

/// 완전히 순수한 함수형 변환기 + 간소화된 TimeFrame 연동
class SurgeTransformer extends StreamTransformerBase<Trade, SurgeEvent> {
  final TimeFrame timeFrame;
  final ProcessingConfig config; // 🔥 공통 ProcessingConfig 사용
  
  // 최적화된 메모리 관리
  LinkedHashSet<String> _seenIds = LinkedHashSet<String>();
  final Map<String, PriceData> _priceData = <String, PriceData>{};
  
  // 배치 처리를 위한 버퍼와 타이머
  final List<Trade> _batchBuffer = [];
  Timer? _batchTimer;
  
  // 🔥 워밍업 모드 - 초기 CPU 스파이크 완화
  bool _warmupMode = true;
  final DateTime _warmupStartTime = DateTime.now();

  SurgeTransformer(
    this.timeFrame, {
    required this.config, // 🔥 공통 설정 주입
  });

  @override
  Stream<SurgeEvent> bind(Stream<Trade> stream) {
    late StreamController<SurgeEvent> controller;
    StreamSubscription<Trade>? subscription;
    StreamSubscription<TimeFrameResetEvent>? resetSubscription;
    
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

    // 🔥 적응형 배치 타이머 리셋 + 워밍업 모드
    void resetBatchTimer() {
      _batchTimer?.cancel();
      
      // 워밍업 모드: 300ms로 천천히, 정상 모드: 적응형 간격
      final interval = _warmupMode
        ? config.warmupBatchInterval  // 🔥 공통 설정 사용
        : config.calculateBatchInterval(_batchBuffer.length);
      
      _batchTimer = Timer(interval, () {
        // 3초 후 워밍업 모드 해제
        if (_warmupMode && DateTime.now().difference(_warmupStartTime).inSeconds >= 3) {
          _warmupMode = false;
          if (AppConfig.enableTradeLog) {
            // log.d('Surge warmup completed for ${timeFrame.displayName}');
          }
        }
        
        flushBatch();
        resetBatchTimer();
      });
    }
    
    controller = StreamController<SurgeEvent>(
      onListen: () {
        // 🔥 간소화된 TimeFrame 리셋 이벤트 구독
        resetSubscription = GlobalTimeFrameManager()
            .getResetStream(timeFrame)
            .listen((resetEvent) {
          _resetData();
          if (!controller.isClosed) {
            controller.add(SurgeEvent.reset(
              timeFrame: timeFrame,
              resetTime: resetEvent.resetTime,
            ));
          }
        });
        
        // 배치 타이머 시작
        resetBatchTimer();

        // 거래 데이터 구독
        subscription = stream.listen(
          (trade) {
            // 즉시 처리하지 않고 버퍼에 추가만
            _batchBuffer.add(trade);
          },
          onError: controller.addError,
          onDone: () {
            // 🔥 타이머 누수 방지
            resetSubscription?.cancel();
            _batchTimer?.cancel();
            flushBatch(); // 마지막 배치 처리
            controller.close();
          },
        );
      },
      onCancel: () {
        // 모든 타이머와 구독 취소
        resetSubscription?.cancel();
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
    final manager = GlobalTimeFrameManager();
    final lastResetTime = manager.getLastResetTime(timeFrame) ?? now;
    
    final surges = _priceData.entries
        .map((e) => Surge(
              market: e.key,
              changePercent: e.value.changePercent,
              basePrice: e.value.basePrice,
              currentPrice: e.value.currentPrice,
              lastUpdatedMs: now.millisecondsSinceEpoch,
              timeFrame: timeFrame.key,
              timeFrameStartMs: lastResetTime.millisecondsSinceEpoch,
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
// 🎯 Providers (간소화된 구조)
// ══════════════════════════════════════════════════════════════════════════════

/// 시간대별 StreamController 관리 (멀티스트림)
final surgeTimeFrameControllersProvider = Provider<Map<TimeFrame, StreamController<SurgeEvent>>>((ref) {
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
      log.i('🛑 Surge TimeFrame controllers disposed');
    }
  });

  return controllers;
});

/// 🔥 Master Stream 기반 팬-아웃 (간소화된 TimeFrame 연동)
final surgeStreamBinderProvider = Provider((ref) async {
  // ✅ Master Trade Stream 사용 (Trade/Volume과 동일한 WS 연결 공유)
  final masterStream = await ref.read(masterTradeStreamProvider.future);
  final controllers = ref.read(surgeTimeFrameControllersProvider);
  final availableTimeFrames = TimeFrame.fromAppConfig();
  final config = ref.read(commonProcessingConfigProvider); // 🔥 공통 설정 사용
  
  // 🔥 각 시간대별로 마스터 스트림을 팬-아웃
  for (final timeFrame in availableTimeFrames) {
    final controller = controllers[timeFrame];
    if (controller != null) {
      // 🔥 마스터 스트림 → 시간대별 독립 변환 → 각 컨트롤러로 전송
      masterStream
          .transform(SurgeTransformer(
            timeFrame,
            config: config, // 🔥 공통 설정 주입
          ))
          .listen(
            controller.add,
            onError: controller.addError,
          );
    }
  }

  if (AppConfig.enableTradeLog) {
    log.i('🔥 Surge Fan-out stream binding completed: ${availableTimeFrames.length} timeframes');
  }
  
  return controllers;
});

/// 메인 급등/급락 데이터 스트림 (간소화된 Provider 사용)
final surgeDataProvider = StreamProvider<SurgeEvent>((ref) async* {
  ref.keepAlive();
  
  final selectedTimeFrame = ref.watch(surgeSelectedTimeFrameProvider); // 🔥 간소화된 Provider 사용
  final controllers = ref.read(surgeTimeFrameControllersProvider);
  
  // 스트림 바인더 활성화
  await ref.read(surgeStreamBinderProvider);
  
  final controller = controllers[selectedTimeFrame];
  if (controller == null) {
    log.e('💥 Surge Controller not found for $selectedTimeFrame');
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