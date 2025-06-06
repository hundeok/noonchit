// lib/presentation/controllers/volume_controller.dart

import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../core/config/app_config.dart';
import '../../core/di/volume_provider.dart'; // 🆕 volume_provider 사용
import '../../domain/entities/volume.dart';

/// 🎯 심플한 볼륨 컨트롤러 - VolumeTimeFrameController 활용
class VolumeController extends StateNotifier<VolumeControllerState> {
  final Ref ref;
  
  VolumeController(this.ref) : super(const VolumeControllerState());

  /// 🆕 Top 50/100 토글
  void toggleTopLimit() {
    state = state.copyWith(isTop100: !state.isTop100);
  }

  /// 🆕 현재 표시 개수 (50 또는 100)
  int get currentLimit => state.isTop100 ? 100 : 50;

  /// 🆕 현재 표시 모드 이름
  String get currentLimitName => state.isTop100 ? 'Top 100' : 'Top 50';

  /// 🆕 Top 100 모드 여부
  bool get isTop100 => state.isTop100;
  void setTimeFrame(String timeFrame, int index) {
    // volume_provider.dart의 VolumeTimeFrameController 사용
    final controller = ref.read(volumeTimeFrameController);
    controller.updateTimeFrame(timeFrame, index);
  }

  /// 현재 시간대
  String get currentTimeFrame => ref.read(volumeTimeFrameController).currentTimeFrame;

  /// 현재 인덱스
  int get currentIndex => ref.read(volumeTimeFrameController).currentIndex;

  /// 사용 가능한 시간대들
  List<String> get availableTimeFrames => ref.read(volumeTimeFrameController).availableTimeFrames;

  /// 시간대 한국어 이름
  String getTimeFrameName(String timeFrame) {
    return ref.read(volumeTimeFrameController).getTimeFrameName(timeFrame);
  }

  /// 볼륨 데이터를 거래량 순으로 정렬 + 🎯 동적 순위 제한 (Top 50/100)
  List<Volume> sortVolumeData(List<Volume> volumeData) {
    final filteredData = volumeData.where((v) => v.totalVolume > 0).toList();
    filteredData.sort((a, b) => b.totalVolume.compareTo(a.totalVolume)); // 내림차순
    
    // 🚀 현재 설정에 따라 50개 또는 100개로 제한
    return filteredData.take(currentLimit).toList();
  }

  /// 코인명 필터링
  List<Volume> filterByMarket(List<Volume> sortedData, String? marketFilter) {
    if (marketFilter == null || marketFilter.isEmpty) {
      return sortedData;
    }
    
    final upper = marketFilter.toUpperCase();
    return sortedData.where((volume) => volume.market.contains(upper)).toList();
  }

  /// 수동 리셋 메서드들
  void resetCurrentTimeFrame() {
    ref.read(volumeTimeFrameController).resetCurrentTimeFrame();
  }

  void resetAllTimeFrames() {
    ref.read(volumeTimeFrameController).resetAllTimeFrames();
  }

  /// 다음 리셋 시간 조회
  DateTime? getNextResetTime() {
    return ref.read(volumeTimeFrameController).getNextResetTime();
  }
}

/// 🆕 VolumeController 상태 관리
class VolumeControllerState {
  final bool isTop100;

  const VolumeControllerState({
    this.isTop100 = false, // 기본값: Top 50
  });

  VolumeControllerState copyWith({
    bool? isTop100,
  }) {
    return VolumeControllerState(
      isTop100: isTop100 ?? this.isTop100,
    );
  }
}

/// Provider 선언 - StateNotifierProvider로 변경!
final volumeControllerProvider = StateNotifierProvider<VolumeController, VolumeControllerState>((ref) => VolumeController(ref));