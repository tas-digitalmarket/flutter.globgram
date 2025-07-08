import 'package:equatable/equatable.dart';
import 'package:hive/hive.dart';

part 'message.g.dart';

@HiveType(typeId: 1)
enum MessageType {
  @HiveField(0)
  text,
  @HiveField(1)
  voice
}

class Message extends Equatable {
  final String id;
  final String content; // For text messages or file path for voice messages
  final MessageType type;
  final DateTime timestamp;
  final bool isSent; // true if sent by current user, false if received
  final String? voiceFilePath; // Path to voice file if type is voice
  final Duration? voiceDuration; // Duration of voice message

  const Message({
    required this.id,
    required this.content,
    required this.type,
    required this.timestamp,
    required this.isSent,
    this.voiceFilePath,
    this.voiceDuration,
  });

  @override
  List<Object?> get props => [
        id,
        content,
        type,
        timestamp,
        isSent,
        voiceFilePath,
        voiceDuration,
      ];

  Message copyWith({
    String? id,
    String? content,
    MessageType? type,
    DateTime? timestamp,
    bool? isSent,
    String? voiceFilePath,
    Duration? voiceDuration,
  }) {
    return Message(
      id: id ?? this.id,
      content: content ?? this.content,
      type: type ?? this.type,
      timestamp: timestamp ?? this.timestamp,
      isSent: isSent ?? this.isSent,
      voiceFilePath: voiceFilePath ?? this.voiceFilePath,
      voiceDuration: voiceDuration ?? this.voiceDuration,
    );
  }
}
