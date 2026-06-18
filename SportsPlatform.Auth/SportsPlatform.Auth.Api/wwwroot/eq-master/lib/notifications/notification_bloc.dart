import 'dart:async';

import 'package:equatable/equatable.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

import '../core/design_tokens.dart';
import '../models/api_models.dart';
import '../services/notification_realtime_service.dart';
import '../services/notification_service.dart';

class AppNotification extends Equatable {
  final String id;
  final String title;
  final String subtitle;
  final String message;
  final IconData icon;
  final Color color;
  final DateTime timestamp;
  final List<String> visibleToRoles;
  final bool isRead;
  final String type;
  final String? targetRoute;
  final String? targetType;
  final String? targetId;
  final String? clubId;
  final String? teamId;
  final String? metadataJson;

  const AppNotification({
    required this.id,
    required this.title,
    required this.subtitle,
    this.message = '',
    required this.icon,
    required this.color,
    required this.visibleToRoles,
    this.isRead = false,
    required this.timestamp,
    this.type = '',
    this.targetRoute,
    this.targetType,
    this.targetId,
    this.clubId,
    this.teamId,
    this.metadataJson,
  });

  factory AppNotification.fromDto(AppNotificationDto dto) {
    final visual = _visualFor(dto.type, dto.priority);
    return AppNotification(
      id: dto.notificationId,
      title: dto.title,
      subtitle: dto.teamName ?? dto.actorName ?? dto.type,
      message: dto.body,
      icon: visual.icon,
      color: visual.color,
      visibleToRoles: const ['All'],
      isRead: dto.isRead,
      timestamp: dto.createdAt,
      type: dto.type,
      targetRoute: dto.targetRoute,
      targetType: dto.targetType,
      targetId: dto.targetId,
      clubId: dto.clubId,
      teamId: dto.teamId,
      metadataJson: dto.metadataJson,
    );
  }

  AppNotification copyWith({bool? isRead}) {
    return AppNotification(
      id: id,
      title: title,
      subtitle: subtitle,
      message: message,
      icon: icon,
      color: color,
      visibleToRoles: visibleToRoles,
      isRead: isRead ?? this.isRead,
      timestamp: timestamp,
      type: type,
      targetRoute: targetRoute,
      targetType: targetType,
      targetId: targetId,
      clubId: clubId,
      teamId: teamId,
      metadataJson: metadataJson,
    );
  }

  @override
  List<Object?> get props => [
    id,
    title,
    subtitle,
    message,
    icon,
    color,
    timestamp,
    visibleToRoles,
    isRead,
    type,
    targetRoute,
    targetType,
    targetId,
    clubId,
    teamId,
    metadataJson,
  ];
}

class _NotificationVisual {
  final IconData icon;
  final Color color;

  const _NotificationVisual(this.icon, this.color);
}

_NotificationVisual _visualFor(String type, String priority) {
  final key = type.toLowerCase();
  if (priority.toLowerCase() == 'critical') {
    return const _NotificationVisual(Icons.priority_high_rounded, Colors.red);
  }
  if (key.contains('medical')) {
    return const _NotificationVisual(Icons.medical_services, Colors.red);
  }
  if (key.contains('fitness')) {
    return const _NotificationVisual(Icons.fitness_center, Colors.blue);
  }
  if (key.contains('event')) {
    return const _NotificationVisual(Icons.event, AppColors.primary);
  }
  if (key.contains('announcement')) {
    return const _NotificationVisual(Icons.announcement, Colors.orange);
  }
  if (key.contains('stats')) {
    return const _NotificationVisual(Icons.bar_chart_rounded, Colors.green);
  }
  if (key.contains('plan') || key.contains('lineup')) {
    return const _NotificationVisual(Icons.assignment_rounded, Colors.teal);
  }
  return const _NotificationVisual(Icons.notifications, AppColors.primary);
}

abstract class NotificationEvent extends Equatable {
  const NotificationEvent();

  @override
  List<Object?> get props => [];
}

class LoadNotifications extends NotificationEvent {
  const LoadNotifications();
}

class RefreshUnreadCount extends NotificationEvent {
  const RefreshUnreadCount();
}

class RealtimeNotificationReceived extends NotificationEvent {
  final AppNotificationDto notification;

  const RealtimeNotificationReceived(this.notification);

  @override
  List<Object?> get props => [notification.notificationId];
}

class AddNotification extends NotificationEvent {
  final AppNotification notification;

  const AddNotification(this.notification);

  @override
  List<Object?> get props => [notification];
}

class MarkAllRead extends NotificationEvent {
  final String role;

  const MarkAllRead(this.role);

  @override
  List<Object?> get props => [role];
}

class MarkRead extends NotificationEvent {
  final String id;

  const MarkRead(this.id);

  @override
  List<Object?> get props => [id];
}

