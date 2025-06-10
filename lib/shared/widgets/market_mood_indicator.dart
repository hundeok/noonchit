// lib/shared/widgets/market_mood_indicator.dart
// 🎨 Shared Widget: Market Mood 인디케이터 (클린 아키텍처 완전 대응)

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../core/di/app_providers.dart';
import '../../presentation/controllers/market_mood_controller.dart';

/// 🎨 메인 마켓무드 인디케이터 위젯
class MarketMoodIndicator extends ConsumerWidget {
  final double size;
  final bool showTooltip;
  final EdgeInsets? padding;

  const MarketMoodIndicator({
    Key? key,
    this.size = 16,
    this.showTooltip = false,
    this.padding,
  }) : super(key: key);

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    // [수정] 중앙 계산 Provider를 watch하여 로딩/에러/데이터 상태를 한 번에 처리합니다.
    final computedAsync = ref.watch(marketMoodComputedDataProvider);
    
    Widget indicator = computedAsync.when(
      data: (computed) {
        // [수정] marketData가 아직 로드되지 않은 초기 상태일 수 있으므로 null 체크 추가
        if (computed.marketData == null) {
          return _buildLoadingIcon();
        }
        // [수정] computed 객체에서 필요한 marketData와 currentMood를 직접 가져옵니다.
        return _buildMoodIcon(context, ref, computed.marketData!, computed.currentMood);
      },
      loading: () => _buildLoadingIcon(),
      error: (_, __) => _buildErrorIcon(),
    );
    
    if (padding != null) {
      indicator = Padding(padding: padding!, child: indicator);
    }
    
    return indicator;
  }

  Widget _buildMoodIcon(BuildContext context, WidgetRef ref, MarketMoodData data, MarketMood mood) {
    Widget moodIcon = _getMoodIcon(mood);
    
    // 롱프레스 제스처 추가
    return GestureDetector(
      onLongPressStart: (details) => _showMarketMoodModal(context, ref, details.globalPosition, data),
      onLongPressEnd: (_) => _hideMarketMoodModal(),
      onLongPressCancel: () => _hideMarketMoodModal(),
      child: moodIcon,
    );
  }

  Widget _buildLoadingIcon() {
    return _AnimatedMoodIcon(
      icon: Icons.refresh,
      color: Colors.grey,
      tooltip: showTooltip ? '시장 데이터 로딩 중...' : null,
      animationType: MoodAnimationType.rotate,
      size: size,
    );
  }

  Widget _buildErrorIcon() {
    return _AnimatedMoodIcon(
      icon: Icons.error_outline,
      color: Colors.red,
      tooltip: showTooltip ? '시장 데이터 로드 실패' : null,
      animationType: MoodAnimationType.blink,
      size: size,
    );
  }

  /// 🔥 시장 분위기 모달 표시 - 컨트롤러의 MarketMoodModalManager 사용
  void _showMarketMoodModal(BuildContext context, WidgetRef ref, Offset globalPosition, MarketMoodData data) {
    HapticFeedback.mediumImpact();
    Tooltip.dismissAllToolTips();
    
    // 화면 크기와 모달 크기 계산
    final screenSize = MediaQuery.of(context).size;
    final modalWidth = screenSize.width * 0.9; // 90% 너비 사용
    
    // 화면 경계 고려한 위치 계산
    double adjustedX = globalPosition.dx - (modalWidth / 2); // 중앙 정렬
    double adjustedY = globalPosition.dy + size + 40; // 🔥 무조건 아래쪽으로 (위쪽 계산 제거)
    
    // 좌측 경계 체크
    if (adjustedX < 16) {
      adjustedX = 16;
    }
    
    // 우측 경계 체크
    if (adjustedX + modalWidth > screenSize.width - 16) {
      adjustedX = screenSize.width - modalWidth - 16;
    }
    
    // 하단 경계 체크 - 화면 밖으로 나가면 위로 조정
    final bottomSafeArea = MediaQuery.of(context).padding.bottom;
    final maxY = screenSize.height - bottomSafeArea - 300; // 모달 최소 높이 고려
    if (adjustedY > maxY) {
      adjustedY = globalPosition.dy - 250; // 충분히 위로 올려서 표시
    }
    
    final adjustedPosition = Offset(adjustedX, adjustedY);
    
    // 컨트롤러의 MarketMoodModalManager 사용
    MarketMoodModalManager.show(
      context: context,
      ref: ref,
      position: adjustedPosition,
      statusIconSize: size,
      data: data,
    );
  }

  /// 🔥 시장 분위기 모달 숨기기
  void _hideMarketMoodModal() {
    MarketMoodModalManager.hide();
  }

  Widget _getMoodIcon(MarketMood mood) {
    switch (mood) {
      case MarketMood.bull:
        return _AnimatedMoodIcon(
          icon: Icons.rocket_launch,
          color: const Color(0xFFFF6B35), // 🚀 화염 오렌지-레드 톤
          tooltip: showTooltip ? '🚀 불장 - 30분 전 대비 +15% 이상 (롱프레스: 상세정보)' : null,
          animationType: MoodAnimationType.fastPulse,
          size: size,
        );
        
      case MarketMood.weakBull:
        return _AnimatedMoodIcon(
          icon: Icons.local_fire_department,
          color: const Color(0xFFFF6B35), // 🔥 화염 오렌지-레드 톤
          tooltip: showTooltip ? '🔥 약불장 - 30분 전 대비 +5~15% (롱프레스: 상세정보)' : null,
          animationType: MoodAnimationType.fireFlicker,
          size: size,
        );
        
      case MarketMood.sideways:
        return _AnimatedMoodIcon(
          icon: Icons.balance,
          color: const Color(0xFF757575), // ⚖️ 중성 회색
          tooltip: showTooltip ? '⚖️ 중간장 - 30분 전 대비 -5~+5% (롱프레스: 상세정보)' : null,
          animationType: MoodAnimationType.wiggle,
          size: size,
        );
        
      case MarketMood.bear:
        return _AnimatedMoodIcon(
          icon: Icons.water_drop,
          color: const Color(0xFF4A90E2), // 💧 물방울 블루 톤
          tooltip: showTooltip ? '💧 물장 - 30분 전 대비 -5~-15% (롱프레스: 상세정보)' : null,
          animationType: MoodAnimationType.waterDrop,
          size: size,
        );
        
      case MarketMood.deepBear:
        return _AnimatedMoodIcon(
          icon: Icons.ac_unit,
          color: const Color(0xFF4A90E2), // 🧊 얼음장 블루 톤
          tooltip: showTooltip ? '🧊 얼음장 - 30분 전 대비 -15% 이하 (롱프레스: 상세정보)' : null,
          animationType: MoodAnimationType.coldShiver,
          size: size,
        );
    }
  }
}

