import 'dart:async';
import 'dart:math';
import 'package:flutter/foundation.dart';
import '../../core/config/app_config.dart';
import '../../core/utils/logger.dart';
import '../../domain/entities/signal.dart';
import '../../domain/entities/trade.dart';
import '../../domain/repositories/signal_repository.dart';
import '../datasources/trade_remote_ds.dart';
import '../processors/trade_aggregator.dart';
import '../../core/utils/pattern_detector.dart';
import '../../core/utils/pattern_config.dart';
import '../../core/utils/market_data_context.dart';
import 'dart:async' show unawaited;


/// 🚀 SignalRepositoryImpl V4.1 - 메모리 최적화
/// 
/// 핵심 최적화:
/// - LRU 기반 메모리 관리
/// - 활성 패턴 필터링으로 불필요한 계산 제거
/// - 스트림 재사용으로 중복 생성 방지
/// - 적응형 정리 주기
class SignalRepositoryImpl implements SignalRepository {
  final TradeRemoteDataSource _remote;
  final TradeAggregator _aggregator;
  final PatternDetector _patternDetector;
  final PatternConfig _patternConfig;

  // 🔥 최적화: LRU 기반 마켓 컨텍스트 관리
  final Map<String, MarketDataContext> _marketContexts = {};
  final Map<String, DateTime> _marketLastAccess = {};
  static const int _maxMarketContexts = 50; // 메모리 제한

  // 🔥 최적화: 활성 패턴만 추적
  final Set<PatternType> _activePatterns = {};
  final Map<PatternType, List<Signal>> _signalLists = {};
  final Map<PatternType, bool> _patternEnabled = {};

  // 🔥 최적화: LRU 기반 중복 감지
  final Map<String, DateTime> _seenIdsWithTime = {};
  static const int _maxSeenIds = 1000; // 메모리 제한

  // 🎯 패턴별 스트림 컨트롤러
  final Map<PatternType, StreamController<List<Signal>>> _patternControllers = {};
  final StreamController<List<Signal>> _allSignalsController = 
      StreamController<List<Signal>>.broadcast();

  // 🔥 스트림 관리
  Stream<Trade>? _signalStream;
  StreamSubscription<Trade>? _signalSubscription;

  // 🚀 적응형 타이머 시스템
  Timer? _batchUpdateTimer;
  Timer? _memoryCleanupTimer;
  Timer? _activeCleanupTimer;

  // 📊 성능 모니터링
  final Map<PatternType, int> _signalCounts = {};
  final Map<PatternType, DateTime?> _lastSignalTimes = {};
  int _totalProcessedTrades = 0;
  DateTime? _lastProcessingTime;

  // 🔥 최적화: 메모리 압박 감지
  int _memoryPressureLevel = 0; // 0: 낮음, 1: 중간, 2: 높음

  // ==========================================================================
  // 초기화
  // ==========================================================================

  SignalRepositoryImpl(
    this._remote, {
    PatternDetector? patternDetector,
    PatternConfig? patternConfig,
  }) : _aggregator = TradeAggregator(),
       _patternDetector = patternDetector ?? PatternDetector(),
       _patternConfig = patternConfig ?? PatternConfig() {
    _initializePatterns();
    _startAdaptiveCleanup();
    log.i('🚀 SignalRepository V4.1 초기화 완료 - 메모리 최적화');
  }

  void _initializePatterns() {
    for (final pattern in PatternType.values) {
      _signalLists[pattern] = [];
      _patternEnabled[pattern] = false;
      _signalCounts[pattern] = 0;
      _patternControllers[pattern] = StreamController<List<Signal>>.broadcast();
      // _activePatterns.add(pattern); // 이 라인을 삭제하거나 주석 처리
    }

    if (kDebugMode) {
      log.i('🎯 패턴 초기화 완료: ${_activePatterns.length}개 활성 패턴');
    }
  }

  /// 🔥 최적화: 적응형 정리 시스템
  void _startAdaptiveCleanup() {
    // 메모리 정리: 압박 수준에 따라 주기 조절
    _memoryCleanupTimer = Timer.periodic(const Duration(minutes: 2), (_) {
      _adaptiveMemoryCleanup();
    });

    // 활성 상태 정리: 더 자주 수행
    _activeCleanupTimer = Timer.periodic(const Duration(minutes: 1), (_) {
      _cleanupActiveStates();
    });
  }

