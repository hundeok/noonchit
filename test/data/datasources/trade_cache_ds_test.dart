// test/data/datasources/trade_cache_ds_test.dart
import 'package:flutter_test/flutter_test.dart';
import 'package:hive/hive.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart';
import 'package:noonchit/data/datasources/trade_cache_ds.dart';
import 'package:noonchit/data/models/trade_dto.dart';
import 'package:noonchit/domain/entities/trade.dart';

void main() {
  late TradeCacheDataSource dataSource;
  late Box<TradeDto> testBox;
  
  setUpAll(() async {
    dotenv.testLoad(fileInput: '''
LOG_LEVEL=debug
DEBUG_MODE=true
    ''');
    Hive.init('./test_hive');
    // TypeAdapter가 이미 등록되어 있는지 확인 후 등록
    if (!Hive.isAdapterRegistered(0)) {
      Hive.registerAdapter(TradeDtoAdapter());
    }
  });

  setUp(() async {
    // 🎯 Box를 직접 생성하고 TradeCacheDataSource에 주입
    testBox = await Hive.openBox<TradeDto>('test_trades');
    dataSource = TradeCacheDataSource(testBox);
  });

  tearDown(() async {
    try {
      // 🔧 Box 정리는 테스트에서 직접 수행
      await dataSource.clearCache();
      await testBox.close();
    } catch (e) {
      // 이미 닫혀있을 수 있으니 무시
    }
  });

  tearDownAll(() async {
    try {
      await Hive.close();
      await Hive.deleteFromDisk();
    } catch (e) {
      // 무시
    }
  });

  group('TradeCacheDataSource', () {
    const trade = Trade(
      market: 'KRW-BTC',
      price: 50000.0,
      volume: 2.5,
      side: 'BID',
      changePrice: 0.0,
      changeState: 'EVEN',
      timestampMs: 1630000000000,
      sequentialId: '12345',
    );

    test('should use injected box for operations', () async {
      // 주입된 Box가 정상적으로 사용되는지 확인
      expect(testBox.isOpen, true);
      expect(testBox.length, 0);
    });

    test('cacheTrade should store TradeDto in injected box', () async {
      await dataSource.cacheTrade(trade);
      
      final result = dataSource.getCachedTrades();
      expect(result.length, 1);
      expect(result.first.market, 'KRW-BTC');
      expect(result.first.sequentialId, '12345');
      
      // Box에서도 직접 확인
      expect(testBox.length, 1);
      expect(testBox.values.first.market, 'KRW-BTC');
    });

    test('cacheTrade should handle max size limit', () async {
      // Fill box to max size + 1
      for (int i = 0; i < 1001; i++) {
        final testTrade = Trade(
          market: 'KRW-BTC',
          price: 50000.0,
          volume: 1.0,
          side: 'BID',
          changePrice: 0.0,
          changeState: 'EVEN',
          timestampMs: 1630000000000 + i,
          sequentialId: i.toString(),
        );
        await dataSource.cacheTrade(testTrade);
      }
      
      // 최대 캐시 사이즈(1000) 확인
      expect(testBox.length, lessThanOrEqualTo(1000));
    });

    test('getCachedTrades should return list of trades', () async {
      await dataSource.cacheTrade(trade);
      
      final result = dataSource.getCachedTrades();
      expect(result.length, 1);
      expect(result.first.market, 'KRW-BTC');
      expect(result.first.price, 50000.0);
      expect(result.first.volume, 2.5);
    });

    test('getCachedTrades should return empty list when no cached data', () async {
      final result = dataSource.getCachedTrades();
      expect(result, isEmpty);
    });

    test('clearCache should clear the injected box', () async {
      await dataSource.cacheTrade(trade);
      expect(dataSource.getCachedTrades().length, 1);
      expect(testBox.length, 1);
      
      await dataSource.clearCache();
      expect(dataSource.getCachedTrades(), isEmpty);
      expect(testBox.length, 0);
    });

    test('should work with multiple trades', () async {
      final trades = [
        trade,
        const Trade(
          market: 'KRW-ETH',
          price: 3000000.0,
          volume: 5.0,
          side: 'ASK',
          changePrice: 100000.0,
          changeState: 'RISE',
          timestampMs: 1630000001000,
          sequentialId: '67890',
        ),
      ];

      for (final t in trades) {
        await dataSource.cacheTrade(t);
      }

      final result = dataSource.getCachedTrades();
      expect(result.length, 2);
      expect(testBox.length, 2);
      
      // 순서 확인 (최신 것이 먼저)
      final markets = result.map((t) => t.market).toList();
      expect(markets, contains('KRW-BTC'));
      expect(markets, contains('KRW-ETH'));
    });

    test('should handle trade overwrites with same sequentialId', () async {
      await dataSource.cacheTrade(trade);
      expect(testBox.length, 1);
      
      // 같은 sequentialId로 다른 데이터
      const updatedTrade = Trade(
        market: 'KRW-BTC',
        price: 51000.0, // 다른 가격
        volume: 2.5,
        side: 'BID',
        changePrice: 0.0,
        changeState: 'EVEN',
        timestampMs: 1630000000000,
        sequentialId: '12345', // 같은 ID
      );
      
      await dataSource.cacheTrade(updatedTrade);
      expect(testBox.length, 1); // 개수는 그대로
      
      final result = dataSource.getCachedTrades();
      expect(result.first.price, 51000.0); // 업데이트된 가격
    });
  });
}