// lib/core/config/app_config.dart

import 'dart:collection';
import 'package:flutter_dotenv/flutter_dotenv.dart';
import 'package:logger/logger.dart';
import '../utils/logger.dart';

/// Application-wide configuration and constants,
/// optimized per Upbit REST & WebSocket specifications.
class AppConfig {
  AppConfig._();

  /// Call once at startup to initialize dynamic config (env variables)
  static Future<void> init({String? envPath}) async {
    // Load .env (optional custom path) + validate
    try {
      if (envPath != null && envPath.isNotEmpty) {
        await dotenv.load(fileName: envPath);
      } else {
        await dotenv.load();
      }
      log.i('[AppConfig] .env loaded');
      _loadEnv();
    } catch (e, st) {
      log.e('[AppConfig] ⚠️ Failed to load required env vars', e, st);
      throw Exception('[AppConfig] ⚠️ Failed to load required env vars: $e');
    }

    log.i('[AppConfig] initialized (debug=$isDebugMode)');
  }

  static void _loadEnv() {
    const requiredKeys = ['UPBIT_API_KEY', 'UPBIT_API_SECRET'];
    for (final key in requiredKeys) {
      final value = dotenv.env[key];
      if (value == null || value.isEmpty) {
        throw Exception('[AppConfig] Missing required env var: $key');
      }
    }

    _upbitRestBase = dotenv.env['UPBIT_REST_URL']?.isNotEmpty == true
        ? dotenv.env['UPBIT_REST_URL']!
        : _upbitRestBase;
    _upbitWsUrl = dotenv.env['UPBIT_WS_URL']?.isNotEmpty == true
        ? dotenv.env['UPBIT_WS_URL']!
        : _upbitWsUrl;

    _apiKey = dotenv.env['UPBIT_API_KEY']!;
    _apiSecret = dotenv.env['UPBIT_API_SECRET']!;
  }

  // ──────────────── 🆕 통일된 Bool 해석 유틸리티 ────────────────
  /// 환경변수에서 boolean 값을 안전하고 일관되게 파싱
  /// 지원하는 true 값: 'true', '1', 'yes', 'on'
  /// 지원하는 false 값: 'false', '0', 'no', 'off', null, 빈 문자열
  static bool _getBool(String key, {bool fallback = false}) {
    final value = dotenv.env[key]?.toLowerCase().trim();
    if (value == null || value.isEmpty) return fallback;
    
    // true 값들
    if (value == 'true' || value == '1' || value == 'yes' || value == 'on') {
      return true;
    }
    
    // false 값들
    if (value == 'false' || value == '0' || value == 'no' || value == 'off') {
      return false;
    }
    
    // 알 수 없는 값이면 fallback 사용
    return fallback;
  }

  // ─────────────────── API Credentials ───────────────────
  static String _apiKey = '';
  static String _apiSecret = '';
  static String get apiKey => _apiKey;
  static String get apiSecret => _apiSecret;

  // ──────────────── Environment Flags ────────────────
  /// `true` when not in Dart VM product mode.
  static const bool isDebugMode = !bool.fromEnvironment('dart.vm.product');

  // ──────────────── Logging Configuration ────────────────
  /// 로그 레벨 설정 (개발 중 조절 가능)
  static Level get logLevel {
    if (!isDebugMode) return Level.warning;
    final envLevel = dotenv.env['LOG_LEVEL']?.toLowerCase();
    switch (envLevel) {
      case 'verbose':
        return Level.verbose;
      case 'debug':
        return Level.debug;
      case 'info':
        return Level.info;
      case 'warning':
        return Level.warning;
      case 'error':
        return Level.error;
      default:
        return Level.debug;
    }
  }

  /// 🔧 특정 모듈 로그 on/off (통일된 방식 적용)
  static bool get enableSignalBusLog =>
      _getBool('ENABLE_SIGNAL_BUS_LOG', fallback: true);
  static bool get enableWebSocketLog =>
      _getBool('ENABLE_WEBSOCKET_LOG', fallback: true);
  static bool get enableTradeLog =>
      _getBool('ENABLE_TRADE_LOG', fallback: true);
  static bool get enableAdaptiveBackoffLog =>
      _getBool('ENABLE_ADAPTIVE_BACKOFF_LOG', fallback: true);

  // ──────────────── REST Configuration (업비트 2025 스펙) ────────────────
  static String _upbitRestBase = 'https://api.upbit.com/v1';
  static String get upbitRestBase => _upbitRestBase;
  
