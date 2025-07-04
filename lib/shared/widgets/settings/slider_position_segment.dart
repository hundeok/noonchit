import 'package:flutter/material.dart';
import '../../../domain/entities/app_settings.dart'; // SliderPosition enum

/// 🎚️ 슬라이더 위치 설정 세그먼트 위젯 (각진 스타일)
class SliderPositionSegment extends StatelessWidget {
  final SliderPosition value;
  final ValueChanged<SliderPosition> onChanged;

  const SliderPositionSegment({
    super.key,
    required this.value,
    required this.onChanged,
  });

  @override
  Widget build(BuildContext context) {
    // 다른 세그먼트 컨트롤과 동일한 스타일을 위한 컨테이너
    return Container(
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: Colors.grey.shade300),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          // '상단' 버튼
          _buildSegmentButton(
            context: context,
            position: SliderPosition.top,
            label: '위',
          ),
          // 구분선
          _buildDivider(),
          // '하단' 버튼
          _buildSegmentButton(
            context: context,
            position: SliderPosition.bottom,
            label: '아래',
          ),
        ],
      ),
    );
  }

  /// 각 세그먼트 버튼을 생성하는 헬퍼 메서드
  Widget _buildSegmentButton({
    required BuildContext context,
    required SliderPosition position,
    required String label,
  }) {
    final isSelected = value == position;
    final color = isSelected ? Colors.orange : Colors.grey.shade600;
    // ✨ Deprecation 경고 수정: withOpacity(0.1) -> withAlpha(26)
    final backgroundColor = isSelected ? Colors.orange.withAlpha(26) : Colors.transparent;

    return GestureDetector(
      onTap: () => onChanged(position),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
        decoration: BoxDecoration(
          color: backgroundColor,
          borderRadius: BorderRadius.circular(6),
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            // 슬라이더 위치를 시각적으로 보여주는 아이콘
            _buildSliderIcon(isTop: position == SliderPosition.top, isSelected: isSelected),
            const SizedBox(height: 2),
            // '위' 또는 '아래' 텍스트
            Text(
              label,
              style: TextStyle(
                fontSize: 11,
                color: color,
                fontWeight: isSelected ? FontWeight.bold : FontWeight.normal,
              ),
            ),
          ],
        ),
      ),
    );
  }
  
  /// 버튼 사이에 표시될 구분선
  Widget _buildDivider() {
    return Container(
      width: 1,
      height: 40, // 아이콘과 텍스트 높이에 맞게 조정
      color: Colors.grey.shade300,
    );
  }
  
  /// 슬라이더 위치를 표현하는 아이콘 위젯 (기존 로직 활용)
  Widget _buildSliderIcon({required bool isTop, required bool isSelected}) {
    final activeColor = isSelected ? Colors.orange : Colors.grey.shade600;
    final inactiveColor = Colors.grey.shade400;

    final sliderHandle = Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Container(
          width: 6,
          height: 6,
          decoration: BoxDecoration(
            shape: BoxShape.circle,
            color: activeColor,
          ),
        ),
        const SizedBox(width: 1),
        Container(
          width: 12,
          height: 1.5,
          color: activeColor,
        ),
      ],
    );

    final dummyItems = Row(
      mainAxisSize: MainAxisSize.min,
      children: List.generate(
        4,
        (i) => Padding(
          padding: const EdgeInsets.symmetric(horizontal: 0.5),
          child: Container(
            width: 3,
            height: 1.5,
            color: inactiveColor,
          ),
        ),
      ),
    );

    // isTop 플래그에 따라 위젯 순서 변경
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: isTop
          ? [sliderHandle, const SizedBox(height: 2), dummyItems]
          : [dummyItems, const SizedBox(height: 2), sliderHandle],
    );
  }
}
