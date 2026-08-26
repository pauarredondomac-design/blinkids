import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../../data/models/profile.dart';
import '../providers/profile_provider.dart';
import '../providers/character_provider.dart';
import '../providers/demo_progress_provider.dart';
import '../providers/world_provider.dart';
import '../providers/auth_provider.dart';
import 'blink_character.dart';
import 'child_notification_bell.dart';
import 'coin_display.dart';
import 'game_popup.dart';
import '../../features/worlds/vestidor/vestidor_screen.dart';
import '../../features/worlds/world_selector_screen.dart';
import '../../features/worlds/mercado/mercado_screen.dart';
import '../providers/wallet_provider.dart';
import '../providers/salary_provider.dart';
import '../providers/fuel_provider.dart';

// ─────────────────────────────────────────────────────────────────────────────
// HUD compartido por todos los mundos (Galaxia, Bosque, Mar...) — mismo
// panel izquierdo (perfil/XP/vestidor), panel derecho (combustible/Marte/
// cambiar mundo) y barra central (monedas/mercado/notificaciones) en todos.
// Solo cambian el fondo y los edificios de cada mundo.
// ─────────────────────────────────────────────────────────────────────────────

// ─────────────────────────────────────────────────────────────────────────────
// Card reutilizable para los paneles laterales — con glow opcional
// ─────────────────────────────────────────────────────────────────────────────
class PanelCard extends StatelessWidget {
  const PanelCard({
    super.key,
    required this.child,
    required this.borderColor,
    this.glowColor = Colors.transparent,
  });
  final Widget child;
  final Color borderColor;
  final Color glowColor;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(10),
      decoration: BoxDecoration(
        color: const Color(0xFF0A1628).withOpacity(0.85),
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: borderColor, width: 1.2),
        boxShadow: [
          if (glowColor != Colors.transparent)
            BoxShadow(
              color: glowColor,
              blurRadius: 14,
              spreadRadius: 2,
            ),
        ],
      ),
      child: child,
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// Panel izquierdo — perfil (tap abre vestuario), nivel, estrellas, XP, opciones
// ─────────────────────────────────────────────────────────────────────────────
class WorldLeftPanel extends ConsumerWidget {
  const WorldLeftPanel({super.key, required this.profile});
  final Profile? profile;

  void _showWardrobeDialog(BuildContext context) {
    showVestidorDialog(context);
  }

