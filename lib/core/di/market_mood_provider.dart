import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';
import '../network/api_client_coingecko.dart';
import '../utils/logger.dart';

/// 🔥 시장 분위기 enum
enum MarketMood {
  bull, // 🚀 불장
  weakBull, // 🔥 약불장
  sideways, // ⚖️ 중간장
  bear, // 💧 물장
  deepBear, // 🧊 얼음장
}

/// 📊 마켓 무드 데이터 모델
class MarketMoodData {
  final double totalMarketCapUsd;
  final double totalVolumeUsd;
  final double btcDominance;
  final double marketCapChange24h;
  final DateTime updatedAt;

  const MarketMoodData({
    required this.totalMarketCapUsd,
    required this.totalVolumeUsd,
    required this.btcDominance,
    required this.marketCapChange24h,
    required this.updatedAt,
  });

  factory MarketMoodData.fromCoinGecko(CoinGeckoGlobalData data) {
    return MarketMoodData(
      totalMarketCapUsd: data.totalMarketCapUsd,
      totalVolumeUsd: data.totalVolumeUsd,
      btcDominance: data.btcDominance,
      marketCapChange24h: data.marketCapChangePercentage24hUsd,
      updatedAt: DateTime.now(),
    );
  }
}

/// 📊 단순화된 비교 결과 데이터
class ComparisonResult {
  final double? changePercent;  // null = 아직 결과 없음
  final double progress;        // 0.0-100.0 (게이지용)

  const ComparisonResult({
    this.changePercent,
    required this.progress,
  });

  /// 진행 중 (아직 결과 없음)
  factory ComparisonResult.inProgress(double progress) {
    return ComparisonResult(changePercent: null, progress: progress);
  }

  /// 완료됨 (결과 있음)
  factory ComparisonResult.completed(double changePercent, double progress) {
    return ComparisonResult(changePercent: changePercent, progress: progress);
  }

  /// 에러 상태
  factory ComparisonResult.error() {
    return const ComparisonResult(changePercent: null, progress: 0.0);
  }

  // 기존 호환성 getters
  bool get isReady => changePercent != null;
  double get progressPercent => progress / 100.0;
  String get status => isReady ? '비교 완료' : '데이터 수집중';

  // 기존 호환성 factory methods
  factory ComparisonResult.collecting(double progress) => ComparisonResult.inProgress(progress * 100);
  factory ComparisonResult.ready(double changePercent) => ComparisonResult.completed(changePercent, 100.0);
  factory ComparisonResult.updating(double changePercent, double progress) => ComparisonResult.completed(changePercent, progress * 100);
}

/// 🎮 정밀 게이지 상태 관리
class GaugeState {
  final double progress;          // 0.0 - 100.0 (1% 단위)
  final bool isCompleted;         // 100% 달성 여부
  final DateTime? completedAt;    // 완성 시점
  final bool isInGracePeriod;     // 10분 유지 기간

  const GaugeState({
    required this.progress,
    required this.isCompleted,
    this.completedAt,
    required this.isInGracePeriod,
  });

  factory GaugeState.initial() {
    return const GaugeState(progress: 0.0, isCompleted: false, isInGracePeriod: false);
  }

  GaugeState copyWith({double? progress, bool? isCompleted, DateTime? completedAt, bool? isInGracePeriod}) {
    return GaugeState(
      progress: progress ?? this.progress,
      isCompleted: isCompleted ?? this.isCompleted,
      completedAt: completedAt ?? this.completedAt,
      isInGracePeriod: isInGracePeriod ?? this.isInGracePeriod,
    );
  }

  Color get gaugeColor => (isCompleted || isInGracePeriod) ? Colors.green : Colors.blue;

  bool get shouldShowNewCycle {
    if (completedAt == null) return false;
    return DateTime.now().difference(completedAt!).inMinutes >= 10;
  }
}

/// 📈 Section 1: 타임프레임별 비교 데이터
class TimeframeComparisonData {
  final ComparisonResult thirtyMin;
  final ComparisonResult oneHour;
  final ComparisonResult twoHour;
  final ComparisonResult fourHour;
  final ComparisonResult eightHour;
  final ComparisonResult twelveHour;
  final ComparisonResult oneDay;
  final ComparisonResult threeDay;
  final ComparisonResult oneWeek;

  const TimeframeComparisonData({
    required this.thirtyMin,
    required this.oneHour,
    required this.twoHour,
    required this.fourHour,
    required this.eightHour,
    required this.twelveHour,
    required this.oneDay,
    required this.threeDay,
    required this.oneWeek,
  });

