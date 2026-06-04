import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:google_fonts/google_fonts.dart';
import '../../../app/router.dart' show skipAuth;
import '../../../core/supabase_client.dart';
import '../../../shared/constants/n_colors.dart';
import '../../../shared/constants/n_spacing.dart';
import '../../../shared/constants/n_typography.dart';
import '../../../shared/widgets/n_button.dart';
import '../../../shared/widgets/n_gradient_bg.dart';
import '../../../shared/widgets/n_gradient_text.dart';

class LoginScreen extends StatefulWidget {
  const LoginScreen({super.key});

  @override
  State<LoginScreen> createState() => _LoginScreenState();
}

class _LoginScreenState extends State<LoginScreen> {
  final _emailCtrl = TextEditingController();
  final _passCtrl = TextEditingController();
  final _formKey = GlobalKey<FormState>();
  bool _isLoading = false;
  bool _obscurePass = true;
  String? _errorMsg;

  @override
  void dispose() {
    _emailCtrl.dispose();
    _passCtrl.dispose();
    super.dispose();
  }

  Future<void> _handleLogin() async {
    setState(() => _errorMsg = null);
    if (!_formKey.currentState!.validate()) return;

    setState(() => _isLoading = true);

    try {
      await supabase.auth.signInWithPassword(
        email: _emailCtrl.text.trim(),
        password: _passCtrl.text,
      );
      if (mounted) context.go('/');
    } catch (e) {
      if (mounted) {
        setState(() {
          _errorMsg = _parseError(e.toString());
        });
      }
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  String _parseError(String raw) {
    if (raw.contains('Invalid login credentials')) {
      return 'Correo o contraseña incorrectos';
    }
    if (raw.contains('Email not confirmed')) {
      return 'Confirma tu correo antes de iniciar sesión';
    }
    if (raw.contains('network')) {
      return 'Sin conexión a internet';
    }
    return 'Error al iniciar sesión. Intenta de nuevo.';
  }

  @override
  Widget build(BuildContext context) {
    final ct = NColorTheme.of(context);

    return Scaffold(
      backgroundColor: ct.bg,
      body: NGradientBg(
        child: SafeArea(
          child: Center(
            child: SingleChildScrollView(
              padding: const EdgeInsets.symmetric(horizontal: NSpacing.pageH),
              child: Form(
                key: _formKey,
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const SizedBox(height: NSpacing.sp16),

                    // Logo
                    NGradientText('numia', style: NTypography.h1),
                    const SizedBox(height: NSpacing.sp2),
                    Text(
                      'Tu inteligencia financiera personal',
                      style: NTypography.body.copyWith(color: ct.textSecondary),
                    ),

                    const SizedBox(height: NSpacing.sp12),

                    // Error banner
                    if (_errorMsg != null) ...[
                      Container(
                        width: double.infinity,
                        padding: const EdgeInsets.all(NSpacing.sp3),
                        decoration: BoxDecoration(
                          color: NColors.errorSoft,
                          borderRadius: BorderRadius.circular(NSpacing.rSm),
                          border: Border.all(color: NColors.error.withValues(alpha: 0.3)),
                        ),
                        child: Row(
                          children: [
                            const Icon(Icons.error_outline, color: NColors.error, size: 18),
                            const SizedBox(width: NSpacing.sp2),
                            Expanded(
                              child: Text(
                                _errorMsg!,
                                style: NTypography.caption.copyWith(color: NColors.error),
                              ),
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(height: NSpacing.sp5),
                    ],

                    // Email field
                    Text('CORREO', style: NTypography.overline.copyWith(color: ct.textTertiary)),
                    const SizedBox(height: NSpacing.sp2),
                    TextFormField(
                      controller: _emailCtrl,
                      keyboardType: TextInputType.emailAddress,
                      autocorrect: false,
                      style: GoogleFonts.plusJakartaSans(
                        color: ct.textPrimary,
                        fontSize: 15,
                      ),
                      decoration: InputDecoration(
                        hintText: 'tu@correo.com',
                        prefixIcon: Icon(Icons.mail_outline, size: 20, color: ct.textTertiary),
                      ),
                      validator: (v) {
                        if (v == null || v.trim().isEmpty) return 'Ingresa tu correo';
                        if (!v.contains('@') || !v.contains('.')) return 'Correo inválido';
                        return null;
                      },
                    ),

                    const SizedBox(height: NSpacing.sp5),

                    // Password field
                    Text('CONTRASEÑA', style: NTypography.overline.copyWith(color: ct.textTertiary)),
                    const SizedBox(height: NSpacing.sp2),
                    TextFormField(
                      controller: _passCtrl,
                      obscureText: _obscurePass,
                      style: GoogleFonts.plusJakartaSans(
                        color: ct.textPrimary,
                        fontSize: 15,
                      ),
                      decoration: InputDecoration(
                        hintText: '\u2022\u2022\u2022\u2022\u2022\u2022\u2022\u2022',
                        prefixIcon: Icon(Icons.lock_outline, size: 20, color: ct.textTertiary),
                        suffixIcon: GestureDetector(
                          onTap: () => setState(() => _obscurePass = !_obscurePass),
                          child: Icon(
                            _obscurePass ? Icons.visibility_off_outlined : Icons.visibility_outlined,
                            size: 20,
                            color: ct.textTertiary,
                          ),
                        ),
                      ),
                      validator: (v) {
                        if (v == null || v.isEmpty) return 'Ingresa tu contraseña';
                        if (v.length < 6) return 'Mínimo 6 caracteres';
                        return null;
                      },
                    ),

                    const SizedBox(height: NSpacing.sp8),

                    // Login button
                    NButton(
                      label: 'Iniciar sesión',
                      onPressed: _isLoading ? null : _handleLogin,
                      isLoading: _isLoading,
                    ),

                    const SizedBox(height: NSpacing.sp3),

                    // Register button
                    NButton(
                      label: 'Crear cuenta',
                      variant: NButtonVariant.secondary,
                      onPressed: () => context.go('/register'),
                    ),

                    const SizedBox(height: NSpacing.sp8),

                    // Divider
                    Row(
                      children: [
                        Expanded(child: Divider(color: ct.borderSubtle)),
                        Padding(
                          padding: const EdgeInsets.symmetric(horizontal: NSpacing.sp4),
                          child: Text('o', style: NTypography.caption.copyWith(color: ct.textSecondary)),
                        ),
                        Expanded(child: Divider(color: ct.borderSubtle)),
                      ],
                    ),

                    const SizedBox(height: NSpacing.sp8),

                    // Skip auth
                    Center(
                      child: GestureDetector(
                        onTap: () {
                          skipAuth = true;
                          context.go('/');
                        },
                        child: Text(
                          'Explorar sin cuenta',
                          style: NTypography.caption.copyWith(
                            color: ct.textTertiary,
                            decoration: TextDecoration.underline,
                            decorationColor: ct.textTertiary,
                          ),
                        ),
                      ),
                    ),

                    const SizedBox(height: NSpacing.sp10),
                  ],
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}
