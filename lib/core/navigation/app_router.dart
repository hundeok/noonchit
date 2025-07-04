import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../config/app_config.dart';
import '../../shared/widgets/notification_service.dart';
import '../../presentation/pages/main_page.dart'; // 🆕 MainPage 사용

/// 🗑️ 개별 라우트 enum 제거 (이제 MainPage에서 관리)
// enum AppRoute는 더 이상 필요 없음

class AppRouter {
  final WidgetRef ref;
  final GlobalKey<NavigatorState> navigatorKey;
  late final GoRouter router;

  AppRouter(this.ref, this.navigatorKey) {
    router = GoRouter(
      navigatorKey: navigatorKey,
      initialLocation: '/', // 메인 페이지로 시작
      debugLogDiagnostics: AppConfig.isDebugMode,
      routes: [
        // 🆕 단일 메인 라우트 (PageView 기반)
        GoRoute(
          path: '/',
          name: 'main',
          builder: (context, state) => const MainPage(),
        ),
        
        // 🔧 필요시 추가 라우트들 (설정, 상세 페이지 등)
        // GoRoute(
        //   path: '/detail/:id',
        //   name: 'detail',
        //   builder: (context, state) => DetailPage(id: state.params['id']!),
        // ),
      ],
    );
  }

  /// 🔧 Firebase 리스너 설정 (NotificationService에 위임)
  void setupFCMListeners() {
    final notificationService = ref.read(notificationServiceProvider);
    notificationService.setupFirebaseListeners(navigatorKey);
  }

  /// 🔧 리소스 정리 (NotificationService에 위임)
  void dispose() {
    final notificationService = ref.read(notificationServiceProvider);
    notificationService.dispose();
  }
}