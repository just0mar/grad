import 'dart:typed_data';
import 'package:equatable/equatable.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

import '../services/api_client.dart';
import '../services/messaging_service.dart';
import 'ChatModel.dart';
import '../location/location_point.dart';

abstract class ChatEvent extends Equatable {
  @override
  List<Object?> get props => [];
}

class LoadChatMessages extends ChatEvent {}

class SendMessage extends ChatEvent {
  final String text;
  SendMessage(this.text);
  @override
  List<Object?> get props => [text];
}

class SendMediaMessage extends ChatEvent {
    final Uint8List? fileBytes;
    final String? filePath;
    final String fileName;
    final String? caption;
    SendMediaMessage({
      this.fileBytes,
      this.filePath,
      required this.fileName,
      this.caption,
    });
  @override
  List<Object?> get props => [fileBytes, filePath, fileName, caption];
}

class SendVoiceNote extends ChatEvent {
  final String filePath;
  SendVoiceNote(this.filePath);
  @override
  List<Object?> get props => [filePath];
}

class SendLocationMessage extends ChatEvent {
  final LocationPoint location;
  SendLocationMessage(this.location);
  @override
  List<Object?> get props => [location.latitude, location.longitude, location.label];
}

class EditMessage extends ChatEvent {
  final String messageId;
  final String newContent;
  EditMessage({required this.messageId, required this.newContent});
  @override
  List<Object?> get props => [messageId, newContent];
}

class DeleteMessage extends ChatEvent {
  final String messageId;
  DeleteMessage(this.messageId);
  @override
  List<Object?> get props => [messageId];
}

class ToggleReaction extends ChatEvent {
  final String messageId;
  final String emoji;
  ToggleReaction({required this.messageId, required this.emoji});
  @override
  List<Object?> get props => [messageId, emoji];
}

class ChatState extends Equatable {
  final List<ChatMessage> messages;
  final bool isLoading;
  final bool isSending;
  final bool isRecording;
  final String? error;

  const ChatState({
    this.messages = const [],
    this.isLoading = false,
    this.isSending = false,
    this.isRecording = false,
    this.error,
  });

  ChatState copyWith({
    List<ChatMessage>? messages,
    bool? isLoading,
    bool? isSending,
    bool? isRecording,
    String? error,
    bool clearError = false,
  }) {
    return ChatState(
      messages: messages ?? this.messages,
      isLoading: isLoading ?? this.isLoading,
      isSending: isSending ?? this.isSending,
      isRecording: isRecording ?? this.isRecording,
      error: clearError ? null : error ?? this.error,
    );
  }

  @override
  List<Object?> get props => [
    messages,
    isLoading,
    isSending,
    isRecording,
    error,
  ];
}

class ChatBloc extends Bloc<ChatEvent, ChatState> {
  final MessagingService _messagingService = MessagingService();
  final String conversationId;
  final String currentUserId;

  ChatBloc({required this.conversationId, required this.currentUserId})
    : super(const ChatState()) {
    on<LoadChatMessages>(_onLoad);
    on<SendMessage>(_onSend);
    on<SendMediaMessage>(_onSendMedia);
    on<SendVoiceNote>(_onSendVoice);
    on<SendLocationMessage>(_onSendLocation);
    on<EditMessage>(_onEdit);
    on<DeleteMessage>(_onDelete);
    on<ToggleReaction>(_onToggleReaction);
  }

  ChatMessage _mapDto(msg) => ChatMessage(
    messageId: msg.messageId,
    text: msg.content,
    fromMe: msg.senderUserId == currentUserId,
    sentAt: msg.sentAt,
    editedAt: msg.editedAt,
    isDeleted: msg.isDeleted ?? false,
    isRead: msg.isRead ?? false,
    messageType: msg.messageType ?? 'text',
    mediaUrl: msg.mediaUrl,
    mediaFileName: msg.mediaFileName,
    locationLatitude: msg.locationLatitude,
    locationLongitude: msg.locationLongitude,
    locationLabel: msg.locationLabel,
    reactions: msg.reactions ?? const [],
    seenBy: msg.seenBy ?? const [],
    seenByCount: msg.seenByCount ?? 0,
    requiredSeenCount: msg.requiredSeenCount ?? 0,
    seenByAll: msg.seenByAll ?? msg.isRead ?? false,
  );

  List<ChatMessage> _newestFirst(Iterable<ChatMessage> messages) {
    final sorted = messages.toList()
      ..sort((a, b) => b.sentAt.compareTo(a.sentAt));
    return sorted;
  }

  Future<void> _onLoad(LoadChatMessages event, Emitter<ChatState> emit) async {
    if (conversationId.isEmpty) {
      emit(state.copyWith(error: 'Conversation is missing.'));
      return;
    }
    emit(state.copyWith(isLoading: true, clearError: true));
    try {
      await _messagingService.markRead(conversationId);
      final messages = await _messagingService.getMessages(conversationId);
      emit(
        state.copyWith(
          messages: _newestFirst(messages.map(_mapDto)),
          isLoading: false,
        ),
      );
    } on ApiException catch (e) {
      emit(state.copyWith(isLoading: false, error: e.message));
    } catch (_) {
      emit(state.copyWith(isLoading: false, error: 'Could not load chat.'));
    }
  }

