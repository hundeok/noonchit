import 'package:dio/dio.dart';
import 'package:test/test.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart';
import 'package:noonchit/core/network/logging_interceptor.dart';

class _FakeRequestHandler extends RequestInterceptorHandler {
  bool called = false;

  @override
  void next(RequestOptions options) {
    called = true;
  }
}

class _FakeResponseHandler extends ResponseInterceptorHandler {
  bool called = false;
  Response? resp;

  @override
  void next(Response response) {
    called = true;
    resp = response;
  }
}

class _FakeErrorHandler extends ErrorInterceptorHandler {
  bool called = false;

  @override
  void next(DioException err) {
    called = true;
  }
}

void main() {
  setUpAll(() async {
    // 테스트용 환경변수 설정
    dotenv.testLoad(fileInput: '''
LOG_LEVEL=debug
DEBUG_MODE=true
    ''');
  });

  group('LoggingInterceptor', () {
    final interceptor = LoggingInterceptor();

    test('onRequest calls next', () {
      final opts = RequestOptions(path: '/');
      final h = _FakeRequestHandler();
      interceptor.onRequest(opts, h);
      expect(h.called, isTrue);
    });

    test('onResponse calls next', () {
      final opts = RequestOptions(path: '/');
      final resp = Response(requestOptions: opts, statusCode: 200, data: 'hello');
      final h = _FakeResponseHandler();
      interceptor.onResponse(resp, h);
      expect(h.called, isTrue);
      expect(h.resp, resp);
    });

    test('onError calls next', () {
      final opts = RequestOptions(path: '/');
      final dioErr = DioException(requestOptions: opts);
      final h = _FakeErrorHandler();
      interceptor.onError(dioErr, h);
      expect(h.called, isTrue);
    });
  });
}