// lib/domain/entities/signal.dart

/// 🚀 Signal Entity V4.1 - 온라인 지표 연동
/// 
/// 주요 개선사항:
/// - 온라인 RSI/MACD 정보 포함
/// - 다이버전스 감지 결과
/// - 신뢰도 동적 조정
/// - 스트림 건강성 정보
/// - 패턴별 고급 메타데이터

/// Signal 패턴 타입 정의 (V4.1 확장)
enum PatternType {
  surge,       // 1. 급등🚀 (1분 전 대비 0.4% 상승)
  flashFire,   // 2. 불티🔥 (3분 거래대금 급증)
  stackUp,     // 3. 스택업💰 (1분씩 연속 증가)
  stealthIn,   // 4. 침투자👣 (소량 지속 유입) - 완화됨
  blackHole,   // 5. 블랙홀🕳️ (거래대금↑ 가격변동↓) - 완화됨
  reboundShot, // 6. 쇼트터치⚡ (급락 후 반등)
}

extension PatternTypeExtension on PatternType {
  String get displayName {
    switch (this) {
      case PatternType.surge:
        return '급등🚀';
      case PatternType.flashFire:
        return '불티🔥';
      case PatternType.stackUp:
        return '스택업💰';
      case PatternType.stealthIn:
        return '침투자👣';
      case PatternType.blackHole:
        return '블랙홀🕳️';
      case PatternType.reboundShot:
        return '쇼트터치⚡';
    }
  }

  String get description {
  switch (this) {
    case PatternType.surge:
      return '가격 급등 + 체결량 폭발 + MACD·RSI·유동성 지표 충족';
    case PatternType.flashFire:
      return '거래대금 급증 + 매수 강도 + 머신급 체결 가속';
    case PatternType.stackUp:
      return '연속 매집 + MACD 상승 + 거래량 추세 정렬';
    case PatternType.stealthIn:
      return '저변동 속 유입 지속 + 분산 체결 + 누적 매수 감지';
    case PatternType.blackHole:
      return '가격 정체 + 매수·매도 균형 + 체결 왜곡 패턴';
    case PatternType.reboundShot:
      return '과매도 후 반등 + RSI·MACD 반응 + 점프 스코어 확인';
  }
}


  /// V4.1 패턴별 기본 임계값 (완화됨)
  double get defaultThreshold {
    switch (this) {
      case PatternType.surge:
        return 0.4; // 0.4% 상승 (기존 1.1%에서 완화)
      case PatternType.flashFire:
        return 2.0; // 2배 급증
      case PatternType.stackUp:
        return 2.0; // 2연속 (기존 3에서 완화)
      case PatternType.stealthIn:
        return 5000000.0; // 500만원 (기존 2000만에서 대폭 완화)
      case PatternType.blackHole:
        return 2.0; // 2% 이하 변동 (기존 1%에서 완화)
      case PatternType.reboundShot:
        return 1.5; // 1.5% 급락 후 반등
    }
  }

  /// 패턴별 시간 윈도우 (분)
  int get timeWindowMinutes {
    switch (this) {
      case PatternType.surge:
        return 1; // 1분
      case PatternType.flashFire:
        return 1; // 1분 (V4.1 단축)
      case PatternType.stackUp:
        return 1; // 1분
      case PatternType.stealthIn:
        return 5; // 5분
      case PatternType.blackHole:
        return 5; // 5분 (V4.1 확장)
      case PatternType.reboundShot:
        return 1; // 1분
    }
  }

  /// V4.1 패턴별 기본 쿨다운 시간 (초)
  int get defaultCooldownSeconds {
    switch (this) {
      case PatternType.surge:
        return 3; // 빠른 감지
      case PatternType.flashFire:
        return 2; // 가장 빠름
      case PatternType.stackUp:
        return 4; // 중간
      case PatternType.stealthIn:
        return 8; // 느림 (은밀함 특성)
      case PatternType.blackHole:
        return 10; // 가장 느림 (안정성 특성)
      case PatternType.reboundShot:
        return 5; // 중간
    }
  }

