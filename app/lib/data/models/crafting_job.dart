import 'item.dart';

// ─────────────────────────────────────────────────────────────────────────────
// CraftingJob — trabajo de crafting con materiales e recompensas
// ─────────────────────────────────────────────────────────────────────────────
class CraftingJob {
  const CraftingJob({
    required this.id,
    required this.emoji,
    required this.name,
    required this.npcName,
    required this.npcEmoji,
    required this.story,
    required this.world,
    required this.requirements,
    required this.coinReward,
    required this.xpReward,
    this.itemReward,
    this.fuelReward = 0,
    this.chapter,
    this.chapterNumber,
    this.orderInChapter,
  });

  final String id;
  final String emoji;
  final String name;
  final String npcName;
  final String npcEmoji;
  final String story;

  /// 'forest' | 'space'
  final String world;
  final List<ItemRequirement> requirements;
  final int coinReward;
  final int xpReward;

  /// Ítem opcional de recompensa (además de monedas)
  final ItemReward? itemReward;

  /// Combustible directo (0-100) que se suma a la barra al completar
  final int fuelReward;

  // ── Campos de capítulo de historia (nuevos, null = trabajo sin capítulo) ──
  final String? chapter;
  final int? chapterNumber;
  final int? orderInChapter;
}

// ─────────────────────────────────────────────────────────────────────────────
// Catálogo de trabajos de crafting
// ─────────────────────────────────────────────────────────────────────────────
const allCraftingJobs = <CraftingJob>[
  // ── BOSQUE ──────────────────────────────────────────────────────────────
  CraftingJob(
    id: 'repair_cabin',
    emoji: '🏚️',
    name: 'Reparar la Cabaña',
    npcName: 'Osito Bruno',
    npcEmoji: '🐻',
    story:
        '¡Hola aventurero! Un árbol cayó sobre mi cabaña durante la tormenta. '
        'Necesito 3 tablones de madera y un martillo para repararla. '
        '¿Me puedes ayudar? ¡Te lo agradeceré con muchas monedas!',
    world: 'forest',
    requirements: [
      ItemRequirement(itemId: 'wood_plank', qty: 3),
      ItemRequirement(itemId: 'hammer', qty: 1),
    ],
    coinReward: 250,
    xpReward: 40,
  ),
  CraftingJob(
    id: 'heal_fox',
    emoji: '🦊',
    name: 'Curar al Zorro',
    npcName: 'Doctora Búho',
    npcEmoji: '🦉',
    story: 'El zorro del bosque está muy enfermo y necesita ayuda urgente. '
        'Prepara 2 hierbas mágicas mezcladas con 1 poción de salud '
        'para hacer la medicina. ¡Date prisa, por favor!',
    world: 'forest',
    requirements: [
      ItemRequirement(itemId: 'magic_herb', qty: 2),
      ItemRequirement(itemId: 'health_potion', qty: 1),
    ],
    coinReward: 200,
    xpReward: 30,
  ),
  CraftingJob(
    id: 'squirrel_feast',
    emoji: '🐿️',
    name: 'El Festín de la Ardilla',
    npcName: 'Ardilla Chispa',
    npcEmoji: '🐿️',
    story: '¡El invierno se acerca y no tengo suficiente comida! '
        'Necesito juntar 5 bellotas para llenar mi despensa. '
        'Si me las consigues, te doy unas hierbas especiales que encontré.',
    world: 'forest',
    requirements: [
      ItemRequirement(itemId: 'acorn', qty: 5),
    ],
    coinReward: 150,
    xpReward: 20,
    itemReward: ItemReward(itemId: 'magic_herb', qty: 2),
  ),

  // ── ESPACIO ──────────────────────────────────────────────────────────────
  CraftingJob(
    id: 'repair_ship',
    emoji: '🚀',
    name: 'Reparar la Nave',
    npcName: 'Capitán Astro',
    npcEmoji: '👨‍🚀',
    story: '¡Socorro, astronauta! Mi nave espacial chocó con un asteroide. '
        'Necesito 3 pernos espaciales y 1 llave inglesa para repararla. '
        'Si me ayudas, te doy una recompensa galáctica muy especial.',
    world: 'space',
    requirements: [
      ItemRequirement(itemId: 'space_bolt', qty: 3),
      ItemRequirement(itemId: 'wrench', qty: 1),
    ],
    coinReward: 300,
    xpReward: 50,
    fuelReward: 10,
  ),
  CraftingJob(
    id: 'power_station',
    emoji: '⚡',
    name: 'Activar la Estación',
    npcName: 'Robot R2',
    npcEmoji: '🤖',
    story: 'BEEP BOOP - Estación de energía sin poder. '
        'Necesito 2 baterías cuánticas y 1 cápsula de combustible '
        'para reactivar los sistemas. ¡Muchas gracias, humano amigo!',
    world: 'space',
    requirements: [
      ItemRequirement(itemId: 'battery', qty: 2),
      ItemRequirement(itemId: 'fuel_capsule', qty: 1),
    ],
    coinReward: 250,
    xpReward: 35,
  ),
  CraftingJob(
    id: 'fix_robot',
    emoji: '🦾',
    name: 'Arreglar al Robot',
    npcName: 'Ingeniera Luna',
    npcEmoji: '👩‍🔬',
    story: 'El robot de mantenimiento de la estación espacial se descompuso. '
        'Para repararlo necesito 1 llave inglesa, 2 circuitos lunares '
        'y 1 perno espacial. ¡Es urgente para la misión!',
    world: 'space',
    requirements: [
      ItemRequirement(itemId: 'wrench', qty: 1),
      ItemRequirement(itemId: 'lunar_circuit', qty: 2),
      ItemRequirement(itemId: 'space_bolt', qty: 1),
    ],
    coinReward: 350,
    xpReward: 60,
    fuelReward: 10,
  ),
];

// ─────────────────────────────────────────────────────────────────────────────
// Helper
// ─────────────────────────────────────────────────────────────────────────────
List<CraftingJob> craftingJobsForWorld(String worldId) =>
    allCraftingJobs.where((j) => j.world == worldId).toList();
