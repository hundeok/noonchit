// lib/core/network/api_client.dart

import 'dart:async';
import 'dart:collection';
import 'package:dio/dio.dart';
import '../config/app_config.dart';
import '../error/app_exception.dart';
import '../extensions/result.dart';
import '../utils/logger.dart';
import 'auth_interceptor.dart';
import 'retry_interceptor.dart';
import 'logging_interceptor.dart';

typedef Json = Map<String, dynamic>;

/// 🆕 업비트 백서 2025 기준 동적 레이트리밋 관리자
/// Remaining-Req 헤더를 파싱하여 그룹별 실시간 슬롯 계산
class _UpbitDynamicRateLimiter {
  final Map<String, _GroupRateLimiter> _groupLimiters = {};
  final Duration _defaultPeriod = const Duration(seconds: 1);
  
  /// 응답 헤더에서 레이트리밋 정보 업데이트
  /// 형식: "Remaining-Req: group=market; min=900; sec=29"
  void updateFromHeaders(Map<String, List<String>> headers) {
    try {
      final remainingReq = headers['remaining-req']?.first ?? 
                          headers['Remaining-Req']?.first;
      if (remainingReq == null) return;
      
      // 헤더 파싱: group=market; min=900; sec=29
      final parsedInfo = _parseRemainingReqHeader(remainingReq);
      if (parsedInfo != null) {
        _updateGroupLimiter(
          parsedInfo.group, 
          parsedInfo.remaining, 
          Duration(seconds: parsedInfo.windowSec)
        );
        
        if (AppConfig.enableTradeLog) {
          log.i('Rate limit updated: ${parsedInfo.group}=${parsedInfo.remaining} req in ${parsedInfo.windowSec}s');
        }
      }
      
      // Req-Group 헤더도 확인 (그룹 정보만)
      final reqGroup = headers['req-group']?.first ?? 
                      headers['Req-Group']?.first;
      if (reqGroup != null && _groupLimiters[reqGroup] == null) {
        _initializeGroupLimiter(reqGroup);
      }
      
    } catch (e, st) {
      log.w('Failed to parse rate limit headers: $e', e, st);
    }
  }
  
  /// Remaining-Req 헤더 파싱
  _RemainingReqInfo? _parseRemainingReqHeader(String header) {
    try {
      final parts = header.split(';').map((p) => p.trim()).toList();
      String? group;
      int? remaining;
      int? windowSec;
      
      for (final part in parts) {
        final kv = part.split('=');
        if (kv.length != 2) continue;
        
        final key = kv[0].trim().toLowerCase();
        final value = kv[1].trim();
        
        switch (key) {
          case 'group':
            group = value;
            break;
          case 'min':
          case 'remaining':
            remaining = int.tryParse(value);
            break;
          case 'sec':
          case 'window':
            windowSec = int.tryParse(value);
            break;
        }
      }
      
      if (group != null && remaining != null && windowSec != null) {
        return _RemainingReqInfo(group, remaining, windowSec);
      }
    } catch (e) {
      log.w('Failed to parse Remaining-Req header: $header, error: $e');
    }
    return null;
  }
  
  /// 그룹별 레이트리밋 초기화
  void _initializeGroupLimiter(String group) {
    final maxRequests = AppConfig.getRateLimitForGroup(group);
    _groupLimiters[group] = _GroupRateLimiter(
      group: group,
      maxRequests: maxRequests,
      period: _defaultPeriod,
    );
    
    if (AppConfig.enableTradeLog) {
      log.d('Initialized rate limiter for group: $group ($maxRequests rps)');
    }
  }
  
  /// 그룹별 레이트리밋 업데이트 (서버 응답 기반)
  void _updateGroupLimiter(String group, int remaining, Duration window) {
    var limiter = _groupLimiters[group];
    if (limiter == null) {
      _initializeGroupLimiter(group);
      limiter = _groupLimiters[group]!;
    }
    
    // 서버에서 받은 정보로 동적 업데이트
    limiter.updateFromServer(remaining, window);
  }
  
  /// 특정 그룹의 throttle 실행
  Future<void> throttle(String group, String path) async {
    // 그룹 리밋이 없으면 초기화
    if (!_groupLimiters.containsKey(group)) {
      _initializeGroupLimiter(group);
    }
    
    final limiter = _groupLimiters[group]!;
    await limiter.throttle(path);
  }
  
  /// 디버그 정보 제공
  Map<String, dynamic> getDebugInfo() {
    return {
      'activeGroups': _groupLimiters.keys.toList(),
      'groupStats': {
        for (final entry in _groupLimiters.entries)
          entry.key: entry.value.getStats(),
      },
      'timestamp': DateTime.now().toIso8601String(),
    };
  }
  
  /// 리소스 정리
  void dispose() {
    for (final limiter in _groupLimiters.values) {
      limiter.dispose();
    }
    _groupLimiters.clear();
  }
}