  /// V4.1 패턴별 신뢰도 기본값
  double get defaultConfidence {
    switch (this) {
      case PatternType.surge:
        return 0.8; // 높음
      case PatternType.flashFire:
        return 0.85; // 매우 높음
      case PatternType.stackUp:
        return 0.75; // 중간
      case PatternType.stealthIn:
        return 0.7; // 낮음 (은밀함)
      case PatternType.blackHole:
        return 0.8; // 높음 (안정성)
      case PatternType.reboundShot:
        return 0.9; // 매우 높음 (명확함)
    }
  }
}

/// 🆕 V4.1 온라인 지표 정보
class OnlineIndicatorInfo {
  final double? rsi;
  final double? macd;
  final double? macdSignal;
  final double? macdHistogram;
  final bool isStale;
  final DateTime lastUpdate;

  const OnlineIndicatorInfo({
    this.rsi,
    this.macd,
    this.macdSignal,
    this.macdHistogram,
    required this.isStale,
    required this.lastUpdate,
  });

  /// RSI/MACD가 유효한지 체크
  bool get hasValidData => !isStale && (rsi != null || macd != null);

  /// RSI 과매수/과매도 상태
  String get rsiState {
    if (rsi == null) return 'N/A';
    if (rsi! >= 70) return 'Overbought';
    if (rsi! <= 30) return 'Oversold';
    return 'Neutral';
  }

  /// MACD 신호 상태
  String get macdState {
    if (macd == null || macdSignal == null) return 'N/A';
    if (macd! > macdSignal!) return 'Bullish';
    if (macd! < macdSignal!) return 'Bearish';
    return 'Neutral';
  }

  Map<String, dynamic> toJson() {
    return {
      'rsi': rsi,
      'macd': macd,
      'macdSignal': macdSignal,
      'macdHistogram': macdHistogram,
      'isStale': isStale,
      'lastUpdate': lastUpdate.toIso8601String(),
      'rsiState': rsiState,
      'macdState': macdState,
    };
  }
}

/// 🆕 V4.1 다이버전스 정보
class DivergenceInfo {
  final bool isBullish;
  final bool isBearish;
  final double strength;
  final String source; // 'online-rsi', 'online-macd' 등

  const DivergenceInfo({
    required this.isBullish,
    required this.isBearish,
    required this.strength,
    required this.source,
  });

  /// 다이버전스 타입
  String get type {
    if (isBullish) return 'Bullish';
    if (isBearish) return 'Bearish';
    return 'None';
  }

  /// 신뢰도 (강도 기반)
  String get confidenceLevel {
    if (strength >= 0.8) return 'Very High';
    if (strength >= 0.6) return 'High';
    if (strength >= 0.4) return 'Medium';
    if (strength >= 0.2) return 'Low';
    return 'Very Low';
  }

  Map<String, dynamic> toJson() {
    return {
      'isBullish': isBullish,
      'isBearish': isBearish,
      'strength': strength,
      'source': source,
      'type': type,
      'confidenceLevel': confidenceLevel,
    };
  }
}

/// 🚀 Signal 감지 결과 엔티티 V4.1
class Signal {
  final String market;
  final String name;
  final double currentPrice;
  final double changePercent;
  final double volume;
  final double tradeAmount;
  final DateTime detectedAt;
  final PatternType patternType;
  final Map<String, dynamic> patternDetails;

  const Signal({
    required this.market,
    required this.name,
    required this.currentPrice,
    required this.changePercent,
    required this.volume,
    required this.tradeAmount,
    required this.detectedAt,
    required this.patternType,
    required this.patternDetails,
  });

  /// 거래 총액 계산
  double get total => currentPrice * volume;

  /// 코인 티커만 추출 (KRW- 제거)
  String get ticker => market.replaceFirst('KRW-', '');

