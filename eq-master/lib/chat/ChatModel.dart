import '../models/api_models.dart';

class ChatMessage {
  final String messageId;
  final String text;
  final bool fromMe;
  final String? senderName;
  final String? senderImageUrl;
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
    required this.messageId,
    required this.text,
    required this.fromMe,
    this.senderName,
    this.senderImageUrl,
    required this.sentAt,
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
  });

  ChatMessage copyWith({
    String? messageId,
    String? text,
    bool? fromMe,
    String? senderName,
    String? senderImageUrl,
    DateTime? sentAt,
    DateTime? editedAt,
    bool? isDeleted,
    bool? isRead,
    String? messageType,
    String? mediaUrl,
    String? mediaFileName,
    double? locationLatitude,
    double? locationLongitude,
    String? locationLabel,
    List<MessageReactionDto>? reactions,
    List<MessageSeenByDto>? seenBy,
    int? seenByCount,
    int? requiredSeenCount,
    bool? seenByAll,
  }) {
    return ChatMessage(
      messageId: messageId ?? this.messageId,
      text: text ?? this.text,
      fromMe: fromMe ?? this.fromMe,
      senderName: senderName ?? this.senderName,
      senderImageUrl: senderImageUrl ?? this.senderImageUrl,
      sentAt: sentAt ?? this.sentAt,
      editedAt: editedAt ?? this.editedAt,
      isDeleted: isDeleted ?? this.isDeleted,
      isRead: isRead ?? this.isRead,
      messageType: messageType ?? this.messageType,
      mediaUrl: mediaUrl ?? this.mediaUrl,
      mediaFileName: mediaFileName ?? this.mediaFileName,
      locationLatitude: locationLatitude ?? this.locationLatitude,
      locationLongitude: locationLongitude ?? this.locationLongitude,
      locationLabel: locationLabel ?? this.locationLabel,
      reactions: reactions ?? this.reactions,
      seenBy: seenBy ?? this.seenBy,
      seenByCount: seenByCount ?? this.seenByCount,
      requiredSeenCount: requiredSeenCount ?? this.requiredSeenCount,
      seenByAll: seenByAll ?? this.seenByAll,
    );
  }
  bool get canEditOrDelete {
    final now = DateTime.now();
    final diff = now.difference(sentAt);
    return fromMe && diff.inMinutes < 60;
  }
}
