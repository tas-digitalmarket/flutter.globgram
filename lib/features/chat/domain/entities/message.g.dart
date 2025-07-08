// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'message.dart';

// **************************************************************************
// TypeAdapterGenerator
// **************************************************************************

class MessageTypeAdapter extends TypeAdapter<MessageType> {
  @override
  final int typeId = 1;

  @override
  MessageType read(BinaryReader reader) {
    switch (reader.readByte()) {
      case 0:
        return MessageType.text;
      case 1:
        return MessageType.voice;
      default:
        return MessageType.text;
    }
  }

  @override
  void write(BinaryWriter writer, MessageType obj) {
    switch (obj) {
      case MessageType.text:
        writer.writeByte(0);
        break;
      case MessageType.voice:
        writer.writeByte(1);
        break;
    }
  }

  @override
  int get hashCode => typeId.hashCode;

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is MessageTypeAdapter &&
          runtimeType == other.runtimeType &&
          typeId == other.typeId;
}
