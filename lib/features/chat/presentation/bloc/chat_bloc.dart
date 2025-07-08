import 'package:equatable/equatable.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import '../../domain/entities/message.dart';
import '../../data/repositories/chat_repository_impl.dart';

// Events
abstract class ChatEvent extends Equatable {
  const ChatEvent();

  @override
  List<Object?> get props => [];
}

class LoadMessages extends ChatEvent {}

class SendTextMessage extends ChatEvent {
  final String content;

  const SendTextMessage(this.content);

  @override
  List<Object?> get props => [content];
}

class SendVoiceMessage extends ChatEvent {
  final String filePath;
  final Duration duration;

  const SendVoiceMessage(this.filePath, this.duration);

  @override
  List<Object?> get props => [filePath, duration];
}

class ReceiveMessage extends ChatEvent {
  final Message message;

  const ReceiveMessage(this.message);

  @override
  List<Object?> get props => [message];
}

class StartRecording extends ChatEvent {}

class StopRecording extends ChatEvent {}

class CancelRecording extends ChatEvent {}

// States
abstract class ChatState extends Equatable {
  const ChatState();

  @override
  List<Object?> get props => [];
}

class ChatInitial extends ChatState {}

class ChatLoading extends ChatState {}

class ChatLoaded extends ChatState {
  final List<Message> messages;
  final bool isRecording;

  const ChatLoaded({
    required this.messages,
    this.isRecording = false,
  });

  @override
  List<Object?> get props => [messages, isRecording];

  ChatLoaded copyWith({
    List<Message>? messages,
    bool? isRecording,
  }) {
    return ChatLoaded(
      messages: messages ?? this.messages,
      isRecording: isRecording ?? this.isRecording,
    );
  }
}

class ChatError extends ChatState {
  final String message;

  const ChatError(this.message);

  @override
  List<Object?> get props => [message];
}

// BLoC
class ChatBloc extends Bloc<ChatEvent, ChatState> {
  final ChatRepositoryImpl chatRepository;

  ChatBloc({required this.chatRepository}) : super(ChatInitial()) {
    on<LoadMessages>(_onLoadMessages);
    on<SendTextMessage>(_onSendTextMessage);
    on<SendVoiceMessage>(_onSendVoiceMessage);
    on<ReceiveMessage>(_onReceiveMessage);
    on<StartRecording>(_onStartRecording);
    on<StopRecording>(_onStopRecording);
    on<CancelRecording>(_onCancelRecording);
  }

  void _onLoadMessages(LoadMessages event, Emitter<ChatState> emit) async {
    emit(ChatLoading());
    try {
      final messages = await chatRepository.getMessages();
      emit(ChatLoaded(messages: messages));
    } catch (e) {
      emit(ChatError(e.toString()));
    }
  }

  void _onSendTextMessage(
      SendTextMessage event, Emitter<ChatState> emit) async {
    if (state is ChatLoaded) {
      final currentState = state as ChatLoaded;
      try {
        final message = await chatRepository.sendTextMessage(event.content);
        final updatedMessages = [...currentState.messages, message];
        emit(currentState.copyWith(messages: updatedMessages));
      } catch (e) {
        emit(ChatError(e.toString()));
      }
    }
  }

  void _onSendVoiceMessage(
      SendVoiceMessage event, Emitter<ChatState> emit) async {
    if (state is ChatLoaded) {
      final currentState = state as ChatLoaded;
      try {
        final message = await chatRepository.sendVoiceMessage(
          event.filePath,
          event.duration,
        );
        final updatedMessages = [...currentState.messages, message];
        emit(currentState.copyWith(
          messages: updatedMessages,
          isRecording: false,
        ));
      } catch (e) {
        emit(ChatError(e.toString()));
      }
    }
  }

  void _onReceiveMessage(ReceiveMessage event, Emitter<ChatState> emit) {
    if (state is ChatLoaded) {
      final currentState = state as ChatLoaded;
      final updatedMessages = [...currentState.messages, event.message];
      emit(currentState.copyWith(messages: updatedMessages));
    }
  }

  void _onStartRecording(StartRecording event, Emitter<ChatState> emit) {
    if (state is ChatLoaded) {
      final currentState = state as ChatLoaded;
      emit(currentState.copyWith(isRecording: true));
    }
  }

  void _onStopRecording(StopRecording event, Emitter<ChatState> emit) {
    if (state is ChatLoaded) {
      final currentState = state as ChatLoaded;
      emit(currentState.copyWith(isRecording: false));
    }
  }

  void _onCancelRecording(CancelRecording event, Emitter<ChatState> emit) {
    if (state is ChatLoaded) {
      final currentState = state as ChatLoaded;
      emit(currentState.copyWith(isRecording: false));
    }
  }
}
