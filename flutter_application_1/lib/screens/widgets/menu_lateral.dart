import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import '../login_screen.dart'; 
import '../reporte_screen.dart';

class MenuLateral extends StatelessWidget {
  final String nombreUsuario;
  final String camion; // <--- Agregamos esto
  final String placas;

  const MenuLateral({super.key, 
  required this.nombreUsuario,
  this.camion = "Sin asignar", // Valor por defecto
    this.placas = "---"
  });

  // Colores que ya estás usando
  static const _primary = Color(0xFF1E3A8A);
  static const _primary2 = Color(0xFF2563EB);

  @override
  Widget build(BuildContext context) {
    return Drawer(
      child: Column(
        children: [
          DrawerHeader(
            margin: EdgeInsets.zero,
            padding: EdgeInsets.zero,
            child: Container(
              decoration: const BoxDecoration(
                gradient: LinearGradient(
                  colors: [_primary, _primary2],
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                ),
              ),
              padding: const EdgeInsets.fromLTRB(16, 18, 16, 16),
              child: Align(
                alignment: Alignment.bottomLeft,
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text(
                      "Menú Logística",
                      style: TextStyle(
                        color: Colors.white,
                        fontSize: 18,
                        fontWeight: FontWeight.w800,
                      ),
                    ),
                    const SizedBox(height: 6),
                    Text(
                      nombreUsuario,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(color: Colors.white70),
                    ),
                  ],
                ),
              ),
            ),
          ),

ListTile(
  leading: const Icon(Icons.report_problem_rounded, color: Colors.orange),
  title: const Text("Reportar Incidente"),
  onTap: () {
    Navigator.of(context).pop(); // Cierra el menú
    Navigator.of(context).push(
      MaterialPageRoute(
        builder: (_) => ReporteScreen(
          nombreUsuario: nombreUsuario,
          camion: camion,
          placas: placas,
          ),
      ),
    );
  },
),

          ListTile(
            leading: const Icon(Icons.home_rounded, color: _primary),
            title: const Text("Inicio", style: TextStyle(fontWeight: FontWeight.w700)),
            onTap: () => Navigator.of(context).pop(), // Solo cierra el menú
          ),
          ListTile(
            leading: const Icon(Icons.logout_rounded, color: Colors.redAccent),
            title: const Text("Cerrar sesión", style: TextStyle(fontWeight: FontWeight.w700)),
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
            padding: EdgeInsets.all(16),
            child: Text("Recicladora v1.0", style: TextStyle(color: Color(0xFF94A3B8))),
          ),
        ],
      ),
    );
  }
}