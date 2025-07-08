import 'package:flutter/material.dart';
import 'dart:html' as html;
import 'dart:convert';
import 'dart:math';

class TestP2PPage extends StatefulWidget {
  const TestP2PPage({super.key});

  @override
  State<TestP2PPage> createState() => _TestP2PPageState();
}

class _TestP2PPageState extends State<TestP2PPage> {
  final TextEditingController _messageController = TextEditingController();
  final TextEditingController _roomController = TextEditingController();
  final List<String> _messages = [];
  html.BroadcastChannel? _channel;
  String _peerId = '';
  String _roomId = '';
  bool _isConnected = false;

  @override
  void initState() {
    super.initState();
    _peerId = _generatePeerId();
    setState(() {
      _messages.add('🚀 Ready to connect. Enter a Room ID to start!');
    });
  }

  void _joinRoom(String roomId) {
    if (roomId.trim().isEmpty) return;

    setState(() {
      _roomId = roomId.trim().toUpperCase();
      _isConnected = true;
    });

    _initializeBroadcast();
  }

  void _createRoom() {
    final newRoomId = _generateRoomId();
    _roomController.text = newRoomId;
    _joinRoom(newRoomId);
  }

  String _generateRoomId() {
    final random = Random();
    const chars = 'ABCDEFGHIJKLMNOPQRSTUVWXYZ0123456789';
    return String.fromCharCodes(
      List.generate(
          6, (index) => chars.codeUnitAt(random.nextInt(chars.length))),
    );
  }

  void _initializeBroadcast() {
    _channel?.close(); // Close existing channel if any

    _channel = html.BroadcastChannel('test_room_$_roomId');

    _channel!.onMessage.listen((event) {
      try {
        final data = json.decode(event.data as String);
        final fromPeer = data['from'] as String;
        final message = data['message'] as String;

        // فقط پیام‌های دیگران را نشان بده
        if (fromPeer != _peerId) {
          setState(() {
            _messages.add('[$fromPeer]: $message');
          });
          print('📨 Message received from $fromPeer: $message');
        } else {
          print('🚫 Ignored own message: $message');
        }
      } catch (e) {
        print('❌ Error handling message: $e');
      }
    });

    setState(() {
      _messages.clear();
      _messages.add('✅ Connected to room: $_roomId');
      _messages.add('👤 Your Peer ID: $_peerId');
    });

    print('🚀 P2P Test initialized');
    print('📱 Peer ID: $_peerId');
    print('🏠 Room: $_roomId');
  }

  void _sendMessage() {
    final message = _messageController.text.trim();
    if (message.isNotEmpty) {
      final data = {
        'from': _peerId,
        'message': message,
        'timestamp': DateTime.now().toIso8601String(),
      };

      try {
        _channel!.postMessage(json.encode(data));
        print('📤 Message sent: $message');

        setState(() {
          _messages.add('Me: $message');
          _messageController.clear();
        });
      } catch (e) {
        print('❌ Error sending message: $e');
      }
    }
  }

  String _generatePeerId() {
    final random = Random();
    const chars = 'abcdefghijklmnopqrstuvwxyz0123456789';
    return String.fromCharCodes(
      List.generate(
          6, (index) => chars.codeUnitAt(random.nextInt(chars.length))),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('P2P Chat Test'),
        backgroundColor: Colors.blue,
        foregroundColor: Colors.white,
      ),
      body: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          children: [
            // Connection Card
            if (!_isConnected) ...[
              Card(
                color: Colors.blue.shade50,
                child: Padding(
                  padding: const EdgeInsets.all(16.0),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      Text('🚀 Join P2P Chat Room',
                          style: TextStyle(
                              fontSize: 18, fontWeight: FontWeight.bold)),
                      const SizedBox(height: 16),

                      // Room ID Input
                      TextField(
                        controller: _roomController,
                        decoration: const InputDecoration(
                          labelText: 'Enter Room ID',
                          hintText: 'e.g., ABC123',
                          border: OutlineInputBorder(),
                          prefixIcon: Icon(Icons.meeting_room),
                        ),
                        textCapitalization: TextCapitalization.characters,
                      ),
                      const SizedBox(height: 12),

                      // Buttons Row
                      Row(
                        children: [
                          Expanded(
                            child: ElevatedButton(
                              onPressed: () => _joinRoom(_roomController.text),
                              style: ElevatedButton.styleFrom(
                                backgroundColor: Colors.blue,
                                foregroundColor: Colors.white,
                              ),
                              child: const Text('Join Room'),
                            ),
                          ),
                          const SizedBox(width: 12),
                          Expanded(
                            child: OutlinedButton(
                              onPressed: _createRoom,
                              child: const Text('Create New Room'),
                            ),
                          ),
                        ],
                      ),

                      const SizedBox(height: 16),
                      Container(
                        padding: const EdgeInsets.all(12),
                        decoration: BoxDecoration(
                          color: Colors.orange.shade100,
                          borderRadius: BorderRadius.circular(8),
                        ),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text('📋 How to Test:',
                                style: TextStyle(fontWeight: FontWeight.bold)),
                            Text(
                                '1. Create a new room OR enter existing Room ID'),
                            Text('2. Open NEW tab: http://localhost:8081'),
                            Text('3. Enter the SAME Room ID in the new tab'),
                            Text('4. Send messages between tabs'),
                            Text('5. Messages should appear only in OTHER tab'),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ] else ...[
              // Status Card (when connected)
              Card(
                color: Colors.green.shade50,
                child: Padding(
                  padding: const EdgeInsets.all(16.0),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Text('🟢 Connected',
                              style: TextStyle(
                                  fontSize: 18,
                                  fontWeight: FontWeight.bold,
                                  color: Colors.green)),
                          TextButton(
                            onPressed: () {
                              setState(() {
                                _isConnected = false;
                                _channel?.close();
                                _messages.clear();
                                _messages.add(
                                    '🚀 Ready to connect. Enter a Room ID to start!');
                              });
                            },
                            child: const Text('Disconnect'),
                          ),
                        ],
                      ),
                      const SizedBox(height: 8),
                      Text('Room ID: $_roomId',
                          style: TextStyle(
                              fontFamily: 'monospace',
                              fontSize: 16,
                              fontWeight: FontWeight.bold)),
                      Text('Peer ID: $_peerId',
                          style: TextStyle(fontFamily: 'monospace')),
                    ],
                  ),
                ),
              ),
            ],

            const SizedBox(height: 16),

            // Messages List
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
                    final message = _messages[index];
                    final isOwnMessage = message.startsWith('Me:');
                    final isSystemMessage = message.startsWith('✅');

                    return Padding(
                      padding: const EdgeInsets.symmetric(vertical: 2),
                      child: Text(
                        message,
                        style: TextStyle(
                          color: isSystemMessage
                              ? Colors.green
                              : isOwnMessage
                                  ? Colors.blue
                                  : Colors.black,
                          fontWeight: isSystemMessage
                              ? FontWeight.bold
                              : FontWeight.normal,
                        ),
                      ),
                    );
                  },
                ),
              ),
            ),

            const SizedBox(height: 16),

            // Message Input
            if (_isConnected) ...[
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
                    style: ElevatedButton.styleFrom(
                      backgroundColor: Colors.blue,
                      foregroundColor: Colors.white,
                    ),
                    child: const Text('Send'),
                  ),
                ],
              ),
            ],
          ],
        ),
      ),
    );
  }

  @override
  void dispose() {
    _channel?.close();
    _messageController.dispose();
    _roomController.dispose();
    super.dispose();
  }
}
