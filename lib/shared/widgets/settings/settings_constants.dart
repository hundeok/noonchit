// shared/widgets/settings/settings_constants.dart
import 'package:flutter/material.dart';
import '../../../domain/entities/app_settings.dart';

/// 🎨 설정 관련 색상 상수
class SettingsColors {
  static const Color primary = Colors.orange;
  static final Color border = Colors.grey.shade300;
  static final Color divider = Colors.grey.shade300;
  static final Color handle = Colors.grey.shade400;
  static final Color subtitle = Colors.grey.shade600;
  static const Color barrier = Colors.black54;
  static final Color shadow = Colors.black.withAlpha(26);
  static final Color primaryLight = Colors.orange.withAlpha(26);
  static final Color scrollThumb = Colors.orange.withAlpha(128);
  static const Color transparent = Colors.transparent;
}

/// 📏 설정 관련 크기 상수
class SettingsSizes {
  // 모달 크기
  static const double modalMargin = 8.0;
  static const double modalBorderRadius = 20.0;
  static const double handleWidth = 40.0;
  static const double handleHeight = 4.0;
  static const double handleBorderRadius = 2.0;
  
  // 카드 및 리스트
  static const double cardElevation = 2.0;
  static const double cardHeight = 80.0;
  static const double cardSpacing = 12.0;
  
  // 세그먼트
  static const double segmentBorderRadius = 8.0;
  static const double segmentItemBorderRadius = 6.0;
  static const double segmentIconSize = 16.0;
  static const double dividerWidth = 1.0;
  static const double dividerHeight = 40.0;
  
  // 스크롤바
  static const double scrollBarThickness = 6.4;
  static const double scrollBarRadius = 3.2;
  static const double scrollBarMinThumbLength = 40.0;
  
  // 레이아웃 높이
  static const double landscapeMaxHeight = 300.0;
  static const double landscapeMinHeight = 250.0;
  static const double portraitMaxHeight = 420.0;
  static const double landscapeHeightRatio = 0.65;
  static const double bottomSafetyPadding = 20.0;
}

/// 📝 설정 관련 패딩 상수
class SettingsPaddings {
  static const EdgeInsets modal = EdgeInsets.all(8);
  static const EdgeInsets header = EdgeInsets.symmetric(vertical: 12);
  static const EdgeInsets headerSpacing = EdgeInsets.only(left: 16, right: 20, top: 16, bottom: 16);
  static const EdgeInsets segment = EdgeInsets.symmetric(horizontal: 12, vertical: 8);
  static const EdgeInsets rowStart = EdgeInsets.only(left: 16);
  
  // 스페이싱
  static const SizedBox headerTop = SizedBox(height: 12);
  static const SizedBox iconText = SizedBox(width: 8);
  static const SizedBox segmentIcon = SizedBox(height: 2);
}

/// 🔤 설정 관련 텍스트 스타일 상수
class SettingsTextStyles {
  static const TextStyle title = TextStyle(
    fontSize: 19,
    fontWeight: FontWeight.bold,
  );
  
  static const TextStyle cardTitle = TextStyle(
    fontSize: 15, 
    fontWeight: FontWeight.bold,
  );
  
  static const TextStyle cardSubtitle = TextStyle(
    fontSize: 11,
  );
  
  static const TextStyle segmentLabel = TextStyle(
    fontSize: 11,
  );
  
  static const TextStyle segmentLabelSelected = TextStyle(
    fontSize: 11,
    color: Colors.orange, // SettingsColors.primary는 const가 아니라서 직접 사용
    fontWeight: FontWeight.bold,
  );
  
  static TextStyle segmentLabelUnselected = TextStyle(
    fontSize: 11,
    color: SettingsColors.subtitle, // shade는 const가 될 수 없음
    fontWeight: FontWeight.normal,
  );
}

/// 📋 설정 관련 문자열 상수
class SettingsStrings {
  static const String title = '설정';
  
  // 설정 항목 제목
  static const String theme = '테마';
  static const String coinDisplay = '코인명 표시';
  static const String amountDisplay = '금액 표시';
  static const String font = '폰트';
  static const String sliderPosition = '슬라이더 위치';
  static const String blinkEffect = '블링크 효과';
  static const String hotIcon = 'HOT 아이콘';
  static const String keepScreenOn = '화면 항상 켜기';
  static const String hapticFeedback = '햅틱 피드백';
  static const String portraitLock = '세로 모드 고정';
  static const String clearCache = '캐시 비우기';
  static const String resetSettings = '설정 초기화';
  static const String appInfo = '앱 정보';
  
  // 세그먼트 라벨
  static const String ticker = '티커';
  static const String korean = '한글';
  static const String english = '영문';
  static const String number = '숫자';
  static const String icon = '아이콘';
  static const String clear = '비우기';
  static const String reset = '초기화';
  static const String info = '정보';
  
