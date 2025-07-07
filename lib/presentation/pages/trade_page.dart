// lib/presentation/pages/trade_page.dart
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../core/di/app_providers.dart';
import '../../shared/widgets/slider_widget.dart';
import '../controllers/trade_controller.dart';
import '../widgets/trade_tile.dart';

class TradePage extends ConsumerWidget {
  final ScrollController scrollController;

  const TradePage({
    Key? key,
    required this.scrollController,
  }) : super(key: key);

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    // ✅ Controller state watch
    final state = ref.watch(tradeControllerProvider);
    final controller = ref.read(tradeControllerProvider.notifier);
    
    // ✅ 신버전 타입 안전 필터 정보
    final currentFilter = state.currentFilter;
    final currentMode = state.currentMode;
    final availableFilters = controller.availableFilters;
    final currentIndex = state.selectedIndex;
    
    // ✅ UI 설정 (appSettingsProvider가 있다면)
    final sliderPosition = ref.watch(appSettingsProvider).sliderPosition;
    final displayMode = ref.watch(appSettingsProvider).displayMode;
    
    // ✅ 공통 슬라이더 위젯
    final sliderWidget = CommonSliderWidget(
      leftText: controller.getThresholdDisplayText(),
      sliderValue: currentIndex.toDouble(),
      sliderMin: 0.0,
      sliderMax: (availableFilters.length - 1).toDouble(),
      sliderDivisions: availableFilters.length - 1,
      sliderLabel: currentFilter.displayName,
      onSliderChanged: (value) {
        final index = value.round();
        final filter = availableFilters[index];
        controller.setThreshold(filter);
      },
      rightWidget: CommonToggleButton(
        text: controller.toggleButtonText,
        isActive: currentMode.isAccumulated,
        onTap: () => controller.toggleMode(),
      ),
    );

    return PrimaryScrollController(
      controller: scrollController,
      child: Column(
        children: [
          if (sliderPosition == SliderPosition.top) sliderWidget,
          Expanded(
            child: _buildTradeList(
              state,
              controller,
              context,
              displayMode,
            ),
          ),
          if (sliderPosition == SliderPosition.bottom) sliderWidget,
        ],
      ),
    );
  }

  /// ✅ 거래 리스트 빌더
  Widget _buildTradeList(
    TradeControllerState state,
    TradeController controller,
    BuildContext context,
    DisplayMode displayMode,
  ) {
    // ✅ 로딩 상태
    if (state.isLoading) {
      return const Center(child: CircularProgressIndicator());
    }

    // ✅ 에러 상태
    if (state.errorMessage != null) {
      return Center(
        child: Text('체결 로드 중 오류: ${state.errorMessage}'),
      );
    }

    // ✅ 빈 데이터 (현재 필터 정보 표시)
    if (state.trades.isEmpty) {
      return Center(
        child: Text(
          '포착된 체결이 없습니다.\n(임계값: ${state.currentFilter.displayName})',
          textAlign: TextAlign.center,
          style: TextStyle(
            color: Theme.of(context).hintColor,
            fontSize: 16,
          ),
        ),
      );
    }

    // ✅ 거래 리스트 표시
    return CommonScrollableList(
      scrollController: scrollController,
      itemCount: state.trades.length,
      itemBuilder: (context, index) {
        final trade = state.trades[index];
        return TradeTile(
          trade: trade,
          displayMode: displayMode,
        );
      },
    );
  }
}