import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
// Core
import 'core/config/app_config.dart';
import 'core/navigation/app_router.dart';
// Shared UI
import 'shared/theme/app_theme.dart';
// All app-level providers
import 'core/di/app_providers.dart';
import 'domain/entities/app_settings.dart';

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
    final settings = ref.watch(appSettingsProvider);

    return MaterialApp.router(
      title: '코인 포착 앱',
      debugShowCheckedModeBanner: AppConfig.isDebugMode,
      
      theme: _applyFontFamily(AppTheme.light(), settings.fontFamily),
      darkTheme: _applyFontFamily(AppTheme.dark(), settings.fontFamily),
      themeMode: settings.themeMode,
      
      routerConfig: _appRouter.router,
      scaffoldMessengerKey: ref.watch(scaffoldMessengerKeyProvider),
    );
  }

  ThemeData _applyFontFamily(ThemeData baseTheme, FontFamily fontFamily) {
    final fontName = fontFamily.fontName;
    
    return baseTheme.copyWith(
      textTheme: baseTheme.textTheme.apply(
        fontFamily: fontName,
      ),
      primaryTextTheme: baseTheme.primaryTextTheme.apply(
        fontFamily: fontName,
      ),
      appBarTheme: baseTheme.appBarTheme.copyWith(
        titleTextStyle: baseTheme.appBarTheme.titleTextStyle?.copyWith(
          fontFamily: fontName,
        ),
      ),
      bottomNavigationBarTheme: baseTheme.bottomNavigationBarTheme.copyWith(
        selectedLabelStyle: TextStyle(fontFamily: fontName),
        unselectedLabelStyle: TextStyle(fontFamily: fontName),
      ),
      elevatedButtonTheme: ElevatedButtonThemeData(
        style: baseTheme.elevatedButtonTheme.style?.copyWith(
          textStyle: WidgetStateProperty.all(
            TextStyle(
              fontFamily: fontName,
              fontSize: 16,
              fontWeight: FontWeight.w500,
            ),
          ),
        ),
      ),
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

      ref.read(appSettingsProvider);
      ref.read(appLifecycleManagerProvider);

      if (AppConfig.isDebugMode) {
        debugPrint('[Initializer] ✅ Provider initialization complete.');
      }
    });

    return child;
  }
}