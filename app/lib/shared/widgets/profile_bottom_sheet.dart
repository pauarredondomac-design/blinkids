import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../../data/models/profile.dart';
import 'blink_character.dart';
import '../providers/auth_provider.dart';
import '../providers/profile_provider.dart';
import '../providers/wallet_provider.dart';
import '../providers/character_provider.dart';
import '../providers/world_provider.dart';
import '../providers/cosmetic_provider.dart';
import 'coin_display.dart';
import '../../features/worlds/vestidor/vestidor_screen.dart';

// ─────────────────────────────────────────────────────────────────────────────
// ProfileBottomSheet
// Hoja de perfil y configuración del niño.
// Se abre al tocar el avatar en el HUD del mundo.
// ─────────────────────────────────────────────────────────────────────────────
class ProfileBottomSheet extends ConsumerWidget {
  const ProfileBottomSheet({super.key, required this.accentColor});

  final Color accentColor;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final profile = ref.watch(currentProfileProvider).valueOrNull;
    final character = ref.watch(currentCharacterProvider).valueOrNull;
    final wallet = ref.watch(currentWalletProvider).valueOrNull;
    final world = ref.watch(currentWorldProvider);

    final supaUser = Supabase.instance.client.auth.currentUser;
    final isDemo = supaUser == null || (supaUser.isAnonymous == true);

    // Si hay sesión real pero el profile aún carga, mostrar datos parciales
    final name = profile?.displayName ?? (isDemo ? 'Blink' : '...');
    final xp = character?.xp ?? 0;
    final level = character?.level ?? 1;
    final coins = wallet?.totalCoins ?? 0;
    final emoji = _characterEmoji(xp);
    final xpPct = _xpProgress(xp);
    final xpLbl = _xpLabel(xp);
    // isChild: verdadero si el perfil lo dice, O si hay sesión real y el perfil aún carga
    final isChild =
        profile?.role == UserRole.child || (!isDemo && profile == null);

    final bottomPad = MediaQuery.of(context).padding.bottom;
    final maxH = MediaQuery.of(context).size.height * 0.80;

    // SafeArea(top:false) evita que el sheet tape la barra superior
    // ConstrainedBox limita la altura máxima al 80 % de pantalla
    // Column(mainAxisSize.min) + Flexible(SingleChildScrollView) = scroll
    // cuando el contenido excede ese límite → sin overflow jamás.
    return SafeArea(
      top: false,
      child: ConstrainedBox(
        constraints: BoxConstraints(maxHeight: maxH),
        child: Container(
          width: double.infinity, // ocupa todo el ancho
          decoration: const BoxDecoration(
            color: Color(0xFF0D1230),
            borderRadius: BorderRadius.vertical(top: Radius.circular(28)),
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              // ── Tirador (fijo, fuera del scroll) ───────────────────
              Container(
                width: 40,
                height: 4,
                margin: const EdgeInsets.only(top: 14, bottom: 6),
                decoration: BoxDecoration(
                  color: Colors.white24,
                  borderRadius: BorderRadius.circular(2),
                ),
              ),

              // ── Contenido desplazable ───────────────────────────────
              Flexible(
                child: SingleChildScrollView(
                  padding: EdgeInsets.fromLTRB(24, 10, 24, 24 + bottomPad),
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      // ── Avatar + nombre ────────────────────────────
                      Row(
                        children: [
                          Container(
                            width: 64,
                            height: 64,
                            decoration: BoxDecoration(
                              shape: BoxShape.circle,
                              color: accentColor.withAlpha(30),
                              border: Border.all(color: accentColor, width: 2),
                            ),
                            child: ClipOval(
                              child: OverflowBox(
                                maxWidth: 130,
                                maxHeight: 130,
                                alignment: Alignment.topCenter,
                                child: Transform.translate(
                                  offset: const Offset(0, -6),
                                  child: const BlinkCharacterWidget(
                                    width: 130,
                                    enableBounce: false,
                                  ),
                                ),
                              ),
                            ),
                          ),
                          const SizedBox(width: 16),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  name,
                                  style: const TextStyle(
                                    color: Colors.white,
                                    fontFamily: 'Nunito',
                                    fontWeight: FontWeight.w800,
                                    fontSize: 20,
                                  ),
                                ),
                                const SizedBox(height: 4),
                                Row(
                                  children: [
                                    Container(
                                      padding: const EdgeInsets.symmetric(
                                          horizontal: 10, vertical: 3),
                                      decoration: BoxDecoration(
                                        color: accentColor,
                                        borderRadius: BorderRadius.circular(10),
                                      ),
                                      child: Text(
                                        'Nivel $level',
                                        style: const TextStyle(
                                          color: Colors.black87,
                                          fontFamily: 'Nunito',
                                          fontWeight: FontWeight.w800,
                                          fontSize: 12,
                                        ),
                                      ),
                                    ),
                                    const SizedBox(width: 10),
                                    const AnimatedCoin(size: 13),
                                    const SizedBox(width: 4),
                                    Text(
                                      '$coins monedas',
                                      style: const TextStyle(
                                        color: Colors.white54,
                                        fontFamily: 'Nunito',
                                        fontSize: 13,
                                      ),
                                    ),
                                  ],
                                ),
                              ],
                            ),
                          ),
                        ],
                      ),

                      const SizedBox(height: 16),

                      // ── Barra de XP ────────────────────────────────
                      Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Row(
                            mainAxisAlignment: MainAxisAlignment.spaceBetween,
                            children: [
                              Text(
                                'Experiencia',
                                style: TextStyle(
                                  color: accentColor.withAlpha(200),
                                  fontFamily: 'Nunito',
                                  fontSize: 12,
                                  fontWeight: FontWeight.w600,
                                ),
                              ),
                              Text(
                                xpLbl,
                                style: const TextStyle(
                                  color: Colors.white54,
                                  fontFamily: 'Nunito',
                                  fontSize: 12,
                                ),
                              ),
                            ],
                          ),
                          const SizedBox(height: 6),
                          ClipRRect(
                            borderRadius: BorderRadius.circular(6),
                            child: LinearProgressIndicator(
                              value: xpPct,
                              backgroundColor: Colors.white12,
                              valueColor:
                                  AlwaysStoppedAnimation<Color>(accentColor),
                              minHeight: 8,
                            ),
                          ),
                        ],
                      ),

