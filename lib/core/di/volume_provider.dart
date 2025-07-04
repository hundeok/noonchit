import 'dart:async';
import 'dart:collection';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../config/app_config.dart';
import '../utils/logger.dart';
import 'trade_provider.dart' show repoProvider, rawTradeProcessingProvider;
import '../../data/repositories/volume_repository_impl.dart';
import '../../domain/repositories/volume_repository.dart';
import '../../domain/usecases/volume_usecase.dart';
import '../../domain/entities/volume.dart';
import '../../domain/entities/trade.dart';

// ══════════════════════════════════════════════════════════════════════════════
// 📋 데이터 클래스 및 설정 (Enum 제거)
// ══════════════════════════════════════════════════════════════════════════════

/// 볼륨 이벤트 클래스 (String 기반으로 단순화)
class VolumeEvent {
  final List<Volume> volumes;
  final String? resetTimeFrame;

  const VolumeEvent(this.volumes, {this.resetTimeFrame});
}

/// 볼륨 설정 (Enum 없이 단순화)
class VolumeConfig {
  static const int maxVolumesPerTimeFrame = 200;
  static const int maxCacheSize = 250;
  static const Duration minBatchInterval = Duration(milliseconds: 50);
  static const Duration maxBatchInterval = Duration(milliseconds: 200);
  static const Duration defaultBatchInterval = Duration(milliseconds: 100);
  
  /// AppConfig 기반 시간대 목록 (String)
  static List<String> get supportedTimeFrames => 
    AppConfig.timeFrames.map((tf) => '${tf}m').toList();
}

// ══════════════════════════════════════════════════════════════════════════════
// 🏗️ Infrastructure Layer
// ══════════════════════════════════════════════════════════════════════════════

final volumeRepositoryProvider = Provider<VolumeRepository>((ref) {
  return VolumeRepositoryImpl(ref.read(repoProvider));
});

final volumeUsecaseProvider = Provider<VolumeUsecase>((ref) {
  return VolumeUsecase(ref.read(repoProvider));
});

// ══════════════════════════════════════════════════════════════════════════════
// ⚙️ Settings Layer (단순 String 기반)
// ══════════════════════════════════════════════════════════════════════════════

/// 시간대 인덱스
final volumeTimeFrameIndexProvider = StateProvider<int>((_) => 0);

/// 현재 시간대 (String 반환)
final volumeTimeFrameProvider = StateProvider<String>((ref) {
  final index = ref.watch(volumeTimeFrameIndexProvider);
  final timeFrames = VolumeConfig.supportedTimeFrames;
  if (index >= 0 && index < timeFrames.length) {
    return timeFrames[index];
  }
  return '1m';
});

// ══════════════════════════════════════════════════════════════════════════════
// 🎯 State Management Layer (최적화 유지 + String 기반)
// ══════════════════════════════════════════════════════════════════════════════

/// 볼륨 데이터 캐시 (String Key + 메모리 최적화 유지)
final volumeDataCacheProvider = StateNotifierProvider<VolumeDataNotifier, Map<String, Map<String, double>>>((ref) {
  return VolumeDataNotifier(ref.read(volumeTimeFrameProvider));
});

class VolumeDataNotifier extends StateNotifier<Map<String, Map<String, double>>> {
  final String _currentTimeFrame;
  final Map<String, bool> _isActive = {}; // 메모리 최적화: 활성 상태 추적

  VolumeDataNotifier(this._currentTimeFrame) : super({}) {
    final initialState = <String, Map<String, double>>{};
    for (final timeFrame in VolumeConfig.supportedTimeFrames) {
      initialState[timeFrame] = <String, double>{};
      _isActive[timeFrame] = timeFrame == _currentTimeFrame;
    }
    state = initialState;
  }

