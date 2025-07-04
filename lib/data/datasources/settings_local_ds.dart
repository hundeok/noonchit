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

  // 슬라이더 위치 관리
  SliderPosition getSliderPosition() {
    final raw = prefs.getString('sliderPosition') ?? 'top';
    return raw == 'bottom' ? SliderPosition.bottom : SliderPosition.top;
  }

  Future<void> saveSliderPosition(SliderPosition position) async {
    await prefs.setString('sliderPosition', position.name);
  }

  // 코인명 표시 방식 관리
  DisplayMode getDisplayMode() {
    final raw = prefs.getString('displayMode') ?? 'ticker';
    return switch (raw) {
      'korean' => DisplayMode.korean,
      'english' => DisplayMode.english,
      _ => DisplayMode.ticker,
    };
  }

  Future<void> saveDisplayMode(DisplayMode mode) async {
    await prefs.setString('displayMode', mode.name);
  }

  // 금액 표시 방식 관리
  AmountDisplayMode getAmountDisplayMode() {
    final raw = prefs.getString('amountDisplayMode') ?? 'number';
    return switch (raw) {
      'icon' => AmountDisplayMode.icon,
      _ => AmountDisplayMode.number,
    };
  }

  Future<void> saveAmountDisplayMode(AmountDisplayMode mode) async {
    await prefs.setString('amountDisplayMode', mode.name);
  }

  // 반짝임 효과 관리
  bool getBlinkEnabled() {
    return prefs.getBool('blinkEnabled') ?? true;
  }

  Future<void> saveBlinkEnabled(bool enabled) async {
    await prefs.setBool('blinkEnabled', enabled);
  }

  // 🔥 HOT 아이콘 표시 관리
  bool getHotEnabled() {
    return prefs.getBool('hotEnabled') ?? true; // 기본값: 활성화
  }

  Future<void> saveHotEnabled(bool enabled) async {
    await prefs.setBool('hotEnabled', enabled);
  }

  // 폰트 패밀리 관리
  FontFamily getFontFamily() {
    final raw = prefs.getString('fontFamily') ?? 'pretendard';
    for (final font in FontFamily.values) {
      if (font.name == raw) return font;
    }
    return FontFamily.pretendard;
  }

  Future<void> saveFontFamily(FontFamily font) async {
    await prefs.setString('fontFamily', font.name);
  }

  // 햅틱 피드백 관리 🆕
  bool getHapticEnabled() {
    return prefs.getBool('hapticEnabled') ?? true; // 기본값: 활성화
  }

  Future<void> saveHapticEnabled(bool enabled) async {
    await prefs.setBool('hapticEnabled', enabled);
  }

  // 화면 회전 잠금 관리 🆕
  bool getPortraitLocked() {
    return prefs.getBool('portraitLocked') ?? false; // 기본값: 자동 회전
  }

  Future<void> savePortraitLocked(bool locked) async {
    await prefs.setBool('portraitLocked', locked);
  }

  // 캐시 비우기
  Future<void> clearCache() async {
    final cacheKeys = [
      'coinData_cache',
      'priceHistory_cache',
      'chartData_cache',
      'marketData_cache',
      'imageCache_timestamp',
    ];
    
    for (final key in cacheKeys) {
      await prefs.remove(key);
    }
  }

  // 모든 설정 초기화
  Future<void> resetAllSettings() async {
    final settingKeys = [
      'themeMode',
      'keepScreenOn',
      'sliderPosition',
      'displayMode',
      'amountDisplayMode',
      'blinkEnabled',
      'hotEnabled', // 🔥 HOT 설정 추가
      'fontFamily',
      'hapticEnabled', // 🆕 추가
      'portraitLocked', // 🆕 추가
    ];
    
    for (final key in settingKeys) {
      await prefs.remove(key);
    }
  }
}