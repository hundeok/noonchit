import 'dart:async';
import 'dart:collection';
import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../config/app_config.dart';
import '../utils/logger.dart';
import '../common/time_frame_manager.dart'; // 🔥 공통 TimeFrame 시스템 사용
import '../common/time_frame_types.dart';   // 🔥 공통 타입 사용
import 'trade_provider.dart' show masterTradeStreamProvider, repoProvider;
import '../../domain/entities/volume.dart';
import '../../domain/entities/trade.dart';
import '../../domain/usecases/volume_usecase.dart';
import '../../domain/repositories/volume_repository.dart';
import '../../data/repositories/volume_repository_impl.dart';

// ══════════════════════════════════════════════════════════════════════════════
// 💎 Volume Event Types (기존 유지)
// ══════════════════════════════════════════════════════════════════════════════

/// 볼륨 이벤트 (완전히 개선된 설계)
@immutable
class VolumeEvent {
  final List<Volume> volumes;
  final TimeFrame timeFrame;
  final bool isReset;
  final DateTime? resetTime;
  final DateTime eventTime;

  const VolumeEvent({
    required this.volumes,
    required this.timeFrame,
    this.isReset = false,
    this.resetTime,
    required this.eventTime,
  });

  /// 일반 데이터 이벤트 생성
  factory VolumeEvent.data({
    required List<Volume> volumes,
    required TimeFrame timeFrame,
  }) {
    return VolumeEvent(
      volumes: volumes,
      timeFrame: timeFrame,
      isReset: false,
      eventTime: DateTime.now(),
    );
  }

  /// 리셋 이벤트 생성
  factory VolumeEvent.reset({
    required TimeFrame timeFrame,
    DateTime? resetTime,
  }) {
    final now = resetTime ?? DateTime.now();
    return VolumeEvent(
      volumes: const [],
      timeFrame: timeFrame,
      isReset: true,
      resetTime: now,
      eventTime: now,
    );
  }
}

/// 볼륨 데이터 (불변)
@immutable
class VolumeData {
  final double totalVolume;
  final DateTime lastUpdated;

  const VolumeData({
    required this.totalVolume,
    required this.lastUpdated,
  });

  factory VolumeData.initial() {
    return VolumeData(
      totalVolume: 0.0,
      lastUpdated: DateTime.now(),
    );
  }

  VolumeData addVolume(double volume) {
    return VolumeData(
      totalVolume: totalVolume + volume,
      lastUpdated: DateTime.now(),
    );
  }

  VolumeData reset() {
    return VolumeData(
      totalVolume: 0.0,
      lastUpdated: DateTime.now(),
    );
  }
}

// ══════════════════════════════════════════════════════════════════════════════
// 🧠 Core Logic: VolumeTransformer (공통 TimeFrame 리셋 연동)
// ══════════════════════════════════════════════════════════════════════════════

/// 완전히 순수한 함수형 변환기 + 글로벌 TimeFrame 연동
class VolumeTransformer extends StreamTransformerBase<Trade, VolumeEvent> {
  final TimeFrame timeFrame;
  final ProcessingConfig config; // 🔥 공통 ProcessingConfig 사용
  
  // 최적화된 메모리 관리
  LinkedHashSet<String> _seenIds = LinkedHashSet<String>();
  final Map<String, VolumeData> _volumeData = <String, VolumeData>{};
  
  // 배치 처리를 위한 버퍼와 타이머
  final List<Trade> _batchBuffer = [];
  Timer? _batchTimer;
  
  // 🔥 워밍업 모드 - 초기 CPU 스파이크 완화
  bool _warmupMode = true;
  final DateTime _warmupStartTime = DateTime.now();

  VolumeTransformer(
    this.timeFrame, {
    required this.config, // 🔥 공통 설정 주입
  });

