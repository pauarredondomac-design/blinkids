import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../../../core/constants/app_colors.dart';
import '../../../core/constants/app_sizes.dart';
import '../../../data/models/app_notification.dart';
import '../../../data/models/profile.dart';
import '../../../data/repositories/parent_repository.dart';
import '../../../data/repositories/salary_repository.dart';
import '../../../shared/providers/auth_provider.dart';
import '../../../shared/providers/parent_mission_provider.dart';
import '../../../shared/providers/parent_provider.dart';
import '../../../shared/providers/profile_provider.dart';
import '../../../shared/providers/wallet_provider.dart';
import '../../../shared/widgets/coin_display.dart';
import 'child_detail_screen.dart';

// ─────────────────────────────────────────────────────────────────────────────
// ParentHomeScreen
// ─────────────────────────────────────────────────────────────────────────────
class ParentHomeScreen extends ConsumerStatefulWidget {
  const ParentHomeScreen({super.key});

  @override
  ConsumerState<ParentHomeScreen> createState() => _ParentHomeScreenState();
}

class _ParentHomeScreenState extends ConsumerState<ParentHomeScreen>
    with SingleTickerProviderStateMixin {

  bool _showNotifPanel = false;
  late AnimationController _notifCtrl;
  late Animation<double>   _notifFade;

  @override
  void initState() {
    super.initState();
    _notifCtrl = AnimationController(
      vsync:    this,
      duration: 220.ms,
    );
    _notifFade = CurvedAnimation(
      parent: _notifCtrl,
      curve:  Curves.easeOut,
    );

    WidgetsBinding.instance.addPostFrameCallback((_) => _grantWeeklyAllowance());
  }

  Future<void> _grantWeeklyAllowance() async {
    try {
      final granted = await ref.read(parentMissionRepositoryProvider).grantWeeklyAllowanceIfDue();
      if (granted > 0 && mounted) {
        ref.invalidate(currentWalletProvider);
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(
          content: Text('¡Recibiste tu recarga semanal de $granted monedas! 🎉'),
          backgroundColor: const Color(0xFF2E7D32),
          behavior: SnackBarBehavior.floating,
        ));
      }
    } catch (_) {
      // Silencioso — no interrumpir el panel de padres
    }
  }

  @override
  void dispose() {
    _notifCtrl.dispose();
    super.dispose();
  }

  void _toggleNotifications() {
    setState(() => _showNotifPanel = !_showNotifPanel);
    _showNotifPanel ? _notifCtrl.forward() : _notifCtrl.reverse();
    if (_showNotifPanel) {
      // marcar como leídas al abrir
      final userId = ref.read(currentUserProvider)?.id;
      if (userId != null) {
        ref.read(notificationRepositoryProvider).markAllRead(userId).then((_) {
          ref.invalidate(unreadCountProvider);
          ref.invalidate(notificationsListProvider);
        });
      }
    }
  }

  Future<void> _showAddChildDialog() async {
    await showDialog(
      context: context,
      builder: (_) => _AddChildDialog(
        onLinked: () => ref.invalidate(linkedChildrenProvider),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final profile      = ref.watch(currentProfileProvider);
    final wallet       = ref.watch(currentWalletProvider);
    final children     = ref.watch(linkedChildrenProvider);
    final unreadAsync  = ref.watch(unreadCountProvider);
    final unreadCount  = unreadAsync.valueOrNull ?? 0;

    // Redirigir si el usuario no es padre
    final profileValue = profile.valueOrNull;
    if (profile.hasValue && profileValue != null && profileValue.role != UserRole.parent) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (context.mounted) context.go('/world');
      });
      return const Scaffold(backgroundColor: Color(0xFF06091A));
    }

    return Scaffold(
      backgroundColor: const Color(0xFF06091A),
      body: Stack(
        children: [

          // ── Fondo animado ────────────────────────────────────────────────
          _AnimatedBackground(),

          // ── Cuerpo principal ─────────────────────────────────────────────
          SafeArea(
            child: Column(
              children: [

                // ── Top bar ───────────────────────────────────────────────
                _TopBar(
                  profile:      profile,
                  unreadCount:  unreadCount,
                  onBell:       _toggleNotifications,
                  onSignOut:    () async {
                    await ref.read(authRepositoryProvider).signOut();
                    if (!context.mounted) return;
                    context.go('/world');
                  },
                ),

                // ── Contenido principal ───────────────────────────────────
                Expanded(
                  child: Padding(
                    padding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
                    child: Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [

                        // ── Panel izquierdo ───────────────────────────────
                        SizedBox(
                          width: 240,
                          child: _LeftPanel(wallet: wallet),
                        ),
                        const SizedBox(width: 16),

                        // ── Panel derecho: Mis Hijos ──────────────────────
                        Expanded(
                          child: _RightChildrenPanel(
                            children:       children,
                            onAddChild:     _showAddChildDialog,
                            onViewActivity: (child) => Navigator.push(
                              context,
                              MaterialPageRoute(
                                builder: (_) => ChildDetailScreen(child: child),
                              ),
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ],
            ),
          ),

          // ── Panel de notificaciones (overlay deslizante) ─────────────────
          if (_showNotifPanel)
            _NotifOverlay(
              animation: _notifFade,
              onClose:   _toggleNotifications,
            ),
        ],
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// Fondo animado con partículas
// ─────────────────────────────────────────────────────────────────────────────
class _AnimatedBackground extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return Stack(
      children: [
        Container(
          decoration: const BoxDecoration(
            gradient: LinearGradient(
              begin: Alignment.topLeft,
              end:   Alignment.bottomRight,
              colors: [
                Color(0xFF06091A),
                Color(0xFF0E0B2E),
                Color(0xFF06091A),
              ],
            ),
          ),
        ),
        // Estrellas decorativas
        for (final s in _stars)
          Positioned(
            left: s.$1,
            top:  s.$2,
            child: Text(
              s.$3,
              style: TextStyle(fontSize: s.$4, color: Colors.white.withAlpha(30)),
            ),
          ),
        // Orbe brillante arriba-derecha
        Positioned(
          right: -80,
          top:   -80,
          child: Container(
            width:  300,
            height: 300,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              gradient: RadialGradient(
                colors: [
                  const Color(0xFF7C3AED).withAlpha(60),
                  Colors.transparent,
                ],
              ),
            ),
          ),
        ),
      ],
    );
  }

  // (left, top, emoji, fontSize)
  static const List<(double, double, String, double)> _stars = [
    (30.0,  20.0, '⭐', 12.0),
    (80.0,  60.0, '✨', 10.0),
    (200.0, 15.0, '🌟', 14.0),
    (350.0, 45.0, '⭐', 10.0),
    (500.0, 25.0, '✨', 12.0),
    (650.0, 55.0, '🌟', 10.0),
  ];
}

// ─────────────────────────────────────────────────────────────────────────────
// Top Bar
// ─────────────────────────────────────────────────────────────────────────────
class _TopBar extends StatelessWidget {
  const _TopBar({
    required this.profile,
    required this.unreadCount,
    required this.onBell,
    required this.onSignOut,
  });
  final AsyncValue<Profile?> profile;
  final int          unreadCount;
  final VoidCallback onBell;
  final VoidCallback onSignOut;

  @override
  Widget build(BuildContext context) {
    final name = profile.valueOrNull?.displayName ?? '…';

    return Container(
      padding: const EdgeInsets.fromLTRB(20, 12, 12, 12),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: [
            const Color(0xFF0E0B2E).withAlpha(230),
            const Color(0xFF06091A).withAlpha(200),
          ],
        ),
        border: const Border(
          bottom: BorderSide(color: Colors.white10),
        ),
      ),
      child: Row(
        children: [
          // Avatar
          Container(
            width:       42,
            height:      42,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              gradient: const LinearGradient(
                colors: [Color(0xFF7C3AED), Color(0xFFEC4899)],
              ),
            ),
            child: const Center(
              child: Text('👨‍👩‍👧', style: TextStyle(fontSize: 20)),
            ),
          ),
          const SizedBox(width: 12),

          // Saludo
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text(
                'Panel de Padres',
                style: TextStyle(
                  color:      Colors.white38,
                  fontFamily: 'Nunito',
                  fontSize:   11,
                  letterSpacing: 1,
                ),
              ),
              Text(
                'Hola, $name! 👋',
                style: const TextStyle(
                  color:       Colors.white,
                  fontFamily:  'Nunito',
                  fontWeight:  FontWeight.w800,
                  fontSize:    18,
                ),
              ),
            ],
          ),

          const Spacer(),

          // Campana de notificaciones
          Stack(
            clipBehavior: Clip.none,
            children: [
              IconButton(
                onPressed: onBell,
                icon: const Icon(
                  Icons.notifications_rounded,
                  color: Colors.white70,
                  size: 26,
                ),
                tooltip: 'Notificaciones',
              ),
              if (unreadCount > 0)
                Positioned(
                  right: 6,
                  top:   6,
                  child: Container(
                    padding: const EdgeInsets.all(4),
                    decoration: const BoxDecoration(
                      color: Color(0xFFEC4899),
                      shape: BoxShape.circle,
                    ),
                    constraints: const BoxConstraints(minWidth: 18, minHeight: 18),
                    child: Text(
                      unreadCount > 9 ? '9+' : '$unreadCount',
                      textAlign: TextAlign.center,
                      style: const TextStyle(
                        color:      Colors.white,
                        fontSize:   9,
                        fontWeight: FontWeight.w800,
                        fontFamily: 'Nunito',
                      ),
                    ),
                  ),
                ),
            ],
          ),

          // Cerrar sesión
          IconButton(
            onPressed: onSignOut,
            icon: const Icon(Icons.logout_rounded, color: Colors.white38, size: 20),
            tooltip: 'Cerrar sesión',
          ),
        ],
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// Panel izquierdo: cartera + send coins
// ─────────────────────────────────────────────────────────────────────────────
class _LeftPanel extends StatelessWidget {
  const _LeftPanel({required this.wallet});
  final AsyncValue wallet;

  @override
  Widget build(BuildContext context) {
    final w     = wallet.valueOrNull;
    final coins = w?.totalCoins ?? 0;

    return SingleChildScrollView(
      padding: const EdgeInsets.only(top: 16),
      child: Column(
        children: [
          // ── Cartera ──────────────────────────────────────────────────────
          _GlassCard(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(children: [
                  Container(
                    padding: const EdgeInsets.all(8),
                    decoration: BoxDecoration(
                      color:        AppColors.secondary.withAlpha(40),
                      borderRadius: BorderRadius.circular(10),
                    ),
                    child: const Icon(
                      Icons.account_balance_wallet_rounded,
                      color: AppColors.secondary,
                      size: 22,
                    ),
                  ),
                  const SizedBox(width: 10),
                  const Text(
                    'Mi Cartera',
                    style: TextStyle(
                      color:      Colors.white,
                      fontFamily: 'Nunito',
                      fontWeight: FontWeight.w800,
                      fontSize:   15,
                    ),
                  ),
                ]),
                const SizedBox(height: 16),
                // Monedas del juego
                _BalanceChip(
                  label: 'Monedas juego',
                  value: '$coins',
                  color: const Color(0xFFFFD600),
                  icon:  '🪙',
                ),
              ],
            ),
          ).animate().fadeIn(duration: 350.ms).slideX(begin: -0.15),

          const SizedBox(height: 12),

          // ── Enviar monedas ────────────────────────────────────────────────
          _GlassCard(
            accentColor: AppColors.accent,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(children: [
                  Container(
                    padding: const EdgeInsets.all(8),
                    decoration: BoxDecoration(
                      color:        AppColors.accent.withAlpha(40),
                      borderRadius: BorderRadius.circular(10),
                    ),
                    child: const Icon(
                      Icons.send_rounded,
                      color: AppColors.accent,
                      size: 22,
                    ),
                  ),
                  const SizedBox(width: 10),
                  const Text(
                    'Enviar Monedas',
                    style: TextStyle(
                      color:      Colors.white,
                      fontFamily: 'Nunito',
                      fontWeight: FontWeight.w800,
                      fontSize:   15,
                    ),
                  ),
                ]),
                const SizedBox(height: 10),
                const Text(
                  'Entra al perfil de tu hijo y usa el botón "Enviar monedas" para premiarlo.',
                  style: TextStyle(
                    color:      Colors.white54,
                    fontFamily: 'Nunito',
                    fontSize:   12,
                    height:     1.4,
                  ),
                ),
                const SizedBox(height: 4),
                const Text(
                  '🏹 Selecciona a tu hijo en el panel derecho',
                  style: TextStyle(
                    color:      Colors.white38,
                    fontFamily: 'Nunito',
                    fontSize:   11,
                    fontStyle:  FontStyle.italic,
                  ),
                ),
              ],
            ),
          ).animate(delay: 80.ms).fadeIn(duration: 350.ms).slideX(begin: -0.15),

          const SizedBox(height: 12),

          // ── Consejo del día ───────────────────────────────────────────────
          _GlassCard(
            accentColor: const Color(0xFF10B981),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Row(children: [
                  Text('💡', style: TextStyle(fontSize: 18)),
                  SizedBox(width: 8),
                  Text(
                    'Consejo del día',
                    style: TextStyle(
                      color:      Colors.white,
                      fontFamily: 'Nunito',
                      fontWeight: FontWeight.w800,
                      fontSize:   14,
                    ),
                  ),
                ]),
                const SizedBox(height: 8),
                const Text(
                  'Felicita a tu hijo cuando completa misiones. '
                  'El refuerzo positivo es clave para el aprendizaje financiero. 🌟',
                  style: TextStyle(
                    color:      Colors.white60,
                    fontFamily: 'Nunito',
                    fontSize:   12,
                    height:     1.4,
                  ),
                ),
              ],
            ),
          ).animate(delay: 160.ms).fadeIn(duration: 350.ms).slideX(begin: -0.15),
        ],
      ),
    );
  }
}

