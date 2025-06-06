import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart';
import 'package:connectivity_plus_platform_interface/connectivity_plus_platform_interface.dart';
import 'package:noonchit/core/network/adaptive_backoff.dart';

/// Fake 구현체로 다양한 ConnectivityResult 시나리오를 강제할 수 있도록.
class FakeConnectivity extends ConnectivityPlatform {
  final ConnectivityResult _result;
  FakeConnectivity(this._result);

  @override
  Future<ConnectivityResult> checkConnectivity() async => _result;
}

void main() {
  late AdaptiveBackoffCalculator calc;
  late ConnectivityPlatform originalPlatform;

  setUpAll(() async {
    // Flutter 바인딩 초기화 (connectivity_plus 때문에 필요)
    TestWidgetsFlutterBinding.ensureInitialized();
    
    // 테스트용 환경변수 설정
    dotenv.testLoad(fileInput: '''
LOG_LEVEL=debug
DEBUG_MODE=true
    ''');
  });

  setUp(() {
    // 원래 구현체를 저장해 두었다가…
    originalPlatform = ConnectivityPlatform.instance;
    calc = AdaptiveBackoffCalculator();
  });

  tearDown(() {
    // 테스트 후에 복원!
    ConnectivityPlatform.instance = originalPlatform;
  });

  test('wifi multiplier reduces jitter range', () async {
    // wifi 환경이라 멀티플라이어=0.8 적용
    ConnectivityPlatform.instance = FakeConnectivity(ConnectivityResult.wifi);
    final d = await calc.calculateBackoff(
      0,
      const Duration(seconds: 1),
      const Duration(seconds: 10),
    );
    // 1000ms ~ 1000+160ms 사이
    expect(
      d.inMilliseconds,
      inInclusiveRange(1000, 1000 + 160),
      reason: 'should be between 1s and 1s+160ms',
    );
  });

  test('none connectivity multiplier increases jitter range', () async {
    // none 환경이라 멀티플라이어=2.0 적용
    ConnectivityPlatform.instance = FakeConnectivity(ConnectivityResult.none);
    final d = await calc.calculateBackoff(
      0,
      const Duration(seconds: 1),
      const Duration(seconds: 10),
    );
    // 1000ms ~ 1000+400ms 사이
    expect(
      d.inMilliseconds,
      inInclusiveRange(1000, 1000 + 400),
      reason: 'should be between 1s and 1s+400ms',
    );
  });

  test('consecutive failures increase backoff (penalty)', () async {
    // connectivity_plus 모킹 (기본값으로 wifi 설정)
    ConnectivityPlatform.instance = FakeConnectivity(ConnectivityResult.wifi);
    
    // 실패 전 백오프 (attempt=0)
    final first = await calc.calculateBackoff(
      0,
      const Duration(seconds: 1),
      const Duration(seconds: 10),
    );
    
    // 연속 실패 시뮬레이션
    calc.recordFailure();
    calc.recordFailure();
    
    // 실패 후 백오프 (attempt=1로 증가시켜서 테스트)
    final second = await calc.calculateBackoff(
      1, // attempt를 1로 설정하여 penalty 적용
      const Duration(seconds: 1),
      const Duration(seconds: 10),
    );
    
    // 두 번째가 첫 번째보다 커야 함 (penalty 적용)
    expect(
      second.inMilliseconds,
      greaterThan(first.inMilliseconds),
      reason: 'penalty should increase backoff time when attempt > 0',
    );
  });
}