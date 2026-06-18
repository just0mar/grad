import 'package:equatable/equatable.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

import '../models/api_models.dart';
import '../services/api_client.dart';
import '../services/messaging_service.dart';
import 'MessagesModel.dart';

abstract class MessagesEvent extends Equatable {
  @override
  List<Object?> get props => [];
}

class LoadMessages extends MessagesEvent {}

class SearchMembers extends MessagesEvent {
  final String query;

  SearchMembers(this.query);

  @override
  List<Object?> get props => [query];
}

class MessagesState extends Equatable {
  final List<TeamMember> members;
  final List<TeamMember> filteredMembers;
  final bool isLoading;
  final String? error;

  const MessagesState({
    this.members = const [],
    this.filteredMembers = const [],
    this.isLoading = false,
    this.error,
  });

  MessagesState copyWith({
    List<TeamMember>? members,
    List<TeamMember>? filteredMembers,
    bool? isLoading,
    String? error,
    bool clearError = false,
  }) {
    return MessagesState(
      members: members ?? this.members,
      filteredMembers: filteredMembers ?? this.filteredMembers,
      isLoading: isLoading ?? this.isLoading,
      error: clearError ? null : error ?? this.error,
    );
  }

  @override
  List<Object?> get props => [members, filteredMembers, isLoading, error];
}

class MessagesBloc extends Bloc<MessagesEvent, MessagesState> {
  final MessagingService _messagingService = MessagingService();
  final String currentUserId;
  final Map<String, String> teamImagesByChatTitle;

  MessagesBloc({
    required this.currentUserId,
    this.teamImagesByChatTitle = const {},
  }) : super(const MessagesState()) {
    on<LoadMessages>(_onLoadMessages);
    on<SearchMembers>(_onSearchMembers);
  }

  Future<void> _onLoadMessages(
    LoadMessages event,
    Emitter<MessagesState> emit,
  ) async {
    emit(state.copyWith(isLoading: true, clearError: true));
    try {
      final conversations = await _messagingService.getConversations();
      final members = conversations.map((conversation) {
        String title;
        String? profileImageUrl;
        final isGroup =
            conversation.isGroup || conversation.participants.length > 2;

        if (conversation.title?.isNotEmpty == true) {
          title = conversation.title!;
          if (isGroup) {
            profileImageUrl = _teamImageForChatTitle(title);
          }
        } else if (!isGroup) {
          // For 1-on-1 conversations, show the OTHER participant's name
          final other = conversation.participants.firstWhere(
            (p) => p.userId != currentUserId,
            orElse: () => conversation.participants.isNotEmpty
                ? conversation.participants.first
                : const ConversationParticipantDto(userId: '', name: ''),
          );
          title = other.name;
          profileImageUrl = other.profileImageUrl;
        } else {
          title = conversation.participants.map((p) => p.name).join(', ');
        }

        return TeamMember(
          conversationId: conversation.conversationId,
          name: title.isNotEmpty ? title : 'Conversation',
          role: conversation.lastMessage?.isNotEmpty == true
              ? _cleanLastMessage(conversation.lastMessage!)
              : 'No messages yet',
          image: 'assets/profile.png',
          profileImageUrl: profileImageUrl,
          unreadCount: conversation.unreadCount,
          lastMessageType: conversation.lastMessageType,
          isGroup: isGroup,
        );
      }).toList();
      emit(
        state.copyWith(
          members: members,
          filteredMembers: members,
          isLoading: false,
        ),
      );
    } on ApiException catch (e) {
      emit(state.copyWith(isLoading: false, error: e.message));
    } catch (_) {
      emit(
        state.copyWith(
          isLoading: false,
          error: 'Could not load conversations.',
        ),
      );
    }
  }

  void _onSearchMembers(SearchMembers event, Emitter<MessagesState> emit) {
    if (event.query.isEmpty) {
      emit(state.copyWith(filteredMembers: state.members));
    } else {
      final filtered = state.members
          .where(
            (m) => m.name.toLowerCase().contains(event.query.toLowerCase()),
          )
          .toList();
      emit(state.copyWith(filteredMembers: filtered));
    }
  }

  String _cleanLastMessage(String value) {
    final text = value.trim();
    if (!text.startsWith('[reply|')) return text;
    final firstBreak = text.indexOf('\n');
    if (firstBreak < 0 || firstBreak + 1 >= text.length) return text;
    return text.substring(firstBreak + 1).trim();
  }

  String? _teamImageForChatTitle(String title) {
    final direct = teamImagesByChatTitle[title];
    if (direct != null && direct.isNotEmpty) return direct;

    final normalized = _normalizeTitle(title);
    for (final entry in teamImagesByChatTitle.entries) {
      if (_normalizeTitle(entry.key) == normalized && entry.value.isNotEmpty) {
        return entry.value;
      }
    }
    return null;
  }

  String _normalizeTitle(String value) =>
      value.trim().replaceAll(RegExp(r'\s+'), ' ').toLowerCase();
}
