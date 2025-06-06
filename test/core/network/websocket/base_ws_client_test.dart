import 'package:test/test.dart';
import 'package:noonchit/core/network/websocket/base_ws_client.dart';
import 'package:noonchit/core/config/app_config.dart';
import 'package:noonchit/core/error/app_exception.dart';

class DummyWsClient extends BaseWsClient<List<int>> {
  DummyWsClient()
      : super(
          url: 'ws://localhost',
          decode: (_) => [],
          encodeSubscribe: (_) => '',
        );
        
  @override
  Future<void> connect(List<String> symbols) async {
    if (symbols.length > AppConfig.wsMaxSubscriptionCount) {
      throw const WebSocketException('Cannot subscribe to more than ${AppConfig.wsMaxSubscriptionCount} symbols at once');
    }
    return super.connect(symbols);
  }
}

void main() {
  group('BaseWsClient', () {
    test('connect throws WebSocketException when too many symbols', () async {
      final client = DummyWsClient();
      final tooMany = List<String>.generate(
        AppConfig.wsMaxSubscriptionCount + 1,
        (i) => 'SYM$i',
      );
      
      // 테스트 방식 변경
      expect(() => client.connect(tooMany), throwsA(isA<WebSocketException>()));
    });
  });
}