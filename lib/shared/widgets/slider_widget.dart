import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter/services.dart';
import '../../core/di/settings_provider.dart';

/// 🔄 공통 슬라이더 위젯 - 4개 페이지 모든 패턴 지원
/// Trade: 좌측 텍스트 + 우측 토글
/// Volume: 좌측 텍스트 + 중앙 토글 + 우측 카운트다운
/// Sector: 좌측 텍스트 + 중앙 토글 + 우측 카운트다운
/// Surge: 좌측 텍스트 + 토글1 + 토글2 + 카운터 + 우측 카운트다운
class CommonSliderWidget extends ConsumerWidget {
  // 필수 파라미터
  final String leftText;                    // 좌측 텍스트
  final double sliderValue;                 // 슬라이더 현재 값
  final double sliderMin;                   // 슬라이더 최소값
  final double sliderMax;                   // 슬라이더 최대값
  final int? sliderDivisions;              // 슬라이더 구간 수
  final String? sliderLabel;               // 슬라이더 라벨
  final ValueChanged<double> onSliderChanged; // 슬라이더 변경 콜백

  // 선택적 컴포넌트들
  final Widget? centerWidget;              // 중앙 위젯 (토글, 카운터 등)
  final Widget? rightWidget;               // 우측 위젯 (토글, 카운트다운 등)
  final List<Widget>? extraWidgets;        // 추가 위젯들 (Surge용)
  final EdgeInsets? padding;               // 커스텀 패딩
  final TextStyle? leftTextStyle;          // 좌측 텍스트 스타일

  const CommonSliderWidget({
    Key? key,
    required this.leftText,
    required this.sliderValue,
    required this.sliderMin,
    required this.sliderMax,
    required this.onSliderChanged,
    this.sliderDivisions,
    this.sliderLabel,
    this.centerWidget,
    this.rightWidget,
    this.extraWidgets,
    this.padding,
    this.leftTextStyle,
  }) : super(key: key);

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return Padding(
      padding: padding ?? const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // 상단 Row: 좌측 텍스트 + 중앙/우측 위젯들
          _buildTopRow(),
          const SizedBox(height: 6),
          // 슬라이더
          _buildSlider(ref),
        ],
      ),
    );
  }

  /// 상단 Row 생성 - 다양한 레이아웃 지원
  Widget _buildTopRow() {
    // Surge 페이지용: 5개 위젯 복잡한 비율
    if (extraWidgets != null && extraWidgets!.isNotEmpty) {
      return Row(
        children: [
          // 좌측 텍스트 (12/49)
          Expanded(
            flex: 12,
            child: Text(
              leftText,
              style: leftTextStyle ?? const TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
              overflow: TextOverflow.ellipsis,
            ),
          ),
          // 추가 위젯들 (Surge의 토글들과 카운터)
          ...extraWidgets!,
          // 우측 위젯 (11/49)
          if (rightWidget != null)
            Expanded(
              flex: 11,
              child: Align(
                alignment: Alignment.centerRight,
                child: rightWidget!,
              ),
            ),
        ],
      );
    }
    
    // Volume/Sector 페이지용: 3등분 레이아웃
    if (centerWidget != null && rightWidget != null) {
      return Row(
        children: [
          // 좌측 텍스트 (1/3)
          Expanded(
            flex: 1,
            child: Text(
              leftText,
              style: leftTextStyle ?? const TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
              overflow: TextOverflow.ellipsis,
            ),
          ),
          // 중앙 위젯 (1/3)
          Expanded(
            flex: 1,
            child: Center(child: centerWidget!),
          ),
          // 우측 위젯 (1/3)
          Expanded(
            flex: 1,
            child: Align(
              alignment: Alignment.centerRight,
              child: rightWidget!,
            ),
          ),
        ],
      );
    }
    
    // Trade 페이지용: 좌측 텍스트 + 우측 위젯
    return Row(
      children: [
        // 좌측 텍스트
        Expanded(
          child: Text(
            leftText,
            style: leftTextStyle ?? const TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
          ),
        ),
        // 우측 위젯 (있으면)
        if (rightWidget != null) rightWidget!,
      ],
    );
  }

  /// 슬라이더 생성
  Widget _buildSlider(WidgetRef ref) {
    return Slider(
      value: sliderValue,
      min: sliderMin,
      max: sliderMax,
      divisions: sliderDivisions,
      label: sliderLabel,
      onChanged: (value) {
        // 햅틱 피드백
        if (ref.read(appSettingsProvider).isHapticEnabled) {
          HapticFeedback.selectionClick();
        }
        onSliderChanged(value);
      },
    );
  }
}

/// 🎯 공통 토글 버튼 위젯
class CommonToggleButton extends ConsumerWidget {
  final String text;
  final bool isActive;
  final VoidCallback onTap;
  final Color? activeColor;
  final Color? inactiveColor;
  final Color? borderColor;
  final IconData? icon;
  final EdgeInsets? padding;
  final double? fontSize;
  
