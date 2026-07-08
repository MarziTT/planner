import 'package:dio/dio.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/network/api_client.dart';
import '../domain/profile_model.dart';

final profileRepositoryProvider = Provider<ProfileRepository>((ref) {
  return ProfileRepository(ref.watch(apiClientProvider));
});

class ProfileRepository {
  ProfileRepository(this._dio);

  final Dio _dio;

  Future<UserProfile> fetchProfile() async {
    final response = await _dio.get('/profile');
    return UserProfile.fromJson(Map<String, dynamic>.from(response.data['data']['item'] as Map));
  }

  Future<UserProfile> saveProfile(UserProfile profile) async {
    final response = await _dio.put('/profile', data: profile.toJson());
    return UserProfile.fromJson(Map<String, dynamic>.from(response.data['data']['item'] as Map));
  }
}
