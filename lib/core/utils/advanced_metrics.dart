import 'dart:math';
import 'dart:isolate';
import 'dart:developer' as developer;
import 'package:flutter/foundation.dart';
import 'rolling_window.dart';

// ==========================================================================
// 🔥 V5.0 스트림 동기화된 온라인 계산기들 (기존 유지 + 개선)
// ==========================================================================

/// V5.0: 향상된 스트림 동기화 OnlineRSI
class StreamAwareOnlineRSI {
  final int period;
  final Duration maxGap;
  final List<double> _prices = [];
  double _avgGain = 0.0;
  double _avgLoss = 0.0;
  bool _isInitialized = false;
  DateTime? _lastUpdate;

  StreamAwareOnlineRSI({
    required this.period,
    this.maxGap = const Duration(seconds: 10),
  });

  void update(double price, DateTime timestamp) {
    // 🔥 스트림 끊김 감지 및 자동 리셋
    if (_lastUpdate != null &&
        timestamp.difference(_lastUpdate!).abs() > maxGap) {
      reset();
      if (_prices.isNotEmpty) {
        developer.log('RSI Reset: Stream gap detected (${timestamp.difference(_lastUpdate!).inSeconds}s)', 
                     name: 'StreamAwareOnlineRSI');
      }
    }

    _lastUpdate = timestamp;
    _prices.add(price);
    
    if (_prices.length < 2) return;

    final change = _prices.last - _prices[_prices.length - 2];
    final gain = change > 0 ? change : 0.0;
    final loss = change < 0 ? change.abs() : 0.0;

    if (!_isInitialized && _prices.length >= period + 1) {
      // 초기 평균 계산
      double gainSum = 0.0;
      double lossSum = 0.0;
      
      for (int i = 1; i <= period; i++) {
        final ch = _prices[i] - _prices[i - 1];
        if (ch > 0) {
          gainSum += ch;
        } else {
          lossSum += ch.abs();
        }
      }
      
      _avgGain = gainSum / period;
      _avgLoss = lossSum / period;
      _isInitialized = true;
    } else if (_isInitialized) {
      // 지수이동평균 업데이트
      _avgGain = ((_avgGain * (period - 1)) + gain) / period;
      _avgLoss = ((_avgLoss * (period - 1)) + loss) / period;
    }

    // V5.0: 메모리 관리 강화 - 최대 period * 2 개만 유지
    if (_prices.length > period * 2) {
      _prices.removeAt(0);
    }
  }

  double get current {
    if (!_isInitialized || _avgLoss == 0) return 50.0;
    final rs = _avgGain / _avgLoss;
    return 100.0 - (100.0 / (1.0 + rs));
  }

  bool get isReady => _isInitialized;
  bool get isStale => _lastUpdate != null &&
      DateTime.now().difference(_lastUpdate!).abs() > maxGap;

  void reset() {
    _prices.clear();
    _avgGain = 0.0;
    _avgLoss = 0.0;
    _isInitialized = false;
    _lastUpdate = null;
  }

  Map<String, dynamic> getHealthStatus() {
    return {
      'isReady': isReady,
      'isStale': isStale,
      'dataPoints': _prices.length,
      'lastUpdate': _lastUpdate?.toIso8601String(),
      'timeSinceLastUpdate': _lastUpdate != null
          ? DateTime.now().difference(_lastUpdate!).inSeconds
          : null,
    };
  }
}

/// V5.0: 향상된 스트림 동기화 OnlineMACD
class StreamAwareOnlineMACD {
  final int fastPeriod;
  final int slowPeriod;
  final int signalPeriod;
  final Duration maxGap;
  
  double _fastEMA = 0.0;
  double _slowEMA = 0.0;
  double _signalEMA = 0.0;
  final List<double> _macdHistory = [];
  bool _isInitialized = false;
  int _count = 0;
  DateTime? _lastUpdate;

  StreamAwareOnlineMACD({
    this.fastPeriod = 12,
    this.slowPeriod = 26,
    this.signalPeriod = 9,
    this.maxGap = const Duration(seconds: 10),
  });

