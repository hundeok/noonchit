// lib/domain/entities/market_mood.dart
// 🎯 Domain Layer: 순수 엔티티들 (VolumeData 추가)

import '../../core/utils/date_time.dart'; // DateTime extension

/// 🕒 볼륨 관련 상수 정의
class VolumeConstants {
 static const int minutesPerSlot = 30;
 static const int slotsPerHour = 60 ~/ minutesPerSlot; // 2
 static const int hoursPerDay = 24;
 static const int daysInBuffer = 7;
 static const int totalSlots = slotsPerHour * hoursPerDay * daysInBuffer; // 336
 static const int maxMinutesBuffer = minutesPerSlot * totalSlots; // 10080
 static const String volumeBoxName = 'market_volumes';
}

/// 🔥 시장 분위기 enum
enum MarketMood {
 bull,       // 🚀 불장
 weakBull,   // 🔥 약불장
 sideways,   // ⚖️ 중간장
 bear,       // 💧 물장
 deepBear,   // 🧊 얼음장
}

/// 📈 볼륨 데이터 엔티티 (30분 단위)
class VolumeData {
 final DateTime timestamp;
 final double volumeUsd;

 const VolumeData({
   required this.timestamp,
   required this.volumeUsd,
 });

 /// DateTime extension 활용
 String get formattedTime => timestamp.yyyyMMddhhmm();
 String get timeAgoText => timestamp.timeAgo();
 String get shortTime => timestamp.hhmmss();

 /// JSON 직렬화
 Map<String, dynamic> toJson() => {
   'timestamp': timestamp.toIso8601String(),
   'volume_usd': volumeUsd,
 };

 factory VolumeData.fromJson(Map<String, dynamic> json) {
   return VolumeData(
     timestamp: DateTime.parse(json['timestamp']),
     volumeUsd: (json['volume_usd'] as num).toDouble(),
   );
 }

 @override
 bool operator ==(Object other) =>
     identical(this, other) ||
     other is VolumeData &&
         runtimeType == other.runtimeType &&
         timestamp == other.timestamp &&
         volumeUsd == other.volumeUsd;

 @override
 int get hashCode => timestamp.hashCode ^ volumeUsd.hashCode;

 @override
 String toString() =>
     'VolumeData(${volumeUsd.toStringAsFixed(0)}B USD at ${timestamp.hhmmss()})';
}

/// 📊 마켓 무드 데이터 엔티티
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

 /// JSON 직렬화 (DTO 호환용)
 Map<String, dynamic> toJson() => {
   'total_market_cap_usd': totalMarketCapUsd,
   'total_volume_usd': totalVolumeUsd,
   'btc_dominance': btcDominance,
   'market_cap_change_24h': marketCapChange24h,
   'updated_at': updatedAt.toIso8601String(),
 };

 @override
 bool operator ==(Object other) =>
     identical(this, other) ||
     other is MarketMoodData &&
         runtimeType == other.runtimeType &&
         totalMarketCapUsd == other.totalMarketCapUsd &&
         totalVolumeUsd == other.totalVolumeUsd &&
         btcDominance == other.btcDominance &&
         marketCapChange24h == other.marketCapChange24h;

 @override
 int get hashCode =>
     totalMarketCapUsd.hashCode ^
     totalVolumeUsd.hashCode ^
     btcDominance.hashCode ^
     marketCapChange24h.hashCode;

 @override
 String toString() =>
     'MarketMoodData(volume: ${totalVolumeUsd.toStringAsFixed(0)}, '
     'cap: ${totalMarketCapUsd.toStringAsFixed(0)}, '
     'btc: ${btcDominance.toStringAsFixed(1)}%)';
}

/// 📊 비교 결과 엔티티
class ComparisonResult {
 final bool isReady;
 final double? changePercent;
 final double progressPercent;
 final String status;

 const ComparisonResult({
   required this.isReady,
   this.changePercent,
   required this.progressPercent,
   required this.status,
 });

 factory ComparisonResult.collecting(double progress) {
   return ComparisonResult(
     isReady: false,
     changePercent: null,
     progressPercent: progress,
     status: '수집중',
   );
 }

 factory ComparisonResult.ready(double changePercent) {
   return ComparisonResult(
     isReady: true,
     changePercent: changePercent,
     progressPercent: 1.0,
     status: '완료',
   );
 }

 factory ComparisonResult.unavailable(String message) {
   return ComparisonResult(
     isReady: false,
     changePercent: null,
     progressPercent: 0.0,
     status: message,
   );
 }

 @override
 bool operator ==(Object other) =>
     identical(this, other) ||
     other is ComparisonResult &&
         runtimeType == other.runtimeType &&
         isReady == other.isReady &&
         changePercent == other.changePercent &&
         progressPercent == other.progressPercent &&
         status == other.status;

 @override
 int get hashCode =>
     isReady.hashCode ^
     changePercent.hashCode ^
     progressPercent.hashCode ^
     status.hashCode;

