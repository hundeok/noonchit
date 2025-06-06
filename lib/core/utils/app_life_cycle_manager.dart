// lib/core/utils/app_life_cycle_manager.dart
import 'dart:async';
import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../utils/logger.dart';

/// 앱 라이프사이클과 주기적인 작업을 관리합니다.
/// 🎯 Hive Box는 백그라운드에서도 유지 (닫지 않음)
/// 🆕 외부 접근을 위한 풀 기능 API 제공
class AppLifecycleManager extends WidgetsBindingObserver {
  final Ref ref;
  Timer? _globalTimer;
  
  // 🆕 외부 접근을 위한 상태 관리
  DateTime? _appStartTime;
  DateTime? _lastResumeTime;
  DateTime? _lastPauseTime;
  int _resumeCount = 0;
  int _pauseCount = 0;
  Duration _totalForegroundTime = Duration.zero;
  Duration _totalBackgroundTime = Duration.zero;
  AppLifecycleState _currentState = AppLifecycleState.resumed;
  
  // 🆕 라이프사이클 리스너들
  final List<void Function(AppLifecycleState)> _lifecycleListeners = [];
  
  // 🆕 성능 통계
  final Map<String, dynamic> _performanceStats = {};

  AppLifecycleManager(this.ref) {
    _appStartTime = DateTime.now();
    _lastResumeTime = _appStartTime;
    WidgetsBinding.instance.addObserver(this);
    _startGlobalTimer();
    log.i('🎬 AppLifecycleManager 초기화 완료');
  }

  // ══════════════════════════════════════════════════════════
  // 🆕 외부 접근 API들
  // ══════════════════════════════════════════════════════════

  /// 🆕 현재 앱 상태 조회
  AppLifecycleState get currentState => _currentState;

  /// 🆕 앱 시작 시간
  DateTime? get appStartTime => _appStartTime;

  /// 🆕 앱 가동 시간 (업타임)
  Duration get uptime {
    if (_appStartTime == null) return Duration.zero;
    return DateTime.now().difference(_appStartTime!);
  }

  /// 🆕 포그라운드 총 시간
  Duration get totalForegroundTime {
    var total = _totalForegroundTime;
    if (_currentState == AppLifecycleState.resumed && _lastResumeTime != null) {
      total += DateTime.now().difference(_lastResumeTime!);
    }
    return total;
  }

  /// 🆕 백그라운드 총 시간
  Duration get totalBackgroundTime {
    var total = _totalBackgroundTime;
    if (_currentState == AppLifecycleState.paused && _lastPauseTime != null) {
      total += DateTime.now().difference(_lastPauseTime!);
    }
    return total;
  }

  /// 🆕 이벤트 카운터들
  int get resumeCount => _resumeCount;
  int get pauseCount => _pauseCount;

  /// 🆕 마지막 상태 변경 시간
  DateTime? get lastStateChangeTime {
    switch (_currentState) {
      case AppLifecycleState.resumed:
        return _lastResumeTime;
      case AppLifecycleState.paused:
        return _lastPauseTime;
      default:
        return null;
    }
  }

  /// 🆕 라이프사이클 리스너 추가
  void addLifecycleListener(void Function(AppLifecycleState) listener) {
    _lifecycleListeners.add(listener);
    log.d('🎧 라이프사이클 리스너 추가됨 (총 ${_lifecycleListeners.length}개)');
  }

  /// 🆕 라이프사이클 리스너 제거
  void removeLifecycleListener(void Function(AppLifecycleState) listener) {
    _lifecycleListeners.remove(listener);
    log.d('🎧 라이프사이클 리스너 제거됨 (총 ${_lifecycleListeners.length}개)');
  }

  /// 🆕 수동 새로고침/정리 작업 강제 실행
  void forceRefresh() {
    log.i('🔄 수동 새로고침 실행');
    _performPeriodicTasks();
  }

