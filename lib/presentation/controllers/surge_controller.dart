import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../core/di/surge_provider.dart';
import '../../domain/entities/surge.dart';
import '../../shared/utils/rank_tracker.dart';
import '../../shared/utils/rank_hot_mixin.dart';

/// 🎯 완전 수정된 SurgeController - TimeFrame enum 기반 + 타이머 동기화
class SurgeController extends StateNotifier<SurgeControllerState> with RankHotMixin {
  final Ref _ref;
  
  // ✅ 순위 추적기 (블링크용)
  final RankTracker _rankTracker = RankTracker();
  
  // ✅ 시간대별 블링크 상태 관리 (TimeFrame enum 기반)
  final Map<TimeFrame, Map<String, bool>> _blinkStatesByTimeFrame = {};
  
  // ✅ Provider 구독 관리
  final List<ProviderSubscription> _subscriptions = [];

  SurgeController(this._ref) : super(const SurgeControllerState()) {
    _initializeAllStates();
    _initializeDataSubscription();
  }

  /// ✅ 모든 상태 초기화
  void _initializeAllStates() {
    clearAllHot();
    _rankTracker.clearAll();
    _blinkStatesByTimeFrame.clear();
  }

  /// 🔥 통합 데이터 구독 초기화
  void _initializeDataSubscription() {
    final subscription = _ref.listen(
      surgeDataProvider,
      (previous, next) {
        next.when(
          data: (event) {
            // 🚀 데이터 처리 (이중 정렬 제거)
            _processSurgeData(event.surges);
            
            // 🔥 리셋 정보 처리 (새로운 SurgeEvent 구조)
            if (event.isReset) {
              clearTimeFrameHot(event.timeFrame.key);
              _clearTimeFrameBlinkStates(event.timeFrame);
            }
          },
          loading: () => state = state.copyWith(isLoading: true),
          error: (error, _) => state = state.copyWith(
            errorMessage: error.toString(),
            isLoading: false,
          ),
        );
      },
    );
    _subscriptions.add(subscription);
  }

  /// ✅ 급등/급락 데이터 처리 - 이중 정렬 제거
  void _processSurgeData(List<Surge> surges) {
    // ✅ Provider에서 이미 정렬된 데이터를 필터링 + 제한만 적용
    final processedSurges = _applyFilterAndLimit(surges);
    
    // ✅ 모든 상태 미리 계산
    _calculateAllStates(processedSurges);
    
    // ✅ 상태 업데이트
    state = state.copyWith(
      surges: processedSurges,
      isLoading: false,
      errorMessage: null,
    );
  }

  /// ✅ 필터링 + 제한만 적용 (정렬은 Provider에서 완료)
  List<Surge> _applyFilterAndLimit(List<Surge> surges) {
    // 1) 필터 타입에 따른 필터링만
    List<Surge> filteredData = _applyFilter(surges, state.filterType);
    
    // 2) 필터 타입에 따른 재정렬 (Provider 정렬과 다른 경우만)
    if (state.filterType == SurgeFilterType.fallingOnly) {
      // 하락만: 하락 큰 순서 (오름차순) - Provider와 다름
      filteredData.sort((a, b) => a.changePercent.compareTo(b.changePercent));
    }
    // 전체/상승: Provider에서 이미 내림차순 정렬되어 있음
    
    // 3) 제한만 적용
    final int limit = state.isTop100 ? 100 : 50;
    return filteredData.take(limit).toList();
  }

  /// ✅ 필터 타입 적용 (Provider에서 받은 원본 데이터 기준)
  List<Surge> _applyFilter(List<Surge> surgeData, SurgeFilterType filterType) {
    switch (filterType) {
      case SurgeFilterType.all:
        return surgeData.where((s) => s.hasChange).toList();
      case SurgeFilterType.risingOnly:
        return surgeData.where((s) => s.isRising).toList();
      case SurgeFilterType.fallingOnly:
        return surgeData.where((s) => s.isFalling).toList();
    }
  }

