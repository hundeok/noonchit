// lib/presentation/widgets/signal_tile.dart

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';
import '../../core/di/app_providers.dart';
import '../../domain/entities/signal.dart';
import '../../shared/widgets/amount_display_widget.dart';
import '../../shared/widgets/coin_logo_provider.dart';
import '../../shared/utils/tile_common.dart';
import '../../shared/utils/blink_animation_mixin.dart';
import '../../shared/utils/amount_formatter.dart';

// 🎯 중복 반짝임 방지를 위한 전역 Set
final Set<String> _blinkedSignals = {};

/// 🚀 SignalTile V4.1 - Clean UI (온라인 지표 연동)
class SignalTile extends ConsumerStatefulWidget {
  final Signal signal;
  final bool showOnlineMetrics; // 🆕 V4.1 온라인 지표 표시 옵션

  const SignalTile({
    super.key, 
    required this.signal,
    this.showOnlineMetrics = true, // 기본값: 표시
  });

  @override
  ConsumerState<SignalTile> createState() => _SignalTileState();
}

class _SignalTileState extends ConsumerState<SignalTile>
    with SingleTickerProviderStateMixin {
  
  // 🕒 시간 포맷터만 유지 (고유 기능)
  static final _timeFormat = DateFormat('HH:mm:ss');

  late AnimationController _blinkController;
  late Animation<double> _blinkAnimation;
  bool _shouldBlink = false;

  @override
  void initState() {
    super.initState();
    // ✨ 반짝임 애니메이션 초기화 (기존 방식)
    _blinkController = AnimationController(
      duration: const Duration(milliseconds: 800), // Signal은 조금 더 길게
      vsync: this,
    );
    _blinkAnimation = Tween<double>(begin: 1.0, end: 0.2).animate(
      CurvedAnimation(parent: _blinkController, curve: Curves.easeInOut),
    );

    _checkNewSignal();
  }

  /// 🎯 새로운 시그널 감지 및 반짝임 처리 (헬퍼 클래스 사용)
  void _checkNewSignal() {
    final signalKey = '${widget.signal.market}_${widget.signal.detectedAt.millisecondsSinceEpoch}';
    
    if (BlinkAnimationHelper.checkNewSignal(
      blinkedSignalsSet: _blinkedSignals,
      detectedAt: widget.signal.detectedAt,
      signalKey: signalKey,
      maxAgeSeconds: 10,
    )) {
      _startBlink();
    }
  }

  /// 반짝임 시작 (설정 연동 추가)
  void _startBlink() {
    final blinkEnabled = ref.read(appSettingsProvider).blinkEnabled;
    if (!mounted || !blinkEnabled) return; // 🎯 설정 체크 추가!
    
    _shouldBlink = true;
    _blinkController.forward().then((_) {
      _blinkController.reverse().then((_) {
        if (mounted) {
          setState(() {
            _shouldBlink = false;
          });
        }
      });
    });
  }

  @override
  void dispose() {
    _blinkController.dispose();
    super.dispose();
  }

  /// 🆕 V4.1 신뢰도 칩
  Widget? _buildConfidenceChip() {
    final confidence = widget.signal.confidence;
    if (confidence == null) return null;

    Color color;
    if (confidence >= 0.8) {
      color = Colors.green;
    } else if (confidence >= 0.6) {
      color = Colors.amber;
    } else {
      color = Colors.orange;
    }

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 2),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(4),
        color: color.withValues(alpha: 0.15),
        border: Border.all(color: color.withValues(alpha: 0.4), width: 0.5),
      ),
      child: Text(
        '${(confidence * 100).toStringAsFixed(0)}%',
        style: TextStyle(
          fontSize: 9,
          color: color,
          fontWeight: FontWeight.bold,
        ),
      ),
    );
  }

  /// 🆕 V4.1 온라인 지표 칩들 생성
  List<Widget> _buildOnlineIndicatorChips() {
    if (!widget.showOnlineMetrics || !widget.signal.hasOnlineMetrics) {
      return [];
    }

    final indicators = widget.signal.onlineIndicators!;
    final chips = <Widget>[];

    // RSI 칩
    if (indicators.rsi != null) {
      Color rsiColor;
      String rsiText;
      
      if (indicators.rsi! >= 70) {
        rsiColor = Colors.red;
        rsiText = 'RSI${indicators.rsi!.toStringAsFixed(0)}';
      } else if (indicators.rsi! <= 30) {
        rsiColor = Colors.blue;
        rsiText = 'RSI${indicators.rsi!.toStringAsFixed(0)}';
      } else {
        rsiColor = Colors.grey[600]!;
        rsiText = 'RSI${indicators.rsi!.toStringAsFixed(0)}';
      }

      chips.add(_buildIndicatorChip(rsiText, rsiColor));
    }

    // MACD 칩
    if (indicators.macd != null && indicators.macdSignal != null) {
      final isBullish = indicators.macd! > indicators.macdSignal!;
      final macdColor = isBullish ? Colors.green : Colors.red;
      final macdText = isBullish ? 'M+' : 'M-';

      chips.add(_buildIndicatorChip(macdText, macdColor));
    }

    return chips;
  }

  /// 🆕 V4.1 지표 칩 위젯
  Widget _buildIndicatorChip(String text, Color color) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 2),
      margin: const EdgeInsets.only(right: 4),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(4),
        color: color.withValues(alpha: 0.15),
        border: Border.all(color: color.withValues(alpha: 0.4), width: 0.5),
      ),
      child: Text(
        text,
        style: TextStyle(
          fontSize: 9,
          color: color,
          fontWeight: FontWeight.bold,
        ),
      ),
    );
  }

  /// 🆕 V4.1 다이버전스 인디케이터
  Widget? _buildDivergenceIndicator() {
    final divergence = widget.signal.divergence;
    if (divergence == null || (!divergence.isBullish && !divergence.isBearish)) {
      return null;
    }

    Color color;
    IconData icon;
    
    if (divergence.isBullish) {
      color = Colors.green;
      icon = Icons.trending_up;
    } else {
      color = Colors.red;
      icon = Icons.trending_down;
    }

    return Container(
      padding: const EdgeInsets.all(3),
      margin: const EdgeInsets.only(right: 4),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(4),
        color: color.withValues(alpha: 0.15),
        border: Border.all(color: color.withValues(alpha: 0.4), width: 0.5),
      ),
      child: Icon(
        icon,
        size: 10,
        color: color,
      ),
    );
  }

  /// 🆕 V4.1 모든 배지들을 오버플로우 방지하며 배치
  Widget _buildBadgeRow() {
    final badges = <Widget>[];
    
    // 신뢰도 칩 추가
    final confidenceChip = _buildConfidenceChip();
    if (confidenceChip != null) {
      badges.add(confidenceChip);
    }
    
    // 온라인 지표 칩들 추가
    badges.addAll(_buildOnlineIndicatorChips());
    
    // 다이버전스 인디케이터 추가
    final divergenceIndicator = _buildDivergenceIndicator();
    if (divergenceIndicator != null) {
      badges.add(divergenceIndicator);
    }

    if (badges.isEmpty) {
      return const SizedBox.shrink();
    }

    return SingleChildScrollView(
      scrollDirection: Axis.horizontal,
      child: Row(
        children: badges,
      ),
    );
  }

  /// 🆕 V4.1 패턴 색상 (온라인 지표 연동시 더 생동감있게)
  Color _getEnhancedPatternColor() {
    Color baseColor;
    
    switch (widget.signal.patternType) {
      case PatternType.surge:
        baseColor = Colors.red;
        break;
      case PatternType.flashFire:
        baseColor = Colors.orange;
        break;
      case PatternType.stackUp:
        baseColor = Colors.amber;
        break;
      case PatternType.stealthIn:
        baseColor = Colors.green;
        break;
      case PatternType.blackHole:
        baseColor = Colors.purple;
        break;
      case PatternType.reboundShot:
        baseColor = Colors.blue;
        break;
    }

    // 🆕 온라인 지표가 있으면 더 선명하게
    if (widget.signal.hasOnlineMetrics) {
      return baseColor;
    } else {
      return baseColor.withValues(alpha: 0.7);
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final onSurface = theme.colorScheme.onSurface;

    // 🎯 표준 카드 위젯 생성 (V4.1 Clean 버전)
    Widget cardWidget = TileCommon.buildStandardCard(
      child: TileCommon.buildFlexRow(
        children: [
          // 🕒 시간 부분: flex 13
          FlexChild.expanded(
            Text(
              _timeFormat.format(widget.signal.detectedAt),
              style: TextStyle(color: onSurface, fontSize: 11),
            ),
            flex: 13,
          ),

          const FlexChild.fixed(SizedBox(width: 8)),

          // 🎨 코인 로고 부분: 고정 크기 (V4.1 패턴 색상 테두리 추가)
          FlexChild.fixed(
            Container(
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                border: Border.all(
                  color: _getEnhancedPatternColor(),
                  width: 1.5,
                ),
              ),
              child: CoinLogoProvider.buildCoinLogo(
                ticker: widget.signal.market.replaceFirst('KRW-', ''),
                radius: 14,
              ),
            ),
          ),

          const FlexChild.fixed(SizedBox(width: 8)),

          // 🪙 코인명 + 배지들: flex 24 (🆕 Clean 버전)
          FlexChild.expanded(
            Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // 첫 번째 줄: 코인명 + NEW 뱃지
                Row(
                  children: [
                    Flexible(
                      child: Text(
                        TileCommon.getDisplayName(ref, widget.signal.market),
                        style: TextStyle(
                          fontWeight: FontWeight.bold,
                          color: theme.colorScheme.primary,
                          fontSize: 15,
                        ),
                        overflow: TextOverflow.ellipsis,
                        maxLines: 1,
                      ),
                    ),
                    const SizedBox(width: 4),
                    // NEW 뱃지 (필요한 경우)
                    if (TileCommon.buildNewBadge(widget.signal.detectedAt) case final badge?) 
                      badge,
                  ],
                ),
                
                const SizedBox(height: 3),
                
                // 🆕 두 번째 줄: 모든 배지들 (오버플로우 방지)
                _buildBadgeRow(),
              ],
            ),
            flex: 24,
          ),

          // 💵 가격 + 변화율: flex 18 (신뢰도 칩 제거됨)
          FlexChild.expanded(
            Column(
              crossAxisAlignment: CrossAxisAlignment.end,
              children: [
                Text(
                  '${AmountFormatter.formatPrice(widget.signal.currentPrice)}원',
                  style: TextStyle(color: onSurface, fontSize: 13),
                  overflow: TextOverflow.ellipsis,
                  maxLines: 1,
                ),
                const SizedBox(height: 2),
                Text(
                  TileCommon.formatChangePercent(widget.signal.changePercent),
                  style: TextStyle(
                    color: TileCommon.getChangeColor(widget.signal.changePercent),
                    fontSize: 12,
                    fontWeight: FontWeight.bold,
                  ),
                  overflow: TextOverflow.ellipsis,
                  maxLines: 1,
                ),
              ],
            ),
            flex: 18,
          ),

          const FlexChild.fixed(SizedBox(width: 8)),

          // 💰 거래대금: flex 18 (AmountDisplayWidget 사용)
          FlexChild.expanded(
            Align(
              alignment: Alignment.centerRight,
              child: AmountDisplayWidget(
                totalAmount: widget.signal.tradeAmount,
                isBuy: widget.signal.changePercent >= 0,
                fontSize: 14,
                fontWeight: FontWeight.w600,
              ),
            ),
            flex: 18,
          ),
        ],
      ),
    );

    // 🎯 반짝임 애니메이션 적용 (V4.1 패턴 색상 연동)
    final blinkEnabled = ref.watch(appSettingsProvider).blinkEnabled;
    
    return blinkEnabled 
        ? BlinkAnimationHelper.wrapWithBlinkEffect(
            child: cardWidget,
            shouldBlink: _shouldBlink,
            blinkAnimation: _blinkAnimation,
            blinkColor: _getEnhancedPatternColor(), // 🆕 V4.1 동적 색상
          )
        : cardWidget;
  }
}

/// 🆕 V4.1 확장: AmountDisplayWidget에 highlightColor 파라미터 추가용 확장
/// (실제로는 AmountDisplayWidget 클래스에 추가해야 함)
extension AmountDisplayWidgetV41 on AmountDisplayWidget {
  /// V4.1 강조 색상이 적용된 위젯 생성
  static Widget withHighlight({
    required double totalAmount,
    required bool isBuy,
    double fontSize = 14,
    FontWeight fontWeight = FontWeight.w600,
    Color? highlightColor,
  }) {
    return Container(
      padding: highlightColor != null 
          ? const EdgeInsets.symmetric(horizontal: 4, vertical: 1)
          : null,
      decoration: highlightColor != null
          ? BoxDecoration(
              borderRadius: BorderRadius.circular(3),
              color: highlightColor.withValues(alpha: 0.1),
              border: Border.all(color: highlightColor.withValues(alpha: 0.3), width: 0.5),
            )
          : null,
      child: AmountDisplayWidget(
        totalAmount: totalAmount,
        isBuy: isBuy,
        fontSize: fontSize,
        fontWeight: fontWeight,
      ),
    );
  }
}