  factory TimeframeComparisonData.loading() {
    const loading = ComparisonResult(changePercent: null, progress: 0.0);
    return const TimeframeComparisonData(
      thirtyMin: loading, oneHour: loading, twoHour: loading, fourHour: loading,
      eightHour: loading, twelveHour: loading, oneDay: loading, threeDay: loading, oneWeek: loading,
    );
  }
}

/// 📅 Section 2: 데일리 현황 데이터
class DailyStatusData {
  final double? hourlyIntensityChange;
  final double? accumulationRate;
  final double? estimatedFinal;
  final double? yesterdayFinal;
  final double? todayCurrent;

  const DailyStatusData({
    this.hourlyIntensityChange,
    this.accumulationRate,
    this.estimatedFinal,
    this.yesterdayFinal,
    this.todayCurrent,
  });

  factory DailyStatusData.empty() => const DailyStatusData();
}

/// 🚀 15분 API 타이머 기반 완전 개선된 슬롯 매니저
class UltimateSlotCacheManager {
  static final _instance = UltimateSlotCacheManager._internal();
  static UltimateSlotCacheManager get instance => _instance;
  UltimateSlotCacheManager._internal();

  // 🕐 인트라데이 슬롯 캐시 {타임프레임: {슬롯번호: 볼륨}}
  final Map<String, Map<int, double>> _intradayCache = {
    '30min': {}, '1hour': {}, '2hour': {}, '4hour': {}, '8hour': {}, '12hour': {},
  };

  // 📅 데일리 시간별 캐시 {날짜: {시간: 볼륨}}
  final Map<String, Map<int, double>> _dailyHourlyCache = {};

  // 📊 완성된 일별 데이터 캐시 {날짜: 완성된최종볼륨}
  final Map<String, double> _dailyCache = {};

  // 🎯 최초 비교 완료 여부 추적
  final Map<String, bool> _hasInitialComparison = {
    '30min': false, '1hour': false, '2hour': false, '4hour': false, '8hour': false, '12hour': false,
  };

  // 📅 장기 최초 비교 완료 여부
  final Map<String, bool> _hasLongTermComparison = {
    '1day': false, '3day': false, '1week': false,
  };

  // 🎮 게이지 상태 관리 (인트라데이만)
  final Map<String, GaugeState> _gaugeStates = {};

  // 📊 최신 비교 결과 저장 (우측 칸 표시용)
  final Map<String, double> _latestResults = {};

  // ⏰ 마지막 00:00 리셋 날짜
  String? _lastResetDate;

  // 🔧 API 클라이언트
  late CoinGeckoApiClient _apiClient;

  /// API 클라이언트 설정
  void setApiClient(CoinGeckoApiClient client) => _apiClient = client;

  /// 🌏 KST 시간 가져오기
  DateTime getKST() => DateTime.now();

  /// 현재 슬롯 번호 계산 (KST 기준)
  int getCurrentSlot(String timeframe, DateTime kstTime) {
    switch (timeframe) {
      case '30min': return (kstTime.hour * 2) + (kstTime.minute >= 30 ? 1 : 0);
      case '1hour': return kstTime.hour;
      case '2hour': return kstTime.hour ~/ 2;
      case '4hour': return kstTime.hour ~/ 4;
      case '8hour': return kstTime.hour ~/ 8;
      case '12hour': return kstTime.hour ~/ 12;
      default: return 0;
    }
  }

  /// 슬롯 시작 시간 계산 (KST 기준)
  DateTime getSlotStartTime(String timeframe, DateTime kstTime) {
    switch (timeframe) {
      case '30min': return kstTime.copyWith(minute: (kstTime.minute >= 30) ? 30 : 0, second: 0);
      case '1hour': return kstTime.copyWith(minute: 0, second: 0);
      case '2hour': 
        final hour = (kstTime.hour ~/ 2) * 2;
        return kstTime.copyWith(hour: hour, minute: 0, second: 0);
      case '4hour':
        final hour = (kstTime.hour ~/ 4) * 4;
        return kstTime.copyWith(hour: hour, minute: 0, second: 0);
      case '8hour':
        final hour = (kstTime.hour ~/ 8) * 8;
        return kstTime.copyWith(hour: hour, minute: 0, second: 0);
      case '12hour':
        final hour = (kstTime.hour ~/ 12) * 12;
        return kstTime.copyWith(hour: hour, minute: 0, second: 0);
      default: return kstTime;
    }
  }

  /// 타임프레임별 지속 시간 (분)
  int getTimeframeMinutes(String timeframe) {
    switch (timeframe) {
      case '30min': return 30;
      case '1hour': return 60;
      case '2hour': return 120;
      case '4hour': return 240;
      case '8hour': return 480;
      case '12hour': return 720;
      default: return 30;
    }
  }

