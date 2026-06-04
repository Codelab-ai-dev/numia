import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../app/router.dart';
import '../../../core/providers.dart';
import '../../../core/supabase_client.dart';
import '../../../core/theme_provider.dart';
import '../../../shared/constants/n_colors.dart';
import '../../../shared/constants/n_spacing.dart';
import '../../../shared/constants/n_typography.dart';
import '../../../shared/widgets/n_badge.dart';
import '../../../shared/widgets/n_button.dart';
import '../../../shared/widgets/n_glass_card.dart';
import '../../../shared/widgets/n_gradient_bg.dart';

class ProfileScreen extends ConsumerWidget {
  const ProfileScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final ct = NColorTheme.of(context);
    final profileAsync = ref.watch(userProfileProvider);

    return Scaffold(
      backgroundColor: ct.bg,
      body: NGradientBg(
        child: SafeArea(
          child: SingleChildScrollView(
            padding: const EdgeInsets.symmetric(horizontal: NSpacing.pageH),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const SizedBox(height: NSpacing.sp5),
                Text('Perfil', style: NTypography.h1.copyWith(color: ct.textPrimary)),
                const SizedBox(height: NSpacing.sp8),

                profileAsync.when(
                  loading: () => _buildLoading(ct),
                  error: (_, __) => _buildError(ct),
                  data: (profile) {
                    if (profile == null) return _buildError(ct);
                    return Column(
                      children: [
                        _ProfileHeader(profile: profile),
                        const SizedBox(height: NSpacing.sp4),
                        _PersonalInfoCard(profile: profile),
                        const SizedBox(height: NSpacing.sp4),
                        const _PreferencesCard(),
                      ],
                    );
                  },
                ),

                const SizedBox(height: NSpacing.sp8),
                const _LogoutButton(),
                const SizedBox(height: NSpacing.sp6),
                Center(
                  child: Text(
                    'Versión 1.0.0',
                    style: NTypography.caption.copyWith(color: ct.textTertiary),
                  ),
                ),
                const SizedBox(height: NSpacing.sp8),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildLoading(NColorTheme ct) {
    return Column(
      children: [
        NGlassCard(
          variant: NGlassVariant.featured,
          child: Center(
            child: Padding(
              padding: const EdgeInsets.symmetric(vertical: NSpacing.sp8),
              child: CircularProgressIndicator(
                strokeWidth: 2,
                color: ct.accent1,
              ),
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildError(NColorTheme ct) {
    return NGlassCard(
      child: Center(
        child: Padding(
          padding: const EdgeInsets.symmetric(vertical: NSpacing.sp6),
          child: Text(
            'No se pudo cargar el perfil',
            style: NTypography.body.copyWith(color: ct.textSecondary),
          ),
        ),
      ),
    );
  }
}

// ─── Profile Header ─────────────────────────────────────────────────────────

class _ProfileHeader extends StatelessWidget {
  const _ProfileHeader({required this.profile});
  final dynamic profile;

  String _initials(String name) {
    final parts = name.trim().split(RegExp(r'\s+'));
    if (parts.isEmpty) return '?';
    if (parts.length == 1) return parts[0][0].toUpperCase();
    return '${parts[0][0]}${parts[parts.length - 1][0]}'.toUpperCase();
  }

  String _planLabel(String plan) {
    final capitalized = plan[0].toUpperCase() + plan.substring(1);
    return 'Plan $capitalized';
  }

  @override
  Widget build(BuildContext context) {
    final ct = NColorTheme.of(context);

    return NGlassCard(
      variant: NGlassVariant.featured,
      child: Column(
        children: [
          Container(
            width: 72,
            height: 72,
            decoration: const BoxDecoration(
              shape: BoxShape.circle,
              gradient: NColors.grad,
              boxShadow: [NColors.glowIndigo],
            ),
            child: Center(
              child: Text(
                _initials(profile.fullName),
                style: NTypography.h1.copyWith(
                  color: Colors.white,
                  fontSize: 26,
                ),
              ),
            ),
          ),
          const SizedBox(height: NSpacing.sp3),
          Text(
            profile.fullName,
            style: NTypography.h2.copyWith(color: ct.textPrimary),
            textAlign: TextAlign.center,
          ),
          const SizedBox(height: NSpacing.sp2),
          NBadge(
            label: _planLabel(profile.plan),
            variant: NBadgeVariant.indigo,
          ),
        ],
      ),
    );
  }
}

// ─── Personal Info Card ─────────────────────────────────────────────────────

class _PersonalInfoCard extends StatelessWidget {
  const _PersonalInfoCard({required this.profile});
  final dynamic profile;

  String _formatDate(DateTime? date) {
    if (date == null) return 'No especificada';
    final d = date.day.toString().padLeft(2, '0');
    final m = date.month.toString().padLeft(2, '0');
    return '$d/$m/${date.year}';
  }

  @override
  Widget build(BuildContext context) {
    final ct = NColorTheme.of(context);

    return NGlassCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Información personal',
            style: NTypography.title.copyWith(color: ct.textPrimary),
          ),
          const SizedBox(height: NSpacing.sp4),
          _InfoRow(
            icon: Icons.public_rounded,
            label: 'País',
            value: profile.country ?? 'No especificado',
            ct: ct,
          ),
          Divider(color: ct.borderSubtle, height: 1),
          _InfoRow(
            icon: Icons.cake_rounded,
            label: 'Fecha de nacimiento',
            value: _formatDate(profile.birthDate),
            ct: ct,
          ),
          Divider(color: ct.borderSubtle, height: 1),
          _InfoRow(
            icon: Icons.work_rounded,
            label: 'Ocupación',
            value: profile.occupation ?? 'No especificada',
            ct: ct,
          ),
        ],
      ),
    );
  }
}

class _InfoRow extends StatelessWidget {
  const _InfoRow({
    required this.icon,
    required this.label,
    required this.value,
    required this.ct,
  });

  final IconData icon;
  final String label;
  final String value;
  final NColorTheme ct;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: NSpacing.sp3),
      child: Row(
        children: [
          Icon(icon, color: ct.accent1, size: 20),
          const SizedBox(width: NSpacing.sp3),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  label,
                  style: NTypography.caption.copyWith(color: ct.textSecondary),
                ),
                const SizedBox(height: 2),
                Text(
                  value,
                  style: NTypography.body.copyWith(color: ct.textPrimary),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

// ─── Preferences Card ───────────────────────────────────────────────────────

class _PreferencesCard extends ConsumerWidget {
  const _PreferencesCard();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final ct = NColorTheme.of(context);
    final themeMode = ref.watch(themeModeProvider);
    final isDark = themeMode == ThemeMode.dark;

    return NGlassCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Preferencias',
            style: NTypography.title.copyWith(color: ct.textPrimary),
          ),
          const SizedBox(height: NSpacing.sp4),
          Row(
            children: [
              Icon(
                isDark ? Icons.dark_mode_rounded : Icons.light_mode_rounded,
                color: isDark ? ct.accent1 : NColors.indigo,
                size: 22,
              ),
              const SizedBox(width: NSpacing.sp3),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Tema oscuro',
                      style: NTypography.title.copyWith(color: ct.textPrimary),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      isDark ? 'Activado' : 'Desactivado',
                      style: NTypography.caption.copyWith(color: ct.textSecondary),
                    ),
                  ],
                ),
              ),
              Switch.adaptive(
                value: isDark,
                activeTrackColor: NColors.indigo,
                onChanged: (_) => ref.read(themeModeProvider.notifier).toggle(),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

// ─── Logout Button ──────────────────────────────────────────────────────────

class _LogoutButton extends ConsumerWidget {
  const _LogoutButton();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return NButton(
      label: 'Cerrar sesión',
      variant: NButtonVariant.danger,
      icon: const Icon(Icons.logout_rounded, size: 18, color: NColors.error),
      onPressed: () => _confirmLogout(context),
    );
  }

  void _confirmLogout(BuildContext context) {
    final ct = NColorTheme.of(context);
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: ct.bg,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(NSpacing.rXl),
          side: BorderSide(color: ct.borderSubtle),
        ),
        title: Text(
          '¿Cerrar sesión?',
          style: NTypography.h2.copyWith(color: ct.textPrimary),
        ),
        content: Text(
          'Tendrás que iniciar sesión de nuevo para acceder a tu cuenta.',
          style: NTypography.body.copyWith(color: ct.textSecondary),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(),
            child: Text(
              'Cancelar',
              style: NTypography.button.copyWith(color: ct.textSecondary),
            ),
          ),
          TextButton(
            onPressed: () async {
              Navigator.of(ctx).pop();
              skipAuth = false;
              await supabase.auth.signOut();
            },
            child: Text(
              'Cerrar sesión',
              style: NTypography.button.copyWith(color: NColors.error),
            ),
          ),
        ],
      ),
    );
  }
}
