// lib/core/di/signal_provider.dart

import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../config/app_config.dart';
import '../utils/logger.dart';
import '../utils/pattern_detector.dart';
import '../utils/pattern_config.dart';
import '../utils/advanced_metrics.dart';
import 'trade_provider.dart'; // 전체 import (app_providers.dart 패턴)
import '../../data/repositories/signal_repository_impl.dart';
import '../../domain/entities/signal.dart';
import '../../domain/repositories/signal_repository.dart';
import '../../domain/usecases/signal_usecase.dart';

// ==========================================================================
// 🚀 V4.1 온라인 지표 의존성 주입 구조
// ==========================================================================

/// AdvancedMetrics Provider (온라인 계산기 관리)
final advancedMetricsProvider = Provider<AdvancedMetrics>((ref) {
  final metrics = AdvancedMetrics(
    maxGap: const Duration(seconds: 10),     // 스트림 끊김 감지 시간
    staleThreshold: const Duration(seconds: 30), // 데이터 만료 시간
  );
  
  // Provider dispose시 리소스 정리
  ref.onDispose(() {
    metrics.dispose();
    if (AppConfig.enableTradeLog) {
      log.i('🔥 AdvancedMetrics disposed - 온라인 지표 정리 완료');
    }
  });
  
  return metrics;
});

/// PatternConfig Provider (상태 관리 가능)
final patternConfigProvider = StateNotifierProvider<PatternConfigNotifier, PatternConfig>((ref) {
  return PatternConfigNotifier();
});

/// PatternDetector Provider (온라인 지표 의존성 주입)
final patternDetectorProvider = Provider<PatternDetector>((ref) {
  final config = ref.watch(patternConfigProvider);
  final metrics = ref.watch(advancedMetricsProvider);
  
  final detector = PatternDetector(
    config: config,
    metrics: metrics,
  );
  
  // Provider dispose시 리소스 정리
  ref.onDispose(() {
    detector.dispose();
    if (AppConfig.enableTradeLog) {
      log.i('🔥 PatternDetector disposed - 쿨다운 및 지표 정리 완료');
    }
  });
  
  return detector;
});

/// Signal Repository Provider (V4.1 온라인 지표 의존성 주입)
final signalRepoProvider = Provider<SignalRepository>((ref) {
  final remoteDS = ref.read(remoteDSProvider);
  final patternDetector = ref.watch(patternDetectorProvider);
  final patternConfig = ref.watch(patternConfigProvider);
  
  final repository = SignalRepositoryImpl(
    remoteDS,
    patternDetector: patternDetector,
    patternConfig: patternConfig,
  );
  
  // Provider dispose시 리소스 정리
  ref.onDispose(() async {
    await repository.dispose();
    if (AppConfig.enableTradeLog) {
      log.i('🔥 SignalRepository V4.1 disposed - 모든 리소스 정리 완료');
    }
  });
  
  return repository;
});

/// Signal UseCase Provider
final signalUsecaseProvider = Provider<SignalUseCase>((ref) {
  final repository = ref.read(signalRepoProvider);
  return SignalUseCase(repository);
});

// ==========================================================================
// 🎯 상태 관리 Providers (V4.1 확장)
// ==========================================================================

/// 현재 선택된 패턴 인덱스 (슬라이더 위치)
final signalPatternIndexProvider = StateProvider<int>((_) => 0);

/// 현재 선택된 패턴 타입
final signalPatternTypeProvider = StateProvider<PatternType>((ref) {
  final index = ref.watch(signalPatternIndexProvider);
  final patternName = AppConfig.getSignalPatternByIndex(index);
  
  // AppConfig 패턴명을 PatternType으로 변환
  switch (patternName) {
    case 'surge':
      return PatternType.surge;
    case 'flashFire':
      return PatternType.flashFire;
    case 'stackUp':
      return PatternType.stackUp;
    case 'stealthIn':
      return PatternType.stealthIn;
    case 'blackHole':
      return PatternType.blackHole;
    case 'reboundShot':
      return PatternType.reboundShot;
    default:
      return PatternType.surge; // 기본값
  }
});