  Future<void> _onSend(SendMessage event, Emitter<ChatState> emit) async {
    final text = event.text.trim();
    if (text.isEmpty || state.isSending) return;
    emit(state.copyWith(isSending: true, clearError: true));
    try {
      final sent = await _messagingService.sendMessage(conversationId, text);
      final updated = [_mapDto(sent), ...state.messages];
      emit(state.copyWith(messages: updated, isSending: false));
    } on ApiException catch (e) {
      emit(state.copyWith(isSending: false, error: e.message));
    } catch (_) {
      emit(state.copyWith(isSending: false, error: 'Could not send message.'));
    }
  }

  Future<void> _onSendMedia(
    SendMediaMessage event,
    Emitter<ChatState> emit,
  ) async {
    emit(state.copyWith(isSending: true, clearError: true));
    try {
      final sent = await _messagingService.sendMedia(
          conversationId,
          event.fileBytes,
          event.filePath,
          event.fileName,
        );
      var updated = [_mapDto(sent), ...state.messages];
      // Send caption as a follow-up text message if provided
      if (event.caption != null && event.caption!.trim().isNotEmpty) {
        final captionMsg = await _messagingService.sendMessage(
          conversationId,
          event.caption!.trim(),
        );
        updated = [_mapDto(captionMsg), ...updated];
      }
      emit(state.copyWith(messages: updated, isSending: false));
    } on ApiException catch (e) {
      emit(state.copyWith(isSending: false, error: e.message));
    } catch (_) {
      emit(state.copyWith(isSending: false, error: 'Could not send file.'));
    }
  }

  Future<void> _onSendVoice(
    SendVoiceNote event,
    Emitter<ChatState> emit,
  ) async {
    emit(state.copyWith(isSending: true, clearError: true));
    try {
      final fileName = 'voice_${DateTime.now().millisecondsSinceEpoch}.m4a';
      final sent = await _messagingService.sendMedia(
          conversationId,
          null,
          event.filePath,
          fileName,
        );
      final updated = [_mapDto(sent), ...state.messages];
      emit(state.copyWith(messages: updated, isSending: false));
    } on ApiException catch (e) {
      emit(state.copyWith(isSending: false, error: e.message));
    } catch (_) {
      emit(
        state.copyWith(isSending: false, error: 'Could not send voice note.'),
      );
    }
  }

  Future<void> _onSendLocation(
    SendLocationMessage event,
    Emitter<ChatState> emit,
  ) async {
    emit(state.copyWith(isSending: true, clearError: true));
    try {
      final sent = await _messagingService.sendLocation(
        conversationId,
        event.location,
      );
      final updated = [_mapDto(sent), ...state.messages];
      emit(state.copyWith(messages: updated, isSending: false));
    } on ApiException catch (e) {
      emit(state.copyWith(isSending: false, error: e.message));
    } catch (_) {
      emit(state.copyWith(isSending: false, error: 'Could not send location.'));
    }
  }

  Future<void> _onEdit(EditMessage event, Emitter<ChatState> emit) async {
    try {
      await _messagingService.editMessage(event.messageId, event.newContent);
      final updated = state.messages.map((m) {
        if (m.messageId == event.messageId) {
          return m.copyWith(text: event.newContent, editedAt: DateTime.now());
        }
        return m;
      }).toList();
      emit(state.copyWith(messages: updated));
    } on ApiException catch (e) {
      emit(state.copyWith(error: e.message));
    } catch (_) {
      emit(state.copyWith(error: 'Could not edit message.'));
    }
  }

  Future<void> _onDelete(DeleteMessage event, Emitter<ChatState> emit) async {
    try {
      await _messagingService.deleteMessage(event.messageId);
      final updated = state.messages.map((m) {
        if (m.messageId == event.messageId) {
          return m.copyWith(isDeleted: true, text: 'This message was deleted');
        }
        return m;
      }).toList();
      emit(state.copyWith(messages: updated));
    } on ApiException catch (e) {
      emit(state.copyWith(error: e.message));
    } catch (_) {
      emit(state.copyWith(error: 'Could not delete message.'));
    }
  }

  Future<void> _onToggleReaction(
    ToggleReaction event,
    Emitter<ChatState> emit,
  ) async {
    try {
      final msg = state.messages.firstWhere(
        (m) => m.messageId == event.messageId,
        orElse: () => ChatMessage(text: '', fromMe: false),
      );
      final hasReaction = msg.reactions.any(
        (r) => r.userId == currentUserId && r.emoji == event.emoji,
      );

      if (hasReaction) {
        await _messagingService.removeReaction(event.messageId, event.emoji);
        final updated = state.messages.map((message) {
          if (message.messageId != event.messageId) return message;
          return message.copyWith(
            reactions: message.reactions
                .where(
                  (reaction) =>
                      !(reaction.userId == currentUserId &&
                          reaction.emoji == event.emoji),
                )
                .toList(),
          );
        }).toList();
        emit(state.copyWith(messages: updated));
      } else {
        for (final reaction in msg.reactions.where(
          (item) => item.userId == currentUserId,
        )) {
          await _messagingService.removeReaction(
            event.messageId,
            reaction.emoji,
          );
        }
        final reaction = await _messagingService.addReaction(
          event.messageId,
          event.emoji,
        );
        final updated = state.messages.map((message) {
          if (message.messageId != event.messageId) return message;
          final reactions =
              message.reactions
                  .where((item) => item.userId != currentUserId)
                  .toList()
                ..add(reaction);
          return message.copyWith(reactions: reactions);
        }).toList();
        emit(state.copyWith(messages: updated));
      }
    } on ApiException catch (e) {
      emit(state.copyWith(error: e.message));
    } catch (_) {
      emit(state.copyWith(error: 'Could not update reaction.'));
    }
  }
}