  void update(double price, DateTime timestamp) {
    // 🔥 스트림 끊김 감지 및 자동 리셋
    if (_lastUpdate != null &&
        timestamp.difference(_lastUpdate!).abs() > maxGap) {
      reset();
      developer.log('MACD Reset: Stream gap detected (${timestamp.difference(_lastUpdate!).inSeconds}s)', 
                   name: 'StreamAwareOnlineMACD');
    }

    _lastUpdate = timestamp;
    _count++;

    final fastAlpha = 2.0 / (fastPeriod + 1);
    final slowAlpha = 2.0 / (slowPeriod + 1);
    final signalAlpha = 2.0 / (signalPeriod + 1);

    if (_count == 1) {
      _fastEMA = price;
      _slowEMA = price;
    } else {
      _fastEMA = (price * fastAlpha) + (_fastEMA * (1 - fastAlpha));
      _slowEMA = (price * slowAlpha) + (_slowEMA * (1 - slowAlpha));
    }

    if (_count >= slowPeriod) {
      final macd = _fastEMA - _slowEMA;
      _macdHistory.add(macd);

      if (_macdHistory.length == 1) {
        _signalEMA = macd;
      } else {
        _signalEMA = (macd * signalAlpha) + (_signalEMA * (1 - signalAlpha));
      }

      _isInitialized = _macdHistory.length >= signalPeriod;

      // V5.0: 메모리 관리 강화
      if (_macdHistory.length > signalPeriod * 2) {
        _macdHistory.removeAt(0);
      }
    }
  }

  double get macd => _count >= slowPeriod ? _fastEMA - _slowEMA : 0.0;
  double get signal => _signalEMA;
  double get histogram => macd - signal;
  bool get isReady => _isInitialized;
  bool get isStale => _lastUpdate != null &&
      DateTime.now().difference(_lastUpdate!).abs() > maxGap;

  MACDResult get current => MACDResult(
        macd: macd,
        signal: signal,
        histogram: histogram,
      );

  void reset() {
    _fastEMA = 0.0;
    _slowEMA = 0.0;
    _signalEMA = 0.0;
    _macdHistory.clear();
    _isInitialized = false;
    _count = 0;
    _lastUpdate = null;
  }

  Map<String, dynamic> getHealthStatus() {
    return {
      'isReady': isReady,
      'isStale': isStale,
      'dataPoints': _count,
      'macdHistoryLength': _macdHistory.length,
      'lastUpdate': _lastUpdate?.toIso8601String(),
      'timeSinceLastUpdate': _lastUpdate != null
          ? DateTime.now().difference(_lastUpdate!).inSeconds
          : null,
    };
  }
}

// ==========================================================================
// 🆕 V5.0: Isolate 분리용 static 함수들
// ==========================================================================

class AdvancedMetrics {
  // 기존 온라인 계산기들
  final Map<String, StreamAwareOnlineRSI> _rsiCalculators = {};
  final Map<String, StreamAwareOnlineMACD> _macdCalculators = {};
  final Map<String, DateTime> _lastUpdates = {};

  final Duration maxGap;
  final Duration staleThreshold;

  AdvancedMetrics({
    this.maxGap = const Duration(seconds: 10),
    this.staleThreshold = const Duration(seconds: 30),
  });

  // ==========================================================================
  // 🆕 V5.0: Isolate 기반 비동기 다이버전스 계산
  // ==========================================================================

  /// 다이버전스 계산을 Isolate에서 실행
  static Future<DivergenceResult?> calculateDivergenceAsync({
    required List<double> prices,
    required List<double> indicators,
    required String indicatorType,
  }) async {
    try {
      return await compute(_calculateDivergenceInIsolate, {
        'prices': prices,
        'indicators': indicators,
        'indicatorType': indicatorType,
      });
    } catch (e) {
      developer.log('Divergence calculation failed: $e', name: 'AdvancedMetrics');
      return null;
    }
  }

  /// Isolate에서 실행될 순수 함수
  static DivergenceResult? _calculateDivergenceInIsolate(Map<String, dynamic> params) {
    try {
      final prices = List<double>.from(params['prices']);
      final indicators = List<double>.from(params['indicators']);
      final indicatorType = params['indicatorType'] as String;

      if (prices.length < 5 || indicators.length < 5) {
        return const DivergenceResult(
          isBullish: false,
          isBearish: false,
          strength: 0.0,
        );
      }

      // RSI 다이버전스 감지
      if (indicatorType == 'RSI') {
        return _detectRSIDivergence(prices, indicators);
      }

      // MACD 다이버전스 감지
      if (indicatorType == 'MACD') {
        return _detectMACDDivergence(prices, indicators);
      }

      return const DivergenceResult(
        isBullish: false,
        isBearish: false,
        strength: 0.0,
      );
    } catch (e) {
      return null;
    }
  }

