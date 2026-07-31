import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:go_router/go_router.dart';
import '../../../shared/widgets/blink_character.dart';

class LoginSelectorScreen extends StatelessWidget {
  const LoginSelectorScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Container(
        decoration: const BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
            colors: [Color(0xFF060618), Color(0xFF0D0D2B), Color(0xFF12124A)],
          ),
        ),
        child: SafeArea(
          child: Row(
            children: [
              // ── Lado izquierdo: Blink + título ─────────────────────────────
              Expanded(
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    const BlinkCharacterWidget(width: 180, enableBounce: true)
                        .animate()
                        .scale(duration: 600.ms, curve: Curves.elasticOut),
                    const SizedBox(height: 24),
                    const Text(
                      '¡Bienvenido de vuelta!',
                      style: TextStyle(
                        fontFamily: 'Nunito',
                        fontWeight: FontWeight.w900,
                        fontSize: 26,
                        color: Colors.white,
                      ),
                      textAlign: TextAlign.center,
                    ).animate().fadeIn(delay: 300.ms),
                    const SizedBox(height: 8),
                    const Text(
                      '¿Quién eres?',
                      style: TextStyle(
                        fontFamily: 'Nunito',
                        fontSize: 16,
                        color: Colors.white54,
                      ),
                    ).animate().fadeIn(delay: 400.ms),
                  ],
                ),
              ),

              // ── Lado derecho: botones ────────────────────────────────────
              Expanded(
                child: Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 40),
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      _RoleCard(
                        emoji: '🧒',
                        title: 'Soy niño',
                        subtitle: 'Entra a tu aventura',
                        color: const Color(0xFF4FC3F7),
                        onTap: () => _showChildOptions(context),
                      )
                          .animate()
                          .fadeIn(delay: 500.ms)
                          .slideX(begin: 0.3, end: 0),
                      const SizedBox(height: 20),
                      _RoleCard(
                        emoji: '👨‍👩‍👧',
                        title: 'Soy papá / mamá',
                        subtitle: 'Panel de padres',
                        color: const Color(0xFFFFD700),
                        onTap: () => context.push('/parent-auth'),
                      )
                          .animate()
                          .fadeIn(delay: 650.ms)
                          .slideX(begin: 0.3, end: 0),
                      const SizedBox(height: 32),
                      TextButton(
                        onPressed: () => context.go('/world'),
                        child: const Text(
                          'Continuar en demo',
                          style: TextStyle(
                              color: Colors.white38, fontFamily: 'Nunito'),
                        ),
                      ).animate().fadeIn(delay: 800.ms),
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

  void _showChildOptions(BuildContext context) {
    showModalBottomSheet(
      context: context,
      backgroundColor: const Color(0xFF0D1B3E),
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      builder: (_) => Padding(
        padding: const EdgeInsets.all(32),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Text(
              '¿Es tu primera vez?',
              style: TextStyle(
                fontFamily: 'Nunito',
                fontWeight: FontWeight.w800,
                fontSize: 20,
                color: Colors.white,
              ),
            ),
            const SizedBox(height: 24),
            Row(
              children: [
                Expanded(
                  child: _BottomSheetBtn(
                    icon: Icons.star_rounded,
                    label: 'Crear cuenta',
                    color: const Color(0xFF4FC3F7),
                    onTap: () {
                      Navigator.pop(context);
                      context.push('/child-signup');
                    },
                  ),
                ),
                const SizedBox(width: 16),
                Expanded(
                  child: _BottomSheetBtn(
                    icon: Icons.login_rounded,
                    label: 'Ya tengo cuenta',
                    color: const Color(0xFF81C784),
                    onTap: () {
                      Navigator.pop(context);
                      context.push('/child-login');
                    },
                  ),
                ),
              ],
            ),
            const SizedBox(height: 16),
          ],
        ),
      ),
    );
  }
}

class _RoleCard extends StatelessWidget {
  const _RoleCard({
    required this.emoji,
    required this.title,
    required this.subtitle,
    required this.color,
    required this.onTap,
  });
  final String emoji;
  final String title;
  final String subtitle;
  final Color color;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.all(20),
        decoration: BoxDecoration(
          color: color.withOpacity(0.12),
          borderRadius: BorderRadius.circular(20),
          border: Border.all(color: color.withOpacity(0.5), width: 1.5),
        ),
        child: Row(
          children: [
            Text(emoji, style: const TextStyle(fontSize: 36)),
            const SizedBox(width: 16),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    title,
                    style: TextStyle(
                      fontFamily: 'Nunito',
                      fontWeight: FontWeight.w800,
                      fontSize: 18,
                      color: color,
                    ),
                  ),
                  Text(
                    subtitle,
                    style: const TextStyle(
                      fontFamily: 'Nunito',
                      fontSize: 13,
                      color: Colors.white54,
                    ),
                  ),
                ],
              ),
            ),
            Icon(Icons.arrow_forward_ios_rounded, color: color, size: 16),
          ],
        ),
      ),
    );
  }
}

class _BottomSheetBtn extends StatelessWidget {
  const _BottomSheetBtn({
    required this.icon,
    required this.label,
    required this.color,
    required this.onTap,
  });
  final IconData icon;
  final String label;
  final Color color;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 18),
        decoration: BoxDecoration(
          color: color.withOpacity(0.15),
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: color.withOpacity(0.4)),
        ),
        child: Column(
          children: [
            Icon(icon, color: color, size: 32),
            const SizedBox(height: 8),
            Text(
              label,
              style: TextStyle(
                fontFamily: 'Nunito',
                fontWeight: FontWeight.w700,
                fontSize: 13,
                color: color,
              ),
              textAlign: TextAlign.center,
            ),
          ],
        ),
      ),
    );
  }
}
