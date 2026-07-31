import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:go_router/go_router.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../../../shared/widgets/blink_character.dart';

/// Primera pantalla que ve el niño al abrir el juego por primera vez.
/// Pide el nombre de aventurero, crea una sesión anónima de Supabase
/// y un perfil con account_type='demo'.
class AdventurerNameScreen extends StatefulWidget {
  const AdventurerNameScreen({super.key});

  @override
  State<AdventurerNameScreen> createState() => _AdventurerNameScreenState();
}

class _AdventurerNameScreenState extends State<AdventurerNameScreen> {
  final _controller = TextEditingController();
  final _focusNode = FocusNode();

  bool _loading = false;
  String _errorMessage = '';
  bool _nameAvailable = false;
  bool _checking = false;

  static const _minLen = 3;
  static const _maxLen = 20;

  @override
  void dispose() {
    _controller.dispose();
    _focusNode.dispose();
    super.dispose();
  }

  String _sanitize(String raw) => raw.trim().replaceAll(RegExp(r'\s+'), ' ');

  Future<void> _checkName(String value) async {
    final name = _sanitize(value);
    if (name.length < _minLen) {
      setState(() {
        _nameAvailable = false;
        _errorMessage = '';
      });
      return;
    }
    setState(() {
      _checking = true;
      _errorMessage = '';
      _nameAvailable = false;
    });
    try {
      // Verificamos directamente en profiles con ILIKE (sin RPC para evitar
      // restricciones de auth en esta pantalla donde aún no hay sesión).
      final result = await Supabase.instance.client
          .from('profiles')
          .select('id')
          .ilike('display_name', name)
          .limit(1);
      final available = (result as List).isEmpty;
      if (mounted) {
        setState(() {
          _nameAvailable = available;
          _errorMessage = available
              ? ''
              : '¡Ese nombre ya está ocupado! 😅 Prueba con otro.';
          _checking = false;
        });
      }
    } catch (_) {
      // Sin sesión activa RLS puede bloquear la lectura; dejamos indeterminado.
      if (mounted)
        setState(() {
          _checking = false;
          _nameAvailable = false;
        });
    }
  }

