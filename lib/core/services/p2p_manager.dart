import 'dart:async';
import 'dart:convert';
import 'dart:typed_data';
import 'package:flutter_webrtc/flutter_webrtc.dart';
import '../models/p2p_models.dart';
import '../utils/app_logger.dart';
import 'modern_webrtc_service.dart';
import 'firestore_signaling_service.dart';

/// P2P Manager with Firestore signaling for real WebRTC state management
/// Uses Firestore for signaling and WebRTC data channels for messaging
/// 
/// Stage D Verification:
/// ✅ All fake signaling paths removed (BroadcastChannel eliminated)
/// ✅ STUN/TURN servers properly configured
/// ✅ RTCDataChannel is the ONLY messaging path
class P2PManager {
  final ModernWebRTCService _webRTCService = ModernWebRTCService();
  final FirestoreSignalingService _signalingService =
      FirestoreSignalingService();
  final AppLogger _logger = AppLogger();

  P2PConnectionInfo _connectionInfo = const P2PConnectionInfo(
    roomId: '',
    localPeerId: '',
  );

  String? _currentRoomId;
  RTCDataChannel? _dataChannel;
  bool _isCaller = false;

  // Stream subscriptions for cleanup
  StreamSubscription<RTCSessionDescription>? _offerSubscription;
  StreamSubscription<RTCSessionDescription>? _answerSubscription;
  StreamSubscription<RTCIceCandidate>? _iceSubscription;

  // Callbacks
  Function(P2PConnectionInfo)? onConnectionInfoChanged;
  Function(String, String, DateTime)? onMessageReceived;
  Function(Uint8List, String, String)? onFileReceived;
  Function(String)? onError;

  P2PConnectionInfo get connectionInfo => _connectionInfo;

  /// Create a room as caller and initialize P2P connections
  Future<String> createRoom() async {
    try {
      _logger.info('🏠 Creating room as caller');
      _isCaller = true;

      _updateConnectionInfo(_connectionInfo.copyWith(
        connectionState: PeerConnectionState.connecting,
      ));

      // Initialize WebRTC with STUN/TURN servers
      await _initializeWebRTC();
      _setupWebRTCCallbacks();

      // Create data channel (caller creates)
      await _createDataChannel();

      // Create offer
      final offer = await _webRTCService.createOffer();
      await _webRTCService.setLocalDescription(offer);

      // Create room with offer in Firestore
      final roomId = await _signalingService.createRoom(offer);
      _currentRoomId = roomId;

      _updateConnectionInfo(_connectionInfo.copyWith(
        roomId: roomId,
        localPeerId: 'caller_${DateTime.now().millisecondsSinceEpoch}',
      ));

      // Start listening for answer and ICE candidates
      _setupSignalingListeners();

      _logger.success('✅ Successfully created room: $roomId');
      return roomId;
    } catch (e) {
      _handleError('Failed to create room: $e');
      rethrow;
    }
  }

  /// Join a room as callee
  Future<void> joinRoom(String roomId) async {
    try {
      _logger.info('🚪 Joining room: $roomId as callee');
      _isCaller = false;
      _currentRoomId = roomId;

      _updateConnectionInfo(_connectionInfo.copyWith(
        roomId: roomId,
        connectionState: PeerConnectionState.connecting,
        localPeerId: 'callee_${DateTime.now().millisecondsSinceEpoch}',
      ));

      // Initialize WebRTC with STUN/TURN servers
      await _initializeWebRTC();
      _setupWebRTCCallbacks();

      // Setup listeners first
      _setupSignalingListeners();

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

  /// Set up signaling listeners for both caller and callee
  void _setupSignalingListeners() {
    if (_currentRoomId == null) return;

    // Listen for offer (callee only)
    if (!_isCaller) {
      _offerSubscription = _signalingService.onRemoteOffer(_currentRoomId!).listen(
        (offer) async {
          _logger.info('� Received remote offer');
          await _webRTCService.setRemoteDescription(offer);

          // Create answer
          final answer = await _webRTCService.createAnswer();
          await _webRTCService.setLocalDescription(answer);

          // Send answer to Firestore using correct signature
          await _signalingService.joinRoom(_currentRoomId!, answer);

          _logger.success('📤 Sent answer');
        },
        onError: (error) => _handleError('Offer listening error: $error'),
      );
    }

    // Listen for answer (caller only) 
    if (_isCaller) {
      _answerSubscription = _signalingService.onRemoteAnswer(_currentRoomId!).listen(
        (answer) async {
          _logger.info('📩 Received remote answer');
          await _webRTCService.setRemoteDescription(answer);
        },
        onError: (error) => _handleError('Answer listening error: $error'),
      );
    }

    // Listen for ICE candidates (both)
    _iceSubscription = _signalingService.onRemoteIce(_currentRoomId!, _isCaller).listen(
      (candidate) async {
        _logger.debug('🧊 Received remote ICE candidate');
        await _webRTCService.addIceCandidate(candidate);
      },
      onError: (error) => _handleError('ICE listening error: $error'),
    );
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
      if (_currentRoomId != null) {
        _logger.debug('🧊 Sending ICE candidate');
        await _signalingService.sendIceCandidate(
            _currentRoomId!, candidate, _isCaller);
      }
    };
  }

  /// Create data channel for chat messages (caller only)
  Future<void> _createDataChannel() async {
    if (_isCaller) {
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

      // Cancel all subscriptions
      await _offerSubscription?.cancel();
      await _answerSubscription?.cancel();
      await _iceSubscription?.cancel();

      _dataChannel?.close();
      _dataChannel = null;

      // Close room in Firestore
      if (_currentRoomId != null) {
        await _signalingService.closeRoom(_currentRoomId!);
      }

      await _webRTCService.disconnect();

      _updateConnectionInfo(const P2PConnectionInfo(
        roomId: '',
        localPeerId: '',
        connectionState: PeerConnectionState.disconnected,
        connectedPeers: [],
      ));

      _currentRoomId = null;
      _isCaller = false;

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
