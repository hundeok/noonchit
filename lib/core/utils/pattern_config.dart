import '../../domain/entities/signal.dart';
import '../../core/config/app_config.dart';
import '../../core/utils/logger.dart';

/// 🎯 PatternConfig - 패턴별 설정값 관리
/// 
/// 개선사항:
/// - 4,5번 패턴 완화된 설정값 적용
/// - 패턴별 개별 쿨다운 시간 관리
/// - 설정값 유효성 검사 (패턴별 분리)
/// - 런타임 설정 변경 지원
class PatternConfig {
  
  /// 📊 패턴별 기본 설정값 (4,5번 패턴 완화됨)
  static const Map<PatternType, Map<String, double>> _defaultConfig = {
    PatternType.surge: {
      'priceChangePercent': 0.4,       // 가격 변동률 0.4%
      'zScoreThreshold': 1.7,          // Z-score 임계값
      'minTradeAmount': 2500000,       // 최소 거래대금 (250만)
      'lvThreshold': 500,              // Liquidity Vortex
    },
    
    PatternType.flashFire: {
      'zScoreThreshold': 2.2,          // Z-score 임계값
      'minTradeAmount': 10000000,      // 최소 거래대금 (1000만)
      'buyRatioMin': 0.7,              // 매수 비율
      'volumeMultiplier': 2.0,         // 거래량 배수
      'mbrThreshold': 0.12,            // Micro Burst Radar
      'mrThreshold': 0.15,             // Machine Rush
    },
    
    PatternType.stackUp: {
      'consecutiveMin': 2,             // 최소 연속 횟수
      'minVolume': 5000000,            // 최소 거래량 (500만)
      'zScoreThreshold': 1.0,          // Z-score 임계값
      'volumeMultiplier': 1.5,         // 거래량 배수
      'rSquaredMin': 0.35,             // R² 최소값
    },
    
    // 🆕 StealthIn 패턴 - 완화된 설정 (감지율 향상)
    PatternType.stealthIn: {
      'minTradeAmount': 5000000,       // 2000만 → 500만 (대폭 완화)
      'intervalVarianceMax': 900,      // 거래 간격 분산 최대값
      'buyRatioMin': 0.6,              // 0.7 → 0.6 (완화)
      'avgTradeSizeRatio': 0.4,        // 평균 거래 크기 비율
      'minTradeCount': 20,             // 최소 거래 횟수
      'cvThreshold': 0.05,             // 변동계수 임계값 (5%)
    },
    
    // 🆕 BlackHole 패턴 - 완화된 설정 (감지율 향상)
    PatternType.blackHole: {
      'minTradeAmount': 10000000,      // 5000만 → 1000만 (대폭 완화)
      'cvThreshold': 0.02,             // 0.01 → 0.02 (완화)
      'buyRatioMin': 0.35,             // 0.4 → 0.35 (완화)
      'buyRatioMax': 0.65,             // 0.6 → 0.65 (완화)
      'priceZScoreMax': 1.0,           // 가격 Z-score 최대값
      'stdDevRatio': 0.02,             // 표준편차 비율 (2%)
    },
    
    PatternType.reboundShot: {
      'minVolume': 1000000,            // 최소 거래량 (100만)
      'priceRangeMin': 0.005,          // 최소 가격 범위 (0.5%)
      'jumpThreshold': 0,              // Jump Gate 임계값
    },
  };

  /// 🔒 패턴별 쿨다운 시간 (성능 최적화)
  static const Map<PatternType, Duration> _cooldownPeriods = {
    PatternType.surge: Duration(seconds: 2),        // 빠른 패턴
    PatternType.flashFire: Duration(seconds: 3),    // 중간 패턴
    PatternType.stackUp: Duration(seconds: 4),      // 중간 패턴
    PatternType.stealthIn: Duration(seconds: 8),    // 느린 패턴 (매집 특성상)
    PatternType.blackHole: Duration(seconds: 10),   // 가장 느린 패턴 (갇힘 특성상)
    PatternType.reboundShot: Duration(seconds: 3),  // 중간 패턴
  };

