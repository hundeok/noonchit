// lib/core/common/time_frame_types.dart
import 'package:flutter/foundation.dart';
import '../config/app_config.dart';

// ══════════════════════════════════════════════════════════════════════════════
// 🕐 TimeFrame Types (기존)
// ══════════════════════════════════════════════════════════════════════════════

/// 시간대 Enum (완전한 타입 안전성)
enum TimeFrame {
  min1(1, '1분'),
  min5(5, '5분'),
  min15(15, '15분'),
  min30(30, '30분'),
  min60(60, '1시간'),
  hour2(120, '2시간'),
  hour4(240, '4시간'),
  hour8(480, '8시간'),
  hour12(720, '12시간'),
  day1(1440, '1일');

  const TimeFrame(this.minutes, this.displayName);
  final int minutes;
  final String displayName;
  
  Duration get duration => Duration(minutes: minutes);
  String get key => '${minutes}m';
  
  /// AppConfig에서 TimeFrame 변환
  static List<TimeFrame> fromAppConfig() {
    return AppConfig.timeFrames.map((minutes) {
      return TimeFrame.values.firstWhere(
        (tf) => tf.minutes == minutes,
        orElse: () => TimeFrame.min1,
      );
    }).toList();
  }
}

/// 시간대 리셋 이벤트
@immutable
class TimeFrameResetEvent {
  final TimeFrame timeFrame;
  final DateTime resetTime;
  final DateTime nextResetTime;

  const TimeFrameResetEvent({
    required this.timeFrame,
    required this.resetTime,
    required this.nextResetTime,
  });

  Duration get timeUntilNextReset => nextResetTime.difference(DateTime.now());
  bool get isOverdue => DateTime.now().isAfter(nextResetTime);
}

/// 배치 처리 설정 (공통)
@immutable
class ProcessingConfig {
  final int maxCacheSize;
  final int maxMarketsPerTimeFrame;
  final Duration minBatchInterval;
  final Duration maxBatchInterval;
  final Duration defaultBatchInterval;
  final int highLoadThreshold;
  final int lowLoadThreshold;

  const ProcessingConfig({
    this.maxCacheSize = 1000,
    this.maxMarketsPerTimeFrame = 200,
    this.minBatchInterval = const Duration(milliseconds: 50),
    this.maxBatchInterval = const Duration(milliseconds: 200),
    this.defaultBatchInterval = const Duration(milliseconds: 100),
    this.highLoadThreshold = 50,
    this.lowLoadThreshold = 10,
  });

  /// 적응형 배치 간격 계산
  Duration calculateBatchInterval(int bufferSize) {
    if (bufferSize > highLoadThreshold) return minBatchInterval;
    if (bufferSize < lowLoadThreshold) return maxBatchInterval;
    return defaultBatchInterval;
  }

  /// 워밍업 배치 간격
  Duration get warmupBatchInterval => const Duration(milliseconds: 300);
}

// ══════════════════════════════════════════════════════════════════════════════
// 💰 Trade Types (Trade Provider에서 이관)
// ══════════════════════════════════════════════════════════════════════════════

/// 거래 필터 Enum
enum TradeFilter {
  min20M(20000000, '2천만원'),
  min50M(50000000, '5천만원'),
  min100M(100000000, '1억원'),
  min200M(200000000, '2억원'),
  min300M(300000000, '3억원'),
  min400M(400000000, '4억원'),
  min500M(500000000, '5억원'),
  min1B(1000000000, '10억원');
  
  const TradeFilter(this.value, this.displayName);
  final double value;
  final String displayName;
  
  static TradeFilter fromValue(double value) {
    return values.firstWhere(
      (filter) => filter.value == value,
      orElse: () => TradeFilter.min20M,
    );
  }
  
  static List<TradeFilter> get available => values;
}

/// 거래 모드 Enum
enum TradeMode {
  accumulated('누적'),
  range('구간');
  
  const TradeMode(this.displayName);
  final String displayName;
  
  bool get isRange => this == TradeMode.range;
  bool get isAccumulated => this == TradeMode.accumulated;
}

/// 거래 설정
class TradeConfig {
  static const int maxTradesPerFilter = 200;
  static const int maxCacheSize = 250;
  static const Duration batchInterval = Duration(milliseconds: 100);
  
  static List<TradeFilter> get supportedFilters => TradeFilter.available;
}

/// 마켓 정보 클래스
@immutable
class MarketInfo {
  final String market;
  final String koreanName;
  final String englishName;

  const MarketInfo({
    required this.market,
    required this.koreanName,
    required this.englishName,
  });

  factory MarketInfo.fromJson(Map<String, dynamic> json) {
    return MarketInfo(
      market: json['market'] ?? '',
      koreanName: json['korean_name'] ?? '',
      englishName: json['english_name'] ?? '',
    );
  }
}