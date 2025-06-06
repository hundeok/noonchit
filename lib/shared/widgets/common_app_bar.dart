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
    final screenWidth = MediaQuery.of(context).size.width;
    final leadingWidth = screenWidth * 0.2; // 🔧 화면 너비의 20% (2:6:2 비율)

    return AppBar(
      title: _buildTitle(),
      centerTitle: centerTitle,
      elevation: elevation,
      leadingWidth: leadingWidth, // 🔧 동적 계산된 너비
      leading: leading ?? Container(
        width: leadingWidth, // 🔧 동적 너비 적용
        child: Row(
          children: [ // 🔧 MainAxisAlignment 제거하고 개별 패딩으로 관리 (actions와 동일)
            // 알림 버튼 (Padding으로 감싸서 actions와 매칭)
            Padding(
              padding: const EdgeInsets.only(left: 8), // 🔧 우측 right: 8과 대칭
              child: IconButton(
                icon: const Icon(Icons.notifications, size: 22),
                onPressed: () {
                  HapticFeedback.lightImpact(); // 🎯 알림 버튼 햅틱
                  NotificationModal.show(context);
                },
              ),
            ),
            // 🆕 Market Mood 아이콘 (actions와 동일한 패딩 적용)
            const MarketMoodIndicator(
              size: 18,
              padding: EdgeInsets.only(right: 4), // 🔧 actions의 WebSocket과 동일한 간격
            ),
          ],
        ),
      ),
      actions: actions ?? [
        // WebSocket 상태 아이콘
        const WsStatusIndicator(
          size: 16,
          padding: EdgeInsets.only(right: 4), // 🔧 약간의 간격 추가
        ),
        // 설정 버튼 (우측 여백 확보)
        Padding(
          padding: const EdgeInsets.only(right: 8), // 🔧 우측 여백만 유지
          child: IconButton(
            icon: const Icon(Icons.settings, size: 22),
            onPressed: () {
              HapticFeedback.lightImpact(); // 🎯 설정 버튼 햅틱
              SettingsModal.show(context);
            },
          ),
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