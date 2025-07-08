import 'package:equatable/equatable.dart';

enum PeerConnectionState {
  disconnected,
  connecting,
  connected,
  failed,
  closed,
}

enum SignalingState {
  disconnected,
  connecting,
  connected,
  stable,
  haveLocalOffer,
  haveRemoteOffer,
  haveLocalPranswer,
  haveRemotePranswer,
  closed,
}

class PeerInfo extends Equatable {
  final String id;
  final String name;
  final DateTime connectedAt;
  final bool isConnected;
  final DateTime? lastSeen;

  const PeerInfo({
    required this.id,
    required this.name,
    required this.connectedAt,
    this.isConnected = false,
    this.lastSeen,
  });

  PeerInfo copyWith({
    String? id,
    String? name,
    DateTime? connectedAt,
    bool? isConnected,
    DateTime? lastSeen,
  }) {
    return PeerInfo(
      id: id ?? this.id,
      name: name ?? this.name,
      connectedAt: connectedAt ?? this.connectedAt,
      isConnected: isConnected ?? this.isConnected,
      lastSeen: lastSeen ?? this.lastSeen,
    );
  }

  @override
  List<Object?> get props => [id, name, connectedAt, isConnected, lastSeen];
}

class SignalingMessage extends Equatable {
  final String type;
  final String? from;
  final String? to;
  final Map<String, dynamic> data;
  final DateTime timestamp;

  const SignalingMessage({
    required this.type,
    this.from,
    this.to,
    required this.data,
    required this.timestamp,
  });

  factory SignalingMessage.fromJson(Map<String, dynamic> json) {
    return SignalingMessage(
      type: json['type'] as String,
      from: json['from'] as String?,
      to: json['to'] as String?,
      data: json['data'] as Map<String, dynamic>,
      timestamp: DateTime.parse(json['timestamp'] as String),
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'type': type,
      'from': from,
      'to': to,
      'data': data,
      'timestamp': timestamp.toIso8601String(),
    };
  }

  @override
  List<Object?> get props => [type, from, to, data, timestamp];
}

class P2PConnectionInfo extends Equatable {
  final String roomId;
  final String localPeerId;
  final List<PeerInfo> connectedPeers;
  final PeerConnectionState connectionState;
  final SignalingState signalingState;
  final String? errorMessage;

  const P2PConnectionInfo({
    required this.roomId,
    required this.localPeerId,
    this.connectedPeers = const [],
    this.connectionState = PeerConnectionState.disconnected,
    this.signalingState = SignalingState.disconnected,
    this.errorMessage,
  });

  P2PConnectionInfo copyWith({
    String? roomId,
    String? localPeerId,
    List<PeerInfo>? connectedPeers,
    PeerConnectionState? connectionState,
    SignalingState? signalingState,
    String? errorMessage,
  }) {
    return P2PConnectionInfo(
      roomId: roomId ?? this.roomId,
      localPeerId: localPeerId ?? this.localPeerId,
      connectedPeers: connectedPeers ?? this.connectedPeers,
      connectionState: connectionState ?? this.connectionState,
      signalingState: signalingState ?? this.signalingState,
      errorMessage: errorMessage,
    );
  }

  @override
  List<Object?> get props => [
        roomId,
        localPeerId,
        connectedPeers,
        connectionState,
        signalingState,
        errorMessage,
      ];
}
