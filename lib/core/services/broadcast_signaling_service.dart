import 'dart:convert';
import 'dart:html' as html;
import 'dart:math';
import '../models/p2p_models.dart';
import '../utils/app_logger.dart';

/// Real BroadcastChannel-based signaling for web platform
/// This allows multiple browser tabs to communicate and establish P2P connections
class BroadcastSignalingService {
  // Remove singleton pattern to allow multiple instances per tab
  String? _localPeerId;
  String? _roomId;
  html.BroadcastChannel? _channel;
  final Map<String, PeerInfo> _connectedPeers = {};
  bool _isInitialized = false;
  DateTime? _lastHeartbeat;

  // Callbacks
  Function(SignalingMessage)? onMessage;
  Function(PeerInfo)? onPeerJoined;
  Function(String)? onPeerLeft;
  Function(String)? onError;
  Function(bool)? onConnectionStatusChanged;
  Function(String, String, DateTime)?
      onChatMessage; // (content, fromPeerId, timestamp)

  void initialize(String roomId, {String? signalingServerUrl}) {
    try {
      final logger = AppLogger();
      _roomId = roomId;
      _localPeerId = _generatePeerId();

      logger.success('🆔 Generated unique Peer ID: $_localPeerId');
      logger.info('🏠 Initializing for room: $roomId');

      // Create BroadcastChannel for this room
      final channelName = 'globgram_room_$roomId';
      _channel = html.BroadcastChannel(channelName);

      // Listen for messages
      _channel!.onMessage.listen((event) {
        _handleBroadcastMessage(event.data);
      });

      _isInitialized = true;
      _lastHeartbeat = DateTime.now();

      logger.success('✅ BroadcastSignalingService initialized');
      logger.info('📄 Room: $roomId');
      logger.info('📄 Local Peer ID: $_localPeerId');
      logger.debug('🐛 Channel: $channelName');

      onConnectionStatusChanged?.call(true);

      // Send announcement that we joined
      _announcePresence();

      // Start heartbeat to keep connection alive and discover peers
      _startHeartbeat();
    } catch (e) {
      final logger = AppLogger();
      logger.error('Failed to initialize BroadcastSignalingService: $e');
      onError?.call('Failed to initialize signaling: $e');
    }
  }

  void _handleBroadcastMessage(dynamic data) {
    try {
      final logger = AppLogger();
      final messageMap = json.decode(data as String);
      
      final messageType = messageMap['type'] as String;
      final fromPeerId = messageMap['from'] as String?;
      
      logger.debug(
          'Received broadcast: $messageType from $fromPeerId');

      // More detailed debug for peer ID comparison
      logger.debug('🔍 Message from: "$fromPeerId"');
      logger.debug('🔍 Local peer: "$_localPeerId"');
      logger.debug('🔍 Are equal: ${fromPeerId == _localPeerId}');

      // Ignore messages from ourselves - more robust check
      if (fromPeerId == null || fromPeerId == _localPeerId) {
        logger.debug('🚫 Ignoring own message from $_localPeerId');
        return;
      } else {
        logger.success(
            '✅ Processing message from $fromPeerId (local: $_localPeerId)');
      }

      switch (messageMap['type']) {
        case 'peer_announcement':
          _handlePeerAnnouncement(messageMap);
          break;

        case 'peer_response':
          _handlePeerResponse(messageMap);
          break;

        case 'heartbeat':
          _handleHeartbeat(messageMap);
          break;

        case 'peer_leaving':
          _handlePeerLeaving(messageMap);
          break;

        case 'chat_message':
          _handleChatMessage(messageMap);
          break;

        case 'offer':
        case 'answer':
        case 'ice_candidate':
          // WebRTC signaling messages
          _handleSignalingMessage(messageMap);
          break;

        default:
          logger.warning('Unknown message type: ${messageMap['type']}');
      }
    } catch (e) {
      AppLogger().error('Error handling broadcast message: $e');
    }
  }

  void _handlePeerAnnouncement(Map<String, dynamic> message) {
    final logger = AppLogger();
    final peerId = message['from'] as String;
    final peerName = message['peer_name'] as String? ?? 'Unknown';

    logger.success('🎉 New peer announced: $peerId ($peerName)');

    // Add peer to our list
    final peer = PeerInfo(
      id: peerId,
      name: peerName,
      connectedAt: DateTime.now(),
      isConnected: true, // Mark as connected for now
    );

    _connectedPeers[peerId] = peer;
    onPeerJoined?.call(peer);

    // Send response back to acknowledge
    _sendBroadcast({
      'type': 'peer_response',
      'from': _localPeerId!,
      'to': peerId,
      'peer_name': 'Flutter User ${_localPeerId!.substring(0, 6)}',
      'timestamp': DateTime.now().toIso8601String(),
    });
    
    logger.info('📢 Sent peer response to $peerId');
  }

  void _handlePeerResponse(Map<String, dynamic> message) {
    final logger = AppLogger();
    final peerId = message['from'] as String;
    final peerName = message['peer_name'] as String? ?? 'Unknown';

    logger.success('Peer responded: $peerId ($peerName)');

    // Add or update peer
    final peer = PeerInfo(
      id: peerId,
      name: peerName,
      connectedAt: DateTime.now(),
      isConnected: false,
    );

    _connectedPeers[peerId] = peer;
    onPeerJoined?.call(peer);
  }