  /// 🎯 슬롯 완성 시점 감지 (정확한 로직)
  bool isSlotJustCompleted(String timeframe, DateTime time) {
    switch (timeframe) {
      case '30min': return time.minute == 0 || time.minute == 30;
      case '1hour': return time.minute == 0;
      case '2hour': return time.minute == 0 && time.hour % 2 == 0;
      case '4hour': return time.minute == 0 && time.hour % 4 == 0;
      case '8hour': return time.minute == 0 && time.hour % 8 == 0;
      case '12hour': return time.minute == 0 && time.hour % 12 == 0;
      default: return false;
    }
  }

  /// 🕐 00:00 KST 리셋 체크
  void checkDailyReset() {
    final now = getKST();
    final today = DateFormat('yyyy-MM-dd').format(now);

    if (_lastResetDate != today) {
      log.i('🔄 00:00 KST 리셋 실행: $today');
      // 인트라데이만 초기화 (장기는 유지)
      _hasInitialComparison.updateAll((key, value) => false);
      _gaugeStates.removeWhere((key, value) => _intradayCache.containsKey(key));
      _lastResetDate = today;
      log.i('🆕 인트라데이 타임프레임만 초기화 완료');
    }
  }

  /// 🎮 정밀 게이지 계산 (1% 단위, 통합)
  double calculateGaugeProgress(String timeframe, DateTime now) {
    if (!_hasInitialComparison[timeframe]!) {
      // 1단계: 2슬롯 필요 기반 (최초 비교까지)
      final timeframeMinutes = getTimeframeMinutes(timeframe);
      final requiredMinutes = timeframeMinutes * 2;
      final slotStart = getSlotStartTime(timeframe, now);
      final elapsed = now.difference(slotStart).inMinutes;
      return (elapsed / requiredMinutes * 100).clamp(0.0, 100.0).floorToDouble();
    } else {
      // 2단계: 1슬롯 기반 (이후 주기적 비교)
      final timeframeMinutes = getTimeframeMinutes(timeframe);
      final slotStart = getSlotStartTime(timeframe, now);
      final elapsed = now.difference(slotStart).inMinutes;
      return (elapsed / timeframeMinutes * 100).clamp(0.0, 100.0).floorToDouble();
    }
  }

  /// 🎨 게이지 상태 업데이트 (10분 유지 + 자연스러운 전환)
  GaugeState updateGaugeState(String timeframe, DateTime now) {
    final current = _gaugeStates[timeframe] ?? GaugeState.initial();
    final progress = calculateGaugeProgress(timeframe, now);
    
    // 100% 달성 시 완성 상태로 전환
    if (progress >= 100.0 && !current.isCompleted) {
      return GaugeState(progress: 100.0, isCompleted: true, completedAt: now, isInGracePeriod: true);
    }
    
    // 10분 유지 후 새 사이클로 전환
    if (current.shouldShowNewCycle) {
      final newProgress = calculateGaugeProgress(timeframe, now);
      return GaugeState(progress: newProgress, isCompleted: false, isInGracePeriod: false);
    }
    
    // 유지 기간 중에는 100% 계속 표시
    if (current.isInGracePeriod) {
      return current.copyWith(progress: 100.0);
    }
    
    // 일반적인 진행률 업데이트
    return GaugeState(progress: progress, isCompleted: current.isCompleted, isInGracePeriod: current.isInGracePeriod);
  }

  /// 🚀 15분 통합 처리 함수 (메인 엔진)
  Future<void> fetchAndProcessAllData() async {
    try {
      checkDailyReset();

      final response = await _apiClient.getGlobalMarketData();
      final volume = response.data.totalVolumeUsd;
      final now = getKST();

      // 1. 완성된 슬롯 저장 (올바른 로직)
      await _saveCompletedSlots(volume, now);
      
      // 2. 현재 슬롯에 임시 데이터 저장
      _saveCurrentSlotData(volume, now);
      
      // 3. 모든 비교 업데이트
      _updateAllComparisons(now);
      
      // 4. 게이지 상태 업데이트 (인트라데이만)
      _updateIntradayGaugeStates(now);
      
      // 5. 데일리 데이터 처리
      _processDailyData(volume, now);

      log.d('✅ 15분 통합 처리 완료: ${(volume/1e9).toStringAsFixed(1)}B');

    } catch (e) {
      log.e('❌ 15분 통합 처리 실패: $e');
    }
  }

  /// 📊 완성된 슬롯 저장 (올바른 로직)
  Future<void> _saveCompletedSlots(double volume, DateTime now) async {
    for (String timeframe in _intradayCache.keys) {
      if (isSlotJustCompleted(timeframe, now)) {
        // 방금 완성된 슬롯에 최종 볼륨 저장
        final justCompletedSlot = getCurrentSlot(timeframe, now.subtract(const Duration(minutes: 1)));
        _intradayCache[timeframe]![justCompletedSlot] = volume;
        log.i('✅ $timeframe 슬롯 $justCompletedSlot 완성: ${(volume/1e9).toStringAsFixed(1)}B');
      }
    }
  }

