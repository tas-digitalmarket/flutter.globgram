import 'package:hive/hive.dart';
import '../../../../core/models/message_types.dart';

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

  Duration? get voiceDuration => voiceDurationInSeconds != null
      ? Duration(seconds: voiceDurationInSeconds!)
      : null;

  MessageModel copyWith({
    String? id,
    String? content,
    MessageType? type,
    DateTime? timestamp,
    bool? isSent,
    String? voiceFilePath,
    int? voiceDurationInSeconds,
  }) {
    return MessageModel(
      id: id ?? this.id,
      content: content ?? this.content,
      type: type ?? this.type,
      timestamp: timestamp ?? this.timestamp,
      isSent: isSent ?? this.isSent,
      voiceFilePath: voiceFilePath ?? this.voiceFilePath,
      voiceDurationInSeconds: voiceDurationInSeconds ?? this.voiceDurationInSeconds,
    );
  }
}
