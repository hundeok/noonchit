import 'package:flutter/foundation.dart';
import '../../core/common/time_frame_types.dart'; // 🔥 공통 타입 시스템 사용
import '../entities/surge.dart';

/// 🔥 A+급 SurgeUsecase - 완전한 타입 안전성 + 함수형 설계
/// - 모든 dynamic 제거로 컴파일타임 안전성 보장
/// - 순수 함수 + 불변성 철저히 적용
/// - 공통 TimeFrame enum 사용으로 타입 안전성 보장
/// - 성능 최적화된 알고리즘 적용
class SurgeUsecase {
  // 🔥 Repository는 향후 확장을 위해 보관 (현재는 순수 함수만 사용)

  // 🎯 성능 최적화 상수 (설정으로 외부화)
  static const int maxSurges = 200;
  static const int maxCacheSize = 1000;

  // 🎯 생성자에서 repository 제거 (순수 함수형 유틸리티로 사용)
  const SurgeUsecase();

  /// 🔥 완전한 타입 안전성: PriceData 인터페이스 정의 + TimeFrame enum 사용
  /// dynamic 완전 제거!
  List<Surge> calculateSurgeList(
    Map<String, PriceData> surgeMap, // 🎯 dynamic → PriceData
    TimeFrame timeFrame, // 🔥 String → TimeFrame enum
    DateTime startTime,
  ) {
    if (!isValidTimeFrame(timeFrame)) return <Surge>[];

    final now = DateTime.now();
    
    // 🔥 함수형 체이닝으로 깔끔하게
    return surgeMap.entries
        .where(_hasValidPriceData)
        .map((entry) => _createSurge(entry, timeFrame, now, startTime))
        .where(_isValidSurge)
        .toList()
      ..sort(_compareByChangePercent)
      ..take(maxSurges);
  }

  /// 🎯 순수 함수: 유효한 가격 데이터 체크
  bool _hasValidPriceData(MapEntry<String, PriceData> entry) {
    final data = entry.value;
    return data.basePrice > 0 && data.changePercent != 0;
  }

  /// 🎯 순수 함수: Surge 객체 생성 - TimeFrame enum 사용
  Surge _createSurge(
    MapEntry<String, PriceData> entry,
    TimeFrame timeFrame, // 🔥 TimeFrame enum 사용
    DateTime now,
    DateTime startTime,
  ) {
    final data = entry.value;
    return Surge(
      market: entry.key,
      changePercent: data.changePercent,
      basePrice: data.basePrice,
      currentPrice: data.currentPrice,
      lastUpdatedMs: now.millisecondsSinceEpoch,
      timeFrame: timeFrame.key, // 🔥 enum.key 사용
      timeFrameStartMs: startTime.millisecondsSinceEpoch,
    );
  }

  /// 🎯 순수 함수: 변동률 비교 (내림차순)
  int _compareByChangePercent(Surge a, Surge b) => 
      b.changePercent.compareTo(a.changePercent);

  /// 🔥 비즈니스 규칙 - 공통 TimeFrame enum 사용
  bool isValidTimeFrame(TimeFrame timeFrame) {
    final activeFrames = TimeFrame.fromAppConfig();
    return activeFrames.contains(timeFrame);
  }

  /// 🎯 함수형 체이닝: 필터링 메서드들
  List<Surge> filterByMinimumPercent(List<Surge> surges, double threshold) =>
      surges.where((s) => s.changePercent.abs() >= threshold).toList();

  List<Surge> filterRisingOnly(List<Surge> surges) =>
      surges.where((s) => s.isRising).toList(); // 🔥 entity 메서드 활용

  List<Surge> filterFallingOnly(List<Surge> surges) =>
      surges.where((s) => s.isFalling).toList(); // 🔥 entity 메서드 활용

  /// 🔥 고성능 정렬: 기본값으로 최적화
  List<Surge> sortByChangePercent(List<Surge> surges, {bool descending = true}) {
    return List<Surge>.from(surges)
      ..sort(descending ? _compareByChangePercent : _compareByChangePercentAsc);
  }

  int _compareByChangePercentAsc(Surge a, Surge b) => 
      a.changePercent.compareTo(b.changePercent);

  /// 🎯 함수형: 크기 제한
  List<Surge> limitCount(List<Surge> surges, [int? maxCount]) =>
      surges.take(maxCount ?? maxSurges).toList();

  /// 🔥 entity 검증 메서드 활용으로 중복 제거
  bool _isValidSurge(Surge surge) => surge.hasChange; // entity 메서드 활용

  /// 🎯 고성능 집계: fold 사용
  double calculateTotalChangePercent(Map<String, PriceData> surgeMap) =>
      surgeMap.values.fold(0.0, (sum, data) => sum + data.changePercent);

  int getActiveSurgeCount(Map<String, PriceData> surgeMap) =>
      surgeMap.values.where((data) => data.changePercent != 0).length;

  /// 🔥 비즈니스 규칙 함수화
  bool isSurgeAboveThreshold(double changePercent, double threshold) =>
      changePercent.abs() > threshold;

  bool isKrwMarket(String market) => market.startsWith('KRW-');

  /// 🎯 설정 기반 메서드들 - 공통 TimeFrame enum 사용
  List<TimeFrame> getActiveTimeFrames() => TimeFrame.fromAppConfig();
  
  String getTimeFrameDisplayName(TimeFrame timeFrame) => timeFrame.displayName;

  /// 🔥 시간 계산 메서드들 - TimeFrame enum 사용
  DateTime calculateNextResetTime(TimeFrame timeFrame, DateTime startTime) {
    return startTime.add(timeFrame.duration); // 🔥 enum.duration 사용
  }

