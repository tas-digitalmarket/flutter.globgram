import 'package:hive/hive.dart';
import '../models/message_model.dart';
import '../../../../core/models/message_types.dart';

class LocalDataSource {
  static const String _messagesBoxName = 'messages';
  Box<MessageModel>? _messagesBox;

  Future<void> init() async {
    // Register adapters
    if (!Hive.isAdapterRegistered(0)) {
      Hive.registerAdapter(MessageModelAdapter());
    }
    if (!Hive.isAdapterRegistered(1)) {
      // Import the generated adapter
      Hive.registerAdapter(MessageTypeAdapter());
    }

    // Open boxes
    _messagesBox = await Hive.openBox<MessageModel>(_messagesBoxName);
  }

  Future<List<MessageModel>> getMessages() async {
    await _ensureInitialized();

    final messageModels = _messagesBox!.values.toList();
    messageModels.sort((a, b) => a.timestamp.compareTo(b.timestamp));

    return messageModels;
  }

  Future<void> saveMessage(MessageModel message) async {
    await _ensureInitialized();

    await _messagesBox!.put(message.id, message);
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