/// 패턴별 임계값 관리 (V4.1 PatternConfig 기반)
final signalThresholdProvider = StateProvider.family<double, PatternType>((ref, pattern) {
  final config = ref.watch(patternConfigProvider);
  return config.getConfigValue(pattern, 'priceChangePercent');
});

/// 패턴별 활성화 상태 관리
final signalPatternEnabledProvider = StateProvider.family<bool, PatternType>((ref, pattern) => true);

/// 🆕 온라인 지표 건강성 모니터링
final onlineMetricsHealthProvider = StreamProvider.autoDispose<Map<String, dynamic>>((ref) async* {
  final metrics = ref.watch(advancedMetricsProvider);
  
  yield* Stream.periodic(const Duration(seconds: 5), (_) {
    return metrics.getSystemHealth();
  });
});

/// 🆕 시스템 성능 모니터링
final systemPerformanceProvider = StreamProvider.autoDispose<Map<String, dynamic>>((ref) async* {
  final repository = ref.watch(signalRepoProvider) as SignalRepositoryImpl;
  
  yield* repository.watchPerformanceMetrics();
});

// ==========================================================================
// 🔥 스트림 Providers (V4.1 온라인 지표 연동)
// ==========================================================================

/// 현재 패턴의 시그널 스트림 (온라인 지표 연동)
final signalListProvider = StreamProvider.autoDispose<List<Signal>>((ref) async* {
  // Prevent immediate dispose on loss of listeners
  ref.keepAlive();

  // 현재 선택된 패턴과 마켓 정보 구독
  final patternType = ref.watch(signalPatternTypeProvider);
  final repository = ref.read(signalRepoProvider);

  // marketsProvider에서 데이터 로드 (Trade와 동일한 패턴)
  final markets = await ref.watch(marketsProvider.future);

  // 패턴 변경 시 로그
  if (AppConfig.enableTradeLog) {
    log.i('🎯 Signal pattern changed to: ${patternType.displayName} (V4.1-Online)');
  }

  // 🆕 온라인 지표 상태 모니터링
  ref.listen(onlineMetricsHealthProvider, (prev, next) {
    if (next.hasValue) {
      final health = next.value!;
      final staleMarkets = health['staleMarkets'] ?? 0;
      if (staleMarkets > 0 && AppConfig.enableTradeLog) {
        log.w('⚠️ 온라인 지표 경고: $staleMarkets개 마켓 데이터 만료');
      }
    }
  });

  // 임계값 변경 감지 및 Repository 업데이트
  ref.listen<double>(signalThresholdProvider(patternType), (prev, next) {
    if (prev != null && prev != next) {
      if (AppConfig.enableTradeLog) {
        log.i('📊 Signal threshold changed: ${patternType.displayName} ${prev.toStringAsFixed(2)} → ${next.toStringAsFixed(2)}');
      }
      repository.updatePatternThreshold(patternType, next);
    }
  });

  // 패턴 활성화 상태 변경 감지
  ref.listen<bool>(signalPatternEnabledProvider(patternType), (prev, next) {
    if (prev != null && prev != next) {
      if (AppConfig.enableTradeLog) {
        log.i('🔄 Signal pattern ${next ? "enabled" : "disabled"}: ${patternType.displayName}');
      }
      repository.setPatternEnabled(patternType, next);
    }
  });

  // 패턴별 시그널 스트림 방출
  yield* repository.watchSignalsByPattern(patternType, markets);
});

/// 모든 패턴의 시그널 통합 스트림 (온라인 지표 연동)
final allSignalsProvider = StreamProvider.autoDispose<List<Signal>>((ref) async* {
  // Prevent dispose on background
  ref.keepAlive();
  
  final repository = ref.read(signalRepoProvider);
  
  // marketsProvider에서 데이터 로드 (Trade와 동일한 패턴)
  final markets = await ref.watch(marketsProvider.future);
  
  if (AppConfig.enableTradeLog) {
    log.i('🚀 All signals stream initialized with ${markets.length} markets (V4.1-Online)');
  }
  
  yield* repository.watchAllSignals(markets);
});

