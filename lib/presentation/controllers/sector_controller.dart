import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../core/di/sector_provider.dart';
import '../../domain/entities/volume.dart';
import '../../shared/utils/rank_tracker.dart';
import '../../shared/utils/rank_hot_mixin.dart';

/// 🚀 수정된 SectorController - Volume Controller와 동일한 개선 적용
class SectorController extends StateNotifier<SectorControllerState> with RankHotMixin {
  final Ref _ref;
  
  // ✅ 순위 추적기 (블링크용)
  final RankTracker _rankTracker = RankTracker();
  
  // ✅ 시간대별 블링크 상태 관리 (독립성 확보)
  final Map<String, Map<String, bool>> _blinkStatesByTimeFrame = {};
  
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

  /// 🚀 통합 데이터 구독 초기화
  void _initializeDataSubscription() {
    final subscription = _ref.listen(
      sectorVolumeDataProvider,
      (previous, next) {
        next.when(
          data: (event) {
            // 🚀 데이터 처리 (이중 정렬 제거)
            _processSectorData(event.volumes);
            
            // 🔥 리셋 정보 처리
            if (event.resetTimeFrame != null) {
              clearTimeFrameHot(event.resetTimeFrame!);
              _clearTimeFrameBlinkStates(event.resetTimeFrame!);
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

  /// ✅ 섹터 데이터 처리 - 이중 정렬 제거
  void _processSectorData(List<Volume> volumes) {
    // ✅ 이미 정렬된 데이터 그대로 사용 (Provider에서 정렬 완료)
    _calculateAllStates(volumes);
    
    // ✅ 상태 업데이트
    state = state.copyWith(
      sectorVolumes: volumes,
      isLoading: false,
      errorMessage: null,
    );
  }

  /// ✅ 모든 아이템의 상태 미리 계산 - 시간대별 독립
  void _calculateAllStates(List<Volume> volumes) {
    final currentTimeFrame = this.currentTimeFrame;
    
    // ✅ 시간대 초기화
    initializeTimeFrame(currentTimeFrame);
    _rankTracker.initializeTimeFrame(currentTimeFrame);
    
    // ✅ 현재 시간대 블링크 상태 초기화
    _initializeTimeFrameBlinkStates(currentTimeFrame);
    
    for (int i = 0; i < volumes.length; i++) {
      final volume = volumes[i];
      final sectorName = volume.market.replaceFirst('SECTOR-', '');
      final currentRank = i + 1;
      
      // ✅ HOT 상태는 Mixin에서 직접 관리
      checkIfHot(
        key: sectorName,
        currentRank: currentRank,
        timeFrame: currentTimeFrame,
        menuType: 'sector',
      );
      
      // ✅ 블링크 상태 계산 (시간대별 관리)
      final blinkStates = _blinkStatesByTimeFrame[currentTimeFrame]!;
      blinkStates[sectorName] = _rankTracker.checkRankChange(
        key: sectorName,
        currentRank: currentRank,
        timeFrame: currentTimeFrame,
      );
    }
  }

  /// ✅ 시간대별 블링크 상태 초기화
  void _initializeTimeFrameBlinkStates(String timeFrame) {
    if (!_blinkStatesByTimeFrame.containsKey(timeFrame)) {
      _blinkStatesByTimeFrame[timeFrame] = <String, bool>{};
    }
  }

  /// ✅ 특정 시간대 블링크 상태 초기화
  void _clearTimeFrameBlinkStates(String timeFrame) {
    _blinkStatesByTimeFrame[timeFrame]?.clear();
  }

  /// 🚀 시간대 변경 - Provider로 위임
  void setTimeFrame(String timeFrame, int index) {
    _ref.read(sectorTimeFrameController).updateTimeFrame(timeFrame, index);
    // 🎯 상태 초기화 제거 - 각 시간대가 독립적으로 유지됨
  }

  /// 🚀 섹터 분류 토글 - 섹터만의 고유 기능
  void toggleSectorClassification() {
    _ref.read(sectorTimeFrameController).toggleSectorClassification();
  }

  /// ✅ HOT 상태 조회
  bool isHot(String sectorName) {
    final hotItems = getHotItems(currentTimeFrame);
    return hotItems.contains(sectorName);
  }

  /// ✅ 블링크 상태 조회 - 시간대별 관리
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

  /// ✅ TimeFrame 관련 메서드들 - Provider로 위임
  String get currentTimeFrame => _ref.read(sectorTimeFrameController).currentTimeFrame;
  int get currentIndex => _ref.read(sectorTimeFrameController).currentIndex;
  List<String> get availableTimeFrames => _ref.read(sectorTimeFrameController).availableTimeFrames;

  String getTimeFrameName(String timeFrame) {
    return _ref.read(sectorTimeFrameController).getTimeFrameName(timeFrame);
  }

  void resetCurrentTimeFrame() {
    _ref.read(sectorTimeFrameController).resetCurrentTimeFrame();
  }

  void resetAllTimeFrames() {
    _ref.read(sectorTimeFrameController).resetAllTimeFrames();
  }

  DateTime? getNextResetTime() {
    return _ref.read(sectorTimeFrameController).getNextResetTime();
  }

  /// 🚀 섹터 고유 기능들
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

  /// ✅ 오래된 블링크 상태 정리
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

/// Provider 선언
final sectorControllerProvider = StateNotifierProvider<SectorController, SectorControllerState>(
  (ref) => SectorController(ref),
);