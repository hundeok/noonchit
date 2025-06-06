// lib/core/di/sector_provider.dart

import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../config/app_config.dart';
import '../utils/logger.dart';
import 'volume_provider.dart' show volumeUsecaseProvider;
import 'trade_provider.dart' show marketsProvider;
import '../../domain/entities/volume.dart';
import '../../shared/widgets/sector_classification.dart';

// ═══════════════════════════════════════════════════════════════════════════════
// 🆕 SECTOR 전용 Provider들 (SectorClassificationProvider 연동)
// ═══════════════════════════════════════════════════════════════════════════════

/// 🆕 섹터 분류 Provider (SectorClassificationProvider 연동)
final sectorClassificationProvider = ChangeNotifierProvider<SectorClassificationProvider>(
  (ref) => SectorClassificationProvider(),
);

/// 🆕 섹터 시간대 상태 (볼륨과 독립적으로 관리)
final sectorTimeFrameIndexProvider = StateProvider<int>((ref) => 0);

final sectorTimeFrameProvider = StateProvider<String>((ref) {
  final index = ref.watch(sectorTimeFrameIndexProvider);
  final timeFrames = AppConfig.timeFrames.map((tf) => '${tf}m').toList();
  if (index >= 0 && index < timeFrames.length) {
    return timeFrames[index];
  }
  return '1m';
});

/// 🆕 섹터별 거래대금 데이터 스트림 (SectorClassificationProvider 활용)
final sectorVolumeDataProvider = StreamProvider.autoDispose<List<Volume>>((ref) async* {
  ref.keepAlive();

  try {
    final timeFrame = ref.watch(sectorTimeFrameProvider);
    final usecase = ref.read(volumeUsecaseProvider);
    
    // markets AsyncValue 처리
    final marketsAsync = ref.watch(marketsProvider);
    final markets = marketsAsync.when(
      data: (data) => data,
      loading: () => <String>[],
      error: (_, __) => <String>[],
    );

    if (markets.isEmpty) {
      yield <Volume>[];
      return;
    }

    if (AppConfig.enableTradeLog) {
      log.i('Sector volume stream started: $timeFrame, ${markets.length} markets');
    }

    // 개별 코인 볼륨을 섹터별로 변환
    yield* usecase.getVolumeRanking(timeFrame, markets).map((result) {
      return result.when(
        ok: (coinVolumes) {
          // SectorClassificationProvider에서 현재 섹터 매핑 가져오기
          final sectorProvider = ref.read(sectorClassificationProvider);
          final sectorMapping = sectorProvider.currentSectors;
          
          final sectorVolumes = _aggregateVolumesBySector(coinVolumes, sectorMapping);
          
          if (AppConfig.enableTradeLog) {
            log.d('Sector volumes aggregated: ${sectorVolumes.length} sectors from ${coinVolumes.length} coins');
          }
          
          return sectorVolumes;
        },
        err: (error) {
          log.e('Sector Volume error: ${error.message}');
          return <Volume>[];
        },
      );
    });
    
  } catch (e, stackTrace) {
    log.e('Sector volume stream error: $e', e, stackTrace);
    yield <Volume>[];
  }
});

/// 🎯 핵심 로직: 개별 코인 볼륨을 섹터별로 합산
List<Volume> _aggregateVolumesBySector(List<Volume> coinVolumes, Map<String, List<String>> sectorMapping) {
  if (coinVolumes.isEmpty) return [];
  
  final Map<String, double> sectorVolumeMap = {};
  final sampleVolume = coinVolumes.first;
  
  // 각 코인을 해당 섹터에 합산
  for (final coinVolume in coinVolumes) {
    final ticker = coinVolume.market.replaceFirst('KRW-', '');
    final sectors = _findSectorsForCoin(ticker, sectorMapping);
    
    for (final sector in sectors) {
      sectorVolumeMap[sector] = (sectorVolumeMap[sector] ?? 0.0) + coinVolume.totalVolume;
    }
  }
  
  // 볼륨이 0인 섹터 제거
  sectorVolumeMap.removeWhere((key, value) => value <= 0);
  
  // Volume 객체로 변환
  final sectorVolumes = sectorVolumeMap.entries
      .map((entry) => Volume(
            market: 'SECTOR-${entry.key}', // 섹터 구분용 prefix
            totalVolume: entry.value,
            lastUpdatedMs: sampleVolume.lastUpdatedMs,
            timeFrame: sampleVolume.timeFrame,
            timeFrameStartMs: sampleVolume.timeFrameStartMs,
          ))
      .toList();
  
  // 볼륨 순 정렬 (높은 순)
  sectorVolumes.sort((a, b) => b.totalVolume.compareTo(a.totalVolume));
  return sectorVolumes;
}