  Duration getTimeUntilReset(TimeFrame timeFrame, DateTime startTime) {
    final nextReset = calculateNextResetTime(timeFrame, startTime);
    final remaining = nextReset.difference(DateTime.now());
    return remaining.isNegative ? Duration.zero : remaining;
  }

  /// 🎯 유틸리티 함수들 - 함수형 스타일
  String formatChangePercent(double changePercent) {
    final sign = changePercent >= 0 ? '+' : '';
    return '$sign${changePercent.toStringAsFixed(2)}%';
  }

  String formatPrice(double price) {
    return price >= 1000000 ? '${(price / 1000000).toStringAsFixed(1)}M'
         : price >= 1000 ? '${(price / 1000).toStringAsFixed(1)}K'
         : price.toStringAsFixed(0);
  }

  /// 🔥 고성능 순위 계산: Map.fromIterables 사용
  Map<String, int> calculateSurgeRanks(List<Surge> surges) {
    final markets = surges.map((s) => s.market);
    final ranks = Iterable.generate(surges.length, (i) => i + 1);
    return Map.fromIterables(markets, ranks);
  }

  /// 🎯 진행률 계산 - TimeFrame enum 사용
  double calculateTimeFrameProgress(TimeFrame timeFrame, DateTime startTime) {
    final elapsed = DateTime.now().difference(startTime);
    final progress = elapsed.inMilliseconds / timeFrame.duration.inMilliseconds;
    return progress.clamp(0.0, 1.0);
  }

  /// 🔥 완전한 함수형: 통계 계산 최적화
  SurgeStatistics calculateSurgeStatistics(List<Surge> surges) {
    if (surges.isEmpty) return SurgeStatistics.empty();

    final changes = surges.map((s) => s.changePercent).toList();
    final risingCount = surges.where((s) => s.isRising).length;
    final fallingCount = surges.where((s) => s.isFalling).length;
    
    return SurgeStatistics(
      totalCount: surges.length,
      risingCount: risingCount,
      fallingCount: fallingCount,
      averageChange: changes.reduce((a, b) => a + b) / changes.length,
      maxRise: changes.reduce((a, b) => a > b ? a : b),
      maxFall: changes.reduce((a, b) => a < b ? a : b),
    );
  }

  /// 🔥 enum 기반 분류: 타입 안전성 + 성능 최적화
  Map<SurgeRangeType, List<Surge>> classifySurgesByRange(List<Surge> surges) {
    final classification = <SurgeRangeType, List<Surge>>{};
    
    // 모든 범위 타입 초기화
    for (final type in SurgeRangeType.values) {
      classification[type] = <Surge>[];
    }
    
    // 한 번의 순회로 모든 분류 완료
    for (final surge in surges) {
      final rangeType = SurgeRangeType.fromPercent(surge.changePercent);
      classification[rangeType]!.add(surge);
    }
    
    return classification;
  }

  /// 🔥 호환성 메서드들 - 기존 String 기반 코드와의 호환성
  @Deprecated('Use TimeFrame enum instead of String')
  List<Surge> calculateSurgeListLegacy(
    Map<String, PriceData> surgeMap,
    String timeFrame,
    DateTime startTime,
  ) {
    // String을 TimeFrame으로 변환
    final tf = _parseStringToTimeFrame(timeFrame);
    if (tf == null) return <Surge>[];
    
    return calculateSurgeList(surgeMap, tf, startTime);
  }

  /// 🔥 String → TimeFrame 변환 헬퍼
  TimeFrame? _parseStringToTimeFrame(String timeFrame) {
    try {
      final minutes = int.parse(timeFrame.replaceAll('m', ''));
      return TimeFrame.values.firstWhere(
        (tf) => tf.minutes == minutes,
        orElse: () => TimeFrame.min1,
      );
    } catch (e) {
      return null;
    }
  }
}

/// 🔥 타입 안전성: PriceData 인터페이스 정의
/// dynamic 완전 제거를 위한 추상화
abstract class PriceData {
  double get basePrice;
  double get currentPrice;
  double get changePercent;
}

/// 🔥 변동률 범위 enum: 타입 안전성 + 성능 최적화 (중복 제거 - 공통 타입으로 이관 고려)
enum SurgeRangeType {
  extremeRise(10, double.infinity, 'extreme_rise'),
  strongRise(5, 10, 'strong_rise'),
  moderateRise(2, 5, 'moderate_rise'),
  slightRise(0, 2, 'slight_rise'),
  slightFall(-2, 0, 'slight_fall'),
  moderateFall(-5, -2, 'moderate_fall'),
  strongFall(-10, -5, 'strong_fall'),
  extremeFall(double.negativeInfinity, -10, 'extreme_fall');

  const SurgeRangeType(this.minPercent, this.maxPercent, this.key);
  final double minPercent;
  final double maxPercent;
  final String key;
  
  static SurgeRangeType fromPercent(double percent) {
    return values.firstWhere(
      (type) => percent >= type.minPercent && percent < type.maxPercent,
      orElse: () => percent >= 0 ? slightRise : slightFall,
    );
  }
}

/// 🔥 통계 데이터 불변 클래스: 타입 안전성
@immutable
class SurgeStatistics {
  final int totalCount;
  final int risingCount;
  final int fallingCount;
  final double averageChange;
  final double maxRise;
  final double maxFall;

  const SurgeStatistics({
    required this.totalCount,
    required this.risingCount,
    required this.fallingCount,
    required this.averageChange,
    required this.maxRise,
    required this.maxFall,
  });

  factory SurgeStatistics.empty() => const SurgeStatistics(
    totalCount: 0,
    risingCount: 0,
    fallingCount: 0,
    averageChange: 0.0,
    maxRise: 0.0,
    maxFall: 0.0,
  );
}