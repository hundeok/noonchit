import 'dart:math';
import 'package:flutter/foundation.dart';
import '../../domain/entities/signal.dart';
import '../../domain/entities/trade.dart';
import 'advanced_metrics.dart';
import 'pattern_config.dart';
import 'market_data_context.dart';

/// 🚀 PatternDetector V4.1 - 온라인 지표 연동
/// 
/// 주요 개선사항:
/// 1. ✅ OnlineAdvancedMetrics 사용으로 O(1) 지표 계산
/// 2. ✅ 스트림 끊김 감지 및 자동 복구
/// 3. ✅ 실제 온라인 RSI/MACD 기반 다이버전스 계산
/// 4. ✅ 시한폭탄 문제 완전 해결
/// 5. ✅ 기존 인터페이스 호환성 유지
class PatternDetector {
  final PatternConfig _config;
  final AdvancedMetrics _metrics;
  
  // 🔒 쿨다운 시스템 (인스턴스 변수로 변경)
  final Map<String, DateTime> _lastSignalTime = {};
  
  PatternDetector({
    PatternConfig? config,
    AdvancedMetrics? metrics,
  }) : _config = config ?? PatternConfig(),
        _metrics = metrics ?? AdvancedMetrics();

  /// 🎯 메인 감지 함수 - 온라인 지표 연동
  Signal? detectPattern({
    required PatternType patternType,
    required Trade trade,
    required DateTime timestamp,
    required MarketDataContext context,
  }) {
    // 🔥 먼저 온라인 지표 업데이트 (O(1))
    _metrics.updatePrice(
      market: trade.market,
      price: trade.price,
      timestamp: timestamp,
    );
    
    // 🔒 쿨다운 체크
    if (_isInCooldown(trade.market, patternType, timestamp)) {
      return null;
    }
    
    Signal? signal;
    
    // 패턴별 감지 로직
    switch (patternType) {
      case PatternType.surge:
        signal = _detectSurge(trade, timestamp, context);
        break;
      case PatternType.flashFire:
        signal = _detectFlashFire(trade, timestamp, context);
        break;
      case PatternType.stackUp:
        signal = _detectStackUp(trade, timestamp, context);
        break;
      case PatternType.stealthIn:
        signal = _detectStealthIn(trade, timestamp, context);
        break;
      case PatternType.blackHole:
        signal = _detectBlackHole(trade, timestamp, context);
        break;
      case PatternType.reboundShot:
        signal = _detectReboundShot(trade, timestamp, context);
        break;
    }
    
    if (signal != null) {
      // 🔒 쿨다운 등록
      _updateCooldown(trade.market, patternType, timestamp);
      
      // 🆕 실제 온라인 RSI/MACD 기반 신뢰도 조정
      signal = _adjustSignalConfidence(signal, context);
    }
    
    return signal;
  }

  /// 🔒 쿨다운 체크 (패턴별 개별 쿨다운)
  bool _isInCooldown(String market, PatternType pattern, DateTime timestamp) {
    final cooldownKey = '$market-${pattern.name}';
    final lastTime = _lastSignalTime[cooldownKey];
    if (lastTime == null) return false;
    
    final cooldownDuration = _config.getCooldownDuration(pattern);
    return timestamp.difference(lastTime) < cooldownDuration;
  }
  
  /// 🔒 쿨다운 등록
  void _updateCooldown(String market, PatternType pattern, DateTime timestamp) {
    final cooldownKey = '$market-${pattern.name}';
    _lastSignalTime[cooldownKey] = timestamp;
  }

