import 'package:flutter/material.dart';

class ThemeModeSegment extends StatelessWidget {
  final ThemeMode value;
  final ValueChanged<ThemeMode> onChanged;

  const ThemeModeSegment({
    super.key,
    required this.value,
    required this.onChanged,
  });

  @override
  Widget build(BuildContext context) {
    return SegmentedButton<ThemeMode>(
      // ✅ 스타일로 크기 조정
      style: SegmentedButton.styleFrom(
        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 6), // ✅ 패딩 줄이기
        minimumSize: const Size(50, 32), // ✅ 최소 크기 줄이기
        textStyle: const TextStyle(fontSize: 11), // ✅ 9 → 10
        iconSize: 14, // ✅ 아이콘 크기 줄이기
      ),
      segments: const [
        ButtonSegment(
          value: ThemeMode.light,
          icon: Icon(Icons.wb_sunny),
          label: Text('라이트'),
        ),
        ButtonSegment(
          value: ThemeMode.system,
          icon: Icon(Icons.phone_iphone),
          label: Text('시스템'),
        ),
        ButtonSegment(
          value: ThemeMode.dark,
          icon: Icon(Icons.nightlight_round),
          label: Text('다크'),
        ),
      ],
      selected: <ThemeMode>{value},
      onSelectionChanged: (newSelection) {
        onChanged(newSelection.first);
      },
    );
  }
}