  /// 💾 현재 슬롯에 임시 데이터 저장
  void _saveCurrentSlotData(double volume, DateTime now) {
    for (String timeframe in _intradayCache.keys) {
      final currentSlot = getCurrentSlot(timeframe, now);
      _intradayCache[timeframe]![currentSlot] = volume;
    }
  }

  /// 🔄 모든 비교 업데이트
  void _updateAllComparisons(DateTime now) {
    // 인트라데이 비교
    for (String timeframe in _intradayCache.keys) {
      final result = calculateIntradayComparison(timeframe, now);
      if (result.changePercent != null) {
        _latestResults[timeframe] = result.changePercent!;
      }
    }

    // 장기 비교
    for (String period in ['1day', '3day', '1week']) {
      final result = calculateLongTermComparison(period, now);
      if (result.changePercent != null) {
        _latestResults[period] = result.changePercent!;
      }
    }
  }

  /// 🎮 인트라데이 게이지 상태 업데이트
  void _updateIntradayGaugeStates(DateTime now) {
    for (String timeframe in _intradayCache.keys) {
      _gaugeStates[timeframe] = updateGaugeState(timeframe, now);
    }
  }

  /// 📅 데일리 데이터 처리
  void _processDailyData(double volume, DateTime now) {
    final today = DateFormat('yyyy-MM-dd').format(now);
    final hour = now.hour;
    
    _dailyHourlyCache[today] ??= {};
    _dailyHourlyCache[today]![hour] = volume;

    // 일별 완성 데이터 체크
    final yesterday = DateFormat('yyyy-MM-dd').format(now.subtract(const Duration(days: 1)));
    if (_dailyHourlyCache[yesterday] != null && _dailyCache[yesterday] == null) {
      final yesterdayFinal = _getDayFinalVolume(yesterday);
      if (yesterdayFinal != null) {
        _dailyCache[yesterday] = yesterdayFinal;
        log.i('📊 일별 완성: $yesterday = ${(yesterdayFinal / 1e9).toStringAsFixed(1)}B');
      }
    }
  }

  /// 📅 하루 최종 볼륨
  double? _getDayFinalVolume(String date) {
    final hourlyData = _dailyHourlyCache[date];
    if (hourlyData == null || hourlyData.isEmpty) return null;
    final latestHour = hourlyData.keys.reduce((a, b) => a > b ? a : b);
    return hourlyData[latestHour];
  }

  /// 🕐 인트라데이 비교 계산 (완성된 슬롯만 사용)
  ComparisonResult calculateIntradayComparison(String timeframe, DateTime now) {
    final currentSlot = getCurrentSlot(timeframe, now);
    final progress = calculateGaugeProgress(timeframe, now);

    if (!_hasInitialComparison[timeframe]!) {
      // 최초 비교: 3개 완성된 슬롯 필요
      if (currentSlot < 3) {
        return ComparisonResult.inProgress(progress);
      }

      final slot1 = currentSlot - 3;
      final slot2 = currentSlot - 2;
      final slot3 = currentSlot - 1;

      final vol1 = _intradayCache[timeframe]![slot1];
      final vol2 = _intradayCache[timeframe]![slot2];
      final vol3 = _intradayCache[timeframe]![slot3];

      if (vol1 != null && vol2 != null && vol3 != null) {
        final activity1 = _calculateActivityPercentage(vol2, vol1);
        final activity2 = _calculateActivityPercentage(vol3, vol2);

        if (activity1 != 0) {
          final changePercent = (activity2 - activity1) / activity1 * 100;
          _hasInitialComparison[timeframe] = true;
          log.i('🎯 $timeframe 최초 비교 완료: ${changePercent.toStringAsFixed(2)}%');
          return ComparisonResult.completed(changePercent, progress);
        }
      }

      return ComparisonResult.inProgress(progress);

    } else {
      // 이후 비교: 2개 완성된 슬롯 필요
      if (currentSlot < 2) {
        return ComparisonResult.inProgress(progress);
      }

      final prevSlot = currentSlot - 2;
      final lastSlot = currentSlot - 1;

      final prevVol = _intradayCache[timeframe]![prevSlot];
      final lastVol = _intradayCache[timeframe]![lastSlot];

      if (prevVol != null && lastVol != null) {
        final changePercent = _calculateActivityPercentage(lastVol, prevVol);
        log.d('🔄 $timeframe 지속 비교: ${changePercent.toStringAsFixed(2)}%');
        return ComparisonResult.completed(changePercent, progress);
      }

      return ComparisonResult.inProgress(progress);
    }
  }

