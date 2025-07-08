import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:easy_localization/easy_localization.dart';
import '../bloc/bloc_exports.dart';
import '../../../../core/models/p2p_models.dart';
import '../../../../core/utils/app_logger.dart';
import '../../../settings/presentation/pages/settings_page_simple.dart';
import 'log_view_page.dart';

class P2PChatPage extends StatefulWidget {
  final String roomId;

  const P2PChatPage({
    super.key,
    required this.roomId,
  });

  @override
  State<P2PChatPage> createState() => _P2PChatPageState();
}

class _P2PChatPageState extends State<P2PChatPage> {
  final TextEditingController _messageController = TextEditingController();
  late P2PBlocFixed _p2pBloc;

  @override
  void initState() {
    super.initState();
    _p2pBloc = P2PBlocFixed();
    _p2pBloc.add(JoinRoom(widget.roomId));
  }

  @override
  Widget build(BuildContext context) {
    return BlocProvider.value(
      value: _p2pBloc,
      child: Scaffold(
        appBar: AppBar(
          title: Text('app_name'.tr()),
          backgroundColor: Theme.of(context).primaryColor,
          foregroundColor: Colors.white,
          actions: [
            // Debug Logs Button
            IconButton(
              icon: const Icon(Icons.list_alt),
              onPressed: () {
                Navigator.push(
                  context,
                  MaterialPageRoute(
                    builder: (context) => const LogViewPage(),
                  ),
                );
              },
              tooltip: 'View Debug Logs',
            ),
            // Test Button
            IconButton(
              icon: const Icon(Icons.bug_report),
              onPressed: _runConnectionTest,
              tooltip: 'Test Connection',
            ),
            // Connection Status
            BlocBuilder<P2PBlocFixed, P2PState>(
              builder: (context, state) {
                return IconButton(
                  icon: Icon(
                    _getConnectionIcon(state.connectionInfo.connectionState),
                  ),
                  onPressed: () => _showConnectionInfo(state.connectionInfo),
                );
              },
            ),
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
            // Connection Status Bar
            BlocBuilder<P2PBlocFixed, P2PState>(
              builder: (context, state) {
                return _buildConnectionStatusBar(state.connectionInfo);
              },
            ),

            // Messages List
            Expanded(
              child: BlocBuilder<P2PBlocFixed, P2PState>(
                builder: (context, state) {
                  if (state.messages.isEmpty) {
                    return _buildEmptyState();
                  }

                  return ListView.builder(
                    padding: const EdgeInsets.all(16),
                    itemCount: state.messages.length,
                    itemBuilder: (context, index) {
                      final message = state.messages[index];
                      return _buildMessageBubble(message);
                    },
                  );
                },
              ),
            ),

            // Input Area
            _buildInputArea(),
          ],
        ),
      ),
    );
  }

  Widget _buildConnectionStatusBar(P2PConnectionInfo connectionInfo) {
    Color statusColor;
    String statusText;
    IconData statusIcon;

    switch (connectionInfo.connectionState) {
      case PeerConnectionState.connecting:
        statusColor = Colors.orange;
        statusText = 'connecting'.tr();
        statusIcon = Icons.wifi_tethering;
        break;
      case PeerConnectionState.connected:
        statusColor = Colors.green;
        statusText = 'connected'.tr();
        statusIcon = Icons.wifi;
        break;
      case PeerConnectionState.failed:
        statusColor = Colors.red;
        statusText = 'connection_failed'.tr();
        statusIcon = Icons.wifi_off;
        break;
      case PeerConnectionState.disconnected:
      default:
        statusColor = Colors.grey;
        statusText = 'disconnected'.tr();
        statusIcon = Icons.wifi_off;
    }

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 16),
      decoration: BoxDecoration(
        color: statusColor.withOpacity(0.1),
        border: Border(
          bottom: BorderSide(color: statusColor.withOpacity(0.3)),
        ),
      ),
      child: Column(
        children: [
          // Status Row
          Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(statusIcon, color: statusColor, size: 16),
              const SizedBox(width: 8),
              Text(
                statusText,
                style: TextStyle(
                  color: statusColor,
                  fontWeight: FontWeight.w600,
                ),
              ),
              if (connectionInfo.connectedPeers.isNotEmpty) ...[
                const SizedBox(width: 8),
                Text(
                  '(${connectionInfo.connectedPeers.length} peers)',
                  style: TextStyle(
                    color: statusColor,
                    fontSize: 12,
                  ),
                ),
              ],
            ],
          ),

