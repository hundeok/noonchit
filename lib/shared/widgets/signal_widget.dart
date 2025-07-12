// lib/shared/widgets/signal_widget.dart

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'dart:ui';
import '../../domain/entities/signal.dart';
import '../../presentation/controllers/signal_controller.dart';
import '../../core/di/settings_provider.dart';

/// 🎚️ 임계값 조정 모달 위젯 V4.1 - Minimal Design
class ThresholdAdjustmentModal extends ConsumerStatefulWidget {
  final PatternType pattern;
  final SignalController controller;
  final VoidCallback onClose;

  const ThresholdAdjustmentModal({
    super.key,
    required this.pattern,
    required this.controller,
    required this.onClose,
  });

  @override
  ConsumerState<ThresholdAdjustmentModal> createState() => _ThresholdAdjustmentModalState();
}

class _ThresholdAdjustmentModalState extends ConsumerState<ThresholdAdjustmentModal> {
  late double _currentValue;
  late double _defaultValue;
  late String _thresholdKey;
  late String _unit;
  late double _minValue;
  late double _maxValue;
  late int _divisions;

  @override
  void initState() {
    super.initState();
    _initializeThresholdConfig();
    
    _currentValue = widget.controller.getCurrentThresholdValue(_thresholdKey);
    _defaultValue = widget.controller.getDefaultThresholdValue(_thresholdKey);
  }

  /// 🎯 패턴별 임계값 설정 초기화
  void _initializeThresholdConfig() {
    switch (widget.pattern) {
      case PatternType.surge:
        _thresholdKey = 'priceChangePercent';
        _unit = '%';
        _minValue = 0.1;
        _maxValue = 3.0;
        _divisions = ((3.0 - 0.1) / 0.1).round();
        break;
      case PatternType.flashFire:
        _thresholdKey = 'zScoreThreshold';
        _unit = '배';
        _minValue = 1.0;
        _maxValue = 4.0;
        _divisions = ((4.0 - 1.0) / 0.1).round();
        break;
      case PatternType.stackUp:
        _thresholdKey = 'consecutiveMin';
        _unit = '연속';
        _minValue = 1;
        _maxValue = 8;
        _divisions = (8 - 1);
        break;
      case PatternType.stealthIn:
        _thresholdKey = 'minTradeAmount';
        _unit = '만원';
        _minValue = 100;
        _maxValue = 5000;
        _divisions = ((5000 - 100) / 100).round();
        break;
      case PatternType.blackHole:
        _thresholdKey = 'cvThreshold';
        _unit = '%';
        _minValue = 0.5;
        _maxValue = 10.0;
        _divisions = ((10.0 - 0.5) / 0.5).round();
        break;
      case PatternType.reboundShot:
        _thresholdKey = 'priceRangeMin';
        _unit = '%';
        _minValue = 0.1;
        _maxValue = 5.0;
        _divisions = ((5.0 - 0.1) / 0.1).round();
        break;
    }
  }

  /// 🎨 패턴별 색상 반환
  Color _getPatternColor() {
    switch (widget.pattern) {
      case PatternType.surge:
        return Colors.red;
      case PatternType.flashFire:
        return Colors.orange;
      case PatternType.stackUp:
        return Colors.amber;
      case PatternType.stealthIn:
        return Colors.green;
      case PatternType.blackHole:
        return Colors.purple;
      case PatternType.reboundShot:
        return Colors.blue;
    }
  }

  /// 💰 값 포맷팅 (패턴별)
  String _formatValue(double value) {
    switch (widget.pattern) {
      case PatternType.surge:
      case PatternType.blackHole:
      case PatternType.reboundShot:
        return '${value.toStringAsFixed(1)}$_unit';
      case PatternType.flashFire:
        return '${value.toStringAsFixed(1)}$_unit';
      case PatternType.stackUp:
        return '${value.toInt()}$_unit';
      case PatternType.stealthIn:
        return '${value.toStringAsFixed(0)}$_unit';
    }
  }

  /// 🔄 실제 값 변환
  double _convertToActualValue(double displayValue) {
    if (widget.pattern == PatternType.stealthIn) {
      return displayValue * 10000;
    }
    if (widget.pattern == PatternType.blackHole || widget.pattern == PatternType.reboundShot) {
      return displayValue / 100;
    }
    return displayValue;
  }

  /// 🎚️ 표시용 값 변환
  double _convertToDisplayValue(double actualValue) {
    if (widget.pattern == PatternType.stealthIn) {
      return actualValue / 10000;
    }
    if (widget.pattern == PatternType.blackHole || widget.pattern == PatternType.reboundShot) {
      return actualValue * 100;
    }
    return actualValue;
  }

  /// 📱 햅틱 피드백 실행
  void _performHaptic() {
    HapticFeedback.selectionClick();
  }

