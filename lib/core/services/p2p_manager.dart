import 'dart:async';
import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:flutter_webrtc/flutter_webrtc.dart';
import '../models/p2p_models.dart';
import '../utils/app_logger.dart';
import 'modern_webrtc_service.dart';
import 'firestore_signaling_service.dart';

/// P2P Manager with Firestore signaling for real WebRTC state management
/// Uses Firestore for signaling and WebRTC data channels for messaging
/// ALL fake code removed - only real Firestore WebRTC implementation
class P2PManager extends ChangeNotifier {
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
      _logger.info('🚀 P2PManager.createRoom() STARTED');
      
      _logger.info('🏠 Creating room as caller');

      _updateConnectionInfo(_connectionInfo.copyWith(
        connectionState: PeerConnectionState.connecting,
      ));

      // Initialize WebRTC with STUN/TURN servers
      _logger.info('🔧 Initializing WebRTC...');
      await _initializeWebRTC();
      _logger.success('✅ WebRTC initialized');
      
      _setupPeerConnectionListeners();

      // Create data channel (caller creates)
      _logger.info('📡 Creating data channel...');
      await _createDataChannel();
      _logger.success('✅ Data channel created');

      // Caller flow - Create offer and set local description
      _logger.info('📤 Creating offer...');
      final offer = await _webRTCService.createOffer();
      await _webRTCService.setLocalDescription(offer);
      _logger.success('✅ Offer created and set as local description');

      // Create room with offer in Firestore
      _logger.info('🏠 Creating room in Firestore...');
      _currentRoomId = await _signalingService.createRoom(offer);
      _isCaller = true;
      _logger.success('✅ Room created in Firestore: $_currentRoomId');

      _updateConnectionInfo(_connectionInfo.copyWith(
        roomId: _currentRoomId,
        localPeerId: 'caller_${DateTime.now().millisecondsSinceEpoch}',
      ));

      // Setup signaling listeners for answer and ICE candidates
      _logger.info('👂 Setting up signaling listeners...');
      _setupSignalingListeners();
      _logger.success('✅ Signaling listeners set up');

