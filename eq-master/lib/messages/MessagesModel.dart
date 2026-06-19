class TeamMember {
  final String conversationId;
  final String name;
  final String role;
  final String image;
  final String? profileImageUrl;
  final int unreadCount;
  final String lastMessageType; // text, image, video, audio, document
  final bool isGroup;

  TeamMember({
    this.conversationId = '',
    required this.name,
    required this.role,
    required this.image,
    this.profileImageUrl,
    this.unreadCount = 0,
    this.lastMessageType = 'text',
    this.isGroup = false,
  });
}
