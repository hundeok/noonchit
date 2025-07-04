import 'package:flutter/material.dart';
import 'package:flutter/services.dart'; // SystemChrome용
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

/// 5) 통합 설정 Provider
final appSettingsProvider = StateNotifierProvider<AppSettingsNotifier, AppSettings>((ref) {
  final usecase = ref.watch(settingsUsecaseProvider);
  return AppSettingsNotifier(usecase);
});

/// 통합 설정 관리 클래스
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
      _applyKeepScreen(settings.keepScreenOn);
      _applyOrientationLock(settings.isPortraitLocked);
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

  /// 코인명 표시 방식 변경
  Future<void> setDisplayMode(DisplayMode mode) async {
    try {
      await _usecase.updateDisplayMode(mode);
      state = state.copyWith(displayMode: mode);
      log.i('💰 코인명 표시 방식 변경: ${mode.name}');
    } catch (e, st) {
      log.e('코인명 표시 방식 변경 실패', e, st);
    }
  }

  /// 금액 표시 방식 변경
  Future<void> setAmountDisplayMode(AmountDisplayMode mode) async {
    try {
      await _usecase.updateAmountDisplayMode(mode);
      state = state.copyWith(amountDisplayMode: mode);
      log.i('💵 금액 표시 방식 변경: ${mode.name}');
    } catch (e, st) {
      log.e('금액 표시 방식 변경 실패', e, st);
    }
  }

  /// 반짝임 효과 설정
  Future<void> setBlinkEnabled(bool enabled) async {
    try {
      await _usecase.updateBlinkEnabled(enabled);
      state = state.copyWith(blinkEnabled: enabled);
      log.i('✨ 반짝임 효과: $enabled');
    } catch (e, st) {
      log.e('반짝임 효과 변경 실패', e, st);
    }
  }

  /// 🔥 HOT 아이콘 설정 (블링크와 동일한 패턴)
  Future<void> setHotEnabled(bool enabled) async {
    try {
      await _usecase.updateHotEnabled(enabled);
      state = state.copyWith(hotEnabled: enabled);
      log.i('🔥 HOT 아이콘: $enabled');
    } catch (e, st) {
      log.e('HOT 아이콘 설정 실패', e, st);
    }
  }

  /// 폰트 패밀리 변경
  Future<void> setFontFamily(FontFamily font) async {
    try {
      await _usecase.updateFontFamily(font);
      state = state.copyWith(fontFamily: font);
      log.i('🔤 폰트 설정: ${font.fontName}');
    } catch (e, st) {
      log.e('폰트 설정 실패', e, st);
    }
  }

  /// 햅틱 피드백 설정
  Future<void> setHapticEnabled(bool enabled) async {
    try {
      await _usecase.updateHapticEnabled(enabled);
      state = state.copyWith(isHapticEnabled: enabled);
      log.i('📳 햅틱 피드백: $enabled');
    } catch (e, st) {
      log.e('햅틱 피드백 설정 실패', e, st);
    }
  }

  /// 화면 회전 잠금 설정
  Future<void> setPortraitLocked(bool locked) async {
    try {
      await _usecase.updatePortraitLocked(locked);
      state = state.copyWith(isPortraitLocked: locked);
      _applyOrientationLock(locked);
      log.i('🔒 화면 회전 잠금: $locked');
    } catch (e, st) {
      log.e('화면 회전 잠금 설정 실패', e, st);
    }
  }

  /// 캐시 비우기
  Future<void> clearCache() async {
    try {
      await _usecase.clearCache();
      log.i('🗂️ 캐시 비우기 완료');
      await refresh();
    } catch (e, st) {
      log.e('캐시 비우기 실패', e, st);
    }
  }

  /// 모든 설정 초기화
  Future<void> resetAllSettings() async {
    try {
      await _usecase.resetSettings();
      state = const AppSettings();
      _applyKeepScreen(false);
      _applyOrientationLock(false);
      log.i('🔄 모든 설정 초기화 완료');
    } catch (e, st) {
      log.e('설정 초기화 실패', e, st);
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

  /// 화면 회전 잠금 실제 적용
  void _applyOrientationLock(bool locked) {
    if (locked) {
      // 세로 모드만 허용
      SystemChrome.setPreferredOrientations([
        DeviceOrientation.portraitUp,
        DeviceOrientation.portraitDown,
      ]);
    } else {
      // 모든 방향 허용
      SystemChrome.setPreferredOrientations([
        DeviceOrientation.landscapeRight,
        DeviceOrientation.landscapeLeft,
        DeviceOrientation.portraitUp,
        DeviceOrientation.portraitDown,
      ]);
    }
  }

  /// 설정 새로고침
  Future<void> refresh() async {
    await _loadSettings();
  }
}