// lib/core/network/auth_interceptor.dart

import 'dart:convert';
import 'package:crypto/crypto.dart';
import 'package:dio/dio.dart';
import '../utils/logger.dart';

/// Upbit REST API 호출 시 JWT 방식의 인증 헤더를 붙여줍니다.
/// - payload에 access_key, nonce, (query_hash, query_hash_alg)을 포함해야 합니다.
/// - 알고리즘: HS256
class AuthInterceptor extends Interceptor {
  final String apiKey;
  final String apiSecret;

  AuthInterceptor({required this.apiKey, required this.apiSecret});

  @override
  void onRequest(RequestOptions options, RequestInterceptorHandler handler) {
    try {
      final nonce = DateTime.now().millisecondsSinceEpoch.toString();
      final payload = <String, dynamic>{
        'access_key': apiKey,
        'nonce': nonce,
      };

      if (options.queryParameters.isNotEmpty || _hasRequestBody(options)) {
        final raw = options.queryParameters.isNotEmpty
            ? Uri(queryParameters: options.queryParameters).query
            : jsonEncode(options.data);
        payload['query_hash'] = sha512.convert(utf8.encode(raw)).toString();
        payload['query_hash_alg'] = 'SHA512';
      }

      // JWT Header and Payload
      const headerMap = {'alg': 'HS256', 'typ': 'JWT'};
      final headerJson = jsonEncode(headerMap);
      final payloadJson = jsonEncode(payload);
      final headerSeg = _base64UrlEncode(headerJson);
      final payloadSeg = _base64UrlEncode(payloadJson);

      // Signature
      final sigBytes = Hmac(sha256, utf8.encode(apiSecret))
          .convert(utf8.encode('$headerSeg.$payloadSeg'))
          .bytes;
      final sigSeg = base64Url.encode(sigBytes).replaceAll('=', '');

      options.headers['Authorization'] =
          'Bearer $headerSeg.$payloadSeg.$sigSeg';
    } catch (e, st) {
      log.e('AuthInterceptor error', e, st);
      return handler.reject(
        DioException(requestOptions: options, error: e),
      );
    }

    handler.next(options);
  }

  bool _hasRequestBody(RequestOptions options) {
    final data = options.data;
    if (data == null) return false;
    if (data is String) return data.isNotEmpty;
    if (data is Iterable || data is Map) return data.isNotEmpty;
    if (data is FormData) return data.fields.isNotEmpty || data.files.isNotEmpty;
    return true;
  }

  String _base64UrlEncode(String input) =>
      base64Url.encode(utf8.encode(input)).replaceAll('=', '');
}