  /// RSI 다이버전스 감지 (Isolate용)
  static DivergenceResult _detectRSIDivergence(List<double> prices, List<double> rsiValues) {
    final priceSlope = _calculateSlope(prices);
    final rsiSlope = _calculateSlope(rsiValues);
    
    bool isBullish = false;
    bool isBearish = false;
    double strength = 0.0;

    // Bullish Divergence: 가격 하락 + RSI 상승
    if (priceSlope < -0.01 && rsiSlope > 0.01) {
      isBullish = true;
      strength = min(1.0, (rsiSlope.abs() + priceSlope.abs()) / 2.0);
    }
    // Bearish Divergence: 가격 상승 + RSI 하락
    else if (priceSlope > 0.01 && rsiSlope < -0.01) {
      isBearish = true;
      strength = min(1.0, (rsiSlope.abs() + priceSlope.abs()) / 2.0);
    }

    return DivergenceResult(
      isBullish: isBullish,
      isBearish: isBearish,
      strength: strength,
    );
  }

  /// MACD 다이버전스 감지 (Isolate용)
  static DivergenceResult _detectMACDDivergence(List<double> prices, List<double> macdValues) {
    final priceSlope = _calculateSlope(prices);
    final macdSlope = _calculateSlope(macdValues);
    
    bool isBullish = false;
    bool isBearish = false;
    double strength = 0.0;

    // Bullish Divergence: 가격 하락 + MACD 상승
    if (priceSlope < -0.01 && macdSlope > 0.01) {
      isBullish = true;
      strength = min(1.0, (macdSlope.abs() + priceSlope.abs()) / 2.0);
    }
    // Bearish Divergence: 가격 상승 + MACD 하락
    else if (priceSlope > 0.01 && macdSlope < -0.01) {
      isBearish = true;
      strength = min(1.0, (macdSlope.abs() + priceSlope.abs()) / 2.0);
    }

    return DivergenceResult(
      isBullish: isBullish,
      isBearish: isBearish,
      strength: strength,
    );
  }

  /// 🆕 V5.0: 배치 지표 계산 (Isolate)
  static Future<Map<String, double>> calculateBatchMetricsAsync({
    required List<double> prices,
    required List<double> volumes,
  }) async {
    try {
      return await compute(_calculateBatchMetricsInIsolate, {
        'prices': prices,
        'volumes': volumes,
      });
    } catch (e) {
      developer.log('Batch metrics calculation failed: $e', name: 'AdvancedMetrics');
      return <String, double>{};
    }
  }

  /// 배치 지표 계산 (Isolate용)
  static Map<String, double> _calculateBatchMetricsInIsolate(Map<String, dynamic> params) {
    try {
      final prices = List<double>.from(params['prices']);
      final volumes = List<double>.from(params['volumes']);

      if (prices.isEmpty || volumes.isEmpty) {
        return <String, double>{};
      }

      final result = <String, double>{};

      // 가격 관련 지표
      result['priceVolatility'] = _calculateVolatility(prices);
      result['priceSlope'] = _calculateSlope(prices);
      result['priceAcceleration'] = _calculateAcceleration(prices);

      // 거래량 관련 지표
      result['volumeSlope'] = _calculateSlope(volumes);
      result['volumeAcceleration'] = _calculateAcceleration(volumes);
      result['volumeSpike'] = _calculateVolumeSpike(volumes);

      // 복합 지표
      result['priceVolumeCorrelation'] = _calculateCorrelation(prices, volumes);

      return result;
    } catch (e) {
      return <String, double>{};
    }
  }

  // ==========================================================================
  // 🔄 메인 업데이트 메서드 (기존 유지)
  // ==========================================================================

