import 'dart:async';
import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:flutter_webrtc/flutter_webrtc.dart';
import '../models/p2p_models.dart';
import '../utils/app_logger.dart';
import 'modern_webrtc_service.dart';
import 'firestore_signaling_service.dart';

/// Core P2P connection manager that handles WebRTC and Firestore signaling
/// This is the main class for P2P functionality
/// ALL fake code removed - only real Firestore WebRTC implementation
class P2PConnectionManager extends ChangeNotifier {
  final ModernWebRTCService _webRTCService = ModernWebRTCService();
  final FirestoreSignalingService _signalingService = FirestoreSignalingService();
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
      _logger.info('🚀 P2PConnectionManager.createRoom() STARTED');
      
      _logger.info('🏠 Creating room as caller');

      _updateConnectionInfo(_connectionInfo.copyWith(
        connectionState: PeerConnectionState.connecting,
      ));

      // Initialize WebRTC with STUN/TURN servers
      _logger.info('🔧 Initializing WebRTC...');
      await _initializeWebRTC();
      _logger.success('✅ WebRTC initialized');
      _setupWebRTCCallbacks();

      // Create data channel (caller creates)
      _logger.info('📡 Creating data channel...');
      await _createDataChannel();
      _logger.success('✅ Data channel created');

      // Create offer
      _logger.info('📤 Creating offer...');
      final offer = await _webRTCService.createOffer();
      await _webRTCService.setLocalDescription(offer);
      _logger.success('✅ Offer created and set as local description');

      // Create room with offer in Firestore - مهم
      _logger.info('🏠 Creating room in Firestore...');
      final roomId = await _signalingService.createRoom(offer);
      _currentRoomId = roomId;
      _isCaller = true;
      _logger.success('✅ Room created in Firestore: $roomId');

      _updateConnectionInfo(_connectionInfo.copyWith(
        roomId: roomId,
        localPeerId: 'caller_${DateTime.now().millisecondsSinceEpoch}',
      ));

      // Start listening for answer and ICE candidates AFTER room creation
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
      // Add immediate logging to test if logger works
      _logger.info('🚀 P2PConnectionManager.joinRoom() STARTED - Testing logger!');
      print('🚀 P2PConnectionManager.joinRoom() STARTED - Console fallback!');
      debugPrint('🚀 P2PConnectionManager.joinRoom() STARTED - Debug fallback!');
      
      _logger.info('🚪 Joining room: $roomId as callee');
      _currentRoomId = roomId;

      _updateConnectionInfo(_connectionInfo.copyWith(
        roomId: roomId,
        connectionState: PeerConnectionState.connecting,
        localPeerId: 'callee_${DateTime.now().millisecondsSinceEpoch}',
      ));

      // Initialize WebRTC with STUN/TURN servers
      await _initializeWebRTC();
      _setupWebRTCCallbacks();

      // Get remote offer
      final offer = await _signalingService.onRemoteOffer(roomId).first;
      await _webRTCService.setRemoteDescription(offer);

      // Create & send answer
      final answer = await _webRTCService.createAnswer();
      await _webRTCService.setLocalDescription(answer);
      await _signalingService.joinRoom(roomId, answer);

      _isCaller = false;

      // Setup ICE candidates listener
      _iceSubscription = _signalingService.onRemoteIce(roomId, false).listen(
        (candidate) async {
          _logger.debug('🧊 Received remote ICE candidate');
          await _webRTCService.addIceCandidate(candidate);
        },
        onError: (error) => _handleError('ICE listening error: $error'),
      );

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

  /// Set up signaling listeners for caller only (answer and ICE)
  void _setupSignalingListeners() {
    if (_currentRoomId == null) return;

    // Listen for answer (caller only) 
    if (_isCaller) {
      _answerSubscription = _signalingService.onRemoteAnswer(_currentRoomId!).listen(
        (answer) async {
          _logger.info('📩 Received remote answer');
          await _webRTCService.setRemoteDescription(answer);
        },
        onError: (error) => _handleError('Answer listening error: $error'),
      );

      // Listen for ICE candidates (caller)
      _iceSubscription = _signalingService.onRemoteIce(_currentRoomId!, true).listen(
        (candidate) async {
          _logger.debug('🧊 Received remote ICE candidate');
          await _webRTCService.addIceCandidate(candidate);
        },
        onError: (error) => _handleError('ICE listening error: $error'),
      );
    }
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
      _updateConnectionInfo(
        _connectionInfo.copyWith(
          connectionState: PeerConnectionState.connected,
        ),
      );
    };

    _webRTCService.onIceCandidate = (RTCIceCandidate candidate) async {
      if (_currentRoomId != null) {
        _logger.debug('🧊 Sending ICE candidate');
        await _signalingService.sendIceCandidate(
            _currentRoomId!, candidate, _isCaller);
      }
    };

    _webRTCService.onDataChannelReceived = (RTCDataChannel channel) {
      _logger.info('📡 Data channel received by callee');
      _dataChannel = channel;
      
      // Set up data channel state listener for callee
      _dataChannel!.onDataChannelState = (RTCDataChannelState state) {
        debugPrint('RTCDataChannelState (callee): $state');
        if (state == RTCDataChannelState.RTCDataChannelOpen) {
          _updateConnectionInfo(
            _connectionInfo.copyWith(
              connectionState: PeerConnectionState.connected,
            ),
          );
        }
      };

      _dataChannel!.onMessage = (RTCDataChannelMessage message) {
        _webRTCService.onDataChannelMessage?.call(message.text);
      };
    };
  }

  /// Create data channel for chat messages (caller only)
  Future<void> _createDataChannel() async {
    if (_isCaller) {
      _dataChannel = await _webRTCService.createDataChannel('chat', {
        'ordered': true,
      });

      _dataChannel!.onDataChannelState = (RTCDataChannelState state) {
        debugPrint('RTCDataChannelState: $state');
        if (state == RTCDataChannelState.RTCDataChannelOpen) {
          _updateConnectionInfo(
            _connectionInfo.copyWith(
              connectionState: PeerConnectionState.connected,
            ),
          );
        }
      };

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
    notifyListeners(); // Ensure UI gets notified
  }

  void _handleError(String error) {
    _logger.error('🚨 P2P Manager Error: $error');
    onError?.call(error);
  }

  /// Dispose all resources
  @override
  void dispose() {
    leaveRoom();
    _webRTCService.dispose();
    _signalingService.dispose();

    onConnectionInfoChanged = null;
    onMessageReceived = null;
    onFileReceived = null;
    onError = null;
    
    super.dispose();
  }
}
