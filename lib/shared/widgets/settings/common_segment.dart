// shared/widgets/settings/common_segment.dart
import 'package:flutter/material.dart';

/// 다중 선택형 세그먼트 위젯 (DisplayMode, AmountDisplayMode용)
class CommonMultiSegment<T> extends StatelessWidget {
  final T value;
  final List<T> options;
  final List<String> labels;
  final List<IconData> icons;
  final ValueChanged<T> onChanged;

  const CommonMultiSegment({
    Key? key,
    required this.value,
    required this.options,
    required this.labels,
    required this.icons,
    required this.onChanged,
  }) : super(key: key);

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: Colors.grey.shade300),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: _buildSegmentButtons(),
      ),
    );
  }

  List<Widget> _buildSegmentButtons() {
    List<Widget> buttons = [];
    
    for (int i = 0; i < options.length; i++) {
      // 버튼 추가
      buttons.add(_buildSegmentButton(
        option: options[i],
        label: labels[i],
        icon: icons[i],
      ));
      
      // 마지막이 아니면 구분선 추가
      if (i < options.length - 1) {
        buttons.add(_buildDivider());
      }
    }
    
    return buttons;
  }

  Widget _buildSegmentButton({
    required T option,
    required String label,
    required IconData icon,
  }) {
    final isSelected = value == option;
    final color = isSelected ? Colors.orange : Colors.grey.shade600;
    final backgroundColor = isSelected ? Colors.orange.withAlpha(26) : Colors.transparent;

    return GestureDetector(
      onTap: () => onChanged(option),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
        decoration: BoxDecoration(
          color: backgroundColor,
          borderRadius: BorderRadius.circular(6),
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
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

  Widget _buildDivider() {
    return Container(width: 1, height: 40, color: Colors.grey.shade300);
  }
}

/// 단일 액션형 세그먼트 위젯 (Cache, Reset, AppInfo용)
class CommonActionSegment extends StatefulWidget {
  final IconData icon;
  final String label;
  final VoidCallback onPressed;

  const CommonActionSegment({
    Key? key,
    required this.icon,
    required this.label,
    required this.onPressed,
  }) : super(key: key);

  @override
  State<CommonActionSegment> createState() => _CommonActionSegmentState();
}

class _CommonActionSegmentState extends State<CommonActionSegment> {
  bool _isPressed = false;

  @override
  Widget build(BuildContext context) {
    final color = _isPressed ? Colors.orange : Colors.grey.shade600;
    final backgroundColor = _isPressed ? Colors.orange.withAlpha(26) : Colors.transparent;

    return Container(
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: Colors.grey.shade300),
      ),
      child: GestureDetector(
        onTapDown: (_) => setState(() => _isPressed = true),
        onTapUp: (_) => setState(() => _isPressed = false),
        onTapCancel: () => setState(() => _isPressed = false),
        onTap: widget.onPressed,
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
          decoration: BoxDecoration(
            color: backgroundColor,
            borderRadius: BorderRadius.circular(6),
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(widget.icon, size: 16, color: color),
              const SizedBox(height: 2),
              Text(
                widget.label,
                style: TextStyle(
                  fontSize: 11,
                  color: color,
                  fontWeight: _isPressed ? FontWeight.bold : FontWeight.normal,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}