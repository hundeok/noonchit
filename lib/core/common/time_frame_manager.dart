// lib/core/common/time_frame_manager.dart

import 'dart:async';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../config/app_config.dart';
import '../utils/logger.dart';
import 'time_frame_types.dart';

// ══════════════════════════════════════════════════════════════════════════════
// 🕐 Global TimeFrame Manager (단일 타이머 시스템)
// ══════════════════════════════════════════════════════════════════════════════

/// 글로벌 시간대 관리자 (싱글톤 패턴)
class GlobalTimeFrameManager {
  static final GlobalTimeFrameManager _instance = GlobalTimeFrameManager._internal();
  factory GlobalTimeFrameManager() => _instance;
  GlobalTimeFrameManager._internal();

  // 각 TimeFrame별 타이머와 스트림 컨트롤러
  final Map<TimeFrame, Timer> _timers = {};
  final Map<TimeFrame, StreamController<TimeFrameResetEvent>> _controllers = {};
  final Map<TimeFrame, DateTime> _lastResetTimes = {};

  /// 특정 TimeFrame의 리셋 이벤트 스트림 구독
  Stream<TimeFrameResetEvent> getResetStream(TimeFrame timeFrame) {
    // 이미 존재하면 기존 스트림 반환
    if (_controllers.containsKey(timeFrame)) {
      return _controllers[timeFrame]!.stream;
    }

    // 새로운 스트림 컨트롤러 생성
    final controller = StreamController<TimeFrameResetEvent>.broadcast();
    _controllers[timeFrame] = controller;

    // 초기 리셋 시간 설정
    final now = DateTime.now();
    _lastResetTimes[timeFrame] = now;

    // 타이머 시작
    _startTimer(timeFrame);

    if (AppConfig.enableTradeLog) {
      log.i('🕐 Global timer started for ${timeFrame.displayName}');
    }

    return controller.stream;
  }

  /// TimeFrame용 타이머 시작 (기존 Volume/Surge 로직 사용)
  void _startTimer(TimeFrame timeFrame) {
    _scheduleNextReset(timeFrame);
  }

  /// 다음 리셋 스케줄링 (상대시간 기반)
  void _scheduleNextReset(TimeFrame timeFrame) {
    final now = DateTime.now();
    final lastReset = _lastResetTimes[timeFrame] ?? now;
    final nextReset = lastReset.add(timeFrame.duration);
    final delay = nextReset.difference(now);

    if (delay.isNegative) {
      // 이미 지난 시간이면 즉시 리셋
      _triggerReset(timeFrame);
      _scheduleNextReset(timeFrame);
    } else {
      // 다음 리셋까지 대기
      _timers[timeFrame] = Timer(delay, () {
        _triggerReset(timeFrame);
        _scheduleNextReset(timeFrame);
      });
    }
  }

  /// 리셋 이벤트 발생
  void _triggerReset(TimeFrame timeFrame) {
    final now = DateTime.now();
    _lastResetTimes[timeFrame] = now;

    final controller = _controllers[timeFrame];
    if (controller != null && !controller.isClosed) {
      final resetEvent = TimeFrameResetEvent(
        timeFrame: timeFrame,
        resetTime: now,
        nextResetTime: now.add(timeFrame.duration), // 상대시간으로 계산
      );
      controller.add(resetEvent);

      if (AppConfig.enableTradeLog) {
        log.i('🔄 Global reset triggered: ${timeFrame.displayName}');
      }
    }
  }

  /// 수동 리셋 (모든 TimeFrame)
  void resetAll() {
    final now = DateTime.now();
    
    for (final timeFrame in _controllers.keys) {
      _lastResetTimes[timeFrame] = now;
      final controller = _controllers[timeFrame];
      
      if (controller != null && !controller.isClosed) {
        final resetEvent = TimeFrameResetEvent(
          timeFrame: timeFrame,
          resetTime: now,
          nextResetTime: now.add(timeFrame.duration), // 상대시간으로 계산
        );
        controller.add(resetEvent);
      }
    }

    if (AppConfig.enableTradeLog) {
      log.i('🔄 Global manual reset: all timeframes');
    }
  }

  /// 특정 TimeFrame 수동 리셋
  void resetTimeFrame(TimeFrame timeFrame) {
    final now = DateTime.now();
    _lastResetTimes[timeFrame] = now;

    final controller = _controllers[timeFrame];
    if (controller != null && !controller.isClosed) {
      final resetEvent = TimeFrameResetEvent(
        timeFrame: timeFrame,
        resetTime: now,
        nextResetTime: now.add(timeFrame.duration), // 상대시간으로 계산
      );
      controller.add(resetEvent);

      if (AppConfig.enableTradeLog) {
        log.i('🔄 Global manual reset: ${timeFrame.displayName}');
      }
    }
  }

  /// 다음 리셋 시간 조회 (상대시간 기반)
  DateTime? getNextResetTime(TimeFrame timeFrame) {
    final lastReset = _lastResetTimes[timeFrame];
    if (lastReset == null) return null;
    
    return lastReset.add(timeFrame.duration);
  }

