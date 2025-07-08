import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:equatable/equatable.dart';
import '../../../../core/models/p2p_models.dart';
import '../../../../core/services/p2p_connection_manager.dart';
import '../../../../core/utils/app_logger.dart';

// Events
abstract class P2PEvent extends Equatable {
  const P2PEvent();
  @override
  List<Object?> get props => [];
}

class CreateRoom extends P2PEvent {
  const CreateRoom();
}

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

class P2PErrorOccurred extends P2PEvent {
  final String error;
  const P2PErrorOccurred(this.error);
  @override
  List<Object?> get props => [error];
}

// States
class P2PState extends Equatable {
  final P2PConnectionInfo connectionInfo;
  final List<P2PMessage> messages;
  final String? errorMessage;
  final bool isLoading;

  const P2PState({
    this.connectionInfo = const P2PConnectionInfo(roomId: '', localPeerId: ''),
    this.messages = const [],
    this.errorMessage,
    this.isLoading = false,
  });

  P2PState copyWith({
    P2PConnectionInfo? connectionInfo,
    List<P2PMessage>? messages,
    String? errorMessage,
    bool? isLoading,
    bool clearError = false,
  }) {
    return P2PState(
      connectionInfo: connectionInfo ?? this.connectionInfo,
      messages: messages ?? this.messages,
      errorMessage: clearError ? null : (errorMessage ?? this.errorMessage),
      isLoading: isLoading ?? this.isLoading,
    );
  }

  @override
  List<Object?> get props => [connectionInfo, messages, errorMessage, isLoading];
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

// BLoC Implementation
class P2PBlocFixed extends Bloc<P2PEvent, P2PState> {
  final P2PConnectionManager _p2pManager;
  final AppLogger _logger = AppLogger();

  P2PBlocFixed({P2PConnectionManager? p2pManager}) 
      : _p2pManager = p2pManager ?? P2PConnectionManager(),
        super(const P2PState()) {
    
    on<CreateRoom>(_onCreateRoom);
    on<JoinRoom>(_onJoinRoom);
    on<SendMessage>(_onSendMessage);
    on<LeaveRoom>(_onLeaveRoom);
    on<P2PConnectionChanged>(_onConnectionChanged);
    on<MessageReceived>(_onMessageReceived);
    on<P2PErrorOccurred>(_onErrorOccurred);
    
    _setupP2PCallbacks();
  }

  void _setupP2PCallbacks() {
    _logger.info('🔗 Setting up P2P callbacks...');
    
    _p2pManager.onConnectionInfoChanged = (P2PConnectionInfo info) {
      _logger.debug('📡 Connection info changed: ${info.connectionState}');
      add(P2PConnectionChanged(info));
    };

    _p2pManager.onMessageReceived = (String message, String fromPeerId, DateTime timestamp) {
      _logger.debug('📥 Message received from $fromPeerId: $message');
      add(MessageReceived(message, fromPeerId, timestamp));
    };

    _p2pManager.onError = (String error) {
      _logger.error('🚨 P2P Error: $error');
      add(P2PErrorOccurred(error));
    };
  }

  Future<void> _onCreateRoom(CreateRoom event, Emitter<P2PState> emit) async {
    try {
      _logger.info('🏠 Creating room...');
      emit(state.copyWith(isLoading: true, clearError: true));
      
      final roomId = await _p2pManager.createRoom();
      
      _logger.success('✅ Room created successfully: $roomId');
      emit(state.copyWith(
        isLoading: false,
        connectionInfo: state.connectionInfo.copyWith(roomId: roomId),
      ));
    } catch (e) {
      _logger.error('❌ Failed to create room: $e');
      emit(state.copyWith(
        isLoading: false,
        errorMessage: 'Failed to create room: $e',
      ));
    }
  }

  Future<void> _onJoinRoom(JoinRoom event, Emitter<P2PState> emit) async {
    try {
      _logger.info('🚪 Joining room: ${event.roomId}');
      emit(state.copyWith(isLoading: true, clearError: true));
      
      await _p2pManager.joinRoom(event.roomId);
      
      _logger.success('✅ Successfully joined room: ${event.roomId}');
      emit(state.copyWith(
        isLoading: false,
        connectionInfo: state.connectionInfo.copyWith(roomId: event.roomId),
      ));
    } catch (e) {
      _logger.error('❌ Failed to join room: $e');
      emit(state.copyWith(
        isLoading: false,
        errorMessage: 'Failed to join room: $e',
      ));
    }
  }

  Future<void> _onSendMessage(SendMessage event, Emitter<P2PState> emit) async {
    try {
      if (state.connectionInfo.connectionState != PeerConnectionState.connected) {
        throw Exception('Not connected to any peer');
      }

      _logger.debug('📤 Sending message: ${event.message}');
      await _p2pManager.sendMessage(event.message);

      // Add local message to UI
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
      _logger.error('❌ Failed to send message: $e');
      emit(state.copyWith(errorMessage: 'Failed to send message: $e'));
    }
  }

  Future<void> _onLeaveRoom(LeaveRoom event, Emitter<P2PState> emit) async {
    try {
      _logger.info('🚪 Leaving room...');
      emit(state.copyWith(isLoading: true));
      
      await _p2pManager.leaveRoom();
      
      _logger.success('✅ Successfully left room');
      emit(state.copyWith(
        isLoading: false,
        connectionInfo: const P2PConnectionInfo(roomId: '', localPeerId: ''),
        messages: [],
        clearError: true,
      ));
    } catch (e) {
      _logger.error('❌ Failed to leave room: $e');
      emit(state.copyWith(
        isLoading: false,
        errorMessage: 'Failed to leave room: $e',
      ));
    }
  }

  void _onConnectionChanged(P2PConnectionChanged event, Emitter<P2PState> emit) {
    _logger.debug('🔄 Connection state updated: ${event.connectionInfo.connectionState}');
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

    _logger.debug('📨 Adding received message to UI: ${event.message}');
    emit(state.copyWith(messages: [...state.messages, message]));
  }

  void _onErrorOccurred(P2PErrorOccurred event, Emitter<P2PState> emit) {
    emit(state.copyWith(errorMessage: event.error));
  }

  @override
  Future<void> close() {
    _logger.info('🔌 Disposing P2P BLoC...');
    _p2pManager.dispose();
    return super.close();
  }
}
