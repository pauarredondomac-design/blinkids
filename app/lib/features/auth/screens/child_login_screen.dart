import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../../../data/services/analytics_service.dart';
import '../../../shared/providers/cosmetic_provider.dart';
import '../../../shared/widgets/blink_character.dart';
import 'pin_pad_widget.dart';

class ChildLoginScreen extends ConsumerStatefulWidget {
  const ChildLoginScreen({super.key});

  @override
  ConsumerState<ChildLoginScreen> createState() => _ChildLoginScreenState();
}

class _ChildLoginScreenState extends ConsumerState<ChildLoginScreen> {
  final _nameCtrl = TextEditingController();

  // Pasos: 0 = nombre, 1 = PIN
  int _step = 0;
  String _pin = '';
  bool _loading = false;
  String _errorMsg = '';

  String _sanitize(String s) => s.trim().replaceAll(RegExp(r'\s+'), ' ');
  String _fakeEmail(String name) =>
      'child_${name.toLowerCase().replaceAll(' ', '_')}@blinkids.app';

  void _onPinDigit(String digit) {
    if (_pin.length >= 6) return;
    setState(() {
      _pin += digit;
      _errorMsg = '';
    });
    if (_pin.length == 6) _login();
  }

  void _onPinDelete() {
    if (_pin.isNotEmpty) {
      setState(() => _pin = _pin.substring(0, _pin.length - 1));
    }
  }

