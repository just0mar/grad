import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import '../appbar/CustomAppBar.dart';
import '../chat/ChatView.dart';
import '../core/app_background.dart';
import '../core/app_transitions.dart';
import '../core/responsive_system.dart';
import '../services/api_client.dart';
import '../session/session_bloc.dart';
import '../team/team_bloc.dart';
import 'messages_bloc.dart';
import 'MessagesModel.dart';
import '../core/app_localizations.dart';

class MessagesView extends StatelessWidget {
  final List<Map<String, dynamic>> plans;

  const MessagesView({super.key, required this.plans});

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return BlocProvider(
      create: (context) => MessagesBloc(
        currentUserId: context.read<SessionBloc>().state.user?.userId ?? '',
        teamImagesByChatTitle: _teamImagesByChatTitle(context),
      )..add(LoadMessages()),
      child: Scaffold(
        extendBodyBehindAppBar: true,
        appBar: CustomAppBar(title: AppLocalizations.of(context).titleMessages, showTeamSwitcher: false, plans: plans),
        body: AppBackground(
          child: SafeArea(
            child: BlocConsumer<MessagesBloc, MessagesState>(
              listener: (context, state) {
                if (state.error != null) {
                  ScaffoldMessenger.of(
                    context,
                  ).showSnackBar(SnackBar(content: Text(state.error!)));
                }
              },
              builder: (context, state) {
                if (state.isLoading) {
                  return const Center(child: CircularProgressIndicator());
                }
                if (state.filteredMembers.isEmpty) {
                  return Center(
                    child: Text(
                      AppLocalizations.of(context).messagesNoConversations,
                      style: TextStyle(
                        color: isDark ? Colors.white70 : Colors.black54,
                        fontFamily: 'SFPro',
                      ),
                    ),
                  );
                }
                return ListView.builder(
                  physics: const AlwaysScrollableScrollPhysics(),
                  padding: ResponsiveSystem.pagePadding(context),
                  itemCount: state.filteredMembers.length,
                  itemBuilder: (context, index) {
                    final member = state.filteredMembers[index];
                    return StaggeredListItem(
                      index: index,
                      child: _MessageCard(member: member),
                    );
                  },
                );
              },
            ),
          ),
        ),
      ),
    );
  }

  Map<String, String> _teamImagesByChatTitle(BuildContext context) {
    final teams = context.read<TeamBloc>().state.availableTeams;
    final images = <String, String>{};
    for (final team in teams) {
      final image = team.imageUrl?.isNotEmpty == true
          ? team.imageUrl!
          : team.clubLogoUrl;
      if (image == null || image.isEmpty) continue;

      final title = '${team.club} Team Chat'.trim();
      if (title.isNotEmpty) images[title] = image;
    }
    return images;
  }
}

class _MessageCard extends StatelessWidget {
  final TeamMember member;

  const _MessageCard({required this.member});

  Widget _buildLastMessagePreview(BuildContext context, TeamMember member, bool isDark) {
    final t = AppLocalizations.of(context);
    final textColor = isDark ? Colors.white54 : Colors.grey;
    final type = member.lastMessageType;

    if (type != 'text') {
      IconData icon;
      String label;
      switch (type) {
        case 'image':
          icon = Icons.photo;
          label = t.messagesPhoto;
          break;
        case 'video':
          icon = Icons.videocam;
          label = t.messagesVideo;
          break;
        case 'audio':
          icon = Icons.mic;
          label = t.messagesVoiceNote;
          break;
        case 'document':
          icon = Icons.insert_drive_file;
          label = t.messagesDocument;
          break;
        case 'location':
          icon = Icons.location_on;
          label = t.messagesLocation;
          break;
        default:
          icon = Icons.insert_drive_file;
          label = t.messagesFile;
      }
      return Row(
        children: [
          Icon(icon, size: 16, color: textColor),
          const SizedBox(width: 4),
          Expanded(
            child: Text(
              label,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: TextStyle(
                fontFamily: 'SFPro',
                fontSize: 14,
                color: textColor,
              ),
            ),
          ),
        ],
      );
    }

    return Text(
      member.role,
      maxLines: 1,
      overflow: TextOverflow.ellipsis,
      style: TextStyle(fontFamily: 'SFPro', fontSize: 14, color: textColor),
    );
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;

    final resolvedUrl = ApiClient.resolveUrl(member.profileImageUrl);
    final hasNetworkImage = resolvedUrl != null && resolvedUrl.isNotEmpty;

    return AnimatedPressable(
      onTap: () async {
        await Navigator.push(
          context,
          AppPageRoute(
            child: ChatView(
              conversationId: member.conversationId,
              personName: member.name,
              personImage: resolvedUrl ?? member.image,
              currentUserId:
                  context.read<SessionBloc>().state.user?.userId ?? '',
            ),
          ),
        );
        if (!context.mounted) return;
        context.read<MessagesBloc>().add(LoadMessages());
      },
      child: Card(
        color: isDark ? const Color(0xFF1B3A2D) : Colors.white,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        elevation: 3,
        margin: const EdgeInsets.symmetric(vertical: 8),
        child: Padding(
          padding: const EdgeInsets.all(12),
          child: Row(
            children: [
              hasNetworkImage
                  ? CircleAvatar(
                      backgroundImage: NetworkImage(resolvedUrl),
                      radius: 28,
                    )
                  : CircleAvatar(
                      radius: 28,
                      backgroundColor: isDark
                          ? const Color(0xFF0D2A1C)
                          : Colors.grey[300],
                      child: Icon(
                        member.isGroup ? Icons.groups : Icons.person,
                        size: 28,
                        color: isDark ? Colors.white54 : Colors.grey[600],
                      ),
                    ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      member.name,
                      style: TextStyle(
                        fontFamily: 'SFPro',
                        fontSize: 16,
                        fontWeight: FontWeight.bold,
                        color: isDark ? Colors.white : Colors.black,
                      ),
                    ),
                    _buildLastMessagePreview(context, member, isDark),
                  ],
                ),
              ),
              if (member.unreadCount > 0)
                CircleAvatar(
                  radius: 11,
                  backgroundColor: Colors.green,
                  child: Text(
                    '${member.unreadCount}',
                    style: const TextStyle(color: Colors.white, fontSize: 11),
                  ),
                ),
            ],
          ),
        ),
      ),
    );
  }
}
