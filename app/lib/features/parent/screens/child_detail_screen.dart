import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../../../data/models/profile.dart';
import '../../../data/repositories/parent_repository.dart';
import '../../../data/repositories/wallet_repository.dart';
import '../../../shared/providers/parent_mission_provider.dart';
import '../../../shared/providers/parent_provider.dart';
import '../../../shared/providers/wallet_provider.dart';
import '../../../shared/widgets/badges_row.dart';
import '../../../shared/widgets/coin_display.dart';

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
  int  _sendAmount = 50;
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
        child:         widget.child,
        amount:        _sendAmount,
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
            childId:     widget.child.id,
            title:       result.title,
            description: result.description,
            coinReward:  result.coinReward,
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

  void _snack(String msg, Color bg) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(msg, style: const TextStyle(fontFamily: 'Nunito')),
        backgroundColor: bg,
        behavior: SnackBarBehavior.floating,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final statsAsync  = ref.watch(childStatsProvider(widget.child));
    final walletAsync = ref.watch(currentWalletProvider);
    final parentCoins = walletAsync.valueOrNull?.totalCoins ?? 0;

    return Scaffold(
      backgroundColor: const Color(0xFF06091A),
      appBar: AppBar(
        backgroundColor: const Color(0xFF0D1230),
        foregroundColor: Colors.white,
        elevation: 0,
        title: Row(children: [
          const Text('🦊', style: TextStyle(fontSize: 22)),
          const SizedBox(width: 8),
          Text(
            widget.child.displayName,
            style: const TextStyle(
              fontFamily: 'Nunito',
              fontWeight: FontWeight.w800,
              fontSize: 18,
            ),
          ),
        ]),
        actions: [
          Padding(
            padding: const EdgeInsets.only(right: 8),
            child: OutlinedButton.icon(
              onPressed: _creatingMission ? null : () => _handleCreateMission(parentCoins),
              icon: const Icon(Icons.add_task_rounded, size: 18),
              label: const Text(
                'Crear misión',
                style: TextStyle(fontFamily: 'Nunito', fontWeight: FontWeight.w700),
              ),
              style: OutlinedButton.styleFrom(
                foregroundColor: const Color(0xFF7C3AED),
                side: const BorderSide(color: Color(0xFF7C3AED)),
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
                style: TextStyle(fontFamily: 'Nunito', fontWeight: FontWeight.w700),
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
              style: const TextStyle(color: Colors.white54, fontFamily: 'Nunito')),
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
  final Profile    child;
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
class _LeftCharPanel extends StatelessWidget {
  const _LeftCharPanel({required this.stats});
  final ChildStats stats;

  @override
  Widget build(BuildContext context) {
    return Container(
      color: const Color(0xFF0D1230),
      padding: const EdgeInsets.all(20),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.center,
        children: [
          // Avatar del personaje
          const Text('🦊', style: TextStyle(fontSize: 72))
              .animate()
              .scale(begin: const Offset(0.7, 0.7), duration: 400.ms, curve: Curves.elasticOut),
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
                  value:            stats.levelProgress,
                  backgroundColor:  Colors.white12,
                  valueColor:       const AlwaysStoppedAnimation(Color(0xFF7C3AED)),
                  minHeight:        8,
                ),
              ),
            ],
          ),
          const SizedBox(height: 20),
          const Divider(color: Colors.white10),
          const SizedBox(height: 12),
          // Stat chips
          _StatRow(emoji: '🪙', label: 'Monedas',   value: '${stats.totalCoins}'),
          _StatRow(emoji: '⭐', label: 'XP total',   value: '${stats.xp}'),
          _StatRow(emoji: '🏆', label: 'Misiones',  value: '${stats.missionsJoined}'),
          const SizedBox(height: 16),
          const Divider(color: Colors.white10),
          const SizedBox(height: 8),
          const Align(
            alignment: Alignment.centerLeft,
            child: Text(
              '🏅 Medallas',
              style: TextStyle(
                color:      Colors.white70,
                fontFamily: 'Nunito',
                fontWeight: FontWeight.w700,
                fontSize:   13,
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
  const _StatRow({required this.emoji, required this.label, required this.value});
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
class _RightActivityPanel extends StatefulWidget {
  const _RightActivityPanel({required this.child, required this.stats});
  final Profile    child;
  final ChildStats stats;

  @override
  State<_RightActivityPanel> createState() => _RightActivityPanelState();
}

class _RightActivityPanelState extends State<_RightActivityPanel> {
  List<Map<String, dynamic>> _missions = [];
  bool _loading = true;

  @override
  void initState() {
    super.initState();
    _loadActivity();
  }

  Future<void> _loadActivity() async {
    try {
      final rows = await Supabase.instance.client
          .from('mission_participants')
          .select('mission_id, joined_at, missions(name, coin_reward, xp_reward)')
          .eq('user_id', widget.child.id)
          .order('joined_at', ascending: false)
          .limit(15);
      if (mounted) {
        setState(() {
          _missions = (rows as List).cast<Map<String, dynamic>>();
          _loading  = false;
        });
      }
    } catch (_) {
      if (mounted) setState(() => _loading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      color: const Color(0xFF06091A),
      padding: const EdgeInsets.all(20),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
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
              onPressed: _loadActivity,
              icon: const Icon(Icons.refresh_rounded, color: Colors.white38, size: 20),
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
                ? const Center(child: CircularProgressIndicator(color: Color(0xFF7C3AED)))
                : _missions.isEmpty
                    ? _EmptyActivity()
                    : ListView.separated(
                        itemCount: _missions.length,
                        separatorBuilder: (_, __) => const SizedBox(height: 8),
                        itemBuilder: (ctx, i) {
                          final entry   = _missions[i];
                          final mission = entry['missions'] as Map<String, dynamic>?;
                          final name    = mission?['name'] as String? ?? 'Misión desconocida';
                          final coins   = mission?['coin_reward'] as int? ?? 0;
                          final xp      = mission?['xp_reward']  as int? ?? 0;
                          final dateStr = entry['joined_at'] as String?;
                          final date    = dateStr != null
                              ? DateTime.tryParse(dateStr)
                              : null;

                          return _ActivityCard(
                            name:  name,
                            coins: coins,
                            xp:    xp,
                            date:  date,
                          ).animate(delay: (40 * i).ms).fadeIn(duration: 250.ms);
                        },
                      ),
          ),
        ],
      ),
    );
  }
}

class _ActivityCard extends StatelessWidget {
  const _ActivityCard({
    required this.name,
    required this.coins,
    required this.xp,
    this.date,
  });
  final String    name;
  final int       coins;
  final int       xp;
  final DateTime? date;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
      decoration: BoxDecoration(
        color:        const Color(0xFF0D1230),
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
    if (diff.inDays == 0)  return 'Hoy';
    if (diff.inDays == 1)  return 'Ayer';
    return 'Hace ${diff.inDays} días';
  }
}

class _EmptyActivity extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          const Text('🎮', style: TextStyle(fontSize: 48)),
          const SizedBox(height: 12),
          const Text(
            '¡Aún no hay actividad!',
            style: TextStyle(
              color: Colors.white70,
              fontFamily: 'Nunito',
              fontWeight: FontWeight.w700,
              fontSize: 16,
            ),
          ),
          const SizedBox(height: 6),
          const Text(
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
  const _NewMissionData({required this.title, this.description, required this.coinReward});
  final String  title;
  final String? description;
  final int     coinReward;
}

class _CreateMissionDialog extends StatefulWidget {
  const _CreateMissionDialog({required this.child, required this.parentBalance});
  final Profile child;
  final int     parentBalance;

  @override
  State<_CreateMissionDialog> createState() => _CreateMissionDialogState();
}

class _CreateMissionDialogState extends State<_CreateMissionDialog> {
  final _titleCtrl = TextEditingController();
  final _descCtrl  = TextEditingController();
  final _steps     = [10, 20, 50, 100];
  int _reward = 20;

  @override
  void dispose() {
    _titleCtrl.dispose();
    _descCtrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final titleOk = _titleCtrl.text.trim().isNotEmpty;
    final canAfford = _reward <= widget.parentBalance;

    return AlertDialog(
      backgroundColor: const Color(0xFF0D1230),
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(20),
        side: const BorderSide(color: Color(0xFF7C3AED), width: 1),
      ),
      title: Row(children: [
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
      content: SingleChildScrollView(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            TextField(
              controller: _titleCtrl,
              maxLength: 60,
              style: const TextStyle(color: Colors.white, fontFamily: 'Nunito'),
              decoration: const InputDecoration(
                labelText: 'Título de la misión',
                labelStyle: TextStyle(color: Colors.white54, fontFamily: 'Nunito'),
                counterStyle: TextStyle(color: Colors.white30),
                enabledBorder: UnderlineInputBorder(borderSide: BorderSide(color: Colors.white24)),
                focusedBorder: UnderlineInputBorder(borderSide: BorderSide(color: Color(0xFF7C3AED))),
              ),
              onChanged: (_) => setState(() {}),
            ),
            const SizedBox(height: 8),
            TextField(
              controller: _descCtrl,
              maxLines: 2,
              maxLength: 140,
              style: const TextStyle(color: Colors.white, fontFamily: 'Nunito', fontSize: 13),
              decoration: const InputDecoration(
                labelText: 'Descripción (opcional)',
                labelStyle: TextStyle(color: Colors.white54, fontFamily: 'Nunito'),
                counterStyle: TextStyle(color: Colors.white30),
                enabledBorder: UnderlineInputBorder(borderSide: BorderSide(color: Colors.white24)),
                focusedBorder: UnderlineInputBorder(borderSide: BorderSide(color: Color(0xFF7C3AED))),
              ),
            ),
            const SizedBox(height: 16),
            Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  'Tu saldo: ${widget.parentBalance}',
                  style: const TextStyle(color: Colors.white54, fontFamily: 'Nunito', fontSize: 13),
                ),
                const SizedBox(width: 4),
                const AnimatedCoin(size: 13),
              ],
            ),
            const SizedBox(height: 8),
            const Text(
              'Recompensa',
              style: TextStyle(color: Colors.white38, fontFamily: 'Nunito', fontSize: 12),
            ),
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
                    padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 6),
                    decoration: BoxDecoration(
                      color: selected
                          ? const Color(0xFFFFD600)
                          : affordable
                              ? Colors.white10
                              : Colors.white.withAlpha(10),
                      borderRadius: BorderRadius.circular(20),
                      border: Border.all(
                        color: selected ? const Color(0xFFFFD600) : Colors.white24,
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
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(context),
          child: const Text('Cancelar', style: TextStyle(color: Colors.white54, fontFamily: 'Nunito')),
        ),
        FilledButton(
          onPressed: (titleOk && canAfford)
              ? () => Navigator.pop(
                    context,
                    _NewMissionData(
                      title: _titleCtrl.text.trim(),
                      description: _descCtrl.text.trim().isEmpty ? null : _descCtrl.text.trim(),
                      coinReward: _reward,
                    ),
                  )
              : null,
          style: FilledButton.styleFrom(
            backgroundColor: const Color(0xFF7C3AED),
            foregroundColor: Colors.white,
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
          ),
          child: const Text('Crear misión', style: TextStyle(fontFamily: 'Nunito', fontWeight: FontWeight.w800)),
        ),
      ],
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
  final Profile  child;
  final int      amount;
  final int      parentBalance;
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
                  padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 6),
                  decoration: BoxDecoration(
                    color: selected
                        ? const Color(0xFFFFD600)
                        : canAfford
                            ? Colors.white10
                            : Colors.white.withAlpha(10),
                    borderRadius: BorderRadius.circular(20),
                    border: Border.all(
                      color: selected ? const Color(0xFFFFD600) : Colors.white24,
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
                      AnimatedCoin(
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
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
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
