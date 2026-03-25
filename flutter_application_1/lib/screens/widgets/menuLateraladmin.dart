import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import '../usuarios_screen.dart';
import '../login_screen.dart';
import 'reportes_equipo_screen.dart';
import 'lista_incidentes_admin.dart'; // Asegúrate de que la ruta sea correcta

class MenuLateralAdmin extends StatelessWidget {
  final String nombreAdmin;

  const MenuLateralAdmin({super.key, required this.nombreAdmin});

  static const _adminColor = Color.fromARGB(255, 76, 94, 175);

  @override
  Widget build(BuildContext context) {
    return Drawer(
      child: Column(
        children: [
          // Encabezado del Menú Admin
          DrawerHeader(
            decoration: const BoxDecoration(
              color: _adminColor,
            ),
            child: Align(
              alignment: Alignment.bottomLeft,
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Icon(Icons.admin_panel_settings, color: Colors.white, size: 40),
                  const SizedBox(height: 10),
                  const Text(
                    "Panel de Control",
                    style: TextStyle(color: Colors.white, fontSize: 18, fontWeight: FontWeight.bold),
                  ),
                  Text(
                    nombreAdmin,
                    style: const TextStyle(color: Colors.white70, fontSize: 14),
                  ),
                ],
              ),
            ),
          ),

          // OPCIÓN: VER USUARIOS (La que pediste)
          ListTile(
            leading: const Icon(Icons.people_alt_rounded, color: _adminColor),
            title: const Text("Gestión de Usuarios", style: TextStyle(fontWeight: FontWeight.bold)),
            onTap: () {
              Navigator.pop(context); // Cierra el drawer
              Navigator.push(
                context,
                MaterialPageRoute(builder: (_) => const UsuariosScreen()),
              );
            },
          ),

// Busca tu widget de Drawer y agrega este ListTile:

ListTile(
  leading: const Icon(Icons.assignment_late_rounded, color: Color.fromARGB(255, 76, 94, 175)),
  title: const Text("Reportes de Equipo", style: TextStyle(fontWeight: FontWeight.bold)),
  subtitle: const Text("Ver faltantes de operadores"),
  onTap: () {
    Navigator.pop(context); // Cierra el menú lateral
    Navigator.push(
      context,
      MaterialPageRoute(builder: (_) => const ReportesEquipoScreen()), // Vamos a la pantalla nueva
    );
  },
),

// En el método _buildAdminDrawer de tu AdminScreen:

ListTile(
  leading: const Icon(Icons.emergency_share, color: Color.fromARGB(255, 76, 94, 175)),
  title: const Text("Incidentes en Ruta", style: TextStyle(fontWeight: FontWeight.bold)),
  subtitle: const Text("Tráfico, averías o retrasos"),
  onTap: () {
    Navigator.pop(context);
    Navigator.push(
      context,
      MaterialPageRoute(builder: (_) => const ListaIncidentesAdmin()),
    );
  },
),


          // OPCIÓN: INICIO (Opcional)
          ListTile(
            leading: const Icon(Icons.dashboard_rounded, color: _adminColor),
            title: const Text(""),
            onTap: () => Navigator.pop(context),
          ),

          const Divider(),

          // BOTÓN CERRAR SESIÓN
          ListTile(
            leading: const Icon(Icons.logout_rounded, color: Colors.redAccent),
            title: const Text("Cerrar Sesión", style: TextStyle(color: Colors.redAccent, fontWeight: FontWeight.bold)),
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
            child: Text("Recicladora v1.0", style: TextStyle(color: Colors.grey, fontSize: 12)),
          ),
        ],
      ),
    );
  }
}