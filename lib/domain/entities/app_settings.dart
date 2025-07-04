import 'package:flutter/material.dart';
import 'package:equatable/equatable.dart';

/// 슬라이더 위치를 표현하는 enum
enum SliderPosition { top, bottom }

/// 🆕 코인명 표시 방식을 표현하는 enum
enum DisplayMode {
  ticker, // BTC, ETH, XRP
  korean, // 비트코인, 이더리움, 리플
  english, // Bitcoin, Ethereum, Ripple
}

/// 💰 금액 표시 방식을 표현하는 enum
enum AmountDisplayMode {
  number, // 1,234만 (숫자)
  icon, // 💵 (아이콘)
}

/// 🔤 폰트 패밀리를 표현하는 enum (✨ pubspec.yaml 기준으로 정리)
enum FontFamily {
  // --- 기본 ---
  pretendard,
  // --- 전체 추가 폰트 ---
  dotGothic16,
  dynaPuff,
  gloriaHallelujah,
  gowunDodum,
  gugi,
  ibmPlexSansKRLight,
  inconsolata,
  kirangHaerang,
  nanumGothicCoding,
  notoSerifKR,
  novaMono,
  novaSquare,
  permanentMarker,
  pixelifySans,
  sunflowerLight,
  syneMono;

  // 실제 폰트명 매핑 (✨ pubspec.yaml 기준으로 정리)
  String get fontName {
    switch (this) {
      case FontFamily.pretendard: return 'Pretendard';
      case FontFamily.dotGothic16: return 'DotGothic16-Regular';
      case FontFamily.dynaPuff: return 'DynaPuff-VariableFont_wdth,wght';
      case FontFamily.gloriaHallelujah: return 'GloriaHallelujah-Regular';
      case FontFamily.gowunDodum: return 'GowunDodum-Regular';
      case FontFamily.gugi: return 'Gugi-Regular';
      case FontFamily.ibmPlexSansKRLight: return 'IBMPlexSansKR-Light';
      case FontFamily.inconsolata: return 'Inconsolata-VariableFont_wdth,wght';
      case FontFamily.kirangHaerang: return 'KirangHaerang-Regular';
      case FontFamily.nanumGothicCoding: return 'NanumGothicCoding-Regular';
      case FontFamily.notoSerifKR: return 'NotoSerifKR-VariableFont_wght';
      case FontFamily.novaMono: return 'NovaMono-Regular';
      case FontFamily.novaSquare: return 'NovaSquare-Regular';
      case FontFamily.permanentMarker: return 'PermanentMarker-Regular';
      case FontFamily.pixelifySans: return 'PixelifySans-VariableFont_wght';
      case FontFamily.sunflowerLight: return 'Sunflower-Light';
      case FontFamily.syneMono: return 'SyneMono-Regular';
    }
  }
}

class AppSettings extends Equatable {
  final ThemeMode themeMode;
  final bool keepScreenOn;
  final SliderPosition sliderPosition;
  final DisplayMode displayMode;
  final AmountDisplayMode amountDisplayMode;
  final bool blinkEnabled;
  final FontFamily fontFamily;
  final bool isHapticEnabled; // 🆕 햅틱 피드백 설정
  final bool isPortraitLocked; // 🆕 화면 회전 잠금 설정
  final bool hotEnabled; // 🔥 HOT 아이콘 on/off 설정

  const AppSettings({
    this.themeMode = ThemeMode.system,
    this.keepScreenOn = false,
    this.sliderPosition = SliderPosition.top,
    this.displayMode = DisplayMode.ticker,
    this.amountDisplayMode = AmountDisplayMode.number,
    this.blinkEnabled = true,
    this.fontFamily = FontFamily.pretendard,
    this.isHapticEnabled = true, // 🆕 기본값: 활성화
    this.isPortraitLocked = false, // 🆕 기본값: 자동 회전
    this.hotEnabled = true, // 🔥 기본값: 활성화
  });

  AppSettings copyWith({
    ThemeMode? themeMode,
    bool? keepScreenOn,
    SliderPosition? sliderPosition,
    DisplayMode? displayMode,
    AmountDisplayMode? amountDisplayMode,
    bool? blinkEnabled,
    FontFamily? fontFamily,
    bool? isHapticEnabled, // 🆕 추가
    bool? isPortraitLocked, // 🆕 추가
    bool? hotEnabled, // 🔥 HOT 설정 추가
  }) =>
      AppSettings(
        themeMode: themeMode ?? this.themeMode,
        keepScreenOn: keepScreenOn ?? this.keepScreenOn,
        sliderPosition: sliderPosition ?? this.sliderPosition,
        displayMode: displayMode ?? this.displayMode,
        amountDisplayMode: amountDisplayMode ?? this.amountDisplayMode,
        blinkEnabled: blinkEnabled ?? this.blinkEnabled,
        fontFamily: fontFamily ?? this.fontFamily,
        isHapticEnabled: isHapticEnabled ?? this.isHapticEnabled, // 🆕 추가
        isPortraitLocked: isPortraitLocked ?? this.isPortraitLocked, // 🆕 추가
        hotEnabled: hotEnabled ?? this.hotEnabled, // 🔥 HOT 설정 추가
      );

  @override
  List<Object?> get props => [
        themeMode,
        keepScreenOn,
        sliderPosition,
        displayMode,
        amountDisplayMode,
        blinkEnabled,
        fontFamily,
        isHapticEnabled, // 🆕 추가
        isPortraitLocked, // 🆕 추가
        hotEnabled, // 🔥 HOT 설정 추가
      ];
}