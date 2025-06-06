// lib/core/error/app_exception.dart

import 'package:dio/dio.dart';

/// 최상위 앱 예외
/// - 모든 커스텀 예외는 이 클래스를 상속해주세요.
class AppException implements Exception {
  /// 사용자에게 노출할 메시지
  final String message;

  /// 내부 로깅 또는 식별용 코드 (nullable)
  final String? code;

  /// HTTP 상태 코드 등 추가 상태 정보
  final int? statusCode;

  /// 원본 예외(있는 경우)
  final Exception? originalException;

  const AppException(
    this.message, {
    this.code,
    this.statusCode,
    this.originalException,
  });

  @override
  String toString() {
    final parts = <String>[];
    if (code != null) parts.add('code: $code');
    if (statusCode != null) parts.add('status: $statusCode');
    parts.add('message: $message');
    return 'AppException(${parts.join(', ')})';
  }
}

/// REST/HTTP 호출 중 발생한 예외
class NetworkException extends AppException {
  const NetworkException(
    String message, {
    String? code,
    int? statusCode,
    Exception? originalException,
  }) : super(
          message,
          code: code,
          statusCode: statusCode,
          originalException: originalException,
        );

  /// DioException → NetworkException 변환 헬퍼
  factory NetworkException.fromDio(DioException dioError) {
    final msg = dioError.message ?? dioError.toString();
    return NetworkException(
      msg,
      code: dioError.response?.statusMessage,
      statusCode: dioError.response?.statusCode,
      originalException: dioError,
    );
  }
}

/// WebSocket 연결/통신 중 발생한 예외
class WebSocketException extends AppException {
  /// WS 서버가 보낸 이유 문자열 (nullable)
  final String? reason;

  const WebSocketException(
    String message, {
    this.reason,
    Exception? originalException,
  }) : super(
          message,
          originalException: originalException,
        );

  @override
  String toString() {
    final parts = <String>[];
    if (reason != null) parts.add('reason: $reason');
    parts.add('message: $message');
    return 'WebSocketException(${parts.join(', ')})';
  }
}

/// 서버로부터 Rate Limit(HTTP 429 등) 응답을 받았을 때
class RateLimitException extends AppException {
  /// 재시도까지 대기해야 할 시간
  final Duration retryAfter;

  const RateLimitException(
    String message, {
    required this.retryAfter,
    String? code,
    int? statusCode,
  }) : super(
          message,
          code: code,
          statusCode: statusCode,
        );

  @override
  String toString() =>
      'RateLimitException(retryAfter: ${retryAfter.inSeconds}s, message: $message)';
}

/// JSON 파싱 또는 데이터 변환 중 발생한 예외
class DataParsingException extends AppException {
  const DataParsingException(
    String message, {
    Exception? originalException,
  }) : super(
          message,
          originalException: originalException,
        );
}

/// 인메모리 캐시에서 키를 찾지 못했을 때
class CacheMissException extends AppException {
  const CacheMissException([String message = 'Cache miss'])
      : super(message);
}

// ──────────────────────────────────────────────────────────────────────────
// 도메인 특화 예외
// ──────────────────────────────────────────────────────────────────────────

/// 체결(Trade) 데이터 유효성 검사 오류
class TradeException extends AppException {
  const TradeException(
    String message, {
    Exception? originalException,
  }) : super(
          message,
          originalException: originalException,
        );
}

/// 호가(Order Book) 데이터 오류
class OrderBookException extends AppException {
  const OrderBookException(
    String message, {
    Exception? originalException,
  }) : super(
          message,
          originalException: originalException,
        );
}

/// 캔들(Candle) 데이터 파싱 오류
class CandleException extends DataParsingException {
  const CandleException(
    String message, {
    Exception? originalException,
  }) : super(
          message,
          originalException: originalException,
        );
}

/// 현재가(Ticker) 데이터 파싱 오류
class TickerException extends DataParsingException {
  const TickerException(
    String message, {
    Exception? originalException,
  }) : super(
          message,
          originalException: originalException,
        );
}
