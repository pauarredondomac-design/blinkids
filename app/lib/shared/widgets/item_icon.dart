import 'package:flutter/material.dart';
import '../../data/models/item.dart';

/// Ícono de un `Item` de crafting (materiales, herramientas) — muestra la
/// ilustración real (`assets/items/<imagePath>`) cuando el item la tiene, y
/// cae al emoji mientras no exista arte para ese item todavía.
class ItemIcon extends StatelessWidget {
  const ItemIcon({super.key, required this.item, this.size = 32});

  final Item? item;
  final double size;

  @override
  Widget build(BuildContext context) {
    final path = item?.imagePath;
    if (path == null) {
      return Text(item?.emoji ?? '❓',
          style: TextStyle(fontSize: size * 0.82));
    }
    return Image.asset(
      'assets/items/$path',
      width: size,
      height: size,
      fit: BoxFit.contain,
      errorBuilder: (_, __, ___) => Text(item?.emoji ?? '❓',
          style: TextStyle(fontSize: size * 0.82)),
    );
  }
}
