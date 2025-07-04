import 'package:flutter/material.dart';
import '../../../domain/entities/app_settings.dart';

/// 🔤 폰트 세그먼트 위젯 (디바운싱 및 고정 크기 적용)
class FontSegment extends StatefulWidget {
  final FontFamily value;
  final ValueChanged<FontFamily> onChanged;

  const FontSegment({
    super.key,
    required this.value,
    required this.onChanged,
  });

  @override
  State<FontSegment> createState() => _FontSegmentState();
}

class _FontSegmentState extends State<FontSegment> {
  bool _isTapped = false;

  void _handleTap() {
    if (_isTapped) return;
    
    setState(() {
      _isTapped = true;
    });

    final currentIndex = FontFamily.values.indexOf(widget.value);
    final nextIndex = (currentIndex + 1) % FontFamily.values.length;
    final nextFont = FontFamily.values[nextIndex];

    widget.onChanged(nextFont);

    Future.delayed(const Duration(milliseconds: 500), () {
      if (mounted) {
        setState(() {
          _isTapped = false;
        });
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    // SizedBox로 감싸 버튼의 크기를 고정시킵니다.
    return SizedBox(
      width: 70, // 고정 너비
      height: 40, // 고정 높이
      child: GestureDetector(
        onTap: _handleTap,
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 200),
          alignment: Alignment.center, // 텍스트를 중앙에 정렬
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(8),
            border: Border.all(color: Colors.grey.shade300), // 회색 테두리로 변경
            color: _isTapped
                ? Colors.grey.withAlpha(50)
                : Colors.orange.withAlpha(26),
          ),
          child: Text(
            'Abc',
            style: TextStyle(
              fontFamily: widget.value.fontName,
              fontSize: 16,
              color: Colors.orange,
              fontWeight: FontWeight.bold,
            ),
          ),
        ),
      ),
    );
  }
}