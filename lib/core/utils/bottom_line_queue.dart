// core/utils/bottom_line_queue.dart
// 🎨 바텀라인 UI 큐 관리 시스템 (18초 간격 표시)

import 'dart:collection';
import 'dart:math' as math;
import 'package:flutter/foundation.dart';
import '../../domain/entities/bottom_line.dart';
import 'bottom_line_constants.dart';

// ══════════════════════════════════════════════════════════════════════════════
// 🎨 바텀라인 큐 상태 열거형
// ══════════════════════════════════════════════════════════════════════════════

enum BottomLineQueueState {
  /// 정상 상태 - 충분한 아이템 보유
  normal,
  
  /// 부족 상태 - 리필 필요 (4개 미만)
  needsRefill,
  
  /// 빈 상태 - 표시할 아이템 없음
  empty,
  
  /// 긴급 상태 - 긴급 아이템 우선 표시
  urgent,
  
  /// 일시정지 상태 - 표시 중단
  paused,
}

// ══════════════════════════════════════════════════════════════════════════════
// 🎯 바텀라인 큐 아이템 래퍼
// ══════════════════════════════════════════════════════════════════════════════

/// 큐에서 관리되는 바텀라인 아이템 (메타데이터 포함)
@immutable
class QueuedBottomLineItem {
  final BottomLineItem item;
  final DateTime queuedAt;        // 큐에 추가된 시간
  final int displayCount;         // 표시된 횟수
  final bool isUrgent;           // 긴급 아이템 여부
  final double priority;         // 우선순위 (높을수록 먼저 표시)
  final String id;               // 고유 ID

  const QueuedBottomLineItem({
    required this.item,
    required this.queuedAt,
    this.displayCount = 0,
    required this.isUrgent,
    required this.priority,
    required this.id,
  });

  /// 큐 아이템 생성 팩토리
  factory QueuedBottomLineItem.fromBottomLineItem(BottomLineItem item) {
    return QueuedBottomLineItem(
      item: item,
      queuedAt: DateTime.now(),
      isUrgent: item.isUrgent,
      priority: item.priority,
      id: '${item.sourceInsightId}_${DateTime.now().millisecondsSinceEpoch}',
    );
  }

  /// 표시 횟수 증가
  QueuedBottomLineItem incrementDisplayCount() {
    return QueuedBottomLineItem(
      item: item,
      queuedAt: queuedAt,
      displayCount: displayCount + 1,
      isUrgent: isUrgent,
      priority: priority,
      id: id,
    );
  }

  /// 큐에서 대기한 시간
  Duration get queuedDuration => DateTime.now().difference(queuedAt);

  /// 만료 여부 (5분 이상 대기)
  bool get isExpired => queuedDuration.inMinutes > 5;

  /// 우선순위 점수 계산 (긴급도 + 시간 가중치)
  double get effectivePriority {
    double score = priority;
    
    // 긴급 아이템은 +2.0 보너스
    if (isUrgent) score += 2.0;
    
    // 오래 대기한 아이템은 우선순위 상승 (최대 +1.0)
    final waitMinutes = queuedDuration.inMinutes;
    final timeBonus = math.min(waitMinutes * 0.1, 1.0);
    score += timeBonus;
    
    return score;
  }

  @override
  String toString() {
    return 'QueuedItem(${item.headline.substring(0, math.min(20, item.headline.length))}..., '
           'urgent: $isUrgent, priority: ${priority.toStringAsFixed(1)}, '
           'displayed: $displayCount, queued: ${queuedDuration.inSeconds}s)';
  }

  @override
  bool operator ==(Object other) {
    if (identical(this, other)) return true;
    return other is QueuedBottomLineItem && other.id == id;
  }

  @override
  int get hashCode => id.hashCode;
}

// ══════════════════════════════════════════════════════════════════════════════
// 🎨 바텀라인 큐 관리자
// ══════════════════════════════════════════════════════════════════════════════

/// ESPN 스타일 바텀라인 큐 관리 시스템
class BottomLineQueue {
  // 🎯 큐 저장소 (우선순위별 분리)
  final Queue<QueuedBottomLineItem> _urgentQueue = Queue<QueuedBottomLineItem>();
  final Queue<QueuedBottomLineItem> _normalQueue = Queue<QueuedBottomLineItem>();
  final Queue<QueuedBottomLineItem> _fallbackQueue = Queue<QueuedBottomLineItem>();
  
