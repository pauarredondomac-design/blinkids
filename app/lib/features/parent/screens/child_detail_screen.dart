import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../../../data/models/parent_mission.dart';
import '../../../data/models/profile.dart';
import '../../../data/repositories/parent_repository.dart';
import '../../../data/repositories/salary_repository.dart';
import '../../../data/repositories/wallet_repository.dart';
import '../../../shared/providers/cosmetic_provider.dart';
import '../../../shared/providers/parent_mission_provider.dart';
import '../../../shared/providers/parent_provider.dart';
import '../../../shared/providers/wallet_provider.dart';
import '../../../shared/widgets/badges_row.dart';
import '../../../shared/widgets/blink_avatar.dart';
import '../../../shared/widgets/coin_display.dart';
import '../../../shared/widgets/game_popup.dart';
import '../../auth/screens/pin_pad_widget.dart';

// ─────────────────────────────────────────────────────────────────────────────
// ChildDetailScreen — Registro de actividad del hijo
// ─────────────────────────────────────────────────────────────────────────────
class ChildDetailScreen extends ConsumerStatefulWidget {
  const ChildDetailScreen({super.key, required this.child});
  final Profile child;

  @override
  ConsumerState<ChildDetailScreen> createState() => _ChildDetailScreenState();
}

class _ChildDetailScreenState extends ConsumerState<ChildDetailScreen> {
  bool _sending = false;
  int _sendAmount = 50;
  bool _creatingMission = false;

  Future<void> _handleSendCoins(int parentCoinsAvail) async {
    if (_sending) return;
    if (parentCoinsAvail < _sendAmount) {
      _snack('No tienes suficientes monedas 😔', Colors.red.shade700);
      return;
    }

    final ok = await showDialog<bool>(
      context: context,
      builder: (_) => _SendCoinsDialog(
        child: widget.child,
        amount: _sendAmount,
        parentBalance: parentCoinsAvail,
        onAmountChanged: (v) => setState(() => _sendAmount = v),
      ),
    );
    if (ok != true || !mounted) return;

    setState(() => _sending = true);
    try {
      // transferCoinsToChild es atómico (RPC SECURITY DEFINER):
      // valida el vínculo padre-hijo, descuenta del padre, suma al hijo e
      // inserta la notificación en una sola transacción PostgreSQL.
      await WalletRepository().transferCoinsToChild(
        widget.child.id,
        _sendAmount,
      );

      ref.invalidate(currentWalletProvider);
      ref.invalidate(childStatsProvider(widget.child));
      _snack('¡Enviaste $_sendAmount 🪙 a ${widget.child.displayName}!',
          const Color(0xFF2E7D32));
    } catch (e) {
      _snack('Error: ${_friendlyError(e)}', Colors.red.shade700);
    } finally {
      if (mounted) setState(() => _sending = false);
    }
  }

  /// Convierte excepciones del RPC en mensajes amigables.
  String _friendlyError(Object e) {
    final msg = e.toString();
    if (msg.contains('vinculado')) return 'No estás vinculado con este hijo';
    if (msg.contains('insuficiente')) return 'Saldo insuficiente';
    if (msg.contains('padre')) return 'Solo los padres pueden enviar monedas';
    return 'Intenta de nuevo';
  }

  Future<void> _handleCreateMission(int parentCoinsAvail) async {
    if (_creatingMission) return;

    final result = await showDialog<_NewMissionData>(
      context: context,
      builder: (_) => _CreateMissionDialog(
        child: widget.child,
        parentBalance: parentCoinsAvail,
      ),
    );
    if (result == null || !mounted) return;

    setState(() => _creatingMission = true);
    try {
      await ref.read(parentMissionRepositoryProvider).createMission(
            childId: widget.child.id,
            title: result.title,
            description: result.description,
            coinReward: result.coinReward,
          );
      ref.invalidate(missionsCreatedForChildProvider(widget.child.id));
      _snack('¡Misión creada para ${widget.child.displayName}! 🎯',
          const Color(0xFF2E7D32));
    } catch (e) {
      _snack('Error: ${_friendlyError(e)}', Colors.red.shade700);
    } finally {
      if (mounted) setState(() => _creatingMission = false);
    }
  }

  void _snack(String msg, Color bg) =>
      showGamePopup(context, msg, accentColor: bg);

  Future<void> _handleResetPin() async {
    final newPin = await showDialog<String>(
      context: context,
      builder: (_) => _ResetPinDialog(childName: widget.child.displayName),
    );
    if (newPin == null || !mounted) return;

    try {
      await Supabase.instance.client.rpc('parent_reset_child_pin', params: {
        'p_child_id': widget.child.id,
        'p_new_pin': newPin,
      });
      _snack('¡PIN de ${widget.child.displayName} actualizado! 🔑',
          const Color(0xFF2E7D32));
    } catch (e) {
      _snack('Error: ${_friendlyError(e)}', Colors.red.shade700);
    }
  }

