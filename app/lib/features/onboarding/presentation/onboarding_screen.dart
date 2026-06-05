import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../shared/constants/n_colors.dart';
import '../../../shared/constants/n_spacing.dart';
import '../../../shared/constants/n_typography.dart';
import '../../../shared/widgets/n_badge.dart';
import '../../../shared/widgets/n_button.dart';
import '../../../shared/widgets/n_glass_card.dart';
import '../../../shared/widgets/n_gradient_bg.dart';
import '../../../shared/widgets/n_gradient_text.dart';
import 'onboarding_notifier.dart';

class OnboardingScreen extends ConsumerStatefulWidget {
  const OnboardingScreen({super.key});

  @override
  ConsumerState<OnboardingScreen> createState() => _OnboardingScreenState();
}

class _OnboardingScreenState extends ConsumerState<OnboardingScreen> {
  late final PageController _pageController;

  @override
  void initState() {
    super.initState();
    _pageController = PageController();
  }

  @override
  void dispose() {
    _pageController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final state = ref.watch(onboardingProvider);
    final notifier = ref.read(onboardingProvider.notifier);
    final ct = NColorTheme.of(context);

    return Scaffold(
      backgroundColor: ct.bg,
      body: NGradientBg(
        child: SafeArea(
          child: Column(
            children: [
              // Header with dots and back button
              _OnboardingHeader(
                currentPage: state.currentPage,
                onBack: state.currentPage > 0
                    ? () => notifier.previousPage(_pageController)
                    : null,
              ),

              // Pages
              Expanded(
                child: PageView(
                  controller: _pageController,
                  physics: const NeverScrollableScrollPhysics(),
                  children: const [
                    _WelcomePage(),
                    _ValuePropPage(
                      icon: Icons.psychology_rounded,
                      gradientColors: [NColors.indigo, NColors.emerald],
                      glow: NColors.glowIndigo,
                      title: 'Coach financiero con IA',
                      description:
                          'Un asistente inteligente que analiza tus finanzas y te guía hacia mejores decisiones.',
                      badge: NBadge(
                        label: 'Inteligencia Artificial',
                        variant: NBadgeVariant.indigo,
                      ),
                      features: [
                        'Análisis automático de tus gastos',
                        'Recomendaciones personalizadas',
                        'Chat natural con tu coach',
                      ],
                    ),
                    _ValuePropPage(
                      icon: Icons.account_balance_wallet_rounded,
                      gradientColors: [NColors.emerald, NColors.amber],
                      glow: NColors.glowEmerald,
                      title: 'Control total de tus finanzas',
                      description:
                          'Todo lo que necesitas para manejar tu dinero en un solo lugar.',
                      badge: NBadge(
                        label: 'Todo en uno',
                        variant: NBadgeVariant.emerald,
                      ),
                      features: [
                        'Cuentas y deudas organizadas',
                        'Seguimiento de metas financieras',
                        'Análisis por categorías',
                      ],
                    ),
                    _ProfileFormPage(),
                  ],
                ),
              ),

              // Footer button
              _OnboardingFooter(
                currentPage: state.currentPage,
                isSubmitting: state.isSubmitting,
                isStep3Valid: notifier.isStep3Valid,
                onNext: () => notifier.nextPage(_pageController),
                onComplete: () => notifier.completeOnboarding(),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

// ─── Header ──────────────────────────────────────────────────

class _OnboardingHeader extends StatelessWidget {
  const _OnboardingHeader({required this.currentPage, this.onBack});
  final int currentPage;
  final VoidCallback? onBack;

  @override
  Widget build(BuildContext context) {
    final ct = NColorTheme.of(context);
    return Padding(
      padding: const EdgeInsets.symmetric(
        horizontal: NSpacing.pageH,
        vertical: NSpacing.sp3,
      ),
      child: Row(
        children: [
          // Back button or spacer
          SizedBox(
            width: 40,
            child: onBack != null
                ? IconButton(
                    icon: Icon(Icons.arrow_back_rounded, color: ct.textPrimary),
                    onPressed: onBack,
                    padding: EdgeInsets.zero,
                    constraints: const BoxConstraints(),
                  )
                : null,
          ),
          // Page dots centered
          Expanded(
            child: Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: List.generate(4, (i) {
                final isActive = i == currentPage;
                return AnimatedContainer(
                  duration: const Duration(milliseconds: 300),
                  curve: Curves.easeInOut,
                  margin: const EdgeInsets.symmetric(horizontal: 3),
                  width: isActive ? 24 : 8,
                  height: 8,
                  decoration: BoxDecoration(
                    borderRadius: BorderRadius.circular(4),
                    gradient: isActive ? NColors.gradH : null,
                    color: isActive ? null : ct.borderDefault,
                  ),
                );
              }),
            ),
          ),
          // Spacer to balance back button
          const SizedBox(width: 40),
        ],
      ),
    );
  }
}

// ─── Footer ──────────────────────────────────────────────────

class _OnboardingFooter extends StatelessWidget {
  const _OnboardingFooter({
    required this.currentPage,
    required this.isSubmitting,
    required this.isStep3Valid,
    required this.onNext,
    required this.onComplete,
  });

  final int currentPage;
  final bool isSubmitting;
  final bool isStep3Valid;
  final VoidCallback onNext;
  final VoidCallback onComplete;

  @override
  Widget build(BuildContext context) {
    final isLastPage = currentPage == 3;
    final disabled = isLastPage && !isStep3Valid;

    return Padding(
      padding: const EdgeInsets.fromLTRB(
        NSpacing.pageH,
        NSpacing.sp3,
        NSpacing.pageH,
        NSpacing.sp4,
      ),
      child: NButton(
        label: isLastPage ? 'Completar' : 'Siguiente',
        onPressed: disabled ? null : (isLastPage ? onComplete : onNext),
        isLoading: isSubmitting,
      ),
    );
  }
}

// ─── Page 0: Welcome ─────────────────────────────────────────

class _WelcomePage extends StatelessWidget {
  const _WelcomePage();

  @override
  Widget build(BuildContext context) {
    final ct = NColorTheme.of(context);
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: NSpacing.pageH),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Container(
            width: 100,
            height: 100,
            decoration: const BoxDecoration(
              gradient: NColors.grad,
              shape: BoxShape.circle,
              boxShadow: [NColors.glowIndigo],
            ),
            child: const Icon(
              Icons.auto_awesome_rounded,
              color: Colors.white,
              size: 44,
            ),
          ),
          const SizedBox(height: NSpacing.sp8),
          NGradientText('Bienvenido a numia', style: NTypography.h1),
          const SizedBox(height: NSpacing.sp3),
          Text(
            'Tu coach financiero personal\nimpulsado por inteligencia artificial',
            style: NTypography.body.copyWith(color: ct.textSecondary),
            textAlign: TextAlign.center,
          ),
        ],
      ),
    );
  }
}

// ─── Pages 1-2: Value Props ──────────────────────────────────

class _ValuePropPage extends StatelessWidget {
  const _ValuePropPage({
    required this.icon,
    required this.gradientColors,
    required this.glow,
    required this.title,
    required this.description,
    required this.badge,
    required this.features,
  });

  final IconData icon;
  final List<Color> gradientColors;
  final BoxShadow glow;
  final String title;
  final String description;
  final Widget badge;
  final List<String> features;

  @override
  Widget build(BuildContext context) {
    final ct = NColorTheme.of(context);
    return SingleChildScrollView(
      padding: const EdgeInsets.symmetric(horizontal: NSpacing.pageH),
      child: Column(
        children: [
          const SizedBox(height: NSpacing.sp8),
          // Featured card with icon
          NGlassCard(
            variant: NGlassVariant.featured,
            child: Column(
              children: [
                Container(
                  width: 72,
                  height: 72,
                  decoration: BoxDecoration(
                    gradient: LinearGradient(
                      begin: Alignment.topLeft,
                      end: Alignment.bottomRight,
                      colors: gradientColors,
                    ),
                    shape: BoxShape.circle,
                    boxShadow: [glow],
                  ),
                  child: Icon(icon, color: Colors.white, size: 36),
                ),
                const SizedBox(height: NSpacing.sp4),
                badge,
                const SizedBox(height: NSpacing.sp3),
                Text(
                  title,
                  style: NTypography.h2.copyWith(color: ct.textPrimary),
                  textAlign: TextAlign.center,
                ),
                const SizedBox(height: NSpacing.sp2),
                Text(
                  description,
                  style: NTypography.body.copyWith(color: ct.textSecondary),
                  textAlign: TextAlign.center,
                ),
              ],
            ),
          ),
          const SizedBox(height: NSpacing.sp4),
          // Features list card
          NGlassCard(
            child: Column(
              children: features.map((f) {
                return Padding(
                  padding: const EdgeInsets.symmetric(vertical: NSpacing.sp2),
                  child: Row(
                    children: [
                      Container(
                        width: 28,
                        height: 28,
                        decoration: BoxDecoration(
                          color: gradientColors.first.withValues(alpha: 0.15),
                          borderRadius: BorderRadius.circular(NSpacing.rSm),
                        ),
                        child: Icon(
                          Icons.check_rounded,
                          color: gradientColors.first,
                          size: 16,
                        ),
                      ),
                      const SizedBox(width: NSpacing.sp3),
                      Expanded(
                        child: Text(
                          f,
                          style: NTypography.body.copyWith(
                            color: ct.textPrimary,
                          ),
                        ),
                      ),
                    ],
                  ),
                );
              }).toList(),
            ),
          ),
          const SizedBox(height: NSpacing.sp8),
        ],
      ),
    );
  }
}

// ─── Page 3: Profile Form ────────────────────────────────────

class _ProfileFormPage extends ConsumerStatefulWidget {
  const _ProfileFormPage();

  @override
  ConsumerState<_ProfileFormPage> createState() => _ProfileFormPageState();
}

class _ProfileFormPageState extends ConsumerState<_ProfileFormPage> {
  late final TextEditingController _nameController;
  late final TextEditingController _occupationController;

  @override
  void initState() {
    super.initState();
    final state = ref.read(onboardingProvider);
    _nameController = TextEditingController(text: state.fullName);
    _occupationController = TextEditingController(text: state.occupation);
  }

  @override
  void dispose() {
    _nameController.dispose();
    _occupationController.dispose();
    super.dispose();
  }

  static const _countries = {
    'MX': 'Mexico',
    'US': 'Estados Unidos',
    'ES': 'Espana',
    'CO': 'Colombia',
    'AR': 'Argentina',
    'CL': 'Chile',
    'PE': 'Peru',
    'VE': 'Venezuela',
    'EC': 'Ecuador',
    'GT': 'Guatemala',
  };

  @override
  Widget build(BuildContext context) {
    final ct = NColorTheme.of(context);
    final state = ref.watch(onboardingProvider);
    final notifier = ref.read(onboardingProvider.notifier);

    return SingleChildScrollView(
      padding: const EdgeInsets.symmetric(horizontal: NSpacing.pageH),
      keyboardDismissBehavior: ScrollViewKeyboardDismissBehavior.onDrag,
      child: Column(
        children: [
          const SizedBox(height: NSpacing.sp4),
          // Header card
          NGlassCard(
            variant: NGlassVariant.featured,
            child: Column(
              children: [
                Container(
                  width: 56,
                  height: 56,
                  decoration: BoxDecoration(
                    color: NColors.indigo.withValues(alpha: 0.15),
                    shape: BoxShape.circle,
                  ),
                  child: const Icon(
                    Icons.person_rounded,
                    color: NColors.indigo,
                    size: 28,
                  ),
                ),
                const SizedBox(height: NSpacing.sp3),
                Text(
                  'Cuentanos sobre ti',
                  style: NTypography.h2.copyWith(color: ct.textPrimary),
                  textAlign: TextAlign.center,
                ),
                const SizedBox(height: NSpacing.sp1),
                Text(
                  'Esta informacion nos ayuda a personalizar tu experiencia.',
                  style: NTypography.caption.copyWith(color: ct.textSecondary),
                  textAlign: TextAlign.center,
                ),
              ],
            ),
          ),
          const SizedBox(height: NSpacing.sp4),

          // Form card
          NGlassCard(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Full name
                Text(
                  'Nombre completo *',
                  style: NTypography.caption.copyWith(color: ct.textSecondary),
                ),
                const SizedBox(height: NSpacing.sp2),
                TextFormField(
                  controller: _nameController,
                  onChanged: notifier.setFullName,
                  textCapitalization: TextCapitalization.words,
                  style: NTypography.body.copyWith(color: ct.textPrimary),
                  decoration: _inputDecoration(ct, 'Tu nombre'),
                ),
                const SizedBox(height: NSpacing.sp5),

                // Country
                Text(
                  'Pais',
                  style: NTypography.caption.copyWith(color: ct.textSecondary),
                ),
                const SizedBox(height: NSpacing.sp2),
                DropdownButtonFormField<String>(
                  initialValue: state.country,
                  onChanged: (v) {
                    if (v != null) notifier.setCountry(v);
                  },
                  items: _countries.entries
                      .map(
                        (e) => DropdownMenuItem(
                          value: e.key,
                          child: Text(e.value),
                        ),
                      )
                      .toList(),
                  style: NTypography.body.copyWith(color: ct.textPrimary),
                  dropdownColor: ct.bg,
                  decoration: _inputDecoration(ct, null),
                ),
                const SizedBox(height: NSpacing.sp5),

                // Birth date
                Text(
                  'Fecha de nacimiento (opcional)',
                  style: NTypography.caption.copyWith(color: ct.textSecondary),
                ),
                const SizedBox(height: NSpacing.sp2),
                GestureDetector(
                  onTap: () => _pickDate(context, notifier, state.birthDate),
                  child: AbsorbPointer(
                    child: TextFormField(
                      controller: TextEditingController(
                        text: state.birthDate != null
                            ? '${state.birthDate!.day.toString().padLeft(2, '0')}/${state.birthDate!.month.toString().padLeft(2, '0')}/${state.birthDate!.year}'
                            : '',
                      ),
                      style: NTypography.body.copyWith(color: ct.textPrimary),
                      decoration: _inputDecoration(ct, 'DD/MM/AAAA').copyWith(
                        suffixIcon: Icon(
                          Icons.calendar_today_rounded,
                          color: ct.textTertiary,
                          size: 20,
                        ),
                      ),
                    ),
                  ),
                ),
                const SizedBox(height: NSpacing.sp5),

                // Occupation
                Text(
                  'Ocupacion (opcional)',
                  style: NTypography.caption.copyWith(color: ct.textSecondary),
                ),
                const SizedBox(height: NSpacing.sp2),
                TextFormField(
                  controller: _occupationController,
                  onChanged: notifier.setOccupation,
                  textCapitalization: TextCapitalization.sentences,
                  style: NTypography.body.copyWith(color: ct.textPrimary),
                  decoration: _inputDecoration(ct, 'Ej: Ingeniero, Estudiante'),
                ),
              ],
            ),
          ),
          const SizedBox(height: NSpacing.sp3),

          // Error banner
          AnimatedSwitcher(
            duration: const Duration(milliseconds: 300),
            child: state.errorMessage != null
                ? Container(
                    key: const ValueKey('error'),
                    width: double.infinity,
                    padding: const EdgeInsets.all(NSpacing.sp3),
                    decoration: BoxDecoration(
                      color: NColors.errorSoft,
                      borderRadius: BorderRadius.circular(NSpacing.rMd),
                      border: Border.all(color: NColors.error.withValues(alpha: 0.3)),
                    ),
                    child: Row(
                      children: [
                        const Icon(Icons.error_outline_rounded,
                            color: NColors.error, size: 20),
                        const SizedBox(width: NSpacing.sp2),
                        Expanded(
                          child: Text(
                            state.errorMessage!,
                            style: NTypography.caption
                                .copyWith(color: NColors.error),
                          ),
                        ),
                      ],
                    ),
                  )
                : const SizedBox.shrink(key: ValueKey('no-error')),
          ),
          const SizedBox(height: NSpacing.sp8),
        ],
      ),
    );
  }

  InputDecoration _inputDecoration(NColorTheme ct, String? hint) {
    return InputDecoration(
      hintText: hint,
      hintStyle: NTypography.body.copyWith(color: ct.textTertiary),
      filled: true,
      fillColor: ct.surface2,
      border: OutlineInputBorder(
        borderRadius: BorderRadius.circular(NSpacing.rMd),
        borderSide: BorderSide(color: ct.borderDefault),
      ),
      enabledBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(NSpacing.rMd),
        borderSide: BorderSide(color: ct.borderDefault),
      ),
      focusedBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(NSpacing.rMd),
        borderSide: const BorderSide(color: NColors.indigo, width: 1.5),
      ),
      contentPadding: const EdgeInsets.symmetric(
        horizontal: NSpacing.sp4,
        vertical: NSpacing.sp3,
      ),
    );
  }

  Future<void> _pickDate(
    BuildContext context,
    OnboardingNotifier notifier,
    DateTime? current,
  ) async {
    final now = DateTime.now();
    final maxDate = DateTime(now.year - 13, now.month, now.day);
    final picked = await showDatePicker(
      context: context,
      initialDate: current ?? maxDate,
      firstDate: DateTime(1920),
      lastDate: maxDate,
      builder: (context, child) {
        return Theme(
          data: Theme.of(context).copyWith(
            colorScheme: Theme.of(context).colorScheme.copyWith(
                  primary: NColors.indigo,
                  onPrimary: Colors.white,
                ),
          ),
          child: child!,
        );
      },
    );
    if (picked != null) {
      notifier.setBirthDate(picked);
    }
  }
}
