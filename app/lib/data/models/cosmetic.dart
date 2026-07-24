// ─────────────────────────────────────────────────────────────────────────────
// Cosmetic model
// ─────────────────────────────────────────────────────────────────────────────

enum CosmeticSlot {
  // ── Slots de imagen PNG (usados en BlinkCharacterWidget) ──────────────────
  /// Accesorio de tronco superior (camisa, sudadera, traje). OBLIGATORIO.
  top,
  /// Accesorio de tronco inferior (pantalón, falda). OBLIGATORIO.
  bottom,
  /// Botas / calzado.
  boots,
  /// Accesorios varios (casco, guantes, mochilas, banderas, etc.)
  accesorios,
  // ── Slots legacy (mantenidos por compatibilidad) ──────────────────────────
  helmet,
  suit,
  backpack,
  flag,
}

extension CosmeticSlotX on CosmeticSlot {
  String get id => name;

  /// Si el slot requiere un PNG de capa (no puede estar vacío).
  bool get isRequired => this == CosmeticSlot.top || this == CosmeticSlot.bottom;

  String get displayName => switch (this) {
    CosmeticSlot.top        => 'Ropa superior',
    CosmeticSlot.bottom     => 'Ropa inferior',
    CosmeticSlot.boots      => 'Botas',
    CosmeticSlot.accesorios => 'Accesorios',
    CosmeticSlot.helmet     => 'Sombrero',
    CosmeticSlot.suit       => 'Traje',
    CosmeticSlot.backpack   => 'Mochila',
    CosmeticSlot.flag       => 'Bandera',
  };

  String get defaultEmoji => switch (this) {
    CosmeticSlot.top        => '👕',
    CosmeticSlot.bottom     => '👖',
    CosmeticSlot.boots      => '👟',
    CosmeticSlot.accesorios => '🎭',
    CosmeticSlot.helmet     => '🪖',
    CosmeticSlot.suit       => '👔',
    CosmeticSlot.backpack   => '🎒',
    CosmeticSlot.flag       => '🚩',
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
  /// Imagen que se muestra en la tienda (carpeta cosmeticos/).
  final String?      assetPath;
  /// Capa PNG que se superpone sobre Blink cuando está equipado (carpeta vestidor/).
  /// null = solo cambia emoji, no afecta imagen de Blink.
  final String?      equippedAssetPath;

  const CosmeticDefinition({
    required this.id,
    required this.slot,
    required this.name,
    required this.description,
    required this.emoji,
    required this.price,
    required this.unlockType,
    this.assetPath,
    this.equippedAssetPath,
  });

  bool get isFree => price == 0;
  bool get hasAsset => assetPath != null;
  bool get hasEquippedAsset => equippedAssetPath != null;

  factory CosmeticDefinition.fromJson(Map<String, dynamic> j) =>
      CosmeticDefinition(
        id:               j['id']                as String,
        slot:             cosmeticSlotFromString(j['slot'] as String),
        name:             j['name']              as String,
        description:      j['description']       as String? ?? '',
        emoji:            j['emoji']             as String? ?? '🎭',
        price:            j['price']             as int?    ?? 0,
        unlockType:       j['unlock_type']       as String? ?? 'buy',
        assetPath:        j['asset_path']        as String?,
        equippedAssetPath: j['equipped_asset_path'] as String?,
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