  /// 🎯 1. Surge 패턴 감지 (온라인 지표 포함)
  Signal? _detectSurge(Trade trade, DateTime timestamp, MarketDataContext context) {
    final priceWindow = context.getPriceWindow(const Duration(seconds: 60));
    final volumeWindow = context.getVolumeWindow(const Duration(seconds: 60));
    
    if (priceWindow.length < 2 || volumeWindow.isEmpty) return null;

    final config = _config.getPatternConfig(PatternType.surge);
    final currentPrice = trade.price;
    final prevPrice = priceWindow.values[1];
    final changePercent = prevPrice == 0 ? 0.0 : ((currentPrice - prevPrice) / prevPrice) * 100;
    
    // 기본 조건들
    final zScore = priceWindow.zScore(currentPrice);
    final conditions = [
      changePercent.abs() >= config['priceChangePercent']!,
      zScore.abs() >= config['zScoreThreshold']!,
      volumeWindow.sum >= config['minTradeAmount']!,
    ];
    
    // 🔥 온라인 지표 사용 (O(1) 복잡도)
    final rsi = _metrics.calculateRSI(market: trade.market);
    final macd = _metrics.calculateMACD(market: trade.market);
    
    // 고급 지표
    final lv = _metrics.calculateLiquidityVortex(priceWindow, volumeWindow);
    final flashPulse = _metrics.calculateFlashPulse(trade.total, volumeWindow);
    
    final advancedConditions = [
      lv >= config['lvThreshold']!,
      flashPulse > 0,
      // 🆕 온라인 RSI/MACD 조건 추가
      _isValidRSIForDirection(rsi, changePercent),
      macd.histogram.abs() > 0.1, // MACD 모멘텀 체크
    ];
    
    if (!conditions.every((c) => c) || !advancedConditions.every((c) => c)) {
      return null;
    }
    
    return Signal(
      market: trade.market,
      name: trade.market.replaceAll('KRW-', ''),
      currentPrice: currentPrice,
      changePercent: changePercent,
      volume: trade.volume,
      tradeAmount: volumeWindow.sum,
      detectedAt: timestamp,
      patternType: PatternType.surge,
      patternDetails: {
        'changePercent': changePercent,
        'zScore': zScore,
        'liquidityVortex': lv,
        'flashPulse': flashPulse,
        'rsi': rsi,
        'macd': macd.macd,
        'macdSignal': macd.signal,
        'macdHistogram': macd.histogram,
        'confidence': 0.8,
        'version': 'V4.1-Online',
      },
    );
  }

  /// 🎯 2. FlashFire 패턴 감지 (온라인 지표 포함)
  Signal? _detectFlashFire(Trade trade, DateTime timestamp, MarketDataContext context) {
    final volumeWindow = context.getVolumeWindow(const Duration(seconds: 60));
    final buyRatioWindow = context.buyRatioWindow;
    
    if (volumeWindow.length < 10 || buyRatioWindow == null) return null;
    
    final config = _config.getPatternConfig(PatternType.flashFire);
    final volumeZScore = volumeWindow.zScore(trade.total);
    final buyRatio = buyRatioWindow.mean;
    
    // 🔥 온라인 RSI 체크
    final rsi = _metrics.calculateRSI(market: trade.market);
    
    // 기본 조건들
    final conditions = [
      volumeZScore >= config['zScoreThreshold']!,
      volumeWindow.sum >= config['minTradeAmount']!,
      buyRatio >= config['buyRatioMin']!,
      // 🆕 RSI 오버바잉/오버셀링 방지
      rsi > 20 && rsi < 80,
    ];
    
    // 고급 지표
    final microBurst = _metrics.calculateMicroBurstRadar(trade.total, volumeWindow);
    final machineRush = _metrics.calculateMachineRush(trade.total, volumeWindow.sum);
    
    final advancedConditions = [
      microBurst >= config['mbrThreshold']!,
      machineRush >= config['mrThreshold']!,
    ];
    
    if (!conditions.every((c) => c) || !advancedConditions.every((c) => c)) {
      return null;
    }
    
    return Signal(
      market: trade.market,
      name: trade.market.replaceAll('KRW-', ''),
      currentPrice: trade.price,
      changePercent: 0.0,
      volume: trade.volume,
      tradeAmount: volumeWindow.sum,
      detectedAt: timestamp,
      patternType: PatternType.flashFire,
      patternDetails: {
        'volumeZScore': volumeZScore,
        'buyRatio': buyRatio,
        'microBurstRadar': microBurst,
        'machineRush': machineRush,
        'rsi': rsi,
        'confidence': 0.85,
        'version': 'V4.1-Online',
      },
    );
  }

