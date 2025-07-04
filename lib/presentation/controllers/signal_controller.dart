// lib/presentation/controllers/signal_controller.dart

import 'dart:async';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../core/config/app_config.dart';
import '../../core/di/signal_provider.dart';
import '../../core/error/app_exception.dart';
import '../../core/extensions/result.dart';
import '../../core/utils/logger.dart';
import '../../domain/entities/signal.dart';
import '../../domain/usecases/signal_usecase.dart';

/// 🚀 Signal 화면 상태를 캡슐화하는 immutable 모델 V4.1
class SignalState {
  final List<Signal> signals;
  final bool isLoading;
  final bool isConnected;
  final PatternType currentPattern;
  final int selectedIndex;
  final double threshold;
  final bool isPatternEnabled;
  final String? errorMessage;
  final Map<String, dynamic>? systemHealth; // 🆕 V4.1
  final Map<String, dynamic>? onlineMetricsHealth; // 🆕 V4.1
  final String sortField; // 🆕 V4.1
  final bool sortAscending; // 🆕 V4.1

  const SignalState({
    this.signals = const [],
    this.isLoading = false,
    this.isConnected = false,
    this.currentPattern = PatternType.surge,
    this.selectedIndex = 0,
    this.threshold = 0.4,
    this.isPatternEnabled = true,
    this.errorMessage,
    this.systemHealth,
    this.onlineMetricsHealth,
    this.sortField = 'time',
    this.sortAscending = false,
  });

  /// 🆕 V4.1 온라인 지표 연결 상태
  bool get hasOnlineMetrics => onlineMetricsHealth != null;
  
  /// 🆕 V4.1 시스템 건강성
  bool get isSystemHealthy => 
      systemHealth?['status'] == 'healthy' && 
      (onlineMetricsHealth?['staleMarkets'] ?? 0) == 0;

  /// 🆕 V4.1 신호 통계
  Map<String, dynamic> get signalStats {
    final total = signals.length;
    final withOnlineMetrics = signals.where((s) => s.hasOnlineMetrics).length;
    final avgConfidence = signals.isNotEmpty 
        ? signals.map((s) => s.confidence ?? 0.0).reduce((a, b) => a + b) / total
        : 0.0;
    
    return {
      'total': total,
      'withOnlineMetrics': withOnlineMetrics,
      'onlineMetricsRatio': total > 0 ? withOnlineMetrics / total : 0.0,
      'avgConfidence': avgConfidence,
      'pattern': currentPattern.displayName,
    };
  }

  SignalState copyWith({
    List<Signal>? signals,
    bool? isLoading,
    bool? isConnected,
    PatternType? currentPattern,
    int? selectedIndex,
    double? threshold,
    bool? isPatternEnabled,
    String? errorMessage,
    Map<String, dynamic>? systemHealth,
    Map<String, dynamic>? onlineMetricsHealth,
    String? sortField,
    bool? sortAscending,
  }) {
    return SignalState(
      signals: signals ?? this.signals,
      isLoading: isLoading ?? this.isLoading,
      isConnected: isConnected ?? this.isConnected,
      currentPattern: currentPattern ?? this.currentPattern,
      selectedIndex: selectedIndex ?? this.selectedIndex,
      threshold: threshold ?? this.threshold,
      isPatternEnabled: isPatternEnabled ?? this.isPatternEnabled,
      errorMessage: errorMessage,
      systemHealth: systemHealth ?? this.systemHealth,
      onlineMetricsHealth: onlineMetricsHealth ?? this.onlineMetricsHealth,
      sortField: sortField ?? this.sortField,
      sortAscending: sortAscending ?? this.sortAscending,
    );
  }
}

