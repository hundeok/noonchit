// lib/presentation/controllers/trade_controller.dart
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../core/di/trade_provider.dart';
import '../../core/common/time_frame_types.dart'; // 🔥 공통 타입 시스템 사용
import '../../domain/entities/trade.dart';
import '../../domain/usecases/trade_usecase.dart';

/// 🎯 신버전 맞춤 TradeController (TradeFilter/TradeMode Enum 기반)
class TradeController extends StateNotifier<TradeControllerState> {
  final Ref _ref;
  final TradeUsecase _usecase;
  
  // ✅ Provider 구독 관리
  final List<ProviderSubscription> _subscriptions = [];

  TradeController(this._usecase, this._ref) : super(const TradeControllerState()) {
    // ✅ 데이터 구독 초기화
    _initializeDataSubscription();
  }

  /// ✅ 데이터 구독 초기화 (신버전 Provider 이름 사용)
  void _initializeDataSubscription() {
    final subscription = _ref.listen(
      tradeListProvider, // ✅ 신버전 Provider 유지
      (previous, next) {
        next.when(
          data: (trades) => _processTradeData(trades),
          loading: () => state = state.copyWith(isLoading: true),
          error: (error, _) => state = state.copyWith(
            errorMessage: error.toString(),
            isLoading: false,
          ),
        );
      },
    );
    _subscriptions.add(subscription);
  }

  /// ✅ 거래 데이터 처리
  void _processTradeData(List<Trade> trades) {
    // 1. 데이터 정렬 (신버전은 이미 reverse 처리됨)
    final sortedTrades = trades; // 신버전에서는 이미 최신순 정렬됨
    
    // 2. 상태 업데이트
    state = state.copyWith(
      trades: sortedTrades,
      isLoading: false,
      errorMessage: null,
    );
  }

  /// ✅ 임계값 설정 - 신버전 TradeFilter 기반
  void setThreshold(TradeFilter filter) {
    final controller = _ref.read(tradeThresholdController);
    
    // 신버전 updateThreshold 사용
    final index = controller.availableFilters.indexOf(filter);
    controller.updateThreshold(filter, index);
    
    // ✅ UI 상태 업데이트
    state = state.copyWith(
      currentFilter: filter,
      selectedIndex: index,
    );
  }

  /// ✅ 구간/누적 모드 토글 - 신버전 TradeMode 기반
  void setMode(TradeMode mode) {
    final controller = _ref.read(tradeThresholdController);
    
    // 신버전 updateMode 사용
    controller.updateMode(mode);
    
    // ✅ UI 상태 업데이트
    state = state.copyWith(currentMode: mode);
  }

  /// ✅ 편의 메서드: 모드 토글
  void toggleMode() {
    final currentMode = state.currentMode;
    final newMode = currentMode.isAccumulated ? TradeMode.range : TradeMode.accumulated;
    setMode(newMode);
  }

  /// ✅ 현재 설정에 따른 표시 텍스트 생성 (신버전 기반)
  String getThresholdDisplayText() {
    final filter = state.currentFilter;
    final mode = state.currentMode;
    final availableFilters = this.availableFilters;
    
    if (mode.isRange) {
      // 구간 모드
      final currentIndex = availableFilters.indexOf(filter);
      if (currentIndex >= 0 && currentIndex < availableFilters.length - 1) {
        final nextFilter = availableFilters[currentIndex + 1];
        return '금액 레인지: ${filter.displayName} ~ ${nextFilter.displayName}';
      } else {
        return '금액 레인지: ${filter.displayName} 이상';
      }
    } else {
      // 누적 모드
      return '최소 거래금액: ${filter.displayName}';
    }
  }

  /// ✅ 토글 버튼 텍스트 (신버전 기반)
  String get toggleButtonText => state.currentMode.displayName;

  /// ✅ 사용 가능한 필터 옵션들 (신버전 기반)
  List<TradeFilter> get availableFilters => TradeConfig.supportedFilters;