  @override
  Widget build(BuildContext context) {
    final statsAsync = ref.watch(childStatsProvider(widget.child));
    final walletAsync = ref.watch(currentWalletProvider);
    final parentCoins = walletAsync.valueOrNull?.totalCoins ?? 0;

    return Scaffold(
      backgroundColor: const Color(0xFF06091A),
      appBar: AppBar(
        backgroundColor: const Color(0xFF0D1230),
        foregroundColor: Colors.white,
        elevation: 0,
        actions: [
          Padding(
            padding: const EdgeInsets.only(right: 4),
            child: IconButton(
              onPressed: _handleResetPin,
              icon: const Icon(Icons.password_rounded),
              tooltip: 'Reiniciar PIN de ${widget.child.displayName}',
              color: Colors.white70,
            ),
          ),
          Padding(
            padding: const EdgeInsets.only(right: 8),
            child: FilledButton.icon(
              onPressed: _creatingMission
                  ? null
                  : () => _handleCreateMission(parentCoins),
              icon: const Icon(Icons.add_task_rounded, size: 18),
              label: const Text(
                'Crear misión',
                style: TextStyle(
                    fontFamily: 'Nunito', fontWeight: FontWeight.w700),
              ),
              style: FilledButton.styleFrom(
                backgroundColor: const Color(0xFF7C3AED),
                foregroundColor: Colors.white,
              ),
            ),
          ),
          Padding(
            padding: const EdgeInsets.only(right: 16),
            child: FilledButton.icon(
              onPressed: _sending ? null : () => _handleSendCoins(parentCoins),
              icon: const AnimatedCoin(size: 16),
              label: const Text(
                'Enviar monedas',
                style: TextStyle(
                    fontFamily: 'Nunito', fontWeight: FontWeight.w700),
              ),
              style: FilledButton.styleFrom(
                backgroundColor: const Color(0xFFFFD600),
                foregroundColor: Colors.black87,
              ),
            ),
          ),
        ],
      ),
      body: statsAsync.when(
        loading: () => const Center(
          child: CircularProgressIndicator(color: Colors.purpleAccent),
        ),
        error: (e, _) => Center(
          child: Text('Error: $e',
              style:
                  const TextStyle(color: Colors.white54, fontFamily: 'Nunito')),
        ),
        data: (stats) => _ChildDetailBody(child: widget.child, stats: stats),
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// Cuerpo principal del detalle
// ─────────────────────────────────────────────────────────────────────────────
class _ChildDetailBody extends StatelessWidget {
  const _ChildDetailBody({required this.child, required this.stats});
  final Profile child;
  final ChildStats stats;

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        // ── Panel izquierdo: carácter ──────────────────────────────────────
        SizedBox(
          width: 260,
          child: _LeftCharPanel(stats: stats),
        ),
        const VerticalDivider(width: 1, color: Colors.white10),
        // ── Panel derecho: actividad recente ──────────────────────────────
        Expanded(
          child: _RightActivityPanel(child: child, stats: stats),
        ),
      ],
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// Panel izquierdo: card de personaje + stats
// ─────────────────────────────────────────────────────────────────────────────
class _LeftCharPanel extends ConsumerWidget {
  const _LeftCharPanel({required this.stats});
  final ChildStats stats;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final loadout = ref.watch(childLoadoutProvider(stats.childId)).valueOrNull;
    return Container(
      color: const Color(0xFF0D1230),
      padding: const EdgeInsets.all(20),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.center,
        children: [
          // Avatar del personaje
          BlinkAvatar(size: 100, bounce: true, loadout: loadout)
              .animate()
              .scale(
                  begin: const Offset(0.7, 0.7),
                  duration: 400.ms,
                  curve: Curves.elasticOut),
          const SizedBox(height: 8),
          // Nivel
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
            decoration: BoxDecoration(
              gradient: const LinearGradient(
                colors: [Color(0xFF7C3AED), Color(0xFFEC4899)],
              ),
              borderRadius: BorderRadius.circular(20),
            ),
            child: Text(
              'Nivel ${stats.level}',
              style: const TextStyle(
                color: Colors.white,
                fontFamily: 'Nunito',
                fontWeight: FontWeight.w800,
                fontSize: 12,
              ),
            ),
          ),
          const SizedBox(height: 16),
          // Nombre y nivel
          Text(
            stats.displayName,
            style: const TextStyle(
              color: Colors.white,
              fontFamily: 'Nunito',
              fontWeight: FontWeight.w900,
              fontSize: 20,
            ),
          ),
          Text(
            'Nivel ${stats.level}',
            style: const TextStyle(
              color: Color(0xFFFFD600),
              fontFamily: 'Nunito',
              fontWeight: FontWeight.w700,
              fontSize: 14,
            ),
          ),
          const SizedBox(height: 16),
          // Barra de progreso al siguiente nivel
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  const Text(
                    '⭐ Experiencia',
                    style: TextStyle(
                      color: Colors.white70,
                      fontFamily: 'Nunito',
                      fontSize: 12,
                    ),
                  ),
                  Text(
                    '${stats.xpInLevel} / 100 XP',
                    style: const TextStyle(
                      color: Colors.white54,
                      fontFamily: 'Nunito',
                      fontSize: 11,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 6),
              ClipRRect(
                borderRadius: BorderRadius.circular(6),
                child: LinearProgressIndicator(
                  value: stats.levelProgress,
                  backgroundColor: Colors.white12,
                  valueColor: const AlwaysStoppedAnimation(Color(0xFF7C3AED)),
                  minHeight: 8,
                ),
              ),
            ],
          ),
          const SizedBox(height: 20),
          const Divider(color: Colors.white10),
          const SizedBox(height: 12),
          // Stat chips
          _StatRow(emoji: '🪙', label: 'Monedas', value: '${stats.totalCoins}'),
          _StatRow(emoji: '⭐', label: 'XP total', value: '${stats.xp}'),
          _StatRow(
              emoji: '🏆', label: 'Misiones', value: '${stats.missionsJoined}'),
          const SizedBox(height: 16),
          const Divider(color: Colors.white10),
          const SizedBox(height: 8),
          const Align(
            alignment: Alignment.centerLeft,
            child: Text(
              '🏅 Medallas',
              style: TextStyle(
                color: Colors.white70,
                fontFamily: 'Nunito',
                fontWeight: FontWeight.w700,
                fontSize: 13,
              ),
            ),
          ),
          const SizedBox(height: 8),
          BadgesRowForChild(childId: stats.childId, maxVisible: 4),
        ],
      ).animate().fadeIn(duration: 300.ms),
    );
  }
}

