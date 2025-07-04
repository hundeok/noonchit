import 'dart:math';
import 'dart:developer' as developer;
import 'rolling_window.dart';

// ==========================================================================
// 🔥 스트림 동기화된 온라인 계산기들
// ==========================================================================

/// 스트림 생명주기와 동기화된 OnlineRSI
class StreamAwareOnlineRSI {
  final int period;
  final Duration maxGap; // 허용 가능한 최대 데이터 간격
  
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
        developer.log('RSI Reset: Stream gap detected (${timestamp.difference(_lastUpdate!).inSeconds}s)', name: 'StreamAwareOnlineRSI');
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
    
    // 메모리 관리: 최대 period * 2 개의 가격만 유지
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
  
  /// 건강 상태 체크
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

/// 스트림 동기화된 OnlineMACD
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
      developer.log('MACD Reset: Stream gap detected (${timestamp.difference(_lastUpdate!).inSeconds}s)', name: 'StreamAwareOnlineMACD');
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
      
      // 메모리 관리
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
    histogram: histogram
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
  
  /// 건강 상태 체크
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
// 🔥 완전히 온라인화된 AdvancedMetrics (메인 클래스)
// ==========================================================================

/// 완전히 온라인화된 AdvancedMetrics
/// 
/// 기존 문제점들 해결:
/// 1. ❌ 캐시 키가 부정확 → ✅ 캐시 제거, 온라인 계산
/// 2. ❌ calculateMACD O(n²) → ✅ O(1) 온라인 업데이트
/// 3. ❌ 매번 전체 재계산 → ✅ 새 데이터만 업데이트
/// 4. ❌ 스트림 끊김시 오염 → ✅ 자동 감지 및 리셋
class AdvancedMetrics {
  
  // 🎯 마켓별 온라인 계산기들
  final Map<String, StreamAwareOnlineRSI> _rsiCalculators = {};
  final Map<String, StreamAwareOnlineMACD> _macdCalculators = {};
  final Map<String, DateTime> _lastUpdates = {};
  
  // 🔒 스트림 건강성 관리
  final Duration maxGap;
  final Duration staleThreshold;
  
  AdvancedMetrics({
    this.maxGap = const Duration(seconds: 10),
    this.staleThreshold = const Duration(seconds: 30),
  });

  // ==========================================================================
  // 🔥 메인 업데이트 메서드 (새 데이터만 받아서 O(1) 업데이트)
  // ==========================================================================
  
  /// 새로운 가격 데이터로 모든 지표 업데이트
  void updatePrice({
    required String market,
    required double price,
    required DateTime timestamp,
  }) {
    _lastUpdates[market] = timestamp;
    
    // RSI 업데이트 (O(1))
    _getRSICalculator(market).update(price, timestamp);
    
    // MACD 업데이트 (O(1))
    _getMACDCalculator(market).update(price, timestamp);
  }
  
  /// RSI 계산기 조회/생성
  StreamAwareOnlineRSI _getRSICalculator(String market) {
    return _rsiCalculators.putIfAbsent(
      market, 
      () => StreamAwareOnlineRSI(period: 14, maxGap: maxGap)
    );
  }
  
  /// MACD 계산기 조회/생성
  StreamAwareOnlineMACD _getMACDCalculator(String market) {
    return _macdCalculators.putIfAbsent(
      market,
      () => StreamAwareOnlineMACD(maxGap: maxGap)
    );
  }

  // ==========================================================================
  // 📊 온라인 지표 조회 (O(1) 복잡도 - 즉시 반환)
  // ==========================================================================
  
  /// RSI 조회 (즉시 반환)
  double calculateRSI({
    required String market,
    List<double>? prices, // 하위 호환성용 (사용 안함)
    int period = 14,
  }) {
    final calculator = _rsiCalculators[market];
    if (calculator == null || !calculator.isReady || calculator.isStale) {
      return 50.0; // 기본값
    }
    return calculator.current;
  }
  
