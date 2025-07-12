// core/utils/bottom_line_insight_engine.dart
// 🧠 바텀라인 인사이트 엔진 - 룰 기반 시장 패턴 분석
import 'dart:math' as math;
import 'package:flutter/foundation.dart';
import '../../domain/entities/bottom_line.dart';
import 'bottom_line_constants.dart';
import 'logger.dart';

// ══════════════════════════════════════════════════════════════════════════════
// 🎯 인사이트 생성 결과
// ══════════════════════════════════════════════════════════════════════════════

/// 인사이트 생성 결과 (성공/실패 정보 포함)
@immutable
class InsightGenerationResult {
  final List<CandidateInsight> insights;
  final List<String> triggeredRules;
  final List<String> failedRules;
  final Duration processingTime;
  final Map<String, dynamic> diagnostics;

  const InsightGenerationResult({
    required this.insights,
    required this.triggeredRules,
    required this.failedRules,
    required this.processingTime,
    required this.diagnostics,
  });

  /// 성공적으로 생성된 인사이트 개수
  int get successCount => insights.length;

  /// 실행된 룰 개수
  int get totalRulesExecuted => triggeredRules.length + failedRules.length;

  /// 성공률
  double get successRate => totalRulesExecuted > 0
      ? triggeredRules.length / totalRulesExecuted
      : 0.0;

  /// 고우선순위 인사이트 개수
  int get highPriorityCount => insights.where((i) => i.isHighPriority).length;

  @override
  String toString() {
    return 'InsightResult($successCount insights, ${triggeredRules.length}/$totalRulesExecuted rules, ${processingTime.inMilliseconds}ms)';
  }
}

// ══════════════════════════════════════════════════════════════════════════════
// 🧠 인사이트 엔진 메인 클래스
// ══════════════════════════════════════════════════════════════════════════════

/// 바텀라인 인사이트 엔진 - 룰 기반 패턴 분석 및 인사이트 생성
class BottomLineInsightEngine {
  // 📊 성능 통계
  int _totalExecutions = 0;
  int _totalInsightsGenerated = 0;
  int _totalRulesExecuted = 0;
  Duration _totalProcessingTime = Duration.zero;
  final Map<String, int> _ruleExecutionCount = {};
  final Map<String, int> _ruleSuccessCount = {};
  final Map<String, Duration> _ruleProcessingTime = {};

  // 🔍 룰 실행 통계
  DateTime? _lastExecution;
  MarketSnapshot? _lastSnapshot;

  /// 모든 등록된 룰들 (RuleRegistry에서 가져옴)
  List<InsightRule> get allRules => RuleRegistry.allRules;

  /// 활성화된 룰들만
  List<InsightRule> get activeRules => allRules
      .where((rule) => BottomLineConstants.isRuleEnabled(rule.id))
      .toList();

  // ══════════════════════════════════════════════════════════════════════════════
  // 🎯 메인 인사이트 생성 메서드
  // ══════════════════════════════════════════════════════════════════════════════

  /// 시장 스냅샷에서 인사이트 생성 (메인 엔트리 포인트)
  InsightGenerationResult generateInsights(MarketSnapshot snapshot) {
    final stopwatch = Stopwatch()..start();
    
    try {
      // 📊 실행 통계 업데이트
      _totalExecutions++;
      _lastExecution = DateTime.now();
      _lastSnapshot = snapshot;

      // 🔍 스냅샷 검증
      final validation = _validateSnapshot(snapshot);
      if (!validation['isValid']) {
        return _createEmptyResult(
          stopwatch.elapsed,
          'Invalid snapshot: ${validation['reason']}',
        );
      }

      // 🧠 룰 실행
      final results = _executeAllRules(snapshot);

      // 📈 인사이트 후처리
      final processedInsights = _postProcessInsights(results['insights'], snapshot);

      // 📊 통계 업데이트
      _updateStats(processedInsights, results, stopwatch.elapsed);

      stopwatch.stop();

      final result = InsightGenerationResult(
        insights: processedInsights,
        triggeredRules: results['triggeredRules'],
        failedRules: results['failedRules'],
        processingTime: stopwatch.elapsed,
        diagnostics: _generateDiagnostics(snapshot, results),
      );

      if (BottomLineConstants.enableLogging && processedInsights.isNotEmpty) {
        log.d('🧠 Generated ${processedInsights.length} insights: ${processedInsights.map((i) => '${i.id}(${i.finalScore.toStringAsFixed(1)})').join(', ')}');
      }

      return result;
    } catch (e, stackTrace) {
      stopwatch.stop();
      log.e('🚨 Insight generation failed: $e', e, stackTrace);
      return _createErrorResult(stopwatch.elapsed, e.toString());
    }
  }