/// 헤더 파싱 결과 정보
class _RemainingReqInfo {
  final String group;
  final int remaining;
  final int windowSec;
  
  _RemainingReqInfo(this.group, this.remaining, this.windowSec);
}

/// 개별 그룹의 레이트리밋 관리자
class _GroupRateLimiter {
  final String group;
  int _maxRequests;
  final Duration _period;
  final Queue<DateTime> _timestamps = Queue<DateTime>();
  
  // 서버 기반 동적 정보
  int? _serverRemaining;
  DateTime? _serverUpdateTime;
  Duration? _serverWindow;
  
  _GroupRateLimiter({
    required this.group,
    required int maxRequests,
    required Duration period,
  }) : _maxRequests = maxRequests, _period = period;
  
  /// 서버 응답 기반 업데이트
  void updateFromServer(int remaining, Duration window) {
    _serverRemaining = remaining;
    _serverUpdateTime = DateTime.now();
    _serverWindow = window;
    
    // 서버 정보가 더 제한적이면 클라이언트 제한도 조정
    if (remaining < _maxRequests) {
      final adjustedMax = (remaining * 0.9).floor(); // 10% 여유
      if (adjustedMax > 0 && adjustedMax < _maxRequests) {
        log.i('Adjusting rate limit for $group: $_maxRequests → $adjustedMax (server: $remaining)');
        _maxRequests = adjustedMax;
      }
    }
  }
  
  /// throttle 실행
  Future<void> throttle(String path) async {
    final now = DateTime.now();
    
    // 서버 정보 기반 추가 체크
    if (_shouldWaitForServerLimit(now)) {
      final waitTime = _calculateServerWaitTime(now);
      if (waitTime > Duration.zero) {
        if (AppConfig.enableTradeLog) {
          log.d('Waiting ${waitTime.inMilliseconds}ms for server rate limit (group: $group)');
        }
        await Future.delayed(waitTime);
      }
    }
    
    // 클라이언트 사이드 레이트리밋
    _cleanOldTimestamps(now);
    
    if (_timestamps.length >= _maxRequests) {
      final oldestTime = _timestamps.first;
      final waitTime = _period - now.difference(oldestTime);
      if (waitTime > Duration.zero) {
        if (AppConfig.enableTradeLog) {
          log.d('Waiting ${waitTime.inMilliseconds}ms for client rate limit (group: $group)');
        }
        await Future.delayed(waitTime);
        _cleanOldTimestamps(DateTime.now());
      }
    }
    
    _timestamps.addLast(DateTime.now());
  }
  
  /// 서버 제한 대기 필요 여부
  bool _shouldWaitForServerLimit(DateTime now) {
    if (_serverRemaining == null || _serverUpdateTime == null || _serverWindow == null) {
      return false;
    }
    
    // 서버 정보가 5분 이상 오래됐으면 무시
    if (now.difference(_serverUpdateTime!).inMinutes > 5) {
      return false;
    }
    
    return _serverRemaining! <= 5; // 서버 잔여 요청이 5개 이하
  }
  
  /// 서버 기반 대기 시간 계산
  Duration _calculateServerWaitTime(DateTime now) {
    if (_serverUpdateTime == null || _serverWindow == null) {
      return Duration.zero;
    }
    
    final elapsed = now.difference(_serverUpdateTime!);
    final remaining = _serverWindow! - elapsed;
    
    return remaining > Duration.zero ? remaining : Duration.zero;
  }
  
  /// 오래된 타임스탬프 정리
  void _cleanOldTimestamps(DateTime now) {
    while (_timestamps.isNotEmpty && 
           now.difference(_timestamps.first) > _period) {
      _timestamps.removeFirst();
    }
  }
  
  /// 통계 정보
  Map<String, dynamic> getStats() {
    return {
      'group': group,
      'maxRequests': _maxRequests,
      'period': _period.inSeconds,
      'currentRequests': _timestamps.length,
      'serverRemaining': _serverRemaining,
      'serverLastUpdate': _serverUpdateTime?.toIso8601String(),
      'availableSlots': _maxRequests - _timestamps.length,
    };
  }
  
  void dispose() {
    _timestamps.clear();
  }
}

/// In-memory cache entry with timestamp.
class _MemCacheEntry<T> {
  final T data;
  final DateTime ts;
  _MemCacheEntry(this.data) : ts = DateTime.now();

  bool fresh(Duration dur) => DateTime.now().difference(ts) < dur;
}

/// Simple LRU cache based on insertion order, with a maxEntries limit.
class _MemCache {
  final int maxEntries;
  final Map<String, _MemCacheEntry<dynamic>> _box;

  _MemCache({this.maxEntries = 100}) : _box = <String, _MemCacheEntry<dynamic>>{};

