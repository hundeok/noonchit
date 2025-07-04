import 'rolling_window.dart';
import 'advanced_metrics.dart';

/// 🎯 MarketDataContext - 마켓 데이터 통합 관리
/// 
/// V4.1 개선사항:
/// - 9개 파라미터 → 1개 객체로 단순화
/// - 타임프레임별 윈도우 관리
/// - 🆕 온라인 지표 연동 지원
/// - 메모리 효율적인 윈도우 관리
/// - 데이터 무결성 보장
class MarketDataContext {
  final String market;
  
  // 📊 멀티 타임프레임 가격 윈도우
  final Map<Duration, RollingWindow<double>> _priceWindows = {};
  
  // 📊 멀티 타임프레임 거래량 윈도우
  final Map<Duration, RollingWindow<double>> _volumeWindows = {};
  
  // 📊 보조 지표 윈도우들
  final RollingWindow<double>? buyRatioWindow;
  final RollingWindow<double>? intervalWindow;
  
  /// 생성자
  MarketDataContext({
    required this.market,
    required Map<Duration, RollingWindow<double>> priceWindows,
    required Map<Duration, RollingWindow<double>> volumeWindows,
    this.buyRatioWindow,
    this.intervalWindow,
  }) {
    _priceWindows.addAll(priceWindows);
    _volumeWindows.addAll(volumeWindows);
    
    // 데이터 무결성 검사
    _validateWindows();
  }

  /// 🏗️ 팩토리 생성자 - 표준 타임프레임으로 생성
  factory MarketDataContext.standard({
    required String market,
    required RollingWindow<double> priceWindow30s,
    required RollingWindow<double> priceWindow60s,
    required RollingWindow<double> priceWindow300s,
    required RollingWindow<double> volumeWindow30s,
    required RollingWindow<double> volumeWindow60s,
    required RollingWindow<double> volumeWindow300s,
    RollingWindow<double>? buyRatioWindow,
    RollingWindow<double>? intervalWindow,
  }) {
    return MarketDataContext(
      market: market,
      priceWindows: {
        const Duration(seconds: 30): priceWindow30s,
        const Duration(seconds: 60): priceWindow60s,
        const Duration(seconds: 300): priceWindow300s,
      },
      volumeWindows: {
        const Duration(seconds: 30): volumeWindow30s,
        const Duration(seconds: 60): volumeWindow60s,
        const Duration(seconds: 300): volumeWindow300s,
      },
      buyRatioWindow: buyRatioWindow,
      intervalWindow: intervalWindow,
    );
  }

  /// 🏗️ 팩토리 생성자 - 빈 컨텍스트 생성
  factory MarketDataContext.empty(String market) {
    return MarketDataContext(
      market: market,
      priceWindows: {
        const Duration(seconds: 30): RollingWindow<double>(span: const Duration(seconds: 30)),
        const Duration(seconds: 60): RollingWindow<double>(span: const Duration(seconds: 60)),
        const Duration(seconds: 300): RollingWindow<double>(span: const Duration(seconds: 300)),
      },
      volumeWindows: {
        const Duration(seconds: 30): RollingWindow<double>(span: const Duration(seconds: 30)),
        const Duration(seconds: 60): RollingWindow<double>(span: const Duration(seconds: 60)),
        const Duration(seconds: 300): RollingWindow<double>(span: const Duration(seconds: 300)),
      },
      buyRatioWindow: RollingWindow<double>(span: const Duration(seconds: 180)),
      intervalWindow: RollingWindow<double>(span: const Duration(seconds: 600)),
    );
  }

  /// 📊 가격 윈도우 조회
  RollingWindow<double> getPriceWindow(Duration timeframe) {
    final window = _priceWindows[timeframe];
    if (window == null) {
      throw ArgumentError('Price window not found for timeframe: ${timeframe.inSeconds}s');
    }
    return window;
  }

  /// 📊 거래량 윈도우 조회
  RollingWindow<double> getVolumeWindow(Duration timeframe) {
    final window = _volumeWindows[timeframe];
    if (window == null) {
      throw ArgumentError('Volume window not found for timeframe: ${timeframe.inSeconds}s');
    }
    return window;
  }

