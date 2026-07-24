import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:go_router/go_router.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../../../shared/widgets/blink_character.dart';

/// Pantalla de entrada del PIN de 6 dígitos para usuarios con cuenta completa.
/// Estilo cajero automático. Se muestra al abrir el juego si la cuenta ya
/// está ligada y el PIN fue configurado.
class PinEntryScreen extends StatefulWidget {
  const PinEntryScreen({super.key});

  @override
  State<PinEntryScreen> createState() => _PinEntryScreenState();
}

class _PinEntryScreenState extends State<PinEntryScreen> {
  static const _pinLength  = 6;
  static const _maxAttempts = 3;

  String _pin      = '';
  int    _attempts = 0;
  bool   _loading  = false;
  bool   _shaking  = false;
  String _errorMsg = '';
  String _displayName = '';

  @override
  void initState() {
    super.initState();
    _loadDisplayName();
  }

  Future<void> _loadDisplayName() async {
    try {
      final userId = Supabase.instance.client.auth.currentUser?.id;
      if (userId == null) return;
      final data = await Supabase.instance.client
          .from('profiles')
          .select('display_name')
          .eq('id', userId)
          .maybeSingle();
      if (mounted) setState(() => _displayName = data?['display_name'] as String? ?? '');
    } catch (_) {}
  }

  void _onDigit(String d) {
    if (_pin.length >= _pinLength || _shaking) return;
    setState(() { _pin += d; _errorMsg = ''; });
    if (_pin.length == _pinLength) {
      Future.delayed(const Duration(milliseconds: 200), _verify);
    }
  }

  void _onDelete() {
    if (_pin.isEmpty) return;
    setState(() => _pin = _pin.substring(0, _pin.length - 1));
  }