  // 📊 상태 관리
  QueuedBottomLineItem? _currentItem;
  BottomLineQueueState _state = BottomLineQueueState.empty;
  DateTime? _lastDisplayTime;
  DateTime? _lastRefillTime;
  int _totalDisplayed = 0;
  int _totalAdded = 0;
  
  // 🎛️ 설정
  bool _isPaused = false;
  double _speedMultiplier = 1.0;
  
  /// 현재 표시 중인 아이템
  QueuedBottomLineItem? get currentItem => _currentItem;
  
  /// 현재 큐 상태
  BottomLineQueueState get state => _state;
  
  /// 총 큐 길이 (모든 큐 합계)
  int get queueLength => _urgentQueue.length + _normalQueue.length + _fallbackQueue.length;
  
  /// 긴급 아이템 개수
  int get urgentCount => _urgentQueue.length;
  
  /// 일반 아이템 개수
  int get normalCount => _normalQueue.length;
  
  /// 대체 아이템 개수
  int get fallbackCount => _fallbackQueue.length;
  
  /// 긴급 아이템이 있는지
  bool get hasUrgentItems => _urgentQueue.isNotEmpty;
  
  /// 큐가 비어있는지
  bool get isEmpty => queueLength == 0;
  
  /// 리필이 필요한지 (4개 미만)
  bool get needsRefill => queueLength < BottomLineConstants.queueRefillThreshold;
  
  /// 일시정지 상태인지
  bool get isPaused => _isPaused;
  
  /// 속도 배수
  double get speedMultiplier => _speedMultiplier;
  
  /// 마지막 표시 시간
  DateTime? get lastDisplayTime => _lastDisplayTime;
  
  /// 다음 표시까지 남은 시간 (초)
  int get secondsUntilNext {
    if (_lastDisplayTime == null) return 0;
    
    final elapsed = DateTime.now().difference(_lastDisplayTime!).inSeconds;
    final interval = (BottomLineConstants.displayIntervalSeconds / _speedMultiplier).round();
    
    return math.max(0, interval - elapsed);
  }

  // ══════════════════════════════════════════════════════════════════════════════
  // 📥 아이템 추가 메서드들
  // ══════════════════════════════════════════════════════════════════════════════

  /// 바텀라인 아이템 추가 (자동 분류)
  void addItem(BottomLineItem item) {
    final queuedItem = QueuedBottomLineItem.fromBottomLineItem(item);
    
    if (item.isUrgent) {
      _addToUrgentQueue(queuedItem);
    } else {
      _addToNormalQueue(queuedItem);
    }
    
    _totalAdded++;
    _updateState();
    
    if (BottomLineConstants.enableDetailedLogging) {
      // log.d('📥 Added item to queue: ${queuedItem}');
    }
  }

  /// 여러 아이템 한 번에 추가
  void addItems(List<BottomLineItem> items) {
    for (final item in items) {
      addItem(item);
    }
    
    if (BottomLineConstants.enableLogging) {
      // log.d('📥 Added ${items.length} items to queue (total: $queueLength)');
    }
  }

  /// 긴급 아이템 즉시 추가 (맨 앞에)
  void addUrgentItem(BottomLineItem item) {
    final queuedItem = QueuedBottomLineItem.fromBottomLineItem(item);
    _urgentQueue.addFirst(queuedItem);
    _totalAdded++;
    _updateState();
    
    if (BottomLineConstants.enableLogging) {
      // log.d('🚨 Added urgent item to front: ${queuedItem}');
    }
  }

  /// 대체 아이템 추가 (큐 고갈 방지용)
  void addFallbackItem(BottomLineItem item) {
    final queuedItem = QueuedBottomLineItem.fromBottomLineItem(item);
    _fallbackQueue.addLast(queuedItem);
    _updateState();
    
    if (BottomLineConstants.enableDetailedLogging) {
      // log.d('🛡️ Added fallback item: ${queuedItem}');
    }
  }

  /// 긴급 큐에 추가 (중복 체크)
  void _addToUrgentQueue(QueuedBottomLineItem item) {
    // 중복 제거 (같은 insight는 하나만)
    _urgentQueue.removeWhere((existing) => 
      existing.item.sourceInsightId == item.item.sourceInsightId);
    
    // 최대 개수 제한
    while (_urgentQueue.length >= BottomLineConstants.maxUrgentItems) {
      _urgentQueue.removeFirst();
    }
    
    _urgentQueue.addLast(item);
  }

