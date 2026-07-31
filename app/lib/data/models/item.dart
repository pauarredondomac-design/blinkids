// ─────────────────────────────────────────────────────────────────────────────
// Item — objeto físico del juego (se guarda en inventario, se usa en crafting)
// ─────────────────────────────────────────────────────────────────────────────
enum ItemSource { shop, mission, both }

class Item {
  const Item({
    required this.id,
    required this.emoji,
    required this.name,
    required this.description,
    required this.world,
    required this.shopPrice,
    required this.source,
    this.isRare = false,
    this.imagePath,
  });

  final String     id;
  final String     emoji;
  final String     name;
  final String     description;
  /// 'forest' | 'space' | 'any'
  final String     world;
  /// Precio en la tienda. 0 = no se vende en tienda (solo misiones).
  final int        shopPrice;
  final ItemSource source;
  final bool       isRare;
  /// Nombre de archivo en assets/items/ (ej: 'llave_inglesa.png'). null = usar emoji.
  final String?    imagePath;

  bool get availableInShop => shopPrice > 0;

  factory Item.fromJson(Map<String, dynamic> j) {
    final price = j['shop_price'] as int? ?? 0;
    return Item(
      id:          j['item_id']     as String,
      emoji:       j['emoji']       as String,
      name:        j['name']        as String,
      description: j['description'] as String? ?? '',
      world:       j['world']       as String? ?? 'any',
      shopPrice:   price,
      source:      price > 0 ? ItemSource.shop : ItemSource.mission,
      isRare:      j['is_rare']     as bool? ?? false,
      imagePath:   j['image_name']  as String?,
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// Catálogo global de ítems
// ─────────────────────────────────────────────────────────────────────────────
const allItems = <Item>[
  // ── BOSQUE ──────────────────────────────────────────────────────────────
  Item(
    id: 'wood_plank',
    emoji: '🪵',
    name: 'Tablón de Madera',
    description: 'Madera resistente del bosque. Sirve para reparar cabañas.',
    world: 'forest',
    shopPrice: 50,
    source: ItemSource.shop,
  ),
  Item(
    id: 'hammer',
    emoji: '🔨',
    name: 'Martillo',
    description: 'Herramienta básica para todo tipo de construcción.',
    world: 'forest',
    shopPrice: 80,
    source: ItemSource.shop,
    imagePath: 'martillo.png',
  ),
  Item(
    id: 'magic_herb',
    emoji: '🌿',
    name: 'Hierba Mágica',
    description: 'Planta curativa que crece en lo profundo del bosque.',
    world: 'forest',
    shopPrice: 100,
    source: ItemSource.shop,
  ),
  Item(
    id: 'health_potion',
    emoji: '🧪',
    name: 'Poción de Salud',
    description: 'Bebida mágica que sana a los animales enfermos del bosque.',
    world: 'forest',
    shopPrice: 150,
    source: ItemSource.shop,
  ),
  Item(
    id: 'acorn',
    emoji: '🌰',
    name: 'Bellota',
    description: 'La ardilla del bosque las colecciona para el invierno.',
    world: 'forest',
    shopPrice: 30,
    source: ItemSource.shop,
  ),

  // ── ESPACIO ──────────────────────────────────────────────────────────────
  Item(
    id: 'space_bolt',
    emoji: '🔩',
    name: 'Perno Espacial',
    description: 'Pieza metálica reforzada para reparar naves espaciales.',
    world: 'space',
    shopPrice: 60,
    source: ItemSource.shop,
  ),
  Item(
    id: 'wrench',
    emoji: '🔧',
    name: 'Llave Inglesa',
    description: 'Herramienta indispensable en cualquier taller galáctico.',
    world: 'space',
    shopPrice: 90,
    source: ItemSource.shop,
    imagePath: 'llave_inglesa.png',
  ),
  Item(
    id: 'battery',
    emoji: '⚡',
    name: 'Batería Cuántica',
    description: 'Fuente de energía para dispositivos espaciales.',
    world: 'space',
    shopPrice: 110,
    source: ItemSource.shop,
    imagePath: 'bateria.png',
  ),
  Item(
    id: 'fuel_capsule',
    emoji: '💊',
    name: 'Cápsula de Combustible',
    description: 'Combustible concentrado para naves espaciales y robots.',
    world: 'space',
    shopPrice: 0,
    source: ItemSource.mission,
  ),
  Item(
    id: 'lunar_circuit',
    emoji: '🖥️',
    name: 'Circuito Lunar',
    description: 'Componente electrónico fabricado en la Luna.',
    world: 'space',
    shopPrice: 120,
    source: ItemSource.shop,
  ),
  Item(
    id: 'gear',
    emoji: '⚙️',
    name: 'Engrane',
    description: 'Pieza mecánica esencial para reparar maquinaria espacial.',
    world: 'space',
    shopPrice: 100,
    source: ItemSource.shop,
    imagePath: 'engrane.png',
  ),
  Item(
    id: 'saw',
    emoji: '🪚',
    name: 'Sierra',
    description: 'Herramienta de corte para trabajos de precisión en la nave.',
    world: 'space',
    shopPrice: 100,
    source: ItemSource.shop,
    imagePath: 'sierra.png',
  ),
  Item(
    id: 'magnet',
    emoji: '🧲',
    name: 'Imán Magnético',
    description: 'Atrae piezas metálicas flotando en la estación espacial.',
    world: 'space',
    shopPrice: 90,
    source: ItemSource.shop,
    imagePath: 'iman.png',
  ),
  Item(
    id: 'master_key',
    emoji: '🔑',
    name: 'Llave Maestra',
    description: 'Abre cualquier compartimento sellado de la nave.',
    world: 'space',
    shopPrice: 130,
    source: ItemSource.shop,
    imagePath: 'llave_maestra.png',
  ),
  Item(
    id: 'screws',
    emoji: '🔩',
    name: 'Tornillos Espaciales',
    description: 'Juego de tornillos resistentes para ajustar cualquier pieza.',
    world: 'space',
    shopPrice: 70,
    source: ItemSource.shop,
    imagePath: 'tornillos.png',
  ),
  Item(
    id: 'supply_box',
    emoji: '📦',
    name: 'Caja de Suministros',
    description: 'Caja llena de materiales variados para la estación espacial.',
    world: 'space',
    shopPrice: 150,
    source: ItemSource.shop,
    imagePath: 'caja_de_suministros.png',
  ),
];

// ─────────────────────────────────────────────────────────────────────────────
// Helpers
// ─────────────────────────────────────────────────────────────────────────────
Item? itemById(String id) {
  try {
    return allItems.firstWhere((i) => i.id == id);
  } catch (_) {
    return null;
  }
}

List<Item> itemsForWorld(String worldId) =>
    allItems.where((i) => i.world == worldId || i.world == 'any').toList();

List<Item> shopItemsForWorld(String worldId) =>
    itemsForWorld(worldId).where((i) => i.availableInShop).toList();

// ─────────────────────────────────────────────────────────────────────────────
// InventoryStack — un ítem con cantidad en el inventario del jugador
// ─────────────────────────────────────────────────────────────────────────────
class InventoryStack {
  const InventoryStack({required this.item, required this.qty});
  final Item item;
  final int  qty;
}

// ─────────────────────────────────────────────────────────────────────────────
// ItemRequirement — cuántos de un ítem necesita un trabajo de crafting
// ─────────────────────────────────────────────────────────────────────────────
class ItemRequirement {
  const ItemRequirement({required this.itemId, required this.qty});
  final String itemId;
  final int    qty;

  Item? get item => itemById(itemId);
}

// ─────────────────────────────────────────────────────────────────────────────
// ItemReward — ítem que se recibe como recompensa (misión o trabajo)
// ─────────────────────────────────────────────────────────────────────────────
class ItemReward {
  const ItemReward({required this.itemId, required this.qty});
  final String itemId;
  final int    qty;

  Item? get item => itemById(itemId);
}

// ─────────────────────────────────────────────────────────────────────────────
// PlayerListing — objeto puesto a la venta en el mercado del jugador
// ─────────────────────────────────────────────────────────────────────────────
class PlayerListing {
  const PlayerListing({
    required this.id,
    required this.itemId,
    required this.qty,
    required this.pricePerUnit,
    required this.sellerName,
  });

  final String id;
  final String itemId;
  final int    qty;
  final int    pricePerUnit;
  final String sellerName;

  Item? get item => itemById(itemId);
}
