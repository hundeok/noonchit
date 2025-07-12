import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../core/di/volume_provider.dart';
import '../../core/common/time_frame_manager.dart'; // 🔥 간소화된 TimeFrame 시스템 사용
import '../../core/common/time_frame_types.dart';   // 🔥 공통 타입 사용
import '../../domain/entities/volume.dart';
import '../../shared/utils/rank_tracker.dart';
import '../../shared/utils/rank_hot_mixin.dart';

/// 🎯 간소화된 VolumeController - Trade 스타일
class VolumeController extends StateNotifier<VolumeControllerState> with RankHotMixin {
  final Ref _ref;
  
  // ✅ 순위 추적기 (블링크용)
  final RankTracker _rankTracker = RankTracker();
  
  // ✅ 시간대별 블링크 상태 관리 (TimeFrame enum 기반)
  final Map<TimeFrame, Map<String, bool>> _blinkStatesByTimeFrame = {};
  
  // ✅ Provider 구독 관리
  final List<ProviderSubscription> _subscriptions = [];

  VolumeController(this._ref) : super(const VolumeControllerState()) {
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
      volumeDataProvider,
      (previous, next) {
        next.when(
          data: (event) {
            // 🚀 데이터 처리
            _processVolumeData(event.volumes);
            
            // 🔥 리셋 정보 처리 (새로운 VolumeEvent 구조)
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

  /// ✅ 볼륨 데이터 처리
  void _processVolumeData(List<Volume> volumes) {
    // ✅ Provider에서 이미 정렬된 데이터를 제한만 적용
    final processedVolumes = _applyLimit(volumes);
    
    // ✅ 모든 상태 미리 계산
    _calculateAllStates(processedVolumes);
    
    // ✅ 상태 업데이트
    state = state.copyWith(
      volumes: processedVolumes,
      isLoading: false,
      errorMessage: null,
    );
  }

  /// ✅ 제한만 적용 (정렬은 Provider에서 완료)
  List<Volume> _applyLimit(List<Volume> volumes) {
    final int limit = state.isTop100 ? 100 : 50;
    return volumes.take(limit).toList();
  }

  /// ✅ 모든 아이템의 상태 미리 계산 - TimeFrame enum 기반
  void _calculateAllStates(List<Volume> processedVolumes) {
    final currentTimeFrame = this.currentTimeFrame;
    final currentTimeFrameKey = currentTimeFrame.key; // TimeFrame → String
    
    // ✅ 시간대 초기화 (String key 사용 - Mixin 호환)
    initializeTimeFrame(currentTimeFrameKey);
    _rankTracker.initializeTimeFrame(currentTimeFrameKey);
    
    // ✅ 현재 시간대 블링크 상태 초기화 (TimeFrame enum 사용)
    _initializeTimeFrameBlinkStates(currentTimeFrame);
    
    for (int i = 0; i < processedVolumes.length; i++) {
      final volume = processedVolumes[i];
      final market = volume.market;
      final currentRank = i + 1;
      
      // ✅ HOT 상태는 Mixin에서 직접 관리 (String key 사용)
      checkIfHot(
        key: market,
        currentRank: currentRank,
        timeFrame: currentTimeFrameKey,
        menuType: 'volume',
      );
      
      // ✅ 블링크 상태 계산 (Volume 전용 메서드 사용)
      final blinkStates = _blinkStatesByTimeFrame[currentTimeFrame]!;
      
      // 볼륨 순위 변화 체크 (순위 + 실제 볼륨 값 기준)
      final isRankChange = _rankTracker.checkRankChangeWithValue(
        key: market,
        currentRank: currentRank,
        currentValue: volume.totalVolume,
        timeFrame: currentTimeFrameKey,
      );
      
      // 의미있는 변화가 있을 때만 블링크
      blinkStates[market] = isRankChange;
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
    if (state.volumes.isNotEmpty) {
      final currentState = _ref.read(volumeDataProvider).value;
      if (currentState != null) {
        _processVolumeData(currentState.volumes);
      }
    }
  }

  /// 🔥 시간대 변경 - Trade 스타일 (직접 Provider 조작)
  void setTimeFrame(TimeFrame timeFrame) {
    _ref.read(volumeSelectedTimeFrameProvider.notifier).state = timeFrame;
    // 🎯 상태 초기화 제거 - 각 시간대가 독립적으로 유지됨
  }

  /// 🔥 시간대 변경 (인덱스 기반) - 호환성 유지
  void setTimeFrameByIndex(int index) {
    final availableTimeFrames = this.availableTimeFrames;
    if (index >= 0 && index < availableTimeFrames.length) {
      setTimeFrame(availableTimeFrames[index]);
    }
  }

  /// ✅ 현재 표시 개수
  int get currentLimit => state.isTop100 ? 100 : 50;

  /// ✅ 현재 표시 모드 이름
  String get currentLimitName => state.isTop100 ? 'Top 100' : 'Top 50';

  /// ✅ HOT 상태 조회 (String key 사용 - Mixin 호환)
  bool isHot(String market) {
    final hotItems = getHotItems(currentTimeFrame.key);
    return hotItems.contains(market);
  }

  /// ✅ 블링크 상태 조회 - TimeFrame enum 기준
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

  /// 🔥 TimeFrame 관련 메서드들 - 간소화된 구조
  TimeFrame get currentTimeFrame => _ref.read(volumeSelectedTimeFrameProvider);
  
  int get currentIndex {
    final availableTimeFrames = this.availableTimeFrames;
    return availableTimeFrames.indexOf(currentTimeFrame);
  }
  
  List<TimeFrame> get availableTimeFrames => TimeFrame.fromAppConfig();
  
  String getTimeFrameName(TimeFrame timeFrame) => timeFrame.displayName;

  /// 🔥 리셋 메서드들 - 간소화된 Manager 직접 사용
  void resetCurrentTimeFrame() {
    final currentTimeFrame = this.currentTimeFrame;
    GlobalTimeFrameManager().resetTimeFrame(currentTimeFrame);
  }

  void resetAllTimeFrames() {
    GlobalTimeFrameManager().resetAll();
  }

  /// 🔥 완벽한 타이머 동기화 - 간소화된 Manager 직접 사용
  DateTime? getNextResetTime() {
    final currentTimeFrame = this.currentTimeFrame;
    return GlobalTimeFrameManager().getNextResetTime(currentTimeFrame);
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
class VolumeControllerState {
  final List<Volume> volumes; // 정렬된 볼륨 데이터
  final bool isTop100; // Top 50/100 모드
  final bool isLoading; // 로딩 상태
  final String? errorMessage; // 에러 메시지

  const VolumeControllerState({
    this.volumes = const [],
    this.isTop100 = false,
    this.isLoading = false,
    this.errorMessage,
  });

  VolumeControllerState copyWith({
    List<Volume>? volumes,
    bool? isTop100,
    bool? isLoading,
    String? errorMessage,
  }) {
    return VolumeControllerState(
      volumes: volumes ?? this.volumes,
      isTop100: isTop100 ?? this.isTop100,
      isLoading: isLoading ?? this.isLoading,
      errorMessage: errorMessage ?? this.errorMessage,
    );
  }
}

/// Provider 선언 - UI용 VolumeController (변경 없음)
final volumeControllerProvider = StateNotifierProvider<VolumeController, VolumeControllerState>(
  (ref) => VolumeController(ref),
);