  /// 🔥 최적화: 적응형 메모리 정리
  void _adaptiveMemoryCleanup() {
    final now = DateTime.now();
    
    // 메모리 압박 수준 계산
    _memoryPressureLevel = _calculateMemoryPressure();
    
    // 압박 수준에 따른 정리 강도 조절
    final maxAge = _memoryPressureLevel == 2 ? 10 : // 높음: 10분
                   _memoryPressureLevel == 1 ? 20 : // 중간: 20분  
                   30; // 낮음: 30분

    _cleanupMarketContextsLRU(maxAge);
    _cleanupSeenIdsLRU(maxAge);

    if (kDebugMode && _memoryPressureLevel > 0) {
      log.d('🧹 적응형 정리 완료 (압박수준: $_memoryPressureLevel, 최대연령: ${maxAge}분)');
    }
  }

  /// 🔥 최적화: 메모리 압박 수준 계산
  int _calculateMemoryPressure() {
    final contextCount = _marketContexts.length;
    final seenIdsCount = _seenIdsWithTime.length;
    final totalSignals = _signalLists.values.fold(0, (sum, list) => sum + list.length);

    if (contextCount > _maxMarketContexts * 0.8 || 
        seenIdsCount > _maxSeenIds * 0.8 ||
        totalSignals > 500) {
      return 2; // 높음
    } else if (contextCount > _maxMarketContexts * 0.6 || 
               seenIdsCount > _maxSeenIds * 0.6 ||
               totalSignals > 300) {
      return 1; // 중간
    }
    return 0; // 낮음
  }

  /// 🔥 최적화: LRU 기반 마켓 컨텍스트 정리
  void _cleanupMarketContextsLRU(int maxAgeMinutes) {
    final now = DateTime.now();
    final cutoff = now.subtract(Duration(minutes: maxAgeMinutes));
    int removedCount = 0;

    // 오래된 항목들 제거
    final toRemove = <String>[];
    for (final entry in _marketLastAccess.entries) {
      if (entry.value.isBefore(cutoff)) {
        toRemove.add(entry.key);
      }
    }

    for (final market in toRemove) {
      final context = _marketContexts.remove(market);
      _marketLastAccess.remove(market);
      
      if (context != null) {
        context.cleanup(force: true, onlineMetrics: _patternDetector.metrics);
        removedCount++;
      }
    }

    // 개수 제한 초과시 LRU 제거
    if (_marketContexts.length > _maxMarketContexts) {
      final sortedByAccess = _marketLastAccess.entries.toList()
        ..sort((a, b) => a.value.compareTo(b.value));

      final excessCount = _marketContexts.length - _maxMarketContexts;
      for (int i = 0; i < excessCount; i++) {
        final market = sortedByAccess[i].key;
        final context = _marketContexts.remove(market);
        _marketLastAccess.remove(market);
        
        if (context != null) {
          context.cleanup(force: true, onlineMetrics: _patternDetector.metrics);
          removedCount++;
        }
      }
    }

    if (kDebugMode && removedCount > 0) {
      log.d('🧹 LRU 마켓 컨텍스트 정리: $removedCount개 제거');
    }
  }

  /// 🔥 최적화: LRU 기반 중복 감지 ID 정리
  void _cleanupSeenIdsLRU(int maxAgeMinutes) {
    final now = DateTime.now();
    final cutoff = now.subtract(Duration(minutes: maxAgeMinutes));
    
    _seenIdsWithTime.removeWhere((id, timestamp) => timestamp.isBefore(cutoff));

    // 개수 제한 초과시 LRU 제거
    if (_seenIdsWithTime.length > _maxSeenIds) {
      final sortedByTime = _seenIdsWithTime.entries.toList()
        ..sort((a, b) => a.value.compareTo(b.value));

      final excessCount = _seenIdsWithTime.length - _maxSeenIds;
      for (int i = 0; i < excessCount; i++) {
        _seenIdsWithTime.remove(sortedByTime[i].key);
      }
    }
  }

  /// 🔥 최적화: 활성 상태 정리
  void _cleanupActiveStates() {
    // 비활성화된 패턴을 활성 패턴 세트에서 제거
    _activePatterns.removeWhere((pattern) => !(_patternEnabled[pattern] ?? false));
    
    // 활성 패턴이 변경되었으면 로그
    final enabledCount = _patternEnabled.values.where((enabled) => enabled).length;
    if (_activePatterns.length != enabledCount) {
      _activePatterns.clear();
      for (final entry in _patternEnabled.entries) {
        if (entry.value) {
          _activePatterns.add(entry.key);
        }
      }
      
      if (kDebugMode) {
        log.d('🎯 활성 패턴 업데이트: ${_activePatterns.length}개');
      }
    }
  }

  // ==========================================================================
  // 🔥 핵심: 브로드캐스트 스트림 초기화
  // ==========================================================================