  /// 모든 활성 룰 실행
  Map<String, dynamic> _executeAllRules(MarketSnapshot snapshot) {
    final insights = <CandidateInsight>[];
    final triggeredRules = <String>[];
    final failedRules = <String>[];

    for (final rule in activeRules) {
      try {
        final ruleStopwatch = Stopwatch()..start();

        // 🔍 룰 실행 (타임아웃 체크)
        final insight = _executeRuleWithTimeout(rule, snapshot);

        ruleStopwatch.stop();

        // 📊 룰별 통계 업데이트
        _updateRuleStats(rule.id, ruleStopwatch.elapsed, insight != null);

        if (insight != null) {
          insights.add(insight);
          triggeredRules.add(rule.id);

          if (BottomLineConstants.enableDetailedLogging) {
            log.d('✅ Rule ${rule.id} triggered: score=${insight.finalScore.toStringAsFixed(2)}');
          }
        } else {
          if (BottomLineConstants.enableDetailedLogging) {
            log.d('❌ Rule ${rule.id} not triggered');
          }
        }
      } catch (e) {
        failedRules.add(rule.id);
        log.w('🚨 Rule ${rule.id} failed: $e');
      }
    }

    return {
      'insights': insights,
      'triggeredRules': triggeredRules,
      'failedRules': failedRules,
    };
  }

  /// 타임아웃이 있는 룰 실행
  CandidateInsight? _executeRuleWithTimeout(InsightRule rule, MarketSnapshot snapshot) {
    final timeout = const Duration(milliseconds: BottomLineConstants.ruleExecutionTimeoutMs);

    try {
      // 간단한 타임아웃 구현 (Isolate 사용 안 함)
      final startTime = DateTime.now();
      final insight = rule.generateInsight(snapshot);
      final elapsed = DateTime.now().difference(startTime);

      if (elapsed > timeout) {
        log.w('⏱️ Rule ${rule.id} took ${elapsed.inMilliseconds}ms (timeout: ${timeout.inMilliseconds}ms)');
      }

      return insight;
    } catch (e) {
      log.w('🚨 Rule ${rule.id} execution error: $e');
      return null;
    }
  }

  // ══════════════════════════════════════════════════════════════════════════════
  // 📈 인사이트 후처리 & 최적화
  // ══════════════════════════════════════════════════════════════════════════════

  /// 생성된 인사이트들 후처리 (정렬, 필터링, 최적화)
  List<CandidateInsight> _postProcessInsights(List<CandidateInsight> insights, MarketSnapshot snapshot) {
    if (insights.isEmpty) return insights;

    // 🔍 1. 중복 제거 (같은 시장/패턴)
    final deduplicated = _removeDuplicateInsights(insights);

    // 📊 2. 점수 정규화 및 조정
    final normalized = _normalizeInsightScores(deduplicated, snapshot);

    // 📈 3. 우선순위 정렬 (점수 높은 순)
    normalized.sort((a, b) => b.finalScore.compareTo(a.finalScore));

    // 🎯 4. 상위 N개만 선택 (AI 비용 절약)
    final selected = normalized.take(BottomLineConstants.maxInsightsPerSnapshot).toList();

    // 🔥 5. 긴급 인사이트 식별 및 마킹
    final marked = _markUrgentInsights(selected);

    if (BottomLineConstants.enableDetailedLogging) {
      log.d('📈 Post-processed insights: ${insights.length} → ${marked.length}');
    }

    return marked;
  }

