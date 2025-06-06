// lib/main.dart

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'core/config/app_config.dart';
import 'core/services/hive_service.dart';
import 'core/bridge/signal_bus.dart';
import 'core/di/app_providers.dart';
import 'app.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();

  // 1) 환경 설정 (Hive 제외)
  await AppConfig.init(envPath: '.env');
  await Firebase.initializeApp();

  // 2) Hive 단일 초기화 🎯
  final hive = HiveService();
  await hive.init();

  // 3) SharedPreferences, SignalBus 준비
  final prefs = await SharedPreferences.getInstance();
  final signalBus = SignalBus();

  // 4) ProviderContainer 생성 및 오버라이드
  final container = ProviderContainer(
    observers: [AppProviderObserver()],
    overrides: [
      hiveServiceProvider.overrideWithValue(hive),           // 🎯 NEW
      sharedPreferencesProvider.overrideWithValue(prefs),
      signalBusProvider.overrideWithValue(signalBus),
    ],
  );

  // 5) 앱 실행
  runApp(
    UncontrolledProviderScope(
      container: container,
      child: ProviderInitializer(
        child: MyApp(navigatorKey: GlobalKey<NavigatorState>()),
      ),
    ),
  );
}