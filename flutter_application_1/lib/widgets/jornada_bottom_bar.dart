import 'package:flutter/material.dart';

class JornadaBottomBar extends StatelessWidget {
  final int activeIndex;
  final VoidCallback onInicio;
  final VoidCallback onHistorial;
  final VoidCallback onReporte;
  final VoidCallback onPerfil;

  const JornadaBottomBar({
    super.key,
    required this.activeIndex,
    required this.onInicio,
    required this.onHistorial,
    required this.onReporte,
    required this.onPerfil,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      height: 68,
      decoration: const BoxDecoration(
        color: Color(0xFFF3F4F6),
        border: Border(top: BorderSide(color: Color(0xFFD8DEE7), width: 1)),
      ),
      child: Row(
        children: [
          Expanded(
            child: BottomItem(
              icon: Icons.home_rounded,
              label: 'Inicio',
              active: activeIndex == 0,
              onTap: onInicio,
            ),
          ),
          Expanded(
            child: BottomItem(
              icon: Icons.history,
              label: 'Historial',
              active: activeIndex == 1,
              onTap: onHistorial,
            ),
          ),
          Expanded(
            child: BottomItem(
              icon: Icons.warning_amber_rounded,
              label: 'Incidente',
              active: activeIndex == 3,
              onTap: onReporte,
            ),
          ),
          Expanded(
            child: BottomItem(
              icon: Icons.person_outline_rounded,
              label: 'Perfil',
              active: activeIndex == 2,
              onTap: onPerfil,
            ),
          ),
        ],
      ),
    );
  }
}

class BottomItem extends StatelessWidget {
  final IconData icon;
  final String label;
  final bool active;
  final VoidCallback? onTap;

  const BottomItem({
    super.key,
    required this.icon,
    required this.label,
    this.active = false,
    this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final color = active ? const Color(0xFF059669) : const Color(0xFF8A94A6);
    return InkWell(
      onTap: onTap,
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(icon, color: color, size: 22),
          const SizedBox(height: 2),
          Text(
            label,
            style: TextStyle(
              color: color,
              fontSize: 12,
              fontWeight: active ? FontWeight.w700 : FontWeight.w500,
            ),
          ),
        ],
      ),
    );
  }
}
