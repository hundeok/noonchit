// core/di/bottom_line_provider.dart
// 🔥 바텀라인 Provider - 실시간 누적 데이터 기반

import 'dart:async';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../config/app_config.dart';
import '../utils/logger.dart';
import '../services/openai_service.dart';
import '../utils/bottom_line_queue.dart';
import '../utils/bottom_line_constants.dart';
import '../utils/bottom_line_insight_engine.dart';
import '../../data/processors/bottom_line_aggregator.dart';
import '../../domain/entities/bottom_line.dart';
import '../../domain/entities/trade.dart';

// 🔥 모든 필요한 Provider들을 app_providers에서 import
import 'app_providers.dart';

// ══════════════════════════════════════════════════════════════════════════════
// 🔥 바텀라인 전용 실시간 데이터 수집 (타임프레임 무관)
// ══════════════════════════════════════════════════════════════════════════════

/// 바텀라인 전용 실시간 Trade 스트림 (리셋 없음)
final bottomLineTradeStreamProvider = StreamProvider<Trade>((ref) async* {
  ref.keepAlive(); // 연결 유지
  
  // 🎯 Master Trade Stream 직접 구독 (타임프레임 변환 없음)
  final masterStream = await ref.read(masterTradeStreamProvider.future);
  
  if (AppConfig.enableTradeLog) {
    log.d('🔥 Bottom line real-time stream started');
  }
  
  // 실시간 데이터 그대로 흘려보내기 (필터링/집계 없음)
  yield* masterStream;
});

/// 바텀라인 전용 데이터 애그리게이터 (지속적 누적)
final bottomLineRealtimeDataProvider = StreamProvider<MarketSnapshot>((ref) async* {
  final aggregator = ref.read(bottomLineAggregatorProvider);
  
  // 30초마다 스냅샷 생성 (누적 데이터 기반)
  Timer.periodic(const Duration(seconds: BottomLineConstants.refreshIntervalSeconds), (timer) {
    final snapshot = aggregator.generateRealtimeSnapshot();
    if (snapshot != null) {
      // StreamController를 통해 스냅샷 방출
    }
  });
  
  // 🔥 올바른 방법: StreamProvider에서 .stream으로 접근
  final tradeStream = ref.watch(bottomLineTradeStreamProvider.stream);
  await for (final trade in tradeStream) {
    // 🔥 실시간으로 계속 누적 (리셋 없음)
    aggregator.addRealtimeTrade(trade);
    
    // 30초 간격으로만 스냅샷 생성
    if (aggregator.shouldGenerateSnapshot()) {
      final snapshot = aggregator.generateRealtimeSnapshot();
      if (snapshot != null) {
        yield snapshot;
      }
    }
  }
});

/// 바텀라인 스냅샷 Provider (30초마다 갱신)
final bottomLineSnapshotProvider = Provider<MarketSnapshot?>((ref) {
  final realtimeSnapshot = ref.watch(bottomLineRealtimeDataProvider).valueOrNull;
  
  if (realtimeSnapshot == null) {
    // 초기 데이터가 없으면 기존 Provider에서 현재 상태 가져오기
    return _getInitialSnapshot(ref);
  }
  
  return realtimeSnapshot;
});

/// 초기 스냅샷 생성 (앱 시작 시)
MarketSnapshot? _getInitialSnapshot(Ref ref) {
  try {
    // 🎯 실제 Provider에서 현재 상태 가져오기
    final currentTrades = ref.read(tradeListProvider).valueOrNull ?? [];
    final currentVolumes = ref.read(currentVolumeListProvider);
    final currentSurges = ref.read(currentSurgeListProvider);
    final currentSectors = ref.read(currentSectorVolumeListProvider);
    
    if (currentTrades.isEmpty && currentVolumes.isEmpty && currentSurges.isEmpty) {
      return null;
    }
    
    // 초기 스냅샷 생성 (이전 스냅샷 없음)
    return MarketSnapshot.create(
      trades: currentTrades.take(50).toList(), // 최근 50개만
      volumes: currentVolumes.take(50).toList(),
      surges: currentSurges,
      sectors: currentSectors.take(10).toList(),
      previousSnapshot: null,
    );
  } catch (e) {
    log.e('🚨 Initial snapshot generation failed: $e');
    return null;
  }
}

