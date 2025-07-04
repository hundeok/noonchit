// lib/domain/usecases/volume_usecase.dart

import '../../core/config/app_config.dart';
import '../entities/volume.dart';
import '../repositories/trade_repository.dart';

/// 🔥 VolumeUsecase - 순수 계산 함수들만 담당 (리팩토링됨)
/// - 비즈니스 규칙 검증
/// - 볼륨 데이터 변환 및 계산
/// - 상태 관리는 모두 Provider로 이전됨
class VolumeUsecase {
  final TradeRepository _volumeRepo;

  // 성능 최적화 상수
  static const int maxVolumes = 200;
  static const int maxCacheSize = 1000;

  VolumeUsecase(this._volumeRepo);

  /// 🎯 볼륨 리스트 계산 (순수 함수)
  /// Provider에서 호출: usecase.calculateVolumeList(volumeMap, timeFrame, startTime)
  List<Volume> calculateVolumeList(
    Map<String, double> volumeMap,
    String timeFrame,
    DateTime startTime,
  ) {
    if (!isValidTimeFrame(timeFrame)) {
      return <Volume>[];
    }

    final now = DateTime.now();
    
    // Volume 객체 생성
    final volumeList = volumeMap.entries
        .where((entry) => entry.value > 0) // 볼륨이 0보다 큰 것만
        .map((entry) => Volume(
              market: entry.key,
              totalVolume: entry.value,
              lastUpdatedMs: now.millisecondsSinceEpoch,
              timeFrame: timeFrame,
              timeFrameStartMs: startTime.millisecondsSinceEpoch,
            ))
        .toList();

    // 볼륨 순으로 정렬 (높은 순)
    volumeList.sort((a, b) => b.totalVolume.compareTo(a.totalVolume));
    
    // 최대 개수 제한
    return volumeList.take(maxVolumes).toList();
  }

  /// 🎯 시간대 유효성 검증 (비즈니스 규칙)
  bool isValidTimeFrame(String timeFrame) {
    final activeFrames = AppConfig.timeFrames.map((tf) => '${tf}m').toList();
    return activeFrames.contains(timeFrame);
  }

  /// 🎯 시간대에서 분 단위 추출 (순수 함수)
  int? parseTimeFrameMinutes(String timeFrame) {
    return int.tryParse(timeFrame.replaceAll('m', ''));
  }

  /// 🎯 다음 리셋 시간 계산 (비즈니스 규칙)
  DateTime? calculateNextResetTime(String timeFrame, DateTime startTime) {
    final minutes = parseTimeFrameMinutes(timeFrame);
    if (minutes == null) return null;
    
    return startTime.add(Duration(minutes: minutes));
  }

  /// 🎯 볼륨 데이터 필터링 (순수 함수)
  List<Volume> filterVolumesByMinimum(List<Volume> volumes, double minimumVolume) {
    return volumes.where((v) => v.totalVolume >= minimumVolume).toList();
  }

  /// 🎯 볼륨 목록을 볼륨 순으로 정렬 (순수 함수)
  List<Volume> sortVolumesByAmount(List<Volume> volumes, {bool descending = true}) {
    final sorted = List<Volume>.from(volumes);
    if (descending) {
      sorted.sort((a, b) => b.totalVolume.compareTo(a.totalVolume));
    } else {
      sorted.sort((a, b) => a.totalVolume.compareTo(b.totalVolume));
    }
    return sorted;
  }

  /// 🎯 볼륨 목록 크기 제한 (순수 함수)
  List<Volume> limitVolumeCount(List<Volume> volumes, [int? maxCount]) {
    final limit = maxCount ?? maxVolumes;
    return volumes.length > limit ? volumes.take(limit).toList() : volumes;
  }

  /// 🎯 유효한 볼륨인지 확인 (비즈니스 규칙)
  bool isValidVolume(Volume volume) {
    return volume.market.isNotEmpty &&
           volume.totalVolume > 0 &&
           volume.lastUpdatedMs > 0 &&
           volume.timeFrame.isNotEmpty;
  }

  /// 🎯 시간대별 볼륨 맵에서 총 볼륨 계산 (순수 함수)
  double calculateTotalVolume(Map<String, double> volumeMap) {
    return volumeMap.values.fold(0.0, (sum, volume) => sum + volume);
  }

  /// 🎯 시간대별 볼륨 맵에서 마켓 수 계산 (순수 함수)
  int getActiveMarketCount(Map<String, double> volumeMap) {
    return volumeMap.entries.where((entry) => entry.value > 0).length;
  }

  /// 🎯 볼륨이 임계값을 초과했는지 확인 (비즈니스 규칙)
  bool isVolumeAboveThreshold(double volume, double threshold) {
    return volume > threshold;
  }

  /// 🎯 시간대가 활성화되어 있는지 확인 (비즈니스 규칙)
  bool isTimeFrameActive(String timeFrame) {
    final activeFrames = getActiveTimeFrames();
    return activeFrames.contains(timeFrame);
  }

  /// 🎯 활성 시간대 목록 조회 (설정 기반)
  List<String> getActiveTimeFrames() {
    return AppConfig.timeFrames.map((tf) => '${tf}m').toList();
  }

  /// 🎯 시간대 표시 이름 조회 (유틸리티)
  String getTimeFrameDisplayName(String timeFrame) {
    final minutes = parseTimeFrameMinutes(timeFrame);
    return AppConfig.timeFrameNames[minutes] ?? timeFrame;
  }

  /// 🎯 볼륨 포맷팅 (유틸리티)
  String formatVolume(double volume) {
    if (volume >= 1000000000) {
      return '${(volume / 1000000000).toStringAsFixed(1)}B';
    } else if (volume >= 1000000) {
      return '${(volume / 1000000).toStringAsFixed(1)}M';
    } else if (volume >= 1000) {
      return '${(volume / 1000).toStringAsFixed(1)}K';
    }
    return volume.toStringAsFixed(0);
  }

  /// 🎯 리셋까지 남은 시간 계산 (유틸리티)
  Duration? getTimeUntilReset(String timeFrame, DateTime startTime) {
    final nextReset = calculateNextResetTime(timeFrame, startTime);
    if (nextReset == null) return null;
    
    final now = DateTime.now();
    final remaining = nextReset.difference(now);
    
    return remaining.isNegative ? Duration.zero : remaining;
  }

  /// 🎯 마켓이 KRW 마켓인지 확인 (비즈니스 규칙)
  bool isKrwMarket(String market) {
    return market.startsWith('KRW-');
  }

  /// 🎯 볼륨 순위 계산 (순수 함수)
  Map<String, int> calculateVolumeRanks(List<Volume> volumes) {
    final ranks = <String, int>{};
    for (int i = 0; i < volumes.length; i++) {
      ranks[volumes[i].market] = i + 1;
    }
    return ranks;
  }

  /// 🎯 시간대별 진행률 계산 (유틸리티)
  double calculateTimeFrameProgress(String timeFrame, DateTime startTime) {
    final minutes = parseTimeFrameMinutes(timeFrame);
    if (minutes == null) return 0.0;
    
    final now = DateTime.now();
    final elapsed = now.difference(startTime);
    final totalDuration = Duration(minutes: minutes);
    
    final progress = elapsed.inMilliseconds / totalDuration.inMilliseconds;
    return progress.clamp(0.0, 1.0);
  }
}