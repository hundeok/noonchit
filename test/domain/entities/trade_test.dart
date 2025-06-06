// test/domain/entities/trade_test.dart
import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart';
import 'package:noonchit/domain/entities/trade.dart';

void main() {
  setUpAll(() async {
    dotenv.testLoad(fileInput: '''
LOG_LEVEL=debug
DEBUG_MODE=true
    ''');
  });

  group('Trade', () {
    const baseTrade = Trade(
      market: 'KRW-BTC',
      price: 50000.0,
      volume: 2.5,
      side: 'BID',
      changePrice: 100.0,
      changeState: 'RISE',
      timestampMs: 1630000000000,
      sequentialId: '12345',
    );

    group('constructor and properties', () {
      test('should create trade with all required properties', () {
        expect(baseTrade.market, 'KRW-BTC');
        expect(baseTrade.price, 50000.0);
        expect(baseTrade.volume, 2.5);
        expect(baseTrade.side, 'BID');
        expect(baseTrade.changePrice, 100.0);
        expect(baseTrade.changeState, 'RISE');
        expect(baseTrade.timestampMs, 1630000000000);
        expect(baseTrade.sequentialId, '12345');
      });

      test('should handle different market codes', () {
        const trades = [
          Trade(
            market: 'KRW-BTC',
            price: 50000000.0,
            volume: 1.0,
            side: 'BID',
            changePrice: 0.0,
            changeState: 'EVEN',
            timestampMs: 1630000000000,
            sequentialId: '1',
          ),
          Trade(
            market: 'KRW-ETH',
            price: 4000000.0,
            volume: 1.0,
            side: 'ASK',
            changePrice: -50000.0,
            changeState: 'FALL',
            timestampMs: 1630000000000,
            sequentialId: '2',
          ),
          Trade(
            market: 'BTC-ETH',
            price: 0.08,
            volume: 5.0,
            side: 'BID',
            changePrice: 0.001,
            changeState: 'RISE',
            timestampMs: 1630000000000,
            sequentialId: '3',
          ),
        ];

        expect(trades[0].market, 'KRW-BTC');
        expect(trades[1].market, 'KRW-ETH');
        expect(trades[2].market, 'BTC-ETH');
      });
    });

    group('total calculation', () {
      test('should calculate total correctly', () {
        expect(baseTrade.total, 125000.0); // 50000.0 * 2.5
      });

      test('should handle small volumes', () {
        const smallTrade = Trade(
          market: 'KRW-BTC',
          price: 50000000.0,
          volume: 0.00001,
          side: 'BID',
          changePrice: 0.0,
          changeState: 'EVEN',
          timestampMs: 1630000000000,
          sequentialId: '12345',
        );

        expect(smallTrade.total, closeTo(500.0, 0.0001)); // 50000000.0 * 0.00001
      });

      test('should handle large volumes', () {
        const largeTrade = Trade(
          market: 'KRW-BTC',
          price: 50000000.0,
          volume: 100.0,
          side: 'BID',
          changePrice: 0.0,
          changeState: 'EVEN',
          timestampMs: 1630000000000,
          sequentialId: '12345',
        );

        expect(largeTrade.total, 5000000000.0); // 50000000.0 * 100.0
      });

      test('should handle zero volume', () {
        const zeroTrade = Trade(
          market: 'KRW-BTC',
          price: 50000000.0,
          volume: 0.0,
          side: 'BID',
          changePrice: 0.0,
          changeState: 'EVEN',
          timestampMs: 1630000000000,
          sequentialId: '12345',
        );

        expect(zeroTrade.total, 0.0);
      });

      test('should handle decimal precision correctly', () {
        const decimalTrade = Trade(
          market: 'KRW-BTC',
          price: 50000.123,
          volume: 2.456789,
          side: 'BID',
          changePrice: 0.0,
          changeState: 'EVEN',
          timestampMs: 1630000000000,
          sequentialId: '12345',
        );

        // 실제 계산값 확인: 50000.123 * 2.456789
        expect(decimalTrade.total, closeTo(122839.75218504701, 0.01));
      });
    });

    group('isBuy property', () {
      test('should return true for BID', () {
        const bidTrade = Trade(
          market: 'KRW-BTC',
          price: 50000.0,
          volume: 1.0,
          side: 'BID',
          changePrice: 0.0,
          changeState: 'EVEN',
          timestampMs: 1630000000000,
          sequentialId: '12345',
        );

        expect(bidTrade.isBuy, true);
      });

      test('should return false for ASK', () {
        const askTrade = Trade(
          market: 'KRW-BTC',
          price: 50000.0,
          volume: 1.0,
          side: 'ASK',
          changePrice: 0.0,
          changeState: 'EVEN',
          timestampMs: 1630000000000,
          sequentialId: '12345',
        );

        expect(askTrade.isBuy, false);
      });

      test('should handle case sensitivity', () {
        const lowercaseBid = Trade(
          market: 'KRW-BTC',
          price: 50000.0,
          volume: 1.0,
          side: 'bid', // 소문자
          changePrice: 0.0,
          changeState: 'EVEN',
          timestampMs: 1630000000000,
          sequentialId: '12345',
        );

        expect(lowercaseBid.isBuy, false); // 'BID'가 아니므로 false
      });
    });

    group('timestamp conversion', () {
      test('should convert timestampMs to DateTime correctly', () {
        expect(baseTrade.timestamp.millisecondsSinceEpoch, 1630000000000);
        expect(baseTrade.timestamp.year, 2021);
        expect(baseTrade.timestamp.month, 8);
        expect(baseTrade.timestamp.day, 27); // UTC 기준으로 27일
      });

      test('should handle different timestamps', () {
        const recentTrade = Trade(
          market: 'KRW-BTC',
          price: 50000.0,
          volume: 1.0,
          side: 'BID',
          changePrice: 0.0,
          changeState: 'EVEN',
          timestampMs: 1700000000000, // 2023년
          sequentialId: '12345',
        );

        expect(recentTrade.timestamp.year, 2023);
        expect(recentTrade.timestamp.month, 11);
      });

      test('should handle zero timestamp', () {
        const zeroTrade = Trade(
          market: 'KRW-BTC',
          price: 50000.0,
          volume: 1.0,
          side: 'BID',
          changePrice: 0.0,
          changeState: 'EVEN',
          timestampMs: 0,
          sequentialId: '12345',
        );

        expect(zeroTrade.timestamp.year, 1970);
        expect(zeroTrade.timestamp.month, 1);
        expect(zeroTrade.timestamp.day, 1);
      });
    });

    group('Equatable', () {
      test('should be equal when all properties are same', () {
        const trade1 = Trade(
          market: 'KRW-BTC',
          price: 50000.0,
          volume: 2.5,
          side: 'BID',
          changePrice: 100.0,
          changeState: 'RISE',
          timestampMs: 1630000000000,
          sequentialId: '12345',
        );
        const trade2 = Trade(
          market: 'KRW-BTC',
          price: 50000.0,
          volume: 2.5,
          side: 'BID',
          changePrice: 100.0,
          changeState: 'RISE',
          timestampMs: 1630000000000,
          sequentialId: '12345',
        );

        expect(trade1, equals(trade2));
        expect(trade1.hashCode, equals(trade2.hashCode));
      });

      test('should not be equal when sequential ID differs', () {
        const trade1 = Trade(
          market: 'KRW-BTC',
          price: 50000.0,
          volume: 2.5,
          side: 'BID',
          changePrice: 100.0,
          changeState: 'RISE',
          timestampMs: 1630000000000,
          sequentialId: '12345',
        );
        const trade2 = Trade(
          market: 'KRW-BTC',
          price: 50000.0,
          volume: 2.5,
          side: 'BID',
          changePrice: 100.0,
          changeState: 'RISE',
          timestampMs: 1630000000000,
          sequentialId: '67890',
        );

        expect(trade1, isNot(equals(trade2)));
      });

      test('should not be equal when price differs', () {
        const trade1 = Trade(
          market: 'KRW-BTC',
          price: 50000.0,
          volume: 2.5,
          side: 'BID',
          changePrice: 100.0,
          changeState: 'RISE',
          timestampMs: 1630000000000,
          sequentialId: '12345',
        );
        const trade2 = Trade(
          market: 'KRW-BTC',
          price: 51000.0,
          volume: 2.5,
          side: 'BID',
          changePrice: 100.0,
          changeState: 'RISE',
          timestampMs: 1630000000000,
          sequentialId: '12345',
        );

        expect(trade1, isNot(equals(trade2)));
      });

      test('should have correct props order', () {
        expect(baseTrade.props, [
          'KRW-BTC',
          50000.0,
          2.5,
          'BID',
          100.0,
          'RISE',
          1630000000000,
          '12345',
        ]);
      });
    });

    group('change states and price movements', () {
      test('should handle RISE state', () {
        const riseTrade = Trade(
          market: 'KRW-BTC',
          price: 50000.0,
          volume: 1.0,
          side: 'BID',
          changePrice: 1000.0,
          changeState: 'RISE',
          timestampMs: 1630000000000,
          sequentialId: '12345',
        );

        expect(riseTrade.changeState, 'RISE');
        expect(riseTrade.changePrice, 1000.0);
      });

      test('should handle FALL state', () {
        const fallTrade = Trade(
          market: 'KRW-BTC',
          price: 49000.0,
          volume: 1.0,
          side: 'ASK',
          changePrice: -1000.0,
          changeState: 'FALL',
          timestampMs: 1630000000000,
          sequentialId: '12345',
        );

        expect(fallTrade.changeState, 'FALL');
        expect(fallTrade.changePrice, -1000.0);
      });

      test('should handle EVEN state', () {
        const evenTrade = Trade(
          market: 'KRW-BTC',
          price: 50000.0,
          volume: 1.0,
          side: 'BID',
          changePrice: 0.0,
          changeState: 'EVEN',
          timestampMs: 1630000000000,
          sequentialId: '12345',
        );

        expect(evenTrade.changeState, 'EVEN');
        expect(evenTrade.changePrice, 0.0);
      });
    });

    group('different cryptocurrencies', () {
      test('should handle Bitcoin trades', () {
        const btcTrade = Trade(
          market: 'KRW-BTC',
          price: 50000000.0,
          volume: 0.1,
          side: 'BID',
          changePrice: 500000.0,
          changeState: 'RISE',
          timestampMs: 1630000000000,
          sequentialId: 'btc123',
        );

        expect(btcTrade.market, 'KRW-BTC');
        expect(btcTrade.total, 5000000.0);
        expect(btcTrade.isBuy, true);
      });

      test('should handle Ethereum trades', () {
        const ethTrade = Trade(
          market: 'KRW-ETH',
          price: 4000000.0,
          volume: 2.5,
          side: 'ASK',
          changePrice: -100000.0,
          changeState: 'FALL',
          timestampMs: 1630000000000,
          sequentialId: 'eth456',
        );

        expect(ethTrade.market, 'KRW-ETH');
        expect(ethTrade.total, 10000000.0);
        expect(ethTrade.isBuy, false);
      });

      test('should handle altcoin trades', () {
        const altTrade = Trade(
          market: 'KRW-ADA',
          price: 1500.0,
          volume: 1000.0,
          side: 'BID',
          changePrice: 50.0,
          changeState: 'RISE',
          timestampMs: 1630000000000,
          sequentialId: 'ada789',
        );

        expect(altTrade.market, 'KRW-ADA');
        expect(altTrade.total, 1500000.0);
        expect(altTrade.changePrice, 50.0);
      });
    });

    group('edge cases and validations', () {
      test('should handle very small decimal prices', () {
        const microTrade = Trade(
          market: 'KRW-DOGE',
          price: 0.123456789,
          volume: 10000.0,
          side: 'BID',
          changePrice: 0.001,
          changeState: 'RISE',
          timestampMs: 1630000000000,
          sequentialId: '12345',
        );

        expect(microTrade.price, 0.123456789);
        expect(microTrade.total, closeTo(1234.56789, 0.00001));
      });

      test('should handle very large volumes', () {
        const largeTrade = Trade(
          market: 'KRW-SHIB',
          price: 0.001,
          volume: 1000000000.0,
          side: 'ASK',
          changePrice: 0.0,
          changeState: 'EVEN',
          timestampMs: 1630000000000,
          sequentialId: '12345',
        );

        expect(largeTrade.volume, 1000000000.0);
        expect(largeTrade.total, 1000000.0);
      });

      test('should handle empty string market', () {
        const emptyMarketTrade = Trade(
          market: '',
          price: 50000.0,
          volume: 1.0,
          side: 'BID',
          changePrice: 0.0,
          changeState: 'EVEN',
          timestampMs: 1630000000000,
          sequentialId: '12345',
        );

        expect(emptyMarketTrade.market, '');
        expect(emptyMarketTrade.total, 50000.0);
      });

      test('should handle unusual side values', () {
        const unusualTrade = Trade(
          market: 'KRW-BTC',
          price: 50000.0,
          volume: 1.0,
          side: 'UNKNOWN',
          changePrice: 0.0,
          changeState: 'EVEN',
          timestampMs: 1630000000000,
          sequentialId: '12345',
        );

        expect(unusualTrade.side, 'UNKNOWN');
        expect(unusualTrade.isBuy, false); // BID가 아니므로 false
      });

      test('should handle negative prices (theoretical)', () {
        const negativeTrade = Trade(
          market: 'KRW-TEST',
          price: -1000.0,
          volume: 1.0,
          side: 'BID',
          changePrice: -100.0,
          changeState: 'FALL',
          timestampMs: 1630000000000,
          sequentialId: '12345',
        );

        expect(negativeTrade.price, -1000.0);
        expect(negativeTrade.total, -1000.0);
      });

      test('should handle future timestamps', () {
        const futureTrade = Trade(
          market: 'KRW-BTC',
          price: 50000.0,
          volume: 1.0,
          side: 'BID',
          changePrice: 0.0,
          changeState: 'EVEN',
          timestampMs: 2000000000000, // 2033년
          sequentialId: '12345',
        );

        expect(futureTrade.timestamp.year, 2033);
        expect(futureTrade.timestampMs, 2000000000000);
      });
    });

    group('business logic scenarios', () {
      test('should identify large trades by total value', () {
        const smallTrade = Trade(
          market: 'KRW-BTC',
          price: 50000000.0,
          volume: 0.0001, // 5천원
          side: 'BID',
          changePrice: 0.0,
          changeState: 'EVEN',
          timestampMs: 1630000000000,
          sequentialId: '1',
        );

        const largeTrade = Trade(
          market: 'KRW-BTC',
          price: 50000000.0,
          volume: 1.0, // 5천만원
          side: 'BID',
          changePrice: 0.0,
          changeState: 'EVEN',
          timestampMs: 1630000000000,
          sequentialId: '2',
        );

        expect(smallTrade.total < 10000, true); // 1만원 미만
        expect(largeTrade.total > 10000000, true); // 1천만원 초과
      });

      test('should compare trades by timestamp', () {
        const earlierTrade = Trade(
          market: 'KRW-BTC',
          price: 50000.0,
          volume: 1.0,
          side: 'BID',
          changePrice: 0.0,
          changeState: 'EVEN',
          timestampMs: 1630000000000,
          sequentialId: '1',
        );

        const laterTrade = Trade(
          market: 'KRW-BTC',
          price: 50000.0,
          volume: 1.0,
          side: 'BID',
          changePrice: 0.0,
          changeState: 'EVEN',
          timestampMs: 1630000001000,
          sequentialId: '2',
        );

        expect(earlierTrade.timestampMs < laterTrade.timestampMs, true);
        expect(earlierTrade.timestamp.isBefore(laterTrade.timestamp), true);
      });

      test('should handle trade aggregation scenarios', () {
        final trades = [
          const Trade(
            market: 'KRW-BTC',
            price: 50000000.0,
            volume: 0.1,
            side: 'BID',
            changePrice: 0.0,
            changeState: 'EVEN',
            timestampMs: 1630000000000,
            sequentialId: '1',
          ),
          const Trade(
            market: 'KRW-BTC',
            price: 50100000.0,
            volume: 0.2,
            side: 'BID',
            changePrice: 100000.0,
            changeState: 'RISE',
            timestampMs: 1630000001000,
            sequentialId: '2',
          ),
        ];

        final totalVolume = trades.fold(0.0, (sum, trade) => sum + trade.volume);
        final totalValue = trades.fold(0.0, (sum, trade) => sum + trade.total);

        expect(totalVolume, closeTo(0.3, 0.0001));
        expect(totalValue, closeTo(15020000.0, 0.01)); // 5000000 + 10020000
      });

      test('should filter trades by market', () {
        final trades = [
          const Trade(
            market: 'KRW-BTC',
            price: 50000000.0,
            volume: 1.0,
            side: 'BID',
            changePrice: 0.0,
            changeState: 'EVEN',
            timestampMs: 1630000000000,
            sequentialId: '1',
          ),
          const Trade(
            market: 'KRW-ETH',
            price: 4000000.0,
            volume: 1.0,
            side: 'BID',
            changePrice: 0.0,
            changeState: 'EVEN',
            timestampMs: 1630000000000,
            sequentialId: '2',
          ),
          const Trade(
            market: 'KRW-BTC',
            price: 50100000.0,
            volume: 0.5,
            side: 'ASK',
            changePrice: 100000.0,
            changeState: 'RISE',
            timestampMs: 1630000000000,
            sequentialId: '3',
          ),
        ];

        final btcTrades = trades.where((trade) => trade.market == 'KRW-BTC').toList();
        final ethTrades = trades.where((trade) => trade.market == 'KRW-ETH').toList();

        expect(btcTrades.length, 2);
        expect(ethTrades.length, 1);
        expect(btcTrades[0].market, 'KRW-BTC');
        expect(btcTrades[1].market, 'KRW-BTC');
        expect(ethTrades[0].market, 'KRW-ETH');
      });

      test('should filter trades by side', () {
        final trades = [
          const Trade(
            market: 'KRW-BTC',
            price: 50000000.0,
            volume: 1.0,
            side: 'BID',
            changePrice: 0.0,
            changeState: 'EVEN',
            timestampMs: 1630000000000,
            sequentialId: '1',
          ),
          const Trade(
            market: 'KRW-BTC',
            price: 50000000.0,
            volume: 0.5,
            side: 'ASK',
            changePrice: 0.0,
            changeState: 'EVEN',
            timestampMs: 1630000000000,
            sequentialId: '2',
          ),
          const Trade(
            market: 'KRW-BTC',
            price: 50000000.0,
            volume: 2.0,
            side: 'BID',
            changePrice: 0.0,
            changeState: 'EVEN',
            timestampMs: 1630000000000,
            sequentialId: '3',
          ),
        ];

        final buyTrades = trades.where((trade) => trade.isBuy).toList();
        final sellTrades = trades.where((trade) => !trade.isBuy).toList();

        expect(buyTrades.length, 2);
        expect(sellTrades.length, 1);
        expect(buyTrades.every((trade) => trade.side == 'BID'), true);
        expect(sellTrades.every((trade) => trade.side == 'ASK'), true);
      });

      test('should calculate weighted average price', () {
        final trades = [
          const Trade(
            market: 'KRW-BTC',
            price: 50000000.0,
            volume: 1.0,
            side: 'BID',
            changePrice: 0.0,
            changeState: 'EVEN',
            timestampMs: 1630000000000,
            sequentialId: '1',
          ),
          const Trade(
            market: 'KRW-BTC',
            price: 51000000.0,
            volume: 2.0,
            side: 'BID',
            changePrice: 1000000.0,
            changeState: 'RISE',
            timestampMs: 1630000001000,
            sequentialId: '2',
          ),
        ];

        final totalValue = trades.fold(0.0, (sum, trade) => sum + trade.total);
        final totalVolume = trades.fold(0.0, (sum, trade) => sum + trade.volume);
        final weightedAvgPrice = totalValue / totalVolume;

        expect(weightedAvgPrice, closeTo(50666666.67, 0.01)); // (50M + 102M) / 3
      });
    });
  });
}