  /// ✅ 활성도 계산: 퍼센트 증가율
  double _calculateActivityPercentage(double current, double previous) {
    if (previous <= 0) return 0.0;
    return (current - previous) / previous * 100;
  }

  /// 📅 장기 비교 계산
  ComparisonResult calculateLongTermComparison(String period, DateTime now) {
    final progress = _calculateLongTermProgress(period, now);

    if (!_hasLongTermComparison[period]!) {
      if (!_hasEnoughDataForLongTermComparison(period)) {
        return ComparisonResult.inProgress(progress);
      }

      final result = _performLongTermComparison(period);
      if (result != null) {
        _hasLongTermComparison[period] = true;
        log.i('🎯 $period 최초 장기 비교 완료: ${result.toStringAsFixed(2)}%');
        return ComparisonResult.completed(result, progress);
      }

    } else {
      final result = _performLongTermComparison(period);
      if (result != null) {
        return ComparisonResult.completed(result, progress);
      }
    }

    return ComparisonResult.inProgress(progress);
  }

  /// 📊 장기 데이터 충분성 체크
  bool _hasEnoughDataForLongTermComparison(String period) {
    final dayCount = _dailyCache.length;
    switch (period) {
      case '1day': return dayCount >= 3;
      case '3day': return dayCount >= 5;
      case '1week': return dayCount >= 9;
      default: return false;
    }
  }

  /// 📊 장기 비교 실행
  double? _performLongTermComparison(String period) {
    final dates = _getSortedDates();
    
    switch (period) {
      case '1day':
        if (dates.length >= 3) {
          final yesterday = _dailyCache[dates[dates.length - 2]]!;
          final dayBefore = _dailyCache[dates[dates.length - 3]]!;
          return (yesterday - dayBefore) / dayBefore * 100;
        }
        break;

      case '3day':
        if (dates.length >= 5) {
          final avg3days = (dates.take(3).map((d) => _dailyCache[d]!).reduce((a, b) => a + b)) / 3;
          final day4 = _dailyCache[dates[3]]!;
          return (day4 - avg3days) / avg3days * 100;
        }
        break;

      case '1week':
        if (dates.length >= 9) {
          final avg7days = (dates.take(7).map((d) => _dailyCache[d]!).reduce((a, b) => a + b)) / 7;
          final day8 = _dailyCache[dates[7]]!;
          return (day8 - avg7days) / avg7days * 100;
        }
        break;
    }
    return null;
  }

  /// 📊 장기 진행률 계산
  double _calculateLongTermProgress(String period, DateTime now) {
    if (!_hasLongTermComparison[period]!) {
      final dayCount = _dailyCache.length;
      switch (period) {
        case '1day': return (dayCount >= 3 ? 100.0 : (dayCount / 3.0 * 100)).floorToDouble();
        case '3day': return (dayCount >= 5 ? 100.0 : (dayCount / 5.0 * 100)).floorToDouble();
        case '1week': return (dayCount >= 9 ? 100.0 : (dayCount / 9.0 * 100)).floorToDouble();
        default: return 0.0;
      }
    } else {
      final midnight = DateTime(now.year, now.month, now.day);
      final elapsed = now.difference(midnight).inMinutes;
      return (elapsed / 1440.0 * 100).clamp(0.0, 100.0).floorToDouble();
    }
  }

  /// 📊 정렬된 날짜 목록
  List<String> _getSortedDates() {
    final dates = _dailyCache.keys.toList();
    dates.sort();
    return dates;
  }

  /// 📅 데일리 현황 계산
  DailyStatusData calculateDailyStatus(double currentVolume) {
    final now = getKST();
    final today = DateFormat('yyyy-MM-dd').format(now);
    final yesterday = DateFormat('yyyy-MM-dd').format(now.subtract(const Duration(days: 1)));

    // 시간대별 강도
    final todayHour = _dailyHourlyCache[today]?[now.hour];
    final yesterdayHour = _dailyHourlyCache[yesterday]?[now.hour];
    double? hourlyIntensityChange;
    if (todayHour != null && yesterdayHour != null) {
      hourlyIntensityChange = (todayHour - yesterdayHour) / yesterdayHour * 100;
    }

    // 누적률
    final yesterdayFinal = _getDayFinalVolume(yesterday);
    double? accumulationRate;
    if (yesterdayFinal != null) {
      accumulationRate = (currentVolume / yesterdayFinal) * 100;
    }

    // 예상 최종량
    final elapsed = now.hour * 60 + now.minute;
    final dayProgress = elapsed / 1440.0;
    double? estimatedFinal;
    if (dayProgress > 0.1) {
      estimatedFinal = currentVolume / dayProgress;
    }

    return DailyStatusData(
      hourlyIntensityChange: hourlyIntensityChange,
      accumulationRate: accumulationRate,
      estimatedFinal: estimatedFinal,
      yesterdayFinal: yesterdayFinal,
      todayCurrent: currentVolume,
    );
  }

