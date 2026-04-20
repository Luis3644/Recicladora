qimport 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import '../../config/session_manager.dart';
import '../login_screen.dart';
import '../reporte_screen.dart';
import '../mis_reportes_operador.dart';

class MenuLateral extends StatelessWidget {
  final String nombreUsuario;
  final String camion; // <--- Agregamos esto
  final String placas;
  final bool mostrarCerrarSesion;

  const MenuLateral({
    super.key,
    required this.nombreUsuario,
    this.camion = "Sin asignar", // Valor por defecto
    this.placas = "---",
    this.mostrarCerrarSesion = true,
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
                      "Menú",
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
  leading: const Icon(Icons.assignment_ind_rounded, color: Color(0xFF06B6D4)), // Color accent que usas
  title: const Text(
    'Mis Reportes ',
    style: TextStyle(fontWeight: FontWeight.w700),
  ),
  onTap: () {
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => const MisReportesOperador(nombreOperador: 'Alberto'), 
        // Nota: Aquí 'Alberto' debería ser la variable donde guardas el nombre del usuario logueado
      ),
    );
  },
),

         

        
          const Spacer(),
          const Padding(
            padding: EdgeInsets.all(16),
            child: Text(
              "Recicladora v1.0",
              style: TextStyle(color: Color(0xFF94A3B8)),
            ),
          ),
        ],
      ),
    );
  }
}