/// 🚀 Signal 화면 전용 ViewModel V4.1 - 온라인 지표 연동
class SignalController extends StateNotifier<SignalState> {
  final SignalUseCase _usecase;
  final Ref _ref;
  StreamSubscription<Result<List<Signal>, AppException>>? _subscription;
  StreamSubscription<Map<String, dynamic>>? _healthSubscription; // 🆕 V4.1
  Timer? _healthUpdateTimer; // 🆕 V4.1

  SignalController(this._usecase, this._ref) : super(const SignalState()) {
    _startSystemHealthMonitoring(); // 🆕 V4.1
  }

  // ==========================================================================
  // 🆕 V4.1 시스템 건강성 모니터링
  // ==========================================================================

  /// 🆕 시스템 헬스 모니터링 시작
  void _startSystemHealthMonitoring() {
    _healthUpdateTimer = Timer.periodic(const Duration(seconds: 10), (_) {
      _updateSystemHealth();
      _updateOnlineMetricsHealth();
    });
  }

  /// 🆕 시스템 헬스 업데이트
  void _updateSystemHealth() async {
    try {
      final controller = _ref.read(signalPatternController);
      final health = await controller.getSystemHealth();
      
      state = state.copyWith(systemHealth: health);
      
      if (AppConfig.enableTradeLog) {
        final staleMarkets = health['onlineMetricsSystem']?['staleMarkets'] ?? 0;
        if (staleMarkets > 0) {
          log.w('⚠️ Signal Controller: $staleMarkets개 마켓 온라인 지표 만료');
        }
      }
    } catch (e) {
      if (AppConfig.enableTradeLog) {
        log.w('Signal Controller: System health update failed - $e');
      }
    }
  }

  /// 🆕 온라인 지표 헬스 업데이트
  void _updateOnlineMetricsHealth() {
    try {
      final controller = _ref.read(signalPatternController);
      final health = controller.getOnlineMetricsHealth();
      
      state = state.copyWith(onlineMetricsHealth: health);
    } catch (e) {
      if (AppConfig.enableTradeLog) {
        log.w('Signal Controller: Online metrics health update failed - $e');
      }
    }
  }

  // ==========================================================================
  // 기본 패턴 관리 (기존 + V4.1 개선)
  // ==========================================================================

  /// 패턴 인덱스 변경 (슬라이더 이동) - V4.1 개선
  void setPatternIndex(int index, List<String> markets) {
    if (index < 0 || index >= PatternType.values.length) {
      if (AppConfig.enableTradeLog) {
        log.w('Invalid pattern index: $index');
      }
      return;
    }

    final patternType = PatternType.values[index];
    final defaultThreshold = patternType.defaultThreshold; // V4.1 기본값

    // Provider 상태 업데이트
    final controller = _ref.read(signalPatternController);
    controller.updatePatternIndex(index);

    state = state.copyWith(
      currentPattern: patternType,
      selectedIndex: index,
      threshold: defaultThreshold,
      isLoading: true,
      errorMessage: null,
    );

    // 스트림 재구독
    _subscribeToPattern(patternType, markets);
    
    if (AppConfig.enableTradeLog) {
      log.i('🎯 Pattern changed to: ${patternType.displayName} (V4.1)');
    }
  }

  /// 현재 패턴의 임계값 변경 - V4.1 개선
  void updateThreshold(double threshold) {
    try {
      // UseCase를 통한 검증된 업데이트
      _usecase.updatePatternThreshold(state.currentPattern, threshold);
      
      final controller = _ref.read(signalPatternController);
      controller.updateThreshold(threshold);

      state = state.copyWith(threshold: threshold);
      
      if (AppConfig.enableTradeLog) {
        log.i('📊 Threshold updated: ${state.currentPattern.displayName} → $threshold');
      }
    } catch (e) {
      if (AppConfig.enableTradeLog) {
        log.e('❌ Threshold update failed: $e');
      }
      
      // 에러를 사용자에게 표시
      state = state.copyWith(
        errorMessage: 'Invalid threshold value: ${e.toString()}'
      );
    }
  }