/// 바텀라인 인사이트 생성 Provider
final bottomLineInsightsProvider = Provider<List<CandidateInsight>>((ref) {
  final snapshot = ref.watch(bottomLineSnapshotProvider);
  
  if (snapshot == null) {
    return [];
  }
  
  // 인사이트 엔진으로 룰 실행
  final insights = RuleRegistry.generateInsights(snapshot);
  
  if (AppConfig.enableTradeLog && insights.isNotEmpty) {
    log.d('🔥 Generated ${insights.length} insights: ${insights.map((i) => '${i.id}(${i.finalScore.toStringAsFixed(1)})').join(', ')}');
  }
  
  return insights;
});

/// AI 생성 바텀라인 Provider (OpenAI 호출)
final bottomLineGeneratedProvider = FutureProvider<List<BottomLineItem>>((ref) async {
  final insights = ref.watch(bottomLineInsightsProvider);
  
  if (insights.isEmpty) {
    // 인사이트가 없으면 플레이스홀더 반환
    return [
      BottomLineItem(
        headline: '📊 시장 데이터 수집 중...',
        timestamp: DateTime.now(),
        priority: 0.1,
        sourceInsightId: 'placeholder',
      ),
    ];
  }
  
  try {
    // OpenAI 서비스로 바텀라인 생성
    final openAI = ref.read(openAIServiceProvider);
    final headlines = await openAI.generateBottomLines(insights);
    
    // BottomLineItem으로 변환
    final items = <BottomLineItem>[];
    for (int i = 0; i < headlines.length && i < insights.length; i++) {
      items.add(BottomLineItem.fromInsight(
        headline: headlines[i],
        insight: insights[i],
      ));
    }
    
    if (AppConfig.enableTradeLog) {
      log.d('🤖 AI generated ${items.length} bottom lines');
    }
    
    return items;
    
  } catch (e, stackTrace) {
    log.e('🚨 Bottom line generation failed: $e', e, stackTrace);
    
    // AI 실패 시 템플릿 기반 대체
    return insights.map((insight) => BottomLineItem.fromInsight(
      headline: insight.populatedTemplate,
      insight: insight,
    )).toList();
  }
});

/// 바텀라인 메인 데이터 Provider (큐에 자동 추가)
final bottomLineDataProvider = Provider<List<BottomLineItem>>((ref) {
  final generatedItems = ref.watch(bottomLineGeneratedProvider);
  final queueNotifier = ref.read(bottomLineQueueProvider.notifier);
  
  generatedItems.when(
    data: (items) {
      if (items.isNotEmpty) {
        // 긴급 아이템과 일반 아이템 분리
        final urgentItems = items.where((item) => item.isUrgent).toList();
        final normalItems = items.where((item) => !item.isUrgent).toList();
        
        // 긴급 아이템은 즉시 큐 앞에 추가
        for (final urgentItem in urgentItems) {
          queueNotifier.addUrgentItem(urgentItem);
        }
        
        // 일반 아이템은 배치로 추가
        if (normalItems.isNotEmpty) {
          queueNotifier.addItems(normalItems);
        }
      }
    },
    loading: () {},
    error: (error, stack) {
      log.e('🚨 Bottom line data error: $error');
    },
  );
  
  return generatedItems.valueOrNull ?? [];
});

// ══════════════════════════════════════════════════════════════════════════════
// 🎨 UI용 Provider들
// ══════════════════════════════════════════════════════════════════════════════

/// 현재 표시할 바텀라인 아이템 Provider
final currentBottomLineItemProvider = Provider<BottomLineItem?>((ref) {
  final queue = ref.watch(bottomLineQueueProvider);
  
  // 데이터 생성 트리거 (watch만 하고 값은 사용하지 않음)
  ref.watch(bottomLineDataProvider);
  
  return queue.currentItem?.item;
});

/// 바텀라인 큐 상태 Provider (디버깅용)
final bottomLineQueueStateProvider = Provider<Map<String, dynamic>>((ref) {
  final queue = ref.watch(bottomLineQueueProvider);
  
  return {
    'queue_length': queue.queueLength,
    'current_item': queue.currentItem?.item.headline ?? 'None',
    'has_urgent': queue.hasUrgentItems,
    'next_refresh_in': BottomLineConstants.refreshIntervalSeconds,
  };
});