/// 🎨 애니메이션 타입 enum
enum MoodAnimationType { 
  none, 
  fastPulse, 
  fireFlicker, 
  wiggle, 
  waterDrop, 
  coldShiver, 
  rotate, 
  blink 
}

/// 🎨 애니메이션 아이콘 위젯
class _AnimatedMoodIcon extends StatefulWidget {
  final IconData icon;
  final Color color;
  final String? tooltip;
  final MoodAnimationType animationType;
  final double size;

  const _AnimatedMoodIcon({
    required this.icon,
    required this.color,
    required this.animationType,
    required this.size,
    this.tooltip,
  });

  @override
  State<_AnimatedMoodIcon> createState() => _AnimatedMoodIconState();
}

class _AnimatedMoodIconState extends State<_AnimatedMoodIcon>
    with TickerProviderStateMixin {
  late AnimationController _controller;
  late Animation<double> _animation;

  @override
  void initState() {
    super.initState();
    _setupAnimation();
  }

  void _setupAnimation() {
    switch (widget.animationType) {
      case MoodAnimationType.fastPulse:
        _controller = AnimationController(
          duration: const Duration(milliseconds: 800),
          vsync: this,
        );
        _animation = Tween<double>(begin: 0.6, end: 1.3).animate(
          CurvedAnimation(parent: _controller, curve: Curves.easeInOut),
        );
        _controller.repeat(reverse: true);
        break;
        
      case MoodAnimationType.fireFlicker:
        _controller = AnimationController(
          duration: const Duration(milliseconds: 600),
          vsync: this,
        );
        _animation = Tween<double>(begin: 0.7, end: 1.3).animate(
          CurvedAnimation(parent: _controller, curve: Curves.elasticOut),
        );
        _controller.repeat(reverse: true);
        break;
        
      case MoodAnimationType.wiggle:
        _controller = AnimationController(
          duration: const Duration(milliseconds: 2000),
          vsync: this,
        );
        _animation = Tween<double>(begin: -0.15, end: 0.15).animate(
          CurvedAnimation(parent: _controller, curve: Curves.easeInOut),
        );
        _controller.repeat(reverse: true);
        break;
        
      case MoodAnimationType.waterDrop:
        _controller = AnimationController(
          duration: const Duration(milliseconds: 2500),
          vsync: this,
        );
        _animation = Tween<double>(begin: 0.85, end: 1.0).animate(
          CurvedAnimation(parent: _controller, curve: Curves.easeInOut),
        );
        _controller.repeat(reverse: true);
        break;
        
      case MoodAnimationType.coldShiver:
        _controller = AnimationController(
          duration: const Duration(milliseconds: 150),
          vsync: this,
        );
        _animation = Tween<double>(begin: 0.95, end: 1.0).animate(
          CurvedAnimation(parent: _controller, curve: Curves.linear),
        );
        _controller.repeat(reverse: true);
        break;
        
      case MoodAnimationType.rotate:
        _controller = AnimationController(
          duration: const Duration(seconds: 1),
          vsync: this,
        );
        _animation = Tween<double>(begin: 0, end: 1).animate(_controller);
        _controller.repeat();
        break;
        
      case MoodAnimationType.blink:
        _controller = AnimationController(
          duration: const Duration(milliseconds: 800),
          vsync: this,
        );
        _animation = Tween<double>(begin: 0.3, end: 1.0).animate(
          CurvedAnimation(parent: _controller, curve: Curves.easeInOut),
        );
        _controller.repeat(reverse: true);
        break;
        
      case MoodAnimationType.none:
        _controller = AnimationController(vsync: this);
        _animation = const AlwaysStoppedAnimation(1.0);
        break;
    }
  }

  @override
  void didUpdateWidget(_AnimatedMoodIcon oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.animationType != widget.animationType) {
      _controller.dispose();
      _setupAnimation();
    }
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    Widget iconWidget = AnimatedBuilder(
      animation: _animation,
      builder: (context, child) {
        Widget icon = Icon(
          widget.icon,
          color: widget.color,
          size: widget.size,
        );

        switch (widget.animationType) {
          case MoodAnimationType.fastPulse:
            return Transform.translate(
              offset: Offset(0, (_animation.value - 1) * 2),
              child: Transform.scale(
                scale: _animation.value,
                child: Opacity(
                  opacity: (_animation.value * 0.8 + 0.2).clamp(0.5, 1.0),
                  child: icon,
                ),
              ),
            );
            
          case MoodAnimationType.fireFlicker:
            return Transform.scale(
              scale: _animation.value,
              child: Transform.rotate(
                angle: (_animation.value - 1) * 0.1,
                child: Opacity(
                  opacity: (_animation.value * 0.8 + 0.2).clamp(0.4, 1.0),
                  child: icon,
                ),
              ),
            );
            
          case MoodAnimationType.wiggle:
            return Transform.rotate(
              angle: _animation.value,
              child: Transform.scale(
                scale: 0.95 + (_animation.value.abs() * 0.1),
                child: icon,
              ),
            );
            
          case MoodAnimationType.waterDrop:
            return Transform.translate(
              offset: Offset(0, (1 - _animation.value) * 1.5),
              child: Transform.scale(
                scale: _animation.value,
                child: Opacity(
                  opacity: _animation.value.clamp(0.6, 1.0),
                  child: icon,
                ),
              ),
            );
            
          case MoodAnimationType.coldShiver:
            return Transform.translate(
              offset: Offset(
                (_animation.value - 0.975) * 40,
                (_animation.value - 0.975) * 20,
              ),
              child: Transform.scale(
                scale: _animation.value,
                child: Opacity(
                  opacity: _animation.value.clamp(0.8, 1.0),
                  child: icon,
                ),
              ),
            );
            
          case MoodAnimationType.rotate:
            return Transform.rotate(
              angle: _animation.value * 2 * 3.14159,
              child: icon,
            );
            
          case MoodAnimationType.blink:
            return Transform.scale(
              scale: _animation.value,
              child: Opacity(
                opacity: _animation.value.clamp(0.3, 1.0),
                child: icon,
              ),
            );
            
          case MoodAnimationType.none:
            return icon;
        }
      },
    );

    if (widget.tooltip != null) {
      return Tooltip(
        message: widget.tooltip!,
        preferBelow: false,
        verticalOffset: 20,
        waitDuration: const Duration(milliseconds: 500),
        showDuration: const Duration(seconds: 3),
        decoration: BoxDecoration(
          color: Colors.black87,
          borderRadius: BorderRadius.circular(8),
        ),
        textStyle: const TextStyle(
          fontSize: 11,
          color: Colors.white,
        ),
        child: iconWidget,
      );
    }
    
    return iconWidget;
  }
}