  /// 🆕 V4.1 신뢰도 (동적 조정된 최종 신뢰도)
  double? get confidence {
    final finalConf = patternDetails['finalConfidence'] as double?;
    final originalConf = patternDetails['confidence'] as double?;
    return finalConf ?? originalConf;
  }

  /// 🆕 V4.1 온라인 지표 정보 조회
  OnlineIndicatorInfo? get onlineIndicators {
    final rsi = patternDetails['rsi'] as double?;
    final macd = patternDetails['macd'] as double?;
    final macdSignal = patternDetails['macdSignal'] as double?;
    final macdHistogram = patternDetails['macdHistogram'] as double?;
    
    if (rsi == null && macd == null) return null;
    
    return OnlineIndicatorInfo(
      rsi: rsi,
      macd: macd,
      macdSignal: macdSignal,
      macdHistogram: macdHistogram,
      isStale: false, // Signal 생성시점에는 최신
      lastUpdate: detectedAt,
    );
  }

  /// 🆕 V4.1 다이버전스 정보 조회
  DivergenceInfo? get divergence {
    final divData = patternDetails['divergence'] as Map<String, dynamic>?;
    if (divData == null) return null;
    
    return DivergenceInfo(
      isBullish: divData['isBullish'] as bool? ?? false,
      isBearish: divData['isBearish'] as bool? ?? false,
      strength: (divData['strength'] as num?)?.toDouble() ?? 0.0,
      source: divData['source'] as String? ?? 'unknown',
    );
  }

  /// 🆕 온라인 지표 기반 신호인지 체크
  bool get hasOnlineMetrics {
    return onlineIndicators?.hasValidData ?? false;
  }

  /// 🆕 V4.1 버전 정보
  String? get version => patternDetails['version'] as String?;

  /// 패턴별 특화 정보 getter들
  
  /// Surge 전용: 기준가 (1분 전 가격)
  double? get basePrice => patternDetails['basePrice'] as double?;
  
  /// FlashFire 전용: 급증 배율
  double? get surgeMultiplier => patternDetails['surgeMultiplier'] as double?;
  
  /// StackUp 전용: 연속 증가 횟수
  int? get consecutiveCount => patternDetails['consecutiveCount'] as int?;
  
  /// StealthIn 전용: 지속 시간 (초)
  int? get sustainedSeconds => patternDetails['sustainedSeconds'] as int?;
  
  /// BlackHole 전용: 가격 변동률
  double? get priceStability => patternDetails['priceStability'] as double?;
  
  /// ReboundShot 전용: 반등 강도
  double? get reboundStrength => patternDetails['reboundStrength'] as double?;

  /// 🆕 V4.1 고급 지표들
  double? get liquidityVortex => patternDetails['liquidityVortex'] as double?;
  double? get flashPulse => patternDetails['flashPulse'] as double?;
  double? get microBurstRadar => patternDetails['microBurstRadar'] as double?;
  double? get machineRush => patternDetails['machineRush'] as double?;
  double? get jumpScore => patternDetails['jumpScore'] as double?;
  double? get zScore => patternDetails['zScore'] as double?;

  /// 🆕 신뢰도 레벨 (텍스트)
  String get confidenceLevel {
    final conf = confidence ?? 0.0;
    if (conf >= 0.9) return 'Excellent';
    if (conf >= 0.8) return 'Very High';
    if (conf >= 0.7) return 'High';
    if (conf >= 0.6) return 'Good';
    if (conf >= 0.5) return 'Medium';
    if (conf >= 0.3) return 'Low';
    return 'Very Low';
  }

