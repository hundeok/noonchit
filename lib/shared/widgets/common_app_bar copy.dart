// lib/shared/widgets/common_app_bar.dart
import 'package:flutter/material.dart';
import 'package:flutter/services.dart'; // 🎯 HapticFeedback용
import 'package:flutter_riverpod/flutter_riverpod.dart'; // ✅ 추가
import 'ws_status_indicator.dart';
import 'market_mood_indicator.dart'; // 🆕 Market Mood 추가
import 'notification_modal.dart';
import 'settings_modal.dart';
import 'slide_indicator.dart'; // ✅ 파일명 정확히 확인
import '../../presentation/pages/main_page.dart';

/// 공통 상단바 + 알림/설정 아이콘 + 슬라이드 인디케이터
class CommonAppBar extends ConsumerWidget implements PreferredSizeWidget { // ✅ ConsumerWidget으로 변경
  const CommonAppBar({
    super.key,
    required this.title,
    this.leading,
    this.actions,
    this.centerTitle = true,
    this.elevation = 0,
    // 🆕 슬라이드 인디케이터용 파라미터들
    this.pages,
    this.pageController,
    this.animationController,
  });

  final String title;
  final Widget? leading;
  final List<Widget>? actions;
  final bool centerTitle;
  final double elevation;

  // 🆕 슬라이드 인디케이터 관련
  final List<PageInfo>? pages;
  final PageController? pageController;
  final AnimationController? animationController;

  @override
  Size get preferredSize => const Size.fromHeight(kToolbarHeight);

  @override
  Widget build(BuildContext context, WidgetRef ref) { // ✅ WidgetRef 파라미터 추가
    return AppBar(
      title: _buildTitle(),
      centerTitle: centerTitle,
      elevation: elevation,
      leading: leading ?? Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          // 알림 버튼 (아이콘 크기 축소)
          IconButton(
            icon: const Icon(Icons.notifications, size: 10), // 🔧 24 → 20으로 축소
            onPressed: () {
              HapticFeedback.lightImpact(); // 🎯 알림 버튼 햅틱
              NotificationModal.show(context);
            },
            tooltip: '알림',
            padding: const EdgeInsets.all(4), // 🔧 패딩 축소
          ),
          // 🆕 Market Mood 아이콘 (크기 축소)
          const MarketMoodIndicator(
            size: 16, // 🔧 18 → 14로 축소
            padding: EdgeInsets.only(left: 12), // 🔧 4 → 2로 축소
          ),
        ],
      ),
      actions: actions ?? [
        // WebSocket 상태 아이콘 (크기 축소)
        const WsStatusIndicator(
          size: 16, // 🔧 16 → 14로 축소
          padding: EdgeInsets.only(right: 6), // 🔧 8 → 6으로 축소
        ),
        // 설정 버튼 (아이콘 크기 축소)
        IconButton(
          icon: const Icon(Icons.settings, size: 14), // 🔧 24 → 20으로 축소
          onPressed: () {
            HapticFeedback.lightImpact(); // 🎯 설정 버튼 햅틱
            SettingsModal.show(context);
          },
          tooltip: '설정',
          padding: const EdgeInsets.all(8), // 🔧 패딩 축소
        ),
      ],
    );
  }

  /// 🎨 타이틀 부분 구성 (슬라이드 인디케이터 또는 텍스트)
  Widget _buildTitle() {
    // 슬라이드 인디케이터 파라미터들이 모두 있으면 인디케이터 표시
    if (pages != null && pageController != null && animationController != null) {
      return SlideIndicator(
        pages: pages!,
        pageController: pageController!,
        animationController: animationController!,
      );
    }

    // 파라미터가 없으면 기본 텍스트 표시
    return Text(title);
  }
}