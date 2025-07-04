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

/// 🚀 SignalRepositoryImpl V4.0 - 완전히 개선된 구조
/// 
/// 주요 개선사항:
/// - PatternDetector 의존성 주입 방식으로 변경
/// - MarketDataContext로 파라미터 지옥 해결
/// - 책임 분리 및 코드 단순화
/// - 테스트 가능한 구조
/// - 메모리 효율성 개선
class SignalRepositoryImpl implements SignalRepository {
  final TradeRemoteDataSource _remote;
  final TradeAggregator _aggregator;
  final PatternDetector _patternDetector;
  final PatternConfig _patternConfig;

  // 📊 마켓별 데이터 컨텍스트 관리
  final Map<String, MarketDataContext> _marketContexts = {};

  // 🎯 신호 관리 시스템
  final Map<PatternType, List<Signal>> _signalLists = {};
  final Map<PatternType, bool> _patternEnabled = {};
  final Set<String> _seenIds = {};

  // 🎯 패턴별 스트림 컨트롤러
  final Map<PatternType, StreamController<List<Signal>>> _patternControllers = {};
  final StreamController<List<Signal>> _allSignalsController = 
      StreamController<List<Signal>>.broadcast();

  // 🔥 스트림 관리
  Stream<Trade>? _signalStream;
  StreamSubscription<Trade>? _signalSubscription;

  // 🚀 배치 처리 및 정리 타이머
  Timer? _batchUpdateTimer;
  Timer? _cleanupTimer;