class _StatRow extends StatelessWidget {
  const _StatRow(
      {required this.emoji, required this.label, required this.value});
  final String emoji, label, value;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 5),
      child: Row(
        children: [
          emoji == '🪙'
              ? const AnimatedCoin(size: 18)
              : Text(emoji, style: const TextStyle(fontSize: 18)),
          const SizedBox(width: 8),
          Expanded(
            child: Text(
              label,
              style: const TextStyle(
                color: Colors.white70,
                fontFamily: 'Nunito',
                fontSize: 13,
              ),
            ),
          ),
          Text(
            value,
            style: const TextStyle(
              color: Colors.white,
              fontFamily: 'Nunito',
              fontWeight: FontWeight.w800,
              fontSize: 14,
            ),
          ),
        ],
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// Panel derecho: actividad reciente del hijo
// ─────────────────────────────────────────────────────────────────────────────
class _RightActivityPanel extends ConsumerStatefulWidget {
  const _RightActivityPanel({required this.child, required this.stats});
  final Profile child;
  final ChildStats stats;

  @override
  ConsumerState<_RightActivityPanel> createState() =>
      _RightActivityPanelState();
}

class _RightActivityPanelState extends ConsumerState<_RightActivityPanel> {
  List<Map<String, dynamic>> _missions = [];
  bool _loading = true;

  @override
  void initState() {
    super.initState();
    _loadActivity();
  }

  final Set<String> _approving = {};

  Future<void> _handleApprove(ParentMission mission) async {
    if (_approving.contains(mission.id)) return;

    final confirm = await showDialog<bool>(
      context: context,
      builder: (_) => AlertDialog(
        backgroundColor: const Color(0xFF0D1230),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(16),
          side: const BorderSide(color: Color(0xFFFFB300), width: 1),
        ),
        title: const Text('¿Confirmar tarea?',
            style: TextStyle(
                color: Colors.white,
                fontFamily: 'Nunito',
                fontWeight: FontWeight.w800)),
        content: Text(
          '${widget.child.displayName} dice que ya hizo "${mission.title}". '
          'Al confirmar se te descontarán ${mission.coinReward} monedas y '
          'se le acreditarán a ${widget.child.displayName}.',
          style: const TextStyle(color: Colors.white70, fontFamily: 'Nunito'),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Todavía no',
                style: TextStyle(color: Colors.white54, fontFamily: 'Nunito')),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(context, true),
            style: FilledButton.styleFrom(
              backgroundColor: const Color(0xFFFFB300),
              foregroundColor: Colors.black87,
            ),
            child: const Text('Sí, confirmar',
                style: TextStyle(
                    fontFamily: 'Nunito', fontWeight: FontWeight.w800)),
          ),
        ],
      ),
    );
    if (confirm != true || !mounted) return;

    setState(() => _approving.add(mission.id));
    try {
      await ref
          .read(parentMissionRepositoryProvider)
          .approveMission(mission.id);
      ref.invalidate(missionsCreatedForChildProvider(widget.child.id));
      ref.invalidate(currentWalletProvider);
      if (mounted) {
        showGamePopup(
          context,
          '¡Confirmado! ${mission.coinReward} monedas para ${widget.child.displayName} 🎉',
          accentColor: const Color(0xFF2E7D32),
        );
      }
    } catch (e) {
      if (mounted) {
        showGamePopup(
          context,
          '$e'.replaceFirst('Exception: ', ''),
          accentColor: Colors.red.shade700,
        );
      }
    } finally {
      if (mounted) setState(() => _approving.remove(mission.id));
    }
  }

  Future<void> _loadActivity() async {
    try {
      final rows = await Supabase.instance.client
          .from('mission_participants')
          .select(
              'mission_id, joined_at, missions(name, coin_reward, xp_reward)')
          .eq('user_id', widget.child.id)
          .order('joined_at', ascending: false)
          .limit(15);
      if (mounted) {
        setState(() {
          _missions = (rows as List).cast<Map<String, dynamic>>();
          _loading = false;
        });
      }
    } catch (_) {
      if (mounted) setState(() => _loading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final createdMissions =
        ref.watch(missionsCreatedForChildProvider(widget.child.id));

    return Container(
      color: const Color(0xFF06091A),
      padding: const EdgeInsets.all(20),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // ── Misiones que el padre le asignó ─────────────────────────────
          const Text(
            '🎯 Misiones que le asignaste',
            style: TextStyle(
              color: Colors.white,
              fontFamily: 'Nunito',
              fontWeight: FontWeight.w800,
              fontSize: 15,
            ),
          ),
          const SizedBox(height: 8),
          SizedBox(
            height: 76,
            child: createdMissions.when(
              loading: () => const Center(
                child: SizedBox(
                  width: 18,
                  height: 18,
                  child: CircularProgressIndicator(
                      strokeWidth: 2, color: Color(0xFF7C3AED)),
                ),
              ),
              error: (_, __) => const _AssignedMissionsEmpty(),
              data: (missions) => missions.isEmpty
                  ? const _AssignedMissionsEmpty()
                  : ListView.separated(
                      scrollDirection: Axis.horizontal,
                      itemCount: missions.length,
                      separatorBuilder: (_, __) => const SizedBox(width: 8),
                      itemBuilder: (ctx, i) => _AssignedMissionChip(
                        mission: missions[i],
                        approving: _approving.contains(missions[i].id),
                        onApprove: missions[i].isAwaitingApproval
                            ? () => _handleApprove(missions[i])
                            : null,
                      ),
                    ),
            ),
          ),
          const SizedBox(height: 16),
          const Divider(color: Colors.white10, height: 1),
          const SizedBox(height: 16),

          // Header
          Row(children: [
            const Text('📋', style: TextStyle(fontSize: 20)),
            const SizedBox(width: 8),
            const Text(
              'Actividad reciente',
              style: TextStyle(
                color: Colors.white,
                fontFamily: 'Nunito',
                fontWeight: FontWeight.w800,
                fontSize: 18,
              ),
            ),
            const Spacer(),
            IconButton(
              onPressed: () => showDialog<void>(
                context: context,
                builder: (_) => SalaryDialog(
                  childId: widget.child.id,
                  childName: widget.child.displayName,
                ),
              ),
              icon: const Text('💰', style: TextStyle(fontSize: 18)),
              tooltip: 'Salario',
            ),
            IconButton(
              onPressed: _loadActivity,
              icon: const Icon(Icons.refresh_rounded,
                  color: Colors.white38, size: 20),
              tooltip: 'Actualizar',
            ),
          ]),
          const SizedBox(height: 4),
          const Text(
            'Misiones en las que participó tu hijo',
            style: TextStyle(
              color: Colors.white38,
              fontFamily: 'Nunito',
              fontSize: 12,
            ),
          ),
          const SizedBox(height: 16),

          // Lista
          Expanded(
            child: _loading
                ? const Center(
                    child: CircularProgressIndicator(color: Color(0xFF7C3AED)))
                : _missions.isEmpty
                    ? _EmptyActivity()
                    : ListView.separated(
                        itemCount: _missions.length,
                        separatorBuilder: (_, __) => const SizedBox(height: 8),
                        itemBuilder: (ctx, i) {
                          final entry = _missions[i];
                          final mission =
                              entry['missions'] as Map<String, dynamic>?;
                          final name = mission?['name'] as String? ??
                              'Misión desconocida';
                          final coins = mission?['coin_reward'] as int? ?? 0;
                          final xp = mission?['xp_reward'] as int? ?? 0;
                          final dateStr = entry['joined_at'] as String?;
                          final date = dateStr != null
                              ? DateTime.tryParse(dateStr)
                              : null;

                          return _ActivityCard(
                            name: name,
                            coins: coins,
                            xp: xp,
                            date: date,
                          )
                              .animate(delay: (40 * i).ms)
                              .fadeIn(duration: 250.ms);
                        },
                      ),
          ),
        ],
      ),
    );
  }
}

