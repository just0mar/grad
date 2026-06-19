import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:equatable/equatable.dart';
import 'app_localizations.dart';
import 'preferences_service.dart';

// Events
abstract class AppEvent extends Equatable {
  @override
  List<Object?> get props => [];
}

class ThemeChanged extends AppEvent {
  final ThemeMode themeMode;
  ThemeChanged(this.themeMode);
  @override
  List<Object?> get props => [themeMode];
}

/// Dispatched when the user picks a language. [languageCode] is 'en' or 'ar'.
class LocaleChanged extends AppEvent {
  final String languageCode;
  LocaleChanged(this.languageCode);
  @override
  List<Object?> get props => [languageCode];
}

class AppStarted extends AppEvent {}

// State
class AppState extends Equatable {
  final ThemeMode themeMode;
  final Locale locale;
  final bool isInitialized;

  const AppState({
    this.themeMode = ThemeMode.system,
    this.locale = const Locale('en'),
    this.isInitialized = false,
  });

  AppState copyWith({
    ThemeMode? themeMode,
    Locale? locale,
    bool? isInitialized,
  }) {
    return AppState(
      themeMode: themeMode ?? this.themeMode,
      locale: locale ?? this.locale,
      isInitialized: isInitialized ?? this.isInitialized,
    );
  }

  @override
  List<Object?> get props => [themeMode, locale, isInitialized];
}

// Bloc
class AppBloc extends Bloc<AppEvent, AppState> {
  AppBloc() : super(const AppState()) {
    on<AppStarted>(_onAppStarted);
    on<ThemeChanged>(_onThemeChanged);
    on<LocaleChanged>(_onLocaleChanged);
  }

  Future<void> _onAppStarted(AppStarted event, Emitter<AppState> emit) async {
    final themeStr = PreferencesService.getThemeMode();
    ThemeMode mode;
    switch (themeStr) {
      case 'light':
        mode = ThemeMode.light;
        break;
      case 'dark':
        mode = ThemeMode.dark;
        break;
      default:
        mode = ThemeMode.system;
    }
    final locale = AppLocalizations.localeForCode(PreferencesService.getLocale());
    emit(state.copyWith(
      themeMode: mode,
      locale: locale,
      isInitialized: true,
    ));
  }

  Future<void> _onThemeChanged(ThemeChanged event, Emitter<AppState> emit) async {
    final modeStr = event.themeMode.toString().split('.').last;
    await PreferencesService.setThemeMode(modeStr);
    emit(state.copyWith(themeMode: event.themeMode));
  }

  Future<void> _onLocaleChanged(
      LocaleChanged event, Emitter<AppState> emit) async {
    await PreferencesService.setLocale(event.languageCode);
    emit(state.copyWith(
      locale: AppLocalizations.localeForCode(event.languageCode),
    ));
  }
}
