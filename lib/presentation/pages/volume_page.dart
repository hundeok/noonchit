// lib/presentation/pages/volume_page.dart

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter/services.dart'; // HapticFeedback용
import '../../core/config/app_config.dart';
import '../../core/di/volume_provider.dart'; // 🆕 volume_provider 사용!
import '../../core/di/settings_provider.dart'; // 🆕 설정 provider 추가
import '../../domain/entities/app_settings.dart'; // 🆕 SliderPosition enum
import '../../domain/entities/volume.dart'; // 🆕 Volume 엔티티
import '../controllers/volume_controller.dart';
import '../widgets/volume_tile.dart';
// ✂️ CommonAppBar import 제거 (MainPage에서 처리)

class VolumePage extends ConsumerWidget {
  final ScrollController scrollController; // ✅ MainPage에서 전달받는 ScrollController
  
  const VolumePage({
    Key? key,
    required this.scrollController, // ✅ 필수 파라미터
  }) : super(key: key);

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    // 1) TimeFrame 상태 및 컨트롤러
    final timeFrames = AppConfig.timeFrames.map((tf) => '${tf}m').toList();
    final index = ref.watch(volumeTimeFrameIndexProvider);
    final timeFrameCtrl = ref.read(volumeTimeFrameController);
    
    // 2) 볼륨 스트림
    final volumesAsync = ref.watch(volumeDataProvider);
    
    // 3) UI 상태 컨트롤러 (필터/정렬) - StateNotifier로 변경됨
    final uiController = ref.watch(volumeControllerProvider.notifier);
    
    // 4) 🆕 슬라이더 위치 설정 읽기
    final sliderPosition = ref.watch(appSettingsProvider).sliderPosition;
    
    // ✅ MainPage에서 전달받은 ScrollController 사용 (로컬 생성 제거)

    // 🆕 슬라이더 위젯 생성 - 토글 추가
    final sliderWidget = _buildSliderWidget(timeFrames, index, timeFrameCtrl, ref);
    
    // 🆕 볼륨 리스트 위젯 생성
    final volumeListWidget = _buildVolumeList(volumesAsync, uiController, scrollController, timeFrames, index, context);

