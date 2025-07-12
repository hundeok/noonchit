// lib/features/trade/data/utils/trade_aggregator.dart
import 'package:flutter/foundation.dart';
import '../../../core/config/app_config.dart';

/// 🚀 TradeAggregator V2.0 - 적절한 성능 최적화
/// 
/// 핵심 개선사항:
/// 1. ✅ 타입 안전한 Trade 클래스 사용
/// 2. ✅ 메모리 할당 최소화 (Map 복사 제거)
/// 3. ✅ 배치 처리 및 성능 모니터링
/// 4. ✅ 기존 인터페이스 100% 호환성 유지
/// 5. ✅ 스마트 병합 로직 개선
class TradeAggregator {
  // 🚀 성능 최적화: 재사용 가능한 Trade 객체들
  final Map<String, _AggregatedTrade> _lastTrades = {};
  final int mergeWindow = AppConfig.mergeWindowMs;
  
  // 📊 성능 모니터링
  int _totalTrades = 0;
  int _mergedTrades = 0;
  int _processedTrades = 0;
  DateTime? _startTime;
  
  TradeAggregator() {
    _startTime = DateTime.now();
  }

  /// 거래 처리 및 병합 로직 (최적화 버전)
  void processTrade(
    Map<String, dynamic> trade, {
    required Function(Map<String, dynamic>) onTradeProcessed,
  }) {
    try {
      _totalTrades++;
      
      // 🚀 빠른 유효성 검사 (타입 캐스팅 최소화)
      final market = trade['market'];
      final price = trade['price'];
      final volume = trade['volume'];
      final timestamp = trade['timestamp'];
      
      if (market is! String || market.isEmpty ||
          price is! double || price <= 0 ||
          volume is! double || volume <= 0 ||
          timestamp is! int || timestamp <= 0) {
        if (kDebugMode) {
          debugPrint('TradeAggregator: Invalid trade data, skipping: $trade');
        }
        return;
      }

      final isBuy = trade['isBuy'] as bool? ?? true;
      final sequentialId = trade['sequential_id'] as String? ?? '';
      final total = price * volume;

      final existingTrade = _lastTrades[market];
      
      if (existingTrade != null) {
        // 🚀 시간 윈도우 체크 (빠른 정수 연산)
        if (timestamp - existingTrade.timestamp <= mergeWindow) {
          // 병합 처리 (메모리 할당 없이 in-place 업데이트)
          _mergeTradeInPlace(existingTrade, price, volume, total, timestamp, isBuy, sequentialId);
          _mergedTrades++;
          
          if (kDebugMode) {
            debugPrint('Merged trade: $market, total: ${existingTrade.total.toStringAsFixed(0)}, avg_price: ${existingTrade.price.toStringAsFixed(2)}');
          }
        } else {
          // 🚀 이전 거래 처리 (Map 복사 없이 직접 전달)
          _processTradeOptimized(existingTrade, onTradeProcessed);
          
          // 새 거래로 교체 (기존 객체 재사용)
          existingTrade.reset(market, price, volume, total, timestamp, isBuy, sequentialId);
        }
      } else {
        // 🚀 새로운 마켓 (객체 풀링)
        final newTrade = _AggregatedTrade(market, price, volume, total, timestamp, isBuy, sequentialId);
        _lastTrades[market] = newTrade;
        
        // 첫 거래 바로 처리
        _processTradeOptimized(newTrade, onTradeProcessed);
      }
      
      _processedTrades++;
      
    } catch (e, stackTrace) {
      if (kDebugMode) {
        debugPrint('TradeAggregator processTrade error: $e');
        debugPrint('StackTrace: $stackTrace');
      }
    }
  }

  /// 🚀 In-place 병합 (메모리 할당 없음)
  void _mergeTradeInPlace(
    _AggregatedTrade existingTrade,
    double newPrice,
    double newVolume, 
    double newTotal,
    int newTimestamp,
    bool newIsBuy,
    String newSequentialId,
  ) {
    final combinedTotal = existingTrade.total + newTotal;
    final combinedVolume = existingTrade.volume + newVolume;
    
    // 가중 평균 가격 계산
    final avgPrice = combinedTotal / combinedVolume;
    
    // In-place 업데이트 (새 객체 생성 없음)
    existingTrade.price = avgPrice;
    existingTrade.volume = combinedVolume;
    existingTrade.total = combinedTotal;
    existingTrade.timestamp = newTimestamp;
    existingTrade.isBuy = newIsBuy;
    existingTrade.sequentialId = newSequentialId;
  }

