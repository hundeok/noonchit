// lib/data/models/market_mood_dto.dart
// 🌐 Data Layer: 통합 DTO 모델 (Trade 스타일)

import 'dart:convert';
import 'package:hive/hive.dart';
import '../../core/utils/date_time.dart'; // DateTime extension
import '../../core/utils/logger.dart';
import '../../domain/entities/market_mood.dart';

part 'market_mood_dto.g.dart';

/// 📈 인트라데이 볼륨 데이터 (30분 단위) - Hive 모델
@HiveType(typeId: 1) // TradeDto가 typeId: 0 사용하므로 1 사용
class TimestampedVolume extends HiveObject {
  @HiveField(0)
  final DateTime timestamp;

  @HiveField(1)
  final double volumeUsd;

  TimestampedVolume({
    required this.timestamp,
    required this.volumeUsd,
  });

  /// Domain Entity로 변환
  VolumeData toEntity() => VolumeData(
    timestamp: timestamp,
    volumeUsd: volumeUsd,
  );

  /// Domain Entity에서 생성
  factory TimestampedVolume.fromEntity(VolumeData entity) => TimestampedVolume(
    timestamp: entity.timestamp,
    volumeUsd: entity.volumeUsd,
  );

  /// JSON 직렬화용 맵 변환
  Map<String, dynamic> toMap() => {
    'timestamp': timestamp.toIso8601String(),
    'volumeUsd': volumeUsd,
  };

  /// JSON 문자열 직렬화
  String toJson() => json.encode(toMap());

  /// JSON 파싱
  static TimestampedVolume? tryParse(Map<String, dynamic> m) {
    try {
      if (m.isEmpty) return null;

      final timestampStr = m['timestamp']?.toString() ?? '';
      final volumeUsd = (m['volumeUsd'] as num?)?.toDouble() ?? 0.0;

      if (timestampStr.isEmpty) return null;

      return TimestampedVolume(
        timestamp: DateTime.parse(timestampStr),
        volumeUsd: volumeUsd,
      );
    } catch (e) {
      log.w('TimestampedVolume.tryParse error: $e');
      return null;
    }
  }

  /// JSON 문자열로부터 객체 생성
  factory TimestampedVolume.fromJson(String src) =>
      tryParse(json.decode(src) as Map<String, dynamic>) ??
      TimestampedVolume(
        timestamp: DateTime.now(),
        volumeUsd: 0.0,
      );

  /// DateTime extension 활용
  String get formattedTime => timestamp.yyyyMMddhhmm();
  String get timeAgoText => timestamp.timeAgo();
  String get shortTime => timestamp.hhmmss();

  @override
  String toString() => 'TimestampedVolume($formattedTime, ${volumeUsd.toStringAsFixed(2)}B)';
}

/// 🌐 CoinGecko 글로벌 마켓 데이터 DTO
@HiveType(typeId: 2)
class CoinGeckoGlobalDataDto extends HiveObject {
  @HiveField(0)
  final double totalMarketCapUsd;

  @HiveField(1)
  final double totalVolumeUsd;

  @HiveField(2)
  final double btcDominance;

  @HiveField(3)
  final double marketCapChangePercentage24hUsd;

  @HiveField(4)
  final int updatedAt;

  CoinGeckoGlobalDataDto({
    required this.totalMarketCapUsd,
    required this.totalVolumeUsd,
    required this.btcDominance,
    required this.marketCapChangePercentage24hUsd,
    required this.updatedAt,
  });

  /// Domain Entity로 변환
  MarketMoodData toEntity() => MarketMoodData(
    totalMarketCapUsd: totalMarketCapUsd,
    totalVolumeUsd: totalVolumeUsd,
    btcDominance: btcDominance,
    marketCapChange24h: marketCapChangePercentage24hUsd,
    updatedAt: DateTime.fromMillisecondsSinceEpoch(updatedAt * 1000),
  );

  /// JSON 직렬화용 맵 변환
  Map<String, dynamic> toMap() => {
    'total_market_cap_usd': totalMarketCapUsd,
    'total_volume_usd': totalVolumeUsd,
    'btc_dominance': btcDominance,
    'market_cap_change_percentage_24h_usd': marketCapChangePercentage24hUsd,
    'updated_at': updatedAt,
  };

