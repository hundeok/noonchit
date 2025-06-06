// 1️⃣ lib/core/di/settings_provider.dart (수정)
// ==========================================
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:wakelock_plus/wakelock_plus.dart';
import '../../data/datasources/settings_local_ds.dart';
import '../../data/repositories/settings_repository_impl.dart';
import '../../domain/entities/app_settings.dart';
import '../../domain/repositories/settings_repository.dart';
import '../../domain/usecases/settings_usecase.dart';
import '../utils/logger.dart';

/// 1) SharedPreferences 인스턴스 (main.dart에서 override)
final sharedPreferencesProvider = Provider<SharedPreferences>((ref) {
  throw UnimplementedError(
    'main.dart에서 SharedPreferences.getInstance() 후 overrides로 주입하세요.'
  );
});

/// 2) Local DataSource
final settingsLocalDSProvider = Provider<SettingsLocalDataSource>((ref) {
  final prefs = ref.watch(sharedPreferencesProvider);
  return SettingsLocalDataSource(prefs);
});

/// 3) Repository
final settingsRepositoryProvider = Provider<SettingsRepository>((ref) {
  final ds = ref.watch(settingsLocalDSProvider);
  return SettingsRepositoryImpl(ds);
});

/// 4) UseCase
final settingsUsecaseProvider = Provider<SettingsUsecase>((ref) {
  final repo = ref.watch(settingsRepositoryProvider);
  return SettingsUsecase(repo);
});

/// 5) 🆕 통합 설정 Provider (이것만 사용!)
final appSettingsProvider = StateNotifierProvider<AppSettingsNotifier, AppSettings>((ref) {
  final usecase = ref.watch(settingsUsecaseProvider);
  return AppSettingsNotifier(usecase);
});

/// 🆕 통합 설정 관리 클래스
class AppSettingsNotifier extends StateNotifier<AppSettings> {
  final SettingsUsecase _usecase;

  AppSettingsNotifier(this._usecase) : super(const AppSettings()) {
    _loadSettings();
  }

  /// 초기 설정 로드
  Future<void> _loadSettings() async {
    try {
      final settings = await _usecase.getSettings();
      state = settings;
      
      // 초기 화면 켜기 상태 적용
      _applyKeepScreen(settings.keepScreenOn);
      
      log.i('⚙️ 설정 로드 완료: ${settings.toString()}');
    } catch (e, st) {
      log.e('설정 로드 실패', e, st);
    }
  }

  /// 테마 모드 변경
  Future<void> setThemeMode(ThemeMode mode) async {
    try {
      await _usecase.updateThemeMode(mode);
      state = state.copyWith(themeMode: mode);
      log.i('🎨 테마 모드 변경: ${mode.name}');
    } catch (e, st) {
      log.e('테마 모드 변경 실패', e, st);
    }
  }

  /// 화면 항상 켜기 설정
  Future<void> setKeepScreenOn(bool keep) async {
    try {
      await _usecase.updateKeepScreenOn(keep);
      state = state.copyWith(keepScreenOn: keep);
      _applyKeepScreen(keep);
      log.i('📱 화면 항상 켜기: $keep');
    } catch (e, st) {
      log.e('화면 켜기 설정 실패', e, st);
    }
  }

  /// 슬라이더 위치 변경
  Future<void> setSliderPosition(SliderPosition position) async {
    try {
      await _usecase.updateSliderPosition(position);
      state = state.copyWith(sliderPosition: position);
      log.i('🎚️ 슬라이더 위치: ${position.name}');
    } catch (e, st) {
      log.e('슬라이더 위치 변경 실패', e, st);
    }
  }

  /// 🆕 코인명 표시 방식 변경
  Future<void> setDisplayMode(DisplayMode mode) async {
    try {
      await _usecase.updateDisplayMode(mode);
      state = state.copyWith(displayMode: mode);
      log.i('💰 코인명 표시 방식 변경: ${mode.name}');
    } catch (e, st) {
      log.e('코인명 표시 방식 변경 실패', e, st);
    }
  }

  /// 💰 금액 표시 방식 변경
  Future<void> setAmountDisplayMode(AmountDisplayMode mode) async {
    try {
      await _usecase.updateAmountDisplayMode(mode);
      state = state.copyWith(amountDisplayMode: mode);
      log.i('💵 금액 표시 방식 변경: ${mode.name}');
    } catch (e, st) {
      log.e('금액 표시 방식 변경 실패', e, st);
    }
  }

  /// 화면 켜기 실제 적용
  void _applyKeepScreen(bool keep) {
    if (keep) {
      WakelockPlus.enable();
    } else {
      WakelockPlus.disable();
    }
  }

  /// 설정 새로고침
  Future<void> refresh() async {
    await _loadSettings();
  }
}