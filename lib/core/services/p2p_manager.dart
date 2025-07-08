import 'dart:convert';
import 'dart:typed_data';
import 'package:flutter_webrtc/flutter_webrtc.dart';
import '../models/p2p_models.dart';
import '../utils/app_logger.dart';
import 'webrtc_service.dart';
import 'broadcast_signaling_service.dart';

class P2PManager {
  // Remove singleton pattern to allow multiple instances per tab
  final WebRTCService _webRTCService = WebRTCService();
  final BroadcastSignalingService _signalingService =
      BroadcastSignalingService();

  P2PConnectionInfo _connectionInfo = const P2PConnectionInfo(
    roomId: '',
    localPeerId: '',
  );

  String? _currentTargetPeer;

  // Callbacks
  Function(P2PConnectionInfo)? onConnectionInfoChanged;
  Function(String, String, DateTime)? onMessageReceived;
  Function(Uint8List, String, String)? onFileReceived;
  Function(String)? onError;

  P2PConnectionInfo get connectionInfo => _connectionInfo;

  Future<void> joinRoom(String roomId, {String? signalingServerUrl}) async {
    try {
      final logger = AppLogger();
      logger.info('Joining room: $roomId');

      _updateConnectionInfo(_connectionInfo.copyWith(
        roomId: roomId,
        connectionState: PeerConnectionState.connecting,
      ));

      _signalingService.initialize(roomId,
          signalingServerUrl: signalingServerUrl);
      _setupSignalingCallbacks();
      _setupWebRTCCallbacks();

      _updateConnectionInfo(_connectionInfo.copyWith(
        localPeerId: _signalingService.localPeerId ?? '',
      ));

      logger.success('Successfully joined room: $roomId');
    } catch (e) {
      _handleError('Failed to join room: $e');
    }
  }

