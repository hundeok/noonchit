// lib/presentation/controllers/market_mood_controller.dart
// 🎮 Presentation Layer: Market Mood 컨트롤러 (리팩토링된 Provider에 맞춰 수정)

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../core/di/app_providers.dart';
import '../../core/utils/date_time.dart';
import '../pages/market_mood_page.dart';

/// 🎮 마켓무드 페이지 컨트롤러
class MarketMoodPageController extends StateNotifier<MarketMoodPageState> {
  final Ref _ref;

  MarketMoodPageController(this._ref) : super(MarketMoodPageState.initial()) {
    // [수정] 초기화 로직을 생성자에서 분리하여 명확하게 관리
    _initialize();
  }

  /// [수정] 초기화 및 실시간 리스닝 시작
  void _initialize() {
    // 1. 초기 상태 설정
    final initialState = _ref.read(marketMoodSystemProvider);
    state = state.copyWith(
      isLoading: initialState.isLoading,
      error: initialState.hasError ? '데이터 로딩 중 오류 발생' : null,
      systemState: initialState,
    );

    // 2. 실시간 상태 변화 감지 및 동기화
    //    이제 최종 상태인 marketMoodSystemProvider만 listen하면 됩니다.
    _ref.listen<MarketMoodSystemState>(
      marketMoodSystemProvider,
      (previous, next) {
        state = state.copyWith(
          isLoading: next.isLoading,
          error: next.hasError ? '데이터 로딩 중 오류 발생' : null,
          systemState: next,
        );
      },
    );
  }

  /// [수정] 데이터 로드 메서드 제거 -> _initialize()로 통합
  // Future<void> loadData() async { ... }

  /// 수동 새로고침
  void refresh() {
    // [수정] controller를 인스턴스 변수로 두지 않고 필요 시 read
    final controller = _ref.read(marketMoodControllerProvider);
    controller.refresh();
  }

  /// [수정] 현재 마켓무드 조회 (동기식으로 변경)
  MarketMood getCurrentMood() {
    // .when()을 사용할 필요 없이 직접 값을 반환합니다.
    return _ref.read(currentMarketMoodProvider);
  }

  /// 환율 조회 (Future 대응 - 이 부분은 변경 없음)
  Future<double> getExchangeRate() async {
    final exchangeAsync = _ref.read(exchangeRateProvider);
    return exchangeAsync.when(
      data: (rate) => rate,
      loading: () => 1400.0,
      error: (_, __) => 1400.0,
    );
  }

  /// [수정] 볼륨 비교 데이터 조회 (동기식으로 변경)
  ComparisonData getVolumeComparisons() {
    // .when()을 사용할 필요 없이 직접 값을 반환합니다.
    return _ref.read(volumeComparisonProvider);
  }

  /// 시스템 헬스체크
  Future<void> checkSystemHealth() async {
    try {
      final controller = _ref.read(marketMoodControllerProvider);
      final health = await controller.getSystemHealth();

      state = state.copyWith(
        systemHealth: health,
        lastHealthCheck: DateTime.now(),
      );
    } catch (e) {
      state = state.copyWith(error: e.toString());
    }
  }

  /// 환율 새로고침
  Future<void> refreshExchangeRate() async {
    try {
      final controller = _ref.read(marketMoodControllerProvider);
      await controller.refreshExchangeRate();
      // loadData() 대신 systemProvider가 자동으로 갱신하므로 별도 호출 불필요
    } catch (e) {
      state = state.copyWith(error: e.toString());
    }
  }

  /// 시스템 상태 로깅
  Future<void> logSystemStatus() async {
    try {
      final controller = _ref.read(marketMoodControllerProvider);
      await controller.logSystemStatus();
    } catch (e) {
      state = state.copyWith(error: e.toString());
    }
  }

  /// 분위기 이모지 조회
  String getMoodEmoji(MarketMood mood) {
    return switch (mood) {
      MarketMood.bull => '🚀',
      MarketMood.weakBull => '🔥',
      MarketMood.sideways => '⚖️',
      MarketMood.bear => '💧',
      MarketMood.deepBear => '🧊',
    };
  }

  /// 분위기 이름 조회
  String getMoodName(MarketMood mood) {
    return switch (mood) {
      MarketMood.bull => '불장',
      MarketMood.weakBull => '약불장',
      MarketMood.sideways => '중간장',
      MarketMood.bear => '물장',
      MarketMood.deepBear => '얼음장',
    };
  }

  /// [수정] 분위기 요약 텍스트 조회 (동기식으로 변경)
  String getMoodSummary() {
    // .when()을 사용할 필요 없이 직접 값을 반환합니다.
    return _ref.read(marketMoodSummaryProvider);
  }

  /// 볼륨 포맷팅 (한국 원화)
  Future<String> formatVolume(double volumeUsd) async {
    final rate = await getExchangeRate();
    final volumeKrw = volumeUsd * rate;

    if (volumeKrw >= 1e12) {
      final trillions = (volumeKrw / 1e12).toStringAsFixed(0);
      return '${_addCommas(trillions)}조원';
    }
    if (volumeKrw >= 1e8) {
      final hundreds = (volumeKrw / 1e8).toStringAsFixed(0);
      return '${_addCommas(hundreds)}억원';
    }
    return '${(volumeKrw / 1e8).toStringAsFixed(1)}억원';
  }

