// lib/shared/utils/amount_formatter.dart
import 'package:intl/intl.dart';

/// 💰 금액 포맷팅 유틸리티 클래스
/// 모든 타일에서 사용하는 금액/가격/거래량 포맷팅을 통합 관리
class AmountFormatter {
  // 포맷터 캐싱 (성능 최적화)
  static final _integerFormat = NumberFormat('#,###');
  static final _decimalFormat = NumberFormat('#,##0.##');
  static final _decimal3Format = NumberFormat('#,##0.###');
  static final _decimal6Format = NumberFormat('#,##0.######');
  static final _decimal1Format = NumberFormat('#,##0.#');
  
  // ==================== 거래량 포맷팅 ====================
  
  /// 📊 거래량 포맷팅 (VolumeTile, SectorTile에서 사용)
  /// 통합된 거래량 표시 규칙
  static String formatVolume(double totalVolume) {
    if (totalVolume < 0) return '0원';
    
    // 1만원 미만: 1원 ~ 9,999원 (콤마 포함)
    if (totalVolume < 10000) {
      return '${_integerFormat.format(totalVolume.toInt())}원';
    }
    // 1만원 ~ 9999만원: x,xxx만원 (콤마 포함)
    else if (totalVolume < 100000000) {
      final man = (totalVolume / 10000).toInt();
      return '${_integerFormat.format(man)}만원';
    }
    // 1억 ~ 9999억: x.xx억원 (소수점 2자리)
    else if (totalVolume < 1000000000000) {
      final eok = totalVolume / 100000000;
      return '${_decimalFormat.format(eok)}억원';
    }
    // 1조 ~ 9999조: x.xx조원 (소수점 2자리)
    else if (totalVolume < 10000000000000000) {
      final jo = totalVolume / 1000000000000;
      return '${_decimalFormat.format(jo)}조원';
    }
    // 1경 이상: x,xxx경원 (콤마 포함)
    else {
      final gyeong = (totalVolume / 10000000000000000).toInt();
      return '${_integerFormat.format(gyeong)}경원';
    }
  }
  
  // ==================== 가격 포맷팅 ====================
  
  /// 💵 조건부 가격 포맷팅 (TradeTile, SignalTile에서 사용)
  /// 가격 크기에 따라 소수점 자릿수를 동적 조절
  static String formatPrice(double price) {
    if (price <= 1.0) {
      return _decimal6Format.format(price); // 1 이하: 소수점 최대 6자리
    } else if (price < 10.0) {
      return _decimal3Format.format(price); // 1 초과 ~ 10 미만: 소수점 3자리
    } else if (price < 100.0) {
      return _decimalFormat.format(price); // 10 초과 ~ 100 미만: 소수점 2자리
    } else if (price < 1000.0) {
      return _decimal1Format.format(price); // 100 초과 ~ 1000 미만: 소수점 1자리
    } else {
      return _integerFormat.format(price); // 1000 이상: 정수
    }
  }
  
  /// 📈 거래량 개수 포맷팅 (TradeTile에서 사용)
  /// 코인 거래량(개수) 전용 포맷터
  static String formatTradeVolume(double volume) {
    if (volume < 1.0) {
      return _decimal6Format.format(volume); // 1개 미만: 소수점 최대 6자리
    } else {
      return _integerFormat.format(volume); // 1개 이상: 정수 표시
    }
  }
  
  // ==================== 간단 포맷팅 ====================
  
  /// 🔢 간단한 정수 포맷팅 (콤마만 추가)
  static String formatInteger(int number) {
    return _integerFormat.format(number);
  }
  
  /// 📉 소수점 2자리 포맷팅
  static String formatDecimal2(double number) {
    return _decimalFormat.format(number);
  }
  
  /// 📊 소수점 3자리 포맷팅
  static String formatDecimal3(double number) {
    return _decimal3Format.format(number);
  }
  
  // ==================== 특수 포맷팅 ====================
  
  /// 💯 퍼센트 포맷팅 (변화율 등)
  static String formatPercent(double percent, {int decimals = 2}) {
    final formatter = decimals == 1 ? _decimal1Format : _decimalFormat;
    return '${formatter.format(percent)}%';
  }
  
  /// 📏 크기에 따른 동적 포맷팅
  static String formatDynamic(double value) {
    if (value.abs() < 1) {
      return _decimal6Format.format(value);
    } else if (value.abs() < 100) {
      return _decimalFormat.format(value);
    } else {
      return _integerFormat.format(value);
    }
  }
  
  // ==================== 단위 변환 포맷팅 ====================
  
  /// 💰 만원 단위로 변환 (AmountDisplayWidget 호환)
  static String formatToManWon(double amount) {
    final manWon = amount / 10000;
    return '${_integerFormat.format(manWon)}만';
  }
  
  /// 📊 억원 단위로 변환
  static String formatToEokWon(double amount) {
    final eokWon = amount / 100000000;
    return '${_decimalFormat.format(eokWon)}억';
  }
  
  /// 📈 조원 단위로 변환
  static String formatToJoWon(double amount) {
    final joWon = amount / 1000000000000;
    return '${_decimalFormat.format(joWon)}조';
  }
  
  // ==================== 헬퍼 메서드 ====================
  
  /// 🎯 금액 크기 판별
  static String getAmountUnit(double amount) {
    if (amount < 10000) {
      return '원';
    } else if (amount < 100000000) {
      return '만원';
    } else if (amount < 1000000000000) {
      return '억원';
    } else if (amount < 10000000000000000) {
      return '조원';
    } else {
      return '경원';
    }
  }
  
  /// 📏 소수점 자릿수 결정
  static int getDecimalPlaces(double value) {
    if (value <= 1.0) return 6;
    if (value < 10.0) return 3;
    if (value < 100.0) return 2;
    if (value < 1000.0) return 1;
    return 0;
  }
  
  /// 🔄 포맷터 선택
  static NumberFormat getFormatter(double value) {
    final decimals = getDecimalPlaces(value);
    switch (decimals) {
      case 6: return _decimal6Format;
      case 3: return _decimal3Format;
      case 2: return _decimalFormat;
      case 1: return _decimal1Format;
      default: return _integerFormat;
    }
  }
}