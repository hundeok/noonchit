// test/data/processors/trade_aggregator_test.dart
import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart';
import 'package:noonchit/data/processors/trade_aggregator.dart';

void main() {
  late TradeAggregator aggregator;

  setUpAll(() async {
    dotenv.testLoad(fileInput: '''
LOG_LEVEL=debug
DEBUG_MODE=true
    ''');
  });

  setUp(() {
    aggregator = TradeAggregator();
  });

  group('TradeAggregator', () {
    test('processTrade should store new trade and call onTradeProcessed', () {
      final trade = {
        'market': 'KRW-BTC',
        'price': 50000.0,
        'volume': 2.0,
        'timestamp': 1630000000000,
        'isBuy': true,
        'sequential_id': '12345',
      };

      bool called = false;
      Map<String, dynamic>? processedTrade;

      aggregator.processTrade(trade, onTradeProcessed: (t) {
        called = true;
        processedTrade = t;
      });

      expect(called, true);
      expect(processedTrade!['market'], 'KRW-BTC');
      expect(processedTrade!['total'], 100000.0);
      expect(aggregator.pendingTradesCount, 1);
    });

    test('processTrade should merge trades within merge window', () {
      final trade1 = {
        'market': 'KRW-BTC',
        'price': 50000.0,
        'volume': 2.0,
        'timestamp': 1630000000000,
        'isBuy': true,
        'sequential_id': '12345',
      };
      final trade2 = {
        'market': 'KRW-BTC',
        'price': 60000.0,
        'volume': 3.0,
        'timestamp': 1630000001000, // 1초 후 (merge window 내)
        'isBuy': true,
        'sequential_id': '12346',
      };

      int processedCount = 0;
      aggregator.processTrade(trade1, onTradeProcessed: (_) {
        processedCount++;
      });

      aggregator.processTrade(trade2, onTradeProcessed: (_) {
        processedCount++;
      });

      final pending = aggregator.getPendingTrade('KRW-BTC');
      expect(pending, isNotNull);
      expect(pending!['volume'], 5.0);
      expect(pending['price'], 56000.0); // 가중평균: (50000*2 + 60000*3) / 5
      expect(pending['total'], 280000.0);
      expect(processedCount, 1); // 첫 번째만 처리됨
    });

    test('processTrade should process previous trade when outside merge window', () {
      final trade1 = {
        'market': 'KRW-BTC',
        'price': 50000.0,
        'volume': 2.0,
        'timestamp': 1630000000000,
        'isBuy': true,
        'sequential_id': '12345',
      };
      final trade2 = {
        'market': 'KRW-BTC',
        'price': 60000.0,
        'volume': 3.0,
        'timestamp': 1630000060000, // 60초 후 (merge window 밖)
        'isBuy': false,
        'sequential_id': '12346',
      };

      final processedTrades = <Map<String, dynamic>>[];

      aggregator.processTrade(trade1, onTradeProcessed: (t) {
        processedTrades.add(Map<String, dynamic>.from(t));
      });

      aggregator.processTrade(trade2, onTradeProcessed: (t) {
        processedTrades.add(Map<String, dynamic>.from(t));
      });

      expect(processedTrades.length, 2);
      expect(processedTrades[0]['price'], 50000.0);
      expect(processedTrades[0]['volume'], 2.0);
      // 두 번째 거래는 아직 pending 상태이므로 처리되지 않음
      expect(aggregator.pendingTradesCount, 1);
    });

    test('processTrade should handle different markets separately', () {
      final btcTrade = {
        'market': 'KRW-BTC',
        'price': 50000.0,
        'volume': 2.0,
        'timestamp': 1630000000000,
        'isBuy': true,
        'sequential_id': '12345',
      };
      final ethTrade = {
        'market': 'KRW-ETH',
        'price': 3000.0,
        'volume': 5.0,
        'timestamp': 1630000001000,
        'isBuy': false,
        'sequential_id': '12346',
      };

      final processedTrades = <Map<String, dynamic>>[];

      aggregator.processTrade(btcTrade, onTradeProcessed: (t) {
        processedTrades.add(Map<String, dynamic>.from(t));
      });

      aggregator.processTrade(ethTrade, onTradeProcessed: (t) {
        processedTrades.add(Map<String, dynamic>.from(t));
      });

      expect(processedTrades.length, 2);
      expect(aggregator.pendingTradesCount, 2);
      expect(aggregator.getPendingTrade('KRW-BTC'), isNotNull);
      expect(aggregator.getPendingTrade('KRW-ETH'), isNotNull);
    });

    test('flushTrades should process all pending trades', () {
      final trade1 = {
        'market': 'KRW-BTC',
        'price': 50000.0,
        'volume': 2.0,
        'timestamp': 1630000000000,
        'isBuy': true,
        'sequential_id': '12345',
      };
      final trade2 = {
        'market': 'KRW-ETH',
        'price': 3000.0,
        'volume': 5.0,
        'timestamp': 1630000001000,
        'isBuy': false,
        'sequential_id': '12346',
      };

      aggregator.processTrade(trade1, onTradeProcessed: (_) {});
      aggregator.processTrade(trade2, onTradeProcessed: (_) {});
      expect(aggregator.pendingTradesCount, 2);

      final flushedTrades = <Map<String, dynamic>>[];
      aggregator.flushTrades(onTradeProcessed: (t) {
        flushedTrades.add(Map<String, dynamic>.from(t));
      });

      expect(flushedTrades.length, 2);
      expect(aggregator.pendingTradesCount, 0);
    });

    test('getPendingTrade should return null for non-existent market', () {
      final pending = aggregator.getPendingTrade('NON-EXISTENT');
      expect(pending, isNull);
    });

    test('clear should remove all pending trades', () {
      final trade = {
        'market': 'KRW-BTC',
        'price': 50000.0,
        'volume': 2.0,
        'timestamp': 1630000000000,
        'isBuy': true,
        'sequential_id': '12345',
      };

      aggregator.processTrade(trade, onTradeProcessed: (_) {});
      expect(aggregator.pendingTradesCount, 1);

      aggregator.clear();
      expect(aggregator.pendingTradesCount, 0);
    });

    test('processTrade should handle missing fields gracefully', () {
      final invalidTrade = {
        'market': 'KRW-BTC',
        'price': 50000.0,
        'volume': 2.0,
        // timestamp 누락
        'isBuy': true,
        'sequential_id': '12345',
      };

      aggregator.processTrade(invalidTrade, onTradeProcessed: (_) {});
      
      // 에러가 내부적으로 처리되므로 직접 확인하지 않음
      expect(aggregator.pendingTradesCount, 0);
    });

    test('processTrade should handle null values gracefully', () {
      final invalidTrade = {
        'market': null,
        'price': null,
        'volume': null,
        'timestamp': null,
        'isBuy': null,
        'sequential_id': null,
      };

      aggregator.processTrade(invalidTrade, onTradeProcessed: (_) {});
      
      // 에러가 내부적으로 처리되므로 직접 확인하지 않음
      expect(aggregator.pendingTradesCount, 0);
    });
  });
}