  /// 패턴 활성화/비활성화 토글 - V4.1 개선
  void togglePatternEnabled() {
    final newEnabled = !state.isPatternEnabled;
    
    _usecase.setPatternEnabled(state.currentPattern, newEnabled);
    
    final controller = _ref.read(signalPatternController);
    controller.setPatternEnabled(state.currentPattern, newEnabled);

    state = state.copyWith(isPatternEnabled: newEnabled);
    
    if (AppConfig.enableTradeLog) {
      log.i('🔄 Pattern ${newEnabled ? "enabled" : "disabled"}: ${state.currentPattern.displayName}');
    }
  }

  /// 시그널 목록 초기화 - V4.1 개선
  void clearSignals([PatternType? pattern]) {
    final controller = _ref.read(signalPatternController);
    controller.clearSignals(pattern);

    if (pattern == null || pattern == state.currentPattern) {
      state = state.copyWith(signals: []);
    }
    
    if (AppConfig.enableTradeLog) {
      final patternName = pattern?.displayName ?? 'All patterns';
      log.i('🧹 Signals cleared: $patternName');
    }
  }

  // ==========================================================================
  // 🆕 V4.1 고급 패턴 설정
  // ==========================================================================

  /// 🆕 고급 패턴 설정 업데이트
  void updateAdvancedPatternConfig(String key, double value) {
    try {
      _usecase.updateAdvancedPatternConfig(state.currentPattern, key, value);
      
      if (AppConfig.enableTradeLog) {
        log.i('⚙️ Advanced config updated: ${state.currentPattern.name}.$key = $value');
      }
    } catch (e) {
      if (AppConfig.enableTradeLog) {
        log.e('❌ Advanced config update failed: $e');
      }
      
      state = state.copyWith(
        errorMessage: 'Configuration update failed: ${e.toString()}'
      );
    }
  }

  /// 🆕 패턴 프리셋 적용
  void applyPreset(String presetName) {
    try {
      _usecase.applyPatternPreset(presetName);
      
      // 현재 패턴의 임계값도 업데이트
      final newThreshold = _usecase.getPatternThreshold(state.currentPattern);
      state = state.copyWith(threshold: newThreshold);
      
      if (AppConfig.enableTradeLog) {
        log.i('🎯 Preset applied: $presetName');
      }
    } catch (e) {
      if (AppConfig.enableTradeLog) {
        log.e('❌ Preset application failed: $e');
      }
      
      state = state.copyWith(
        errorMessage: 'Preset application failed: ${e.toString()}'
      );
    }
  }

  /// 🆕 온라인 지표 리셋
  void resetOnlineMetrics([String? market]) {
    final controller = _ref.read(signalPatternController);
    controller.resetOnlineMetrics(market);
    
    // 헬스 상태 즉시 업데이트
    _updateOnlineMetricsHealth();
    
    if (AppConfig.enableTradeLog) {
      final target = market ?? 'all markets';
      log.i('🔄 Online metrics reset: $target');
    }
  }

  // ==========================================================================
  // 스트림 관리 (V4.1 개선)
  // ==========================================================================

  /// 패턴별 시그널 스트림 구독 - V4.1 개선
  void _subscribeToPattern(PatternType patternType, List<String> markets) {
    _subscription?.cancel();
    
    _subscription = _usecase
        .watchSignalsByPattern(patternType, markets)
        .map((signals) => Ok<List<Signal>, AppException>(signals))
        .handleError((error) => Err<List<Signal>, AppException>(
            AppException(
              'Signal pattern detection failed: ${error.toString()}',
              code: 'SIGNAL_PATTERN_ERROR',
              originalException: error is Exception ? error : null,
            )))
        .listen(_handleResult);
  }

