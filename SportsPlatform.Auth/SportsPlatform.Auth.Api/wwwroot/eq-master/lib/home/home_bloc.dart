import 'package:equatable/equatable.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

import '../addteam/AddTeamModel.dart';
import '../announcement/AnnouncementModel.dart';
import '../services/announcement_service.dart';
import '../services/api_client.dart';
import '../services/team_service.dart';

abstract class HomeEvent extends Equatable {
  @override
  List<Object?> get props => [];
}

class LoadHomeData extends HomeEvent {
  final String? clubId;
  final String? teamId;

  LoadHomeData({this.clubId, this.teamId});

  @override
  List<Object?> get props => [clubId, teamId];
}

class AddTeamEvent extends HomeEvent {
  final Team team;

  AddTeamEvent(this.team);

  @override
  List<Object?> get props => [team];
}

class AddAnnouncementEvent extends HomeEvent {
  final Announcement announcement;
  final String? clubId;
  final String? teamId;

  AddAnnouncementEvent(this.announcement, {this.clubId, this.teamId});

  @override
  List<Object?> get props => [announcement, clubId, teamId];
}

class DeleteAnnouncementEvent extends HomeEvent {
  final String announcementId;
  final String clubId;
  final String teamId;

  DeleteAnnouncementEvent({
    required this.announcementId,
    required this.clubId,
    required this.teamId,
  });

  @override
  List<Object?> get props => [announcementId, clubId, teamId];
}

class UpdateAnnouncementEvent extends HomeEvent {
  final Announcement announcement;
  final String clubId;
  final String teamId;

  UpdateAnnouncementEvent({
    required this.announcement,
    required this.clubId,
    required this.teamId,
  });

  @override
  List<Object?> get props => [announcement, clubId, teamId];
}

class HomeState extends Equatable {
  final List<Team?> teams;
  final List<Announcement> announcements;
  final bool isLoading;
  final bool isSaving;
  final String? error;

  const HomeState({
    this.teams = const [],
    this.announcements = const [],
    this.isLoading = false,
    this.isSaving = false,
    this.error,
  });

  HomeState copyWith({
    List<Team?>? teams,
    List<Announcement>? announcements,
    bool? isLoading,
    bool? isSaving,
    String? error,
    bool clearError = false,
  }) {
    return HomeState(
      teams: teams ?? this.teams,
      announcements: announcements ?? this.announcements,
      isLoading: isLoading ?? this.isLoading,
      isSaving: isSaving ?? this.isSaving,
      error: clearError ? null : error ?? this.error,
    );
  }

  @override
  List<Object?> get props => [teams, announcements, isLoading, isSaving, error];
}

class HomeBloc extends Bloc<HomeEvent, HomeState> {
  final TeamService _teamService = TeamService();
  final AnnouncementService _announcementService = AnnouncementService();

  HomeBloc() : super(const HomeState()) {
    on<LoadHomeData>(_onLoadHomeData);
    on<AddTeamEvent>(_onAddTeam);
    on<AddAnnouncementEvent>(_onAddAnnouncement);
    on<UpdateAnnouncementEvent>(_onUpdateAnnouncement);
    on<DeleteAnnouncementEvent>(_onDeleteAnnouncement);
  }

  Future<void> _onLoadHomeData(
    LoadHomeData event,
    Emitter<HomeState> emit,
  ) async {
    emit(state.copyWith(isLoading: true, clearError: true));
    try {
      final teamDtos = await _teamService.getMyTeams();
      final teams = teamDtos
          .map(
            (team) => Team(
              id: team.teamId,
              clubId: team.clubId,
              country: '',
              club: team.teamName,
              imageUrl: team.imageUrl,
              clubLogoUrl: team.clubLogoUrl,
              sport: 'Basketball',
              category: team.clubName ?? team.categoryName ?? '',
              memberRoles: {'self': team.myRole ?? ''},
            ),
          )
          .cast<Team?>()
          .toList();

      final announcements =
          (event.clubId ?? '').isEmpty || (event.teamId ?? '').isEmpty
          ? <Announcement>[]
          : (await _announcementService.getTeamAnnouncements(
                  event.clubId!,
                  event.teamId!,
                ))
                .map(
                  (a) => Announcement(
                    id: a.announcementId,
                    authorName: a.creatorName.isNotEmpty
                        ? a.creatorName
                        : 'Team announcement',
                    authorRole: a.creatorRole.isNotEmpty
                        ? a.creatorRole
                        : 'Member',
                    authorImage: a.creatorImageUrl ?? '',
                    authorUserId: a.createdBy,
                    imageUrl: a.imageUrl,
                    caption: a.content.isNotEmpty ? a.content : a.title,
                    priority: a.priority,
                  ),
                )
                .toList();

      emit(
        state.copyWith(
          teams: teams,
          announcements: announcements,
          isLoading: false,
        ),
      );
    } on ApiException catch (e) {
      emit(state.copyWith(isLoading: false, error: e.message));
    } catch (_) {
      emit(
        state.copyWith(isLoading: false, error: 'Could not load home data.'),
      );
    }
  }

