// domain/entities/bottom_line.dart
// 🔥 바텀라인 시스템 - 모든 Entity & Rule 통합

import 'package:freezed_annotation/freezed_annotation.dart';
import '../entities/trade.dart';
import '../entities/volume.dart';
import '../entities/surge.dart';

part 'bottom_line.freezed.dart';
// part 'bottom_line.g.dart'; ← 이 라인 제거

// ===== 1. 시장 스냅샷 Entity =====
@freezed
class MarketSnapshot with _$MarketSnapshot {
  const factory MarketSnapshot({
    required DateTime timestamp,
    required String timeFrame,
    required List<Trade> topTrades,           // ≥20M, 최근 50건
    required List<Volume> topVolumes,         // 활성 마켓 상위 50개
    required List<Surge> surges,              // 변화 있는 코인만
    required List<Volume> sectorVolumes,      // 주요 섹터 10개
    required Map<String, double> volChangePct,    // 볼륨 변화율
    required Map<String, double> sectorShareDelta,    // 섹터 점유율 변화 (수정됨)
    required Map<String, double> priceDelta,          // 가격 변화율 (수정됨)
  }) = _MarketSnapshot;

  // factory MarketSnapshot.fromJson(Map<String, dynamic> json) => 
  //   _$MarketSnapshotFromJson(json); ← 이 라인들 제거

  const MarketSnapshot._();

  // 델타 계산 헬퍼
  static MarketSnapshot create({
    required List<Trade> trades,
    required List<Volume> volumes,
    required List<Surge> surges,
    required List<Volume> sectors,
    MarketSnapshot? previousSnapshot,
  }) {
    final now = DateTime.now();
    
    // 볼륨 변화율 계산
    final volChangePct = <String, double>{};
    if (previousSnapshot != null) {
      for (final vol in volumes) {
        final prevVol = previousSnapshot.topVolumes
          .where((p) => p.market == vol.market)
          .firstOrNull;
        if (prevVol != null && prevVol.totalVolume > 0) {
          volChangePct[vol.market] = 
            ((vol.totalVolume - prevVol.totalVolume) / prevVol.totalVolume) * 100;
        }
      }
    }

    // 섹터 점유율 변화 계산
    final sectorShareDelta = <String, double>{};
    final totalVolume = volumes.fold<double>(0, (sum, v) => sum + v.totalVolume);
    if (previousSnapshot != null && totalVolume > 0) {
      for (final sector in sectors) {
        final currentShare = (sector.totalVolume / totalVolume) * 100;
        final prevTotalVol = previousSnapshot.topVolumes
          .fold<double>(0, (sum, v) => sum + v.totalVolume);
        if (prevTotalVol > 0) {
          final prevSector = previousSnapshot.sectorVolumes
            .where((s) => s.market == sector.market)
            .firstOrNull;
          if (prevSector != null) {
            final prevShare = (prevSector.totalVolume / prevTotalVol) * 100;
            sectorShareDelta[sector.market] = currentShare - prevShare;
          }
        }
      }
    }

    // 가격 변화율 계산
    final priceDelta = <String, double>{};
    for (final surge in surges) {
      priceDelta[surge.ticker] = surge.changePercent;
    }

    return MarketSnapshot(
      timestamp: now,
      timeFrame: 'min5', // 기본값
      topTrades: trades.take(50).toList(),
      topVolumes: volumes.take(50).toList(),
      surges: surges,
      sectorVolumes: sectors.take(10).toList(),
      volChangePct: volChangePct,
      sectorShareDelta: sectorShareDelta,
      priceDelta: priceDelta,
    );
  }

  // 스냅샷 해시 (캐싱용)
  String get hash {
    final content = [
      timestamp.millisecondsSinceEpoch,
      topTrades.length,
      topVolumes.length,
      surges.length,
      sectorVolumes.length,
    ].join('-');
    return content.hashCode.toString();
  }
}