  /// 🆕 업비트 백서 2025 기준 레이트리밋 (그룹별)
  /// 공개 API: 초당 30회 / 사적 API: 초당 8회
  static const Map<String, int> rateLimitByGroup = {
    'market': 30,      // 공개 API: /market/all, /ticker 등
    'candles': 30,     // 공개 API: /candles 등  
    'trades': 30,      // 공개 API: /trades 등
    'orderbook': 30,   // 공개 API: /orderbook 등
    'orders': 8,       // 사적 API: 주문 관련
    'accounts': 8,     // 사적 API: 계정 관련
    'withdraws': 8,    // 사적 API: 출금 관련
    'deposits': 8,     // 사적 API: 입금 관련
    'default': 8,      // 기본값: 사적 API 기준
  };
  
  /// 🆕 그룹별 레이트리밋 조회
  static int getRateLimitForGroup(String group) {
    return rateLimitByGroup[group] ?? rateLimitByGroup['default']!;
  }
  
  /// 🆕 경로 기반 그룹 자동 판별
  static String getGroupFromPath(String path) {
    final normalizedPath = path.toLowerCase();
    
    // 공개 API 그룹들
    if (normalizedPath.contains('/market/')) return 'market';
    if (normalizedPath.contains('/ticker')) return 'market';
    if (normalizedPath.contains('/candles/')) return 'candles';
    if (normalizedPath.contains('/trades')) return 'trades';  
    if (normalizedPath.contains('/orderbook')) return 'orderbook';
    
    // 사적 API 그룹들
    if (normalizedPath.contains('/orders')) return 'orders';
    if (normalizedPath.contains('/accounts')) return 'accounts';
    if (normalizedPath.contains('/withdraws')) return 'withdraws';
    if (normalizedPath.contains('/deposits')) return 'deposits';
    
    // 기본값 (사적 API)
    return 'default';
  }
  
  /// 레거시 호환용 (기존 코드 호환성)
  @Deprecated('Use rateLimitByGroup instead')
  static const int restRateLimitCount = 8; // 사적 API 기준으로 보수적 설정
  static const Duration restRateLimitPeriod = Duration(seconds: 1);

  // ──────────────── WebSocket Configuration ────────────────
  static String _upbitWsUrl = 'wss://api.upbit.com/websocket/v1';
  static String get upbitWsUrl => _upbitWsUrl;
  static const int wsMaxSubscriptionCount = 200;

  // Upbit 권장 타이밍으로 변경 (30s Ping / 60s Pong):
  static const Duration wsPingInterval = Duration(seconds: 30);
  static const Duration wsPongTimeout = Duration(seconds: 60);

  static const int wsMaxRetryCount = 5;
  static const Duration wsInitialBackoff = Duration(seconds: 1);
  static const Duration wsMaxBackoff = Duration(seconds: 30);

  // ──────────────── Aggregation ────────────────
  static const int mergeWindowMs = 1000;
  static const Duration globalResetInterval = Duration(seconds: 30);

  // ──────────────── Dev/Test Flags ────────────────
  static bool useTestDataInDev = false;

  // ──────────────── Trade Filters ────────────────
  static final List<double> _filters = [
    2e6, 5e6, 1e7, 2e7, 5e7,
    1e8, 2e8, 3e8, 4e8, 5e8,
    1e9,
  ];
  static UnmodifiableListView<double> get tradeFilters =>
      UnmodifiableListView(_filters);

  /// Human-readable labels always in sync with `_filters`
  static Map<double, String> get filterNames => Map.unmodifiable({
        for (final f in _filters) f: _formatFilterLabel(f),
      });

  /// Update the trade filters at runtime (ensures positive & sorted)
  static void updateFilters(List<double> newFilters) {
    _filters
      ..clear()
      ..addAll(newFilters.where((f) => f > 0))
      ..sort();
    log.i('[AppConfig] filters updated → $_filters');
  }

  static String _formatFilterLabel(double f) {
    if (f >= 1e8 && f % 1e8 == 0) return '${(f / 1e8).toInt()}억';
    if (f >= 1e7 && f % 1e7 == 0) return '${(f / 1e7).toInt()}천만';
    if (f >= 1e6 && f % 1e6 == 0) return '${(f / 1e6).toInt()}백만';
    return f.toStringAsFixed(0);
  }

  // ──────────────── Candle Timeframes ────────────────
  static const List<int> timeFrames = [
    1, 5, 15, 30, 60, 120, 240, 480, 720, 1440
  ];
  static final Map<int, String> timeFrameNames = Map.unmodifiable({
    1: '1분',
    5: '5분',
    15: '15분',
    30: '30분',
    60: '1시간',
    120: '2시간',
    240: '4시간',
    480: '8시간',
    720: '12시간',
    1440: '1일',
  });

  // ──────────────── Surge Detection ────────────────
  static const double surgeThresholdPercent = 1.1;
  static const Duration surgeWindowDuration = Duration(minutes: 1);
}