  /// 🆕 메모리 정리 강제 실행
  void forceCleanup() {
    log.i('🧹 수동 메모리 정리 실행');
    _performMemoryCleanup();
  }

  /// 🆕 성능 통계 업데이트
  void updatePerformanceStats(String key, dynamic value) {
    _performanceStats[key] = value;
    _performanceStats['lastUpdated'] = DateTime.now().toIso8601String();
  }

  /// 🆕 메모리 상태 조회
  Map<String, dynamic> getMemoryStats() {
    return {
      'uptime': uptime.toString(),
      'foregroundTime': totalForegroundTime.toString(),
      'backgroundTime': totalBackgroundTime.toString(),
      'resumeCount': resumeCount,
      'pauseCount': pauseCount,
      'currentState': _currentState.name,
      'lastStateChange': lastStateChangeTime?.toIso8601String(),
      'platformMemoryUsage': _getPlatformMemoryInfo(),
      'timestamp': DateTime.now().toIso8601String(),
    };
  }

  /// 🆕 성능 통계 조회
  Map<String, dynamic> getPerformanceStats() {
    return Map.from(_performanceStats)
      ..addAll({
        'uptime': uptime.inSeconds,
        'foregroundTimeSeconds': totalForegroundTime.inSeconds,
        'backgroundTimeSeconds': totalBackgroundTime.inSeconds,
        'resumeCount': resumeCount,
        'pauseCount': pauseCount,
        'currentState': _currentState.name,
      });
  }

  /// 🆕 전체 시스템 상태 조회 (디버깅용)
  Map<String, dynamic> getSystemStatus() {
    return {
      'app': getMemoryStats(),
      'performance': getPerformanceStats(),
      'platform': {
        'os': Platform.operatingSystem,
        'version': Platform.operatingSystemVersion,
        'locale': Platform.localeName,
      },
      'listeners': {
        'lifecycleListeners': _lifecycleListeners.length,
      },
      'timers': {
        'globalTimerActive': _globalTimer?.isActive ?? false,
      },
    };
  }

  // ══════════════════════════════════════════════════════════
  // 기존 내부 로직들
  // ══════════════════════════════════════════════════════════

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    final previousState = _currentState;
    _currentState = state;
    
    _updateStateTimes(previousState, state);
    
    switch (state) {
      case AppLifecycleState.resumed:
        log.i('➡️ 앱이 포그라운드로 돌아왔습니다.');
        _resumeCount++;
        _lastResumeTime = DateTime.now();
        _startGlobalTimer();
        _onAppResumed();
        break;
        
      case AppLifecycleState.paused:
        log.i('⏸️ 앱이 백그라운드로 이동했습니다.');
        _pauseCount++;
        _lastPauseTime = DateTime.now();
        _stopGlobalTimer();
        _onAppPaused();
        break;
        
      case AppLifecycleState.detached:
        log.i('🔚 앱이 종료되었습니다.');
        _onAppDetached();
        break;
        
      case AppLifecycleState.inactive:
        log.d('😴 앱이 비활성 상태입니다.');
        break;
        
      case AppLifecycleState.hidden:
        log.d('🫥 앱이 숨김 상태입니다.');
        break;
    }
    
