// lib/presentation/pages/sector_page.dart

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter/services.dart'; // HapticFeedback용
import '../../core/config/app_config.dart';
import '../../core/di/sector_provider.dart';
import '../../core/di/settings_provider.dart';
import '../../domain/entities/app_settings.dart';
import '../../domain/entities/volume.dart';
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
    // 1) TimeFrame 상태 및 컨트롤러
    final timeFrames = AppConfig.timeFrames.map((tf) => '${tf}m').toList();
    final index = ref.watch(sectorTimeFrameIndexProvider);
    final timeFrameCtrl = ref.read(sectorTimeFrameController);
    
    // 2) 섹터 스트림
    final sectorsAsync = ref.watch(sectorVolumeDataProvider);
    
    // 3) UI 상태 컨트롤러
    final uiController = ref.watch(sectorControllerProvider.notifier);
    
    // 4) 슬라이더 위치 설정 읽기
    final sliderPosition = ref.watch(appSettingsProvider).sliderPosition;
    
    // 슬라이더 위젯 생성
    final sliderWidget = _buildSliderWidget(timeFrames, index, timeFrameCtrl, ref);
    
    // 섹터 리스트 위젯 생성
    final sectorListWidget = _buildSectorList(sectorsAsync, uiController, scrollController, timeFrames, index, context);

    return PrimaryScrollController(
      controller: scrollController,
      child: Column(
        children: [
          // 슬라이더 위치에 따른 조건부 배치
          if (sliderPosition == SliderPosition.top) sliderWidget,
          
          // 섹터 리스트 (항상 중간)
          Expanded(child: sectorListWidget),
          
          // 슬라이더가 하단일 때
          if (sliderPosition == SliderPosition.bottom) sliderWidget,
        ],
      ),
    );
  }

  /// 슬라이더 위젯 생성 (시간대 선택 + 🆕 토글 + 카운트다운)
  Widget _buildSliderWidget(List<String> timeFrames, int index, SectorTimeFrameController timeFrameCtrl, WidgetRef ref) {
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
              
              // 🆕 중앙: 토글 버튼 (1/3 영역, 정중앙 정렬)
              Expanded(
                flex: 1,
                child: Center(
                  child: _buildClassificationToggle(timeFrameCtrl, ref),
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
              HapticFeedback.mediumImpact();
              final i = v.round();
              timeFrameCtrl.updateTimeFrame(timeFrames[i], i);
            },
          ),
        ],
      ),
    );
  }

  /// 🆕 작은 분류 토글 버튼 (상세/기본)
  Widget _buildClassificationToggle(SectorTimeFrameController timeFrameCtrl, WidgetRef ref) {
    final isDetailed = timeFrameCtrl.isDetailedClassification;
    final currentName = timeFrameCtrl.currentSectorClassificationName;
    
    return GestureDetector(
      onTap: () {
        HapticFeedback.lightImpact(); // 🎯 light haptic 추가
        timeFrameCtrl.toggleSectorClassification();
      },
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
        decoration: BoxDecoration(
          color: isDetailed ? Colors.orange : Colors.transparent, // 🎯 기본일 때 투명
          borderRadius: BorderRadius.circular(12),
          border: Border.all(
            color: Colors.orange, // 🎯 둘 다 주황 테두리
            width: 1,
          ),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(
              isDetailed ? Icons.view_module : Icons.view_list,
              size: 14,
              color: isDetailed ? Colors.white : Colors.orange, // 🎯 기본일 때 주황 아이콘
            ),
            const SizedBox(width: 4),
            Text(
              currentName,
              style: TextStyle(
                fontSize: 12,
                fontWeight: FontWeight.w600,
                color: isDetailed ? Colors.white : Colors.orange, // 🎯 기본일 때 주황 텍스트
              ),
            ),
          ],
        ),
      ),
    );
  }

  /// 카운트다운 위젯 생성
  Widget _buildCountdownWidget(SectorTimeFrameController timeFrameCtrl) {
    final nextResetTime = timeFrameCtrl.getNextResetTime();
    
    if (nextResetTime == null) {
      return const Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(Icons.access_time, size: 16, color: Colors.grey),
          SizedBox(width: 4),
          Text(
            '--:--',
            style: TextStyle(
              fontSize: 14,
              color: Colors.grey,
              fontWeight: FontWeight.w500,
            ),
          ),
        ],
      );
    }

    final now = DateTime.now();
    final remaining = nextResetTime.difference(now);
    
    if (remaining.isNegative) {
      return const Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(Icons.access_time, size: 16, color: Colors.orange),
          SizedBox(width: 4),
          Text(
            '00:00',
            style: TextStyle(
              fontSize: 14,
              color: Colors.orange,
              fontWeight: FontWeight.w500,
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

  /// 섹터 리스트 위젯 생성
  Widget _buildSectorList(
    AsyncValue<List<Volume>> sectorsAsync, 
    SectorController uiController, 
    ScrollController scrollController,
    List<String> timeFrames,
    int index,
    BuildContext context,
  ) {
    return sectorsAsync.when(
      data: (sectorVolumes) {
        // List<Volume>을 정렬된 리스트로 변환
        final sortedSectors = uiController.applySorting(sectorVolumes);
        
        if (sortedSectors.isEmpty) {
          return Center(
            child: Text(
              '섹터 거래대금 데이터가 없습니다.\n(시간대: ${AppConfig.timeFrameNames[AppConfig.timeFrames[index]] ?? timeFrames[index]})',
              textAlign: TextAlign.center,
              style: TextStyle(color: Theme.of(context).hintColor, fontSize: 16),
            ),
          );
        }

        return RawScrollbar(
          controller: scrollController,
          thumbVisibility: true,
          trackVisibility: true,
          thickness: 8,
          radius: const Radius.circular(4),
          thumbColor: Colors.orange.withValues(alpha: 0.5),
          trackColor: Colors.transparent,
          interactive: true,
          minThumbLength: 50,
          child: ListView.builder(
            controller: scrollController,
            physics: const BouncingScrollPhysics(
              parent: AlwaysScrollableScrollPhysics(),
            ),
            padding: const EdgeInsets.only(left: 16, right: 24, top: 16, bottom: 16),
            itemCount: sortedSectors.length,
            itemBuilder: (_, i) => SectorTile(
              sectorName: sortedSectors[i].market.replaceFirst('SECTOR-', ''),
              totalVolume: sortedSectors[i].totalVolume,
              rank: i + 1,
              timeFrame: sortedSectors[i].timeFrame,
              lastUpdated: sortedSectors[i].lastUpdated,
            ),
          ),
        );
      },
      loading: () => const Center(child: CircularProgressIndicator()),
      error: (e, _) => Center(child: Text('섹터 데이터 로드 중 오류: $e')),
    );
  }
}