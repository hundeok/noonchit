import 'dart:async';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../core/config/app_config.dart';
import '../../core/di/trade_provider.dart'; // usecaseProvider, repoProvider
import '../../core/error/app_exception.dart';
import '../../core/extensions/result.dart';
import '../../domain/entities/trade.dart';
import '../../domain/usecases/trade_usecase.dart';

/// 화면 상태를 캡슐화하는 immutable 모델
class TradeState {
  final List<Trade> trades;
  final bool isLoading;
  final bool isConnected;
  final double threshold;
  final int selectedIndex;
  final String? errorMessage;

  const TradeState({
    this.trades = const [],
    this.isLoading = false,
    this.isConnected = false,
    this.threshold = 20000000,
    this.selectedIndex = 0,
    this.errorMessage,
  });

  TradeState copyWith({
    List<Trade>? trades,
    bool? isLoading,
    bool? isConnected,
    double? threshold,
    int? selectedIndex,
    String? errorMessage,
  }) {
    return TradeState(
      trades: trades ?? this.trades,
      isLoading: isLoading ?? this.isLoading,
      isConnected: isConnected ?? this.isConnected,
      threshold: threshold ?? this.threshold,
      selectedIndex: selectedIndex ?? this.selectedIndex,
      errorMessage: errorMessage,
    );
  }
}

/// Trade 화면 전용 ViewModel
class TradeController extends StateNotifier<TradeState> {
  final TradeUsecase _usecase;
  final Ref _ref;  // 🔥 추가: Repository 접근을 위한 ref
  StreamSubscription<Result<List<Trade>, AppException>>? _subscription;

  TradeController(this._usecase, this._ref) : super(const TradeState());  // 🔥 수정: ref 매개변수 추가

  /// 임계값 및 인덱스 설정 후 스트림 구독
  void setThreshold(double threshold, int index, List<String> markets) {
    // 🔥 추가: Repository의 updateThreshold 호출 (핵심 누락 부분)
    final repository = _ref.read(repoProvider);
    repository.updateThreshold(threshold);
    
    state = state.copyWith(
      threshold: threshold,
      selectedIndex: index,
      isLoading: true,
      errorMessage: null,
    );
    _subscription?.cancel();
    _subscription = _usecase
        .filterTrades(threshold, markets)
        .listen(_handleResult);
  }

  void _handleResult(Result<List<Trade>, AppException> result) {
    result.when(
      ok: (trades) {
        state = state.copyWith(
          trades: trades,
          isLoading: false,
          isConnected: true,
          errorMessage: null,
        );
      },
      err: (e) {
        state = state.copyWith(
          isLoading: false,
          isConnected: false,
          errorMessage: e.message,
        );
      },
    );
  }

  /// 재연결/새로고침: markets만 받아서 내부적으로 setThreshold 호출
  void refresh(List<String> markets) {
    setThreshold(state.threshold, state.selectedIndex, markets);
  }

  /// 거래 목록 추가 필터 (시장명)
  List<Trade> filterByMarket(String? marketFilter) {
    if (marketFilter == null || marketFilter.isEmpty) {
      return state.trades;
    }
    final upper = marketFilter.toUpperCase();
    return state.trades.where((t) => t.market.contains(upper)).toList();
  }

  /// 거래 목록 정렬
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

  /// 거래 목록 필터링/정렬 적용
  List<Trade> apply(List<Trade> trades) {
    // 현재 threshold로 필터링
    final filtered = trades.where((trade) => trade.total >= state.threshold).toList();
    // 기본 정렬 (timestampMs 내림차순)
    filtered.sort((a, b) => b.timestampMs.compareTo(a.timestampMs));
    return filtered;
  }

  /// 사용 가능한 임계값 옵션들
  List<double> get availableThresholds =>
    AppConfig.tradeFilters.where((f) => f >= 20000000).toList();

  @override
  void dispose() {
    _subscription?.cancel();
    super.dispose();
  }
}

/// Provider 선언
final tradeControllerProvider =
    StateNotifierProvider<TradeController, TradeState>((ref) {
  final usecase = ref.read(usecaseProvider);
  return TradeController(usecase, ref);  // 🔥 수정: ref도 함께 전달
});