import '../models/api_models.dart';

class ChatMessage {
  final String messageId;
  final String text;
  final bool fromMe;
  final DateTime sentAt;
  final DateTime? editedAt;
  final bool isDeleted;
  final bool isRead;
  final String messageType; // text, image, video, document, audio, poll, location
  final String? mediaUrl;
  final String? mediaFileName;
  final double? locationLatitude;
  final double? locationLongitude;
  final String? locationLabel;
  final List<MessageReactionDto> reactions;
  final List<MessageSeenByDto> seenBy;
  final int seenByCount;
  final int requiredSeenCount;
  final bool seenByAll;

  ChatMessage({
    this.messageId = '',
    required this.text,
    required this.fromMe,
    DateTime? sentAt,
    this.editedAt,
    this.isDeleted = false,
    this.isRead = false,
    this.messageType = 'text',
    this.mediaUrl,
    this.mediaFileName,
    this.locationLatitude,
    this.locationLongitude,
    this.locationLabel,
    this.reactions = const [],
    this.seenBy = const [],
    this.seenByCount = 0,
    this.requiredSeenCount = 0,
    this.seenByAll = false,
  }) : sentAt = sentAt ?? DateTime.now();

  bool get canEditOrDelete {
    final now = DateTime.now();
    final diff = now.difference(sentAt);
    return fromMe && diff.inMinutes < 60;
  }

  ChatMessage copyWith({
    String? text,
    DateTime? editedAt,
    bool? isDeleted,
    bool? isRead,
    List<MessageReactionDto>? reactions,
    List<MessageSeenByDto>? seenBy,
    int? seenByCount,
    int? requiredSeenCount,
    bool? seenByAll,
  }) {
    return ChatMessage(
      messageId: messageId,
      text: text ?? this.text,
      fromMe: fromMe,
      sentAt: sentAt,
      editedAt: editedAt ?? this.editedAt,
      isDeleted: isDeleted ?? this.isDeleted,
      isRead: isRead ?? this.isRead,
      messageType: messageType,
      mediaUrl: mediaUrl,
      mediaFileName: mediaFileName,
      locationLatitude: locationLatitude,
      locationLongitude: locationLongitude,
      locationLabel: locationLabel,
      reactions: reactions ?? this.reactions,
      seenBy: seenBy ?? this.seenBy,
      seenByCount: seenByCount ?? this.seenByCount,
      requiredSeenCount: requiredSeenCount ?? this.requiredSeenCount,
      seenByAll: seenByAll ?? this.seenByAll,
    );
  }
}