  void updatePrice({
    required String market,
    required double price,
    required DateTime timestamp,
  }) {
    _lastUpdates[market] = timestamp;
    _getRSICalculator(market).update(price, timestamp);
    _getMACDCalculator(market).update(price, timestamp);
  }

  StreamAwareOnlineRSI _getRSICalculator(String market) {
    return _rsiCalculators.putIfAbsent(
      market,
      () => StreamAwareOnlineRSI(period: 14, maxGap: maxGap),
    );
  }

  StreamAwareOnlineMACD _getMACDCalculator(String market) {
    return _macdCalculators.putIfAbsent(
      market,
      () => StreamAwareOnlineMACD(maxGap: maxGap),
    );
  }

  // ==========================================================================
  // 📊 온라인 지표 조회 (기존 유지)
  // ==========================================================================

  double calculateRSI({
    required String market,
    List<double>? prices,
    int period = 14,
  }) {
    final calculator = _rsiCalculators[market];
    if (calculator == null || !calculator.isReady || calculator.isStale) {
      return 50.0;
    }
    return calculator.current;
  }

  MACDResult calculateMACD({
    required String market,
    List<double>? prices,
    int fastPeriod = 12,
    int slowPeriod = 26,
    int signalPeriod = 9,
  }) {
    final calculator = _macdCalculators[market];
    if (calculator == null || !calculator.isReady || calculator.isStale) {
      return const MACDResult(macd: 0.0, signal: 0.0, histogram: 0.0);
    }
    return calculator.current;
  }

  /// 🆕 V5.0: 비동기 다이버전스 감지 (Isolate 사용)
  Future<DivergenceResult> detectDivergenceAsync({
    required String market,
    required List<double> prices,
    required List<double> indicator,
    int lookback = 5,
  }) async {
    final rsiCalculator = _rsiCalculators[market];
    if (rsiCalculator == null || !rsiCalculator.isReady || prices.length < lookback) {
      return const DivergenceResult(
        isBullish: false,
        isBearish: false,
        strength: 0.0,
      );
    }

    // 현재 RSI 값을 포함한 지표 리스트 생성
    final currentRSI = rsiCalculator.current;
    final rsiValues = [...indicator, currentRSI];

    // Isolate에서 계산
    final result = await calculateDivergenceAsync(
      prices: prices.take(lookback).toList(),
      indicators: rsiValues.take(lookback).toList(),
      indicatorType: 'RSI',
    );

    return result ?? const DivergenceResult(
      isBullish: false,
      isBearish: false,
      strength: 0.0,
    );
  }

  /// 기존 동기 버전 (하위 호환성)
  DivergenceResult detectDivergence({
    required String market,
    required List<double> prices,
    required List<double> indicator,
    int lookback = 5,
  }) {
    final rsiCalculator = _rsiCalculators[market];
    if (rsiCalculator == null ||
        !rsiCalculator.isReady ||
        prices.length < lookback) {
      return const DivergenceResult(
        isBullish: false,
        isBearish: false,
        strength: 0.0,
      );
    }

    final currentRSI = rsiCalculator.current;
    final recentPrices = prices.take(lookback).toList();
    return _calculateDivergence(recentPrices, currentRSI);
  }

  DivergenceResult _calculateDivergence(List<double> prices, double currentRSI) {
    if (prices.length < 2) {
      return const DivergenceResult(
        isBullish: false,
        isBearish: false,
        strength: 0.0,
      );
    }

    final priceSlope = _calculateSlope(prices);
    bool isBullish = false;
    bool isBearish = false;
    double strength = 0.0;

    if (priceSlope < -0.1 && currentRSI > 50) {
      isBullish = true;
      strength = min(1.0, (currentRSI - 50) / 50);
    } else if (priceSlope > 0.1 && currentRSI < 50) {
      isBearish = true;
      strength = min(1.0, (50 - currentRSI) / 50);
    }

    return DivergenceResult(
      isBullish: isBullish,
      isBearish: isBearish,
      strength: strength,
    );
  }

  // ==========================================================================
  // 🎯 커스텀 지표들 (기존 유지)
  // ==========================================================================

