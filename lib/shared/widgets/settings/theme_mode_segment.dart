import 'package:flutter/material.dart';

/// 🎨 테마 모드 세그먼트 위젯 (3개 토글)
class ThemeModeSegment extends StatelessWidget {
  final ThemeMode themeMode;
  final ValueChanged<ThemeMode> onChanged;

  const ThemeModeSegment({
    super.key,
    required this.themeMode,
    required this.onChanged,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: Colors.grey.shade300),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          _buildSegmentButton(
            context: context,
            label: '시스템',
            icon: Icons.phone_iphone,
            isSelected: themeMode == ThemeMode.system,
            onTap: () => onChanged(ThemeMode.system),
          ),
          _buildDivider(),
          _buildSegmentButton(
            context: context,
            label: '라이트',
            icon: Icons.wb_sunny,
            isSelected: themeMode == ThemeMode.light,
            onTap: () => onChanged(ThemeMode.light),
          ),
          _buildDivider(),
          _buildSegmentButton(
            context: context,
            label: '다크',
            icon: Icons.nightlight_round,
            isSelected: themeMode == ThemeMode.dark,
            onTap: () => onChanged(ThemeMode.dark),
          ),
        ],
      ),
    );
  }

  /// 개별 세그먼트 버튼 생성
  Widget _buildSegmentButton({
    required BuildContext context,
    required String label,
    required IconData icon,
    required bool isSelected,
    required VoidCallback onTap,
  }) {
    final color = isSelected ? Colors.orange : Colors.grey.shade600;
    final backgroundColor = isSelected ? Colors.orange.withAlpha(26) : Colors.transparent;

    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
        decoration: BoxDecoration(
          color: backgroundColor,
          borderRadius: BorderRadius.circular(6),
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(icon, size: 16, color: color),
            const SizedBox(height: 2),
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

  /// 버튼 사이 구분선
  Widget _buildDivider() {
    return Container(
      width: 1,
      height: 40,
      color: Colors.grey.shade300,
    );
  }
}