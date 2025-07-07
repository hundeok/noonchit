import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../core/di/app_providers.dart';
import '../../shared/widgets/slider_widget.dart';
import '../controllers/volume_controller.dart';
import '../widgets/volume_tile.dart';

class VolumePage extends ConsumerWidget {
  final ScrollController scrollController;

  const VolumePage({
    Key? key,
    required this.scrollController,
  }) : super(key: key);

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    // ✅ Controller state watch (데이터 + UI 상태)
    final state = ref.watch(volumeControllerProvider);
    final controller = ref.read(volumeControllerProvider.notifier);
    
    // 🔥 TimeFrame 관련 - 공통 Provider 사용
    final currentTimeFrame = ref.watch(volumeSelectedTimeFrameProvider);
    final availableTimeFrames = TimeFrame.fromAppConfig();
    final currentIndex = availableTimeFrames.indexOf(currentTimeFrame);
    final globalController = ref.read(globalTimeFrameControllerProvider);
    
    // ✅ UI 설정
    final sliderPosition = ref.watch(appSettingsProvider).sliderPosition;
    
    // ✅ 공통 슬라이더 위젯 - 공통 TimeFrame 시스템 연동
    final sliderWidget = CommonSliderWidget(
      leftText: '시간대: ${currentTimeFrame.displayName}',
      sliderValue: currentIndex.toDouble(),
      sliderMin: 0.0,
      sliderMax: (availableTimeFrames.length - 1).toDouble(),
      sliderDivisions: availableTimeFrames.length - 1,
      sliderLabel: currentTimeFrame.displayName,
      onSliderChanged: (value) {
        final newIndex = value.round();
        if (newIndex >= 0 && newIndex < availableTimeFrames.length) {
          // 🔥 공통 GlobalTimeFrameController 사용
          globalController.setVolumeTimeFrame(availableTimeFrames[newIndex]);
        }
      },
      // 🔥 Volume 고유: 심플한 중앙 위젯 (Top 50/100 토글만)
      centerWidget: CommonToggleButton(
        text: controller.currentLimitName,
        isActive: state.isTop100,
        onTap: () => controller.toggleTopLimit(),
        fontSize: 10,
        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 6),
      ),
      rightWidget: CommonCountdownWidget(
        // 🔥 공통 GlobalTimeFrameController로 완벽한 타이머 동기화
        nextResetTime: globalController.getNextResetTime(currentTimeFrame),
      ),
    );

    return PrimaryScrollController(
      controller: scrollController,
      child: Column(
        children: [
          if (sliderPosition == SliderPosition.top) sliderWidget,
          Expanded(child: _buildVolumeList(state, controller, currentTimeFrame, context)),
          if (sliderPosition == SliderPosition.bottom) sliderWidget,
        ],
      ),
    );
  }

  /// ✅ 볼륨 리스트 (Controller state 기반) - 공통 TimeFrame enum 사용
  Widget _buildVolumeList(
    VolumeControllerState state,
    VolumeController controller,
    TimeFrame currentTimeFrame, // 🔥 TimeFrame enum 사용
    BuildContext context,
  ) {
    // ✅ 로딩 상태
    if (state.isLoading) {
      return const Center(child: CircularProgressIndicator());
    }

    // ✅ 에러 상태
    if (state.errorMessage != null) {
      return Center(child: Text('볼륨 로드 중 오류: ${state.errorMessage}'));
    }

    // ✅ 빈 데이터
    if (state.volumes.isEmpty) {
      return Center(
        child: Text(
          '거래량 데이터가 없습니다.\n(시간대: ${currentTimeFrame.displayName})', // 🔥 enum 직접 사용
          textAlign: TextAlign.center,
          style: TextStyle(color: Theme.of(context).hintColor, fontSize: 16),
        ),
      );
    }

    // ✅ 볼륨 리스트 (이미 정렬된 데이터 사용)
    return CommonScrollableList(
      scrollController: scrollController,
      itemCount: state.volumes.length,
      itemBuilder: (_, i) {
        final volume = state.volumes[i];
        final rank = i + 1;
        
        return VolumeTile(
          market: volume.market,
          totalVolume: volume.totalVolume,
          rank: rank,
          // ✅ 안전한 상태 조회 (Controller 메서드 사용)
          isHot: controller.isHot(volume.market),
          shouldBlink: controller.shouldBlink(volume.market),
        );
      },
    );
  }
}