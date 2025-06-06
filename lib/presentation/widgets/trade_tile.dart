import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';
import '../../domain/entities/trade.dart';
import '../../core/di/app_providers.dart'; // DisplayMode import
import '../../shared/widgets/amount_display_widget.dart'; // 💰 AmountDisplayWidget import

class TradeTile extends ConsumerWidget { // ✅ StatelessWidget → ConsumerWidget 변경
  // 포맷터를 static으로 캐싱해 매번 새로 생성하지 않도록 최적화
  static final _timeFormat = DateFormat('HH:mm:ss');
  static final _integerFormat = NumberFormat('#,###'); // 정수용
  static final _decimalFormat = NumberFormat('#,##0.######'); // 소수점 최대 6자리
  static final _decimal3Format = NumberFormat('#,##0.###'); // 소수점 3자리
  static final _decimal2Format = NumberFormat('#,##0.##'); // 소수점 2자리
  static final _decimal1Format = NumberFormat('#,##0.#'); // 소수점 1자리
  
  final Trade trade;
  
  const TradeTile({Key? key, required this.trade}) : super(key: key);
  
  // 🎯 조건부 가격 포맷팅
  String _formatPrice(double price) {
    if (price <= 1.0) {
      return _decimalFormat.format(price); // 1 이하: 소수점 최대 6자리
    } else if (price < 10.0) {
      return _decimal3Format.format(price); // 1 초과 ~ 10 미만: 소수점 3자리
    } else if (price < 100.0) {
      return _decimal2Format.format(price); // 10 초과 ~ 100 미만: 소수점 2자리
    } else if (price < 1000.0) {
      return _decimal1Format.format(price); // 100 초과 ~ 1000 미만: 소수점 1자리
    } else {
      return _integerFormat.format(price); // 1000 이상: 정수
    }
  }
  
  // 🎯 조건부 거래량 포맷팅
  String _formatVolume(double volume) {
    if (volume < 1.0) {
      return _decimalFormat.format(volume); // 1개 미만: 소수점 최대 6자리
    } else {
      return _integerFormat.format(volume); // 1개 이상: 정수 표시
    }
  }

  // 🆕 코인명 표시 로직
  String _getDisplayName(WidgetRef ref) {
    final displayMode = ref.watch(appSettingsProvider).displayMode;
    final marketInfoAsync = ref.watch(marketInfoProvider);
    
    // 기본 티커 (fallback)
    final ticker = trade.market.replaceFirst('KRW-', '');
    
    // marketInfo가 로딩 중이거나 에러인 경우 티커 반환
    return marketInfoAsync.when(
      data: (marketInfoMap) {
        final marketInfo = marketInfoMap[trade.market];
        
        switch (displayMode) {
          case DisplayMode.ticker:
            return ticker;
          case DisplayMode.korean:
            return marketInfo?.koreanName ?? ticker;
          case DisplayMode.english:
            return marketInfo?.englishName ?? ticker;
        }
      },
      loading: () => ticker, // 로딩 중에는 티커 표시
      error: (_, __) => ticker, // 에러 시에도 티커 표시
    );
  }
  
  @override
  Widget build(BuildContext context, WidgetRef ref) { // ✅ WidgetRef 파라미터 추가
    final theme = Theme.of(context);
    final onSurface = theme.colorScheme.onSurface;
    final onSurface70 = onSurface.withValues(alpha: 0.7); // ✅ withAlpha → withValues
    
    return Card(
      elevation: 2,
      margin: const EdgeInsets.symmetric(vertical: 4),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 16),
        child: Row(
          children: [
            // 🎯 시간 부분: flex 12 (1.2 비율, 17.1%)
            Expanded(
              flex: 12,
              child: Text(
                _timeFormat.format(trade.timestamp),
                style: TextStyle(color: onSurface, fontSize: 11),
                // 시간은 고정 형식이므로 overflow 방지 불필요
              ),
            ),
            
            // 🔧 코인명 부분: flex 18 (1.8 비율, 25.7%) - 동적 표시 적용
            Expanded(
              flex: 18,
              child: Text(
                _getDisplayName(ref), // ✅ 동적 코인명 표시
                style: TextStyle(
                  fontWeight: FontWeight.bold,
                  color: theme.colorScheme.primary,
                  fontSize: 16,
                ),
                overflow: TextOverflow.ellipsis, // 긴 코인명 방지
                maxLines: 1,
              ),
            ),
            
            // 🔧 가격/거래량 부분: flex 20 (2.0 비율, 28.6%)
            Expanded(
              flex: 20,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.end,
                children: [
                  Text(
                    '${_formatPrice(trade.price)}원', // 🎯 조건부 가격 포맷
                    style: TextStyle(color: onSurface, fontSize: 14),
                    overflow: TextOverflow.ellipsis, // 큰 가격 방지
                    maxLines: 1,
                  ),
                  const SizedBox(height: 2),
                  Text(
                    '${_formatVolume(trade.volume)} 개', // 🎯 조건부 거래량 포맷
                    style: TextStyle(color: onSurface70, fontSize: 12),
                    overflow: TextOverflow.ellipsis, // 큰 거래량 방지
                    maxLines: 1,
                  ),
                ],
              ),
            ),
            
            // 💰 총액 부분: flex 20 (2.0 비율, 28.6%) - AmountDisplayWidget 사용!
            Expanded(
              flex: 20,
              child: Align(
                alignment: Alignment.centerRight,
                child: AmountDisplayWidget(
                  totalAmount: trade.total,
                  isBuy: trade.isBuy,
                  fontSize: 16,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ),
            
            // 아이콘은 고정 크기이므로 변경 없음
            Icon(
              trade.isBuy ? Icons.arrow_upward : Icons.arrow_downward,
              color: trade.isBuy ? Colors.green : Colors.red,
              size: 16,
            ),
          ],
        ),
      ),
    );
  }
}