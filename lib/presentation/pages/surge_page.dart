import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../core/di/app_providers.dart';
import '../../shared/widgets/slider_widget.dart';
import '../controllers/surge_controller.dart';
import '../widgets/surge_tile.dart';

class SurgePage extends ConsumerWidget {
  final ScrollController scrollController;

  const SurgePage({
    Key? key,
    required this.scrollController,
  }) : super(key: key);

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    // ✅ Controller state watch (데이터 + UI 상태)
    final state = ref.watch(surgeControllerProvider);
    final controller = ref.read(surgeControllerProvider.notifier);
    
    // 🔥 TimeFrame 관련 - 공통 Provider 사용
    final currentTimeFrame = ref.watch(surgeSelectedTimeFrameProvider);
    final availableTimeFrames = TimeFrame.fromAppConfig();
    final currentIndex = availableTimeFrames.indexOf(currentTimeFrame);
    final globalController = ref.read(globalTimeFrameControllerProvider);
    
    // ✅ UI 설정
    final sliderPosition = ref.watch(appSettingsProvider).sliderPosition;
    
    // ✅ 공통 슬라이더 위젯 - Surge 고유의 복잡한 5분할 구조
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
          globalController.setSurgeTimeFrame(availableTimeFrames[newIndex]);
        }
      },
      // 🔥 Surge 고유: 복잡한 5분할 레이아웃 (12-6-10-10-11)
      extraWidgets: [
        // 필터 토글 버튼 (6/49)
        Expanded(
          flex: 6,
          child: Center(
            child: CommonToggleButton(
              text: controller.currentFilterName,
              isActive: state.filterType != SurgeFilterType.all,
              onTap: () {
                // 필터 순환: 전체 → 급등만 → 급락만 → 전체
                SurgeFilterType nextFilter;
                switch (state.filterType) {
                  case SurgeFilterType.all:
                    nextFilter = SurgeFilterType.risingOnly;
                    break;
                  case SurgeFilterType.risingOnly:
                    nextFilter = SurgeFilterType.fallingOnly;
                    break;
                  case SurgeFilterType.fallingOnly:
                    nextFilter = SurgeFilterType.all;
                    break;
                }
                controller.setFilterType(nextFilter);
              },
              activeColor: Colors.blue,
              borderColor: Colors.blue,
              fontSize: 10,
              padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 6),
            ),
          ),
        ),
        // Top 50/100 토글 버튼 (10/49)
        Expanded(
          flex: 10,
          child: Center(
            child: CommonToggleButton(
              text: controller.currentLimitName,
              isActive: state.isTop100,
              onTap: () => controller.toggleTopLimit(),
              fontSize: 10,
              padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 6),
            ),
          ),
        ),
        // 급등/급락 카운터 (10/49)
        Expanded(
          flex: 10,
          child: Center(
            child: _buildSurgeCounter(controller, state),
          ),
        ),
      ],
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
          Expanded(child: _buildSurgeList(state, controller, currentTimeFrame, context)),
          if (sliderPosition == SliderPosition.bottom) sliderWidget,
        ],
      ),
    );
  }

  /// ✅ 급등/급락 카운터 위젯 (기존 유지)
  Widget _buildSurgeCounter(SurgeController controller, SurgeControllerState state) {
    if (state.surges.isEmpty) {
      return Container(
        height: 29,
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(12),
          color: Colors.grey.withValues(alpha: 0.1),
        ),
        child: const Center(
          child: Text(
            '로딩중',
            style: TextStyle(fontSize: 8, color: Colors.grey),
          ),
        ),
      );
    }

    final count = controller.getSurgeCount();
    final risingCount = count['rising'] ?? 0;
    final fallingCount = count['falling'] ?? 0;

    return Container(
      height: 29,
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: Colors.grey.withValues(alpha: 0.3), width: 1),
      ),
      child: Row(
        children: [
          // 좌측: 급등 카운터 (초록 배경)
          Expanded(
            child: Container(
              decoration: const BoxDecoration(
                color: Colors.green,
                borderRadius: BorderRadius.only(
                  topLeft: Radius.circular(11),
                  bottomLeft: Radius.circular(11),
                ),
              ),
              child: Center(
                child: Text(
                  '$risingCount',
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 10,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ),
            ),
          ),
          // 우측: 급락 카운터 (빨간 배경)
          Expanded(
            child: Container(
              decoration: const BoxDecoration(
                color: Colors.red,
                borderRadius: BorderRadius.only(
                  topRight: Radius.circular(11),
                  bottomRight: Radius.circular(11),
                ),
              ),
              child: Center(
                child: Text(
                  '$fallingCount',
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 10,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  /// ✅ 급등/급락 리스트 (Controller state 기반) - 기존 유지
  Widget _buildSurgeList(
    SurgeControllerState state,
    SurgeController controller,
    TimeFrame currentTimeFrame, // 🔥 TimeFrame enum 사용
    BuildContext context,
  ) {
    // ✅ 로딩 상태
    if (state.isLoading) {
      return const Center(child: CircularProgressIndicator());
    }

    // ✅ 에러 상태
    if (state.errorMessage != null) {
      return Center(child: Text('급등/급락 로드 중 오류: ${state.errorMessage}'));
    }

    // ✅ 빈 데이터
    if (state.surges.isEmpty) {
      return Center(
        child: Text(
          '급등/급락 데이터가 없습니다.\n(시간대: ${currentTimeFrame.displayName})', // 🔥 enum 직접 사용
          textAlign: TextAlign.center,
          style: TextStyle(color: Theme.of(context).hintColor, fontSize: 16),
        ),
      );
    }

    // ✅ 급등/급락 리스트 (이미 정렬/필터된 데이터 사용)
    return CommonScrollableList(
      scrollController: scrollController,
      itemCount: state.surges.length,
      itemBuilder: (_, i) {
        final surge = state.surges[i];
        final rank = i + 1;
        
        return SurgeTile(
          market: surge.market,
          changePercent: surge.changePercent,
          basePrice: surge.basePrice,
          currentPrice: surge.currentPrice,
          rank: rank,
          // ✅ 안전한 상태 조회
          isHot: controller.isHot(surge.market),
          shouldBlink: controller.shouldBlink(surge.market),
        );
      },
    );
  }
}