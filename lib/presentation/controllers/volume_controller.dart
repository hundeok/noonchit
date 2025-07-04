// lib/presentation/controllers/volume_controller.dart

import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../core/di/volume_provider.dart';
import '../../domain/entities/volume.dart';
import '../../domain/usecases/volume_usecase.dart';
import '../../shared/utils/rank_tracker.dart';
import '../../shared/utils/rank_hot_mixin.dart';

/// 🎯 깔끔하게 리팩토링된 VolumeController (Provider 연동)
class VolumeController extends StateNotifier<VolumeControllerState> with RankHotMixin {
  final Ref _ref;
  final VolumeUsecase _usecase;
  
  // ✅ 순위 추적기 (블링크용)
  final RankTracker _rankTracker = RankTracker();
  
  // ✅ 미리 계산된 상태 저장 (블링크만, HOT은 Mixin에서 관리)
  final Map<String, bool> _blinkStates = {};
  
  // ✅ Provider 구독 관리
  final List<ProviderSubscription> _subscriptions = [];

  VolumeController(this._usecase, this._ref) : super(const VolumeControllerState()) {
    // ✅ 모든 상태 초기화
    _initializeAllStates();
    _initializeDataSubscription();
  }

  /// ✅ 모든 상태 초기화 (HOT은 Mixin에서 관리하므로 제외)
  void _initializeAllStates() {
    clearAllHot();
    _rankTracker.clearAll();
    _blinkStates.clear();
  }