class _BalanceChip extends StatelessWidget {
  const _BalanceChip({
    required this.label,
    required this.value,
    required this.color,
    required this.icon,
  });
  final String label, value, icon;
  final Color  color;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
      decoration: BoxDecoration(
        color:        color.withAlpha(20),
        borderRadius: BorderRadius.circular(10),
        border:       Border.all(color: color.withAlpha(60)),
      ),
      child: Row(children: [
        icon == '🪙'
            ? const AnimatedCoin(size: 16)
            : Text(icon, style: const TextStyle(fontSize: 16)),
        const SizedBox(width: 8),
        Expanded(
          child: Text(
            label,
            style: const TextStyle(
              color: Colors.white54, fontFamily: 'Nunito', fontSize: 11,
            ),
          ),
        ),
        Text(
          value,
          style: TextStyle(
            color:      color,
            fontFamily: 'Nunito',
            fontWeight: FontWeight.w800,
            fontSize:   13,
          ),
        ),
      ]),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// Panel derecho: lista de hijos
// ─────────────────────────────────────────────────────────────────────────────
class _RightChildrenPanel extends ConsumerWidget {
  const _RightChildrenPanel({
    required this.children,
    required this.onAddChild,
    required this.onViewActivity,
  });
  final AsyncValue<List<Profile>> children;
  final VoidCallback              onAddChild;
  final void Function(Profile)    onViewActivity;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // Header
        Padding(
          padding: const EdgeInsets.only(top: 16, bottom: 12),
          child: Row(children: [
            const Text(
              '👨‍👩‍👧 Mis Hijos',
              style: TextStyle(
                color:      Colors.white,
                fontFamily: 'Nunito',
                fontWeight: FontWeight.w800,
                fontSize:   20,
              ),
            ),
            const Spacer(),
            // Botón agregar hijo
            FilledButton.icon(
              onPressed: onAddChild,
              icon:  const Icon(Icons.add_rounded, size: 18),
              label: const Text(
                'Agregar hijo',
                style: TextStyle(fontFamily: 'Nunito', fontWeight: FontWeight.w700, fontSize: 13),
              ),
              style: FilledButton.styleFrom(
                backgroundColor: const Color(0xFF7C3AED),
                foregroundColor: Colors.white,
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
              ),
            ),
          ]),
        ),