  void _handleResult(Result<List<Signal>, AppException> result) {
    result.when(
      ok: (signals) {
        // V4.1 정렬 적용
        final sortedSignals = _applySorting(signals);
        
        state = state.copyWith(
          signals: sortedSignals,
          isLoading: false,
          isConnected: true,
          errorMessage: null,
        );
        
        // 온라인 지표 통계 로깅
        if (AppConfig.enableTradeLog && signals.isNotEmpty) {
          final withOnlineMetrics = signals.where((s) => s.hasOnlineMetrics).length;
          final ratio = (withOnlineMetrics / signals.length * 100).toStringAsFixed(1);
          log.i('📊 Signals received: ${signals.length}, Online metrics: $withOnlineMetrics ($ratio%)');
        }
      },
      err: (e) {
        state = state.copyWith(
          isLoading: false,
          isConnected: false,
          errorMessage: e.message,
        );
        
        if (AppConfig.enableTradeLog) {
          log.e('❌ Signal stream error: ${e.message}');
        }
      },
    );
  }

  /// 재연결/새로고침 - V4.1 개선
  void refresh(List<String> markets) {
    if (AppConfig.enableTradeLog) {
      log.i('🔄 Signal refresh requested for ${markets.length} markets');
    }
    
    // 온라인 지표 상태도 리셋
    resetOnlineMetrics();
    
    // 패턴 재구독
    setPatternIndex(state.selectedIndex, markets);
  }

  // ==========================================================================
  // 🆕 V4.1 정렬 및 필터링
  // ==========================================================================

  /// 🆕 정렬 필드 변경
  void setSortField(String field, {bool? ascending}) {
    final newAscending = ascending ?? (state.sortField == field ? !state.sortAscending : false);
    
    state = state.copyWith(
      sortField: field,
      sortAscending: newAscending,
      signals: _applySorting(state.signals),
    );
    
    if (AppConfig.enableTradeLog) {
      log.i('📊 Sort changed: $field (${newAscending ? "ASC" : "DESC"})');
    }
  }

  /// 🆕 정렬 적용
  List<Signal> _applySorting(List<Signal> signals) {
    final list = List<Signal>.from(signals);
    
    list.sort((a, b) {
      dynamic aValue;
      dynamic bValue;
      
      switch (state.sortField) {
        case 'market':
          aValue = a.market;
          bValue = b.market;
          break;
        case 'price':
          aValue = a.currentPrice;
          bValue = b.currentPrice;
          break;
        case 'change':
          aValue = a.changePercent.abs();
          bValue = b.changePercent.abs();
          break;
        case 'amount':
          aValue = a.tradeAmount;
          bValue = b.tradeAmount;
          break;
        case 'confidence':
          aValue = a.confidence ?? 0.0;
          bValue = b.confidence ?? 0.0;
          break;
        case 'time':
        default:
          aValue = a.detectedAt.millisecondsSinceEpoch;
          bValue = b.detectedAt.millisecondsSinceEpoch;
      }
      
      final cmp = aValue is Comparable && bValue is Comparable
          ? aValue.compareTo(bValue)
          : 0;
      
      return state.sortAscending ? cmp : -cmp;
    });
    
    return list;
  }

  /// 🆕 고급 필터링 (V4.1)
  List<Signal> filterSignals({
    String? marketFilter,
    double? minConfidence,
    bool? requireOnlineMetrics,
    Set<PatternType>? patternTypes,
    Duration? timeWindow,
  }) {
    return _usecase.filterSignals(
      state.signals,
      markets: marketFilter != null ? {marketFilter.toUpperCase()} : null,
      minConfidence: minConfidence,
      requireOnlineMetrics: requireOnlineMetrics,
      patternTypes: patternTypes,
      timeWindow: timeWindow,
    );
  }

  // ==========================================================================
  // 표시 텍스트 생성 (V4.1 개선)
  // ==========================================================================

  /// 현재 패턴 표시 텍스트 생성 - V4.1 개선
  String getPatternDisplayText() {
    final pattern = state.currentPattern;
    return '${pattern.displayName}: ${pattern.description}';
  }