  /// 📊 사용 가능한 타임프레임 목록
  List<Duration> get availableTimeframes {
    final timeframes = <Duration>{..._priceWindows.keys, ..._volumeWindows.keys}.toList();
    timeframes.sort((a, b) => a.inSeconds.compareTo(b.inSeconds));
    return timeframes;
  }

  /// 📊 가장 긴 타임프레임 윈도우 조회
  RollingWindow<double> get longestPriceWindow {
    if (_priceWindows.isEmpty) {
      throw StateError('No price windows available');
    }
    
    final longestTimeframe = _priceWindows.keys.reduce(
      (a, b) => a.inSeconds > b.inSeconds ? a : b
    );
    return _priceWindows[longestTimeframe]!;
  }

  /// 📊 가장 긴 타임프레임 거래량 윈도우 조회
  RollingWindow<double> get longestVolumeWindow {
    if (_volumeWindows.isEmpty) {
      throw StateError('No volume windows available');
    }
    
    final longestTimeframe = _volumeWindows.keys.reduce(
      (a, b) => a.inSeconds > b.inSeconds ? a : b
    );
    return _volumeWindows[longestTimeframe]!;
  }

  /// 📊 가장 짧은 타임프레임 윈도우 조회
  RollingWindow<double> get shortestPriceWindow {
    if (_priceWindows.isEmpty) {
      throw StateError('No price windows available');
    }
    
    final shortestTimeframe = _priceWindows.keys.reduce(
      (a, b) => a.inSeconds < b.inSeconds ? a : b
    );
    return _priceWindows[shortestTimeframe]!;
  }

  /// 📊 가장 짧은 타임프레임 거래량 윈도우 조회
  RollingWindow<double> get shortestVolumeWindow {
    if (_volumeWindows.isEmpty) {
      throw StateError('No volume windows available');
    }
    
    final shortestTimeframe = _volumeWindows.keys.reduce(
      (a, b) => a.inSeconds < b.inSeconds ? a : b
    );
    return _volumeWindows[shortestTimeframe]!;
  }

  /// 🔄 데이터 업데이트
  void updateAllWindows({
    required double price,
    required double volume,
    required DateTime timestamp,
    double? buyRatio,
    double? interval,
  }) {
    // 모든 가격 윈도우 업데이트
    for (final window in _priceWindows.values) {
      window.add(price, timestamp: timestamp);
    }
    
    // 모든 거래량 윈도우 업데이트
    for (final window in _volumeWindows.values) {
      window.add(volume, timestamp: timestamp);
    }
    
    // 보조 윈도우 업데이트
    if (buyRatio != null && buyRatioWindow != null) {
      buyRatioWindow!.add(buyRatio, timestamp: timestamp);
    }
    
    if (interval != null && intervalWindow != null) {
      intervalWindow!.add(interval, timestamp: timestamp);
    }
  }

  /// 🆕 온라인 지표 업데이트를 위한 메서드
  void updateWithOnlineMetrics({
    required double price,
    required double volume,
    required DateTime timestamp,
    double? buyRatio,
    double? interval,
    required AdvancedMetrics onlineMetrics,
  }) {
    // 기본 윈도우 업데이트
    updateAllWindows(
      price: price,
      volume: volume,
      timestamp: timestamp,
      buyRatio: buyRatio,
      interval: interval,
    );
    
    // 🔥 온라인 지표도 동시 업데이트
    onlineMetrics.updatePrice(
      market: market,
      price: price,
      timestamp: timestamp,
    );
  }

  /// 📊 다중 타임프레임 트렌드 분석
  Map<String, dynamic> getMultiTimeframeTrend() {
    final trends = <String, Map<String, dynamic>>{};
    
    for (final entry in _priceWindows.entries) {
      final timeframe = '${entry.key.inSeconds}s';
      final window = entry.value;
      
      if (window.length >= 2) {
        final currentPrice = window.values.first;
        final previousPrice = window.values[1];
        final changePercent = ((currentPrice - previousPrice) / previousPrice) * 100;
        
        trends[timeframe] = {
          'changePercent': changePercent,
          'trend': changePercent > 0.1 ? 'UP' : 
                   changePercent < -0.1 ? 'DOWN' : 'FLAT',
          'volatility': window.cv,
          'dataPoints': window.length,
        };
      }
    }
    
    return {
      'market': market,
      'trends': trends,
      'consensus': _calculateTrendConsensus(trends),
    };
  }

