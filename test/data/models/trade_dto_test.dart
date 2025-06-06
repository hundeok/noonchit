// test/data/models/trade_dto_test.dart
import 'dart:convert';
import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart';
import 'package:noonchit/data/models/trade_dto.dart';
import 'package:noonchit/domain/entities/trade.dart';

void main() {
  setUpAll(() async {
    dotenv.testLoad(fileInput: '''
LOG_LEVEL=debug
DEBUG_MODE=true
    ''');
  });

  group('TradeDto', () {
    final tradeDto = TradeDto(
      market: 'KRW-BTC',
      price: 50000.0,
      volume: 2.5,
      side: 'BID',
      changePrice: 100.0,
      changeState: 'RISE',
      timestampMs: 1630000000000,
      sequentialId: '12345',
    );

    test('toEntity should convert to Trade', () {
      final trade = tradeDto.toEntity();
      expect(trade, isA<Trade>());
      expect(trade.market, tradeDto.market);
      expect(trade.price, tradeDto.price);
      expect(trade.volume, tradeDto.volume);
      expect(trade.side, tradeDto.side);
      expect(trade.changePrice, tradeDto.changePrice);
      expect(trade.changeState, tradeDto.changeState);
      expect(trade.timestampMs, tradeDto.timestampMs);
      expect(trade.sequentialId, tradeDto.sequentialId);
    });

    test('toMap should return correct map', () {
      final map = tradeDto.toMap();
      expect(map['market'], tradeDto.market);
      expect(map['price'], tradeDto.price);
      expect(map['volume'], tradeDto.volume);
      expect(map['side'], tradeDto.side);
      expect(map['changePrice'], tradeDto.changePrice); // ← camelCase로 수정
      expect(map['changeState'], tradeDto.changeState); // ← camelCase로 수정
      expect(map['timestampMs'], tradeDto.timestampMs); // ← camelCase로 수정
      expect(map['sequentialId'], tradeDto.sequentialId); // ← camelCase로 수정
    });

    test('tryParse should parse valid JSON map with camelCase keys', () {
      final map = {
        'market': 'KRW-BTC',
        'price': 50000.0,
        'volume': 2.5,
        'side': 'BID',
        'changePrice': 100.0, // ← camelCase로 수정
        'changeState': 'RISE', // ← camelCase로 수정
        'timestampMs': 1630000000000, // ← camelCase로 수정
        'sequentialId': '12345', // ← camelCase로 수정
      };
      final dto = TradeDto.tryParse(map);
      expect(dto, isNotNull);
      expect(dto!.market, 'KRW-BTC');
      expect(dto.price, 50000.0);
      expect(dto.volume, 2.5);
      expect(dto.side, 'BID');
      expect(dto.changePrice, 100.0);
      expect(dto.changeState, 'RISE');
      expect(dto.timestampMs, 1630000000000);
      expect(dto.sequentialId, '12345');
    });

    test('tryParse should parse valid JSON map with snake_case keys', () {
      final map = {
        'market': 'KRW-BTC',
        'price': 50000.0,
        'volume': 2.5,
        'side': 'BID',
        'change_price': 100.0, // ← snake_case 키
        'change_state': 'RISE', // ← snake_case 키
        'timestamp_ms': 1630000000000, // ← snake_case 키
        'sequential_id': '12345', // ← snake_case 키
      };
      final dto = TradeDto.tryParse(map);
      expect(dto, isNotNull);
      expect(dto!.market, 'KRW-BTC');
      expect(dto.price, 50000.0);
      expect(dto.volume, 2.5);
      expect(dto.side, 'BID');
      expect(dto.changePrice, 100.0);
      expect(dto.changeState, 'RISE');
      expect(dto.timestampMs, 1630000000000);
      expect(dto.sequentialId, '12345');
    });

    test('tryParse should parse valid JSON map with alternative keys', () {
      final map = {
        'code': 'KRW-BTC', // ← alternative key
        'trade_price': 50000.0, // ← alternative key
        'trade_volume': 2.5, // ← alternative key
        'ask_bid': 'BID', // ← alternative key
        'timestamp': 1630000000000, // ← alternative key
        'sid': '12345', // ← alternative key
      };
      final dto = TradeDto.tryParse(map);
      expect(dto, isNotNull);
      expect(dto!.market, 'KRW-BTC');
      expect(dto.price, 50000.0);
      expect(dto.volume, 2.5);
      expect(dto.side, 'BID');
      expect(dto.changePrice, 0.0); // changePrice는 없으므로 기본값
      expect(dto.changeState, 'EVEN'); // changeState는 없으므로 기본값
      expect(dto.timestampMs, 1630000000000);
      expect(dto.sequentialId, '12345');
    });

    test('tryParse should handle empty map', () {
      final dto = TradeDto.tryParse({});
      expect(dto, isNull);
    });

    test('tryParse should handle invalid data types gracefully', () {
      final map = {
        'market': 'KRW-BTC',
        'price': 'invalid_price',
        'volume': null,
        'side': 123,
      };
      final dto = TradeDto.tryParse(map);
      expect(dto, isNotNull);
      expect(dto!.market, 'KRW-BTC');
      expect(dto.price, 0.0);
      expect(dto.volume, 0.0);
      expect(dto.side, '123');
      expect(dto.changePrice, 0.0);
      expect(dto.changeState, 'EVEN');
    });

    test('tryParse should handle parsing exception gracefully', () {
      final dto = TradeDto.tryParse({'invalid': 'data'});
      expect(dto, isNotNull);
      expect(dto!.market, 'UNKNOWN');
      expect(dto.price, 0.0);
      expect(dto.volume, 0.0);
      expect(dto.side, 'UNKNOWN');
      expect(dto.changePrice, 0.0);
      expect(dto.changeState, 'EVEN');
    });

    test('fromJson should parse valid JSON string', () {
      final json = jsonEncode(tradeDto.toMap());
      final dto = TradeDto.fromJson(json);
      expect(dto.market, tradeDto.market);
      expect(dto.price, tradeDto.price);
      expect(dto.volume, tradeDto.volume);
      expect(dto.side, tradeDto.side);
      expect(dto.changePrice, tradeDto.changePrice);
      expect(dto.changeState, tradeDto.changeState);
      expect(dto.timestampMs, tradeDto.timestampMs);
      expect(dto.sequentialId, tradeDto.sequentialId);
    });

    test('fromJson should handle invalid JSON with fallback', () {
      expect(
        () => TradeDto.fromJson('invalid json'),
        throwsA(isA<FormatException>()),
      );
    });

    test('toJson should return valid JSON string', () {
      final json = tradeDto.toJson();
      final decoded = jsonDecode(json);
      expect(decoded['market'], tradeDto.market);
      expect(decoded['price'], tradeDto.price);
      expect(decoded['volume'], tradeDto.volume);
      expect(decoded['side'], tradeDto.side);
      expect(decoded['changePrice'], tradeDto.changePrice); // ← camelCase로 수정
      expect(decoded['changeState'], tradeDto.changeState); // ← camelCase로 수정
      expect(decoded['timestampMs'], tradeDto.timestampMs); // ← camelCase로 수정
      expect(decoded['sequentialId'], tradeDto.sequentialId); // ← camelCase로 수정
    });

    test('tryParse should handle minimal data', () {
      final map = {
        'market': 'KRW-BTC',
        'price': 50000.0,
      };
      final dto = TradeDto.tryParse(map);
      expect(dto, isNotNull);
      expect(dto!.market, 'KRW-BTC');
      expect(dto.price, 50000.0);
      expect(dto.volume, 0.0);
      expect(dto.side, 'UNKNOWN');
    });

    test('tryParse should handle string numbers', () {
      final map = {
        'market': 'KRW-BTC',
        'price': '50000.5',
        'volume': '2.5',
        'timestampMs': '1630000000000', // ← camelCase로 수정
      };
      final dto = TradeDto.tryParse(map);
      expect(dto, isNotNull);
      expect(dto!.price, 50000.5);
      expect(dto.volume, 2.5);
      expect(dto.timestampMs, 1630000000000);
    });

    test('tryParse should handle mixed key formats in same map', () {
      final map = {
        'market': 'KRW-BTC',
        'trade_price': 50000.0,
        'volume': 2.5,
        'ask_bid': 'BID',
        'timestampMs': 1630000000000, // ← camelCase 키
      };
      final dto = TradeDto.tryParse(map);
      expect(dto, isNotNull);
      expect(dto!.market, 'KRW-BTC');
      expect(dto.price, 50000.0);
      expect(dto.volume, 2.5);
      expect(dto.side, 'BID');
      expect(dto.timestampMs, 1630000000000);
    });

    test('tryParse should support all timestamp key formats', () {
      // timestampMs 키
      final mapWithTimestampMs = {
        'market': 'KRW-BTC',
        'price': 50000.0,
        'timestampMs': 1630000000000,
      };
      final dto1 = TradeDto.tryParse(mapWithTimestampMs);
      expect(dto1, isNotNull);
      expect(dto1!.timestampMs, 1630000000000);

      // timestamp_ms 키
      final mapWithSnakeCaseTimestamp = {
        'market': 'KRW-BTC',
        'price': 50000.0,
        'timestamp_ms': 1630000000000,
      };
      final dto2 = TradeDto.tryParse(mapWithSnakeCaseTimestamp);
      expect(dto2, isNotNull);
      expect(dto2!.timestampMs, 1630000000000);

      // timestamp 키
      final mapWithTimestamp = {
        'market': 'KRW-BTC',
        'price': 50000.0,
        'timestamp': 1630000000000,
      };
      final dto3 = TradeDto.tryParse(mapWithTimestamp);
      expect(dto3, isNotNull);
      expect(dto3!.timestampMs, 1630000000000);
    });
  });
}