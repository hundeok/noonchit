import 'dart:convert';

import 'package:test/test.dart';
import 'package:noonchit/core/network/websocket/candle_ws_client.dart';
import 'package:noonchit/core/config/app_config.dart';

void main() {
  group('CandleWsClient', () {
    test('encodeSubscribe formats correctly with <= max codes', () {
      final client = CandleWsClient(timeFrame: '5m');
      final codes = ['A', 'B', 'C'];
      final jsonStr = client.encodeSubscribe(codes);
      final msg = jsonDecode(jsonStr) as List<dynamic>;
      expect(msg[1]['type'], 'candles_5m');
      expect(List<String>.from(msg[1]['codes']), codes);
    });

    test('encodeSubscribe truncates codes to wsMaxSubscriptionCount', () {
      final client = CandleWsClient(timeFrame: '1m');
      final tooMany = List<String>.generate(
        AppConfig.wsMaxSubscriptionCount + 10,
        (i) => 'C$i',
      );
      final jsonStr = client.encodeSubscribe(tooMany);
      final msg = jsonDecode(jsonStr) as List<dynamic>;
      expect((msg[1]['codes'] as List).length, AppConfig.wsMaxSubscriptionCount);
    });

    test('decode parses single object and list', () {
      final client = CandleWsClient(timeFrame: '15m');
      // single
      final raw1 = jsonEncode({'x': 42});
      final out1 = client.decode(raw1);
      expect(out1, isA<List<Map<String, dynamic>>>());
      expect(out1.first, {'x': 42});
      // list
      final raw2 = jsonEncode([{'a': 1}, {'b': 2}]);
      final out2 = client.decode(raw2);
      expect(out2.length, 2);
      expect(out2[0], {'a': 1});
      expect(out2[1], {'b': 2});
    });
  });
}