  /// 현재 패턴 아이콘/이모지
  String getPatternIcon() {
    return state.currentPattern.displayName;
  }

  /// 임계값 표시 텍스트 - V4.1 개선
  String getThresholdDisplayText() {
    final threshold = state.threshold;
    final pattern = state.currentPattern;

    switch (pattern) {
      case PatternType.surge:
        return '${threshold.toStringAsFixed(1)}% 상승';
      case PatternType.flashFire:
        return '${threshold.toStringAsFixed(1)}배 급증';
      case PatternType.stackUp:
        return '${threshold.toInt()}연속 증가';
      case PatternType.stealthIn:
        final amountText = threshold >= 1000000 
            ? '${(threshold / 1000000).toStringAsFixed(0)}백만원'
            : '${threshold.toStringAsFixed(0)}원';
        return '$amountText 이상';
      case PatternType.blackHole:
        return '${threshold.toStringAsFixed(1)}% 이하 변동';
      case PatternType.reboundShot:
        return '${threshold.toStringAsFixed(1)}% 급락 후 반등';
    }
  }

  /// 🆕 시스템 상태 표시 텍스트
  String getSystemStatusText() {
    if (!state.hasOnlineMetrics) return 'Online metrics: Connecting...';
    
    final health = state.onlineMetricsHealth!;
    final totalMarkets = health['totalMarkets'] ?? 0;
    final healthyMarkets = health['healthyMarkets'] ?? 0;
    final staleMarkets = health['staleMarkets'] ?? 0;
    
    if (staleMarkets > 0) {
      return 'Online metrics: $healthyMarkets/$totalMarkets healthy ($staleMarkets stale)';
    }
    
    return 'Online metrics: $healthyMarkets/$totalMarkets healthy ✅';
  }

  /// 🆕 신뢰도 상태 표시
  String getConfidenceStatusText() {
    final stats = state.signalStats;
    final avgConf = stats['avgConfidence'] as double;
    final onlineRatio = stats['onlineMetricsRatio'] as double;
    
    return 'Avg confidence: ${(avgConf * 100).toStringAsFixed(1)}%, '
           'Online: ${(onlineRatio * 100).toStringAsFixed(1)}%';
  }

  // ==========================================================================
  // 🆕 V4.1 통계 및 분석
  // ==========================================================================

  /// 🆕 패턴별 성능 통계
  Future<Map<String, dynamic>> getPatternPerformance() async {
    try {
      final performance = await _usecase.getPatternPerformance(state.currentPattern);
      return {
        'pattern': performance.patternType.displayName,
        'totalSignals': performance.totalSignals,
        'recentSignals': performance.recentSignals,
        'lastSignalTime': performance.lastSignalTime?.toIso8601String(),
        'isEnabled': performance.isEnabled,
        'onlineMetricsHealth': performance.onlineMetricsHealth,
      };
    } catch (e) {
      if (AppConfig.enableTradeLog) {
        log.e('❌ Pattern performance query failed: $e');
      }
      return {'error': e.toString()};
    }
  }

  /// 🆕 시스템 헬스 리포트
  Future<Map<String, dynamic>> getSystemHealthReport() async {
    try {
      final report = await _usecase.getSystemHealthReport();
      return {
        'version': report.version,
        'status': report.status,
        'uptime': report.uptime,
        'totalProcessedTrades': report.totalProcessedTrades,
        'activePatterns': report.activePatterns,
        'trackedMarkets': report.trackedMarkets,
        'isHealthy': report.isHealthy,
        'onlineMetricsHealth': report.onlineMetricsHealth,
      };
    } catch (e) {
      if (AppConfig.enableTradeLog) {
        log.e('❌ System health report query failed: $e');
      }
      return {'error': e.toString()};
    }
  }

  /// 🆕 신호 통계 계산
  Map<String, dynamic> calculateSignalStats() {
    return _usecase.calculateSignalStats(state.signals).toJson();
  }