// ===== 2. 후보 인사이트 Entity =====
@freezed
class CandidateInsight with _$CandidateInsight {
  const factory CandidateInsight({
    required String id,
    required String template,
    required double score,
    required double weight,
    required Map<String, dynamic> templateVars,
    required DateTime timestamp,
    @Default(false) bool isUrgent,
  }) = _CandidateInsight;

  // factory CandidateInsight.fromJson(Map<String, dynamic> json) => 
  //   _$CandidateInsightFromJson(json); ← 이 라인들도 제거

  const CandidateInsight._();

  // 최종 점수 (가중치 적용)
  double get finalScore => score * weight;

  // 긴급 여부 판단 (점수 2.5 이상)
  bool get isHighPriority => finalScore >= 2.5;

  // 템플릿 변수 적용
  String get populatedTemplate {
    String result = template;
    templateVars.forEach((key, value) {
      result = result.replaceAll('{$key}', value.toString());
    });
    return result;
  }
}

// ===== 3. 바텀라인 아이템 Entity =====
@freezed
class BottomLineItem with _$BottomLineItem {
  const factory BottomLineItem({
    required String headline,
    required DateTime timestamp,
    required double priority,
    required String sourceInsightId,
    @Default(false) bool isUrgent,
    @Default(18) int displayDurationSeconds,
  }) = _BottomLineItem;

  // factory BottomLineItem.fromJson(Map<String, dynamic> json) => 
  //   _$BottomLineItemFromJson(json); ← 이 라인들도 제거

  const BottomLineItem._();

  // AI 생성용 팩토리
  factory BottomLineItem.fromInsight({
    required String headline,
    required CandidateInsight insight,
  }) {
    return BottomLineItem(
      headline: headline,
      timestamp: DateTime.now(),
      priority: insight.finalScore,
      sourceInsightId: insight.id,
      isUrgent: insight.isHighPriority,
    );
  }

  // 표시 순서 비교 (우선순위 높은 순)
  int compareTo(BottomLineItem other) {
    if (isUrgent != other.isUrgent) {
      return isUrgent ? -1 : 1; // 긴급한 것이 먼저
    }
    return other.priority.compareTo(priority); // 높은 점수가 먼저
  }
}

// ===== 4. 인사이트 룰 시스템 =====
abstract class InsightRule {
  String get id;
  String get template;
  double get weight;
  
  bool canTrigger(MarketSnapshot snapshot);
  Map<String, dynamic> getTemplateVars(MarketSnapshot snapshot);
  
  // 점수 계산
  double calculateScore(MarketSnapshot snapshot) {
    if (!canTrigger(snapshot)) return 0.0;
    
    final vars = getTemplateVars(snapshot);
    
    // 기본 점수 계산 (가격변화^0.3 + 볼륨Z-score^0.25 + 고액거래^0.25 + 섹터변화^0.2)
    double score = 0.0;
    
    // 가격 변화 요소
    final priceChange = (vars['price_change'] as double?) ?? 0.0;
    score += (priceChange.abs() / 100).clamp(0.0, 1.0) * 0.3;
    
    // 볼륨 요소
    final volumeChange = (vars['volume_change'] as double?) ?? 0.0;
    score += (volumeChange.abs() / 500).clamp(0.0, 1.0) * 0.25;
    
    // 고액거래 요소
    final largeTradeCount = (vars['large_trade_count'] as int?) ?? 0;
    score += (largeTradeCount / 5).clamp(0.0, 1.0) * 0.25;
    
    // 섹터 변화 요소
    final sectorChange = (vars['sector_change'] as double?) ?? 0.0;
    score += (sectorChange.abs() / 10).clamp(0.0, 1.0) * 0.2;
    
    return score * weight;
  }

  // 인사이트 생성
  CandidateInsight? generateInsight(MarketSnapshot snapshot) {
    final score = calculateScore(snapshot);
    if (score < 1.0) return null; // 임계값 미달
    
    return CandidateInsight(
      id: '${id}_${snapshot.timestamp.millisecondsSinceEpoch}',
      template: template,
      score: score,
      weight: weight,
      templateVars: getTemplateVars(snapshot),
      timestamp: snapshot.timestamp,
      isUrgent: score >= 2.5,
    );
  }
}

