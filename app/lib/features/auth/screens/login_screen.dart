import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../../../core/constants/app_colors.dart';
import '../../../core/constants/app_sizes.dart';
import '../../../core/constants/app_strings.dart';
import '../../../core/utils/extensions.dart';
import '../../../shared/providers/auth_provider.dart';
import '../../../shared/widgets/fin_button.dart';
import '../../../shared/widgets/loading_overlay.dart';

class LoginScreen extends ConsumerStatefulWidget {
  const LoginScreen({super.key});

  @override
  ConsumerState<LoginScreen> createState() => _LoginScreenState();
}

class _LoginScreenState extends ConsumerState<LoginScreen> {
  bool _isLoading = false;
  bool _showEmailForm = false;
  bool _isSignUp = false; // toggle login ↔ registro
  final _emailController = TextEditingController();
  final _passwordController = TextEditingController();
  final _formKey = GlobalKey<FormState>();

  @override
  void dispose() {
    _emailController.dispose();
    _passwordController.dispose();
    super.dispose();
  }

  Future<void> _signInWithGoogle() async {
    setState(() => _isLoading = true);
    try {
      final repo = ref.read(authRepositoryProvider);
      // En web no usamos deep link — Supabase redirige al origen actual
      if (kIsWeb) {
        await repo.signInWithGoogleWeb();
      } else {
        await repo.signInWithGoogle();
      }
    } catch (e) {
      if (mounted) context.showError('Error al conectar con Google: ${e.toString()}');
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  Future<void> _submitEmailForm() async {
    if (!(_formKey.currentState?.validate() ?? false)) return;

    setState(() => _isLoading = true);
    try {
      final repo = ref.read(authRepositoryProvider);
      final email = _emailController.text.trim();
      final password = _passwordController.text;

      if (_isSignUp) {
        final res = await repo.signUpWithEmail(email: email, password: password);
        if (mounted && res.user != null) {
          context.showSuccess('¡Cuenta creada! Revisa tu correo para confirmar.');
        }
      } else {
        await repo.signInWithEmail(email: email, password: password);
      }
    } on AuthException catch (e) {
      if (mounted) {
        final msg = _authErrorToSpanish(e.message);
        // Caso especial: correo sin confirmar → ofrecer reenvío
        if (e.message.toLowerCase().contains('email not confirmed')) {
          _showEmailNotConfirmedDialog(email: _emailController.text.trim());
        } else {
          context.showError(msg);
        }
      }
    } catch (e) {
      if (mounted) {
        context.showError(_isSignUp
            ? 'No se pudo crear la cuenta: ${e.toString()}'
            : 'Error al iniciar sesión: ${e.toString()}');
      }
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  // Traduce los mensajes de error de Supabase Auth al español.
  String _authErrorToSpanish(String msg) {
    final m = msg.toLowerCase();
    if (m.contains('email not confirmed')) {
      return 'Debes confirmar tu correo antes de entrar. Revisa tu bandeja de entrada.';
    }
    if (m.contains('invalid login') || m.contains('invalid credentials') || m.contains('wrong password')) {
      return 'Correo o contraseña incorrectos.';
    }
    if (m.contains('user not found')) {
      return 'No existe ninguna cuenta con ese correo.';
    }
    if (m.contains('email rate limit') || m.contains('too many requests')) {
      return 'Demasiados intentos. Espera unos minutos e inténtalo de nuevo.';
    }
    if (m.contains('network')) {
      return 'Sin conexión a internet. Revisa tu red.';
    }
    return msg; // fallback: mensaje original de Supabase
  }

  void _showEmailNotConfirmedDialog({required String email}) {
    showDialog<void>(
      context: context,
      builder: (_) => AlertDialog(
        title: const Text('Correo sin confirmar 📧',
            style: TextStyle(fontFamily: 'Nunito', fontWeight: FontWeight.w800)),
        content: Text(
          'La cuenta "$email" aún no está confirmada.\n\n'
          '¿Quieres que te enviemos el correo de confirmación de nuevo?',
          style: const TextStyle(fontFamily: 'Nunito'),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Cancelar'),
          ),
          FilledButton(
            onPressed: () async {
              Navigator.pop(context);
              try {
                await ref.read(authRepositoryProvider).resetPassword(email);
                if (mounted) context.showSuccess('¡Correo enviado! Revisa tu bandeja de entrada.');
              } catch (_) {
                if (mounted) context.showError('No se pudo enviar el correo. Inténtalo más tarde.');
              }
            },
            child: const Text('Reenviar correo'),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return LoadingOverlay(
      isLoading: _isLoading,
      child: Scaffold(
        backgroundColor: Colors.transparent,
        extendBody: true,
        extendBodyBehindAppBar: true,
        resizeToAvoidBottomInset: false,
        body: Container(
          // Gradiente como base absoluta — cubre status bar, nav bar y todo
          width:  double.infinity,
          height: double.infinity,
          decoration: const BoxDecoration(
            gradient: LinearGradient(
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
              colors: [AppColors.forestGreen, AppColors.primary, Color(0xFF66BB6A)],
            ),
          ),
          child: Stack(
          children: [
            Positioned(
              left: -20,
              bottom: -20,
              child: Icon(Icons.park, size: 200, color: Colors.white.withAlpha(20)),
            ),
            Positioned(
              right: -30,
              top: -30,
              child: Icon(Icons.star, size: 180, color: Colors.white.withAlpha(15)),
            ),
            SafeArea(
              left: false,
              right: false,
              child: Row(
                children: [
                  // Panel izquierdo: branding
                  Expanded(
                    flex: 5,
                    child: Padding(
                      padding: const EdgeInsets.all(AppSizes.xl),
                      child: Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Image.asset(
                            'assets/blink/blink_dressed.png',
                            width: 200,
                            filterQuality: FilterQuality.high,
                          ).animate().scale(duration: 800.ms, curve: Curves.elasticOut),
                          const SizedBox(height: AppSizes.md),
                          ShaderMask(
                            shaderCallback: (bounds) => const LinearGradient(
                              colors: [Colors.white, Color(0xFFB9F6CA)],
                              begin: Alignment.topLeft,
                              end: Alignment.bottomRight,
                            ).createShader(bounds),
                            child: const Text(
                              'Blinkids',
                              style: TextStyle(
                                fontSize: 64,
                                fontWeight: FontWeight.w900,
                                color: Colors.white,
                                fontFamily: 'Nunito',
                                letterSpacing: 2,
                                height: 1,
                              ),
                            ),
                          ).animate().fadeIn(delay: 200.ms).slideX(begin: -0.3, end: 0),
                        ],
                      ),
                    ),
                  ),
                  // Panel derecho: formulario
                  Expanded(
                    flex: 5,
                    child: AnimatedPadding(
                      duration: const Duration(milliseconds: 200),
                      curve: Curves.easeOut,
                      padding: EdgeInsets.only(
                        bottom: MediaQuery.of(context).viewInsets.bottom * 0.5,
                      ),
                      child: Center(
                      child: ConstrainedBox(
                        constraints: const BoxConstraints(maxWidth: 400),
                        child: Card(
                          margin: const EdgeInsets.symmetric(
                            horizontal: AppSizes.lg,
                            vertical: AppSizes.sm,
                          ),
                          child: Padding(
                            padding: const EdgeInsets.symmetric(
                              horizontal: AppSizes.xl,
                              vertical: AppSizes.md,
                            ),
                            child: _showEmailForm
                                ? _EmailForm(
                                    formKey: _formKey,
                                    emailController: _emailController,
                                    passwordController: _passwordController,
                                    isSignUp: _isSignUp,
                                    onSubmit: _submitEmailForm,
                                    onToggleMode: () => setState(() {
                                      _isSignUp = !_isSignUp;
                                      _formKey.currentState?.reset();
                                    }),
                                    onBack: () => setState(() {
                                      _showEmailForm = false;
                                      _isSignUp = false;
                                    }),
                                  )
                                : _MainLoginOptions(
                                    onGoogleTap: _signInWithGoogle,
                                    onEmailTap: () => setState(() {
                                      _showEmailForm = true;
                                      _isSignUp = false;
                                    }),
                                    onRegisterTap: () => setState(() {
                                      _showEmailForm = true;
                                      _isSignUp = true;
                                    }),
                                  ),
                          ),
                        )
                            .animate()
                            .fadeIn(delay: 300.ms, duration: 500.ms)
                            .slideX(begin: 0.3, end: 0),
                      ),
                      ), // Center
                    ), // AnimatedPadding
                  ),
                ],
              ),
            ),
          ],
          ), // Stack
        ), // Container gradiente
      ),
    );
  }
}

// ─────────────────────────────────────────────
// Opciones principales de login
// ─────────────────────────────────────────────
class _MainLoginOptions extends StatelessWidget {
  const _MainLoginOptions({
    required this.onGoogleTap,
    required this.onEmailTap,
    required this.onRegisterTap,
  });

  final VoidCallback onGoogleTap;
  final VoidCallback onEmailTap;
  final VoidCallback onRegisterTap;

  @override
  Widget build(BuildContext context) {
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        Text(
          AppStrings.welcome,
          style: Theme.of(context).textTheme.headlineMedium,
          textAlign: TextAlign.center,
        ),
        const SizedBox(height: AppSizes.sm),
        Text(
          AppStrings.loginSubtitle,
          style: Theme.of(context).textTheme.bodyMedium,
          textAlign: TextAlign.center,
        ),
        const SizedBox(height: AppSizes.xl),
        // Google
        InkWell(
          onTap: onGoogleTap,
          borderRadius: BorderRadius.circular(14),
          child: Container(
            width: double.infinity,
            padding: const EdgeInsets.symmetric(vertical: 14, horizontal: 16),
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(14),
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withAlpha(25),
                  blurRadius: 8,
                  offset: const Offset(0, 2),
                ),
              ],
            ),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                const _GoogleGLogo(size: 22),
                const SizedBox(width: 12),
                Text(
                  AppStrings.signInWithGoogle,
                  style: TextStyle(
                    color: AppColors.textPrimary,
                    fontFamily: 'Nunito',
                    fontWeight: FontWeight.w700,
                    fontSize: 15,
                  ),
                ),
              ],
            ),
          ),
        ),
        const SizedBox(height: AppSizes.md),
        // Divisor
        Row(
          children: [
            const Expanded(child: Divider()),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: AppSizes.sm),
              child: Text('o', style: Theme.of(context).textTheme.bodyMedium),
            ),
            const Expanded(child: Divider()),
          ],
        ),
        const SizedBox(height: AppSizes.md),
        // Login con correo
        OutlinedButton.icon(
          onPressed: onEmailTap,
          icon: const Icon(Icons.email_outlined),
          label: const Text('Iniciar sesión con correo'),
        ),
        const SizedBox(height: AppSizes.sm),
        // Registro nuevo
        TextButton(
          onPressed: onRegisterTap,
          child: const Text(
            '¿No tienes cuenta? Regístrate aquí',
            style: TextStyle(fontWeight: FontWeight.w600),
          ),
        ),
      ],
    );
  }
}

