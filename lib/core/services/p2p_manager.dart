import 'dart:convert';
import 'dart:typed_data';
import 'package:flutter_webrtc/flutter_webrtc.dart';
import '../models/p2p_models.dart';
import '../utils/app_logger.dart';
import 'modern_webrtc_service.dart';
import 'broadcast_signaling_service.dart';

/// P2P Manager with BroadcastChannel signaling for local testing and real WebRTC state management
/// Removes fake "connected" simulation and relies only on actual connection states
class P2PManager {
  final ModernWebRTCService _webRTCService = ModernWebRTCService();
  final BroadcastSignalingService _signalingService = BroadcastSignalingService();
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

      // Initialize BroadcastChannel signaling
      _signalingService.initialize(roomId);
      _setupSignalingCallbacks();
      
      // Initialize WebRTC with STUN/TURN servers
      await _initializeWebRTC();
      _setupWebRTCCallbacks();

      _updateConnectionInfo(_connectionInfo.copyWith(
        localPeerId: _signalingService.localPeerId ?? '',
      ));

      _logger.success('✅ Successfully joined room: $roomId');
    } catch (e) {
      _handleError('Failed to join room: $e');
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

  /// Set up Firebase signaling callbacks
  void _setupSignalingCallbacks() {
    _signalingService.onMessage = (SignalingMessage message) {
      _handleSignalingMessage(message);
    };

    _signalingService.onPeerJoined = (PeerInfo peer) {
      _logger.success('👥 Peer joined: ${peer.id}');
      
      // Update peer list without changing connection state
      _updateConnectionInfo(_connectionInfo.copyWith(
        connectedPeers: [..._connectionInfo.connectedPeers, peer],
      ));

      // Only initiate connection if we don't have one and this is a new peer
      if (_currentTargetPeer == null) {
        _initiateConnection(peer.id);
      }
    };

    _signalingService.onPeerLeft = (String peerId) {
      _logger.info('👋 Peer left: $peerId');
      
      _updateConnectionInfo(_connectionInfo.copyWith(
        connectedPeers: _connectionInfo.connectedPeers
            .where((p) => p.id != peerId)
            .toList(),
      ));

      if (_currentTargetPeer == peerId) {
        _handlePeerDisconnection();
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
        final type = messageData['type'] as String;
        
        if (type == 'chat') {
          final content = messageData['content'] as String;
          final fromPeerId = messageData['from'] as String;
          final timestamp = DateTime.parse(messageData['timestamp'] as String);
          
          _logger.success('💬 Received chat message: "$content" from $fromPeerId');
          onMessageReceived?.call(content, fromPeerId, timestamp);
        }
      } catch (e) {
        _logger.error('❌ Failed to parse data channel message: $e');
      }
    };

    _webRTCService.onDataChannelOpen = () {
      _logger.success('📡 Data channel opened - ready for messaging');
    };

    _webRTCService.onIceCandidate = (RTCIceCandidate candidate) {
      if (_currentTargetPeer != null) {
        _signalingService.sendIceCandidate(candidate, _currentTargetPeer!);
      }
    };
  }

  /// Handle incoming signaling messages
  Future<void> _handleSignalingMessage(SignalingMessage message) async {
    _logger.debug('📨 Handling signaling: ${message.type} from ${message.from}');

    switch (message.type) {
      case 'offer':
        await _handleOffer(message);
        break;
      case 'answer':
        await _handleAnswer(message);
        break;
      case 'ice_candidate':
        await _handleIceCandidate(message);
        break;
      default:
        _logger.warning('⚠️ Unknown signaling message type: ${message.type}');
    }
  }

  /// Handle incoming offer
  Future<void> _handleOffer(SignalingMessage message) async {
    try {
      _currentTargetPeer = message.from;
      _isOfferingPeer = false;

      final offer = RTCSessionDescription(
        message.data['sdp'] as String,
        message.data['type'] as String,
      );

      await _webRTCService.setRemoteDescription(offer);
      await _createDataChannel();
      
      final answer = await _webRTCService.createAnswer();
      await _webRTCService.setLocalDescription(answer);
      
      await _signalingService.sendAnswer(answer, message.from!);
      
      _logger.info('📤 Sent answer to ${message.from}');
    } catch (e) {
      _logger.error('❌ Failed to handle offer: $e');
    }
  }

  /// Handle incoming answer
  Future<void> _handleAnswer(SignalingMessage message) async {
    try {
      final answer = RTCSessionDescription(
        message.data['sdp'] as String,
        message.data['type'] as String,
      );

      await _webRTCService.setRemoteDescription(answer);
      _logger.info('✅ Processed answer from ${message.from}');
    } catch (e) {
      _logger.error('❌ Failed to handle answer: $e');
    }
  }

  /// Handle incoming ICE candidate
  Future<void> _handleIceCandidate(SignalingMessage message) async {
    try {
      final candidateData = message.data['candidate'] as Map<String, dynamic>;
      final candidate = RTCIceCandidate(
        candidateData['candidate'] as String,
        candidateData['sdpMid'] as String?,
        candidateData['sdpMLineIndex'] as int?,
      );

      await _webRTCService.addIceCandidate(candidate);
      _logger.debug('🧊 Added ICE candidate from ${message.from}');
    } catch (e) {
      _logger.error('❌ Failed to handle ICE candidate: $e');
    }
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
      
      await _signalingService.sendOffer(offer, peerId);
      
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

  /// Handle peer disconnection
  void _handlePeerDisconnection() {
    _currentTargetPeer = null;
    _dataChannel?.close();
    _dataChannel = null;
    
    _updateConnectionInfo(_connectionInfo.copyWith(
      connectionState: PeerConnectionState.disconnected,
    ));
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
      await _signalingService.disconnect();

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