  /// 🎮 게이지 상태 가져오기
  GaugeState getGaugeState(String timeframe) {
    return _gaugeStates[timeframe] ?? GaugeState.initial();
  }

  /// 📊 최신 결과 가져오기
  double? getLatestResult(String timeframe) {
    return _latestResults[timeframe];
  }

  /// 🎮 기존 호환성: 인트라데이 게이지 (0.0-1.0)
  double calculateIntradayGauge(String timeframe) {
    return calculateGaugeProgress(timeframe, getKST()) / 100.0;
  }

  /// 📅 기존 호환성: 장기 게이지 (0.0-1.0)
  double calculateLongTermGauge(String period) {
    return _calculateLongTermProgress(period, getKST()) / 100.0;
  }

  /// 🚀 앱 시작 시 모든 슬롯 체크
  Future<void> checkAllSlotsOnAppStart() async {
    await fetchAndProcessAllData();
  }

  /// ⏰ 마스터 타이머 시작 (호환성 - 실제로는 marketGlobalDataProvider에서 처리)
  void startMasterTimer() {
    // marketGlobalDataProvider에서 처리됨
  }
}

/// 💰 마켓 무드 계산기
class MarketMoodCalculator {
  static String _addCommas(String numberStr) {
    final parts = numberStr.split('.');
    final integerPart = parts[0];
    final reversedInteger = integerPart.split('').reversed.join('');
    final withCommas = reversedInteger
        .replaceAllMapped(RegExp(r'.{3}'), (match) => '${match.group(0)},')
        .split('')
        .reversed
        .join('');
    final result = withCommas.startsWith(',') ? withCommas.substring(1) : withCommas;
    return parts.length > 1 ? '$result.${parts[1]}' : result;
  }

  static String formatVolume(double volumeUsd, [double usdToKrw = 1400]) {
    final volumeKrw = volumeUsd * usdToKrw;
    if (volumeKrw >= 1e12) {
      final trillions = (volumeKrw / 1e12).toStringAsFixed(0);
      return '${_addCommas(trillions)}조원';
    }
    if (volumeKrw >= 1e8) {
      final hundreds = (volumeKrw / 1e8).toStringAsFixed(0);
      return '${_addCommas(hundreds)}억원';
    }
    return '${(volumeKrw / 1e8).toStringAsFixed(1)}억원';
  }

  static String getMoodEmoji(double changePercent) {
    if (changePercent >= 50) return '🚀';
    if (changePercent >= 20) return '🔥';
    if (changePercent >= -20) return '⚖️';
    if (changePercent >= -50) return '💧';
    return '🧊';
  }

  static MarketMood calculateMoodByTimeframe(double changePercent, String timeframe) {
    double threshold50, threshold20;

    switch (timeframe) {
      case '30min':
      case '1hour':
        threshold50 = 75.0; threshold20 = 30.0; break;
      case '2hour':
      case '4hour':
        threshold50 = 50.0; threshold20 = 25.0; break;
      case '8hour':
      case '12hour':
        threshold50 = 37.0; threshold20 = 18.0; break;
      case '1day':
        threshold50 = 37.0; threshold20 = 15.0; break;
      case '3day':
        threshold50 = 25.0; threshold20 = 12.0; break;
      case '1week':
        threshold50 = 20.0; threshold20 = 10.0; break;
      default:
        threshold50 = 50.0; threshold20 = 20.0;
    }

    if (changePercent >= threshold50) return MarketMood.bull;
    if (changePercent >= threshold20) return MarketMood.weakBull;
    if (changePercent >= -threshold20) return MarketMood.sideways;
    if (changePercent >= -threshold50) return MarketMood.bear;
    return MarketMood.deepBear;
  }

  static MarketMood calculateCurrentMood(TimeframeComparisonData data) {
    if (data.thirtyMin.changePercent != null) {
      return calculateMoodByTimeframe(data.thirtyMin.changePercent!, '30min');
    }
    return MarketMood.sideways;
  }

  static String getLeftText(String timeframe, ComparisonResult result, GaugeState gauge) {
    if (result.changePercent != null) {
      return '$timeframe: +100%';
    } else {
      return '$timeframe: 진행률 ${gauge.progress.toInt()}%';
    }
  }

  static String getRightText(double? changePercent) {
    if (changePercent != null) {
      final emoji = getMoodEmoji(changePercent);
      return '${changePercent.toStringAsFixed(1)}% $emoji';
    } else {
      return '';
    }
  }
}

