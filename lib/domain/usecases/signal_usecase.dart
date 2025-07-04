import '../entities/signal.dart';
import '../repositories/signal_repository.dart';

/// 🚀 Signal UseCase V4.1 - 온라인 지표 비즈니스 로직
/// 
/// 주요 개선사항:
/// - V4.1 온라인 지표 시스템 연동
/// - 고급 패턴 설정 비즈니스 규칙
/// - 시스템 헬스 모니터링
/// - 백테스팅 지원
/// - 성능 최적화된 필터링
class SignalUseCase {
  final SignalRepository _repository;

  const SignalUseCase(this._repository);

  // ==========================================================================
  // 기본 시그널 스트림 (기존 호환성)
  // ==========================================================================

  /// 특정 패턴의 시그널 스트림 감시
  Stream<List<Signal>> watchSignalsByPattern(
    PatternType patternType,
    List<String> markets,
  ) {
    return _repository.watchSignalsByPattern(patternType, markets);
  }

  /// 모든 패턴의 시그널 스트림 감시
  Stream<List<Signal>> watchAllSignals(List<String> markets) {
    return _repository.watchAllSignals(markets);
  }

  // ==========================================================================
  // 패턴 설정 관리 (비즈니스 규칙 포함)
  // ==========================================================================

  /// 패턴별 임계값 업데이트 (비즈니스 규칙 검증)
  void updatePatternThreshold(PatternType patternType, double threshold) {
    // 기본 검증
    if (threshold <= 0) {
      throw ArgumentError('Threshold must be positive: $threshold');
    }

    // V4.1 패턴별 임계값 범위 검증 (완화된 기준 적용)
    switch (patternType) {
      case PatternType.surge:
        if (threshold < 0.1 || threshold > 50.0) {
          throw ArgumentError('Surge threshold must be between 0.1% and 50%: $threshold');
        }
        break;
      case PatternType.flashFire:
        if (threshold < 1.1 || threshold > 10.0) {
          throw ArgumentError('FlashFire threshold must be between 1.1x and 10x: $threshold');
        }
        break;
      case PatternType.stackUp:
        if (threshold < 2 || threshold > 10) {
          throw ArgumentError('StackUp threshold must be between 2 and 10: $threshold');
        }
        break;
      case PatternType.stealthIn:
        // V4.1 완화된 기준: 300만 ~ 1억
        if (threshold < 3000000 || threshold > 100000000) {
          throw ArgumentError('StealthIn threshold must be between 3M and 100M: $threshold');
        }
        break;
      case PatternType.blackHole:
        // V4.1 완화된 기준: 0.5% ~ 5%
        if (threshold < 0.5 || threshold > 5.0) {
          throw ArgumentError('BlackHole threshold must be between 0.5% and 5%: $threshold');
        }
        break;
      case PatternType.reboundShot:
        if (threshold < 0.5 || threshold > 20.0) {
          throw ArgumentError('ReboundShot threshold must be between 0.5% and 20%: $threshold');
        }
        break;
    }

    _repository.updatePatternThreshold(patternType, threshold);
  }

  /// 패턴별 임계값 조회
  double getPatternThreshold(PatternType patternType) {
    return _repository.getPatternThreshold(patternType);
  }

  /// 패턴 활성화/비활성화 설정
  void setPatternEnabled(PatternType patternType, bool enabled) {
    _repository.setPatternEnabled(patternType, enabled);
  }

  /// 패턴 활성화 상태 조회
  bool isPatternEnabled(PatternType patternType) {
    return _repository.isPatternEnabled(patternType);
  }

  /// 특정 패턴의 시그널 목록 초기화
  void clearPatternSignals(PatternType patternType) {
    _repository.clearSignals(patternType);
  }

  /// 모든 시그널 목록 초기화
  void clearAllSignals() {
    _repository.clearSignals(null);
  }

  // ==========================================================================
  // 🆕 V4.1 고급 패턴 설정 (비즈니스 규칙 포함)
  // ==========================================================================