  void _initializeSignalStream(List<String> markets) {
    if (_signalStream != null) return;

    log.i('SignalRepositoryImpl V4.1: 신호 스트림 초기화 - ${markets.length}개 시장');

    _signalStream = _remote.watch(markets).asBroadcastStream();

    _signalSubscription = _signalStream!.listen(
      _processRawTradeForSignal,
      onError: (error, stackTrace) {
        log.e('Signal stream error: $error', stackTrace);
      },
      onDone: () {
        log.i('Signal stream done');
      },
    );
  }

  // ==========================================================================
  // 📊 마켓 데이터 컨텍스트 관리 (LRU 최적화)
  // ==========================================================================

  /// 🔥 최적화: LRU 기반 마켓 데이터 컨텍스트 관리
  MarketDataContext _getOrCreateMarketContext(String market) {
    final now = DateTime.now();
    
    // 접근 시간 업데이트 (LRU)
    _marketLastAccess[market] = now;
    
    return _marketContexts.putIfAbsent(
      market,
      () => MarketDataContext.empty(market),
    );
  }

  /// 모든 타임프레임 윈도우 업데이트 (온라인 지표 연동)
  void _updateMarketContext(Trade trade, DateTime timestamp) {
    final context = _getOrCreateMarketContext(trade.market);
    
    // 거래 간격 계산
    final interval = context.intervalWindow != null && 
                    context.intervalWindow!.timestamps.isNotEmpty
        ? timestamp.difference(context.intervalWindow!.timestamps.last).inSeconds.toDouble()
        : 10.0;
    
    // 매수 비율 (간단한 추정)
    final buyRatio = trade.isBuy ? 1.0 : 0.0;
    
    // 🔥 온라인 지표와 함께 모든 윈도우 업데이트
    context.updateWithOnlineMetrics(
      price: trade.price,
      volume: trade.total,
      timestamp: timestamp,
      buyRatio: buyRatio,
      interval: max(interval, 1.0),
      onlineMetrics: _patternDetector.metrics, // 온라인 지표 연동
    );
  }

  // ==========================================================================
  // 📥 원시 거래 데이터 처리 (중복 감지 최적화)
  // ==========================================================================

  void _processRawTradeForSignal(Trade trade) {
    try {
      final key = '${trade.market}/${trade.sequentialId}';
      final now = DateTime.now();

      // 🔥 최적화: LRU 기반 중복 감지
      if (_seenIdsWithTime.containsKey(key)) {
        return; // 이미 처리된 거래
      }
      
      _seenIdsWithTime[key] = now;

      _aggregator.processTrade(
        {
          'market': trade.market,
          'price': trade.price,
          'volume': trade.volume,
          'timestamp': trade.timestampMs,
          'isBuy': trade.isBuy,
          'sequential_id': trade.sequentialId,
        },
        onTradeProcessed: _handleAggregatedTrade,
      );
    } catch (e, stackTrace) {
      log.w('_processRawTradeForSignal error: $e', stackTrace);
    }
  }

  void _handleAggregatedTrade(Map<String, dynamic> aggregatedTrade) {
    if (_activePatterns.isEmpty) return; // 활성 패턴이 없으면 모든 분석 중단
    try {
      final trade = Trade(
        market: aggregatedTrade['market'] as String,
        price: aggregatedTrade['price'] as double,
        volume: aggregatedTrade['volume'] as double,
        side: (aggregatedTrade['isBuy'] as bool) ? 'BID' : 'ASK',
        changePrice: 0.0,
        changeState: 'EVEN',
        timestampMs: aggregatedTrade['timestamp'] as int,
        sequentialId: aggregatedTrade['sequential_id'] as String? ?? '',
      );

      final now = DateTime.fromMillisecondsSinceEpoch(trade.timestampMs);
      _updateMarketContext(trade, now);
      unawaited(_analyzePatterns(trade, now));
    } catch (e, stackTrace) {
      log.w('_handleAggregatedTrade error: $e', stackTrace);
    }
  }

  // ==========================================================================
  // 🎯 패턴 분석 (활성 패턴만 처리)
  // ==========================================================================