// ==========================================================================
// 🛠️ PatternConfig StateNotifier (V4.1 온라인 지표 설정 관리)
// ==========================================================================

class PatternConfigNotifier extends StateNotifier<PatternConfig> {
  PatternConfigNotifier() : super(PatternConfig());

  /// 특정 패턴의 설정값 업데이트
  void updatePatternConfig(PatternType pattern, String key, double value) {
    try {
      state.updatePatternConfig(pattern, key, value);
      // 상태 갱신을 위해 새 인스턴스 생성
      state = PatternConfig(customConfig: state.getAllPatternConfigs());
      
      if (AppConfig.enableTradeLog) {
        log.i('⚙️ Pattern config updated: ${pattern.name}.$key = $value');
      }
    } catch (e) {
      if (AppConfig.enableTradeLog) {
        log.e('❌ Pattern config update failed: $e');
      }
    }
  }

  /// 패턴 프리셋 적용
  void applyPreset(String presetName) {
    try {
      switch (presetName.toLowerCase()) {
        case 'conservative':
          state.applyConservativePreset();
          break;
        case 'aggressive':
          state.applyAggressivePreset();
          break;
        case 'balanced':
          state.applyBalancedPreset();
          break;
        default:
          throw ArgumentError('Unknown preset: $presetName');
      }
      
      // 상태 갱신
      state = PatternConfig(customConfig: state.getAllPatternConfigs());
      
      if (AppConfig.enableTradeLog) {
        log.i('🎯 Pattern preset applied: $presetName');
      }
    } catch (e) {
      if (AppConfig.enableTradeLog) {
        log.e('❌ Preset application failed: $e');
      }
    }
  }

  /// 설정 가져오기/내보내기
  void importConfig(Map<String, dynamic> config) {
    try {
      state.importConfig(config);
      state = PatternConfig(customConfig: state.getAllPatternConfigs());
      
      if (AppConfig.enableTradeLog) {
        log.i('📥 Pattern config imported successfully');
      }
    } catch (e) {
      if (AppConfig.enableTradeLog) {
        log.e('❌ Config import failed: $e');
      }
    }
  }

  Map<String, dynamic> exportConfig() {
    return state.exportConfig();
  }

  /// 기본값으로 리셋
  void resetToDefault([PatternType? pattern]) {
    state.resetToDefault(pattern);
    state = PatternConfig(customConfig: state.getAllPatternConfigs());
    
    if (AppConfig.enableTradeLog) {
      final message = pattern != null 
          ? 'Pattern ${pattern.name} reset to default'
          : 'All patterns reset to default';
      log.i('🔄 $message');
    }
  }
}

// ==========================================================================
// 🎮 Signal 패턴 컨트롤러 (V4.1 온라인 지표 확장)
// ==========================================================================

final signalPatternController = Provider((ref) => SignalPatternControllerV4(ref));

class SignalPatternControllerV4 {
  final Ref ref;
  SignalPatternControllerV4(this.ref);

  /// 패턴 인덱스 변경 (슬라이더 이동)
  void updatePatternIndex(int index) {
    final maxIndex = AppConfig.signalPatterns.length - 1;
    if (index < 0 || index > maxIndex) {
      if (AppConfig.enableTradeLog) {
        log.w('⚠️ Invalid pattern index: $index (max: $maxIndex)');
      }
      return;
    }

    ref.read(signalPatternIndexProvider.notifier).state = index;
    
    if (AppConfig.enableTradeLog) {
      final patternName = AppConfig.getSignalPatternByIndex(index);
      log.i('🎯 Pattern index updated: $index (${AppConfig.getSignalPatternName(patternName)})');
    }
  }

  /// 현재 패턴의 임계값 변경 (V4.1 PatternConfig 연동)
  void updateThreshold(double threshold) {
    final currentPattern = ref.read(signalPatternTypeProvider);
    
    // PatternConfig에도 반영
    ref.read(patternConfigProvider.notifier)
        .updatePatternConfig(currentPattern, 'priceChangePercent', threshold);
    
    // Provider 상태 업데이트
    ref.read(signalThresholdProvider(currentPattern).notifier).state = threshold;
  }