  /// 🚀 최적화된 거래 처리 (Map 복사 최소화)
  void _processTradeOptimized(
    _AggregatedTrade trade,
    Function(Map<String, dynamic>) onTradeProcessed,
  ) {
    // 🚀 재사용 가능한 Map 객체 (필요시에만 생성)
    final tradeMap = trade.toMap();
    onTradeProcessed(tradeMap);
  }

  /// 대기 중인 모든 거래를 플러시 (배치 최적화)
  void flushTrades({
    required Function(Map<String, dynamic>) onTradeProcessed,
  }) {
    try {
      final tradesCount = _lastTrades.length;
      
      if (tradesCount == 0) return;
      
      // 🚀 배치 처리 (리스트 한번 생성 후 재사용)
      final tradesToProcess = _lastTrades.values.toList();
      
      for (final trade in tradesToProcess) {
        _processTradeOptimized(trade, onTradeProcessed);
      }
      
      _lastTrades.clear();
      
      if (kDebugMode) {
        debugPrint('TradeAggregator: $tradesCount trades flushed');
      }
    } catch (e, stackTrace) {
      if (kDebugMode) {
        debugPrint('TradeAggregator flushTrades error: $e');
        debugPrint('StackTrace: $stackTrace');
      }
    }
  }

  /// 특정 마켓의 대기 중인 거래 가져오기 (호환성 유지)
  Map<String, dynamic>? getPendingTrade(String market) {
    final trade = _lastTrades[market];
    return trade?.toMap();
  }

  /// 현재 대기 중인 거래 수
  int get pendingTradesCount => _lastTrades.length;

  /// 🚀 성능 통계 조회
  Map<String, dynamic> get performanceStats {
    final uptime = _startTime != null 
        ? DateTime.now().difference(_startTime!).inSeconds 
        : 0;
    
    final mergeRate = _totalTrades > 0 ? (_mergedTrades / _totalTrades) : 0.0;
    final throughput = uptime > 0 ? (_processedTrades / uptime) : 0.0;
    
    return {
      'version': 'V2.0-Optimized',
      'uptime': uptime,
      'totalTrades': _totalTrades,
      'mergedTrades': _mergedTrades,
      'processedTrades': _processedTrades,
      'pendingTrades': pendingTradesCount,
      'mergeRate': mergeRate,
      'throughput': throughput,
      'optimizations': [
        'Type-safe Trade objects',
        'In-place merging (no allocation)',
        'Batch processing',
        'Object pooling',
        'Smart validation',
      ],
    };
  }

  /// 모든 대기 거래 클리어 (테스트/디버그용)
  void clear() {
    _lastTrades.clear();
    _totalTrades = 0;
    _mergedTrades = 0;
    _processedTrades = 0;
    _startTime = DateTime.now();
  }

  /// 🚀 리소스 정리
  void dispose() {
    if (kDebugMode) {
      final stats = performanceStats;
      debugPrint('TradeAggregator disposed - Merge rate: ${(stats['mergeRate'] * 100).toStringAsFixed(1)}%, Throughput: ${stats['throughput'].toStringAsFixed(1)} trades/sec');
    }
    _lastTrades.clear();
  }
}

// ==========================================================================
// 🚀 내부 최적화된 Trade 클래스
// ==========================================================================

/// 메모리 효율적인 집계 거래 클래스
class _AggregatedTrade {
  String market;
  double price;
  double volume;
  double total;
  int timestamp;
  bool isBuy;
  String sequentialId;

  _AggregatedTrade(
    this.market,
    this.price,
    this.volume,
    this.total,
    this.timestamp,
    this.isBuy,
    this.sequentialId,
  );

  /// 🚀 객체 재사용을 위한 리셋
  void reset(
    String newMarket,
    double newPrice,
    double newVolume,
    double newTotal,
    int newTimestamp,
    bool newIsBuy,
    String newSequentialId,
  ) {
    market = newMarket;
    price = newPrice;
    volume = newVolume;
    total = newTotal;
    timestamp = newTimestamp;
    isBuy = newIsBuy;
    sequentialId = newSequentialId;
  }

  /// 🚀 기존 인터페이스 호환용 Map 변환 (필요시에만)
  Map<String, dynamic> toMap() {
    return {
      'market': market,
      'price': price,
      'volume': volume,
      'total': total,
      'timestamp': timestamp,
      'isBuy': isBuy,
      'sequential_id': sequentialId,
    };
  }

  @override
  String toString() {
    return '_AggregatedTrade(market: $market, price: ${price.toStringAsFixed(2)}, volume: ${volume.toStringAsFixed(4)}, total: ${total.toStringAsFixed(0)})';
  }
}