import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../core/config/app_config.dart';
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
    
    // ✅ TimeFrame 관련
    final timeFrames = AppConfig.timeFrames.map((tf) => '${tf}m').toList();
    final index = ref.watch(volumeTimeFrameIndexProvider);
    final timeFrameCtrl = ref.read(volumeTimeFrameController);
    
    // ✅ UI 설정
    final sliderPosition = ref.watch(appSettingsProvider).sliderPosition;
    
    // ✅ 공통 슬라이더 위젯
    final sliderWidget = CommonSliderWidget(
      leftText: '시간대: ${AppConfig.timeFrameNames[AppConfig.timeFrames[index]] ?? timeFrames[index]}',
      sliderValue: index.toDouble(),
      sliderMin: 0.0,
      sliderMax: (timeFrames.length - 1).toDouble(),
      sliderDivisions: timeFrames.length - 1,
      sliderLabel: AppConfig.timeFrameNames[AppConfig.timeFrames[index]] ?? timeFrames[index],
      onSliderChanged: (value) {
        final i = value.round();
        controller.setTimeFrame(timeFrames[i], i); 
      },
      centerWidget: CommonToggleButton(
        text: controller.currentLimitName,
        isActive: state.isTop100,
        onTap: () => controller.toggleTopLimit(),
      ),
      rightWidget: CommonCountdownWidget(
        nextResetTime: timeFrameCtrl.getNextResetTime(),
      ),
    );

    return PrimaryScrollController(
      controller: scrollController,
      child: Column(
        children: [
          if (sliderPosition == SliderPosition.top) sliderWidget,
          Expanded(child: _buildVolumeList(state, controller, timeFrames, index, context)),
          if (sliderPosition == SliderPosition.bottom) sliderWidget,
        ],
      ),
    );
  }

  /// ✅ 볼륨 리스트 (Controller state 기반)
  Widget _buildVolumeList(
    VolumeControllerState state,
    VolumeController controller,
    List<String> timeFrames,
    int index,
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
          '거래량 데이터가 없습니다.\n(시간대: ${AppConfig.timeFrameNames[AppConfig.timeFrames[index]] ?? timeFrames[index]})',
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
          // ✅ 안전한 상태 조회 (rank 파라미터 불필요)
          isHot: controller.isHot(volume.market),
          shouldBlink: controller.shouldBlink(volume.market),
        );
      },
    );
  }
}