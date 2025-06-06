import 'dart:convert';

import 'package:test/test.dart';
import 'package:noonchit/core/network/websocket/orderbook_ws_client.dart';
import 'package:noonchit/core/config/app_config.dart';

void main() {
  group('OrderbookWsClient', () {
    test('encodeSubscribe formats correctly and truncates', () {
      final client = OrderbookWsClient();
      final codes = ['A', 'B'];
      final jsonStr = client.encodeSubscribe(codes);
      final msg = jsonDecode(jsonStr) as List<dynamic>;
      expect(msg[1]['type'], 'orderbook');
      expect(List<String>.from(msg[1]['codes']), codes);

      final tooMany = List<String>.generate(
        AppConfig.wsMaxSubscriptionCount + 1,
        (i) => 'C$i',
      );
      final jsonStr2 = client.encodeSubscribe(tooMany);
      final msg2 = jsonDecode(jsonStr2) as List<dynamic>;
      expect((msg2[1]['codes'] as List).length, AppConfig.wsMaxSubscriptionCount);
    });

    test('decode wraps single and list JSON', () {
      final client = OrderbookWsClient();
      final single = jsonEncode({'o': 0});
      final out1 = client.decode(single);
      expect(out1.first, {'o': 0});

      final arr = jsonEncode([{'x': 5}, {'y': 6}]);
      final out2 = client.decode(arr);
      expect(out2.length, 2);
      expect(out2[1], {'y': 6});
    });
  });
}
