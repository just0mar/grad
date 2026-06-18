import 'package:equatable/equatable.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

import '../models/api_models.dart';
import '../services/api_client.dart';
import '../services/auth_service.dart';

abstract class AuthEvent extends Equatable {
  @override
  List<Object?> get props => [];
}

class LoginRequested extends AuthEvent {
  final String emailOrPhone;
  final String password;

  LoginRequested({required this.emailOrPhone, required this.password, String? role});

  @override
  List<Object?> get props => [emailOrPhone, password];
}

class SignUpRequested extends AuthEvent {
  final String email;
  final String name;
  final String password;
  final String dob;
  final String? phone;
  final String? username;
  final String? bio;

  SignUpRequested({
    required this.email,
    required this.name,
    required this.password,
    required this.dob,
    this.phone,
    this.username,
    this.bio,
    String? role,
    String? age,
  });

  @override
  List<Object?> get props => [email, name, password, dob, phone, username, bio];
}

class GoogleSignInRequested extends AuthEvent {
  final String idToken;

  GoogleSignInRequested({required this.idToken});

  @override
  List<Object?> get props => [idToken];
}

/// Dispatched from CompleteProfileView after the user fills in name + DOB.
class CompleteProfileRequested extends AuthEvent {
  final String name;
  final String dob;
  final String tempToken;

  CompleteProfileRequested({
    required this.name,
    required this.dob,
    required this.tempToken,
  });

  @override
  List<Object?> get props => [name, dob, tempToken];
}

class LogoutRequested extends AuthEvent {}

abstract class AuthState extends Equatable {
  @override
  List<Object?> get props => [];
}

class AuthInitial extends AuthState {}

class AuthLoading extends AuthState {}

class Authenticated extends AuthState {
  final AuthResponse auth;
  final String role;
  final String userId;

  Authenticated({required this.auth})
      : role = auth.user?.email ?? '',
        userId = auth.user?.userId ?? '';

  @override
  List<Object?> get props => [auth, role, userId];
}

/// Emitted when Google sign-in succeeds for a new account that still needs
/// a name and date-of-birth. Carries the temporary JWT so CompleteProfileView
/// can call the backend without a full session.
class ProfileCompletionRequired extends AuthState {
  final AuthResponse auth;

  ProfileCompletionRequired({required this.auth});

  @override
  List<Object?> get props => [auth];
}

class AuthError extends AuthState {
  final String message;

  AuthError(this.message);

  @override
  List<Object?> get props => [message];
}

class AuthBloc extends Bloc<AuthEvent, AuthState> {
  final AuthService _authService = AuthService();

  AuthBloc() : super(AuthInitial()) {
    on<LoginRequested>(_onLoginRequested);
    on<SignUpRequested>(_onSignUpRequested);
    on<GoogleSignInRequested>(_onGoogleSignInRequested);
    on<CompleteProfileRequested>(_onCompleteProfileRequested);
    on<LogoutRequested>((_, emit) => emit(AuthInitial()));
  }

  Future<void> _onLoginRequested(
    LoginRequested event,
    Emitter<AuthState> emit,
  ) async {
    emit(AuthLoading());
    try {
      final auth = await _authService.login(event.emailOrPhone, event.password);
      emit(Authenticated(auth: auth));
    } on ApiException catch (e) {
      emit(AuthError(_friendly(e)));
    } catch (_) {
      emit(AuthError('Network error. Check the backend and try again.'));
    }
  }

  Future<void> _onSignUpRequested(
    SignUpRequested event,
    Emitter<AuthState> emit,
  ) async {
    emit(AuthLoading());
    try {
      final auth = await _authService.register(
        name: event.name,
        email: event.email,
        password: event.password,
        dob: event.dob,
        phone: event.phone,
        username: event.username,
        bio: event.bio,
      );
      emit(Authenticated(auth: auth));
    } on ApiException catch (e) {
      emit(AuthError(_friendly(e)));
    } catch (_) {
      emit(AuthError('Network error. Check the backend and try again.'));
    }
  }

  Future<void> _onGoogleSignInRequested(
    GoogleSignInRequested event,
    Emitter<AuthState> emit,
  ) async {
    emit(AuthLoading());
    try {
      final auth = await _authService.loginWithGoogle(event.idToken);
      if (auth.requiresProfileCompletion) {
        emit(ProfileCompletionRequired(auth: auth));
      } else {
        emit(Authenticated(auth: auth));
      }
    } on ApiException catch (e) {
      emit(AuthError(_friendly(e)));
    } catch (e) {
      emit(AuthError('Google sign-in failed. Please try again.'));
    }
  }

  Future<void> _onCompleteProfileRequested(
    CompleteProfileRequested event,
    Emitter<AuthState> emit,
  ) async {
    emit(AuthLoading());
    try {
      final auth = await _authService.completeGoogleProfile(
        name: event.name,
        dob: event.dob,
        tempToken: event.tempToken,
      );
      emit(Authenticated(auth: auth));
    } on ApiException catch (e) {
      emit(AuthError(_friendly(e)));
    } catch (_) {
      emit(AuthError('Network error. Check the backend and try again.'));
    }
  }

  String _friendly(ApiException e) {
    if (e.isUnauthorized) return 'Invalid credentials.';
    if (e.isForbidden) return 'You do not have permission for this action.';
    if (e.isNotFound) return 'The requested resource was not found.';
    return e.message;
  }
}