  /// 메모리 최적화: 시간대 활성화/비활성화
  void setActiveTimeFrame(String timeFrame) {
    _isActive.updateAll((key, value) => false);
    _isActive[timeFrame] = true;
    
    // 비활성 시간대 데이터 압축 (상위 50개만 유지)
    final newState = Map<String, Map<String, double>>.from(state);
    _isActive.forEach((tf, isActive) {
      if (!isActive && newState[tf] != null) {
        final volumeMap = newState[tf]!;
        if (volumeMap.length > 50) {
          final sorted = volumeMap.entries.toList()
            ..sort((a, b) => b.value.compareTo(a.value));
          newState[tf] = Map.fromEntries(sorted.take(50));
        }
      }
    });
    state = newState;
  }

  void updateBatch(Map<String, Map<String, double>> batchData) {
    final newState = Map<String, Map<String, double>>.from(state);
    
    batchData.forEach((timeFrame, volumeMap) {
      final isActive = _isActive[timeFrame] ?? false;
      final maxItems = isActive ? VolumeConfig.maxVolumesPerTimeFrame : 50;
      
      if (volumeMap.length > maxItems) {
        final sorted = volumeMap.entries.toList()
          ..sort((a, b) => b.value.compareTo(a.value));
        volumeMap.clear();
        volumeMap.addAll(Map.fromEntries(sorted.take(maxItems)));
      }
      newState[timeFrame] = Map<String, double>.from(volumeMap);
    });
    
    state = newState;
  }

  void resetTimeFrame(String timeFrame) {
    final newState = Map<String, Map<String, double>>.from(state);
    newState[timeFrame] = <String, double>{};
    state = newState;
    log.i('🔄 Volume reset: $timeFrame');
  }

  void resetAll() {
    final newState = <String, Map<String, double>>{};
    for (final timeFrame in VolumeConfig.supportedTimeFrames) {
      newState[timeFrame] = <String, double>{};
    }
    state = newState;
  }
}

/// 중복 ID 관리 (LinkedHashSet LRU 유지)
final volumeSeenIdsProvider = StateNotifierProvider<VolumeSeenIdsNotifier, Set<String>>((ref) {
  return VolumeSeenIdsNotifier();
});

class VolumeSeenIdsNotifier extends StateNotifier<Set<String>> {
  final LinkedHashSet<String> _orderedIds = LinkedHashSet<String>();

  VolumeSeenIdsNotifier() : super(<String>{});

  bool addId(String id) {
    if (_orderedIds.contains(id)) return false;

    _orderedIds.add(id);

    // LinkedHashSet LRU 패턴: 25% 배치 제거
    if (_orderedIds.length > VolumeConfig.maxCacheSize) {
      final removeCount = (_orderedIds.length / 4).ceil();
      final oldestIds = _orderedIds.take(removeCount).toList();
      
      for (final oldId in oldestIds) {
        _orderedIds.remove(oldId);
      }
    }

    state = Set<String>.from(_orderedIds);
    return true;
  }

  void clear() {
    _orderedIds.clear();
    state = <String>{};
  }
}

// ══════════════════════════════════════════════════════════════════════════════
// 🔄 Processing Layer (개선된 절대 시간 기반 타이머)
// ══════════════════════════════════════════════════════════════════════════════

/// 주기적 리셋 타이머
final volumeProcessingTimerProvider = StreamProvider((ref) {
  return Stream.periodic(AppConfig.globalResetInterval, (i) => i);
});