        // Lista de hijos
        Expanded(
          child: children.when(
            loading: () => const Center(
              child: CircularProgressIndicator(color: Color(0xFF7C3AED)),
            ),
            error: (e, _) => _ErrorState(message: e.toString()),
            data: (list) => list.isEmpty
                ? _EmptyChildren(onAddChild: onAddChild)
                : _ChildrenGrid(
                    children:       list,
                    onViewActivity: onViewActivity,
                  ),
          ),
        ),
      ],
    );
  }
}

class _ChildrenGrid extends ConsumerWidget {
  const _ChildrenGrid({required this.children, required this.onViewActivity});
  final List<Profile>          children;
  final void Function(Profile) onViewActivity;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return ListView.separated(
      itemCount:      children.length,
      separatorBuilder: (_, __) => const SizedBox(height: 12),
      itemBuilder: (ctx, i) {
        final child = children[i];
        return _ChildCard(
          child:         child,
          onViewActivity: () => onViewActivity(child),
        ).animate(delay: (60 * i).ms).fadeIn(duration: 300.ms).slideY(begin: 0.1);
      },
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// Tarjeta de hijo
// ─────────────────────────────────────────────────────────────────────────────
class _ChildCard extends ConsumerWidget {
  const _ChildCard({required this.child, required this.onViewActivity});
  final Profile    child;
  final VoidCallback onViewActivity;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final statsAsync = ref.watch(childStatsProvider(child));

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end:   Alignment.bottomRight,
          colors: [
            const Color(0xFF0D1230),
            const Color(0xFF12103A),
          ],
        ),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: const Color(0xFF7C3AED).withAlpha(80),
        ),
        boxShadow: [
          BoxShadow(
            color:      const Color(0xFF7C3AED).withAlpha(30),
            blurRadius: 16,
            offset:     const Offset(0, 4),
          ),
        ],
      ),
      child: statsAsync.when(
        loading: () => SizedBox(
          height: 80,
          child: Center(
            child: CircularProgressIndicator(
              color: const Color(0xFF7C3AED).withAlpha(150),
              strokeWidth: 2,
            ),
          ),
        ),
        error: (_, __) => _ChildCardBasic(child: child, onView: onViewActivity),
        data: (stats) => _ChildCardFull(stats: stats, onView: onViewActivity),
      ),
    );
  }
}

