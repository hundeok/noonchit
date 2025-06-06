import 'dart:async';
import 'package:test/test.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart';
import 'package:noonchit/core/network/websocket/ticker_ws_client.dart';

void main() {
  late TickerWsClient client;
  StreamSubscription? sub;

  setUpAll(() async {
    // 테스트용 환경변수 설정
    dotenv.testLoad(fileInput: '''
LOG_LEVEL=debug
DEBUG_MODE=true
    ''');
  });

  setUp(() {
    client = TickerWsClient();
  });

  tearDown(() async {
    // 리소스 정리 순서 개선
    try {
      // 1. 스트림 구독 먼저 취소
      if (sub != null) {
        await sub!.cancel();
        sub = null;
      }
      
      // 2. 클라이언트 정리
      await client.dispose();
      
      // 3. 추가 정리 대기 시간
      await Future.delayed(const Duration(milliseconds: 100));
    } catch (e) {
      // 정리 중 에러는 무시 (테스트 환경에서 발생할 수 있음)
      // ignore: avoid_print
      print('Cleanup error (ignored): $e');
    }
  });

  test('connect and receive at least one ticker update', () async {
    final completer = Completer<Map<String, dynamic>>();
    
    try {
      sub = client.stream.listen(
        (data) {
          if (data.isNotEmpty && !completer.isCompleted) {
            completer.complete(data.first);
          }
        },
        onError: (error) {
          if (!completer.isCompleted) {
            completer.completeError(error);
          }
        },
      );

      await client.connect(['KRW-BTC']);
      
      final ticker = await completer.future.timeout(
        const Duration(seconds: 10),
        onTimeout: () => throw TimeoutException('No ticker data received', const Duration(seconds: 10)),
      );
      
      expect(ticker.containsKey('trade_price'), isTrue);
    } catch (e) {
      // 테스트 실패 시에도 리소스 정리
      if (sub != null) {
        await sub!.cancel();
        sub = null;
      }
      await client.dispose();
      rethrow;
    }
  });
}