/// 🎯 개선된 시간대별 리셋 타이머 (절대 시간 기준)
final volumeResetTimersProvider = Provider<Map<String, Timer>>((ref) {
  final timers = <String, Timer>{};
  final dataCacheNotifier = ref.read(volumeDataCacheProvider.notifier);

  /// 절대 시간 기준으로 다음 리셋을 예약하는 핵심 함수
  void scheduleNextAbsoluteReset(String timeFrame) {
    // 1. 현재 시간과 설정된 시간(분) 가져오기
    final now = DateTime.now();
    final minutes = int.tryParse(timeFrame.replaceAll('m', '')) ?? 1;

    // 2. 현재 시간을 기준으로 '현재 봉'의 시작 시간을 계산
    // 예: now=12:32, minutes=5 -> (32 ~/ 5) * 5 = 30 -> 현재 봉은 12:30:00에 시작됨
    final currentChunkStartMinute = (now.minute ~/ minutes) * minutes;
    final startOfCurrentChunk = DateTime(
      now.year,
      now.month,
      now.day,
      now.hour,
      currentChunkStartMinute,
      0, // 초는 0으로 설정
      0, // 밀리초도 0으로 설정
    );

    // 3. '다음 봉'의 시작 시간을 계산 (가장 중요)
    // 현재 봉 시작 시간에 해당 시간(minutes)을 더하면 다음 봉의 시작 시간이 됨
    final nextResetTime = startOfCurrentChunk.add(Duration(minutes: minutes));

    // 4. 다음 리셋까지 남은 시간을 계산
    final delay = nextResetTime.difference(now);

    // 5. 혹시 계산 오차로 음수가 나오면 다음 사이클로
    if (delay.inMilliseconds <= 0) {
      final nextNextResetTime = nextResetTime.add(Duration(minutes: minutes));
      final newDelay = nextNextResetTime.difference(now);
      
      timers[timeFrame] = Timer(newDelay, () {
        log.i('⏰ Absolute Time Reset: $timeFrame at ${nextNextResetTime.toLocal()}');
        dataCacheNotifier.resetTimeFrame(timeFrame);
        scheduleNextAbsoluteReset(timeFrame);
      });
      return;
    }

    // 6. 계산된 'delay' 후에 리셋 및 다음 스케줄링을 예약
    timers[timeFrame] = Timer(delay, () {
      log.i('⏰ Absolute Time Reset: $timeFrame at ${nextResetTime.toLocal()}');
      
      // 데이터 캐시에서 해당 시간대 리셋
      dataCacheNotifier.resetTimeFrame(timeFrame);
      
      // ✅ 중요: 자기 자신을 다시 호출하여 다음 알람을 무한 예약 (연속 스케줄링 유지)
      scheduleNextAbsoluteReset(timeFrame);
    });

    log.i('📅 Next reset scheduled: $timeFrame at ${nextResetTime.toLocal()} (in ${delay.inSeconds}s)');
  }

  // 지원하는 모든 시간대에 대해 타이머 스케줄링 시작
  for (final timeFrame in VolumeConfig.supportedTimeFrames) {
    scheduleNextAbsoluteReset(timeFrame);
  }

  // Provider가 소멸될 때 모든 타이머를 안전하게 취소
  ref.onDispose(() {
    for (final timer in timers.values) {
      timer.cancel();
    }
    timers.clear();
    log.i('🧹 All volume timers disposed');
  });

  return timers;
});

/// 원시 볼륨 처리 스트림 (Trade 구독으로 변경)
final rawVolumeProcessingProvider = StreamProvider<Trade>((ref) async* {
  // ❌ 기존: 독립 WebSocket 연결
  // final markets = await ref.watch(marketsProvider.future);
  // final repo = ref.read(repoProvider);
  
  final seenIdsNotifier = ref.read(volumeSeenIdsProvider.notifier);
  final dataCacheNotifier = ref.read(volumeDataCacheProvider.notifier);

  final Map<String, Map<String, double>> batchBuffer = {};
  Timer? batchTimer;
  int batchCount = 0;
  
  for (final timeFrame in VolumeConfig.supportedTimeFrames) {
    batchBuffer[timeFrame] = <String, double>{};
  }

  // 적응형 배치: 동적 간격 계산
  Duration calculateBatchInterval() {
    if (batchCount > 50) {
      return VolumeConfig.minBatchInterval;
    } else if (batchCount < 10) {
      return VolumeConfig.maxBatchInterval;
    }
    return VolumeConfig.defaultBatchInterval;
  }

  void flushBatch() {
    if (batchBuffer.values.any((map) => map.isNotEmpty)) {
      final currentState = ref.read(volumeDataCacheProvider);
      final mergedData = <String, Map<String, double>>{};
      
      currentState.forEach((timeFrame, currentVolumeMap) {
        final bufferedVolumeMap = batchBuffer[timeFrame] ?? {};
        final merged = Map<String, double>.from(currentVolumeMap);
        
        bufferedVolumeMap.forEach((market, volume) {
          merged[market] = (merged[market] ?? 0.0) + volume;
        });
        
        mergedData[timeFrame] = merged;
      });
      
      dataCacheNotifier.updateBatch(mergedData);
      batchBuffer.forEach((timeFrame, map) => map.clear());
      batchCount = 0;
    }
  }

  void resetBatchTimer() {
    batchTimer?.cancel();
    batchTimer = Timer(calculateBatchInterval(), () {
      flushBatch();
      resetBatchTimer();
    });
  }

  resetBatchTimer();

  // ✅ 개선된 타이머 활성화
  ref.read(volumeResetTimersProvider);

  ref.listen(volumeProcessingTimerProvider, (previous, next) {
    next.whenData((value) {
      flushBatch();
    });
  });

  ref.onDispose(() {
    batchTimer?.cancel();
    flushBatch();
  });

  // ✅ 핵심 변경: Trade 구독으로 교체
  yield* ref.watch(rawTradeProcessingProvider.stream).where((trade) {
    final key = '${trade.market}/${trade.sequentialId}';
    if (!seenIdsNotifier.addId(key)) return false;

    batchCount++;

    for (final timeFrame in VolumeConfig.supportedTimeFrames) {
      final bufferMap = batchBuffer[timeFrame];
      if (bufferMap != null) {
        bufferMap[trade.market] = (bufferMap[trade.market] ?? 0.0) + trade.total;
      }
    }

    return true;
  });
});