  /// 현재 설정값 (런타임 변경 가능)
  final Map<PatternType, Map<String, double>> _currentConfig;
  
  /// 생성자
  PatternConfig({Map<PatternType, Map<String, double>>? customConfig}) 
    : _currentConfig = customConfig != null 
        ? Map.from(customConfig)
        : _deepCopyConfig(_defaultConfig);

  /// 패턴별 설정값 조회
  Map<String, double> getPatternConfig(PatternType pattern) {
    return Map.from(_currentConfig[pattern] ?? <String, double>{});
  }

  /// 특정 설정값 조회 (기본값 fallback 포함)
  double getConfigValue(PatternType pattern, String key) {
    // 1. 현재 설정(_currentConfig)에서 값을 먼저 찾아봅니다.
    final currentValue = _currentConfig[pattern]?[key];

    // 2. 만약 값이 있다면 그 값을 반환합니다.
    if (currentValue != null) {
      return currentValue;
    }

    // 3. 현재 설정에 값이 없다면, 최후의 보루로 기본 설정(_defaultConfig)에서 값을 찾아 반환합니다.
    return _defaultConfig[pattern]?[key] ?? 0.0;
  }

  /// 패턴별 쿨다운 시간 조회
  Duration getCooldownDuration(PatternType pattern) {
    return _cooldownPeriods[pattern] ?? const Duration(seconds: 5);
  }

  /// 🛠️ 런타임 설정 변경
  
  /// 특정 패턴의 설정값 업데이트
void updatePatternConfig(PatternType pattern, String key, double value) {
  if (_isValidConfigValue(pattern, key, value)) {
    _currentConfig[pattern] ??= <String, double>{};
    _currentConfig[pattern]![key] = value;
    
    // 🆕 추가할 로그
    if (AppConfig.enableTradeLog) {
      log.i('🔧 PatternConfig 업데이트 완료: ${pattern.name}.$key = $value');
    }
  } else {
    throw ArgumentError('Invalid config value: $key = $value for pattern ${pattern.name}');
  }
}

  /// 패턴의 전체 설정 업데이트
  void updateFullPatternConfig(PatternType pattern, Map<String, double> config) {
    // 유효성 검사
    for (final entry in config.entries) {
      if (!_isValidConfigValue(pattern, entry.key, entry.value)) {
        throw ArgumentError('Invalid config value: ${entry.key} = ${entry.value} for pattern ${pattern.name}');
      }
    }
    
    _currentConfig[pattern] = Map.from(config);
  }

  /// 설정값을 기본값으로 리셋
  void resetToDefault(PatternType? pattern) {
    if (pattern != null) {
      _currentConfig[pattern] = Map.from(_defaultConfig[pattern] ?? <String, double>{});
    } else {
      _currentConfig.clear();
      _currentConfig.addAll(_deepCopyConfig(_defaultConfig));
    }
  }

  /// 🔍 설정값 유효성 검사 (패턴별 분리)
  bool _isValidConfigValue(PatternType pattern, String key, double value) {
    // 음수 값 방지
    if (value < 0) return false;
    
    // 패턴별 검증 위임
    switch (pattern) {
      case PatternType.surge:
        return _validateSurgeConfig(key, value);
      case PatternType.flashFire:
        return _validateFlashFireConfig(key, value);
      case PatternType.stackUp:
        return _validateStackUpConfig(key, value);
      case PatternType.stealthIn:
        return _validateStealthInConfig(key, value);
      case PatternType.blackHole:
        return _validateBlackHoleConfig(key, value);
      case PatternType.reboundShot:
        return _validateReboundShotConfig(key, value);
    }
  }

  /// 🎯 패턴별 검증 로직

