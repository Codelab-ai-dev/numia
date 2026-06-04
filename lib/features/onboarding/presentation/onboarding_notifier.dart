import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../core/providers.dart';
import '../domain/onboarding_state.dart';

final onboardingProvider =
    StateNotifierProvider.autoDispose<OnboardingNotifier, OnboardingState>(
  (ref) => OnboardingNotifier(ref),
);

class OnboardingNotifier extends StateNotifier<OnboardingState> {
  OnboardingNotifier(this._ref) : super(const OnboardingState());
  final Ref _ref;

  void nextPage(PageController controller) {
    if (state.currentPage >= 3) return;
    final next = state.currentPage + 1;
    controller.animateToPage(
      next,
      duration: const Duration(milliseconds: 400),
      curve: Curves.easeInOutCubic,
    );
    state = state.copyWith(currentPage: next);
  }

  void previousPage(PageController controller) {
    if (state.currentPage <= 0) return;
    final prev = state.currentPage - 1;
    controller.animateToPage(
      prev,
      duration: const Duration(milliseconds: 400),
      curve: Curves.easeInOutCubic,
    );
    state = state.copyWith(currentPage: prev);
  }

  void setFullName(String value) =>
      state = state.copyWith(fullName: value, clearError: true);

  void setCountry(String value) =>
      state = state.copyWith(country: value);

  void setBirthDate(DateTime? value) => state = value == null
      ? state.copyWith(clearBirthDate: true)
      : state.copyWith(birthDate: value);

  void setOccupation(String value) =>
      state = state.copyWith(occupation: value);

  bool get isStep3Valid => state.fullName.trim().length >= 2;

  Future<void> completeOnboarding() async {
    if (!isStep3Valid) return;
    state = state.copyWith(isSubmitting: true, clearError: true);
    try {
      await _ref.read(userRepositoryProvider).completeOnboarding(
            fullName: state.fullName.trim(),
            country: state.country,
            birthDate: state.birthDate,
            occupation:
                state.occupation.trim().isEmpty ? null : state.occupation.trim(),
          );
      _ref.invalidate(userProfileProvider);
    } catch (e, st) {
      debugPrint('completeOnboarding error: $e\n$st');
      state = state.copyWith(
        isSubmitting: false,
        errorMessage: 'Error al completar el registro: $e',
      );
    }
  }
}
