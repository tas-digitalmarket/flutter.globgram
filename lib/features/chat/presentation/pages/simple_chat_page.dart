import 'package:flutter/material.dart';
import 'package:easy_localization/easy_localization.dart';
import 'package:file_picker/file_picker.dart';
import '../widgets/voice_recorder_widget.dart';
import '../widgets/voice_player_widget.dart';
import '../widgets/file_message_widget.dart';
import '../../../settings/presentation/pages/settings_page_simple.dart';

enum MessageType { text, voice, file }

class ChatMessage {
  final String id;
  final String content;
  final MessageType type;
  final DateTime timestamp;
  final Duration? voiceDuration;
  final String? fileName;
  final int? fileSize;
  final String? fileType;

  ChatMessage({
    required this.id,
    required this.content,
    required this.type,
    required this.timestamp,
    this.voiceDuration,
    this.fileName,
    this.fileSize,
    this.fileType,
  });
}

class SimpleChatPage extends StatefulWidget {
  const SimpleChatPage({super.key});

  @override
  State<SimpleChatPage> createState() => _SimpleChatPageState();
}

class _SimpleChatPageState extends State<SimpleChatPage> {
  final TextEditingController _messageController = TextEditingController();
  final List<ChatMessage> _messages = [];

  void _sendMessage() {
    if (_messageController.text.trim().isNotEmpty) {
      setState(() {
        _messages.add(ChatMessage(
          id: DateTime.now().millisecondsSinceEpoch.toString(),
          content: _messageController.text.trim(),
          type: MessageType.text,
          timestamp: DateTime.now(),
        ));
        _messageController.clear();
      });
    }
  }

  void _sendVoiceMessage(String filePath, Duration duration) {
    setState(() {
      _messages.add(ChatMessage(
        id: DateTime.now().millisecondsSinceEpoch.toString(),
        content: filePath,
        type: MessageType.voice,
        timestamp: DateTime.now(),
        voiceDuration: duration,
      ));
    });
  }

  void _sendFileMessage(
      String filePath, String fileName, int? fileSize, String? fileType) {
    setState(() {
      _messages.add(ChatMessage(
        id: DateTime.now().millisecondsSinceEpoch.toString(),
        content: filePath,
        type: MessageType.file,
        timestamp: DateTime.now(),
        fileName: fileName,
        fileSize: fileSize,
        fileType: fileType,
      ));
    });
  }

  Future<void> _pickFile() async {
    try {
      FilePickerResult? result = await FilePicker.platform.pickFiles(
        type: FileType.any,
        allowMultiple: false,
      );

      if (result != null && result.files.isNotEmpty) {
        final file = result.files.first;
        _sendFileMessage(
          file.path ?? '',
          file.name,
          file.size,
          file.extension,
        );

        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('${'file_selected'.tr()}: ${file.name}'),
            duration: const Duration(seconds: 2),
          ),
        );
      }
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Error selecting file: $e'),
          backgroundColor: Colors.red,
        ),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text('app_name'.tr()),
        backgroundColor: Theme.of(context).primaryColor,
        foregroundColor: Colors.white,
        actions: [
          IconButton(
            icon: const Icon(Icons.settings),
            onPressed: () {
              Navigator.push(
                context,
                MaterialPageRoute(
                  builder: (context) => const SettingsPage(),
                ),
              );
            },
          ),
        ],
      ),
      body: Column(
        children: [
          // Connection status
          Container(
            width: double.infinity,
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: Colors.green.shade100,
              border: Border(
                bottom: BorderSide(color: Colors.green.shade300),
              ),
            ),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Icon(Icons.circle, color: Colors.green, size: 12),
                const SizedBox(width: 8),
                Text(
                  'connected'.tr(),
                  style: TextStyle(
                    color: Colors.green.shade700,
                    fontWeight: FontWeight.w500,
                  ),
                ),
              ],
            ),
          ),

          // Messages list
          Expanded(
            child: _messages.isEmpty
                ? Center(
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Icon(
                          Icons.chat_bubble_outline,
                          size: 64,
                          color: Colors.grey.shade400,
                        ),
                        const SizedBox(height: 16),
                        Text(
                          'app_name'.tr(),
                          style: Theme.of(context)
                              .textTheme
                              .headlineSmall
                              ?.copyWith(
                                color: Colors.grey.shade600,
                              ),
                        ),
                        const SizedBox(height: 8),
                        Text(
                          'type_message'.tr(),
                          style:
                              Theme.of(context).textTheme.bodyMedium?.copyWith(
                                    color: Colors.grey.shade500,
                                  ),
                        ),
                      ],
                    ),
                  )
                : ListView.builder(
                    padding: const EdgeInsets.all(16),
                    itemCount: _messages.length,
                    itemBuilder: (context, index) {
                      final message = _messages[index];
                      return Container(
                        margin: const EdgeInsets.only(bottom: 12),
                        child: Align(
                          alignment: Alignment.centerRight,
                          child: Container(
                            padding: const EdgeInsets.symmetric(
                              horizontal: 16,
                              vertical: 10,
                            ),
                            decoration: BoxDecoration(
                              color: Theme.of(context).primaryColor,
                              borderRadius: BorderRadius.circular(18),
                            ),
                            child: message.type == MessageType.text
                                ? Text(
                                    message.content,
                                    style: const TextStyle(
                                      color: Colors.white,
                                      fontSize: 16,
                                    ),
                                  )
                                : message.type == MessageType.voice
                                    ? VoicePlayerWidget(
                                        filePath: message.content,
                                        duration: message.voiceDuration ??
                                            Duration.zero,
                                      )
                                    : FileMessageWidget(
                                        fileName:
                                            message.fileName ?? 'Unknown file',
                                        filePath: message.content,
                                        fileSize: message.fileSize,
                                        fileType: message.fileType,
                                      ),
                          ),
                        ),
                      );
                    },
                  ),
          ),

          // Input area
          Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: Theme.of(context).scaffoldBackgroundColor,
              border: Border(
                top: BorderSide(color: Colors.grey.shade300),
              ),
            ),
            child: Row(
              children: [
                // File attachment button
                IconButton(
                  onPressed: _pickFile,
                  icon: Icon(
                    Icons.attach_file,
                    color: Theme.of(context).primaryColor,
                  ),
                  tooltip: 'attach_file'.tr(),
                ),

                const SizedBox(width: 8),

                // Text input
                Expanded(
                  child: TextField(
                    controller: _messageController,
                    decoration: InputDecoration(
                      hintText: 'type_message'.tr(),
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(25),
                        borderSide: BorderSide.none,
                      ),
                      filled: true,
                      fillColor: Colors.grey.shade100,
                      contentPadding: const EdgeInsets.symmetric(
                        horizontal: 20,
                        vertical: 12,
                      ),
                    ),
                    onSubmitted: (_) => _sendMessage(),
                  ),
                ),

                const SizedBox(width: 12),

                // Voice recorder
                VoiceRecorderWidget(
                  onVoiceRecorded: _sendVoiceMessage,
                ),

                const SizedBox(width: 8),

                // Send button
                FloatingActionButton(
                  onPressed: _sendMessage,
                  mini: true,
                  child: const Icon(Icons.send),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  @override
  void dispose() {
    _messageController.dispose();
    super.dispose();
  }
}