  /// 🆕 신호 강도 (종합 점수)
  String get signalStrength {
    double score = 0.0;
    
    // 기본 점수 (변화율 기반)
    score += (changePercent.abs() / 10.0).clamp(0.0, 1.0);
    
    // 신뢰도 점수
    score += (confidence ?? 0.0);
    
    // 온라인 지표 보너스
    if (hasOnlineMetrics) score += 0.3;
    
    // 다이버전스 보너스
    final div = divergence;
    if (div != null && div.strength > 0.5) score += 0.2;
    
    score = score.clamp(0.0, 3.0) / 3.0; // 0-1 정규화
    
    if (score >= 0.8) return 'Very Strong';
    if (score >= 0.6) return 'Strong';
    if (score >= 0.4) return 'Moderate';
    if (score >= 0.2) return 'Weak';
    return 'Very Weak';
  }

  /// 🆕 상세 정보 (디버깅용)
  Map<String, dynamic> get debugInfo {
    return {
      'market': market,
      'pattern': patternType.name,
      'confidence': confidence,
      'hasOnlineMetrics': hasOnlineMetrics,
      'onlineIndicators': onlineIndicators?.toJson(),
      'divergence': divergence?.toJson(),
      'signalStrength': signalStrength,
      'version': version,
      'detectedAt': detectedAt.toIso8601String(),
    };
  }

  Signal copyWith({
    String? market,
    String? name,
    double? currentPrice,
    double? changePercent,
    double? volume,
    double? tradeAmount,
    DateTime? detectedAt,
    PatternType? patternType,
    Map<String, dynamic>? patternDetails,
  }) {
    return Signal(
      market: market ?? this.market,
      name: name ?? this.name,
      currentPrice: currentPrice ?? this.currentPrice,
      changePercent: changePercent ?? this.changePercent,
      volume: volume ?? this.volume,
      tradeAmount: tradeAmount ?? this.tradeAmount,
      detectedAt: detectedAt ?? this.detectedAt,
      patternType: patternType ?? this.patternType,
      patternDetails: patternDetails ?? this.patternDetails,
    );
  }

  @override
  String toString() {
    final confText = confidence != null 
        ? '${(confidence! * 100).toStringAsFixed(1)}%' 
        : 'N/A';
    final onlineText = hasOnlineMetrics ? '[Online]' : '';
    
    return 'Signal(${patternType.displayName} $onlineText: $market '
        '${changePercent.toStringAsFixed(2)}% @ $currentPrice, '
        'Conf: $confText, at: ${detectedAt.toString().substring(11, 19)})';
  }

  @override
  bool operator ==(Object other) {
    if (identical(this, other)) return true;
    return other is Signal &&
        other.market == market &&
        other.detectedAt == detectedAt &&
        other.patternType == patternType;
  }

  @override
  int get hashCode {
    return market.hashCode ^ detectedAt.hashCode ^ patternType.hashCode;
  }

  /// 🆕 V4.1 JSON 직렬화 (저장/로드용)
  Map<String, dynamic> toJson() {
    return {
      'market': market,
      'name': name,
      'currentPrice': currentPrice,
      'changePercent': changePercent,
      'volume': volume,
      'tradeAmount': tradeAmount,
      'detectedAt': detectedAt.toIso8601String(),
      'patternType': patternType.name,
      'patternDetails': patternDetails,
      'version': 'V4.1-Online',
    };
  }

  /// 🆕 V4.1 JSON 역직렬화
  factory Signal.fromJson(Map<String, dynamic> json) {
    return Signal(
      market: json['market'] as String,
      name: json['name'] as String,
      currentPrice: (json['currentPrice'] as num).toDouble(),
      changePercent: (json['changePercent'] as num).toDouble(),
      volume: (json['volume'] as num).toDouble(),
      tradeAmount: (json['tradeAmount'] as num).toDouble(),
      detectedAt: DateTime.parse(json['detectedAt'] as String),
      patternType: PatternType.values.firstWhere(
        (e) => e.name == json['patternType'],
        orElse: () => PatternType.surge,
      ),
      patternDetails: Map<String, dynamic>.from(json['patternDetails'] as Map),
    );
  }
}