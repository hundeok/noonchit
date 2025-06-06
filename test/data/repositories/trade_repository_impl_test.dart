// test/data/repositories/trade_repository_impl_test.dart
import 'dart:async';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart';
import 'package:noonchit/data/datasources/trade_cache_ds.dart';
import 'package:noonchit/data/datasources/trade_remote_ds.dart';
import 'package:noonchit/data/repositories/trade_repository_impl.dart';
import 'package:noonchit/domain/entities/trade.dart';

class MockTradeRemoteDataSource extends Mock implements TradeRemoteDataSource {}
class MockTradeCacheDataSource extends Mock implements TradeCacheDataSource {}

void main() {
  late TradeRepositoryImpl repository;
  late MockTradeRemoteDataSource mockRemote;
  late MockTradeCacheDataSource mockCache;

  setUpAll(() async {
    dotenv.testLoad(fileInput: '''
LOG_LEVEL=debug
DEBUG_MODE=true
    ''');
    registerFallbackValue(const Trade(
      market: 'KRW-BTC',
      price: 0.0,
      volume: 0.0,
      side: 'BID',
      changePrice: 0.0,
      changeState: 'EVEN',
      timestampMs: 0,
      sequentialId: '',
    ));
  });

  setUp(() {
    mockRemote = MockTradeRemoteDataSource();
    mockCache = MockTradeCacheDataSource();
    repository = TradeRepositoryImpl(mockRemote, mockCache);
    
    // 🔧 Remote DataSource만 dispose() 호출
    when(() => mockRemote.dispose()).thenAnswer((_) async => {});
    
    // 🗑️ Cache DataSource dispose() 제거 (HiveService가 Box 생명주기 관리)
    // when(() => mockCache.dispose()).thenAnswer((_) async => {});  // ← 제거됨
    
    when(() => mockCache.cacheTrade(any())).thenAnswer((_) async => {});
  });

  tearDown(() async {
    await repository.dispose();
  });

  group('TradeRepositoryImpl', () {
    const trade = Trade(
      market: 'KRW-BTC',
      price: 50000000.0, // 5천만원으로 설정 (필터 임계값 충족)
      volume: 2.5,
      side: 'BID',
      changePrice: 0.0,
      changeState: 'EVEN',
      timestampMs: 1630000000000,
      sequentialId: '12345',
    );

    test('watchTrades should stream raw trades', () async {
      final controller = StreamController<Trade>.broadcast();
      when(() => mockRemote.watch(['KRW-BTC'])).thenAnswer((_) => controller.stream);

      final stream = repository.watchTrades(['KRW-BTC']);
      controller.add(trade);

      final result = await stream.first;
      expect(result.market, trade.market);
      expect(result.price, trade.price);

      await controller.close();
    });

    test('watchTrades should initialize master stream only once', () async {
      final controller = StreamController<Trade>.broadcast();
      when(() => mockRemote.watch(any())).thenAnswer((_) => controller.stream);

      final stream1 = repository.watchTrades(['KRW-BTC']);
      final stream2 = repository.watchTrades(['KRW-ETH']);

      expect(identical(stream1, stream2), true);
      verify(() => mockRemote.watch(any())).called(1);

      await controller.close();
    });

    test('watchFilteredTrades should stream filtered trades', () async {
      final controller = StreamController<Trade>.broadcast();
      when(() => mockRemote.watch(['KRW-BTC'])).thenAnswer((_) => controller.stream);
      when(() => mockCache.cacheTrade(trade)).thenAnswer((_) async => {});

      final stream = repository.watchFilteredTrades(100000000, ['KRW-BTC']); // 1억원 임계값

      final tradesReceived = <List<Trade>>[];
      final subscription = stream.listen((trades) {
        tradesReceived.add(trades);
      });

      controller.add(trade);
      await Future.delayed(const Duration(milliseconds: 200));

      expect(tradesReceived.isNotEmpty, true);
      if (tradesReceived.isNotEmpty) {
        expect(tradesReceived.first, contains(trade));
      }
      verify(() => mockCache.cacheTrade(trade)).called(1);

      await subscription.cancel();
      await controller.close();
    });

    test('updateThreshold should trigger batch update', () async {
      final controller = StreamController<Trade>.broadcast();
      when(() => mockRemote.watch(['KRW-BTC'])).thenAnswer((_) => controller.stream);
      when(() => mockCache.cacheTrade(trade)).thenAnswer((_) async => {});

      final stream = repository.watchFilteredTrades(50000000, ['KRW-BTC']); // 5천만원 임계값

      final tradesReceived = <List<Trade>>[];
      final subscription = stream.listen((trades) {
        tradesReceived.add(trades);
      });

      controller.add(trade);
      await Future.delayed(const Duration(milliseconds: 200));

      // 임계값을 높여서 기존 거래가 필터링되도록 함
      repository.updateThreshold(200000000); // 2억원으로 상향
      await Future.delayed(const Duration(milliseconds: 200));

      expect(tradesReceived.length, greaterThanOrEqualTo(1));

      await subscription.cancel();
      await controller.close();
    });

    test('watchAggregatedTrades should stream aggregated trades', () async {
      final controller = StreamController<Trade>.broadcast();
      when(() => mockRemote.watch(any())).thenAnswer((_) => controller.stream);
      when(() => mockCache.cacheTrade(trade)).thenAnswer((_) async => {});

      final stream = repository.watchAggregatedTrades();

      final tradesReceived = <Trade>[];
      final subscription = stream.listen((trade) {
        tradesReceived.add(trade);
      });

      // 마스터 스트림 초기화를 위해 watchTrades 호출
      repository.watchTrades(['KRW-BTC']);
      
      controller.add(trade);
      await Future.delayed(const Duration(milliseconds: 200));

      expect(tradesReceived.isNotEmpty, true);

      await subscription.cancel();
      await controller.close();
    });

    test('should handle duplicate trades correctly', () async {
      final controller = StreamController<Trade>.broadcast();
      when(() => mockRemote.watch(['KRW-BTC'])).thenAnswer((_) => controller.stream);
      when(() => mockCache.cacheTrade(trade)).thenAnswer((_) async => {});

      final stream = repository.watchTrades(['KRW-BTC']);

      final tradesReceived = <Trade>[];
      final subscription = stream.listen((trade) {
        tradesReceived.add(trade);
      });

      // 같은 거래를 여러번 전송
      controller.add(trade);
      controller.add(trade);
      controller.add(trade);
      await Future.delayed(const Duration(milliseconds: 200));

      expect(tradesReceived.length, 3); // 스트림에서는 모두 받지만
      verify(() => mockCache.cacheTrade(trade)).called(1); // 캐시에는 한번만 저장

      await subscription.cancel();
      await controller.close();
    });

    test('should handle errors in trade processing gracefully', () async {
      final controller = StreamController<Trade>.broadcast();
      when(() => mockRemote.watch(['KRW-BTC'])).thenAnswer((_) => controller.stream);
      when(() => mockCache.cacheTrade(trade)).thenThrow(Exception('Cache error'));

      final stream = repository.watchTrades(['KRW-BTC']);

      final tradesReceived = <Trade>[];
      final subscription = stream.listen((trade) {
        tradesReceived.add(trade);
      });

      controller.add(trade);
      await Future.delayed(const Duration(milliseconds: 200));

      expect(tradesReceived.length, 1);
      verify(() => mockCache.cacheTrade(trade)).called(1);

      await subscription.cancel();
      await controller.close();
    });

    test('dispose should clean up all resources', () async {
      final controller = StreamController<Trade>.broadcast();
      when(() => mockRemote.watch(['KRW-BTC'])).thenAnswer((_) => controller.stream);

      final stream = repository.watchTrades(['KRW-BTC']);
      final subscription = stream.listen((_) {});

      await repository.dispose();

      // 🔧 Remote DataSource만 dispose() 검증
      verify(() => mockRemote.dispose()).called(1);
      
      // 🗑️ Cache DataSource dispose() 검증 제거 (HiveService가 Box 생명주기 관리)
      // verify(() => mockCache.dispose()).called(1);  // ← 제거됨

      await subscription.cancel();
      await controller.close();
    });
  });
}