  double calculateLiquidityVortex(
    RollingWindow<double> priceWindow,
    RollingWindow<double> volumeWindow,
  ) {
    if (priceWindow.length < 3 || volumeWindow.length < 3) return 0.0;

    final priceAccel = _calculateSecondDerivative(priceWindow.values);
    final volumeAccel = _calculateSecondDerivative(volumeWindow.values);
    final cps = priceWindow.length / priceWindow.span.inSeconds;

    return (priceAccel * volumeAccel * cps).abs();
  }

  double calculateFlashPulse(double currentVolume, RollingWindow<double> volumeWindow) {
    if (volumeWindow.length < 10) return 0.0;

    final recentVolumes = volumeWindow.values.take(10).toList();
    final ema = _calculateEMA(recentVolumes, 10);
    return currentVolume / max(ema, 1.0) - 1.0;
  }

  double calculateMicroBurstRadar(double currentVolume, RollingWindow<double> volumeWindow) {
    if (volumeWindow.length < 3) return 0.0;

    final recentVolumes = volumeWindow.values.take(3).toList();
    final mean = recentVolumes.reduce((a, b) => a + b) / recentVolumes.length;
    final variance = recentVolumes
        .map((v) => pow(v - mean, 2))
        .reduce((a, b) => a + b) / recentVolumes.length;
    final stdDev = sqrt(variance);

    if (stdDev == 0) return 0.0;
    return (currentVolume - mean) / stdDev;
  }

  double calculateMachineRush(double currentVolume, double totalVolume) {
    if (totalVolume == 0) return 0.0;
    return currentVolume / totalVolume;
  }

  double calculateJumpGate(double currentPrice, double low, double high, double volume) {
    if (high <= low) return 0.0;
    final pricePosition = (currentPrice - low) / (high - low);
    final volumeWeight = log(volume + 1) / 10.0;
    return pricePosition * volumeWeight;
  }

  double calculateATR({
    required List<double> highs,
    required List<double> lows,
    required List<double> closes,
    int period = 14,
  }) {
    if (highs.length < period || lows.length < period || closes.length < period) {
      return 0.0;
    }

    final trueRanges = <double>[];
    for (int i = 1; i < closes.length; i++) {
      final high = highs[i];
      final low = lows[i];
      final prevClose = closes[i - 1];

      final tr1 = high - low;
      final tr2 = (high - prevClose).abs();
      final tr3 = (low - prevClose).abs();

      trueRanges.add(max(tr1, max(tr2, tr3)));
    }

    if (trueRanges.length < period) return 0.0;

    double atr = trueRanges.take(period).reduce((a, b) => a + b) / period;

    for (int i = period; i < trueRanges.length; i++) {
      atr = ((atr * (period - 1)) + trueRanges[i]) / period;
    }

    return atr;
  }

  // ==========================================================================
  // 🛠️ 헬퍼 함수들 (V5.0: Isolate 호환)
  // ==========================================================================

  double _calculateEMA(List<double> values, int period) {
    if (values.isEmpty) return 0.0;
    if (values.length == 1) return values.first;

    final alpha = 2.0 / (period + 1);
    double ema = values.first;

    for (int i = 1; i < values.length; i++) {
      ema = (values[i] * alpha) + (ema * (1 - alpha));
    }
    return ema;
  }

  double _calculateSecondDerivative(List<double> values) {
    if (values.length < 3) return 0.0;
    final recent = values.take(3).toList();
    return recent[0] - (2 * recent[1]) + recent[2];
  }

  static double _calculateSlope(List<double> values) {
    if (values.length < 2) return 0.0;
    
    final n = values.length;
    double sumX = 0, sumY = 0, sumXY = 0, sumX2 = 0;

    for (int i = 0; i < n; i++) {
      sumX += i;
      sumY += values[i];
      sumXY += i * values[i];
      sumX2 += i * i;
    }

    final denominator = n * sumX2 - sumX * sumX;
    if (denominator == 0) return 0.0;
    
    return (n * sumXY - sumX * sumY) / denominator;
  }

  // 🆕 V5.0: 추가 Isolate용 헬퍼 함수들
  static double _calculateVolatility(List<double> values) {
    if (values.length < 2) return 0.0;
    
    final mean = values.reduce((a, b) => a + b) / values.length;
    final variance = values
        .map((v) => pow(v - mean, 2))
        .reduce((a, b) => a + b) / values.length;
    
    return sqrt(variance);
  }