  /// ✅ 거래 목록 추가 필터 (시장명)
  List<Trade> filterByMarket(String? marketFilter) {
    if (marketFilter == null || marketFilter.isEmpty) {
      return state.trades;
    }
    
    final upper = marketFilter.toUpperCase();
    return state.trades.where((t) => t.market.contains(upper)).toList();
  }

  /// ✅ 거래 목록 정렬
  void sortTrades(String field, bool ascending) {
    final list = [...state.trades];
    
    list.sort((a, b) {
      dynamic aValue;
      dynamic bValue;
      
      switch (field) {
        case 'market':
          aValue = a.market;
          bValue = b.market;
          break;
        case 'price':
          aValue = a.price;
          bValue = b.price;
          break;
        case 'volume':
          aValue = a.volume;
          bValue = b.volume;
          break;
        case 'total':
          aValue = a.total;
          bValue = b.total;
          break;
        case 'timestamp':
          aValue = a.timestampMs;
          bValue = b.timestampMs;
          break;
        default:
          aValue = a.timestampMs;
          bValue = b.timestampMs;
      }
      
      final cmp = aValue is Comparable && bValue is Comparable
          ? aValue.compareTo(bValue)
          : 0;
      return ascending ? cmp : -cmp;
    });
    
    state = state.copyWith(trades: list);
  }

  /// ✅ 호환성 메서드들 (기존 UI 코드와의 호환성을 위해)
  void setThresholdByValue(double value, int index) {
    final filter = TradeFilter.fromValue(value);
    setThreshold(filter);
  }

  void toggleRangeMode() {
    toggleMode();
  }

  /// ✅ 현재 상태 조회 메서드들
  TradeFilter get currentFilter => state.currentFilter;
  TradeMode get currentMode => state.currentMode;
  double get currentThreshold => state.currentFilter.value;
  bool get isRangeMode => state.currentMode.isRange;

  /// ✅ 리소스 정리
  @override
  void dispose() {
    // Provider 구독 해제
    for (final subscription in _subscriptions) {
      subscription.close();
    }
    _subscriptions.clear();
    super.dispose();
  }
}

/// ✅ 상태 클래스 (신버전 Enum 기반)
class TradeControllerState {
  final List<Trade> trades; // 표시용 거래 데이터
  final bool isLoading; // 로딩 상태
  final TradeFilter currentFilter; // 현재 필터 (신버전)
  final TradeMode currentMode; // 현재 모드 (신버전)
  final int selectedIndex; // 슬라이더 인덱스
  final String? errorMessage; // 에러 메시지

  const TradeControllerState({
    this.trades = const [],
    this.isLoading = false,
    this.currentFilter = TradeFilter.min20M, // 신버전 기본값
    this.currentMode = TradeMode.accumulated, // 신버전 기본값
    this.selectedIndex = 0,
    this.errorMessage,
  });

  TradeControllerState copyWith({
    List<Trade>? trades,
    bool? isLoading,
    TradeFilter? currentFilter,
    TradeMode? currentMode,
    int? selectedIndex,
    String? errorMessage,
  }) {
    return TradeControllerState(
      trades: trades ?? this.trades,
      isLoading: isLoading ?? this.isLoading,
      currentFilter: currentFilter ?? this.currentFilter,
      currentMode: currentMode ?? this.currentMode,
      selectedIndex: selectedIndex ?? this.selectedIndex,
      errorMessage: errorMessage ?? this.errorMessage,
    );
  }

  // ✅ 호환성을 위한 getter들
  double get threshold => currentFilter.value;
  bool get isRangeMode => currentMode.isRange;
}

/// ✅ Provider 선언 (신버전 기반)
final tradeControllerProvider = StateNotifierProvider<TradeController, TradeControllerState>(
  (ref) {
    final usecase = ref.read(usecaseProvider); // ✅ 신버전 Provider 사용
    return TradeController(usecase, ref);
  },
);