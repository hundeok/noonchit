import 'dart:async';

import '../utils/logger.dart';           // log.d, log.i, log.w, log.e
import '../event/app_event.dart';        // Json typedef

/// Types of signals carried by the bus.
enum SignalEventType { trade, orderBook, notification }

/// Supported exchange platforms.
enum ExchangePlatform { upbit, binance, bybit, bithumb }

/// Global singleton event bus.
/// Dispatches all AppEvent payloads by type & platform.
///
/// ⚠️ Remember to call `SignalBus().dispose()` on app shutdown or via
/// Riverpod's `ref.onDispose` to clean up streams.
class SignalBus {
  SignalBus._();
  static final SignalBus _instance = SignalBus._();
  factory SignalBus() => _instance;

  final StreamController<Json> _globalController = StreamController<Json>.broadcast();
  final Map<SignalEventType, StreamController<Json>> _typeControllers = {};
  final Map<String, StreamController<Json>> _platformControllers = {};
  final StreamController<String> _errorController = StreamController<String>.broadcast();

  /// All events as raw JSON maps.
  Stream<Json> get events => _globalController.stream;

  /// Events of a specific type.
  Stream<Json> eventsOfType(SignalEventType type) =>
      _typeControllers.putIfAbsent(type, () {
        final ctrl = StreamController<Json>.broadcast();
        log.d('SignalBus: Created type controller for $type');
        return ctrl;
      }).stream;

  /// 🆕 타입 안전한 이벤트 스트림 (제네릭)
  Stream<T> eventsOf<T>(SignalEventType type, T Function(Json) converter) =>
      eventsOfType(type).map(converter);

  /// Events of a specific type and platform, cached for efficiency.
  Stream<Json> eventsOfPlatform(SignalEventType type, ExchangePlatform platform) {
    final key = '${type.name}_${platform.name}';
    return _platformControllers.putIfAbsent(key, () {
      final ctrl = StreamController<Json>.broadcast();
      eventsOfType(type)
          .where((m) => (m['platform'] as String? ?? '') == platform.name)
          .listen(
            ctrl.add,
            onError: ctrl.addError,
            onDone: () {
              ctrl.close();
              _platformControllers.remove(key);
              log.d('SignalBus: Closed platform controller for $key');
            },
          );
      log.d('SignalBus: Created platform controller for $key');
      return ctrl;
    }).stream;
  }

  /// 🆕 타입 안전한 플랫폼별 이벤트 스트림
  Stream<T> eventsOfPlatformTyped<T>(
    SignalEventType type,
    ExchangePlatform platform,
    T Function(Json) converter,
  ) => eventsOfPlatform(type, platform).map(converter);

  /// Errors from bus internals.
  Stream<String> get errors => _errorController.stream;

  // ───────────────────────────────────────────────────────────────────────
  // Emitters for raw payloads
  // ───────────────────────────────────────────────────────────────────────

  void fireTrade(Json data, {ExchangePlatform platform = ExchangePlatform.upbit}) =>
      _fire(SignalEventType.trade, data, platform);

  void fireOrderBook(Json data, {ExchangePlatform platform = ExchangePlatform.upbit}) =>
      _fire(SignalEventType.orderBook, data, platform);

  void fireNotification(Json data, {ExchangePlatform platform = ExchangePlatform.upbit}) =>
      _fire(SignalEventType.notification, data, platform);

  // ───────────────────────────────────────────────────────────────────────
  // Emitters for AppEvent
  // ───────────────────────────────────────────────────────────────────────

  void fireTradeEvent(AppEvent event, {ExchangePlatform platform = ExchangePlatform.upbit}) =>
      _fire(SignalEventType.trade, event.toJson(), platform);

  void fireOrderBookEvent(AppEvent event, {ExchangePlatform platform = ExchangePlatform.upbit}) =>
      _fire(SignalEventType.orderBook, event.toJson(), platform);

  void fireNotificationEvent(AppEvent event, {ExchangePlatform platform = ExchangePlatform.upbit}) =>
      _fire(SignalEventType.notification, event.toJson(), platform);

  // ───────────────────────────────────────────────────────────────────────
  // Internal dispatch logic
  // ───────────────────────────────────────────────────────────────────────

  void _fire(SignalEventType type, Json data, ExchangePlatform platform) {
    try {
      final enriched = <String, dynamic>{...data, 'platform': platform.name};

      // Broadcast to global subscribers
      if (!_globalController.isClosed) {
        _globalController.add(enriched);
      } else {
        log.w('SignalBus: Global controller closed, skipping event $type');
      }

      // Type-specific subscribers
      final typeCtrl = _typeControllers[type];
      if (typeCtrl != null && !typeCtrl.isClosed) {
        typeCtrl.add(enriched);
      } else if (typeCtrl != null) {
        log.w('SignalBus: Type controller for $type closed, removing');
        _typeControllers.remove(type);
      }

      // Debug preview (limited to 100 chars)
      final msg = enriched.toString();
      if (msg.length <= 100) {
        log.d('SignalBus: $type @${platform.name} → $msg');
      } else {
        log.d('SignalBus: $type @${platform.name} → ${msg.substring(0, 100)}…');
      }
    } catch (e, st) {
      final errMsg = 'SignalBus error: $e';
      log.e(errMsg, e, st);
      if (!_errorController.isClosed) {
        _errorController.add(errMsg);
      } else {
        log.w('SignalBus: Error controller closed, error not dispatched: $errMsg');
      }
    }
  }

  /// Log current memory status for debugging.
  void logMemoryStatus() {
    log.d('SignalBus Memory Status:');
    log.d('  - Type controllers: ${_typeControllers.length}');
    log.d('  - Platform controllers: ${_platformControllers.length}');
    log.d('  - Global controller active: ${_globalController.hasListener}');
    log.d('  - Error controller active: ${_errorController.hasListener}');
  }

  /// Close all controllers to free resources and log cleanup.
  void dispose() {
    // Close type-specific controllers
    for (final entry in _typeControllers.entries) {
      final ctrl = entry.value;
      if (!ctrl.isClosed) {
        ctrl.close();
        log.d('SignalBus: Closed type controller for ${entry.key}');
      }
    }
    _typeControllers.clear();

    // Close platform-specific controllers
    for (final entry in _platformControllers.entries) {
      final ctrl = entry.value;
      if (!ctrl.isClosed) {
        ctrl.close();
        log.d('SignalBus: Closed platform controller for ${entry.key}');
      }
    }
    _platformControllers.clear();

    // Close global and error controllers
    if (!_globalController.isClosed) {
      _globalController.close();
      log.d('SignalBus: Closed global controller');
    }
    if (!_errorController.isClosed) {
      _errorController.close();
      log.d('SignalBus: Closed error controller');
    }

    log.i('SignalBus: fully disposed');
  }
}