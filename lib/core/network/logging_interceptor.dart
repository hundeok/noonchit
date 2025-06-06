// lib/core/network/logging_interceptor.dart

import 'dart:convert';
import 'package:dio/dio.dart';
import '../utils/logger.dart';

/// 모든 REST 요청과 응답, 오류를 로깅합니다.
/// 🔒 보안: access_key, signature 등 민감 정보 자동 마스킹
class LoggingInterceptor extends Interceptor {
  @override
  void onRequest(RequestOptions options, RequestInterceptorHandler handler) {
    // 🔒 URL 보안 마스킹
    final secureUri = _sanitizeUri(options.uri);
    log.i('--> ${options.method} $secureUri');
    
    // 🔒 헤더 보안 마스킹 (Authorization 헤더)
    if (options.headers.containsKey('Authorization')) {
      log.d('Headers: Authorization: Bearer ***[MASKED]***');
    }
    
    if (options.data != null && options.data is! String) {
      try {
        final sanitizedData = _sanitizeRequestData(options.data);
        log.d('Request Data:\n${const JsonEncoder.withIndent('  ').convert(sanitizedData)}');
      } catch (e, st) {
        log.d('Request Data serialization failed', e, st);
      }
    }
    handler.next(options);
  }

  @override
  void onResponse(Response response, ResponseInterceptorHandler handler) {
    // 🔒 URL 보안 마스킹
    final secureUri = _sanitizeUri(response.requestOptions.uri);
    log.i('<-- ${response.statusCode} $secureUri');
    
    final text = response.data is String
        ? response.data as String
        : response.data.toString();
    if (text.isNotEmpty) {
      log.d(text.length > 500 ? '${text.substring(0, 500)}...' : text);
    }
    handler.next(response);
  }

  @override
  void onError(DioException err, ErrorInterceptorHandler handler) {
    // 🔒 URL 보안 마스킹
    final secureUri = _sanitizeUri(err.requestOptions.uri);
    log.e('<-- Error ${err.response?.statusCode} $secureUri', err, err.stackTrace);
    handler.next(err);
  }

  /// 🔒 URI에서 민감 정보 마스킹
  String _sanitizeUri(Uri uri) {
    final uriString = uri.toString();
    return uriString
        .replaceAll(RegExp(r'access_key=[^&?#]+'), 'access_key=***')
        .replaceAll(RegExp(r'signature=[^&?#]+'), 'signature=***')
        .replaceAll(RegExp(r'nonce=[^&?#]+'), 'nonce=***')
        .replaceAll(RegExp(r'api_key=[^&?#]+'), 'api_key=***')
        .replaceAll(RegExp(r'secret=[^&?#]+'), 'secret=***');
  }

  /// 🔒 요청 데이터에서 민감 정보 마스킹
  dynamic _sanitizeRequestData(dynamic data) {
    if (data is Map<String, dynamic>) {
      final sanitized = <String, dynamic>{};
      for (final entry in data.entries) {
        final key = entry.key.toLowerCase();
        if (_isSensitiveKey(key)) {
          sanitized[entry.key] = '***[MASKED]***';
        } else {
          sanitized[entry.key] = _sanitizeRequestData(entry.value);
        }
      }
      return sanitized;
    } else if (data is List) {
      return data.map((item) => _sanitizeRequestData(item)).toList();
    }
    return data;
  }

  /// 🔒 민감한 키 판별
  bool _isSensitiveKey(String key) {
    const sensitiveKeys = {
      'access_key', 'accesskey', 'api_key', 'apikey',
      'secret', 'signature', 'nonce', 'password', 
      'token', 'auth', 'authorization'
    };
    return sensitiveKeys.contains(key);
  }
}