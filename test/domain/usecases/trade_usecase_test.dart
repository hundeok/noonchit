// test/domain/usecases/trade_usecase_test.dart
import 'dart:async';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart';
import 'package:noonchit/core/extensions/result.dart';
import 'package:noonchit/domain/entities/trade.dart';
import 'package:noonchit/domain/repositories/trade_repository.dart';
import 'package:noonchit/domain/usecases/trade_usecase.dart';

class MockTradeRepository extends Mock implements TradeRepository {}

void main() {
  late TradeUsecase usecase;
  late MockTradeRepository mockRepo;

  setUpAll(() async {
    dotenv.testLoad(fileInput: '''
LOG_LEVEL=debug
DEBUG_MODE=true
    ''');
  });

  setUp(() {
    mockRepo = MockTradeRepository();
    usecase = TradeUsecase(mockRepo);
  });

  group('TradeUsecase', () {
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

    test('filterTrades should stream Ok with trades', () async {
      final controller = StreamController<List<Trade>>();
      when(() => mockRepo.watchFilteredTrades(20000000, ['KRW-BTC']))
          .thenAnswer((_) => controller.stream);

      final stream = usecase.filterTrades(20000000, ['KRW-BTC']);
      controller.add([trade]);

      final result = await stream.first;
      expect(result, isA<Ok>());
      expect((result as Ok).value, [trade]);

      await controller.close();
    });

    test('filterTrades should stream Err on error', () async {
      when(() => mockRepo.watchFilteredTrades(20000000, ['KRW-BTC']))
          .thenAnswer((_) => Stream.error(Exception('Test error')));

      final stream = usecase.filterTrades(20000000, ['KRW-BTC']);
      final result = await stream.first;

      expect(result, isA<Err>());
      expect((result as Err).error.message, contains('Test error'));
    });

    test('filterTrades should handle multiple trades', () async {
      final controller = StreamController<List<Trade>>();
      when(() => mockRepo.watchFilteredTrades(20000000, ['KRW-BTC']))
          .thenAnswer((_) => controller.stream);

      final stream = usecase.filterTrades(20000000, ['KRW-BTC']);
      
      const trade2 = Trade(
        market: 'KRW-ETH',
        price: 30000.0,
        volume: 1.0,
        side: 'ASK',
        changePrice: 0.0,
        changeState: 'EVEN',
        timestampMs: 1630000001000,
        sequentialId: '67890',
      );
      
      controller.add([trade, trade2]);

      final result = await stream.first;
      expect(result, isA<Ok>());
      expect((result as Ok).value.length, 2);
      expect((result as Ok).value, contains(trade));
      expect((result as Ok).value, contains(trade2));

      await controller.close();
    });

    test('filterTrades should handle empty list', () async {
      final controller = StreamController<List<Trade>>();
      when(() => mockRepo.watchFilteredTrades(20000000, ['KRW-BTC']))
          .thenAnswer((_) => controller.stream);

      final stream = usecase.filterTrades(20000000, ['KRW-BTC']);
      controller.add(<Trade>[]);

      final result = await stream.first;
      expect(result, isA<Ok>());
      expect((result as Ok).value, isEmpty);

      await controller.close();
    });

    test('aggregateTrades should stream Ok with trade', () async {
      final controller = StreamController<Trade>();
      when(() => mockRepo.watchAggregatedTrades())
          .thenAnswer((_) => controller.stream);

      final stream = usecase.aggregateTrades();
      controller.add(trade);

      final result = await stream.first;
      expect(result, isA<Ok>());
      expect((result as Ok).value, trade);

      await controller.close();
    });

    test('aggregateTrades should stream Err on error', () async {
      when(() => mockRepo.watchAggregatedTrades())
          .thenAnswer((_) => Stream.error(Exception('Aggregate error')));

      final stream = usecase.aggregateTrades();
      final result = await stream.first;

      expect(result, isA<Err>());
      expect((result as Err).error.message, contains('Aggregate error'));
    });

    test('aggregateTrades should handle multiple trades in sequence', () async {
      final controller = StreamController<Trade>();
      when(() => mockRepo.watchAggregatedTrades())
          .thenAnswer((_) => controller.stream);

      final stream = usecase.aggregateTrades();
      final results = <Result<Trade, dynamic>>[];
      
      final subscription = stream.listen((result) {
        results.add(result);
      });
      
      controller.add(trade);
      await Future.delayed(const Duration(milliseconds: 50));
      
      expect(results.length, 1);
      expect(results[0], isA<Ok>());
      expect((results[0] as Ok).value, trade);

      const trade2 = Trade(
        market: 'KRW-ETH',
        price: 30000.0,
        volume: 1.0,
        side: 'ASK',
        changePrice: 0.0,
        changeState: 'EVEN',
        timestampMs: 1630000001000,
        sequentialId: '67890',
      );
      
      controller.add(trade2);
      await Future.delayed(const Duration(milliseconds: 50));
      
      expect(results.length, 2);
      expect(results[1], isA<Ok>());
      expect((results[1] as Ok).value, trade2);

      await subscription.cancel();
      await controller.close();
    });

    test('should handle repository method calls correctly', () async {
      final filterController = StreamController<List<Trade>>();
      final aggregateController = StreamController<Trade>();
      
      when(() => mockRepo.watchFilteredTrades(any(), any()))
          .thenAnswer((_) => filterController.stream);
      when(() => mockRepo.watchAggregatedTrades())
          .thenAnswer((_) => aggregateController.stream);

      // Test filter trades
      final filterStream = usecase.filterTrades(100000, ['KRW-BTC', 'KRW-ETH']);
      filterController.add([trade]);
      await filterStream.first;
      
      verify(() => mockRepo.watchFilteredTrades(100000, ['KRW-BTC', 'KRW-ETH'])).called(1);

      // Test aggregate trades
      final aggregateStream = usecase.aggregateTrades();
      aggregateController.add(trade);
      await aggregateStream.first;
      
      verify(() => mockRepo.watchAggregatedTrades()).called(1);

      await filterController.close();
      await aggregateController.close();
    });
  });
}