  void _setupSignalingCallbacks() {
    _signalingService.onMessage = (SignalingMessage message) {
      _handleSignalingMessage(message);
    };

    _signalingService.onPeerJoined = (PeerInfo peer) {
      final logger = AppLogger();
      logger.success('Peer joined: ${peer.id}');
      _updateConnectionInfo(_connectionInfo.copyWith(
        connectedPeers: [..._connectionInfo.connectedPeers, peer],
      ));

      if (_connectionInfo.connectionState != PeerConnectionState.connected &&
          _currentTargetPeer == null) {
        _connectToPeer(peer.id);
      }
    };

    _signalingService.onPeerLeft = (String peerId) {
      print('Peer left: $peerId');
      _updateConnectionInfo(_connectionInfo.copyWith(
        connectedPeers: _connectionInfo.connectedPeers
            .where((p) => p.id != peerId)
            .toList(),
      ));

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

    _signalingService.onChatMessage =
        (String content, String fromPeerId, DateTime timestamp) {
      final logger = AppLogger();
      logger.success('💬 P2P Manager: Chat message received from $fromPeerId: "$content"');
      logger.info('📍 Local Peer ID: ${_connectionInfo.localPeerId}');
      logger.info(
          '✅ Message from different peer: ${fromPeerId != _connectionInfo.localPeerId}');
      
      // Always call the callback to show message in chat UI
      if (onMessageReceived != null) {
        onMessageReceived!(content, fromPeerId, timestamp);
        logger.success('📱 Message forwarded to UI');
      } else {
        logger.warning('⚠️ No message receiver callback set!');
      }
    };
  }

  void _setupWebRTCCallbacks() {
    _webRTCService.onConnectionStateChanged = (RTCPeerConnectionState state) {
      final p2pState = _mapRTCState(state);
      _updateConnectionInfo(_connectionInfo.copyWith(
        connectionState: p2pState,
      ));
    };

    _webRTCService.onDataChannelMessage = (String message, String fromPeerId) {
      try {
        final data = jsonDecode(message) as Map<String, dynamic>;
        final messageType = data['type'] as String;

        switch (messageType) {
          case 'text':
            onMessageReceived?.call(
              data['content'] as String,
              fromPeerId,
              DateTime.parse(data['timestamp'] as String),
            );
            break;
          case 'file':
            // Handle file message
            break;
        }
      } catch (e) {
        print('Failed to parse message: $e');
      }
    };

    _webRTCService.onSignalingMessage = (SignalingMessage message) {
      _signalingService.sendSignalingMessage(message);
    };

    _webRTCService.onError = (String error) {
      _handleError('WebRTC error: $error');
    };

    // For testing: simulate successful connection after signaling
    Future.delayed(Duration(seconds: 2), () {
      if (_connectionInfo.connectionState == PeerConnectionState.connecting) {
        print('Simulating successful WebRTC connection');
        _updateConnectionInfo(_connectionInfo.copyWith(
          connectionState: PeerConnectionState.connected,
        ));
      }
    });
  }

  Future<void> _connectToPeer(String peerId) async {
    try {
      _currentTargetPeer = peerId;
      _updateConnectionInfo(_connectionInfo.copyWith(
        connectionState: PeerConnectionState.connecting,
      ));

      await _webRTCService.initialize(peerId, true);
      await _webRTCService.createOffer();
    } catch (e) {
      _handleError('Failed to connect to peer $peerId: $e');
    }
  }

  void _handleSignalingMessage(SignalingMessage message) {
    switch (message.type) {
      case 'offer':
        _handleOffer(message);
        break;
      case 'answer':
        _webRTCService.handleAnswer(message.data);
        break;
      case 'ice-candidate':
        _webRTCService.handleIceCandidate(message.data);
        break;
    }
  }

  Future<void> _handleOffer(SignalingMessage message) async {
    try {
      if (_currentTargetPeer == null) {
        _currentTargetPeer = message.from;
        await _webRTCService.initialize(message.from!, false);
      }
      await _webRTCService.createAnswer(message.data, message.from!);
    } catch (e) {
      _handleError('Failed to handle offer: $e');
    }
  }

  Future<void> sendMessage(String content) async {
    final logger = AppLogger();

    if (_connectionInfo.connectionState != PeerConnectionState.connected) {
      logger.warning(
          'Sending message while not connected (state: ${_connectionInfo.connectionState})');
    }

    try {
      logger.info(
          '📤 Sending message: "$content" from ${_connectionInfo.localPeerId}');

      // Send via WebRTC data channel if possible
      try {
        _webRTCService.sendMessage(content);
        logger.success('Message sent via WebRTC');
      } catch (e) {
        logger.warning('WebRTC send failed: $e');
      }

      // Send via broadcast channel (this is the main communication method for now)
      _signalingService.sendSignalingMessage(SignalingMessage(
        type: 'chat_message',
        from: _connectionInfo.localPeerId,
        to: 'broadcast',
        data: {
          'content': content,
          'timestamp': DateTime.now().toIso8601String(),
        },
        timestamp: DateTime.now(),
      ));

      logger.success(
          '📡 Message broadcast via signaling from ${_connectionInfo.localPeerId}');
    } catch (e) {
      logger.error('Message send failed: $e');
      _handleError('Failed to send message: $e');
    }
  }

  Future<void> sendFile(Uint8List fileData, String fileName) async {
    if (_connectionInfo.connectionState != PeerConnectionState.connected) {
      _handleError('Not connected to any peer');
      return;
    }

    try {
      _webRTCService.sendFile(fileData, fileName, 'application/octet-stream');
    } catch (e) {
      _handleError('Failed to send file: $e');
    }
  }

  Future<void> leaveRoom() async {
    disconnect();
  }

  PeerConnectionState _mapRTCState(RTCPeerConnectionState state) {
    switch (state) {
      case RTCPeerConnectionState.RTCPeerConnectionStateConnected:
        return PeerConnectionState.connected;
      case RTCPeerConnectionState.RTCPeerConnectionStateConnecting:
        return PeerConnectionState.connecting;
      case RTCPeerConnectionState.RTCPeerConnectionStateDisconnected:
      case RTCPeerConnectionState.RTCPeerConnectionStateFailed:
      case RTCPeerConnectionState.RTCPeerConnectionStateClosed:
        return PeerConnectionState.disconnected;
      default:
        return PeerConnectionState.disconnected;
    }
  }

  void _updateConnectionInfo(P2PConnectionInfo newInfo) {
    _connectionInfo = newInfo;
    onConnectionInfoChanged?.call(_connectionInfo);
  }

  void _handleError(String error) {
    print('P2P Manager Error: $error');
    onError?.call(error);
  }

  void disconnect() {
    _webRTCService.disconnect();
    _signalingService.disconnect();
    _currentTargetPeer = null;
    _updateConnectionInfo(_connectionInfo.copyWith(
      connectionState: PeerConnectionState.disconnected,
      connectedPeers: [],
    ));
  }

  void dispose() {
    disconnect();
    _webRTCService.dispose();
    _signalingService.dispose();
    onConnectionInfoChanged = null;
    onMessageReceived = null;
    onFileReceived = null;
    onError = null;
  }
}