  /// 🆕 V4.1 고급 설정 업데이트
  void updatePatternConfig(PatternType pattern, String key, double value) {
    ref.read(patternConfigProvider.notifier).updatePatternConfig(pattern, key, value);
  }

  /// 🆕 프리셋 적용
  void applyPreset(String presetName) {
    ref.read(patternConfigProvider.notifier).applyPreset(presetName);
  }

  /// 패턴 활성화/비활성화
  void setPatternEnabled(PatternType pattern, bool enabled) {
    ref.read(signalPatternEnabledProvider(pattern).notifier).state = enabled;
  }

  /// 시그널 초기화
  void clearSignals([PatternType? pattern]) {
    final repository = ref.read(signalRepoProvider);
    repository.clearSignals(pattern);
    
    if (AppConfig.enableTradeLog) {
      final message = pattern != null 
          ? 'Signals cleared for pattern: ${pattern.displayName}'
          : 'All signals cleared';
      log.i('🧹 $message');
    }
  }

  /// 🆕 V4.1 온라인 지표 리셋
  void resetOnlineMetrics([String? market]) {
    final metrics = ref.read(advancedMetricsProvider);
    
    if (market != null) {
      metrics.resetMarket(market);
      if (AppConfig.enableTradeLog) {
        log.i('🔄 Online metrics reset for market: $market');
      }
    } else {
      metrics.resetAll();
      if (AppConfig.enableTradeLog) {
        log.i('🔄 All online metrics reset');
      }
    }
  }

  /// 🆕 V4.1 시스템 헬스 체크
  Future<Map<String, dynamic>> getSystemHealth() async {
    final repository = ref.read(signalRepoProvider) as SignalRepositoryImpl;
    return await repository.getSystemHealth();
  }

  /// 🆕 V4.1 패턴별 통계 (온라인 지표 포함)
  Future<Map<String, dynamic>> getPatternStats(PatternType pattern) async {
    final repository = ref.read(signalRepoProvider) as SignalRepositoryImpl;
    return await repository.getPatternStats(pattern);
  }

  /// 🆕 V4.1 온라인 지표 상태 조회
  Map<String, dynamic> getOnlineMetricsHealth() {
    final metricsHealth = ref.read(onlineMetricsHealthProvider);
    return metricsHealth.when(
      data: (health) => health,
      loading: () => {'status': 'loading'},
      error: (error, stack) => {'status': 'error', 'message': error.toString()},
    );
  }

  /// 🆕 V4.1 설정 내보내기/가져오기
  Map<String, dynamic> exportConfiguration() {
    final repository = ref.read(signalRepoProvider) as SignalRepositoryImpl;
    return repository.exportConfiguration();
  }

  void importConfiguration(Map<String, dynamic> config) {
    final repository = ref.read(signalRepoProvider) as SignalRepositoryImpl;
    repository.importConfiguration(config);
    
    if (AppConfig.enableTradeLog) {
      log.i('📥 Configuration imported successfully');
    }
  }

  /// 현재 상태 조회
  int get currentIndex => ref.read(signalPatternIndexProvider);
  PatternType get currentPattern => ref.read(signalPatternTypeProvider);
  double get currentThreshold => ref.read(signalThresholdProvider(currentPattern));
  bool get isCurrentPatternEnabled => ref.read(signalPatternEnabledProvider(currentPattern));

  /// 사용 가능한 패턴 정보
  List<String> get availablePatterns => AppConfig.signalPatterns;
  List<String> get patternDisplayNames => 
      AppConfig.signalPatterns.map((p) => AppConfig.getSignalPatternName(p)).toList();
  List<String> get patternDescriptions => 
      AppConfig.signalPatterns.map((p) => AppConfig.getSignalPatternDescription(p)).toList();

  /// V4.1 패턴별 기본 임계값 조회 (PatternConfig 기반)
  double getDefaultThreshold(PatternType pattern) {
    final config = ref.read(patternConfigProvider);
    return config.getConfigValue(pattern, 'priceChangePercent');
  }

