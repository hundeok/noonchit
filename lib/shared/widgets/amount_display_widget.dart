// lib/shared/widgets/amount_display_widget.dart
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';
import '../../core/di/settings_provider.dart';
import '../../domain/entities/app_settings.dart';

/// 거래 금액 표시 위젯 (숫자 ↔ 아이콘)
class AmountDisplayWidget extends ConsumerWidget {
  final double totalAmount; // 총 거래 금액 (원 단위)
  final bool isBuy; // 매수/매도 구분 (색상용)
  final double fontSize;
  final FontWeight fontWeight;
  
  // 포맷터 캐싱
  static final _integerFormat = NumberFormat('#,###');
  
  const AmountDisplayWidget({
    Key? key,
    required this.totalAmount,
    required this.isBuy,
    this.fontSize = 16,
    this.fontWeight = FontWeight.bold,
  }) : super(key: key);

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final amountDisplayMode = ref.watch(appSettingsProvider).amountDisplayMode;
    
    return amountDisplayMode == AmountDisplayMode.icon
        ? _buildAmountIcon(context)
        : _buildAmountText(context);
  }

  /// 숫자로 금액 표시
  Widget _buildAmountText(BuildContext context) {
    return Text(
      '${_integerFormat.format(totalAmount / 10000)}만',
      style: TextStyle(
        fontWeight: fontWeight,
        color: isBuy ? Colors.green : Colors.red,
        fontSize: fontSize,
      ),
      overflow: TextOverflow.ellipsis,
      maxLines: 1,
    );
  }

  /// 아이콘으로 금액 표시 (1000만 ~ 100억원)
  Widget _buildAmountIcon(BuildContext context) {
    final amountInMan = (totalAmount / 10000).round(); // 만원 단위
    
    // 1000만원 미만이면 숫자로 표시
    if (amountInMan < 1000) {
      return _buildAmountText(context);
    }
    
    final assetPath = _getIconPath(amountInMan);
    
    return Image.asset(
      assetPath,
      width: 64,
      height: 40,
      fit: BoxFit.contain,
      errorBuilder: (context, error, stackTrace) {
        // 아이콘 로드 실패 시 숫자로 fallback
        return _buildAmountText(context);
      },
    );
  }

  /// 금액에 따른 아이콘 경로 결정
  String _getIconPath(int amountInMan) {
    if (amountInMan >= 1000 && amountInMan < 5000) {
      return _get1000SeriesPath(amountInMan);
    } else if (amountInMan >= 5000 && amountInMan < 100000) {
      return _get5000SeriesPath(amountInMan);
    } else if (amountInMan >= 100000 && amountInMan <= 1000000) {
      return _get10000SeriesPath(amountInMan);
    } else {
      // 100억 초과시 최대값으로
      return 'assets/icons/money/money_10000_10.png';
    }
  }

  /// 🔧 1000 시리즈 (1000만 ~ 4999만) - 세련된 계산식
  String _get1000SeriesPath(int amountInMan) {
    // 1000만원 기준으로 정규화하고 1000만원 단위로 레벨 결정
    final normalizedAmount = amountInMan - 1000; // 1000만원을 0으로 맞춤
    final level = (normalizedAmount / 1000).floor() + 1; // 1000만원 단위로 레벨 계산
    final clampedLevel = level.clamp(1, 4); // 1~4 범위로 제한
    
    return 'assets/icons/money/money_1000_$clampedLevel.png';
    
    // 수학적 매핑:
    // 1000~1999만 → (0~999)/1000 + 1 = 1 → money_1000_1.png
    // 2000~2999만 → (1000~1999)/1000 + 1 = 2 → money_1000_2.png
    // 3000~3999만 → (2000~2999)/1000 + 1 = 3 → money_1000_3.png
    // 4000~4999만 → (3000~3999)/1000 + 1 = 4 → money_1000_4.png
  }

  /// 🔧 5000 시리즈 (5000만 ~ 9억9999만) - 정확한 구간 매핑
  String _get5000SeriesPath(int amountInMan) {
    // 5000만원 기준으로 정규화
    final normalizedAmount = amountInMan - 5000; // 5000만원을 0으로 맞춤
    
    // 5000만원 단위와 1000만원 나머지 계산
    final fiveThousandUnits = (normalizedAmount / 5000).floor(); // 5천만 추가 개수
    final remainder = normalizedAmount % 5000; // 1000만원 단위 나머지
    
    // 총 5천만 개수 (기본 1개 + 추가 개수)
    final totalFiveThousands = fiveThousandUnits + 1;
    
    if (remainder == 0) {
      // 정확히 5천만 배수: 5000만, 1억, 1억5천만, 2억...
      final clampedCount = totalFiveThousands.clamp(1, 19);
      return 'assets/icons/money/money_5000_$clampedCount.png';
    } else {
      // 5천만 + 천만 조합
      final thousandLevel = _getThousandLevel(remainder); // 🔧 정확한 구간 매핑
      
      if (totalFiveThousands <= 3) {
        // 조합 지원: 1~3장까지
        return 'assets/icons/money/money_5000_${totalFiveThousands}_1000_$thousandLevel.png';
      } else {
        // 4장 이상은 조합 미지원, 스마트 반올림
        final roundedFiveThousands = remainder >= 2500 
          ? (totalFiveThousands + 1).clamp(4, 19)  // 2500만 이상이면 올림
          : totalFiveThousands.clamp(4, 19);       // 미만이면 버림
        return 'assets/icons/money/money_5000_$roundedFiveThousands.png';
      }
    }
    
    // 정확한 매핑 예시:
    // 5000만 → money_5000_1.png
    // 6200만 → remainder=1200 → level=1 → money_5000_1_1000_1.png ✅
    // 7800만 → remainder=2800 → level=2 → money_5000_1_1000_2.png ✅
    // 8300만 → remainder=3300 → level=3 → money_5000_1_1000_3.png ✅
    // 8560만 → remainder=3560 → level=3 → money_5000_1_1000_3.png ✅
    // 9200만 → remainder=4200 → level=4 → money_5000_1_1000_4.png ✅
  }
  
  /// 🔧 천만원 나머지를 정확한 레벨로 매핑
  int _getThousandLevel(int remainder) {
    if (remainder >= 1000 && remainder < 2000) return 1; // 1000~1999만 → level 1
    if (remainder >= 2000 && remainder < 3000) return 2; // 2000~2999만 → level 2  
    if (remainder >= 3000 && remainder < 4000) return 3; // 3000~3999만 → level 3
    return 4; // 4000만 이상 → level 4
  }

  /// 🔧 10000 시리즈 (10억 ~ 100억원) - 세련된 계산식
  String _get10000SeriesPath(int amountInMan) {
    // 10억원(100000만) 기준으로 정규화
    final normalizedAmount = amountInMan - 100000; // 10억원을 0으로 맞춤
    
    // 10억원 단위와 나머지 계산
    final tenBillionUnits = (normalizedAmount / 100000).floor(); // 10억 추가 개수
    final remainder = normalizedAmount % 100000; // 10억 미만 나머지
    
    // 총 10억 개수 (기본 1개 + 추가 개수)
    final totalTenBillions = tenBillionUnits + 1;
    
    if (remainder == 0) {
      // 정확히 10억 배수: 10억, 20억, 30억...
      final clampedCount = totalTenBillions.clamp(1, 10);
      return 'assets/icons/money/money_10000_$clampedCount.png';
    } else {
      // 10억 + 나머지 조합
      if (totalTenBillions <= 2) {
        // 조합 지원: 1~2장까지
        // 나머지를 5천만 단위로 변환 (정밀한 매핑)
        final fiveThousandCount = _calculateFiveThousandLevel(remainder);
        final clampedFiveThousand = fiveThousandCount.clamp(1, 19);
        return 'assets/icons/money/money_10000_${totalTenBillions}_5000_$clampedFiveThousand.png';
      } else {
        // 3장 이상은 조합 미지원, 스마트 반올림
        final roundedTenBillions = remainder >= 50000 
          ? (totalTenBillions + 1).clamp(3, 10)  // 5억 이상이면 올림
          : totalTenBillions.clamp(3, 10);       // 미만이면 버림
        return 'assets/icons/money/money_10000_$roundedTenBillions.png';
      }
    }
    
    // 수학적 매핑 예시:
    // 10억 → normalized=0, total=1 → money_10000_1.png
    // 15억 → normalized=50000, total=1, fiveThousand=10 → money_10000_1_5000_10.png
    // 23억 → normalized=130000, total=2, remainder=30000, fiveThousand=6 → money_10000_2_5000_6.png
    // 35억 → normalized=250000, total=3, remainder>=50000 → money_10000_4.png (올림)
  }
  
  /// 나머지 금액을 5천만 레벨로 정밀 변환하는 헬퍼 함수
  int _calculateFiveThousandLevel(int remainder) {
    // 5천만원 단위로 나누고, 2500만원 기준으로 반올림
    final exactLevel = remainder / 5000; // 정확한 5천만 레벨
    return exactLevel.round(); // 반올림으로 가장 가까운 정수
    
    // 예시:
    // 2500만원 → 2500/5000 = 0.5 → round() = 1 → 5천만 1장
    // 7500만원 → 7500/5000 = 1.5 → round() = 2 → 5천만 2장
    // 12000만원 → 12000/5000 = 2.4 → round() = 2 → 5천만 2장
    // 13000만원 → 13000/5000 = 2.6 → round() = 3 → 5천만 3장
  }
}