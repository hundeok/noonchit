// lib/domain/usecases/signal_usecase.dart

import '../entities/signal.dart';
import '../repositories/signal_repository.dart';
import '../../core/config/app_config.dart';
import '../../core/utils/logger.dart';

/// 🚀 Signal UseCase V4.1 - Clean Architecture + 모달 지원
/// 
/// 주요 개선사항:
/// - V4.1 온라인 지표 시스템 연동
/// - 고급 패턴 설정 비즈니스 규칙
/// - 시스템 헬스 모니터링
/// - 모달용 메서드 4개 추가 (정석 Repository 호출)
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
  // 🆕 V4.1 모달용 메서드 (Controller에서 직접 호출)
  // ==========================================================================

  /// 🆕 현재 패턴의 특정 임계값 조회 (모달에서 사용)
  double getCurrentThresholdValue(PatternType pattern, String key) {
    return _repository.getCurrentThresholdValue(pattern, key);
  }

  /// 🆕 패턴의 기본 임계값 조회 (모달에서 사용)
  double getDefaultThresholdValue(PatternType pattern, String key) {
    // 패턴별 기본값 정의 (비즈니스 로직)
    switch (pattern) {
      case PatternType.surge:
        switch (key) {
          case 'priceChangePercent': return 0.4;
          case 'zScoreThreshold': return 2.0;
          case 'buyRatioMin': return 0.6;
          case 'buyRatioMax': return 0.95;
          case 'consecutiveMin': return 3;
          case 'timeWindowSeconds': return 300;
          case 'cooldownSeconds': return 300;
          case 'minVolume': return 100000;
          default: return 0.0;
        }
      case PatternType.flashFire:
        switch (key) {
          case 'priceChangePercent': return 0.8;
          case 'zScoreThreshold': return 3.0;
          case 'buyRatioMin': return 0.7;
          case 'buyRatioMax': return 0.98;
          case 'consecutiveMin': return 5;
          case 'timeWindowSeconds': return 180;
          case 'cooldownSeconds': return 240;
          case 'minVolume': return 200000;
          default: return 0.0;
        }
      case PatternType.stackUp:
        switch (key) {
          case 'priceChangePercent': return 0.2;
          case 'consecutiveMin': return 7;
          case 'buyRatioMin': return 0.65;
          case 'rSquaredMin': return 0.8;
          case 'timeWindowSeconds': return 600;
          case 'cooldownSeconds': return 600;
          case 'minVolume': return 150000;
          default: return 0.0;
        }
      case PatternType.stealthIn:
        switch (key) {
          case 'minTradeAmount': return 5000000.0; // 500만원
          case 'priceChangePercent': return 0.15;
          case 'cvThreshold': return 0.05;
          case 'buyRatioMin': return 0.55;
          case 'timeWindowSeconds': return 900;
          case 'cooldownSeconds': return 900;
          case 'minVolume': return 300000;
          default: return 0.0;
        }
      case PatternType.blackHole:
        switch (key) {
          case 'cvThreshold': return 0.02;
          case 'priceChangePercent': return 0.1;
          case 'minTradeAmount': return 10000000.0; // 1000만원
          case 'buyRatioMin': return 0.5;
          case 'timeWindowSeconds': return 1200;
          case 'cooldownSeconds': return 1200;
          case 'minVolume': return 500000;
          default: return 0.0;
        }
      case PatternType.reboundShot:
        switch (key) {
          case 'priceRangeMin': return 0.03; // 3% 급락
          case 'priceChangePercent': return 0.25;
          case 'buyRatioMin': return 0.75;
          case 'timeWindowSeconds': return 240;
          case 'cooldownSeconds': return 360;
          case 'reboundStrength': return 1.5;
          case 'minVolume': return 250000;
          default: return 0.0;
        }
    }
  }

  /// 🆕 임계값 직접 업데이트 (모달에서 사용) - updateAdvancedPatternConfig 별칭
  void updatePatternThresholdDirect(String key, double value, PatternType pattern) {
    updateAdvancedPatternConfig(pattern, key, value);
  }

  /// 🆕 임계값 기본값으로 리셋 (모달에서 사용)
  void resetThresholdToDefault(PatternType pattern, String key) {
    try {
      final defaultValue = getDefaultThresholdValue(pattern, key);
      updateAdvancedPatternConfig(pattern, key, defaultValue);
      
      if (AppConfig.enableTradeLog) {
        log.i('🔄 Threshold reset to default: ${pattern.name}.$key = $defaultValue');
      }
    } catch (e) {
      if (AppConfig.enableTradeLog) {
        log.e('❌ Reset threshold to default failed: $e');
      }
      rethrow;
    }
  }

  // ==========================================================================
  // 🆕 V4.1 시스템 제어 메서드 (Fallback 처리 포함)
  // ==========================================================================

  /// 🆕 시스템 전체 활성화/비활성화 (Controller에서 사용)
  void setSystemActive(bool active) {
    _repository.setSystemActive(active);
  }

  /// 🆕 시스템 상태 조회 (Controller에서 사용)
  Map<String, dynamic> getSystemStatus() {
    return _repository.getSystemStatus();
  }

  /// 🆕 온라인 지표 헬스 조회 (Controller에서 사용)
  Map<String, dynamic> getOnlineMetricsHealth() {
    return _repository.getOnlineMetricsHealth();
  }

  /// 🆕 시스템 헬스 조회 (Controller에서 사용)
  Future<Map<String, dynamic>> getSystemHealth() async {
    return await _repository.getSystemHealth();
  }

  /// 🆕 온라인 지표 리셋 (Controller에서 사용)
  void resetOnlineMetrics([String? market]) {
    _repository.resetOnlineMetrics(market);
  }

  /// 🆕 설정 내보내기 (Controller에서 사용)
  Map<String, dynamic> exportCurrentConfiguration() {
    return _repository.exportConfiguration();
  }

  /// 🆕 패턴의 모든 기본값 조회 (내부 헬퍼)
  Map<String, double> _getAllDefaultValues(PatternType pattern) {
    final commonKeys = [
      'priceChangePercent', 'zScoreThreshold', 'buyRatioMin', 'buyRatioMax',
      'consecutiveMin', 'timeWindowSeconds', 'cooldownSeconds', 'minVolume',
      'cvThreshold', 'rSquaredMin', 'minTradeAmount', 'priceRangeMin', 'reboundStrength'
    ];
    
    final defaults = <String, double>{};
    for (final key in commonKeys) {
      try {
        final value = getDefaultThresholdValue(pattern, key);
        if (value > 0) {
          defaults[key] = value;
        }
      } catch (e) {
        // 해당 키가 패턴에 없으면 무시
      }
    }
    
    return defaults;
  }

  /// 🆕 설정 가져오기 (Controller에서 사용)
  void importSignalConfiguration(Map<String, dynamic> config) {
    _repository.importConfiguration(config);
  }

  /// 🆕 시그널 초기화 (오버로드된 메서드)
  void clearSignals([PatternType? pattern]) {
    if (pattern != null) {
      clearPatternSignals(pattern);
    } else {
      clearAllSignals();
    }
  }

  // ==========================================================================
  // 🆕 V4.1 시스템 모니터링 및 분석
  // ==========================================================================

  /// 패턴별 성능 통계
  Future<PatternPerformanceStats> getPatternPerformance(PatternType pattern) async {
    final stats = await _repository.getPatternStats(pattern);
    final systemHealth = await getSystemHealth(); // UseCase의 getSystemHealth 사용
    
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
    final health = await getSystemHealth(); // UseCase의 getSystemHealth 사용
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
  SignalConfiguration exportSignalConfiguration() {
    final config = exportCurrentConfiguration();
    return SignalConfiguration.fromJson(config);
  }

  /// 설정 복원  
  void importConfiguration(SignalConfiguration configuration) {
    importSignalConfiguration(configuration.toJson());
  }

  /// 설정 비교 (A/B 테스트용)
  ConfigurationDiff compareConfigurations(
    SignalConfiguration configA,
    SignalConfiguration configB,
  ) {
    return ConfigurationDiff.compare(configA, configB);
  }

  // ==========================================================================
  // 🆕 V4.1 추가 유틸리티 메서드들
  // ==========================================================================

  /// 🆕 패턴별 설정 키 목록 조회
  List<String> getPatternConfigKeys(PatternType pattern) {
    final allKeys = _getAllDefaultValues(pattern).keys.toList();
    return allKeys..sort();
  }

  /// 🆕 모든 패턴의 현재 상태 조회
  Map<String, dynamic> getAllPatternStatus() {
    final status = <String, dynamic>{};
    
    for (final pattern in PatternType.values) {
      status[pattern.name] = {
        'enabled': isPatternEnabled(pattern),
        'threshold': getPatternThreshold(pattern),
        'displayName': pattern.displayName,
        'description': pattern.description,
        'defaultThreshold': pattern.defaultThreshold,
        'timeWindowMinutes': pattern.timeWindowMinutes,
        'defaultConfidence': pattern.defaultConfidence,
        'defaultCooldownSeconds': pattern.defaultCooldownSeconds,
        'availableKeys': getPatternConfigKeys(pattern),
      };
    }
    
    return {
      'timestamp': DateTime.now().toIso8601String(),
      'version': 'V4.1-Complete',
      'patterns': status,
      'systemStatus': getSystemStatus(),
    };
  }

  /// 🆕 설정 검증
  Map<String, dynamic> validateConfiguration(Map<String, dynamic> config) {
    final errors = <String>[];
    final warnings = <String>[];
    
    try {
      // 버전 확인
      final version = config['version'] as String?;
      if (version == null) {
        warnings.add('Configuration version not specified');
      }
      
      // 패턴 설정 검증
      final patternEnabled = config['patternEnabled'] as Map<String, dynamic>?;
      if (patternEnabled != null) {
        for (final patternName in patternEnabled.keys) {
          final found = PatternType.values.any((p) => p.name == patternName);
          if (!found) {
            warnings.add('Unknown pattern: $patternName');
          }
        }
      }
      
      // 임계값 검증
      final patternConfig = config['patternConfig'] as Map<String, dynamic>?;
      if (patternConfig != null) {
        for (final entry in patternConfig.entries) {
          final patternName = entry.key;
          final settings = entry.value as Map<String, dynamic>?;
          
          if (settings != null && settings.containsKey('threshold')) {
            try {
              final pattern = PatternType.values.firstWhere(
                (p) => p.name == patternName,
              );
              final threshold = settings['threshold'] as double;
              
              // 임계값 범위 검증 (updatePatternThreshold 로직 재사용)
              try {
                updatePatternThreshold(pattern, threshold);
              } catch (e) {
                errors.add('Invalid threshold for $patternName: $e');
              }
            } catch (e) {
              warnings.add('Unknown pattern in config: $patternName');
            }
          }
        }
      }
      
      return {
        'valid': errors.isEmpty,
        'errors': errors,
        'warnings': warnings,
        'timestamp': DateTime.now().toIso8601String(),
      };
    } catch (e) {
      return {
        'valid': false,
        'errors': ['Configuration validation failed: $e'],
        'warnings': warnings,
        'timestamp': DateTime.now().toIso8601String(),
      };
    }
  }

  /// 🆕 성능 최적화된 패턴 활성화 상태 체크
  bool isAnyPatternEnabled() {
    return PatternType.values.any((pattern) => isPatternEnabled(pattern));
  }

  /// 🆕 활성화된 패턴 목록 조회
  List<PatternType> getEnabledPatterns() {
    return PatternType.values
        .where((pattern) => isPatternEnabled(pattern))
        .toList();
  }

  /// 🆕 비활성화된 패턴 목록 조회
  List<PatternType> getDisabledPatterns() {
    return PatternType.values
        .where((pattern) => !isPatternEnabled(pattern))
        .toList();
  }

  /// 🆕 패턴별 권장 설정 조회
  Map<String, dynamic> getRecommendedSettings(PatternType pattern) {
    final defaultValues = _getAllDefaultValues(pattern);
    
    return {
      'pattern': pattern.name,
      'displayName': pattern.displayName,
      'description': pattern.description,
      'defaultValues': defaultValues,
      'currentThreshold': getPatternThreshold(pattern),
      'isEnabled': isPatternEnabled(pattern),
      'recommendations': {
        'conservative': _getConservativeSettings(pattern),
        'balanced': _getBalancedSettings(pattern),
        'aggressive': _getAggressiveSettings(pattern),
      },
    };
  }

  /// 🆕 보수적 설정 조회
  Map<String, double> _getConservativeSettings(PatternType pattern) {
    final defaults = _getAllDefaultValues(pattern);
    final conservative = <String, double>{};
    
    for (final entry in defaults.entries) {
      final key = entry.key;
      final value = entry.value;
      
      // 보수적 설정: 더 높은 임계값, 더 엄격한 조건
      switch (key) {
        case 'priceChangePercent':
          conservative[key] = value * 1.5; // 50% 더 높은 임계값
          break;
        case 'zScoreThreshold':
          conservative[key] = value * 1.3; // 30% 더 높은 Z-Score
          break;
        case 'buyRatioMin':
          conservative[key] = (value * 1.1).clamp(0.0, 1.0); // 10% 더 높은 매수비율
          break;
        case 'cooldownSeconds':
          conservative[key] = value * 2.0; // 2배 더 긴 쿨다운
          break;
        default:
          conservative[key] = value;
      }
    }
    
    return conservative;
  }

  /// 🆕 균형 설정 조회 (기본값)
  Map<String, double> _getBalancedSettings(PatternType pattern) {
    return _getAllDefaultValues(pattern);
  }

  /// 🆕 공격적 설정 조회
  Map<String, double> _getAggressiveSettings(PatternType pattern) {
    final defaults = _getAllDefaultValues(pattern);
    final aggressive = <String, double>{};
    
    for (final entry in defaults.entries) {
      final key = entry.key;
      final value = entry.value;
      
      // 공격적 설정: 더 낮은 임계값, 더 느슨한 조건
      switch (key) {
        case 'priceChangePercent':
          aggressive[key] = value * 0.7; // 30% 더 낮은 임계값
          break;
        case 'zScoreThreshold':
          aggressive[key] = value * 0.8; // 20% 더 낮은 Z-Score
          break;
        case 'buyRatioMin':
          aggressive[key] = (value * 0.9).clamp(0.0, 1.0); // 10% 더 낮은 매수비율
          break;
        case 'cooldownSeconds':
          aggressive[key] = value * 0.5; // 절반으로 줄인 쿨다운
          break;
        default:
          aggressive[key] = value;
      }
    }
    
    return aggressive;
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
    final changedPatterns = <String>[];
    final changedSettings = <String>[];
    final differences = <String, dynamic>{};
    
    // 패턴 활성화 상태 비교
    for (final pattern in configA.patternEnabled.keys) {
      final aEnabled = configA.patternEnabled[pattern] ?? false;
      final bEnabled = configB.patternEnabled[pattern] ?? false;
      
      if (aEnabled != bEnabled) {
        changedPatterns.add(pattern);
        differences['patternEnabled_$pattern'] = {
          'from': aEnabled,
          'to': bEnabled,
        };
      }
    }
    
    // 패턴 설정 비교
    for (final pattern in configA.patternConfig.keys) {
      final aConfig = configA.patternConfig[pattern] as Map<String, dynamic>?;
      final bConfig = configB.patternConfig[pattern] as Map<String, dynamic>?;
      
      if (aConfig != null && bConfig != null) {
        for (final key in aConfig.keys) {
          final aValue = aConfig[key];
          final bValue = bConfig[key];
          
          if (aValue != bValue) {
            changedSettings.add('${pattern}_$key');
            differences['config_${pattern}_$key'] = {
              'from': aValue,
              'to': bValue,
            };
          }
        }
      }
    }
    
    return ConfigurationDiff(
      changedPatterns: changedPatterns,
      changedSettings: changedSettings,
      differences: differences,
    );
  }

  bool get hasChanges => changedPatterns.isNotEmpty || changedSettings.isNotEmpty;
}