  const CommonToggleButton({
    Key? key,
    required this.text,
    required this.isActive,
    required this.onTap,
    this.activeColor,
    this.inactiveColor,
    this.borderColor,
    this.icon,
    this.padding,
    this.fontSize,
  }) : super(key: key);

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final defaultActiveColor = activeColor ?? Colors.orange;
    final defaultBorderColor = borderColor ?? Colors.orange;
    
    return GestureDetector(
      onTap: () {
        if (ref.read(appSettingsProvider).isHapticEnabled) {
          HapticFeedback.lightImpact();
        }
        onTap();
      },
      child: Container(
        padding: padding ?? const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
        decoration: BoxDecoration(
          color: isActive ? defaultActiveColor : (inactiveColor ?? Colors.transparent),
          borderRadius: BorderRadius.circular(12),
          border: Border.all(
            color: defaultBorderColor,
            width: 1.5,
          ),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            if (icon != null) ...[
              Icon(
                icon,
                size: 14,
                color: isActive ? Colors.white : defaultBorderColor,
              ),
              const SizedBox(width: 4),
            ],
            Text(
              text,
              style: TextStyle(
                color: isActive ? Colors.white : defaultBorderColor,
                fontSize: fontSize ?? 12,
                fontWeight: FontWeight.w600,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

/// 🎯 공통 카운트다운 위젯
class CommonCountdownWidget extends StatelessWidget {
  final DateTime? nextResetTime;
  
  const CommonCountdownWidget({
    Key? key,
    required this.nextResetTime,
  }) : super(key: key);

  @override
  Widget build(BuildContext context) {
    if (nextResetTime == null) {
      return const Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(Icons.access_time, size: 16, color: Colors.grey),
          SizedBox(width: 2),
          Text(
            '--:--',
            style: TextStyle(
              fontSize: 12,
              color: Colors.grey,
              fontWeight: FontWeight.w500,
            ),
          ),
        ],
      );
    }

    final now = DateTime.now();
    final remaining = nextResetTime!.difference(now);
    
    if (remaining.isNegative) {
      return const Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(Icons.access_time, size: 16, color: Colors.orange),
          SizedBox(width: 2),
          Text(
            '00:00',
            style: TextStyle(
              fontSize: 13,
              color: Colors.orange,
              fontWeight: FontWeight.w500,
            ),
          ),
        ],
      );
    }

    final minutes = remaining.inMinutes;
    final seconds = remaining.inSeconds % 60;
    final minutesStr = minutes.toString().padLeft(2, '0');
    final secondsStr = seconds.toString().padLeft(2, '0');
    
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        const Icon(Icons.access_time, size: 16, color: Colors.orange),
        const SizedBox(width: 2),
        Text(
          '$minutesStr:$secondsStr',
          style: const TextStyle(
            fontSize: 12,
            color: Colors.orange,
            fontWeight: FontWeight.w500,
          ),
        ),
      ],
    );
  }
}

/// 🎯 공통 스크롤 리스트 위젯 - 최적화 버전
class CommonScrollableList extends StatelessWidget {
  final ScrollController scrollController;
  final int itemCount;
  final Widget Function(BuildContext, int) itemBuilder;
  final EdgeInsets? padding;
  final bool addAutomaticKeepAlives;       // 🔥 메모리 최적화
  final bool addRepaintBoundaries;         // 🔥 리페인트 최적화
  
  const CommonScrollableList({
    Key? key,
    required this.scrollController,
    required this.itemCount,
    required this.itemBuilder,
    this.padding,
    this.addAutomaticKeepAlives = true,    // 기본값 true (기존 동작 유지)
    this.addRepaintBoundaries = true,      // 기본값 true (기존 동작 유지)
  }) : super(key: key);

  @override
  Widget build(BuildContext context) {
    return RawScrollbar(
      controller: scrollController,
      thumbVisibility: false,
      trackVisibility: false,
      thickness: 6.4,
      radius: const Radius.circular(3.2),
      thumbColor: Colors.orange.withValues(alpha: 0.5),
      trackColor: Colors.transparent,
      interactive: true,
      minThumbLength: 40,
      child: ListView.builder(
        controller: scrollController,
        physics: const BouncingScrollPhysics(
          parent: AlwaysScrollableScrollPhysics(),
        ),
        padding: padding ?? const EdgeInsets.only(left: 16, right: 20, top: 16, bottom: 16),
        itemCount: itemCount,
        itemBuilder: itemBuilder,
        addAutomaticKeepAlives: addAutomaticKeepAlives, // 🔥 메모리 최적화
        addRepaintBoundaries: addRepaintBoundaries,     // 🔥 리페인트 최적화
      ),
    );
  }
}