  /// JSON 문자열 직렬화
  String toJson() => json.encode(toMap());

  /// JSON 파싱 (CoinGecko API 응답 형태)
  static CoinGeckoGlobalDataDto? tryParse(Map<String, dynamic> m) {
    try {
      if (m.isEmpty) return null;

      double parseDouble(dynamic v) {
        if (v is num) return v.toDouble();
        final str = v?.toString().trim() ?? '';
        return str.isNotEmpty ? double.tryParse(str) ?? 0.0 : 0.0;
      }

      int parseInt(dynamic v) {
        if (v is int) return v;
        final str = v?.toString().trim() ?? '';
        return str.isNotEmpty ? int.tryParse(str) ?? DateTime.now().millisecondsSinceEpoch ~/ 1000
            : DateTime.now().millisecondsSinceEpoch ~/ 1000;
      }

      final totalMarketCap = m['total_market_cap'] as Map<String, dynamic>?;
      final totalVolume = m['total_volume'] as Map<String, dynamic>?;
      final marketCapPercentage = m['market_cap_percentage'] as Map<String, dynamic>?;

      return CoinGeckoGlobalDataDto(
        totalMarketCapUsd: parseDouble(totalMarketCap?['usd']),
        totalVolumeUsd: parseDouble(totalVolume?['usd']),
        btcDominance: parseDouble(marketCapPercentage?['btc']),
        marketCapChangePercentage24hUsd: parseDouble(m['market_cap_change_percentage_24h_usd']),
        updatedAt: parseInt(m['updated_at']),
      );
    } catch (e) {
      log.w('CoinGeckoGlobalDataDto.tryParse error: $e');
      return null;
    }
  }

  factory CoinGeckoGlobalDataDto.fromJson(String src) =>
      tryParse(json.decode(src) as Map<String, dynamic>) ??
      CoinGeckoGlobalDataDto(
        totalMarketCapUsd: 0.0,
        totalVolumeUsd: 0.0,
        btcDominance: 0.0,
        marketCapChangePercentage24hUsd: 0.0,
        updatedAt: DateTime.now().millisecondsSinceEpoch ~/ 1000,
      );

  @override
  String toString() => 'CoinGeckoGlobalDataDto(volume: ${totalVolumeUsd.toStringAsFixed(0)}B USD)';
}

/// 🌐 CoinGecko 글로벌 마켓 응답 래퍼 DTO
@HiveType(typeId: 3)
class CoinGeckoGlobalResponseDto extends HiveObject {
  @HiveField(0)
  final CoinGeckoGlobalDataDto data;

  CoinGeckoGlobalResponseDto({
    required this.data,
  });

  Map<String, dynamic> toMap() => {
    'data': data.toMap(),
  };

  String toJson() => json.encode(toMap());

  static CoinGeckoGlobalResponseDto? tryParse(Map<String, dynamic> m) {
    try {
      if (m.isEmpty) return null;
      final dataMap = m['data'] as Map<String, dynamic>?;
      if (dataMap == null) return null;
      final data = CoinGeckoGlobalDataDto.tryParse(dataMap);
      if (data == null) return null;
      return CoinGeckoGlobalResponseDto(data: data);
    } catch (e) {
      log.w('CoinGeckoGlobalResponseDto.tryParse error: $e');
      return null;
    }
  }

  factory CoinGeckoGlobalResponseDto.fromJson(Map<String, dynamic> json) {
     final parsed = tryParse(json);
     if(parsed != null) return parsed;
     
     return CoinGeckoGlobalResponseDto(
        data: CoinGeckoGlobalDataDto(
          totalMarketCapUsd: 0.0,
          totalVolumeUsd: 0.0,
          btcDominance: 0.0,
          marketCapChangePercentage24hUsd: 0.0,
          updatedAt: DateTime.now().millisecondsSinceEpoch ~/ 1000,
        ),
      );
  }

  @override
  String toString() => 'CoinGeckoGlobalResponseDto(data: $data)';
}