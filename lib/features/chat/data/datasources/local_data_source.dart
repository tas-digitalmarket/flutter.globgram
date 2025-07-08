import 'package:hive/hive.dart';
import '../../domain/entities/message.dart';
import '../models/message_model.dart';

class LocalDataSource {
  static const String _messagesBoxName = 'messages';
  Box<MessageModel>? _messagesBox;

  Future<void> init() async {
    // Register adapters
    if (!Hive.isAdapterRegistered(0)) {
      Hive.registerAdapter(MessageModelAdapter());
    }
    if (!Hive.isAdapterRegistered(1)) {
      Hive.registerAdapter(MessageTypeAdapter());
    }

    // Open boxes
    _messagesBox = await Hive.openBox<MessageModel>(_messagesBoxName);
  }

  Future<List<Message>> getMessages() async {
    await _ensureInitialized();

    final messageModels = _messagesBox!.values.toList();
    messageModels.sort((a, b) => a.timestamp.compareTo(b.timestamp));

    return messageModels.map((model) => model.toEntity()).toList();
  }

  Future<void> saveMessage(Message message) async {
    await _ensureInitialized();

    final messageModel = MessageModel.fromEntity(message);
    await _messagesBox!.put(message.id, messageModel);
  }

  Future<void> clearMessages() async {
    await _ensureInitialized();
    await _messagesBox!.clear();
  }

  Future<void> _ensureInitialized() async {
    if (_messagesBox == null) {
      await init();
    }
  }
}
