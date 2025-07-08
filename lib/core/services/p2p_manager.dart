import 'dart:convert';
import 'dart:typed_data';
import 'package:flutter_webrtc/flutter_webrtc.dart';
import '../models/p2p_models.dart';
import '../utils/app_logger.dart';
import 'modern_webrtc_service.dart';
import 'firestore_signaling_service.dart';

/// P2P Manager with Firestore signaling for real WebRTC state management
/// Uses Firestore for signaling and WebRTC data channels for messaging
class P2PManager {
  final ModernWebRTCService _webRTCService = ModernWebRTCService();
  final FirestoreSignalingService _signalingService = FirestoreSignalingService();
  final AppLogger _logger = AppLogger();

  P2PConnectionInfo _connectionInfo = const P2PConnectionInfo(
    roomId: '',
    localPeerId: '',
  );

  String? _currentTargetPeer;
  RTCDataChannel? _dataChannel;
  bool _isOfferingPeer = false;

  // Callbacks
  Function(P2PConnectionInfo)? onConnectionInfoChanged;
  Function(String, String, DateTime)? onMessageReceived;
  Function(Uint8List, String, String)? onFileReceived;
  Function(String)? onError;

  P2PConnectionInfo get connectionInfo => _connectionInfo;

  /// Join a room and initialize P2P connections
  Future<void> joinRoom(String roomId) async {
    try {
      _logger.info('🚪 Joining room: $roomId');

      _updateConnectionInfo(_connectionInfo.copyWith(
        roomId: roomId,
        connectionState: PeerConnectionState.connecting,
      ));

      // Join room via Firestore signaling
      await _signalingService.joinRoom(roomId);
      _setupSignalingCallbacks();
      
      // Initialize WebRTC with STUN/TURN servers
      await _initializeWebRTC();
      _setupWebRTCCallbacks();

      _updateConnectionInfo(_connectionInfo.copyWith(
        localPeerId: 'peer_${DateTime.now().millisecondsSinceEpoch}',
      ));

      _logger.success('✅ Successfully joined room: $roomId');
    } catch (e) {
      _handleError('Failed to join room: $e');
    }
  }

  /// Create a room and initialize P2P connections
  Future<String> createRoom() async {
    try {
      _logger.info('🏠 Creating room');

      // Create room via Firestore signaling
      final roomId = await _signalingService.createRoom();
      _isOfferingPeer = true;
      
      _updateConnectionInfo(_connectionInfo.copyWith(
        roomId: roomId,
        connectionState: PeerConnectionState.connecting,
      ));

      _setupSignalingCallbacks();
      
      // Initialize WebRTC with STUN/TURN servers
      await _initializeWebRTC();
      _setupWebRTCCallbacks();

      _updateConnectionInfo(_connectionInfo.copyWith(
        localPeerId: 'peer_${DateTime.now().millisecondsSinceEpoch}',
      ));

      _logger.success('✅ Successfully created room: $roomId');
      return roomId;
    } catch (e) {
      _handleError('Failed to create room: $e');
      rethrow;
    }
  }

  /// Initialize WebRTC with proper STUN/TURN configuration
  Future<void> _initializeWebRTC() async {
    final configuration = {
      'iceServers': [
        {
          'urls': 'stun:stun.l.google.com:19302',
        },
        {
          'urls': 'turn:relay.metered.ca:80',
          'username': 'webrtc',
          'credential': 'webrtc',
        },
      ]
    };

    await _webRTCService.initialize(configuration);
  }

  /// Set up Firestore signaling callbacks
  void _setupSignalingCallbacks() {
    _signalingService.onRemoteOffer = (RTCSessionDescription offer) async {
      _logger.info('📥 Received remote offer');
      await _webRTCService.setRemoteDescription(offer);
      
      // Create data channel for answering peer
      await _createDataChannel();
      
      // Create and send answer
      final answer = await _webRTCService.createAnswer();
      await _webRTCService.setLocalDescription(answer);
      await _signalingService.sendAnswer(answer);
    };

    _signalingService.onRemoteAnswer = (RTCSessionDescription answer) async {
      _logger.info('📩 Received remote answer');
      await _webRTCService.setRemoteDescription(answer);
    };

    _signalingService.onRemoteIceCandidate = (RTCIceCandidate candidate) async {
      _logger.info('🧊 Received remote ICE candidate');
      await _webRTCService.addIceCandidate(candidate);
    };

    _signalingService.onPeerJoined = (String peerId) {
      _logger.success('👥 Peer joined: $peerId');
      
      // Only initiate connection if we don't have one and we are offering peer
      if (_currentTargetPeer == null && _isOfferingPeer) {
        _initiateConnection(peerId);
      }
    };

    _signalingService.onPeerLeft = (String peerId) {
      _logger.info('👋 Peer left: $peerId');
      if (_currentTargetPeer == peerId) {
        _currentTargetPeer = null;
        _updateConnectionInfo(_connectionInfo.copyWith(
          connectionState: PeerConnectionState.disconnected,
        ));
      }
    };

    _signalingService.onError = (String error) {
      _handleError('Signaling error: $error');
    };
  }