  /// 고급 패턴 설정 업데이트 (비즈니스 규칙 검증)
  void updateAdvancedPatternConfig(PatternType pattern, String key, double value) {
    // 설정 키별 비즈니스 규칙 검증
    switch (key) {
      case 'zScoreThreshold':
        if (value < 0.5 || value > 5.0) {
          throw ArgumentError('Z-Score threshold must be between 0.5 and 5.0: $value');
        }
        break;
      case 'buyRatioMin':
        if (value < 0.0 || value > 1.0) {
          throw ArgumentError('Buy ratio must be between 0.0 and 1.0: $value');
        }
        break;
      case 'buyRatioMax':
        if (value < 0.0 || value > 1.0) {
          throw ArgumentError('Buy ratio max must be between 0.0 and 1.0: $value');
        }
        break;
      case 'cvThreshold':
        if (value < 0.001 || value > 0.5) {
          throw ArgumentError('CV threshold must be between 0.001 and 0.5: $value');
        }
        break;
      case 'rSquaredMin':
        if (value < 0.0 || value > 1.0) {
          throw ArgumentError('R-squared must be between 0.0 and 1.0: $value');
        }
        break;
      default:
        // 일반적인 양수 검증
        if (value < 0) {
          throw ArgumentError('Configuration value must be non-negative: $value');
        }
    }

    _repository.updatePatternConfig(pattern, key, value);
  }

  /// 패턴 프리셋 적용 (비즈니스 로직 검증)
  void applyPatternPreset(String presetName) {
    final validPresets = ['conservative', 'aggressive', 'balanced'];
    if (!validPresets.contains(presetName.toLowerCase())) {
      throw ArgumentError('Invalid preset name. Valid options: ${validPresets.join(', ')}');
    }

    _repository.applyPatternPreset(presetName);
  }

  // ==========================================================================
  // 🆕 V4.1 시스템 모니터링 및 분석
  // ==========================================================================

  /// 패턴별 성능 통계
  Future<PatternPerformanceStats> getPatternPerformance(PatternType pattern) async {
    final stats = await _repository.getPatternStats(pattern);
    final systemHealth = await _repository.getSystemHealth();
    
    return PatternPerformanceStats(
      patternType: pattern,
      totalSignals: stats['totalSignals'] ?? 0,
      recentSignals: stats['recentSignals'] ?? 0,
      lastSignalTime: stats['lastSignalTime'] != null 
          ? DateTime.parse(stats['lastSignalTime'])
          : null,
      isEnabled: stats['isEnabled'] ?? false,
      config: Map<String, double>.from(stats['config'] ?? {}),
      cooldownStatus: Map<String, dynamic>.from(stats['cooldownStatus'] ?? {}),
      onlineMetricsHealth: systemHealth['onlineMetricsSystem'],
    );
  }

  /// 전체 시스템 헬스 체크
  Future<SystemHealthReport> getSystemHealthReport() async {
    final health = await _repository.getSystemHealth();
    final dataQuality = _repository.getMarketDataQuality();
    
    return SystemHealthReport(
      version: health['version'] ?? 'Unknown',
      status: health['status'] ?? 'Unknown',
      uptime: health['uptime'] ?? 0,
      totalProcessedTrades: health['totalProcessedTrades'] ?? 0,
      activePatterns: health['activePatterns'] ?? 0,
      trackedMarkets: health['trackedMarkets'] ?? 0,
      onlineMetricsHealth: health['onlineMetricsSystem'],
      marketDataQuality: dataQuality,
      lastProcessingTime: health['lastProcessingTime'] != null 
          ? DateTime.parse(health['lastProcessingTime'])
          : null,
    );
  }

  /// 성능 메트릭스 스트림 (필터링 포함)
  Stream<PerformanceMetrics> watchFilteredPerformanceMetrics() {
    return _repository.watchPerformanceMetrics().map((raw) {
      return PerformanceMetrics(
        timestamp: DateTime.parse(raw['timestamp']),
        version: raw['version'] ?? 'Unknown',
        totalProcessedTrades: raw['totalProcessedTrades'] ?? 0,
        activeMarkets: raw['activeMarkets'] ?? 0,
        signalCounts: Map<String, int>.from(raw['signalCounts'] ?? {}),
        memoryUsage: Map<String, dynamic>.from(raw['memoryUsage'] ?? {}),
        onlineMetrics: Map<String, dynamic>.from(raw['onlineMetrics'] ?? {}),
        architecture: raw['architecture'] ?? 'Unknown',
      );
    });
  }

  // ==========================================================================
  // 시그널 분석 및 필터링 (개선된 로직)
  // ==========================================================================

