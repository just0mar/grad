import '../models/api_models.dart';
import '../location/location_point.dart';
import 'api_client.dart';

class MessagingService {
  final ApiClient _api = ApiClient.instance;

  Future<List<ConversationDto>> getConversations() async {
    final json = await _api.get('/messages/conversations');
    return (json as List)
        .map((e) =>
            ConversationDto.fromJson(Map<String, dynamic>.from(e as Map)))
        .toList();
  }

  Future<ConversationDto> createConversation({
    required List<String> participantIds,
    String? name,
    bool isGroup = false,
  }) async {
    final json = await _api.post('/messages/conversations', body: {
      'participantUserIds': participantIds,
      if (name != null && name.isNotEmpty) 'name': name,
      'isGroup': isGroup,
    });
    return ConversationDto.fromJson(Map<String, dynamic>.from(json as Map));
  }

  Future<List<MessageDto>> getMessages(String conversationId) async {
    final json =
        await _api.get('/messages/conversations/$conversationId/messages');
    return (json as List)
        .map((e) => MessageDto.fromJson(Map<String, dynamic>.from(e as Map)))
        .toList();
  }

  Future<MessageDto> sendMessage(String conversationId, String content) async {
    final json = await _api.post(
      '/messages/conversations/$conversationId/messages',
      body: {'content': content},
    );
    return MessageDto.fromJson(Map<String, dynamic>.from(json as Map));
  }

  Future<MessageDto> sendLocation(
    String conversationId,
    LocationPoint location,
  ) async {
    final label = location.label?.trim();
    final json = await _api.post(
      '/messages/conversations/$conversationId/messages',
      body: {
        'content': label == null || label.isEmpty ? 'Shared location' : label,
        'messageType': 'location',
        'locationLatitude': location.latitude,
        'locationLongitude': location.longitude,
        if (label != null && label.isNotEmpty) 'locationLabel': label,
      },
    );
    return MessageDto.fromJson(Map<String, dynamic>.from(json as Map));
  }

  Future<void> markRead(String conversationId) async {
    await _api.post('/messages/conversations/$conversationId/read');
  }

  Future<MessageDto> editMessage(String messageId, String content) async {
    final json = await _api.put(
      '/messages/messages/$messageId',
      body: {'content': content},
    );
    return MessageDto.fromJson(Map<String, dynamic>.from(json as Map));
  }

  Future<void> deleteMessage(String messageId) async {
    await _api.delete('/messages/messages/$messageId');
  }

  Future<MessageReactionDto> addReaction(
      String messageId, String emoji) async {
    final json = await _api.post(
      '/messages/messages/$messageId/reactions',
      body: {'emoji': emoji},
    );
    return MessageReactionDto.fromJson(
      Map<String, dynamic>.from(json as Map),
    );
  }

  Future<void> removeReaction(String messageId, String emoji) async {
    await _api.delete(
      '/messages/messages/$messageId/reactions/${Uri.encodeComponent(emoji)}',
    );
  }

  Future<MessageDto> sendMedia(
      String conversationId, String filePath, String fileName) {
    return _api
        .uploadFile(
          '/messages/conversations/$conversationId/media',
          fileField: 'file',
          filePath: filePath,
          fileName: fileName,
        )
        .then((json) =>
            MessageDto.fromJson(Map<String, dynamic>.from(json as Map)));
  }
}