class _AssignedMissionsEmpty extends StatelessWidget {
  const _AssignedMissionsEmpty();

  @override
  Widget build(BuildContext context) {
    return const Center(
      child: Text(
        'Aún no le asignaste ninguna misión.',
        style: TextStyle(
            color: Colors.white38, fontFamily: 'Nunito', fontSize: 12),
      ),
    );
  }
}

class _AssignedMissionChip extends StatelessWidget {
  const _AssignedMissionChip({
    required this.mission,
    this.approving = false,
    this.onApprove,
  });
  final ParentMission mission;
  final bool approving;
  final VoidCallback? onApprove;

  @override
  Widget build(BuildContext context) {
    final done = mission.isCompleted;
    final waiting = mission.isAwaitingApproval;
    final accent = done
        ? const Color(0xFF10B981)
        : waiting
            ? const Color(0xFFFFB300)
            : const Color(0xFF7C3AED);

    final content = Container(
      width: 150,
      padding: const EdgeInsets.all(10),
      decoration: BoxDecoration(
        color: const Color(0xFF12103A),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: accent.withAlpha(waiting ? 200 : 100)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(
            mission.title,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: const TextStyle(
              color: Colors.white,
              fontFamily: 'Nunito',
              fontWeight: FontWeight.w700,
              fontSize: 12,
            ),
          ),
          if (waiting)
            Padding(
              padding: const EdgeInsets.only(top: 2, bottom: 2),
              child: Text(
                approving ? 'Confirmando…' : 'Toca para confirmar',
                style: const TextStyle(
                  color: Color(0xFFFFB300),
                  fontFamily: 'Nunito',
                  fontWeight: FontWeight.w700,
                  fontSize: 9,
                ),
              ),
            ),
          Row(
            children: [
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                decoration: BoxDecoration(
                  color: accent.withAlpha(40),
                  borderRadius: BorderRadius.circular(6),
                ),
                child: Text(
                  done
                      ? 'Completada'
                      : waiting
                          ? '⏳ Esperando'
                          : 'Pendiente',
                  style: TextStyle(
                    color: accent,
                    fontFamily: 'Nunito',
                    fontWeight: FontWeight.w700,
                    fontSize: 9,
                  ),
                ),
              ),
              const Spacer(),
              Text('${mission.coinReward}',
                  style: const TextStyle(
                      color: Color(0xFFFFD600),
                      fontFamily: 'Nunito',
                      fontWeight: FontWeight.w700,
                      fontSize: 11)),
              const SizedBox(width: 2),
              const AnimatedCoin(size: 11),
            ],
          ),
        ],
      ),
    );

    if (onApprove == null) return content;
    return GestureDetector(onTap: approving ? null : onApprove, child: content);
  }
}