  /// 일반 큐에 추가 (우선순위 정렬)
  void _addToNormalQueue(QueuedBottomLineItem item) {
    final queueList = _normalQueue.toList();
    
    // 중복 제거
    queueList.removeWhere((existing) => 
      existing.item.sourceInsightId == item.item.sourceInsightId);
    
    // 우선순위 순으로 삽입
    queueList.add(item);
    queueList.sort((a, b) => b.effectivePriority.compareTo(a.effectivePriority));
    
    // 최대 개수 제한
    final limitedList = queueList.take(BottomLineConstants.maxNormalItems).toList();
    
    _normalQueue.clear();
    _normalQueue.addAll(limitedList);
  }

  // ══════════════════════════════════════════════════════════════════════════════
  // 📤 아이템 표시 메서드들
  // ══════════════════════════════════════════════════════════════════════════════

  /// 다음 아이템 표시 (18초 간격)
  BottomLineQueue showNext() {
    if (_isPaused) return this;
    
    // 현재 아이템 표시 횟수 증가
    if (_currentItem != null) {
      _currentItem = _currentItem!.incrementDisplayCount();
    }
    
    // 다음 아이템 선택
    final nextItem = _getNextItem();
    
    if (nextItem != null) {
      _currentItem = nextItem;
      _lastDisplayTime = DateTime.now();
      _totalDisplayed++;
      
      // 사용된 아이템을 큐에서 제거
      _removeUsedItem(nextItem);
      
      if (BottomLineConstants.enableDetailedLogging) {
        // log.d('📺 Showing next item: ${nextItem}');
      }
    } else {
      // 표시할 아이템이 없음
      _currentItem = null;
      
      if (BottomLineConstants.enableLogging) {
        // log.w('📺 No items to display, queue is empty');
      }
    }
    
    _updateState();
    return this;
  }

  /// 다음 표시할 아이템 선택 (우선순위 순)
  QueuedBottomLineItem? _getNextItem() {
    // 1. 긴급 아이템 우선
    if (_urgentQueue.isNotEmpty) {
      return _urgentQueue.first;
    }
    
    // 2. 일반 아이템 (우선순위 순)
    if (_normalQueue.isNotEmpty) {
      return _normalQueue.first;
    }
    
    // 3. 대체 아이템 (큐 고갈 시)
    if (_fallbackQueue.isNotEmpty) {
      return _fallbackQueue.first;
    }
    
    return null;
  }

  /// 사용된 아이템을 큐에서 제거
  void _removeUsedItem(QueuedBottomLineItem item) {
    _urgentQueue.remove(item);
    _normalQueue.remove(item);
    _fallbackQueue.remove(item);
  }

  /// 즉시 다음 아이템으로 스킵
  BottomLineQueue skipCurrent() {
    if (_currentItem != null) {
      if (BottomLineConstants.enableLogging) {
        // log.d('⏭️ Skipping current item: ${_currentItem}');
      }
    }
    
    return showNext();
  }

  /// 현재 아이템 다시 표시 (18초 연장)
  BottomLineQueue repeatCurrent() {
    if (_currentItem != null) {
      _lastDisplayTime = DateTime.now();
      
      if (BottomLineConstants.enableDetailedLogging) {
        // log.d('🔄 Repeating current item: ${_currentItem}');
      }
    }
    
    return this;
  }

  // ══════════════════════════════════════════════════════════════════════════════
  // 🎛️ 큐 제어 메서드들
  // ══════════════════════════════════════════════════════════════════════════════

  /// 큐 일시정지/재개
  BottomLineQueue setPaused(bool paused) {
    _isPaused = paused;
    _updateState();
    
    if (BottomLineConstants.enableLogging) {
      // log.d('⏸️ Queue ${paused ? 'paused' : 'resumed'}');
    }
    
    return this;
  }

  /// 표시 속도 변경 (배수)
  BottomLineQueue setSpeedMultiplier(double multiplier) {
    _speedMultiplier = math.max(0.1, math.min(5.0, multiplier));
    
    if (BottomLineConstants.enableLogging) {
      // log.d('⚡ Speed multiplier set to ${_speedMultiplier}x');
    }
    
    return this;
  }

