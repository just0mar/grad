import 'dart:io';

import 'package:equatable/equatable.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

import '../models/api_models.dart';
import '../services/api_client.dart';
import '../services/club_service.dart';
import '../location/location_point.dart';

abstract class AddClubEvent extends Equatable {
  @override
  List<Object?> get props => [];
}

class ClubNameChanged extends AddClubEvent {
  final String clubName;
  ClubNameChanged(this.clubName);

  @override
  List<Object?> get props => [clubName];
}

class ClubLogoSelected extends AddClubEvent {
  final File logoFile;
  ClubLogoSelected(this.logoFile);

  @override
  List<Object?> get props => [logoFile.path];
}

class SubmitCreateClub extends AddClubEvent {}

class ClubEstablishedDateChanged extends AddClubEvent {
  final String date;
  ClubEstablishedDateChanged(this.date);

  @override
  List<Object?> get props => [date];
}

class ClubLocationChanged extends AddClubEvent {
  final String location;
  ClubLocationChanged(this.location);

  @override
  List<Object?> get props => [location];
}

class ClubLocationPointChanged extends AddClubEvent {
  final LocationPoint? point;
  ClubLocationPointChanged(this.point);

  @override
  List<Object?> get props => [point?.latitude, point?.longitude, point?.label];
}

class AddClubState extends Equatable {
  final String clubName;
  final File? logoFile;
  final String establishedDate;
  final String location;
  final double? locationLatitude;
  final double? locationLongitude;
  final bool isSubmitting;
  final String? error;
  final ClubDto? createdClub;

  const AddClubState({
    this.clubName = '',
    this.logoFile,
    this.establishedDate = '',
    this.location = '',
    this.locationLatitude,
    this.locationLongitude,
    this.isSubmitting = false,
    this.error,
    this.createdClub,
  });

  AddClubState copyWith({
    String? clubName,
    File? logoFile,
    String? establishedDate,
    String? location,
    double? locationLatitude,
    double? locationLongitude,
    bool? isSubmitting,
    String? error,
    ClubDto? createdClub,
    bool clearError = false,
  }) {
    return AddClubState(
      clubName: clubName ?? this.clubName,
      logoFile: logoFile ?? this.logoFile,
      establishedDate: establishedDate ?? this.establishedDate,
      location: location ?? this.location,
      locationLatitude: locationLatitude ?? this.locationLatitude,
      locationLongitude: locationLongitude ?? this.locationLongitude,
      isSubmitting: isSubmitting ?? this.isSubmitting,
      error: clearError ? null : error ?? this.error,
      createdClub: createdClub ?? this.createdClub,
    );
  }

  @override
  List<Object?> get props => [
        clubName,
        logoFile?.path,
        establishedDate,
        location,
        locationLatitude,
        locationLongitude,
        isSubmitting,
        error,
        createdClub,
      ];
}

class AddClubBloc extends Bloc<AddClubEvent, AddClubState> {
  final ClubService _clubService = ClubService();

  AddClubBloc() : super(const AddClubState()) {
    on<ClubNameChanged>((event, emit) {
      emit(state.copyWith(clubName: event.clubName, clearError: true));
    });
    on<ClubLogoSelected>((event, emit) {
      emit(state.copyWith(logoFile: event.logoFile, clearError: true));
    });
    on<ClubEstablishedDateChanged>((event, emit) {
      emit(state.copyWith(establishedDate: event.date, clearError: true));
    });
    on<ClubLocationChanged>((event, emit) {
      emit(state.copyWith(location: event.location, clearError: true));
    });
    on<ClubLocationPointChanged>((event, emit) {
      final point = event.point;
      emit(state.copyWith(
        location: point?.label ?? state.location,
        locationLatitude: point?.latitude,
        locationLongitude: point?.longitude,
        clearError: true,
      ));
    });
    on<SubmitCreateClub>(_onSubmit);
  }

  Future<void> _onSubmit(
    SubmitCreateClub event,
    Emitter<AddClubState> emit,
  ) async {
    final name = state.clubName.trim();
    if (name.isEmpty) {
      emit(state.copyWith(error: 'Club name is required'));
      return;
    }
    if (name.length > 200) {
      emit(state.copyWith(error: 'Club name must be 200 characters or less'));
      return;
    }
    if (state.logoFile == null) {
      emit(state.copyWith(error: 'Club logo is required'));
      return;
    }

    emit(state.copyWith(isSubmitting: true, clearError: true));
    try {
      final club = await _clubService.createClub(
        name,
        logo: state.logoFile,
        location: state.location,
        locationLatitude: state.locationLatitude,
        locationLongitude: state.locationLongitude,
      );
      emit(state.copyWith(isSubmitting: false, createdClub: club));
    } on ApiException catch (e) {
      emit(state.copyWith(isSubmitting: false, error: e.message));
    } catch (_) {
      emit(state.copyWith(
        isSubmitting: false,
        error: 'Could not create club. Please try again.',
      ));
    }
  }
}