// ─────────────────────────────────────────────
// Formulario de correo (login + registro)
// ─────────────────────────────────────────────
class _EmailForm extends StatelessWidget {
  const _EmailForm({
    required this.formKey,
    required this.emailController,
    required this.passwordController,
    required this.isSignUp,
    required this.onSubmit,
    required this.onToggleMode,
    required this.onBack,
  });

  final GlobalKey<FormState> formKey;
  final TextEditingController emailController;
  final TextEditingController passwordController;
  final bool isSignUp;
  final VoidCallback onSubmit;
  final VoidCallback onToggleMode;
  final VoidCallback onBack;

  @override
  Widget build(BuildContext context) {
    return SingleChildScrollView(
      child: Form(
      key: formKey,
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(
            isSignUp ? 'Crear cuenta' : 'Iniciar sesión',
            style: Theme.of(context).textTheme.headlineMedium,
          ),
          const SizedBox(height: AppSizes.lg),
          TextFormField(
            controller: emailController,
            keyboardType: TextInputType.emailAddress,
            decoration: const InputDecoration(
              labelText: AppStrings.emailLabel,
              prefixIcon: Icon(Icons.email_outlined),
            ),
            validator: (v) {
              if (v == null || v.isEmpty) return AppStrings.emailRequired;
              if (!v.isValidEmail) return AppStrings.emailInvalid;
              return null;
            },
          ),
          const SizedBox(height: AppSizes.md),
          TextFormField(
            controller: passwordController,
            obscureText: true,
            decoration: const InputDecoration(
              labelText: AppStrings.passwordLabel,
              prefixIcon: Icon(Icons.lock_outline),
            ),
            validator: (v) {
              if (v == null || v.isEmpty) return AppStrings.passwordRequired;
              if (v.length < 6) return AppStrings.passwordTooShort;
              return null;
            },
            onFieldSubmitted: (_) => onSubmit(),
          ),
          const SizedBox(height: AppSizes.xl),
          FinButton(
            label: isSignUp ? 'Crear cuenta' : 'Iniciar sesión',
            icon: isSignUp ? Icons.person_add_rounded : Icons.login_rounded,
            onPressed: onSubmit,
          ),
          const SizedBox(height: AppSizes.md),
          TextButton(
            onPressed: onToggleMode,
            child: Text(
              isSignUp
                  ? '¿Ya tienes cuenta? Inicia sesión'
                  : '¿No tienes cuenta? Regístrate',
              style: const TextStyle(fontWeight: FontWeight.w600),
            ),
          ),
          TextButton(
            onPressed: onBack,
            child: const Text(AppStrings.back),
          ),
        ],
      ),
      ), // Form
    ); // SingleChildScrollView
  }
}