  /// 🎯 3. StackUp 패턴 감지 (온라인 지표 포함)
  Signal? _detectStackUp(Trade trade, DateTime timestamp, MarketDataContext context) {
    final volumeWindow = context.getVolumeWindow(const Duration(seconds: 60));
    
    if (volumeWindow.length < 4) return null;
    
    final config = _config.getPatternConfig(PatternType.stackUp);
    final consecutiveCount = volumeWindow.consecutiveIncreases;
    final volumeZScore = volumeWindow.zScore(trade.total);
    
    // 🔥 온라인 MACD 체크
    final macd = _metrics.calculateMACD(market: trade.market);
    
    // 기본 조건들
    final conditions = [
      consecutiveCount >= config['consecutiveMin']!,
      volumeWindow.sum >= config['minVolume']!,
      volumeZScore >= config['zScoreThreshold']!,
      // 🆕 MACD 상승 모멘텀 체크
      macd.histogram > 0, // MACD 히스토그램 상승
    ];
    
    // 추세 분석
    final slope = volumeWindow.slope;
    final rSquared = volumeWindow.rSquared;
    final trendOk = slope > 0 && rSquared > config['rSquaredMin']!;
    
    if (!conditions.every((c) => c) || !trendOk) {
      return null;
    }
    
    return Signal(
      market: trade.market,
      name: trade.market.replaceAll('KRW-', ''),
      currentPrice: trade.price,
      changePercent: 0.0,
      volume: trade.volume,
      tradeAmount: volumeWindow.sum,
      detectedAt: timestamp,
      patternType: PatternType.stackUp,
      patternDetails: {
        'consecutiveCount': consecutiveCount,
        'slope': slope,
        'rSquared': rSquared,
        'volumeZScore': volumeZScore,
        'macd': macd.macd,
        'macdHistogram': macd.histogram,
        'confidence': 0.75,
        'version': 'V4.1-Online',
      },
    );
  }

  /// 🎯 4. StealthIn 패턴 감지 (완화된 설정 + 온라인 지표)
  Signal? _detectStealthIn(Trade trade, DateTime timestamp, MarketDataContext context) {
    final priceWindow = context.getPriceWindow(const Duration(seconds: 300)); // 장기 윈도우 사용
    final volumeWindow = context.getVolumeWindow(const Duration(seconds: 300));
    final buyRatioWindow = context.buyRatioWindow;
    final intervalWindow = context.intervalWindow;
    
    if (volumeWindow.length < 15 || buyRatioWindow == null || intervalWindow == null) {
      return null;
    }
    
    final config = _config.getPatternConfig(PatternType.stealthIn);
    final totalAmount = volumeWindow.sum;
    final buyRatio = buyRatioWindow.mean;
    final priceStability = 1.0 - priceWindow.cv; // 변동계수의 역수
    
    // 🔥 온라인 RSI - 중립 구간 체크
    final rsi = _metrics.calculateRSI(market: trade.market);
    
    // 🆕 완화된 조건들 + RSI 체크
    final conditions = [
      // "조용히 매집" - 가격 안정성
      priceStability >= 0.95, // CV가 5% 이하
      priceWindow.zScore(trade.price).abs() <= 1.0,
      
      // "꾸준한 매수" - 완화된 임계값들  
      buyRatio >= config['buyRatioMin']!, // 0.6 (기존 0.7에서 완화)
      totalAmount >= config['minTradeAmount']!, // 500만 (기존 2000만에서 완화)
      volumeWindow.length >= config['minTradeCount']!,
      
      // "거래 간격 일정"
      intervalWindow.variance <= config['intervalVarianceMax']!,
      
      // 🆕 RSI 중립 구간 (조용한 매집시 극단값 회피)
      rsi >= 30 && rsi <= 70,
    ];
    
    if (!conditions.every((c) => c)) {
      return null;
    }
    
    return Signal(
      market: trade.market,
      name: trade.market.replaceAll('KRW-', ''),
      currentPrice: trade.price,
      changePercent: 0.0,
      volume: trade.volume,
      tradeAmount: totalAmount,
      detectedAt: timestamp,
      patternType: PatternType.stealthIn,
      patternDetails: {
        'totalAmount': totalAmount,
        'buyRatio': buyRatio,
        'priceStability': priceStability,
        'tradeCount': volumeWindow.length,
        'rsi': rsi,
        'confidence': 0.7,
        'enhancement': 'V4.1 - Online + Relaxed Thresholds',
      },
    );
  }

