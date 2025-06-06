import 'package:flutter/material.dart';
import '../../domain/entities/app_settings.dart'; // SliderPosition enum

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
    return SegmentedButton<SliderPosition>(
      // ✅ 스타일로 크기 조정
      style: SegmentedButton.styleFrom(
        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 6), // ✅ 패딩 줄이기
        minimumSize: const Size(40, 32), // ✅ 최소 크기 줄이기 (더 작게)
        textStyle: const TextStyle(fontSize: 11), // ✅ 9 → 10
      ),
      segments: [
        ButtonSegment(
          value: SliderPosition.top,
          icon: _buildSliderIcon(isTop: true),
          label: const Text('위'),
        ),
        ButtonSegment(
          value: SliderPosition.bottom,
          icon: _buildSliderIcon(isTop: false),
          label: const Text('아래'),
        ),
      ],
      selected: <SliderPosition>{value},
      onSelectionChanged: (newSelection) {
        onChanged(newSelection.first);
      },
    );
  }

  Widget _buildSliderIcon({required bool isTop}) {
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        if (isTop) ...[
          Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Container(
                width: 6, // ✅ 8 → 6 (작게)
                height: 6, // ✅ 8 → 6 (작게)
                decoration: const BoxDecoration(
                  shape: BoxShape.circle, 
                  color: Colors.orange
                )
              ),
              const SizedBox(width: 1), // ✅ 2 → 1 (간격 줄이기)
              Container(
                width: 12, // ✅ 16 → 12 (작게)
                height: 1.5, // ✅ 2 → 1.5 (얇게)
                color: Colors.orange
              ),
            ],
          ),
          const SizedBox(height: 2), // ✅ 4 → 2 (간격 줄이기)
          Row(
            mainAxisSize: MainAxisSize.min,
            children: List.generate(4, (i) => Padding(
              padding: const EdgeInsets.symmetric(horizontal: 0.5), // ✅ 1 → 0.5 (간격 줄이기)
              child: Container(
                width: 3, // ✅ 4 → 3 (작게)
                height: 1.5, // ✅ 2 → 1.5 (얇게)
                color: Colors.grey
              ),
            )),
          ),
        ] else ...[
          Row(
            mainAxisSize: MainAxisSize.min,
            children: List.generate(4, (i) => Padding(
              padding: const EdgeInsets.symmetric(horizontal: 0.5), // ✅ 1 → 0.5 (간격 줄이기)
              child: Container(
                width: 3, // ✅ 4 → 3 (작게)
                height: 1.5, // ✅ 2 → 1.5 (얇게)
                color: Colors.grey
              ),
            )),
          ),
          const SizedBox(height: 2), // ✅ 4 → 2 (간격 줄이기)
          Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Container(
                width: 6, // ✅ 8 → 6 (작게)
                height: 6, // ✅ 8 → 6 (작게)
                decoration: const BoxDecoration(
                  shape: BoxShape.circle, 
                  color: Colors.orange
                )
              ),
              const SizedBox(width: 1), // ✅ 2 → 1 (간격 줄이기)
              Container(
                width: 12, // ✅ 16 → 12 (작게)
                height: 1.5, // ✅ 2 → 1.5 (얇게)
                color: Colors.orange
              ),
            ],
          ),
        ],
      ],
    );
  }
}