import 'dart:async';

import 'package:equatable/equatable.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

import '../models/api_models.dart';
import '../services/search_service.dart';

abstract class SearchEvent extends Equatable {
  const SearchEvent();

  @override
  List<Object?> get props => [];
}

class UpdateQuery extends SearchEvent {
  final String query;

  const UpdateQuery(this.query);

  @override
  List<Object?> get props => [query];
}

class UpdateTab extends SearchEvent {
  final String tab;

  const UpdateTab(this.tab);

  @override
  List<Object?> get props => [tab];
}

class SearchState extends Equatable {
  final String selectedTab;
  final String query;
  final List<SearchResultDto> results;
  final bool isLoading;
  final String? error;
  final int totalCount;

  const SearchState({
    this.selectedTab = 'All',
    this.query = '',
    this.results = const [],
    this.isLoading = false,
    this.error,
    this.totalCount = 0,
  });

  SearchState copyWith({
    String? selectedTab,
    String? query,
    List<SearchResultDto>? results,
    bool? isLoading,
    String? error,
    int? totalCount,
  }) {
    return SearchState(
      selectedTab: selectedTab ?? this.selectedTab,
      query: query ?? this.query,
      results: results ?? this.results,
      isLoading: isLoading ?? this.isLoading,
      error: error,
      totalCount: totalCount ?? this.totalCount,
    );
  }

  @override
  List<Object?> get props => [
    selectedTab,
    query,
    results,
    isLoading,
    error,
    totalCount,
  ];
}

class SearchBloc extends Bloc<SearchEvent, SearchState> {
  SearchBloc({SearchService? searchService})
    : _service = searchService ?? SearchService(),
      super(const SearchState()) {
    on<UpdateQuery>(_onQuery);
    on<UpdateTab>(_onTab);
  }

  final SearchService _service;
  Timer? _debounce;

  Future<void> _onQuery(UpdateQuery event, Emitter<SearchState> emit) async {
    _debounce?.cancel();
    emit(state.copyWith(query: event.query));
    final query = event.query.trim();
    if (query.length < 2) {
      emit(state.copyWith(results: const [], totalCount: 0, isLoading: false));
      return;
    }

    await Future<void>.delayed(const Duration(milliseconds: 280));
    if (query != state.query.trim()) return;
    await _runSearch(emit, query, state.selectedTab);
  }

  Future<void> _onTab(UpdateTab event, Emitter<SearchState> emit) async {
    emit(state.copyWith(selectedTab: event.tab));
    final query = state.query.trim();
    if (query.length >= 2) {
      await _runSearch(emit, query, event.tab);
    }
  }

  Future<void> _runSearch(
    Emitter<SearchState> emit,
    String query,
    String tab,
  ) async {
    emit(state.copyWith(isLoading: true));
    try {
      final response = await _service.search(
        query: query,
        type: _typeForTab(tab),
      );
      emit(
        state.copyWith(
          isLoading: false,
          results: response.results,
          totalCount: response.totalCount,
        ),
      );
    } catch (e) {
      emit(state.copyWith(isLoading: false, error: e.toString()));
    }
  }

  static String _typeForTab(String tab) {
    switch (tab) {
      case 'Teams':
        return 'teams';
      case 'Users':
        return 'users';
      case 'Events':
        return 'events';
      case 'Plans':
        return 'plans';
      case 'Announcements':
        return 'announcements';
      case 'Stats':
        return 'stats';
      default:
        return 'all';
    }
  }

  @override
  Future<void> close() {
    _debounce?.cancel();
    return super.close();
  }
}
