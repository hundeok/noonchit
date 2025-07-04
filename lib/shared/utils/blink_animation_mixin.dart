// lib/shared/utils/blink_animation_mixin.dart
import 'package:flutter/material.dart';

/// ✨ 블링크 애니메이션 전용 Mixin
/// UI 애니메이션과 시각적 효과만 담당
mixin BlinkAnimationMixin<T extends StatefulWidget> on State<T>, TickerProviderStateMixin<T> {
  
  late AnimationController _blinkController;
  late Animation<double> _blinkAnimation;

  @override
  void initState() {
    super.initState();
    _initializeBlinkAnimation();
  }

  /// 블링크 애니메이션 초기화
  void _initializeBlinkAnimation() {
    _blinkController = AnimationController(
      duration: const Duration(milliseconds: 1000),
      vsync: this,
    );
    
    _blinkAnimation = Tween<double>(
      begin: 0.0,
      end: 1.0,
    ).animate(CurvedAnimation(
      parent: _blinkController,
      curve: Curves.easeInOut,
    ));
  }

  /// 블링크 애니메이션 시작
  void startBlinkAnimation() {
    _blinkController.reset();
    _blinkController.forward();
  }

  /// 블링크 효과가 적용된 위젯
  Widget buildBlinkWrapper({
    required Widget child,
    required bool shouldBlink,
    Color blinkColor = Colors.orange,
    double blurRadius = 15.0,
    double spreadRadius = 4.0,
    BorderRadius? borderRadius,
  }) {
    if (!shouldBlink) return child;
    
    return AnimatedBuilder(
      animation: _blinkAnimation,
      builder: (context, _) {
        return Container(
          decoration: BoxDecoration(
            borderRadius: borderRadius ?? BorderRadius.circular(12),
            boxShadow: [
              BoxShadow(
                color: blinkColor.withValues(
                  alpha: (1.0 - _blinkAnimation.value) * 0.8,
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

  /// 조건부 블링크 효과 (간단한 버전)
  Widget buildSimpleBlink({
    required Widget child,
    required bool shouldBlink,
    Color? blinkColor,
    BorderRadius? borderRadius,
  }) {
    if (!shouldBlink) return child;
    
    final theme = Theme.of(context);
    final effectiveBlinkColor = blinkColor ?? theme.colorScheme.primary;
    
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
                color: effectiveBlinkColor.withValues(alpha: 1.0 - value),
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

  @override
  void dispose() {
    _blinkController.dispose();
    super.dispose();
  }
}

/// ✨ 정적 블링크 유틸리티 (Mixin 사용이 어려운 경우)
class BlinkAnimationHelper {
  
  /// 반짝임 효과가 적용된 위젯 래핑
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
  
  /// 새로운 시그널 감지 (기존 기능 유지)
  static bool checkNewSignal({
    required Set<String> blinkedSignalsSet,
    required DateTime detectedAt,
    required String signalKey,
    int maxAgeSeconds = 10,
  }) {
    final now = DateTime.now();
    final signalAge = now.difference(detectedAt).inSeconds;
    if (signalAge <= maxAgeSeconds && !blinkedSignalsSet.contains(signalKey)) {
      blinkedSignalsSet.add(signalKey);
      return true;
    }
    return false;
  }

  /// 조건부 블링크 효과 (정적 버전)
  static Widget wrapWithConditionalBlink({
    required Widget child,
    required bool shouldBlink,
    required ThemeData theme,
    Color? blinkColor,
    BorderRadius? borderRadius,
  }) {
    if (!shouldBlink) return child;
    
    final effectiveBlinkColor = blinkColor ?? theme.colorScheme.primary;
    
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
                color: effectiveBlinkColor.withValues(alpha: 1.0 - value),
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
}