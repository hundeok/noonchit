import 'dart:convert';

import 'package:test/test.dart';
import 'package:noonchit/core/network/websocket/ticker_ws_client.dart';
import 'package:noonchit/core/config/app_config.dart';

void main() {
  group('TickerWsClient', () {
    test('encodeSubscribe formats correctly and truncates', () {
      final client = TickerWsClient();
      final codes = ['ONE', 'TWO'];
      final jsonStr = client.encodeSubscribe(codes);
      final msg = jsonDecode(jsonStr) as List<dynamic>;
      expect(msg[1]['type'], 'ticker');
      expect(List<String>.from(msg[1]['codes']), codes);

      final tooMany = List<String>.generate(
        AppConfig.wsMaxSubscriptionCount + 5,
        (i) => 'C$i',
      );
      final jsonStr2 = client.encodeSubscribe(tooMany);
      final msg2 = jsonDecode(jsonStr2) as List<dynamic>;
      expect((msg2[1]['codes'] as List).length, AppConfig.wsMaxSubscriptionCount);
    });

    test('decode wraps single and list JSON', () {
      final client = TickerWsClient();
      final single = jsonEncode({'t': 'val'});
      final out1 = client.decode(single);
      expect(out1.first, {'t': 'val'});

      final arr = jsonEncode([{'a': 1}, {'b': 2}]);
      final out2 = client.decode(arr);
      expect(out2.length, 2);
    });
  });
}
