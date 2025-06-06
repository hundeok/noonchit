import 'package:flutter/material.dart';
import '../entities/app_settings.dart';

abstract class SettingsRepository {
  /// 현재 앱 설정 가져오기
  Future<AppSettings> getSettings();

  /// 테마 모드 업데이트
  Future<void> updateThemeMode(ThemeMode mode);

  /// 화면 항상 켜기 설정 업데이트
  Future<void> updateKeepScreenOn(bool value);

  /// 슬라이더 위치 업데이트
  Future<void> updateSliderPosition(SliderPosition position);

  /// 🆕 코인명 표시 방식 업데이트
  Future<void> updateDisplayMode(DisplayMode mode);

  /// 💰 금액 표시 방식 업데이트
  Future<void> updateAmountDisplayMode(AmountDisplayMode mode);
}