  /// 🎯 트렌드 합의 계산
  String _calculateTrendConsensus(Map<String, Map<String, dynamic>> trends) {
    if (trends.isEmpty) return 'UNKNOWN';
    
    final upCount = trends.values.where((t) => t['trend'] == 'UP').length;
    final downCount = trends.values.where((t) => t['trend'] == 'DOWN').length;
    final flatCount = trends.values.where((t) => t['trend'] == 'FLAT').length;
    
    if (upCount > downCount && upCount > flatCount) return 'BULLISH';
    if (downCount > upCount && downCount > flatCount) return 'BEARISH';
    return 'NEUTRAL';
  }

  /// 📊 윈도우 상태 정보
  Map<String, dynamic> getWindowStats() {
    final stats = <String, dynamic>{
      'market': market,
      'priceWindows': <String, dynamic>{},
      'volumeWindows': <String, dynamic>{},
      'auxWindows': <String, dynamic>{},
    };
    
    // 가격 윈도우 통계
    for (final entry in _priceWindows.entries) {
      final timeframe = '${entry.key.inSeconds}s';
      final window = entry.value;
      
      stats['priceWindows'][timeframe] = {
        'length': window.length,
        'mean': window.length > 0 ? window.mean : 0.0,
        'stdev': window.length > 0 ? window.stdev : 0.0,
        'cv': window.length > 0 ? window.cv : 0.0,
        'min': window.length > 0 ? window.min : 0.0,
        'max': window.length > 0 ? window.max : 0.0,
      };
    }
    
    // 거래량 윈도우 통계
    for (final entry in _volumeWindows.entries) {
      final timeframe = '${entry.key.inSeconds}s';
      final window = entry.value;
      
      stats['volumeWindows'][timeframe] = {
        'length': window.length,
        'sum': window.length > 0 ? window.sum : 0.0,
        'mean': window.length > 0 ? window.mean : 0.0,
        'stdev': window.length > 0 ? window.stdev : 0.0,
      };
    }
    
    // 보조 윈도우 통계
    if (buyRatioWindow != null) {
      stats['auxWindows']['buyRatio'] = {
        'length': buyRatioWindow!.length,
        'mean': buyRatioWindow!.length > 0 ? buyRatioWindow!.mean : 0.5,
      };
    }
    
    if (intervalWindow != null) {
      stats['auxWindows']['interval'] = {
        'length': intervalWindow!.length,
        'mean': intervalWindow!.length > 0 ? intervalWindow!.mean : 0.0,
        'variance': intervalWindow!.length > 0 ? intervalWindow!.variance : 0.0,
      };
    }
    
    return stats;
  }