  /// 🎯 5. BlackHole 패턴 감지 (완화된 설정 + 온라인 지표)
  Signal? _detectBlackHole(Trade trade, DateTime timestamp, MarketDataContext context) {
    final priceWindow = context.getPriceWindow(const Duration(seconds: 300)); // 장기 윈도우 사용
    final volumeWindow = context.getVolumeWindow(const Duration(seconds: 300));
    final buyRatioWindow = context.buyRatioWindow;
    
    if (priceWindow.length < 10 || volumeWindow.length < 10 || buyRatioWindow == null) {
      return null;
    }
    
    final config = _config.getPatternConfig(PatternType.blackHole);
    final totalVolume = volumeWindow.sum;
    final cv = priceWindow.cv;
    final buyRatio = buyRatioWindow.mean;
    
    // 🔥 온라인 MACD - 횡보 구간 체크
    final macd = _metrics.calculateMACD(market: trade.market);
    
    // 🆕 완화된 조건들 + MACD 체크
    final conditions = [
      // "엄청난 거래량" - 완화된 임계값
      totalVolume >= config['minTradeAmount']!, // 1000만 (기존 5000만에서 완화)
      
      // "가격 갇힘" - 완화된 변동성 기준
      cv <= config['cvThreshold']!, // 2% (기존 1%에서 완화)
      priceWindow.zScore(trade.price).abs() <= config['priceZScoreMax']!,
      
      // "매수/매도 균형" - 완화된 범위
      buyRatio >= config['buyRatioMin']! && buyRatio <= config['buyRatioMax']!, // 35-65% (기존 40-60%에서 완화)
      
      // 🆕 MACD 횡보 구간 (갇힘 패턴 특성)
      macd.histogram.abs() < 50, // 작은 MACD 히스토그램
    ];
    
    if (!conditions.every((c) => c)) {
      return null;
    }
    
    return Signal(
      market: trade.market,
      name: trade.market.replaceAll('KRW-', ''),
      currentPrice: trade.price,
      changePercent: 0.0,
      volume: trade.volume,
      tradeAmount: totalVolume,
      detectedAt: timestamp,
      patternType: PatternType.blackHole,
      patternDetails: {
        'cv': cv,
        'buyRatio': buyRatio,
        'totalVolume': totalVolume,
        'stabilityIndex': 1.0 - cv,
        'macd': macd.macd,
        'macdHistogram': macd.histogram,
        'confidence': 0.8,
        'enhancement': 'V4.1 - Online + Relaxed Thresholds',
      },
    );
  }

  /// 🎯 6. ReboundShot 패턴 감지 (온라인 지표 포함)
  Signal? _detectReboundShot(Trade trade, DateTime timestamp, MarketDataContext context) {
    final priceWindow = context.getPriceWindow(const Duration(seconds: 60));
    final volumeWindow = context.getVolumeWindow(const Duration(seconds: 60));
    
    if (priceWindow.length < 5) return null;
    
    final config = _config.getPatternConfig(PatternType.reboundShot);
    final prices = priceWindow.values;
    final low = prices.reduce(min);
    final high = prices.reduce(max);
    final recentVolume = volumeWindow.sum;
    
    // 🔥 온라인 RSI - 과매도에서 반등 체크
    final rsi = _metrics.calculateRSI(market: trade.market);
    final macd = _metrics.calculateMACD(market: trade.market);
    
    // Jump Gate 계산
    final jumpScore = _metrics.calculateJumpGate(trade.price, low, high, trade.total);
    final priceRange = (high - low) / low;
    
    final conditions = [
      // "의미있는 반등 범위"
      priceRange >= config['priceRangeMin']!,
      
      // "점프하는 움직임"
      jumpScore > 0,
      
      // "강력한 매수세"
      recentVolume >= config['minVolume']!,
      
      // 🆕 RSI 과매도에서 반등 or MACD 골든크로스
      (rsi < 35 && trade.price > low * 1.01) || // 과매도 반등
      (macd.histogram > 0 && macd.macd > macd.signal), // MACD 상승
    ];
    
    if (!conditions.every((c) => c)) {
      return null;
    }
    
    return Signal(
      market: trade.market,
      name: trade.market.replaceAll('KRW-', ''),
      currentPrice: trade.price,
      changePercent: ((trade.price - low) / low) * 100,
      volume: trade.volume,
      tradeAmount: recentVolume,
      detectedAt: timestamp,
      patternType: PatternType.reboundShot,
      patternDetails: {
        'jumpScore': jumpScore,
        'priceRange': priceRange,
        'lowPrice': low,
        'highPrice': high,
        'rsi': rsi,
        'macd': macd.macd,
        'macdHistogram': macd.histogram,
        'confidence': 0.9,
        'version': 'V4.1-Online',
      },
    );
  }

