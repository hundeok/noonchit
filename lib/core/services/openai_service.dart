// core/services/openai_service.dart
// 🤖 OpenAI GPT 연동 서비스 - 바텀라인 생성

import 'dart:async';
import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart';
import 'package:http/http.dart' as http;

import '../utils/bottom_line_constants.dart';
import '../utils/logger.dart';
import '../../domain/entities/bottom_line.dart';

// ══════════════════════════════════════════════════════════════════════════════
// 🔧 OpenAI API 응답 모델들
// ══════════════════════════════════════════════════════════════════════════════

/// OpenAI API 응답 모델
@immutable
class OpenAIResponse {
  final List<String> headlines;
  final String model;
  final int tokensUsed;
  final Duration processingTime;
  final bool isFromCache;

  const OpenAIResponse({
    required this.headlines,
    required this.model,
    required this.tokensUsed,
    required this.processingTime,
    this.isFromCache = false,
  });

  factory OpenAIResponse.fromJson(Map<String, dynamic> json, Duration processingTime) {
    final choices = json['choices'] as List<dynamic>? ?? [];
    final usage = json['usage'] as Map<String, dynamic>? ?? {};
    
    // GPT 응답에서 헤드라인 추출
    final headlines = <String>[];
    for (final choice in choices) {
      final content = choice['message']?['content'] as String? ?? '';
      if (content.isNotEmpty) {
        // 줄바꿈으로 분리된 헤드라인들 파싱
        final lines = content.split('\n')
          .map((line) => line.trim())
          .where((line) => line.isNotEmpty && !line.startsWith('//'))
          .toList();
        headlines.addAll(lines);
      }
    }
    
    return OpenAIResponse(
      headlines: headlines,
      model: json['model'] as String? ?? 'unknown',
      tokensUsed: usage['total_tokens'] as int? ?? 0,
      processingTime: processingTime,
    );
  }

  /// 캐시된 응답 생성
  factory OpenAIResponse.cached(List<String> headlines) {
    return OpenAIResponse(
      headlines: headlines,
      model: 'cached',
      tokensUsed: 0,
      processingTime: Duration.zero,
      isFromCache: true,
    );
  }

  @override
  String toString() {
    return 'OpenAIResponse(${headlines.length} headlines, $model, $tokensUsed tokens, ${processingTime.inMilliseconds}ms, cached: $isFromCache)';
  }
}

/// OpenAI API 에러 모델
@immutable
class OpenAIError {
  final String message;
  final String? code;
  final int? statusCode;
  final bool isRetryable;

  const OpenAIError({
    required this.message,
    this.code,
    this.statusCode,
    this.isRetryable = false,
  });

  factory OpenAIError.fromJson(Map<String, dynamic> json) {
    final error = json['error'] as Map<String, dynamic>? ?? {};
    
    return OpenAIError(
      message: error['message'] as String? ?? 'Unknown error',
      code: error['code'] as String?,
      statusCode: json['status_code'] as int?,
      isRetryable: _isRetryableError(error['code'] as String?),
    );
  }

  static bool _isRetryableError(String? code) {
    // 재시도 가능한 에러 코드들
    const retryableCodes = [
      'rate_limit_exceeded',
      'server_error',
      'timeout',
      'insufficient_quota',
    ];
    return code != null && retryableCodes.contains(code);
  }

  @override
  String toString() {
    return 'OpenAIError($code: $message, retryable: $isRetryable)';
  }
}

// ══════════════════════════════════════════════════════════════════════════════
// 🤖 OpenAI 서비스 메인 클래스
// ══════════════════════════════════════════════════════════════════════════════

/// OpenAI GPT 기반 바텀라인 생성 서비스
class OpenAIService {
  // 🔑 API 설정
  static const String _baseUrl = 'https://api.openai.com/v1';
  static const String _chatEndpoint = '/chat/completions';
  static const String _model = 'gpt-4o-mini'; // 비용 효율적 모델
  static const int _maxRetries = 3;
  
