import 'package:flutter/material.dart';

import '../models/api_models.dart';

class Event {
  final String eventId;
  final String teamId;
  final String seasonId;
  final String type;
  final DateTime date;
  final TimeOfDay time;
  final String description;
  final String? location;
  final double? locationLatitude;
  final double? locationLongitude;
  final String? recurrenceRule;
  final DateTime? recurrenceEndDate;

  Event({
    this.eventId = '',
    this.teamId = '',
    this.seasonId = '',
    required this.type,
    required this.date,
    required this.time,
    required this.description,
    this.location,
    this.locationLatitude,
    this.locationLongitude,
    this.recurrenceRule,
    this.recurrenceEndDate,
  });

  factory Event.fromDto(EventDto dto) {
    return Event(
      eventId: dto.eventId,
      teamId: dto.teamId,
      seasonId: dto.seasonId,
      type: dto.eventType,
      date: dto.startAt,
      time: TimeOfDay(hour: dto.startAt.hour, minute: dto.startAt.minute),
      description: dto.description?.isNotEmpty == true
          ? dto.description!
          : dto.title,
      location: dto.location,
      locationLatitude: dto.locationLatitude,
      locationLongitude: dto.locationLongitude,
      recurrenceRule: dto.recurrenceRule,
      recurrenceEndDate: dto.recurrenceEndDate,
    );
  }
}