  /// 큐 전체 비우기
  BottomLineQueue clear() {
    _urgentQueue.clear();
    _normalQueue.clear();
    _fallbackQueue.clear();
    _currentItem = null;
    _updateState();
    
    if (BottomLineConstants.enableLogging) {
      // log.d('🗑️ Queue cleared');
    }
    
    return this;
  }

  /// 만료된 아이템 제거
  BottomLineQueue removeExpired() {
    int removedCount = 0;
    
    // 각 큐에서 만료된 아이템 제거
    removedCount += _removeExpiredFromQueue(_urgentQueue);
    removedCount += _removeExpiredFromQueue(_normalQueue);
    removedCount += _removeExpiredFromQueue(_fallbackQueue);
    
    if (removedCount > 0) {
      _updateState();
      
      if (BottomLineConstants.enableLogging) {
        // log.d('🗑️ Removed $removedCount expired items');
      }
    }
    
    return this;
  }

  /// 특정 큐에서 만료된 아이템 제거
  int _removeExpiredFromQueue(Queue<QueuedBottomLineItem> queue) {
    final originalLength = queue.length;
    queue.removeWhere((item) => item.isExpired);
    return originalLength - queue.length;
  }

  /// 큐 상태 업데이트
  void _updateState() {
    if (_isPaused) {
      _state = BottomLineQueueState.paused;
    } else if (hasUrgentItems) {
      _state = BottomLineQueueState.urgent;
    } else if (isEmpty) {
      _state = BottomLineQueueState.empty;
    } else if (needsRefill) {
      _state = BottomLineQueueState.needsRefill;
    } else {
      _state = BottomLineQueueState.normal;
    }
  }

  // ══════════════════════════════════════════════════════════════════════════════
  // 📊 통계 및 모니터링
  // ══════════════════════════════════════════════════════════════════════════════

  /// 큐 통계 정보
  Map<String, dynamic> get stats {
    
    return {
      'state': _state.name,
      'queue_length': queueLength,
      'urgent_count': urgentCount,
      'normal_count': normalCount,
      'fallback_count': fallbackCount,
      'current_item': _currentItem?.item.headline ?? 'None',
      'total_added': _totalAdded,
      'total_displayed': _totalDisplayed,
      'display_rate': _totalAdded > 0 ? (_totalDisplayed / _totalAdded * 100).toStringAsFixed(1) : '0.0',
      'is_paused': _isPaused,
      'speed_multiplier': _speedMultiplier,
      'seconds_until_next': secondsUntilNext,
      'last_display': _lastDisplayTime?.toIso8601String() ?? 'Never',
      'needs_refill': needsRefill,
      'memory_usage_items': queueLength,
    };
  }

  /// 우선순위 분포 통계
  Map<String, dynamic> get priorityStats {
    final allItems = [
      ..._urgentQueue,
      ..._normalQueue,
      ..._fallbackQueue,
    ];
    
    if (allItems.isEmpty) {
      return {'count': 0, 'min': 0.0, 'max': 0.0, 'avg': 0.0};
    }
    
    final priorities = allItems.map((item) => item.effectivePriority).toList();
    priorities.sort();
    
    return {
      'count': priorities.length,
      'min': priorities.first,
      'max': priorities.last,
      'avg': priorities.reduce((a, b) => a + b) / priorities.length,
      'median': priorities[priorities.length ~/ 2],
    };
  }

  /// 성능 메트릭
  Map<String, dynamic> get performanceMetrics {
    final now = DateTime.now();
    final startTime = _lastRefillTime ?? now;
    final uptimeMinutes = now.difference(startTime).inMinutes;
    
    return {
      'uptime_minutes': uptimeMinutes,
      'items_per_minute': uptimeMinutes > 0 ? _totalAdded / uptimeMinutes : 0.0,
      'display_efficiency': _totalAdded > 0 ? _totalDisplayed / _totalAdded : 0.0,
      'queue_turnover_rate': queueLength > 0 ? _totalDisplayed / queueLength : 0.0,
      'average_queue_length': queueLength.toDouble(),
      'urgent_ratio': queueLength > 0 ? urgentCount / queueLength : 0.0,
    };
  }

  @override
  String toString() {
    return 'BottomLineQueue(state: ${_state.name}, length: $queueLength, '
           'urgent: $urgentCount, current: ${_currentItem?.item.headline ?? 'None'})';
  }
}