  // ==========================================================================
  // 기존 호환성 메서드들 (V4.1 개선)
  // ==========================================================================

  /// 시그널 통계 정보 (기존 호환성)
  Map<String, dynamic> getSignalStats() {
    return state.signalStats;
  }

  /// 시그널 목록 적용 (정렬 등) - V4.1 개선
  List<Signal> apply(List<Signal> signals) {
    return _applySorting(signals);
  }

  /// 사용 가능한 패턴 목록 - V4.1 개선
  List<String> get availablePatterns => 
      PatternType.values.map((p) => p.name).toList();

  /// 패턴 표시명 목록 - V4.1 개선
  List<String> get patternDisplayNames => 
      PatternType.values.map((p) => p.displayName).toList();

  /// 현재 패턴의 시간 윈도우 - V4.1 개선
  int get currentTimeWindow => state.currentPattern.timeWindowMinutes;

  /// 🆕 V4.1 현재 패턴의 기본 신뢰도
  double get currentPatternDefaultConfidence => state.currentPattern.defaultConfidence;

  /// 🆕 V4.1 현재 패턴의 쿨다운 시간
  int get currentPatternCooldownSeconds => state.currentPattern.defaultCooldownSeconds;

  // ==========================================================================
  // 🆕 V4.1 설정 관리
  // ==========================================================================

  /// 🆕 현재 설정 내보내기
  Map<String, dynamic> exportConfiguration() {
    final controller = _ref.read(signalPatternController);
    return controller.exportConfiguration();
  }

  /// 🆕 설정 가져오기
  void importConfiguration(Map<String, dynamic> config) {
    try {
      final controller = _ref.read(signalPatternController);
      controller.importConfiguration(config);
      
      // 현재 상태 새로고침
      final newThreshold = _usecase.getPatternThreshold(state.currentPattern);
      final newEnabled = _usecase.isPatternEnabled(state.currentPattern);
      
      state = state.copyWith(
        threshold: newThreshold,
        isPatternEnabled: newEnabled,
      );
      
      if (AppConfig.enableTradeLog) {
        log.i('📥 Configuration imported successfully');
      }
    } catch (e) {
      if (AppConfig.enableTradeLog) {
        log.e('❌ Configuration import failed: $e');
      }
      
      state = state.copyWith(
        errorMessage: 'Configuration import failed: ${e.toString()}'
      );
    }
  }

  /// 🆕 에러 메시지 클리어
  void clearError() {
    state = state.copyWith(errorMessage: null);
  }

  // ==========================================================================
  // 리소스 정리 (V4.1 확장)
  // ==========================================================================

  @override
  void dispose() {
    _subscription?.cancel();
    _healthSubscription?.cancel();
    _healthUpdateTimer?.cancel();
    
    if (AppConfig.enableTradeLog) {
      log.i('🔥 Signal Controller V4.1 disposed');
    }
    
    super.dispose();
  }
}

/// Provider 선언 - V4.1
final signalControllerProvider =
    StateNotifierProvider<SignalController, SignalState>((ref) {
  final usecase = ref.read(signalUsecaseProvider);
  return SignalController(usecase, ref);
});

/// 🆕 V4.1 확장 - 시스템 모니터링 Provider
final signalSystemMonitorProvider = StreamProvider.autoDispose<Map<String, dynamic>>((ref) async* {
  final controller = ref.watch(signalControllerProvider.notifier);
  
  yield* Stream.periodic(const Duration(seconds: 15), (_) async {
    final performance = await controller.getPatternPerformance();
    final systemHealth = await controller.getSystemHealthReport();
    final signalStats = controller.calculateSignalStats();
    
    return {
      'timestamp': DateTime.now().toIso8601String(),
      'performance': performance,
      'systemHealth': systemHealth,
      'signalStats': signalStats,
      'version': 'V4.1-Online',
    };
  }).asyncMap((event) => event);
});