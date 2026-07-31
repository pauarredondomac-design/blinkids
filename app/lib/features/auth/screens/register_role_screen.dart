import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:go_router/go_router.dart';
import '../../../core/constants/app_colors.dart';
import '../../../core/constants/app_sizes.dart';
import '../../../core/constants/app_strings.dart';

/// Pantalla 1 del registro: el usuario elige si es papá/mamá o niño.
class RegisterRoleScreen extends StatefulWidget {
  const RegisterRoleScreen({super.key});

  @override
  State<RegisterRoleScreen> createState() => _RegisterRoleScreenState();
}

class _RegisterRoleScreenState extends State<RegisterRoleScreen> {
  String? _selectedRole;

  void _select(String role) {
    setState(() => _selectedRole = role);
    Future.delayed(const Duration(milliseconds: 300), () {
      if (mounted) context.go('/register/profile', extra: role);
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Container(
        decoration: const BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
            colors: [AppColors.primaryDark, AppColors.primary],
          ),
        ),
        child: SafeArea(
          child: Center(
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                const Text(
                  AppStrings.selectRole,
                  style: TextStyle(
                    fontSize: 28,
                    fontWeight: FontWeight.w800,
                    color: Colors.white,
                    fontFamily: 'Nunito',
                  ),
                  textAlign: TextAlign.center,
                )
                    .animate()
                    .fadeIn(duration: 500.ms)
                    .slideY(begin: -0.3, end: 0),
                const SizedBox(height: AppSizes.xxl),
                Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    _RoleCard(
                      emoji: '👨‍👩‍👧',
                      title: AppStrings.iAmParent,
                      description: AppStrings.parentDescription,
                      color: AppColors.spaceBlue,
                      isSelected: _selectedRole == 'parent',
                      onTap: () => _select('parent'),
                    )
                        .animate()
                        .fadeIn(delay: 200.ms, duration: 400.ms)
                        .slideX(begin: -0.4, end: 0),
                    const SizedBox(width: AppSizes.xl),
                    _RoleCard(
                      emoji: '🦊',
                      title: AppStrings.iAmChild,
                      description: AppStrings.childDescription,
                      color: AppColors.secondary,
                      isSelected: _selectedRole == 'child',
                      onTap: () => _select('child'),
                    )
                        .animate()
                        .fadeIn(delay: 350.ms, duration: 400.ms)
                        .slideX(begin: 0.4, end: 0),
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

class _RoleCard extends StatelessWidget {
  const _RoleCard({
    required this.emoji,
    required this.title,
    required this.description,
    required this.color,
    required this.isSelected,
    required this.onTap,
  });

  final String emoji;
  final String title;
  final String description;
  final Color color;
  final bool isSelected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 200),
        width: 220,
        padding: const EdgeInsets.all(AppSizes.xl),
        decoration: BoxDecoration(
          color: isSelected ? color : Colors.white,
          borderRadius: BorderRadius.circular(AppSizes.radiusXl),
          border: Border.all(
            color: isSelected ? Colors.white : Colors.transparent,
            width: 3,
          ),
          boxShadow: [
            BoxShadow(
              color: color.withOpacity(0.4),
              blurRadius: isSelected ? 24 : 12,
              spreadRadius: isSelected ? 4 : 0,
            ),
          ],
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(emoji, style: const TextStyle(fontSize: 56)),
            const SizedBox(height: AppSizes.md),
            Text(
              title,
              style: TextStyle(
                fontSize: AppSizes.fontXl,
                fontWeight: FontWeight.w800,
                color: isSelected ? Colors.white : AppColors.textPrimary,
                fontFamily: 'Nunito',
              ),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: AppSizes.sm),
            Text(
              description,
              style: TextStyle(
                fontSize: AppSizes.fontSm,
                color: isSelected ? Colors.white70 : AppColors.textSecondary,
                fontFamily: 'Nunito',
              ),
              textAlign: TextAlign.center,
            ),
          ],
        ),
      ),
    );
  }
}