// ══════════════════════════════════════════════════════════════════════════════
// 🔧 의존성 Provider들
// ══════════════════════════════════════════════════════════════════════════════

/// 바텀라인 애그리게이터 Provider
final bottomLineAggregatorProvider = Provider<BottomLineAggregator>((ref) {
  return BottomLineAggregator();
});

/// 바텀라인 큐 Provider
final bottomLineQueueProvider = StateNotifierProvider<BottomLineQueueNotifier, BottomLineQueue>((ref) {
  return BottomLineQueueNotifier();
});

/// 바텀라인 큐 관리 Notifier
class BottomLineQueueNotifier extends StateNotifier<BottomLineQueue> {
  BottomLineQueueNotifier() : super(BottomLineQueue());

  void addItem(BottomLineItem item) {
    state.addItem(item);
    // StateNotifier는 상태 변경을 알리기 위해 새 인스턴스를 생성해야 하지만
    // BottomLineQueue는 내부 상태를 변경하는 방식이므로 이렇게 처리
    state = state;
  }

  void addItems(List<BottomLineItem> items) {
    state.addItems(items);
    state = state;
  }

  void addUrgentItem(BottomLineItem item) {
    state.addUrgentItem(item);
    state = state;
  }

  void showNext() {
    state.showNext();
    state = state;
  }

  void skipCurrent() {
    state.skipCurrent();
    state = state;
  }

  void setPaused(bool paused) {
    state.setPaused(paused);
    state = state;
  }

  void setSpeedMultiplier(double multiplier) {
    state.setSpeedMultiplier(multiplier);
    state = state;
  }

  void clear() {
    state.clear();
    state = state;
  }
}

/// OpenAI 서비스 Provider  
final openAIServiceProvider = Provider<OpenAIService>((ref) {
  return OpenAIService();
});

/// 인사이트 엔진 Provider
final insightEngineProvider = Provider<BottomLineInsightEngine>((ref) {
  return BottomLineInsightEngine();
});

// ══════════════════════════════════════════════════════════════════════════════
// 🎛️ 설정 Provider들
// ══════════════════════════════════════════════════════════════════════════════

/// 바텀라인 활성화/비활성화 Provider
final bottomLineEnabledProvider = StateProvider<bool>((ref) => true);

/// 바텀라인 표시 속도 Provider (개발자용)
final bottomLineSpeedMultiplierProvider = StateProvider<double>((ref) => 1.0);

// ══════════════════════════════════════════════════════════════════════════════
// 🚨 에러 처리 및 대체 Provider들
// ══════════════════════════════════════════════════════════════════════════════

/// 바텀라인 에러 상태 Provider
final bottomLineErrorProvider = StateProvider<String?>((ref) => null);

/// 바텀라인 연결 상태 Provider
final bottomLineConnectionProvider = Provider<bool>((ref) {
  // 4대 Provider 중 하나라도 데이터가 있으면 연결됨으로 간주
  final hasTradeData = ref.watch(tradeListProvider).hasValue;
  final hasVolumeData = ref.watch(currentVolumeListProvider).isNotEmpty;
  final hasSurgeData = ref.watch(currentSurgeListProvider).isNotEmpty;
  
  return hasTradeData || hasVolumeData || hasSurgeData;
});

/// 대체 바텀라인 Provider (AI 실패 시)
final fallbackBottomLineProvider = Provider<BottomLineItem>((ref) {
  final timestamp = DateTime.now();
  final minute = timestamp.minute;
  
  // 시간대별 다른 메시지
  const messages = [
    '📊 암호화폐 시장 실시간 모니터링 중',
    '💰 고액거래 패턴 분석 중', 
    '⚡ 급등 코인 스캔 진행 중',
    '🔥 시장 트렌드 분석 중',
    '📈 거래량 급증 감지 대기 중',
  ];
  
  return BottomLineItem(
    headline: messages[minute % messages.length],
    timestamp: timestamp,
    priority: 0.1,
    sourceInsightId: 'fallback_$minute',
  );
});