import 'dart:convert';

import 'package:dio/dio.dart';
import 'package:test/test.dart';
import 'package:noonchit/core/network/auth_interceptor.dart';

class _FakeHandler extends RequestInterceptorHandler {
  RequestOptions? opts;
  @override
  void next(RequestOptions options) {
    opts = options;
  }
}

void main() {
  group('AuthInterceptor', () {
    late AuthInterceptor interceptor;
    late RequestOptions options;
    late _FakeHandler handler;

    setUp(() {
      interceptor = AuthInterceptor(apiKey: 'myKey', apiSecret: 'mySecret');
      options = RequestOptions(path: '/x', method: 'POST')
        ..queryParameters.addAll({'a': '1'})
        ..data = {'b': '2'};
      handler = _FakeHandler();
    });

    test('adds Authorization header with JWT', () {
      interceptor.onRequest(options, handler);
      final opts = handler.opts!;
      final auth = opts.headers['Authorization'] as String;
      expect(auth.startsWith('Bearer '), isTrue);
      final token = auth.substring(7);
      final parts = token.split('.');
      expect(parts, hasLength(3));

      // verify payload contains access_key and nonce
      final payload = parts[1];
      final decoded = utf8.decode(base64Url.decode(base64Url.normalize(payload)));
      expect(decoded.contains('myKey'), isTrue);
      expect(decoded.contains('nonce'), isTrue);
      expect(decoded.contains('query_hash'), isTrue);
      expect(decoded.contains('SHA512'), isTrue);
    });

    test('does not fail when no query or body', () {
      options = RequestOptions(path: '/y', method: 'GET');
      handler = _FakeHandler();
      interceptor.onRequest(options, handler);
      expect(handler.opts!, isNotNull);
      expect(handler.opts!.headers.containsKey('Authorization'), isTrue);
    });
  });
}