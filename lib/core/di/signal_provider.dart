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
// 🚀 Clean Architecture V4.1 - 단방향 데이터 흐름 + PatternConfig 공유
// ==========================================================================

/// AdvancedMetrics Provider (온라인 계산기 관리)
final advancedMetricsProvider = Provider<AdvancedMetrics>((ref) {
  final metrics = AdvancedMetrics(
    maxGap: const Duration(seconds: 10),
    staleThreshold: const Duration(seconds: 30),
  );
  
  ref.onDispose(() {
    metrics.dispose();
    if (AppConfig.enableTradeLog) {
      log.i('🔥 AdvancedMetrics disposed');
    }
  });
  
  return metrics;
});

/// 🆕 PatternConfig Provider (단일 진실의 원천)
/// Repository와 PatternDetector가 동일한 인스턴스를 공유하도록 분리
final patternConfigProvider = Provider<PatternConfig>((ref) {
  return PatternConfig(); // 단일 인스턴스
});

/// Signal Repository Provider (단일 진실의 원천)
final signalRepoProvider = Provider<SignalRepository>((ref) {
  final remoteDS = ref.read(remoteDSProvider);
  final metrics = ref.watch(advancedMetricsProvider);
  
  // ✅ 공유된 PatternConfig 인스턴스 사용
  final sharedPatternConfig = ref.watch(patternConfigProvider);
  
  // ✅ PatternDetector를 Repository 내부에서 생성하여 동일한 config 공유
  final patternDetector = PatternDetector(
    config: sharedPatternConfig, // ✅ 공유된 config 사용
    metrics: metrics,
  );
  
  // ✅ Repository도 동일한 config 인스턴스 사용
  final repository = SignalRepositoryImpl(
    remoteDS,
    patternDetector: patternDetector,
    patternConfig: sharedPatternConfig, // ✅ 동일한 인스턴스!
  );
  
  ref.onDispose(() async {
    // PatternDetector도 함께 dispose
    patternDetector.dispose();
    await repository.dispose();
    if (AppConfig.enableTradeLog) {
      log.i('🔥 SignalRepository & PatternDetector disposed - Clean Architecture');
    }
  });
  
  return repository;
});

/// Signal UseCase Provider (비즈니스 로직 계층)
final signalUsecaseProvider = Provider<SignalUseCase>((ref) {
  final repository = ref.read(signalRepoProvider);
  return SignalUseCase(repository);
});

// ==========================================================================
// 🎯 UI 상태 관리 Providers (최소화)
// ==========================================================================

/// 현재 선택된 패턴 인덱스 (슬라이더 위치만)
final signalPatternIndexProvider = StateProvider<int>((_) => 0);

/// 현재 선택된 패턴 타입 (UI 표시용)
final signalPatternTypeProvider = StateProvider<PatternType>((ref) {
  final index = ref.watch(signalPatternIndexProvider);
  final patternName = AppConfig.getSignalPatternByIndex(index);
  
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
      return PatternType.surge;
  }
});

/// 패턴별 활성화 상태 관리 (UI 동기화용)
final signalPatternEnabledProvider = StateProvider.family<bool, PatternType>((ref, pattern) => false);

/// 통합 On/Off 스위치 Provider
final isAnyPatternActiveProvider = Provider<bool>((ref) {
  for (final pattern in PatternType.values) {
    if (ref.watch(signalPatternEnabledProvider(pattern))) {
      return true;
    }
  }
  return false;
});

// ==========================================================================
// 🔥 스트림 Providers (단순화)
// ==========================================================================

/// 패턴별 시그널 스트림을 독립적으로 제공
final signalsByPatternProvider =
    StreamProvider.family.autoDispose<List<Signal>, PatternType>((ref, patternType) async* {

  final isPatternEnabled = ref.watch(signalPatternEnabledProvider(patternType));
  if (!isPatternEnabled) {
    yield [];
    return;
  }

  final repository = ref.read(signalRepoProvider);
  final markets = await ref.watch(marketsProvider.future);

  if (AppConfig.enableTradeLog) {
    log.i('🎯 Starting stream for pattern: ${patternType.displayName} (Clean)');
  }

  // 🔧 패턴 활성화 상태 변경 감지 및 Repository 직접 업데이트
  ref.listen<bool>(signalPatternEnabledProvider(patternType), (prev, next) {
    if (prev != null && prev != next) {
      if (AppConfig.enableTradeLog) {
        log.i('🔄 Pattern ${next ? "enabled" : "disabled"}: ${patternType.displayName}');
      }
      repository.setPatternEnabled(patternType, next);
    }
  });

  yield* repository.watchSignalsByPattern(patternType, markets);
});

