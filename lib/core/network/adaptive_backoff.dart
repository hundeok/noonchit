// lib/core/network/adaptive_backoff.dart

import 'dart:math' as math;
import 'package:connectivity_plus/connectivity_plus.dart';
import '../utils/logger.dart';

class AdaptiveBackoffCalculator {
  final Connectivity _connectivity = Connectivity();
  int _consecutiveFailures = 0;
  DateTime? _lastFailureTime;
  
  // 네트워크별 기본 지터 계수 (connectivity_plus 연동)
  static const Map<ConnectivityResult, double> _networkMultipliers = {
    ConnectivityResult.wifi: 0.8,      // WiFi는 빠른 재연결
    ConnectivityResult.mobile: 1.2,    // 모바일은 보수적
    ConnectivityResult.ethernet: 0.6,  // 유선은 가장 빠름
    ConnectivityResult.none: 2.0,      // 연결 없음은 매우 보수적
  };

  Future<Duration> calculateBackoff(int attempt, Duration baseDelay, Duration maxDelay) async {
    final connectivityResult = await _connectivity.checkConnectivity();
    final networkMultiplier = _networkMultipliers[connectivityResult] ?? 1.0; // 기본값
    
    final failurePenalty = _calculateFailurePenalty();
    
    final exponentialMs = baseDelay.inMilliseconds * (1 << attempt);
    final cappedMs = math.min(exponentialMs, maxDelay.inMilliseconds);
    
    // 지터 범위 20%로 빠른 재연결 보장
    final jitterRange = cappedMs * 0.2;
    final random = math.Random();
    final adaptiveJitter = random.nextDouble() * jitterRange * networkMultiplier * failurePenalty;
    
    final finalMs = math.max(0, cappedMs + adaptiveJitter.round());
    
    log.d('AdaptiveBackoff: attempt=$attempt, network=$connectivityResult, '
          'base=${cappedMs}ms, jitter=${adaptiveJitter.round()}ms, final=${finalMs}ms');
    
    return Duration(milliseconds: finalMs);
  }

  double _calculateFailurePenalty() {
    if (_lastFailureTime == null) return 1.0;
    
    final timeSinceLastFailure = DateTime.now().difference(_lastFailureTime!);
    if (timeSinceLastFailure > const Duration(minutes: 5)) {
      _consecutiveFailures = 0;
      return 1.0;
    }
    
    // 페널티 상한 1.5배로 조정 (그록의 수정사항 유지)
    return math.min(1.5, 1.0 + (_consecutiveFailures * 0.2));
  }

  void recordFailure() {
    _consecutiveFailures++;
    _lastFailureTime = DateTime.now();
  }

  void recordSuccess() {
    _consecutiveFailures = 0;
    _lastFailureTime = null;
  }
}