  /// Surge 패턴 검증
  bool _validateSurgeConfig(String key, double value) {
    switch (key) {
      case 'priceChangePercent':
        return value >= 0.1 && value <= 10.0;
      case 'zScoreThreshold':
        return value >= 0.5 && value <= 5.0;
      case 'minTradeAmount':
        return value >= 100000; // 최소 10만원
      case 'lvThreshold':
        return value >= 0;
      default:
        return true;
    }
  }

  /// FlashFire 패턴 검증
  bool _validateFlashFireConfig(String key, double value) {
    switch (key) {
      case 'zScoreThreshold':
        return value >= 0.5 && value <= 5.0;
      case 'minTradeAmount':
        return value >= 1000000; // 최소 100만원
      case 'buyRatioMin':
        return value >= 0.0 && value <= 1.0;
      case 'volumeMultiplier':
        return value >= 1.0 && value <= 10.0;
      case 'mbrThreshold':
        return value >= 0.0 && value <= 1.0;
      case 'mrThreshold':
        return value >= 0.0 && value <= 1.0;
      default:
        return true;
    }
  }

  /// StackUp 패턴 검증
  bool _validateStackUpConfig(String key, double value) {
    switch (key) {
      case 'consecutiveMin':
        return value >= 1 && value <= 10;
      case 'minVolume':
        return value >= 100000; // 최소 10만원
      case 'zScoreThreshold':
        return value >= 0.5 && value <= 5.0;
      case 'volumeMultiplier':
        return value >= 1.0 && value <= 10.0;
      case 'rSquaredMin':
        return value >= 0.0 && value <= 1.0;
      default:
        return true;
    }
  }

  /// StealthIn 패턴 검증
  bool _validateStealthInConfig(String key, double value) {
    switch (key) {
      case 'minTradeAmount':
        return value >= 1000000; // 최소 100만원
      case 'intervalVarianceMax':
        return value >= 0;
      case 'buyRatioMin':
        return value >= 0.0 && value <= 1.0;
      case 'avgTradeSizeRatio':
        return value >= 0.0 && value <= 1.0;
      case 'minTradeCount':
        return value >= 1;
      case 'cvThreshold':
        return value >= 0.001 && value <= 0.5;
      default:
        return true;
    }
  }

  /// BlackHole 패턴 검증
  bool _validateBlackHoleConfig(String key, double value) {
    switch (key) {
      case 'minTradeAmount':
        return value >= 1000000; // 최소 100만원
      case 'cvThreshold':
        return value >= 0.001 && value <= 0.5;
      case 'buyRatioMin':
        return value >= 0.0 && value <= 1.0;
      case 'buyRatioMax':
        return value >= 0.0 && value <= 1.0;
      case 'priceZScoreMax':
        return value >= 0.0 && value <= 10.0;
      case 'stdDevRatio':
        return value >= 0.0 && value <= 1.0;
      default:
        return true;
    }
  }

  /// ReboundShot 패턴 검증
  bool _validateReboundShotConfig(String key, double value) {
    switch (key) {
      case 'minVolume':
        return value >= 100000; // 최소 10만원
      case 'priceRangeMin':
        return value >= 0.001 && value <= 0.5;
      case 'jumpThreshold':
        return value >= 0;
      default:
        return true;
    }
  }

  /// 설정 깊은 복사
  static Map<PatternType, Map<String, double>> _deepCopyConfig(
    Map<PatternType, Map<String, double>> source
  ) {
    final result = <PatternType, Map<String, double>>{};
    for (final entry in source.entries) {
      result[entry.key] = Map.from(entry.value);
    }
    return result;
  }

  /// 📊 설정값 정보 조회
  
  /// 모든 패턴의 설정값 조회
  Map<PatternType, Map<String, double>> getAllPatternConfigs() {
    return _deepCopyConfig(_currentConfig);
  }

