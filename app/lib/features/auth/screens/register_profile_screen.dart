import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../../../core/constants/app_colors.dart';
import '../../../core/constants/app_sizes.dart';
import '../../../core/constants/app_strings.dart';
import '../../../core/utils/extensions.dart';
import '../../../data/models/profile.dart';
import '../../../shared/providers/auth_provider.dart';
import '../../../shared/providers/profile_provider.dart';
import '../../../shared/providers/wallet_provider.dart';
import '../../../shared/providers/character_provider.dart';
import '../../../shared/widgets/fin_button.dart';
import '../../../shared/widgets/loading_overlay.dart';

/// Pantalla 2 del registro: ingresar nombre y crear el perfil completo.
/// Crea en secuencia: perfil → cartera → personaje → registro de tutorial.
class RegisterProfileScreen extends ConsumerStatefulWidget {
  const RegisterProfileScreen({super.key, required this.role});

  final String role;

  @override
  ConsumerState<RegisterProfileScreen> createState() =>
      _RegisterProfileScreenState();
}

class _RegisterProfileScreenState extends ConsumerState<RegisterProfileScreen> {
  final _nameController = TextEditingController();
  final _formKey = GlobalKey<FormState>();
  bool _isLoading = false;
  String _status = '';
  String? _nameError;

  @override
  void dispose() {
    _nameController.dispose();
    super.dispose();
  }

  UserRole get _userRole =>
      widget.role == 'parent' ? UserRole.parent : UserRole.child;

  bool get _isParent => _userRole == UserRole.parent;

  Future<void> _createProfile() async {
    // Limpiar error previo de nombre
    if (_nameError != null) setState(() => _nameError = null);

    if (!(_formKey.currentState?.validate() ?? false)) return;

    setState(() {
      _isLoading = true;
      _status = AppStrings.creatingProfile;
    });

    try {
      final user = ref.read(currentUserProvider);
      if (user == null) throw Exception('No hay sesión activa');

      final profileRepo = ref.read(profileRepositoryProvider);
      final walletRepo = ref.read(walletRepositoryProvider);
      final charRepo = ref.read(characterRepositoryProvider);

      // Verificar que el apodo no esté en uso (solo para niños; padres pueden repetir nombre)
      if (!_isParent) {
        final taken =
            await profileRepo.isDisplayNameTaken(_nameController.text.trim());
        if (taken) {
          if (mounted) {
            setState(() {
              _isLoading = false;
              _nameError = 'Este apodo ya está en uso. Prueba con otro.';
            });
          }
          return;
        }
      }

      // 1. Crear perfil
      await profileRepo.createProfile(
        userId: user.id,
        role: _userRole,
        displayName: _nameController.text.trim(),
      );

      // 2. Crear cartera
      await walletRepo.createWallet(user.id);

      // 3. Crear personaje (Juan) — solo para niños
      if (!_isParent) {
        await charRepo.createCharacter(user.id);
      }

      if (!mounted) return;

      // Navegar al destino correcto
      context.go(_isParent ? '/parent' : '/world');
    } catch (e) {
      if (mounted) {
        setState(() => _isLoading = false);
        context.showError('Error al crear el perfil: ${e.toString()}');
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final isParent = _isParent;

    return LoadingOverlay(
      isLoading: _isLoading,
      message: _status,
      child: Scaffold(
        body: Container(
          decoration: BoxDecoration(
            gradient: LinearGradient(
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
              colors: isParent
                  ? [AppColors.spaceBlue, AppColors.spacePurple]
                  : [AppColors.forestGreen, AppColors.primary],
            ),
          ),
          child: SafeArea(
            child: Row(
              children: [
                // Panel izquierdo: información del rol
                Expanded(
                  flex: 4,
                  child: Padding(
                    padding: const EdgeInsets.all(AppSizes.xl),
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          isParent ? '👨‍👩‍👧' : '🦊',
                          style: const TextStyle(fontSize: 72),
                        )
                            .animate()
                            .scale(duration: 600.ms, curve: Curves.elasticOut),
                        const SizedBox(height: AppSizes.lg),
                        Text(
                          isParent
                              ? 'Panel de familia'
                              : '¡Bienvenido, aventurero!',
                          style: const TextStyle(
                            fontSize: 26,
                            fontWeight: FontWeight.w800,
                            color: Colors.white,
                            fontFamily: 'Nunito',
                          ),
                        ).animate().fadeIn(delay: 200.ms),
                        const SizedBox(height: AppSizes.sm),
                        Text(
                          isParent
                              ? 'Gestiona la educación financiera de tus hijos de forma divertida'
                              : 'Explora mundos, aprende a ahorrar e invierte tus monedas',
                          style: const TextStyle(
                            fontSize: 15,
                            color: Colors.white70,
                            fontFamily: 'Nunito',
                          ),
                        ).animate().fadeIn(delay: 350.ms),
                      ],
                    ),
                  ),
                ),
                // Panel derecho: formulario
                Expanded(
                  flex: 6,
                  child: Center(
                    child: ConstrainedBox(
                      constraints: const BoxConstraints(maxWidth: 400),
                      child: Card(
                        margin: const EdgeInsets.all(AppSizes.lg),
                        child: Padding(
                          padding: const EdgeInsets.all(AppSizes.xl),
                          child: Form(
                            key: _formKey,
                            child: Column(
                              mainAxisSize: MainAxisSize.min,
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  AppStrings.enterYourName,
                                  style: Theme.of(context)
                                      .textTheme
                                      .headlineMedium,
                                ),
                                const SizedBox(height: AppSizes.sm),
                                Text(
                                  isParent
                                      ? 'Este nombre verán tus hijos en la app'
                                      : 'Este será tu nombre de aventurero',
                                  style: Theme.of(context).textTheme.bodyMedium,
                                ),
                                const SizedBox(height: AppSizes.xl),
                                TextFormField(
                                  controller: _nameController,
                                  autofocus: true,
                                  textCapitalization: TextCapitalization.words,
                                  decoration: InputDecoration(
                                    hintText: AppStrings.namePlaceholder,
                                    prefixIcon: Icon(
                                      isParent
                                          ? Icons.person
                                          : Icons.star_outlined,
                                      color: AppColors.primary,
                                    ),
                                  ),
                                  validator: (v) {
                                    if (v == null || v.trim().isEmpty) {
                                      return AppStrings.nameRequired;
                                    }
                                    if (v.trim().length < 2) {
                                      return AppStrings.nameTooShort;
                                    }
                                    return null;
                                  },
                                  onFieldSubmitted: (_) => _createProfile(),
                                ),
                                if (_nameError != null) ...[
                                  const SizedBox(height: 8),
                                  Row(
                                    children: [
                                      const Icon(Icons.error_outline,
                                          color: Color(0xFFEF4444), size: 14),
                                      const SizedBox(width: 6),
                                      Expanded(
                                        child: Text(
                                          _nameError!,
                                          style: const TextStyle(
                                            color: Color(0xFFEF4444),
                                            fontFamily: 'Nunito',
                                            fontSize: 12,
                                          ),
                                        ),
                                      ),
                                    ],
                                  ),
                                ],
                                const SizedBox(height: AppSizes.xl),
                                FinButton(
                                  label: AppStrings.continueText,
                                  icon: Icons.arrow_forward_rounded,
                                  onPressed: _createProfile,
                                ),
                              ],
                            ),
                          ),
                        ),
                      )
                          .animate()
                          .fadeIn(delay: 200.ms)
                          .slideX(begin: 0.3, end: 0),
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