/// 🎯 특정 코인이 속한 섹터들 찾기
List<String> _findSectorsForCoin(String ticker, Map<String, List<String>> sectorMapping) {
  final sectors = <String>[];
  sectorMapping.forEach((sectorName, coins) {
    if (coins.contains(ticker)) {
      sectors.add(sectorName);
    }
  });
  return sectors;
}

/// 🆕 섹터 컨트롤러
final sectorTimeFrameController = Provider((ref) => SectorTimeFrameController(ref));

class SectorTimeFrameController {
  final Ref ref;
  SectorTimeFrameController(this.ref);

  /// 시간대 변경
  void updateTimeFrame(String timeFrame, int index) {
    final timeFrames = AppConfig.timeFrames.map((tf) => '${tf}m').toList();
    if (index < 0 || index >= timeFrames.length) {
      if (AppConfig.enableTradeLog) log.w('Invalid sector timeFrame index: $index');
      return;
    }
    
    ref.read(sectorTimeFrameProvider.notifier).state = timeFrame;
    ref.read(sectorTimeFrameIndexProvider.notifier).state = index;
    
    if (AppConfig.enableTradeLog) {
      log.i('Sector TimeFrame updated: $timeFrame (index: $index)');
    }
  }

  /// 🆕 섹터 분류 토글 (SectorClassificationProvider 연동)
  void toggleSectorClassification() {
    ref.read(sectorClassificationProvider.notifier).toggleClassificationType();
    
    if (AppConfig.enableTradeLog) {
      final currentName = ref.read(sectorClassificationProvider).currentClassificationName;
      log.i('Sector classification toggled: $currentName');
    }
  }

  /// 현재 시간대 정보
  String get currentTimeFrame => ref.read(sectorTimeFrameProvider);
  int get currentIndex => ref.read(sectorTimeFrameIndexProvider);
  
  /// 현재 섹터 분류 정보 (SectorClassificationProvider 연동)
  bool get isDetailedClassification => ref.read(sectorClassificationProvider).isDetailedClassification;
  String get currentSectorClassificationName => ref.read(sectorClassificationProvider).currentClassificationName;
  int get totalSectors => ref.read(sectorClassificationProvider).currentSectors.length;
  
  /// 기본 정보
  List<String> get availableTimeFrames => AppConfig.timeFrames.map((tf) => '${tf}m').toList();
  
  String getTimeFrameName(String timeFrame) {
    final minutes = int.tryParse(timeFrame.replaceAll('m', ''));
    return AppConfig.timeFrameNames[minutes] ?? timeFrame;
  }

  /// 🆕 섹터 관련 유틸리티 (SectorClassificationProvider 연동)
  Map<String, int> getSectorSizes() {
    return ref.read(sectorClassificationProvider).sectorSizes;
  }

  List<String> getCoinsInSector(String sectorName) {
    return ref.read(sectorClassificationProvider).getCoinsInSector(sectorName);
  }

  List<String> getSectorsForCoin(String ticker) {
    return ref.read(sectorClassificationProvider).getSectorsForCoin(ticker);
  }

  /// 수동 리셋 메서드들 (볼륨 UseCase 재사용)
  void resetCurrentTimeFrame() {
    final usecase = ref.read(volumeUsecaseProvider);
    final timeFrame = ref.read(sectorTimeFrameProvider);
    
    final result = usecase.resetTimeFrame(timeFrame);
    result.when(
      ok: (_) {
        if (AppConfig.enableTradeLog) {
          log.i('Sector volume reset: $timeFrame');
        }
      },
      err: (error) {
        log.e('Sector volume reset failed: ${error.message}');
      },
    );
  }

  void resetAllTimeFrames() {
    final usecase = ref.read(volumeUsecaseProvider);
    
    final result = usecase.resetAllTimeFrames();
    result.when(
      ok: (_) {
        if (AppConfig.enableTradeLog) {
          log.i('Sector volume reset: all timeframes');
        }
      },
      err: (error) {
        log.e('Sector volume reset all failed: ${error.message}');
      },
    );
  }

  /// 다음 리셋 시간 조회
  DateTime? getNextResetTime() {
    final usecase = ref.read(volumeUsecaseProvider);
    final timeFrame = ref.read(sectorTimeFrameProvider);
    
    final result = usecase.getNextResetTime(timeFrame);
    return result.when(
      ok: (resetTime) => resetTime,
      err: (error) {
        log.e('Get sector reset time failed: ${error.message}');
        return null;
      },
    );
  }
}