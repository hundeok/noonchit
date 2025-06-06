// lib/presentation/pages/settings_page.dart
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../core/di/app_providers.dart';
import '../../../shared/widgets/theme_mode_segment.dart';
import '../../../shared/widgets/slider_position_segment.dart';

/// 🆕 TopSheet에서 사용할 설정 내용만 담은 위젯
class SettingsPageContent extends ConsumerWidget {
  const SettingsPageContent({Key? key}) : super(key: key);

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final settings = ref.watch(appSettingsProvider);
    final controller = ref.read(appSettingsProvider.notifier);

    return Container(
      constraints: const BoxConstraints(maxHeight: 400), // 최대 높이 제한
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
                  '화면 모드',
                  style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
                ),
                trailing: ThemeModeSegment(
                  value: settings.themeMode,
                  onChanged: controller.setThemeMode,
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
                  style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
                ),
                subtitle: Text(
                  settings.keepScreenOn
                      ? '화면이 자동으로 꺼지지 않습니다'
                      : '시스템 설정에 따라 화면이 꺼집니다'
                ),
                value: settings.keepScreenOn,
                onChanged: controller.setKeepScreenOn,
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
                  style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
                ),
                subtitle: Text(
                  '필터 슬라이더를 ${_getSliderPositionText(settings.sliderPosition)}에 표시'
                ),
                trailing: SliderPositionSegment(
                  value: settings.sliderPosition,
                  onChanged: controller.setSliderPosition,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  /// 슬라이더 위치 텍스트
  String _getSliderPositionText(SliderPosition position) {
    return position.name == 'top' ? '상단' : '하단';
  }
}

/// 🗑️ 기존 SettingsPage는 호환성을 위해 유지 (사용 안 함)
class SettingsPage extends ConsumerWidget {
  const SettingsPage({Key? key}) : super(key: key);

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('설정'),
        centerTitle: true,
      ),
      body: const SettingsPageContent(),
    );
  }
}