class _ActivityCard extends StatelessWidget {
  const _ActivityCard({
    required this.name,
    required this.coins,
    required this.xp,
    this.date,
  });
  final String name;
  final int coins;
  final int xp;
  final DateTime? date;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
      decoration: BoxDecoration(
        color: const Color(0xFF0D1230),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: Colors.white10),
      ),
      child: Row(children: [
        const Text('🏆', style: TextStyle(fontSize: 22)),
        const SizedBox(width: 12),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                name,
                style: const TextStyle(
                  color: Colors.white,
                  fontFamily: 'Nunito',
                  fontWeight: FontWeight.w700,
                  fontSize: 13,
                ),
              ),
              if (date != null)
                Text(
                  _formatDate(date!),
                  style: const TextStyle(
                    color: Colors.white38,
                    fontFamily: 'Nunito',
                    fontSize: 11,
                  ),
                ),
            ],
          ),
        ),
        Column(
          crossAxisAlignment: CrossAxisAlignment.end,
          children: [
            Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  '+$coins',
                  style: const TextStyle(
                    color: Color(0xFFFFD600),
                    fontFamily: 'Nunito',
                    fontWeight: FontWeight.w800,
                    fontSize: 12,
                  ),
                ),
                const SizedBox(width: 3),
                const AnimatedCoin(size: 12),
              ],
            ),
            Text(
              '+$xp ⭐',
              style: const TextStyle(
                color: Color(0xFFBB86FC),
                fontFamily: 'Nunito',
                fontSize: 11,
              ),
            ),
          ],
        ),
      ]),
    );
  }

  String _formatDate(DateTime d) {
    final diff = DateTime.now().difference(d);
    if (diff.inDays == 0) return 'Hoy';
    if (diff.inDays == 1) return 'Ayer';
    return 'Hace ${diff.inDays} días';
  }
}

class _EmptyActivity extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return const Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Text('🎮', style: TextStyle(fontSize: 48)),
          SizedBox(height: 12),
          Text(
            '¡Aún no hay actividad!',
            style: TextStyle(
              color: Colors.white70,
              fontFamily: 'Nunito',
              fontWeight: FontWeight.w700,
              fontSize: 16,
            ),
          ),
          SizedBox(height: 6),
          Text(
            'Cuando tu hijo complete misiones\naparecerán aquí.',
            textAlign: TextAlign.center,
            style: TextStyle(
              color: Colors.white38,
              fontFamily: 'Nunito',
              fontSize: 13,
            ),
          ),
        ],
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// Diálogo para crear una misión de papá
// ─────────────────────────────────────────────────────────────────────────────
class _NewMissionData {
  const _NewMissionData(
      {required this.title, this.description, required this.coinReward});
  final String title;
  final String? description;
  final int coinReward;
}

class _CreateMissionDialog extends StatefulWidget {
  const _CreateMissionDialog(
      {required this.child, required this.parentBalance});
  final Profile child;
  final int parentBalance;

  @override
  State<_CreateMissionDialog> createState() => _CreateMissionDialogState();
}

class _CreateMissionDialogState extends State<_CreateMissionDialog> {
  final _titleCtrl = TextEditingController();
  final _descCtrl = TextEditingController();
  final _steps = [10, 20, 50, 100];
  int _reward = 20;
  int _step = 0; // asistente de 3 pasos: título → instrucciones → recompensa
  static const _totalSteps = 3;

  @override
  void dispose() {
    _titleCtrl.dispose();
    _descCtrl.dispose();
    super.dispose();
  }

  static const _fieldFill = Color(0x14FFFFFF); // blanco 8% — fondo del campo