          // Room Info Row
          const SizedBox(height: 4),
          Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Text(
                'Room: ${widget.roomId}',
                style: TextStyle(
                  color: statusColor.withOpacity(0.8),
                  fontSize: 12,
                  fontFamily: 'monospace',
                ),
              ),
              if (connectionInfo.localPeerId.isNotEmpty) ...[
                const SizedBox(width: 12),
                Text(
                  'You: ${connectionInfo.localPeerId.substring(0, 4)}',
                  style: TextStyle(
                    color: statusColor.withOpacity(0.8),
                    fontSize: 12,
                    fontFamily: 'monospace',
                  ),
                ),
              ],
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildEmptyState() {
    return BlocBuilder<P2PBlocFixed, P2PState>(
      builder: (context, state) {
        return Center(
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
                'Room: ${widget.roomId}',
                style: Theme.of(context).textTheme.headlineSmall?.copyWith(
                      color: Colors.grey.shade600,
                      fontWeight: FontWeight.w600,
                    ),
              ),
              const SizedBox(height: 8),
              if (state.connectionInfo.localPeerId.isNotEmpty) ...[
                Text(
                  'Your ID: ${state.connectionInfo.localPeerId}',
                  style: TextStyle(
                    fontFamily: 'monospace',
                    color: Colors.blue.shade600,
                    fontWeight: FontWeight.w500,
                  ),
                ),
                const SizedBox(height: 12),
              ],
              Text(
                state.connectionInfo.connectedPeers.isEmpty
                    ? 'Waiting for others to join...'
                    : 'Connected to ${state.connectionInfo.connectedPeers.length} peer(s)',
                style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                      color: Colors.grey.shade500,
                    ),
              ),
              const SizedBox(height: 16),
              if (state.connectionInfo.connectedPeers.isEmpty) ...[
                Container(
                  padding: const EdgeInsets.all(16),
                  margin: const EdgeInsets.symmetric(horizontal: 32),
                  decoration: BoxDecoration(
                    color: Colors.blue.shade50,
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(color: Colors.blue.shade200),
                  ),
                  child: Column(
                    children: [
                      Icon(
                        Icons.share,
                        color: Colors.blue.shade600,
                        size: 32,
                      ),
                      const SizedBox(height: 8),
                      Text(
                        'Share this Room ID with others:',
                        style: TextStyle(
                          color: Colors.blue.shade700,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                      const SizedBox(height: 8),
                      Text(
                        widget.roomId,
                        style: TextStyle(
                          fontSize: 20,
                          fontFamily: 'monospace',
                          color: Colors.blue.shade800,
                          fontWeight: FontWeight.bold,
                          letterSpacing: 2,
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 16),
              ],
              ElevatedButton.icon(
                onPressed: () => _p2pBloc.add(JoinRoom(widget.roomId)),
                icon: const Icon(Icons.refresh),
                label: Text('retry'.tr()),
                style: ElevatedButton.styleFrom(
                  backgroundColor: Theme.of(context).primaryColor,
                  foregroundColor: Colors.white,
                ),
              ),
            ],
          ),
        );
      },
    );
  }

  Widget _buildMessageBubble(P2PMessage message) {
    final isLocal = message.isLocal;
    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      child: Align(
        alignment: isLocal ? Alignment.centerRight : Alignment.centerLeft,
        child: Container(
          constraints: BoxConstraints(
            maxWidth: MediaQuery.of(context).size.width * 0.75,
          ),
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
          decoration: BoxDecoration(
            color:
                isLocal ? Theme.of(context).primaryColor : Colors.grey.shade200,
            borderRadius: BorderRadius.circular(18),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisSize: MainAxisSize.min,
            children: [
              if (!isLocal) ...[
                Text(
                  'Peer ${message.fromPeerId}',
                  style: TextStyle(
                    fontSize: 12,
                    fontWeight: FontWeight.w600,
                    color: Colors.grey.shade600,
                  ),
                ),
                const SizedBox(height: 4),
              ],
              Text(
                message.content,
                style: TextStyle(
                  color: isLocal ? Colors.white : Colors.black87,
                  fontSize: 16,
                ),
              ),
              const SizedBox(height: 4),
              Text(
                DateFormat('HH:mm').format(message.timestamp),
                style: TextStyle(
                  fontSize: 11,
                  color: isLocal
                      ? Colors.white.withOpacity(0.7)
                      : Colors.grey.shade600,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildInputArea() {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Theme.of(context).scaffoldBackgroundColor,
        border: Border(
          top: BorderSide(color: Colors.grey.shade300),
        ),
      ),
      child: Row(
        children: [
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

          // Send button
          BlocBuilder<P2PBlocFixed, P2PState>(
            builder: (context, state) {
              final isConnected = state.connectionInfo.connectionState ==
                  PeerConnectionState.connected;

              return FloatingActionButton(
                onPressed: isConnected ? _sendMessage : null,
                mini: true,
                backgroundColor:
                    isConnected ? Theme.of(context).primaryColor : Colors.grey,
                child: const Icon(Icons.send, color: Colors.white),
              );
            },
          ),
        ],
      ),
    );
  }

  void _sendMessage() {
    final message = _messageController.text.trim();
    if (message.isNotEmpty) {
      _p2pBloc.add(SendMessage(message));
      _messageController.clear();
    }
  }

  IconData _getConnectionIcon(PeerConnectionState state) {
    switch (state) {
      case PeerConnectionState.connecting:
        return Icons.wifi_tethering;
      case PeerConnectionState.connected:
        return Icons.wifi;
      case PeerConnectionState.failed:
        return Icons.error;
      case PeerConnectionState.disconnected:
      default:
        return Icons.wifi_off;
    }
  }

  void _showConnectionInfo(P2PConnectionInfo connectionInfo) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Connection Info'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('Room ID: ${connectionInfo.roomId}'),
            const SizedBox(height: 8),
            Text('Your ID: ${connectionInfo.localPeerId}'),
            const SizedBox(height: 8),
            Text('Status: ${connectionInfo.connectionState.name}'),
            const SizedBox(height: 8),
            Text('Connected Peers: ${connectionInfo.connectedPeers.length}'),
            if (connectionInfo.connectedPeers.isNotEmpty) ...[
              const SizedBox(height: 8),
              ...connectionInfo.connectedPeers.map(
                (peer) => Text('• ${peer.id}'),
              ),
            ],
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('OK'),
          ),
        ],
      ),
    );
  }

  void _runConnectionTest() {
    final logger = AppLogger();

    logger.info('=== REAL P2P CONNECTION TEST STARTED ===');
    logger.info('Room ID: ${widget.roomId}');

    final state = _p2pBloc.state;
    logger.info('Current State: ${state.connectionInfo.connectionState}');
    logger.info('Local Peer ID: ${state.connectionInfo.localPeerId}');
    logger
        .info('Connected Peers: ${state.connectionInfo.connectedPeers.length}');

    for (final peer in state.connectionInfo.connectedPeers) {
      logger.debug(
          'Peer: ${peer.id} (${peer.isConnected ? "Connected" : "Disconnected"})');
    }

    // Test message sending
    final testMessage =
        'REAL TEST MESSAGE ${DateTime.now().millisecondsSinceEpoch}';
    logger.info('Sending test message: $testMessage');
    _p2pBloc.add(SendMessage(testMessage));

    // Show result dialog
    _showTestResults();
    logger.success('=== REAL P2P CONNECTION TEST COMPLETED ===');
  }

  void _showTestResults() {
    final state = _p2pBloc.state;

    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('🔗 Real P2P Connection Test'),
        content: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Current Status
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: Colors.blue.shade50,
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(color: Colors.blue.shade200),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text('📊 Current Status:',
                        style: TextStyle(fontWeight: FontWeight.bold)),
                    const SizedBox(height: 8),
                    _buildTestResultRow('Room ID', widget.roomId),
                    _buildTestResultRow(
                        'Local Peer ID', state.connectionInfo.localPeerId),
                    _buildTestResultRow('Connection State',
                        state.connectionInfo.connectionState.name),
                    _buildTestResultRow('Connected Peers',
                        '${state.connectionInfo.connectedPeers.length}'),
                  ],
                ),
              ),