  @override
  Stream<VolumeEvent> bind(Stream<Trade> stream) {
    late StreamController<VolumeEvent> controller;
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
      final volumes = _calculateVolumes();
      if (!controller.isClosed) {
        controller.add(VolumeEvent.data(
          volumes: volumes,
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
            // log.d('Volume warmup completed for ${timeFrame.displayName}');
          }
        }
        
        flushBatch();
        resetBatchTimer();
      });
    }
    
    controller = StreamController<VolumeEvent>(
      onListen: () {
        // 🔥 글로벌 TimeFrame 리셋 이벤트 구독
        resetSubscription = GlobalTimeFrameManager()
            .getResetStream(timeFrame)
            .listen((resetEvent) {
          _resetData();
          if (!controller.isClosed) {
            controller.add(VolumeEvent.reset(
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

    // 볼륨 데이터 업데이트
    final existing = _volumeData[trade.market];
    if (existing != null) {
      _volumeData[trade.market] = existing.addVolume(trade.total);
    } else {
      _volumeData[trade.market] = VolumeData.initial().addVolume(trade.total);
    }

    // 메모리 관리
    if (_volumeData.length > config.maxMarketsPerTimeFrame) {
      final sorted = _volumeData.entries.toList()
        ..sort((a, b) => b.value.totalVolume.compareTo(a.value.totalVolume));
      
      _volumeData.clear();
      _volumeData.addAll(Map.fromEntries(sorted.take(config.maxMarketsPerTimeFrame)));
    }

    return true;
  }

  void _resetData() {
    for (final entry in _volumeData.entries) {
      _volumeData[entry.key] = entry.value.reset();
    }
  }

  List<Volume> _calculateVolumes() {
    final now = DateTime.now();
    final manager = GlobalTimeFrameManager();
    final lastResetTime = manager.getLastResetTime(timeFrame) ?? now;
    
    final volumes = _volumeData.entries
        .map((e) => Volume(
              market: e.key,
              totalVolume: e.value.totalVolume,
              lastUpdatedMs: now.millisecondsSinceEpoch,
              timeFrame: timeFrame.key,
              timeFrameStartMs: lastResetTime.millisecondsSinceEpoch,
            ))
        .where((volume) => volume.totalVolume > 0)
        .toList();

    // 볼륨 내림차순 정렬
    volumes.sort((a, b) => b.totalVolume.compareTo(a.totalVolume));
    
    return volumes;
  }
}

// ══════════════════════════════════════════════════════════════════════════════
// 🎯 Providers (공통 TimeFrame 시스템 연동)
// ══════════════════════════════════════════════════════════════════════════════

/// 🔥 개별 Provider 제거 - 공통 volumeSelectedTimeFrameProvider 사용
// final selectedTimeFrameProvider = ... (제거)

/// 🔥 개별 리셋 시간 관리 제거 - 공통 GlobalTimeFrameManager 사용  
// final timeFrameResetTimesProvider = ... (제거)

/// 🔥 개별 ProcessingConfig 제거 - 공통 commonProcessingConfigProvider 사용
// final volumeProcessingConfigProvider = ... (제거)

/// 시간대별 StreamController 관리 (멀티스트림)
final volumeTimeFrameControllersProvider = Provider<Map<TimeFrame, StreamController<VolumeEvent>>>((ref) {
  final controllers = <TimeFrame, StreamController<VolumeEvent>>{};
  final availableTimeFrames = TimeFrame.fromAppConfig();
  
  for (final timeFrame in availableTimeFrames) {
    controllers[timeFrame] = StreamController<VolumeEvent>.broadcast();
  }

  ref.onDispose(() {
    for (final controller in controllers.values) {
      if (!controller.isClosed) {
        controller.close();
      }
    }
    controllers.clear();
    
    if (AppConfig.enableTradeLog) {
      log.i('🛑 Volume TimeFrame controllers disposed');
    }
  });

  return controllers;
});

/// 🔥 Master Stream 기반 팬-아웃 (공통 TimeFrame 연동)
final volumeStreamBinderProvider = Provider((ref) async {
  // ✅ Master Trade Stream 사용 (Trade와 동일한 WS 연결 공유)
  final masterStream = await ref.read(masterTradeStreamProvider.future);
  final controllers = ref.read(volumeTimeFrameControllersProvider);
  final availableTimeFrames = TimeFrame.fromAppConfig();
  final config = ref.read(commonProcessingConfigProvider); // 🔥 공통 설정 사용
  
  // 🔥 각 시간대별로 마스터 스트림을 팬-아웃
  for (final timeFrame in availableTimeFrames) {
    final controller = controllers[timeFrame];
    if (controller != null) {
      // 🔥 마스터 스트림 → 시간대별 독립 변환 → 각 컨트롤러로 전송
      masterStream
          .transform(VolumeTransformer(
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
    log.i('🔥 Volume Fan-out stream binding completed: ${availableTimeFrames.length} timeframes');
  }
  
  return controllers;
});

/// 메인 볼륨 데이터 스트림 (공통 Provider 사용)
final volumeDataProvider = StreamProvider<VolumeEvent>((ref) async* {
  ref.keepAlive();
  
  final selectedTimeFrame = ref.watch(volumeSelectedTimeFrameProvider); // 🔥 공통 Provider 사용
  final controllers = ref.read(volumeTimeFrameControllersProvider);
  
  // 스트림 바인더 활성화
  await ref.read(volumeStreamBinderProvider);
  
  final controller = controllers[selectedTimeFrame];
  if (controller == null) {
    log.e('💥 Volume Controller not found for $selectedTimeFrame');
    return;
  }

  if (AppConfig.enableTradeLog) {
    log.i('🔥 Volume stream started: $selectedTimeFrame');
  }

  yield* controller.stream;
});

/// 현재 시간대의 Volume 리스트 (UI용)
final currentVolumeListProvider = Provider<List<Volume>>((ref) {
  final volumeEvent = ref.watch(volumeDataProvider).valueOrNull;
  return volumeEvent?.volumes ?? [];
});

// ══════════════════════════════════════════════════════════════════════════════
// 🎛️ Volume TimeFrame Controller (공통 시스템 연동)
// ══════════════════════════════════════════════════════════════════════════════

final volumeTimeFrameControllerProvider = Provider((ref) => VolumeTimeFrameController(ref));

class VolumeTimeFrameController {
  final Ref _ref;
  
  VolumeTimeFrameController(this._ref);

  /// 시간대 변경 (공통 Provider 사용)
  void setTimeFrame(TimeFrame timeFrame) {
    _ref.read(volumeSelectedTimeFrameProvider.notifier).state = timeFrame;
    
    if (AppConfig.enableTradeLog) {
      log.i('🔄 Volume TimeFrame changed: ${timeFrame.displayName}');
    }
  }

  /// 현재 시간대 수동 리셋 (공통 GlobalTimeFrameManager 사용)
  void resetCurrentTimeFrame() {
    final currentTimeFrame = _ref.read(volumeSelectedTimeFrameProvider);
    final globalController = _ref.read(globalTimeFrameControllerProvider);
    
    globalController.resetTimeFrame(currentTimeFrame);
    
    if (AppConfig.enableTradeLog) {
      log.i('🔄 Volume Manual reset: ${currentTimeFrame.displayName}');
    }
  }

  /// 모든 시간대 리셋 (공통 GlobalTimeFrameManager 사용)
  void resetAllTimeFrames() {
    final globalController = _ref.read(globalTimeFrameControllerProvider);
    globalController.resetAllTimeFrames();
    
    if (AppConfig.enableTradeLog) {
      log.i('🔄 Volume Manual reset: all timeframes');
    }
  }

  /// 🔥 공통 시스템으로 다음 리셋 시간 계산
  DateTime? getNextResetTime() {
    final currentTimeFrame = _ref.read(volumeSelectedTimeFrameProvider);
    final globalController = _ref.read(globalTimeFrameControllerProvider);
    
    return globalController.getNextResetTime(currentTimeFrame);
  }

  /// Getters (공통 Provider 사용)
  TimeFrame get currentTimeFrame => _ref.read(volumeSelectedTimeFrameProvider);
  
  int get currentIndex {
    final availableTimeFrames = TimeFrame.fromAppConfig();
    return availableTimeFrames.indexOf(currentTimeFrame);
  }
  
  List<TimeFrame> get availableTimeFrames => TimeFrame.fromAppConfig();
  
  String get currentTimeFrameName => currentTimeFrame.displayName;
  
  String getTimeFrameName(TimeFrame timeFrame) => timeFrame.displayName;
}

// ══════════════════════════════════════════════════════════════════════════════
// 🏗️ UseCase Layer (기존 유지)
// ══════════════════════════════════════════════════════════════════════════════

final volumeRepositoryProvider = Provider<VolumeRepository>((ref) {
  return VolumeRepositoryImpl(ref.read(repoProvider));
});

final volumeUsecaseProvider = Provider<VolumeUsecase>((ref) {
  return VolumeUsecase(ref.read(repoProvider));
});