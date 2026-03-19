import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'usuarios_screen.dart'; // Asegúrate de que el nombre del archivo sea correcto
import 'login_screen.dart';    // Para el cierre de sesión

class AdminScreen extends StatefulWidget {
  const AdminScreen({super.key});

  @override
  State<AdminScreen> createState() => _AdminScreenState();
}

class _AdminScreenState extends State<AdminScreen> {
  String nombreUsuario = "";
  bool isLoading = true;

  // Color principal que ya estás usando en tu Admin
  final Color adminColor = const Color.fromARGB(255, 76, 94, 175);

  @override
  void initState() {
    super.initState();
    obtenerNombre();
  }

  Future<void> obtenerNombre() async {
    try {
      final uid = FirebaseAuth.instance.currentUser?.uid;
      if (uid == null) return;

      final doc = await FirebaseFirestore.instance
          .collection("usuarios")
          .doc(uid)
          .get();

      if (doc.exists) {
        setState(() {
          nombreUsuario = doc["nombre"] ?? "Administrador";
          isLoading = false;
        });
      }
    } catch (e) {
      print("Error obteniendo nombre: $e");
      setState(() => isLoading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: isLoading
            ? const Text("Cargando...")
            : Text("Panel Admin: $nombreUsuario"),
        backgroundColor: adminColor,
        foregroundColor: Colors.white,
        elevation: 0,
      ),
      
      // --- BARRA LATERAL (DRAWER) ---
      drawer: isLoading ? null : _buildAdminDrawer(context),

      // --- CUERPO PRINCIPAL ---
      body: Container(
        width: double.infinity,
        color: Colors.grey[100],
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.admin_panel_settings_rounded, size: 100, color: adminColor.withOpacity(0.3)),
            const SizedBox(height: 20),
            Text(
              "Bienvenido, $nombreUsuario",
              style: TextStyle(fontSize: 24, fontWeight: FontWeight.bold, color: adminColor),
            ),
            const SizedBox(height: 10),
            const Padding(
              padding: EdgeInsets.symmetric(horizontal: 40),
              child: Text(
                "Usa el menú lateral para gestionar los usuarios y revisar los reportes de la recicladora.",
                textAlign: TextAlign.center,
                style: TextStyle(color: Colors.grey, fontSize: 16),
              ),
            ),
          ],
        ),
      ),
    );
  }

  // --- WIDGET DEL MENÚ LATERAL ---
  Widget _buildAdminDrawer(BuildContext context) {
    return Drawer(
      child: Column(
        children: [
          // Encabezado del Menú
          UserAccountsDrawerHeader(
            decoration: BoxDecoration(color: adminColor),
            currentAccountPicture: const CircleAvatar(
              backgroundColor: Colors.white,
              child: Icon(Icons.person, size: 45, color: Color.fromARGB(255, 76, 94, 175)),
            ),
            accountName: Text(
              nombreUsuario,
              style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 18),
            ),
            accountEmail: const Text("Administrador del Sistema"),
          ),

          // Opción: Ver Usuarios
          ListTile(
            leading: Icon(Icons.people_alt_rounded, color: adminColor),
            title: const Text("Gestión de Usuarios", style: TextStyle(fontWeight: FontWeight.bold)),
            subtitle: const Text("Ver, editar o eliminar"),
            onTap: () {
              Navigator.pop(context); // Cierra el menú
              Navigator.push(
                context,
                MaterialPageRoute(builder: (_) => const UsuariosScreen()),
              );
            },
          ),

          // Opción: Reportes (Ejemplo para futuro)
          ListTile(
            leading: Icon(Icons.assignment_rounded, color: adminColor),
            title: const Text("Reportes de Incidentes"),
            onTap: () {
              Navigator.pop(context);
              // Aquí podrías navegar a una pantalla de reportes generales
            },
          ),

          const Divider(),

          // Opción: Cerrar Sesión
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
            child: Text(
              "Recicladora App Admin v1.0",
              style: TextStyle(color: Colors.grey, fontSize: 12),
            ),
          ),
        ],
      ),
    );
  }
}