  static double _calculateAcceleration(List<double> values) {
    if (values.length < 3) return 0.0;
    
    // 2차 미분 (가속도)
    return values[0] - (2 * values[1]) + values[2];
  }

  static double _calculateVolumeSpike(List<double> volumes) {
    if (volumes.length < 5) return 0.0;
    
    final recent = volumes.take(3).toList();
    final baseline = volumes.skip(3).take(2).toList();
    
    final recentAvg = recent.reduce((a, b) => a + b) / recent.length;
    final baselineAvg = baseline.reduce((a, b) => a + b) / baseline.length;
    
    return baselineAvg > 0 ? recentAvg / baselineAvg - 1.0 : 0.0;
  }

  static double _calculateCorrelation(List<double> x, List<double> y) {
    if (x.length != y.length || x.length < 2) return 0.0;
    
    final n = x.length;
    final meanX = x.reduce((a, b) => a + b) / n;
    final meanY = y.reduce((a, b) => a + b) / n;
    
    double sumXY = 0, sumX2 = 0, sumY2 = 0;
    
    for (int i = 0; i < n; i++) {
      final dx = x[i] - meanX;
      final dy = y[i] - meanY;
      sumXY += dx * dy;
      sumX2 += dx * dx;
      sumY2 += dy * dy;
    }
    
    final denominator = sqrt(sumX2 * sumY2);
    return denominator > 0 ? sumXY / denominator : 0.0;
  }

  double calculateDynamicThreshold({
    required double baseThreshold,
    required double atr,
    required double priceAverage,
    double multiplier = 1.0,
  }) {
    if (priceAverage == 0) return baseThreshold;
    final atrPercent = (atr / priceAverage) * 100;
    final volatilityFactor = max(0.5, min(2.0, atrPercent / baseThreshold));
    return baseThreshold * volatilityFactor * multiplier;
  }

  // ==========================================================================
  // 🔍 시스템 헬스 및 관리 (기존 유지)
  // ==========================================================================

  Map<String, dynamic> getSystemHealth() {
    final now = DateTime.now();
    final healthStatus = <String, dynamic>{
      'totalMarkets': _rsiCalculators.length,
      'staleMarkets': 0,
      'healthyMarkets': 0,
      'markets': <String, dynamic>{},
    };

    for (final market in _rsiCalculators.keys) {
      final rsiHealth = _rsiCalculators[market]?.getHealthStatus();
      final macdHealth = _macdCalculators[market]?.getHealthStatus();
      final lastUpdate = _lastUpdates[market];
      final isStale = lastUpdate != null &&
          now.difference(lastUpdate).abs() > staleThreshold;

      if (isStale) {
        healthStatus['staleMarkets']++;
      } else {
        healthStatus['healthyMarkets']++;
      }

      healthStatus['markets'][market] = {
        'rsi': rsiHealth,
        'macd': macdHealth,
        'isStale': isStale,
        'lastUpdate': lastUpdate?.toIso8601String(),
      };
    }

    return healthStatus;
  }

  void cleanup() {
    final now = DateTime.now();
    final marketsToRemove = <String>[];

    for (final entry in _lastUpdates.entries) {
      if (now.difference(entry.value).abs() > const Duration(hours: 1)) {
        marketsToRemove.add(entry.key);
      }
    }

    for (final market in marketsToRemove) {
      _rsiCalculators.remove(market);
      _macdCalculators.remove(market);
      _lastUpdates.remove(market);
    }

    if (marketsToRemove.isNotEmpty) {
      developer.log('AdvancedMetrics: Cleaned up ${marketsToRemove.length} stale market calculators', 
                   name: 'AdvancedMetrics');
    }
  }

  void resetMarket(String market) {
    _rsiCalculators[market]?.reset();
    _macdCalculators[market]?.reset();
    _lastUpdates.remove(market);
  }

  void resetAll() {
    for (final calculator in _rsiCalculators.values) {
      calculator.reset();
    }
    for (final calculator in _macdCalculators.values) {
      calculator.reset();
    }
    _lastUpdates.clear();
  }

  // 하위 호환성용 메서드들
  void clearCache() {
    // 온라인 계산에서는 캐시가 없으므로 빈 구현
  }

  void cleanupExpiredCache() {
    cleanup();
  }

