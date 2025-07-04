import 'dart:async';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../config/app_config.dart';
import '../utils/logger.dart';
import 'volume_provider.dart' show 
    volumeUsecaseProvider, 
    volumeDataCacheProvider;
import '../../domain/entities/volume.dart';
import '../../domain/usecases/volume_usecase.dart';
import '../../shared/widgets/sector_classification.dart';

// ══════════════════════════════════════════════════════════════════════════════
// 📋 섹터 데이터 클래스
// ══════════════════════════════════════════════════════════════════════════════

/// 섹터 볼륨 이벤트 클래스
class SectorVolumeEvent {
  final List<Volume> volumes;
  final String? resetTimeFrame;

  const SectorVolumeEvent(this.volumes, {this.resetTimeFrame});
}

// ══════════════════════════════════════════════════════════════════════════════
// 🔧 기본 Provider들
// ══════════════════════════════════════════════════════════════════════════════

/// 섹터 분류 Provider
final sectorClassificationProvider = ChangeNotifierProvider<SectorClassificationProvider>(
  (ref) => SectorClassificationProvider(),
);

/// SectorUsecase (Volume UseCase 공유)
final sectorUsecaseProvider = Provider<VolumeUsecase>((ref) {
  return ref.read(volumeUsecaseProvider);
});

/// 섹터 시간대 인덱스 (Volume과 완전 독립)
final sectorTimeFrameIndexProvider = StateProvider<int>((_) => 0);

/// 섹터 현재 시간대 (Volume과 완전 독립)
final sectorTimeFrameProvider = StateProvider<String>((ref) {
  final index = ref.watch(sectorTimeFrameIndexProvider);
  final timeFrames = AppConfig.timeFrames.map((tf) => '${tf}m').toList();
  if (index >= 0 && index < timeFrames.length) {
    return timeFrames[index];
  }
  return '1m';
});

// ══════════════════════════════════════════════════════════════════════════════
// 🎯 섹터 시간대별 스트림 컨트롤러 관리
// ══════════════════════════════════════════════════════════════════════════════

/// 섹터 시간대별 스트림 컨트롤러들
final sectorStreamControllersProvider = Provider<Map<String, StreamController<SectorVolumeEvent>>>((ref) {
  final controllers = <String, StreamController<SectorVolumeEvent>>{};
  
  for (final timeFrameMinutes in AppConfig.timeFrames) {
    final timeFrameStr = '${timeFrameMinutes}m';
    controllers[timeFrameStr] = StreamController<SectorVolumeEvent>.broadcast();
  }

  ref.onDispose(() {
    for (final entry in controllers.entries) {
      if (!entry.value.isClosed) {
        entry.value.close();
      }
    }
    controllers.clear();
  });

  return controllers;
});

/// 섹터 시간대별 업데이트 로직 (절대 시간 기준으로 수정)
final sectorTimeFrameUpdaterProvider = Provider((ref) {
  final controllers = ref.read(sectorStreamControllersProvider);
  final usecase = ref.read(sectorUsecaseProvider);
  
  void updateTimeFrame(String timeFrame) {
    final controller = controllers[timeFrame];
    if (controller == null || controller.isClosed) return;
    
    final dataCache = ref.read(volumeDataCacheProvider);
    final volumeMap = dataCache[timeFrame] ?? <String, double>{};
    
    // ✅ 절대 시간 기준으로 변경 (volumeTimeFrameStartTimesProvider 제거)
    final now = DateTime.now();
    
    // UseCase로 Volume 리스트 생성
    final volumes = usecase.calculateVolumeList(volumeMap, timeFrame, now);
    
    if (volumes.isNotEmpty) {
      // 섹터 분류 가져오기
      final sectorClassification = ref.read(sectorClassificationProvider);
      final sectorMapping = sectorClassification.currentSectors;
      
      // Volume 데이터를 섹터별로 집계
      final sectorVolumes = _aggregateVolumesBySector(volumes, sectorMapping);
      
      controller.add(SectorVolumeEvent(sectorVolumes));
    } else {
      controller.add(const SectorVolumeEvent([]));
    }
  }

  // Volume 캐시 변경 감지
  ref.listen(volumeDataCacheProvider, (previous, next) {
    for (final timeFrame in controllers.keys) {
      updateTimeFrame(timeFrame);
    }
  });

  // 섹터 분류 변경 감지
  ref.listen(sectorClassificationProvider, (previous, next) {
    if (previous != null && previous.currentSectors != next.currentSectors) {
      for (final timeFrame in controllers.keys) {
        updateTimeFrame(timeFrame);
      }
    }
  });

  return updateTimeFrame;
});

// ══════════════════════════════════════════════════════════════════════════════
// 🔵 메인 섹터 볼륨 Provider (절대 시간 기준으로 수정)
// ══════════════════════════════════════════════════════════════════════════════