 @override
 String toString() =>
     'ComparisonResult(ready: $isReady, change: $changePercent%, progress: ${(progressPercent * 100).round()}%)';
}

/// 📈 전체 비교 데이터 엔티티
class ComparisonData {
 final ComparisonResult thirtyMin;
 final ComparisonResult oneHour;
 final ComparisonResult twoHour;
 final ComparisonResult fourHour;
 final ComparisonResult eightHour;
 final ComparisonResult twelveHour;
 final ComparisonResult twentyFourHour;
 final ComparisonResult threeDayAverage;
 final ComparisonResult weeklyAverage;

 const ComparisonData({
   required this.thirtyMin,
   required this.oneHour,
   required this.twoHour,
   required this.fourHour,
   required this.eightHour,
   required this.twelveHour,
   required this.twentyFourHour,
   required this.threeDayAverage,
   required this.weeklyAverage,
 });

 factory ComparisonData.loading() {
   final loading = ComparisonResult.collecting(0.0);
   return ComparisonData(
     thirtyMin: loading,
     oneHour: loading,
     twoHour: loading,
     fourHour: loading,
     eightHour: loading,
     twelveHour: loading,
     twentyFourHour: loading,
     threeDayAverage: loading,
     weeklyAverage: loading,
   );
 }

 factory ComparisonData.error() {
   final error = ComparisonResult.unavailable('오류');
   return ComparisonData(
     thirtyMin: error,
     oneHour: error,
     twoHour: error,
     fourHour: error,
     eightHour: error,
     twelveHour: error,
     twentyFourHour: error,
     threeDayAverage: error,
     weeklyAverage: error,
   );
 }

 /// 모든 비교 결과를 리스트로 반환
 List<ComparisonResult> get allResults => [
       thirtyMin,
       oneHour,
       twoHour,
       fourHour,
       eightHour,
       twelveHour,
       twentyFourHour,
       threeDayAverage,
       weeklyAverage,
     ];

 /// 준비된 비교 결과 개수
 int get readyCount => allResults.where((r) => r.isReady).length;

 /// 전체 진행률 (0.0 ~ 1.0)
 double get overallProgress =>
     allResults.map((r) => r.progressPercent).reduce((a, b) => a + b) / 9;

 @override
 bool operator ==(Object other) =>
     identical(this, other) ||
     other is ComparisonData &&
         runtimeType == other.runtimeType &&
         thirtyMin == other.thirtyMin &&
         oneHour == other.oneHour &&
         twoHour == other.twoHour &&
         fourHour == other.fourHour &&
         eightHour == other.eightHour &&
         twelveHour == other.twelveHour &&
         twentyFourHour == other.twentyFourHour &&
         threeDayAverage == other.threeDayAverage &&
         weeklyAverage == other.weeklyAverage;

 @override
 int get hashCode => Object.hash(
       thirtyMin,
       oneHour,
       twoHour,
       fourHour,
       eightHour,
       twelveHour,
       twentyFourHour,
       threeDayAverage,
       weeklyAverage,
     );

 @override
 String toString() =>
     'ComparisonData(ready: $readyCount/9, progress: ${(overallProgress * 100).round()}%)';
}

/// 📦 전체 시스템 상태 엔티티
class MarketMoodSystemState {
 final MarketMoodData? marketData;
 final ComparisonData comparisonData;
 final MarketMood currentMood;
 final double exchangeRate;
 final bool isLoading;
 final bool hasError;

 const MarketMoodSystemState({
   required this.marketData,
   required this.comparisonData,
   required this.currentMood,
   required this.exchangeRate,
   required this.isLoading,
   required this.hasError,
 });

 /// 시스템이 정상 작동 중인지 확인
 bool get isHealthy => !hasError && marketData != null;

 /// 데이터 수집 진행률 (0.0 ~ 1.0)
 double get dataProgress => comparisonData.overallProgress;

 /// 상태 요약 문자열
 String get statusSummary {
   if (hasError) return '오류 발생';
   if (isLoading) return '로딩 중';
   if (marketData == null) return '데이터 없음';
   return '정상 작동';
 }

 @override
 bool operator ==(Object other) =>
     identical(this, other) ||
     other is MarketMoodSystemState &&
         runtimeType == other.runtimeType &&
         marketData == other.marketData &&
         comparisonData == other.comparisonData &&
         currentMood == other.currentMood &&
         exchangeRate == other.exchangeRate &&
         isLoading == other.isLoading &&
         hasError == other.hasError;

 @override
 int get hashCode => Object.hash(
       marketData,
       comparisonData,
       currentMood,
       exchangeRate,
       isLoading,
       hasError,
     );

 @override
 String toString() =>
     'MarketMoodSystemState(mood: $currentMood, status: $statusSummary, progress: ${(dataProgress * 100).round()}%)';
}