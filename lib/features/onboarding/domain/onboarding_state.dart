class OnboardingState {
  final int currentPage;
  final String fullName;
  final String country;
  final DateTime? birthDate;
  final String occupation;
  final bool isSubmitting;
  final String? errorMessage;

  const OnboardingState({
    this.currentPage = 0,
    this.fullName = '',
    this.country = 'MX',
    this.birthDate,
    this.occupation = '',
    this.isSubmitting = false,
    this.errorMessage,
  });

  OnboardingState copyWith({
    int? currentPage,
    String? fullName,
    String? country,
    DateTime? birthDate,
    bool clearBirthDate = false,
    String? occupation,
    bool? isSubmitting,
    String? errorMessage,
    bool clearError = false,
  }) {
    return OnboardingState(
      currentPage: currentPage ?? this.currentPage,
      fullName: fullName ?? this.fullName,
      country: country ?? this.country,
      birthDate: clearBirthDate ? null : (birthDate ?? this.birthDate),
      occupation: occupation ?? this.occupation,
      isSubmitting: isSubmitting ?? this.isSubmitting,
      errorMessage: clearError ? null : (errorMessage ?? this.errorMessage),
    );
  }
}
