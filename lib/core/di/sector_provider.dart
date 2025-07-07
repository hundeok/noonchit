import 'dart:async';
import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../config/app_config.dart';
import '../utils/logger.dart';
import '../common/time_frame_manager.dart'; // 🔥 공통 TimeFrame 시스템 추가
import '../common/time_frame_types.dart';   // 🔥 공통 타입 추가
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
// 🎯 메인 섹터 볼륨 Provider - 공통 시스템 연동
// ══════════════════════════════════════════════════════════════════════════════

/// 섹터 볼륨 데이터 Provider (공통 TimeFrame 시스템 연동)
final sectorVolumeDataProvider = StreamProvider<SectorVolumeEvent>((ref) async* {
  ref.keepAlive();
  
  // 🔥 섹터 전용 시간대 Provider 사용 (Volume과 독립)
  final selectedTimeFrame = ref.watch(selectedSectorTimeFrameProvider);
  final sectorClassification = ref.watch(sectorClassificationProvider);
  
  // 🔥 공통 Volume 시간대별 컨트롤러에서 직접 받기
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

// ══════════════════════════════════════════════════════════════════════════════
// 🎛️ 컨트롤러 - 공통 GlobalTimeFrameController 연동
// ══════════════════════════════════════════════════════════════════════════════

final sectorTimeFrameController = Provider((ref) => SectorTimeFrameController(ref));

class SectorTimeFrameController {
  final Ref ref;
  SectorTimeFrameController(this.ref);

  /// 🔥 시간대 변경 - 섹터 독립적 TimeFrame 사용
  void setTimeFrame(TimeFrame timeFrame) {
    ref.read(selectedSectorTimeFrameProvider.notifier).state = timeFrame;
    
    if (AppConfig.enableTradeLog) {
      log.i('🔄 Sector TimeFrame changed (independent): ${timeFrame.displayName}');
    }
  }

  /// 인덱스로 시간대 변경
  void setTimeFrameByIndex(int index) {
    final availableTimeFrames = TimeFrame.fromAppConfig();
    if (index >= 0 && index < availableTimeFrames.length) {
      setTimeFrame(availableTimeFrames[index]);
    }
  }

  /// 섹터 분류 토글
  void toggleSectorClassification() {
    ref.read(sectorClassificationProvider.notifier).toggleClassificationType();
  }

  /// 🔥 현재 시간대 리셋 - 공통 GlobalTimeFrameController 사용
  void resetCurrentTimeFrame() {
    final currentTimeFrame = this.currentTimeFrame;
    ref.read(globalTimeFrameControllerProvider).resetTimeFrame(currentTimeFrame);
  }

  /// 🔥 모든 시간대 리셋 - 공통 GlobalTimeFrameController 사용
  void resetAllTimeFrames() {
    ref.read(globalTimeFrameControllerProvider).resetAllTimeFrames();
  }

  /// 🔥 다음 리셋 시간 - 공통 GlobalTimeFrameController 사용
  DateTime? getNextResetTime() {
    final currentTimeFrame = this.currentTimeFrame;
    return ref.read(globalTimeFrameControllerProvider).getNextResetTime(currentTimeFrame);
  }

  // ══════════════════════════════════════════════════════════════════════════════
  // Getters - 공통 Provider 사용
  // ══════════════════════════════════════════════════════════════════════════════

  /// 🔥 섹터 전용 시간대 Provider 사용 (Volume과 독립)
  TimeFrame get currentTimeFrame => ref.read(selectedSectorTimeFrameProvider);
  
  int get currentIndex {
    final availableTimeFrames = TimeFrame.fromAppConfig();
    return availableTimeFrames.indexOf(currentTimeFrame);
  }
  
  List<TimeFrame> get availableTimeFrames {
    final globalController = ref.read(globalTimeFrameControllerProvider);
    return globalController.availableTimeFrames;
  }
  
  String get currentTimeFrameName => currentTimeFrame.displayName;
  
  String getTimeFrameName(TimeFrame timeFrame) {
    final globalController = ref.read(globalTimeFrameControllerProvider);
    return globalController.getTimeFrameName(timeFrame);
  }

  // 섹터 관련 정보 (기존 유지)
  bool get isDetailedClassification => 
    ref.read(sectorClassificationProvider).isDetailedClassification;
  
  String get currentSectorClassificationName => 
    ref.read(sectorClassificationProvider).currentClassificationName;
  
  int get totalSectors => 
    ref.read(sectorClassificationProvider).currentSectors.length;

  Map<String, int> getSectorSizes() {
    return ref.read(sectorClassificationProvider).sectorSizes;
  }

  List<String> getCoinsInSector(String sectorName) {
    return ref.read(sectorClassificationProvider).getCoinsInSector(sectorName);
  }

  List<String> getSectorsForCoin(String ticker) {
    return ref.read(sectorClassificationProvider).getSectorsForCoin(ticker);
  }
}