  /// 기본값과 현재값 비교
  Map<String, dynamic> getConfigComparison(PatternType pattern) {
    final current = _currentConfig[pattern] ?? <String, double>{};
    final defaultValues = _defaultConfig[pattern] ?? <String, double>{};
    
    final comparison = <String, Map<String, double>>{};
    final allKeys = <String>{...current.keys, ...defaultValues.keys};
    
    for (final key in allKeys) {
      comparison[key] = {
        'current': current[key] ?? 0.0,
        'default': defaultValues[key] ?? 0.0,
        'isModified': (current[key] ?? 0.0) != (defaultValues[key] ?? 0.0) ? 1.0 : 0.0,
      };
    }
    
    return {
      'pattern': pattern.name,
      'cooldownSeconds': getCooldownDuration(pattern).inSeconds,
      'configs': comparison,
      'totalModified': comparison.values
          .where((v) => v['isModified'] == 1.0)
          .length,
    };
  }

  /// 설정 요약 정보
  Map<String, dynamic> getConfigSummary() {
    final summary = <String, dynamic>{
      'version': '4.0',
      'totalPatterns': PatternType.values.length,
      'enhancedPatterns': ['stealthIn', 'blackHole'], // 완화된 패턴들
    };
    
    // 패턴별 쿨다운 시간
    final cooldowns = <String, String>{};
    for (final pattern in PatternType.values) {
      cooldowns[pattern.name] = '${getCooldownDuration(pattern).inSeconds}s';
    }
    summary['cooldownPeriods'] = cooldowns;
    
    // 변경된 설정값 개수
    int totalModified = 0;
    for (final pattern in PatternType.values) {
      final current = _currentConfig[pattern] ?? <String, double>{};
      final defaultValues = _defaultConfig[pattern] ?? <String, double>{};
      
      for (final key in current.keys) {
        if (current[key] != defaultValues[key]) {
          totalModified++;
        }
      }
    }
    summary['totalModifiedConfigs'] = totalModified;
    
    // 완화된 설정값들 (4,5번 패턴)
    summary['relaxedSettings'] = {
      'stealthIn': {
        'minTradeAmount': '2000만 → 500만 (75% 완화)',
        'buyRatioMin': '0.7 → 0.6 (14% 완화)',
        'cvThreshold': '추가됨 (5%)',
      },
      'blackHole': {
        'minTradeAmount': '5000만 → 1000만 (80% 완화)',
        'cvThreshold': '1% → 2% (100% 완화)',
        'buyRatioRange': '40-60% → 35-65% (25% 확대)',
      },
    };
    
    return summary;
  }

  /// 🎯 프리셋 설정

  /// 보수적 설정 (False Positive 최소화)
  void applyConservativePreset() {
    // Surge 패턴 강화
    updatePatternConfig(PatternType.surge, 'priceChangePercent', 0.6);
    updatePatternConfig(PatternType.surge, 'zScoreThreshold', 2.0);
    
    // FlashFire 패턴 강화
    updatePatternConfig(PatternType.flashFire, 'zScoreThreshold', 2.5);
    updatePatternConfig(PatternType.flashFire, 'buyRatioMin', 0.75);
    
    // StackUp 패턴 강화
    updatePatternConfig(PatternType.stackUp, 'consecutiveMin', 3);
    updatePatternConfig(PatternType.stackUp, 'rSquaredMin', 0.5);
    
    // StealthIn 패턴 강화 (하지만 여전히 기존보다는 완화)
    updatePatternConfig(PatternType.stealthIn, 'minTradeAmount', 8000000); // 800만
    updatePatternConfig(PatternType.stealthIn, 'buyRatioMin', 0.65);
    
    // BlackHole 패턴 강화 (하지만 여전히 기존보다는 완화)
    updatePatternConfig(PatternType.blackHole, 'minTradeAmount', 15000000); // 1500만
    updatePatternConfig(PatternType.blackHole, 'cvThreshold', 0.015);
  }