  void _onAddTeam(AddTeamEvent event, Emitter<HomeState> emit) {
    final newTeams = List<Team?>.from(state.teams)..add(event.team);
    emit(state.copyWith(teams: newTeams));
  }

  Future<void> _onAddAnnouncement(
    AddAnnouncementEvent event,
    Emitter<HomeState> emit,
  ) async {
    if ((event.clubId ?? '').isEmpty || (event.teamId ?? '').isEmpty) {
      emit(
        state.copyWith(error: 'Select a team before posting announcements.'),
      );
      return;
    }
    emit(state.copyWith(isLoading: true, clearError: true));
    try {
      final dto = await _announcementService.createAnnouncement(
        event.clubId!,
        event.teamId!,
        {
          'title': event.announcement.caption.split('\n').first,
          'content': event.announcement.caption,
          if (event.announcement.imageUrl != null)
            'imageUrl': event.announcement.imageUrl,
          'priority': event.announcement.priority,
        },
        imagePath: event.announcement.imagePath,
        imageFileName: event.announcement.imageFileName,
      );
      final created = Announcement(
        id: dto.announcementId,
        authorName: dto.creatorName.isNotEmpty ? dto.creatorName : 'Me',
        authorRole: dto.creatorRole.isNotEmpty
            ? dto.creatorRole
            : event.announcement.authorRole,
        authorImage: dto.creatorImageUrl ?? event.announcement.authorImage,
        authorUserId: dto.createdBy,
        imageUrl: dto.imageUrl,
        caption: dto.content.isNotEmpty ? dto.content : dto.title,
        priority: dto.priority,
      );
      final newAnnouncements = List<Announcement>.from(state.announcements)
        ..insert(0, created);
      emit(state.copyWith(announcements: newAnnouncements, isLoading: false));
    } on ApiException catch (e) {
      emit(state.copyWith(isLoading: false, error: e.message));
    } catch (_) {
      emit(
        state.copyWith(isLoading: false, error: 'Could not post announcement.'),
      );
    }
  }

  Future<void> _onDeleteAnnouncement(
    DeleteAnnouncementEvent event,
    Emitter<HomeState> emit,
  ) async {
    emit(state.copyWith(isLoading: true, clearError: true));
    try {
      await _announcementService.deleteAnnouncement(
        event.clubId,
        event.teamId,
        event.announcementId,
      );
      emit(
        state.copyWith(
          announcements: state.announcements
              .where((a) => a.id != event.announcementId)
              .toList(),
          isLoading: false,
        ),
      );
    } on ApiException catch (e) {
      emit(state.copyWith(isLoading: false, error: e.message));
    } catch (_) {
      emit(
        state.copyWith(
          isLoading: false,
          error: 'Could not delete announcement.',
        ),
      );
    }
  }

  Future<void> _onUpdateAnnouncement(
    UpdateAnnouncementEvent event,
    Emitter<HomeState> emit,
  ) async {
    emit(state.copyWith(isSaving: true, clearError: true));
    try {
      final dto = await _announcementService.updateAnnouncement(
        event.clubId,
        event.teamId,
        event.announcement.id,
        {
          'title': event.announcement.caption.split('\n').first,
          'content': event.announcement.caption,
          if (event.announcement.imageUrl != null)
            'imageUrl': event.announcement.imageUrl,
          'priority': event.announcement.priority,
        },
        imagePath: event.announcement.imagePath,
        imageFileName: event.announcement.imageFileName,
      );
      final updated = event.announcement.copyWith(
        authorName: dto.creatorName.isNotEmpty
            ? dto.creatorName
            : event.announcement.authorName,
        authorRole: dto.creatorRole.isNotEmpty
            ? dto.creatorRole
            : event.announcement.authorRole,
        authorImage: dto.creatorImageUrl ?? event.announcement.authorImage,
        authorUserId: dto.createdBy ?? event.announcement.authorUserId,
        imageUrl: dto.imageUrl,
        clearImageUrl: dto.imageUrl == null,
        caption: dto.content.isNotEmpty ? dto.content : dto.title,
        priority: dto.priority,
      );
      emit(
        state.copyWith(
          announcements: state.announcements
              .map((a) => a.id == updated.id ? updated : a)
              .toList(),
          isSaving: false,
        ),
      );
    } on ApiException catch (e) {
      emit(state.copyWith(isSaving: false, error: e.message));
    } catch (_) {
      emit(
        state.copyWith(
          isSaving: false,
          error: 'Could not update announcement.',
        ),
      );
    }
  }
}