  // 📊 통계 및 캐시
  final Map<String, List<String>> _responseCache = {};
  final Map<String, DateTime> _cacheTimestamps = {};
  int _totalRequests = 0;
  int _successfulRequests = 0;
  int _cachedResponses = 0;
  int _failedRequests = 0;
  Duration _totalResponseTime = const Duration();
  
  // 🔧 HTTP 클라이언트
  late final http.Client _httpClient;
  
  /// API 키 (환경변수에서 가져오기)
  final String _apiKey;
  
  OpenAIService({String? apiKey}) 
    : _apiKey = apiKey ?? _getApiKeyFromEnvironment(),
      _httpClient = http.Client() {
    
    if (_apiKey.isEmpty) {
      log.w('⚠️ OpenAI API key not found. Service will use fallback mode.');
    }
    
    if (BottomLineConstants.enableAILogging) {
      log.i('🤖 OpenAI Service initialized with gpt-4o-mini');
    }
  }

  static String _getApiKeyFromEnvironment() {
    // .env 파일에서 API 키 로드
    try {
      return dotenv.env['OPENAI_API_KEY'] ?? '';
    } catch (e) {
      log.e('Failed to load .env file: $e');
      return '';
    }
  }

  // ══════════════════════════════════════════════════════════════════════════════
  // 🎯 메인 바텀라인 생성 메서드
  // ══════════════════════════════════════════════════════════════════════════════

  /// 인사이트 목록을 ESPN 스타일 바텀라인으로 변환
  Future<List<String>> generateBottomLines(List<CandidateInsight> insights) async {
    if (insights.isEmpty) {
      return _getFallbackMessages();
    }
    
    if (_apiKey.isEmpty) {
      log.w('🛡️ No API key - using fallback mode');
      return _generateFallbackFromInsights(insights);
    }
    
    try {
      // 🔍 캐시 확인
      final cacheKey = _generateCacheKey(insights);
      final cachedResponse = _getFromCache(cacheKey);
      if (cachedResponse != null) {
        _cachedResponses++;
        return cachedResponse;
      }
      
      // 🤖 AI 호출 (재시도 로직 포함)
      final response = await _callOpenAIWithRetry(insights);
      
      // 📝 응답 처리
      final headlines = _processResponse(response, insights);
      
      // 💾 캐시 저장
      _saveToCache(cacheKey, headlines);
      
      // 📊 통계 업데이트
      _updateStats(true, response.processingTime);
      
      if (BottomLineConstants.enableAILogging) {
        log.d('🤖 Generated ${headlines.length} headlines: $response');
      }
      
      return headlines;
      
    } catch (e, stackTrace) {
      log.e('🚨 OpenAI generation failed: $e', e, stackTrace);
      
      _updateStats(false, const Duration());
      
      // 실패 시 템플릿 기반 대체
      return _generateFallbackFromInsights(insights);
    }
  }

  /// 재시도 로직이 포함된 OpenAI API 호출
  Future<OpenAIResponse> _callOpenAIWithRetry(List<CandidateInsight> insights) async {
    Exception? lastException;
    
    for (int retry = 0; retry < _maxRetries; retry++) {
      try {
        if (retry > 0) {
          // 지수 백오프 대기
          final delay = Duration(seconds: (retry * 2));
          await Future.delayed(delay);
          log.d('🔄 Retrying OpenAI call (${retry + 1}/$_maxRetries)');
        }
        
        return await _callOpenAI(insights);
        
      } catch (e) {
        lastException = e is Exception ? e : Exception('$e');
        
        // 재시도 불가능한 에러면 즉시 종료
        if (e.toString().contains('invalid_api_key') || 
            e.toString().contains('insufficient_quota')) {
          break;
        }
        
        log.w('⚠️ OpenAI call failed (attempt ${retry + 1}): $e');
      }
    }
    
    throw lastException ?? Exception('Max retries exceeded');
  }

