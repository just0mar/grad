import 'dart:async';
import 'package:app_links/app_links.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import '../session/session_bloc.dart';
import 'preferences_service.dart';
import '../navigation/MainNavigation.dart';
import '../core/app_transitions.dart';
import '../jointeam/JoinTeamView.dart';
import '../main.dart' show MyApp;

class DeepLinkService {
  static final DeepLinkService _instance = DeepLinkService._internal();
  factory DeepLinkService() => _instance;
  DeepLinkService._internal();

  final _appLinks = AppLinks();
  StreamSubscription<Uri>? _sub;

  void init() {
    // Check initial deep link if the app was launched from one
    _appLinks.getInitialLink().then((uri) {
      if (uri != null) {
        _handleDeepLink(uri);
      }
    });

    // Listen to deep links while the app is running
    _sub = _appLinks.uriLinkStream.listen((Uri? uri) {
      if (uri != null) {
        _handleDeepLink(uri);
      }
    }, onError: (err) {
      debugPrint("Deep link error: \$err");
    });
  }

  void _handleDeepLink(Uri uri) {
    if (uri.path == '/invite' && uri.queryParameters.containsKey('token')) {
      final token = uri.queryParameters['token']!;
      
      final context = MyApp.navigatorKey.currentContext;
      if (context == null) {
        // App isn't fully booted yet (no navigator), save it for later.
        PreferencesService.savePendingInviteToken(token);
        return;
      }
      
      final sessionState = context.read<SessionBloc>().state;
      if (sessionState.status == SessionStatus.authenticated) {
        // We are logged in, so route immediately to invitations view
        PreferencesService.clearPendingInviteToken();
        Navigator.pushAndRemoveUntil(
          context,
          AppFadeRoute(
            child: MainNavigation(
              userRole: sessionState.currentRole ?? '',
              userId: sessionState.user?.userId ?? '',
            ),
            settings: const RouteSettings(name: '/'),
          ),
          (_) => false,
        );
        Navigator.push(
          context,
          AppFadeRoute(child: const JoinTeamView()),
        );
      } else {
        // Not authenticated, just save it. 
        // When they finish Login/SignUp, MainNavigation will be launched and can handle it.
        PreferencesService.savePendingInviteToken(token);
      }
    }
  }

  void dispose() {
    _sub?.cancel();
  }
}