/// 🌐 Provider들

/// API 클라이언트 Provider
final coinGeckoApiClientProvider = Provider<CoinGeckoApiClient>((ref) {
  return CoinGeckoApiClient();
});

/// 환율 Provider
final exchangeRateProvider = FutureProvider.autoDispose<double>((ref) async {
  final client = ref.read(coinGeckoApiClientProvider);
  try {
    final rate = await client.getUsdToKrwRate();
    log.d('💱 환율 조회 성공: $rate원');
    return rate;
  } catch (e) {
    log.w('⚠️ 환율 조회 실패, 기본값 사용: $e');
    return 1400.0;
  }
});

/// 슬롯 캐시 매니저 Provider
final ultimateSlotCacheManagerProvider = Provider<UltimateSlotCacheManager>((ref) {
  final manager = UltimateSlotCacheManager.instance;
  final apiClient = ref.read(coinGeckoApiClientProvider);
  manager.setApiClient(apiClient);
  return manager;
});

/// 🚀 단일 15분 타이머 기반 글로벌 마켓 데이터 Provider
final marketGlobalDataProvider = StreamProvider<CoinGeckoGlobalData>((ref) {
  final client = ref.read(coinGeckoApiClientProvider);
  final slotManager = ref.read(ultimateSlotCacheManagerProvider);
  final controller = StreamController<CoinGeckoGlobalData>();

  Timer? timer;
  
  Future<void> fetchData() async {
    try {
      // 15분 통합 처리 먼저 실행
      await slotManager.fetchAndProcessAllData();
      
      // API 호출 및 스트림 업데이트
      final response = await client.getGlobalMarketData();
      
      if (!controller.isClosed) {
        controller.add(response.data);
      }
    } catch (e) {
      log.e('❌ 마켓 데이터 조회 실패: $e');
      if (!controller.isClosed) {
        controller.addError(e);
      }
    }
  }

  // 최초 실행
  fetchData();

  // 단일 15분 타이머
  timer = Timer.periodic(const Duration(minutes: 15), (timer) => fetchData());

  ref.onDispose(() {
    timer?.cancel();
    controller.close();
  });

  return controller.stream;
});

/// 마켓 무드 데이터 Provider
final marketMoodProvider = StreamProvider<MarketMoodData>((ref) {
  return ref.watch(marketGlobalDataProvider).when(
    data: (globalData) async* {
      yield MarketMoodData.fromCoinGecko(globalData);
    },
    loading: () => const Stream<MarketMoodData>.empty(),
    error: (error, stackTrace) => Stream<MarketMoodData>.error(error, stackTrace),
  );
});

/// 🚀 추가 필요한 Provider들 (app_providers.dart에서 요구하는 것들)

/// 마켓 무드 상태 Provider (기존 호환성)
final marketMoodStateProvider = Provider<Map<String, dynamic>>((ref) {
  final marketMoodAsync = ref.watch(marketMoodProvider);
  final timeframeComparison = ref.watch(timeframeComparisonProvider);
  final dailyStatus = ref.watch(dailyStatusProvider);
  final currentMood = ref.watch(currentMarketMoodProvider);
  final exchangeRateAsync = ref.watch(exchangeRateProvider);

  return {
    'status': marketMoodAsync.hasValue ? 'ready' : 'loading',
    'marketData': marketMoodAsync.valueOrNull,
    'timeframeComparison': timeframeComparison,
    'dailyStatus': dailyStatus,
    'currentMood': currentMood,
    'exchangeRate': exchangeRateAsync.valueOrNull ?? 1400.0,
    'isLoading': marketMoodAsync.isLoading || exchangeRateAsync.isLoading,
    'hasError': marketMoodAsync.hasError || exchangeRateAsync.hasError,
    'errorMessage': marketMoodAsync.hasError ? marketMoodAsync.error.toString() : 
                   exchangeRateAsync.hasError ? exchangeRateAsync.error.toString() : null,
  };
});

/// Section 1: 타임프레임별 비교 Provider
final timeframeComparisonProvider = Provider<TimeframeComparisonData>((ref) {
  final marketMoodAsync = ref.watch(marketMoodProvider);
  final slotManager = ref.read(ultimateSlotCacheManagerProvider);

  return marketMoodAsync.when(
    data: (data) {
      final now = slotManager.getKST();

      return TimeframeComparisonData(
        thirtyMin: slotManager.calculateIntradayComparison('30min', now),
        oneHour: slotManager.calculateIntradayComparison('1hour', now),
        twoHour: slotManager.calculateIntradayComparison('2hour', now),
        fourHour: slotManager.calculateIntradayComparison('4hour', now),
        eightHour: slotManager.calculateIntradayComparison('8hour', now),
        twelveHour: slotManager.calculateIntradayComparison('12hour', now),
        oneDay: slotManager.calculateLongTermComparison('1day', now),
        threeDay: slotManager.calculateLongTermComparison('3day', now),
        oneWeek: slotManager.calculateLongTermComparison('1week', now),
      );
    },
    loading: () => TimeframeComparisonData.loading(),
    error: (_, __) => TimeframeComparisonData.loading(),
  );
});

