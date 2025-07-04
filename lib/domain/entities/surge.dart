// lib/domain/entities/surge.dart
import 'package:equatable/equatable.dart';
import '../../core/config/app_config.dart';

/// 순수 도메인 모델: 급등/급락 데이터 비즈니스 로직
class Surge extends Equatable {
  /// 시장 코드 (예: "KRW-BTC")
  final String market;
  
  /// 해당 시간대 변동률 (퍼센트 기준)
  final double changePercent;
  
  /// 시간대 시작 가격
  final double basePrice;
  
  /// 현재 가격
  final double currentPrice;
  
  /// 마지막 업데이트 시간 (UTC 밀리초)
  final int lastUpdatedMs;
  
  /// 시간대 (예: "1m", "5m", "15m")
  final String timeFrame;
  
  /// 해당 시간대 시작 시간 (UTC 밀리초)
  final int timeFrameStartMs;

  const Surge({
    required this.market,
    required this.changePercent,
    required this.basePrice,
    required this.currentPrice,
    required this.lastUpdatedMs,
    required this.timeFrame,
    required this.timeFrameStartMs,
  });

  @override
  List<Object?> get props => [
    market,
    changePercent,
    basePrice,
    currentPrice,
    lastUpdatedMs,
    timeFrame,
    timeFrameStartMs,
  ];

  /// 마지막 업데이트 DateTime 변환
  DateTime get lastUpdated => DateTime.fromMillisecondsSinceEpoch(lastUpdatedMs);
  
  /// 시간대 시작 DateTime 변환
  DateTime get timeFrameStart => DateTime.fromMillisecondsSinceEpoch(timeFrameStartMs);
  
  /// 시간대 종료 예정 시간
  DateTime get timeFrameEnd {
    final duration = _getTimeFrameDuration();
    return timeFrameStart.add(duration);
  }
  
  /// 현재 시간대 남은 시간 (초)
  int get remainingSeconds {
    final now = DateTime.now();
    final remaining = timeFrameEnd.difference(now).inSeconds;
    return remaining > 0 ? remaining : 0;
  }
  
  /// 현재 시간대 남은 시간 포맷 (예: "3:42", "12:18")
  String get remainingTimeFormatted {
    final remaining = remainingSeconds;
    if (remaining <= 0) return "00:00";
    
    final hours = remaining ~/ 3600;
    final minutes = (remaining % 3600) ~/ 60;
    final seconds = remaining % 60;
    
    if (hours > 0) {
      return "${hours.toString().padLeft(2, '0')}:${minutes.toString().padLeft(2, '0')}:${seconds.toString().padLeft(2, '0')}";
    } else {
      return "${minutes.toString().padLeft(2, '0')}:${seconds.toString().padLeft(2, '0')}";
    }
  }
  
  /// 시간대별 Duration 계산 (AppConfig.timeFrames 활용)
  Duration _getTimeFrameDuration() {
    // timeFrame에서 분 단위 추출 ("15m" → 15)
    final minutes = int.tryParse(timeFrame.replaceAll('m', ''));
    if (minutes != null && AppConfig.timeFrames.contains(minutes)) {
      return Duration(minutes: minutes);
    }
    return const Duration(minutes: 15); // 기본값
  }
  
  /// 변동이 유의미한지 체크 (0이 아님)
  bool get hasChange => changePercent != 0;
  
  /// 급등인지 체크 (양수)
  bool get isRising => changePercent > 0;
  
  /// 급락인지 체크 (음수)
  bool get isFalling => changePercent < 0;
  
  /// 변동률 절댓값
  double get absChangePercent => changePercent.abs();
  
  /// 코인 티커만 추출 (KRW- 제거)
  String get ticker => market.replaceFirst('KRW-', '');
  
  /// 변동률 포맷팅 (예: "+12.34%", "-5.67%")
  String get formattedChangePercent {
    final sign = changePercent >= 0 ? '+' : '';
    return '$sign${changePercent.toStringAsFixed(2)}%';
  }
  
  /// 복사본 생성 (불변성 유지)
  Surge copyWith({
    String? market,
    double? changePercent,
    double? basePrice,
    double? currentPrice,
    int? lastUpdatedMs,
    String? timeFrame,
    int? timeFrameStartMs,
  }) {
    return Surge(
      market: market ?? this.market,
      changePercent: changePercent ?? this.changePercent,
      basePrice: basePrice ?? this.basePrice,
      currentPrice: currentPrice ?? this.currentPrice,
      lastUpdatedMs: lastUpdatedMs ?? this.lastUpdatedMs,
      timeFrame: timeFrame ?? this.timeFrame,
      timeFrameStartMs: timeFrameStartMs ?? this.timeFrameStartMs,
    );
  }
}