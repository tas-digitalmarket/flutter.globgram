import 'package:flutter/material.dart';
import '../../../../core/services/p2p_manager.dart';
import '../../../../core/models/p2p_models.dart';

class P2PTestPage extends StatefulWidget {
  const P2PTestPage({Key? key}) : super(key: key);

  @override
  State<P2PTestPage> createState() => _P2PTestPageState();
}

class _P2PTestPageState extends State<P2PTestPage> {
  final P2PManager _p2pManager = P2PManager();
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
                    Text('Local Peer ID: ${_connectionInfo.localPeerId.isEmpty ? "Not generated yet" : _connectionInfo.localPeerId}'),
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
