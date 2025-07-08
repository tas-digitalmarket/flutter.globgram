import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:equatable/equatable.dart';
import '../../../../core/models/p2p_models.dart';
import '../../../../core/services/p2p_manager.dart';

// Events
abstract class P2PEvent extends Equatable {
  const P2PEvent();
  @override
  List<Object?> get props => [];
}

class CreateRoom extends P2PEvent {}

class JoinRoom extends P2PEvent {
  final String roomId;
  const JoinRoom(this.roomId);
  @override
  List<Object?> get props => [roomId];
}

class SendMessage extends P2PEvent {
  final String message;
  const SendMessage(this.message);
  @override
  List<Object?> get props => [message];
}

class LeaveRoom extends P2PEvent {
  const LeaveRoom();
}

class P2PConnectionChanged extends P2PEvent {
  final P2PConnectionInfo connectionInfo;
  const P2PConnectionChanged(this.connectionInfo);
  @override
  List<Object?> get props => [connectionInfo];
}

class MessageReceived extends P2PEvent {
  final String message;
  final String fromPeerId;
  final DateTime timestamp;

  const MessageReceived(this.message, this.fromPeerId, this.timestamp);
  @override
  List<Object?> get props => [message, fromPeerId, timestamp];
}

// State
class P2PState extends Equatable {
  final P2PConnectionInfo connectionInfo;
  final List<P2PMessage> messages;
  final String? errorMessage;
  final bool isLoading;

  const P2PState({
    this.connectionInfo = const P2PConnectionInfo(
      roomId: '',
      localPeerId: '',
    ),
    this.messages = const [],
    this.errorMessage,
    this.isLoading = false,
  });

  P2PState copyWith({
    P2PConnectionInfo? connectionInfo,
    List<P2PMessage>? messages,
    String? errorMessage,
    bool? isLoading,
  }) {
    return P2PState(
      connectionInfo: connectionInfo ?? this.connectionInfo,
      messages: messages ?? this.messages,
      errorMessage: errorMessage,
      isLoading: isLoading ?? this.isLoading,
    );
  }

  @override
  List<Object?> get props =>
      [connectionInfo, messages, errorMessage, isLoading];
}

class P2PMessage extends Equatable {
  final String id;
  final String content;
  final String fromPeerId;
  final DateTime timestamp;
  final bool isLocal;

  const P2PMessage({
    required this.id,
    required this.content,
    required this.fromPeerId,
    required this.timestamp,
    required this.isLocal,
  });

  @override
  List<Object?> get props => [id, content, fromPeerId, timestamp, isLocal];
}

// BLoC
class P2PBloc extends Bloc<P2PEvent, P2PState> {
  final P2PManager _p2pManager = P2PManager();

  P2PBloc() : super(const P2PState()) {
    on<CreateRoom>(_onCreateRoom);
    on<JoinRoom>(_onJoinRoom);
    on<SendMessage>(_onSendMessage);
    on<LeaveRoom>(_onLeaveRoom);
    on<P2PConnectionChanged>(_onConnectionChanged);
    on<MessageReceived>(_onMessageReceived);

    _setupP2PCallbacks();
  }

  void _setupP2PCallbacks() {
    _p2pManager.onConnectionInfoChanged = (P2PConnectionInfo info) {
      add(P2PConnectionChanged(info));
    };

    _p2pManager.onMessageReceived =
        (String message, String fromPeerId, DateTime timestamp) {
      add(MessageReceived(message, fromPeerId, timestamp));
    };

    _p2pManager.onError = (String error) {
      add(P2PConnectionChanged(state.connectionInfo.copyWith(
          // Add error handling in connection state changes
          )));
    };
  }

  Future<void> _onCreateRoom(CreateRoom event, Emitter<P2PState> emit) async {
    try {
      emit(state.copyWith(isLoading: true, errorMessage: null));
      final roomId = await _p2pManager.createRoom();
      emit(state.copyWith(
        isLoading: false,
        connectionInfo: state.connectionInfo.copyWith(roomId: roomId),
      ));
    } catch (e) {
      emit(state.copyWith(
        isLoading: false,
        errorMessage: 'Failed to create room: $e',
      ));
    }
  }

  Future<void> _onJoinRoom(JoinRoom event, Emitter<P2PState> emit) async {
    try {
      emit(state.copyWith(isLoading: true, errorMessage: null));
      await _p2pManager.joinRoom(event.roomId);
      emit(state.copyWith(isLoading: false));
    } catch (e) {
      emit(state.copyWith(
        isLoading: false,
        errorMessage: 'Failed to join room: $e',
      ));
    }
  }

  void _onSendMessage(SendMessage event, Emitter<P2PState> emit) {
    try {
      _p2pManager.sendMessage(event.message);

      // Add local message to state
      final localMessage = P2PMessage(
        id: DateTime.now().millisecondsSinceEpoch.toString(),
        content: event.message,
        fromPeerId: state.connectionInfo.localPeerId,
        timestamp: DateTime.now(),
        isLocal: true,
      );

      emit(state.copyWith(
        messages: [...state.messages, localMessage],
      ));
    } catch (e) {
      emit(state.copyWith(
        errorMessage: 'Failed to send message: $e',
      ));
    }
  }

  Future<void> _onLeaveRoom(LeaveRoom event, Emitter<P2PState> emit) async {
    try {
      await _p2pManager.leaveRoom();
      emit(state.copyWith(
        connectionInfo: const P2PConnectionInfo(
          roomId: '',
          localPeerId: '',
        ),
        messages: const [],
        errorMessage: null,
      ));
    } catch (e) {
      emit(state.copyWith(
        errorMessage: 'Failed to leave room: $e',
      ));
    }
  }

  void _onConnectionChanged(
      P2PConnectionChanged event, Emitter<P2PState> emit) {
    emit(state.copyWith(connectionInfo: event.connectionInfo));
  }

  void _onMessageReceived(MessageReceived event, Emitter<P2PState> emit) {
    final message = P2PMessage(
      id: DateTime.now().millisecondsSinceEpoch.toString(),
      content: event.message,
      fromPeerId: event.fromPeerId,
      timestamp: event.timestamp,
      isLocal: false,
    );

    emit(state.copyWith(
      messages: [...state.messages, message],
    ));
  }

  @override
  Future<void> close() {
    _p2pManager.dispose();
    return super.close();
  }
}
