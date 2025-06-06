import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../../domain/entities/app_settings.dart';

class SettingsLocalDataSource {
  final SharedPreferences prefs;

  SettingsLocalDataSource(this.prefs);

  // 테마 모드 관리
  ThemeMode getThemeMode() {
    final themeName = prefs.getString('themeMode') ?? 'system';
    return switch (themeName) {
      'light' => ThemeMode.light,
      'dark' => ThemeMode.dark,
      _ => ThemeMode.system,
    };
  }

  Future<void> saveThemeMode(ThemeMode mode) async {
    await prefs.setString('themeMode', mode.name);
  }

  // 화면 항상 켜기 관리
  bool getKeepScreenOn() {
    return prefs.getBool('keepScreenOn') ?? false;
  }

  Future<void> saveKeepScreenOn(bool value) async {
    await prefs.setBool('keepScreenOn', value);
  }

  // 슬라이더 위치 관리 (enum)
  SliderPosition getSliderPosition() {
    final raw = prefs.getString('sliderPosition') ?? 'top';
    return raw == 'bottom' ? SliderPosition.bottom : SliderPosition.top;
  }

  Future<void> saveSliderPosition(SliderPosition position) async {
    await prefs.setString('sliderPosition', position.name);
  }

  // 🆕 코인명 표시 방식 관리
  DisplayMode getDisplayMode() {
    final raw = prefs.getString('displayMode') ?? 'ticker';
    return switch (raw) {
      'korean' => DisplayMode.korean,
      'english' => DisplayMode.english,
      _ => DisplayMode.ticker, // 기본값: ticker
    };
  }

  Future<void> saveDisplayMode(DisplayMode mode) async {
    await prefs.setString('displayMode', mode.name);
  }

  // 💰 금액 표시 방식 관리
  AmountDisplayMode getAmountDisplayMode() {
    final raw = prefs.getString('amountDisplayMode') ?? 'number';
    return switch (raw) {
      'icon' => AmountDisplayMode.icon,
      _ => AmountDisplayMode.number, // 기본값: number
    };
  }

  Future<void> saveAmountDisplayMode(AmountDisplayMode mode) async {
    await prefs.setString('amountDisplayMode', mode.name);
  }
}