// ===== 5. 구체적인 룰 구현들 =====

// 스마트머니 룰 (고액거래 패턴)
class SmartMoneyRule extends InsightRule {
  @override
  String get id => 'smart_money';
  
  @override
  String get template => '🔥 {market} {count}건 대형매수 탐지 · 총 {amount}억원';
  
  @override
  double get weight => 1.0;
  
  @override
  bool canTrigger(MarketSnapshot snapshot) {
    final largeTrades = snapshot.topTrades
      .where((t) => t.total >= 20000000) // 2천만원 이상
      .toList();
    
    // 고액거래 3건 이상 + 동일 마켓 볼륨 급증
    if (largeTrades.length < 3) return false;
    
    final markets = largeTrades.map((t) => t.market).toSet();
    for (final market in markets) {
      final marketTrades = largeTrades.where((t) => t.market == market).length;
      final volumeChange = snapshot.volChangePct[market] ?? 0.0;
      if (marketTrades >= 3 && volumeChange > 50) return true;
    }
    
    return false;
  }
  
  @override
  Map<String, dynamic> getTemplateVars(MarketSnapshot snapshot) {
    final largeTrades = snapshot.topTrades
      .where((t) => t.total >= 20000000)
      .toList();
    
    final marketGroups = <String, List<Trade>>{};
    for (final trade in largeTrades) {
      marketGroups.putIfAbsent(trade.market, () => []).add(trade);
    }
    
    // 가장 활발한 마켓 선택
    String topMarket = '';
    int maxCount = 0;
    double totalAmount = 0;
    
    for (final entry in marketGroups.entries) {
      if (entry.value.length > maxCount) {
        maxCount = entry.value.length;
        topMarket = entry.key;
        totalAmount = entry.value.fold(0, (sum, t) => sum + t.total);
      }
    }
    
    return {
      'market': topMarket,
      'count': maxCount,
      'amount': (totalAmount / 100000000).toStringAsFixed(1), // 억원 단위
      'large_trade_count': maxCount,
      'volume_change': snapshot.volChangePct[topMarket] ?? 0.0,
      'price_change': snapshot.priceDelta[topMarket] ?? 0.0,
      'sector_change': 0.0,
    };
  }
}

// 볼륨 급증 룰
class VolumeSpikeRule extends InsightRule {
  @override
  String get id => 'volume_spike';
  
  @override
  String get template => '⚡ {market} 거래량 {change}%↑ · 평소 대비 {multiplier}배';
  
  @override
  double get weight => 0.8;
  
  @override
  bool canTrigger(MarketSnapshot snapshot) {
    return snapshot.volChangePct.values.any((change) => change > 200);
  }
  
  @override
  Map<String, dynamic> getTemplateVars(MarketSnapshot snapshot) {
    final maxEntry = snapshot.volChangePct.entries
      .reduce((a, b) => a.value > b.value ? a : b);
    
    final multiplier = (maxEntry.value / 100 + 1).toStringAsFixed(1);
    
    return {
      'market': maxEntry.key,
      'change': maxEntry.value.toStringAsFixed(0),
      'multiplier': multiplier,
      'volume_change': maxEntry.value,
      'price_change': snapshot.priceDelta[maxEntry.key] ?? 0.0,
      'large_trade_count': 0,
      'sector_change': 0.0,
    };
  }
}

// 연쇄 급등 룰
class SurgeChainRule extends InsightRule {
  @override
  String get id => 'surge_chain';
  
  @override
  String get template => '🔗 {theme} 테마 연쇄 급등 {count}종 · 평균 +{avg_change}%';
  
  @override
  double get weight => 0.7;
  
  @override
  bool canTrigger(MarketSnapshot snapshot) {
    final surgingCoins = snapshot.surges
      .where((s) => s.changePercent > 10)
      .toList();
    
    return surgingCoins.length >= 3;
  }
  