  /// 중복 인사이트 제거
  List<CandidateInsight> _removeDuplicateInsights(List<CandidateInsight> insights) {
    final uniqueInsights = <String, CandidateInsight>{};

    for (final insight in insights) {
      // 템플릿 변수에서 시장 정보 추출
      final market = insight.templateVars['market'] as String? ?? '';
      final ruleType = insight.id.split('_').first;

      // 키: 룰타입_시장 (예: smart_money_KRW-BTC)
      final key = '${ruleType}_$market';

      // 더 높은 점수의 인사이트만 유지
      if (!uniqueInsights.containsKey(key) ||
          uniqueInsights[key]!.finalScore < insight.finalScore) {
        uniqueInsights[key] = insight;
      }
    }

    return uniqueInsights.values.toList();
  }

  /// 인사이트 점수 정규화
  List<CandidateInsight> _normalizeInsightScores(List<CandidateInsight> insights, MarketSnapshot snapshot) {
    if (insights.isEmpty) return insights;

    // 현재 최고점과 최저점
    final scores = insights.map((i) => i.finalScore).toList();
    final maxScore = scores.reduce(math.max);
    final minScore = scores.reduce(math.min);

    // 점수 범위가 너무 좁으면 정규화 생략
    if (maxScore - minScore < 0.5) return insights;

    // 컨텍스트 기반 보정
    final marketContext = _analyzeMarketContext(snapshot);

    return insights.map((insight) {
      double adjustedScore = insight.finalScore;

      // 시장 상황에 따른 점수 조정
      if (marketContext['isVolatile']) {
        // 변동성 높은 상황에서는 급등/급락 인사이트 강화
        if (insight.id.contains('surge') || insight.id.contains('spike')) {
          adjustedScore *= 1.2;
        }
      }

      if (marketContext['isHighVolume']) {
        // 고거래량 상황에서는 스마트머니 인사이트 강화
        if (insight.id.contains('smart_money')) {
          adjustedScore *= 1.1;
        }
      }

      // 정규화 (0.0 ~ 5.0 범위)
      adjustedScore = math.min(adjustedScore, BottomLineConstants.maxInsightScore);

      return CandidateInsight(
        id: insight.id,
        template: insight.template,
        score: adjustedScore,
        weight: insight.weight,
        templateVars: insight.templateVars,
        timestamp: insight.timestamp,
        isUrgent: adjustedScore >= BottomLineConstants.urgentInsightThreshold,
      );
    }).toList();
  }

  /// 긴급 인사이트 마킹
  List<CandidateInsight> _markUrgentInsights(List<CandidateInsight> insights) {
    return insights.map((insight) {
      final isUrgent = insight.finalScore >= BottomLineConstants.urgentInsightThreshold;

      if (isUrgent && !insight.isUrgent) {
        return CandidateInsight(
          id: insight.id,
          template: insight.template,
          score: insight.score,
          weight: insight.weight,
          templateVars: insight.templateVars,
          timestamp: insight.timestamp,
          isUrgent: true,
        );
      }

      return insight;
    }).toList();
  }

  // ══════════════════════════════════════════════════════════════════════════════
  // 🔍 시장 컨텍스트 분석
  // ══════════════════════════════════════════════════════════════════════════════

  /// 시장 상황 분석 (점수 조정용)
  Map<String, dynamic> _analyzeMarketContext(MarketSnapshot snapshot) {
    // 변동성 분석
    final priceChanges = snapshot.priceDelta.values.where((change) => change.abs() > 0).toList();
    final avgPriceChange = priceChanges.isNotEmpty
        ? priceChanges.map((c) => c.abs()).reduce((a, b) => a + b) / priceChanges.length
        : 0.0;
    final isVolatile = avgPriceChange > 5.0; // 평균 5% 이상 변동

    // 거래량 분석
    final totalVolume = snapshot.topVolumes.fold<double>(0, (sum, v) => sum + v.totalVolume);
    final isHighVolume = totalVolume > 1000000000; // 10억 이상

    // 급등/급락 코인 개수
    final surgingCount = snapshot.surges.where((s) => s.changePercent > 10).length;
    final plungingCount = snapshot.surges.where((s) => s.changePercent < -10).length;

    // 고액거래 활성도
    final largeTradeCount = snapshot.topTrades
        .where((t) => t.total >= BottomLineConstants.largeTradeThreshold)
        .length;

    return {
      'isVolatile': isVolatile,
      'isHighVolume': isHighVolume,
      'avgPriceChange': avgPriceChange,
      'totalVolume': totalVolume,
      'surgingCount': surgingCount,
      'plungingCount': plungingCount,
      'largeTradeCount': largeTradeCount,
      'marketMood': _classifyMarketMood(surgingCount, plungingCount, avgPriceChange),
    };
  }