                      const SizedBox(height: 20),
                      const Divider(color: Colors.white10),
                      const SizedBox(height: 4),

                      // ── Opciones ───────────────────────────────────
                      _OptionTile(
                        icon: '🌐',
                        label: 'Cambiar mundo',
                        onTap: () {
                          Navigator.pop(context);
                          context.push('/worlds', extra: world);
                        },
                      ),
                      _OptionTile(
                        icon: '🎭',
                        label: 'Vestuario',
                        onTap: () {
                          Navigator.pop(context);
                          showVestidorDialog(context);
                        },
                      ),
                      // Solo los niños ven el estado del vínculo padre-hijo
                      if (isChild) const _ParentLinkSection(),
                      _OptionTile(
                        icon: '🔔',
                        label: 'Notificaciones',
                        onTap: () => Navigator.pop(context),
                      ),

                      const SizedBox(height: 4),
                      const Divider(color: Colors.white10),
                      const SizedBox(height: 4),

                      // ── Demo: Iniciar sesión ───────────────────────
                      if (isDemo)
                        _OptionTile(
                          icon: '🚀',
                          label: 'Iniciar sesión',
                          color: const Color(0xFF4FC3F7),
                          onTap: () {
                            Navigator.pop(context);
                            context.push('/child-login');
                          },
                        )
                      else
                        // ── Cerrar sesión ──────────────────────────────
                        _OptionTile(
                          icon: '🚪',
                          label: 'Cerrar sesión',
                          color: const Color(0xFFEF4444),
                          onTap: () => _confirmLogout(context, ref),
                        ),
                    ], // children del Column interior
                  ),
                ),
              ), // Flexible
            ], // children del Column exterior
          ),
        ),
      ),
    );
  }

  // ── Diálogo de confirmación de logout ──────────────────────────────────────
  void _confirmLogout(BuildContext context, WidgetRef ref) {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: const Color(0xFF1A2240),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        title: const Text(
          '¿Cerrar sesión?',
          style: TextStyle(
            color: Colors.white,
            fontFamily: 'Nunito',
            fontWeight: FontWeight.w800,
          ),
        ),
        content: const Text(
          'Tu progreso está guardado en la nube. '
          'Puedes volver cuando quieras.',
          style: TextStyle(color: Colors.white54, fontFamily: 'Nunito'),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text(
              'Cancelar',
              style: TextStyle(
                color: Colors.white38,
                fontFamily: 'Nunito',
              ),
            ),
          ),
          FilledButton(
            onPressed: () async {
              Navigator.pop(ctx); // cierra diálogo
              Navigator.pop(context); // cierra bottom sheet
              await ref.read(authRepositoryProvider).signOut();
              ref.invalidate(equippedLoadoutProvider);
              ref.invalidate(ownedCosmeticsProvider);
              if (context.mounted) context.go('/child-login');
            },
            style: FilledButton.styleFrom(
              backgroundColor: const Color(0xFFEF4444),
            ),
            child: const Text(
              'Salir',
              style: TextStyle(
                fontFamily: 'Nunito',
                fontWeight: FontWeight.w700,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// Tile de opción del menú
// ─────────────────────────────────────────────────────────────────────────────
class _OptionTile extends StatelessWidget {
  const _OptionTile({
    required this.icon,
    required this.label,
    required this.onTap,
    this.color,
  });

  final String icon;
  final String label;
  final VoidCallback onTap;
  final Color? color;

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(12),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 12),
        child: Row(
          children: [
            Text(icon, style: const TextStyle(fontSize: 22)),
            const SizedBox(width: 14),
            Text(
              label,
              style: TextStyle(
                color: color ?? Colors.white,
                fontFamily: 'Nunito',
                fontWeight: FontWeight.w600,
                fontSize: 15,
              ),
            ),
            const Spacer(),
            Icon(
              Icons.chevron_right_rounded,
              color: color?.withAlpha(150) ?? Colors.white24,
              size: 20,
            ),
          ],
        ),
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// Estado del vínculo padre-hijo (solo visible para niños).
// Carga asíncronamente si el niño ya está vinculado y muestra el nombre
// del padre; si no, muestra la opción de ingresar el código de invitación.
// ─────────────────────────────────────────────────────────────────────────────
class _ParentLinkSection extends StatefulWidget {
  const _ParentLinkSection();

  @override
  State<_ParentLinkSection> createState() => _ParentLinkSectionState();
}

class _ParentLinkSectionState extends State<_ParentLinkSection> {
  String? _parentName; // null = no vinculado (o cargando)
  bool _loaded = false;

  @override
  void initState() {
    super.initState();
    _loadParentLink();
  }

  Future<void> _loadParentLink() async {
    final userId = Supabase.instance.client.auth.currentUser?.id;
    if (userId == null) {
      if (mounted) setState(() => _loaded = true);
      return;
    }

    try {
      // 1. Buscar si existe un vínculo para este niño
      final link = await Supabase.instance.client
          .from('parent_child')
          .select('parent_id')
          .eq('child_id', userId)
          .maybeSingle();

      if (link == null) {
        if (mounted) setState(() => _loaded = true);
        return;
      }

      final parentId = link['parent_id'] as String?;
      if (parentId == null) {
        if (mounted) setState(() => _loaded = true);
        return;
      }

      // 2. Obtener el nombre del padre
      final parentProfile = await Supabase.instance.client
          .from('profiles')
          .select('display_name')
          .eq('id', parentId)
          .maybeSingle();

      if (mounted) {
        setState(() {
          _parentName = parentProfile?['display_name'] as String?;
          _loaded = true;
        });
      }
    } catch (_) {
      // Error de red o RLS → degradación segura: mostrar opción de vincular
      if (mounted) setState(() => _loaded = true);
    }
  }

  @override
  Widget build(BuildContext context) {
    // Mientras carga, reservar el espacio del tile para evitar saltos
    if (!_loaded) {
      return const SizedBox(height: 48);
    }

    if (_parentName != null) {
      // ── Ya vinculado: mostrar nombre del padre/madre ──────────────────────
      return Padding(
        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 12),
        child: Row(
          children: [
            const Text('👨‍👩‍👧', style: TextStyle(fontSize: 22)),
            const SizedBox(width: 14),
            Expanded(
              child: Text(
                'Vinculado con $_parentName',
                style: const TextStyle(
                  color: Color(0xFF4ADE80),
                  fontFamily: 'Nunito',
                  fontWeight: FontWeight.w600,
                  fontSize: 15,
                ),
              ),
            ),
            const Icon(
              Icons.check_circle_rounded,
              color: Color(0xFF4ADE80),
              size: 20,
            ),
          ],
        ),
      );
    }

    // ── No vinculado: mostrar opción para ingresar el código ──────────────
    return _OptionTile(
      icon: '🔗',
      label: 'Vincularme con papá/mamá',
      onTap: () {
        Navigator.pop(context);
        showDialog(
          context: context,
          builder: (_) => const _RedeemCodeDialog(),
        );
      },
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// Diálogo para que el hijo ingrese el código del padre
// ─────────────────────────────────────────────────────────────────────────────
class _RedeemCodeDialog extends StatefulWidget {
  const _RedeemCodeDialog();

  @override
  State<_RedeemCodeDialog> createState() => _RedeemCodeDialogState();
}

class _RedeemCodeDialogState extends State<_RedeemCodeDialog> {
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
      if (mounted)
        setState(() {
          _success = true;
          _loading = false;
        });
    } catch (e) {
      if (mounted) {
        setState(() {
          // El mensaje de error viene de la excepción del RPC
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
    final keyboardH = MediaQuery.of(context).viewInsets.bottom;

    return Dialog(
      backgroundColor: const Color(0xFF0D1230),
      insetPadding: EdgeInsets.fromLTRB(24, 40, 24, keyboardH + 24),
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(24),
        side: const BorderSide(color: Color(0xFF7C3AED), width: 1),
      ),
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 380),
        child: Padding(
          padding: const EdgeInsets.all(28),
          child: _success
              ? _SuccessView(onClose: () => Navigator.pop(context))
              : Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    // Header
                    Row(children: [
                      const Text(
                        '🔗 Vincularme',
                        style: TextStyle(
                          color: Colors.white,
                          fontFamily: 'Nunito',
                          fontWeight: FontWeight.w800,
                          fontSize: 18,
                        ),
                      ),
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
                        height: 1.5,
                      ),
                    ),
                    const SizedBox(height: 24),

                    // Campo del código
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
                        letterSpacing: 8,
                      ),
                      decoration: InputDecoration(
                        counterText: '',
                        hintText: 'XXXXXX',
                        hintStyle: const TextStyle(
                          color: Colors.white24,
                          fontFamily: 'Courier',
                          fontSize: 32,
                          letterSpacing: 8,
                        ),
                        filled: true,
                        fillColor: Colors.white.withAlpha(10),
                        border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(14),
                          borderSide: const BorderSide(color: Colors.white10),
                        ),
                        enabledBorder: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(14),
                          borderSide: const BorderSide(color: Colors.white10),
                        ),
                        focusedBorder: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(14),
                          borderSide: const BorderSide(
                              color: Color(0xFF7C3AED), width: 2),
                        ),
                        contentPadding:
                            const EdgeInsets.symmetric(vertical: 16),
                      ),
                      onSubmitted: (_) => _redeem(),
                    ),

                    // Error
                    if (_error != null) ...[
                      const SizedBox(height: 12),
                      Text(
                        _error!,
                        textAlign: TextAlign.center,
                        style: const TextStyle(
                          color: Color(0xFFFBBF24),
                          fontFamily: 'Nunito',
                          fontSize: 13,
                        ),
                      ),
                    ],

                    const SizedBox(height: 20),

                    // Botón
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
                                    color: Colors.white, strokeWidth: 2),
                              )
                            : const Text(
                                '¡Vincularme! 🎉',
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

class _SuccessView extends StatelessWidget {
  const _SuccessView({required this.onClose});
  final VoidCallback onClose;

  @override
  Widget build(BuildContext context) {
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        const Text('🎉', style: TextStyle(fontSize: 64)),
        const SizedBox(height: 12),
        const Text(
          '¡Vinculado!',
          style: TextStyle(
            color: Colors.white,
            fontFamily: 'Nunito',
            fontWeight: FontWeight.w800,
            fontSize: 22,
          ),
        ),
        const SizedBox(height: 8),
        const Text(
          'Ahora tu papá o mamá puede ver\ntu progreso y enviarte monedas.',
          textAlign: TextAlign.center,
          style: TextStyle(
            color: Colors.white54,
            fontFamily: 'Nunito',
            fontSize: 13,
            height: 1.5,
          ),
        ),
        const SizedBox(height: 24),
        FilledButton(
          onPressed: onClose,
          style: FilledButton.styleFrom(
            backgroundColor: const Color(0xFF7C3AED),
            foregroundColor: Colors.white,
            minimumSize: const Size(double.infinity, 46),
            shape:
                RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
          ),
          child: const Text(
            '¡Perfecto! 👍',
            style: TextStyle(fontFamily: 'Nunito', fontWeight: FontWeight.w800),
          ),
        ),
      ],
    );
  }
}

// ── Helpers de XP ────────────────────────────────────────────────────────────
// Emoji fijo del personaje — cambiará cuando se implementen los cosméticos.
String _characterEmoji(int xp) => '🦊';

// Progreso dentro del nivel actual (0-100 XP por nivel).
double _xpProgress(int xp) => (xp % 100) / 100.0;

String _xpLabel(int xp) => '${xp % 100} / 100 XP';