    // 🆕 외부 리스너들에게 알림
    _notifyLifecycleListeners(state);
  }

  /// 🆕 상태 전환 시간 업데이트
  void _updateStateTimes(AppLifecycleState from, AppLifecycleState to) {
    final now = DateTime.now();
    
    if (from == AppLifecycleState.resumed && _lastResumeTime != null) {
      _totalForegroundTime += now.difference(_lastResumeTime!);
    } else if (from == AppLifecycleState.paused && _lastPauseTime != null) {
      _totalBackgroundTime += now.difference(_lastPauseTime!);
    }
  }

  /// 🆕 라이프사이클 리스너들에게 알림
  void _notifyLifecycleListeners(AppLifecycleState state) {
    for (final listener in _lifecycleListeners) {
      try {
        listener(state);
      } catch (e, st) {
        log.e('라이프사이클 리스너 실행 중 오류', e, st);
      }
    }
  }

  /// 전역 타이머 시작
  void _startGlobalTimer() {
    if (_globalTimer == null || !_globalTimer!.isActive) {
      _globalTimer = Timer.periodic(const Duration(seconds: 30), (_) {
        _performPeriodicTasks();
      });
      log.i('⏰ 전역 타이머 시작: 30초 간격');
    }
  }

  /// 전역 타이머 중지
  void _stopGlobalTimer() {
    _globalTimer?.cancel();
    _globalTimer = null;
    log.d('⏹️ 전역 타이머 중지');
  }

  /// 주기적 작업 실행
  void _performPeriodicTasks() {
    log.d('🔄 전역 타이머: 주기적 작업 실행');
    
    // 여기에 주기적으로 실행할 작업들 추가
    // 예: 메모리 정리, 상태 체크, 백그라운드 동기화 등
    
    // 예시: 메모리 사용량 체크 (디버그 모드에서만)
    _checkMemoryUsage();
    
    // 🆕 성능 통계 업데이트
    updatePerformanceStats('lastPeriodicTaskRun', DateTime.now().toIso8601String());
  }

  /// 앱이 포그라운드로 돌아왔을 때
  void _onAppResumed() {
    log.i('📦 Hive Box 유지 - 백그라운드에서도 데이터 보존됨');
    
    // 포그라운드 복귀 시 필요한 작업들
    // 예: 연결 상태 확인, 데이터 새로고침 등
  }

  /// 앱이 백그라운드로 이동했을 때
  void _onAppPaused() {
    log.i('💾 백그라운드 진입 - 중요 데이터 보존 중');
    
    // 백그라운드 진입 시 필요한 작업들
    // 예: 임시 데이터 저장, 연결 정리 등
  }

  /// 앱이 완전히 종료될 때
  void _onAppDetached() {
    log.i('🧹 앱 종료 - 최종 정리 작업 수행');
    dispose();
  }

  /// 메모리 사용량 체크 (디버그용)
  void _checkMemoryUsage() {
    // 실제 구현은 플랫폼별로 다를 수 있음
    log.d('🧠 메모리 상태 체크 (개발 중)');
    
    // 🆕 플랫폼별 메모리 정보 수집
    final memInfo = _getPlatformMemoryInfo();
    updatePerformanceStats('memoryInfo', memInfo);
  }

  /// 🆕 메모리 정리 실행
  void _performMemoryCleanup() {
    // 실제 메모리 정리 로직
    log.i('🧹 메모리 정리 실행');
    
    // 예시: 가비지 컬렉션 강제 실행 (Dart에서는 제한적)
    // System.gc() 같은 것은 없지만, 불필요한 참조 정리 등을 할 수 있음
  }

  /// 🆕 플랫폼별 메모리 정보 수집
  Map<String, dynamic> _getPlatformMemoryInfo() {
    try {
      return {
        'platform': Platform.operatingSystem,
        'availableProcessors': Platform.numberOfProcessors,
        'timestamp': DateTime.now().toIso8601String(),
        // 실제 메모리 정보는 플랫폼 채널을 통해 구현 가능
        'note': 'Platform memory info implementation needed'
      };
    } catch (e) {
      return {'error': e.toString()};
    }
  }

  /// 정리 작업
  void dispose() {
    _stopGlobalTimer();
    WidgetsBinding.instance.removeObserver(this);
    _lifecycleListeners.clear();
    log.i('🧹 AppLifecycleManager 정리 완료');
  }
}

/// AppLifecycleManager 프로바이더
final appLifecycleManagerProvider = Provider<AppLifecycleManager>((ref) {
  final manager = AppLifecycleManager(ref);
  ref.onDispose(() => manager.dispose());
  return manager;
});