// ══════════════════════════════════════════════════════════════════════════════
// 🎯 시간대별 스트림 컨트롤러 관리 (String 기반 + 멀티스트림 유지)
// ══════════════════════════════════════════════════════════════════════════════

/// 시간대별 스트림 컨트롤러들 (String Key)
final volumeStreamControllersProvider = Provider<Map<String, StreamController<VolumeEvent>>>((ref) {
  final controllers = <String, StreamController<VolumeEvent>>{};
  
  for (final timeFrame in VolumeConfig.supportedTimeFrames) {
    controllers[timeFrame] = StreamController<VolumeEvent>.broadcast();
  }

  ref.onDispose(() {
    for (final entry in controllers.entries) {
      if (!entry.value.isClosed) {
        entry.value.close();
      }
    }
    controllers.clear();
  });

  return controllers;
});

/// 시간대별 볼륨 업데이트 로직 (String 기반)
final volumeTimeFrameUpdaterProvider = Provider((ref) {
  final controllers = ref.read(volumeStreamControllersProvider);
  final usecase = ref.read(volumeUsecaseProvider);
  
  void updateTimeFrame(String timeFrame) {
    final controller = controllers[timeFrame];
    if (controller == null || controller.isClosed) return;
    
    final dataCache = ref.read(volumeDataCacheProvider);
    final volumeMap = dataCache[timeFrame] ?? <String, double>{};
    
    // ✅ 절대 시간 기준이므로 startTime 불필요 - 현재 시간 사용
    final now = DateTime.now();
    final volumes = usecase.calculateVolumeList(volumeMap, timeFrame, now);
    
    controller.add(VolumeEvent(volumes));
  }

  ref.listen(volumeDataCacheProvider, (previous, next) {
    for (final timeFrame in controllers.keys) {
      updateTimeFrame(timeFrame);
    }
  });

  return updateTimeFrame;
});

// ══════════════════════════════════════════════════════════════════════════════
// 🔵 Public API Layer (String 기반 + 즉시 캐시 로드로 끊김 방지)
// ══════════════════════════════════════════════════════════════════════════════

