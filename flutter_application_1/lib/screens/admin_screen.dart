import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';

import 'login_screen.dart';
import 'usuarios_screen.dart';
import 'widgets/lista_incidentes_admin.dart';
import 'widgets/reportes_equipo_screen.dart';

class _AnimatedOptionCard extends StatefulWidget {
  final IconData icon;
  final String title;
  final String description;
  final VoidCallback onTap;
  final Color color;

  const _AnimatedOptionCard({
    required this.icon,
    required this.title,
    required this.description,
    required this.onTap,
    required this.color,
  });

  @override
  State<_AnimatedOptionCard> createState() => _AnimatedOptionCardState();
}

class _AnimatedOptionCardState extends State<_AnimatedOptionCard>
    with SingleTickerProviderStateMixin {
  late AnimationController _controller;
  late Animation<double> _scaleAnimation;
  bool _isHovered = false;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      duration: const Duration(milliseconds: 300),
      vsync: this,
    );
    _scaleAnimation = Tween<double>(begin: 1.0, end: 1.05).animate(
      CurvedAnimation(parent: _controller, curve: Curves.easeInOut),
    );
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  void _onHover(bool hovering) {
    setState(() {
      _isHovered = hovering;
      if (hovering) {
        _controller.forward();
      } else {
        _controller.reverse();
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    return MouseRegion(
      onEnter: (_) => _onHover(true),
      onExit: (_) => _onHover(false),
      child: GestureDetector(
        onTap: widget.onTap,
        child: ScaleTransition(
          scale: _scaleAnimation,
          child: Card(
            elevation: _isHovered ? 12 : 4,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(16),
            ),
            child: Container(
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(16),
                gradient: LinearGradient(
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                  colors: _isHovered
                      ? [
                          widget.color.withValues(alpha: 0.15),
                          widget.color.withValues(alpha: 0.08),
                        ]
                      : [
                          Colors.white,
                          Colors.grey[50]!,
                        ],
                ),
              ),
              child: Padding(
                padding: const EdgeInsets.all(14),
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    AnimatedContainer(
                      duration: const Duration(milliseconds: 300),
                      padding: const EdgeInsets.all(10),
                      decoration: BoxDecoration(
                        color: _isHovered
                            ? widget.color.withValues(alpha: 0.25)
                            : widget.color.withValues(alpha: 0.12),
                        shape: BoxShape.circle,
                      ),
                      child: Icon(
                        widget.icon,
                        size: _isHovered ? 40 : 36,
                        color: widget.color,
                      ),
                    ),
                    const SizedBox(height: 10),
                    Text(
                      widget.title,
                      textAlign: TextAlign.center,
                      style: TextStyle(
                        fontSize: 14,
                        fontWeight: FontWeight.bold,
                        color: Colors.black87,
                        height: 1.1,
                      ),
                    ),
                    const SizedBox(height: 6),
                    Text(
                      widget.description,
                      textAlign: TextAlign.center,
                      style: TextStyle(
                        fontSize: 12,
                        color: Colors.grey[600],
                        height: 1.2,
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class AdminScreen extends StatefulWidget {
  const AdminScreen({super.key});

  @override
  State<AdminScreen> createState() => _AdminScreenState();
}

class _AdminScreenState extends State<AdminScreen> {
  String nombreUsuario = '';
  bool isLoading = true;

  final Color adminColor = const Color.fromARGB(255, 76, 94, 175);

  @override
  void initState() {
    super.initState();
    obtenerNombre();
  }

  Future<DocumentSnapshot<Map<String, dynamic>>?>
  _obtenerPerfilUsuario() async {
    final currentUser = FirebaseAuth.instance.currentUser;
    if (currentUser == null) return null;

    final doc = await FirebaseFirestore.instance
        .collection('usuarios')
        .doc(currentUser.uid)
        .get();

    if (doc.exists) return doc;

    final email = currentUser.email;
    if (email == null || email.isEmpty) return null;

    final query = await FirebaseFirestore.instance
        .collection('usuarios')
        .where('email', isEqualTo: email)
        .limit(1)
        .get();

    if (query.docs.isEmpty) return null;
    return query.docs.first;
  }

  Future<void> obtenerNombre() async {
    try {
      final doc = await _obtenerPerfilUsuario();
      if (!mounted) return;

      setState(() {
        nombreUsuario = doc?.data()?['nombre']?.toString() ?? 'Administrador';
        isLoading = false;
      });
    } catch (e) {
      debugPrint('Error obteniendo nombre: $e');
      if (!mounted) return;
      setState(() => isLoading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final isMobile = MediaQuery.of(context).size.width < 600;
    final screenWidth = MediaQuery.of(context).size.width;
    final gridColumns = isMobile ? 1 : (screenWidth > 1200 ? 4 : 2);

    return Scaffold(
      backgroundColor: const Color(0xFFF0F3F8),
      appBar: AppBar(
        elevation: 0,
        backgroundColor: Colors.transparent,
        foregroundColor: Colors.white,
        centerTitle: false,
        title: const Text(
          'Administrador',
          style: TextStyle(fontWeight: FontWeight.w700),
        ),
        flexibleSpace: Container(
          decoration: BoxDecoration(
            gradient: LinearGradient(
              colors: [
                adminColor,
                Color.lerp(adminColor, const Color(0xFF3A4FA8), 0.3)!,
              ],
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
            ),
          ),
        ),
      ),
      drawer: isLoading ? null : _buildAdminDrawer(context),
      body: isLoading
          ? Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  const CircularProgressIndicator(
                    valueColor:
                        AlwaysStoppedAnimation<Color>(Color.fromARGB(255, 76, 94, 175)),
                  ),
                  const SizedBox(height: 16),
                  Text(
                    'Cargando tu panel...',
                    style: TextStyle(
                      color: Colors.grey[600],
                      fontSize: 14,
                    ),
                  ),
                ],
              ),
            )
          : SingleChildScrollView(
              child: Padding(
                padding: EdgeInsets.all(isMobile ? 12 : 20),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // Sección de Bienvenida
                    Container(
                      padding: const EdgeInsets.all(20),
                      decoration: BoxDecoration(
                        gradient: LinearGradient(
                          colors: [
                            adminColor.withValues(alpha: 0.08),
                            adminColor.withValues(alpha: 0.03),
                          ],
                          begin: Alignment.topLeft,
                          end: Alignment.bottomRight,
                        ),
                        borderRadius: BorderRadius.circular(16),
                        border: Border.all(
                          color: adminColor.withValues(alpha: 0.1),
                        ),
                      ),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Row(
                            children: [
                              Container(
                                padding: const EdgeInsets.all(10),
                                decoration: BoxDecoration(
                                  color: adminColor.withValues(alpha: 0.2),
                                  borderRadius: BorderRadius.circular(10),
                                ),
                                child: Icon(
                                  Icons.favorite_rounded,
                                  color: adminColor,
                                  size: 20,
                                ),
                              ),
                              const SizedBox(width: 12),
                              Expanded(
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Text(
                                      'Listo para trabajar',
                                      style: TextStyle(
                                        fontSize: 16,
                                        fontWeight: FontWeight.bold,
                                        color: adminColor,
                                      ),
                                    ),
                                    const SizedBox(height: 4),
                                    Text(
                                      'Accede a todas las herramientas de gestión',
                                      style: TextStyle(
                                        fontSize: 12,
                                        color: Colors.grey[600],
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                            ],
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(height: 28),

                    // Sección de Opciones
                    Text(
                      'Gestiones Principales',
                      style: TextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.bold,
                        color: Colors.black87,
                      ),
                    ),
                    const SizedBox(height: 16),
                    GridView.count(
                      crossAxisCount: gridColumns,
                      shrinkWrap: true,
                      physics: const NeverScrollableScrollPhysics(),
                      mainAxisSpacing: 12,
                      crossAxisSpacing: 12,
                      childAspectRatio: isMobile ? 0.45 : 0.9,
                      children: [
                        _AnimatedOptionCard(
                          icon: Icons.people_alt_rounded,
                          title: 'Gestión de Usuarios',
                          description: 'Ver, editar y eliminar usuarios del sistema',
                          onTap: _abrirUsuarios,
                          color: const Color(0xFF5B7DFF),
                        ),
                        _AnimatedOptionCard(
                          icon: Icons.bar_chart_rounded,
                          title: 'Reportes de Equipo',
                          description: 'Faltantes y asignaciones de equipos',
                          onTap: _abrirReportes,
                          color: const Color(0xFF6AA3FF),
                        ),
                        _AnimatedOptionCard(
                          icon: Icons.emergency_share,
                          title: 'Incidentes en Ruta',
                          description: 'Tráfico, averías y retrasos en ruta',
                          onTap: _abrirIncidentes,
                          color: const Color(0xFF7BBFFF),
                        ),
                        _AnimatedOptionCard(
                          icon: Icons.settings_rounded,
                          title: 'Configuración',
                          description: 'Ajustes y preferencias del sistema',
                          onTap: () {
                            ScaffoldMessenger.of(context).showSnackBar(
                              SnackBar(
                                content: const Text('Configuración en desarrollo'),
                                backgroundColor: adminColor,
                                behavior: SnackBarBehavior.floating,
                              ),
                            );
                          },
                          color: const Color(0xFF8AC9FF),
                        ),
                      ],
                    ),
                    const SizedBox(height: 32),

                    // Sección de Estadísticas
                    Text(
                      'Estado del Sistema',
                      style: TextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.bold,
                        color: Colors.black87,
                      ),
                    ),
                    const SizedBox(height: 16),
                    _buildSystemStatsSection(),
                    const SizedBox(height: 32),

                    // Sección de Información Detallada
                    _buildDetailedInfoSection(),
                    const SizedBox(height: 20),
                  ],
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

  Future<void> _cerrarSesion() async {
    try {
      await FirebaseAuth.instance.signOut();
      if (!mounted) return;
      Navigator.of(context).pushAndRemoveUntil(
        MaterialPageRoute(builder: (_) => const LoginScreen()),
        (route) => false,
      );
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Error al cerrar sesión: $e')),
      );
    }
  }

  Stream<QuerySnapshot<Map<String, dynamic>>> _streamUsuariosActivos() {
    return FirebaseFirestore.instance
        .collection('usuarios')
        .where('jornada_activa', isEqualTo: true)
        .snapshots();
  }

  void _mostrarDetalleUsuariosActivos(
    List<QueryDocumentSnapshot<Map<String, dynamic>>> usuarios,
  ) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (context) {
        return Container(
          height: MediaQuery.of(context).size.height * 0.7,
          decoration: const BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
          ),
          child: Column(
            children: [
              const SizedBox(height: 12),
              Container(
                width: 52,
                height: 5,
                decoration: BoxDecoration(
                  color: Colors.grey[300],
                  borderRadius: BorderRadius.circular(10),
                ),
              ),
              const SizedBox(height: 16),
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 20),
                child: Row(
                  children: [
                    Container(
                      padding: const EdgeInsets.all(10),
                      decoration: BoxDecoration(
                        color: adminColor.withValues(alpha: 0.12),
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: Icon(Icons.people_alt_rounded, color: adminColor),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          const Text(
                            'Usuarios Activos',
                            style: TextStyle(
                              fontSize: 18,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                          Text(
                            '${usuarios.length} en línea',
                            style: TextStyle(
                              color: Colors.grey[600],
                              fontSize: 13,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 12),
              const Divider(height: 1),
              Expanded(
                child: usuarios.isEmpty
                    ? Center(
                        child: Column(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            Icon(
                              Icons.person_off_rounded,
                              size: 44,
                              color: Colors.grey[350],
                            ),
                            const SizedBox(height: 10),
                            Text(
                              'No hay usuarios activos en este momento',
                              style: TextStyle(color: Colors.grey[600]),
                            ),
                          ],
                        ),
                      )
                    : ListView.separated(
                        padding: const EdgeInsets.all(16),
                        itemCount: usuarios.length,
                        separatorBuilder: (_, index) =>
                          const SizedBox(height: 10),
                        itemBuilder: (context, index) {
                          final data = usuarios[index].data();
                          final nombre =
                              (data['nombre']?.toString().trim().isNotEmpty ??
                                  false)
                              ? data['nombre'].toString().trim()
                              : 'Sin nombre';
                          final rol = data['rol']?.toString() ?? 'usuario';
                          final camion = data['camion_actual']?.toString() ?? '';
                          final inicial = nombre.substring(0, 1).toUpperCase();

                          return Container(
                            padding: const EdgeInsets.all(14),
                            decoration: BoxDecoration(
                              gradient: LinearGradient(
                                colors: [
                                  adminColor.withValues(alpha: 0.09),
                                  adminColor.withValues(alpha: 0.03),
                                ],
                                begin: Alignment.topLeft,
                                end: Alignment.bottomRight,
                              ),
                              borderRadius: BorderRadius.circular(14),
                              border: Border.all(
                                color: adminColor.withValues(alpha: 0.14),
                              ),
                            ),
                            child: Row(
                              children: [
                                CircleAvatar(
                                  backgroundColor:
                                      adminColor.withValues(alpha: 0.18),
                                  child: Text(
                                    inicial,
                                    style: TextStyle(
                                      color: adminColor,
                                      fontWeight: FontWeight.bold,
                                    ),
                                  ),
                                ),
                                const SizedBox(width: 12),
                                Expanded(
                                  child: Column(
                                    crossAxisAlignment: CrossAxisAlignment.start,
                                    children: [
                                      Text(
                                        nombre,
                                        style: const TextStyle(
                                          fontWeight: FontWeight.bold,
                                          fontSize: 14,
                                        ),
                                      ),
                                      const SizedBox(height: 4),
                                      Text(
                                        rol,
                                        style: TextStyle(
                                          fontSize: 12,
                                          color: Colors.grey[700],
                                        ),
                                      ),
                                      if (camion.isNotEmpty)
                                        Padding(
                                          padding: const EdgeInsets.only(top: 6),
                                          child: Row(
                                            children: [
                                              Icon(
                                                Icons.local_shipping_rounded,
                                                size: 14,
                                                color: adminColor,
                                              ),
                                              const SizedBox(width: 6),
                                              Text(
                                                camion,
                                                style: TextStyle(
                                                  fontSize: 11,
                                                  color: adminColor,
                                                  fontWeight: FontWeight.w500,
                                                ),
                                              ),
                                            ],
                                          ),
                                        ),
                                    ],
                                  ),
                                ),
                                Container(
                                  padding: const EdgeInsets.symmetric(
                                    horizontal: 10,
                                    vertical: 6,
                                  ),
                                  decoration: BoxDecoration(
                                    color: const Color(0xFF4CAF50).withValues(
                                      alpha: 0.14,
                                    ),
                                    borderRadius: BorderRadius.circular(20),
                                  ),
                                  child: const Text(
                                    'En jornada',
                                    style: TextStyle(
                                      color: Color(0xFF2E7D32),
                                      fontSize: 12,
                                      fontWeight: FontWeight.bold,
                                    ),
                                  ),
                                ),
                              ],
                            ),
                          );
                        },
                      ),
              ),
            ],
          ),
        );
      },
    );
  }

  Widget _buildSystemStatsSection() {
    return StreamBuilder<QuerySnapshot<Map<String, dynamic>>>(
      stream: _streamUsuariosActivos(),
      builder: (context, snapshot) {
        final usuariosActivos = snapshot.data?.docs ?? [];
        final cantidadActivos = usuariosActivos.length;

        return LayoutBuilder(
          builder: (context, constraints) {
            final columnas = constraints.maxWidth < 700 ? 1 : 3;

            return GridView.count(
              crossAxisCount: columnas,
              shrinkWrap: true,
              physics: const NeverScrollableScrollPhysics(),
              mainAxisSpacing: 14,
              crossAxisSpacing: 14,
              childAspectRatio: columnas == 1 ? 1.8 : 1.5,
              children: [
                _buildStatCard(
                  icon: Icons.people_outline_rounded,
                  label: 'Usuarios Activos',
                  value: snapshot.connectionState == ConnectionState.waiting
                      ? '...'
                      : cantidadActivos.toString(),
                  color: const Color(0xFF5B7DFF),
                  backgroundGradient: [
                    const Color(0xFF5B7DFF).withValues(alpha: 0.1),
                    const Color(0xFF5B7DFF).withValues(alpha: 0.02),
                  ],
                  onTap: () => _mostrarDetalleUsuariosActivos(usuariosActivos),
                ),
                _buildStatCard(
                  icon: Icons.assignment_rounded,
                  label: 'Reportes',
                  value: '8',
                  color: const Color(0xFF6AA3FF),
                  backgroundGradient: [
                    const Color(0xFF6AA3FF).withValues(alpha: 0.1),
                    const Color(0xFF6AA3FF).withValues(alpha: 0.02),
                  ],
                ),
                _buildStatCard(
                  icon: Icons.warning_rounded,
                  label: 'Incidentes',
                  value: '3',
                  color: const Color(0xFFFFA726),
                  backgroundGradient: [
                    const Color(0xFFFFA726).withValues(alpha: 0.1),
                    const Color(0xFFFFA726).withValues(alpha: 0.02),
                  ],
                ),
              ],
            );
          },
        );
      },
    );
  }

  Widget _buildStatCard({
    required IconData icon,
    required String label,
    required String value,
    required Color color,
    required List<Color> backgroundGradient,
    VoidCallback? onTap,
  }) {
    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(12),
        child: Container(
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            gradient: LinearGradient(
              colors: backgroundGradient,
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
            ),
            borderRadius: BorderRadius.circular(12),
            border: Border.all(
              color: color.withValues(alpha: 0.2),
            ),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisSize: MainAxisSize.min,
            children: [
              Row(
                children: [
                  Container(
                    padding: const EdgeInsets.all(8),
                    decoration: BoxDecoration(
                      color: color.withValues(alpha: 0.15),
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: Icon(
                      icon,
                      color: color,
                      size: 20,
                    ),
                  ),
                  const Spacer(),
                  if (onTap != null)
                    Icon(
                      Icons.open_in_new_rounded,
                      size: 16,
                      color: color.withValues(alpha: 0.8),
                    ),
                ],
              ),
              const SizedBox(height: 12),
              Text(
                value,
                style: TextStyle(
                  fontSize: 24,
                  fontWeight: FontWeight.bold,
                  color: color,
                ),
              ),
              const SizedBox(height: 4),
              Text(
                label,
                style: TextStyle(
                  fontSize: 12,
                  color: Colors.grey[600],
                  fontWeight: FontWeight.w500,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildDetailedInfoSection() {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: [
            adminColor.withValues(alpha: 0.08),
            adminColor.withValues(alpha: 0.02),
          ],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: adminColor.withValues(alpha: 0.15),
        ),
        boxShadow: [
          BoxShadow(
            color: adminColor.withValues(alpha: 0.08),
            blurRadius: 12,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                padding: const EdgeInsets.all(10),
                decoration: BoxDecoration(
                  color: adminColor.withValues(alpha: 0.2),
                  borderRadius: BorderRadius.circular(10),
                ),
                child: Icon(
                  Icons.info_rounded,
                  color: adminColor,
                  size: 20,
                ),
              ),
              const SizedBox(width: 12),
              const Expanded(
                child: Text(
                  'Información del Sistema',
                  style: TextStyle(
                    fontWeight: FontWeight.bold,
                    fontSize: 16,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 20),
          _buildInfoRow('Versión', 'v1.0.0'),
          const SizedBox(height: 12),
          _buildInfoRow('Plataforma', 'Flutter'),
          const SizedBox(height: 12),
          _buildInfoRow('Estado', 'En línea', valueColor: Colors.green),
          const SizedBox(height: 12),
          _buildInfoRow('Última Actualización', 'Hoy a las ${TimeOfDay.now().format(context)}'),
        ],
      ),
    );
  }

  Widget _buildInfoRow(String label, String value, {Color? valueColor}) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Text(
          label,
          style: TextStyle(
            color: Colors.grey[600],
            fontSize: 13,
          ),
        ),
        Text(
          value,
          style: TextStyle(
            fontWeight: FontWeight.bold,
            fontSize: 13,
            color: valueColor,
          ),
        ),
      ],
    );
  }

  Widget _buildAdminDrawer(BuildContext context) {
    return Drawer(
      child: Column(
        children: [
          DrawerHeader(
            margin: EdgeInsets.zero,
            padding: EdgeInsets.zero,
            child: Container(
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  colors: [
                    adminColor,
                    Color.lerp(adminColor, const Color(0xFF2D3E7F), 0.5)!,
                  ],
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
                      'Menú',
                      style: TextStyle(
                        color: Colors.white,
                        fontSize: 18,
                        fontWeight: FontWeight.w800,
                      ),
                    ),
                    const SizedBox(height: 6),
                    Text(
                      isLoading ? 'Administrador' : nombreUsuario,
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
            leading: const Icon(Icons.logout_rounded, color: Color.fromARGB(255, 76, 94, 175)),
            title: const Text(
              'Cerrar sesión',
              style: TextStyle(fontWeight: FontWeight.w700),
            ),
            subtitle: const Text('Volver a la pantalla de inicio'),
            onTap: () async {
              Navigator.of(context).pop();
              await _cerrarSesion();
            },
          ),
          const Spacer(),
          const Padding(
            padding: EdgeInsets.all(16),
            child: Text(
              'Recicladora',
              style: TextStyle(color: Color(0xFF94A3B8)),
            ),
          ),
        ],
      ),
    );
  }
}
