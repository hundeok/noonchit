// lib/domain/usecases/market_mood_usecase.dart
// 🎯 Domain Layer: 비즈니스 로직 (순수 계산 알고리즘)

import 'dart:async';
import 'dart:math';
import '../entities/market_mood.dart';
import '../repositories/market_mood_repository.dart';

/// 💰 마켓 무드 계산기 (순수 비즈니스 로직)
class MarketMoodCalculator {
  static MarketMood calculateMoodByComparison(double current, double previous) {
    if (previous <= 0) return MarketMood.sideways;
    final changePercent = ((current - previous) / previous) * 100;
    
    // [수정] 요청하신 임계값 (10, 5, -5, -10)으로 변경
    if (changePercent >= 10) return MarketMood.bull;
    if (changePercent >= 5) return MarketMood.weakBull;
    if (changePercent >= -5) return MarketMood.sideways;
    if (changePercent >= -10) return MarketMood.bear;
    return MarketMood.deepBear;
  }

  static MarketMood calculateMoodByAbsolute(double volumeUsd) {
    if (volumeUsd >= 150e9) return MarketMood.bull;
    if (volumeUsd >= 100e9) return MarketMood.weakBull;
    if (volumeUsd >= 70e9) return MarketMood.sideways;
    if (volumeUsd >= 50e9) return MarketMood.bear;
    return MarketMood.deepBear;
  }
}

/// 🧮 볼륨 비교 계산기 (순수 계산 로직)
class VolumeComparator {
  final MarketMoodRepository _repository;

  VolumeComparator(this._repository);

  double _calculateChangePercent(double current, double previous) {
    if (previous <= 0) return 0.0;
    return ((current - previous) / previous) * 100;
  }

  double _calculateProgress(int targetMinutes) {
    final elapsed = DateTime.now().difference(_repository.getAppStartTime()).inMinutes;
    if (elapsed < targetMinutes) {
      return min(elapsed / targetMinutes, 1.0);
    }
    final cycleElapsed = (elapsed - targetMinutes) % targetMinutes;
    return cycleElapsed / targetMinutes;
  }

  double _calculateLongTermProgress(int targetMinutes) {
    final elapsed = DateTime.now().difference(_repository.getAppStartTime()).inMinutes;
    return min(elapsed / targetMinutes, 1.0);
  }

  Future<ComparisonResult> _compareGeneric({
    required double currentVolume,
    required int targetMinutes,
    required bool isLongTermAverage,
    required int daysForAverage,
  }) async {
    final elapsed = DateTime.now().difference(_repository.getAppStartTime()).inMinutes;

    if (isLongTermAverage) {
      if (elapsed < targetMinutes) {
        return ComparisonResult.collecting(_calculateLongTermProgress(targetMinutes));
      }
      final average = await _repository.getAverageVolume(daysForAverage);
      if (average == null) {
        return ComparisonResult.unavailable('샘플 부족');
      }
      return ComparisonResult.ready(_calculateChangePercent(currentVolume, average));
    }

    if (elapsed < targetMinutes) {
      return ComparisonResult.collecting(_calculateProgress(targetMinutes));
    }
    final past = await _repository.getVolumeNMinutesAgo(targetMinutes);
    if (past == null) {
      return ComparisonResult.collecting(_calculateProgress(targetMinutes));
    }
    return ComparisonResult.ready(_calculateChangePercent(currentVolume, past.volumeUsd));
  }

  Future<ComparisonResult> compare30Minutes(double currentVolume) =>
      _compareGeneric(currentVolume: currentVolume, targetMinutes: 30, isLongTermAverage: false, daysForAverage: 0);

  Future<ComparisonResult> compare1Hour(double currentVolume) =>
      _compareGeneric(currentVolume: currentVolume, targetMinutes: 60, isLongTermAverage: false, daysForAverage: 0);

  Future<ComparisonResult> compare2Hours(double currentVolume) =>
      _compareGeneric(currentVolume: currentVolume, targetMinutes: 120, isLongTermAverage: false, daysForAverage: 0);

  Future<ComparisonResult> compare4Hours(double currentVolume) =>
      _compareGeneric(currentVolume: currentVolume, targetMinutes: 240, isLongTermAverage: false, daysForAverage: 0);

  Future<ComparisonResult> compare8Hours(double currentVolume) =>
      _compareGeneric(currentVolume: currentVolume, targetMinutes: 480, isLongTermAverage: false, daysForAverage: 0);

