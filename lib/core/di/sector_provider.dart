import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../config/app_config.dart';
import '../utils/logger.dart';
import '../common/time_frame_types.dart';   // 🔥 공통 타입 사용
import 'volume_provider.dart';
import '../../domain/entities/volume.dart';
import '../../shared/widgets/sector_classification.dart';

// ══════════════════════════════════════════════════════════════════════════════
// 📋 섹터 이벤트 클래스 (기존 유지)
// ══════════════════════════════════════════════════════════════════════════════

@immutable
class SectorVolumeEvent {
  final List<Volume> volumes;
  final TimeFrame timeFrame;
  final bool isReset;
  final DateTime? resetTime;
  final DateTime eventTime;

  const SectorVolumeEvent({
    required this.volumes,
    required this.timeFrame,
    this.isReset = false,
    this.resetTime,
    required this.eventTime,
  });

  factory SectorVolumeEvent.data({
    required List<Volume> volumes,
    required TimeFrame timeFrame,
  }) {
    return SectorVolumeEvent(
      volumes: volumes,
      timeFrame: timeFrame,
      eventTime: DateTime.now(),
    );
  }

  factory SectorVolumeEvent.reset({
    required TimeFrame timeFrame,
    DateTime? resetTime,
  }) {
    final now = resetTime ?? DateTime.now();
    return SectorVolumeEvent(
      volumes: const [],
      timeFrame: timeFrame,
      isReset: true,
      resetTime: now,
      eventTime: now,
    );
  }
}

// ══════════════════════════════════════════════════════════════════════════════
// 🔧 기본 Provider들
// ══════════════════════════════════════════════════════════════════════════════

/// 섹터 분류 Provider (기존 유지)
final sectorClassificationProvider = ChangeNotifierProvider<SectorClassificationProvider>(
  (ref) => SectorClassificationProvider(),
);

/// 🔥 섹터 전용 시간대 Provider (Volume과 독립)
final selectedSectorTimeFrameProvider = StateProvider<TimeFrame>((ref) => TimeFrame.min1);

// ══════════════════════════════════════════════════════════════════════════════
// 🎯 메인 섹터 볼륨 Provider - 간소화된 시스템 연동
// ══════════════════════════════════════════════════════════════════════════════

/// 섹터 볼륨 데이터 Provider (간소화된 TimeFrame 시스템 연동)
final sectorVolumeDataProvider = StreamProvider<SectorVolumeEvent>((ref) async* {
  ref.keepAlive();
  
  // 🔥 섹터 전용 시간대 Provider 사용 (Volume과 독립)
  final selectedTimeFrame = ref.watch(selectedSectorTimeFrameProvider);
  final sectorClassification = ref.watch(sectorClassificationProvider);
  
  // 🔥 간소화된 Volume 시간대별 컨트롤러에서 직접 받기
  final controllers = ref.read(volumeTimeFrameControllersProvider);
  final controller = controllers[selectedTimeFrame];
  
  if (controller == null) {
    if (AppConfig.enableTradeLog) {
      log.e('💥 Sector: Volume controller not found for $selectedTimeFrame');
    }
    return;
  }
  
  // Volume 스트림 바인더 활성화
  await ref.read(volumeStreamBinderProvider);
  
  if (AppConfig.enableTradeLog) {
    log.i('🔥 Sector stream started: $selectedTimeFrame');
  }
  
  await for (final volumeEvent in controller.stream) {
    if (volumeEvent.isReset) {
      yield SectorVolumeEvent.reset(
        timeFrame: volumeEvent.timeFrame,
        resetTime: volumeEvent.resetTime,
      );
    } else {
      // 섹터별 집계
      final sectorVolumes = _aggregateVolumesBySector(
        volumeEvent.volumes,
        sectorClassification.currentSectors,
      );
      
      yield SectorVolumeEvent.data(
        volumes: sectorVolumes,
        timeFrame: volumeEvent.timeFrame,
      );
    }
  }
});

/// 현재 섹터 볼륨 리스트 (기존 유지)
final currentSectorVolumeListProvider = Provider<List<Volume>>((ref) {
  final sectorEvent = ref.watch(sectorVolumeDataProvider).valueOrNull;
  return sectorEvent?.volumes ?? [];
});

// ══════════════════════════════════════════════════════════════════════════════
// 🔄 섹터별 집계 로직 (기존 유지)
// ══════════════════════════════════════════════════════════════════════════════

List<Volume> _aggregateVolumesBySector(
  List<Volume> coinVolumes,
  Map<String, List<String>> sectorMapping,
) {
  if (coinVolumes.isEmpty) return [];
  
  final Map<String, double> sectorVolumeMap = {};
  final sampleVolume = coinVolumes.first;
  
  // 각 코인을 해당 섹터에 합산
  for (final coinVolume in coinVolumes) {
    final ticker = coinVolume.market.replaceFirst('KRW-', '');
    
    sectorMapping.forEach((sectorName, coins) {
      if (coins.contains(ticker)) {
        sectorVolumeMap[sectorName] = 
          (sectorVolumeMap[sectorName] ?? 0.0) + coinVolume.totalVolume;
      }
    });
  }
  
  // 볼륨이 0인 섹터 제거하고 Volume 객체로 변환
  final sectorVolumes = sectorVolumeMap.entries
      .where((entry) => entry.value > 0)
      .map((entry) => Volume(
            market: 'SECTOR-${entry.key}',
            totalVolume: entry.value,
            lastUpdatedMs: sampleVolume.lastUpdatedMs,
            timeFrame: sampleVolume.timeFrame,
            timeFrameStartMs: sampleVolume.timeFrameStartMs,
          ))
      .toList();
  
  // 볼륨 순 정렬
  sectorVolumes.sort((a, b) => b.totalVolume.compareTo(a.totalVolume));
  
  return sectorVolumes;
}