/// 멀티 스트림: 섹터 timeFrame 변경시 다른 스트림으로 전환
final sectorVolumeDataProvider = StreamProvider<SectorVolumeEvent>((ref) async* {
  ref.keepAlive();
  
  final timeFrame = ref.watch(sectorTimeFrameProvider);
  final controllers = ref.read(sectorStreamControllersProvider);
  final controller = controllers[timeFrame];
  
  if (controller == null) {
    log.e('💥 Sector StreamController not found for $timeFrame');
    return;
  }

  // 🚀 즉시 캐시 데이터 방출 (끊김 방지) - 절대 시간 기준으로 수정
  final dataCache = ref.read(volumeDataCacheProvider);
  final cachedVolumeMap = dataCache[timeFrame] ?? {};
  
  if (cachedVolumeMap.isNotEmpty) {
    final usecase = ref.read(sectorUsecaseProvider);
    // ✅ 절대 시간 기준으로 변경
    final now = DateTime.now();
    
    final volumes = usecase.calculateVolumeList(cachedVolumeMap, timeFrame, now);
    
    if (volumes.isNotEmpty) {
      final sectorClassification = ref.read(sectorClassificationProvider);
      final sectorMapping = sectorClassification.currentSectors;
      final sectorVolumes = _aggregateVolumesBySector(volumes, sectorMapping);
      
      yield SectorVolumeEvent(sectorVolumes);
    }
  }

  // 업데이터 활성화
  ref.read(sectorTimeFrameUpdaterProvider);
  
  // 섹터 스트림 반환
  yield* controller.stream;
});

/// Volume 리스트를 섹터별로 집계
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
    final sectors = <String>[];
    
    sectorMapping.forEach((sectorName, coins) {
      if (coins.contains(ticker)) {
        sectors.add(sectorName);
      }
    });
    
    for (final sector in sectors) {
      sectorVolumeMap[sector] = (sectorVolumeMap[sector] ?? 0.0) + coinVolume.totalVolume;
    }
  }
  
  // 볼륨이 0인 섹터 제거
  sectorVolumeMap.removeWhere((key, value) => value <= 0);
  
  // Volume 객체로 변환
  final sectorVolumes = sectorVolumeMap.entries
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
// 🎛️ Controller Helper (절대 시간 기준으로 개선)
// ══════════════════════════════════════════════════════════════════════════════

final sectorTimeFrameController = Provider((ref) => SectorTimeFrameController(ref));

class SectorTimeFrameController {
  final Ref ref;
  SectorTimeFrameController(this.ref);

  void updateTimeFrame(String timeFrame, int index) {
    final timeFrames = AppConfig.timeFrames.map((tf) => '${tf}m').toList();
    if (index < 0 || index >= timeFrames.length) return;
    
    ref.read(sectorTimeFrameProvider.notifier).state = timeFrame;
    ref.read(sectorTimeFrameIndexProvider.notifier).state = index;
  }

  void toggleSectorClassification() {
    ref.read(sectorClassificationProvider.notifier).toggleClassificationType();
  }

  void resetCurrentTimeFrame() {
    final timeFrame = ref.read(sectorTimeFrameProvider);
    final dataCacheNotifier = ref.read(volumeDataCacheProvider.notifier);
    
    dataCacheNotifier.resetTimeFrame(timeFrame);
  }

  void resetAllTimeFrames() {
    final dataCacheNotifier = ref.read(volumeDataCacheProvider.notifier);
    
    dataCacheNotifier.resetAll();
  }

  /// ✅ 개선된 다음 리셋 시간 계산 (절대 시간 기준, Volume과 동일한 로직)
  DateTime? getNextResetTime() {
    final timeFrame = ref.read(sectorTimeFrameProvider);
    final now = DateTime.now();
    final minutes = int.tryParse(timeFrame.replaceAll('m', '')) ?? 1;

    // Volume Provider와 동일한 절대 시간 기준 계산
    final currentChunkStartMinute = (now.minute ~/ minutes) * minutes;
    final startOfCurrentChunk = DateTime(
      now.year,
      now.month,
      now.day,
      now.hour,
      currentChunkStartMinute,
      0,
      0,
    );

    final nextResetTime = startOfCurrentChunk.add(Duration(minutes: minutes));
    
    // 이미 지난 시간이면 다음 사이클
    if (nextResetTime.isBefore(now)) {
      return nextResetTime.add(Duration(minutes: minutes));
    }
    
    return nextResetTime;
  }

  String get currentTimeFrame => ref.read(sectorTimeFrameProvider);
  int get currentIndex => ref.read(sectorTimeFrameIndexProvider);
  List<String> get availableTimeFrames => AppConfig.timeFrames.map((tf) => '${tf}m').toList();
  
  String getTimeFrameName(String timeFrame) {
    final minutes = int.tryParse(timeFrame.replaceAll('m', ''));
    return AppConfig.timeFrameNames[minutes] ?? timeFrame;
  }

  // 섹터 고유 정보
  bool get isDetailedClassification => ref.read(sectorClassificationProvider).isDetailedClassification;
  String get currentSectorClassificationName => ref.read(sectorClassificationProvider).currentClassificationName;
  int get totalSectors => ref.read(sectorClassificationProvider).currentSectors.length;

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