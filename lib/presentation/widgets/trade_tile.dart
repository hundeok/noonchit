// lib/presentation/widgets/trade_tile.dart

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';
import '../../domain/entities/trade.dart';
import '../../core/di/app_providers.dart';
import '../../shared/widgets/amount_display_widget.dart';
import '../../shared/utils/tile_common.dart';
import '../../shared/utils/amount_formatter.dart';

class TradeTile extends ConsumerWidget {
  // 🕒 시간 포맷터만 유지 (고유 기능)
  static final _timeFormat = DateFormat('HH:mm:ss');
  
  final Trade trade;
  final DisplayMode displayMode;  // ✅ 상위에서 받아옴 (Volume/Surge 패턴)

  const TradeTile({
    Key? key,
    required this.trade,
    required this.displayMode,
  }) : super(key: key);

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final theme = Theme.of(context);
    final onSurface = theme.colorScheme.onSurface;
    final onSurface70 = onSurface.withValues(alpha: 0.7);
    
    // ✅ 최적화된 코인명 표시 (TileCommon 사용)
    final displayName = TileCommon.getDisplayNameOptimized(
      ref,
      trade.market,
      displayMode, // 상위에서 받은 DisplayMode 사용
    );
    
    // ✅ 표준 카드 위젯 사용 (Volume/Surge와 동일한 패턴)
    return TileCommon.buildStandardCard(
      child: TileCommon.buildFlexRow(
        children: [
          // 🕒 시간 부분: flex 12
          FlexChild.expanded(
            Text(
              _timeFormat.format(trade.timestamp),
              style: TextStyle(color: onSurface, fontSize: 11),
            ),
            flex: 12,
          ),
          
          // 🪙 코인명 부분: flex 18 - 최적화된 버전 사용
          FlexChild.expanded(
            Text(
              displayName, // ✅ 최적화된 방식
              style: TextStyle(
                fontWeight: FontWeight.bold,
                color: theme.colorScheme.primary,
                fontSize: 16,
              ),
              overflow: TextOverflow.ellipsis,
              maxLines: 1,
            ),
            flex: 18,
          ),
          
          // 💵 가격/거래량 부분: flex 20
          FlexChild.expanded(
            Column(
              crossAxisAlignment: CrossAxisAlignment.end,
              children: [
                Text(
                  '${AmountFormatter.formatPrice(trade.price)}원', // ✅ 공통 포맷터
                  style: TextStyle(color: onSurface, fontSize: 14),
                  overflow: TextOverflow.ellipsis,
                  maxLines: 1,
                ),
                const SizedBox(height: 2),
                Text(
                  '${AmountFormatter.formatTradeVolume(trade.volume)}개', // ✅ 공통 포맷터
                  style: TextStyle(color: onSurface70, fontSize: 12),
                  overflow: TextOverflow.ellipsis,
                  maxLines: 1,
                ),
              ],
            ),
            flex: 20,
          ),
          
          // 💰 총액 부분: flex 20 - AmountDisplayWidget 사용
          FlexChild.expanded(
            Align(
              alignment: Alignment.centerRight,
              child: AmountDisplayWidget(
                totalAmount: trade.total,
                isBuy: trade.isBuy,
                fontSize: 16,
                fontWeight: FontWeight.bold,
              ),
            ),
            flex: 20,
          ),
          
          // 📈 방향 아이콘: 고정 크기
          FlexChild.fixed(
            Icon(
              trade.isBuy ? Icons.arrow_upward : Icons.arrow_downward,
              color: trade.isBuy ? Colors.green : Colors.red,
              size: 16,
            ),
          ),
        ],
      ),
    );
  }
}