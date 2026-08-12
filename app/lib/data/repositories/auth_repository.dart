import 'package:supabase_flutter/supabase_flutter.dart';
import '../services/supabase_service.dart';
import '../../core/constants/app_strings.dart';

class AuthRepository {
  Stream<AuthState> get authStateChanges => supabase.auth.onAuthStateChange;

  User? get currentUser => supabase.auth.currentUser;

  bool get isAuthenticated => currentUser != null;

  /// Inicia sesión con Google OAuth en móvil (usa deep link blinkids://callback).
  Future<void> signInWithGoogle() async {
    await supabase.auth.signInWithOAuth(
      OAuthProvider.google,
      redirectTo: AppStrings.oauthRedirectUrl,
    );
  }

  /// Inicia sesión con Google OAuth en web (sin redirectTo — Supabase usa el origen actual).
  Future<void> signInWithGoogleWeb() async {
    await supabase.auth.signInWithOAuth(
      OAuthProvider.google,
    );
  }

  /// Inicia sesión con correo y contraseña.
  Future<AuthResponse> signInWithEmail({
    required String email,
    required String password,
  }) async {
    return supabase.auth.signInWithPassword(
      email: email,
      password: password,
    );
  }

  /// Registra un nuevo usuario con correo y contraseña.
  Future<AuthResponse> signUpWithEmail({
    required String email,
    required String password,
  }) async {
    return supabase.auth.signUp(
      email: email,
      password: password,
    );
  }

  /// Envía correo para restablecer contraseña.
  Future<void> resetPassword(String email) async {
    await supabase.auth.resetPasswordForEmail(email);
  }

  /// Cierra la sesión activa.
  Future<void> signOut() async {
    await supabase.auth.signOut();
  }
}
