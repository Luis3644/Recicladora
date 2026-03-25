import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'usuarios_screen.dart';
import 'login_screen.dart';
import 'widgets/reportes_equipo_screen.dart';
import 'widgets/lista_incidentes_admin.dart';

class AdminScreen extends StatefulWidget {
  const AdminScreen({super.key});

  @override
  State<AdminScreen> createState() => _AdminScreenState();
}

class _AdminScreenState extends State<AdminScreen> {
  String nombreUsuario = "";
  bool isLoading = true;

  final Color adminColor = const Color.fromARGB(255, 76, 94, 175);

  @override
  void initState() {
    super.initState();
    obtenerNombre();
  }

  Future<void> obtenerNombre() async {
    try {
      final uid = FirebaseAuth.instance.currentUser?.uid;
      if (uid == null) {
        setState(() => isLoading = false);
        return;
      }

      final doc = await FirebaseFirestore.instance
          .collection("usuarios")
          .doc(uid)
          .get();

      setState(() {
        nombreUsuario = doc.exists
            ? (doc["nombre"] ?? "Administrador")
            : "Administrador";
        isLoading = false;
      });
    } catch (e) {
      print("Error obteniendo nombre: $e");
      setState(() => isLoading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF3F5FA),
      appBar: AppBar(
        title: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text("Panel de Administración"),
            Text(
              isLoading ? "Cargando perfil..." : "Hola, $nombreUsuario",
              style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w400),
            ),
          ],
        ),
        backgroundColor: adminColor,
        foregroundColor: Colors.white,
        elevation: 2,
      ),
      drawer: _buildAdminDrawer(context),

      body: isLoading
          ? Center(child: CircularProgressIndicator(color: adminColor))
          : Stack(
              children: [
                Container(
                  height: 220,
                  decoration: BoxDecoration(
                    gradient: LinearGradient(
                      begin: Alignment.topLeft,
                      end: Alignment.bottomRight,
                      colors: [
                        adminColor,
                        Color.lerp(adminColor, Colors.black, 0.18)!,
                      ],
                    ),
                  ),
                ),
                SingleChildScrollView(
                  padding: const EdgeInsets.fromLTRB(20, 18, 20, 20),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Container(
                        width: double.infinity,
                        padding: const EdgeInsets.all(20),
                        decoration: BoxDecoration(
                          color: Colors.white.withOpacity(0.16),
                          borderRadius: BorderRadius.circular(18),
                          border: Border.all(color: Colors.white.withOpacity(0.18)),
                        ),
                        child: Row(
                          children: [
                            Container(
                              decoration: BoxDecoration(
                                color: Colors.white.withOpacity(0.2),
                                shape: BoxShape.circle,
                              ),
                              padding: const EdgeInsets.all(12),
                              child: const Icon(
                                Icons.verified_user_rounded,
                                color: Colors.white,
                                size: 30,
                              ),
                            ),
                            const SizedBox(width: 14),
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(
                                    "Bienvenido, $nombreUsuario",
                                    style: const TextStyle(
                                      fontSize: 20,
                                      fontWeight: FontWeight.w700,
                                      color: Colors.white,
                                    ),
                                  ),
                                  const SizedBox(height: 4),
                                  const Text(
                                    "Controla usuarios, reportes e incidentes desde un solo lugar.",
                                    style: TextStyle(color: Colors.white70),
                                  ),
                                ],
                              ),
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(height: 16),
                      Row(
                        children: const [
                          Expanded(
                            child: _InfoChip(
                              icon: Icons.people_alt_rounded,
                              label: "Usuarios",
                            ),
                          ),
                          SizedBox(width: 10),
                          Expanded(
                            child: _InfoChip(
                              icon: Icons.assignment_late_rounded,
                              label: "Reportes",
                            ),
                          ),
                          SizedBox(width: 10),
                          Expanded(
                            child: _InfoChip(
                              icon: Icons.emergency_share,
                              label: "Incidentes",
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 24),
                      const Text(
                        "Accesos rápidos",
                        style: TextStyle(
                          fontSize: 18,
                          fontWeight: FontWeight.w700,
                          color: Colors.black87,
                        ),
                      ),
                      const SizedBox(height: 12),
                      Wrap(
                        spacing: 12,
                        runSpacing: 12,
                        children: [
                          _buildQuickActionCard(
                            context: context,
                            icon: Icons.people_alt_rounded,
                            title: "Gestión de Usuarios",
                            subtitle: "Ver, editar o eliminar",
                            onTap: _abrirUsuarios,
                          ),
                          _buildQuickActionCard(
                            context: context,
                            icon: Icons.assignment_late_rounded,
                            title: "Reportes de Equipo",
                            subtitle: "Ver faltantes de operadores",
                            onTap: _abrirReportes,
                          ),
                          _buildQuickActionCard(
                            context: context,
                            icon: Icons.emergency_share,
                            title: "Incidentes en Ruta",
                            subtitle: "Tráfico, averías o retrasos",
                            onTap: _abrirIncidentes,
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
              ],
            ),
    );
  }

  Widget _buildQuickActionCard({
    required BuildContext context,
    required IconData icon,
    required String title,
    required String subtitle,
    required VoidCallback onTap,
  }) {
    final width = (MediaQuery.of(context).size.width - 52) / 2;

    return SizedBox(
      width: width < 240 ? double.infinity : width,
      child: Material(
        color: Colors.white,
        borderRadius: BorderRadius.circular(14),
        elevation: 1,
        shadowColor: Colors.black.withOpacity(0.08),
        child: InkWell(
          borderRadius: BorderRadius.circular(14),
          onTap: onTap,
          child: Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(14),
              border: Border.all(color: adminColor.withOpacity(0.14)),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Container(
                      padding: const EdgeInsets.all(8),
                      decoration: BoxDecoration(
                        color: adminColor.withOpacity(0.1),
                        borderRadius: BorderRadius.circular(10),
                      ),
                      child: Icon(icon, color: adminColor, size: 22),
                    ),
                    const Spacer(),
                    Icon(Icons.arrow_forward_ios_rounded, size: 14, color: adminColor),
                  ],
                ),
                const SizedBox(height: 12),
                Text(
                  title,
                  style: const TextStyle(
                    fontWeight: FontWeight.bold,
                    fontSize: 15,
                  ),
                ),
                const SizedBox(height: 6),
                Text(
                  subtitle,
                  style: const TextStyle(color: Colors.black54, fontSize: 13),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  void _abrirUsuarios() {
    Navigator.push(
      context,
      MaterialPageRoute(builder: (_) => const UsuariosScreen()),
    );
  }

  void _abrirReportes() {
    Navigator.push(
      context,
      MaterialPageRoute(builder: (_) => const ReportesEquipoScreen()),
    );
  }

  void _abrirIncidentes() {
    Navigator.push(
      context,
      MaterialPageRoute(builder: (_) => const ListaIncidentesAdmin()),
    );
  }

  Widget _buildAdminDrawer(BuildContext context) {
    return Drawer(
      backgroundColor: const Color(0xFFF7F8FC),
      child: Column(
        children: [
          UserAccountsDrawerHeader(
            decoration: BoxDecoration(
              gradient: LinearGradient(
                colors: [adminColor, Color.lerp(adminColor, Colors.black, 0.2)!],
              ),
            ),
            currentAccountPicture: const CircleAvatar(
              backgroundColor: Colors.white,
              child: Icon(
                Icons.person,
                size: 45,
                color: Color.fromARGB(255, 76, 94, 175),
              ),
            ),
            accountName: Text(
              isLoading ? "Administrador" : nombreUsuario,
              style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 18),
            ),
            accountEmail: const Text("Administrador del Sistema"),
          ),
          _buildDrawerItem(
            icon: Icons.people_alt_rounded,
            title: "Gestión de Usuarios",
            subtitle: "Ver, editar o eliminar",
            onTap: () {
              Navigator.pop(context);
              _abrirUsuarios();
            },
          ),
          _buildDrawerItem(
            icon: Icons.assignment_late_rounded,
            title: "Reportes de Equipo",
            subtitle: "Ver faltantes de operadores",
            onTap: () {
              Navigator.pop(context);
              _abrirReportes();
            },
          ),
          _buildDrawerItem(
            icon: Icons.emergency_share,
            title: "Incidentes en Ruta",
            subtitle: "Tráfico, averías o retrasos",
            onTap: () {
              Navigator.pop(context);
              _abrirIncidentes();
            },
          ),
          const Divider(),
          ListTile(
            leading: const Icon(Icons.logout_rounded, color: Colors.redAccent),
            title: const Text(
              "Cerrar Sesión",
              style: TextStyle(
                color: Colors.redAccent,
                fontWeight: FontWeight.bold,
              ),
            ),
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
              "Recicladora v1.0",
              style: TextStyle(color: Colors.grey, fontSize: 12),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildDrawerItem({
    required IconData icon,
    required String title,
    required String subtitle,
    required VoidCallback onTap,
  }) {
    return ListTile(
      contentPadding: const EdgeInsets.symmetric(horizontal: 18, vertical: 2),
      leading: Container(
        padding: const EdgeInsets.all(8),
        decoration: BoxDecoration(
          color: adminColor.withOpacity(0.12),
          borderRadius: BorderRadius.circular(10),
        ),
        child: Icon(icon, color: adminColor, size: 20),
      ),
      title: Text(title, style: const TextStyle(fontWeight: FontWeight.bold)),
      subtitle: Text(subtitle),
      trailing: const Icon(Icons.chevron_right_rounded),
      onTap: onTap,
    );
  }
}

class _InfoChip extends StatelessWidget {
  final IconData icon;
  final String label;

  const _InfoChip({required this.icon, required this.label});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 10),
      decoration: BoxDecoration(
        color: Colors.white.withOpacity(0.18),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: Colors.white.withOpacity(0.22)),
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(icon, color: Colors.white, size: 16),
          const SizedBox(width: 6),
          Flexible(
            child: Text(
              label,
              overflow: TextOverflow.ellipsis,
              style: const TextStyle(
                color: Colors.white,
                fontWeight: FontWeight.w600,
                fontSize: 12,
              ),
            ),
          ),
        ],
      ),
    );
  }
}
