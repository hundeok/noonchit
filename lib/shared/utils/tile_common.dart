// lib/shared/utils/tile_common.dart
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../core/di/app_providers.dart';

/// 🎯 타일 공통 유틸리티 클래스 - Provider 최적화 버전
/// SignalTile, TradeTile, VolumeTile, SectorTile에서 중복되는 로직들을 통합 관리
class TileCommon {
  
  // ==================== 코인명 표시 관련 ====================
  
  /// 🪙 동적 코인명 표시 (최적화된 버전 - DisplayMode만 외부에서 받음)
  /// DisplayMode는 상위에서 받고, MarketInfo는 기존 방식 유지
  static String getDisplayNameOptimized(WidgetRef ref, String market, DisplayMode displayMode) {
    final marketInfoAsync = ref.watch(marketInfoProvider);
    
    // 기본 티커 (fallback)
    final ticker = market.replaceFirst('KRW-', '');
    
    // marketInfo가 로딩 중이거나 에러인 경우 티커 반환
    return marketInfoAsync.when(
      data: (marketInfoMap) {
        final marketInfo = marketInfoMap[market];
        
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
  
  /// 🔄 기존 메서드 (하위 호환성을 위해 유지)
  static String getDisplayName(WidgetRef ref, String market) {
    final displayMode = ref.watch(appSettingsProvider).displayMode;
    return getDisplayNameOptimized(ref, market, displayMode);
  }
  
  // ==================== 순위 관련 ====================
  
  /// 🏆 순위에 따른 색상 결정
  /// VolumeTile, SectorTile에서 공통 사용
  static Color getRankColor(BuildContext context, int rank) {
    final theme = Theme.of(context);
    switch (rank) {
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
  
  /// 🎯 순위 위젯 생성
  /// VolumeTile, SectorTile에서 공통 사용
  static Widget buildRankWidget(BuildContext context, int rank) {
    final rankColor = getRankColor(context, rank);
    final isTopThree = rank <= 3;
    
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
          '$rank',
          style: TextStyle(
            fontSize: 14,
            fontWeight: isTopThree ? FontWeight.bold : FontWeight.normal,
            color: rankColor,
          ),
        ),
      ),
    );
  }
  
  // ==================== 상태 아이콘 관련 ====================
  
  /// 🔥 HOT 아이콘 (급상승 표시) - 깔끔한 텍스트 디자인
  /// SignalTile, VolumeTile, SectorTile에서 공통 사용
  static Widget? buildHotIcon(bool showHotIcon) {
    if (!showHotIcon) return null;
    
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
      decoration: BoxDecoration(
        color: Colors.red,
        borderRadius: BorderRadius.circular(12), // ✅ Volume 토글과 일치
      ),
      child: const Text(
        'HOT', // ✅ 이모지 제거, 텍스트만
        style: TextStyle(
          color: Colors.white,
          fontSize: 10,
          fontWeight: FontWeight.bold,
        ),
      ),
    );
  }
  
  /// 🆕 NEW 뱃지 (최근 감지된 시그널용)
  /// SignalTile에서 사용
  static Widget? buildNewBadge(DateTime detectedAt, {int maxAgeSeconds = 30}) {
    final signalAge = DateTime.now().difference(detectedAt).inSeconds;
    if (signalAge > maxAgeSeconds) return null;

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 2),
      decoration: BoxDecoration(
        color: Colors.red,
        borderRadius: BorderRadius.circular(6),
      ),
      child: const Text(
        'NEW',
        style: TextStyle(
          color: Colors.white,
          fontSize: 9,
          fontWeight: FontWeight.bold,
        ),
      ),
    );
  }
  
  // ==================== 변화율/가격 관련 ====================
  
  /// 📈 변화율 포맷팅
  /// SignalTile에서 사용
  static String formatChangePercent(double changePercent) {
    final absChange = changePercent.abs();
    if (absChange >= 10) {
      return '${changePercent >= 0 ? '+' : ''}${changePercent.toStringAsFixed(1)}%';
    } else {
      return '${changePercent >= 0 ? '+' : ''}${changePercent.toStringAsFixed(2)}%';
    }
  }
  
  /// 🎨 변화율에 따른 색상
  /// SignalTile에서 사용
  static Color getChangeColor(double changePercent) {
    if (changePercent > 0) {
      return Colors.red; // 상승: 빨강
    } else if (changePercent < 0) {
      return Colors.blue; // 하락: 파랑
    } else {
      return Colors.grey; // 변동 없음: 회색
    }
  }
  
  // ==================== 반짝임 효과 관련 ====================
  
  /// ✨ 반짝임 효과가 적용된 위젯 래핑
  /// 모든 타일에서 공통 사용
  static Widget wrapWithBlinkEffect({
    required Widget child,
    required bool shouldBlink,
    required Animation<double> blinkAnimation,
    Color blinkColor = Colors.orange,
    double blurRadius = 15.0,
    double spreadRadius = 4.0,
    BorderRadius? borderRadius,
  }) {
    if (!shouldBlink) return child;
    
    return AnimatedBuilder(
      animation: blinkAnimation,
      builder: (context, _) {
        return Container(
          decoration: BoxDecoration(
            borderRadius: borderRadius ?? BorderRadius.circular(12),
            boxShadow: [
              BoxShadow(
                color: blinkColor.withValues(
                  alpha: (1.0 - blinkAnimation.value) * 0.8,
                ),
                blurRadius: blurRadius,
                spreadRadius: spreadRadius,
              ),
            ],
          ),
          child: child,
        );
      },
    );
  }
  
  /// 🎯 조건부 깜빡임 효과 (enableBlinkAnimation용)
  /// 모든 타일에서 공통 사용
  static Widget wrapWithConditionalBlink({
    required Widget child,
    required bool enableBlinkAnimation,
    required ThemeData theme,
    BorderRadius? borderRadius,
  }) {
    if (!enableBlinkAnimation) return child;
    
    return TweenAnimationBuilder<double>(
      tween: Tween(begin: 1.0, end: 0.7),
      duration: const Duration(milliseconds: 300),
      builder: (context, value, _) {
        return AnimatedContainer(
          duration: const Duration(milliseconds: 150),
          decoration: BoxDecoration(
            borderRadius: borderRadius ?? BorderRadius.circular(12),
            boxShadow: [
              BoxShadow(
                color: theme.colorScheme.primary.withValues(alpha: 1.0 - value),
                blurRadius: 8,
                spreadRadius: 2,
              ),
            ],
          ),
          child: child,
        );
      },
    );
  }
  
  // ==================== 공통 레이아웃 헬퍼 ====================
  
  /// 📱 표준 카드 래퍼
  static Widget buildStandardCard({
    required Widget child,
    EdgeInsetsGeometry? margin,
    EdgeInsetsGeometry? padding,
    BorderRadius? borderRadius,
    double? elevation,
  }) {
    return Card(
      elevation: elevation ?? 2,
      margin: margin ?? const EdgeInsets.symmetric(vertical: 4),
      shape: RoundedRectangleBorder(
        borderRadius: borderRadius ?? BorderRadius.circular(12),
      ),
      child: Padding(
        padding: padding ?? const EdgeInsets.symmetric(vertical: 12, horizontal: 16),
        child: child,
      ),
    );
  }
  
  /// 🔧 Flex 기반 Row 레이아웃 헬퍼
  static Widget buildFlexRow({
    required List<FlexChild> children,
    MainAxisAlignment mainAxisAlignment = MainAxisAlignment.start,
    CrossAxisAlignment crossAxisAlignment = CrossAxisAlignment.center,
  }) {
    return Row(
      mainAxisAlignment: mainAxisAlignment,
      crossAxisAlignment: crossAxisAlignment,
      children: children.map((flexChild) {
        if (flexChild.flex > 0) {
          return Expanded(
            flex: flexChild.flex,
            child: flexChild.child,
          );
        } else {
          return flexChild.child;
        }
      }).toList(),
    );
  }
}

/// 🔧 Flex 레이아웃용 헬퍼 클래스
class FlexChild {
  final Widget child;
  final int flex; // 0이면 Expanded 사용 안함
  
  const FlexChild(this.child, {this.flex = 0});
  
  /// 고정 크기 위젯
  const FlexChild.fixed(this.child) : flex = 0;
  
  /// 확장 가능한 위젯
  const FlexChild.expanded(this.child, {this.flex = 1});
}