  /// OpenAI API 호출
  Future<OpenAIResponse> _callOpenAI(List<CandidateInsight> insights) async {
    final stopwatch = Stopwatch()..start();
    
    try {
      // 📝 프롬프트 생성 (최적화된 버전)
      final prompt = _buildOptimizedPrompt(insights);
      
      // 🌐 HTTP 요청
      final response = await _httpClient
        .post(
          Uri.parse('$_baseUrl$_chatEndpoint'),
          headers: _buildHeaders(),
          body: jsonEncode(_buildRequestBody(prompt)),
        )
        .timeout(const Duration(seconds: 30));
      
      stopwatch.stop();
      
      // 📊 응답 처리
      if (response.statusCode == 200) {
        final jsonResponse = jsonDecode(response.body) as Map<String, dynamic>;
        return OpenAIResponse.fromJson(jsonResponse, stopwatch.elapsed);
      } else {
        final errorJson = jsonDecode(response.body) as Map<String, dynamic>;
        final error = OpenAIError.fromJson(errorJson);
        throw Exception('OpenAI API error: $error');
      }
      
    } on TimeoutException {
      stopwatch.stop();
      throw Exception('OpenAI API timeout after 30s');
    } on http.ClientException catch (e) {
      stopwatch.stop();
      throw Exception('Network error: $e');
    }
  }

  /// 최적화된 프롬프트 생성 (토큰 절약)
  String _buildOptimizedPrompt(List<CandidateInsight> insights) {
    final hasUrgent = insights.any((i) => i.isHighPriority);
    
    final prompt = StringBuffer();
    
    // 간결한 시스템 프롬프트
    prompt.writeln('ESPN 스타일 암호화폐 속보를 생성하세요.');
    prompt.writeln('요구사항: 15-30단어, 구체적 수치 포함, 이모지 1-2개');
    
    if (hasUrgent) {
      prompt.writeln('⚠️ 긴급 상황 포함 - 강렬하게 작성');
    }
    
    prompt.writeln('\n예시:');
    prompt.writeln('🔥 BTC 3분 연속 상승세, 1600만원 돌파');
    prompt.writeln('⚡ AI 섹터 거래량 전일比 340% 폭증');
    
    // 인사이트 데이터 (간결하게)
    prompt.writeln('\n현재 인사이트:');
    for (int i = 0; i < insights.length && i < 5; i++) { // 최대 5개만
      final insight = insights[i];
      final priority = insight.isHighPriority ? '[긴급]' : '';
      prompt.writeln('${i + 1}. $priority${insight.populatedTemplate}');
    }
    
    prompt.writeln('\n위를 ESPN 스타일 헤드라인 ${insights.length.clamp(1, 5)}개로 변환:');
    
    return prompt.toString();
  }

  /// HTTP 헤더 생성
  Map<String, String> _buildHeaders() {
    return {
      'Content-Type': 'application/json',
      'Authorization': 'Bearer $_apiKey',
      'User-Agent': 'BottomLine/1.0.0',
    };
  }

  /// 요청 본문 생성 (최적화된 설정)
  Map<String, dynamic> _buildRequestBody(String prompt) {
    return {
      'model': _model,
      'messages': [
        {
          'role': 'system',
          'content': '전문 금융 뉴스 헤드라인 작성자',
        },
        {
          'role': 'user',
          'content': prompt,
        },
      ],
      'max_tokens': 300, // 토큰 절약
      'temperature': 0.7,
      'top_p': 0.9,
      'frequency_penalty': 0.3,
      'presence_penalty': 0.1,
    };
  }

  // ══════════════════════════════════════════════════════════════════════════════
  // 🔄 응답 처리 및 후처리
  // ══════════════════════════════════════════════════════════════════════════════