  void _showOptionsMenu(BuildContext context, WidgetRef ref) {
    final supaUser = Supabase.instance.client.auth.currentUser;
    final isDemo = supaUser == null || (supaUser.isAnonymous == true);
    final profile = ref.read(currentProfileProvider).valueOrNull;
    final isChild = !isDemo && (profile?.role == UserRole.child);

    showDialog(
      context: context,
      builder: (ctx) => _WorldOptionsDialog(
        isDemo: isDemo,
        isChild: isChild,
        onSignIn: () {
          Navigator.pop(ctx);
          context.push('/welcome');
        },
        onLinkParent: () {
          Navigator.pop(ctx);
          showDialog(
              context: context, builder: (_) => const RedeemCodeDialog());
        },
        onSignOut: () async {
          Navigator.pop(ctx);
          await ref.read(authRepositoryProvider).signOut();
          if (context.mounted) context.go('/welcome');
        },
      ),
    );
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final liveProfile =
        ref.watch(currentProfileProvider).valueOrNull ?? profile;
    final character = ref.watch(currentCharacterProvider).valueOrNull;
    final demoState = ref.watch(demoProgressProvider);
    final isDemo = DemoStore.isActive;
    final xp = isDemo ? demoState.xp : (character?.xp ?? 0);
    final level = isDemo ? (demoState.xp ~/ 500) + 1 : (character?.level ?? 1);
    const xpPerLevel = 500;
    final xpProgress = (xp % xpPerLevel) / xpPerLevel;
    final xpInLevel = xp % xpPerLevel;
    final filledStars = (xpProgress * 5).floor().clamp(0, 5);

    return Container(
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.centerLeft,
          end: Alignment.centerRight,
          colors: [
            const Color(0xFF020D1F).withOpacity(0.92),
            const Color(0xFF020D1F).withOpacity(0.78),
            Colors.transparent,
          ],
          stops: const [0.0, 0.65, 1.0],
        ),
      ),
      padding: const EdgeInsets.fromLTRB(10, 10, 10, 10),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          // ── Card de perfil — tap abre vestuario ───────────────────────
          GestureDetector(
            onTap: () => _showWardrobeDialog(context),
            child: PanelCard(
              borderColor: const Color(0xFF4FC3F7).withOpacity(0.55),
              glowColor: const Color(0xFF4FC3F7).withOpacity(0.12),
              child: Column(
                children: [
                  Container(
                    width: 72,
                    height: 72,
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      border: Border.all(
                          color: const Color(0xFF4FC3F7).withOpacity(0.70),
                          width: 2),
                      color: const Color(0xFF0D1B3E),
                      boxShadow: [
                        BoxShadow(
                            color: const Color(0xFF4FC3F7).withOpacity(0.30),
                            blurRadius: 10,
                            spreadRadius: 1)
                      ],
                    ),
                    clipBehavior: Clip.antiAlias,
                    child: const OverflowBox(
                      maxWidth: 70,
                      maxHeight: 220,
                      alignment: Alignment(0.05, -0.70),
                      child: BlinkCharacterWidget(
                        width: 70,
                        enableBounce: false,
                      ),
                    ),
                  ),
                  const SizedBox(height: 6),
                  Text(
                    liveProfile?.displayName ?? 'Blink',
                    style: const TextStyle(
                        color: Colors.white,
                        fontSize: 13,
                        fontWeight: FontWeight.bold),
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                    textAlign: TextAlign.center,
                  ),
                  const SizedBox(height: 1),
                  Container(
                    padding:
                        const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                    decoration: BoxDecoration(
                      gradient: const LinearGradient(
                          colors: [Color(0xFF0277BD), Color(0xFF01579B)]),
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: Text('Nivel $level',
                        style: const TextStyle(
                            color: Colors.white,
                            fontSize: 10,
                            fontWeight: FontWeight.w800,
                            letterSpacing: 0.5)),
                  ),
                  const SizedBox(height: 7),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: List.generate(
                        5,
                        (i) => Padding(
                              padding:
                                  const EdgeInsets.symmetric(horizontal: 1.5),
                              child: Icon(
                                i < filledStars
                                    ? Icons.star_rounded
                                    : Icons.star_outline_rounded,
                                color: i < filledStars
                                    ? Colors.amber
                                    : Colors.white24,
                                size: 13,
                              ),
                            )),
                  ),
                  const SizedBox(height: 5),
                  ClipRRect(
                    borderRadius: BorderRadius.circular(4),
                    child: LinearProgressIndicator(
                      value: xpProgress,
                      backgroundColor: Colors.white.withOpacity(0.10),
                      valueColor:
                          const AlwaysStoppedAnimation(Color(0xFF4FC3F7)),
                      minHeight: 5,
                    ),
                  ),
                  const SizedBox(height: 3),
                  Text('$xpInLevel / $xpPerLevel XP',
                      style: TextStyle(
                          color: Colors.white.withOpacity(0.40), fontSize: 9)),
                ],
              ),
            ),
          ),

          const Spacer(),

          // ── Botón tuerca de opciones ───────────────────────────────────
          GestureDetector(
            onTap: () => _showOptionsMenu(context, ref),
            child: PanelCard(
              borderColor: const Color(0xFF4FC3F7).withOpacity(0.30),
              glowColor: Colors.transparent,
              child: Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(Icons.settings_rounded,
                      color: const Color(0xFF4FC3F7).withOpacity(0.80),
                      size: 20),
                  const SizedBox(width: 6),
                  Text('Opciones',
                      style: TextStyle(
                          color: Colors.white.withOpacity(0.70),
                          fontSize: 10,
                          fontWeight: FontWeight.w600)),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}

// Diálogo de opciones — carga el nombre del papá vinculado de forma asíncrona
class _WorldOptionsDialog extends StatefulWidget {
  const _WorldOptionsDialog({
    required this.isDemo,
    required this.isChild,
    required this.onSignIn,
    required this.onLinkParent,
    required this.onSignOut,
  });
  final bool isDemo;
  final bool isChild;
  final VoidCallback onSignIn;
  final VoidCallback onLinkParent;
  final VoidCallback onSignOut;

  @override
  State<_WorldOptionsDialog> createState() => _WorldOptionsDialogState();
}

class _WorldOptionsDialogState extends State<_WorldOptionsDialog> {
  String? _parentName;
  bool _loaded = false;

  @override
  void initState() {
    super.initState();
    if (widget.isChild) {
      _loadParentLink();
    } else {
      _loaded = true;
    }
  }

  Future<void> _loadParentLink() async {
    final userId = Supabase.instance.client.auth.currentUser?.id;
    if (userId == null) {
      if (mounted) setState(() => _loaded = true);
      return;
    }
    try {
      final link = await Supabase.instance.client
          .from('parent_child')
          .select('parent_id')
          .eq('child_id', userId)
          .maybeSingle();
      if (link != null) {
        final parentId = link['parent_id'] as String?;
        if (parentId != null) {
          final p = await Supabase.instance.client
              .from('profiles')
              .select('display_name')
              .eq('id', parentId)
              .maybeSingle();
          if (mounted) {
            setState(() {
              _parentName = p?['display_name'] as String?;
            });
          }
        }
      }
    } catch (_) {}
    if (mounted) setState(() => _loaded = true);
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      backgroundColor: const Color(0xFF0D1B3E),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
      title: const Row(
        children: [
          Icon(Icons.settings_rounded, color: Color(0xFF4FC3F7), size: 20),
          SizedBox(width: 8),
          Text('Opciones',
              style: TextStyle(
                  color: Colors.white,
                  fontSize: 16,
                  fontWeight: FontWeight.bold)),
        ],
      ),
      content: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          if (widget.isDemo)
            _OptionItem(
                icon: Icons.login_rounded,
                label: 'Iniciar sesión',
                onTap: widget.onSignIn),
          if (!widget.isDemo) ...[
            if (widget.isChild) ...[
              if (!_loaded)
                const Padding(
                  padding: EdgeInsets.symmetric(vertical: 8),
                  child: SizedBox(
                      height: 20,
                      width: 20,
                      child: CircularProgressIndicator(
                          strokeWidth: 2, color: Color(0xFF4FC3F7))),
                )
              else if (_parentName != null)
                _OptionItem(
                  icon: Icons.verified_user_rounded,
                  label: 'Vinculado con $_parentName',
                  color: const Color(0xFF4CAF50),
                  onTap: () {},
                )
              else
                _OptionItem(
                  icon: Icons.link_rounded,
                  label: 'Vincular a papás',
                  onTap: widget.onLinkParent,
                ),
            ],
            _OptionItem(
              icon: Icons.logout_rounded,
              label: 'Cerrar sesión',
              color: const Color(0xFFEF4444),
              onTap: widget.onSignOut,
            ),
          ],
        ],
      ),
    );
  }
}

