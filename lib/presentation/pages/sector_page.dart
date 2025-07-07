import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
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
    // ✅ Controller state watch (데이터 + UI 상태)
    final state = ref.watch(sectorControllerProvider);
    final controller = ref.read(sectorControllerProvider.notifier);
    
    // ✅ TimeFrame 관련 - 섹터 독립적 TimeFrame 사용
    final currentTimeFrame = ref.watch(selectedSectorTimeFrameProvider);
    final availableTimeFrames = TimeFrame.fromAppConfig();
    final currentIndex = availableTimeFrames.indexOf(currentTimeFrame);
    final timeFrameController = ref.read(sectorTimeFrameController);
    
    // ✅ UI 설정
    final sliderPosition = ref.watch(appSettingsProvider).sliderPosition;
    
    // ✅ 공통 슬라이더 위젯 - 기존 구조 완전 유지
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
          controller.setTimeFrame(availableTimeFrames[newIndex]); // ✅ 직접 호출로 즉시 반응
        }
      },
      // 🚀 Sector 고유: 섹터 분류 토글 버튼
      centerWidget: CommonToggleButton(
        text: controller.currentSectorClassificationName,
        isActive: controller.isDetailedClassification,
        onTap: () => controller.toggleSectorClassification(),
        icon: controller.isDetailedClassification ? Icons.view_module : Icons.view_list,
        fontSize: 10,
        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 6),
      ),
      rightWidget: CommonCountdownWidget(
        nextResetTime: timeFrameController.getNextResetTime(), // 🔥 완벽한 타이머 동기화
      ),
    );

    return PrimaryScrollController(
      controller: scrollController,
      child: Column(
        children: [
          if (sliderPosition == SliderPosition.top) sliderWidget,
          Expanded(child: _buildSectorList(state, controller, currentTimeFrame, context)),
          if (sliderPosition == SliderPosition.bottom) sliderWidget,
        ],
      ),
    );
  }

  /// ✅ 섹터 리스트 (Controller state 기반) - 기존 패턴 유지
  Widget _buildSectorList(
    SectorControllerState state,
    SectorController controller,
    TimeFrame currentTimeFrame, // 🔥 TimeFrame enum 사용
    BuildContext context,
  ) {
    // ✅ 로딩 상태
    if (state.isLoading) {
      return const Center(child: CircularProgressIndicator());
    }

    // ✅ 에러 상태
    if (state.errorMessage != null) {
      return Center(child: Text('섹터 데이터 로드 중 오류: ${state.errorMessage}'));
    }

    // ✅ 빈 데이터
    if (state.sectorVolumes.isEmpty) {
      return Center(
        child: Text(
          '섹터 거래대금 데이터가 없습니다.\n(시간대: ${currentTimeFrame.displayName})', // 🔥 enum 직접 사용
          textAlign: TextAlign.center,
          style: TextStyle(color: Theme.of(context).hintColor, fontSize: 16),
        ),
      );
    }

    // ✅ 섹터 리스트 (이미 정렬된 데이터 사용)
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
          // ✅ 안전한 상태 조회 (기존 패턴 유지)
          isHot: controller.isHot(sectorName),
          shouldBlink: controller.shouldBlink(sectorName),
        );
      },
    );
  }
}