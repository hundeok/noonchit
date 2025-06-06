import 'package:dio/dio.dart';
import 'package:mocktail/mocktail.dart';
import 'package:test/test.dart';
import 'package:noonchit/core/network/api_client.dart';
import 'package:noonchit/core/error/app_exception.dart';

// Dio 모킹 클래스
class MockDio extends Mock implements Dio {}

void main() {
  group('ApiClient', () {
    late MockDio mockDio;
    late ApiClient client;

    setUp(() {
      mockDio = MockDio();
      // Mock interceptors to avoid TypeError
      when(() => mockDio.interceptors).thenReturn(Interceptors());
      // Dio.request 모킹 설정
      when(() => mockDio.request<Map<String, String>>(
            any(),
            queryParameters: any(named: 'queryParameters'),
            data: any(named: 'data'),
            options: any(named: 'options'),
          )).thenAnswer((_) async => Response(
            data: {'foo': 'bar'},
            statusCode: 200,
            requestOptions: RequestOptions(path: ''),
          ));
      // ignore: prefer_const_constructors
      client = ApiClient(
        dio: mockDio,
        apiKey: 'key',
        apiSecret: 'secret',
      );
    });

    test('request without cache calls Dio every time', () async {
      final r1 = await client.request<Map<String, String>>(
        method: 'GET',
        path: '/test',
      );
      final r2 = await client.request<Map<String, String>>(
        method: 'GET',
        path: '/test',
      );
      expect(r1.valueOrNull, {'foo': 'bar'});
      expect(r2.valueOrNull, {'foo': 'bar'});
      verify(() => mockDio.request<Map<String, String>>(
            any(),
            options: any(named: 'options'),
          )).called(2);
    });

    test('request with cacheDur caches result', () async {
      const cacheDur = Duration(seconds: 1);
      final r1 = await client.request<Map<String, String>>(
        method: 'GET',
        path: '/test',
        cacheDur: cacheDur,
      );
      final r2 = await client.request<Map<String, String>>(
        method: 'GET',
        path: '/test',
        cacheDur: cacheDur,
      );
      expect(r2.valueOrNull, r1.valueOrNull);
      verify(() => mockDio.request<Map<String, String>>(
            any(),
            options: any(named: 'options'),
          )).called(1);
    });

    test('stable query string sorts keys', () async {
      const cacheDur = Duration(seconds: 1);
      final r1 = await client.request<Map<String, String>>(
        method: 'GET',
        path: '/q',
        query: {'b': '2', 'a': '1'},
        cacheDur: cacheDur,
      );
      final r2 = await client.request<Map<String, String>>(
        method: 'GET',
        path: '/q',
        query: {'a': '1', 'b': '2'},
        cacheDur: cacheDur,
      );
      expect(r2.valueOrNull, r1.valueOrNull);
      verify(() => mockDio.request<Map<String, String>>(
            any(),
            queryParameters: any(named: 'queryParameters'),
            options: any(named: 'options'),
          )).called(1);
    });

    test('network error returns Err(NetworkException)', () async {
      // Dio.request 모킹: 에러 반환
      when(() => mockDio.request<Map<String, String>>(
            any(),
            queryParameters: any(named: 'queryParameters'),
            data: any(named: 'data'),
            options: any(named: 'options'),
          )).thenThrow(DioException(
            requestOptions: RequestOptions(path: '/err'),
            error: 'network failure',
          ));

      final res = await client.request<Map<String, String>>(
        method: 'GET',
        path: '/err',
      );
      expect(res.isErr, isTrue);
      final err = res.errorOrNull;
      expect(err, isA<NetworkException>());
      expect(err!.message, contains('network failure'));
      verify(() => mockDio.request<Map<String, String>>(
            any(),
            options: any(named: 'options'),
          )).called(1);
    });
  });
}