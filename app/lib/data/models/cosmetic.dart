// ─────────────────────────────────────────────────────────────────────────────
// Cosmetic model
// ─────────────────────────────────────────────────────────────────────────────

enum CosmeticSlot {
  // ── Slots de imagen PNG (usados en BlinkCharacterWidget) ──────────────────
  /// Accesorio de tronco superior (camisa, sudadera, traje). OBLIGATORIO.
  top,
  /// Accesorio de tronco inferior (pantalón, falda). OBLIGATORIO.
  bottom,
  /// Sombrero / accesorio de cabeza. Opcional.
  helmet,
  // ── Slots de emoji (cosméticos legacy) ────────────────────────────────────
  suit,
  backpack,
  boots,
  flag,
}

extension CosmeticSlotX on CosmeticSlot {
  String get id => name;

  /// Si el slot requiere un PNG de capa (no puede estar vacío).
  bool get isRequired => this == CosmeticSlot.top || this == CosmeticSlot.bottom;

  String get displayName => switch (this) {
    CosmeticSlot.top      => 'Ropa superior',
    CosmeticSlot.bottom   => 'Ropa inferior',
    CosmeticSlot.helmet   => 'Sombrero',
    CosmeticSlot.suit     => 'Traje',
    CosmeticSlot.backpack => 'Mochila',
    CosmeticSlot.boots    => 'Botas',
    CosmeticSlot.flag     => 'Bandera',
  };

  String get defaultEmoji => switch (this) {
    CosmeticSlot.top      => '👕',
    CosmeticSlot.bottom   => '👖',
    CosmeticSlot.helmet   => '🪖',
    CosmeticSlot.suit     => '👔',
    CosmeticSlot.backpack => '🎒',
    CosmeticSlot.boots    => '👟',
    CosmeticSlot.flag     => '🚩',
  };
}

CosmeticSlot cosmeticSlotFromString(String s) =>
    CosmeticSlot.values.firstWhere((e) => e.name == s,
        orElse: () => CosmeticSlot.helmet);

// ─────────────────────────────────────────────────────────────────────────────

class CosmeticDefinition {
  final String       id;
  final CosmeticSlot slot;
  final String       name;
  final String       description;
  final String       emoji;
  final int          price;
  final String       unlockType; // 'buy' | 'earn'
  /// Ruta al PNG de capa (solo para slots top/bottom/helmet).
  /// null = cosmético de emoji solamente.
  final String?      assetPath;

  const CosmeticDefinition({
    required this.id,
    required this.slot,
    required this.name,
    required this.description,
    required this.emoji,
    required this.price,
    required this.unlockType,
    this.assetPath,
  });

  bool get isFree => price == 0;
  bool get hasAsset => assetPath != null;

  factory CosmeticDefinition.fromJson(Map<String, dynamic> j) =>
      CosmeticDefinition(
        id:          j['id']          as String,
        slot:        cosmeticSlotFromString(j['slot'] as String),
        name:        j['name']        as String,
        description: j['description'] as String? ?? '',
        emoji:       j['emoji']       as String? ?? '🎭',
        price:       j['price']       as int?    ?? 0,
        unlockType:  j['unlock_type'] as String? ?? 'buy',
        assetPath:   j['asset_path']  as String?,
      );
}

// ─────────────────────────────────────────────────────────────────────────────

class EquippedLoadout {
  /// Maps slot name → CosmeticDefinition (null = nothing equipped)
  final Map<String, CosmeticDefinition?> slots;

  const EquippedLoadout(this.slots);

  CosmeticDefinition? operator [](CosmeticSlot slot) => slots[slot.id];

  /// Emoji for a slot (equipped cosmetic emoji or slot default).
  String emojiFor(CosmeticSlot slot) =>
      slots[slot.id]?.emoji ?? slot.defaultEmoji;

  static const EquippedLoadout empty = EquippedLoadout({});
}
