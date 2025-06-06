// lib/core/network/ws_rate_limiter_interceptor.dart

import 'dart:async';
import 'dart:collection';
import 'package:flutter/foundation.dart';
import '../utils/logger.dart';

/// Upbit WebSocket 구독 메시지 발행 간 최소 간격 보장 유틸
class WsRateLimiter {
  final Duration minInterval;
  final Queue<VoidCallback> _queue = Queue<VoidCallback>();
  bool _isFlushing = false;
  DateTime _lastSent = DateTime.fromMillisecondsSinceEpoch(0);

  WsRateLimiter({this.minInterval = const Duration(milliseconds: 500)});

  /// 메시지를 큐에 추가하고 즉시 전송 시도
  void enqueue(VoidCallback send) {
    _queue.add(send);
    _flushNext();
  }

  void _flushNext() {
    if (_isFlushing || _queue.isEmpty) return;
    _isFlushing = true;

    final now = DateTime.now();
    final elapsed = now.difference(_lastSent);
    final delay = elapsed >= minInterval ? Duration.zero : minInterval - elapsed;

    Timer(delay, () {
      final send = _queue.removeFirst();
      try {
        send();
        _lastSent = DateTime.now();
        log.d('WsRateLimiter sent, next after \${minInterval.inMilliseconds}ms');
      } catch (e, st) {
        log.e('WsRateLimiter send error', e, st);
      } finally {
        _isFlushing = false;
        if (_queue.isNotEmpty) _flushNext();
      }
    });
  }

  /// 큐를 비우고 사용 중지
  void dispose() {
    _queue.clear();
  }
}