/// 멀티 스트림 + 즉시 캐시 데이터 제공 (끊김 방지)
final volumeDataProvider = StreamProvider<VolumeEvent>((ref) async* {
  ref.keepAlive();
  
  final timeFrame = ref.watch(volumeTimeFrameProvider);
  final controllers = ref.read(volumeStreamControllersProvider);
  final controller = controllers[timeFrame];
  
  if (controller == null) {
    log.e('💥 StreamController not found for $timeFrame');
    return;
  }

  // 메모리 최적화: 현재 시간대 활성화
  ref.read(volumeDataCacheProvider.notifier).setActiveTimeFrame(timeFrame);

  // 🚀 즉시 캐시 데이터 방출 (끊김 방지)
  final dataCache = ref.read(volumeDataCacheProvider);
  final cachedVolumeMap = dataCache[timeFrame] ?? {};
  
  if (cachedVolumeMap.isNotEmpty) {
    final usecase = ref.read(volumeUsecaseProvider);
    // ✅ 절대 시간 기준이므로 현재 시간 사용
    final now = DateTime.now();
    
    final volumes = usecase.calculateVolumeList(cachedVolumeMap, timeFrame, now);
    yield VolumeEvent(volumes); // 즉시 데이터 제공
  }

  // 업데이터 활성화
  ref.read(volumeTimeFrameUpdaterProvider);

  // 원시 볼륨 처리 스트림 활성화
  ref.listen(rawVolumeProcessingProvider, (previous, next) {
    next.when(
      data: (trade) => {},
      loading: () => {},
      error: (error, stack) => log.e('💥 Volume error: $error'),
    );
  });
  
  // 해당 시간대의 독립적인 스트림 반환 (멀티 스트림!)
  yield* controller.stream;
});

// ══════════════════════════════════════════════════════════════════════════════
// 🎛️ Controller Helper (단순 String 기반 + 개선된 리셋 시간 계산)
// ══════════════════════════════════════════════════════════════════════════════

final volumeTimeFrameController = Provider((ref) => VolumeTimeFrameController(ref));

class VolumeTimeFrameController {
  final Ref ref;
  VolumeTimeFrameController(this.ref);

  /// 시간대 설정 (String 기반) - 옛날 메서드명 유지
  void updateTimeFrame(String timeFrame, int index) {
    final timeFrames = VolumeConfig.supportedTimeFrames;
    if (index < 0 || index >= timeFrames.length) return;
    
    ref.read(volumeTimeFrameProvider.notifier).state = timeFrame;
    ref.read(volumeTimeFrameIndexProvider.notifier).state = index;
  }

  void resetCurrentTimeFrame() {
    final timeFrame = ref.read(volumeTimeFrameProvider);
    final dataCacheNotifier = ref.read(volumeDataCacheProvider.notifier);
    
    dataCacheNotifier.resetTimeFrame(timeFrame);
  }

  void resetAllTimeFrames() {
    final dataCacheNotifier = ref.read(volumeDataCacheProvider.notifier);
    
    dataCacheNotifier.resetAll();
  }

  /// ✅ 개선된 다음 리셋 시간 계산 (절대 시간 기준)
  DateTime? getNextResetTime() {
    final timeFrame = ref.read(volumeTimeFrameProvider);
    final now = DateTime.now();
    final minutes = int.tryParse(timeFrame.replaceAll('m', '')) ?? 1;

    // 절대 시간 기준으로 다음 리셋 시간 계산 (타이머와 동일한 로직)
    final currentChunkStartMinute = (now.minute ~/ minutes) * minutes;
    final startOfCurrentChunk = DateTime(
      now.year,
      now.month,
      now.day,
      now.hour,
      currentChunkStartMinute,
      0,
      0,
    );

    final nextResetTime = startOfCurrentChunk.add(Duration(minutes: minutes));
    
    // 이미 지난 시간이면 다음 사이클
    if (nextResetTime.isBefore(now)) {
      return nextResetTime.add(Duration(minutes: minutes));
    }
    
    return nextResetTime;
  }

  // 단순 Getter들
  String get currentTimeFrame => ref.read(volumeTimeFrameProvider);
  int get currentIndex => ref.read(volumeTimeFrameIndexProvider);
  List<String> get availableTimeFrames => VolumeConfig.supportedTimeFrames;
  
  String getTimeFrameName(String timeFrame) {
    final minutes = int.tryParse(timeFrame.replaceAll('m', ''));
    return AppConfig.timeFrameNames[minutes] ?? timeFrame;
  }
}