  /// 🔥 최적화: 활성 패턴만 분석
  Future<void> _analyzePatterns(Trade trade, DateTime now) async {

    try {
      final context = _getOrCreateMarketContext(trade.market);
      final detectedSignals = <Signal>[];

      // 🔥 최적화: 활성화된 패턴만 처리
      for (final pattern in _activePatterns) {
        try {
          // 🚀 개선된 패턴 감지 (단일 메서드, 명확한 파라미터)
          final signal = await _patternDetector.detectPattern(
            patternType: pattern,
            trade: trade,
            timestamp: now,
            context: context,
          );

          if (signal != null) {
            detectedSignals.add(signal);
            _signalCounts[pattern] = (_signalCounts[pattern] ?? 0) + 1;
            _lastSignalTimes[pattern] = now;
          }
        } catch (e, stackTrace) {
          log.w('Pattern analysis error: ${pattern.name} - $e', stackTrace);
        }
      }

      // 신호 추가
      for (final signal in detectedSignals) {
        _addSignal(signal.patternType, signal);
      }

      if (detectedSignals.isNotEmpty) {
        _scheduleBatchUpdate();
      }

      _totalProcessedTrades++;
      _lastProcessingTime = now;
    } catch (e, stackTrace) {
      log.e('_analyzePatterns error: $e', stackTrace);
    }
  }

  // ==========================================================================
  // 🚀 시그널 추가 및 관리
  // ==========================================================================

  void _addSignal(PatternType pattern, Signal signal) {
    final signalList = _signalLists[pattern];
    if (signalList == null) return;

    // 중복 신호 체크 (5분 이내)
    final cutoff = signal.detectedAt.subtract(const Duration(minutes: 5));
    final isDuplicate = signalList.any((existingSignal) =>
        existingSignal.market == signal.market &&
        existingSignal.detectedAt.isAfter(cutoff));

    if (isDuplicate) return;

    signalList.insert(0, signal);

    // 최대 신호 개수 제한
    if (signalList.length > AppConfig.maxSignalsPerPattern) {
      signalList.removeLast();
    }

    if (kDebugMode) {
      final confidence = signal.patternDetails['finalConfidence'] ?? 
                       signal.patternDetails['confidence'] ?? 0.0;
      log.i('🚨 V4.1 신호 감지: ${signal.patternType.displayName} - ${signal.market} '
          '(${signal.changePercent.toStringAsFixed(2)}%, 신뢰도: ${(confidence * 100).toStringAsFixed(1)}%)');
    }
  }

  /// 🚀 배치 업데이트 스케줄링
  void _scheduleBatchUpdate() {
    if (_batchUpdateTimer?.isActive != true) {
      _batchUpdateTimer = Timer(AppConfig.signalBatchInterval, _updateSignalStreams);
    }
  }

  /// 📊 모든 시그널 스트림 배치 업데이트
  void _updateSignalStreams() {
    try {
      for (final entry in _signalLists.entries) {
        final pattern = entry.key;
        final signals = List<Signal>.from(entry.value);

        final controller = _patternControllers[pattern];
        if (controller != null && !controller.isClosed) {
          controller.add(signals);
        }
      }

      final allSignals = _signalLists.values.expand((list) => list).toList();
      allSignals.sort((a, b) => b.detectedAt.compareTo(a.detectedAt));
      final recentSignals = allSignals.take(50).toList();

      if (!_allSignalsController.isClosed) {
        _allSignalsController.add(recentSignals);
      }

      if (kDebugMode && allSignals.isNotEmpty) {
        log.d('🚀 V4.1 신호 스트림 업데이트: ${allSignals.length}개 총 신호');
      }
    } catch (e, stackTrace) {
      log.w('_updateSignalStreams error: $e', stackTrace);
    }
  }

  // ==========================================================================
  // SignalRepository 인터페이스 구현 (변경사항 없음)
  // ==========================================================================

  @override
  Stream<List<Signal>> watchSignalsByPattern(
    PatternType patternType,
    List<String> markets,
  ) {
    _initializeSignalStream(markets);
    return _patternControllers[patternType]?.stream ?? const Stream.empty();
  }

  @override
  Stream<List<Signal>> watchAllSignals(List<String> markets) {
    _initializeSignalStream(markets);
    return _allSignalsController.stream;
  }

  @override
  void updatePatternThreshold(PatternType patternType, double threshold) {
    try {
      _patternConfig.updatePatternConfig(patternType, 'priceChangePercent', threshold);
      log.i('V4.1: 패턴 임계값 업데이트 - ${patternType.name}: $threshold');
    } catch (e) {
      log.w('패턴 임계값 업데이트 실패: $e');
    }
  }

  @override
  double getPatternThreshold(PatternType patternType) {
    return _patternConfig.getConfigValue(patternType, 'priceChangePercent');
  }

  @override
  void setPatternEnabled(PatternType patternType, bool enabled) {
    _patternEnabled[patternType] = enabled;
    
    // 🔥 최적화: 활성 패턴 세트 즉시 업데이트
    if (enabled) {
      _activePatterns.add(patternType);
    } else {
      _activePatterns.remove(patternType);
    }
    
    log.i('패턴 ${patternType.name} ${enabled ? '활성화' : '비활성화'} (활성패턴: ${_activePatterns.length}개)');
  }

