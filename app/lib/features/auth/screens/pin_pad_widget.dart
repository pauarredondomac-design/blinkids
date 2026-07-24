import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';

class PinPadWidget extends StatefulWidget {
  const PinPadWidget({
    super.key,
    required this.onDigit,
    required this.onDelete,
  });
  final void Function(String digit) onDigit;
  final VoidCallback onDelete;

  @override
  State<PinPadWidget> createState() => _PinPadWidgetState();
}

class _PinPadWidgetState extends State<PinPadWidget> {
  String? _pressed;

  static const _layout = [
    ['1', '2', '3'],
    ['4', '5', '6'],
    ['7', '8', '9'],
    ['', '0', '<'],
  ];

  void _tap(String key) {
    setState(() => _pressed = key);
    Future.delayed(120.ms, () {
      if (mounted) setState(() => _pressed = null);
    });
    if (key == '<') {
      widget.onDelete();
    } else if (key.isNotEmpty) {
      widget.onDigit(key);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: _layout.map((row) {
        return Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: row.map((key) {
            if (key.isEmpty) return const SizedBox(width: 72, height: 72);
            return _PinKey(
              label: key,
              isDelete: key == '<',
              isPressed: _pressed == key,
              onTap: () => _tap(key),
            );
          }).toList(),
        );
      }).toList(),
    );
  }
}

class _PinKey extends StatelessWidget {
  const _PinKey({
    required this.label,
    required this.isDelete,
    required this.isPressed,
    required this.onTap,
  });
  final String label;
  final bool   isDelete;
  final bool   isPressed;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: AnimatedContainer(
        duration: 100.ms,
        width: 72,
        height: 72,
        margin: const EdgeInsets.all(6),
        decoration: BoxDecoration(
          color: isPressed
              ? const Color(0xFF4FC3F7).withOpacity(0.25)
              : const Color(0xFF1A2A5E).withOpacity(0.6),
          shape: BoxShape.circle,
          border: Border.all(
            color: isPressed ? const Color(0xFF4FC3F7) : Colors.white24,
            width: isPressed ? 2 : 1,
          ),
          boxShadow: isPressed
              ? [BoxShadow(color: const Color(0xFF4FC3F7).withOpacity(0.3), blurRadius: 12)]
              : null,
        ),
        child: Center(
          child: isDelete
              ? const Icon(Icons.backspace_outlined, color: Colors.white70, size: 22)
              : Text(
                  label,
                  style: const TextStyle(
                    fontFamily: 'Nunito',
                    fontWeight: FontWeight.w700,
                    fontSize: 26,
                    color: Colors.white,
                  ),
                ),
        ),
      ),
    );
  }
}
