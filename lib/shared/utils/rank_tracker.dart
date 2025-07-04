// lib/shared/utils/rank_tracker.dart
import 'dart:collection';

/// 🎯 순위 변경 추적 전용 클래스
/// 시간대별로 독립적인 순위 추적만 담당
class RankTracker {
  // 시간대별 이전 순위 저장
  // {'1m': {'BTC': 5, 'ETH': 3}, '5m': {'BTC': 2, 'ETH': 7}}
  final Map<String, Map<String, int>> _previousRanks = HashMap();
  // 시간대별 이전 값 저장 (Surge용)
  // {'1m': {'BTC': -2.5, 'ETH': 1.3}, '5m': {'BTC': -1.2, 'ETH': 2.7}}
  final Map<String, Map<String, double>> _previousValues = HashMap();

  /// 특정 시간대 초기화
  void initializeTimeFrame(String timeFrame) {
    _previousRanks[timeFrame] ??= HashMap<String, int>();
    _previousValues[timeFrame] ??= HashMap<String, double>();
  }

  /// 순위 변경 감지 (상승시에만 true 반환) - Volume/Sector용
  bool checkRankChange({
    required String key,
    required int currentRank,
    required String timeFrame,
  }) {
    final timeFrameRanks = _previousRanks[timeFrame] ??= HashMap<String, int>();
    final previousRank = timeFrameRanks[key];
    final hasRankUp = previousRank != null && currentRank < previousRank;
    
    // 현재 순위 저장
    timeFrameRanks[key] = currentRank;
    return hasRankUp;
  }

  /// 순위 + 실제값 변경 감지 - Surge용 상승 (순위 상승 + 실제 수치 개선)
  bool checkRankChangeWithValue({
    required String key,
    required int currentRank,
    required double currentValue,
    required String timeFrame,
  }) {
    final timeFrameRanks = _previousRanks[timeFrame] ??= HashMap<String, int>();
    final timeFrameValues = _previousValues[timeFrame] ??= HashMap<String, double>();
    
    final previousRank = timeFrameRanks[key];
    final previousValue = timeFrameValues[key];
    
    // 1️⃣ 순위 상승 체크
    final hasRankUp = previousRank != null && currentRank < previousRank;
    
    // 2️⃣ 실제 값 개선 체크 (최소 0.01% 이상 상승)
    final hasValueImprovement = previousValue == null ||
        (currentValue - previousValue) >= 0.01;
    
    // 현재 데이터 저장
    timeFrameRanks[key] = currentRank;
    timeFrameValues[key] = currentValue;
    
    // 3️⃣ 둘 다 만족해야 블링크!
    return hasRankUp && hasValueImprovement;
  }

  /// 순위 + 실제값 변경 감지 - Surge용 하락 (순위 하락 + 실제 수치 악화)
  bool checkRankDropWithValue({
    required String key,
    required int currentRank,
    required double currentValue,
    required String timeFrame,
  }) {
    final timeFrameRanks = _previousRanks[timeFrame] ??= HashMap<String, int>();
    final timeFrameValues = _previousValues[timeFrame] ??= HashMap<String, double>();
    
    final previousRank = timeFrameRanks[key];
    final previousValue = timeFrameValues[key];
    
    // 1️⃣ 순위 하락 체크
    final hasRankDown = previousRank != null && currentRank > previousRank;
    
    // 2️⃣ 실제 값 악화 체크 (최소 0.01% 이상 하락)
    final hasValueDrop = previousValue != null &&
        (currentValue - previousValue) <= -0.01;
    
    // 현재 데이터 저장
    timeFrameRanks[key] = currentRank;
    timeFrameValues[key] = currentValue;
    
    // 3️⃣ 둘 다 만족해야 블링크!
    return hasRankDown && hasValueDrop;
  }

  /// 특정 시간대의 추적 데이터 개수
  int getTrackedCount(String timeFrame) {
    return _previousRanks[timeFrame]?.length ?? 0;
  }

  /// 특정 시간대 데이터 초기화
  void clearTimeFrame(String timeFrame) {
    _previousRanks[timeFrame]?.clear();
    _previousValues[timeFrame]?.clear();
  }

  /// 모든 데이터 초기화
  void clearAll() {
    _previousRanks.clear();
    _previousValues.clear();
  }

  /// 디버깅용 정보
  Map<String, int> getDebugInfo() {
    return _previousRanks.map((timeFrame, ranks) =>
        MapEntry(timeFrame, ranks.length));
  }

  /// 리소스 정리
  void dispose() {
    _previousRanks.clear();
    _previousValues.clear();
  }
}