  /// 💾 임계값 업데이트
  void _updateThreshold(double displayValue) {
    try {
      final actualValue = _convertToActualValue(displayValue);
      widget.controller.updatePatternThresholdDirect(_thresholdKey, actualValue);
      setState(() {
        _currentValue = actualValue;
      });
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('임계값 업데이트 실패: ${e.toString()}'),
          backgroundColor: Colors.red,
        ),
      );
    }
  }

  /// 🔄 기본값으로 리셋
  void _resetToDefault() {
    try {
      if (ref.read(appSettingsProvider).isHapticEnabled) {
        _performHaptic();
      }
      
      widget.controller.resetThresholdToDefault(_thresholdKey);
      setState(() {
        _currentValue = _defaultValue;
      });
      
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('기본값으로 리셋되었습니다'),
          backgroundColor: Colors.green,
          duration: Duration(seconds: 2),
        ),
      );
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('리셋 실패: ${e.toString()}'),
          backgroundColor: Colors.red,
        ),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final patternColor = _getPatternColor();
    final displayValue = _convertToDisplayValue(_currentValue);

    return Material(
      color: Colors.transparent,
      child: ClipRRect(
        borderRadius: BorderRadius.circular(20),
        child: BackdropFilter(
          filter: ImageFilter.blur(sigmaX: 20, sigmaY: 20),
          child: Container(
            width: 200,
            height: 350,
            decoration: BoxDecoration(
              color: Colors.white.withValues(alpha: 0.15),
              borderRadius: BorderRadius.circular(20),
              border: Border.all(
                color: Colors.white.withValues(alpha: 0.2),
                width: 1,
              ),
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withValues(alpha: 0.1),
                  blurRadius: 20,
                  offset: const Offset(0, 10),
                ),
              ],
            ),
            child: Column(
              children: [
                const SizedBox(height: 30),
                
                // 🎯 현재 값 표시 (크기 축소)
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                  decoration: BoxDecoration(
                    color: patternColor.withValues(alpha: 0.15),
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(
                      color: patternColor.withValues(alpha: 0.3),
                      width: 1,
                    ),
                  ),
                  child: Text(
                    _formatValue(displayValue),
                    style: TextStyle(
                      fontSize: 18, // 24 → 18로 축소
                      fontWeight: FontWeight.bold,
                      color: patternColor,
                    ),
                  ),
                ),

                const SizedBox(height: 25),

                // 🎚️ 세로 슬라이더 (길이 증가)
                Expanded(
                  child: Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 30),
                    child: RotatedBox(
                      quarterTurns: 3,
                      child: SliderTheme(
                        data: SliderTheme.of(context).copyWith(
                          activeTrackColor: patternColor,
                          inactiveTrackColor: patternColor.withValues(alpha: 0.3),
                          thumbColor: patternColor,
                          overlayColor: patternColor.withValues(alpha: 0.2),
                          thumbShape: const RoundSliderThumbShape(enabledThumbRadius: 12),
                          overlayShape: const RoundSliderOverlayShape(overlayRadius: 20),
                          trackHeight: 8,
                        ),
                        child: Slider(
                          value: displayValue.clamp(_minValue, _maxValue),
                          min: _minValue,
                          max: _maxValue,
                          divisions: _divisions,
                          onChanged: (value) {
                            if (ref.read(appSettingsProvider).isHapticEnabled) {
                              _performHaptic();
                            }
                            _updateThreshold(value);
                          },
                        ),
                      ),
                    ),
                  ),
                ),

                const SizedBox(height: 25),

                // 🔄 액션 버튼들 (아이콘만)
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 30),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                    children: [
                      // 리셋 버튼
                      GestureDetector(
                        onTap: _resetToDefault,
                        child: Container(
                          width: 45,
                          height: 45,
                          decoration: BoxDecoration(
                            color: Colors.grey.withValues(alpha: 0.2),
                            borderRadius: BorderRadius.circular(22.5),
                            border: Border.all(
                              color: Colors.grey.withValues(alpha: 0.3),
                              width: 1,
                            ),
                          ),
                          child: Icon(
                            Icons.refresh,
                            color: Colors.grey[700],
                            size: 22,
                          ),
                        ),
                      ),
                      
                      // 완료 버튼
                      GestureDetector(
                        onTap: () {
                          if (ref.read(appSettingsProvider).isHapticEnabled) {
                            _performHaptic();
                          }
                          widget.onClose();
                        },
                        child: Container(
                          width: 45,
                          height: 45,
                          decoration: BoxDecoration(
                            color: patternColor.withValues(alpha: 0.8),
                            borderRadius: BorderRadius.circular(22.5),
                            border: Border.all(
                              color: patternColor,
                              width: 1,
                            ),
                          ),
                          child: const Icon(
                            Icons.check,
                            color: Colors.white,
                            size: 22,
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
                
                const SizedBox(height: 30),
              ],
            ),
          ),
        ),
      ),
    );
  }
}