  /// 🔥 통합 데이터 구독 초기화 (VolumeEvent 처리)
  void _initializeDataSubscription() {
    final subscription = _ref.listen(
      volumeDataProvider,
      (previous, next) {
        next.when(
          data: (event) {
            // 🚀 데이터 처리 (기존 로직 그대로)
            _processVolumeData(event.volumes);
            
            // 🔥 리셋 정보 처리 (새로 추가)
            if (event.resetTimeFrame != null) {
              clearTimeFrameHot(event.resetTimeFrame!);
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

  /// ✅ 볼륨 데이터 처리 - 모든 상태 미리 계산
  void _processVolumeData(List<Volume> volumes) {
    // 1. 데이터 정렬
    final sortedVolumes = _applySorting(volumes);
    
    // 2. 모든 상태 미리 계산 (build 밖에서!)
    _calculateAllStates(sortedVolumes);
    
    // 3. 상태 업데이트
    state = state.copyWith(
      volumes: sortedVolumes,
      isLoading: false,
      errorMessage: null,
    );
  }

  /// ✅ 모든 아이템의 상태 미리 계산 - 시간대별 독립
  void _calculateAllStates(List<Volume> sortedVolumes) {
    final currentTimeFrame = this.currentTimeFrame;
    
    // ✅ 시간대 초기화
    initializeTimeFrame(currentTimeFrame);
    _rankTracker.initializeTimeFrame(currentTimeFrame);
    
    // ✅ 블링크 상태만 초기화 (HOT은 Mixin이 관리)
    _blinkStates.clear();
    
    for (int i = 0; i < sortedVolumes.length; i++) {
      final volume = sortedVolumes[i];
      final market = volume.market;
      final currentRank = i + 1;
      
      // ✅ HOT 상태는 Mixin에서 직접 관리 (Controller는 개입 안함)
      checkIfHot(
        key: market,
        currentRank: currentRank,
        timeFrame: currentTimeFrame,
        menuType: 'volume', 
      );
      
      // ✅ 블링크 상태 계산 (RankTracker 사용)
      _blinkStates[market] = _rankTracker.checkRankChange(
        key: market,
        currentRank: currentRank,
        timeFrame: currentTimeFrame,
      );
    }
  }

  /// ✅ 데이터 정렬 (순수 함수)
  List<Volume> _applySorting(List<Volume> volumeData) {
    // UseCase의 순수 함수 사용
    final filteredData = _usecase.filterVolumesByMinimum(volumeData, 0);
    final sortedData = _usecase.sortVolumesByAmount(filteredData, descending: true);
    
    // 현재 설정에 따라 50개 또는 100개로 제한
    final int limit = state.isTop100 ? 100 : 50;
    return _usecase.limitVolumeCount(sortedData, limit);
  }

  /// ✅ Top 50/100 토글
  void toggleTopLimit() {
    state = state.copyWith(isTop100: !state.isTop100);
    
    // 기존 데이터로 재처리
    if (state.volumes.isNotEmpty) {
      final volumesAsync = _ref.read(volumeDataProvider);
      volumesAsync.whenData((event) => _processVolumeData(event.volumes));
    }
  }

  /// 🔥 시간대 변경 - Provider로 위임
  void setTimeFrame(String timeFrame, int index) {
    // ✅ Provider로 위임 (UseCase 직접 호출 제거)
    _ref.read(volumeTimeFrameController).updateTimeFrame(timeFrame, index);
    // 🎯 상태 초기화 제거 - 각 시간대가 독립적으로 유지됨
  }

  /// ✅ 현재 표시 개수
  int get currentLimit => state.isTop100 ? 100 : 50;
  
  /// ✅ 현재 표시 모드 이름
  String get currentLimitName => state.isTop100 ? 'Top 100' : 'Top 50';

  /// ✅ HOT 상태 조회 (Mixin의 현재 HOT 아이템 목록에서 확인)
  bool isHot(String market) {
    final hotItems = getHotItems(currentTimeFrame);
    return hotItems.contains(market);
  }

  /// ✅ 블링크 상태 조회 (build에서 안전하게 호출 가능)
  bool shouldBlink(String market) {
    return _blinkStates[market] ?? false;
  }

  /// ✅ 블링크 상태 초기화 (애니메이션 완료 후 호출)
  void clearBlinkState(String market) {
    _blinkStates[market] = false;
    // 상태 업데이트를 위한 notify
    state = state.copyWith();
  }

  /// ✅ TimeFrame 관련 메서드들 - Provider로 위임
  String get currentTimeFrame => _ref.read(volumeTimeFrameController).currentTimeFrame;
  int get currentIndex => _ref.read(volumeTimeFrameController).currentIndex;
  List<String> get availableTimeFrames => _ref.read(volumeTimeFrameController).availableTimeFrames;

  String getTimeFrameName(String timeFrame) {
    return _ref.read(volumeTimeFrameController).getTimeFrameName(timeFrame);
  }

  void resetCurrentTimeFrame() {
    _ref.read(volumeTimeFrameController).resetCurrentTimeFrame();
  }

  void resetAllTimeFrames() {
    _ref.read(volumeTimeFrameController).resetAllTimeFrames();
  }

  DateTime? getNextResetTime() {
    return _ref.read(volumeTimeFrameController).getNextResetTime();
  }

  /// ✅ 볼륨 포맷팅 (UseCase 활용)
  String formatVolume(double volume) {
    return _usecase.formatVolume(volume);
  }

  /// ✅ 시간대 진행률 계산 (UseCase 활용)
  double getTimeFrameProgress() {
    final timeFrame = currentTimeFrame;
    final now = DateTime.now();
    
    return _usecase.calculateTimeFrameProgress(timeFrame, now);
  }

  /// ✅ 리셋까지 남은 시간 (UseCase 활용)
  Duration? getTimeUntilReset() {
    final timeFrame = currentTimeFrame;
    final now = DateTime.now();
    
    return _usecase.getTimeUntilReset(timeFrame, now);
  }

  /// ✅ 디버깅용 메서드들
  Map<String, int> getBlinkDebugInfo() {
    return _rankTracker.getDebugInfo();
  }

  /// ✅ 메모리 정리 (주기적으로 호출 권장)
  void cleanupExpiredStates() {
    cleanupExpiredHotStates();
  }

  /// ✅ 리소스 정리
  @override
  void dispose() {
    // Provider 구독 해제
    for (final subscription in _subscriptions) {
      subscription.close();
    }
    _subscriptions.clear();
    
    // ✅ 모든 리소스 정리 (HOT은 Mixin이 관리)
    disposeHot();
    _rankTracker.dispose();
    _blinkStates.clear();
    
    super.dispose();
  }
}

/// ✅ 상태 클래스 (변경 없음)
class VolumeControllerState {
  final List<Volume> volumes;      // 정렬된 볼륨 데이터
  final bool isTop100;            // Top 50/100 모드
  final bool isLoading;           // 로딩 상태
  final String? errorMessage;     // 에러 메시지

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

/// Provider 선언
final volumeControllerProvider = StateNotifierProvider<VolumeController, VolumeControllerState>(
  (ref) {
    final usecase = ref.read(volumeUsecaseProvider);  // ✅ 기존 Provider 이름 사용
    return VolumeController(usecase, ref);
  },
);