  // 📊 성능 모니터링
  final Map<PatternType, int> _signalCounts = {};
  final Map<PatternType, DateTime?> _lastSignalTimes = {};
  int _totalProcessedTrades = 0;
  DateTime? _lastProcessingTime;

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
    _startCleanupTimer();
    log.i('🚀 SignalRepository V4.0 초기화 완료 - 개선된 구조');
  }

  void _initializePatterns() {
    for (final pattern in PatternType.values) {
      _signalLists[pattern] = [];
      _patternEnabled[pattern] = true;
      _signalCounts[pattern] = 0;
      _patternControllers[pattern] = StreamController<List<Signal>>.broadcast();
    }

    if (kDebugMode) {
      log.i('🎯 패턴 초기화 완료: ${PatternType.values.length}개 패턴');
    }
  }

  /// 🧹 메모리 정리 타이머 시작
  void _startCleanupTimer() {
    _cleanupTimer = Timer.periodic(const Duration(minutes: 5), (_) {
      _cleanupMarketContexts();
      _cleanupSeenIds();
    });
  }

  /// 🧹 마켓 컨텍스트 정리 (온라인 지표 포함)
  void _cleanupMarketContexts() {
    final now = DateTime.now();
    int removedMarkets = 0;

    _marketContexts.removeWhere((market, context) {
      // 🆕 온라인 지표 포함 데이터 품질 검사
      final quality = context.getDataQuality(onlineMetrics: _patternDetector.metrics);
      final isHealthy = quality['overall'] != 'POOR';
      
      // 최근 활동 확인
      final hasRecentActivity = context.shortestPriceWindow.timestamps.isNotEmpty &&
          now.difference(context.shortestPriceWindow.timestamps.last).inMinutes < 30;
      
      if (!isHealthy || !hasRecentActivity) {
        // 🆕 온라인 지표도 함께 정리
        context.cleanup(force: true, onlineMetrics: _patternDetector.metrics);
        removedMarkets++;
        return true;
      }
      
      return false;
    });

    if (kDebugMode && removedMarkets > 0) {
      log.d('🧹 마켓 컨텍스트 정리: $removedMarkets개 비활성 시장 제거 (온라인 지표 포함)');
    }
  }

  /// 🧹 중복 감지 ID 정리
  void _cleanupSeenIds() {
    if (_seenIds.length > AppConfig.signalCacheSize) {
      final excess = _seenIds.length - AppConfig.signalCacheSize;
      final toRemove = _seenIds.take(excess).toList();
      _seenIds.removeAll(toRemove);
    }
  }

  // ==========================================================================
  // 🔥 핵심: 브로드캐스트 스트림 초기화
  // ==========================================================================

  void _initializeSignalStream(List<String> markets) {
    if (_signalStream != null) return;

    log.i('SignalRepositoryImpl V4.0: 신호 스트림 초기화 - ${markets.length}개 시장');

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
  // 📊 마켓 데이터 컨텍스트 관리
  // ==========================================================================

  /// 마켓 데이터 컨텍스트 생성 또는 조회
  MarketDataContext _getOrCreateMarketContext(String market) {
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
  // 📥 원시 거래 데이터 처리
  // ==========================================================================

  void _processRawTradeForSignal(Trade trade) {
    try {
      final key = '${trade.market}/${trade.sequentialId}';

      if (!_seenIds.add(key)) return;

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
      _analyzePatterns(trade, now);
    } catch (e, stackTrace) {
      log.w('_handleAggregatedTrade error: $e', stackTrace);
    }
  }

  // ==========================================================================
  // 🎯 패턴 분석 (단순화된 로직)
  // ==========================================================================

  /// 🎯 메인 패턴 분석 로직
  void _analyzePatterns(Trade trade, DateTime now) {
    try {
      final context = _getOrCreateMarketContext(trade.market);
      final detectedSignals = <Signal>[];

      // 🔥 각 패턴에 대해 감지 수행
      for (final pattern in PatternType.values) {
        if (!(_patternEnabled[pattern] ?? false)) continue;

        try {
          // 🚀 개선된 패턴 감지 (단일 메서드, 명확한 파라미터)
          final signal = _patternDetector.detectPattern(
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
      log.i('🚨 V4.0 신호 감지: ${signal.patternType.displayName} - ${signal.market} '
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
        log.d('🚀 V4.0 신호 스트림 업데이트: ${allSignals.length}개 총 신호');
      }
    } catch (e, stackTrace) {
      log.w('_updateSignalStreams error: $e', stackTrace);
    }
  }

  // ==========================================================================
  // SignalRepository 인터페이스 구현
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
    // 설정 업데이트 로직 (구체적인 키에 따라 다를 수 있음)
    try {
      _patternConfig.updatePatternConfig(patternType, 'priceChangePercent', threshold);
      log.i('V4.0: 패턴 임계값 업데이트 - ${patternType.name}: $threshold');
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
    log.i('패턴 ${patternType.name} ${enabled ? '활성화' : '비활성화'}');
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
  // 🆕 V4.0 확장 기능들
  // ==========================================================================

  /// 패턴 설정 업데이트
  @override
  void updatePatternConfig(PatternType pattern, String key, double value) {
    _patternConfig.updatePatternConfig(pattern, key, value);
  }

  /// 패턴별 통계 정보
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
      'cooldownStatus': _patternDetector.getCooldownStatus(),
      'config': _patternConfig.getPatternConfig(type),
    };
  }

  /// 시스템 헬스 체크 (온라인 지표 포함)
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

    // 🆕 온라인 지표 포함 마켓 컨텍스트 상태
    final marketStats = <String, dynamic>{};
    for (final entry in _marketContexts.entries) {
      final quality = entry.value.getDataQuality(onlineMetrics: _patternDetector.metrics);
      marketStats[entry.key] = {
        'quality': quality['overall'],
        'score': quality['overallScore'],
        'timeframes': entry.value.availableTimeframes.length,
        'onlineMetrics': quality['onlineMetrics'], // 온라인 지표 상태 포함
      };
    }

    // 🆕 전체 온라인 지표 시스템 건강성
    final onlineMetricsHealth = _patternDetector.metrics.getSystemHealth();

    return {
      'version': '4.1-Online',
      'status': 'healthy',
      'uptime': uptime,
      'totalProcessedTrades': _totalProcessedTrades,
      'lastProcessingTime': _lastProcessingTime?.toIso8601String(),
      'activePatterns': _patternEnabled.values.where((enabled) => enabled).length,
      'trackedMarkets': _marketContexts.length,
      'patternStats': patternStats,
      'marketStats': marketStats,
      'onlineMetricsSystem': onlineMetricsHealth, // 온라인 지표 시스템 전체 상태
      'improvements': [
        'Online RSI/MACD Integration',
        'Stream Gap Auto-Recovery', 
        'O(1) Indicator Calculation',
        'Real Divergence Detection',
        'Dependency Injection Architecture',
        'Fixed Parameter Hell',
        'Enhanced Memory Management',
        'Testable Structure',
      ],
    };
  }

  /// 마켓별 데이터 품질 조회 (온라인 지표 포함)
  @override
  Map<String, dynamic> getMarketDataQuality() {
    final qualityReport = <String, dynamic>{};

    for (final entry in _marketContexts.entries) {
      // 🆕 온라인 지표 포함 품질 검사
      qualityReport[entry.key] = entry.value.getDataQuality(
        onlineMetrics: _patternDetector.metrics
      );
    }

    // 🆕 온라인 지표 건강성 요약
    final onlineHealth = _patternDetector.metrics.getSystemHealth();

    return {
      'totalMarkets': _marketContexts.length,
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

  /// 패턴 설정 프리셋 적용
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

  /// 설정 내보내기/가져오기
  @override
  Map<String, dynamic> exportConfiguration() {
    return {
      'version': '4.0',
      'timestamp': DateTime.now().toIso8601String(),
      'patternConfig': _patternConfig.exportConfig(),
      'patternEnabled': _patternEnabled.map((k, v) => MapEntry(k.name, v)),
      'systemSettings': {
        'maxSignalsPerPattern': AppConfig.maxSignalsPerPattern,
        'signalCacheSize': AppConfig.signalCacheSize,
        'batchInterval': AppConfig.signalBatchInterval.inMilliseconds,
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
            _patternEnabled[pattern] = enabledMap[pattern.name] as bool;
          }
        }
      }

      log.i('설정 가져오기 완료');
    } catch (e, stackTrace) {
      log.e('설정 가져오기 실패: $e', stackTrace);
      rethrow;
    }
  }

  /// 성능 메트릭스 스트림 (온라인 지표 포함)
  @override
  Stream<Map<String, dynamic>> watchPerformanceMetrics() {
    return Stream.periodic(const Duration(seconds: 10), (_) {
      final onlineMetricsHealth = _patternDetector.metrics.getSystemHealth();
      
      return {
        'timestamp': DateTime.now().toIso8601String(),
        'version': '4.1-Online',
        'totalProcessedTrades': _totalProcessedTrades,
        'signalCounts': Map.from(_signalCounts),
        'activeMarkets': _marketContexts.length,
        'cooldownStatus': _patternDetector.getCooldownStatus(),
        'memoryUsage': {
          'totalSignals': _signalLists.values.fold(0, (sum, list) => sum + list.length),
          'seenIdsCount': _seenIds.length,
          'marketContexts': _marketContexts.length,
        },
        'onlineMetrics': {
          'totalMarkets': onlineMetricsHealth['totalMarkets'],
          'healthyMarkets': onlineMetricsHealth['healthyMarkets'],
          'staleMarkets': onlineMetricsHealth['staleMarkets'],
        },
        'architecture': 'V4.1 - Online Indicators + Dependency Injection + Clean Structure',
      };
    });
  }

  // ==========================================================================
  // 리소스 정리
  // ==========================================================================

  @override
  Future<void> dispose() async {
    log.i('SignalRepositoryImpl V4.0: dispose() 시작');

    _batchUpdateTimer?.cancel();
    _cleanupTimer?.cancel();

    _aggregator.flushTrades(onTradeProcessed: (_) {});

    await _signalSubscription?.cancel();
    _signalStream = null;

    // 스트림 컨트롤러 정리
    for (final controller in _patternControllers.values) {
      await controller.close();
    }
    await _allSignalsController.close();

    // 마켓 컨텍스트 정리 (온라인 지표 포함)
    for (final context in _marketContexts.values) {
      context.cleanup(force: true, onlineMetrics: _patternDetector.metrics);
    }
    _marketContexts.clear();

    // 신호 및 캐시 정리
    _signalLists.clear();
    _signalCounts.clear();
    _lastSignalTimes.clear();
    _seenIds.clear();

    // PatternDetector 정리 (온라인 지표 포함)
    _patternDetector.dispose();

    log.i('SignalRepositoryImpl V4.1: dispose() 완료 - 온라인 지표 포함');
  }
}