  Future<void> _verify() async {
    setState(() => _loading = true);

    try {
      // Verificar contra SharedPreferences primero (más rápido)
      final prefs = await SharedPreferences.getInstance();
      String? stored = prefs.getString('child_pin');

      // Si no está local, leer de Supabase
      if (stored == null || stored.isEmpty) {
        final userId = Supabase.instance.client.auth.currentUser?.id;
        if (userId != null) {
          final data = await Supabase.instance.client
              .from('profiles')
              .select('pin_hash')
              .eq('id', userId)
              .maybeSingle();
          stored = data?['pin_hash'] as String?;
          if (stored != null) await prefs.setString('child_pin', stored);
        }
      }

      if (stored == _pin) {
        if (mounted) context.go('/world');
        return;
      }

      // PIN incorrecto
      _attempts++;
      if (!mounted) return;
      setState(() {
        _loading  = false;
        _pin      = '';
        _shaking  = true;
        _errorMsg = _attempts >= _maxAttempts
            ? 'Demasiados intentos. Pídele a tu papá que te ayude.'
            : 'PIN incorrecto 🔐 Te quedan ${_maxAttempts - _attempts} intento${_maxAttempts - _attempts == 1 ? '' : 's'}.';
      });
      await Future.delayed(const Duration(milliseconds: 600));
      if (mounted) setState(() => _shaking = false);
    } catch (_) {
      if (mounted) {
        setState(() {
          _loading  = false;
          _pin      = '';
          _errorMsg = 'No se pudo verificar. ¿Tienes internet?';
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
            end:   Alignment.bottomCenter,
            colors: [Color(0xFF0D0D2B), Color(0xFF1A237E), Color(0xFF0D0D2B)],
          ),
        ),
        child: SafeArea(
          child: Column(
            children: [
              const SizedBox(height: 16),

              // Blink
              BlinkCharacterWidget(width: 90, enableBounce: true)
                  .animate()
                  .scale(duration: 600.ms, curve: Curves.elasticOut),

              const SizedBox(height: 8),

              // Saludo personalizado
              AnimatedSwitcher(
                duration: const Duration(milliseconds: 300),
                child: Text(
                  key: ValueKey(_displayName),
                  _displayName.isNotEmpty
                      ? '¡Hola, $_displayName! 👋\nPon tu clave secreta'
                      : '¡Bienvenido de vuelta! 👋\nPon tu clave secreta',
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

              const SizedBox(height: 16),

              // Dots del PIN con shake si hay error
              _PinDots(
                pin:     _pin,
                length:  _pinLength,
                shaking: _shaking,
              ),

              const SizedBox(height: 8),

              // Mensaje de error
              AnimatedSwitcher(
                duration: const Duration(milliseconds: 250),
                child: _errorMsg.isNotEmpty
                    ? Padding(
                        key: const ValueKey('err'),
                        padding: const EdgeInsets.symmetric(horizontal: 32),
                        child: Container(
                          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                          decoration: BoxDecoration(
                            color: const Color(0xFFFF5252).withValues(alpha: 0.15),
                            borderRadius: BorderRadius.circular(12),
                          ),
                          child: Text(
                            _errorMsg,
                            textAlign: TextAlign.center,
                            style: const TextStyle(
                              color: Color(0xFFFF5252),
                              fontFamily: 'Nunito',
                              fontWeight: FontWeight.w600,
                              fontSize: 13,
                            ),
                          ),
                        ),
                      )
                    : const SizedBox.shrink(key: ValueKey('none')),
              ),

              const Spacer(),

              if (!_loading)
                _NumPad(onDigit: _onDigit, onDelete: _onDelete),

              if (_loading)
                const Padding(
                  padding: EdgeInsets.all(40),
                  child: CircularProgressIndicator(color: Colors.white),
                ),

              const SizedBox(height: 24),
            ],
          ),
        ),
      ),
    );
  }
}

// ─── Puntos con animación shake ───────────────────────────────────────────────

class _PinDots extends StatelessWidget {
  const _PinDots({required this.pin, required this.length, required this.shaking});
  final String pin;
  final int    length;
  final bool   shaking;

  @override
  Widget build(BuildContext context) {
    final dots = Row(
      mainAxisAlignment: MainAxisAlignment.center,
      children: List.generate(length, (i) {
        final filled = i < pin.length;
        return AnimatedContainer(
          duration: const Duration(milliseconds: 200),
          margin: const EdgeInsets.symmetric(horizontal: 8),
          width:  filled ? 22 : 18,
          height: filled ? 22 : 18,
          decoration: BoxDecoration(
            shape: BoxShape.circle,
            color: filled
                ? const Color(0xFFFFD700)
                : Colors.white.withValues(alpha: 0.2),
            border: Border.all(
              color: filled ? const Color(0xFFFFD700) : Colors.white38,
              width: 2,
            ),
            boxShadow: filled
                ? [const BoxShadow(color: Color(0x66FFD700), blurRadius: 8)]
                : null,
          ),
        );
      }),
    );

    if (!shaking) return dots;

    return dots
        .animate()
        .shake(hz: 4, offset: const Offset(8, 0), duration: 600.ms);
  }
}

// ─── Teclado numérico ─────────────────────────────────────────────────────────

class _NumPad extends StatelessWidget {
  const _NumPad({required this.onDigit, required this.onDelete});
  final ValueChanged<String> onDigit;
  final VoidCallback         onDelete;

  @override
  Widget build(BuildContext context) {
    const rows = [
      ['1', '2', '3'],
      ['4', '5', '6'],
      ['7', '8', '9'],
    ];
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 48),
      child: Column(
        children: [
          ...rows.map((row) => Padding(
            padding: const EdgeInsets.only(bottom: 12),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceEvenly,
              children: row.map((d) => _NumKey(digit: d, onTap: () => onDigit(d))).toList(),
            ),
          )),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceEvenly,
            children: [
              const SizedBox(width: 72),
              _NumKey(digit: '0', onTap: () => onDigit('0')),
              GestureDetector(
                onTap: onDelete,
                child: const SizedBox(
                  width: 72,
                  height: 72,
                  child: Center(
                    child: Icon(Icons.backspace_rounded, color: Colors.white54, size: 30),
                  ),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class _NumKey extends StatelessWidget {
  const _NumKey({required this.digit, required this.onTap});
  final String       digit;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        width: 72,
        height: 72,
        decoration: BoxDecoration(
          color: Colors.white.withValues(alpha: 0.1),
          shape: BoxShape.circle,
          border: Border.all(color: Colors.white24, width: 1.5),
        ),
        child: Center(
          child: Text(
            digit,
            style: const TextStyle(
              fontFamily: 'Nunito',
              fontWeight: FontWeight.w800,
              fontSize: 28,
              color: Colors.white,
            ),
          ),
        ),
      ),
    );
  }
}