  /// 시그널 통계 정보 계산 (V4.1 온라인 지표 포함)
  SignalStats calculateSignalStats(List<Signal> signals) {
    if (signals.isEmpty) {
      return const SignalStats(
        totalCount: 0,
        patternCounts: {},
        avgChangePercent: 0.0,
        maxChangePercent: 0.0,
        minChangePercent: 0.0,
        totalTradeAmount: 0.0,
        avgConfidence: 0.0,
        onlineMetricsCount: 0,
      );
    }

    final patternCounts = <PatternType, int>{};
    double totalChangePercent = 0.0;
    double maxChangePercent = signals.first.changePercent;
    double minChangePercent = signals.first.changePercent;
    double totalTradeAmount = 0.0;
    double totalConfidence = 0.0;
    int onlineMetricsCount = 0;

    for (final signal in signals) {
      // 패턴별 카운트
      patternCounts[signal.patternType] = 
          (patternCounts[signal.patternType] ?? 0) + 1;

      // 변화율 통계
      totalChangePercent += signal.changePercent;
      if (signal.changePercent > maxChangePercent) {
        maxChangePercent = signal.changePercent;
      }
      if (signal.changePercent < minChangePercent) {
        minChangePercent = signal.changePercent;
      }

      // 거래대금 합계
      totalTradeAmount += signal.tradeAmount;
      
      // V4.1 신뢰도 통계
      final confidence = signal.confidence ?? 0.0;
      totalConfidence += confidence;
      
      // V4.1 온라인 지표 기반 신호 카운트
      if (signal.hasOnlineMetrics) {
        onlineMetricsCount++;
      }
    }

    return SignalStats(
      totalCount: signals.length,
      patternCounts: patternCounts,
      avgChangePercent: totalChangePercent / signals.length,
      maxChangePercent: maxChangePercent,
      minChangePercent: minChangePercent,
      totalTradeAmount: totalTradeAmount,
      avgConfidence: totalConfidence / signals.length,
      onlineMetricsCount: onlineMetricsCount,
    );
  }

  /// 고급 시그널 필터링 (V4.1 확장)
  List<Signal> filterSignals(
    List<Signal> signals, {
    double? minChangePercent,
    double? maxChangePercent,
    double? minTradeAmount,
    double? maxTradeAmount,
    Set<PatternType>? patternTypes,
    Duration? timeWindow,
    double? minConfidence,
    bool? requireOnlineMetrics,
    Set<String>? markets,
  }) {
    return signals.where((signal) {
      // 기존 필터들
      if (minChangePercent != null && signal.changePercent < minChangePercent) {
        return false;
      }
      if (maxChangePercent != null && signal.changePercent > maxChangePercent) {
        return false;
      }
      if (minTradeAmount != null && signal.tradeAmount < minTradeAmount) {
        return false;
      }
      if (maxTradeAmount != null && signal.tradeAmount > maxTradeAmount) {
        return false;
      }
      if (patternTypes != null && !patternTypes.contains(signal.patternType)) {
        return false;
      }
      if (timeWindow != null) {
        final cutoff = DateTime.now().subtract(timeWindow);
        if (signal.detectedAt.isBefore(cutoff)) {
          return false;
        }
      }
      
      // V4.1 새로운 필터들
      if (minConfidence != null && (signal.confidence ?? 0.0) < minConfidence) {
        return false;
      }
      if (requireOnlineMetrics == true && !signal.hasOnlineMetrics) {
        return false;
      }
      if (markets != null && !markets.contains(signal.market)) {
        return false;
      }

      return true;
    }).toList();
  }

  // ==========================================================================
  // 🆕 V4.1 백테스팅 및 설정 관리
  // ==========================================================================

  /// 현재 설정 백업
  SignalConfiguration exportCurrentConfiguration() {
    final config = _repository.exportConfiguration();
    return SignalConfiguration.fromJson(config);
  }

  /// 설정 복원
  void importConfiguration(SignalConfiguration configuration) {
    _repository.importConfiguration(configuration.toJson());
  }

  /// 설정 비교 (A/B 테스트용)
  ConfigurationDiff compareConfigurations(
    SignalConfiguration configA,
    SignalConfiguration configB,
  ) {
    return ConfigurationDiff.compare(configA, configB);
  }

  // ==========================================================================
  // 리소스 정리
  // ==========================================================================

  /// 리소스 정리
  Future<void> dispose() async {
    await _repository.dispose();
  }
}

// ==========================================================================
// 🆕 V4.1 확장 데이터 클래스들
// ==========================================================================

/// V4.1 향상된 Signal 통계 정보
class SignalStats {
  final int totalCount;
  final Map<PatternType, int> patternCounts;
  final double avgChangePercent;
  final double maxChangePercent;
  final double minChangePercent;
  final double totalTradeAmount;
  final double avgConfidence;
  final int onlineMetricsCount;

  const SignalStats({
    required this.totalCount,
    required this.patternCounts,
    required this.avgChangePercent,
    required this.maxChangePercent,
    required this.minChangePercent,
    required this.totalTradeAmount,
    required this.avgConfidence,
    required this.onlineMetricsCount,
  });

  double get onlineMetricsRatio => 
      totalCount > 0 ? onlineMetricsCount / totalCount : 0.0;