class NotificationState extends Equatable {
  final List<AppNotification> notifications;
  final int unreadCount;
  final bool isLoading;
  final String? error;

  const NotificationState({
    this.notifications = const [],
    this.unreadCount = 0,
    this.isLoading = false,
    this.error,
  });

  NotificationState copyWith({
    List<AppNotification>? notifications,
    int? unreadCount,
    bool? isLoading,
    String? error,
  }) {
    return NotificationState(
      notifications: notifications ?? this.notifications,
      unreadCount: unreadCount ?? this.unreadCount,
      isLoading: isLoading ?? this.isLoading,
      error: error,
    );
  }

  List<AppNotification> notificationsForRole(String role) {
    return notifications
        .where(
          (n) =>
              n.visibleToRoles.contains(role) ||
              n.visibleToRoles.contains('All'),
        )
        .toList()
      ..sort((a, b) => b.timestamp.compareTo(a.timestamp));
  }

  int unreadCountForRole(String role) => unreadCount;

  @override
  List<Object?> get props => [notifications, unreadCount, isLoading, error];
}

class NotificationBloc extends Bloc<NotificationEvent, NotificationState> {
  NotificationBloc({
    NotificationService? notificationService,
    NotificationRealtimeService? realtimeService,
  }) : _service = notificationService ?? NotificationService(),
       _realtime = realtimeService ?? NotificationRealtimeService.instance,
       super(const NotificationState()) {
    on<LoadNotifications>(_onLoad);
    on<RefreshUnreadCount>(_onRefreshUnreadCount);
    on<RealtimeNotificationReceived>(_onRealtimeReceived);
    on<AddNotification>(_onAddLocal);
    on<MarkRead>(_onMarkRead);
    on<MarkAllRead>(_onMarkAllRead);

    _realtimeSub = _realtime.notifications.listen(
      (notification) => add(RealtimeNotificationReceived(notification)),
    );
  }

  final NotificationService _service;
  final NotificationRealtimeService _realtime;
  StreamSubscription<AppNotificationDto>? _realtimeSub;

  Future<void> startRealtime() async {
    try {
      await _realtime.connect();
    } catch (_) {}
  }

  Future<void> _onLoad(
    LoadNotifications event,
    Emitter<NotificationState> emit,
  ) async {
    emit(state.copyWith(isLoading: true));
    try {
      final list = await _service.getNotifications();
      emit(
        state.copyWith(
          isLoading: false,
          notifications: list.items.map(AppNotification.fromDto).toList(),
          unreadCount: list.unreadCount,
        ),
      );
    } catch (e) {
      emit(state.copyWith(isLoading: false, error: e.toString()));
    }
  }

  Future<void> _onRefreshUnreadCount(
    RefreshUnreadCount event,
    Emitter<NotificationState> emit,
  ) async {
    try {
      final count = await _service.getUnreadCount();
      emit(state.copyWith(unreadCount: count));
    } catch (_) {}
  }

  void _onRealtimeReceived(
    RealtimeNotificationReceived event,
    Emitter<NotificationState> emit,
  ) {
    final notification = AppNotification.fromDto(event.notification);
    final withoutDuplicate = state.notifications
        .where((n) => n.id != notification.id)
        .toList();
    emit(
      state.copyWith(
        notifications: [notification, ...withoutDuplicate],
        unreadCount: state.unreadCount + (notification.isRead ? 0 : 1),
      ),
    );
  }

  void _onAddLocal(AddNotification event, Emitter<NotificationState> emit) {
    final updated = List<AppNotification>.from(state.notifications)
      ..insert(0, event.notification);
    emit(state.copyWith(notifications: updated));
  }

  Future<void> _onMarkRead(
    MarkRead event,
    Emitter<NotificationState> emit,
  ) async {
    final wasUnread = state.notifications.any((n) => n.id == event.id && !n.isRead);
    final updated = state.notifications
        .map((n) => n.id == event.id ? n.copyWith(isRead: true) : n)
        .toList();
    emit(
      state.copyWith(
        notifications: updated,
        unreadCount: wasUnread
            ? (state.unreadCount - 1).clamp(0, 1 << 31).toInt()
            : state.unreadCount,
      ),
    );
    try {
      await _service.markRead(event.id);
    } catch (_) {
      add(const LoadNotifications());
    }
  }

  Future<void> _onMarkAllRead(
    MarkAllRead event,
    Emitter<NotificationState> emit,
  ) async {
    emit(
      state.copyWith(
        notifications: state.notifications
            .map((n) => n.copyWith(isRead: true))
            .toList(),
        unreadCount: 0,
      ),
    );
    try {
      await _service.markAllRead();
    } catch (_) {
      add(const LoadNotifications());
    }
  }

  @override
  Future<void> close() async {
    await _realtimeSub?.cancel();
    return super.close();
  }
}
