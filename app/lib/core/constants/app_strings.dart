abstract class AppStrings {
  // ── Credenciales de Supabase ───────────────────────────────────────────────
  // La anon key de Supabase está diseñada para ir embebida en apps cliente
  // (no es secreta — la protección real la da Row Level Security, no ocultar
  // esta llave). Por eso va como valor por defecto aquí: así "flutter run" o
  // compilar directo en Xcode funciona sin configuración extra tras clonar.
  //
  // Si alguna vez necesitas apuntar a OTRO proyecto de Supabase (staging,
  // por ejemplo), puedes seguir sobreescribiendo estos valores con:
  //   flutter run --dart-define-from-file=dart_defines/local.json
  // (ese archivo sigue en .gitignore; solo hace falta si quieres el override).
  static const supabaseUrl = String.fromEnvironment(
    'SUPABASE_URL',
    defaultValue: 'https://mzwvazjofbdelsejxoqi.supabase.co',
  );
  static const supabaseAnonKey = String.fromEnvironment(
    'SUPABASE_ANON_KEY',
    defaultValue:
        'eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9.eyJpc3MiOiJzdXBhYmFzZSIsInJlZiI6Im16d3ZhempvZmJkZWxzZWp4b3FpIiwicm9sZSI6ImFub24iLCJpYXQiOjE3Nzg1OTk1NzcsImV4cCI6MjA5NDE3NTU3N30.xYCpnIC9CdfemaoWrGAdsJDfBfubXWmL23OV6ZQjjas',
  );

  // Deep link para OAuth (configura en AndroidManifest.xml e Info.plist)
  static const oauthRedirectUrl = 'blinkids://callback';

  // App
  static const appName = 'Blinkids';
  static const appTagline = '¡Aprende a manejar tu dinero!';

  // Generales
  static const loading = 'Cargando...';
  static const error = 'Algo salió mal, intenta de nuevo';
  static const retry = 'Reintentar';
  static const cancel = 'Cancelar';
  static const continueText = 'Continuar';
  static const save = 'Guardar';
  static const next = 'Siguiente';
  static const back = 'Atrás';
  static const close = 'Cerrar';
  static const accept = 'Aceptar';

  // Auth
  static const signInWithGoogle = 'Continuar con Google';
  static const signInWithEmail = 'Continuar con correo';
  static const emailLabel = 'Correo electrónico';
  static const passwordLabel = 'Contraseña';
  static const forgotPassword = '¿Olvidaste tu contraseña?';
  static const noAccount = '¿No tienes cuenta? Regístrate';
  static const hasAccount = '¿Ya tienes cuenta? Inicia sesión';
  static const signOut = 'Cerrar sesión';
  static const welcome = '¡Bienvenido!';
  static const welcomeBack = '¡Bienvenido de vuelta!';
  static const loginSubtitle = 'Inicia sesión para continuar tu aventura';

  // Registro
  static const selectRole = '¿Cómo quieres jugar?';
  static const iAmParent = 'Soy papá / mamá';
  static const iAmChild = '¡Soy aventurero!';
  static const parentDescription =
      'Gestiona la cartera y supervisa el progreso de tus hijos';
  static const childDescription =
      'Explora mundos y aprende a manejar tus monedas';
  static const enterYourName = '¿Cómo te llamas?';
  static const namePlaceholder = 'Tu nombre de aventurero';
  static const profileCreated = '¡Perfil creado!';
  static const profileCreatedSub = 'Tu aventura está a punto de comenzar';
  static const creatingProfile = 'Creando tu perfil...';

  // Validaciones
  static const nameRequired = 'El nombre es obligatorio';
  static const nameTooShort = 'El nombre debe tener al menos 2 caracteres';
  static const emailRequired = 'El correo es obligatorio';
  static const emailInvalid = 'Ingresa un correo válido';
  static const passwordRequired = 'La contraseña es obligatoria';
  static const passwordTooShort =
      'La contraseña debe tener al menos 6 caracteres';

  // Monedas
  static const coins = 'monedas';
  static const yourBalance = 'Tu balance';
  static const totalCoins = 'Total de monedas';

  // Categorías de bolsa
  static const categoryAhorro = 'Ahorro';
  static const categoryInversion = 'Inversión';
  static const categoryEmergencia = 'Emergencia';
  static const categoryGastos = 'Gastos';
  static const categoryMetas = 'Metas';

  // Mundos
  static const worldForest = 'Bosque Mágico';
  static const worldSpace = 'Galaxia Blinkids';
  static const worldCity = 'Ciudad del Futuro';
  static const worldsTitle = 'Mis mundos';
  static const unlockWorld = 'Desbloquear mundo';

  // Tutorial
  static const startAdventure = '¡Empezar aventura!';
  static const tutorialTitle = 'Aprende con Blink';
  static const tutorialSkipDisabled = 'El tutorial no se puede saltar';
  static const meetJuan = '¡Hola! Soy Blink, tu guía en Blinkids.';

  // Papá
  static const parentHome = 'Mi panel';
  static const myChildren = 'Mis hijos';
  static const myWallet = 'Mi cartera';
  static const sendCoins = 'Enviar monedas';
  static const recharge = 'Recargar';
  static const realBalance = 'Saldo real';

  // Personaje
  static const xpLabel = 'XP';
  static const levelLabel = 'Nivel';
}
