import '../models/api_models.dart';
import 'api_client.dart';

class NotificationService {
  NotificationService({ApiClient? apiClient})
    : _api = apiClient ?? ApiClient.instance;

  final ApiClient _api;

  Future<NotificationListDto> getNotifications({
    int page = 1,
    int pageSize = 30,
    bool unreadOnly = false,
  }) async {
    final json = await _api.get(
      '/notifications',
      queryParams: {
        'page': page.toString(),
        'pageSize': pageSize.toString(),
        'unreadOnly': unreadOnly.toString(),
      },
    );
    return NotificationListDto.fromJson(Map<String, dynamic>.from(json as Map));
  }

  Future<int> getUnreadCount() async {
    final json = await _api.get('/notifications/unread-count');
    final map = Map<String, dynamic>.from(json as Map);
    return (map['unreadCount'] as num?)?.toInt() ?? 0;
  }

  Future<void> markRead(String notificationId) =>
      _api.post('/notifications/$notificationId/read');

  Future<void> markAllRead() => _api.post('/notifications/read-all');
}
