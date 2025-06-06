// lib/presentation/widgets/sector_tile.dart (수정됨)

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';
import '../../core/di/app_providers.dart'; // 🆕 sectorClassificationProvider 추가
import '../../shared/widgets/sector_names.dart'; // 🆕 섹터 네이밍 추가

// 🎯 순위 추적을 위한 전역 Map (섹터별 이전 순위 저장)
final Map<String, int> _previousSectorRanks = {};

class SectorTile extends ConsumerStatefulWidget {
  final String sectorName; // 섹터명 (예: "모놀리식 블록체인")
  final double totalVolume; // 섹터별 총 거래대금
  final int rank; // 🎯 순위 (1위부터)
  final String timeFrame; // 시간대 (예: "1m", "5m")
  final DateTime lastUpdated; // 마지막 업데이트 시간
  final bool showHotIcon; // 🚀 급상승 표시 여부
  final bool enableBlinkAnimation; // 깜빡임 애니메이션 여부
  
  const SectorTile({
    Key? key, 
    required this.sectorName,
    required this.totalVolume,
    required this.rank,
    required this.timeFrame,
    required this.lastUpdated,
    this.showHotIcon = false,
    this.enableBlinkAnimation = false,
  }) : super(key: key);

  @override
  ConsumerState<SectorTile> createState() => _SectorTileState();
}

class _SectorTileState extends ConsumerState<SectorTile> 
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
  void didUpdateWidget(SectorTile oldWidget) {
    super.didUpdateWidget(oldWidget);
    _checkRankChange();
  }

  void _checkRankChange() {
    final previousRank = _previousSectorRanks[widget.sectorName];
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
    _previousSectorRanks[widget.sectorName] = currentRank;
  }

  @override
  void dispose() {
    _blinkController.dispose();
    super.dispose();
  }

  // 🆕 섹터명 표시 로직 (설정에 따라 동적 변경)
  String _getDisplaySectorName() {
    final displayMode = ref.watch(appSettingsProvider).displayMode;
    
    // 🎯 실제 상세/기본 분류 상태 가져오기!
    final isDetailed = ref.watch(sectorClassificationProvider).isDetailedClassification;
    
    return SectorNames.getDisplayName(widget.sectorName, displayMode, isDetailed: isDetailed);
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

  // 🎯 섹터 아이콘/이모지 (나중에 커스텀 아이콘으로 대체 예정)
  Widget _buildSectorIcon() {
    return Container(
      width: 32,
      height: 32,
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        color: Colors.blue.withValues(alpha: 0.1),
        border: Border.all(color: Colors.blue.withValues(alpha: 0.3), width: 1),
      ),
      child: const Center(
        child: Text(
          '📊', // 임시 이모지 (나중에 섹터별 커스텀 아이콘으로)
          style: TextStyle(fontSize: 16),
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
    final onSurface70 = onSurface.withValues(alpha: 0.7);
    
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
            
            // 🎨 섹터 아이콘 부분 (나중에 커스텀 아이콘으로 대체)
            _buildSectorIcon(),
            
            const SizedBox(width: 12),
            
            // 📱 섹터명 부분: flex 25 (확장 가능) - 🆕 동적 표시 적용!
            Expanded(
              flex: 25,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Flexible(
                        child: Text(
                          _getDisplaySectorName(), // 🆕 설정에 따라 동적 표시!
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
                  // 🎯 상세 설명 공간 (일단 비워둠 - 나중에 섹터 설명 추가)
                  Text(
                    '', // 나중에 섹터 상세 설명 추가 예정
                    style: TextStyle(
                      color: onSurface70,
                      fontSize: 12,
                    ),
                  ),
                ],
              ),
            ),
            
            // 💰 거래대금 부분: flex 30
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
                    '⏰ 실시간',
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