  /// OpenAI 응답 처리 및 검증
  List<String> _processResponse(OpenAIResponse response, List<CandidateInsight> insights) {
    if (response.headlines.isEmpty) {
      log.w('⚠️ OpenAI returned empty headlines');
      return _generateFallbackFromInsights(insights);
    }
    
    // 헤드라인 정제 및 검증
    final processedHeadlines = response.headlines
      .map((headline) => _sanitizeHeadline(headline))
      .where((headline) => _isValidHeadline(headline))
      .take(5) // 최대 5개
      .toList();
    
    // 부족한 경우 템플릿으로 보완
    while (processedHeadlines.length < 3 && 
           processedHeadlines.length < insights.length) {
      final remainingInsights = insights.skip(processedHeadlines.length).toList();
      if (remainingInsights.isNotEmpty) {
        processedHeadlines.add(remainingInsights.first.populatedTemplate);
      } else {
        break;
      }
    }
    
    return processedHeadlines;
  }

  /// 헤드라인 정제 (개선된 파싱)
  String _sanitizeHeadline(String headline) {
    // 불필요한 문자 제거 (개선된 정규식)
    String cleaned = headline
      .replaceAll(RegExp(r'^[-*\d.]+\s*'), '') // 모든 bullet point 제거
      .replaceAll(RegExp(r'["""]'), '"')       // 따옴표 통일
      .trim();
    
    // 길이 제한
    if (cleaned.length > 100) {
      cleaned = '${cleaned.substring(0, 97)}...';
    }
    
    return cleaned;
  }

  /// 헤드라인 유효성 검증
  bool _isValidHeadline(String headline) {
    // 최소 길이 체크
    if (headline.length < 10) {
      return false;
    }
    
    // 금지된 단어나 패턴 체크
    const forbiddenPatterns = [
      'error', 'failed', 'undefined', 'null', '####', '***',
    ];
    
    final lowerHeadline = headline.toLowerCase();
    for (final pattern in forbiddenPatterns) {
      if (lowerHeadline.contains(pattern)) {
        return false;
      }
    }
    
    // 기본적인 한글/영어/숫자 포함 여부
    if (!RegExp(r'[가-힣a-zA-Z0-9]').hasMatch(headline)) {
      return false;
    }
    
    return true;
  }

  // ══════════════════════════════════════════════════════════════════════════════
  // 💾 캐싱 시스템
  // ══════════════════════════════════════════════════════════════════════════════

  /// 캐시 키 생성
  String _generateCacheKey(List<CandidateInsight> insights) {
    final keyData = insights
      .take(3) // 상위 3개만 사용
      .map((i) => '${i.id}_${i.finalScore.toStringAsFixed(1)}')
      .join('|');
    return keyData.hashCode.toString();
  }

  /// 캐시에서 조회
  List<String>? _getFromCache(String key) {
    final cached = _responseCache[key];
    final timestamp = _cacheTimestamps[key];
    
    if (cached != null && timestamp != null) {
      // 3분 이내 캐시만 유효 (더 짧게)
      final age = DateTime.now().difference(timestamp);
      if (age.inMinutes < 3) {
        return cached;
      } else {
        _responseCache.remove(key);
        _cacheTimestamps.remove(key);
      }
    }
    
    return null;
  }

  /// 캐시에 저장
  void _saveToCache(String key, List<String> headlines) {
    _responseCache[key] = headlines;
    _cacheTimestamps[key] = DateTime.now();
    
    // 캐시 크기 제한 (최대 20개)
    if (_responseCache.length > 20) {
      final oldestKey = _cacheTimestamps.entries
        .reduce((a, b) => a.value.isBefore(b.value) ? a : b)
        .key;
      
      _responseCache.remove(oldestKey);
      _cacheTimestamps.remove(oldestKey);
    }
  }

  // ══════════════════════════════════════════════════════════════════════════════
  // 🛡️ 에러 처리 및 대체 시스템
  // ══════════════════════════════════════════════════════════════════════════════

  /// 템플릿 기반 대체 헤드라인 생성
  List<String> _generateFallbackFromInsights(List<CandidateInsight> insights) {
    if (BottomLineConstants.enableAILogging) {
      log.d('🛡️ Generating fallback headlines from ${insights.length} insights');
    }
    
    return insights
      .take(3) // 최대 3개
      .map((insight) => _enhanceTemplate(insight.populatedTemplate))
      .toList();
  }