  T? get<T>(String key, Duration dur) {
    final entry = _box[key];
    if (entry == null || !entry.fresh(dur)) return null;
    return entry.data as T;
  }

  void put<T>(String key, T data) {
    if (_box.length >= maxEntries) {
      final oldestKey = _box.keys.first;
      _box.remove(oldestKey);
    }
    _box[key] = _MemCacheEntry<T>(data);
  }

  void invalidate(String key) => _box.remove(key);

  void clear() => _box.clear();
}

/// Converts a query map into a stable, sorted query string.
/// Silently skips values that cannot be represented.
String _stableQueryString(Json? query) {
  if (query == null || query.isEmpty) return '';
  try {
    final entries = query.entries
      .where((e) => e.value != null)
      .toList()
      ..sort((a, b) => a.key.compareTo(b.key));
    final params = <String, String>{};
    for (final e in entries) {
      final v = e.value;
      if (v is List) {
        params[e.key] = v.join(',');
      } else {
        params[e.key] = v.toString();
      }
    }
    return Uri(queryParameters: params).query;
  } catch (e, st) {
    log.e('StableQueryString failed', e, st);
    return '';
  }
}

/// 🆕 응답 헤더에서 레이트리밋 정보를 파싱하는 인터셉터
class _RateLimitResponseInterceptor extends Interceptor {
  final _UpbitDynamicRateLimiter rateLimiter;
  
  _RateLimitResponseInterceptor(this.rateLimiter);
  
  @override
  void onResponse(Response response, ResponseInterceptorHandler handler) {
    // 업비트 응답 헤더에서 레이트리밋 정보 업데이트
    rateLimiter.updateFromHeaders(response.headers.map);
    handler.next(response);
  }
}

/// 🔥 완전히 재구현된 ApiClient - 업비트 백서 100% 준수
/// - 그룹별 동적 레이트리밋 (공개 30rps / 사적 8rps)
/// - Remaining-Req 헤더 실시간 파싱
/// - 서버 응답 기반 동적 슬롯 조정
class ApiClient {
  final Dio _dio;
  final _MemCache _cache;
  final _UpbitDynamicRateLimiter _rateLimiter;

  /// [apiKey], [apiSecret] 는 Upbit Open API 자격증명
  ApiClient({
    Dio? dio,
    required String apiKey,
    required String apiSecret,
    int cacheSize = 100,
  })  : _dio = dio ?? Dio(),
        _cache = _MemCache(maxEntries: cacheSize),
        _rateLimiter = _UpbitDynamicRateLimiter() {
    _dio.interceptors.addAll([
      AuthInterceptor(apiKey: apiKey, apiSecret: apiSecret),
      RetryInterceptor(dio: _dio),
      LoggingInterceptor(),
      _RateLimitResponseInterceptor(_rateLimiter), // 🆕 동적 레이트리밋 인터셉터
    ]);
  }

  /// [method]: GET, POST 등
  /// [path]: 전체 URL 또는 baseUrl 이후 경로
  /// [query]: URL 쿼리 파라미터
  /// [body]: JSON 바디
  /// [cacheDur]: null이 아닐 때 캐시 사용 (기간 지정)
  /// [rateLimitGroup]: 수동 그룹 지정 (선택적)
  Future<Result<R, NetworkException>> request<R>({
    required String method,
    required String path,
    Json? query,
    Json? body,
    Duration? cacheDur,
    String? rateLimitGroup,
  }) async {
    // 🔥 업비트 백서 기준 그룹별 동적 레이트리밋 적용
    final group = rateLimitGroup ?? AppConfig.getGroupFromPath(path);
    await _rateLimiter.throttle(group, path);

    String? cacheKey;
    if (cacheDur != null) {
      final qstr = _stableQueryString(query);
      cacheKey = '$method|$path|$qstr';
      final cached = _cache.get<R>(cacheKey, cacheDur);
      if (cached != null) {
        return Ok(cached);
      }
    }

    try {
      final response = await _dio.request<R>(
        path,
        queryParameters: query,
        data: body,
        options: Options(method: method),
      );

      final data = response.data;
      if (cacheKey != null && data != null) {
        _cache.put<R>(cacheKey, data as R);
      }

      return Ok(data as R);
    } on DioException catch (dioErr) {
      return Err(NetworkException.fromDio(dioErr));
    } catch (e, st) {
      log.e('ApiClient unexpected error', e, st);
      final ex = e is Exception ? e : Exception(e.toString());
      return Err(NetworkException(e.toString(), originalException: ex));
    }
  }
  
  /// 🆕 레이트리밋 디버그 정보 조회
  Map<String, dynamic> getRateLimitDebugInfo() {
    return _rateLimiter.getDebugInfo();
  }
  
  /// 🆕 리소스 정리
  void dispose() {
    _rateLimiter.dispose();
    _cache.clear();
  }
}