  void _handleHeartbeat(Map<String, dynamic> message) {
    final peerId = message['from'] as String;

    // Update peer's last seen time
    if (_connectedPeers.containsKey(peerId)) {
      final peer = _connectedPeers[peerId]!;
      _connectedPeers[peerId] = PeerInfo(
        id: peer.id,
        name: peer.name,
        connectedAt: peer.connectedAt,
        isConnected: peer.isConnected,
        lastSeen: DateTime.now(),
      );
    }
  }

  void _handlePeerLeaving(Map<String, dynamic> message) {
    final logger = AppLogger();
    final peerId = message['from'] as String;
    logger.info('Peer leaving: $peerId');

    _connectedPeers.remove(peerId);
    onPeerLeft?.call(peerId);
  }

  void _handleChatMessage(Map<String, dynamic> message) {
    final logger = AppLogger();
    final fromPeerId = message['from'] as String;

    // Double check - ignore messages from ourselves
    if (fromPeerId == _localPeerId) {
      logger.debug('🚫 Ignoring own chat message from $_localPeerId');
      return;
    }

    // Extract content from data field
    final data = message['data'] as Map<String, dynamic>;
    final content = data['content'] as String;
    final timestamp = DateTime.parse(data['timestamp'] as String);

    logger.success('💬 Chat message received from $fromPeerId: "$content"');
    logger.info(
        '📨 Message details: fromPeer=$fromPeerId, localPeer=$_localPeerId');
    
    // Call the callback to show message in UI
    onChatMessage?.call(content, fromPeerId, timestamp);
  }

  void _handleSignalingMessage(Map<String, dynamic> messageMap) {
    final logger = AppLogger();
    final signalingMessage = SignalingMessage(
      type: messageMap['type'],
      from: messageMap['from'],
      to: messageMap['to'],
      data: messageMap['data'] ?? messageMap,
      timestamp: DateTime.parse(messageMap['timestamp']),
    );

    logger.debug(
        'Signaling message: ${signalingMessage.type} from ${signalingMessage.from}');
    onMessage?.call(signalingMessage);
  }

  void _announcePresence() {
    final logger = AppLogger();
    final announcement = {
      'type': 'peer_announcement',
      'from': _localPeerId!,
      'peer_name': 'User ${_localPeerId!.substring(_localPeerId!.length - 8)}', // Last 8 chars
      'room_id': _roomId!,
      'timestamp': DateTime.now().toIso8601String(),
    };

    logger.info('📄 Announcing presence in room $_roomId');
    logger.debug('🎯 Announcement data: $announcement');
    _sendBroadcast(announcement);
  }

  void _startHeartbeat() {
    // Send heartbeat every 10 seconds
    Future.delayed(Duration(seconds: 10), () {
      if (_isInitialized) {
        _sendHeartbeat();
        _startHeartbeat(); // Continue heartbeat
      }
    });
  }

  void _sendHeartbeat() {
    _lastHeartbeat = DateTime.now();
    _sendBroadcast({
      'type': 'heartbeat',
      'from': _localPeerId!,
      'timestamp': _lastHeartbeat!.toIso8601String(),
    });
  }

  void _sendBroadcast(Map<String, dynamic> data) {
    if (_channel != null) {
      final jsonData = json.encode(data);
      _channel!.postMessage(jsonData);
      AppLogger().debug('Broadcast sent: ${data['type']}');
    }
  }

  void sendSignalingMessage(SignalingMessage message) {
    final logger = AppLogger();
    logger.info(
        'Sending signaling: ${message.type} from ${message.from} to ${message.to}');

    _sendBroadcast({
      'type': message.type,
      'from': message.from,
      'to': message.to,
      'data': message.data,
      'timestamp': message.timestamp.toIso8601String(),
    });
  }

  String _generatePeerId() {
    final random = Random();
    const chars = 'abcdefghijklmnopqrstuvwxyz0123456789';
    final timestamp = DateTime.now().microsecondsSinceEpoch; // More precision
    final randomPart = String.fromCharCodes(
      List.generate(
          8, (index) => chars.codeUnitAt(random.nextInt(chars.length))),
    );
    return 'peer_${randomPart}_$timestamp';
  }

  // Getters
  String? get localPeerId => _localPeerId;
  String? get roomId => _roomId;
  List<PeerInfo> get connectedPeers => _connectedPeers.values.toList();
  bool get isInitialized => _isInitialized;
  bool get isConnectedToServer => _isInitialized;

  void disconnect() {
    final logger = AppLogger();
    logger.info('Disconnecting BroadcastSignalingService...');

    // Announce that we're leaving
    if (_isInitialized && _localPeerId != null) {
      _sendBroadcast({
        'type': 'peer_leaving',
        'from': _localPeerId!,
        'timestamp': DateTime.now().toIso8601String(),
      });
    }

    _channel?.close();
    _channel = null;
    _connectedPeers.clear();
    _localPeerId = null;
    _roomId = null;
    _isInitialized = false;
    _lastHeartbeat = null;

    onConnectionStatusChanged?.call(false);
    logger.success('BroadcastSignalingService disconnected');
  }

  void dispose() {
    disconnect();
    onMessage = null;
    onPeerJoined = null;
    onPeerLeft = null;
    onError = null;
    onConnectionStatusChanged = null;
  }
}
