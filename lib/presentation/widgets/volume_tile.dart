// lib/presentation/widgets/volume_tile.dart (한 줄로 수정됨)

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';
import '../../core/di/app_providers.dart'; // DisplayMode import
import '../../shared/widgets/coin_logo_provider.dart'; // 🆕 코인 로고 프로바이더 import (올바른 경로)

// 🎯 순위 추적을 위한 전역 Map (market별 이전 순위 저장)
final Map<String, int> _previousRanks = {};

class VolumeTile extends ConsumerStatefulWidget {
  final String market; // 🔄 Volume 엔티티 대신 단순 데이터
  final double totalVolume;
  final int rank; // 🎯 순위 (1위부터)
  final bool showHotIcon; // 🚀 급상승 표시 여부
  final bool enableBlinkAnimation; // 깜빡임 애니메이션 여부
  
  const VolumeTile({
    Key? key, 
    required this.market,
    required this.totalVolume,
    required this.rank,
    this.showHotIcon = false,
    this.enableBlinkAnimation = false,
  }) : super(key: key);

  @override
  ConsumerState<VolumeTile> createState() => _VolumeTileState();
}

class _VolumeTileState extends ConsumerState<VolumeTile> 
    with SingleTickerProviderStateMixin {
  late AnimationController _blinkController;
  late Animation<double> _blinkAnimation;
  bool _shouldBlink = false;

  @override
  void initState() {
    super.initState();
    _blinkController = AnimationController(
      duration: const Duration(milliseconds: 600),
      vsync: this,
    );
    _blinkAnimation = Tween<double>(begin: 1.0, end: 0.3).animate(
      CurvedAnimation(parent: _blinkController, curve: Curves.easeInOut),
    );
  }

  @override
  void didUpdateWidget(VolumeTile oldWidget) {
    super.didUpdateWidget(oldWidget);
    _checkRankChange();
  }

  void _checkRankChange() {
    final previousRank = _previousRanks[widget.market];
    final currentRank = widget.rank;
    
    // 이전 순위가 있고, 순위가 올라간 경우에만 반짝
    if (previousRank != null && currentRank < previousRank) {
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
    
    // 현재 순위를 저장
    _previousRanks[widget.market] = currentRank;
  }

  @override
  void dispose() {
    _blinkController.dispose();
    super.dispose();
  }

  // 🆕 코인명 표시 로직 (TradeTile과 동일)
  String _getDisplayName(WidgetRef ref) {
    final displayMode = ref.watch(appSettingsProvider).displayMode;
    final marketInfoAsync = ref.watch(marketInfoProvider);
    
    // 기본 티커 (fallback)
    final ticker = widget.market.replaceFirst('KRW-', '');
    
    // marketInfo가 로딩 중이거나 에러인 경우 티커 반환
    return marketInfoAsync.when(
      data: (marketInfoMap) {
        final marketInfo = marketInfoMap[widget.market];
        
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

  // 🎯 거래량 포맷팅 (새로운 통합 규칙)
  String _formatVolume(double totalVolume) {
    if (totalVolume < 0) return '0원';
    
    final decimalFormat = NumberFormat('#,##0.##'); // 소수점 2자리
    final integerFormat = NumberFormat('#,###'); // 정수용 콤마
    
    // 1만원 미만: 1원 ~ 9,999원 (콤마 포함)
    if (totalVolume < 10000) {
      return '${integerFormat.format(totalVolume.toInt())}원';
    }
    // 1만원 ~ 9999만원: x,xxx만원 (콤마 포함)
    else if (totalVolume < 100000000) {
      final man = (totalVolume / 10000).toInt();
      return '${integerFormat.format(man)}만원';
    }
    // 1억 ~ 9999억: x.xx억원 (소수점 2자리)
    else if (totalVolume < 1000000000000) {
      final eok = totalVolume / 100000000;
      return '${decimalFormat.format(eok)}억원';
    }
    // 1조 ~ 9999조: x.xx조원 (소수점 2자리)
    else if (totalVolume < 10000000000000000) {
      final jo = totalVolume / 1000000000000;
      return '${decimalFormat.format(jo)}조원';
    }
    // 1경 이상: x,xxx경원 (콤마 포함)
    else {
      final gyeong = (totalVolume / 10000000000000000).toInt();
      return '${integerFormat.format(gyeong)}경원';
    }
  }

  // 🎯 순위에 따른 색상
  Color _getRankColor(BuildContext context) {
    final theme = Theme.of(context);
    switch (widget.rank) {
      case 1:
        return Colors.amber; // 🥇 1위 - 금색
      case 2:
        return Colors.grey.shade400; // 🥈 2위 - 은색
      case 3:
        return Colors.orange.shade300; // 🥉 3위 - 동색
      default:
        return theme.colorScheme.onSurface.withValues(alpha: 0.6); // 기본
    }
  }

  // 🎯 순위 아이콘
  Widget _buildRankWidget(BuildContext context) {
    final rankColor = _getRankColor(context);
    final isTopThree = widget.rank <= 3;
    
    return Container(
      width: 32,
      height: 32,
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        color: isTopThree ? rankColor.withValues(alpha: 0.2) : Colors.transparent,
        border: isTopThree ? Border.all(color: rankColor, width: 2) : null,
      ),
      child: Center(
        child: Text(
          '${widget.rank}',
          style: TextStyle(
            fontSize: 14,
            fontWeight: isTopThree ? FontWeight.bold : FontWeight.normal,
            color: rankColor,
          ),
        ),
      ),
    );
  }

  // 🎯 HOT 아이콘 (급상승 시)
  Widget? _buildHotIcon() {
    if (!widget.showHotIcon) return null;
    
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
      decoration: BoxDecoration(
        color: Colors.red,
        borderRadius: BorderRadius.circular(8),
      ),
      child: const Text(
        '🚀 HOT',
        style: TextStyle(
          color: Colors.white,
          fontSize: 10,
          fontWeight: FontWeight.bold,
        ),
      ),
    );
  }
  
  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final onSurface = theme.colorScheme.onSurface;
    
    // 🎯 깜빡임 애니메이션 (설정에 따라)
    Widget cardWidget = Card(
      elevation: 2,
      margin: const EdgeInsets.symmetric(vertical: 4),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 16),
        child: Row(
          children: [
            // 🏆 순위 부분: 고정 크기
            _buildRankWidget(context),
            
            const SizedBox(width: 12),
            
            // 🎨 코인 로고 부분
            CoinLogoProvider.buildCoinLogo(
              ticker: widget.market.replaceFirst('KRW-', ''),
              radius: 16,
            ),
            
            const SizedBox(width: 12),
            
            // 📱 코인명 부분: flex 25 (확장 가능)
            Expanded(
              flex: 25,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Flexible(
                        child: Text(
                          _getDisplayName(ref), // ✅ 동적 코인명 표시
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
                      // 🚀 HOT 아이콘
                      if (_buildHotIcon() != null) _buildHotIcon()!,
                    ],
                  ),
                  const SizedBox(height: 2),
                  Row(
                    children: [
                      Text(
                        widget.market.replaceFirst('KRW-', ''), // 항상 티커는 표시
                        style: TextStyle(
                          color: onSurface.withValues(alpha: 0.7),
                          fontSize: 12,
                        ),
                      ),
                      const SizedBox(width: 4),
                      // 🎯 로고 지원 여부 표시 (개발용 - 나중에 제거 가능)
                      if (CoinLogoProvider.isSupported(widget.market.replaceFirst('KRW-', '')))
                        Container(
                          width: 4,
                          height: 4,
                          decoration: const BoxDecoration(
                            color: Colors.green,
                            shape: BoxShape.circle,
                          ),
                        ),
                    ],
                  ),
                ],
              ),
            ),
            
            // 💰 거래량 부분: flex 30
            Expanded(
              flex: 30,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.end,
                children: [
                  Text(
                    _formatVolume(widget.totalVolume),
                    style: TextStyle(
                      color: onSurface,
                      fontSize: 15,
                      fontWeight: FontWeight.w600,
                    ),
                    overflow: TextOverflow.ellipsis,
                    maxLines: 1,
                  ),
                  const SizedBox(height: 2),
                  const Text(
                    '⏰ 실시간', // TODO: 카운트다운 구현
                    style: TextStyle(
                      color: Colors.orange,
                      fontSize: 11,
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );

    // 🎯 반짝임 애니메이션이 있을 때와 없을 때 분기
    Widget finalWidget = cardWidget;
    
    if (_shouldBlink) {
      finalWidget = AnimatedBuilder(
        animation: _blinkAnimation,
        builder: (context, child) {
          return Container(
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(12),
              boxShadow: [
                BoxShadow(
                  color: Colors.amber.withValues(alpha: 1.0 - _blinkAnimation.value),
                  blurRadius: 12,
                  spreadRadius: 3,
                ),
              ],
            ),
            child: cardWidget,
          );
        },
      );
    } else if (widget.enableBlinkAnimation) {
      finalWidget = TweenAnimationBuilder<double>(
        tween: Tween(begin: 1.0, end: 0.7),
        duration: const Duration(milliseconds: 300),
        builder: (context, value, child) {
          return AnimatedContainer(
            duration: const Duration(milliseconds: 150),
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(12),
              boxShadow: [
                BoxShadow(
                  color: theme.colorScheme.primary.withValues(alpha: 1.0 - value),
                  blurRadius: 8,
                  spreadRadius: 2,
                ),
              ],
            ),
            child: cardWidget,
          );
        },
      );
    }
    
    return finalWidget;
  }
}