import 'dart:convert';
import 'package:crypto/crypto.dart';
import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../../../shared/providers/profile_provider.dart';
import '../../../shared/widgets/blink_character.dart';
import 'pin_pad_widget.dart';

class ChildSignupScreen extends ConsumerStatefulWidget {
  const ChildSignupScreen({super.key});

  @override
  ConsumerState<ChildSignupScreen> createState() => _ChildSignupScreenState();
}

class _ChildSignupScreenState extends ConsumerState<ChildSignupScreen> {
  final _nameCtrl = TextEditingController();
  final _focusNode = FocusNode();

  // Pasos: 0 = nombre, 1 = crear PIN, 2 = confirmar PIN
  int _step = 0;
  String _pin = '';
  String _pinConfirm = '';
  bool _checking = false;
  bool _loading = false;
  String _errorMsg = '';
  bool _nameOk = false;

  static const _minLen = 3;
  static const _maxLen = 20;

  @override
  void dispose() {
    _nameCtrl.dispose();
    _focusNode.dispose();
    super.dispose();
  }

  String _sanitize(String s) => s.trim().replaceAll(RegExp(r'\s+'), ' ');

  String _fakeEmail(String name) =>
      'child_${name.toLowerCase().replaceAll(' ', '_')}@blinkids.app';

  String _hashPin(String pin) => sha256.convert(utf8.encode(pin)).toString();

  Future<void> _checkName(String value) async {
    final name = _sanitize(value);
    if (name.length < _minLen) {
      setState(() {
        _nameOk = false;
        _errorMsg = '';
      });
      return;
    }
    setState(() {
      _checking = true;
      _errorMsg = '';
      _nameOk = false;
    });
    try {
      // RPC SECURITY DEFINER: funciona sin sesión activa (RLS bloquea SELECT
      // directo a profiles antes de autenticarse).
      final available = await Supabase.instance.client
          .rpc('is_display_name_available', params: {'p_name': name}) as bool;
      if (mounted) {
        setState(() {
          _nameOk = available;
          _errorMsg = available
              ? ''
              : '¡Ese nombre ya está ocupado! 😅 Prueba con otro.';
          _checking = false;
        });
      }
    } catch (_) {
      if (mounted)
        setState(() {
          _checking = false;
          _nameOk = false;
        });
    }
  }

  void _onPinDigit(String digit) {
    if (_step == 1) {
      if (_pin.length >= 6) return;
      setState(() {
        _pin += digit;
        _errorMsg = '';
      });
      if (_pin.length == 6) {
        Future.delayed(200.ms, () {
          if (mounted) setState(() => _step = 2);
        });
      }
    } else if (_step == 2) {
      if (_pinConfirm.length >= 6) return;
      setState(() {
        _pinConfirm += digit;
        _errorMsg = '';
      });
      if (_pinConfirm.length == 6) _confirmPin();
    }
  }

  void _onPinDelete() {
    if (_step == 1 && _pin.isNotEmpty) {
      setState(() => _pin = _pin.substring(0, _pin.length - 1));
    } else if (_step == 2 && _pinConfirm.isNotEmpty) {
      setState(
          () => _pinConfirm = _pinConfirm.substring(0, _pinConfirm.length - 1));
    }
  }

  void _confirmPin() {
    if (_pin != _pinConfirm) {
      setState(() {
        _errorMsg = 'Los PINs no coinciden. Inténtalo de nuevo.';
        _pinConfirm = '';
      });
      return;
    }
    _createAccount();
  }

  Future<void> _createAccount() async {
    setState(() {
      _loading = true;
      _errorMsg = '';
    });
    final name = _sanitize(_nameCtrl.text);
    final email = _fakeEmail(name);
    final client = Supabase.instance.client;

    try {
      // Verificación final de nombre (race condition guard)
      final existing = await client
          .from('profiles')
          .select('id')
          .ilike('display_name', name)
          .limit(1);
      if ((existing as List? ?? []).isNotEmpty) {
        setState(() {
          _errorMsg = '¡Ese nombre ya está ocupado! Elige otro.';
          _loading = false;
          _step = 0;
          _pin = '';
          _pinConfirm = '';
          _nameOk = false;
        });
        return;
      }

      // Crear cuenta con email interno + PIN como contraseña
      final authRes = await client.auth.signUp(
        email: email,
        password: _pin,
      );
      final userId = authRes.user?.id;
      if (userId == null) throw Exception('No se pudo crear la cuenta');

      // Si Supabase requiere confirmación de email, el signUp devuelve
      // user pero sin sesión activa. Intentamos iniciar sesión directamente.
      if (client.auth.currentUser == null) {
        await client.auth.signInWithPassword(email: email, password: _pin);
      }

      // Crear perfil + cartera via RPC (SECURITY DEFINER, bypasea RLS)
      await client.rpc('create_child_profile', params: {
        'p_display_name': name,
        'p_pin_hash': _hashPin(_pin),
      });

      // Invalidar caché del perfil para que se vuelva a cargar con el nuevo perfil
      ref.invalidate(currentProfileProvider);

      if (mounted) context.go('/tutorial');
    } on AuthException catch (e) {
      if (mounted)
        setState(() {
          _errorMsg = 'Error: ${e.message}';
          _loading = false;
        });
    } catch (e) {
      final msg = e.toString();
      final friendly = msg.contains('ya está en uso') || msg.contains('already')
          ? '¡Ese nombre ya está ocupado! Elige otro.'
          : msg.contains('network') || msg.contains('SocketException')
              ? 'Sin conexión. Verifica tu internet.'
              : 'Error: $msg';
      if (mounted)
        setState(() {
          _errorMsg = friendly;
          _loading = false;
        });
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
          child: Row(
            children: [
              // ── Izquierda: Blink + instrucción ──────────────────────────
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
                                  ? '¿Cómo te llamas,\naventurero?'
                                  : _step == 1
                                      ? 'Crea tu PIN\nde 6 dígitos'
                                      : 'Confirma\ntu PIN',
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
                          const SizedBox(height: 12),
                          if (_errorMsg.isNotEmpty)
                            Container(
                              padding: const EdgeInsets.symmetric(
                                  horizontal: 16, vertical: 8),
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
                      ),
                    ),
                  ),
                ),
              ),

