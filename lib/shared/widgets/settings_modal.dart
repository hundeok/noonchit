import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../core/di/app_providers.dart';
import '../../domain/entities/app_settings.dart';

// 🎨 기존 세그먼트 위젯들 Import (기존 구조 유지)
import 'settings/theme_mode_segment.dart';
import 'settings/slider_position_segment.dart';
import 'settings/font_segment.dart';

// 🆕 새로 만든 공통 위젯들 Import
import 'settings/common_segment.dart';
import 'settings/settings_constants.dart';

// 📱 앱 정보 모달 Import
import '../information/app_information_modal.dart';

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
            color: Colors.black.withAlpha(26),
            blurRadius: 10,
            spreadRadius: 2,
          ),
        ],
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          _buildHeader(context, ref),
          Divider(color: Colors.grey.shade300, height: 1),
          _buildContent(context, settings, controller, ref),
          SizedBox(height: MediaQuery.of(context).padding.bottom + 20),
        ],
      ),
    );
  }

  /// 헤더 (제목 + 닫기 버튼)
  Widget _buildHeader(BuildContext context, WidgetRef ref) {
    return Container(
      padding: const EdgeInsets.symmetric(vertical: 12),
      child: Column(
        children: [
          Container(
            width: 40,
            height: 4,
            decoration: BoxDecoration(
              color: Colors.grey.shade400,
              borderRadius: BorderRadius.circular(2),
            ),
          ),
          const SizedBox(height: 12),
          const Row(
            children: [
              SizedBox(width: 16),
              Icon(Icons.settings, color: Colors.orange),
              SizedBox(width: 8),
              Text(
                '설정',
                style: TextStyle(
                  fontSize: 19,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  /// 설정 컨텐츠 (스크롤 가능)
  Widget _buildContent(BuildContext context, AppSettings settings, dynamic controller, WidgetRef ref) {
    final scrollController = ScrollController();
    final screenHeight = MediaQuery.of(context).size.height;
    final isLandscape = MediaQuery.of(context).orientation == Orientation.landscape;
    final bottomPadding = MediaQuery.of(context).padding.bottom;
    
    final maxHeight = isLandscape 
        ? (screenHeight * 0.65 - bottomPadding).clamp(250.0, 300.0)
        : 420.0;
    
    return Container(
      constraints: BoxConstraints(maxHeight: maxHeight),
      child: RawScrollbar(
        controller: scrollController,
        thumbVisibility: false,
        trackVisibility: false,
        thickness: 6.4,
        radius: const Radius.circular(3.2),
        thumbColor: Colors.orange.withAlpha(128),
        trackColor: Colors.transparent,
        interactive: true,
        minThumbLength: 40,
        child: SingleChildScrollView(
          controller: scrollController,
          physics: const BouncingScrollPhysics(
            parent: AlwaysScrollableScrollPhysics(),
          ),
          padding: const EdgeInsets.only(left: 16, right: 20, top: 16, bottom: 16),
          child: Column(
            children: [
              // 🎨 테마 설정 (기존 위젯 유지)
              SizedBox(
                height: 80,
                child: Card(
                  elevation: 2,
                  child: ListTile(
                    leading: const Icon(Icons.palette, color: Colors.orange),
                    title: const Text('테마', style: TextStyle(fontSize: 15, fontWeight: FontWeight.bold)),
                    subtitle: Text(
                      SettingsHelpers.getThemeDescription(settings.themeMode),
                      style: const TextStyle(fontSize: 11),
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                    ),
                    trailing: ThemeModeSegment(
                      themeMode: settings.themeMode,
                      onChanged: (ThemeMode mode) {
                        if (ref.read(appSettingsProvider).isHapticEnabled) {
                          HapticFeedback.lightImpact();
                        }
                        controller.setThemeMode(mode);
                      },
                    ),
                  ),
                ),
              ),
              const SizedBox(height: 12),
              
              // 💰 코인명 표시 방식 (새 공통 위젯 사용)
              SizedBox(
                height: 80,
                child: Card(
                  elevation: 2,
                  child: ListTile(
                    leading: const Icon(Icons.monetization_on, color: Colors.orange),
                    title: const Text('코인명 표시', style: TextStyle(fontSize: 15, fontWeight: FontWeight.bold)),
                    subtitle: Text(
                      SettingsHelpers.getDisplayModeDescription(settings.displayMode),
                      style: const TextStyle(fontSize: 11),
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                    ),
                    trailing: CommonMultiSegment<DisplayMode>(
                      value: settings.displayMode,
                      options: const [DisplayMode.ticker, DisplayMode.korean, DisplayMode.english],
                      labels: const ['티커', '한글', '영문'],
                      icons: const [Icons.code, Icons.language, Icons.translate],
                      onChanged: (DisplayMode mode) {
                        if (ref.read(appSettingsProvider).isHapticEnabled) {
                          HapticFeedback.lightImpact();
                        }
                        controller.setDisplayMode(mode);
                      },
                    ),
                  ),
                ),
              ),
              const SizedBox(height: 12),
              
              // 💵 금액 표시 방식 (새 공통 위젯 사용)
              SizedBox(
                height: 80,
                child: Card(
                  elevation: 2,
                  child: ListTile(
                    leading: const Icon(Icons.account_balance_wallet, color: Colors.orange),
                    title: const Text('금액 표시', style: TextStyle(fontSize: 15, fontWeight: FontWeight.bold)),
                    subtitle: Text(
                      SettingsHelpers.getAmountDisplayModeDescription(settings.amountDisplayMode),
                      style: const TextStyle(fontSize: 11),
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                    ),
                    trailing: CommonMultiSegment<AmountDisplayMode>(
                      value: settings.amountDisplayMode,
                      options: const [AmountDisplayMode.number, AmountDisplayMode.icon],
                      labels: const ['숫자', '아이콘'],
                      icons: const [Icons.format_list_numbered, Icons.account_balance_wallet],
                      onChanged: (AmountDisplayMode mode) {
                        if (ref.read(appSettingsProvider).isHapticEnabled) {
                          HapticFeedback.lightImpact();
                        }
                        controller.setAmountDisplayMode(mode);
                      },
                    ),
                  ),
                ),
              ),
              const SizedBox(height: 12),
              
              // 🔤 폰트 설정 (기존 위젯 유지)
              SizedBox(
                height: 80,
                child: Card(
                  elevation: 2,
                  child: ListTile(
                    leading: const Icon(Icons.font_download, color: Colors.orange),
                    title: const Text('폰트', style: TextStyle(fontSize: 15, fontWeight: FontWeight.bold)),
                    subtitle: Text(
                      SettingsHelpers.getFontDescription(settings.fontFamily),
                      style: const TextStyle(fontSize: 11),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                    trailing: FontSegment(
                      value: settings.fontFamily,
                      onChanged: (FontFamily font) {
                        if (ref.read(appSettingsProvider).isHapticEnabled) {
                          HapticFeedback.lightImpact();
                        }
                        controller.setFontFamily(font);
                      },
                    ),
                  ),
                ),
              ),
              const SizedBox(height: 12),
              
              // 🎚️ 슬라이더 위치 (기존 위젯 유지)
              SizedBox(
                height: 80,
                child: Card(
                  elevation: 2,
                  child: ListTile(
                    leading: const Icon(Icons.tune, color: Colors.orange),
                    title: const Text('슬라이더 위치', style: TextStyle(fontSize: 15, fontWeight: FontWeight.bold)),
                    subtitle: Text(
                      SettingsHelpers.getSliderPositionDescription(settings.sliderPosition),
                      style: const TextStyle(fontSize: 11),
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                    ),
                    trailing: SliderPositionSegment(
                      value: settings.sliderPosition,
                      onChanged: (SliderPosition position) {
                        if (ref.read(appSettingsProvider).isHapticEnabled) {
                          HapticFeedback.lightImpact();
                        }
                        controller.setSliderPosition(position);
                      },
                    ),
                  ),
                ),
              ),
              const SizedBox(height: 12),
              
              // ✨ 블링크 효과
              SizedBox(
                height: 80,
                child: Card(
                  elevation: 2,
                  child: SwitchListTile(
                    secondary: const Icon(Icons.auto_awesome, color: Colors.orange),
                    title: const Text('블링크 효과', style: TextStyle(fontSize: 15, fontWeight: FontWeight.bold)),
                    subtitle: Text(
                      SettingsHelpers.getBlinkDescription(settings.blinkEnabled),
                      style: const TextStyle(fontSize: 11),
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                    ),
                    value: settings.blinkEnabled,
                    onChanged: (bool value) {
                      if (ref.read(appSettingsProvider).isHapticEnabled) {
                        HapticFeedback.lightImpact();
                      }
                      controller.setBlinkEnabled(value);
                    },
                    activeColor: Colors.orange,
                  ),
                ),
              ),
              const SizedBox(height: 12),

              // 🔥 HOT 아이콘
              SizedBox(
                height: 80,
                child: Card(
                  elevation: 2,
                  child: SwitchListTile(
                    secondary: const Icon(Icons.local_fire_department, color: Colors.orange),
                    title: const Text('HOT 아이콘', style: TextStyle(fontSize: 15, fontWeight: FontWeight.bold)),
                    subtitle: Text(
                      SettingsHelpers.getHotIconDescription(settings.hotEnabled),
                      style: const TextStyle(fontSize: 11),
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                    ),
                    value: settings.hotEnabled,
                    onChanged: (bool value) {
                      if (ref.read(appSettingsProvider).isHapticEnabled) {
                        HapticFeedback.lightImpact();
                      }
                      controller.setHotEnabled(value);
                    },
                    activeColor: Colors.orange,
                  ),
                ),
              ),
              const SizedBox(height: 12),
              
              // 📱 화면 항상 켜기
              SizedBox(
                height: 80,
                child: Card(
                  elevation: 2,
                  child: SwitchListTile(
                    secondary: const Icon(Icons.screen_lock_rotation, color: Colors.orange),
                    title: const Text('화면 항상 켜기', style: TextStyle(fontSize: 15, fontWeight: FontWeight.bold)),
                    subtitle: Text(
                      SettingsHelpers.getKeepScreenDescription(settings.keepScreenOn),
                      style: const TextStyle(fontSize: 11),
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                    ),
                    value: settings.keepScreenOn,
                    onChanged: (bool value) {
                      if (ref.read(appSettingsProvider).isHapticEnabled) {
                        HapticFeedback.lightImpact();
                      }
                      controller.setKeepScreenOn(value);
                    },
                    activeColor: Colors.orange,
                  ),
                ),
              ),
              const SizedBox(height: 12),
              
              // 📳 햅틱 피드백
              SizedBox(
                height: 80,
                child: Card(
                  elevation: 2,
                  child: SwitchListTile(
                    secondary: const Icon(Icons.vibration, color: Colors.orange),
                    title: const Text('햅틱 피드백', style: TextStyle(fontSize: 15, fontWeight: FontWeight.bold)),
                    subtitle: Text(
                      SettingsHelpers.getHapticDescription(settings.isHapticEnabled),
                      style: const TextStyle(fontSize: 11),
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                    ),
                    value: settings.isHapticEnabled,
                    onChanged: (bool value) {
                      if (settings.isHapticEnabled) {
                        HapticFeedback.lightImpact();
                      }
                      controller.setHapticEnabled(value);
                    },
                    activeColor: Colors.orange,
                  ),
                ),
              ),
              const SizedBox(height: 12),
              
              // 🔒 화면 회전 잠금
              SizedBox(
                height: 80,
                child: Card(
                  elevation: 2,
                  child: SwitchListTile(
                    secondary: const Icon(Icons.screen_rotation_outlined, color: Colors.orange),
                    title: const Text('세로 모드 고정', style: TextStyle(fontSize: 15, fontWeight: FontWeight.bold)),
                    subtitle: Text(
                      SettingsHelpers.getPortraitLockDescription(settings.isPortraitLocked),
                      style: const TextStyle(fontSize: 11),
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                    ),
                    value: settings.isPortraitLocked,
                    onChanged: (bool value) {
                      if (ref.read(appSettingsProvider).isHapticEnabled) {
                        HapticFeedback.lightImpact();
                      }
                      controller.setPortraitLocked(value);
                    },
                    activeColor: Colors.orange,
                  ),
                ),
              ),
              const SizedBox(height: 12),
              
              // 🔧 캐시 비우기 (새 공통 위젯 사용)
              SizedBox(
                height: 80,
                child: Card(
                  elevation: 2,
                  child: ListTile(
                    leading: const Icon(Icons.cleaning_services, color: Colors.orange),
                    title: const Text('캐시 비우기', style: TextStyle(fontSize: 15, fontWeight: FontWeight.bold)),
                    subtitle: const Text(
                      '임시 데이터를 삭제합니다',
                      style: TextStyle(fontSize: 11),
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                    ),
                    trailing: CommonActionSegment(
                      icon: Icons.cleaning_services,
                      label: '비우기',
                      onPressed: () {
                        if (ref.read(appSettingsProvider).isHapticEnabled) {
                          HapticFeedback.lightImpact();
                        }
                        _showClearCacheDialog(context, controller, ref);
                      },
                    ),
                  ),
                ),
              ),
              const SizedBox(height: 12),
              
              // 🔄 설정 초기화 (새 공통 위젯 사용)
              SizedBox(
                height: 80,
                child: Card(
                  elevation: 2,
                  child: ListTile(
                    leading: const Icon(Icons.restore, color: Colors.orange),
                    title: const Text('설정 초기화', style: TextStyle(fontSize: 15, fontWeight: FontWeight.bold)),
                    subtitle: const Text(
                      '모든 설정을 기본값으로 되돌립니다',
                      style: TextStyle(fontSize: 11),
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                    ),
                    trailing: CommonActionSegment(
                      icon: Icons.restore,
                      label: '초기화',
                      onPressed: () {
                        if (ref.read(appSettingsProvider).isHapticEnabled) {
                          HapticFeedback.lightImpact();
                        }
                        _showResetDialog(context, controller, ref);
                      },
                    ),
                  ),
                ),
              ),
              const SizedBox(height: 12),
              
              // 📱 앱 정보 (새 공통 위젯 사용)
              SizedBox(
                height: 80,
                child: Card(
                  elevation: 2,
                  child: ListTile(
                    leading: const Icon(Icons.info_outline, color: Colors.orange),
                    title: const Text('앱 정보', style: TextStyle(fontSize: 15, fontWeight: FontWeight.bold)),
                    subtitle: const Text(
                      '버전 정보 및 개발자 정보를 확인합니다',
                      style: TextStyle(fontSize: 11),
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                    ),
                    trailing: CommonActionSegment(
                      icon: Icons.info_outline,
                      label: '정보',
                      onPressed: () {
                        if (ref.read(appSettingsProvider).isHapticEnabled) {
                          HapticFeedback.lightImpact();
                        }
                        AppInformationModal.show(context);
                      },
                    ),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  // 🗂️ 다이얼로그 메서드들 (기존 유지)
  void _showClearCacheDialog(BuildContext context, dynamic controller, WidgetRef ref) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('캐시 비우기'),
        content: const Text('임시 데이터를 삭제하시겠습니까?\n앱 성능이 향상될 수 있습니다.'),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(),
            child: const Text('취소'),
          ),
          TextButton(
            onPressed: () async {
              if (ref.read(appSettingsProvider).isHapticEnabled) {
                HapticFeedback.lightImpact();
              }
              Navigator.of(context).pop();
              await controller.clearCache();
              if (context.mounted) {
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(content: Text('캐시가 삭제되었습니다')),
                );
              }
            },
            child: const Text('삭제', style: TextStyle(color: Colors.red)),
          ),
        ],
      ),
    );
  }

  void _showResetDialog(BuildContext context, dynamic controller, WidgetRef ref) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('설정 초기화'),
        content: const Text('모든 설정을 기본값으로 되돌리시겠습니까?\n이 작업은 되돌릴 수 없습니다.'),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(),
            child: const Text('취소'),
          ),
          TextButton(
            onPressed: () async {
              if (ref.read(appSettingsProvider).isHapticEnabled) {
                HapticFeedback.lightImpact();
              }
              Navigator.of(context).pop();
              await controller.resetAllSettings();
              if (context.mounted) {
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(content: Text('설정이 초기화되었습니다')),
                );
              }
            },
            child: const Text('초기화', style: TextStyle(color: Colors.red)),
          ),
        ],
      ),
    );
  }
}