   /// 🆕 V4.1 JSON 직렬화
  Map<String, dynamic> toJson() {
    return {
      'totalCount': totalCount,
      'patternCounts': patternCounts.map((k, v) => MapEntry(k.name, v)),
      'avgChangePercent': avgChangePercent,
      'maxChangePercent': maxChangePercent,
      'minChangePercent': minChangePercent,
      'totalTradeAmount': totalTradeAmount,
      'avgConfidence': avgConfidence,
      'onlineMetricsCount': onlineMetricsCount,
      'onlineMetricsRatio': onlineMetricsRatio,
    };
  }

  @override
  String toString() {
    return 'SignalStats(total: $totalCount, avg: ${avgChangePercent.toStringAsFixed(2)}%, '
        'confidence: ${(avgConfidence * 100).toStringAsFixed(1)}%, '
        'online: ${(onlineMetricsRatio * 100).toStringAsFixed(1)}%)';
  }
}

/// 패턴별 성능 통계
class PatternPerformanceStats {
  final PatternType patternType;
  final int totalSignals;
  final int recentSignals;
  final DateTime? lastSignalTime;
  final bool isEnabled;
  final Map<String, double> config;
  final Map<String, dynamic> cooldownStatus;
  final Map<String, dynamic>? onlineMetricsHealth;

  const PatternPerformanceStats({
    required this.patternType,
    required this.totalSignals,
    required this.recentSignals,
    this.lastSignalTime,
    required this.isEnabled,
    required this.config,
    required this.cooldownStatus,
    this.onlineMetricsHealth,
  });
}

/// 시스템 헬스 리포트
class SystemHealthReport {
  final String version;
  final String status;
  final int uptime;
  final int totalProcessedTrades;
  final int activePatterns;
  final int trackedMarkets;
  final Map<String, dynamic>? onlineMetricsHealth;
  final Map<String, dynamic> marketDataQuality;
  final DateTime? lastProcessingTime;

  const SystemHealthReport({
    required this.version,
    required this.status,
    required this.uptime,
    required this.totalProcessedTrades,
    required this.activePatterns,
    required this.trackedMarkets,
    this.onlineMetricsHealth,
    required this.marketDataQuality,
    this.lastProcessingTime,
  });

  bool get isHealthy => status == 'healthy';
}

/// 성능 메트릭스
class PerformanceMetrics {
  final DateTime timestamp;
  final String version;
  final int totalProcessedTrades;
  final int activeMarkets;
  final Map<String, int> signalCounts;
  final Map<String, dynamic> memoryUsage;
  final Map<String, dynamic> onlineMetrics;
  final String architecture;

  const PerformanceMetrics({
    required this.timestamp,
    required this.version,
    required this.totalProcessedTrades,
    required this.activeMarkets,
    required this.signalCounts,
    required this.memoryUsage,
    required this.onlineMetrics,
    required this.architecture,
  });
}

/// 설정 정보
class SignalConfiguration {
  final String version;
  final DateTime timestamp;
  final Map<String, dynamic> patternConfig;
  final Map<String, bool> patternEnabled;
  final Map<String, dynamic> systemSettings;

  const SignalConfiguration({
    required this.version,
    required this.timestamp,
    required this.patternConfig,
    required this.patternEnabled,
    required this.systemSettings,
  });

  factory SignalConfiguration.fromJson(Map<String, dynamic> json) {
    return SignalConfiguration(
      version: json['version'] ?? 'Unknown',
      timestamp: DateTime.parse(json['timestamp']),
      patternConfig: Map<String, dynamic>.from(json['patternConfig'] ?? {}),
      patternEnabled: Map<String, bool>.from(json['patternEnabled'] ?? {}),
      systemSettings: Map<String, dynamic>.from(json['systemSettings'] ?? {}),
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'version': version,
      'timestamp': timestamp.toIso8601String(),
      'patternConfig': patternConfig,
      'patternEnabled': patternEnabled,
      'systemSettings': systemSettings,
    };
  }
}

/// 설정 비교 결과
class ConfigurationDiff {
  final List<String> changedPatterns;
  final List<String> changedSettings;
  final Map<String, dynamic> differences;

  const ConfigurationDiff({
    required this.changedPatterns,
    required this.changedSettings,
    required this.differences,
  });

  static ConfigurationDiff compare(
    SignalConfiguration configA,
    SignalConfiguration configB,
  ) {
    // 간단한 비교 로직 (실제로는 더 정교하게 구현)
    return const ConfigurationDiff(
      changedPatterns: [],
      changedSettings: [],
      differences: {},
    );
  }

  bool get hasChanges => changedPatterns.isNotEmpty || changedSettings.isNotEmpty;
}