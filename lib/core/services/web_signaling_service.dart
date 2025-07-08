import 'dart:math';
import 'dart:async';
import '../models/p2p_models.dart';

// Web-specific SignalingService using BroadcastChannel
class WebSignalingService {
  static final WebSignalingService _instance = WebSignalingService._internal();
  factory WebSignalingService() => _instance;
  WebSignalingService._internal();

  String? _localPeerId;
  String? _roomId;
  final Map<String, PeerInfo> _connectedPeers = {};
  bool _isInitialized = false;
  Timer? _heartbeatTimer;

  // Callbacks
  Function(SignalingMessage)? onMessage;
  Function(PeerInfo)? onPeerJoined;
  Function(String)? onPeerLeft;
  Function(String)? onError;
  Function(bool)? onConnectionStatusChanged;

  void initialize(String roomId, {String? signalingServerUrl}) {
    _roomId = roomId;
    _localPeerId = _generatePeerId();

    try {
      _initializeBroadcastChannelSignaling();
      _isInitialized = true;
      _startHeartbeat();
      onConnectionStatusChanged?.call(true);
    } catch (e) {
      onError?.call('Failed to initialize signaling: $e');
    }
  }

  void _initializeBroadcastChannelSignaling() {
    // This will be implemented using dart:html for web
    print('Initializing BroadcastChannel signaling for room: $_roomId');

    // Announce our presence immediately
    _announcePresence();

    // For demo purposes, simulate peer discovery
    _simulatePeerDiscovery();
  }

  void _announcePresence() {
    print('Announcing presence: $_localPeerId in room $_roomId');
    // In real implementation, this would broadcast via BroadcastChannel
  }

  void _simulatePeerDiscovery() {
    // For testing, simulate discovering peers
    Future.delayed(Duration(seconds: 3), () {
      if (_isInitialized) {
        final mockPeer = PeerInfo(
          id: 'peer_${_generatePeerId()}',
          name: 'Test Peer',
          connectedAt: DateTime.now(),
          isConnected: true,
        );

        _connectedPeers[mockPeer.id] = mockPeer;
        onPeerJoined?.call(mockPeer);
      }
    });
  }

  void _startHeartbeat() {
    _heartbeatTimer?.cancel();
    _heartbeatTimer = Timer.periodic(Duration(seconds: 30), (timer) {
      if (_isInitialized) {
        _announcePresence();
      }
    });
  }

  void sendSignalingMessage(SignalingMessage message) {
    final messageWithFrom = SignalingMessage(
      type: message.type,
      from: _localPeerId,
      to: message.to,
      data: message.data,
      timestamp: message.timestamp,
    );

    print(
        'Sending signaling message: ${message.type} from $_localPeerId to ${message.to}');

    // In real implementation, this would send via BroadcastChannel
    // For now, we'll simulate message delivery
    _simulateMessageDelivery(messageWithFrom);
  }

  void _simulateMessageDelivery(SignalingMessage message) {
    // Simulate message being received by other peer
    Future.delayed(Duration(milliseconds: 100), () {
      if (message.type == 'offer') {
        // Simulate peer sending answer
        final answerMessage = SignalingMessage(
          type: 'answer',
          from: message.to ?? 'mock_peer',
          to: message.from,
          data: {
            'sdp': 'mock_answer_sdp',
            'type': 'answer',
          },
          timestamp: DateTime.now(),
        );
        onMessage?.call(answerMessage);
      }
    });
  }

  String _generatePeerId() {
    final random = Random();
    const chars = 'abcdefghijklmnopqrstuvwxyz0123456789';
    return String.fromCharCodes(
      List.generate(
          8, (index) => chars.codeUnitAt(random.nextInt(chars.length))),
    );
  }

  // Public getters
  String? get localPeerId => _localPeerId;
  String? get roomId => _roomId;
  List<PeerInfo> get connectedPeers => _connectedPeers.values.toList();
  bool get isInitialized => _isInitialized;
  bool get isConnectedToServer => _isInitialized;

  void disconnect() {
    if (_localPeerId != null) {
      print('Leaving room: $_localPeerId');
    }

    _heartbeatTimer?.cancel();
    _connectedPeers.clear();
    _localPeerId = null;
    _roomId = null;
    _isInitialized = false;
    onConnectionStatusChanged?.call(false);
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
