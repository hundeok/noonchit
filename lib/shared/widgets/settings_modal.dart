// lib/shared/widgets/settings_modal.dart
import 'package:flutter/material.dart';
import 'package:flutter/services.dart'; // 🎯 HapticFeedback 추가
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../core/di/app_providers.dart';
import '../../domain/entities/app_settings.dart';
import 'theme_mode_segment.dart';
import 'slider_position_segment.dart';

class SettingsModal {
  /// 설정 모달 표시
  static void show(BuildContext context) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      barrierColor: Colors.black54,
      builder: (context) => const _SettingsModalContent(),
    );
  }
}

class _SettingsModalContent extends ConsumerWidget {
  const _SettingsModalContent();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final settings = ref.watch(appSettingsProvider);
    final controller = ref.read(appSettingsProvider.notifier);

    return Container(
      margin: const EdgeInsets.all(8),
      decoration: BoxDecoration(
        color: Theme.of(context).scaffoldBackgroundColor,
        borderRadius: const BorderRadius.only(
          topLeft: Radius.circular(20),
          topRight: Radius.circular(20),
        ),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.1),
            blurRadius: 10,
            spreadRadius: 2,
          ),
        ],
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          // 🎨 설정 모달 헤더
          _buildHeader(context),
          
          // 구분선
          Divider(color: Colors.grey.shade300, height: 1),
          
          // 🎯 설정 내용
          _buildContent(context, settings, controller),
          
          // 하단 여백
          SizedBox(height: MediaQuery.of(context).padding.bottom + 20),
        ],
      ),
    );
  }

  /// 헤더 (제목 + 닫기 버튼)
  Widget _buildHeader(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(vertical: 12),
      child: Column(
        children: [
          // 당김 핸들
          Container(
            width: 40,
            height: 4,
            decoration: BoxDecoration(
              color: Colors.grey.shade400,
              borderRadius: BorderRadius.circular(2),
            ),
          ),
          const SizedBox(height: 12),
          // 제목과 닫기 버튼
          Row(
            children: [
              const SizedBox(width: 16),
              const Icon(Icons.settings, color: Colors.orange),
              const SizedBox(width: 8),
              const Text(
                '설정',
                style: TextStyle(
                  fontSize: 19,
                  fontWeight: FontWeight.bold,
                ),
              ),
              const Spacer(),
              IconButton(
                icon: const Icon(Icons.close),
                onPressed: () => Navigator.of(context).pop(),
              ),
            ],
          ),
        ],
      ),
    );
  }

  /// 설정 컨텐츠
  Widget _buildContent(BuildContext context, AppSettings settings, dynamic controller) {
    return Container(
      constraints: const BoxConstraints(maxHeight: 550),
      child: SingleChildScrollView(
        padding: const EdgeInsets.all(16),
        child: Column(
          children: [
            // 🎨 테마 설정
            Card(
              elevation: 2,
              child: ListTile(
                leading: const Icon(Icons.palette, color: Colors.orange),
                title: const Text(
                  '테마',
                  style: TextStyle(fontSize: 15, fontWeight: FontWeight.bold),
                ),
                trailing: ThemeModeSegment(
                  value: settings.themeMode,
                  onChanged: (ThemeMode mode) {
                    HapticFeedback.lightImpact(); // 🎯 햅틱 추가
                    controller.setThemeMode(mode);
                  },
                ),
              ),
            ),
            
            const SizedBox(height: 12),
            
            // 💰 코인명 표시 방식
            Card(
              elevation: 2,
              child: ListTile(
                leading: const Icon(Icons.monetization_on, color: Colors.orange),
                title: const Text(
                  '코인명 표시',
                  style: TextStyle(fontSize: 15, fontWeight: FontWeight.bold),
                ),
                subtitle: Text(
                  _getDisplayModeDescription(settings.displayMode),
                  style: const TextStyle(fontSize: 11),
                ),
                trailing: _DisplayModeSegment(
                  value: settings.displayMode,
                  onChanged: (DisplayMode mode) {
                    HapticFeedback.lightImpact(); // 🎯 햅틱 추가
                    controller.setDisplayMode(mode);
                  },
                ),
              ),
            ),
            
            const SizedBox(height: 12),
            
            // 💵 금액 표시 방식
            Card(
              elevation: 2,
              child: ListTile(
                leading: const Icon(Icons.account_balance_wallet, color: Colors.orange),
                title: const Text(
                  '금액 표시',
                  style: TextStyle(fontSize: 15, fontWeight: FontWeight.bold),
                ),
                subtitle: Text(
                  _getAmountDisplayModeDescription(settings.amountDisplayMode),
                  style: const TextStyle(fontSize: 11),
                ),
                trailing: _AmountDisplayModeSegment(
                  value: settings.amountDisplayMode,
                  onChanged: (AmountDisplayMode mode) {
                    HapticFeedback.lightImpact(); // 🎯 햅틱 추가
                    controller.setAmountDisplayMode(mode);
                  },
                ),
              ),
            ),
            
            const SizedBox(height: 12),
            
            // 📱 화면 항상 켜기
            Card(
              elevation: 2,
              child: SwitchListTile(
                secondary: const Icon(Icons.screen_lock_rotation, color: Colors.orange),
                title: const Text(
                  '화면 항상 켜기',
                  style: TextStyle(fontSize: 15, fontWeight: FontWeight.bold),
                ),
                subtitle: Text(
                  settings.keepScreenOn
                    ? '화면이 자동으로 꺼지지 않습니다'
                    : '시스템 설정에 따라 화면이 꺼집니다',
                  style: const TextStyle(fontSize: 11),
                ),
                value: settings.keepScreenOn,
                onChanged: (bool value) {
                  HapticFeedback.lightImpact(); // 🎯 햅틱 추가
                  controller.setKeepScreenOn(value);
                },
                activeColor: Colors.orange,
              ),
            ),
            
            const SizedBox(height: 12),
            
            // 🎚️ 슬라이더 위치
            Card(
              elevation: 2,
              child: ListTile(
                leading: const Icon(Icons.tune, color: Colors.orange),
                title: const Text(
                  '슬라이더 위치',
                  style: TextStyle(fontSize: 15, fontWeight: FontWeight.bold),
                ),
                subtitle: Text(
                  '슬라이더를 ${_getSliderPositionText(settings.sliderPosition)}에 표시',
                  style: const TextStyle(fontSize: 11),
                ),
                trailing: SliderPositionSegment(
                  value: settings.sliderPosition,
                  onChanged: (SliderPosition position) {
                    HapticFeedback.lightImpact(); // 🎯 햅틱 추가
                    controller.setSliderPosition(position);
                  },
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  /// 🆕 표시 모드 설명 텍스트
  String _getDisplayModeDescription(DisplayMode mode) {
    switch (mode) {
      case DisplayMode.ticker:
        return 'BTC, ETH, XRP\n형태로 표시';
      case DisplayMode.korean:
        return '비트코인, 이더리움, 리플\n형태로 표시';
      case DisplayMode.english:
        return 'Bitcoin, Ethereum, Ripple\n형태로 표시';
    }
  }

  /// 💰 금액 표시 방식 설명 텍스트
  String _getAmountDisplayModeDescription(AmountDisplayMode mode) {
    switch (mode) {
      case AmountDisplayMode.number:
        return '1,234만\n숫자로 표시';
      case AmountDisplayMode.icon:
        return '💵 지폐 아이콘\n으로 표시';
    }
  }

  /// 슬라이더 위치 텍스트
  String _getSliderPositionText(SliderPosition position) {
    return position.name == 'top' ? '상단' : '하단';
  }
}

/// 🆕 표시 모드 세그먼트 위젯
class _DisplayModeSegment extends StatelessWidget {
  final DisplayMode value;
  final ValueChanged<DisplayMode> onChanged;

  const _DisplayModeSegment({
    required this.value,
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
            mode: DisplayMode.ticker,
            label: '티커',
            icon: Icons.code,
          ),
          _buildDivider(),
          _buildSegmentButton(
            context: context,
            mode: DisplayMode.korean,
            label: '한글',
            icon: Icons.language,
          ),
          _buildDivider(),
          _buildSegmentButton(
            context: context,
            mode: DisplayMode.english,
            label: '영문',
            icon: Icons.translate,
          ),
        ],
      ),
    );
  }

  Widget _buildSegmentButton({
    required BuildContext context,
    required DisplayMode mode,
    required String label,
    required IconData icon,
  }) {
    final isSelected = value == mode;
    final color = isSelected ? Colors.orange : Colors.grey.shade600;
    final backgroundColor = isSelected ? Colors.orange.withValues(alpha: 0.1) : Colors.transparent;

    return GestureDetector(
      onTap: () => onChanged(mode),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 6),
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
                fontSize: 10,
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
    return Container(
      width: 1,
      height: 30,
      color: Colors.grey.shade300,
    );
  }
}

/// 💰 금액 표시 방식 세그먼트 위젯
class _AmountDisplayModeSegment extends StatelessWidget {
  final AmountDisplayMode value;
  final ValueChanged<AmountDisplayMode> onChanged;

  const _AmountDisplayModeSegment({
    required this.value,
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
            mode: AmountDisplayMode.number,
            label: '숫자',
            icon: Icons.format_list_numbered,
          ),
          _buildDivider(),
          _buildSegmentButton(
            context: context,
            mode: AmountDisplayMode.icon,
            label: '아이콘',
            icon: Icons.account_balance_wallet,
          ),
        ],
      ),
    );
  }

  Widget _buildSegmentButton({
    required BuildContext context,
    required AmountDisplayMode mode,
    required String label,
    required IconData icon,
  }) {
    final isSelected = value == mode;
    final color = isSelected ? Colors.orange : Colors.grey.shade600;
    final backgroundColor = isSelected ? Colors.orange.withValues(alpha: 0.1) : Colors.transparent;

    return GestureDetector(
      onTap: () => onChanged(mode),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
        decoration: BoxDecoration(
          color: backgroundColor,
          borderRadius: BorderRadius.circular(6),
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(icon, size: 18, color: color),
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
    return Container(
      width: 1,
      height: 36,
      color: Colors.grey.shade300,
    );
  }
}