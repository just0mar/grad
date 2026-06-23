import 'package:shared_preferences/shared_preferences.dart';

class PreferencesService {
  static late SharedPreferences _prefs;

  static Future<void> init() async {
    _prefs = await SharedPreferences.getInstance();
  }

  // Theme preference
  static const String _themeKey = 'theme_mode';
  
  static Future<void> setThemeMode(String mode) async {
    await _prefs.setString(_themeKey, mode);
  }

  static String getThemeMode() {
    return _prefs.getString(_themeKey) ?? 'system';
  }

  // Language / locale preference. Stores a language code ('en', 'ar').
  static const String _localeKey = 'locale_code';

  static Future<void> setLocale(String languageCode) async {
    await _prefs.setString(_localeKey, languageCode);
  }

  /// Returns the saved language code, or 'en' when nothing has been chosen yet.
  static String getLocale() {
    return _prefs.getString(_localeKey) ?? 'en';
  }

  // Auth/Session preference (example)
  static const String _isLoggedInKey = 'is_logged_in';
  
  static Future<void> setLoggedIn(bool value) async {
    await _prefs.setBool(_isLoggedInKey, value);
  }

  static bool isLoggedIn() {
    return _prefs.getBool(_isLoggedInKey) ?? false;
  }

  // Generic methods
  static Future<void> clear() async {
    await _prefs.clear();
  }

  // Onboarding preference
  static const String _hasSeenOnboardingKey = 'has_seen_onboarding';

  static Future<void> setHasSeenOnboarding(bool value) async {
    await _prefs.setBool(_hasSeenOnboardingKey, value);
  }

  static bool hasSeenOnboarding() {
    return _prefs.getBool(_hasSeenOnboardingKey) ?? false;
  }

  // Pending Invite Token
  static const String _pendingInviteTokenKey = 'pending_invite_token';

  static Future<void> savePendingInviteToken(String token) async {
    await _prefs.setString(_pendingInviteTokenKey, token);
  }

  static String? getPendingInviteToken() {
    return _prefs.getString(_pendingInviteTokenKey);
  }

  static Future<void> clearPendingInviteToken() async {
    await _prefs.remove(_pendingInviteTokenKey);
  }
}
