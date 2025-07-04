// ===== lib/domain/usecases/filter_params.dart =====
import '../entities/signal.dart'; // PatternType import 추가

class FilterParams {
  final double? minChangePercent;
  final double? maxChangePercent;
  final double? minTradeAmount;
  final double? maxTradeAmount;
  final Set<PatternType>? patternTypes; // ✅ 수정: 올바른 import
  final Duration? timeWindow;
  final double? minSeverityScore;

  const FilterParams({
    this.minChangePercent,
    this.maxChangePercent,
    this.minTradeAmount,
    this.maxTradeAmount,
    this.patternTypes, // ✅ 수정: 올바른 import
    this.timeWindow,
    this.minSeverityScore,
  });

  FilterParams copyWith({
    double? minChangePercent,
    double? maxChangePercent,
    double? minTradeAmount,
    double? maxTradeAmount,
    Set<PatternType>? patternTypes, // ✅ 수정: 올바른 import
    Duration? timeWindow,
    double? minSeverityScore,
  }) {
    return FilterParams(
      minChangePercent: minChangePercent ?? this.minChangePercent,
      maxChangePercent: maxChangePercent ?? this.maxChangePercent,
      minTradeAmount: minTradeAmount ?? this.minTradeAmount,
      maxTradeAmount: maxTradeAmount ?? this.maxTradeAmount,
      patternTypes: patternTypes ?? this.patternTypes,
      timeWindow: timeWindow ?? this.timeWindow,
      minSeverityScore: minSeverityScore ?? this.minSeverityScore,
    );
  }
}
