// lib/features/trade/data/utils/trade_aggregator.dart
import 'package:flutter/foundation.dart';
import '../../../core/config/app_config.dart';

/// 예전 프로젝트와 같이 효율적으로 작동하는 거래 집계기
class TradeAggregator {
  final Map<String, Map<String, dynamic>> _lastTrades = {};
  final int mergeWindow = AppConfig.mergeWindowMs;

  /// 거래 처리 및 병합 로직
  void processTrade(
    Map<String, dynamic> trade, {
    required Function(Map<String, dynamic>) onTradeProcessed,
  }) {
    try {
      // 안전한 null 체크와 타입 캐스팅
      final market = trade['market'] as String? ?? '';
      final price = trade['price'] as double? ?? 0.0;
      final volume = trade['volume'] as double? ?? 0.0;
      final timestamp = trade['timestamp'] as int? ?? 0;
      final isBuy = trade['isBuy'] as bool? ?? true;
      final sequentialId = trade['sequential_id'] as String? ?? '';

      // 유효하지 않은 데이터는 처리하지 않음
      if (market.isEmpty || price <= 0 || volume <= 0 || timestamp <= 0) {
        if (kDebugMode) {
          debugPrint('TradeAggregator: Invalid trade data, skipping: market=$market, price=$price, volume=$volume, timestamp=$timestamp');
        }
        return;
      }

      final total = price * volume;

      if (_lastTrades.containsKey(market)) {
        final lastTrade = _lastTrades[market]!;
        final lastTs = lastTrade['timestamp'] as int;

        // 시간 윈도우 내의 거래면 병합
        if (timestamp - lastTs <= mergeWindow) {
          final lastTotal = lastTrade['total'] as double;
          final lastVolume = lastTrade['volume'] as double;
          final newTotal = lastTotal + total;
          final newVolume = lastVolume + volume;

          // 가중 평균 가격 계산
          final avgPrice = newTotal / newVolume;

          // 병합된 거래 정보 업데이트
          lastTrade['price'] = avgPrice;
          lastTrade['volume'] = newVolume;
          lastTrade['total'] = newTotal;
          lastTrade['timestamp'] = timestamp; // 최신 시간으로 업데이트
          lastTrade['sequential_id'] = sequentialId;
          lastTrade['isBuy'] = isBuy; // 최신 거래의 방향 사용

          if (kDebugMode) {
            debugPrint(
              'Merged trade: $market, total: ${newTotal.toStringAsFixed(0)}, avg_price: ${avgPrice.toStringAsFixed(2)}',
            );
          }
        } else {
          // 시간 윈도우를 벗어나면 이전 거래 처리하고 새 거래로 교체
          onTradeProcessed(Map<String, dynamic>.from(lastTrade));
          _lastTrades[market] = {
            'market': market,
            'price': price,
            'volume': volume,
            'total': total,
            'timestamp': timestamp,
            'isBuy': isBuy,
            'sequential_id': sequentialId,
          };
        }
      } else {
        // 새로운 마켓의 첫 거래
        final newTrade = {
          'market': market,
          'price': price,
          'volume': volume,
          'total': total,
          'timestamp': timestamp,
          'isBuy': isBuy,
          'sequential_id': sequentialId,
        };
        _lastTrades[market] = newTrade;
        // 🔥 중요: 첫 거래도 바로 처리하여 UI에 반영
        onTradeProcessed(Map<String, dynamic>.from(newTrade));
      }
    } catch (e, stackTrace) {
      if (kDebugMode) {
        debugPrint('TradeAggregator processTrade error: $e');
        debugPrint('StackTrace: $stackTrace');
      }
    }
  }

  /// 대기 중인 모든 거래를 플러시
  void flushTrades({
    required Function(Map<String, dynamic>) onTradeProcessed,
  }) {
    try {
      final tradesCount = _lastTrades.length;
      for (final trade in _lastTrades.values) {
        onTradeProcessed(Map<String, dynamic>.from(trade));
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

  /// 특정 마켓의 대기 중인 거래 가져오기 (디버깅용)
  Map<String, dynamic>? getPendingTrade(String market) {
    return _lastTrades[market] != null
        ? Map<String, dynamic>.from(_lastTrades[market]!)
        : null;
  }

  /// 현재 대기 중인 거래 수
  int get pendingTradesCount => _lastTrades.length;

  /// 모든 대기 거래 클리어 (테스트/디버그용)
  void clear() {
    _lastTrades.clear();
  }
}