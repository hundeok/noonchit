// lib/core/network/websocket/base_ws_client.dart

import 'dart:async';
import 'dart:convert';

import 'package:web_socket_channel/web_socket_channel.dart';

import '../../config/app_config.dart';
import '../../error/app_exception.dart';
import '../adaptive_backoff.dart';               // AdaptiveBackoff 연동
import '../ws_rate_limiter_interceptor.dart';
import '../../utils/logger.dart';                // ← logger import

typedef DecodeFn<T> = T Function(dynamic json);
typedef EncodeFn = String Function(List<String> symbols);

/// WebSocket connection status notifications.
enum WsStatus {
  connecting,
  connected,
  failed,
  disconnected,
  error,
  reconnecting,
  pongTimeout,
  maxRetryExceeded,
}

/// Common WebSocket client: connect, subscribe, reconnect, emit
class BaseWsClient<T> {
  /// Helper to decode a JSON list (or single object) into a List<Map<String, dynamic>>.
  static List<Map<String, dynamic>> decodeJsonList(dynamic raw) {
    final jsonObj = raw is String ? jsonDecode(raw) : raw;
    final list = jsonObj is List ? jsonObj : [jsonObj];
    return list
        .cast<Map<String, dynamic>>()
        .map((e) => Map<String, dynamic>.from(e))
        .toList();
  }

  final String url;
  final DecodeFn<T> decode;
  final EncodeFn encodeSubscribe;
  final void Function(WsStatus)? onStatusChange;
  final WsRateLimiter _rateLimiter;
  final AdaptiveBackoffCalculator _backoffCalculator =
      AdaptiveBackoffCalculator();
  final Set<StreamSubscription> _activeSubscriptions = {};
  Timer? _memoryCleanupTimer;

  WebSocketChannel? _channel;
  final _controller = StreamController<T>.broadcast();
  List<String> _symbols = [];
  Timer? _pingTimer;
  Timer? _pongTimer;
  bool _disposed = false;
  bool _reconnecting = false;
  int _retryCount = 0;

  BaseWsClient({
    required this.url,
    required this.decode,
    required this.encodeSubscribe,
    this.onStatusChange,
    WsRateLimiter? rateLimiter,
  }) : _rateLimiter = rateLimiter ?? WsRateLimiter() {
    _startMemoryCleanup();
  }

  /// Start periodic cleanup of inactive subscriptions.
  void _startMemoryCleanup() {
    _memoryCleanupTimer =
        Timer.periodic(const Duration(seconds: 30), (_) {
      _cleanupInactiveSubscriptions();
    });
  }

  /// Clean up paused subscriptions to prevent memory leaks.
  void _cleanupInactiveSubscriptions() {
    final toRemove =
        _activeSubscriptions.where((sub) => sub.isPaused).toList();
    for (final sub in toRemove) {
      sub.cancel();
      _activeSubscriptions.remove(sub);
    }
    if (toRemove.isNotEmpty) {
      log.d('WSClient: Cleaned up ${toRemove.length} inactive subscriptions');
    }
  }

  /// 🔥 재연결 시 기존 구독들 안전하게 정리 (메모리 누수 방지)
  void _cleanupActiveSubscriptions() {
    if (_activeSubscriptions.isNotEmpty) {
      log.d('🧹 기존 구독 ${_activeSubscriptions.length}개 정리 중...');
      
      for (final subscription in _activeSubscriptions) {
        try {
          subscription.cancel();
        } catch (e) {
          log.w('⚠️ 구독 취소 중 에러: $e');
        }
      }
      
      _activeSubscriptions.clear();
      log.d('✅ 구독 정리 완료');
    }
  }

  /// Exposed stream of decoded messages.
  Stream<T> get stream => _controller.stream;

