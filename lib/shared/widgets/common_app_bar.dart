import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../core/di/settings_provider.dart';
import 'ws_status_indicator.dart';
import 'market_mood_indicator.dart';
import 'notification_modal.dart';
import 'settings_modal.dart';
import 'slide_indicator.dart';
import '../../presentation/pages/main_page.dart';

/// 공통 상단바 + 알림/설정 아이콘 + 슬라이드 인디케이터
class CommonAppBar extends ConsumerWidget implements PreferredSizeWidget {
 const CommonAppBar({
   super.key,
   required this.title,
   this.leading,
   this.actions,
   this.centerTitle = true,
   this.elevation = 0,
   // 슬라이드 인디케이터용 파라미터들
   this.pages,
   this.pageController,
   this.animationController,
 });

 final String title;
 final Widget? leading;
 final List<Widget>? actions;
 final bool centerTitle;
 final double elevation;

 // 슬라이드 인디케이터 관련
 final List<PageInfo>? pages;
 final PageController? pageController;
 final AnimationController? animationController;

 @override
 Size get preferredSize => const Size.fromHeight(kToolbarHeight);

 @override
 Widget build(BuildContext context, WidgetRef ref) {
   final screenWidth = MediaQuery.of(context).size.width;
   final leadingWidth = screenWidth * 0.2; // 화면 너비의 20%

   return AppBar(
     title: _buildTitle(),
     centerTitle: centerTitle,
     elevation: elevation,
     leadingWidth: leadingWidth,
     leading: leading ?? SizedBox(
       width: leadingWidth,
       child: Row(
         children: [
           // 알림 버튼 (그라디언트 효과 적용)
           Padding(
             padding: const EdgeInsets.only(left: 8),
             child: IconButton(
               icon: ShaderMask(
                 shaderCallback: (bounds) => const LinearGradient(
                   colors: [
                     Color(0xFF9E9E9E), // 밝은 회색
                     Color(0xFF616161), // 중간 회색
                     Color(0xFF424242), // 어두운 회색
                   ],
                   begin: Alignment.topLeft,
                   end: Alignment.bottomRight,
                 ).createShader(bounds),
                 child: const Icon(
                   Icons.notifications,
                   size: 22,
                   color: Colors.white, // 그라디언트가 적용될 베이스
                 ),
               ),
               onPressed: () {
                 if (ref.read(appSettingsProvider).isHapticEnabled) {
                   HapticFeedback.lightImpact();
                 }
                 NotificationModal.show(context);
               },
             ),
           ),
           // 임시 이미지 (주석 처리)
           // Padding(
           //   padding: const EdgeInsets.only(left: 8),
           //   child: IconButton(
           //     icon: Image.asset(
           //       'assets/common_app_bar_icon.webp',
           //       width: 22,
           //       height: 22,
           //       fit: BoxFit.contain,
           //     ),
           //     onPressed: () {
           //       if (ref.read(settingsProvider).isHapticEnabled) {
           //         HapticFeedback.lightImpact();
           //       }
           //       // TODO: 임시로 노티피케이션 개발 전까지 비활성화
           //       // NotificationModal.show(context);
           //     },
           //   ),
           // ),
           // Market Mood 아이콘
           const MarketMoodIndicator(
             size: 18,
             padding: EdgeInsets.only(right: 4),
           ),
         ],
       ),
     ),
     actions: actions ?? [
       // WebSocket 상태 아이콘
       const WsStatusIndicator(
         size: 16,
         padding: EdgeInsets.only(right: 4),
       ),
       // 설정 버튼 (예쁜 그라디언트 적용)
       Padding(
         padding: const EdgeInsets.only(right: 8),
         child: IconButton(
           icon: ShaderMask(
             shaderCallback: (bounds) => const LinearGradient(
               colors: [
                 Color(0xFF9E9E9E), // 밝은 회색
                 Color(0xFF616161), // 중간 회색
                 Color(0xFF424242), // 어두운 회색
               ],
               begin: Alignment.topLeft,
               end: Alignment.bottomRight,
             ).createShader(bounds),
             child: const Icon(
               Icons.settings,
               size: 22,
               color: Colors.white, // 그라디언트가 적용될 베이스
             ),
           ),
           onPressed: () {
             if (ref.read(appSettingsProvider).isHapticEnabled) {
               HapticFeedback.lightImpact();
             }
             SettingsModal.show(context);
           },
         ),
       ),
     ],
   );
 }

 /// 타이틀 부분 구성 (슬라이드 인디케이터 또는 텍스트)
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