  /// 시장 분위기 분류
  String _classifyMarketMood(int surgingCount, int plungingCount, double avgPriceChange) {
    if (surgingCount > plungingCount * 2 && avgPriceChange > 3.0) {
      return 'bullish'; // 강세
    } else if (plungingCount > surgingCount * 2 && avgPriceChange > 3.0) {
      return 'bearish'; // 약세
    } else if (avgPriceChange > 5.0) {
      return 'volatile'; // 변동성
    } else {
      return 'neutral'; // 중립
    }
  }

  // ══════════════════════════════════════════════════════════════════════════════
  // 📊 통계 및 검증
  // ══════════════════════════════════════════════════════════════════════════════

  /// 스냅샷 유효성 검증
  Map<String, dynamic> _validateSnapshot(MarketSnapshot snapshot) {
    // 기본 데이터 존재 여부
    if (snapshot.topTrades.isEmpty &&
        snapshot.topVolumes.isEmpty &&
        snapshot.surges.isEmpty) {
      return {
      'isValid': false, 
      'reason': 'No data available'
    };
    }

    // 타임스탬프 검증 (너무 오래된 데이터)
    final age = DateTime.now().difference(snapshot.timestamp);
    if (age.inMinutes > 10) {
      return {
      'isValid': false, 
      'reason': 'Data too old: ${age.inMinutes} minutes'
    };
    }

    // 데이터 일관성 검증
    final inconsistencies = <String>[];

    // 가격 변화율 검증 (-100% ~ +1000% 범위)
    for (final entry in snapshot.priceDelta.entries) {
      if (entry.value < -100 || entry.value > 1000) {
        inconsistencies.add('Invalid price change: ${entry.key} ${entry.value}%');
      }
    }

    // 볼륨 변화율 검증 (-100% ~ +10000% 범위)
    for (final entry in snapshot.volChangePct.entries) {
      if (entry.value < -100 || entry.value > 10000) {
        inconsistencies.add('Invalid volume change: ${entry.key} ${entry.value}%');
      }
    }

    if (inconsistencies.isNotEmpty) {
      log.w('⚠️ Snapshot inconsistencies: ${inconsistencies.join(', ')}');
    }

    return {
      'isValid': true, 
      'inconsistencies': inconsistencies
    };
  }

  /// 룰별 실행 통계 업데이트
  void _updateRuleStats(String ruleId, Duration elapsed, bool success) {
    _ruleExecutionCount[ruleId] = (_ruleExecutionCount[ruleId] ?? 0) + 1;
    if (success) {
      _ruleSuccessCount[ruleId] = (_ruleSuccessCount[ruleId] ?? 0) + 1;
    }

    final currentTime = _ruleProcessingTime[ruleId] ?? Duration.zero;
    _ruleProcessingTime[ruleId] = currentTime + elapsed;
    _totalRulesExecuted++;
  }

  /// 전체 통계 업데이트
  void _updateStats(List<CandidateInsight> insights, Map<String, dynamic> results, Duration elapsed) {
    _totalInsightsGenerated += insights.length;
    _totalProcessingTime += elapsed;
  }

  /// 진단 정보 생성
  Map<String, dynamic> _generateDiagnostics(MarketSnapshot snapshot, Map<String, dynamic> results) {
    final marketContext = _analyzeMarketContext(snapshot);

    return {
      'snapshot_age_seconds': DateTime.now().difference(snapshot.timestamp).inSeconds,
      'data_points': {
        'trades': snapshot.topTrades.length,
        'volumes': snapshot.topVolumes.length,
        'surges': snapshot.surges.length,
        'sectors': snapshot.sectorVolumes.length,
      },
      'market_context': marketContext,
      'rule_performance': _getRulePerformanceSnapshot(),
      'engine_stats': getEngineStats(),
    };
  }