  /// 🆕 실제 온라인 RSI/MACD 기반 신뢰도 조정
  Signal _adjustSignalConfidence(Signal signal, MarketDataContext context) {
    try {
      final priceWindow = context.getPriceWindow(const Duration(seconds: 300));
      if (priceWindow.length < 5) return signal; // 다이버전스 계산 불가
      
      // 🔥 실제 온라인 RSI/MACD 사용한 다이버전스 감지
      final divergence = _metrics.detectDivergence(
        market: signal.market,
        prices: priceWindow.values,
        indicator: [], // 사용 안함 (온라인 RSI 사용)
      );
      
      // 신뢰도 조정
      double confidenceMultiplier = 1.0;
      
      if (signal.changePercent > 0 && divergence.isBearish) {
        // 상승 신호인데 Bearish 다이버전스 → 신뢰도 하락
        confidenceMultiplier = max(0.3, 1.0 - (divergence.strength * 0.5));
      } else if (signal.changePercent < 0 && divergence.isBullish) {
        // 하락 신호인데 Bullish 다이버전스 → 신뢰도 하락
        confidenceMultiplier = max(0.3, 1.0 - (divergence.strength * 0.5));
      } else if ((signal.changePercent > 0 && divergence.isBullish) ||
                 (signal.changePercent < 0 && divergence.isBearish)) {
        // 신호와 다이버전스 방향 일치 → 신뢰도 상승
        confidenceMultiplier = min(1.5, 1.0 + (divergence.strength * 0.3));
      }
      
      // 조정된 신뢰도로 신호 업데이트
      final adjustedDetails = Map<String, dynamic>.from(signal.patternDetails);
      adjustedDetails['originalConfidence'] = adjustedDetails['confidence'];
      adjustedDetails['confidenceMultiplier'] = confidenceMultiplier;
      adjustedDetails['finalConfidence'] = 
          (adjustedDetails['confidence'] as double) * confidenceMultiplier;
      adjustedDetails['divergence'] = {
        'isBullish': divergence.isBullish,
        'isBearish': divergence.isBearish,
        'strength': divergence.strength,
        'source': 'online-rsi', // 온라인 RSI 기반임을 명시
      };
      
      return Signal(
        market: signal.market,
        name: signal.name,
        currentPrice: signal.currentPrice,
        changePercent: signal.changePercent,
        volume: signal.volume,
        tradeAmount: signal.tradeAmount,
        detectedAt: signal.detectedAt,
        patternType: signal.patternType,
        patternDetails: adjustedDetails,
      );
      
    } catch (e) {
      if (kDebugMode) {
        print('Confidence adjustment failed: $e');
      }
      return signal; // 실패시 원본 반환
    }
  }

  /// 🛠️ 헬퍼 함수들

  /// 🆕 온라인 지표 접근자 (Repository에서 사용)
  AdvancedMetrics get metrics => _metrics;

  /// RSI 방향성 검증
  bool _isValidRSIForDirection(double rsi, double changePercent) {
    if (changePercent > 0) {
      // 상승시 RSI 80 이하 (과매수 회피)
      return rsi <= 80;
    } else if (changePercent < 0) {
      // 하락시 RSI 20 이상 (과매도 회피)
      return rsi >= 20;
    }
    return true; // 변화 없으면 통과
  }

  /// 쿨다운 상태 조회
  Map<String, dynamic> getCooldownStatus() {
    final now = DateTime.now();
    final status = <String, dynamic>{};
    
    for (final entry in _lastSignalTime.entries) {
      final parts = entry.key.split('-');
      final market = parts[0];
      final patternName = parts[1];
      
      final pattern = PatternType.values.firstWhere(
        (p) => p.name == patternName,
        orElse: () => PatternType.surge,
      );
      
      final cooldownDuration = _config.getCooldownDuration(pattern);
      final remainingMs = cooldownDuration.inMilliseconds - 
                         now.difference(entry.value).inMilliseconds;
      
      status[entry.key] = {
        'market': market,
        'pattern': patternName,
        'isInCooldown': remainingMs > 0,
        'remainingMs': max(0, remainingMs),
        'cooldownDurationSeconds': cooldownDuration.inSeconds,
      };
    }
    
    return status;
  }

  /// 특정 패턴의 쿨다운 해제 (디버깅용)
  void clearCooldown(String market, PatternType pattern) {
    final cooldownKey = '$market-${pattern.name}';
    _lastSignalTime.remove(cooldownKey);
  }

  /// 모든 쿨다운 해제 (디버깅용)
  void clearAllCooldowns() {
    _lastSignalTime.clear();
  }

  /// 🆕 시스템 헬스 체크 (온라인 지표 포함)
  Map<String, dynamic> getSystemHealth() {
    final metricsHealth = _metrics.getSystemHealth();
    
    return {
      'version': 'V4.1-Online',
      'patternDetector': {
        'activeCooldowns': _lastSignalTime.length,
        'cooldownEntries': getCooldownStatus(),
      },
      'onlineMetrics': metricsHealth,
      'improvements': [
        'Online RSI/MACD Integration',
        'Stream Gap Auto-Recovery',
        'O(1) Indicator Calculation',
        'Real Divergence Detection',
        'Stale Data Prevention',
      ],
    };
  }

  /// 리소스 정리
  void dispose() {
    _lastSignalTime.clear();
    _metrics.dispose();
  }
}