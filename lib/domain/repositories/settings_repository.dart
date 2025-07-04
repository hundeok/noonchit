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

  /// 코인명 표시 방식 업데이트
  Future<void> updateDisplayMode(DisplayMode mode);

  /// 금액 표시 방식 업데이트
  Future<void> updateAmountDisplayMode(AmountDisplayMode mode);

  /// 반짝임 효과 업데이트
  Future<void> updateBlinkEnabled(bool enabled);

  /// 🔥 HOT 아이콘 업데이트 (블링크와 동일한 패턴)
  Future<void> updateHotEnabled(bool enabled);

  /// 폰트 패밀리 업데이트
  Future<void> updateFontFamily(FontFamily font);

  /// 햅틱 피드백 설정 업데이트
  Future<void> updateHapticEnabled(bool enabled); // 🆕 추가

  /// 화면 회전 잠금 설정 업데이트
  Future<void> updatePortraitLocked(bool locked); // 🆕 추가

  /// 캐시 비우기
  Future<void> clearCache();

  /// 모든 설정 초기화
  Future<void> resetSettings();
}