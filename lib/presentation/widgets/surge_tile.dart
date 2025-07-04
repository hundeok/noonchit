import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../core/di/app_providers.dart';
import '../../shared/widgets/coin_logo_provider.dart';
import '../../shared/utils/tile_common.dart';
import '../../shared/utils/blink_animation_mixin.dart';
import '../../shared/utils/amount_formatter.dart';
import '../controllers/surge_controller.dart';

class SurgeTile extends ConsumerStatefulWidget {
  final String market;
  final double changePercent;
  final double basePrice;
  final double currentPrice;
  final int rank;
  final bool isHot;        // ✅ Controller에서 계산된 값
  final bool shouldBlink;  // ✅ Controller에서 계산된 값
  
  const SurgeTile({
    Key? key, 
    required this.market,
    required this.changePercent,
    required this.basePrice,
    required this.currentPrice,
    required this.rank,
    required this.isHot,
    required this.shouldBlink,
  }) : super(key: key);

  @override
  ConsumerState<SurgeTile> createState() => _SurgeTileState();
}

class _SurgeTileState extends ConsumerState<SurgeTile> 
    with SingleTickerProviderStateMixin {

  late AnimationController _blinkController;
  late Animation<double> _blinkAnimation;
  bool _isBlinking = false;

  @override
  void initState() {
    super.initState();
    // ✅ 애니메이션 초기화
    _blinkController = AnimationController(
      duration: const Duration(milliseconds: 600),
      vsync: this,
    );
    _blinkAnimation = Tween<double>(begin: 1.0, end: 0.3).animate(
      CurvedAnimation(parent: _blinkController, curve: Curves.easeInOut),
    );
  }

  @override
  void didUpdateWidget(SurgeTile oldWidget) {
    super.didUpdateWidget(oldWidget);
    
    // ✅ shouldBlink props 변화 감지해서 애니메이션 시작
    if (widget.shouldBlink && !oldWidget.shouldBlink && !_isBlinking) {
      _startBlink();
    }
  }

  @override
  void dispose() {
    _blinkController.dispose();
    super.dispose();
  }

  /// ✅ 블링크 시작 (설정 체크 + Controller 상태 초기화)
  void _startBlink() {
    final blinkEnabled = ref.read(appSettingsProvider).blinkEnabled;
    if (!mounted || !blinkEnabled) return;
    
    _isBlinking = true;
    _blinkController.forward().then((_) {
      if (mounted) {
        _blinkController.reverse().then((_) {
          if (mounted) {
            setState(() {
              _isBlinking = false;
            });
            
            // ✅ 애니메이션 완료 후 Controller에 상태 초기화 요청
            ref.read(surgeControllerProvider.notifier).clearBlinkState(widget.market);
          }
        });
      }
    });
  }

  // ✅ 변동률 포맷팅
  String _formatChangePercent(double changePercent) {
    final sign = changePercent >= 0 ? '+' : '';
    return '$sign${changePercent.toStringAsFixed(2)}%';
  }

  // ✅ 변동률 텍스트 색상
  Color _getChangeColor() {
    if (widget.changePercent > 0) {
      return Colors.green; 
    } else if (widget.changePercent < 0) {
      return Colors.red; 
    } else {
      return Colors.grey; 
    }
  }

  // ✅ 블링크 색상 (상승=초록, 하락=빨강)
  Color _getBlinkColor() {
    if (widget.changePercent > 0) {
      return Colors.green; // 🟢 상승 = 초록 블링크
    } else {
      return Colors.red;   // 🔴 하락 = 빨강 블링크
    }
  }
  
  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final onSurface = theme.colorScheme.onSurface;
    final changeColor = _getChangeColor();
    
    // ✅ 표준 카드 위젯 생성
    Widget cardWidget = TileCommon.buildStandardCard(
      child: TileCommon.buildFlexRow(
        children: [
          // 🏆 순위 부분
          FlexChild.fixed(
            TileCommon.buildRankWidget(context, widget.rank),
          ),
          
          const FlexChild.fixed(SizedBox(width: 12)),
          
          // 🎨 코인 로고 부분
          FlexChild.fixed(
            CoinLogoProvider.buildCoinLogo(
              ticker: widget.market.replaceFirst('KRW-', ''),
              radius: 16,
            ),
          ),
          
          const FlexChild.fixed(SizedBox(width: 12)),
          
          // 📱 코인명 부분
          FlexChild.expanded(
            Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Flexible(
                      child: Text(
                        TileCommon.getDisplayName(ref, widget.market),
                        style: TextStyle(
                          fontWeight: FontWeight.bold,
                          color: theme.colorScheme.primary,
                          fontSize: 16,
                        ),
                        overflow: TextOverflow.ellipsis,
                        maxLines: 1,
                      ),
                    ),
                    const SizedBox(width: 4),
                    // 🔥 HOT 아이콘
                    Consumer(
                      builder: (context, ref, child) {
                        final hotEnabled = ref.watch(appSettingsProvider).hotEnabled;
                        if (hotEnabled && widget.isHot) {
                          return TileCommon.buildHotIcon(true) ?? const SizedBox.shrink();
                        }
                        return const SizedBox.shrink();
                      },
                    ),
                  ],
                ),
                const SizedBox(height: 2),
                Text(
                  widget.market.replaceFirst('KRW-', ''),
                  style: TextStyle(
                    color: onSurface.withValues(alpha: 0.7),
                    fontSize: 12,
                  ),
                ),
              ],
            ),
            flex: 25,
          ),
          
          // 🚀 변동률 부분
          FlexChild.expanded(
            Column(
              crossAxisAlignment: CrossAxisAlignment.end,
              children: [
                Text(
                  _formatChangePercent(widget.changePercent),
                  style: TextStyle(
                    color: changeColor,
                    fontSize: 15,
                    fontWeight: FontWeight.w600,
                  ),
                  overflow: TextOverflow.ellipsis,
                  maxLines: 1,
                ),
                const SizedBox(height: 2),
                Text(
                  '${AmountFormatter.formatPrice(widget.currentPrice)}원',
                  style: TextStyle(
                    color: onSurface.withValues(alpha: 0.7),
                    fontSize: 11,
                    fontWeight: FontWeight.w500,
                  ),
                  overflow: TextOverflow.ellipsis,
                  maxLines: 1,
                ),
              ],
            ),
            flex: 30,
          ),
        ],
      ),
    );

    // ✅ 블링크 애니메이션 적용
    final blinkEnabled = ref.watch(appSettingsProvider).blinkEnabled;
    
    if (blinkEnabled && (_isBlinking || widget.shouldBlink)) {
      return BlinkAnimationHelper.wrapWithBlinkEffect(
        child: cardWidget,
        shouldBlink: _isBlinking,
        blinkAnimation: _blinkAnimation,
        blinkColor: _getBlinkColor(), // ✅ 상승=초록, 하락=빨강
      );
    }
    
    return cardWidget;
  }
}