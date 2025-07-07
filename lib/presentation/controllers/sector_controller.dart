import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../core/di/sector_provider.dart';
import '../../core/common/time_frame_types.dart'; // 🔥 공통 타입 추가
import '../../domain/entities/volume.dart';
import '../../shared/utils/rank_tracker.dart';
import '../../shared/utils/rank_hot_mixin.dart';

/// 🎯 완전 수정된 SectorController - 공통 TimeFrame 시스템 연동
class SectorController extends StateNotifier<SectorControllerState> with RankHotMixin {
  final Ref _ref;
  
  // ✅ 순위 추적기 (블링크용)
  final RankTracker _rankTracker = RankTracker();
  
  // ✅ 시간대별 블링크 상태 관리 (TimeFrame enum 기반)
  final Map<TimeFrame, Map<String, bool>> _blinkStatesByTimeFrame = {};
  
  // ✅ Provider 구독 관리
  final List<ProviderSubscription> _subscriptions = [];

  SectorController(this._ref) : super(const SectorControllerState()) {
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
      sectorVolumeDataProvider,
      (previous, next) {
        next.when(
          data: (event) {
            // 🚀 데이터 처리
            _processSectorData(event.volumes);
            
            // 🔥 리셋 정보 처리 (새로운 SectorVolumeEvent 구조)
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

  /// ✅ 섹터 데이터 처리
  void _processSectorData(List<Volume> volumes) {
    // ✅ Provider에서 이미 정렬된 데이터 그대로 사용
    final processedVolumes = volumes;
    
    // ✅ 모든 상태 미리 계산
    _calculateAllStates(processedVolumes);
    
    // ✅ 상태 업데이트
    state = state.copyWith(
      sectorVolumes: processedVolumes,
      isLoading: false,
      errorMessage: null,
    );
  }

  /// ✅ 모든 아이템의 상태 미리 계산 - TimeFrame enum 기반
  void _calculateAllStates(List<Volume> volumes) {
    final currentTimeFrame = this.currentTimeFrame;
    final currentTimeFrameKey = currentTimeFrame.key; // TimeFrame → String
    
    // ✅ 시간대 초기화 (String key 사용 - Mixin 호환)
    initializeTimeFrame(currentTimeFrameKey);
    _rankTracker.initializeTimeFrame(currentTimeFrameKey);
    
    // ✅ 현재 시간대 블링크 상태 초기화 (TimeFrame enum 사용)
    _initializeTimeFrameBlinkStates(currentTimeFrame);
    
    for (int i = 0; i < volumes.length; i++) {
      final volume = volumes[i];
      final sectorName = volume.market.replaceFirst('SECTOR-', '');
      final currentRank = i + 1;
      
      // ✅ HOT 상태는 Mixin에서 직접 관리 (String key 사용)
      checkIfHot(
        key: sectorName,
        currentRank: currentRank,
        timeFrame: currentTimeFrameKey,
        menuType: 'sector',
      );
      
      // ✅ 블링크 상태 계산 (Sector 전용 메서드 사용)
      final blinkStates = _blinkStatesByTimeFrame[currentTimeFrame]!;
      
      // 섹터 순위 변화 체크 (순위 + 실제 볼륨 값 기준)
      final isRankChange = _rankTracker.checkRankChangeWithValue(
        key: sectorName,
        currentRank: currentRank,
        currentValue: volume.totalVolume,
        timeFrame: currentTimeFrameKey,
      );
      
      // 의미있는 변화가 있을 때만 블링크
      blinkStates[sectorName] = isRankChange;
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

  /// 🔥 시간대 변경 - sectorTimeFrameController 사용 (기존 유지)
  void setTimeFrame(TimeFrame timeFrame) {
    _ref.read(sectorTimeFrameController).setTimeFrame(timeFrame);
    // 🎯 상태 초기화 제거 - 각 시간대가 독립적으로 유지됨
  }

  /// 🔥 시간대 변경 (인덱스 기반) - 호환성 유지
  void setTimeFrameByIndex(int index) {
    final availableTimeFrames = TimeFrame.fromAppConfig();
    if (index >= 0 && index < availableTimeFrames.length) {
      setTimeFrame(availableTimeFrames[index]);
    }
  }

  /// 🚀 섹터 분류 토글 - 섹터만의 고유 기능
  void toggleSectorClassification() {
    _ref.read(sectorTimeFrameController).toggleSectorClassification();
  }

  /// ✅ HOT 상태 조회 (String key 사용 - Mixin 호환)
  bool isHot(String sectorName) {
    final hotItems = getHotItems(currentTimeFrame.key);
    return hotItems.contains(sectorName);
  }

  /// ✅ 블링크 상태 조회 - TimeFrame enum 기반
  bool shouldBlink(String sectorName) {
    final currentTimeFrame = this.currentTimeFrame;
    final blinkStates = _blinkStatesByTimeFrame[currentTimeFrame];
    return blinkStates?[sectorName] ?? false;
  }

  /// ✅ 블링크 상태 초기화 - 강제 notify 문제 해결
  void clearBlinkState(String sectorName) {
    final currentTimeFrame = this.currentTimeFrame;
    final blinkStates = _blinkStatesByTimeFrame[currentTimeFrame];
    if (blinkStates != null) {
      blinkStates[sectorName] = false;
      // ✅ 실제 변화가 있을 때만 notify (불필요한 copyWith 제거)
    }
  }

  /// ✅ TimeFrame 관련 메서드들 - sectorTimeFrameController 사용 (기존 유지)
  TimeFrame get currentTimeFrame => _ref.read(sectorTimeFrameController).currentTimeFrame;
  
  int get currentIndex => _ref.read(sectorTimeFrameController).currentIndex;
  
  List<TimeFrame> get availableTimeFrames => _ref.read(sectorTimeFrameController).availableTimeFrames;

  String getTimeFrameName(TimeFrame timeFrame) {
    return _ref.read(sectorTimeFrameController).getTimeFrameName(timeFrame);
  }

  void resetCurrentTimeFrame() {
    _ref.read(sectorTimeFrameController).resetCurrentTimeFrame();
  }

  void resetAllTimeFrames() {
    _ref.read(sectorTimeFrameController).resetAllTimeFrames();
  }

  /// 🔥 완벽한 타이머 동기화 - sectorTimeFrameController 사용 (기존 유지)
  DateTime? getNextResetTime() {
    return _ref.read(sectorTimeFrameController).getNextResetTime();
  }

  /// 🚀 섹터 고유 기능들 (기존 유지)
  String get currentSectorClassificationName {
    return _ref.read(sectorTimeFrameController).currentSectorClassificationName;
  }

  bool get isDetailedClassification {
    return _ref.read(sectorTimeFrameController).isDetailedClassification;
  }

  int get totalSectors {
    return _ref.read(sectorTimeFrameController).totalSectors;
  }

  Map<String, int> getSectorSizes() {
    return _ref.read(sectorTimeFrameController).getSectorSizes();
  }

  /// ✅ 특정 섹터의 코인들 조회
  List<String> getCoinsInSector(String sectorName) {
    return _ref.read(sectorTimeFrameController).getCoinsInSector(sectorName);
  }

  /// ✅ 특정 코인이 속한 섹터들 조회
  List<String> getSectorsForCoin(String ticker) {
    return _ref.read(sectorTimeFrameController).getSectorsForCoin(ticker);
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
class SectorControllerState {
  final List<Volume> sectorVolumes;        // 정렬된 섹터 볼륨 데이터
  final bool isLoading;                   // 로딩 상태
  final String? errorMessage;             // 에러 메시지

  const SectorControllerState({
    this.sectorVolumes = const [],
    this.isLoading = false,
    this.errorMessage,
  });

  SectorControllerState copyWith({
    List<Volume>? sectorVolumes,
    bool? isLoading,
    String? errorMessage,
  }) {
    return SectorControllerState(
      sectorVolumes: sectorVolumes ?? this.sectorVolumes,
      isLoading: isLoading ?? this.isLoading,
      errorMessage: errorMessage ?? this.errorMessage,
    );
  }
}

/// Provider 선언 - UI용 SectorController
final sectorControllerProvider = StateNotifierProvider<SectorController, SectorControllerState>(
  (ref) => SectorController(ref),
);