// Ítem de opción reutilizable para el menú de opciones
class _OptionItem extends StatelessWidget {
  const _OptionItem(
      {required this.icon,
      required this.label,
      required this.onTap,
      this.color});
  final IconData icon;
  final String label;
  final VoidCallback onTap;
  final Color? color;

  @override
  Widget build(BuildContext context) {
    final c = color ?? Colors.white;
    return ListTile(
      leading: Icon(icon, color: c, size: 20),
      title: Text(label,
          style:
              TextStyle(color: c, fontSize: 13, fontWeight: FontWeight.w600)),
      onTap: onTap,
      dense: true,
      contentPadding: const EdgeInsets.symmetric(horizontal: 4),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// Diálogo para que el hijo ingrese el código de invitación del padre
// ─────────────────────────────────────────────────────────────────────────────
class RedeemCodeDialog extends StatefulWidget {
  const RedeemCodeDialog();

  @override
  State<RedeemCodeDialog> createState() => RedeemCodeDialogState();
}

class RedeemCodeDialogState extends State<RedeemCodeDialog> {
  final _ctrl = TextEditingController();
  bool _loading = false;
  String? _error;
  bool _success = false;

  @override
  void dispose() {
    _ctrl.dispose();
    super.dispose();
  }

  Future<void> _redeem() async {
    final code = _ctrl.text.trim().toUpperCase().replaceAll(' ', '');
    if (code.length != 6) {
      setState(() =>
          _error = 'El código tiene 6 letras. Revísalo e inténtalo de nuevo.');
      return;
    }
    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      await Supabase.instance.client
          .rpc('redeem_invite_code', params: {'p_code': code});
      if (mounted) {
        setState(() {
          _success = true;
          _loading = false;
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _error = e.toString().contains('inválido')
              ? '❌ Código inválido o expirado. Pide uno nuevo a tu papá/mamá.'
              : e.toString().contains('vinculado')
                  ? '✅ ¡Ya estás vinculado con ese papá/mamá!'
                  : '⚠️ No se pudo procesar. Verifica tu conexión.';
          _loading = false;
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Dialog(
      backgroundColor: const Color(0xFF0D1230),
      insetPadding: const EdgeInsets.symmetric(horizontal: 24, vertical: 24),
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(24),
        side: const BorderSide(color: Color(0xFF7C3AED), width: 1),
      ),
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 380),
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(28),
          child: _success
              ? _RedeemSuccessView(onClose: () => Navigator.pop(context))
              : Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Row(children: [
                      const Text('🔗 Vincularme',
                          style: TextStyle(
                              color: Colors.white,
                              fontFamily: 'Nunito',
                              fontWeight: FontWeight.w800,
                              fontSize: 18)),
                      const Spacer(),
                      IconButton(
                        onPressed: () => Navigator.pop(context),
                        icon: const Icon(Icons.close_rounded,
                            color: Colors.white38),
                      ),
                    ]),
                    const SizedBox(height: 8),
                    const Text(
                      'Escribe el código de 6 letras que te dio tu papá o mamá.',
                      textAlign: TextAlign.center,
                      style: TextStyle(
                          color: Colors.white54,
                          fontFamily: 'Nunito',
                          fontSize: 13,
                          height: 1.5),
                    ),
                    const SizedBox(height: 24),
                    TextField(
                      controller: _ctrl,
                      textAlign: TextAlign.center,
                      autocorrect: false,
                      textCapitalization: TextCapitalization.characters,
                      maxLength: 6,
                      style: const TextStyle(
                          color: Colors.white,
                          fontFamily: 'Courier',
                          fontWeight: FontWeight.w900,
                          fontSize: 32,
                          letterSpacing: 8),
                      decoration: InputDecoration(
                        counterText: '',
                        hintText: 'XXXXXX',
                        hintStyle: const TextStyle(
                            color: Colors.white24,
                            fontFamily: 'Courier',
                            fontSize: 32,
                            letterSpacing: 8),
                        filled: true,
                        fillColor: Colors.white.withAlpha(10),
                        border: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(14),
                            borderSide:
                                const BorderSide(color: Colors.white10)),
                        enabledBorder: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(14),
                            borderSide:
                                const BorderSide(color: Colors.white10)),
                        focusedBorder: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(14),
                            borderSide: const BorderSide(
                                color: Color(0xFF7C3AED), width: 2)),
                        contentPadding:
                            const EdgeInsets.symmetric(vertical: 16),
                      ),
                      onSubmitted: (_) => _redeem(),
                    ),
                    if (_error != null) ...[
                      const SizedBox(height: 12),
                      Text(_error!,
                          textAlign: TextAlign.center,
                          style: const TextStyle(
                              color: Color(0xFFFBBF24),
                              fontFamily: 'Nunito',
                              fontSize: 13)),
                    ],
                    const SizedBox(height: 20),
                    SizedBox(
                      width: double.infinity,
                      child: FilledButton(
                        onPressed: _loading ? null : _redeem,
                        style: FilledButton.styleFrom(
                          backgroundColor: const Color(0xFF7C3AED),
                          foregroundColor: Colors.white,
                          padding: const EdgeInsets.symmetric(vertical: 14),
                          shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(14)),
                        ),
                        child: _loading
                            ? const SizedBox(
                                width: 20,
                                height: 20,
                                child: CircularProgressIndicator(
                                    color: Colors.white, strokeWidth: 2))
                            : const Text('¡Vincularme! 🎉',
                                style: TextStyle(
                                    fontFamily: 'Nunito',
                                    fontWeight: FontWeight.w800,
                                    fontSize: 15)),
                      ),
                    ),
                  ],
                ),
        ),
      ),
    );
  }
}

