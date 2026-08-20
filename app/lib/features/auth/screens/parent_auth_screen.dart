import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:go_router/go_router.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../../../data/services/analytics_service.dart';

class ParentAuthScreen extends StatefulWidget {
  const ParentAuthScreen({super.key});

  @override
  State<ParentAuthScreen> createState() => _ParentAuthScreenState();
}

class _ParentAuthScreenState extends State<ParentAuthScreen>
    with SingleTickerProviderStateMixin {
  late final TabController _tabs;

  final _emailCtrl = TextEditingController();
  final _passCtrl = TextEditingController();
  final _nameCtrl = TextEditingController(); // solo registro
  final _emailRegCtrl = TextEditingController();
  final _passRegCtrl = TextEditingController();

  bool _loadingLogin = false;
  bool _loadingReg = false;
  String _errorLogin = '';
  String _errorReg = '';
  bool _obscureLogin = true;
  bool _obscureReg = true;

  @override
  void initState() {
    super.initState();
    _tabs = TabController(length: 2, vsync: this);
  }

  @override
  void dispose() {
    _tabs.dispose();
    _emailCtrl.dispose();
    _passCtrl.dispose();
    _nameCtrl.dispose();
    _emailRegCtrl.dispose();
    _passRegCtrl.dispose();
    super.dispose();
  }

  Future<void> _login() async {
    final email = _emailCtrl.text.trim();
    final pass = _passCtrl.text;
    if (email.isEmpty || pass.isEmpty) {
      setState(() => _errorLogin = 'Completa todos los campos.');
      return;
    }
    setState(() {
      _loadingLogin = true;
      _errorLogin = '';
    });
    try {
      await Supabase.instance.client.auth.signInWithPassword(
        email: email,
        password: pass,
      );
      AnalyticsService.instance.login('parent_email');
      if (mounted) context.go('/parent');
    } on AuthException catch (e) {
      if (mounted) {
        setState(() {
          _errorLogin = _mapAuthError(e.message);
          _loadingLogin = false;
        });
      }
    } catch (_) {
      if (mounted) {
        setState(() {
          _errorLogin = 'Error de conexión.';
          _loadingLogin = false;
        });
      }
    }
  }

  Future<void> _register() async {
    final name = _nameCtrl.text.trim();
    final email = _emailRegCtrl.text.trim();
    final pass = _passRegCtrl.text;
    if (name.isEmpty || email.isEmpty || pass.isEmpty) {
      setState(() => _errorReg = 'Completa todos los campos.');
      return;
    }
    if (pass.length < 8) {
      setState(
          () => _errorReg = 'La contraseña debe tener al menos 8 caracteres.');
      return;
    }
    setState(() {
      _loadingReg = true;
      _errorReg = '';
    });
    try {
      final res = await Supabase.instance.client.auth.signUp(
        email: email,
        password: pass,
      );
      final userId = res.user?.id;
      if (userId == null) throw Exception('No se pudo crear la cuenta');

      await Supabase.instance.client.from('profiles').insert({
        'id': userId,
        'role': 'parent',
        'display_name': name,
        'account_type': 'full',
      });

      // Billetera del padre — financia envíos y recompensas de misiones,
      // se recarga automáticamente cada semana (ver grant_weekly_allowance_if_due).
      await Supabase.instance.client.from('wallets').insert({
        'user_id': userId,
        'weekly_allowance': 500,
      });

      AnalyticsService.instance.register('parent');
      if (mounted) context.go('/parent');
    } on AuthException catch (e) {
      if (mounted) {
        setState(() {
          _errorReg = _mapAuthError(e.message);
          _loadingReg = false;
        });
      }
    } catch (_) {
      if (mounted) {
        setState(() {
          _errorReg = 'Error inesperado. Inténtalo de nuevo.';
          _loadingReg = false;
        });
      }
    }
  }

  Future<void> _forgotPassword() async {
    final email = _emailCtrl.text.trim();
    if (email.isEmpty) {
      setState(() => _errorLogin =
          'Escribe tu correo arriba para poder enviarte el link.');
      return;
    }
    setState(() {
      _loadingLogin = true;
      _errorLogin = '';
    });
    try {
      await Supabase.instance.client.auth.resetPasswordForEmail(email);
      if (mounted) {
        setState(() => _loadingLogin = false);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
                'Te enviamos un correo a $email con un link para restablecer tu contraseña.'),
            backgroundColor: const Color(0xFF388E3C),
          ),
        );
      }
    } catch (_) {
      if (mounted) {
        setState(() {
          _loadingLogin = false;
          _errorLogin = 'No pudimos enviar el correo. Verifica tu internet.';
        });
      }
    }
  }

  String _mapAuthError(String msg) {
    if (msg.contains('Invalid login')) {
      return 'Correo o contraseña incorrectos.';
    }
    if (msg.contains('Email already')) return 'Este correo ya está registrado.';
    if (msg.contains('Password should')) return 'La contraseña es muy corta.';
    // Errores de red/conexión (SocketException, ClientException, timeouts,
    // etc.) nunca deben mostrarse tal cual al usuario.
    final lower = msg.toLowerCase();
    if (lower.contains('socket') ||
        lower.contains('connection') ||
        lower.contains('network') ||
        lower.contains('client') ||
        lower.contains('timeout') ||
        lower.contains('host')) {
      return 'No se pudo conectar. Verifica tu internet e inténtalo de nuevo.';
    }
    // Cualquier otro mensaje no reconocido: nunca exponer el texto técnico.
    return 'Ocurrió un error. Inténtalo de nuevo.';
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      resizeToAvoidBottomInset: false,
      body: Container(
        decoration: const BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
            colors: [Color(0xFF060618), Color(0xFF0D0D2B), Color(0xFF1A1040)],
          ),
        ),
        child: SafeArea(
          child: Row(
            children: [
              // ── Izquierda: icono + texto ─────────────────────────────────
              Expanded(
                child: Center(
                  child: FittedBox(
                    fit: BoxFit.scaleDown,
                    child: SizedBox(
                      width: 220,
                      child: Column(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Container(
                            width: 100,
                            height: 100,
                            decoration: BoxDecoration(
                              color: const Color(0xFFFFD700).withOpacity(0.15),
                              shape: BoxShape.circle,
                              border: Border.all(
                                  color:
                                      const Color(0xFFFFD700).withOpacity(0.4),
                                  width: 2),
                            ),
                            child: const Center(
                              child: Text('👨‍👩‍👧',
                                  style: TextStyle(fontSize: 46)),
                            ),
                          ).animate().scale(
                              duration: 600.ms, curve: Curves.elasticOut),
                          const SizedBox(height: 20),
                          const Text(
                            'Panel de padres',
                            style: TextStyle(
                              fontFamily: 'Nunito',
                              fontWeight: FontWeight.w900,
                              fontSize: 24,
                              color: Color(0xFFFFD700),
                            ),
                            textAlign: TextAlign.center,
                          ).animate().fadeIn(delay: 300.ms),
                          const SizedBox(height: 6),
                          const Text(
                            'Controla el aprendizaje\nde tu hijo',
                            style: TextStyle(
                                fontFamily: 'Nunito',
                                fontSize: 13,
                                color: Colors.white54,
                                height: 1.4),
                            textAlign: TextAlign.center,
                          ).animate().fadeIn(delay: 400.ms),
                        ],
                      ),
                    ),
                  ),
                ),
              ),

              // ── Derecha: tabs login / registro ────────────────────────────
              Expanded(
                child: Center(
                  child: FittedBox(
                    fit: BoxFit.scaleDown,
                    child: SizedBox(
                      width: 260,
                      child: Column(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          // Tab selector
                          Container(
                            decoration: BoxDecoration(
                              color: const Color(0xFF0A0A2A),
                              borderRadius: BorderRadius.circular(30),
                              border: Border.all(color: Colors.white12),
                            ),
                            child: TabBar(
                              controller: _tabs,
                              indicator: BoxDecoration(
                                color: const Color(0xFFFFD700),
                                borderRadius: BorderRadius.circular(30),
                              ),
                              indicatorSize: TabBarIndicatorSize.tab,
                              dividerHeight: 0,
                              labelColor: const Color(0xFF0D0D2B),
                              unselectedLabelColor: Colors.white54,
                              labelStyle: const TextStyle(
                                  fontFamily: 'Nunito',
                                  fontWeight: FontWeight.w700,
                                  fontSize: 14),
                              tabs: const [
                                Tab(text: 'Entrar'),
                                Tab(text: 'Registrarse'),
                              ],
                            ),
                          ),
                          const SizedBox(height: 20),

                          SizedBox(
                            height: 290,
                            child: TabBarView(
                              controller: _tabs,
                              children: [_buildLogin(), _buildRegister()],
                            ),
                          ),

                          const SizedBox(height: 8),
                          TextButton(
                            onPressed: () => context.canPop()
                                ? context.pop()
                                : context.go('/world'),
                            child: const Text('← Volver',
                                style: TextStyle(
                                    color: Colors.white38,
                                    fontFamily: 'Nunito')),
                          ),
                        ],
                      ),
                    ),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildLogin() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        _Field(
            controller: _emailCtrl,
            hint: 'Correo electrónico',
            icon: Icons.email_outlined,
            keyboardType: TextInputType.emailAddress),
        const SizedBox(height: 12),
        _Field(
            controller: _passCtrl,
            hint: 'Contraseña',
            icon: Icons.lock_outline,
            obscure: _obscureLogin,
            onToggleObscure: () =>
                setState(() => _obscureLogin = !_obscureLogin)),
        Align(
          alignment: Alignment.centerRight,
          child: TextButton(
            onPressed: _loadingLogin ? null : _forgotPassword,
            style: TextButton.styleFrom(
                padding: EdgeInsets.zero,
                minimumSize: const Size(0, 32),
                tapTargetSize: MaterialTapTargetSize.shrinkWrap),
            child: const Text('¿Olvidaste tu contraseña?',
                style: TextStyle(
                    color: Color(0xFFFFD700),
                    fontFamily: 'Nunito',
                    fontSize: 12,
                    fontWeight: FontWeight.w600)),
          ),
        ),
        if (_errorLogin.isNotEmpty) ...[
          const SizedBox(height: 6),
          _ErrorBox(msg: _errorLogin),
        ],
        const SizedBox(height: 14),
        _loadingLogin
            ? const Center(
                child: CircularProgressIndicator(color: Color(0xFFFFD700)))
            : _GoldButton(label: 'Entrar', onTap: _login),
      ],
    );
  }

  Widget _buildRegister() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        _Field(
            controller: _nameCtrl,
            hint: 'Tu nombre',
            icon: Icons.person_outline),
        const SizedBox(height: 10),
        _Field(
            controller: _emailRegCtrl,
            hint: 'Correo electrónico',
            icon: Icons.email_outlined,
            keyboardType: TextInputType.emailAddress),
        const SizedBox(height: 10),
        _Field(
            controller: _passRegCtrl,
            hint: 'Contraseña (mín. 8 caracteres)',
            icon: Icons.lock_outline,
            obscure: _obscureReg,
            onToggleObscure: () => setState(() => _obscureReg = !_obscureReg)),
        if (_errorReg.isNotEmpty) ...[
          const SizedBox(height: 10),
          _ErrorBox(msg: _errorReg),
        ],
        const SizedBox(height: 16),
        _loadingReg
            ? const Center(
                child: CircularProgressIndicator(color: Color(0xFFFFD700)))
            : _GoldButton(label: 'Crear cuenta', onTap: _register),
      ],
    );
  }
}

