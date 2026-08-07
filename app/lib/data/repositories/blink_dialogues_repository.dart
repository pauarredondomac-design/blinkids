import 'package:supabase_flutter/supabase_flutter.dart';

class BlinkDialogue {
  const BlinkDialogue(
      {required this.order, required this.title, required this.body});
  final int order;
  final String title;
  final String body;
}

/// Obtiene los diálogos de Blink desde Supabase.
/// Si Supabase no está disponible (demo/offline/RLS) usa los textos hardcodeados.
class BlinkDialoguesRepository {
  static Future<List<BlinkDialogue>> getSteps(String screen) async {
    try {
      final data = await Supabase.instance.client
          .from('blink_dialogues')
          .select('order, title, body')
          .eq('screen', screen)
          .eq('active', true)
          .order('order');
      final list = (data as List);
      if (list.isNotEmpty) {
        return list
            .map((e) => BlinkDialogue(
                  order: (e['order'] as num).toInt(),
                  title: (e['title'] as String?) ?? '',
                  body: (e['body'] as String?) ?? '',
                ))
            .toList();
      }
    } catch (_) {}
    return _fallback[screen] ?? [];
  }

  // ── Textos hardcodeados (fallback si Supabase no responde) ────────────────

  static const Map<String, List<BlinkDialogue>> _fallback = {
    // ── Intro / Tutorial inicial ──────────────────────────────────────────
    'intro': [
      BlinkDialogue(
          order: 1,
          title: '¡Hola!',
          body:
              '¡Hola! Soy Blink, el zorro más curioso de la galaxia. 🦊 ¡Por fin llegaste! Estaba esperando un compañero de viaje.'),
      BlinkDialogue(
          order: 2,
          title: 'Monedas con superpoderes',
          body:
              'Cada misión nos lleva un poco más lejos. Algunas fáciles, otras nos harán pensar, pero en todas aprendemos algo. ¡Cada decisión cuenta!'),
      BlinkDialogue(
          order: 3,
          title: 'Nuestras misiones',
          body:
              'Cada misión nos lleva un poco más lejos. Algunas fáciles, otras nos harán pensar, pero en todas aprendemos algo. ¡Cada decisión cuenta!'),
      BlinkDialogue(
          order: 4,
          title: 'Tu Bolsa Espacial',
          body:
              'Antes de despegar te muestro tu Bolsa: Ahorro, Inversión,  Compartir, Gastor . Aquí cada moneda encuentra su misión.'),
    ],

    // ── Mapa Mundo Espacio ────────────────────────────────────────────────
    'world_map': [
      BlinkDialogue(
          order: 1,
          title: 'Nuestra galaxia',
          body:
              '¡Esta es nuestra galaxia! Cada estación esconde algo distinto donde ganas monedas y aprendes. ¿Cuál exploramos primero?'),
      BlinkDialogue(
          order: 2,
          title: 'Las estaciones',
          body:
              'Toca cualquier estación para entrar: el Banco,  Trabajos o  Misiones. Tú eliges... yo voy contigo.'),
    ],

    // ── Bolsa / Wallet ────────────────────────────────────────────────────
    'wallet': [
      BlinkDialogue(
          order: 1,
          title: 'Mi Bolsa',
          body:
              'Mira todas tus monedas: parecen iguales, pero cada categoría tiene su propio propósito. Aquí las ves ordenadas.'),
      BlinkDialogue(
          order: 2,
          title: '¿Cómo distribuir?',
          body:
              'Cada moneda puede tener una mision diferente\nAlgunas prefieren esperar en Ahorro\nOtras quieren crecer en Inversión \nUnas ayudan a otros en Compartir\nY otras están listas para usarse en Gastos\n¿A cuál misión enviarás la siguiente?'),
    ],

    // ── Banco Estelar ─────────────────────────────────────────────────────
    'banco_estelar': [
      BlinkDialogue(
          order: 1,
          title: 'Aquí las monedas crecen 🌱',
          body:
              'Psst... ¿escuchas eso? Aquí las monedas crecen.  Deposita tu Inversión  , lo verás crecer solito,  hasta mientras duermes.'),
      BlinkDialogue(
          order: 2,
          title: 'Crecer despacito',
          body:
              'Algunas monedas son impacientes.  Otras prefieren crecer despacito. Si no las tocas un rato, cada día pasa un poquito de magia... y así cargamos combustible para Marte.'),
      BlinkDialogue(
          order: 3,
          title: 'Lo que espera, recompensa',
          body:
              'Hay tesoros que solo aparecen para quien sabe esperar.  Completa los retos de ahorro y ganamos recompensas extra.'),
    ],

    // ── Trabajos ──────────────────────────────────────────────────────────
    'trabajos_v2': [
      BlinkDialogue(
          order: 1,
          title: '¡Trabajos Espaciales!',
          body:
              '¿Listo para un buen reto? Toma un trabajo y complétalo para ganar monedas. Ojo: cada trabajo necesita materiales.'),
      BlinkDialogue(
          order: 2,
          title: '¿Cómo funciona?',
          body:
              'Aceptamos el reto, conseguimos los materiales en la Tienda... ¡y luego festejamos la recompensa como se debe!'),
    ],

    // ── Misiones ──────────────────────────────────────────────────────────
    'misiones_v2': [
      BlinkDialogue(
          order: 1,
          title: 'Cómo completar una misión',
          body:
              'Antes de despegar, revisemos el plan: unas misiones piden materiales, otras tiempo o XP. Un buen explorador siempre se prepara.'),
      BlinkDialogue(
          order: 2,
          title: 'Cómo completar una misión',
          body:
              'Antes de despegar, revisemos el plan: unas misiones piden materiales, otras tiempo o XP. Un buen explorador siempre se prepara.'),
      BlinkDialogue(
          order: 3,
          title: '¡Reclamar la recompensa!',
          body:
              '¡Lo logramos!  Hora de recoger nuestra recompensa: toca "Reclamar" para llevarte tus monedas y XP.'),
    ],

    // ── Tienda ────────────────────────────────────────────────────────────
    'tienda_v2': [
      BlinkDialogue(
          order: 1,
          title: '¡La Tienda Espacial!',
          body:
              '¡Bienvenido a mi tienda favorita! Aquí compras los materiales para tus trabajos y misiones. Elige lo que de verdad necesitas.'),
      BlinkDialogue(
          order: 2,
          title: 'Guarda los materiales',
          body:
              'Todo lo que consigues viaja contigo en tu mochila. Míralo cuando quieras en "Mi inventario".'),
    ],

    // ── Mercado Galáctico ─────────────────────────────────────────────────
    'mercado_v2': [
      BlinkDialogue(
          order: 1,
          title: '¡Mercado Galáctico! 🛒',
          body:
              'Aquí cada explorador trae algo distinto. Tienes 3 secciones: ver lo que tienes, poner cosas a la venta y explorar lo de otros. ¿Qué encontraremos?'),
      BlinkDialogue(
          order: 2,
          title: 'Tu tienda personal',
          body:
              'Si algo ya terminó su viaje contigo, quizá ayude a otro explorador. Pon hasta 10 artículos a la venta. ¿Qué precio sería justo?'),
      BlinkDialogue(
          order: 3,
          title: 'Explorar el mercado 🔍',
          body:
              'Tengo una sospecha... aquí hay buenos hallazgos. Pero antes de comprar: ¿lo necesitamos para la misión, o solo nos emocionó verlo?'),
    ],

    // ── Preguntas ─────────────────────────────────────────────────────────
    'preguntas': [
      BlinkDialogue(
          order: 1,
          title: '¡Hora de preguntas!',
          body:
              '¡Me encantan estos retos! Responde preguntas de finanzas y cada acierto te da monedas y experiencia. ¿Probamos?'),
      BlinkDialogue(
          order: 2,
          title: 'Lee con calma',
          body:
              'No respondas todavía. Primero piensa cuál elegirías tú. Ahora descubramos qué estaba pasando realmente. 👀'),
    ],

    // ── Mapa Bosque ───────────────────────────────────────────────────────
    'forest_map': [
      BlinkDialogue(
          order: 1,
          title: '¡Bienvenido al Bosque! 🌲',
          body:
              'Mi nariz de zorro detectó algo por aquí... Este lugar guarda muchos secretos. ¿Cuál descubrimos hoy?'),
      BlinkDialogue(
          order: 2,
          title: 'Explora los edificios 🏠',
          body:
              'Cada rincón esconde una sorpresa. El Mercado y las Preguntas nos esperan. Mi cola me dice que vamos por buen camino.'),
      BlinkDialogue(
          order: 3,
          title: 'Tus monedas 🪙',
          body:
              'Cada moneda que ganas aquí se suma a tu bolsa principal. ¡Todo cuenta para avanzar!'),
    ],

    // ── Burbujas ambientales de Blink en el mapa principal ─────────────────
    'ambient_idle': [
      BlinkDialogue(order: 1, title: '', body: '¡Hola, aventurero! 👋'),
      BlinkDialogue(order: 2, title: '', body: '¿Qué aventura tenemos hoy?'),
      BlinkDialogue(
          order: 3, title: '', body: '¡Cada día es una nueva misión!'),
    ],
    'ambient_outfit': [
      BlinkDialogue(order: 1, title: '', body: '¡Wow, qué bien me veo! ✨'),
      BlinkDialogue(order: 2, title: '', body: '¡Me encanta mi nuevo look!'),
    ],
    'ambient_absence': [
      BlinkDialogue(
          order: 1, title: '', body: '¡Te extrañé! Tenemos cosas por hacer.'),
      BlinkDialogue(
          order: 2, title: '', body: '¡Volviste! Vamos a ponernos al día.'),
    ],
    'ambient_jobs': [
      BlinkDialogue(
          order: 1, title: '', body: 'Tienes trabajos que podemos terminar 🔨'),
      BlinkDialogue(order: 2, title: '', body: '¡Hay trabajos esperándote!'),
    ],
  };
}
