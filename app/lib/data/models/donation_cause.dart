// ─────────────────────────────────────────────────────────────────────────────
// Causas de donación — Mi Bolsa > Donar (v1: meta PERSONAL de cada niño,
// no compartida entre jugadores; ver [[project_donation_causes]] para el
// contexto de la decisión con Paulina).
// ─────────────────────────────────────────────────────────────────────────────
class DonationCause {
  const DonationCause({
    required this.id,
    required this.label,
    required this.emoji,
    required this.goal,
    required this.impactMessage,
  });

  final String id;
  final String label;
  final String emoji;

  /// Monedas necesarias para "completar" esta causa una vez.
  final int goal;

  /// Mensaje corto que se muestra al llegar a la meta.
  final String impactMessage;
}

const donationCauses = <DonationCause>[
  DonationCause(
    id: 'animales',
    label: 'Animales',
    emoji: '🐾',
    goal: 300,
    impactMessage: '¡Ayudaste a que un refugio le diera hogar a más mascotas! 🐶🐱',
  ),
  DonationCause(
    id: 'educacion',
    label: 'Educación',
    emoji: '📚',
    goal: 300,
    impactMessage: '¡Ayudaste a que más niños tuvieran libros y útiles! 📖✏️',
  ),
  DonationCause(
    id: 'medio_ambiente',
    label: 'Medio Ambiente',
    emoji: '🌱',
    goal: 300,
    impactMessage: '¡Ayudaste a plantar árboles y cuidar la naturaleza! 🌳🌍',
  ),
];

/// Progreso del jugador actual hacia la meta de una causa.
class DonationCauseProgress {
  const DonationCauseProgress({
    required this.causeId,
    required this.amount,
    required this.completions,
  });

  final String causeId;
  final int amount;

  /// Cuántas veces ya llegó a la meta de esta causa (historial/reconocimiento).
  final int completions;

  factory DonationCauseProgress.fromJson(Map<String, dynamic> j) =>
      DonationCauseProgress(
        causeId: j['cause_id'] as String,
        amount: j['amount'] as int? ?? 0,
        completions: j['completions'] as int? ?? 0,
      );

  static const empty = DonationCauseProgress(
    causeId: '',
    amount: 0,
    completions: 0,
  );
}