  /// ✅ 모든 아이템의 상태 미리 계산 - TimeFrame enum 기반
  void _calculateAllStates(List<Surge> processedSurges) {
    final currentTimeFrame = this.currentTimeFrame;
    final currentTimeFrameKey = currentTimeFrame.key; // TimeFrame → String
    
    // ✅ 시간대 초기화 (String key 사용 - Mixin 호환)
    initializeTimeFrame(currentTimeFrameKey);
    _rankTracker.initializeTimeFrame(currentTimeFrameKey);
    
    // ✅ 현재 시간대 블링크 상태 초기화 (TimeFrame enum 사용)
    _initializeTimeFrameBlinkStates(currentTimeFrame);
    
    for (int i = 0; i < processedSurges.length; i++) {
      final surge = processedSurges[i];
      final market = surge.market;
      final currentRank = i + 1;
      
      // ✅ HOT 상태는 Mixin에서 직접 관리 (String key 사용)
      checkIfHot(
        key: market,
        currentRank: currentRank,
        timeFrame: currentTimeFrameKey,
        menuType: 'surge',
      );
      
      // ✅ 블링크 상태 계산 (Surge 전용 메서드 사용)
      final blinkStates = _blinkStatesByTimeFrame[currentTimeFrame]!;
      
      // 급등 체크 (순위 상승 + 실제 수치 개선)
      final isRankUp = _rankTracker.checkRankChangeWithValue(
        key: market,
        currentRank: currentRank,
        currentValue: surge.changePercent,
        timeFrame: currentTimeFrameKey,
      );
      
      // 급락 체크 (순위 하락 + 실제 수치 악화)  
      final isRankDown = _rankTracker.checkRankDropWithValue(
        key: market,
        currentRank: currentRank,
        currentValue: surge.changePercent,
        timeFrame: currentTimeFrameKey,
      );
      
      // 의미있는 변화가 있을 때만 블링크
      blinkStates[market] = isRankUp || isRankDown;
    }
  }

  /// ✅ 시간대별 블링크 상태 초기화 (TimeFrame enum)
  void _initializeTimeFrameBlinkStates(TimeFrame timeFrame) {
    if (!_blinkStatesByTimeFrame.containsKey(timeFrame)) {
      _blinkStatesByTimeFrame[timeFrame] = <String, bool>{};
    }
  }

  /// ✅ 특정 시간대 블링크 상태 초기화 (TimeFrame enum)
  void _clearTimeFrameBlinkStates(TimeFrame timeFrame) {
    _blinkStatesByTimeFrame[timeFrame]?.clear();
  }

  /// ✅ Top 50/100 토글 - Provider 구독 이슈 해결
  void toggleTopLimit() {
    state = state.copyWith(isTop100: !state.isTop100);
    
    // ✅ 현재 데이터로 재처리 (read + whenData 문제 해결)
    if (state.surges.isNotEmpty) {
      final currentState = _ref.read(surgeDataProvider).value;
      if (currentState != null) {
        _processSurgeData(currentState.surges);
      }
    }
  }

  /// ✅ 필터 타입 변경 - Provider 구독 이슈 해결
  void setFilterType(SurgeFilterType filterType) {
    state = state.copyWith(filterType: filterType);
    
    // ✅ 현재 데이터로 재처리
    if (state.surges.isNotEmpty) {
      final currentState = _ref.read(surgeDataProvider).value;
      if (currentState != null) {
        _processSurgeData(currentState.surges);
      }
    }
  }

  /// 🔥 시간대 변경 - timeFrameControllerProvider로 수정
  void setTimeFrame(TimeFrame timeFrame) {
    _ref.read(timeFrameControllerProvider).setTimeFrame(timeFrame);
    // 🎯 상태 초기화 제거 - 각 시간대가 독립적으로 유지됨
  }

  /// 🔥 시간대 변경 (인덱스 기반) - 호환성 유지
  void setTimeFrameByIndex(int index) {
    final availableTimeFrames = TimeFrame.fromAppConfig();
    if (index >= 0 && index < availableTimeFrames.length) {
      setTimeFrame(availableTimeFrames[index]);
    }
  }

  /// ✅ 현재 표시 개수
  int get currentLimit => state.isTop100 ? 100 : 50;
  
  /// ✅ 현재 표시 모드 이름
  String get currentLimitName => state.isTop100 ? 'Top 100' : 'Top 50';

  /// ✅ 현재 필터 타입 이름
  String get currentFilterName {
    switch (state.filterType) {
      case SurgeFilterType.all:
        return '전체';
      case SurgeFilterType.risingOnly:
        return '상승';
      case SurgeFilterType.fallingOnly:
        return '하락';
    }
  }

  /// ✅ HOT 상태 조회 (String key 사용 - Mixin 호환)
  bool isHot(String market) {
    final hotItems = getHotItems(currentTimeFrame.key);
    return hotItems.contains(market);
  }

  /// ✅ 블링크 상태 조회 - TimeFrame enum 기반
  bool shouldBlink(String market) {
    final currentTimeFrame = this.currentTimeFrame;
    final blinkStates = _blinkStatesByTimeFrame[currentTimeFrame];
    return blinkStates?[market] ?? false;
  }

