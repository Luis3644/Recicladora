import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import '../usuarios_screen.dart';
import '../login_screen.dart';
import 'reportes_equipo_screen.dart';
import 'lista_incidentes_admin.dart';

class MenuLateralAdmin extends StatefulWidget {
  final String nombreAdmin;

  const MenuLateralAdmin({super.key, required this.nombreAdmin});

  @override
  State<MenuLateralAdmin> createState() => _MenuLateralAdminState();
}

class _MenuLateralAdminState extends State<MenuLateralAdmin>
    with SingleTickerProviderStateMixin {
  static const _adminColor = Color.fromARGB(255, 76, 94, 175);

  // ── Controla si el submenú de Camiones está abierto ──
  bool _camionesExpanded = false;

  late AnimationController _animCtrl;
  late Animation<double> _rotateAnim;

  @override
  void initState() {
    super.initState();
    _animCtrl = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 220),
    );
    _rotateAnim = Tween<double>(begin: 0, end: 0.5).animate(
      CurvedAnimation(parent: _animCtrl, curve: Curves.easeInOut),
    );
  }

  @override
  void dispose() {
    _animCtrl.dispose();
    super.dispose();
  }

  void _toggleCamiones() {
    setState(() => _camionesExpanded = !_camionesExpanded);
    _camionesExpanded ? _animCtrl.forward() : _animCtrl.reverse();
  }

  @override
  Widget build(BuildContext context) {
    return Drawer(
      child: Column(
        children: [
          // ── Encabezado ────────────────────────────────────────────────────
          DrawerHeader(
            decoration: const BoxDecoration(color: _adminColor),
            child: Align(
              alignment: Alignment.bottomLeft,
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Icon(Icons.admin_panel_settings,
                      color: Colors.white, size: 40),
                  const SizedBox(height: 10),
                  const Text(
                    "Panel de Control",
                    style: TextStyle(
                        color: Colors.white,
                        fontSize: 18,
                        fontWeight: FontWeight.bold),
                  ),
                  Text(
                    widget.nombreAdmin,
                    style: const TextStyle(color: Colors.white70, fontSize: 14),
                  ),
                ],
              ),
            ),
          ),

          // ── Gestión de Usuarios ───────────────────────────────────────────
          ListTile(
            leading: const Icon(Icons.people_alt_rounded, color: _adminColor),
            title: const Text("Gestión de Usuarios",
                style: TextStyle(fontWeight: FontWeight.bold)),
            onTap: () {
              Navigator.pop(context);
              Navigator.push(
                context,
                MaterialPageRoute(builder: (_) => const UsuariosScreen()),
              );
            },
          ),

          // ── CAMIONES (expandible) ─────────────────────────────────────────
          // Encabezado del grupo
          InkWell(
            onTap: _toggleCamiones,
            child: Padding(
              padding:
                  const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
              child: Row(
                children: [
                  const Icon(Icons.local_shipping_rounded, color: _adminColor),
                  const SizedBox(width: 16),
                  const Expanded(
                    child: Text(
                      "Camiones",
                      style: TextStyle(
                          fontWeight: FontWeight.bold, fontSize: 15),
                    ),
                  ),
                  RotationTransition(
                    turns: _rotateAnim,
                    child: const Icon(Icons.keyboard_arrow_down_rounded,
                        color: Colors.grey),
                  ),
                ],
              ),
            ),
          ),

          // Submenú animado
          AnimatedCrossFade(
            duration: const Duration(milliseconds: 220),
            crossFadeState: _camionesExpanded
                ? CrossFadeState.showSecond
                : CrossFadeState.showFirst,
            firstChild: const SizedBox.shrink(),
            secondChild: Container(
              decoration: BoxDecoration(
                color: _adminColor.withOpacity(0.05),
                border: Border(
                  left: BorderSide(
                      color: _adminColor.withOpacity(0.4), width: 3),
                ),
              ),
              margin: const EdgeInsets.only(left: 24, right: 8, bottom: 4),
              child: Column(
                children: [
                  // → Gestión de Camiones
                  ListTile(
                    dense: true,
                    leading: const Icon(Icons.assignment_late_rounded,
                        color: _adminColor, size: 20),
                    title: const Text("Reportes de Equipo",
                        style: TextStyle(fontWeight: FontWeight.w600)),
                    subtitle: const Text("Ver faltantes de operadores",
                        style: TextStyle(fontSize: 11)),
                    onTap: () {
                      Navigator.pop(context);
                      Navigator.push(
                        context,
                        MaterialPageRoute(
                            builder: (_) => const ReportesEquipoScreen()),
                      );
                    },
                  ),
                  // → Reportes de Camiones
                  ListTile(
                    dense: true,
                    leading: const Icon(Icons.emergency_share,
                        color: _adminColor, size: 20),
                    title: const Text("Incidentes en Ruta",
                        style: TextStyle(fontWeight: FontWeight.w600)),
                    subtitle: const Text("Tráfico, averías o retrasos",
                        style: TextStyle(fontSize: 11)),
                    onTap: () {
                      Navigator.pop(context);
                      Navigator.push(
                        context,
                        MaterialPageRoute(
                            builder: (_) => const ListaIncidentesAdmin()),
                      );
                    },
                  ),
                ],
              ),
            ),
          ),

          const Divider(),

          // ── Cerrar Sesión ─────────────────────────────────────────────────
          ListTile(
            leading: const Icon(Icons.logout_rounded, color: Colors.redAccent),
            title: const Text("Cerrar Sesión",
                style: TextStyle(
                    color: Colors.redAccent, fontWeight: FontWeight.bold)),
            onTap: () async {
              await FirebaseAuth.instance.signOut();
              if (context.mounted) {
                Navigator.of(context).pushAndRemoveUntil(
                  MaterialPageRoute(builder: (_) => const LoginScreen()),
                  (route) => false,
                );
              }
            },
          ),

          const Spacer(),
          const Padding(
            padding: EdgeInsets.all(16.0),
            child: Text("Recicladora v1.0",
                style: TextStyle(color: Colors.grey, fontSize: 12)),
          ),
        ],
      ),
    );
  }
}