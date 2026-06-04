import 'package:equatable/equatable.dart';

class UserProfile extends Equatable {
  final String id;
  final String fullName;
  final String country;
  final DateTime? birthDate;
  final String? occupation;
  final bool onboardingDone;
  final String plan;
  final DateTime? planExpiresAt;
  final String? avatarUrl;
  final DateTime createdAt;
  final DateTime updatedAt;

  const UserProfile({
    required this.id,
    required this.fullName,
    this.country = 'MX',
    this.birthDate,
    this.occupation,
    this.onboardingDone = false,
    this.plan = 'free',
    this.planExpiresAt,
    this.avatarUrl,
    required this.createdAt,
    required this.updatedAt,
  });

  factory UserProfile.fromJson(Map<String, dynamic> json) {
    return UserProfile(
      id: json['id'] as String,
      fullName: json['full_name'] as String,
      country: json['country'] as String? ?? 'MX',
      birthDate: json['birth_date'] != null
          ? DateTime.parse(json['birth_date'] as String)
          : null,
      occupation: json['occupation'] as String?,
      onboardingDone: json['onboarding_done'] as bool? ?? false,
      plan: json['plan'] as String? ?? 'free',
      planExpiresAt: json['plan_expires_at'] != null
          ? DateTime.parse(json['plan_expires_at'] as String)
          : null,
      avatarUrl: json['avatar_url'] as String?,
      createdAt: DateTime.parse(json['created_at'] as String),
      updatedAt: DateTime.parse(json['updated_at'] as String),
    );
  }

  Map<String, dynamic> toJson() => {
        'id': id,
        'full_name': fullName,
        'country': country,
        'birth_date': birthDate?.toIso8601String(),
        'occupation': occupation,
        'onboarding_done': onboardingDone,
        'plan': plan,
        'plan_expires_at': planExpiresAt?.toIso8601String(),
        'avatar_url': avatarUrl,
      };

  @override
  List<Object?> get props => [id, fullName, onboardingDone, plan];
}
