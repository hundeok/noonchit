import 'package:dio/dio.dart';
import 'package:mocktail/mocktail.dart';
import 'package:test/test.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart';
import 'package:noonchit/core/network/retry_interceptor.dart';

// Dio 모킹 클래스
class MockDio extends Mock implements Dio {}

class _FakeErrorHandler extends ErrorInterceptorHandler {
  Response? resolved;
  DioException? forwarded;

  @override
  void resolve(Response response) {
    resolved = response;
  }

  @override
  void next(DioException err) {
    forwarded = err;
  }
}

void main() {
  setUpAll(() async {
    // 테스트용 환경변수 설정
    dotenv.testLoad(fileInput: '''
LOG_LEVEL=debug
DEBUG_MODE=true
    ''');
    registerFallbackValue(RequestOptions(path: ''));
  });

  group('RetryInterceptor', () {
    late MockDio mockDio;
    late RetryInterceptor interceptor;
    late RequestOptions options;
    late _FakeErrorHandler handler;

    setUp(() {
      mockDio = MockDio();
      when(() => mockDio.interceptors).thenReturn(Interceptors());
      options = RequestOptions(path: '/p', method: 'GET');

      // 모의 객체 설정 - 명시적인 성공 응답 생성
      final mockResponse = Response(
        data: 'ok',
        statusCode: 200,
        requestOptions: options,
      );

      // 명확한 응답 반환 설정
      when(() => mockDio.fetch(any())).thenAnswer((_) async => mockResponse);

      interceptor = RetryInterceptor(
        dio: mockDio,
        maxRetries: 2,
        initialBackoff: Duration.zero, // 테스트 속도를 위해 대기 시간 없음
        maxBackoff: Duration.zero,
      );
      handler = _FakeErrorHandler();
    });

    test('retries on 429 and resolves', () async {
      // 429 응답으로 DioException 생성
      final resp = Response(
        requestOptions: options,
        statusCode: 429,
        statusMessage: 'Too Many'
      );
      final dioErr = DioException(
        requestOptions: options,
        response: resp,
        type: DioExceptionType.badResponse,
      );

      // 인터셉터 실행 - 비동기 호출이므로 await 사용
      await interceptor.onError(dioErr, handler);

      // 검증
      expect(handler.resolved, isNotNull, reason: 'Response should be resolved, not null');
      if (handler.resolved == null) {
        // 디버깅용 추가 검증
        verify(() => mockDio.fetch(any())).called(1);
      } else {
        expect(handler.resolved!.data, equals('ok'));
        verify(() => mockDio.fetch(any())).called(1);
      }
    });

    test('does not retry on non-5xx/429', () async {
      final resp = Response(requestOptions: options, statusCode: 400, statusMessage: 'Bad');
      final dioErr = DioException(
        requestOptions: options,
        response: resp,
        type: DioExceptionType.badResponse,
      );

      await interceptor.onError(dioErr, handler);

      expect(handler.forwarded, isNotNull);
      expect(handler.forwarded!.response?.statusCode, 400);
      verifyNever(() => mockDio.fetch(any()));
    });
  });
}