  /// ✅ 블링크 상태 초기화 - 강제 notify 문제 해결
  void clearBlinkState(String market) {
    final currentTimeFrame = this.currentTimeFrame;
    final blinkStates = _blinkStatesByTimeFrame[currentTimeFrame];
    if (blinkStates != null) {
      blinkStates[market] = false;
      // ✅ 실제 변화가 있을 때만 notify (불필요한 copyWith 제거)
    }
  }

  /// ✅ 급등/급락 카운트 계산
  Map<String, int> getSurgeCount() {
    final risingCount = state.surges.where((s) => s.isRising).length;
    final fallingCount = state.surges.where((s) => s.isFalling).length;
    
    return {
      'rising': risingCount,
      'falling': fallingCount,
    };
  }

  /// ✅ TimeFrame 관련 메서드들 - timeFrameControllerProvider로 수정
  TimeFrame get currentTimeFrame => _ref.read(timeFrameControllerProvider).currentTimeFrame;
  
  int get currentIndex => _ref.read(timeFrameControllerProvider).currentIndex;
  
  List<TimeFrame> get availableTimeFrames => _ref.read(timeFrameControllerProvider).availableTimeFrames;

  String getTimeFrameName(TimeFrame timeFrame) {
    return _ref.read(timeFrameControllerProvider).getTimeFrameName(timeFrame);
  }

  void resetCurrentTimeFrame() {
    _ref.read(timeFrameControllerProvider).resetCurrentTimeFrame();
  }

  void resetAllTimeFrames() {
    _ref.read(timeFrameControllerProvider).resetAllTimeFrames();
  }

  /// 🔥 완벽한 타이머 동기화 - timeFrameControllerProvider 사용
  DateTime? getNextResetTime() {
    return _ref.read(timeFrameControllerProvider).getNextResetTime();
  }

  /// ✅ 디버깅용 메서드들
  Map<String, int> getBlinkDebugInfo() {
    return _rankTracker.getDebugInfo();
  }

  /// ✅ 메모리 정리
  void cleanupExpiredStates() {
    cleanupExpiredHotStates();
    _cleanupOldBlinkStates();
  }

  /// ✅ 오래된 블링크 상태 정리 (TimeFrame enum 기반)
  void _cleanupOldBlinkStates() {
    final currentTimeFrame = this.currentTimeFrame;
    final availableTimeFrames = this.availableTimeFrames.toSet();
    
    _blinkStatesByTimeFrame.removeWhere((timeFrame, _) => 
      timeFrame != currentTimeFrame && !availableTimeFrames.contains(timeFrame)
    );
  }

  /// ✅ 리소스 정리
  @override
  void dispose() {
    // Provider 구독 해제
    for (final subscription in _subscriptions) {
      subscription.close();
    }
    _subscriptions.clear();
    
    // ✅ 모든 리소스 정리
    disposeHot();
    _rankTracker.dispose();
    _blinkStatesByTimeFrame.clear();
    
    super.dispose();
  }
}

/// ✅ 상태 클래스 (변경 없음)
class SurgeControllerState {
  final List<Surge> surges;           // 정렬/필터링된 급등/급락 데이터
  final bool isTop100;               // Top 50/100 모드
  final SurgeFilterType filterType;  // 필터 타입
  final bool isLoading;              // 로딩 상태
  final String? errorMessage;        // 에러 메시지

  const SurgeControllerState({
    this.surges = const [],
    this.isTop100 = false,
    this.filterType = SurgeFilterType.all,
    this.isLoading = false,
    this.errorMessage,
  });

  SurgeControllerState copyWith({
    List<Surge>? surges,
    bool? isTop100,
    SurgeFilterType? filterType,
    bool? isLoading,
    String? errorMessage,
  }) {
    return SurgeControllerState(
      surges: surges ?? this.surges,
      isTop100: isTop100 ?? this.isTop100,
      filterType: filterType ?? this.filterType,
      isLoading: isLoading ?? this.isLoading,
      errorMessage: errorMessage ?? this.errorMessage,
    );
  }
}

/// Surge 필터 타입 enum
enum SurgeFilterType {
  all,        // 전체
  risingOnly, // 상승만
  fallingOnly // 하락만
}

/// Provider 선언 - UI용 SurgeController
final surgeControllerProvider = StateNotifierProvider<SurgeController, SurgeControllerState>(
  (ref) => SurgeController(ref),
);