// ─────────────────────────────────────────────
// Logo G de Google con los 4 colores oficiales
// ─────────────────────────────────────────────
class _GoogleGLogo extends StatelessWidget {
  const _GoogleGLogo({this.size = 20});
  final double size;

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: size,
      height: size,
      child: CustomPaint(painter: _GoogleGPainter()),
    );
  }
}

class _GoogleGPainter extends CustomPainter {
  @override
  void paint(Canvas canvas, Size size) {
    final w = size.width;
    final h = size.height;
    final cx = w / 2;
    final cy = h / 2;
    final r  = w * 0.46;
    final stroke = w * 0.22;

    final paint = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = stroke
      ..strokeCap = StrokeCap.butt;

    final oval = Rect.fromCircle(center: Offset(cx, cy), radius: r);

    // Rojo — de 225° a 330° (top izquierda → arriba)
    paint.color = const Color(0xFFEA4335);
    canvas.drawArc(oval, _deg(225), _deg(105), false, paint);

    // Azul — de 330° a 90° (arriba → derecha, pasando 0°)
    paint.color = const Color(0xFF4285F4);
    canvas.drawArc(oval, _deg(330), _deg(120), false, paint);

    // Verde — de 90° a 150°
    paint.color = const Color(0xFF34A853);
    canvas.drawArc(oval, _deg(90), _deg(65), false, paint);

    // Amarillo — de 150° a 225°
    paint.color = const Color(0xFFFBBC05);
    canvas.drawArc(oval, _deg(155), _deg(70), false, paint);

    // Barra horizontal derecha del "G"
    final barPaint = Paint()
      ..color = const Color(0xFF4285F4)
      ..style = PaintingStyle.fill;
    final barTop    = cy - stroke / 2;
    final barBottom = cy + stroke / 2;
    final barLeft   = cx;
    final barRight  = w * 0.92;
    canvas.drawRect(
      Rect.fromLTRB(barLeft, barTop, barRight, barBottom),
      barPaint,
    );
  }

  double _deg(double deg) => deg * 3.14159265 / 180;

  @override
  bool shouldRepaint(_GoogleGPainter _) => false;
}