/// Section 2: 데일리 현황 Provider
final dailyStatusProvider = Provider<DailyStatusData>((ref) {
  final marketMoodAsync = ref.watch(marketMoodProvider);
  final slotManager = ref.read(ultimateSlotCacheManagerProvider);

  return marketMoodAsync.when(
    data: (data) => slotManager.calculateDailyStatus(data.totalVolumeUsd),
    loading: () => DailyStatusData.empty(),
    error: (_, __) => DailyStatusData.empty(),
  );
});

/// 현재 마켓 무드 Provider
final currentMarketMoodProvider = Provider<MarketMood>((ref) {
  final comparisonData = ref.watch(timeframeComparisonProvider);
  return MarketMoodCalculator.calculateCurrentMood(comparisonData);
});

/// 게이지 상태 Provider
final gaugeStateProvider = Provider.family<GaugeState, String>((ref, timeframe) {
  final slotManager = ref.read(ultimateSlotCacheManagerProvider);
  ref.watch(marketMoodProvider);
  return slotManager.getGaugeState(timeframe);
});

/// 최신 결과 Provider
final latestResultProvider = Provider.family<double?, String>((ref, timeframe) {
  final slotManager = ref.read(ultimateSlotCacheManagerProvider);
  ref.watch(marketMoodProvider);
  return slotManager.getLatestResult(timeframe);
});

/// 기존 호환성 게이지 Provider들
final intradayGaugeProvider = Provider.family<double, String>((ref, timeframe) {
  final slotManager = ref.read(ultimateSlotCacheManagerProvider);
  ref.watch(marketMoodProvider);
  return slotManager.calculateIntradayGauge(timeframe);
});

final longTermGaugeProvider = Provider.family<double, String>((ref, period) {
  final slotManager = ref.read(ultimateSlotCacheManagerProvider);
  ref.watch(marketMoodProvider);
  return slotManager.calculateLongTermGauge(period);
});

/// 메인 시스템 Provider
final mainMarketMoodProvider = Provider<Map<String, dynamic>>((ref) {
  final marketMoodAsync = ref.watch(marketMoodProvider);
  final timeframeComparison = ref.watch(timeframeComparisonProvider);
  final dailyStatus = ref.watch(dailyStatusProvider);
  final currentMood = ref.watch(currentMarketMoodProvider);
  final exchangeRateAsync = ref.watch(exchangeRateProvider);

  return {
    'status': marketMoodAsync.hasValue ? 'ready' : 'loading',
    'marketData': marketMoodAsync.valueOrNull,
    'timeframeComparison': timeframeComparison,
    'dailyStatus': dailyStatus,
    'currentMood': currentMood,
    'exchangeRate': exchangeRateAsync.valueOrNull ?? 1400.0,
    'isLoading': marketMoodAsync.isLoading || exchangeRateAsync.isLoading,
    'hasError': marketMoodAsync.hasError || exchangeRateAsync.hasError,
    'errorMessage': marketMoodAsync.hasError ? marketMoodAsync.error.toString() : 
                   exchangeRateAsync.hasError ? exchangeRateAsync.error.toString() : null,
  };
});

/// 디버그 정보 Provider
final debugInfoProvider = Provider<Map<String, dynamic>>((ref) {
  final slotManager = ref.read(ultimateSlotCacheManagerProvider);
  
  return {
    'lastResetDate': slotManager._lastResetDate ?? 'Not set',
    'intradayInitialStatus': slotManager._hasInitialComparison,
    'longTermInitialStatus': slotManager._hasLongTermComparison,
    'intradaySlotCounts': slotManager._intradayCache.map(
      (timeframe, slots) => MapEntry(timeframe, slots.length)
    ),
    'dailyCacheCount': slotManager._dailyCache.length,
    'dailyHourlyCacheCount': slotManager._dailyHourlyCache.length,
    'gaugeStates': slotManager._gaugeStates.map(
      (timeframe, state) => MapEntry(timeframe, '${state.progress.toInt()}% ${state.isCompleted ? "완료" : "진행중"}')
    ),
    'latestResults': slotManager._latestResults.map(
      (timeframe, result) => MapEntry(timeframe, '${result.toStringAsFixed(1)}%')
    ),
  };
});