  /// 빈 결과 생성
  InsightGenerationResult _createEmptyResult(Duration elapsed, String reason) {
    return InsightGenerationResult(
      insights: const <CandidateInsight>[],
      triggeredRules: const <String>[],
      failedRules: const <String>[],
      processingTime: elapsed,
      diagnostics: {'reason': reason},
    );
  }

  /// 에러 결과 생성
  InsightGenerationResult _createErrorResult(Duration elapsed, String error) {
    return InsightGenerationResult(
      insights: const <CandidateInsight>[],
      triggeredRules: const <String>[],
      failedRules: activeRules.map((r) => r.id).toList(),
      processingTime: elapsed,
      diagnostics: {'error': error},
    );
  }

  // ══════════════════════════════════════════════════════════════════════════════
  // 📊 성능 모니터링 & 통계
  // ══════════════════════════════════════════════════════════════════════════════

  /// 엔진 전체 통계
  Map<String, dynamic> getEngineStats() {
    final avgProcessingTime = _totalExecutions > 0
        ? _totalProcessingTime.inMilliseconds / _totalExecutions
        : 0.0;

    final avgInsightsPerExecution = _totalExecutions > 0
        ? _totalInsightsGenerated / _totalExecutions
        : 0.0;

    return {
      'total_executions': _totalExecutions,
      'total_insights_generated': _totalInsightsGenerated,
      'total_rules_executed': _totalRulesExecuted,
      'avg_processing_time_ms': avgProcessingTime,
      'avg_insights_per_execution': avgInsightsPerExecution,
      'last_execution': _lastExecution?.toIso8601String() ?? 'Never',
      'active_rules_count': activeRules.length,
      'total_rules_count': allRules.length,
    };
  }

  /// 룰별 성능 통계
  Map<String, dynamic> _getRulePerformanceSnapshot() {
    final performance = <String, Map<String, dynamic>>{};

    for (final ruleId in _ruleExecutionCount.keys) {
      final executions = _ruleExecutionCount[ruleId] ?? 0;
      final successes = _ruleSuccessCount[ruleId] ?? 0;
      final totalTime = _ruleProcessingTime[ruleId] ?? Duration.zero;

      performance[ruleId] = {
        'executions': executions,
        'successes': successes,
        'success_rate': executions > 0 ? successes / executions : 0.0,
        'avg_time_ms': executions > 0 ? totalTime.inMilliseconds / executions : 0.0,
        'total_time_ms': totalTime.inMilliseconds,
      };
    }

    return performance;
  }

  /// 엔진 상태 리셋
  void resetStats() {
    _totalExecutions = 0;
    _totalInsightsGenerated = 0;
    _totalRulesExecuted = 0;
    _totalProcessingTime = Duration.zero;
    _ruleExecutionCount.clear();
    _ruleSuccessCount.clear();
    _ruleProcessingTime.clear();
    _lastExecution = null;
    _lastSnapshot = null;

    if (BottomLineConstants.enableLogging) {
      log.d('📊 Insight engine stats reset');
    }
  }

  /// 상세 진단 보고서 생성 (디버깅용)
  Map<String, dynamic> generateDiagnosticReport() {
    return {
      'engine_info': {
        'version': '1.0.0',
        'initialization_time': DateTime.now().toIso8601String(),
        'rules_loaded': allRules.map((r) => r.id).toList(),
        'active_rules': activeRules.map((r) => r.id).toList(),
      },
      'performance': getEngineStats(),
      'rule_performance': _getRulePerformanceSnapshot(),
      'configuration': {
        'min_insight_score': BottomLineConstants.minInsightScore,
        'urgent_threshold': BottomLineConstants.urgentInsightThreshold,
        'max_insights_per_snapshot': BottomLineConstants.maxInsightsPerSnapshot,
        'rule_timeout_ms': BottomLineConstants.ruleExecutionTimeoutMs,
      },
      'last_snapshot_info': _lastSnapshot != null ? {
        'timestamp': _lastSnapshot!.timestamp.toIso8601String(),
        'trades_count': _lastSnapshot!.topTrades.length,
        'volumes_count': _lastSnapshot!.topVolumes.length,
        'surges_count': _lastSnapshot!.surges.length,
      } : null,
    };
  }
}