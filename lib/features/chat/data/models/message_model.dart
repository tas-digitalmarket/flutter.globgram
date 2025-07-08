import 'package:hive/hive.dart';
import '../../domain/entities/message.dart';

part 'message_model.g.dart';

@HiveType(typeId: 0)
class MessageModel extends HiveObject {
  @HiveField(0)
  final String id;

  @HiveField(1)
  final String content;

  @HiveField(2)
  final MessageType type;

  @HiveField(3)
  final DateTime timestamp;

  @HiveField(4)
  final bool isSent;

  @HiveField(5)
  final String? voiceFilePath;

  @HiveField(6)
  final int? voiceDurationInSeconds;

  MessageModel({
    required this.id,
    required this.content,
    required this.type,
    required this.timestamp,
    required this.isSent,
    this.voiceFilePath,
    this.voiceDurationInSeconds,
  });

  factory MessageModel.fromEntity(Message message) {
    return MessageModel(
      id: message.id,
      content: message.content,
      type: message.type,
      timestamp: message.timestamp,
      isSent: message.isSent,
      voiceFilePath: message.voiceFilePath,
      voiceDurationInSeconds: message.voiceDuration?.inSeconds,
    );
  }

  Message toEntity() {
    return Message(
      id: id,
      content: content,
      type: type,
      timestamp: timestamp,
      isSent: isSent,
      voiceFilePath: voiceFilePath,
      voiceDuration: voiceDurationInSeconds != null
          ? Duration(seconds: voiceDurationInSeconds!)
          : null,
    );
  }
}

@HiveType(typeId: 1)
enum MessageType {
  @HiveField(0)
  text,
  @HiveField(1)
  voice,
}