  Future<void> _start() async {
    final name = _sanitize(_controller.text);
    if (name.length < _minLen) {
      setState(
          () => _errorMessage = 'Tu nombre necesita al menos $_minLen letras.');
      return;
    }

    setState(() {
      _loading = true;
      _errorMessage = '';
    });

    final client = Supabase.instance.client;

    try {
      // 1. Sesión anónima primero (necesaria para que RLS permita leer profiles)
      final authRes = await client.auth.signInAnonymously();
      final userId = authRes.user?.id;
      if (userId == null) throw Exception('No se pudo crear sesión');

      // 2. Verificar disponibilidad del nombre (ya con sesión → RLS funciona)
      final existing = await client
          .from('profiles')
          .select('id')
          .ilike('display_name', name)
          .limit(1);
      if ((existing as List).isNotEmpty) {
        await client.auth.signOut();
        if (mounted) {
          setState(() {
            _errorMessage = '¡Ese nombre ya está ocupado! 😅 Prueba con otro.';
            _nameAvailable = false;
            _loading = false;
          });
        }
        return;
      }

      // 3. Crear perfil demo
      await client.from('profiles').insert({
        'id': userId,
        'role': 'child',
        'display_name': name,
        'account_type': 'demo',
      });

      // 4. Crear cartera vacía
      await client.from('wallets').insert({
        'user_id': userId,
        'total_coins': 0,
      });

      if (mounted) context.go('/tutorial');
    } on PostgrestException catch (e) {
      final msg = e.code == '23505'
          ? '¡Ese nombre ya está ocupado! 😅 Prueba con otro.'
          : 'Error al guardar: ${e.message}';
      if (mounted)
        setState(() {
          _errorMessage = msg;
          _loading = false;
        });
    } on AuthException catch (e) {
      if (mounted)
        setState(() {
          _errorMessage = 'Error auth: ${e.message}';
          _loading = false;
        });
    } catch (e) {
      if (mounted)
        setState(() {
          _errorMessage = 'Error inesperado: $e';
          _loading = false;
        });
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Container(
        decoration: const BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
            colors: [Color(0xFF0D0D2B), Color(0xFF1A237E), Color(0xFF0D0D2B)],
          ),
        ),
        child: SafeArea(
          child: Stack(
            children: [
              // Estrellas
              ...List.generate(20, (i) => _Star(seed: i)),

              // Contenido centrado
              Center(
                child: SingleChildScrollView(
                  padding: const EdgeInsets.symmetric(horizontal: 32),
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      // Blink
                      const BlinkCharacterWidget(width: 140, enableBounce: true)
                          .animate()
                          .scale(duration: 600.ms, curve: Curves.elasticOut),

                      const SizedBox(height: 20),

                      // Globo con saludo
                      const _SpeechBubble(
                        text:
                            '¡Hola! Soy Blink 👋\n¿Cómo te llamas, aventurero?',
                      ).animate().fadeIn(delay: 300.ms, duration: 400.ms),

                      const SizedBox(height: 32),

                      // Label
                      const Text(
                        'Nombre de Aventurero',
                        style: TextStyle(
                          fontFamily: 'Nunito',
                          fontWeight: FontWeight.w800,
                          fontSize: 20,
                          color: Colors.white,
                        ),
                      ).animate().fadeIn(delay: 500.ms),

                      const SizedBox(height: 12),

                      // Campo de texto
                      _NameField(
                        controller: _controller,
                        focusNode: _focusNode,
                        maxLength: _maxLen,
                        checking: _checking,
                        available: _nameAvailable,
                        onChanged: (v) {
                          setState(() {
                            _errorMessage = '';
                            _nameAvailable = false;
                          });
                          if (_sanitize(v).length >= _minLen) _checkName(v);
                        },
                        onSubmitted: (_) => _start(),
                      ).animate().fadeIn(delay: 600.ms),

                      const SizedBox(height: 12),

                      // Error / disponibilidad
                      AnimatedSwitcher(
                        duration: const Duration(milliseconds: 250),
                        child: _errorMessage.isNotEmpty
                            ? _StatusChip(
                                key: const ValueKey('err'),
                                text: _errorMessage,
                                color: const Color(0xFFFF5252),
                                icon: Icons.cancel_rounded,
                              )
                            : _nameAvailable &&
                                    _controller.text.trim().length >= _minLen
                                ? const _StatusChip(
                                    key: ValueKey('ok'),
                                    text: '¡Nombre disponible! 🎉',
                                    color: Color(0xFF4CAF50),
                                    icon: Icons.check_circle_rounded,
                                  )
                                : const SizedBox.shrink(key: ValueKey('none')),
                      ),

                      const SizedBox(height: 28),

                      // Botón principal
                      _StartButton(
                        loading: _loading,
                        enabled: _nameAvailable && !_loading,
                        onTap: _start,
                      ).animate().fadeIn(delay: 700.ms),

                      const SizedBox(height: 8),
                      const Text(
                        'Mín. 3 letras · Solo para ti, ¡elige bien!',
                        textAlign: TextAlign.center,
                        style: TextStyle(
                          color: Colors.white38,
                          fontSize: 12,
                          fontFamily: 'Nunito',
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

// ─── Widgets auxiliares ───────────────────────────────────────────────────────

class _SpeechBubble extends StatelessWidget {
  const _SpeechBubble({required this.text});
  final String text;

  @override
  Widget build(BuildContext context) {
    return Stack(
      clipBehavior: Clip.none,
      alignment: Alignment.bottomCenter,
      children: [
        Container(
          padding: const EdgeInsets.fromLTRB(20, 16, 20, 16),
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(18),
            boxShadow: const [
              BoxShadow(
                  color: Colors.black38, blurRadius: 16, offset: Offset(0, 6))
            ],
          ),
          child: Text(
            text,
            textAlign: TextAlign.center,
            style: const TextStyle(
              fontFamily: 'Nunito',
              fontWeight: FontWeight.w700,
              fontSize: 17,
              color: Color(0xFF1A1A2E),
              height: 1.4,
            ),
          ),
        ),
        // Cola apuntando hacia arriba (hacia Blink)
        Positioned(
          top: -12,
          child: CustomPaint(
            size: const Size(24, 14),
            painter: _UpTailPainter(),
          ),
        ),
      ],
    );
  }
}

class _UpTailPainter extends CustomPainter {
  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()..color = Colors.white;
    final path = Path()
      ..moveTo(0, size.height)
      ..lineTo(size.width, size.height)
      ..lineTo(size.width / 2, 0)
      ..close();
    canvas.drawPath(path, paint);
  }

  @override
  bool shouldRepaint(_) => false;
}

class _NameField extends StatelessWidget {
  const _NameField({
    required this.controller,
    required this.focusNode,
    required this.maxLength,
    required this.checking,
    required this.available,
    required this.onChanged,
    required this.onSubmitted,
  });
  final TextEditingController controller;
  final FocusNode focusNode;
  final int maxLength;
  final bool checking;
  final bool available;
  final ValueChanged<String> onChanged;
  final ValueChanged<String> onSubmitted;

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        color: Colors.white.withValues(alpha: 0.95),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: available ? const Color(0xFF4CAF50) : Colors.white24,
          width: 2,
        ),
        boxShadow: const [
          BoxShadow(color: Colors.black26, blurRadius: 8, offset: Offset(0, 3))
        ],
      ),
      child: TextField(
        controller: controller,
        focusNode: focusNode,
        maxLength: maxLength,
        textAlign: TextAlign.center,
        textInputAction: TextInputAction.done,
        onChanged: onChanged,
        onSubmitted: onSubmitted,
        style: const TextStyle(
          color: Color(0xFF1A1A2E),
          fontFamily: 'Nunito',
          fontWeight: FontWeight.w700,
          fontSize: 22,
          letterSpacing: 1,
        ),
        decoration: InputDecoration(
          hintText: '¿Tu nombre de héroe?',
          hintStyle: const TextStyle(
              color: Color(0xFF9EA3B8), fontSize: 18, fontFamily: 'Nunito'),
          counterStyle: const TextStyle(color: Color(0xFF9EA3B8), fontSize: 11),
          border: InputBorder.none,
          filled: true,
          fillColor: Colors.transparent,
          contentPadding:
              const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
          suffixIcon: checking
              ? const Padding(
                  padding: EdgeInsets.all(14),
                  child: SizedBox(
                    width: 20,
                    height: 20,
                    child: CircularProgressIndicator(
                        color: Colors.white54, strokeWidth: 2),
                  ),
                )
              : available
                  ? const Icon(Icons.check_circle_rounded,
                      color: Color(0xFF4CAF50), size: 28)
                  : const Icon(Icons.edit_rounded,
                      color: Color(0xFF9EA3B8), size: 22),
        ),
      ),
    );
  }
}

class _StatusChip extends StatelessWidget {
  const _StatusChip(
      {super.key, required this.text, required this.color, required this.icon});
  final String text;
  final Color color;
  final IconData icon;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.15),
        borderRadius: BorderRadius.circular(24),
        border: Border.all(color: color.withValues(alpha: 0.4)),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, color: color, size: 18),
          const SizedBox(width: 8),
          Flexible(
            child: Text(
              text,
              style: TextStyle(
                  color: color,
                  fontFamily: 'Nunito',
                  fontWeight: FontWeight.w600,
                  fontSize: 13),
            ),
          ),
        ],
      ),
    );
  }
}

