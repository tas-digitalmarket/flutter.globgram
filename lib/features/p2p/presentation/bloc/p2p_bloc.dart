import 'package:equatable/equatable.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import '../../data/repositories/p2p_repository_impl.dart';

// Events
abstract class P2pEvent extends Equatable {
  const P2pEvent();

  @override
  List<Object?> get props => [];
}

class InitializeP2P extends P2pEvent {}

class CreateRoom extends P2pEvent {
  final String roomName;

  const CreateRoom(this.roomName);

  @override
  List<Object?> get props => [roomName];
}

class JoinRoom extends P2pEvent {
  final String sdpOffer;

  const JoinRoom(this.sdpOffer);

  @override
  List<Object?> get props => [sdpOffer];
}

class DisconnectP2P extends P2pEvent {}

class SendP2PMessage extends P2pEvent {
  final String message;

  const SendP2PMessage(this.message);

  @override
  List<Object?> get props => [message];
}

// States
abstract class P2pState extends Equatable {
  const P2pState();

  @override
  List<Object?> get props => [];
}

class P2pInitial extends P2pState {}

class P2pInitializing extends P2pState {}

class P2pWaitingForPeer extends P2pState {
  final String sdpOffer; // QR code data

  const P2pWaitingForPeer(this.sdpOffer);

  @override
  List<Object?> get props => [sdpOffer];
}

class P2pConnecting extends P2pState {}

class P2pConnected extends P2pState {
  final String peerId;

  const P2pConnected(this.peerId);

  @override
  List<Object?> get props => [peerId];
}

class P2pDisconnected extends P2pState {}

class P2pError extends P2pState {
  final String message;

  const P2pError(this.message);

  @override
  List<Object?> get props => [message];
}

// BLoC
class P2pBloc extends Bloc<P2pEvent, P2pState> {
  final P2pRepositoryImpl p2pRepository;

  P2pBloc({required this.p2pRepository}) : super(P2pInitial()) {
    on<InitializeP2P>(_onInitializeP2P);
    on<CreateRoom>(_onCreateRoom);
    on<JoinRoom>(_onJoinRoom);
    on<DisconnectP2P>(_onDisconnectP2P);
    on<SendP2PMessage>(_onSendP2PMessage);
  }

  void _onInitializeP2P(InitializeP2P event, Emitter<P2pState> emit) async {
    emit(P2pInitializing());
    try {
      await p2pRepository.initialize();
      emit(P2pInitial());
    } catch (e) {
      emit(P2pError(e.toString()));
    }
  }

  void _onCreateRoom(CreateRoom event, Emitter<P2pState> emit) async {
    emit(P2pInitializing());
    try {
      final sdpOffer = await p2pRepository.createRoom(event.roomName);
      emit(P2pWaitingForPeer(sdpOffer));
    } catch (e) {
      emit(P2pError(e.toString()));
    }
  }

  void _onJoinRoom(JoinRoom event, Emitter<P2pState> emit) async {
    emit(P2pConnecting());
    try {
      final peerId = await p2pRepository.joinRoom(event.sdpOffer);
      emit(P2pConnected(peerId));
    } catch (e) {
      emit(P2pError(e.toString()));
    }
  }

  void _onDisconnectP2P(DisconnectP2P event, Emitter<P2pState> emit) async {
    try {
      await p2pRepository.disconnect();
      emit(P2pDisconnected());
    } catch (e) {
      emit(P2pError(e.toString()));
    }
  }

  void _onSendP2PMessage(SendP2PMessage event, Emitter<P2pState> emit) async {
    try {
      await p2pRepository.sendMessage(event.message);
    } catch (e) {
      emit(P2pError(e.toString()));
    }
  }
}