  @override
  bool isPatternEnabled(PatternType patternType) {
    return _patternEnabled[patternType] ?? false;
  }

  @override
  void clearSignals(PatternType? patternType) {
    if (patternType != null) {
      _signalLists[patternType]?.clear();
      _patternControllers[patternType]?.add([]);
      _signalCounts[patternType] = 0;
    } else {
      for (final pattern in PatternType.values) {
        _signalLists[pattern]?.clear();
        _patternControllers[pattern]?.add([]);
        _signalCounts[pattern] = 0;
      }
      _patternDetector.clearAllCooldowns();
    }
    _scheduleBatchUpdate();
  }

  // ==========================================================================
  // 🆕 V4.1 확장 기능들 (메모리 상태 포함)
  // ==========================================================================

  @override
  void updatePatternConfig(PatternType pattern, String key, double value) {
    _patternConfig.updatePatternConfig(pattern, key, value);
  }

  @override
  Future<Map<String, dynamic>> getPatternStats(PatternType type) async {
    final signals = _signalLists[type] ?? [];
    final lastSignal = _lastSignalTimes[type];

    return {
      'patternType': type.name,
      'totalSignals': _signalCounts[type] ?? 0,
      'recentSignals': signals.length,
      'lastSignalTime': lastSignal?.toIso8601String(),
      'isEnabled': _patternEnabled[type] ?? false,
      'isActive': _activePatterns.contains(type),
      'cooldownStatus': _patternDetector.getCooldownStatus(),
      'config': _patternConfig.getPatternConfig(type),
    };
  }

  @override
  Future<Map<String, dynamic>> getSystemHealth() async {
    final now = DateTime.now();
    final uptime = _lastProcessingTime != null
        ? now.difference(_lastProcessingTime!).inMinutes
        : 0;

    final patternStats = <String, dynamic>{};
    for (final pattern in PatternType.values) {
      patternStats[pattern.name] = await getPatternStats(pattern);
    }

    final marketStats = <String, dynamic>{};
    for (final entry in _marketContexts.entries) {
      final quality = entry.value.getDataQuality(onlineMetrics: _patternDetector.metrics);
      marketStats[entry.key] = {
        'quality': quality['overall'],
        'score': quality['overallScore'],
        'timeframes': entry.value.availableTimeframes.length,
        'onlineMetrics': quality['onlineMetrics'],
        'lastAccess': _marketLastAccess[entry.key]?.toIso8601String(),
      };
    }

    final onlineMetricsHealth = _patternDetector.metrics.getSystemHealth();

    return {
      'version': '4.1-Optimized',
      'status': 'healthy',
      'uptime': uptime,
      'totalProcessedTrades': _totalProcessedTrades,
      'lastProcessingTime': _lastProcessingTime?.toIso8601String(),
      'activePatterns': _activePatterns.length,
      'enabledPatterns': _patternEnabled.values.where((enabled) => enabled).length,
      'trackedMarkets': _marketContexts.length,
      'memoryPressure': _memoryPressureLevel,
      'memoryStats': {
        'marketContexts': _marketContexts.length,
        'maxMarketContexts': _maxMarketContexts,
        'seenIds': _seenIdsWithTime.length,
        'maxSeenIds': _maxSeenIds,
        'totalSignals': _signalLists.values.fold(0, (sum, list) => sum + list.length),
      },
      'patternStats': patternStats,
      'marketStats': marketStats,
      'onlineMetricsSystem': onlineMetricsHealth,
      'optimizations': [
        'LRU Memory Management',
        'Active Pattern Filtering', 
        'Adaptive Cleanup Intervals',
        'Memory Pressure Detection',
        'Stream Reuse Prevention',
        'Online RSI/MACD Integration',
        'O(1) Indicator Calculation',
        'Dependency Injection Architecture',
      ],
    };
  }

  @override
  Map<String, dynamic> getMarketDataQuality() {
    final qualityReport = <String, dynamic>{};

    for (final entry in _marketContexts.entries) {
      qualityReport[entry.key] = entry.value.getDataQuality(
        onlineMetrics: _patternDetector.metrics
      );
    }

    final onlineHealth = _patternDetector.metrics.getSystemHealth();

    return {
      'totalMarkets': _marketContexts.length,
      'maxMarkets': _maxMarketContexts,
      'memoryPressure': _memoryPressureLevel,
      'markets': qualityReport,
      'healthyMarkets': qualityReport.values
          .where((q) => q['overall'] == 'EXCELLENT' || q['overall'] == 'GOOD')
          .length,
      'onlineMetricsSummary': {
        'totalMarkets': onlineHealth['totalMarkets'],
        'healthyMarkets': onlineHealth['healthyMarkets'],
        'staleMarkets': onlineHealth['staleMarkets'],
      },
    };
  }

