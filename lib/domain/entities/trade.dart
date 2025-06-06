import 'package:equatable/equatable.dart';

/// 순수 도메인 모델: 비즈니스 로직만 포함
class Trade extends Equatable {
  /// 시장 코드 (예: "KRW-BTC")
  final String market;

  /// 체결 단가
  final double price;

  /// 체결 수량
  final double volume;

  /// 'BID' 또는 'ASK'
  final String side;

  /// 가격 변동량
  final double changePrice;

  /// 변동 상태 ('RISE'/'FALL'/'EVEN')
  final String changeState;

  /// UTC 밀리초 타임스탬프
  final int timestampMs;

  /// 중복 제거용 고유 ID
  final String sequentialId;

  const Trade({
    required this.market,
    required this.price,
    required this.volume,
    required this.side,
    required this.changePrice,
    required this.changeState,
    required this.timestampMs,
    required this.sequentialId,
  });

  @override
  List<Object?> get props => [
        market,
        price,
        volume,
        side,
        changePrice,
        changeState,
        timestampMs,
        sequentialId,
      ];

  /// 총 체결 금액
  double get total => price * volume;

  /// 매수 여부
  bool get isBuy => side == 'BID';

  /// DateTime 변환
  DateTime get timestamp => DateTime.fromMillisecondsSinceEpoch(timestampMs);
}
