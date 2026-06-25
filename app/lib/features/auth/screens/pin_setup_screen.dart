import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:go_router/go_router.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../../../shared/widgets/blink_character.dart';

/// Pantalla estilo cajero automático para que el niño configure su PIN de
/// 6 dígitos por primera vez (después de que el padre ligó la cuenta).
class PinSetupScreen extends StatefulWidget {
  const PinSetupScreen({super.key});

  @override
  State<PinSetupScreen> createState() => _PinSetupScreenState();
}

class _PinSetupScreenState extends State<PinSetupScreen> {
  static const _pinLength = 6;

  String _pin        = '';
  String _confirmPin = '';
  bool   _confirming = false; // true = segunda pantalla (confirmar PIN)
  bool   _loading    = false;
  String _errorMsg   = '';

  void _onDigit(String d) {
    setState(() {
      _errorMsg = '';
      if (!_confirming) {
        if (_pin.length < _pinLength) _pin += d;
        if (_pin.length == _pinLength) {
          // Automáticamente pasa a confirmar
          Future.delayed(const Duration(milliseconds: 300), () {
            if (mounted) setState(() => _confirming = true);
          });
        }
      } else {
        if (_confirmPin.length < _pinLength) _confirmPin += d;
        if (_confirmPin.length == _pinLength) {
          Future.delayed(const Duration(milliseconds: 200), () => _checkAndSave());
        }
      }
    });
  }

  void _onDelete() {
    setState(() {
      _errorMsg = '';
      if (_confirming) {
        if (_confirmPin.isNotEmpty) {
          _confirmPin = _confirmPin.substring(0, _confirmPin.length - 1);
        }
      } else {
        if (_pin.isNotEmpty) {
          _pin = _pin.substring(0, _pin.length - 1);
        }
      }
    });
  }

  void _reset() {
    setState(() {
      _pin        = '';
      _confirmPin = '';
      _confirming = false;
      _errorMsg   = '';
    });
  }

  Future<void> _checkAndSave() async {
    if (_pin != _confirmPin) {
      setState(() {
        _errorMsg   = 'Los PINs no coinciden. Inténtalo de nuevo.';
        _confirmPin = '';
      });
      return;
    }

    setState(() => _loading = true);
    try {
      final userId = Supabase.instance.client.auth.currentUser?.id;
      if (userId == null) throw Exception('Sin sesión');

      // Guardar PIN en Supabase y localmente
      await Supabase.instance.client
          .from('profiles')
          .update({'pin_hash': _pin})
          .eq('id', userId);

      final prefs = await SharedPreferences.getInstance();
      await prefs.setString('child_pin', _pin);

      if (mounted) context.go('/tutorial');
    } catch (_) {
      if (mounted) {
        setState(() {
          _errorMsg = 'No se pudo guardar tu PIN. Verifica tu conexión.';
          _loading  = false;
          _confirmPin = '';
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final currentPin = _confirming ? _confirmPin : _pin;

    return Scaffold(
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
              const SizedBox(height: 24),

              // Blink
              BlinkCharacterWidget(width: 100, enableBounce: true)
                  .animate()
                  .scale(duration: 600.ms, curve: Curves.elasticOut),

              const SizedBox(height: 16),

              // Instrucción
              AnimatedSwitcher(
                duration: const Duration(milliseconds: 350),
                child: Text(
                  key: ValueKey(_confirming),
                  _confirming
                      ? '¡Perfecto! Ahora escríbelo\notra vez para confirmarlo 🔒'
                      : '¡Crea tu clave secreta!\nElige 6 números que recuerdes 🔑',
                  textAlign: TextAlign.center,
                  style: const TextStyle(
                    fontFamily: 'Nunito',
                    fontWeight: FontWeight.w800,
                    fontSize: 20,
                    color: Colors.white,
                    height: 1.3,
                  ),
                ),
              ),

              const SizedBox(height: 28),

              // Puntos del PIN
              Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: List.generate(_pinLength, (i) {
                  final filled = i < currentPin.length;
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
              ),

              const SizedBox(height: 16),

              // Error
              AnimatedSwitcher(
                duration: const Duration(milliseconds: 250),
                child: _errorMsg.isNotEmpty
                    ? Container(
                        key: const ValueKey('err'),
                        margin: const EdgeInsets.symmetric(horizontal: 32),
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
                      )
                    : const SizedBox.shrink(key: ValueKey('none')),
              ),

              const Spacer(),

              // Teclado numérico
              if (!_loading)
                _NumPad(onDigit: _onDigit, onDelete: _onDelete, onReset: _reset, showReset: _confirming),

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

// ─── Teclado estilo cajero ────────────────────────────────────────────────────

class _NumPad extends StatelessWidget {
  const _NumPad({
    required this.onDigit,
    required this.onDelete,
    required this.onReset,
    required this.showReset,
  });
  final ValueChanged<String> onDigit;
  final VoidCallback         onDelete;
  final VoidCallback         onReset;
  final bool                 showReset;

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
          // Última fila: reset / 0 / borrar
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceEvenly,
            children: [
              showReset
                  ? _ActionKey(
                      icon: Icons.refresh_rounded,
                      color: Colors.white38,
                      onTap: onReset,
                    )
                  : const SizedBox(width: 72),
              _NumKey(digit: '0', onTap: () => onDigit('0')),
              _ActionKey(
                icon: Icons.backspace_rounded,
                color: Colors.white54,
                onTap: onDelete,
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
      )
          .animate(onPlay: (c) => c.reset())
          .scaleXY(begin: 1.0, end: 0.92, duration: 80.ms, curve: Curves.easeIn),
    );
  }
}

class _ActionKey extends StatelessWidget {
  const _ActionKey({required this.icon, required this.color, required this.onTap});
  final IconData     icon;
  final Color        color;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: SizedBox(
        width: 72,
        height: 72,
        child: Center(child: Icon(icon, color: color, size: 30)),
      ),
    );
  }
}
