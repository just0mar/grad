import '../models/api_models.dart';
import 'api_client.dart';

class AuthService {
  final ApiClient _api = ApiClient.instance;

  Future<AuthResponse> login(String emailOrPhone, String password) async {
    final json = await _api.post('/auth/login', body: {
      'emailOrPhone': emailOrPhone,
      'password': password,
    });
    return AuthResponse.fromJson(Map<String, dynamic>.from(json as Map));
  }

  Future<AuthResponse> register({
    required String name,
    required String email,
    required String password,
    required String dob,
    String? phone,
    String? username,
    String? bio,
  }) async {
    final json = await _api.post('/auth/register', body: {
      'name': name,
      'email': email,
      'password': password,
      'dob': dob,
      if (phone != null && phone.isNotEmpty) 'phoneNumber': phone,
      if (username != null && username.isNotEmpty) 'username': username,
      if (bio != null && bio.isNotEmpty) 'bio': bio,
    });
    return AuthResponse.fromJson(Map<String, dynamic>.from(json as Map));
  }

  Future<AuthResponse> loginWithGoogle(String idToken) async {
    final json = await _api.post('/auth/google/mobile', body: {
      'idToken': idToken,
    });
    return AuthResponse.fromJson(Map<String, dynamic>.from(json as Map));
  }

  /// Completes the Google sign-up profile for new accounts.
  /// Uses [tempToken], the temporary JWT returned with RequiresProfileCompletion.
  Future<AuthResponse> completeGoogleProfile({
    required String name,
    required String dob,
    required String tempToken,
  }) async {
    final json = await _api.postWithBearer(
      '/auth/complete-google-profile',
      tempToken,
      body: {'name': name, 'dob': dob},
    );
    return AuthResponse.fromJson(Map<String, dynamic>.from(json as Map));
  }

  Future<void> logout(String refreshToken) async {
    await _api.post('/auth/logout', body: {'refreshToken': refreshToken});
  }

  /// Step 1 - request a password reset. The server emails a 6-digit OTP.
  /// Always succeeds (the server doesn't reveal if the email exists).
  Future<void> forgotPassword(String email) async {
    await _api.post('/auth/forgot-password', body: {'email': email});
  }

  /// Step 2 - verify the OTP before showing the new-password form.
  Future<void> verifyResetCode(String email, String code) async {
    await _api.post('/auth/verify-reset-code',
        body: {'email': email, 'code': code});
  }

  /// Step 3 - set a new password using the OTP [code].
  Future<void> resetPassword({
    required String email,
    required String newPassword,
    required String code,
  }) async {
    await _api.post('/auth/reset-password', body: {
      'email': email,
      'newPassword': newPassword,
      'code': code,
    });
  }
}