  @override
  Map<String, dynamic> getTemplateVars(MarketSnapshot snapshot) {
    final surgingCoins = snapshot.surges
      .where((s) => s.changePercent > 10)
      .toList();
    
    final avgChange = surgingCoins.isEmpty ? 0.0 :
      surgingCoins.map((s) => s.changePercent).reduce((a, b) => a + b) / surgingCoins.length;
    
    return {
      'theme': '연관코인', // TODO: 실제 테마 분류 로직
      'count': surgingCoins.length,
      'avg_change': avgChange.toStringAsFixed(1),
      'volume_change': 0.0,
      'price_change': avgChange,
      'large_trade_count': 0,
      'sector_change': 0.0,
    };
  }
}

// 섹터 로테이션 룰
class SectorRotationRule extends InsightRule {
  @override
  String get id => 'sector_rotation';
  
  @override
  String get template => '💫 {sector} 섹터 점유율 +{change}%p · 자금 유입 감지';
  
  @override
  double get weight => 0.8;
  
  @override
  bool canTrigger(MarketSnapshot snapshot) {
    return snapshot.sectorShareDelta.values.any((change) => change > 7);
  }
  
  @override
  Map<String, dynamic> getTemplateVars(MarketSnapshot snapshot) {
    final maxEntry = snapshot.sectorShareDelta.entries
      .reduce((a, b) => a.value > b.value ? a : b);
    
    return {
      'sector': maxEntry.key,
      'change': maxEntry.value.toStringAsFixed(1),
      'volume_change': 0.0,
      'price_change': 0.0,
      'large_trade_count': 0,
      'sector_change': maxEntry.value,
    };
  }
}

// 폴백 룰 (빈 큐 방지)
class FallbackRule extends InsightRule {
  @override
  String get id => 'fallback';
  
  @override
  String get template => '💰 {market} 시장 활발 · 실시간 모니터링 중';
  
  @override
  double get weight => 0.3; // 낮은 가중치
  
  @override
  bool canTrigger(MarketSnapshot snapshot) {
    // 고액거래가 1건 이상 있으면 무조건 트리거
    return snapshot.topTrades.isNotEmpty;
  }
  
  @override
  Map<String, dynamic> getTemplateVars(MarketSnapshot snapshot) {
    final topTrade = snapshot.topTrades.isNotEmpty 
      ? snapshot.topTrades.first 
      : null;
    
    return {
      'market': topTrade?.market ?? 'BTC',
      'volume_change': 0.0,
      'price_change': 0.0,
      'large_trade_count': snapshot.topTrades.length,
      'sector_change': 0.0,
    };
  }
}

// ===== 6. 룰 레지스트리 =====
class RuleRegistry {
  static final List<InsightRule> allRules = [
    SmartMoneyRule(),
    VolumeSpikeRule(),
    SurgeChainRule(),
    SectorRotationRule(),
    FallbackRule(),
  ];
  
  // 특정 스냅샷에 대해 모든 룰 실행
  static List<CandidateInsight> generateInsights(MarketSnapshot snapshot) {
    final insights = <CandidateInsight>[];
    
    for (final rule in allRules) {
      final insight = rule.generateInsight(snapshot);
      if (insight != null) {
        insights.add(insight);
      }
    }
    
    // 점수 높은 순으로 정렬
    insights.sort((a, b) => b.finalScore.compareTo(a.finalScore));
    
    // 상위 5개만 반환 (AI 호출 비용 절약)
    return insights.take(5).toList();
  }
  
  // 긴급 인사이트 필터
  static List<CandidateInsight> getUrgentInsights(List<CandidateInsight> insights) {
    return insights.where((i) => i.isHighPriority).toList();
  }
  
  // 룰 성능 통계 (디버깅용)
  static Map<String, int> getRuleStats(List<CandidateInsight> insights) {
    final stats = <String, int>{};
    for (final insight in insights) {
      final ruleId = insight.id.split('_').first;
      stats[ruleId] = (stats[ruleId] ?? 0) + 1;
    }
    return stats;
  }
}