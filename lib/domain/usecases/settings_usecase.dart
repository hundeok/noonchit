import 'package:flutter/material.dart';
import '../entities/app_settings.dart';
import '../repositories/settings_repository.dart';

/// 앱 설정 관련 비즈니스 로직
class SettingsUsecase {
  final SettingsRepository _repo;

  SettingsUsecase(this._repo);

  Future<AppSettings> getSettings() {
    return _repo.getSettings();
  }

  Future<void> updateThemeMode(ThemeMode mode) {
    return _repo.updateThemeMode(mode);
  }

  Future<void> updateKeepScreenOn(bool on) {
    return _repo.updateKeepScreenOn(on);
  }

  Future<void> updateSliderPosition(SliderPosition pos) {
    return _repo.updateSliderPosition(pos);
  }

  Future<void> updateDisplayMode(DisplayMode mode) {
    return _repo.updateDisplayMode(mode);
  }

  Future<void> updateAmountDisplayMode(AmountDisplayMode mode) {
    return _repo.updateAmountDisplayMode(mode);
  }

  Future<void> updateBlinkEnabled(bool enabled) {
    return _repo.updateBlinkEnabled(enabled);
  }

  Future<void> updateHotEnabled(bool enabled) { // 🔥 HOT 설정 추가
    return _repo.updateHotEnabled(enabled);
  }

  Future<void> updateFontFamily(FontFamily font) {
    return _repo.updateFontFamily(font);
  }

  Future<void> updateHapticEnabled(bool enabled) { // 🆕 추가
    return _repo.updateHapticEnabled(enabled);
  }

  Future<void> updatePortraitLocked(bool locked) { // 🆕 추가
    return _repo.updatePortraitLocked(locked);
  }

  Future<void> clearCache() {
    return _repo.clearCache();
  }

  Future<void> resetSettings() {
    return _repo.resetSettings();
  }
}