  @override
  void applyPatternPreset(String presetName) {
    switch (presetName.toLowerCase()) {
      case 'conservative':
        _patternConfig.applyConservativePreset();
        break;
      case 'aggressive':
        _patternConfig.applyAggressivePreset();
        break;
      case 'balanced':
        _patternConfig.applyBalancedPreset();
        break;
      default:
        throw ArgumentError('Unknown preset: $presetName');
    }

    log.i('패턴 프리셋 적용: $presetName');
  }

  @override
  Map<String, dynamic> exportConfiguration() {
    return {
      'version': '4.1',
      'timestamp': DateTime.now().toIso8601String(),
      'patternConfig': _patternConfig.exportConfig(),
      'patternEnabled': _patternEnabled.map((k, v) => MapEntry(k.name, v)),
      'systemSettings': {
        'maxSignalsPerPattern': AppConfig.maxSignalsPerPattern,
        'signalCacheSize': AppConfig.signalCacheSize,
        'batchInterval': AppConfig.signalBatchInterval.inMilliseconds,
        'maxMarketContexts': _maxMarketContexts,
        'maxSeenIds': _maxSeenIds,
      },
      'memoryOptimizations': {
        'lruEnabled': true,
        'adaptiveCleanup': true,
        'activePatternFiltering': true,
      },
    };
  }

  @override
  void importConfiguration(Map<String, dynamic> config) {
    try {
      // 패턴 설정 가져오기
      if (config['patternConfig'] != null) {
        _patternConfig.importConfig(config['patternConfig']);
      }

      // 패턴 활성화 상태 가져오기
      if (config['patternEnabled'] != null) {
        final enabledMap = config['patternEnabled'] as Map<String, dynamic>;
        for (final pattern in PatternType.values) {
          if (enabledMap.containsKey(pattern.name)) {
            final enabled = enabledMap[pattern.name] as bool;
            _patternEnabled[pattern] = enabled;
            
            // 🔥 최적화: 활성 패턴 세트 업데이트
            if (enabled) {
              _activePatterns.add(pattern);
            } else {
              _activePatterns.remove(pattern);
            }
          }
        }
      }

      log.i('설정 가져오기 완료 (활성패턴: ${_activePatterns.length}개)');
    } catch (e, stackTrace) {
      log.e('설정 가져오기 실패: $e', stackTrace);
      rethrow;
    }
  }

  @override
  Stream<Map<String, dynamic>> watchPerformanceMetrics() {
    return Stream.periodic(const Duration(seconds: 10), (_) {
      final onlineMetricsHealth = _patternDetector.metrics.getSystemHealth();
      
      return {
        'timestamp': DateTime.now().toIso8601String(),
        'version': '4.1-Optimized',
        'totalProcessedTrades': _totalProcessedTrades,
        'signalCounts': Map.from(_signalCounts),
        'activeMarkets': _marketContexts.length,
        'activePatterns': _activePatterns.length,
        'memoryPressure': _memoryPressureLevel,
        'cooldownStatus': _patternDetector.getCooldownStatus(),
        'memoryUsage': {
          'totalSignals': _signalLists.values.fold(0, (sum, list) => sum + list.length),
          'seenIdsCount': _seenIdsWithTime.length,
          'marketContexts': _marketContexts.length,
          'memoryUtilization': {
            'marketContexts': '${(_marketContexts.length / _maxMarketContexts * 100).toStringAsFixed(1)}%',
            'seenIds': '${(_seenIdsWithTime.length / _maxSeenIds * 100).toStringAsFixed(1)}%',
          },
        },
        'performance': {
          'activePatternFiltering': _activePatterns.length < PatternType.values.length,
          'lruCleanupActive': _memoryPressureLevel > 0,
          'adaptiveCleanupLevel': _memoryPressureLevel,
        },
        'onlineMetrics': {
          'totalMarkets': onlineMetricsHealth['totalMarkets'],
          'healthyMarkets': onlineMetricsHealth['healthyMarkets'],
          'staleMarkets': onlineMetricsHealth['staleMarkets'],
        },
        'architecture': 'V4.1 - Memory Optimized + LRU + Active Pattern Filtering',
      };
    });
  }

  // ==========================================================================
  // 🔥 V4.1 추가: 메모리 최적화 제어 메서드들
  // ==========================================================================

