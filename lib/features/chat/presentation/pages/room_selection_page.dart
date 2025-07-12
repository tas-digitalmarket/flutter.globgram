import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:easy_localization/easy_localization.dart';
import 'p2p_chat_page.dart';

/// Clean Room Selection Page - No fake Room IDs, only real Firestore implementation
class RoomSelectionPage extends StatefulWidget {
  const RoomSelectionPage({super.key});

  @override
  State<RoomSelectionPage> createState() => _RoomSelectionPageState();
}

class _RoomSelectionPageState extends State<RoomSelectionPage> {
  final TextEditingController _roomController = TextEditingController();
  bool _hasRoomInput = false;

  @override
  void initState() {
    super.initState();
    _roomController.addListener(_updateRoomInputState);
  }

  void _updateRoomInputState() {
    setState(() {
      _hasRoomInput = _roomController.text.trim().isNotEmpty;
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Container(
        decoration: BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
            colors: [
              Theme.of(context).primaryColor.withOpacity(0.1),
              Theme.of(context).primaryColor.withOpacity(0.05),
            ],
          ),
        ),
        child: SafeArea(
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

                // Action Buttons
                Row(
                  children: [
                    // Join Room Button
                    Expanded(
                      child: ElevatedButton.icon(
                        onPressed: _hasRoomInput ? _joinRoom : null,
                        icon: const Icon(Icons.login),
                        label: Text('join_room'.tr()),
                        style: ElevatedButton.styleFrom(
                          backgroundColor: Theme.of(context).primaryColor,
                          foregroundColor: Colors.white,
                          padding: const EdgeInsets.symmetric(vertical: 16),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(12),
                          ),
                        ),
                      ),
                    ),

                    const SizedBox(width: 16),

                    // Create Room Button
                    Expanded(
                      child: ElevatedButton.icon(
                        onPressed: _createNewRoom,
                        icon: const Icon(Icons.add),
                        label: Text('create_room'.tr()),
                        style: ElevatedButton.styleFrom(
                          backgroundColor: Colors.green,
                          foregroundColor: Colors.white,
                          padding: const EdgeInsets.symmetric(vertical: 16),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(12),
                          ),
                        ),
                      ),
                    ),
                  ],
                ),

                const SizedBox(height: 32),

                // Instructions
                Container(
                  padding: const EdgeInsets.all(16),
                  decoration: BoxDecoration(
                    color: Colors.blue.shade50,
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(color: Colors.blue.shade200),
                  ),
                  child: Column(
                    children: [
                      Icon(
                        Icons.info_outline,
                        color: Colors.blue.shade600,
                        size: 24,
                      ),
                      const SizedBox(height: 8),
                      Text(
                        'Instructions',
                        style: TextStyle(
                          color: Colors.blue.shade700,
                          fontWeight: FontWeight.w600,
                          fontSize: 16,
                        ),
                      ),
                      const SizedBox(height: 8),
                      Text(
                        '• Create a room to get a real Room ID from Firestore\n'
                        '• Share the Room ID with others to join\n'
                        '• Enter a Room ID here to join an existing room\n'
                        '• All communication is peer-to-peer via WebRTC',
                        style: TextStyle(
                          color: Colors.blue.shade600,
                          fontSize: 14,
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ),
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

  void _createNewRoom() {
    // Navigate directly to P2PChatPage as creator
    // P2PManager will create the real Firestore Room ID
    Navigator.pushReplacement(
      context,
      MaterialPageRoute(
        builder: (context) => const P2PChatPage(
          roomId: '', // Empty - will be filled by P2PManager
          isCreator: true, // Mark as room creator
        ),
      ),
    );
  }

  @override
  void dispose() {
    _roomController.removeListener(_updateRoomInputState);
    _roomController.dispose();
    super.dispose();
  }
}
