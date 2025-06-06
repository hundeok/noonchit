import 'dart:async';
import 'dart:math';
import 'package:dio/dio.dart';
import '../utils/logger.dart';

/// 429 혹은 5xx 에러에 대해 지수 백오프 + 지터 방식으로 재시도합니다.
class RetryInterceptor extends Interceptor {
  final Dio dio;
  final int maxRetries;
  final Duration initialBackoff;
  final Duration maxBackoff;
  final double jitterFactor;

  RetryInterceptor({
    required this.dio,
    this.maxRetries = 3,
    this.initialBackoff = const Duration(milliseconds: 500),
    this.maxBackoff = const Duration(seconds: 5),
    this.jitterFactor = 0.2,
  });

  @override
  Future<void> onError(DioException err, ErrorInterceptorHandler handler) async {
    final options = err.requestOptions;
    final retryCount = (options.extra['retry_count'] as int?) ?? 0;
    final status = err.response?.statusCode;

    if (_shouldRetry(err) && retryCount < maxRetries) {
      final next = retryCount + 1;
      options.extra['retry_count'] = next;

      // 429 응답일 경우 서버가 제공하는 헤더 우선 사용
      Duration delay;
      if (status == 429) {
        final retryAfter = err.response?.headers.value('Retry-After');
        if (retryAfter != null) {
          final secs = int.tryParse(retryAfter) ?? 0;
          delay = Duration(seconds: secs);
          log.i('Retry #$next after Retry-After header: ${delay.inSeconds}s');
        } else {
          final remaining = err.response?.headers.value('Remaining-Req');
          if (remaining != null) {
            log.d('Remaining-Req header: $remaining');
          }
          delay = _computeBackoff(next);
        }
      } else {
        // 5xx 에러는 기본 백오프 사용
        delay = _computeBackoff(next);
      }

      log.i('Retry #$next for [${options.method} ${options.path}] in ${delay.inMilliseconds}ms');
      await Future.delayed(delay);

      try {
        final response = await dio.fetch(options);
        return handler.resolve(response);
      } on DioException catch (e) {
        return handler.next(e);
      }
    }

    handler.next(err);
  }

  bool _shouldRetry(DioException err) {
    final status = err.response?.statusCode;
    return err.type == DioExceptionType.badResponse &&
        (status == 429 || (status != null && status >= 500 && status < 600));
  }

  Duration _computeBackoff(int attempt) {
    final expMs = initialBackoff.inMilliseconds * (1 << (attempt - 1));
    final cap = min(expMs, maxBackoff.inMilliseconds);
    final jitter = ((Random().nextDouble() * 2 - 1) * jitterFactor * cap).round();
    final finalMs = max(0, cap + jitter);
    return Duration(milliseconds: finalMs);
  }
}
