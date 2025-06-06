// test/core/error/app_exception_test.dart

import 'package:dio/dio.dart';
import 'package:test/test.dart';
import 'package:noonchit/core/error/app_exception.dart';

void main() {
  group('AppException hierarchy', () {
    test('AppException.toString includes message and optional fields', () {
      const ex = AppException('msg', code: 'C', statusCode: 123);
      final str = ex.toString();
      expect(str, contains('code: C'));
      expect(str, contains('status: 123'));
      expect(str, contains('message: msg'));
    });

    test('NetworkException.fromDio maps fields correctly', () {
      final req = RequestOptions(path: '/');
      final resp = Response(requestOptions: req, statusCode: 429, statusMessage: 'Too Many');
      final dioErr = DioException(requestOptions: req, response: resp, error: 'err');
      final netEx = NetworkException.fromDio(dioErr);

      expect(netEx, isA<NetworkException>());
      expect(netEx.message, isNotEmpty);
      expect(netEx.code, 'Too Many');
      expect(netEx.statusCode, 429);
      expect(netEx.originalException, dioErr);
    });

    test('RateLimitException.toString formats correctly', () {
      const ex = RateLimitException('limit', retryAfter: Duration(seconds: 5));
      final str = ex.toString();
      expect(str, 'RateLimitException(retryAfter: 5s, message: limit)');
    });

    test('DataParsingException and CacheMissException work', () {
      const dp = DataParsingException('parse error');
      expect(dp.message, 'parse error');

      const cm = CacheMissException();
      expect(cm.message, 'Cache miss');
    });

    test('Domain exceptions extend AppException', () {
      const te = TradeException('trade bad');
      expect(te, isA<AppException>());

      const oe = OrderBookException('order bad');
      expect(oe, isA<AppException>());

      const ce = CandleException('candle bad');
      expect(ce, isA<DataParsingException>());

      const ti = TickerException('ticker bad');
      expect(ti, isA<DataParsingException>());
    });
  });
}
