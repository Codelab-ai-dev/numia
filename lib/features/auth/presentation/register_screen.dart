import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:google_fonts/google_fonts.dart';
import '../../../core/supabase_client.dart';
import '../../../shared/constants/n_colors.dart';
import '../../../shared/constants/n_spacing.dart';
import '../../../shared/constants/n_typography.dart';
import '../../../shared/widgets/n_button.dart';
import '../../../shared/widgets/n_gradient_bg.dart';

class RegisterScreen extends StatefulWidget {
  const RegisterScreen({super.key});

  @override
  State<RegisterScreen> createState() => _RegisterScreenState();
}

class _RegisterScreenState extends State<RegisterScreen> {
  final _emailCtrl = TextEditingController();
  final _passCtrl = TextEditingController();
  final _confirmCtrl = TextEditingController();
  final _formKey = GlobalKey<FormState>();
  bool _isLoading = false;
  bool _obscurePass = true;
  bool _obscureConfirm = true;
  String? _errorMsg;
  bool _success = false;

  @override
  void dispose() {
    _emailCtrl.dispose();
    _passCtrl.dispose();
    _confirmCtrl.dispose();
    super.dispose();
  }

  Future<void> _handleRegister() async {
    setState(() => _errorMsg = null);
    if (!_formKey.currentState!.validate()) return;

    setState(() => _isLoading = true);

    try {
      final res = await supabase.auth.signUp(
        email: _emailCtrl.text.trim(),
        password: _passCtrl.text,
      );

      if (!mounted) return;

      if (res.session != null) {
        context.go('/');
      } else {
        setState(() => _success = true);
      }
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
    if (raw.contains('already registered') || raw.contains('already exists')) {
      return 'Ya existe una cuenta con ese correo';
    }
    if (raw.contains('valid email')) {
      return 'Ingresa un correo válido';
    }
    if (raw.contains('password')) {
      return 'La contraseña debe tener al menos 6 caracteres';
    }
    if (raw.contains('network')) {
      return 'Sin conexión a internet';
    }
    return 'Error al crear cuenta. Intenta de nuevo.';
  }

  @override
  Widget build(BuildContext context) {
    if (_success) return _buildSuccessView();

    final ct = NColorTheme.of(context);

    return Scaffold(
      backgroundColor: ct.bg,
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        leading: IconButton(
          icon: Icon(Icons.arrow_back, color: ct.textPrimary),
          onPressed: () => context.go('/login'),
        ),
      ),
      extendBodyBehindAppBar: true,
      body: NGradientBg(
        child: SafeArea(
          child: SingleChildScrollView(
            padding: const EdgeInsets.symmetric(horizontal: NSpacing.pageH),
            child: Form(
              key: _formKey,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const SizedBox(height: NSpacing.sp6),

                  // Header
                  Text('Crea tu cuenta', style: NTypography.h2.copyWith(color: ct.textPrimary)),
                  const SizedBox(height: NSpacing.sp2),
                  Text(
                    'Comienza a tomar el control de tus finanzas',
                    style: NTypography.body.copyWith(color: ct.textSecondary),
                  ),

                  const SizedBox(height: NSpacing.sp10),

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

                  // Email
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

                  // Password
                  Text('CONTRASEÑA', style: NTypography.overline.copyWith(color: ct.textTertiary)),
                  const SizedBox(height: NSpacing.sp2),
                  TextFormField(
                    controller: _passCtrl,
                    obscureText: _obscurePass,
                    onChanged: (_) => setState(() {}),
                    style: GoogleFonts.plusJakartaSans(
                      color: ct.textPrimary,
                      fontSize: 15,
                    ),
                    decoration: InputDecoration(
                      hintText: 'Mínimo 6 caracteres',
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
                      if (v == null || v.isEmpty) return 'Ingresa una contraseña';
                      if (v.length < 6) return 'Mínimo 6 caracteres';
                      return null;
                    },
                  ),

                  const SizedBox(height: NSpacing.sp5),

                  // Confirm password
                  Text('CONFIRMAR CONTRASEÑA', style: NTypography.overline.copyWith(color: ct.textTertiary)),
                  const SizedBox(height: NSpacing.sp2),
                  TextFormField(
                    controller: _confirmCtrl,
                    obscureText: _obscureConfirm,
                    style: GoogleFonts.plusJakartaSans(
                      color: ct.textPrimary,
                      fontSize: 15,
                    ),
                    decoration: InputDecoration(
                      hintText: 'Repite tu contraseña',
                      prefixIcon: Icon(Icons.lock_outline, size: 20, color: ct.textTertiary),
                      suffixIcon: GestureDetector(
                        onTap: () => setState(() => _obscureConfirm = !_obscureConfirm),
                        child: Icon(
                          _obscureConfirm ? Icons.visibility_off_outlined : Icons.visibility_outlined,
                          size: 20,
                          color: ct.textTertiary,
                        ),
                      ),
                    ),
                    validator: (v) {
                      if (v == null || v.isEmpty) return 'Confirma tu contraseña';
                      if (v != _passCtrl.text) return 'Las contraseñas no coinciden';
                      return null;
                    },
                  ),

                  const SizedBox(height: NSpacing.sp8),

                  // Password strength hints
                  _PasswordHints(password: _passCtrl.text),

                  const SizedBox(height: NSpacing.sp8),

                  // Register button
                  NButton(
                    label: 'Crear cuenta',
                    onPressed: _isLoading ? null : _handleRegister,
                    isLoading: _isLoading,
                  ),

                  const SizedBox(height: NSpacing.sp5),

                  // Back to login
                  Center(
                    child: GestureDetector(
                      onTap: () => context.go('/login'),
                      child: Text.rich(
                        TextSpan(
                          text: '¿Ya tienes cuenta? ',
                          style: NTypography.caption.copyWith(color: ct.textSecondary),
                          children: [
                            TextSpan(
                              text: 'Inicia sesión',
                              style: NTypography.caption.copyWith(
                                color: ct.accent1,
                                fontWeight: FontWeight.w600,
                              ),
                            ),
                          ],
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
    );
  }

  Widget _buildSuccessView() {
    final ct = NColorTheme.of(context);

    return Scaffold(
      backgroundColor: ct.bg,
      body: NGradientBg(
        child: SafeArea(
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: NSpacing.pageH),
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Container(
                  width: 72,
                  height: 72,
                  decoration: BoxDecoration(
                    color: NColors.successSoft,
                    shape: BoxShape.circle,
                    border: Border.all(color: NColors.success.withValues(alpha: 0.3)),
                  ),
                  child: const Icon(Icons.mark_email_read_outlined, color: NColors.success, size: 32),
                ),
                const SizedBox(height: NSpacing.sp6),
                Text(
                  'Revisa tu correo',
                  style: NTypography.h2.copyWith(color: ct.textPrimary),
                  textAlign: TextAlign.center,
                ),
                const SizedBox(height: NSpacing.sp3),
                Text(
                  'Enviamos un enlace de confirmación a',
                  style: NTypography.body.copyWith(color: ct.textSecondary),
                  textAlign: TextAlign.center,
                ),
                const SizedBox(height: NSpacing.sp1),
                Text(
                  _emailCtrl.text.trim(),
                  style: NTypography.title.copyWith(color: ct.accent1),
                  textAlign: TextAlign.center,
                ),
                const SizedBox(height: NSpacing.sp3),
                Text(
                  'Confirma tu correo y luego inicia sesión',
                  style: NTypography.caption.copyWith(color: ct.textSecondary),
                  textAlign: TextAlign.center,
                ),
                const SizedBox(height: NSpacing.sp10),
                NButton(
                  label: 'Ir a iniciar sesión',
                  onPressed: () => context.go('/login'),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

/// Password strength indicator
class _PasswordHints extends StatefulWidget {
  const _PasswordHints({required this.password});
  final String password;

  @override
  State<_PasswordHints> createState() => _PasswordHintsState();
}

class _PasswordHintsState extends State<_PasswordHints> {
  @override
  Widget build(BuildContext context) {
    final ct = NColorTheme.of(context);

    return Column(
      children: [
        _hint('Al menos 6 caracteres', widget.password.length >= 6, ct),
        const SizedBox(height: NSpacing.sp1),
        _hint('Contiene un número', widget.password.contains(RegExp(r'[0-9]')), ct),
        const SizedBox(height: NSpacing.sp1),
        _hint('Contiene una mayúscula', widget.password.contains(RegExp(r'[A-Z]')), ct),
      ],
    );
  }

  Widget _hint(String label, bool met, NColorTheme ct) {
    return Row(
      children: [
        Icon(
          met ? Icons.check_circle : Icons.circle_outlined,
          size: 14,
          color: met ? NColors.success : ct.textTertiary,
        ),
        const SizedBox(width: NSpacing.sp2),
        Text(
          label,
          style: NTypography.caption.copyWith(
            color: met ? NColors.success : ct.textTertiary,
          ),
        ),
      ],
    );
  }
}
