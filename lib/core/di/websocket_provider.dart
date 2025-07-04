// lib/core/di/websocket_provider.dart

import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../config/app_config.dart';
import '../network/websocket/trade_ws_client.dart';
import '../network/websocket/base_ws_client.dart'; // WsStatus enum
import '../utils/logger.dart';
import '../bridge/signal_bus.dart';

/// 🆕 WebSocket 상세 통계 클래스 (시간/연결/앱생명주기 중심)
class WebSocketStats {
  final DateTime? connectTime;
  final int reconnectCount;
  final int totalSessions;
  final Duration _storedCumulativeTime;
  final int connectionAttempts;
  final DateTime? lastStateChangeTime;
  
  const WebSocketStats({
    this.connectTime,
    this.reconnectCount = 0,
    this.totalSessions = 0,
    Duration cumulativeConnectTime = Duration.zero,
    this.connectionAttempts = 0,
    this.lastStateChangeTime,
  }) : _storedCumulativeTime = cumulativeConnectTime;

  /// 연결 지속 시간 계산
  Duration? get uptime {
    if (connectTime == null) return null;
    return DateTime.now().difference(connectTime!);
  }

  /// 실시간 누적 연결 시간
  Duration get cumulativeConnectTime {
    Duration total = _storedCumulativeTime;
    
    // 현재 연결 중이면 현재 세션 시간도 포함
    if (connectTime != null) {
      total += DateTime.now().difference(connectTime!);
    }
    
    return total;
  }

  /// 실시간 평균 연결 지속 시간
  Duration get averageSessionDuration {
    if (totalSessions == 0) return Duration.zero;
    return Duration(
      milliseconds: cumulativeConnectTime.inMilliseconds ~/ totalSessions,
    );
  }

  /// 연결 성공률 (%)
  double get connectionSuccessRate {
    if (connectionAttempts == 0) return 0.0;
    return (totalSessions / connectionAttempts) * 100;
  }
}

/// 🔄 SignalBus Provider (순환 참조 방지)
final signalBusProvider = Provider<SignalBus>((ref) {
  final bus = SignalBus();
  ref.onDispose(() => bus.dispose());
  return bus;
});

/// 🆕 WebSocket 상태 관리
final wsStatusProvider = StateProvider<WsStatus>((ref) => WsStatus.disconnected);

/// 🆕 WebSocket 통계 관리 (개별 Provider들 - 시간/연결/앱생명주기)
final wsConnectTimeProvider = StateProvider<DateTime?>((ref) => null);
final wsReconnectCountProvider = StateProvider<int>((ref) => 0);
final wsTotalSessionsProvider = StateProvider<int>((ref) => 0);
final wsCumulativeConnectTimeProvider = StateProvider<Duration>((ref) => Duration.zero);
final wsConnectionAttemptsProvider = StateProvider<int>((ref) => 0);
final wsLastStateChangeTimeProvider = StateProvider<DateTime?>((ref) => null);

/// 🆕 통합 WebSocket 통계 Provider (개별 Provider들을 조합)
final wsStatsProvider = Provider<WebSocketStats>((ref) {
  final connectTime = ref.watch(wsConnectTimeProvider);
  final reconnectCount = ref.watch(wsReconnectCountProvider);
  final totalSessions = ref.watch(wsTotalSessionsProvider);
  final cumulativeConnectTime = ref.watch(wsCumulativeConnectTimeProvider);
  final connectionAttempts = ref.watch(wsConnectionAttemptsProvider);
  final lastStateChangeTime = ref.watch(wsLastStateChangeTimeProvider);

  return WebSocketStats(
    connectTime: connectTime,
    reconnectCount: reconnectCount,
    totalSessions: totalSessions,
    cumulativeConnectTime: cumulativeConnectTime,
    connectionAttempts: connectionAttempts,
    lastStateChangeTime: lastStateChangeTime,
  );
});

/// 🆕 WebSocket 클라이언트 (기본 - 기존 그대로)
final wsClientProvider = Provider<TradeWsClient>((ref) {
  return TradeWsClient(
    onStatusChange: (status) {
      final now = DateTime.now();
      ref.read(wsStatusProvider.notifier).state = status;
      ref.read(wsLastStateChangeTimeProvider.notifier).state = now;
      
      // 간단한 통계 업데이트 (시간/연결/앱생명주기)
      switch (status) {
        case WsStatus.connecting:
          // 연결 시도 카운트
          final attempts = ref.read(wsConnectionAttemptsProvider);
          ref.read(wsConnectionAttemptsProvider.notifier).state = attempts + 1;
          break;
          
        case WsStatus.connected:
          // 연결 성공
          ref.read(wsConnectTimeProvider.notifier).state = now;
          
          // 총 세션 수 증가
          final sessions = ref.read(wsTotalSessionsProvider);
          ref.read(wsTotalSessionsProvider.notifier).state = sessions + 1;
          break;
          
        case WsStatus.reconnecting:
          // 재연결 카운트
          final currentCount = ref.read(wsReconnectCountProvider);
          ref.read(wsReconnectCountProvider.notifier).state = currentCount + 1;
          break;
          
        case WsStatus.disconnected:
          // 연결 종료 시 누적 시간 업데이트
          final connectTime = ref.read(wsConnectTimeProvider);
          if (connectTime != null) {
            final sessionDuration = now.difference(connectTime);
            final cumulative = ref.read(wsCumulativeConnectTimeProvider);
            ref.read(wsCumulativeConnectTimeProvider.notifier).state = 
                cumulative + sessionDuration;
          }
          ref.read(wsConnectTimeProvider.notifier).state = null;
          break;
          
        default:
          break;
      }
      
      if (AppConfig.enableTradeLog) {
        log.i('WebSocket status changed: $status');
      }
    },
  );
});