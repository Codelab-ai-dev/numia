import 'package:dio/dio.dart';
import '../../../core/api_client.dart';
import '../domain/auth_models.dart';

class UserRepository {
  UserRepository(this._client);
  final ApiClient _client;

  Future<UserProfile?> getProfile() async {
    try {
      final response = await _client.dio.get('/api/v1/users/me');
      return UserProfile.fromJson(response.data as Map<String, dynamic>);
    } on DioException catch (e) {
      if (e.response?.statusCode == 401) return null;
      rethrow;
    }
  }

  Future<void> updateProfile({
    String? fullName,
    String? avatarUrl,
  }) async {
    final updates = <String, dynamic>{};
    if (fullName != null) updates['full_name'] = fullName;
    if (avatarUrl != null) updates['avatar_url'] = avatarUrl;
    if (updates.isEmpty) return;

    await _client.dio.put('/api/v1/users/me', data: updates);
  }

  Future<void> completeOnboarding({
    required String fullName,
    String country = 'MX',
    DateTime? birthDate,
    String? occupation,
  }) async {
    await _client.dio.post('/api/v1/users/onboarding', data: {
      'full_name': fullName,
      'country': country,
      'birth_date': birthDate?.toIso8601String().split('T').first,
      'occupation': occupation,
    });
  }
}
