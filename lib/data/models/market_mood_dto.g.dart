// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'market_mood_dto.dart';

// **************************************************************************
// TypeAdapterGenerator
// **************************************************************************

class TimestampedVolumeAdapter extends TypeAdapter<TimestampedVolume> {
  @override
  final int typeId = 1;

  @override
  TimestampedVolume read(BinaryReader reader) {
    final numOfFields = reader.readByte();
    final fields = <int, dynamic>{
      for (int i = 0; i < numOfFields; i++) reader.readByte(): reader.read(),
    };
    return TimestampedVolume(
      timestamp: fields[0] as DateTime,
      volumeUsd: fields[1] as double,
    );
  }

  @override
  void write(BinaryWriter writer, TimestampedVolume obj) {
    writer
      ..writeByte(2)
      ..writeByte(0)
      ..write(obj.timestamp)
      ..writeByte(1)
      ..write(obj.volumeUsd);
  }

  @override
  int get hashCode => typeId.hashCode;

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is TimestampedVolumeAdapter &&
          runtimeType == other.runtimeType &&
          typeId == other.typeId;
}

class CoinGeckoGlobalDataDtoAdapter
    extends TypeAdapter<CoinGeckoGlobalDataDto> {
  @override
  final int typeId = 2;

  @override
  CoinGeckoGlobalDataDto read(BinaryReader reader) {
    final numOfFields = reader.readByte();
    final fields = <int, dynamic>{
      for (int i = 0; i < numOfFields; i++) reader.readByte(): reader.read(),
    };
    return CoinGeckoGlobalDataDto(
      totalMarketCapUsd: fields[0] as double,
      totalVolumeUsd: fields[1] as double,
      btcDominance: fields[2] as double,
      marketCapChangePercentage24hUsd: fields[3] as double,
      updatedAt: fields[4] as int,
    );
  }

  @override
  void write(BinaryWriter writer, CoinGeckoGlobalDataDto obj) {
    writer
      ..writeByte(5)
      ..writeByte(0)
      ..write(obj.totalMarketCapUsd)
      ..writeByte(1)
      ..write(obj.totalVolumeUsd)
      ..writeByte(2)
      ..write(obj.btcDominance)
      ..writeByte(3)
      ..write(obj.marketCapChangePercentage24hUsd)
      ..writeByte(4)
      ..write(obj.updatedAt);
  }

  @override
  int get hashCode => typeId.hashCode;

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is CoinGeckoGlobalDataDtoAdapter &&
          runtimeType == other.runtimeType &&
          typeId == other.typeId;
}

class CoinGeckoGlobalResponseDtoAdapter
    extends TypeAdapter<CoinGeckoGlobalResponseDto> {
  @override
  final int typeId = 3;

  @override
  CoinGeckoGlobalResponseDto read(BinaryReader reader) {
    final numOfFields = reader.readByte();
    final fields = <int, dynamic>{
      for (int i = 0; i < numOfFields; i++) reader.readByte(): reader.read(),
    };
    return CoinGeckoGlobalResponseDto(
      data: fields[0] as CoinGeckoGlobalDataDto,
    );
  }

  @override
  void write(BinaryWriter writer, CoinGeckoGlobalResponseDto obj) {
    writer
      ..writeByte(1)
      ..writeByte(0)
      ..write(obj.data);
  }

  @override
  int get hashCode => typeId.hashCode;

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is CoinGeckoGlobalResponseDtoAdapter &&
          runtimeType == other.runtimeType &&
          typeId == other.typeId;
}
