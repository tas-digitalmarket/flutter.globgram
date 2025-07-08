import 'package:uuid/uuid.dart';
import '../../domain/entities/message.dart';
import '../datasources/local_data_source.dart';

class ChatRepositoryImpl {
  final LocalDataSource localDataSource;
  final Uuid _uuid = const Uuid();

  ChatRepositoryImpl({required this.localDataSource});

  Future<List<Message>> getMessages() async {
    try {
      return await localDataSource.getMessages();
    } catch (e) {
      throw Exception('Failed to load messages: $e');
    }
  }

  Future<Message> sendTextMessage(String content) async {
    try {
      final message = Message(
        id: _uuid.v4(),
        content: content,
        type: MessageType.text,
        timestamp: DateTime.now(),
        isSent: true,
      );

      await localDataSource.saveMessage(message);
      return message;
    } catch (e) {
      throw Exception('Failed to send text message: $e');
    }
  }

  Future<Message> sendVoiceMessage(String filePath, Duration duration) async {
    try {
      final message = Message(
        id: _uuid.v4(),
        content: filePath,
        type: MessageType.voice,
        timestamp: DateTime.now(),
        isSent: true,
        voiceFilePath: filePath,
        voiceDuration: duration,
      );

      await localDataSource.saveMessage(message);
      return message;
    } catch (e) {
      throw Exception('Failed to send voice message: $e');
    }
  }

  Future<void> receiveMessage(Message message) async {
    try {
      final receivedMessage = message.copyWith(isSent: false);
      await localDataSource.saveMessage(receivedMessage);
    } catch (e) {
      throw Exception('Failed to receive message: $e');
    }
  }

  Future<void> clearMessages() async {
    try {
      await localDataSource.clearMessages();
    } catch (e) {
      throw Exception('Failed to clear messages: $e');
    }
  }
}
