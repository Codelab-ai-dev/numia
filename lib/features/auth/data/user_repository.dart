import 'package:supabase_flutter/supabase_flutter.dart';
import '../domain/auth_models.dart';

class UserRepository {
  UserRepository(this._client);
  final SupabaseClient _client;

  Future<UserProfile?> getProfile() async {
    final uid = _client.auth.currentUser?.id;
    if (uid == null) return null;

    final data = await _client
        .from('users')
        .select()
        .eq('id', uid)
        .maybeSingle();

    if (data == null) return null;
    return UserProfile.fromJson(data);
  }

  Future<void> updateProfile({
    String? fullName,
    String? avatarUrl,
  }) async {
    final uid = _client.auth.currentUser!.id;
    final updates = <String, dynamic>{};
    if (fullName != null) updates['full_name'] = fullName;
    if (avatarUrl != null) updates['avatar_url'] = avatarUrl;
    if (updates.isEmpty) return;

    await _client.from('users').update(updates).eq('id', uid);
  }

  Future<void> completeOnboarding({
    required String fullName,
    String country = 'MX',
    DateTime? birthDate,
    String? occupation,
  }) async {
    await _client.rpc('complete_onboarding', params: {
      'p_full_name': fullName,
      'p_country': country,
      'p_birth_date': birthDate?.toIso8601String().split('T').first,
      'p_occupation': occupation,
    });
  }
}