// ── Widgets auxiliares ────────────────────────────────────────────────────────

class _Field extends StatelessWidget {
  const _Field({
    required this.controller,
    required this.hint,
    required this.icon,
    this.keyboardType,
    this.obscure = false,
    this.onToggleObscure,
  });
  final TextEditingController controller;
  final String hint;
  final IconData icon;
  final TextInputType? keyboardType;
  final bool obscure;
  final VoidCallback? onToggleObscure;

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        color: Colors.white.withOpacity(0.9),
        borderRadius: BorderRadius.circular(14),
      ),
      child: TextField(
        controller: controller,
        obscureText: obscure,
        keyboardType: keyboardType,
        style: const TextStyle(
            color: Color(0xFF1A1A2E),
            fontFamily: 'Nunito',
            fontWeight: FontWeight.w600,
            fontSize: 15),
        decoration: InputDecoration(
          hintText: hint,
          hintStyle: const TextStyle(
              color: Color(0xFF9EA3B8), fontFamily: 'Nunito', fontSize: 14),
          prefixIcon: Icon(icon, color: const Color(0xFF9EA3B8), size: 20),
          suffixIcon: onToggleObscure != null
              ? IconButton(
                  icon: Icon(obscure ? Icons.visibility_off : Icons.visibility,
                      color: const Color(0xFF9EA3B8), size: 20),
                  onPressed: onToggleObscure,
                )
              : null,
          border: InputBorder.none,
          contentPadding:
              const EdgeInsets.symmetric(vertical: 14, horizontal: 12),
        ),
      ),
    );
  }
}

class _ErrorBox extends StatelessWidget {
  const _ErrorBox({required this.msg});
  final String msg;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
      decoration: BoxDecoration(
        color: Colors.red.withOpacity(0.15),
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: Colors.red.withOpacity(0.4)),
      ),
      child: Text(
        msg,
        style: const TextStyle(
            color: Colors.redAccent, fontFamily: 'Nunito', fontSize: 12),
        textAlign: TextAlign.center,
      ),
    );
  }
}

class _GoldButton extends StatelessWidget {
  const _GoldButton({required this.label, required this.onTap});
  final String label;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 15),
        decoration: BoxDecoration(
          gradient: const LinearGradient(
              colors: [Color(0xFFFFD700), Color(0xFFF9A825)]),
          borderRadius: BorderRadius.circular(30),
          boxShadow: [
            BoxShadow(
                color: const Color(0xFFFFD700).withOpacity(0.3),
                blurRadius: 12,
                offset: const Offset(0, 4))
          ],
        ),
        child: Text(
          label,
          textAlign: TextAlign.center,
          style: const TextStyle(
              fontFamily: 'Nunito',
              fontWeight: FontWeight.w900,
              fontSize: 16,
              color: Color(0xFF1A1A2E)),
        ),
      ),
    );
  }
}