              const SizedBox(height: 16),

              // Test Instructions
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: Colors.green.shade50,
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(color: Colors.green.shade200),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text('🧪 How to Test Real P2P:',
                        style: TextStyle(fontWeight: FontWeight.bold)),
                    const SizedBox(height: 8),
                    Text(
                        '1. Copy this URL: http://localhost:8081/#/chat/${widget.roomId}'),
                    const SizedBox(height: 4),
                    const Text('2. Open a NEW browser tab'),
                    const SizedBox(height: 4),
                    const Text('3. Paste the URL in the new tab'),
                    const SizedBox(height: 4),
                    const Text('4. Wait for "Connected" status'),
                    const SizedBox(height: 4),
                    const Text('5. Send messages between tabs!'),
                    const SizedBox(height: 8),
                    Container(
                      padding: const EdgeInsets.all(8),
                      decoration: BoxDecoration(
                        color: Colors.yellow.shade100,
                        borderRadius: BorderRadius.circular(4),
                      ),
                      child: const Text(
                        '💡 Tip: Check browser console (F12) in both tabs for connection logs',
                        style: TextStyle(fontSize: 12),
                      ),
                    ),
                  ],
                ),
              ),

              const SizedBox(height: 16),

              // Quick Actions
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: Colors.orange.shade50,
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(color: Colors.orange.shade200),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text('⚡ Quick Actions:',
                        style: TextStyle(fontWeight: FontWeight.bold)),
                    const SizedBox(height: 8),
                    Wrap(
                      spacing: 8,
                      runSpacing: 8,
                      children: [
                        ElevatedButton.icon(
                          onPressed: () {
                            Navigator.pop(context);
                            _p2pBloc.add(JoinRoom(widget.roomId)); // Rejoin
                          },
                          icon: const Icon(Icons.refresh, size: 16),
                          label: const Text('Rejoin Room'),
                          style: ElevatedButton.styleFrom(
                            backgroundColor: Colors.blue,
                            foregroundColor: Colors.white,
                            padding: const EdgeInsets.symmetric(
                                horizontal: 12, vertical: 8),
                          ),
                        ),
                        ElevatedButton.icon(
                          onPressed: () {
                            Navigator.pop(context);
                            _p2pBloc.add(SendMessage(
                                'Ping from ${state.connectionInfo.localPeerId}'));
                          },
                          icon: const Icon(Icons.send, size: 16),
                          label: const Text('Send Ping'),
                          style: ElevatedButton.styleFrom(
                            backgroundColor: Colors.green,
                            foregroundColor: Colors.white,
                            padding: const EdgeInsets.symmetric(
                                horizontal: 12, vertical: 8),
                          ),
                        ),
                        ElevatedButton.icon(
                          onPressed: () {
                            // Copy URL to clipboard would need additional package
                            final url =
                                'http://localhost:8081/#/chat/${widget.roomId}';
                            print('Copy this URL: $url');
                            ScaffoldMessenger.of(context).showSnackBar(
                              SnackBar(
                                content: Text('URL logged to console: $url'),
                                backgroundColor: Colors.blue,
                              ),
                            );
                          },
                          icon: const Icon(Icons.copy, size: 16),
                          label: const Text('Log URL'),
                          style: ElevatedButton.styleFrom(
                            backgroundColor: Colors.purple,
                            foregroundColor: Colors.white,
                            padding: const EdgeInsets.symmetric(
                                horizontal: 12, vertical: 8),
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Close'),
          ),
        ],
      ),
    );
  }

  Widget _buildTestResultRow(String label, String value) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 2),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(
            width: 120,
            child: Text(
              '$label:',
              style: const TextStyle(fontWeight: FontWeight.w600),
            ),
          ),
          Expanded(
            child: Text(
              value,
              style: const TextStyle(fontFamily: 'monospace'),
            ),
          ),
        ],
      ),
    );
  }

  @override
  void dispose() {
    _messageController.dispose();
    _p2pBloc.add(const LeaveRoom());
    _p2pBloc.close();
    super.dispose();
  }
}
