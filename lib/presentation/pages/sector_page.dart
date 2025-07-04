import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../core/config/app_config.dart';
import '../../core/di/app_providers.dart';
import '../../shared/widgets/slider_widget.dart';
import '../controllers/sector_controller.dart';
import '../widgets/sector_tile.dart';

class SectorPage extends ConsumerWidget {
  final ScrollController scrollController;

  const SectorPage({
    Key? key,
    required this.scrollController,
  }) : super(key: key);

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    // ✅ Controller state watch (데이터 + UI 상태) - Volume과 완전 동일
    final state = ref.watch(sectorControllerProvider);
    final controller = ref.read(sectorControllerProvider.notifier);
    
    // ✅ TimeFrame 관련 - Volume과 완전 동일한 패턴
    final timeFrames = AppConfig.timeFrames.map((tf) => '${tf}m').toList();
    final index = ref.watch(sectorTimeFrameIndexProvider);
    final timeFrameCtrl = ref.read(sectorTimeFrameController);
    
    // ✅ UI 설정
    final sliderPosition = ref.watch(appSettingsProvider).sliderPosition;
    
    // ✅ 공통 슬라이더 위젯 - Volume과 완전 동일한 패턴
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
      // 🚀 Controller 메서드 사용 (Volume과 동일한 방식)
      centerWidget: CommonToggleButton(
        text: controller.currentSectorClassificationName,
        isActive: controller.isDetailedClassification,
        onTap: () => controller.toggleSectorClassification(),
        icon: controller.isDetailedClassification ? Icons.view_module : Icons.view_list,
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
          Expanded(child: _buildSectorList(state, controller, timeFrames, index, context)),
          if (sliderPosition == SliderPosition.bottom) sliderWidget,
        ],
      ),
    );
  }

  /// ✅ 섹터 리스트 (Volume과 완전 동일한 패턴)
  Widget _buildSectorList(
    SectorControllerState state,
    SectorController controller,
    List<String> timeFrames,
    int index,
    BuildContext context,
  ) {
    // ✅ 로딩 상태 - Volume과 동일
    if (state.isLoading) {
      return const Center(child: CircularProgressIndicator());
    }

    // ✅ 에러 상태 - Volume과 동일
    if (state.errorMessage != null) {
      return Center(child: Text('섹터 데이터 로드 중 오류: ${state.errorMessage}'));
    }

    // ✅ 빈 데이터 - Volume과 동일
    if (state.sectorVolumes.isEmpty) {
      return Center(
        child: Text(
          '섹터 거래대금 데이터가 없습니다.\n(시간대: ${AppConfig.timeFrameNames[AppConfig.timeFrames[index]] ?? timeFrames[index]})',
          textAlign: TextAlign.center,
          style: TextStyle(color: Theme.of(context).hintColor, fontSize: 16),
        ),
      );
    }

    // ✅ 섹터 리스트 (Volume과 완전 동일한 패턴)
    return CommonScrollableList(
      scrollController: scrollController,
      itemCount: state.sectorVolumes.length,
      itemBuilder: (_, i) {
        final volume = state.sectorVolumes[i];
        final sectorName = volume.market.replaceFirst('SECTOR-', '');
        final rank = i + 1;
        
        return SectorTile(
          sectorName: sectorName,
          totalVolume: volume.totalVolume,
          rank: rank,
          // ✅ 안전한 상태 조회 - Volume과 완전 동일
          isHot: controller.isHot(sectorName),
          shouldBlink: controller.shouldBlink(sectorName),
        );
      },
    );
  }
}