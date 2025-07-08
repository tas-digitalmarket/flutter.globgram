import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'dart:html' as html;
import 'dart:convert';

class SimpleBroadcastTestPage extends StatefulWidget {
  const SimpleBroadcastTestPage({super.key});

  @override
  State<SimpleBroadcastTestPage> createState() =>
      _SimpleBroadcastTestPageState();
}

class _SimpleBroadcastTestPageState extends State<SimpleBroadcastTestPage> {
  final TextEditingController _messageController = TextEditingController();
  final List<String> _messages = [];
  html.BroadcastChannel? _channel;
  String _peerId = '';

  @override
  void initState() {
    super.initState();
    _initializeBroadcast();
  }

  void _initializeBroadcast() {
    _peerId = 'peer_${DateTime.now().millisecondsSinceEpoch}';
    _channel = html.BroadcastChannel('test_chat');

    _channel!.onMessage.listen((event) {
      final data = json.decode(event.data as String);
      if (data['from'] != _peerId) {
        setState(() {
          _messages.add('${data['from']}: ${data['message']}');
        });
      }
    });

    setState(() {
      _messages.add('Connected as: $_peerId');
    });
  }

  void _sendMessage() {
    final message = _messageController.text.trim();
    if (message.isNotEmpty) {
      final data = {
        'from': _peerId,
        'message': message,
        'timestamp': DateTime.now().toIso8601String(),
      };

      _channel!.postMessage(json.encode(data));

      setState(() {
        _messages.add('Me: $message');
        _messageController.clear();
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Simple Broadcast Test'),
        backgroundColor: Colors.blue,
        foregroundColor: Colors.white,
      ),
      body: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          children: [
            Card(
              child: Padding(
                padding: const EdgeInsets.all(16.0),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text('Peer ID: $_peerId',
                        style: const TextStyle(fontWeight: FontWeight.bold)),
                    const SizedBox(height: 8),
                    const Text('Open multiple tabs and test messaging!'),
                    const SizedBox(height: 8),
                    ElevatedButton(
                      onPressed: () {
                        Clipboard.setData(ClipboardData(text: _peerId));
                        ScaffoldMessenger.of(context).showSnackBar(
                          const SnackBar(
                              content: Text('Peer ID copied to clipboard')),
                        );
                      },
                      child: const Text('Copy Peer ID'),
                    ),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 16),
            Expanded(
              child: Container(
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  border: Border.all(color: Colors.grey.shade300),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: ListView.builder(
                  itemCount: _messages.length,
                  itemBuilder: (context, index) {
                    return Padding(
                      padding: const EdgeInsets.symmetric(vertical: 4),
                      child: Text(_messages[index]),
                    );
                  },
                ),
              ),
            ),
            const SizedBox(height: 16),
            Row(
              children: [
                Expanded(
                  child: TextField(
                    controller: _messageController,
                    decoration: const InputDecoration(
                      hintText: 'Type a message...',
                      border: OutlineInputBorder(),
                    ),
                    onSubmitted: (_) => _sendMessage(),
                  ),
                ),
                const SizedBox(width: 8),
                ElevatedButton(
                  onPressed: _sendMessage,
                  child: const Text('Send'),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  @override
  void dispose() {
    _channel?.close();
    _messageController.dispose();
    super.dispose();
  }
}
