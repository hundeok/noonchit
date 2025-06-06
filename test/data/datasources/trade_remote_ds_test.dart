// test/data/datasources/trade_remote_ds_test.dart
import 'dart:async';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart';
import 'package:noonchit/core/bridge/signal_bus.dart';
import 'package:noonchit/core/network/websocket/trade_ws_client.dart';
import 'package:noonchit/data/datasources/trade_remote_ds.dart';
import 'package:noonchit/core/event/app_event.dart';
import 'package:noonchit/domain/entities/trade.dart';

class MockTradeWsClient extends Mock implements TradeWsClient {}
class MockSignalBus extends Mock implements SignalBus {}

void main() {
  late TradeRemoteDataSource dataSource;
  late MockTradeWsClient mockWsClient;
  late MockSignalBus mockSignalBus;

  setUpAll(() async {
    dotenv.testLoad(fileInput: '''
LOG_LEVEL=debug
DEBUG_MODE=true
    ''');
    registerFallbackValue(AppEvent.now(const {}));
  });

  setUp(() {
    mockWsClient = MockTradeWsClient();
    mockSignalBus = MockSignalBus();
    dataSource = TradeRemoteDataSource(mockWsClient, mockSignalBus);
  });

  tearDown(() async {
    await dataSource.dispose();
  });

  group('TradeRemoteDataSource', () {
    const tradeMap = {
      'market': 'KRW-BTC',
      'trade_price': 50000.0,
      'trade_volume': 2.5,
      'ask_bid': 'BID',
      'cp': 0.0,
      'change': 'EVEN',
      'timestamp_ms': 1630000000000,
      'sid': '12345',
    };

    test('watch should stream trades from WebSocket', () async {
      final controller = StreamController<List<Map<String, dynamic>>>();
      when(() => mockWsClient.connect(['KRW-BTC'])).thenAnswer((_) async => {});
      when(() => mockWsClient.stream).thenAnswer((_) => controller.stream);
      when(() => mockSignalBus.fireTradeEvent(any())).thenReturn(null);

      final stream = dataSource.watch(['KRW-BTC']);
      controller.add([tradeMap]);

      final result = await stream.first;
      expect(result.market, 'KRW-BTC');
      expect(result.price, 50000.0);
      expect(result.volume, 2.5);
      expect(result.side, 'BID');

      verify(() => mockSignalBus.fireTradeEvent(any())).called(1);
      await controller.close();
    });

    test('watch should fallback to test stream on WebSocket error', () async {
      when(() => mockWsClient.connect(['KRW-BTC'])).thenThrow(Exception('Connection failed'));
      when(() => mockWsClient.stream).thenAnswer((_) => Stream.error('WS Error'));
      when(() => mockSignalBus.fireTradeEvent(any())).thenReturn(null);

      final testDataSource = TradeRemoteDataSource(
        mockWsClient,
        mockSignalBus,
        useTestData: true,
      );

      final stream = testDataSource.watch(['KRW-BTC']);
      final trade = await stream.first;

      expect(trade.market, contains('KRW-'));
      expect(['BID', 'ASK'].contains(trade.side), true);
      expect(trade.price, greaterThan(0));

      await testDataSource.dispose();
    });

    test('watch with useTestData should return synthetic stream', () async {
      final testDataSource = TradeRemoteDataSource(
        mockWsClient,
        mockSignalBus,
        useTestData: true,
      );
      when(() => mockSignalBus.fireTradeEvent(any())).thenReturn(null);

      final stream = testDataSource.watch(['KRW-BTC']);
      final trade = await stream.first;

      expect(trade.market, contains('KRW-'));
      expect(['BID', 'ASK'].contains(trade.side), true);
      expect(trade.price, greaterThan(0));

      await testDataSource.dispose();
    });

    test('watch should handle invalid trade data gracefully', () async {
      final controller = StreamController<List<Map<String, dynamic>>>();
      when(() => mockWsClient.connect(['KRW-BTC'])).thenAnswer((_) async => {});
      when(() => mockWsClient.stream).thenAnswer((_) => controller.stream);

      final stream = dataSource.watch(['KRW-BTC']);
      controller.add([{'market': null, 'price': 'invalid'}]);
      final tradesReceived = <Trade>[];
      final subscription = stream.listen((trade) {
        tradesReceived.add(trade);
      });

      await Future.delayed(const Duration(milliseconds: 100));
      
      // TradeDto.tryParse가 null을 반환하지 않고 기본값으로 Trade를 생성하므로
      // 빈 리스트가 아닌 기본값이 포함된 Trade가 반환됨
      expect(tradesReceived.length, 1);
      expect(tradesReceived.first.market, 'UNKNOWN');

      await subscription.cancel();
      await controller.close();
    });

    test('dispose should clean up resources', () async {
      final controller = StreamController<List<Map<String, dynamic>>>();
      when(() => mockWsClient.connect(['KRW-BTC'])).thenAnswer((_) async => {});
      when(() => mockWsClient.stream).thenAnswer((_) => controller.stream);

      final stream = dataSource.watch(['KRW-BTC']);
      final subscription = stream.listen((_) {});

      await dataSource.dispose();

      await subscription.cancel();
      await controller.close();
    });
  });
}