  /// 메모리 압박 수준 강제 설정 (테스트/디버깅용)
  void setMemoryPressureLevel(int level) {
    _memoryPressureLevel = level.clamp(0, 2);
    log.i('메모리 압박 수준 설정: $_memoryPressureLevel');
  }

  /// 즉시 메모리 정리 수행
  void forceMemoryCleanup() {
    _adaptiveMemoryCleanup();
    log.i('강제 메모리 정리 수행 완료');
  }

  /// LRU 상태 조회
  Map<String, dynamic> getLRUStatus() {
    final now = DateTime.now();
    
    // 마켓 컨텍스트 LRU 상태
    final marketLRU = _marketLastAccess.entries
        .map((e) => {
          'market': e.key,
          'lastAccess': e.value.toIso8601String(),
          'ageMinutes': now.difference(e.value).inMinutes,
        })
        .toList()
      ..sort((a, b) => (a['ageMinutes'] as int).compareTo(b['ageMinutes'] as int));

    // Seen IDs LRU 상태 (최신 10개만)
    final seenIdsLRU = _seenIdsWithTime.entries
        .map((e) => {
          'id': e.key,
          'timestamp': e.value.toIso8601String(),
          'ageMinutes': now.difference(e.value).inMinutes,
        })
        .toList()
      ..sort((a, b) => (b['ageMinutes'] as int).compareTo(a['ageMinutes'] as int))
      ..take(10);

    return {
      'memoryPressureLevel': _memoryPressureLevel,
      'marketContexts': {
        'total': _marketContexts.length,
        'limit': _maxMarketContexts,
        'utilization': '${(_marketContexts.length / _maxMarketContexts * 100).toStringAsFixed(1)}%',
        'lruList': marketLRU.take(10).toList(),
      },
      'seenIds': {
        'total': _seenIdsWithTime.length,
        'limit': _maxSeenIds,
        'utilization': '${(_seenIdsWithTime.length / _maxSeenIds * 100).toStringAsFixed(1)}%',
        'oldestEntries': seenIdsLRU.toList(),
      },
      'activePatterns': {
        'active': _activePatterns.length,
        'total': PatternType.values.length,
        'patterns': _activePatterns.map((p) => p.name).toList(),
      },
    };
  }

  /// 패턴 활성화 상태 일괄 설정
  void setBulkPatternEnabled(Map<PatternType, bool> settings) {
    _activePatterns.clear();
    
    for (final entry in settings.entries) {
      _patternEnabled[entry.key] = entry.value;
      if (entry.value) {
        _activePatterns.add(entry.key);
      }
    }
    
    log.i('패턴 일괄 설정 완료: ${_activePatterns.length}개 활성화');
  }

// lib/data/repositories/signal_repository_impl.dart
// 기존 코드 끝부분 (dispose() 메서드 위)에 다음 메서드들을 추가:

  // ==========================================================================
  // 🆕 V4.1 모달용 메서드 구현 (Repository 인터페이스 준수)
  // ==========================================================================