  // 설명 텍스트
  static const String cacheDescription = '임시 데이터를 삭제합니다';
  static const String resetDescription = '모든 설정을 기본값으로 되돌립니다';
  static const String appInfoDescription = '버전 정보 및 개발자 정보를 확인합니다';
  
  // 다이얼로그
  static const String clearCacheTitle = '캐시 비우기';
  static const String clearCacheContent = '임시 데이터를 삭제하시겠습니까?\n앱 성능이 향상될 수 있습니다.';
  static const String resetSettingsTitle = '설정 초기화';
  static const String resetSettingsContent = '모든 설정을 기본값으로 되돌리시겠습니까?\n이 작업은 되돌릴 수 없습니다.';
  static const String cancel = '취소';
  static const String delete = '삭제';
  static const String resetAction = '초기화';
  
  // 스낵바
  static const String cacheCleared = '캐시가 삭제되었습니다';
  static const String settingsReset = '설정이 초기화되었습니다';
}

/// 📱 설정 아이콘 상수
class SettingsIcons {
  static const IconData settings = Icons.settings;
  static const IconData palette = Icons.palette;
  static const IconData monetization = Icons.monetization_on;
  static const IconData wallet = Icons.account_balance_wallet;
  static const IconData font = Icons.font_download;
  static const IconData tune = Icons.tune;
  static const IconData autoAwesome = Icons.auto_awesome;
  static const IconData localFire = Icons.local_fire_department;
  static const IconData screenLock = Icons.screen_lock_rotation;
  static const IconData vibration = Icons.vibration;
  static const IconData screenRotation = Icons.screen_rotation_outlined;
  static const IconData cleaningServices = Icons.cleaning_services;
  static const IconData restore = Icons.restore;
  static const IconData infoOutline = Icons.info_outline;
  
  // 세그먼트 아이콘
  static const IconData code = Icons.code;
  static const IconData language = Icons.language;
  static const IconData translate = Icons.translate;
  static const IconData formatListNumbered = Icons.format_list_numbered;
}

/// 🔧 설정 헬퍼 함수들
class SettingsHelpers {
  /// 테마 모드 설명 텍스트
  static String getThemeDescription(ThemeMode themeMode) {
    switch (themeMode) {
      case ThemeMode.system:
        return '시스템 설정에 따라 테마가 결정됩니다';
      case ThemeMode.light:
        return '밝은 테마가 적용됩니다';
      case ThemeMode.dark:
        return '어두운 테마가 적용됩니다';
    }
  }

  /// 표시 모드 설명 텍스트
  static String getDisplayModeDescription(DisplayMode mode) {
    switch (mode) {
      case DisplayMode.ticker:
        return 'BTC, ETH, XRP 형식으로 표시됩니다';
      case DisplayMode.korean:
        return '비트코인, 이더리움, 리플 형식으로 표시됩니다';
      case DisplayMode.english:
        return 'Bitcoin, Ethereum, Ripple 형식으로 표시됩니다';
    }
  }

  /// 금액 표시 모드 설명 텍스트
  static String getAmountDisplayModeDescription(AmountDisplayMode mode) {
    switch (mode) {
      case AmountDisplayMode.number:
        return '금액 숫자로 표시됩니다';
      case AmountDisplayMode.icon:
        return '💵 아이콘으로 표시됩니다';
    }
  }

  /// 폰트 설명 텍스트
  static String getFontDescription(FontFamily fontFamily) {
    return '${fontFamily.fontName} 폰트가 적용됩니다';
  }

  /// 슬라이더 위치 설명 텍스트
  static String getSliderPositionDescription(SliderPosition position) {
    return position == SliderPosition.top
        ? '슬라이더를 화면 상단에 표시합니다'
        : '슬라이더를 화면 하단에 표시합니다';
  }

  /// 블링크 효과 설명 텍스트
  static String getBlinkDescription(bool enabled) {
    return enabled
        ? '가격 변동 시 블링크 효과가 표시됩니다'
        : '블링크 효과가 비활성화됩니다';
  }

  /// HOT 아이콘 설명 텍스트
  static String getHotIconDescription(bool enabled) {
    return enabled
        ? '급상승 종목에 HOT 아이콘이 표시됩니다'
        : 'HOT 아이콘이 비활성화됩니다';
  }

  /// 화면 항상 켜기 설명 텍스트
  static String getKeepScreenDescription(bool enabled) {
    return enabled
        ? '화면이 자동으로 꺼지지 않습니다'
        : '시스템 설정에 따라 화면이 꺼집니다';
  }

  /// 햅틱 피드백 설명 텍스트
  static String getHapticDescription(bool enabled) {
    return enabled
        ? '터치 시 진동 피드백이 활성화됩니다'
        : '진동 피드백이 비활성화됩니다';
  }

  /// 세로 모드 고정 설명 텍스트
  static String getPortraitLockDescription(bool locked) {
    return locked
        ? '화면이 세로 모드로 고정됩니다'
        : '화면 회전이 자동으로 전환됩니다';
  }
}