import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:equatable/equatable.dart';
import '../models/api_models.dart';
import '../services/club_service.dart';
import '../services/team_service.dart';
import 'AddTeamModel.dart';

// Events
abstract class AddTeamEvent extends Equatable {
  @override
  List<Object?> get props => [];
}

class CountryChanged extends AddTeamEvent {
  final String? country;
  CountryChanged(this.country);
  @override
  List<Object?> get props => [country];
}

class ClubChanged extends AddTeamEvent {
  final String? club;
  ClubChanged(this.club);
  @override
  List<Object?> get props => [club];
}

class SportChanged extends AddTeamEvent {
  final String? sport;
  SportChanged(this.sport);
  @override
  List<Object?> get props => [sport];
}

class CategoryChanged extends AddTeamEvent {
  final String? category;
  CategoryChanged(this.category);
  @override
  List<Object?> get props => [category];
}

class LoadAddTeamOptions extends AddTeamEvent {}

// State
class AddTeamState extends Equatable {
  final String? selectedCountry;
  final String? selectedClub;
  final String? selectedSport;
  final String? selectedCategory;
  final List<ClubDto> clubOptions;
  final List<TeamCategoryDto> categoryOptions;
  final bool isLoading;
  final String? error;

  final List<String> countries = const ['Egypt', 'USA', 'Spain'];
  List<String> get clubs => clubOptions.map((club) => club.name).toList();
  final List<String> sports = const ['Basketball', 'Football', 'Volleyball'];
  List<String> get categories =>
      categoryOptions.map((category) => category.name).toList();

  const AddTeamState({
    this.selectedCountry,
    this.selectedClub,
    this.selectedSport,
    this.selectedCategory,
    this.clubOptions = const [],
    this.categoryOptions = const [],
    this.isLoading = false,
    this.error,
  });

  AddTeamState copyWith({
    String? selectedCountry,
    String? selectedClub,
    String? selectedSport,
    String? selectedCategory,
    List<ClubDto>? clubOptions,
    List<TeamCategoryDto>? categoryOptions,
    bool? isLoading,
    String? error,
    bool clearError = false,
  }) {
    return AddTeamState(
      selectedCountry: selectedCountry ?? this.selectedCountry,
      selectedClub: selectedClub ?? this.selectedClub,
      selectedSport: selectedSport ?? this.selectedSport,
      selectedCategory: selectedCategory ?? this.selectedCategory,
      clubOptions: clubOptions ?? this.clubOptions,
      categoryOptions: categoryOptions ?? this.categoryOptions,
      isLoading: isLoading ?? this.isLoading,
      error: clearError ? null : error ?? this.error,
    );
  }

  Team buildTeam() {
    return Team(
      country: selectedCountry ?? 'Unknown',
      club: selectedClub ?? 'Unknown',
      sport: selectedSport ?? 'Unknown',
      category: selectedCategory ?? 'Unknown',
    );
  }

  ClubDto? get selectedClubDto {
    for (final club in clubOptions) {
      if (club.name == selectedClub) return club;
    }
    return null;
  }

  TeamCategoryDto? get selectedCategoryDto {
    for (final category in categoryOptions) {
      if (category.name == selectedCategory) return category;
    }
    return null;
  }

  @override
  List<Object?> get props => [
        selectedCountry,
        selectedClub,
        selectedSport,
        selectedCategory,
        clubOptions,
        categoryOptions,
        isLoading,
        error,
      ];
}

// Bloc
class AddTeamBloc extends Bloc<AddTeamEvent, AddTeamState> {
  final ClubService _clubService = ClubService();
  final TeamService _teamService = TeamService();

  AddTeamBloc() : super(const AddTeamState()) {
    on<LoadAddTeamOptions>(_onLoadAddTeamOptions);
    on<CountryChanged>((event, emit) => emit(state.copyWith(selectedCountry: event.country)));
    on<ClubChanged>((event, emit) => emit(state.copyWith(selectedClub: event.club)));
    on<SportChanged>((event, emit) => emit(state.copyWith(selectedSport: event.sport)));
    on<CategoryChanged>((event, emit) => emit(state.copyWith(selectedCategory: event.category)));
  }

  Future<void> _onLoadAddTeamOptions(
    LoadAddTeamOptions event,
    Emitter<AddTeamState> emit,
  ) async {
    emit(state.copyWith(isLoading: true, clearError: true));
    try {
      final clubs = await _clubService.getMyClubs();
      final categories = await _teamService.getCategories();
      emit(state.copyWith(
        clubOptions: clubs,
        categoryOptions: categories,
        selectedClub: clubs.isEmpty ? state.selectedClub : clubs.first.name,
        selectedCategory:
            categories.isEmpty ? state.selectedCategory : categories.first.name,
        isLoading: false,
      ));
    } catch (_) {
      emit(state.copyWith(
        isLoading: false,
        error: 'Could not load club and category options.',
      ));
    }
  }
}
