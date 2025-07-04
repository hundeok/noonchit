import 'package:flutter/material.dart';
import '../../domain/entities/app_settings.dart';
import '../../domain/repositories/settings_repository.dart';
import '../datasources/settings_local_ds.dart';

class SettingsRepositoryImpl implements SettingsRepository {
  final SettingsLocalDataSource dataSource;

  SettingsRepositoryImpl(this.dataSource);

  @override
  Future<AppSettings> getSettings() async {
    return AppSettings(
      themeMode: dataSource.getThemeMode(),
      keepScreenOn: dataSource.getKeepScreenOn(),
      sliderPosition: dataSource.getSliderPosition(),
      displayMode: dataSource.getDisplayMode(),
      amountDisplayMode: dataSource.getAmountDisplayMode(),
      blinkEnabled: dataSource.getBlinkEnabled(),
      hotEnabled: dataSource.getHotEnabled(), // 🔥 HOT 설정 추가
      fontFamily: dataSource.getFontFamily(),
      isHapticEnabled: dataSource.getHapticEnabled(), // 🆕 추가
      isPortraitLocked: dataSource.getPortraitLocked(), // 🆕 추가
    );
  }

  @override
  Future<void> updateThemeMode(ThemeMode mode) async {
    await dataSource.saveThemeMode(mode);
  }

  @override
  Future<void> updateKeepScreenOn(bool value) async {
    await dataSource.saveKeepScreenOn(value);
  }

  @override
  Future<void> updateSliderPosition(SliderPosition position) async {
    await dataSource.saveSliderPosition(position);
  }

  @override
  Future<void> updateDisplayMode(DisplayMode mode) async {
    await dataSource.saveDisplayMode(mode);
  }

  @override
  Future<void> updateAmountDisplayMode(AmountDisplayMode mode) async {
    await dataSource.saveAmountDisplayMode(mode);
  }

  @override
  Future<void> updateBlinkEnabled(bool enabled) async {
    await dataSource.saveBlinkEnabled(enabled);
  }

  @override
  Future<void> updateHotEnabled(bool enabled) async { // 🔥 HOT 설정 추가
    await dataSource.saveHotEnabled(enabled);
  }

  @override
  Future<void> updateFontFamily(FontFamily font) async {
    await dataSource.saveFontFamily(font);
  }

  @override
  Future<void> updateHapticEnabled(bool enabled) async { // 🆕 추가
    await dataSource.saveHapticEnabled(enabled);
  }

  @override
  Future<void> updatePortraitLocked(bool locked) async { // 🆕 추가
    await dataSource.savePortraitLocked(locked);
  }

  @override
  Future<void> clearCache() async {
    await dataSource.clearCache();
  }

  @override
  Future<void> resetSettings() async {
    await dataSource.resetAllSettings();
  }
}