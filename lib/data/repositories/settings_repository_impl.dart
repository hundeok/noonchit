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
      displayMode: dataSource.getDisplayMode(), // 🆕 DisplayMode 로드
      amountDisplayMode: dataSource.getAmountDisplayMode(), // 💰 AmountDisplayMode 로드
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
    await dataSource.saveDisplayMode(mode); // 🆕 DisplayMode 저장
  }

  @override
  Future<void> updateAmountDisplayMode(AmountDisplayMode mode) async {
    await dataSource.saveAmountDisplayMode(mode); // 💰 AmountDisplayMode 저장
  }
}