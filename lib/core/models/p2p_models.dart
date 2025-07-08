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
