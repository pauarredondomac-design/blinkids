import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'core/constants/app_strings.dart';
import 'core/router/app_router.dart';
import 'core/theme/app_theme.dart';
import 'data/services/analytics_service.dart';
import 'data/services/crash_reporting_service.dart';
import 'data/services/push_notification_service.dart';
import 'shared/providers/music_provider.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();

  // Captura de errores no manejados — debe ser lo primero
  CrashReportingService.init();

  // Orientación e UI inmersiva en paralelo (ambas son sincrónicas en Android)
  await Future.wait([
    SystemChrome.setPreferredOrientations([
      DeviceOrientation.landscapeLeft,
      DeviceOrientation.landscapeRight,
    ]),
    SystemChrome.setEnabledSystemUIMode(SystemUiMode.immersiveSticky),
    Supabase.initialize(
      url: AppStrings.supabaseUrl,
      anonKey: AppStrings.supabaseAnonKey,
    ),
  ]);

  // Aumenta caché de imágenes para que el mapa no parpadee al volver de pantallas
  PaintingBinding.instance.imageCache.maximumSize = 200;
  PaintingBinding.instance.imageCache.maximumSizeBytes = 80 << 20; // 80 MB

  runApp(const ProviderScope(child: FinQuestApp()));

  // Servicios secundarios en background — no bloquean el arranque
  AnalyticsService.instance.appOpen(voluntaryOpen: true);
  PushNotificationService.instance.init();
}

class FinQuestApp extends ConsumerWidget {
  const FinQuestApp({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    ref.watch(musicProvider); // inicia música en loop al arrancar la app
    final router = ref.watch(appRouterProvider);
    return MaterialApp.router(
      title: AppStrings.appName,
      theme: AppTheme.light(),
      routerConfig: router,
      debugShowCheckedModeBanner: false,
      locale: const Locale('es', 'MX'),
      supportedLocales: const [Locale('es', 'MX'), Locale('es'), Locale('en')],
      localizationsDelegates: const [
        GlobalMaterialLocalizations.delegate,
        GlobalWidgetsLocalizations.delegate,
        GlobalCupertinoLocalizations.delegate,
      ],
    );
  }
}
