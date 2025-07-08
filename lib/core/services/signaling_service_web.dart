import 'dart:convert';
import 'dart:math';
import 'dart:async';
import '../models/p2p_models.dart';

// For web platform
import 'dart:html' as html show BroadcastChannel, MessageEvent, WebSocket;

class SignalingService {
  static final SignalingService _instance = SignalingService._internal();
  factory SignalingService() => _instance;
  SignalingService._internal();

  // Platform-specific signaling
  html.BroadcastChannel? _broadcastChannel; // For web local testing
  html.WebSocket? _webSocket; // WebSocket for real P2P
  String? _localPeerId;
  String? _roomId;
  final Map<String, PeerInfo> _connectedPeers = {};
  bool _isInitialized = false;
  Timer? _heartbeatTimer;
  Timer? _reconnectTimer;
  int _reconnectAttempts = 0;
  static const int _maxReconnectAttempts = 5;

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
      if (signalingServerUrl != null && signalingServerUrl.isNotEmpty) {
        // Use WebSocket for real P2P signaling
        _initializeWebSocketSignaling(signalingServerUrl);
      } else {
        // Use BroadcastChannel for local testing
        _initializeBroadcastChannelSignaling();
      }

      _isInitialized = true;
      _startHeartbeat();
    } catch (e) {
      onError?.call('Failed to initialize signaling: $e');
    }
  }

  void _initializeBroadcastChannelSignaling() {
    // Use BroadcastChannel for local P2P communication (same device testing)
    _broadcastChannel = html.BroadcastChannel('globgram_p2p_$_roomId');

    _broadcastChannel!.onMessage.listen((html.MessageEvent event) {
      try {
        final data = event.data;
        if (data is String) {
          final messageData = jsonDecode(data) as Map<String, dynamic>;
          final message = SignalingMessage.fromJson(messageData);

          // Don't process our own messages
          if (message.from != _localPeerId) {
            _handleMessage(message);
          }
        }
      } catch (e) {
        onError?.call('Failed to process signaling message: $e');
      }
    });

    // Announce our presence
    _sendMessage(SignalingMessage(
      type: 'peer-joined',
      from: _localPeerId,
      data: {
        'peerId': _localPeerId,
        'roomId': _roomId,
        'timestamp': DateTime.now().toIso8601String(),
      },
      timestamp: DateTime.now(),
    ));
  }

  void _initializeWebSocketSignaling(String serverUrl) {
    try {
      _webSocket = html.WebSocket(serverUrl);

      _webSocket!.onOpen.listen((_) {
        print('WebSocket connected to signaling server');
        onConnectionStatusChanged?.call(true);
        _reconnectAttempts = 0;

        // Join room
        _sendWebSocketMessage({
          'type': 'join-room',
          'roomId': _roomId,
          'peerId': _localPeerId,
          'timestamp': DateTime.now().toIso8601String(),
        });
      });

      _webSocket!.onMessage.listen((event) {
        try {
          final data = jsonDecode(event.data) as Map<String, dynamic>;
          final message = SignalingMessage.fromJson(data);

          if (message.from != _localPeerId) {
            _handleMessage(message);
          }
        } catch (e) {
          onError?.call('Failed to process WebSocket message: $e');
        }
      });

      _webSocket!.onClose.listen((event) {
        print('WebSocket connection closed: ${event.code} ${event.reason}');
        onConnectionStatusChanged?.call(false);
        _scheduleReconnect();
      });

      _webSocket!.onError.listen((error) {
        print('WebSocket error: $error');
        onError?.call('WebSocket connection error');
        _scheduleReconnect();
      });
    } catch (e) {
      onError?.call('Failed to connect to signaling server: $e');
    }
  }

  void _scheduleReconnect() {
    if (_reconnectAttempts < _maxReconnectAttempts) {
      _reconnectTimer?.cancel();
      _reconnectTimer = Timer(Duration(seconds: 2 << _reconnectAttempts), () {
        _reconnectAttempts++;
        if (_roomId != null) {
          // Try to reconnect
          final serverUrl = _webSocket?.url;
          if (serverUrl != null) {
            _initializeWebSocketSignaling(serverUrl);
          }
        }
      });
    }
  }

  void _startHeartbeat() {
    _heartbeatTimer?.cancel();
    _heartbeatTimer = Timer.periodic(Duration(seconds: 30), (timer) {
      if (_webSocket != null && _webSocket!.readyState == html.WebSocket.OPEN) {
        _sendWebSocketMessage({
          'type': 'heartbeat',
          'peerId': _localPeerId,
          'timestamp': DateTime.now().toIso8601String(),
        });
      }
    });
  }

  void _sendWebSocketMessage(Map<String, dynamic> data) {
    if (_webSocket != null && _webSocket!.readyState == html.WebSocket.OPEN) {
      _webSocket!.send(jsonEncode(data));
    }
  }

  void _handleMessage(SignalingMessage message) {
    switch (message.type) {
      case 'peer-joined':
        _handlePeerJoined(message);
        break;
      case 'peer-left':
        _handlePeerLeft(message);
        break;
      case 'offer':
      case 'answer':
      case 'ice-candidate':
        onMessage?.call(message);
        break;
      case 'peer-list':
        _handlePeerList(message);
        break;
      default:
        print('Unknown message type: ${message.type}');
    }
  }

  void _handlePeerJoined(SignalingMessage message) {
    final peerId = message.from!;
    if (peerId != _localPeerId && !_connectedPeers.containsKey(peerId)) {
      final peer = PeerInfo(
        id: peerId,
        name: 'User $peerId',
        connectedAt: DateTime.now(),
        isConnected: true,
      );

      _connectedPeers[peerId] = peer;
      onPeerJoined?.call(peer);

      // Send our presence back if using BroadcastChannel
      if (_broadcastChannel != null) {
        _sendMessage(SignalingMessage(
          type: 'peer-joined',
          from: _localPeerId,
          to: peerId,
          data: {
            'peerId': _localPeerId,
            'timestamp': DateTime.now().toIso8601String(),
          },
          timestamp: DateTime.now(),
        ));
      }
    }
  }

  void _handlePeerLeft(SignalingMessage message) {
    final peerId = message.from!;
    if (_connectedPeers.containsKey(peerId)) {
      _connectedPeers.remove(peerId);
      onPeerLeft?.call(peerId);
    }
  }

  void _handlePeerList(SignalingMessage message) {
    final peerList = message.data['peers'] as List<dynamic>?;
    if (peerList != null) {
      _connectedPeers.clear();
      for (final peerData in peerList) {
        final peerId = peerData['peerId'] as String;
        if (peerId != _localPeerId) {
          final peer = PeerInfo(
            id: peerId,
            name: 'User $peerId',
            connectedAt: DateTime.now(),
            isConnected: true,
          );
          _connectedPeers[peerId] = peer;
          onPeerJoined?.call(peer);
        }
      }
    }
  }

  void sendSignalingMessage(SignalingMessage message) {
    final messageWithFrom = SignalingMessage(
      type: message.type,
      from: _localPeerId,
      to: message.to,
      data: message.data,
      timestamp: message.timestamp,
    );

    if (_webSocket != null && _webSocket!.readyState == html.WebSocket.OPEN) {
      _sendWebSocketMessage(messageWithFrom.toJson());
    } else {
      _sendMessage(messageWithFrom);
    }
  }

  void _sendMessage(SignalingMessage message) {
    if (_broadcastChannel != null) {
      try {
        _broadcastChannel!.postMessage(jsonEncode(message.toJson()));
      } catch (e) {
        onError?.call('Failed to send signaling message: $e');
      }
    }
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
  bool get isConnectedToServer => _webSocket?.readyState == html.WebSocket.OPEN;

  void disconnect() {
    if (_localPeerId != null) {
      final leaveMessage = SignalingMessage(
        type: 'peer-left',
        from: _localPeerId,
        data: {
          'peerId': _localPeerId,
          'timestamp': DateTime.now().toIso8601String(),
        },
        timestamp: DateTime.now(),
      );

      if (_webSocket != null && _webSocket!.readyState == html.WebSocket.OPEN) {
        _sendWebSocketMessage(leaveMessage.toJson());
      } else {
        _sendMessage(leaveMessage);
      }
    }

    _heartbeatTimer?.cancel();
    _reconnectTimer?.cancel();
    _webSocket?.close();
    _broadcastChannel?.close();

    _webSocket = null;
    _broadcastChannel = null;
    _connectedPeers.clear();
    _localPeerId = null;
    _roomId = null;
    _isInitialized = false;
    _reconnectAttempts = 0;
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