              // ── Derecha: formulario ──────────────────────────────────────
              Expanded(
                child: Center(
                  child: FittedBox(
                    fit: BoxFit.scaleDown,
                    child: SizedBox(
                      width: 260,
                      child: _step == 0 ? _buildNameStep() : _buildPinStep(),
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

  Widget _buildNameStep() {
    return Column(
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        // Indicador de pasos
        const _StepIndicator(current: 0),
        const SizedBox(height: 32),

        // Campo nombre
        Container(
          decoration: BoxDecoration(
            color: Colors.white.withOpacity(0.95),
            borderRadius: BorderRadius.circular(16),
            border: Border.all(
              color: _nameOk ? const Color(0xFF4CAF50) : Colors.white24,
              width: 2,
            ),
          ),
          child: TextField(
            controller: _nameCtrl,
            focusNode: _focusNode,
            maxLength: _maxLen,
            textAlign: TextAlign.center,
            style: const TextStyle(
              color: Color(0xFF1A1A2E),
              fontFamily: 'Nunito',
              fontWeight: FontWeight.w700,
              fontSize: 22,
            ),
            decoration: InputDecoration(
              hintText: 'Tu nombre de héroe',
              hintStyle: const TextStyle(
                  color: Color(0xFF9EA3B8), fontSize: 18, fontFamily: 'Nunito'),
              counterStyle:
                  const TextStyle(color: Color(0xFF9EA3B8), fontSize: 11),
              border: InputBorder.none,
              contentPadding:
                  const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
              suffixIcon: _checking
                  ? const Padding(
                      padding: EdgeInsets.all(14),
                      child: SizedBox(
                          width: 20,
                          height: 20,
                          child: CircularProgressIndicator(
                              color: Colors.white54, strokeWidth: 2)),
                    )
                  : _nameOk
                      ? const Icon(Icons.check_circle_rounded,
                          color: Color(0xFF4CAF50), size: 28)
                      : null,
            ),
            onChanged: (v) {
              setState(() {
                _nameOk = false;
                _errorMsg = '';
              });
              if (_sanitize(v).length >= _minLen) _checkName(v);
            },
          ),
        ),

        const SizedBox(height: 8),
        const Text(
          'Mín. 3 letras · Único en Blinkids',
          style: TextStyle(
              color: Colors.white38, fontSize: 12, fontFamily: 'Nunito'),
        ),

        const SizedBox(height: 28),

        // Botón siguiente
        GestureDetector(
          onTap: _nameOk ? () => setState(() => _step = 1) : null,
          child: AnimatedOpacity(
            duration: 250.ms,
            opacity: _nameOk ? 1.0 : 0.4,
            child: Container(
              width: double.infinity,
              padding: const EdgeInsets.symmetric(vertical: 16),
              decoration: BoxDecoration(
                gradient: const LinearGradient(
                    colors: [Color(0xFF4FC3F7), Color(0xFF0288D1)]),
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
        ),

        const SizedBox(height: 16),
        TextButton(
          onPressed: () =>
              context.canPop() ? context.pop() : context.go('/world'),
          child: const Text('← Volver',
              style: TextStyle(color: Colors.white38, fontFamily: 'Nunito')),
        ),
      ],
    );
  }

  Widget _buildPinStep() {
    final currentPin = _step == 1 ? _pin : _pinConfirm;
    return Column(
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        _StepIndicator(current: _step),
        const SizedBox(height: 32),

        // Dots del PIN
        Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: List.generate(6, (i) {
            final filled = i < currentPin.length;
            return AnimatedContainer(
              duration: 150.ms,
              margin: const EdgeInsets.symmetric(horizontal: 8),
              width: 18,
              height: 18,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: filled ? const Color(0xFF4FC3F7) : Colors.transparent,
                border: Border.all(
                  color: filled ? const Color(0xFF4FC3F7) : Colors.white38,
                  width: 2,
                ),
              ),
            );
          }),
        ),

        const SizedBox(height: 32),

        // Teclado cajero
        _loading
            ? const CircularProgressIndicator(color: Color(0xFF4FC3F7))
            : PinPadWidget(onDigit: _onPinDigit, onDelete: _onPinDelete),

        const SizedBox(height: 16),
        if (_step == 2)
          TextButton(
            onPressed: () => setState(() {
              _step = 1;
              _pin = '';
              _pinConfirm = '';
              _errorMsg = '';
            }),
            child: const Text('← Cambiar PIN',
                style: TextStyle(color: Colors.white38, fontFamily: 'Nunito')),
          ),
      ],
    );
  }
}

class _StepIndicator extends StatelessWidget {
  const _StepIndicator({required this.current});
  final int current;

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.center,
      children: List.generate(3, (i) {
        final active = i == current;
        final done = i < current;
        return AnimatedContainer(
          duration: 300.ms,
          margin: const EdgeInsets.symmetric(horizontal: 4),
          width: active ? 28 : 8,
          height: 8,
          decoration: BoxDecoration(
            color: done
                ? const Color(0xFF4CAF50)
                : active
                    ? const Color(0xFF4FC3F7)
                    : Colors.white24,
            borderRadius: BorderRadius.circular(4),
          ),
        );
      }),
    );
  }
}