class _StartButton extends StatelessWidget {
  const _StartButton(
      {required this.loading, required this.enabled, required this.onTap});
  final bool loading;
  final bool enabled;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: enabled ? onTap : null,
      child: AnimatedOpacity(
        duration: const Duration(milliseconds: 250),
        opacity: enabled ? 1.0 : 0.45,
        child: Container(
          width: double.infinity,
          padding: const EdgeInsets.symmetric(vertical: 16),
          decoration: BoxDecoration(
            gradient: const LinearGradient(
              colors: [Color(0xFFFFD700), Color(0xFFFF8C00)],
            ),
            borderRadius: BorderRadius.circular(30),
            boxShadow: enabled
                ? const [
                    BoxShadow(
                        color: Color(0x66FFD700),
                        blurRadius: 18,
                        offset: Offset(0, 4))
                  ]
                : null,
          ),
          child: loading
              ? const Center(
                  child: SizedBox(
                    width: 24,
                    height: 24,
                    child: CircularProgressIndicator(
                        color: Colors.white, strokeWidth: 2.5),
                  ),
                )
              : const Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Icon(Icons.rocket_launch_rounded,
                        color: Colors.white, size: 22),
                    SizedBox(width: 10),
                    Text(
                      '¡Comenzar aventura!',
                      style: TextStyle(
                        fontFamily: 'Nunito',
                        fontWeight: FontWeight.w900,
                        fontSize: 18,
                        color: Colors.white,
                      ),
                    ),
                  ],
                ),
        ),
      ),
    ).animate(onPlay: (c) => enabled ? c.repeat(reverse: true) : null).scaleXY(
        begin: 1.0,
        end: enabled ? 1.02 : 1.0,
        duration: 900.ms,
        curve: Curves.easeInOut);
  }
}

class _Star extends StatelessWidget {
  const _Star({required this.seed});
  final int seed;

  @override
  Widget build(BuildContext context) {
    final size = MediaQuery.of(context).size;
    final rng = seed * 1693 + 17;
    final left = (rng % 100) / 100 * size.width;
    final top = ((rng * 37) % 100) / 100 * size.height;
    final radius = 1.0 + (rng % 3).toDouble();
    final opacity = 0.2 + (rng % 5) / 12.0;

    return Positioned(
      left: left,
      top: top,
      child: Opacity(
        opacity: opacity,
        child: Container(
          width: radius * 2,
          height: radius * 2,
          decoration:
              const BoxDecoration(color: Colors.white, shape: BoxShape.circle),
        ),
      )
          .animate(
              onPlay: (c) => c.repeat(reverse: true),
              delay: Duration(milliseconds: (seed * 317) % 1500))
          .fadeIn(duration: Duration(milliseconds: 800 + (seed * 200) % 600)),
    );
  }
}
