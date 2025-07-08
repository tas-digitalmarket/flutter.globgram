import 'package:flutter/material.dart';
import 'package:easy_localization/easy_localization.dart';

class ChatInput extends StatefulWidget {
  final TextEditingController controller;
  final Function(String) onSendMessage;
  final VoidCallback onStartRecording;
  final Function(String, Duration) onStopRecording;
  final bool isRecording;

  const ChatInput({
    super.key,
    required this.controller,
    required this.onSendMessage,
    required this.onStartRecording,
    required this.onStopRecording,
    required this.isRecording,
  });

  @override
  State<ChatInput> createState() => _ChatInputState();
}

class _ChatInputState extends State<ChatInput> {
  bool _showSendButton = false;

  @override
  void initState() {
    super.initState();
    widget.controller.addListener(_onTextChanged);
  }

  void _onTextChanged() {
    setState(() {
      _showSendButton = widget.controller.text.trim().isNotEmpty;
    });
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Theme.of(context).scaffoldBackgroundColor,
        border: Border(
          top: BorderSide(
            color: Colors.grey.shade300,
            width: 0.5,
          ),
        ),
      ),
      child: Row(
        children: [
          // Emoji button
          IconButton(
            icon: const Icon(Icons.emoji_emotions_outlined),
            onPressed: () {
              // TODO: Open emoji picker
            },
          ),

          // Text input field
          Expanded(
            child: TextField(
              controller: widget.controller,
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
              maxLines: null,
              textInputAction: TextInputAction.send,
              onSubmitted: widget.onSendMessage,
            ),
          ),

          const SizedBox(width: 8),

          // Send/Record button
          if (_showSendButton)
            IconButton(
              icon: const Icon(Icons.send, color: Colors.blue),
              onPressed: () {
                widget.onSendMessage(widget.controller.text);
              },
            )
          else
            GestureDetector(
              onTapDown: (_) => widget.onStartRecording(),
              onTapUp: (_) {
                // Simulate recording completion
                widget.onStopRecording(
                    'dummy_path', const Duration(seconds: 5));
              },
              child: Container(
                padding: const EdgeInsets.all(12),
                decoration: const BoxDecoration(
                  color: Colors.blue,
                  shape: BoxShape.circle,
                ),
                child: Icon(
                  widget.isRecording ? Icons.stop : Icons.mic,
                  color: Colors.white,
                ),
              ),
            ),
        ],
      ),
    );
  }

  @override
  void dispose() {
    widget.controller.removeListener(_onTextChanged);
    super.dispose();
  }
}