  /// Connect or reconnect with a new set of symbols.
  Future<void> connect(List<String> symbols) async {
    _notify(WsStatus.connecting);
    if (_disposed) return;
    _symbols = List.from(symbols);
    
    // 🔥 재연결 시 기존 구독들 정리 (메모리 누수 방지)
    _cleanupActiveSubscriptions();
    
    await _channel?.sink.close();

    try {
      if (_symbols.length > AppConfig.wsMaxSubscriptionCount) {
        throw const WebSocketException('Subscribe limit exceeded');
      }
      _channel = WebSocketChannel.connect(Uri.parse(url));
      _setupPing();
      _send(encodeSubscribe(_symbols));

      final subscription = _channel!.stream.listen(
        _handleData,
        onDone: _handleDone,
        onError: _handleError,
        cancelOnError: true,
      );
      _activeSubscriptions.add(subscription);

      _retryCount = 0;
      _backoffCalculator.recordSuccess();
      _notify(WsStatus.connected);
      log.i('WS connected to $url (subscriptions: ${_symbols.length})');
    } catch (e, st) {
      log.w('WS connect failed: $e', e, st);
      _backoffCalculator.recordFailure();
      _notify(WsStatus.failed);
      _scheduleReconnect();
    }
  }

  void _handleData(dynamic raw) {
    _pongTimer?.cancel();
    try {
      final text = raw is List<int> ? utf8.decode(raw) : raw.toString();
      final jsonObj = jsonDecode(text);
      final data = decode(jsonObj);
      _controller.add(data);
    } catch (e, st) {
      log.e('WS processing error', e, st);
    }
  }

  void _handleDone() {
    log.i('WS closed by server');
    _notify(WsStatus.disconnected);
    _scheduleReconnect();
  }

  void _handleError(dynamic e) {
    log.e('WS error', e);
    _backoffCalculator.recordFailure();
    _notify(WsStatus.error);
    _scheduleReconnect();
  }

  void _send(String msg) => _rateLimiter.enqueue(() {
        try {
          _channel?.sink.add(msg);
          log.d('WS ▶ $msg');
        } catch (e, st) {
          log.e('WS send error', e, st);
        }
      });

  void _setupPing() {
    _pingTimer?.cancel();
    _pongTimer?.cancel();
    _pingTimer =
        Timer.periodic(AppConfig.wsPingInterval, (_) {
      _send(jsonEncode({'type': 'ping'}));
      _pongTimer = Timer(AppConfig.wsPongTimeout, () {
        log.w('Pong timeout, reconnecting');
        _notify(WsStatus.pongTimeout);
        _scheduleReconnect();
      });
    });
    log.d('WS ping/pong timers set');
  }

  /// Schedule reconnection with adaptive backoff.
  void _scheduleReconnect() {
    if (_disposed || _reconnecting) return;
    _reconnecting = true;
    _pingTimer?.cancel();
    _pongTimer?.cancel();

    _backoffCalculator
        .calculateBackoff(
          _retryCount,
          AppConfig.wsInitialBackoff,
          AppConfig.wsMaxBackoff,
        )
        .then((delay) {
      if (_disposed) return;
      Future.delayed(delay, () {
        if (_disposed) return;
        if (_retryCount < AppConfig.wsMaxRetryCount) {
          _retryCount++;
          log.i(
            'Reconnect attempt #$_retryCount after ${delay.inMilliseconds}ms',
          );
          _notify(WsStatus.reconnecting);
          connect(_symbols).whenComplete(() => _reconnecting = false);
        } else {
          log.w('Max WS retries exceeded');
          _notify(WsStatus.maxRetryExceeded);
          _retryCount = 0;
          _reconnecting = false;
        }
      });
    });
  }

  void _notify(WsStatus status) => onStatusChange?.call(status);

  /// Dispose resources: timers, subscriptions, channel, controller, and backoff state.
  Future<void> dispose() async {
    _disposed = true;
    _pingTimer?.cancel();
    _pongTimer?.cancel();
    _memoryCleanupTimer?.cancel();

    // 🔥 dispose 시에도 안전하게 정리
    _cleanupActiveSubscriptions();

    _rateLimiter.dispose();
    await _channel?.sink.close();
    await _controller.close();
    _backoffCalculator.recordSuccess(); // reset
    log.i('WSClient disposed');
  }
}