  /// 마지막 리셋 시간 조회
  DateTime? getLastResetTime(TimeFrame timeFrame) {
    return _lastResetTimes[timeFrame];
  }

  /// 리소스 정리
  void dispose() {
    // 모든 타이머 정리
    for (final timer in _timers.values) {
      timer.cancel();
    }
    _timers.clear();

    // 모든 스트림 컨트롤러 정리
    for (final controller in _controllers.values) {
      if (!controller.isClosed) {
        controller.close();
      }
    }
    _controllers.clear();
    _lastResetTimes.clear();

    if (AppConfig.enableTradeLog) {
      log.i('🛑 Global TimeFrame Manager disposed');
    }
  }

  /// 현재 활성 TimeFrame 목록
  List<TimeFrame> get activeTimeFrames => _controllers.keys.toList();

  /// 디버그 정보
  Map<String, dynamic> get debugInfo => {
    'activeTimeFrames': activeTimeFrames.map((tf) => tf.displayName).toList(),
    'activeTimers': _timers.length,
    'lastResetTimes': _lastResetTimes.map(
      (tf, time) => MapEntry(tf.displayName, time.toIso8601String()),
    ),
  };
}

// ══════════════════════════════════════════════════════════════════════════════
// 🎯 Providers
// ══════════════════════════════════════════════════════════════════════════════

/// 글로벌 TimeFrame 관리자 Provider
final globalTimeFrameManagerProvider = Provider<GlobalTimeFrameManager>((ref) {
  final manager = GlobalTimeFrameManager();
  
  ref.onDispose(() {
    manager.dispose();
  });
  
  return manager;
});

/// TimeFrame별 리셋 이벤트 스트림 Provider
final timeFrameResetStreamProvider = StreamProvider.family<TimeFrameResetEvent, TimeFrame>((ref, timeFrame) {
  final manager = ref.read(globalTimeFrameManagerProvider);
  return manager.getResetStream(timeFrame);
});

/// 선택된 TimeFrame Provider (Volume용)
final volumeSelectedTimeFrameProvider = StateProvider<TimeFrame>((ref) => TimeFrame.min1);

/// 선택된 TimeFrame Provider (Surge용)  
final surgeSelectedTimeFrameProvider = StateProvider<TimeFrame>((ref) => TimeFrame.min1);

/// 공통 처리 설정 Provider
final commonProcessingConfigProvider = Provider<ProcessingConfig>((ref) {
  return const ProcessingConfig(
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

/// TimeFrame 컨트롤러 Provider
final globalTimeFrameControllerProvider = Provider((ref) => GlobalTimeFrameController(ref));

// ══════════════════════════════════════════════════════════════════════════════
// 🎛️ Global TimeFrame Controller
// ══════════════════════════════════════════════════════════════════════════════

class GlobalTimeFrameController {
  final Ref _ref;
  
  GlobalTimeFrameController(this._ref);

  /// Volume 시간대 변경
  void setVolumeTimeFrame(TimeFrame timeFrame) {
    _ref.read(volumeSelectedTimeFrameProvider.notifier).state = timeFrame;
    
    if (AppConfig.enableTradeLog) {
      log.i('🔄 Volume TimeFrame changed: ${timeFrame.displayName}');
    }
  }

  /// Surge 시간대 변경
  void setSurgeTimeFrame(TimeFrame timeFrame) {
    _ref.read(surgeSelectedTimeFrameProvider.notifier).state = timeFrame;
    
    if (AppConfig.enableTradeLog) {
      log.i('🔄 Surge TimeFrame changed: ${timeFrame.displayName}');
    }
  }

  /// 모든 TimeFrame 리셋
  void resetAllTimeFrames() {
    final manager = _ref.read(globalTimeFrameManagerProvider);
    manager.resetAll();
  }

  /// 특정 TimeFrame 리셋
  void resetTimeFrame(TimeFrame timeFrame) {
    final manager = _ref.read(globalTimeFrameManagerProvider);
    manager.resetTimeFrame(timeFrame);
  }

  /// 다음 리셋 시간 조회
  DateTime? getNextResetTime(TimeFrame timeFrame) {
    final manager = _ref.read(globalTimeFrameManagerProvider);
    return manager.getNextResetTime(timeFrame);
  }

  // ══════════════════════════════════════════════════════════════════════════════
  // Getters
  // ══════════════════════════════════════════════════════════════════════════════

  TimeFrame get currentVolumeTimeFrame => _ref.read(volumeSelectedTimeFrameProvider);
  TimeFrame get currentSurgeTimeFrame => _ref.read(surgeSelectedTimeFrameProvider);
  
  List<TimeFrame> get availableTimeFrames => TimeFrame.fromAppConfig();
  
  int getVolumeTimeFrameIndex() {
    return availableTimeFrames.indexOf(currentVolumeTimeFrame);
  }
  
  int getSurgeTimeFrameIndex() {
    return availableTimeFrames.indexOf(currentSurgeTimeFrame);
  }
  
  String getTimeFrameName(TimeFrame timeFrame) => timeFrame.displayName;
}