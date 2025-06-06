// lib/app.dart
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
// Core
import 'core/config/app_config.dart';
import 'core/navigation/app_router.dart';
// Shared UI
import 'shared/theme/app_theme.dart';
// All app-level providers
import 'core/di/app_providers.dart';

/// Entry widget for the application
class MyApp extends ConsumerStatefulWidget {
  final GlobalKey<NavigatorState> navigatorKey;
  
  const MyApp({required this.navigatorKey, Key? key}) : super(key: key);

  @override
  ConsumerState<MyApp> createState() => _MyAppState();
}

class _MyAppState extends ConsumerState<MyApp> {
  late final AppRouter _appRouter;

  @override
  void initState() {
    super.initState();
    _appRouter = AppRouter(ref, widget.navigatorKey)
      ..setupFCMListeners();
  }

  @override
  void dispose() {
    _appRouter.dispose();
    ref.read(signalBusProvider).dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    // 🆕 통합 설정 사용
    final settings = ref.watch(appSettingsProvider);
    // 🔧 기본 upbit 플랫폼 사용 (platformProvider 없으므로)

    return MaterialApp.router(
      title: '코인 포착 앱',
      debugShowCheckedModeBanner: AppConfig.isDebugMode,
      
      // 🆕 기본 upbit 테마 적용
      theme: AppTheme.light(), // 기본값 사용
      darkTheme: AppTheme.dark(), // 기본값 사용
      themeMode: settings.themeMode, // 🎯 실시간 테마 적용!
      
      routerConfig: _appRouter.router,
      scaffoldMessengerKey: ref.watch(scaffoldMessengerKeyProvider),
    );
  }
}

/// ProviderObserver for logging state changes
class AppProviderObserver extends ProviderObserver {
  @override
  void didAddProvider(
    ProviderBase provider,
    Object? value,
    ProviderContainer container,
  ) {
    if (AppConfig.isDebugMode) {
      debugPrint('[Observer] 🆕 Provider Added: ${provider.name ?? provider.runtimeType}');
    }
  }

  @override
  void didUpdateProvider(
    ProviderBase provider,
    Object? previousValue,
    Object? newValue,
    ProviderContainer container,
  ) {
    if (AppConfig.isDebugMode) {
      debugPrint('[Observer] 🔄 Provider Updated: ${provider.name ?? provider.runtimeType}');
    }
  }

  @override
  void didDisposeProvider(
    ProviderBase provider,
    ProviderContainer container,
  ) {
    if (AppConfig.isDebugMode) {
      debugPrint('[Observer] ♻️ Provider Disposed: ${provider.name ?? provider.runtimeType}');
    }
  }
}

/// Initializes critical providers on app start
class ProviderInitializer extends ConsumerWidget {
  final Widget child;
  
  const ProviderInitializer({required this.child, Key? key}) : super(key: key);

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (AppConfig.isDebugMode) {
        debugPrint('[Initializer] ⚡ Initializing providers...');
      }
      
      // 🆕 통합 설정 초기화
      ref.read(appSettingsProvider);
      
      // 🆕 앱 라이프사이클 관리자 초기화 (슬라이더 관련 코드 제거된 버전)
      ref.read(appLifecycleManagerProvider);
      
      if (AppConfig.isDebugMode) {
        debugPrint('[Initializer] ✅ Provider initialization complete.');
      }
    });
    
    return child;
  }
}