class _RedeemSuccessView extends StatelessWidget {
  const _RedeemSuccessView({required this.onClose});
  final VoidCallback onClose;

  @override
  Widget build(BuildContext context) {
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        const Text('🎉', style: TextStyle(fontSize: 48)),
        const SizedBox(height: 12),
        const Text('¡Vinculado!',
            style: TextStyle(
                color: Colors.white,
                fontFamily: 'Nunito',
                fontWeight: FontWeight.w800,
                fontSize: 20)),
        const SizedBox(height: 8),
        const Text('Ya estás conectado con tu papá o mamá.',
            textAlign: TextAlign.center,
            style: TextStyle(
                color: Colors.white54, fontFamily: 'Nunito', fontSize: 13)),
        const SizedBox(height: 20),
        FilledButton(
          onPressed: onClose,
          style: FilledButton.styleFrom(
              backgroundColor: const Color(0xFF4ADE80),
              foregroundColor: Colors.white,
              shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(14))),
          child: const Text('¡Perfecto! ✓',
              style:
                  TextStyle(fontFamily: 'Nunito', fontWeight: FontWeight.w800)),
        ),
      ],
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// Panel derecho — Destino Marte + combustible + Hangar de Despegue + Cambiar mundo
// ─────────────────────────────────────────────────────────────────────────────
class WorldRightPanel extends ConsumerWidget {
  const WorldRightPanel(
      {super.key,
      required this.fuel,
      this.hasSalary = false,
      this.onSalaryClaim});
  final int fuel;
  final bool hasSalary;
  final VoidCallback? onSalaryClaim;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final world = ref.watch(currentWorldProvider);
    final weeksLeft = ((100 - fuel) / 7.0).ceil().clamp(1, 20);
    const totalSegments = 5;
    final filledSegs = (fuel / 100 * totalSegments).round();