/// 현재 패턴의 시그널 스트림 (호환성)
// ✅ 더 깔끔한 해결법
final signalListProvider = StreamProvider.autoDispose<List<Signal>>((ref) {
  final currentPattern = ref.watch(signalPatternTypeProvider);
  
  // 직접 signalsByPatternProvider의 스트림을 반환
  return ref.watch(signalsByPatternProvider(currentPattern).future).asStream().asyncExpand(
    (signals) => Stream.value(signals),
  );
});

/// 모든 패턴의 시그널 통합 스트림
final allSignalsProvider = StreamProvider.autoDispose<List<Signal>>((ref) async* {
  final isAnyActive = ref.watch(isAnyPatternActiveProvider);
  if (!isAnyActive) {
    yield [];
    return;
  }

  ref.keepAlive();
  
  final repository = ref.read(signalRepoProvider);
  final markets = await ref.watch(marketsProvider.future);
  
  if (AppConfig.enableTradeLog) {
    log.i('🚀 All signals stream initialized (Clean Architecture)');
  }
  
  yield* repository.watchAllSignals(markets);
});

// ==========================================================================
// 🆕 모니터링 Providers (간소화)
// ==========================================================================

/// 온라인 지표 건강성 모니터링
final onlineMetricsHealthProvider = StreamProvider.autoDispose<Map<String, dynamic>>((ref) async* {
  final isAnyActive = ref.watch(isAnyPatternActiveProvider);
  if (!isAnyActive) {
    yield {'status': 'inactive', 'message': '모든 패턴이 비활성 상태입니다.'};
    return;
  }
  
  final metrics = ref.watch(advancedMetricsProvider);
  
  yield* Stream.periodic(const Duration(seconds: 5), (_) {
    return metrics.getSystemHealth();
  });
});

/// 시스템 성능 모니터링
final systemPerformanceProvider = StreamProvider.autoDispose<Map<String, dynamic>>((ref) async* {
  final isAnyActive = ref.watch(isAnyPatternActiveProvider);
  if (!isAnyActive) {
    yield {'status': 'inactive', 'message': '시스템 모니터링이 비활성 상태입니다.'};
    return;
  }
  
  final repository = ref.watch(signalRepoProvider) as SignalRepositoryImpl;
  
  yield* repository.watchPerformanceMetrics();
});

// ==========================================================================
// 🔍 개발자용 디버깅 (간소화)
// ==========================================================================

/// Repository dispose 관리
final signalRepositoryDisposeProvider = Provider.autoDispose<SignalRepository>((ref) {
  final repository = ref.watch(signalRepoProvider);
  
  ref.onDispose(() async {
    await repository.dispose();
    if (AppConfig.enableTradeLog) {
      log.i('🔥 Signal repository disposed - Clean Architecture');
    }
  });
  
  return repository;
});

// ==========================================================================
// 🆕 디버깅용 PatternConfig 상태 조회 Provider
// ==========================================================================

/// 🛠️ 개발/디버깅용: PatternConfig 상태 실시간 모니터링
final patternConfigDebugProvider = Provider<Map<String, dynamic>>((ref) {
  final config = ref.watch(patternConfigProvider);
  
  return {
    'version': '4.1-Fixed',
    'timestamp': DateTime.now().toIso8601String(),
    'configInstanceId': config.hashCode.toString(),
    'allConfigs': config.getAllPatternConfigs(),
    'summary': config.getConfigSummary(),
    'message': 'PatternConfig instance is now properly shared between Repository and PatternDetector',
    'fix': 'Single PatternConfig instance ensures threshold changes are immediately reflected in pattern detection',
  };
});