  Map<String, dynamic> getCacheStats() {
    return {
      'mode': 'online',
      'totalMarkets': _rsiCalculators.length,
      'healthyMarkets': getSystemHealth()['healthyMarkets'],
      'staleMarkets': getSystemHealth()['staleMarkets'],
    };
  }

  void dispose() {
    _rsiCalculators.clear();
    _macdCalculators.clear();
    _lastUpdates.clear();
  }
}

// ==========================================================================
// 📊 V5.0 결과 클래스들 (강화됨)
// ==========================================================================

/// MACD 계산 결과
class MACDResult {
  final double macd;
  final double signal;
  final double histogram;

  const MACDResult({
    required this.macd,
    required this.signal,
    required this.histogram,
  });

  /// 🆕 V5.0: MACD 상태 판단
  String get state {
    if (macd > signal && histogram > 0) return 'Bullish';
    if (macd < signal && histogram < 0) return 'Bearish';
    return 'Neutral';
  }

  /// 🆕 V5.0: 신호 강도
  double get strength {
    return histogram.abs().clamp(0.0, 1.0);
  }

  /// 🆕 V5.0: JSON 직렬화
  Map<String, dynamic> toJson() {
    return {
      'macd': macd,
      'signal': signal,
      'histogram': histogram,
      'state': state,
      'strength': strength,
    };
  }

  factory MACDResult.fromJson(Map<String, dynamic> json) {
    return MACDResult(
      macd: (json['macd'] as num).toDouble(),
      signal: (json['signal'] as num).toDouble(),
      histogram: (json['histogram'] as num).toDouble(),
    );
  }

  @override
  String toString() => 'MACD(macd: $macd, signal: $signal, histogram: $histogram, state: $state)';

  @override
  bool operator ==(Object other) {
    if (identical(this, other)) return true;
    return other is MACDResult &&
        other.macd == macd &&
        other.signal == signal &&
        other.histogram == histogram;
  }

  @override
  int get hashCode => macd.hashCode ^ signal.hashCode ^ histogram.hashCode;
}

/// 다이버전스 감지 결과
class DivergenceResult {
  final bool isBullish;
  final bool isBearish;
  final double strength;

  const DivergenceResult({
    required this.isBullish,
    required this.isBearish,
    required this.strength,
  });

  /// 다이버전스 존재 여부
  bool get hasAnyDivergence => isBullish || isBearish;

  /// 다이버전스 타입
  String get type {
    if (isBullish) return 'Bullish';
    if (isBearish) return 'Bearish';
    return 'None';
  }

  /// 신뢰도 레벨
  String get confidenceLevel {
    if (strength >= 0.8) return 'Very High';
    if (strength >= 0.6) return 'High';
    if (strength >= 0.4) return 'Medium';
    if (strength >= 0.2) return 'Low';
    return 'Very Low';
  }

  /// 🆕 V5.0: JSON 직렬화
  Map<String, dynamic> toJson() {
    return {
      'isBullish': isBullish,
      'isBearish': isBearish,
      'strength': strength,
      'type': type,
      'confidenceLevel': confidenceLevel,
      'hasAnyDivergence': hasAnyDivergence,
    };
  }

  factory DivergenceResult.fromJson(Map<String, dynamic> json) {
    return DivergenceResult(
      isBullish: json['isBullish'] as bool,
      isBearish: json['isBearish'] as bool,
      strength: (json['strength'] as num).toDouble(),
    );
  }

  @override
  String toString() => 'Divergence(type: $type, strength: $strength, confidence: $confidenceLevel)';

  @override
  bool operator ==(Object other) {
    if (identical(this, other)) return true;
    return other is DivergenceResult &&
        other.isBullish == isBullish &&
        other.isBearish == isBearish &&
        other.strength == strength;
  }

  @override
  int get hashCode => isBullish.hashCode ^ isBearish.hashCode ^ strength.hashCode;
}

// ==========================================================================
// 🔢 V5.0 하위 호환성 타입 정의
// ==========================================================================

/// 온라인 RSI 계산기 (하위 호환성)
typedef OnlineRSI = StreamAwareOnlineRSI;

/// 온라인 MACD 계산기 (하위 호환성)
typedef OnlineMACD = StreamAwareOnlineMACD;