// Tarjeta simple (sin stats)
class _ChildCardBasic extends StatelessWidget {
  const _ChildCardBasic({required this.child, required this.onView});
  final Profile    child;
  final VoidCallback onView;

  @override
  Widget build(BuildContext context) {
    return Row(children: [
      const Text('🐣', style: TextStyle(fontSize: 36)),
      const SizedBox(width: 14),
      Expanded(
        child: Text(
          child.displayName,
          style: const TextStyle(
            color: Colors.white,
            fontFamily: 'Nunito',
            fontWeight: FontWeight.w700,
            fontSize: 16,
          ),
        ),
      ),
      FilledButton(
        onPressed: onView,
        child: const Text('Ver actividad'),
      ),
    ]);
  }
}

// Tarjeta completa (con stats)
class _ChildCardFull extends StatelessWidget {
  const _ChildCardFull({required this.stats, required this.onView});
  final ChildStats   stats;
  final VoidCallback onView;

  void _openSalaryDialog(BuildContext context) {
    showDialog<void>(
      context: context,
      builder: (_) => _SalaryDialog(childId: stats.childId, childName: stats.displayName),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        // Avatar del personaje
        Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Text('🦊', style: TextStyle(fontSize: 44)),
            const SizedBox(height: 2),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
              decoration: BoxDecoration(
                color:        const Color(0xFF7C3AED).withAlpha(60),
                borderRadius: BorderRadius.circular(6),
              ),
              child: Text(
                'Nivel ${stats.level}',
                style: const TextStyle(
                  color:      Colors.white54,
                  fontFamily: 'Nunito',
                  fontSize:   9,
                ),
              ),
            ),
          ],
        ),
        const SizedBox(width: 16),

        // Nombre + XP bar + stats
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Nombre y nivel
              Row(children: [
                Expanded(
                  child: Text(
                    stats.displayName,
                    style: const TextStyle(
                      color:      Colors.white,
                      fontFamily: 'Nunito',
                      fontWeight: FontWeight.w900,
                      fontSize:   17,
                    ),
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                  decoration: BoxDecoration(
                    color:        const Color(0xFFFFD600).withAlpha(30),
                    borderRadius: BorderRadius.circular(8),
                    border: Border.all(color: const Color(0xFFFFD600).withAlpha(80)),
                  ),
                  child: Text(
                    'Nv. ${stats.level}',
                    style: const TextStyle(
                      color:      Color(0xFFFFD600),
                      fontFamily: 'Nunito',
                      fontWeight: FontWeight.w800,
                      fontSize:   11,
                    ),
                  ),
                ),
              ]),
              const SizedBox(height: 6),

              // Barra de progreso al siguiente nivel
              Row(children: [
                Expanded(
                  child: ClipRRect(
                    borderRadius: BorderRadius.circular(4),
                    child: LinearProgressIndicator(
                      value:           stats.levelProgress,
                      backgroundColor: Colors.white10,
                      valueColor:      const AlwaysStoppedAnimation(Color(0xFF7C3AED)),
                      minHeight:       6,
                    ),
                  ),
                ),
                const SizedBox(width: 8),
                Text(
                  '${stats.xp} XP',
                  style: const TextStyle(
                    color:      Colors.white38,
                    fontFamily: 'Nunito',
                    fontSize:   10,
                  ),
                ),
              ]),
              const SizedBox(height: 10),

              // Chips de stats
              Wrap(
                spacing: 8,
                runSpacing: 4,
                children: [
                  _MiniChip('${stats.totalCoins}',  const Color(0xFFFFD600), showCoin: true),
                  _MiniChip('🏆 ${stats.missionsJoined}', const Color(0xFF10B981)),
                  _MiniChip('⭐ ${stats.xp} XP',       const Color(0xFFBB86FC)),
                ],
              ),
            ],
          ),
        ),
        const SizedBox(width: 16),

        // Botones de acción
        Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            // Ver actividad
            FilledButton(
              onPressed: onView,
              style: FilledButton.styleFrom(
                backgroundColor: const Color(0xFF7C3AED),
                foregroundColor: Colors.white,
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
              ),
              child: const Column(
                children: [
                  Icon(Icons.bar_chart_rounded, size: 22),
                  SizedBox(height: 2),
                  Text(
                    'Ver\nactividad',
                    textAlign: TextAlign.center,
                    style: TextStyle(
                      fontFamily: 'Nunito',
                      fontWeight: FontWeight.w700,
                      fontSize:   11,
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 8),
            // Asignar salario
            OutlinedButton(
              onPressed: () => _openSalaryDialog(context),
              style: OutlinedButton.styleFrom(
                foregroundColor: const Color(0xFFFFD600),
                side: const BorderSide(color: Color(0xFFFFD600), width: 1),
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
              ),
              child: const Column(
                children: [
                  Text('💰', style: TextStyle(fontSize: 18)),
                  SizedBox(height: 2),
                  Text(
                    'Salario',
                    style: TextStyle(
                      fontFamily: 'Nunito',
                      fontWeight: FontWeight.w700,
                      fontSize: 11,
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ],
    );
  }
}

class _MiniChip extends StatelessWidget {
  const _MiniChip(this.label, this.color, {this.showCoin = false});
  final String label;
  final Color  color;
  final bool   showCoin;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
      decoration: BoxDecoration(
        color:        color.withAlpha(25),
        borderRadius: BorderRadius.circular(8),
        border:       Border.all(color: color.withAlpha(70)),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          if (showCoin) ...[
            const AnimatedCoin(size: 11),
            const SizedBox(width: 3),
          ],
          Text(
            label,
            style: TextStyle(
              color:      color,
              fontFamily: 'Nunito',
              fontWeight: FontWeight.w700,
              fontSize:   11,
            ),
          ),
        ],
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// Estado vacío: sin hijos vinculados
// ─────────────────────────────────────────────────────────────────────────────
class _EmptyChildren extends StatelessWidget {
  const _EmptyChildren({required this.onAddChild});
  final VoidCallback onAddChild;

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          const Text('👨‍👩‍👧', style: TextStyle(fontSize: 56))
              .animate(onPlay: (c) => c.repeat(reverse: true))
              .scale(begin: const Offset(1, 1), end: const Offset(1.08, 1.08), duration: 1800.ms),
          const SizedBox(height: 16),
          const Text(
            'Aún no tienes hijos vinculados',
            style: TextStyle(
              color:      Colors.white,
              fontFamily: 'Nunito',
              fontWeight: FontWeight.w800,
              fontSize:   18,
            ),
          ),
          const SizedBox(height: 8),
          const Text(
            'Toca "Agregar hijo" para generar\nun código y compartirlo con tu hijo.',
            textAlign: TextAlign.center,
            style: TextStyle(
              color:      Colors.white38,
              fontFamily: 'Nunito',
              fontSize:   13,
              height:     1.5,
            ),
          ),
          const SizedBox(height: 24),
          FilledButton.icon(
            onPressed: onAddChild,
            icon:  const Icon(Icons.add_rounded),
            label: const Text(
              'Agregar hijo',
              style: TextStyle(
                fontFamily: 'Nunito',
                fontWeight: FontWeight.w700,
                fontSize:   14,
              ),
            ),
            style: FilledButton.styleFrom(
              backgroundColor: const Color(0xFF7C3AED),
              foregroundColor: Colors.white,
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
              padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 14),
            ),
          ),
        ],
      ),
    );
  }
}

class _ErrorState extends StatelessWidget {
  const _ErrorState({required this.message});
  final String message;

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Text(
        '⚠️ $message',
        style: const TextStyle(color: Colors.white38, fontFamily: 'Nunito'),
        textAlign: TextAlign.center,
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// Panel de notificaciones (overlay)
// ─────────────────────────────────────────────────────────────────────────────
class _NotifOverlay extends ConsumerWidget {
  const _NotifOverlay({required this.animation, required this.onClose});
  final Animation<double> animation;
  final VoidCallback      onClose;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final notifsAsync = ref.watch(notificationsListProvider);

    return Stack(
      children: [
        // Scrim semitransparente
        GestureDetector(
          onTap: onClose,
          child: FadeTransition(
            opacity: animation,
            child: Container(color: Colors.black54),
          ),
        ),
        // Panel deslizante desde la derecha
        Positioned(
          top:    0,
          right:  0,
          bottom: 0,
          width:  360,
          child: SlideTransition(
            position: Tween<Offset>(
              begin: const Offset(1, 0),
              end:   Offset.zero,
            ).animate(animation),
            child: Container(
              decoration: const BoxDecoration(
                color: Color(0xFF0D1230),
                border: Border(left: BorderSide(color: Colors.white10)),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // Header
                  Container(
                    padding: const EdgeInsets.fromLTRB(20, 16, 8, 12),
                    decoration: const BoxDecoration(
                      border: Border(bottom: BorderSide(color: Colors.white10)),
                    ),
                    child: Row(children: [
                      const Text(
                        '🔔 Notificaciones',
                        style: TextStyle(
                          color:      Colors.white,
                          fontFamily: 'Nunito',
                          fontWeight: FontWeight.w800,
                          fontSize:   16,
                        ),
                      ),
                      const Spacer(),
                      IconButton(
                        onPressed: onClose,
                        icon: const Icon(Icons.close_rounded, color: Colors.white38),
                      ),
                    ]),
                  ),
                  // Lista
                  Expanded(
                    child: notifsAsync.when(
                      loading: () => const Center(
                        child: CircularProgressIndicator(color: Color(0xFF7C3AED)),
                      ),
                      error: (_, __) => const Center(
                        child: Text(
                          'Error cargando notificaciones',
                          style: TextStyle(color: Colors.white38, fontFamily: 'Nunito'),
                        ),
                      ),
                      data: (list) => list.isEmpty
                          ? const _EmptyNotifs()
                          : ListView.builder(
                              padding:   const EdgeInsets.all(12),
                              itemCount: list.length,
                              itemBuilder: (ctx, i) => _NotifTile(notif: list[i])
                                  .animate(delay: (30 * i).ms)
                                  .fadeIn(duration: 200.ms),
                            ),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ],
    );
  }
}

class _NotifTile extends StatelessWidget {
  const _NotifTile({required this.notif});
  final AppNotification notif;

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.only(bottom: 8),
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: notif.isRead
            ? Colors.white.withAlpha(5)
            : const Color(0xFF7C3AED).withAlpha(30),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
          color: notif.isRead ? Colors.white10 : const Color(0xFF7C3AED).withAlpha(80),
        ),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(notif.typeIcon, style: const TextStyle(fontSize: 22)),
          const SizedBox(width: 10),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  notif.title,
                  style: const TextStyle(
                    color:      Colors.white,
                    fontFamily: 'Nunito',
                    fontWeight: FontWeight.w700,
                    fontSize:   13,
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  notif.body,
                  style: const TextStyle(
                    color:      Colors.white54,
                    fontFamily: 'Nunito',
                    fontSize:   11,
                    height:     1.3,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  notif.timeAgo,
                  style: const TextStyle(
                    color:      Colors.white30,
                    fontFamily: 'Nunito',
                    fontSize:   10,
                  ),
                ),
              ],
            ),
          ),
          if (!notif.isRead)
            Container(
              width:  8,
              height: 8,
              decoration: const BoxDecoration(
                color:  Color(0xFFEC4899),
                shape:  BoxShape.circle,
              ),
            ),
        ],
      ),
    );
  }
}

class _EmptyNotifs extends StatelessWidget {
  const _EmptyNotifs();

  @override
  Widget build(BuildContext context) {
    return const Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Text('🔔', style: TextStyle(fontSize: 40)),
          SizedBox(height: 12),
          Text(
            'Sin notificaciones',
            style: TextStyle(
              color:      Colors.white54,
              fontFamily: 'Nunito',
              fontWeight: FontWeight.w700,
              fontSize:   15,
            ),
          ),
          SizedBox(height: 6),
          Text(
            'Aquí verás cuando tu hijo\nacepte tu solicitud.',
            textAlign: TextAlign.center,
            style: TextStyle(
              color:      Colors.white30,
              fontFamily: 'Nunito',
              fontSize:   12,
            ),
          ),
        ],
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// Glassmorphism card base
// ─────────────────────────────────────────────────────────────────────────────
class _GlassCard extends StatelessWidget {
  const _GlassCard({required this.child, this.accentColor});
  final Widget child;
  final Color? accentColor;

  @override
  Widget build(BuildContext context) {
    final accent = accentColor ?? const Color(0xFF7C3AED);
    return Container(
      padding: const EdgeInsets.all(AppSizes.md),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end:   Alignment.bottomRight,
          colors: [
            const Color(0xFF0D1230),
            const Color(0xFF0A0E28),
          ],
        ),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: accent.withAlpha(60)),
        boxShadow: [
          BoxShadow(
            color:      accent.withAlpha(20),
            blurRadius: 12,
            offset:     const Offset(0, 2),
          ),
        ],
      ),
      child: child,
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// Diálogo: Código de invitación para agregar hijo
// El padre genera un código de 6 letras; el hijo lo escribe en su app.
// ─────────────────────────────────────────────────────────────────────────────
class _AddChildDialog extends ConsumerStatefulWidget {
  const _AddChildDialog({required this.onLinked});
  final VoidCallback onLinked;

  @override
  ConsumerState<_AddChildDialog> createState() => _AddChildDialogState();
}

class _AddChildDialogState extends ConsumerState<_AddChildDialog> {
  String? _code;
  bool    _loading = false;
  String? _error;

  @override
  void initState() {
    super.initState();
    _generateCode();
  }

  Future<void> _generateCode() async {
    setState(() { _loading = true; _error = null; });
    try {
      final result = await Supabase.instance.client
          .rpc('generate_invite_code');
      if (mounted) setState(() { _code = result as String; _loading = false; });
    } catch (e) {
      if (mounted) setState(() {
        _error   = 'No se pudo generar el código. Verifica tu conexión.';
        _loading = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return Dialog(
      backgroundColor: const Color(0xFF0D1230),
      insetPadding: const EdgeInsets.symmetric(horizontal: 24, vertical: 40),
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(24),
        side: const BorderSide(color: Color(0xFF7C3AED), width: 1),
      ),
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 400),
        child: Padding(
          padding: const EdgeInsets.fromLTRB(24, 16, 24, 20),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [

              // ── Header ───────────────────────────────────────────────────
              Row(children: [
                const Text(
                  '👨‍👩‍👧 Agregar Hijo',
                  style: TextStyle(
                    color:      Colors.white,
                    fontFamily: 'Nunito',
                    fontWeight: FontWeight.w800,
                    fontSize:   18,
                  ),
                ),
                const Spacer(),
                IconButton(
                  onPressed: () => Navigator.pop(context),
                  icon: const Icon(Icons.close_rounded, color: Colors.white38),
                ),
              ]),
              const SizedBox(height: 4),

              const Text(
                'Comparte este código con tu hijo.\nÉl lo escribe en su app y quedan vinculados al instante.',
                textAlign: TextAlign.center,
                style: TextStyle(
                  color:      Colors.white54,
                  fontFamily: 'Nunito',
                  fontSize:   13,
                  height:     1.4,
                ),
              ),
              const SizedBox(height: 16),

              // ── Código grande ─────────────────────────────────────────────
              if (_loading)
                const CircularProgressIndicator(color: Color(0xFF7C3AED))
              else if (_error != null) ...[
                Text(
                  '⚠️ $_error',
                  textAlign: TextAlign.center,
                  style: const TextStyle(
                    color:      Color(0xFFFBBF24),
                    fontFamily: 'Nunito',
                    fontSize:   13,
                  ),
                ),
              ] else if (_code != null) ...[
                // Fondo del código
                Container(
                  width: double.infinity,
                  padding: const EdgeInsets.symmetric(vertical: 20),
                  decoration: BoxDecoration(
                    color:        const Color(0xFF7C3AED).withAlpha(30),
                    borderRadius: BorderRadius.circular(16),
                    border:       Border.all(
                      color: const Color(0xFF7C3AED).withAlpha(120),
                      width: 2,
                    ),
                  ),
                  child: Column(
                    children: [
                      // El código formateado en grupos de 3
                      Text(
                        '${_code!.substring(0, 3)} ${_code!.substring(3)}',
                        style: const TextStyle(
                          color:       Colors.white,
                          fontFamily:  'Courier',
                          fontWeight:  FontWeight.w900,
                          fontSize:    36,
                          letterSpacing: 6,
                        ),
                      ),
                      const SizedBox(height: 6),
                      const Text(
                        '⏱ Válido 24 h · un solo uso',
                        style: TextStyle(
                          color:      Colors.white38,
                          fontFamily: 'Nunito',
                          fontSize:   11,
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 14),

                // ── Botones ──────────────────────────────────────────────
                Row(children: [
                  // Copiar
                  Expanded(
                    child: OutlinedButton.icon(
                      onPressed: () {
                        Clipboard.setData(ClipboardData(text: _code!));
                        ScaffoldMessenger.of(context).showSnackBar(
                          const SnackBar(
                            content: Text(
                              '📋 Código copiado',
                              style: TextStyle(fontFamily: 'Nunito'),
                            ),
                            duration:  Duration(seconds: 2),
                            behavior:  SnackBarBehavior.floating,
                          ),
                        );
                      },
                      icon:  const Icon(Icons.copy_rounded, size: 16),
                      label: const Text(
                        'Copiar',
                        style: TextStyle(fontFamily: 'Nunito', fontWeight: FontWeight.w700),
                      ),
                      style: OutlinedButton.styleFrom(
                        foregroundColor: Colors.white70,
                        side: const BorderSide(color: Colors.white24),
                        shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(12)),
                        padding: const EdgeInsets.symmetric(vertical: 12),
                      ),
                    ),
                  ),
                  const SizedBox(width: 12),
                  // Nuevo código
                  Expanded(
                    child: FilledButton.icon(
                      onPressed: _loading ? null : _generateCode,
                      icon:  const Icon(Icons.refresh_rounded, size: 16),
                      label: const Text(
                        'Nuevo código',
                        style: TextStyle(fontFamily: 'Nunito', fontWeight: FontWeight.w700),
                      ),
                      style: FilledButton.styleFrom(
                        backgroundColor: const Color(0xFF7C3AED),
                        foregroundColor: Colors.white,
                        shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(12)),
                        padding: const EdgeInsets.symmetric(vertical: 12),
                      ),
                    ),
                  ),
                ]),
              ],

            ],
          ),
        ),
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// _SalaryDialog — asigna/edita el salario semanal de un hijo
// ─────────────────────────────────────────────────────────────────────────────
class _SalaryDialog extends StatefulWidget {
  const _SalaryDialog({required this.childId, required this.childName});
  final String childId;
  final String childName;

  @override
  State<_SalaryDialog> createState() => _SalaryDialogState();
}

class _SalaryDialogState extends State<_SalaryDialog> {
  int    _amount  = 25;
  bool   _loading = false;
  bool   _saved   = false;
  String? _error;

  static const _min = 20;
  static const _max = 35;

  Future<void> _save() async {
    setState(() { _loading = true; _error = null; });
    try {
      await SalaryRepository().upsertSalary(
        childId: widget.childId,
        amount:  _amount,
      );
      if (mounted) setState(() { _loading = false; _saved = true; });
    } catch (e) {
      if (mounted) setState(() {
        _loading = false;
        _error   = 'Error al guardar. Verifica tu conexión.';
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return Dialog(
      backgroundColor: const Color(0xFF0D1230),
      insetPadding: const EdgeInsets.symmetric(horizontal: 24, vertical: 40),
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(24),
        side: const BorderSide(color: Color(0xFFFFD600), width: 1),
      ),
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 380),
        child: Padding(
          padding: const EdgeInsets.fromLTRB(24, 16, 24, 20),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              // Header
              Row(children: [
                const Text('💰', style: TextStyle(fontSize: 24)),
                const SizedBox(width: 10),
                Expanded(
                  child: Text(
                    'Salario de ${widget.childName}',
                    style: const TextStyle(
                      color: Colors.white,
                      fontFamily: 'Nunito',
                      fontWeight: FontWeight.w800,
                      fontSize: 17,
                    ),
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
                IconButton(
                  onPressed: () => Navigator.pop(context),
                  icon: const Icon(Icons.close_rounded, color: Colors.white38),
                ),
              ]),
              const SizedBox(height: 4),

              const Text(
                'Elige cuántas monedas Blink quieres\nasignar por semana (20 – 35).',
                textAlign: TextAlign.center,
                style: TextStyle(
                  color: Colors.white54,
                  fontFamily: 'Nunito',
                  fontSize: 13,
                  height: 1.4,
                ),
              ),
              const SizedBox(height: 20),

              // Valor actual grande
              Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  const AnimatedCoin(size: 32),
                  const SizedBox(width: 6),
                  Text(
                    '$_amount',
                    style: const TextStyle(
                      color: Color(0xFFFFD600),
                      fontFamily: 'Nunito',
                      fontWeight: FontWeight.w900,
                      fontSize: 40,
                    ),
                  ),
                ],
              ),
              const Text(
                'monedas / semana',
                style: TextStyle(
                  color: Colors.white38,
                  fontFamily: 'Nunito',
                  fontSize: 12,
                ),
              ),
              const SizedBox(height: 8),

              // Slider
              Slider(
                value: _amount.toDouble(),
                min: _min.toDouble(),
                max: _max.toDouble(),
                divisions: _max - _min,
                activeColor: const Color(0xFFFFD600),
                inactiveColor: Colors.white24,
                onChanged: _saved ? null : (v) => setState(() => _amount = v.toInt()),
              ),
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text('$_min', style: const TextStyle(color: Colors.white38, fontSize: 11)),
                  Text('$_max', style: const TextStyle(color: Colors.white38, fontSize: 11)),
                ],
              ),
              const SizedBox(height: 16),

              if (_error != null)
                Padding(
                  padding: const EdgeInsets.only(bottom: 12),
                  child: Text(
                    '⚠️ $_error',
                    style: const TextStyle(
                      color: Color(0xFFFBBF24),
                      fontFamily: 'Nunito',
                      fontSize: 12,
                    ),
                    textAlign: TextAlign.center,
                  ),
                ),

              if (_saved)
                Container(
                  width: double.infinity,
                  padding: const EdgeInsets.symmetric(vertical: 12),
                  decoration: BoxDecoration(
                    color: Colors.green.withOpacity(0.15),
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(color: Colors.greenAccent.withOpacity(0.5)),
                  ),
                  child: const Text(
                    '✅ ¡Salario guardado!',
                    textAlign: TextAlign.center,
                    style: TextStyle(
                      color: Colors.greenAccent,
                      fontFamily: 'Nunito',
                      fontWeight: FontWeight.w700,
                      fontSize: 14,
                    ),
                  ),
                )
              else
                SizedBox(
                  width: double.infinity,
                  child: FilledButton(
                    onPressed: _loading ? null : _save,
                    style: FilledButton.styleFrom(
                      backgroundColor: const Color(0xFFFFD600),
                      foregroundColor: Colors.black87,
                      shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(12)),
                      padding: const EdgeInsets.symmetric(vertical: 14),
                    ),
                    child: _loading
                        ? const SizedBox(
                            height: 18,
                            width: 18,
                            child: CircularProgressIndicator(
                              strokeWidth: 2,
                              color: Colors.black54,
                            ),
                          )
                        : const Text(
                            'Asignar salario',
                            style: TextStyle(
                              fontFamily: 'Nunito',
                              fontWeight: FontWeight.w800,
                              fontSize: 15,
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
}
