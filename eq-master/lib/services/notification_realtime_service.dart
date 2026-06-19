import 'dart:async';

import 'package:signalr_netcore/signalr_client.dart';

import '../config/app_config.dart';
import '../models/api_models.dart';
import 'api_client.dart';

class NotificationRealtimeService {
  NotificationRealtimeService._();
  static final NotificationRealtimeService instance =
      NotificationRealtimeService._();

  HubConnection? _connection;
  StreamController<AppNotificationDto>? _controller;

  Stream<AppNotificationDto> get notifications {
    _controller ??= StreamController<AppNotificationDto>.broadcast();
    return _controller!.stream;
  }

  Future<void> connect() async {
    final token = await ApiClient.instance.accessToken;
    if (token == null || token.isEmpty) return;

    if (_connection?.state == HubConnectionState.Connected ||
        _connection?.state == HubConnectionState.Connecting) {
      return;
    }

    final hubUrl = '${AppConfig.baseUrl}/hubs/notifications';
    final connection = HubConnectionBuilder()
        .withUrl(
          hubUrl,
          options: HttpConnectionOptions(
            accessTokenFactory: () async =>
                await ApiClient.instance.accessToken ?? '',
          ),
        )
        .withAutomaticReconnect()
        .build();

    connection.on('notificationReceived', (args) {
      if (args == null || args.isEmpty || args.first is! Map) return;
      final notification = AppNotificationDto.fromJson(
        Map<String, dynamic>.from(args.first as Map),
      );
      _controller?.add(notification);
    });

    _connection = connection;
    await connection.start();
  }

  Future<void> disconnect() async {
    await _connection?.stop();
    _connection = null;
  }
}