  /// MACD 조회 (즉시 반환)
  MACDResult calculateMACD({
    required String market,
    List<double>? prices, // 하위 호환성용 (사용 안함)
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
  
  /// 🆕 다이버전스 감지 (온라인 RSI 기반)
  DivergenceResult detectDivergence({
    required String market,
    required List<double> prices,
    required List<double> indicator, // 사용 안함 (온라인 RSI 사용)
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
    
    // 🔥 실제 온라인 RSI 사용
    final currentRSI = rsiCalculator.current;
    final recentPrices = prices.take(lookback).toList();
    
    return _calculateDivergence(recentPrices, currentRSI);
  }
  
  /// 다이버전스 계산 (단순화된 버전)
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
    
    // 다이버전스 감지
    if (priceSlope < -0.1 && currentRSI > 50) {
      // 가격 하락 + RSI 높음 → Bullish Divergence 가능성
      isBullish = true;
      strength = min(1.0, (currentRSI - 50) / 50);
    } else if (priceSlope > 0.1 && currentRSI < 50) {
      // 가격 상승 + RSI 낮음 → Bearish Divergence 가능성
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
  // 🎯 커스텀 지표들 (기존 방식 유지)
  // ==========================================================================
  
  /// Liquidity Vortex 계산
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
  
  /// Flash Pulse 계산
  double calculateFlashPulse(double currentVolume, RollingWindow<double> volumeWindow) {
    if (volumeWindow.length < 10) return 0.0;
    
    final recentVolumes = volumeWindow.values.take(10).toList();
    final ema = _calculateEMA(recentVolumes, 10);
    
    return currentVolume / max(ema, 1.0) - 1.0;
  }
  
  /// Micro Burst Radar 계산
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
  
  /// Machine Rush 계산
  double calculateMachineRush(double currentVolume, double totalVolume) {
    if (totalVolume == 0) return 0.0;
    return currentVolume / totalVolume;
  }
  
  /// Jump Gate 계산
  double calculateJumpGate(double currentPrice, double low, double high, double volume) {
    if (high <= low) return 0.0;
    
    final pricePosition = (currentPrice - low) / (high - low);
    final volumeWeight = log(volume + 1) / 10.0;
    
    return pricePosition * volumeWeight;
  }

  /// ATR 계산 (기존 방식 유지)
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
    
    // 첫 번째 ATR은 단순 평균
    double atr = trueRanges.take(period).reduce((a, b) => a + b) / period;
    
    // 이후는 지수이동평균
    for (int i = period; i < trueRanges.length; i++) {
      atr = ((atr * (period - 1)) + trueRanges[i]) / period;
    }
    
    return atr;
  }

  // ==========================================================================
  // 🛠️ 헬퍼 함수들
  // ==========================================================================
  
  /// EMA 계산
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
  
  /// 2차 미분 계산
  double _calculateSecondDerivative(List<double> values) {
    if (values.length < 3) return 0.0;
    
    final recent = values.take(3).toList();
    return recent[0] - (2 * recent[1]) + recent[2];
  }
  
  /// 선형 회귀 기울기 계산
  double _calculateSlope(List<double> values) {
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

  /// 동적 임계값 계산 (ATR 기반)
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
  // 🔍 시스템 헬스 및 관리
  // ==========================================================================
  
  /// 전체 시스템 헬스 체크
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
  
  /// 오래된 계산기들 정리
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
      developer.log('AdvancedMetrics: Cleaned up ${marketsToRemove.length} stale market calculators', name: 'AdvancedMetrics');
    }
  }
  
  /// 특정 마켓 리셋
  void resetMarket(String market) {
    _rsiCalculators[market]?.reset();
    _macdCalculators[market]?.reset();
    _lastUpdates.remove(market);
  }
  
  /// 전체 리셋
  void resetAll() {
    for (final calculator in _rsiCalculators.values) {
      calculator.reset();
    }
    for (final calculator in _macdCalculators.values) {
      calculator.reset();
    }
    _lastUpdates.clear();
  }
  
  /// 캐시 정리 (하위 호환성용 - 실제로는 빈 구현)
  void clearCache() {
    // 온라인 계산에서는 캐시가 없으므로 빈 구현
  }
  
  /// 만료된 캐시 정리 (하위 호환성용 - 실제로는 cleanup 호출)
  void cleanupExpiredCache() {
    cleanup();
  }
  
  /// 캐시 통계 (하위 호환성용)
  Map<String, dynamic> getCacheStats() {
    return {
      'mode': 'online',
      'totalMarkets': _rsiCalculators.length,
      'healthyMarkets': getSystemHealth()['healthyMarkets'],
      'staleMarkets': getSystemHealth()['staleMarkets'],
    };
  }
  
  /// 리소스 정리
  void dispose() {
    _rsiCalculators.clear();
    _macdCalculators.clear();
    _lastUpdates.clear();
  }
}

// ==========================================================================
// 📊 결과 클래스들
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
  
  @override
  String toString() => 'MACD(macd: $macd, signal: $signal, histogram: $histogram)';
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
  
  bool get hasAnyDivergence => isBullish || isBearish;
  
  @override
  String toString() => 'Divergence(bullish: $isBullish, bearish: $isBearish, strength: $strength)';
}

// ==========================================================================
// 🔢 온라인 지표 계산기들 (하위 호환성용 - 실제로는 위의 StreamAware 버전 사용)
// ==========================================================================

/// 온라인 RSI 계산기 (하위 호환성)
typedef OnlineRSI = StreamAwareOnlineRSI;

/// 온라인 MACD 계산기 (하위 호환성)
typedef OnlineMACD = StreamAwareOnlineMACD;