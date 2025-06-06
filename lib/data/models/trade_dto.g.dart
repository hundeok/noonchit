// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'trade_dto.dart';

// **************************************************************************
// TypeAdapterGenerator
// **************************************************************************

class TradeDtoAdapter extends TypeAdapter<TradeDto> {
  @override
  final int typeId = 0;

  @override
  TradeDto read(BinaryReader reader) {
    final numOfFields = reader.readByte();
    final fields = <int, dynamic>{
      for (int i = 0; i < numOfFields; i++) reader.readByte(): reader.read(),
    };
    return TradeDto(
      market: fields[0] as String,
      price: fields[1] as double,
      volume: fields[2] as double,
      side: fields[3] as String,
      changePrice: fields[4] as double,
      changeState: fields[5] as String,
      timestampMs: fields[6] as int,
      sequentialId: fields[7] as String,
    );
  }

  @override
  void write(BinaryWriter writer, TradeDto obj) {
    writer
      ..writeByte(8)
      ..writeByte(0)
      ..write(obj.market)
      ..writeByte(1)
      ..write(obj.price)
      ..writeByte(2)
      ..write(obj.volume)
      ..writeByte(3)
      ..write(obj.side)
      ..writeByte(4)
      ..write(obj.changePrice)
      ..writeByte(5)
      ..write(obj.changeState)
      ..writeByte(6)
      ..write(obj.timestampMs)
      ..writeByte(7)
      ..write(obj.sequentialId);
  }

  @override
  int get hashCode => typeId.hashCode;

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is TradeDtoAdapter &&
          runtimeType == other.runtimeType &&
          typeId == other.typeId;
}
