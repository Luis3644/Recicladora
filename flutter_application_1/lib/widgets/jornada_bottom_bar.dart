import 'package:flutter/material.dart';

class JornadaBottomBar extends StatelessWidget {
  final int activeIndex;
  final VoidCallback onInicio;
  final VoidCallback onContenedores;
  final VoidCallback onHistorial;
  final VoidCallback onPerfil;
  final VoidCallback? onReporte;

  const JornadaBottomBar({
    super.key,
    required this.activeIndex,
    required this.onInicio,
    required this.onContenedores,
    required this.onHistorial,
    required this.onPerfil,
    this.onReporte,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      height: 72,
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: const BorderRadius.vertical(top: Radius.circular(20)),
        boxShadow: [
          BoxShadow(
            color: const Color(0xFF0F172A).withOpacity(0.06),
            blurRadius: 16,
            offset: const Offset(0, -4),
          ),
        ],
        border: const Border(
          top: BorderSide(color: Color(0xFFE2E8F0), width: 1),
        ),
      ),
      child: SafeArea(
        top: false,
        child: Row(
          mainAxisAlignment: MainAxisAlignment.spaceAround,
          children: [
            _buildNavItem(
              index: 0,
              icon: Icons.home_rounded,
              activeIcon: Icons.home_rounded,
              label: 'Inicio',
              onTap: onInicio,
            ),
            _buildNavItem(
              index: 1,
              icon: Icons.inventory_2_outlined,
              activeIcon: Icons.inventory_2_rounded,
              label: 'Contenedores',
              onTap: onContenedores,
            ),
            _buildNavItem(
              index: 2,
              icon: Icons.history_rounded,
              activeIcon: Icons.history_rounded,
              label: 'Historial',
              onTap: onHistorial,
            ),
            _buildNavItem(
              index: 3,
              icon: Icons.person_outline_rounded,
              activeIcon: Icons.person_rounded,
              label: 'Perfil',
              onTap: onPerfil,
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildNavItem({
    required int index,
    required IconData icon,
    required IconData activeIcon,
    required String label,
    required VoidCallback onTap,
  }) {
    final bool active = activeIndex == index;
    const Color activeColor = Color(0xFF059669);
    const Color inactiveColor = Color(0xFF94A3B8);
    final Color color = active ? activeColor : inactiveColor;

    return Expanded(
      child: GestureDetector(
        onTap: onTap,
        behavior: HitTestBehavior.opaque,
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            AnimatedContainer(
              duration: const Duration(milliseconds: 250),
              padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 6),
              decoration: BoxDecoration(
                color: active ? activeColor.withOpacity(0.08) : Colors.transparent,
                borderRadius: BorderRadius.circular(16),
              ),
              child: Icon(
                active ? activeIcon : icon,
                color: color,
                size: 22,
              ),
            ),
            const SizedBox(height: 3),
            Text(
              label,
              style: TextStyle(
                color: color,
                fontSize: 11,
                fontWeight: active ? FontWeight.w800 : FontWeight.w600,
                letterSpacing: 0.1,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
