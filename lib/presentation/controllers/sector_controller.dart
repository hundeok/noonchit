// lib/presentation/controllers/sector_controller.dart

import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../core/di/sector_provider.dart';
import '../../domain/entities/volume.dart';

/// 섹터 화면 상태를 캡슐화하는 immutable 모델
class SectorState {
  final List<Volume> sectorVolumes;
  final bool isLoading;
  final bool isDetailedClassification;
  final String timeFrame;
  final int selectedTimeFrameIndex;
  final String? errorMessage;

  const SectorState({
    this.sectorVolumes = const [],
    this.isLoading = false,
    this.isDetailedClassification = true,
    this.timeFrame = '1m',
    this.selectedTimeFrameIndex = 0,
    this.errorMessage,
  });

  SectorState copyWith({
    List<Volume>? sectorVolumes,
    bool? isLoading,
    bool? isDetailedClassification,
    String? timeFrame,
    int? selectedTimeFrameIndex,
    String? errorMessage,
  }) {
    return SectorState(
      sectorVolumes: sectorVolumes ?? this.sectorVolumes,
      isLoading: isLoading ?? this.isLoading,
      isDetailedClassification: isDetailedClassification ?? this.isDetailedClassification,
      timeFrame: timeFrame ?? this.timeFrame,
      selectedTimeFrameIndex: selectedTimeFrameIndex ?? this.selectedTimeFrameIndex,
      errorMessage: errorMessage,
    );
  }
}

/// Sector 화면 전용 ViewModel
class SectorController extends StateNotifier<SectorState> {
  final Ref _ref;
  ProviderSubscription<AsyncValue<List<Volume>>>? _subscription;

  SectorController(this._ref) : super(const SectorState()) {
    _initializeStream();
  }

  /// 섹터 볼륨 스트림 구독 초기화
  void _initializeStream() {
    _subscription?.close();
    
    final controller = _ref.read(sectorTimeFrameController);
    
    state = state.copyWith(
      isLoading: true,
      isDetailedClassification: controller.isDetailedClassification,
      timeFrame: controller.currentTimeFrame,
      selectedTimeFrameIndex: controller.currentIndex,
      errorMessage: null,
    );

    // AsyncValue 직접 구독
    _subscription = _ref.listen(sectorVolumeDataProvider, (previous, next) {
      next.when(
        data: (volumes) {
          state = state.copyWith(
            sectorVolumes: volumes,
            isLoading: false,
            errorMessage: null,
          );
        },
        loading: () {
          state = state.copyWith(
            isLoading: true,
            errorMessage: null,
          );
        },
        error: (error, stackTrace) {
          state = state.copyWith(
            isLoading: false,
            errorMessage: error.toString(),
          );
        },
      );
    });
  }

  /// 시간대 변경
  void setTimeFrame(String timeFrame, int index) {
    final controller = _ref.read(sectorTimeFrameController);
    controller.updateTimeFrame(timeFrame, index);
    
    state = state.copyWith(
      timeFrame: timeFrame,
      selectedTimeFrameIndex: index,
      isLoading: true,
      errorMessage: null,
    );
    
    // 스트림 재구독
    _initializeStream();
  }

  /// 섹터 분류 토글 (상세 ↔ 기본)
  void toggleSectorClassification() {
    final controller = _ref.read(sectorTimeFrameController);
    controller.toggleSectorClassification();
    
    state = state.copyWith(
      isDetailedClassification: !state.isDetailedClassification,
      isLoading: true,
      errorMessage: null,
    );
    
    // 스트림 재구독 (새로운 분류로)
    _initializeStream();
  }

  /// 새로고침
  void refresh() {
    _initializeStream();
  }

  /// 섹터 목록 필터링 (섹터명으로)
  List<Volume> filterBySector(String? sectorFilter) {
    if (sectorFilter == null || sectorFilter.isEmpty) {
      return state.sectorVolumes;
    }
    final upper = sectorFilter.toUpperCase();
    return state.sectorVolumes.where((volume) {
      final sectorName = volume.market.replaceFirst('SECTOR-', '');
      return sectorName.contains(upper);
    }).toList();
  }

  /// 섹터 목록 정렬
  void sortSectors(String field, bool ascending) {
    final list = [...state.sectorVolumes];
    list.sort((a, b) {
      dynamic aValue;
      dynamic bValue;
      switch (field) {
        case 'sector':
          aValue = a.market.replaceFirst('SECTOR-', '');
          bValue = b.market.replaceFirst('SECTOR-', '');
          break;
        case 'volume':
          aValue = a.totalVolume;
          bValue = b.totalVolume;
          break;
        case 'timestamp':
          aValue = a.lastUpdatedMs;
          bValue = b.lastUpdatedMs;
          break;
        default:
          aValue = a.totalVolume;
          bValue = b.totalVolume;
      }
      final cmp = aValue is Comparable && bValue is Comparable
          ? aValue.compareTo(bValue)
          : 0;
      return ascending ? cmp : -cmp;
    });
    state = state.copyWith(sectorVolumes: list);
  }

  /// 섹터 볼륨 데이터 정렬 적용 (기본: 볼륨 내림차순)
  List<Volume> applySorting(List<Volume> volumes) {
    final sorted = [...volumes];
    sorted.sort((a, b) => b.totalVolume.compareTo(a.totalVolume));
    return sorted;
  }

  /// 수동 리셋 메서드들
  void resetCurrentTimeFrame() {
    final controller = _ref.read(sectorTimeFrameController);
    controller.resetCurrentTimeFrame();
    refresh();
  }

  void resetAllTimeFrames() {
    final controller = _ref.read(sectorTimeFrameController);
    controller.resetAllTimeFrames();
    refresh();
  }

  /// 다음 리셋 시간 조회
  DateTime? getNextResetTime() {
    final controller = _ref.read(sectorTimeFrameController);
    return controller.getNextResetTime();
  }

  /// 유틸리티 Getters
  List<String> get availableTimeFrames {
    final controller = _ref.read(sectorTimeFrameController);
    return controller.availableTimeFrames;
  }

  String getTimeFrameName(String timeFrame) {
    final controller = _ref.read(sectorTimeFrameController);
    return controller.getTimeFrameName(timeFrame);
  }

  String get currentSectorClassificationName {
    final controller = _ref.read(sectorTimeFrameController);
    return controller.currentSectorClassificationName;
  }

  int get totalSectors {
    final controller = _ref.read(sectorTimeFrameController);
    return controller.totalSectors;
  }

  /// 특정 섹터의 코인들 조회
  List<String> getCoinsInSector(String sectorName) {
    final controller = _ref.read(sectorTimeFrameController);
    return controller.getCoinsInSector(sectorName);
  }

  /// 특정 코인이 속한 섹터들 조회
  List<String> getSectorsForCoin(String ticker) {
    final controller = _ref.read(sectorTimeFrameController);
    return controller.getSectorsForCoin(ticker);
  }

  @override
  void dispose() {
    _subscription?.close();
    super.dispose();
  }
}

/// Provider 선언
final sectorControllerProvider =
    StateNotifierProvider<SectorController, SectorState>((ref) {
  return SectorController(ref);
});