  /// 템플릿 향상 (이모지 추가)
  String _enhanceTemplate(String template) {
    // 이미 이모지가 있으면 그대로
    if (RegExp(r'[\u{1F600}-\u{1F64F}]|[\u{1F300}-\u{1F5FF}]|[\u{1F680}-\u{1F6FF}]|[\u{1F1E0}-\u{1F1FF}]', 
               unicode: true).hasMatch(template)) {
      return template;
    }
    
    // 키워드에 따라 이모지 추가
    if (template.contains('대형매수') || template.contains('고액거래')) {
      return '🔥 $template';
    } else if (template.contains('거래량') || template.contains('볼륨')) {
      return '⚡ $template';
    } else if (template.contains('급등') || template.contains('상승')) {
      return '📈 $template';
    } else if (template.contains('섹터') || template.contains('자금')) {
      return '💫 $template';
    } else {
      return '📊 $template';
    }
  }

  /// 기본 대체 메시지들
  List<String> _getFallbackMessages() {
    const messages = [
      '📊 암호화폐 시장 실시간 모니터링 중',
      '💰 고액거래 패턴 분석 진행 중', 
      '⚡ 거래량 급증 코인 스캔 중',
    ];
    
    return messages.toList();
  }

  // ══════════════════════════════════════════════════════════════════════════════
  // 📊 통계 및 모니터링
  // ══════════════════════════════════════════════════════════════════════════════

  /// 통계 업데이트
  void _updateStats(bool success, Duration responseTime) {
    _totalRequests++;
    _totalResponseTime += responseTime;
    
    if (success) {
      _successfulRequests++;
    } else {
      _failedRequests++;
    }
  }

  /// 서비스 통계 조회
  Map<String, dynamic> getStats() {
    final successRate = _totalRequests > 0 
      ? _successfulRequests / _totalRequests 
      : 0.0;
    
    final avgResponseTime = _totalRequests > 0
      ? _totalResponseTime.inMilliseconds / _totalRequests
      : 0.0;
    
    final cacheHitRate = _totalRequests > 0
      ? _cachedResponses / _totalRequests
      : 0.0;
    
    return {
      'total_requests': _totalRequests,
      'successful_requests': _successfulRequests,
      'failed_requests': _failedRequests,
      'cached_responses': _cachedResponses,
      'success_rate': '${(successRate * 100).toStringAsFixed(1)}%',
      'cache_hit_rate': '${(cacheHitRate * 100).toStringAsFixed(1)}%',
      'avg_response_time_ms': avgResponseTime.toStringAsFixed(1),
      'cache_size': _responseCache.length,
      'api_key_configured': _apiKey.isNotEmpty,
      'model': _model,
    };
  }

  /// 연결 테스트
  Future<bool> testConnection() async {
    if (_apiKey.isEmpty) {
      log.w('⚠️ No API key configured');
      return false;
    }
    
    try {
      final testInsights = [
        CandidateInsight(
          id: 'test',
          template: 'BTC 테스트 거래 감지',
          score: 1.5,
          weight: 1.0,
          templateVars: {'market': 'KRW-BTC'},
          timestamp: DateTime.now(),
        ),
      ];
      
      final result = await generateBottomLines(testInsights);
      return result.isNotEmpty;
      
    } catch (e) {
      log.e('🚨 OpenAI connection test failed: $e');
      return false;
    }
  }

  /// 캐시 정리
  void clearCache() {
    _responseCache.clear();
    _cacheTimestamps.clear();
    
    if (BottomLineConstants.enableAILogging) {
      log.d('🗑️ OpenAI cache cleared');
    }
  }

  /// 리소스 정리
  void dispose() {
    _httpClient.close();
    clearCache();
    
    if (BottomLineConstants.enableAILogging) {
      log.d('🛑 OpenAI Service disposed');
    }
  }
}