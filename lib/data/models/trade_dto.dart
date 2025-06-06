// lib/data/models/trade_dto.dart

import 'dart:convert';
import 'package:hive/hive.dart';
import '../../domain/entities/trade.dart';
import '../../core/utils/logger.dart';

part 'trade_dto.g.dart';

@HiveType(typeId: 0)
class TradeDto {
  @HiveField(0)
  final String market;

  @HiveField(1)
  final double price;

  @HiveField(2)
  final double volume;

  @HiveField(3)
  final String side;

  @HiveField(4)
  final double changePrice;

  @HiveField(5)
  final String changeState;

  @HiveField(6)
  final int timestampMs;

  @HiveField(7)
  final String sequentialId;

  TradeDto({
    required this.market,
    required this.price,
    required this.volume,
    required this.side,
    required this.changePrice,
    required this.changeState,
    required this.timestampMs,
    required this.sequentialId,
  });

  Trade toEntity() => Trade(
        market: market,
        price: price,
        volume: volume,
        side: side,
        changePrice: changePrice,
        changeState: changeState,
        timestampMs: timestampMs,
        sequentialId: sequentialId,
      );

  /// JSON 직렬화용 맵 변환 (camelCase 키 사용으로 시스템 통일)
  Map<String, dynamic> toMap() => {
        'market': market,
        'price': price,
        'volume': volume,
        'side': side,
        'changePrice': changePrice,
        'changeState': changeState,
        'timestampMs': timestampMs,
        'sequentialId': sequentialId,
      };

  /// JSON 문자열 직렬화
  String toJson() => json.encode(toMap());

  /// JSON 파싱 (여러 키 네이밍 지원)
  static TradeDto? tryParse(Map<String, dynamic> m) {
    try {
      if (m.isEmpty) return null;
      log.d('TradeDto.tryParse: ${m.toString().substring(0, m.toString().length.clamp(0, 100))}');

      String parseString(dynamic v, [String fallback = '']) =>
          v != null ? v.toString() : fallback;

      double parseDouble(dynamic v) {
        if (v is num) return v.toDouble();
        final str = v?.toString().trim() ?? '';
        return str.isNotEmpty ? double.tryParse(str) ?? 0.0 : 0.0;
      }

      int parseInt(dynamic v) {
        if (v is int) return v;
        final str = v?.toString().trim() ?? '';
        return str.isNotEmpty ? int.tryParse(str) ?? DateTime.now().millisecondsSinceEpoch
                              : DateTime.now().millisecondsSinceEpoch;
      }

      final market = parseString(m['market'] ?? m['symbol'] ?? m['code'], 'UNKNOWN');
      final price = parseDouble(m['price'] ?? m['trade_price']);
      final volume = parseDouble(m['volume'] ?? m['trade_volume']);
      final side = parseString(m['side'] ?? m['ask_bid'], 'UNKNOWN');

      final changePrice = parseDouble(m['changePrice'] ?? m['change_price']);
      final changeState = parseString(m['changeState'] ?? m['change_state'], 'EVEN');
      final timestamp = parseInt(m['timestampMs'] ?? m['timestamp_ms'] ?? m['timestamp']);
      final sequentialId = parseString(
        m['sequentialId'] ?? m['sequential_id'] ?? m['sid'], 
        timestamp.toString(),
      );

      return TradeDto(
        market: market,
        price: price,
        volume: volume,
        side: side,
        changePrice: changePrice,
        changeState: changeState,
        timestampMs: timestamp,
        sequentialId: sequentialId,
      );
    } catch (e) {
      log.w('TradeDto.tryParse error: $e');
      return null;
    }
  }

  /// JSON 문자열로부터 객체 생성
  factory TradeDto.fromJson(String src) =>
      tryParse(json.decode(src) as Map<String, dynamic>) ??
      TradeDto(
        market: 'ERROR',
        price: 0.0,
        volume: 0.0,
        side: 'UNKNOWN',
        changePrice: 0.0,
        changeState: 'UNKNOWN',
        timestampMs: DateTime.now().millisecondsSinceEpoch,
        sequentialId: 'ERROR',
      );
}
