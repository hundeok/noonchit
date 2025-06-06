// lib/domain/usecases/trade_usecase.dart

import 'dart:async';
import '../../core/error/app_exception.dart';
import '../../core/extensions/result.dart';
import '../entities/trade.dart';
import '../repositories/trade_repository.dart';

/// Trade 관련 비즈니스 로직을 제공하는 UseCase
class TradeUsecase {
  final TradeRepository _repository;

  TradeUsecase(this._repository);

  /// threshold와 markets를 기준으로 필터링된 거래 목록 스트림 반환
  Stream<Result<List<Trade>, AppException>> filterTrades(
    double threshold,
    List<String> markets,
  ) {
    return _repository
        .watchFilteredTrades(threshold, markets)
        .transform(_wrap<List<Trade>>('Filter trades failed'));
  }

  /// 집계된 거래 스트림 반환
  Stream<Result<Trade, AppException>> aggregateTrades() {
    return _repository
        .watchAggregatedTrades()
        .transform(_wrap<Trade>('Aggregate trades failed'));
  }

  StreamTransformer<T, Result<T, AppException>> _wrap<T>(String errorMsg) {
    return StreamTransformer.fromHandlers(
      handleData: (data, sink) => sink.add(Ok(data)),
      handleError: (error, stack, sink) =>
          sink.add(Err(AppException('$errorMsg: $error'))),
    );
  }
}