  /// Set up WebRTC callbacks for real connection state monitoring
  void _setupWebRTCCallbacks() {
    _webRTCService.onConnectionStateChanged = (RTCPeerConnectionState state) {
      _logger.info('🔗 WebRTC connection state: $state');
      
      PeerConnectionState newState;
      switch (state) {
        case RTCPeerConnectionState.RTCPeerConnectionStateConnecting:
          newState = PeerConnectionState.connecting;
          break;
        case RTCPeerConnectionState.RTCPeerConnectionStateConnected:
          newState = PeerConnectionState.connected;
          _logger.success('🎉 P2P connection established!');
          break;
        case RTCPeerConnectionState.RTCPeerConnectionStateDisconnected:
        case RTCPeerConnectionState.RTCPeerConnectionStateFailed:
        case RTCPeerConnectionState.RTCPeerConnectionStateClosed:
          newState = PeerConnectionState.disconnected;
          _logger.warning('❌ P2P connection lost');
          break;
        default:
          newState = PeerConnectionState.disconnected;
      }

      _updateConnectionInfo(_connectionInfo.copyWith(
        connectionState: newState,
      ));
    };

    _webRTCService.onDataChannelMessage = (String message) {
      try {
        final messageData = json.decode(message) as Map<String, dynamic>;
        
        if (messageData['type'] == 'chat') {
          final content = messageData['content'] as String;
          final fromPeerId = messageData['from'] as String;
          final timestamp = DateTime.parse(messageData['timestamp'] as String);
          
          onMessageReceived?.call(content, fromPeerId, timestamp);
        }
      } catch (e) {
        _logger.error('❌ Failed to parse message: $e');
      }
    };

    _webRTCService.onDataChannelOpen = () {
      _logger.success('📡 Data channel opened - ready for messaging');
    };

    _webRTCService.onIceCandidate = (RTCIceCandidate candidate) async {
      _logger.info('🧊 Sending ICE candidate');
      await _signalingService.sendIceCandidate(candidate);
    };
  }

  /// Initiate connection to a peer
  Future<void> _initiateConnection(String peerId) async {
    try {
      _currentTargetPeer = peerId;
      _isOfferingPeer = true;
      
      _logger.info('🤝 Initiating connection to: $peerId');

      await _createDataChannel();
      final offer = await _webRTCService.createOffer();
      await _webRTCService.setLocalDescription(offer);
      
      await _signalingService.sendOffer(offer);
      
      _logger.info('📤 Sent offer to: $peerId');
    } catch (e) {
      _logger.error('❌ Failed to initiate connection: $e');
      _handleError('Failed to connect to peer: $e');
    }
  }

  /// Create data channel for chat messages
  Future<void> _createDataChannel() async {
    if (_isOfferingPeer) {
      _dataChannel = await _webRTCService.createDataChannel('chat', {
        'ordered': true,
      });
      
      _dataChannel!.onMessage = (RTCDataChannelMessage message) {
        _webRTCService.onDataChannelMessage?.call(message.text);
      };
    }
  }

  /// Send a chat message through the data channel
  Future<void> sendMessage(String message) async {
    if (_connectionInfo.connectionState != PeerConnectionState.connected) {
      _handleError('Cannot send message: not connected to any peer');
      return;
    }

    try {
      final messageData = {
        'type': 'chat',
        'content': message,
        'from': _connectionInfo.localPeerId,
        'timestamp': DateTime.now().toIso8601String(),
      };

      final jsonMessage = json.encode(messageData);
      await _webRTCService.sendDataChannelMessage(jsonMessage);
      
      _logger.success('📤 Sent chat message: "$message"');
      
      // Also call the callback for our own message to show in UI
      onMessageReceived?.call(
        message,
        _connectionInfo.localPeerId,
        DateTime.now(),
      );
    } catch (e) {
      _logger.error('❌ Failed to send message: $e');
      _handleError('Failed to send message: $e');
    }
  }

  /// Leave the current room and disconnect
  Future<void> leaveRoom() async {
    try {
      _logger.info('🚪 Leaving room...');

      _dataChannel?.close();
      _dataChannel = null;
      _currentTargetPeer = null;

      await _webRTCService.disconnect();
      _signalingService.disconnect();

      _updateConnectionInfo(const P2PConnectionInfo(
        roomId: '',
        localPeerId: '',
        connectionState: PeerConnectionState.disconnected,
        connectedPeers: [],
      ));

      _logger.success('✅ Successfully left room');
    } catch (e) {
      _handleError('Failed to leave room: $e');
    }
  }

  void _updateConnectionInfo(P2PConnectionInfo newInfo) {
    _connectionInfo = newInfo;
    onConnectionInfoChanged?.call(_connectionInfo);
  }

  void _handleError(String error) {
    _logger.error('🚨 P2P Manager Error: $error');
    onError?.call(error);
  }

  /// Dispose all resources
  void dispose() {
    leaveRoom();
    _webRTCService.dispose();
    _signalingService.dispose();
    
    onConnectionInfoChanged = null;
    onMessageReceived = null;
    onFileReceived = null;
    onError = null;
  }
}