    // ✅ PrimaryScrollController로 상태바 터치 활성화 + 정확한 ScrollController 연결
    return PrimaryScrollController(
      controller: scrollController, // ✅ 이제 MainPage와 같은 인스턴스!
      child: Column(
        children: [
          // 🆕 슬라이더 위치에 따른 조건부 배치 (enum 직접 비교)
          if (sliderPosition == SliderPosition.top) sliderWidget,
          
          // 볼륨 리스트 (항상 중간)
          Expanded(child: volumeListWidget),
          
          // 🆕 슬라이더가 하단일 때 (enum 직접 비교)
          if (sliderPosition == SliderPosition.bottom) sliderWidget,
        ],
      ),
    );
  }

  /// 🆕 슬라이더 위젯 생성 (시간대 선택 + Top 50/100 토글 + 카운트다운)
  Widget _buildSliderWidget(List<String> timeFrames, int index, VolumeTimeFrameController timeFrameCtrl, WidgetRef ref) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // 🎯 시간대, 토글, 카운트다운을 Row로 배치 (3등분)
          Row(
            children: [
              // 좌측: 시간대 (1/3 영역)
              Expanded(
                flex: 1,
                child: Text(
                  '시간대: ${AppConfig.timeFrameNames[AppConfig.timeFrames[index]] ?? timeFrames[index]}',
                  style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
                  overflow: TextOverflow.ellipsis,
                ),
              ),
              
              // 🆕 중앙: Top 50/100 토글 버튼 (1/3 영역, 정중앙 정렬)
              Expanded(
                flex: 1,
                child: Center(
                  child: _buildTopLimitToggle(ref),
                ),
              ),
              
              // 우측: 카운트다운 (1/3 영역, 우측 정렬)
              Expanded(
                flex: 1,
                child: Align(
                  alignment: Alignment.centerRight,
                  child: _buildCountdownWidget(timeFrameCtrl),
                ),
              ),
            ],
          ),
          Slider(
            value: index.toDouble(),
            min: 0,
            max: (timeFrames.length - 1).toDouble(),
            divisions: timeFrames.length - 1,
            label: AppConfig.timeFrameNames[AppConfig.timeFrames[index]] ?? timeFrames[index],
            onChanged: (v) {
              HapticFeedback.mediumImpact(); // 🎯 햅틱 피드백
              final i = v.round();
              timeFrameCtrl.updateTimeFrame(timeFrames[i], i);
            },
          ),
        ],
      ),
    );
  }

  /// 🆕 Top 50/100 토글 버튼
  Widget _buildTopLimitToggle(WidgetRef ref) {
    final uiController = ref.watch(volumeControllerProvider.notifier);
    final isTop100 = ref.watch(volumeControllerProvider).isTop100;
    final currentName = uiController.currentLimitName;
    
    return GestureDetector(
      onTap: () {
        HapticFeedback.lightImpact(); // 🎯 light haptic 추가
        uiController.toggleTopLimit();
      },
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
        decoration: BoxDecoration(
          color: isTop100 ? Colors.orange : Colors.transparent, // 🎯 Top 100일 때 주황
          borderRadius: BorderRadius.circular(12),
          border: Border.all(
            color: Colors.orange, // 🎯 둘 다 주황 테두리
            width: 1,
          ),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(
              currentName,
              style: TextStyle(
                fontSize: 12,
                fontWeight: FontWeight.w600,
                color: isTop100 ? Colors.white : Colors.orange, // 🎯 Top 50일 때 주황 텍스트
              ),
            ),
          ],
        ),
      ),
    );
  }

  /// 🎯 카운트다운 위젯 생성 (흔들림 방지 적용)
  Widget _buildCountdownWidget(VolumeTimeFrameController timeFrameCtrl) {
    final nextResetTime = timeFrameCtrl.getNextResetTime();
    
    if (nextResetTime == null) {
      return Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          const Icon(Icons.access_time, size: 16, color: Colors.grey),
          const SizedBox(width: 4),
          Container(
            width: 48, // 🎯 42 → 48로 더 넓히기
            alignment: Alignment.center,
            child: const Text(
              '--:--',
              style: TextStyle(
                fontSize: 12, // 🎯 13 → 12로 더 줄이기
                color: Colors.grey,
                fontWeight: FontWeight.w500,
              ),
            ),
          ),
        ],
      );
    }

    final now = DateTime.now();
    final remaining = nextResetTime.difference(now);
    
    if (remaining.isNegative) {
      return Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          const Icon(Icons.access_time, size: 16, color: Colors.orange),
          const SizedBox(width: 4),
          Container(
            width: 42, // 🎯 40 → 42로 조금 넓히기
            alignment: Alignment.center,
            child: const Text(
              '00:00',
              style: TextStyle(
                fontSize: 13, // 🎯 14 → 13으로 조금 줄이기
                color: Colors.orange,
                fontWeight: FontWeight.w500,
              ),
            ),
          ),
        ],
      );
    }

    final minutes = remaining.inMinutes;
    final seconds = remaining.inSeconds % 60;
    final minutesStr = minutes.toString().padLeft(2, '0');
    final secondsStr = seconds.toString().padLeft(2, '0');
    
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        const Icon(Icons.access_time, size: 16, color: Colors.orange),
        const SizedBox(width: 4),
        Container(
          width: 52, // 🎯 48 → 52로 4px 더 넓히기 (6자리 대응)
          alignment: Alignment.center,
          child: Text(
            '$minutesStr:$secondsStr',
            style: const TextStyle(
              fontSize: 12, // 🎯 13 → 12로 더 줄이기
              color: Colors.orange,
              fontWeight: FontWeight.w500,
            ),
          ),
        ),
      ],
    );
  }

  /// 🆕 볼륨 리스트 위젯 생성 - 스크롤바 드래그 기능 강화
  Widget _buildVolumeList(
    AsyncValue<List<Volume>> volumesAsync, 
    VolumeController uiController, 
    ScrollController scrollController,
    List<String> timeFrames,
    int index,
    BuildContext context,
  ) {
    return volumesAsync.when(
      data: (volumes) {
        // List<Volume>을 정렬된 리스트로 변환 (동적 순위 제한 적용)
        final sortedVolumes = uiController.sortVolumeData(volumes);
        
        if (sortedVolumes.isEmpty) {
          return Center(
            child: Text(
              '거래량 데이터가 없습니다.\n(시간대: ${AppConfig.timeFrameNames[AppConfig.timeFrames[index]] ?? timeFrames[index]})',
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
            itemCount: sortedVolumes.length,
            itemBuilder: (_, i) => VolumeTile(
              market: sortedVolumes[i].market,
              totalVolume: sortedVolumes[i].totalVolume,
              rank: i + 1, // 🎯 순위 전달 (1위부터 시작)
            ),
          ),
        );
      },
      loading: () => const Center(child: CircularProgressIndicator()),
      error: (e, _) => Center(child: Text('볼륨 로드 중 오류: $e')),
    );
  }
}