  /// 공격적 설정 (감지율 최대화)
  void applyAggressivePreset() {
    // Surge 패턴 완화
    updatePatternConfig(PatternType.surge, 'priceChangePercent', 0.3);
    updatePatternConfig(PatternType.surge, 'zScoreThreshold', 1.5);
    
    // FlashFire 패턴 완화
    updatePatternConfig(PatternType.flashFire, 'zScoreThreshold', 2.0);
    updatePatternConfig(PatternType.flashFire, 'buyRatioMin', 0.65);
    
    // StackUp 패턴 완화
    updatePatternConfig(PatternType.stackUp, 'consecutiveMin', 2);
    updatePatternConfig(PatternType.stackUp, 'rSquaredMin', 0.25);
    
    // StealthIn 패턴 최대 완화
    updatePatternConfig(PatternType.stealthIn, 'minTradeAmount', 3000000); // 300만
    updatePatternConfig(PatternType.stealthIn, 'buyRatioMin', 0.55);
    
    // BlackHole 패턴 최대 완화
    updatePatternConfig(PatternType.blackHole, 'minTradeAmount', 5000000); // 500만
    updatePatternConfig(PatternType.blackHole, 'cvThreshold', 0.03);
    updatePatternConfig(PatternType.blackHole, 'buyRatioMin', 0.3);
    updatePatternConfig(PatternType.blackHole, 'buyRatioMax', 0.7);
  }

  /// 균형 설정 (기본값)
  void applyBalancedPreset() {
    resetToDefault(null); // 모든 패턴을 기본값으로 리셋
  }

  /// 🧪 백테스팅용 설정 내보내기/가져오기
  
  /// 설정을 JSON 형태로 내보내기
  Map<String, dynamic> exportConfig() {
    final export = <String, dynamic>{
      'version': '4.0',
      'timestamp': DateTime.now().toIso8601String(),
      'patterns': <String, dynamic>{},
    };
    
    for (final pattern in PatternType.values) {
      export['patterns'][pattern.name] = {
        'config': getPatternConfig(pattern),
        'cooldownSeconds': getCooldownDuration(pattern).inSeconds,
      };
    }
    
    return export;
  }

  /// JSON에서 설정 가져오기
  void importConfig(Map<String, dynamic> configData) {
    if (configData['version'] != '4.0') {
      throw ArgumentError('Unsupported config version: ${configData['version']}');
    }
    
    final patterns = configData['patterns'] as Map<String, dynamic>?;
    if (patterns == null) return;
    
    for (final pattern in PatternType.values) {
      final patternData = patterns[pattern.name] as Map<String, dynamic>?;
      if (patternData == null) continue;
      
      final config = patternData['config'] as Map<String, dynamic>?;
      if (config == null) continue;
      
      // double 타입으로 변환하여 설정 적용
      final doubleConfig = <String, double>{};
      for (final entry in config.entries) {
        if (entry.value is num) {
          doubleConfig[entry.key] = (entry.value as num).toDouble();
        }
      }
      
      if (doubleConfig.isNotEmpty) {
        updateFullPatternConfig(pattern, doubleConfig);
      }
    }
  }

  /// 🎯 A/B 테스트용 설정 변형
  
  /// 특정 패턴만 조정한 변형 생성
  PatternConfig createVariant({
    PatternType? targetPattern,
    String? targetKey,
    double? multiplier,
  }) {
    if (targetPattern == null || targetKey == null || multiplier == null) {
      return PatternConfig(customConfig: getAllPatternConfigs());
    }
    
    final variantConfig = getAllPatternConfigs();
    final currentValue = getConfigValue(targetPattern, targetKey);
    
    if (currentValue > 0) {
      variantConfig[targetPattern] ??= <String, double>{};
      variantConfig[targetPattern]![targetKey] = currentValue * multiplier;
    }
    
    return PatternConfig(customConfig: variantConfig);
  }
}