  /// 🔍 데이터 품질 검사 (온라인 지표 포함)
  Map<String, dynamic> getDataQuality({AdvancedMetrics? onlineMetrics}) {
    final quality = <String, dynamic>{
      'market': market,
      'overall': 'GOOD',
      'issues': <String>[],
      'scores': <String, double>{},
    };
    
    double totalScore = 0.0;
    int windowCount = 0;
    
    // 가격 윈도우 품질 검사
    for (final entry in _priceWindows.entries) {
      final timeframe = '${entry.key.inSeconds}s';
      final window = entry.value;
      
      double score = 1.0;
      
      if (window.isEmpty) {
        quality['issues'].add('Empty price window: $timeframe');
        score = 0.0;
      } else if (window.length < entry.key.inSeconds / 10) {
        quality['issues'].add('Insufficient data in price window: $timeframe');
        score = 0.5;
      } else if (window.stdev == 0) {
        quality['issues'].add('No price variance in window: $timeframe');
        score = 0.3;
      }
      
      quality['scores']['price_$timeframe'] = score;
      totalScore += score;
      windowCount++;
    }
    
    // 거래량 윈도우 품질 검사
    for (final entry in _volumeWindows.entries) {
      final timeframe = '${entry.key.inSeconds}s';
      final window = entry.value;
      
      double score = 1.0;
      
      if (window.isEmpty) {
        quality['issues'].add('Empty volume window: $timeframe');
        score = 0.0;
      } else if (window.sum == 0) {
        quality['issues'].add('No volume in window: $timeframe');
        score = 0.0;
      }
      
      quality['scores']['volume_$timeframe'] = score;
      totalScore += score;
      windowCount++;
    }
    
    // 🆕 온라인 지표 품질 검사
    if (onlineMetrics != null) {
      final metricsHealth = onlineMetrics.getSystemHealth();
      final marketHealth = metricsHealth['markets']?[market];
      
      if (marketHealth != null) {
        double metricsScore = 1.0;
        
        if (marketHealth['isStale'] == true) {
          quality['issues'].add('Online metrics are stale');
          metricsScore = 0.3;
        } else if (marketHealth['rsi']?['isReady'] != true) {
          quality['issues'].add('RSI calculator not ready');
          metricsScore = 0.5;
        } else if (marketHealth['macd']?['isReady'] != true) {
          quality['issues'].add('MACD calculator not ready');
          metricsScore = 0.5;
        }
        
        quality['scores']['online_metrics'] = metricsScore;
        totalScore += metricsScore;
        windowCount++;
        
        // 온라인 지표 상세 정보 추가
        quality['onlineMetrics'] = {
          'rsi': marketHealth['rsi'],
          'macd': marketHealth['macd'],
          'lastUpdate': marketHealth['lastUpdate'],
        };
      }
    }
    
    // 전체 품질 점수 계산
    final overallScore = windowCount > 0 ? totalScore / windowCount : 0.0;
    quality['overallScore'] = overallScore;
    
    if (overallScore >= 0.8) {
      quality['overall'] = 'EXCELLENT';
    } else if (overallScore >= 0.6) {
      quality['overall'] = 'GOOD';
    } else if (overallScore >= 0.4) {
      quality['overall'] = 'FAIR';
    } else {
      quality['overall'] = 'POOR';
    }
    
    return quality;
  }

  /// 🧹 윈도우 정리 (메모리 최적화 + 온라인 지표)
  void cleanup({bool force = false, AdvancedMetrics? onlineMetrics}) {
    final now = DateTime.now();
    
    for (final window in _priceWindows.values) {
      if (force || (window.timestamps.isNotEmpty && 
          now.difference(window.timestamps.last).inMinutes > 30)) {
        // 오래된 데이터나 force 플래그시 정리
        window.clear();
      }
    }
    
    for (final window in _volumeWindows.values) {
      if (force || (window.timestamps.isNotEmpty && 
          now.difference(window.timestamps.last).inMinutes > 30)) {
        window.clear();
      }
    }
    
    buyRatioWindow?.clear();
    intervalWindow?.clear();
    
    // 🆕 온라인 지표도 함께 정리
    if (onlineMetrics != null && force) {
      onlineMetrics.resetMarket(market);
    }
  }

  /// 🔍 데이터 무결성 검사
  void _validateWindows() {
    // 가격 윈도우 검사
    for (final entry in _priceWindows.entries) {
      final timeframe = entry.key;
      final window = entry.value;
      
      if (window.span != timeframe) {
        throw ArgumentError(
          'Price window span mismatch: expected ${timeframe.inSeconds}s, '
          'got ${window.span.inSeconds}s'
        );
      }
    }
    
    // 거래량 윈도우 검사
    for (final entry in _volumeWindows.entries) {
      final timeframe = entry.key;
      final window = entry.value;
      
      if (window.span != timeframe) {
        throw ArgumentError(
          'Volume window span mismatch: expected ${timeframe.inSeconds}s, '
          'got ${window.span.inSeconds}s'
        );
      }
    }
  }
}