  Future<ComparisonResult> compare12Hours(double currentVolume) =>
      _compareGeneric(currentVolume: currentVolume, targetMinutes: 720, isLongTermAverage: false, daysForAverage: 0);

  Future<ComparisonResult> compare24Hours(double currentVolume) =>
      _compareGeneric(currentVolume: currentVolume, targetMinutes: 1440, isLongTermAverage: false, daysForAverage: 0);

  Future<ComparisonResult> compare3DayAverage(double currentVolume) =>
      _compareGeneric(currentVolume: currentVolume, targetMinutes: 4320, isLongTermAverage: true, daysForAverage: 3);

  Future<ComparisonResult> compareWeeklyAverage(double currentVolume) =>
      _compareGeneric(currentVolume: currentVolume, targetMinutes: 10080, isLongTermAverage: true, daysForAverage: 7);

  /// [개선] 전체 비교 데이터 계산 (병렬 처리)
  Future<ComparisonData> calculateAll(double currentVolume) async {
    final results = await Future.wait([
      compare30Minutes(currentVolume),
      compare1Hour(currentVolume),
      compare2Hours(currentVolume),
      compare4Hours(currentVolume),
      compare8Hours(currentVolume),
      compare12Hours(currentVolume),
      compare24Hours(currentVolume),
      compare3DayAverage(currentVolume),
      compareWeeklyAverage(currentVolume),
    ]);

    return ComparisonData(
      thirtyMin: results[0],
      oneHour: results[1],
      twoHour: results[2],
      fourHour: results[3],
      eightHour: results[4],
      twelveHour: results[5],
      twentyFourHour: results[6],
      threeDayAverage: results[7],
      weeklyAverage: results[8],
    );
  }
}

/// 🎯 마켓무드 UseCase (전체 비즈니스 로직 조합) - Provider와 매칭
class MarketMoodUsecase {
  final MarketMoodRepository _repository;
  final VolumeComparator _comparator;

  MarketMoodUsecase(this._repository) : _comparator = VolumeComparator(_repository);

  Future<void> addVolumeData(double volumeUsd) async {
    final volumeData = VolumeData(
      timestamp: DateTime.now(),
      volumeUsd: volumeUsd,
    );
    await _repository.addVolumeData(volumeData);
  }

  /// [수정] 현재 마켓무드 계산 기준을 2시간으로 변경
  Future<MarketMood> calculateCurrentMood(double currentVolume) async {
    // 2시간 = 120분
    final twoHoursAgo = await _repository.getVolumeNMinutesAgo(120);
    
    if (twoHoursAgo != null) {
      return MarketMoodCalculator.calculateMoodByComparison(
        currentVolume, 
        twoHoursAgo.volumeUsd
      );
    }
    return MarketMoodCalculator.calculateMoodByAbsolute(currentVolume);
  }

  Future<ComparisonData> calculateVolumeComparison(double currentVolume) {
    return _comparator.calculateAll(currentVolume);
  }

  MarketMoodSystemState createSystemState({
    required MarketMoodData? marketData,
    required ComparisonData comparisonData,
    required MarketMood currentMood,
    required double exchangeRate,
    required bool isLoading,
    required bool hasError,
  }) {
    return MarketMoodSystemState(
      marketData: marketData,
      comparisonData: comparisonData,
      currentMood: currentMood,
      exchangeRate: exchangeRate,
      isLoading: isLoading,
      hasError: hasError,
    );
  }

  String generateMoodSummary(MarketMood mood) {
    switch (mood) {
      case MarketMood.bull: return '🚀 불장';
      case MarketMood.weakBull: return '🔥 약불장';
      case MarketMood.sideways: return '⚖️ 중간장';
      case MarketMood.bear: return '💧 물장';
      case MarketMood.deepBear: return '🧊 얼음장';
    }
  }

  Future<void> handleBackgroundResume() async {
    await _repository.syncMissingData();
  }

  Future<Map<String, dynamic>> getSystemHealth() async {
    return await _repository.getSystemHealth();
  }

  Future<void> logSystemStatus() async {
    await _repository.logCurrentStatus();
  }

  Future<int> getCollectedDataCount() async {
    return await _repository.getCollectedDataCount();
  }

  DateTime getAppStartTime() {
    return _repository.getAppStartTime();
  }

  Future<double> getExchangeRate() async {
    return await _repository.getExchangeRate();
  }

  Future<void> refreshExchangeRate() async {
    await _repository.refreshExchangeRate();
  }
}