    return Container(
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.centerRight,
          end: Alignment.centerLeft,
          colors: [
            const Color(0xFF0A051A).withOpacity(0.92),
            const Color(0xFF0A051A).withOpacity(0.78),
            Colors.transparent,
          ],
          stops: const [0.0, 0.65, 1.0],
        ),
      ),
      padding: const EdgeInsets.fromLTRB(10, 10, 10, 10),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          // ── Destino Marte ──────────────────────────────────────────────
          PanelCard(
            borderColor: Colors.deepOrange.withOpacity(0.60),
            glowColor: Colors.deepOrange.withOpacity(0.10),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Encabezado con ícono de cohete
                Row(
                  children: [
                    Container(
                      width: 22,
                      height: 22,
                      decoration: BoxDecoration(
                        color: Colors.deepOrange.withOpacity(0.20),
                        shape: BoxShape.circle,
                      ),
                      child: Icon(Icons.flag_rounded,
                          color: Colors.deepOrange.shade300, size: 12),
                    ),
                    const SizedBox(width: 6),
                    const Text(
                      'Marte',
                      style: TextStyle(
                        color: Colors.white,
                        fontWeight: FontWeight.w900,
                        fontSize: 14,
                        shadows: [
                          Shadow(color: Colors.deepOrange, blurRadius: 6)
                        ],
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 1),
                Text(
                  'Nuestro destino final',
                  style: TextStyle(
                    color: Colors.white.withOpacity(0.45),
                    fontSize: 9,
                  ),
                ),
                const SizedBox(height: 10),

                // Porcentaje combustible
                Row(
                  crossAxisAlignment: CrossAxisAlignment.end,
                  children: [
                    Text(
                      '$fuel',
                      style: const TextStyle(
                        color: Colors.white,
                        fontSize: 32,
                        fontWeight: FontWeight.w900,
                        height: 1.0,
                        shadows: [
                          Shadow(color: Colors.deepOrange, blurRadius: 8),
                        ],
                      ),
                    ),
                    Padding(
                      padding: const EdgeInsets.only(bottom: 5),
                      child: Text(
                        '%',
                        style: TextStyle(
                          color: Colors.white.withOpacity(0.70),
                          fontSize: 15,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ),
                  ],
                ),
                Text(
                  'combustible cargado',
                  style: TextStyle(
                    color: Colors.white.withOpacity(0.50),
                    fontSize: 9,
                  ),
                ),
                const SizedBox(height: 8),

                // Barra segmentada con glow
                Row(
                  children: List.generate(totalSegments, (i) {
                    final filled = i < filledSegs;
                    return Expanded(
                      child: Container(
                        height: 10,
                        margin: EdgeInsets.only(
                            right: i < totalSegments - 1 ? 3 : 0),
                        decoration: BoxDecoration(
                          color: filled
                              ? const Color(0xFF4FC3F7)
                              : Colors.white.withOpacity(0.10),
                          borderRadius: BorderRadius.circular(4),
                          boxShadow: filled
                              ? [
                                  BoxShadow(
                                    color: const Color(0xFF4FC3F7)
                                        .withOpacity(0.55),
                                    blurRadius: 6,
                                    spreadRadius: 1,
                                  )
                                ]
                              : null,
                        ),
                      ),
                    );
                  }),
                ),
                const SizedBox(height: 6),
                Text(
                  '$weeksLeft semanas para despegar',
                  style: TextStyle(
                    color: Colors.white.withOpacity(0.55),
                    fontSize: 9,
                  ),
                ),
              ],
            ),
          ),

          const SizedBox(height: 8),

          // ── Hangar de Despegue ─────────────────────────────────────────
          PanelCard(
            borderColor: Colors.deepOrange.withOpacity(0.25),
            glowColor: Colors.transparent,
            child: Row(
              children: [
                Container(
                  width: 32,
                  height: 32,
                  decoration: BoxDecoration(
                    gradient: LinearGradient(
                      colors: [
                        Colors.deepOrange.withOpacity(0.25),
                        Colors.deepOrange.withOpacity(0.10),
                      ],
                    ),
                    shape: BoxShape.circle,
                    border: Border.all(
                      color: Colors.deepOrange.withOpacity(0.40),
                      width: 1,
                    ),
                  ),
                  child: Icon(Icons.rocket_launch_rounded,
                      color: Colors.deepOrange.shade300, size: 16),
                ),
                const SizedBox(width: 7),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      // FittedBox en vez de dejar que el texto se ajuste
                      // solo — en pantallas angostas este panel no tiene
                      // espacio ni para la primera palabra completa, y sin
                      // esto el texto se partía letra por letra ("Han/gar/
                      // de/Desp/egue"). Así siempre cabe en una línea,
                      // achicándose si hace falta, en vez de partirse.
                      FittedBox(
                        fit: BoxFit.scaleDown,
                        alignment: Alignment.centerLeft,
                        child: const Text(
                          'Hangar de Despegue',
                          maxLines: 1,
                          softWrap: false,
                          style: TextStyle(
                            color: Colors.white,
                            fontSize: 10,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      ),
                      FittedBox(
                        fit: BoxFit.scaleDown,
                        alignment: Alignment.centerLeft,
                        child: Text(
                          'Prepárate para Marte',
                          maxLines: 1,
                          softWrap: false,
                          style: TextStyle(
                            color: Colors.white.withOpacity(0.45),
                            fontSize: 9,
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),

          if (hasSalary) ...[
            const SizedBox(height: 8),
            GestureDetector(
              onTap: onSalaryClaim,
              child: PanelCard(
                borderColor: const Color(0xFFFFD600).withOpacity(0.70),
                glowColor: const Color(0xFFFFD600).withOpacity(0.15),
                child: const Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Text('💰', style: TextStyle(fontSize: 14)),
                    SizedBox(width: 6),
                    Text('¡Cobrar salario!',
                        style: TextStyle(
                            color: Color(0xFFFFD600),
                            fontSize: 10,
                            fontWeight: FontWeight.w800)),
                  ],
                ),
              )
                  .animate(onPlay: (c) => c.repeat(reverse: true))
                  .fadeIn(duration: 600.ms)
                  .then()
                  .shimmer(duration: 1200.ms, color: Colors.white24),
            ),
          ],

          const Spacer(),

          // ── Cambiar mundo ──────────────────────────────────────────────
          GestureDetector(
            onTap: () => showWorldSelectorDialog(context, world),
            child: PanelCard(
              borderColor: const Color(0xFF4FC3F7).withOpacity(0.30),
              glowColor: Colors.transparent,
              child: Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(Icons.public_rounded,
                      color: const Color(0xFF4FC3F7).withOpacity(0.80),
                      size: 18),
                  const SizedBox(width: 6),
                  Flexible(
                    child: FittedBox(
                      fit: BoxFit.scaleDown,
                      child: Text('Cambiar mundo',
                          maxLines: 1,
                          softWrap: false,
                          style: TextStyle(
                              color: Colors.white.withOpacity(0.70),
                              fontSize: 10,
                              fontWeight: FontWeight.w600)),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// HUD central superior — monedas + mercado + campana
// ─────────────────────────────────────────────────────────────────────────────
Widget buildWorldCenterHud(
  BuildContext context,
  WidgetRef ref,
  int coins,
  double panelW,
) {
  return Positioned(
    top: 0,
    left: panelW,
    right: panelW,
    child: Container(
      height: 64,
      padding: const EdgeInsets.symmetric(horizontal: 16),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
          colors: [
            Colors.black.withOpacity(0.65),
            Colors.transparent,
          ],
        ),
      ),
      child: Row(
        children: [
          // ── Monedas ──────────────────────────────────────────────────────
          CoinChip(coins: coins, size: CoinChipSize.lg)
              .animate(onPlay: (c) => c.repeat(reverse: true))
              .scale(
                  begin: const Offset(1, 1),
                  end: const Offset(1.04, 1.04),
                  duration: 1800.ms,
                  curve: Curves.easeInOut),

          const Spacer(),

          // ── Mercado ───────────────────────────────────────────────────────
          GestureDetector(
            onTap: () => showMercadoDialog(context),
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
              margin: const EdgeInsets.only(right: 10),
              decoration: BoxDecoration(
                color: Colors.black.withAlpha(100),
                borderRadius: BorderRadius.circular(20),
                border: Border.all(color: Colors.white24),
              ),
              child: const Icon(
                Icons.storefront_rounded,
                color: Colors.white54,
                size: 20,
              ),
            ),
          ),

          // ── Campana ───────────────────────────────────────────────────────
          const ChildNotificationBell(),
        ],
      ),
    ),
  );
}

// ─────────────────────────────────────────────────────────────────────────────
// Cobro de salario semanal — mismo flujo en todos los mundos.
// ─────────────────────────────────────────────────────────────────────────────
Future<void> handleSalaryClaim(BuildContext context, WidgetRef ref) async {
  final result = await ref.read(salaryNotifierProvider.notifier).claim();
  if (!context.mounted) return;
  if (result.alreadyClaimed) {
    showGamePopup(
      context,
      'Ya cobraste tu salario esta semana 😊',
      accentColor: const Color(0xFF7C3AED),
    );
    return;
  }
  ref.invalidate(currentWalletProvider);
  ref.invalidate(mySalaryStatusProvider);
  ref.invalidate(spaceFuelProvider);
  showDialog<void>(
    context: context,
    builder: (_) => SalaryReceivedDialog(
      amount: result.amount,
      fuelAdded: result.fuelAdded,
    ),
  );
}

class SalaryReceivedDialog extends StatelessWidget {
  const SalaryReceivedDialog(
      {super.key, required this.amount, required this.fuelAdded});
  final int amount;
  final int fuelAdded;

  @override
  Widget build(BuildContext context) {
    return Dialog(
      backgroundColor: const Color(0xFF0D1B3E),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(24)),
      child: Padding(
        padding: const EdgeInsets.all(28),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Text('💰', style: TextStyle(fontSize: 56)).animate().scale(
                begin: const Offset(0.5, 0.5),
                duration: 400.ms,
                curve: Curves.elasticOut),
            const SizedBox(height: 12),
            const Text(
              '¡Salario cobrado!',
              style: TextStyle(
                color: Color(0xFFFFD600),
                fontFamily: 'Nunito',
                fontWeight: FontWeight.w900,
                fontSize: 22,
              ),
            ),
            const SizedBox(height: 8),
            Text(
              '+$amount monedas Blink',
              style: const TextStyle(
                color: Colors.white70,
                fontFamily: 'Nunito',
                fontSize: 15,
              ),
            ),
            if (fuelAdded > 0) ...[
              const SizedBox(height: 4),
              Text(
                '🚀 +$fuelAdded% combustible',
                style: const TextStyle(
                  color: Colors.orangeAccent,
                  fontFamily: 'Nunito',
                  fontWeight: FontWeight.w700,
                  fontSize: 13,
                ),
              ),
            ],
            const SizedBox(height: 20),
            FilledButton(
              onPressed: () => Navigator.pop(context),
              style: FilledButton.styleFrom(
                backgroundColor: const Color(0xFFFFD600),
                foregroundColor: Colors.black87,
                shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(14)),
                padding:
                    const EdgeInsets.symmetric(horizontal: 32, vertical: 12),
              ),
              child: const Text(
                '¡Genial!',
                style: TextStyle(
                  fontFamily: 'Nunito',
                  fontWeight: FontWeight.w800,
                  fontSize: 15,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