  @override
  double getCurrentThresholdValue(PatternType pattern, String key) {
    try {
      // PatternConfig에서 현재 설정값 직접 조회
      return _patternConfig.getConfigValue(pattern, key);
    } catch (e) {
      // 해당 키가 없으면 기본값 반환
      if (AppConfig.enableTradeLog) {
        log.w('⚠️ getCurrentThresholdValue failed for ${pattern.name}.$key: $e');
      }
      
      // 패턴별 기본값 반환
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
  }

  @override
  void setSystemActive(bool active) {
    if (AppConfig.enableTradeLog) {
      log.i('🎯 System ${active ? "activated" : "deactivated"} - ${active ? "enabling" : "disabling"} all patterns');
    }
    
    // 모든 패턴을 일괄 활성화/비활성화
    for (final pattern in PatternType.values) {
      setPatternEnabled(pattern, active);
    }
    
    if (AppConfig.enableTradeLog) {
      log.i('✅ System activation complete: ${_activePatterns.length}/${PatternType.values.length} patterns active');
    }
  }

  @override
  Map<String, dynamic> getSystemStatus() {
    final enabledPatterns = _patternEnabled.values.where((enabled) => enabled).length;
    final enabledPatternsList = PatternType.values
        .where((pattern) => _patternEnabled[pattern] ?? false)
        .map((p) => p.name)
        .toList();
    
    return {
      'isSystemActive': enabledPatterns > 0,
      'activePatterns': _activePatterns.length,
      'enabledPatterns': enabledPatterns,
      'totalPatterns': PatternType.values.length,
      'enabledPatternsList': enabledPatternsList,
      'activePatternsList': _activePatterns.map((p) => p.name).toList(),
      'systemHealth': _memoryPressureLevel == 0 ? 'healthy' : 
                     _memoryPressureLevel == 1 ? 'warning' : 'critical',
      'memoryPressure': _memoryPressureLevel,
      'timestamp': DateTime.now().toIso8601String(),
      'version': '4.1-Repository',
      'totalProcessedTrades': _totalProcessedTrades,
      'trackedMarkets': _marketContexts.length,
    };
  }

  @override
  Map<String, dynamic> getOnlineMetricsHealth() {
    try {
      // PatternDetector의 온라인 지표 헬스 조회
      final onlineHealth = _patternDetector.metrics.getSystemHealth();
      
      return {
        'status': onlineHealth['status'] ?? 'unknown',
        'message': onlineHealth['message'] ?? 'Online metrics system operational',
        'totalMarkets': onlineHealth['totalMarkets'] ?? 0,
        'healthyMarkets': onlineHealth['healthyMarkets'] ?? 0,
        'staleMarkets': onlineHealth['staleMarkets'] ?? 0,
        'lastUpdate': onlineHealth['lastUpdate'],
        'rsiHealth': onlineHealth['rsiHealth'],
        'macdHealth': onlineHealth['macdHealth'],
        'timestamp': DateTime.now().toIso8601String(),
        'version': '4.1-Repository',
        'source': 'PatternDetector.metrics',
      };
    } catch (e) {
      if (AppConfig.enableTradeLog) {
        log.w('⚠️ getOnlineMetricsHealth failed: $e');
      }
      
      return {
        'status': 'error',
        'message': 'Failed to retrieve online metrics health: $e',
        'totalMarkets': 0,
        'healthyMarkets': 0,
        'staleMarkets': 0,
        'timestamp': DateTime.now().toIso8601String(),
        'version': '4.1-Repository',
        'source': 'Repository-Fallback',
      };
    }
  }

  @override
  void resetOnlineMetrics([String? market]) {
    try {
      if (market != null) {
        // 특정 마켓의 온라인 지표 리셋
        _patternDetector.metrics.resetMarket(market);
        
        // 해당 마켓의 컨텍스트도 리셋
        final context = _marketContexts[market];
        if (context != null) {
          context.cleanup(force: true, onlineMetrics: _patternDetector.metrics);
          _marketContexts.remove(market);
          _marketLastAccess.remove(market);
        }
        
        if (AppConfig.enableTradeLog) {
          log.i('🔄 Online metrics reset for market: $market');
        }
      } else {
        // 모든 마켓의 온라인 지표 리셋
        _patternDetector.metrics.resetAll();
        
        // 모든 마켓 컨텍스트 리셋
        for (final context in _marketContexts.values) {
          context.cleanup(force: true, onlineMetrics: _patternDetector.metrics);
        }
        _marketContexts.clear();
        _marketLastAccess.clear();
        
        if (AppConfig.enableTradeLog) {
          log.i('🔄 Online metrics reset for all markets');
        }
      }
    } catch (e) {
      if (AppConfig.enableTradeLog) {
        log.e('❌ resetOnlineMetrics failed: $e');
      }
      // 에러 발생 시에도 최소한의 정리 수행
      if (market == null) {
        _marketContexts.clear();
        _marketLastAccess.clear();
      } else {
        _marketContexts.remove(market);
        _marketLastAccess.remove(market);
      }
    }
  }
  
  // ==========================================================================
  // 리소스 정리 (강화된 메모리 정리)
  // ==========================================================================

  @override
  Future<void> dispose() async {
    log.i('SignalRepositoryImpl V4.1: dispose() 시작');

    _batchUpdateTimer?.cancel();
    _memoryCleanupTimer?.cancel();
    _activeCleanupTimer?.cancel();

    _aggregator.flushTrades(onTradeProcessed: (_) {});

    await _signalSubscription?.cancel();
    _signalStream = null;

    // 스트림 컨트롤러 정리
    for (final controller in _patternControllers.values) {
      await controller.close();
    }
    await _allSignalsController.close();

    // 🔥 강화된 메모리 정리
    for (final context in _marketContexts.values) {
      context.cleanup(force: true, onlineMetrics: _patternDetector.metrics);
    }
    _marketContexts.clear();
    _marketLastAccess.clear();

    // 신호 및 캐시 정리
    _signalLists.clear();
    _signalCounts.clear();
    _lastSignalTimes.clear();
    _seenIdsWithTime.clear();
    _activePatterns.clear();

    // PatternDetector 정리
    _patternDetector.dispose();

    log.i('SignalRepositoryImpl V4.1: dispose() 완료 - 메모리 최적화 포함');
  }
}

