import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter/services.dart'; // HapticFeedback용
import '../../core/config/app_config.dart';
import '../../core/di/trade_provider.dart';
import '../../core/di/settings_provider.dart'; // 🆕 설정 provider 추가
import '../../domain/entities/app_settings.dart'; // 🆕 SliderPosition enum
import '../controllers/trade_controller.dart';
import '../widgets/trade_tile.dart';
// ✂️ CommonAppBar import 제거 (MainPage에서 처리)

class TradePage extends ConsumerWidget {
  final ScrollController scrollController; // ✅ MainPage에서 전달받는 ScrollController
  
  const TradePage({
    Key? key,
    required this.scrollController, // ✅ 필수 파라미터
  }) : super(key: key);

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    // 1) Threshold 상태 및 컨트롤러
    final thresholds = AppConfig.tradeFilters.where((f) => f >= 20000000).toList();
    final index = ref.watch(tradeFilterIndexProvider);
    final thresholdCtrl = ref.read(tradeThresholdController);
    
    // 2) 거래 스트림
    final tradesAsync = ref.watch(tradeListProvider);
    
    // 3) UI 상태 컨트롤러 (필터/정렬)
    final uiController = ref.watch(tradeControllerProvider.notifier);
    
    // 4) 🆕 슬라이더 위치 설정 읽기
    final sliderPosition = ref.watch(appSettingsProvider).sliderPosition;
    
    // ✅ MainPage에서 전달받은 ScrollController 사용 (로컬 생성 제거)

    // 🆕 슬라이더 위젯 생성
    final sliderWidget = _buildSliderWidget(thresholds, index, thresholdCtrl);
    
    // 🆕 거래 리스트 위젯 생성
    final tradeListWidget = _buildTradeList(tradesAsync, uiController, scrollController, thresholds, index, context);

    // ✅ PrimaryScrollController로 상태바 터치 활성화 + 정확한 ScrollController 연결
    return PrimaryScrollController(
      controller: scrollController, // ✅ 이제 MainPage와 같은 인스턴스!
      child: Column(
        children: [
          // 🆕 슬라이더 위치에 따른 조건부 배치 (enum 직접 비교)
          if (sliderPosition == SliderPosition.top) sliderWidget,
          
          // 거래 리스트 (항상 중간)
          Expanded(child: tradeListWidget),
          
          // 🆕 슬라이더가 하단일 때 (enum 직접 비교)
          if (sliderPosition == SliderPosition.bottom) sliderWidget,
        ],
      ),
    );
  }

  /// 🆕 슬라이더 위젯 생성
  Widget _buildSliderWidget(List<double> thresholds, int index, dynamic thresholdCtrl) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            '최소 거래 금액: ${AppConfig.filterNames[thresholds[index]] ?? thresholds[index].toStringAsFixed(0)}',
            style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
          ),
          Slider(
            value: index.toDouble(),
            min: 0,
            max: (thresholds.length - 1).toDouble(),
            divisions: thresholds.length - 1,
            label: AppConfig.filterNames[thresholds[index]] ?? thresholds[index].toStringAsFixed(0),
            onChanged: (v) {
              HapticFeedback.mediumImpact(); // 🎯 여기에 추가!  
              final i = v.round();
              thresholdCtrl.updateThreshold(thresholds[i], i);
            },
          ),
        ],
      ),
    );
  }

  /// 🆕 거래 리스트 위젯 생성 - 스크롤바 드래그 기능 강화
  Widget _buildTradeList(
    AsyncValue tradesAsync, 
    dynamic uiController, 
    ScrollController scrollController,
    List<double> thresholds,
    int index,
    BuildContext context,
  ) {
    return tradesAsync.when(
      data: (list) {
        final viewList = uiController.apply(list);
        if (viewList.isEmpty) {
          return Center(
            child: Text(
              '포착된 체결이 없습니다.\n(임계값: ${AppConfig.filterNames[thresholds[index]] ?? thresholds[index].toStringAsFixed(0)})',
              textAlign: TextAlign.center,
              style: TextStyle(color: Theme.of(context).hintColor, fontSize: 16),
            ),
          );
        }

        // 🎯 더 강력한 드래그 가능한 스크롤바
        return RawScrollbar(
          controller: scrollController,
          thumbVisibility: true,
          trackVisibility: true, // 트랙 표시
          thickness: 8, // ✅ 두께 줄이기 (16 → 8)
          radius: const Radius.circular(4), // ✅ 반지름도 조정
          thumbColor: Colors.orange.withValues(alpha: 0.5), // ✅ 기존 주황 반투명
          trackColor: Colors.transparent, // ✅ 트랙은 투명하게
          interactive: true, // 드래그 가능
          minThumbLength: 50, // 최소 썸 길이
          child: ListView.builder(
            controller: scrollController,
            // 🍎 iOS 스타일 스크롤 물리 효과
            physics: const BouncingScrollPhysics(
              parent: AlwaysScrollableScrollPhysics(),
            ),
            padding: const EdgeInsets.only(left: 16, right: 24, top: 16, bottom: 16), // ✅ 우측 패딩 줄이기
            itemCount: viewList.length,
            itemBuilder: (_, i) => TradeTile(trade: viewList[i]),
          ),
        );
      },
      loading: () => const Center(child: CircularProgressIndicator()),
      error: (e, _) => Center(child: Text('체결 로드 중 오류: $e')),
    );
  }
}