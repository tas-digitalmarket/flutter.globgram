import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:easy_localization/easy_localization.dart';
import 'dart:math';

import 'p2p_chat_page.dart';

class SimpleRoomPage extends StatefulWidget {
  const SimpleRoomPage({super.key});

  @override
  State<SimpleRoomPage> createState() => _SimpleRoomPageState();
}

class _SimpleRoomPageState extends State<SimpleRoomPage> {
  final TextEditingController _roomController = TextEditingController();
  String _generatedRoomId = '';
  bool _isRoomInputEmpty = true;

  @override
  void initState() {
    super.initState();
    _roomController.addListener(_updateRoomInputState);
  }

  void _updateRoomInputState() {
    final isEmpty = _roomController.text.trim().isEmpty;
    if (_isRoomInputEmpty != isEmpty) {
      setState(() {
        _isRoomInputEmpty = isEmpty;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text('app_name'.tr()),
        backgroundColor: Theme.of(context).primaryColor,
        foregroundColor: Colors.white,
      ),
      body: SingleChildScrollView(
        child: Padding(
          padding: const EdgeInsets.all(24.0),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              // App Logo/Icon
              Container(
                width: 120,
                height: 120,
                decoration: BoxDecoration(
                  color: Theme.of(context).primaryColor,
                  shape: BoxShape.circle,
                ),
                child: const Icon(
                  Icons.chat_bubble_outline,
                  size: 60,
                  color: Colors.white,
                ),
              ),

              const SizedBox(height: 32),

              Text(
                'app_name'.tr(),
                style: Theme.of(context).textTheme.headlineMedium?.copyWith(
                      fontWeight: FontWeight.bold,
                      color: Theme.of(context).primaryColor,
                    ),
              ),

              const SizedBox(height: 8),

              Text(
                'Peer-to-peer messaging without servers',
                style: Theme.of(context).textTheme.bodyLarge?.copyWith(
                      color: Colors.grey.shade600,
                    ),
                textAlign: TextAlign.center,
              ),

              const SizedBox(height: 48),

              // Room ID Input
              TextField(
                controller: _roomController,
                decoration: InputDecoration(
                  labelText: 'room_name'.tr(),
                  hintText: 'Enter room ID to join...',
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                  prefixIcon: const Icon(Icons.meeting_room),
                ),
              ),

              const SizedBox(height: 24),

              // Join Room Button
              SizedBox(
                width: double.infinity,
                height: 56,
                child: ElevatedButton(
                  onPressed: _isRoomInputEmpty ? null : _joinRoom,
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Theme.of(context).primaryColor,
                    foregroundColor: Colors.white,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
                  ),
                  child: Text(
                    'join_room'.tr(),
                    style: const TextStyle(
                        fontSize: 18, fontWeight: FontWeight.w600),
                  ),
                ),
              ),

              const SizedBox(height: 16),

              Text(
                'OR',
                style: TextStyle(
                  color: Colors.grey.shade600,
                  fontWeight: FontWeight.w500,
                ),
              ),

              const SizedBox(height: 16),

              // Create New Room Button
              SizedBox(
                width: double.infinity,
                height: 56,
                child: OutlinedButton(
                  onPressed: _createNewRoom,
                  style: OutlinedButton.styleFrom(
                    side: BorderSide(color: Theme.of(context).primaryColor),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
                  ),
                  child: Text(
                    'create_room'.tr(),
                    style: TextStyle(
                      fontSize: 18,
                      fontWeight: FontWeight.w600,
                      color: Theme.of(context).primaryColor,
                    ),
                  ),
                ),
              ),

              const SizedBox(height: 32),

              // Generated Room ID Display
              if (_generatedRoomId.isNotEmpty) ...[
                Card(
                  elevation: 4,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(16),
                  ),
                  child: Padding(
                    padding: const EdgeInsets.all(24),
                    child: Column(
                      children: [
                        Text(
                          '🎉 Room Created Successfully!',
                          style:
                              Theme.of(context).textTheme.titleLarge?.copyWith(
                                    fontWeight: FontWeight.bold,
                                    color: Colors.green.shade700,
                                  ),
                          textAlign: TextAlign.center,
                        ),
                        const SizedBox(height: 20),

                        // Room ID Display
                        Container(
                          width: double.infinity,
                          padding: const EdgeInsets.all(20),
                          decoration: BoxDecoration(
                            color: Colors.blue.shade50,
                            borderRadius: BorderRadius.circular(12),
                            border: Border.all(
                                color: Colors.blue.shade200, width: 2),
                          ),
                          child: Column(
                            children: [
                              Text(
                                'YOUR ROOM ID',
                                style: TextStyle(
                                  fontSize: 16,
                                  color: Colors.blue.shade700,
                                  fontWeight: FontWeight.bold,
                                  letterSpacing: 1,
                                ),
                              ),
                              const SizedBox(height: 12),

                              // Large Room ID
                              Container(
                                padding: const EdgeInsets.symmetric(
                                    horizontal: 24, vertical: 16),
                                decoration: BoxDecoration(
                                  color: Colors.white,
                                  borderRadius: BorderRadius.circular(8),
                                  border:
                                      Border.all(color: Colors.blue.shade300),
                                  boxShadow: [
                                    BoxShadow(
                                      color: Colors.blue.shade100,
                                      blurRadius: 4,
                                      offset: const Offset(0, 2),
                                    ),
                                  ],
                                ),
                                child: SelectableText(
                                  _generatedRoomId,
                                  style: TextStyle(
                                    fontSize: 32,
                                    fontFamily: 'monospace',
                                    color: Colors.blue.shade900,
                                    fontWeight: FontWeight.bold,
                                    letterSpacing: 4,
                                  ),
                                  textAlign: TextAlign.center,
                                ),
                              ),

                              const SizedBox(height: 16),
                              Text(
                                'Share this Room ID with others so they can join your chat',
                                style: TextStyle(
                                  fontSize: 14,
                                  color: Colors.blue.shade600,
                                  fontWeight: FontWeight.w500,
                                ),
                                textAlign: TextAlign.center,
                              ),
                            ],
                          ),
                        ),

                        const SizedBox(height: 20),

                        // Action Buttons
                        Row(
                          children: [
                            Expanded(
                              child: OutlinedButton.icon(
                                onPressed: () => _copyRoomId(),
                                icon: const Icon(Icons.copy),
                                label: const Text('Copy ID'),
                                style: OutlinedButton.styleFrom(
                                  side: BorderSide(color: Colors.blue.shade400),
                                ),
                              ),
                            ),
                            const SizedBox(width: 12),
                            Expanded(
                              child: ElevatedButton.icon(
                                onPressed: () => _joinRoom(_generatedRoomId),
                                icon: const Icon(Icons.login),
                                label: const Text('Join Room'),
                                style: ElevatedButton.styleFrom(
                                  backgroundColor: Colors.green.shade600,
                                  foregroundColor: Colors.white,
                                ),
                              ),
                            ),
                          ],
                        ),

                        const SizedBox(height: 12),

                        TextButton(
                          onPressed: () {
                            setState(() {
                              _generatedRoomId = '';
                            });
                          },
                          child: Text(
                            'Create Another Room',
                            style: TextStyle(color: Colors.grey.shade600),
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }

  void _createNewRoom() {
    final roomId = _generateRoomId();
    setState(() {
      _generatedRoomId = roomId;
    });

    // Show success message
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text('🎉 Room created with ID: $roomId'),
        backgroundColor: Colors.green,
        duration: const Duration(seconds: 3),
        action: SnackBarAction(
          label: 'Copy',
          textColor: Colors.white,
          onPressed: () => _copyRoomId(),
        ),
      ),
    );
  }

  void _copyRoomId() {
    Clipboard.setData(ClipboardData(text: _generatedRoomId));
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text('Room ID copied: $_generatedRoomId'),
        backgroundColor: Colors.blue,
        duration: const Duration(seconds: 2),
      ),
    );
  }

  void _joinRoom([String? roomId]) {
    final targetRoomId = roomId ?? _roomController.text.trim();

    if (targetRoomId.isNotEmpty) {
      Navigator.pushReplacement(
        context,
        MaterialPageRoute(
          builder: (context) => P2PChatPage(roomId: targetRoomId),
        ),
      );
    }
  }

  String _generateRoomId() {
    const chars = 'ABCDEFGHIJKLMNOPQRSTUVWXYZ0123456789';
    final random = Random();
    return String.fromCharCodes(
      List.generate(
          6, (index) => chars.codeUnitAt(random.nextInt(chars.length))),
    );
  }

  @override
  void dispose() {
    _roomController.removeListener(_updateRoomInputState);
    _roomController.dispose();
    super.dispose();
  }
}
