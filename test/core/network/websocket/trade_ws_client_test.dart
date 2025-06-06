import 'dart:convert';

import 'package:test/test.dart';
import 'package:noonchit/core/network/websocket/trade_ws_client.dart';
import 'package:noonchit/core/config/app_config.dart';

void main() {
  group('TradeWsClient', () {
    test('encodeSubscribe formats correctly and truncates', () {
      final client = TradeWsClient();
      final codes = ['X1', 'X2'];
      final jsonStr = client.encodeSubscribe(codes);
      final msg = jsonDecode(jsonStr) as List<dynamic>;
      expect(msg[1]['type'], 'trade');
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
      final client = TradeWsClient();
      final single = jsonEncode({'k': 123});
      final out1 = client.decode(single);
      expect(out1.first, {'k': 123});

      final arr = jsonEncode([{'m': 5}, {'n': 6}]);
      final out2 = client.decode(arr);
      expect(out2, hasLength(2));
      expect(out2[1], {'n': 6});
    });
  });
}