  InputDecoration _fieldDecoration({
    required String label,
    required String hint,
  }) {
    return InputDecoration(
      filled: true,
      fillColor: _fieldFill,
      labelText: label,
      hintText: hint,
      labelStyle: const TextStyle(color: Colors.white54, fontFamily: 'Nunito'),
      hintStyle: const TextStyle(color: Colors.white30, fontFamily: 'Nunito'),
      counterStyle: const TextStyle(color: Colors.white30),
      contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 12),
      border: OutlineInputBorder(
        borderRadius: BorderRadius.circular(12),
        borderSide: const BorderSide(color: Colors.white24),
      ),
      enabledBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(12),
        borderSide: const BorderSide(color: Colors.white24),
      ),
      focusedBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(12),
        borderSide: const BorderSide(color: Color(0xFF7C3AED), width: 2),
      ),
    );
  }

  bool _canAdvance(bool titleOk, bool canAfford) {
    return switch (_step) {
      0 => titleOk,
      1 => true,
      _ => canAfford,
    };
  }

  Widget _titleStep() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      mainAxisSize: MainAxisSize.min,
      children: [
        const Text('¿Cuál es la misión?',
            style: TextStyle(
                color: Colors.white70,
                fontFamily: 'Nunito',
                fontWeight: FontWeight.w700,
                fontSize: 13)),
        const SizedBox(height: 10),
        TextField(
          controller: _titleCtrl,
          autofocus: true,
          maxLength: 60,
          style: const TextStyle(color: Colors.white, fontFamily: 'Nunito'),
          decoration: _fieldDecoration(
            label: 'Título de la misión',
            hint: 'Ej: Tender la cama',
          ),
          onChanged: (_) => setState(() {}),
        ),
      ],
    );
  }

  Widget _descriptionStep() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      mainAxisSize: MainAxisSize.min,
      children: [
        const Text('¿Alguna instrucción para tu hijo? (opcional)',
            style: TextStyle(
                color: Colors.white70,
                fontFamily: 'Nunito',
                fontWeight: FontWeight.w700,
                fontSize: 13)),
        const SizedBox(height: 10),
        TextField(
          controller: _descCtrl,
          autofocus: true,
          maxLines: 3,
          maxLength: 140,
          style: const TextStyle(
              color: Colors.white, fontFamily: 'Nunito', fontSize: 13),
          decoration: _fieldDecoration(
            label: 'Instrucciones (opcional)',
            hint: 'Ej: Todos los días antes de las 9am',
          ),
        ),
      ],
    );
  }

  Widget _rewardStep() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      mainAxisSize: MainAxisSize.min,
      children: [
        Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(
              'Tu saldo: ${widget.parentBalance}',
              style: const TextStyle(
                  color: Colors.white54, fontFamily: 'Nunito', fontSize: 13),
            ),
            const SizedBox(width: 4),
            const AnimatedCoin(size: 13),
          ],
        ),
        const SizedBox(height: 8),
        const Text('¿Cuántas monedas de recompensa?',
            style: TextStyle(
                color: Colors.white70,
                fontFamily: 'Nunito',
                fontWeight: FontWeight.w700,
                fontSize: 13)),
        const SizedBox(height: 8),
        Wrap(
          spacing: 8,
          runSpacing: 8,
          children: _steps.map((s) {
            final selected = s == _reward;
            final affordable = s <= widget.parentBalance;
            return GestureDetector(
              onTap: affordable ? () => setState(() => _reward = s) : null,
              child: Container(
                padding:
                    const EdgeInsets.symmetric(horizontal: 14, vertical: 6),
                decoration: BoxDecoration(
                  color: selected
                      ? const Color(0xFFFFD600)
                      : affordable
                          ? Colors.white10
                          : Colors.white.withAlpha(10),
                  borderRadius: BorderRadius.circular(20),
                  border: Border.all(
                    color:
                        selected ? const Color(0xFFFFD600) : Colors.white24,
                  ),
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text(
                      '$s',
                      style: TextStyle(
                        color: selected
                            ? Colors.black87
                            : affordable
                                ? Colors.white
                                : Colors.white24,
                        fontFamily: 'Nunito',
                        fontWeight: FontWeight.w700,
                        fontSize: 13,
                      ),
                    ),
                    const SizedBox(width: 3),
                    const AnimatedCoin(size: 13),
                  ],
                ),
              ),
            );
          }).toList(),
        ),
      ],
    );
  }

  @override
  Widget build(BuildContext context) {
    final titleOk = _titleCtrl.text.trim().isNotEmpty;
    final canAfford = _reward <= widget.parentBalance;

    // Dialog propio (en vez de AlertDialog): tamaño y posición fijos, sin
    // reaccionar al teclado — el niño... digo, el padre, sigue viendo el
    // popup completo en vez de que se achique o se corra al escribir.
    // Asistente de 3 pasos (título → instrucciones → recompensa) en vez de
    // un solo formulario con todo junto.
    return MediaQuery.removeViewInsets(
      context: context,
      removeBottom: true,
      child: Dialog(
        backgroundColor: const Color(0xFF0D1230),
        insetPadding: const EdgeInsets.symmetric(horizontal: 24, vertical: 20),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(20),
          side: const BorderSide(color: Color(0xFF7C3AED), width: 1),
        ),
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 420, maxHeight: 360),
          child: Padding(
            padding: const EdgeInsets.all(20),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(children: [
                  const Text('👨‍👩‍👧', style: TextStyle(fontSize: 26)),
                  const SizedBox(width: 10),
                  Expanded(
                    child: Text(
                      'Misión para\n${widget.child.displayName}',
                      style: const TextStyle(
                        color: Colors.white,
                        fontFamily: 'Nunito',
                        fontWeight: FontWeight.w800,
                        fontSize: 16,
                      ),
                    ),
                  ),
                ]),
                const SizedBox(height: 14),
                Row(
                  children: List.generate(_totalSteps, (i) {
                    return AnimatedContainer(
                      duration: const Duration(milliseconds: 250),
                      margin: const EdgeInsets.only(right: 6),
                      width: i == _step ? 22 : 8,
                      height: 8,
                      decoration: BoxDecoration(
                        color: i <= _step
                            ? const Color(0xFF7C3AED)
                            : Colors.white24,
                        borderRadius: BorderRadius.circular(4),
                      ),
                    );
                  }),
                ),
                const SizedBox(height: 18),
                SizedBox(
                  height: 160,
                  child: SingleChildScrollView(
                    child: switch (_step) {
                      0 => _titleStep(),
                      1 => _descriptionStep(),
                      _ => _rewardStep(),
                    },
                  ),
                ),
                const SizedBox(height: 20),
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    TextButton(
                      onPressed: _step == 0
                          ? () => Navigator.pop(context)
                          : () => setState(() => _step--),
                      child: Text(_step == 0 ? 'Cancelar' : 'Atrás',
                          style: const TextStyle(
                              color: Colors.white54, fontFamily: 'Nunito')),
                    ),
                    FilledButton(
                      onPressed: _canAdvance(titleOk, canAfford)
                          ? () {
                              if (_step < _totalSteps - 1) {
                                setState(() => _step++);
                              } else {
                                Navigator.pop(
                                  context,
                                  _NewMissionData(
                                    title: _titleCtrl.text.trim(),
                                    description: _descCtrl.text.trim().isEmpty
                                        ? null
                                        : _descCtrl.text.trim(),
                                    coinReward: _reward,
                                  ),
                                );
                              }
                            }
                          : null,
                      style: FilledButton.styleFrom(
                        backgroundColor: const Color(0xFF7C3AED),
                        foregroundColor: Colors.white,
                        shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(12)),
                      ),
                      child: Text(
                          _step < _totalSteps - 1 ? 'Siguiente' : 'Crear misión',
                          style: const TextStyle(
                              fontFamily: 'Nunito',
                              fontWeight: FontWeight.w800)),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// Diálogo para reiniciar el PIN del hijo
// ─────────────────────────────────────────────────────────────────────────────
class _ResetPinDialog extends StatefulWidget {
  const _ResetPinDialog({required this.childName});
  final String childName;

  @override
  State<_ResetPinDialog> createState() => _ResetPinDialogState();
}

class _ResetPinDialogState extends State<_ResetPinDialog> {
  // Pasos: 0 = nuevo PIN, 1 = confirmar
  int _step = 0;
  String _pin = '';
  String _pinConfirm = '';
  String _errorMsg = '';

  void _onDigit(String digit) {
    if (_step == 0) {
      if (_pin.length >= 6) return;
      setState(() {
        _pin += digit;
        _errorMsg = '';
      });
      if (_pin.length == 6) {
        Future.delayed(const Duration(milliseconds: 200), () {
          if (mounted) setState(() => _step = 1);
        });
      }
    } else {
      if (_pinConfirm.length >= 6) return;
      setState(() {
        _pinConfirm += digit;
        _errorMsg = '';
      });
      if (_pinConfirm.length == 6) {
        if (_pinConfirm == _pin) {
          Navigator.of(context).pop(_pin);
        } else {
          setState(() {
            _errorMsg = 'Los PINs no coinciden. Inténtalo de nuevo.';
            _pinConfirm = '';
          });
        }
      }
    }
  }

  void _onDelete() {
    setState(() {
      if (_step == 0 && _pin.isNotEmpty) {
        _pin = _pin.substring(0, _pin.length - 1);
      } else if (_step == 1 && _pinConfirm.isNotEmpty) {
        _pinConfirm = _pinConfirm.substring(0, _pinConfirm.length - 1);
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    final currentPin = _step == 0 ? _pin : _pinConfirm;
    return Dialog(
      backgroundColor: const Color(0xFF0D1230),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(24)),
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Icon(Icons.password_rounded,
                color: Color(0xFF4FC3F7), size: 36),
            const SizedBox(height: 12),
            Text(
              _step == 0
                  ? 'Nuevo PIN para\n${widget.childName}'
                  : 'Confirma el nuevo PIN',
              textAlign: TextAlign.center,
              style: const TextStyle(
                fontFamily: 'Nunito',
                fontWeight: FontWeight.w800,
                fontSize: 18,
                color: Colors.white,
              ),
            ),
            if (_errorMsg.isNotEmpty) ...[
              const SizedBox(height: 10),
              Text(
                _errorMsg,
                textAlign: TextAlign.center,
                style: const TextStyle(
                    color: Colors.redAccent,
                    fontFamily: 'Nunito',
                    fontSize: 13),
              ),
            ],
            const SizedBox(height: 20),
            Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: List.generate(6, (i) {
                final filled = i < currentPin.length;
                return Container(
                  margin: const EdgeInsets.symmetric(horizontal: 6),
                  width: 16,
                  height: 16,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    color:
                        filled ? const Color(0xFF4FC3F7) : Colors.transparent,
                    border: Border.all(
                      color: filled ? const Color(0xFF4FC3F7) : Colors.white38,
                      width: 2,
                    ),
                  ),
                );
              }),
            ),
            const SizedBox(height: 20),
            PinPadWidget(onDigit: _onDigit, onDelete: _onDelete),
            const SizedBox(height: 8),
            TextButton(
              onPressed: () => Navigator.of(context).pop(),
              child: const Text('Cancelar',
                  style:
                      TextStyle(color: Colors.white38, fontFamily: 'Nunito')),
            ),
          ],
        ),
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// Diálogo para enviar monedas
// ─────────────────────────────────────────────────────────────────────────────
class _SendCoinsDialog extends StatefulWidget {
  const _SendCoinsDialog({
    required this.child,
    required this.amount,
    required this.parentBalance,
    required this.onAmountChanged,
  });
  final Profile child;
  final int amount;
  final int parentBalance;
  final void Function(int) onAmountChanged;

  @override
  State<_SendCoinsDialog> createState() => _SendCoinsDialogState();
}

class _SendCoinsDialogState extends State<_SendCoinsDialog> {
  late int _amount;
  final _steps = [10, 25, 50, 100, 200, 500];

  @override
  void initState() {
    super.initState();
    _amount = widget.amount;
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      backgroundColor: const Color(0xFF0D1230),
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(20),
        side: const BorderSide(color: Color(0xFF7C3AED), width: 1),
      ),
      title: Row(children: [
        const AnimatedCoin(size: 28),
        const SizedBox(width: 10),
        Expanded(
          child: Text(
            'Enviar monedas a\n${widget.child.displayName}',
            style: const TextStyle(
              color: Colors.white,
              fontFamily: 'Nunito',
              fontWeight: FontWeight.w800,
              fontSize: 16,
            ),
          ),
        ),
      ]),
      content: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(
                'Tu saldo: ${widget.parentBalance}',
                style: const TextStyle(
                  color: Colors.white54,
                  fontFamily: 'Nunito',
                  fontSize: 13,
                ),
              ),
              const SizedBox(width: 4),
              const AnimatedCoin(size: 13),
            ],
          ),
          const SizedBox(height: 16),
          // Cantidad seleccionada
          Text(
            '$_amount',
            style: const TextStyle(
              color: Color(0xFFFFD600),
              fontFamily: 'Nunito',
              fontWeight: FontWeight.w900,
              fontSize: 48,
            ),
          ),
          const Text(
            'monedas',
            style: TextStyle(
              color: Colors.white38,
              fontFamily: 'Nunito',
              fontSize: 13,
            ),
          ),
          const SizedBox(height: 16),
          // Botones de cantidad
          Wrap(
            spacing: 8,
            runSpacing: 8,
            alignment: WrapAlignment.center,
            children: _steps.map((s) {
              final selected = s == _amount;
              final canAfford = s <= widget.parentBalance;
              return GestureDetector(
                onTap: canAfford
                    ? () {
                        setState(() => _amount = s);
                        widget.onAmountChanged(s);
                      }
                    : null,
                child: Container(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 14, vertical: 6),
                  decoration: BoxDecoration(
                    color: selected
                        ? const Color(0xFFFFD600)
                        : canAfford
                            ? Colors.white10
                            : Colors.white.withAlpha(10),
                    borderRadius: BorderRadius.circular(20),
                    border: Border.all(
                      color:
                          selected ? const Color(0xFFFFD600) : Colors.white24,
                    ),
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Text(
                        '$s',
                        style: TextStyle(
                          color: selected
                              ? Colors.black87
                              : canAfford
                                  ? Colors.white
                                  : Colors.white24,
                          fontFamily: 'Nunito',
                          fontWeight: FontWeight.w700,
                          fontSize: 13,
                        ),
                      ),
                      const SizedBox(width: 3),
                      const AnimatedCoin(
                        size: 13,
                      ),
                    ],
                  ),
                ),
              );
            }).toList(),
          ),
        ],
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(context, false),
          child: const Text(
            'Cancelar',
            style: TextStyle(color: Colors.white54, fontFamily: 'Nunito'),
          ),
        ),
        FilledButton(
          onPressed: _amount <= widget.parentBalance
              ? () => Navigator.pop(context, true)
              : null,
          style: FilledButton.styleFrom(
            backgroundColor: const Color(0xFFFFD600),
            foregroundColor: Colors.black87,
            shape:
                RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(
                '¡Enviar $_amount',
                style: const TextStyle(
                  fontFamily: 'Nunito',
                  fontWeight: FontWeight.w800,
                ),
              ),
              const SizedBox(width: 4),
              const AnimatedCoin(size: 15),
              const Text(
                '!',
                style: TextStyle(
                  fontFamily: 'Nunito',
                  fontWeight: FontWeight.w800,
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// SalaryDialog — asigna/edita el salario semanal de un hijo
// ─────────────────────────────────────────────────────────────────────────────
class SalaryDialog extends StatefulWidget {
  const SalaryDialog(
      {super.key, required this.childId, required this.childName});
  final String childId;
  final String childName;

  @override
  State<SalaryDialog> createState() => _SalaryDialogState();
}

class _SalaryDialogState extends State<SalaryDialog> {
  int _amount = 25;
  bool _loading = false;
  bool _saved = false;
  String? _error;

  static const _min = 20;
  static const _max = 35;

  Future<void> _save() async {
    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      await SalaryRepository().upsertSalary(
        childId: widget.childId,
        amount: _amount,
      );
      if (mounted) {
        setState(() {
          _loading = false;
          _saved = true;
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _loading = false;
          _error = 'Error al guardar. Verifica tu conexión.';
        });
      }
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
                onChanged:
                    _saved ? null : (v) => setState(() => _amount = v.toInt()),
              ),
              const Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text('$_min',
                      style: TextStyle(color: Colors.white38, fontSize: 11)),
                  Text('$_max',
                      style: TextStyle(color: Colors.white38, fontSize: 11)),
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
                    border:
                        Border.all(color: Colors.greenAccent.withOpacity(0.5)),
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
