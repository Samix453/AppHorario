import 'dart:async';

import 'package:flutter/material.dart';

const kCard = Color(0xFF0E0E0E);
const kField = Color(0xFF141414);
const kChip = Color(0xFF1A1A1A);
const kBorder = Color(0xFF2A2A2A);
const kGrey = Color(0xFFA0A0A0);
const kError = Color(0xFFFF8A8A);

const kDays = ['Lunes', 'Martes', 'Miércoles', 'Jueves', 'Viernes', 'Sábado', 'Domingo'];
const kLetters = ['L', 'M', 'X', 'J', 'V', 'S', 'D'];
const kMonths = [
  'enero',
  'febrero',
  'marzo',
  'abril',
  'mayo',
  'junio',
  'julio',
  'agosto',
  'septiembre',
  'octubre',
  'noviembre',
  'diciembre',
];

const kEventPalette = [
  0xFF0B5394,
  0xFF7DB7FF,
  0xFF9FC5E8,
  0xFF00FFFF,
  0xFF5FE0C0,
  0xFF93C47D,
  0xFFC6FF3D,
  0xFFFFD966,
  0xFFF6B26B,
  0xFFFF6D01,
  0xFFCC0000,
  0xFFFF7DB0,
  0xFFC27BA0,
  0xFF8E7CC3,
  0xFFB7B7B7,
  0xFF666666,
];

const kAccentPalette = [0xFFC6FF3D, 0xFF3DE0FF, 0xFFFF8A3D, 0xFFA78BFA, 0xFFFF5C8A, 0xFFFFFFFF];

String capitalize(String s) => s.isEmpty ? s : s[0].toUpperCase() + s.substring(1);

/// Botón tipo píldora: relleno con el color secundario cuando está seleccionado.
class Pill extends StatelessWidget {
  final String label;
  final bool selected;
  final Color accent;
  final VoidCallback onTap;
  final double height;

  const Pill({
    super.key,
    required this.label,
    required this.selected,
    required this.accent,
    required this.onTap,
    this.height = 44,
  });

  @override
  Widget build(BuildContext context) {
    return Material(
      color: selected ? accent : kChip,
      borderRadius: BorderRadius.circular(12),
      child: InkWell(
        borderRadius: BorderRadius.circular(12),
        onTap: onTap,
        child: Container(
          height: height,
          padding: const EdgeInsets.symmetric(horizontal: 13),
          child: Center(
            widthFactor: 1,
            child: Text(
              label,
              style: TextStyle(
                fontSize: 14,
                fontWeight: FontWeight.w600,
                color: selected ? Colors.black : Colors.white,
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class FieldLabel extends StatelessWidget {
  final String text;

  const FieldLabel(this.text, {super.key});

  @override
  Widget build(BuildContext context) => Text(text, style: const TextStyle(fontSize: 13, color: kGrey));
}

/// Cabecera de pestaña: etiqueta pequeña en el color secundario y título grande.
class PageHeader extends StatelessWidget {
  final String label;
  final String title;
  final Color accent;
  final List<Widget> actions;

  const PageHeader({super.key, required this.label, required this.title, required this.accent, this.actions = const []});

  @override
  Widget build(BuildContext context) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.center,
      children: [
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                label.toUpperCase(),
                style: TextStyle(fontSize: 12, fontWeight: FontWeight.w600, letterSpacing: 1.5, color: accent),
              ),
              const SizedBox(height: 2),
              Text(
                title,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: const TextStyle(fontSize: 24, fontWeight: FontWeight.w700, height: 1.15),
              ),
            ],
          ),
        ),
        ...actions,
      ],
    );
  }
}

class RoundIconButton extends StatelessWidget {
  final IconData icon;
  final String tooltip;
  final VoidCallback onTap;
  final Color background;
  final Color foreground;
  final double radius;

  const RoundIconButton({
    super.key,
    required this.icon,
    required this.tooltip,
    required this.onTap,
    this.background = kField,
    this.foreground = Colors.white,
    this.radius = 22,
  });

  @override
  Widget build(BuildContext context) {
    return Tooltip(
      message: tooltip,
      child: Material(
        color: background,
        borderRadius: BorderRadius.circular(radius),
        child: InkWell(
          borderRadius: BorderRadius.circular(radius),
          onTap: onTap,
          child: SizedBox(width: 44, height: 44, child: Icon(icon, size: 22, color: foreground)),
        ),
      ),
    );
  }
}

InputDecoration fieldDecoration(String hint) => InputDecoration(
      hintText: hint,
      hintStyle: const TextStyle(color: Color(0xFF7A7A7A)),
      filled: true,
      fillColor: kField,
      isDense: true,
      contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 13),
      enabledBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(12),
        borderSide: const BorderSide(color: kBorder),
      ),
      focusedBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(12),
        borderSide: const BorderSide(color: Colors.white),
      ),
    );

/// Aparece con fade deslizándose desde la derecha, tras un retraso.
class SlideIn extends StatefulWidget {
  final int delayMs;
  final Widget child;

  const SlideIn({super.key, required this.delayMs, required this.child});

  @override
  State<SlideIn> createState() => _SlideInState();
}

class _SlideInState extends State<SlideIn> with SingleTickerProviderStateMixin {
  late final AnimationController _c = AnimationController(vsync: this, duration: const Duration(milliseconds: 400));
  late final Animation<double> _a = CurvedAnimation(parent: _c, curve: Curves.easeOut);
  Timer? _t;

  @override
  void initState() {
    super.initState();
    _t = Timer(Duration(milliseconds: widget.delayMs), () {
      if (mounted) _c.forward();
    });
  }

  @override
  void dispose() {
    _t?.cancel();
    _c.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return FadeTransition(
      opacity: _a,
      child: SlideTransition(
        position: Tween<Offset>(begin: const Offset(0.2, 0), end: Offset.zero).animate(_a),
        child: widget.child,
      ),
    );
  }
}

/// Panel que se abre y se cierra con fade y cambio de tamaño.
class FadePanel extends StatelessWidget {
  final bool open;
  final Widget child;

  const FadePanel({super.key, required this.open, required this.child});

  @override
  Widget build(BuildContext context) {
    return AnimatedSize(
      duration: const Duration(milliseconds: 220),
      curve: Curves.easeOut,
      alignment: Alignment.topCenter,
      child: AnimatedSwitcher(
        duration: const Duration(milliseconds: 200),
        child: open
            ? KeyedSubtree(key: const ValueKey('open'), child: child)
            : const SizedBox(key: ValueKey('closed'), width: double.infinity),
      ),
    );
  }
}