  Future<void> _login() async {
    setState(() {
      _loading = true;
      _errorMsg = '';
    });
    final name = _sanitize(_nameCtrl.text);
    final email = _fakeEmail(name);

    try {
      await Supabase.instance.client.auth.signInWithPassword(
        email: email,
        password: _pin,
      );
      ref.invalidate(equippedLoadoutProvider);
      ref.invalidate(ownedCosmeticsProvider);
      AnalyticsService.instance.login('child_email');
      if (mounted) context.go('/world');
    } on AuthException {
      if (mounted) {
        setState(() {
          _errorMsg = 'Nombre o PIN incorrecto. Inténtalo de nuevo.';
          _loading = false;
          _pin = '';
        });
      }
    } catch (_) {
      if (mounted) {
        setState(() {
          _errorMsg = 'Error de conexión. Verifica tu internet.';
          _loading = false;
          _pin = '';
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      resizeToAvoidBottomInset: false,
      body: Container(
        decoration: const BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
            colors: [Color(0xFF060618), Color(0xFF0D0D2B), Color(0xFF12124A)],
          ),
        ),
        child: SafeArea(
          child: Column(
            children: [
              Expanded(
                child: Row(
                  children: [
                    // ── Izquierda: Blink + mensaje ─────────────────────────
                    Expanded(
                      child: Center(
                        child: FittedBox(
                          fit: BoxFit.scaleDown,
                          child: SizedBox(
                            width: 220,
                            child: Column(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                const BlinkCharacterWidget(
                                    width: 160, enableBounce: true),
                                const SizedBox(height: 20),
                                AnimatedSwitcher(
                                  duration: 300.ms,
                                  child: Text(
                                    _step == 0
                                        ? '¡Hola de nuevo,\naventurero!'
                                        : '¡Introduce\ntu PIN!',
                                    key: ValueKey(_step),
                                    textAlign: TextAlign.center,
                                    style: const TextStyle(
                                      fontFamily: 'Nunito',
                                      fontWeight: FontWeight.w800,
                                      fontSize: 22,
                                      color: Colors.white,
                                      height: 1.3,
                                    ),
                                  ),
                                ),
                                if (_errorMsg.isNotEmpty) ...[
                                  const SizedBox(height: 16),
                                  Container(
                                    padding: const EdgeInsets.symmetric(
                                        horizontal: 16, vertical: 10),
                                    decoration: BoxDecoration(
                                      color: Colors.red.withOpacity(0.15),
                                      borderRadius: BorderRadius.circular(12),
                                      border: Border.all(
                                          color: Colors.red.withOpacity(0.4)),
                                    ),
                                    child: Text(
                                      _errorMsg,
                                      textAlign: TextAlign.center,
                                      style: const TextStyle(
                                          color: Colors.redAccent,
                                          fontFamily: 'Nunito',
                                          fontSize: 13),
                                    ),
                                  ),
                                ],
                              ],
                            ),
                          ),
                        ),
                      ),
                    ),

                    // ── Derecha: formulario ────────────────────────────────
                    Expanded(
                      child: Center(
                        child: FittedBox(
                          fit: BoxFit.scaleDown,
                          child: SizedBox(
                            width: 260,
                            child:
                                _step == 0 ? _buildNameStep() : _buildPinStep(),
                          ),
                        ),
                      ),
                    ),
                  ],
                ),
              ),

              // ── Enlaces pequeños: registrarte / login de padre ──────────
              Padding(
                padding: const EdgeInsets.only(bottom: 12),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    TextButton(
                      onPressed: () => context.push('/child-signup'),
                      child: const Text(
                        'Registrarte',
                        style: TextStyle(
                            color: Colors.white54,
                            fontFamily: 'Nunito',
                            fontWeight: FontWeight.w600,
                            fontSize: 12),
                      ),
                    ),
                    const Text('•',
                        style: TextStyle(color: Colors.white24, fontSize: 12)),
                    TextButton(
                      onPressed: () => context.push('/parent-auth'),
                      child: const Text(
                        'Iniciar sesión padre',
                        style: TextStyle(
                            color: Colors.white54,
                            fontFamily: 'Nunito',
                            fontWeight: FontWeight.w600,
                            fontSize: 12),
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildNameStep() {
    return Column(
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        const Text(
          'Tu nombre de aventurero',
          style: TextStyle(
            fontFamily: 'Nunito',
            fontWeight: FontWeight.w700,
            fontSize: 16,
            color: Colors.white60,
          ),
        ),
        const SizedBox(height: 12),
        Container(
          decoration: BoxDecoration(
            color: Colors.white.withOpacity(0.95),
            borderRadius: BorderRadius.circular(16),
          ),
          child: TextField(
            controller: _nameCtrl,
            textAlign: TextAlign.center,
            style: const TextStyle(
              color: Color(0xFF1A1A2E),
              fontFamily: 'Nunito',
              fontWeight: FontWeight.w700,
              fontSize: 22,
            ),
            decoration: const InputDecoration(
              hintText: 'Nombre de héroe',
              hintStyle: TextStyle(
                  color: Color(0xFF9EA3B8), fontSize: 18, fontFamily: 'Nunito'),
              border: InputBorder.none,
              contentPadding:
                  EdgeInsets.symmetric(horizontal: 16, vertical: 14),
            ),
            onSubmitted: (_) => _goToPin(),
          ),
        ),
        const SizedBox(height: 24),
        GestureDetector(
          onTap: _goToPin,
          child: Container(
            width: double.infinity,
            padding: const EdgeInsets.symmetric(vertical: 16),
            decoration: BoxDecoration(
              gradient: const LinearGradient(
                  colors: [Color(0xFF81C784), Color(0xFF388E3C)]),
              borderRadius: BorderRadius.circular(30),
            ),
            child: const Text(
              'Siguiente →',
              textAlign: TextAlign.center,
              style: TextStyle(
                  fontFamily: 'Nunito',
                  fontWeight: FontWeight.w900,
                  fontSize: 18,
                  color: Colors.white),
            ),
          ),
        ),
        const SizedBox(height: 16),
        TextButton(
          onPressed: () =>
              context.canPop() ? context.pop() : context.go('/world'),
          child: const Text('← Volver',
              style: TextStyle(color: Colors.white38, fontFamily: 'Nunito')),
        ),
      ],
    ).animate().fadeIn(duration: 300.ms);
  }

  void _goToPin() {
    final name = _sanitize(_nameCtrl.text);
    if (name.length < 3) {
      setState(() => _errorMsg = 'Escribe tu nombre de aventurero.');
      return;
    }
    setState(() {
      _step = 1;
      _errorMsg = '';
    });
  }

  Widget _buildPinStep() {
    return Column(
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        // Dots del PIN
        Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: List.generate(6, (i) {
            final filled = i < _pin.length;
            return AnimatedContainer(
              duration: 150.ms,
              margin: const EdgeInsets.symmetric(horizontal: 8),
              width: 18,
              height: 18,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: filled ? const Color(0xFF81C784) : Colors.transparent,
                border: Border.all(
                  color: filled ? const Color(0xFF81C784) : Colors.white38,
                  width: 2,
                ),
              ),
            );
          }),
        ),
        const SizedBox(height: 32),
        _loading
            ? const CircularProgressIndicator(color: Color(0xFF81C784))
            : PinPadWidget(onDigit: _onPinDigit, onDelete: _onPinDelete),
        const SizedBox(height: 16),
        TextButton(
          onPressed: () => setState(() {
            _step = 0;
            _pin = '';
            _errorMsg = '';
          }),
          child: const Text('← Cambiar nombre',
              style: TextStyle(color: Colors.white38, fontFamily: 'Nunito')),
        ),
      ],
    ).animate().fadeIn(duration: 300.ms);
  }

  @override
  void dispose() {
    _nameCtrl.dispose();
    super.dispose();
  }
}