  /// 시가총액 포맷팅 (한국 원화)
  Future<String> formatMarketCap(double marketCapUsd) async {
    final rate = await getExchangeRate();
    // [수정] marketCapKrw 변수 선언
    final marketCapKrw = marketCapUsd * rate; 

    // [수정] volumeKrw -> marketCapKrw로 변경
    if (marketCapKrw >= 1e12) { 
      final trillions = (marketCapKrw / 1e12).toStringAsFixed(0);
      return '${_addCommas(trillions)}조원';
    }
    // [수정] volumeKrw -> marketCapKrw로 변경
    if (marketCapKrw >= 1e8) {
      final hundreds = (marketCapKrw / 1e8).toStringAsFixed(0);
      return '${_addCommas(hundreds)}억원';
    }
    // [수정] volumeKrw -> marketCapKrw로 변경
    return '${(marketCapKrw / 1e8).toStringAsFixed(1)}억원';
  }

  /// 업데이트 시간 포맷팅
  String formatUpdateTime(DateTime updatedAt) {
    return updatedAt.hhmmss(); // DateTime extension 사용
  }

  /// 비교 결과 값 포맷팅
  String formatComparisonValue(ComparisonResult result) {
    if (result.isReady && result.changePercent != null) {
      final value = result.changePercent!;
      final arrow = value > 5 ? '↗️' : value < -5 ? '↘️' : '➡️';
      return '${value >= 0 ? '+' : ''}${value.toStringAsFixed(1)}% $arrow';
    }
    return '${(result.progressPercent * 100).round()}% (${result.status})';
  }

  /// 진행률 계산
  int getProgressPercent(ComparisonResult result) {
    return (result.progressPercent * 100).round();
  }

  /// 하이라이트 색상 판단
  bool isHighlight(ComparisonResult result) {
    return result.isReady && (result.changePercent ?? 0) > 5;
  }

  /// 경고 색상 판단
  bool isWarning(ComparisonResult result) {
    return result.isReady && (result.changePercent ?? 0) < -5;
  }

  /// [수정] 데이터 스트림 리스닝 메서드 제거 -> _initialize()로 통합
  // void startListening() { ... }

  /// 숫자에 콤마 추가
  String _addCommas(String numberStr) {
    final parts = numberStr.split('.');
    final integerPart = parts[0];
    final reversedInteger = integerPart.split('').reversed.join('');
    final withCommas = reversedInteger
        .replaceAllMapped(RegExp(r'.{3}'), (match) => '${match.group(0)},')
        .split('')
        .reversed
        .join('');
    final result =
        withCommas.startsWith(',') ? withCommas.substring(1) : withCommas;
    return parts.length > 1 ? '$result.${parts[1]}' : result;
  }
}

/// 🎮 마켓무드 페이지 상태
class MarketMoodPageState {
  final bool isLoading;
  final String? error;
  final MarketMoodSystemState? systemState;
  final Map<String, dynamic>? systemHealth;
  final DateTime? lastHealthCheck;

  const MarketMoodPageState({
    required this.isLoading,
    this.error,
    this.systemState,
    this.systemHealth,
    this.lastHealthCheck,
  });

  factory MarketMoodPageState.initial() {
    return const MarketMoodPageState(isLoading: true); // [수정] 초기 상태는 로딩중
  }

  MarketMoodPageState copyWith({
    bool? isLoading,
    String? error,
    MarketMoodSystemState? systemState,
    Map<String, dynamic>? systemHealth,
    DateTime? lastHealthCheck,
  }) {
    return MarketMoodPageState(
      isLoading: isLoading ?? this.isLoading,
      error: error, // [수정] null로 덮어쓰기 가능하도록 ?? this.error 제거
      systemState: systemState ?? this.systemState,
      systemHealth: systemHealth ?? this.systemHealth,
      lastHealthCheck: lastHealthCheck ?? this.lastHealthCheck,
    );
  }
}

/// 🎮 마켓무드 페이지 컨트롤러 Provider
final marketMoodPageControllerProvider = StateNotifierProvider.autoDispose<
    MarketMoodPageController, MarketMoodPageState>((ref) {
  // [수정] 컨트롤러 생성 시 바로 _initialize()가 호출되므로 별도 로직 불필요
  return MarketMoodPageController(ref);
});

/// 🎮 모달 오버레이 관리자 (실제 MarketMoodPage 사용)
class MarketMoodModalManager {
  static OverlayEntry? _overlayEntry;

  /// 모달 표시
  static void show({
    required BuildContext context,
    required WidgetRef ref,
    required Offset position,
    required double statusIconSize,
    required MarketMoodData data,
  }) {
    hide(); // 기존 모달 제거

    _overlayEntry = OverlayEntry(
      builder: (context) => MarketMoodModalOverlay(
        position: position,
        statusIconSize: statusIconSize,
        ref: ref,
        data: data,
      ),
    );

    Overlay.of(context).insert(_overlayEntry!);
  }

  /// 모달 숨기기
  static void hide() {
    _overlayEntry?.remove();
    _overlayEntry = null;
  }
}

/// 🎮 모달 오버레이 (실제 MarketMoodPage 사용)
class MarketMoodModalOverlay extends StatelessWidget {
  final Offset position;
  final double statusIconSize;
  final WidgetRef ref;
  final MarketMoodData data;

  const MarketMoodModalOverlay({
    super.key,
    required this.position,
    required this.statusIconSize,
    required this.ref,
    required this.data,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: () => MarketMoodModalManager.hide(),
      behavior: HitTestBehavior.translucent,
      child: Material(
        color: Colors.transparent,
        child: Stack(
          children: [
            // 투명 배경
            Positioned.fill(
              child: Container(color: Colors.transparent),
            ),
            // 실제 MarketMoodPage 위젯
            Positioned(
              left: position.dx,
              top: position.dy,
              child: Consumer(
                builder: (context, ref, child) {
                  return MarketMoodPage(
                    statusIconSize: statusIconSize,
                    data: data,
                  );
                },
              ),
            ),
          ],
        ),
      ),
    );
  }
}