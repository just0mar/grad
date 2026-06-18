import 'dart:io';

import '../models/api_models.dart';
import 'api_client.dart';

class UserService {
  final ApiClient _api = ApiClient.instance;

  Future<UserInfo> updateProfile({
    String? name,
    String? username,
    String? bio,
    String? dob,
    String? phoneNumber,
    int? yearsOfExperience,
  }) async {
    final body = <String, dynamic>{};
    if (name != null) body['name'] = name;
    if (username != null) body['username'] = username;
    if (bio != null) body['bio'] = bio;
    if (dob != null) body['dob'] = dob;
    if (phoneNumber != null) body['phoneNumber'] = phoneNumber;
    if (yearsOfExperience != null) body['yearsOfExperience'] = yearsOfExperience;

    final json = await _api.put('/users/me', body: body);
    return UserInfo.fromJson(Map<String, dynamic>.from(json as Map));
  }

  Future<String> uploadProfileImage(File image) async {
    final json = await _api.uploadFile(
      '/users/me/profile-image',
      fileField: 'image',
      filePath: image.path,
      fileName: image.uri.pathSegments.isEmpty
          ? 'profile-image'
          : image.uri.pathSegments.last,
    );

    if (json is Map && json['profileImageUrl'] != null) {
      return json['profileImageUrl'].toString();
    }

    throw const ApiException(500, 'Profile image upload failed.');
  }
}
