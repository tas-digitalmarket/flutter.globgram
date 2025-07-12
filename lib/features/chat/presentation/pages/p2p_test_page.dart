import 'package:flutter/material.dart';
import '../../../../core/services/p2p_manager.dart';
import '../../../../core/models/p2p_models.dart';
import '../../../../core/utils/app_logger.dart';

class P2PTestPage extends StatefulWidget {
  const P2PTestPage({super.key});

  @override
  State<P2PTestPage> createState() => _P2PTestPageState();
}

class _P2PTestPageState extends State<P2PTestPage> {
  final P2PManager _p2pManager = P2PManager();
  final AppLogger _logger = AppLogger();
  final TextEditingController _roomController = TextEditingController();
  final TextEditingController _messageController = TextEditingController();

  P2PConnectionInfo _connectionInfo = const P2PConnectionInfo(
    roomId: '',
    localPeerId: '',
  );

  final List<String> _messages = [];
  String _status = 'Disconnected';

  @override
  void initState() {
    super.initState();
    _setupP2PCallbacks();
    _setupLoggerCallback();
  }

  void _setupLoggerCallback() {
    _logger.onLogAdded = () {
      if (mounted) {
        setState(() {});
      }
    };
  }

  void _setupP2PCallbacks() {
    _p2pManager.onConnectionInfoChanged = (info) {
      setState(() {
        _connectionInfo = info;
        _status = _getStatusText(info.connectionState);
      });
    };

    _p2pManager.onMessageReceived = (message, fromPeerId, timestamp) {
      setState(() {
        _messages.add('[$fromPeerId]: $message');
      });
    };

    _p2pManager.onError = (error) {
      setState(() {
        _messages.add('ERROR: $error');
      });
    };
  }

  String _getStatusText(PeerConnectionState state) {
    switch (state) {
      case PeerConnectionState.connecting:
        return 'Connecting...';
      case PeerConnectionState.connected:
        return 'Connected';
      case PeerConnectionState.disconnected:
        return 'Disconnected';
      case PeerConnectionState.failed:
        return 'Failed';
      case PeerConnectionState.closed:
        return 'Closed';
    }
  }

  void _joinRoom() async {
    final roomId = _roomController.text.trim();
    if (roomId.isNotEmpty) {
      await _p2pManager.joinRoom(roomId);
    }
  }

  void _createRoom() async {
    try {
      final roomId = await _p2pManager.createRoom();
      setState(() {
        _roomController.text = roomId;
      });
      print('📄 Room created with ID: $roomId');
    } catch (e) {
      print('❌ Failed to create room: $e');
    }
  }

  void _sendMessage() async {
    final message = _messageController.text.trim();
    if (message.isNotEmpty &&
        _connectionInfo.connectionState == PeerConnectionState.connected) {
      await _p2pManager.sendMessage(message);
      setState(() {
        _messages.add('[Me]: $message');
      });
      _messageController.clear();
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('P2P Test'),
      ),
      body: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          children: [
            // Connection Section
            Card(
              child: Padding(
                padding: const EdgeInsets.all(16.0),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text('Status: $_status',
                        style: const TextStyle(fontWeight: FontWeight.bold)),
                    const SizedBox(height: 8),
                    Text('Room ID: ${_connectionInfo.roomId}'),
                    Text(
                        'Local Peer ID: ${_connectionInfo.localPeerId.isEmpty ? "Not generated yet" : _connectionInfo.localPeerId}'),
                    Text(
                        'Connected Peers: ${_connectionInfo.connectedPeers.length}'),
                    const SizedBox(height: 16),
                    Row(
                      children: [
                        Expanded(
                          child: TextField(
                            controller: _roomController,
                            decoration: const InputDecoration(
                              labelText: 'Room ID',
                              border: OutlineInputBorder(),
                            ),
                          ),
                        ),
                        const SizedBox(width: 8),
                        ElevatedButton(
                          onPressed: _connectionInfo.connectionState ==
                                  PeerConnectionState.disconnected
                              ? _createRoom
                              : null,
                          child: const Text('Create Room'),
                        ),
                        const SizedBox(width: 8),
                        ElevatedButton(
                          onPressed: _connectionInfo.connectionState ==
                                  PeerConnectionState.disconnected
                              ? _joinRoom
                              : null,
                          child: const Text('Join Room'),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            ),

            const SizedBox(height: 16),

            // Messages Section
            Expanded(
              flex: 2,
              child: Card(
                child: Padding(
                  padding: const EdgeInsets.all(16.0),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text('Messages:',
                          style: TextStyle(fontWeight: FontWeight.bold)),
                      const SizedBox(height: 8),
                      Expanded(
                        child: Container(
                          width: double.infinity,
                          decoration: BoxDecoration(
                            border: Border.all(color: Colors.grey),
                            borderRadius: BorderRadius.circular(4),
                          ),
                          child: ListView.builder(
                            itemCount: _messages.length,
                            itemBuilder: (context, index) {
                              return Padding(
                                padding: const EdgeInsets.all(4.0),
                                child: Text(_messages[index]),
                              );
                            },
                          ),
                        ),
                      ),
                      const SizedBox(height: 8),
                      Row(
                        children: [
                          Expanded(
                            child: TextField(
                              controller: _messageController,
                              decoration: const InputDecoration(
                                labelText: 'Message',
                                border: OutlineInputBorder(),
                              ),
                              onSubmitted: (_) => _sendMessage(),
                            ),
                          ),
                          const SizedBox(width: 8),
                          ElevatedButton(
                            onPressed: _connectionInfo.connectionState ==
                                    PeerConnectionState.connected
                                ? _sendMessage
                                : null,
                            child: const Text('Send'),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
              ),
            ),

            const SizedBox(height: 16),

            // Debug Logs Section
            Expanded(
              flex: 1,
              child: Card(
                child: Padding(
                  padding: const EdgeInsets.all(16.0),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          const Text('Debug Logs:',
                              style: TextStyle(fontWeight: FontWeight.bold)),
                          const Spacer(),
                          ElevatedButton(
                            onPressed: () {
                              _logger.clear();
                            },
                            child: const Text('Clear'),
                          ),
                        ],
                      ),
                      const SizedBox(height: 8),
                      Expanded(
                        child: Container(
                          width: double.infinity,
                          decoration: BoxDecoration(
                            border: Border.all(color: Colors.grey),
                            borderRadius: BorderRadius.circular(4),
                          ),
                          child: ListView.builder(
                            itemCount: _logger.logs.length,
                            itemBuilder: (context, index) {
                              final log = _logger.logs[index];
                              return Padding(
                                padding: const EdgeInsets.symmetric(
                                    horizontal: 8.0, vertical: 2.0),
                                child: RichText(
                                  text: TextSpan(
                                    style: const TextStyle(
                                        color: Colors.black, fontSize: 12),
                                    children: [
                                      TextSpan(
                                        text: '[${log.formattedTime}] ',
                                        style: const TextStyle(
                                            color: Colors.grey),
                                      ),
                                      TextSpan(
                                        text: '${log.prefix} ',
                                        style: TextStyle(color: log.color),
                                      ),
                                      TextSpan(text: log.message),
                                    ],
                                  ),
                                ),
                              );
                            },
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  @override
  void dispose() {
    _p2pManager.dispose();
    _roomController.dispose();
    _messageController.dispose();
    super.dispose();
  }
}
