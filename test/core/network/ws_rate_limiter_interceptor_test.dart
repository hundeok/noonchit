import 'package:fake_async/fake_async.dart';
import 'package:test/test.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart';
import 'package:noonchit/core/network/ws_rate_limiter_interceptor.dart';

void main() {
  setUpAll(() async {
    // 테스트용 환경변수 설정
    dotenv.testLoad(fileInput: '''
LOG_LEVEL=debug
DEBUG_MODE=true
    ''');
  });

  test('WsRateLimiter respects minInterval', () {
    fakeAsync((async) {
      final sent = <int>[];
      final limiter = WsRateLimiter(minInterval: const Duration(milliseconds: 100));

      // 첫 번째 작업 실행
      limiter.enqueue(() => sent.add(1));

      // Future.delayed 처리를 위해 최소한의 시간 경과
      async.elapse(Duration.zero);
      async.flushMicrotasks();

      // 첫 번째 작업이 실행되었는지 확인
      expect(sent, [1], reason: 'First item should be executed immediately');

      // 두 번째 작업 큐에 추가
      limiter.enqueue(() => sent.add(2));

      // 최소 간격의 절반만 경과
      async.elapse(const Duration(milliseconds: 50));
      async.flushMicrotasks();

      // Rate limiter가 올바르게 동작하여 두 번째 작업이 지연되고 있음
      expect(sent, [1], reason: 'Second item should not be executed after 50ms due to rate limiting');

      // 나머지 간격을 경과
      async.elapse(const Duration(milliseconds: 50));
      async.flushMicrotasks();

      // 추가 작업이 있다면 확인
      expect(sent.length, greaterThanOrEqualTo(2), reason: 'At least two items should be processed');
    });
  });
}