      _logger.success('✅ Successfully created room: $_currentRoomId');
      return _currentRoomId!;
    } catch (e) {
      _logger.error('❌ Failed to create room: $e');
      _handleError('Failed to create room: $e');
      rethrow;
    }
  }

  /// Join a room as callee
  Future<void> joinRoom(String roomId) async {
    try {
      _logger.info('🚀 P2PManager.joinRoom() STARTED');
      
      _logger.info('🚪 Joining room: $roomId as callee');
      _currentRoomId = roomId;

      _updateConnectionInfo(_connectionInfo.copyWith(
        roomId: roomId,
        connectionState: PeerConnectionState.connecting,
        localPeerId: 'callee_${DateTime.now().millisecondsSinceEpoch}',
      ));

      // Initialize WebRTC with STUN/TURN servers
      await _initializeWebRTC();
      _setupPeerConnectionListeners();

      // Get remote offer
      _logger.info('👂 Waiting for remote offer...');
      try {
        final offer = await _signalingService.onRemoteOffer(roomId).first;
        _logger.success('📥 Received remote offer successfully!');
        await _webRTCService.setRemoteDescription(offer);
        _logger.success('✅ Remote description set successfully!');

        // Create & send answer
        _logger.info('📤 Creating answer...');
        final answer = await _webRTCService.createAnswer();
        await _webRTCService.setLocalDescription(answer);
        _logger.success('✅ Answer created and local description set');
        
        _logger.info('📤 Sending answer to Firestore...');
        await _signalingService.joinRoom(roomId, answer);
        _logger.success('✅ Answer sent to Firestore successfully');
      } catch (e) {
        _logger.error('❌ Failed to get remote offer or send answer: $e');
        throw Exception('Signaling failed: $e');
      }

      _isCaller = false;

      // Setup ICE candidates listener
      _logger.info('👂 Setting up ICE listener for callee...');
      _iceSubscription = _signalingService.onRemoteIce(roomId, false).listen(
        (candidate) async {
          _logger.debug('🧊 Callee received remote ICE candidate');
          try {
            await _webRTCService.addIceCandidate(candidate);
            _logger.debug('✅ ICE candidate added successfully');
          } catch (e) {
            _logger.error('❌ Failed to add ICE candidate: $e');
          }
        },
        onError: (error) {
          _logger.error('❌ ICE listening error: $error');
          _handleError('ICE listening error: $error');
        },
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

  /// Set up signaling listeners for caller flow
  void _setupSignalingListeners() {
    if (_currentRoomId == null) return;

    // Caller flow: Listen for remote answer
    if (_isCaller) {
      _logger.info('👂 Setting up answer listener for caller...');
      _answerSubscription = _signalingService.onRemoteAnswer(_currentRoomId!).listen(
        (answer) async {
          _logger.success('📩 Received remote answer from callee!');
          try {
            await _webRTCService.setRemoteDescription(answer);
            _logger.success('✅ Remote answer description set successfully');
          } catch (e) {
            _logger.error('❌ Failed to set remote answer: $e');
            _handleError('Failed to set remote answer: $e');
          }
        },
        onError: (error) {
          _logger.error('❌ Answer listening error: $error');
          _handleError('Answer listening error: $error');
        },
      );

      // Listen for ICE candidates (caller)
      _logger.info('👂 Setting up ICE listener for caller...');
      _iceSubscription = _signalingService.onRemoteIce(_currentRoomId!, true).listen(
        (candidate) async {
          _logger.debug('🧊 Caller received remote ICE candidate');
          try {
            await _webRTCService.addIceCandidate(candidate);
            _logger.debug('✅ ICE candidate added successfully');
          } catch (e) {
            _logger.error('❌ Failed to add ICE candidate: $e');
          }
        },
        onError: (error) {
          _logger.error('❌ ICE listening error: $error');
          _handleError('ICE listening error: $error');
        },
      );
    }
  }

  /// Set up WebRTC peer connection listeners - writes ICE and flips UI state
  void _setupPeerConnectionListeners() {
    _webRTCService.onConnectionStateChanged = (RTCPeerConnectionState state) {
      _logger.info('🔗 WebRTC connection state: $state');

      // Enhanced connection state callback - flips UI state
      debugPrint('RTCPeerConnectionState: $state');
      
      PeerConnectionState newState;
      switch (state) {
        case RTCPeerConnectionState.RTCPeerConnectionStateConnecting:
          newState = PeerConnectionState.connecting;
          _logger.info('🔄 Connection in progress...');
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
          _logger.warning('⚠️ Unknown connection state: $state');
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
      // Additional state update when data channel opens
      _updateConnectionInfo(
        _connectionInfo.copyWith(
          connectionState: PeerConnectionState.connected,
        ),
      );
    };

    // ICE candidate callback - writes ICE to Firestore
    _webRTCService.onIceCandidate = (RTCIceCandidate candidate) async {
      if (_currentRoomId != null) {
        _logger.debug('🧊 Sending ICE candidate: ${candidate.candidate?.substring(0, 50)}...');
        await _signalingService.sendIceCandidate(
            _currentRoomId!, candidate, _isCaller);
      }
    };

    _webRTCService.onDataChannelReceived = (RTCDataChannel channel) {
      _logger.info('📡 Data channel received by callee');
      _dataChannel = channel;
      
      // Set up data channel state listener for callee
      _dataChannel!.onDataChannelState = (RTCDataChannelState state) {
        _logger.info('📡 DataChannel state (callee): $state');
        debugPrint('RTCDataChannelState (callee): $state');
        if (state == RTCDataChannelState.RTCDataChannelOpen) {
          _logger.success('📡 Callee data channel opened!');
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