  /// V4.1 패턴별 쿨다운 시간 조회
  Duration getCooldownDuration(PatternType pattern) {
    final config = ref.read(patternConfigProvider);
    return config.getCooldownDuration(pattern);
  }

  /// V4.1 패턴 설정 전체 조회
  Map<String, double> getPatternConfig(PatternType pattern) {
    final config = ref.read(patternConfigProvider);
    return config.getPatternConfig(pattern);
  }

  /// 패턴별 시간 윈도우 조회 (기존 호환성)
  int getTimeWindow(PatternType pattern) {
    final patternName = _getPatternConfigName(pattern);
    return AppConfig.getSignalTimeWindow(patternName);
  }

  /// 패턴 통계 조회 (V4.1 온라인 지표 확장)
  Map<String, dynamic> getPatternStatsOverview() {
    final allSignals = ref.read(allSignalsProvider).value ?? [];
    final patternCounts = <PatternType, int>{};
    
    for (final signal in allSignals) {
      patternCounts[signal.patternType] = 
          (patternCounts[signal.patternType] ?? 0) + 1;
    }
    
    // 온라인 지표 건강성 추가
    final onlineHealth = getOnlineMetricsHealth();
    
    return {
      'totalSignals': allSignals.length,
      'patternCounts': patternCounts,
      'lastUpdate': allSignals.isNotEmpty ? allSignals.first.detectedAt : null,
      'version': '4.1-Online',
      'onlineMetrics': onlineHealth,
    };
  }

  /// 🆕 V4.1 성능 모니터링 스트림
  Stream<Map<String, dynamic>> watchPerformanceMetrics() {
    final repository = ref.read(signalRepoProvider) as SignalRepositoryImpl;
    return repository.watchPerformanceMetrics();
  }

  /// 🆕 V4.1 온라인 지표 모니터링 스트림
  Stream<Map<String, dynamic>> watchOnlineMetricsHealth() {
    return Stream.periodic(const Duration(seconds: 5), (_) {
      final metrics = ref.read(advancedMetricsProvider);
      return metrics.getSystemHealth();
    });
  }
}

/// Helper function: PatternType을 AppConfig 패턴명으로 변환
String _getPatternConfigName(PatternType pattern) {
  switch (pattern) {
    case PatternType.surge:
      return 'surge';
    case PatternType.flashFire:
      return 'flashFire';
    case PatternType.stackUp:
      return 'stackUp';
    case PatternType.stealthIn:
      return 'stealthIn';
    case PatternType.blackHole:
      return 'blackHole';
    case PatternType.reboundShot:
      return 'reboundShot';
  }
}

// ==========================================================================
// 🔍 개발자용 디버깅 Providers
// ==========================================================================

/// 🆕 디버깅용 Provider - 전체 시스템 상태
final debugSystemStatusProvider = FutureProvider.autoDispose<Map<String, dynamic>>((ref) async {
  final controller = ref.watch(signalPatternController);
  final systemHealth = await controller.getSystemHealth();
  final onlineHealth = controller.getOnlineMetricsHealth();
  
  return {
    'timestamp': DateTime.now().toIso8601String(),
    'version': 'V4.1-Online-Debug',
    'systemHealth': systemHealth,
    'onlineMetrics': onlineHealth,
    'currentPattern': controller.currentPattern.name,
    'activeProviders': {
      'advancedMetrics': 'active',
      'patternDetector': 'active', 
      'signalRepository': 'active',
      'patternConfig': 'active',
    },
  };
});

/// Repository dispose 관리 (V4.1)
final signalRepositoryDisposeProvider = Provider.autoDispose<SignalRepository>((ref) {
  final repository = ref.watch(signalRepoProvider);
  
  ref.onDispose(() async {
    await repository.dispose();
    if (AppConfig.enableTradeLog) {
      log.i('🔥 Signal repository V4.1 disposed - 온라인 지표 포함 완전 정리');
    }
  });
  
  return repository;
});