import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:firebase_messaging/firebase_messaging.dart';

import '../config/session_manager.dart';
import 'admin_notificaciones_screen.dart';
import 'login_screen.dart';
import 'mapa_general_operadores_screen.dart';
import 'panel_general_usuarios_screen.dart';
import 'usuarios_screen.dart';
import 'widgets/lista_incidentes_admin.dart';
import 'widgets/reporte_gasolina_camiones_screen.dart';
import 'widgets/notificaciones_drawer.dart';
import 'widgets/reportes_equipo_screen.dart';
import 'widgets/reporte_toneladas_camiones_screen.dart';
 
import 'gestion_camiones_screen.dart';
import 'ReportesCamionesAdminScreen.dart';

// ─────────────────────────────────────────────────────────────────────────────
// Card animada de opciones
// ─────────────────────────────────────────────────────────────────────────────
class _AnimatedOptionCard extends StatefulWidget {
  final IconData icon;
  final String title;
  final String description;
  final VoidCallback onTap;
  final Color color;
  final bool compact;

  const _AnimatedOptionCard({
    required this.icon,
    required this.title,
    required this.description,
    required this.onTap,
    required this.color,
    this.compact = false,
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
      hovering ? _controller.forward() : _controller.reverse();
    });
  }

  @override
  Widget build(BuildContext context) {
    final iconBaseSize = widget.compact ? 21.0 : 42.0;
    final iconHoverSize = widget.compact ? 24.0 : 50.0;
    final titleFontSize = widget.compact ? 11.5 : 15.0;
    final descriptionFontSize = widget.compact ? 10.0 : 13.0;

    return MouseRegion(
      onEnter: (_) => _onHover(true),
      onExit: (_) => _onHover(false),
      child: GestureDetector(
        onTap: widget.onTap,
        child: ScaleTransition(
          scale: _scaleAnimation,
          child: Card(
            elevation: 0,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(20),
            ),
            child: Container(
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(20),
                gradient: LinearGradient(
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                  colors: _isHovered
                      ? [
                          widget.color.withValues(alpha: 0.16),
                          widget.color.withValues(alpha: 0.06),
                        ]
                      : [Colors.white, const Color(0xFFF9FAFB)],
                ),
                border: Border.all(
                  color: _isHovered
                      ? widget.color.withValues(alpha: 0.25)
                      : widget.color.withValues(alpha: 0.12),
                  width: 1.5,
                ),
                boxShadow: [
                  BoxShadow(
                    color: widget.color.withValues(
                      alpha: _isHovered ? 0.16 : 0.06,
                    ),
                    blurRadius: _isHovered ? 28 : 16,
                    offset: Offset(0, _isHovered ? 16 : 8),
                    spreadRadius: _isHovered ? 2 : 0,
                  ),
                ],
              ),
              child: Padding(
                padding: EdgeInsets.all(widget.compact ? 6 : 14),
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    AnimatedContainer(
                      duration: const Duration(milliseconds: 300),
                      padding: EdgeInsets.all(widget.compact ? 5 : 10),
                      decoration: BoxDecoration(
                        color: _isHovered
                            ? widget.color.withValues(alpha: 0.25)
                            : widget.color.withValues(alpha: 0.12),
                        shape: BoxShape.circle,
                      ),
                      child: Icon(
                        widget.icon,
                        size: _isHovered ? iconHoverSize : iconBaseSize,
                        color: widget.color,
                      ),
                    ),
                    SizedBox(height: widget.compact ? 4 : 10),
                    Text(
                      widget.title,
                      textAlign: TextAlign.center,
                      style: TextStyle(
                        fontSize: titleFontSize,
                        fontWeight: FontWeight.bold,
                        color: const Color(0xFF0F2B66),
                        height: 1.2,
                      ),
                      maxLines: widget.compact ? 1 : 2,
                      overflow: TextOverflow.ellipsis,
                    ),
                    SizedBox(height: widget.compact ? 2 : 6),
                    Text(
                      widget.description,
                      textAlign: TextAlign.center,
                      style: TextStyle(
                        fontSize: descriptionFontSize,
                        color: const Color(0xFF5A6B8C),
                        height: 1.2,
                      ),
                      maxLines: widget.compact ? 1 : 2,
                      overflow: TextOverflow.ellipsis,
                    ),
                    if (!widget.compact) ...[
                      const SizedBox(height: 8),
                      Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 10,
                          vertical: 6,
                        ),
                        decoration: BoxDecoration(
                          color: widget.color.withValues(alpha: 0.12),
                          borderRadius: BorderRadius.circular(30),
                          border: Border.all(
                            color: widget.color.withValues(alpha: 0.2),
                          ),
                        ),
                        child: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Text(
                              'Abrir',
                              style: TextStyle(
                                color: widget.color,
                                fontSize: 11.5,
                                fontWeight: FontWeight.w700,
                              ),
                            ),
                            const SizedBox(width: 4),
                            Icon(
                              Icons.arrow_forward_rounded,
                              size: 14,
                              color: widget.color,
                            ),
                          ],
                        ),
                      ),
                    ],
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

// ─────────────────────────────────────────────────────────────────────────────
// AdminScreen
// ─────────────────────────────────────────────────────────────────────────────
class AdminScreen extends StatefulWidget {
  const AdminScreen({super.key});

  @override
  State<AdminScreen> createState() => _AdminScreenState();
}

class _AdminScreenState extends State<AdminScreen>
    with TickerProviderStateMixin {          // ← TickerProviderStateMixin para múltiples controllers
  String nombreUsuario = '';
  bool isLoading = true;
  bool _avisoPrecaucionMostrado = false;
  int _bottomNavIndex = 0;

  // ── Submenú Camiones ──────────────────────────────────────────────────────
  bool _camionesExpanded = false;
  late AnimationController _drawerAnimCtrl;
  late Animation<double> _drawerRotateAnim;

  // ── Colores ───────────────────────────────────────────────────────────────
  final Color primaryColor = const Color(0xFF0f172a);
  final Color accentColor  = const Color(0xFF06b6d4);
  final Color successColor = const Color(0xFF10b981);
  final Color warningColor = const Color(0xFFf59e0b);
  final Color bgColor      = const Color(0xFFF0F9FF);

  final FlutterLocalNotificationsPlugin _notificaciones =
      FlutterLocalNotificationsPlugin();

  @override
  void initState() {
    super.initState();

    // Animación de la flecha del submenú
    _drawerAnimCtrl = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 220),
    );
    _drawerRotateAnim = Tween<double>(begin: 0, end: 0.5).animate(
      CurvedAnimation(parent: _drawerAnimCtrl, curve: Curves.easeInOut),
    );

    obtenerNombre();
    _inicializarAvisoPrecauciones();
  }

  @override
  void dispose() {
    _drawerAnimCtrl.dispose();
    super.dispose();
  }

  // ── Helpers submenú ───────────────────────────────────────────────────────
  void _toggleCamiones() {
    setState(() => _camionesExpanded = !_camionesExpanded);
    _camionesExpanded ? _drawerAnimCtrl.forward() : _drawerAnimCtrl.reverse();
  }

  Future<void> obtenerNombre() async {
    try {
      final user = FirebaseAuth.instance.currentUser;
      if (user == null) {
        if (!mounted) return;
        setState(() {
          nombreUsuario = 'Administrador';
          isLoading = false;
        });
        return;
      }

      final doc = await FirebaseFirestore.instance
          .collection('usuarios')
          .doc(user.uid)
          .get();
      final data = doc.data();
      if (!mounted) return;

      setState(() {
        nombreUsuario =
            data?['nombre']?.toString().trim().isNotEmpty == true
                ? data!['nombre'].toString().trim()
                : user.displayName?.trim().isNotEmpty == true
                    ? user.displayName!.trim()
                    : 'Administrador';
        isLoading = false;
      });
    } catch (_) {
      if (!mounted) return;
      setState(() {
        nombreUsuario = 'Administrador';
        isLoading = false;
      });
    }
  }

  Future<void> _recargarPanelAdmin() async {
    await obtenerNombre();
  }

  Future<void> _cerrarSesion() async {
    try {
      await SessionManager.limpiarSesionRemota();
      await FirebaseAuth.instance.signOut();
      await SessionManager.limpiarSesion();
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

  Future<void> _confirmarYCerrarSesion() async {
    final confirmar =
            await showDialog<bool>(
              context: context,
              builder: (_) => AlertDialog(
                title: const Text('Cerrar sesión'),
                content: const Text('¿Estás seguro de salir de la sesión?'),
                actions: [
                  TextButton(
                    onPressed: () => Navigator.of(context).pop(false),
                    child: const Text('Cancelar'),
                  ),
                  ElevatedButton(
                    onPressed: () => Navigator.of(context).pop(true),
                    child: const Text('Sí, salir'),
                  ),
                ],
              ),
            ) ??
        false;
    if (!confirmar) return;
    await _cerrarSesion();
  }

  void _abrirUsuarios() => Navigator.push(
        context,
        MaterialPageRoute(builder: (_) => const UsuariosScreen()),
      );

  void _abrirReportes() => Navigator.push(
        context,
        MaterialPageRoute(builder: (_) => const ReportesEquipoScreen()),
      );

  void _abrirIncidentes() => Navigator.push(
        context,
        MaterialPageRoute(builder: (_) => const ListaIncidentesAdmin()),
      );

  void _abrirReporteGasolina() => Navigator.push(
        context,
        MaterialPageRoute(
          builder: (_) => const ReporteGasolinaCamionesScreen(),
        ),
      );

  void _abrirReporteToneladas() => Navigator.push(
        context,
        MaterialPageRoute(
          builder: (_) => const ReporteToneladasAdminScreen(),
        ),
      );

  void _abrirReportesCamiones() => Navigator.push(
        context,
        MaterialPageRoute(
          builder: (_) => const ReportesCamionesAdminScreen(),
        ),
      );

  void _abrirPanelGeneralUsuarios() => Navigator.push(
        context,
        MaterialPageRoute(builder: (_) => const PanelGeneralUsuariosScreen()),
      );

  void _abrirMapaGeneralOperadores() => Navigator.push(
        context,
        MaterialPageRoute(builder: (_) => const MapaGeneralOperadoresScreen()),
      );

  void _abrirNotificacionesAdmin() => Navigator.push(
        context,
        MaterialPageRoute(
          builder: (_) => AdminNotificacionesScreen(adminNombre: nombreUsuario),
        ),
      );

  // ── Precauciones ──────────────────────────────────────────────────────────
  Future<void> _inicializarAvisoPrecauciones() async {
    if (_avisoPrecaucionMostrado) return;
    _avisoPrecaucionMostrado = true;
    await _mostrarNotificacionPrecauciones();
    if (!mounted) return;
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      _mostrarDialogoPrecaucionesTrabajo();
    });
  }

  Future<void> _mostrarNotificacionPrecauciones() async {
    try {
      const androidInit = AndroidInitializationSettings('@mipmap/ic_launcher');
      const iosInit = DarwinInitializationSettings(
        requestAlertPermission: false,
        requestBadgePermission: false,
        requestSoundPermission: false,
      );
      await _notificaciones.initialize(
        const InitializationSettings(android: androidInit, iOS: iosInit),
      );
      final androidImpl = _notificaciones
          .resolvePlatformSpecificImplementation<
              AndroidFlutterLocalNotificationsPlugin>();
      await androidImpl?.requestNotificationsPermission();
      final iosImpl = _notificaciones
          .resolvePlatformSpecificImplementation<
              IOSFlutterLocalNotificationsPlugin>();
      await iosImpl?.requestPermissions(
        alert: true,
        badge: true,
        sound: true,
      );

      const details = NotificationDetails(
        android: AndroidNotificationDetails(
          'precauciones_admin',
          'Precauciones de administración',
          channelDescription: 'Avisos preventivos para administración',
          importance: Importance.max,
          priority: Priority.high,
        ),
        iOS: DarwinNotificationDetails(),
      );

      await _notificaciones.show(
        1,
        'Precauciones de seguridad',
        'Revisa los procedimientos antes de comenzar tus tareas.',
        details,
      );
    } catch (_) {
      // Aviso informativo: no bloquea la pantalla si falla.
    }
  }

  Future<void> _mostrarDialogoPrecaucionesTrabajo() async {
    if (!mounted) return;
    await showDialog<void>(
      context: context,
      barrierDismissible: false,
      builder: (context) => AlertDialog(
        title: const Row(
          children: [
            Icon(Icons.health_and_safety_rounded, color: Color(0xFF0B1F3A)),
            SizedBox(width: 8),
            Expanded(child: Text('Precauciones de trabajo')),
          ],
        ),
        content: const SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              _RecomendacionItemAdmin(
                icon: Icons.back_hand_outlined,
                texto: 'Usa guantes resistentes para manipular vidrio.',
              ),
              SizedBox(height: 8),
              _RecomendacionItemAdmin(
                icon: Icons.visibility_outlined,
                texto: 'Porta lentes de seguridad para evitar lesiones.',
              ),
              SizedBox(height: 8),
              _RecomendacionItemAdmin(
                icon: Icons.hiking_outlined,
                texto: 'Utiliza cubrebocas en todo momento.',
              ),
              SizedBox(height: 8),
              _RecomendacionItemAdmin(
                icon: Icons.construction_outlined,
                texto: 'Usa el uniforme para mayor seguridad.',
              ),
              SizedBox(height: 8),
              _RecomendacionItemAdmin(
                icon: Icons.clean_hands_outlined,
                texto: 'Revisa tu equipo antes de iniciar y reporta daños.',
              ),
            ],
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(),
            child: const Text('Entendido'),
          ),
        ],
      ),
    );
  }

  // ── Drawer ────────────────────────────────────────────────────────────────
  Widget _buildAdminDrawer(BuildContext context) {
    return Drawer(
      child: Column(
        children: [
          // Encabezado
          DrawerHeader(
            margin: EdgeInsets.zero,
            padding: EdgeInsets.zero,
            child: Container(
              width: double.infinity,
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  colors: [primaryColor, const Color(0xFF1e293b)],
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                ),
                boxShadow: [
                  BoxShadow(
                    color: primaryColor.withValues(alpha: 0.4),
                    blurRadius: 16,
                    offset: const Offset(0, 8),
                  ),
                ],
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
                        fontSize: 20,
                        fontWeight: FontWeight.w800,
                        letterSpacing: -0.5,
                      ),
                    ),
                    const SizedBox(height: 8),
                    Text(
                      isLoading ? 'Administrador' : nombreUsuario,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(
                        color: Colors.white70,
                        fontSize: 14,
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),

          // ── Gestión de Usuarios ──────────────────────────────────────────
          ListTile(
            leading: Icon(Icons.people_alt_rounded, color: accentColor),
            title: const Text(
              'Gestión de Usuarios',
              style: TextStyle(fontWeight: FontWeight.w700),
            ),
            onTap: () {
              Navigator.pop(context);
              _abrirUsuarios();
            },
          ),

          const Divider(height: 1),

          // ── CAMIONES (expandible) ────────────────────────────────────────
          InkWell(
            onTap: _toggleCamiones,
            child: Padding(
              padding:
                  const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
              child: Row(
                children: [
                  Icon(Icons.local_shipping_rounded, color: accentColor),
                  const SizedBox(width: 16),
                  const Expanded(
                    child: Text(
                      'Camiones',
                      style: TextStyle(
                          fontWeight: FontWeight.w700, fontSize: 15),
                    ),
                  ),
                  RotationTransition(
                    turns: _drawerRotateAnim,
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
                color: accentColor.withValues(alpha: 0.05),
                border: Border(
                  left: BorderSide(
                      color: accentColor.withValues(alpha: 0.4), width: 3),
                ),
              ),
              margin: const EdgeInsets.only(left: 24, right: 8, bottom: 4),
              child: Column(
                children: [
                  // → Gestión de Camiones
                  ListTile(
                    dense: true,
                    leading: Icon(Icons.settings_rounded,
                        color: accentColor, size: 20),
                    title: const Text(
                      'Gestión de Camiones',
                      style: TextStyle(fontWeight: FontWeight.w600),
                    ),
                    subtitle: const Text('Administrar flota',
                        style: TextStyle(fontSize: 11)),
                    onTap: () {
                      Navigator.pop(context);
                      Navigator.push(
                        context,
                        MaterialPageRoute(
                            builder: (_) => const GestionCamionesScreen()),
                      );
                    },
                  ),
                  // → Reportes de Camiones
                  ListTile(
                    dense: true,
                    leading: const Icon(Icons.warning_amber_rounded,
                        color: Color(0xFFF59E0B), size: 20),
                    title: const Text(
                      'Reportes de Camiones',
                      style: TextStyle(fontWeight: FontWeight.w600),
                    ),
                    subtitle: const Text('Incidentes y averías',
                        style: TextStyle(fontSize: 11)),
                    onTap: () {
                      Navigator.pop(context);
                      Navigator.push(
                        context,
                        MaterialPageRoute(
                            builder: (_) =>
                                const ReportesCamionesAdminScreen()),
                      );
                    },
                  ),
                ],
              ),
            ),
          ),

          const Divider(height: 1),

          // ── Cerrar Sesión ────────────────────────────────────────────────
          ListTile(
            leading: Icon(Icons.logout_rounded, color: accentColor),
            title: const Text(
              'Cerrar sesión',
              style: TextStyle(fontWeight: FontWeight.w700),
            ),
            subtitle: const Text('Volver a la pantalla de inicio'),
            onTap: () async {
              Navigator.of(context).pop();
              await _confirmarYCerrarSesion();
            },
          ),

          const Spacer(),
          const Padding(
            padding: EdgeInsets.all(16),
            child: Text(
              'Recicladora v1.0',
              style: TextStyle(color: Color(0xFF94A3B8)),
            ),
          ),
        ],
      ),
    );
  }

  // ── Build ─────────────────────────────────────────────────────────────────
  @override
  int get _contentIndex => _bottomNavIndex;

  Widget build(BuildContext context) {
    final isMobile = MediaQuery.of(context).size.width < 600;

    return Scaffold(
      backgroundColor: bgColor,
      appBar: AppBar(
        elevation: 0,
        backgroundColor: Colors.transparent,
        foregroundColor: Colors.white,
        centerTitle: false,
        title: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Text(
              'Administrador',
              style: TextStyle(fontWeight: FontWeight.w700),
            ),
            const SizedBox(width: 10),
            ClipRRect(
              borderRadius: BorderRadius.circular(10),
              child: Image.asset(
                'assets/logo circular.jpeg',
                height: 38,
                width: 38,
                fit: BoxFit.cover,
              ),
            ),
          ],
        ),
        flexibleSpace: Container(
          decoration: BoxDecoration(
            gradient: LinearGradient(
              colors: [primaryColor, const Color(0xFF1e293b)],
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
            ),
            boxShadow: [
              BoxShadow(
                color: primaryColor.withValues(alpha: 0.3),
                blurRadius: 20,
                offset: const Offset(0, 8),
              ),
            ],
          ),
        ),
        actions: [
          Builder(
            builder: (context) => NotificacionesBellButton(
              rolUsuario: 'admin',
              nombreUsuario: nombreUsuario,
              onPressed: () => Scaffold.of(context).openEndDrawer(),
            ),
          ),
        ],
      ),
      drawer: isLoading ? null : _buildAdminDrawer(context),
      endDrawer: NotificacionesDrawer(
        rolUsuario: 'admin',
        nombreUsuario: nombreUsuario,
      ),
      body: isLoading
          ? Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  CircularProgressIndicator(
                    valueColor: AlwaysStoppedAnimation<Color>(accentColor),
                    strokeWidth: 3,
                  ),
                  const SizedBox(height: 16),
                  Text(
                    'Cargando tu panel...',
                    style: TextStyle(color: Colors.grey[600], fontSize: 14),
                  ),
                ],
              ),
            )
          : IndexedStack(
              index: _contentIndex,
              children: [
                _buildInicioTab(isMobile),
                _buildUsuariosTab(isMobile),
                _buildReportesTab(isMobile),
                _buildAjustesTab(isMobile),
              ],
            ),
      bottomNavigationBar: isLoading ? null : _buildBottomNavigationBar(),
    );
  }

  Widget _buildInicioTab(bool isMobile) {
    return RefreshIndicator(
      onRefresh: _recargarPanelAdmin,
      child: ListView(
        physics: const AlwaysScrollableScrollPhysics(),
        padding: EdgeInsets.fromLTRB(isMobile ? 12 : 20, 16, isMobile ? 12 : 20, 24),
        children: [
          _buildWelcomeBanner(),
          const SizedBox(height: 16),
          _sectionHeader('Acceso Rápido'),
          const SizedBox(height: 16),
          GridView.count(
            crossAxisCount: isMobile ? 2 : 3,
            shrinkWrap: true,
            physics: const NeverScrollableScrollPhysics(),
            mainAxisSpacing: 12,
            crossAxisSpacing: 12,
            childAspectRatio: isMobile ? 0.92 : 1.0,
            children: [
              _dashboardShortcutCard(
                title: 'Panel General\nde Usuarios',
                subtitle: 'Ver y administrar usuarios',
                icon: Icons.groups_2_rounded,
                colors: const [Color(0xFF0F172A), Color(0xFF1E3A8A)],
                accent: const Color(0xFF3B82F6),
                onTap: _abrirPanelGeneralUsuarios,
                compact: true,
              ),
              _dashboardShortcutCard(
                title: 'Mapa General\nde Operadores',
                subtitle: 'Ubicación y estado en tiempo real',
                icon: Icons.map_rounded,
                colors: const [Color(0xFF0F766E), Color(0xFF10B981)],
                accent: const Color(0xFF14B8A6),
                onTap: _abrirMapaGeneralOperadores,
                compact: true,
              ),
              _dashboardShortcutCard(
                title: 'Enviar\nNotificaciones',
                subtitle: 'Alertas rápidas y efectivas',
                icon: Icons.notifications_active_rounded,
                colors: const [Color(0xFFF59E0B), Color(0xFFFB923C)],
                accent: const Color(0xFFF97316),
                onTap: _abrirNotificacionesAdmin,
                compact: true,
              ),
            ],
          ),
          const SizedBox(height: 24),
          _sectionHeader('Estado del Sistema'),
          const SizedBox(height: 16),
          _buildSystemStatsSection(),
        ],
      ),
    );
  }

  Widget _buildUsuariosTab(bool isMobile) {
    return RefreshIndicator(
      onRefresh: _recargarPanelAdmin,
      child: Column(
        children: [
          Padding(
            padding: EdgeInsets.fromLTRB(isMobile ? 12 : 20, 16, isMobile ? 12 : 20, 12),
            child: Align(
              alignment: Alignment.centerLeft,
              child: _sectionHeader('Usuarios'),
            ),
          ),
          Expanded(
            child: Padding(
              padding: EdgeInsets.fromLTRB(isMobile ? 12 : 20, 0, isMobile ? 12 : 20, 12),
              child: _buildUsuariosPanelEmbed(),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildReportesTab(bool isMobile) {
    return RefreshIndicator(
      onRefresh: _recargarPanelAdmin,
      child: ListView(
        physics: const AlwaysScrollableScrollPhysics(),
        padding: EdgeInsets.fromLTRB(isMobile ? 12 : 20, 16, isMobile ? 12 : 20, 24),
        children: [
          _sectionHeader('Reportes'),
          const SizedBox(height: 16),
          _buildReportOverviewCard(),
          const SizedBox(height: 16),
          GridView.count(
            crossAxisCount: isMobile ? 2 : 3,
            shrinkWrap: true,
            physics: const NeverScrollableScrollPhysics(),
            mainAxisSpacing: 12,
            crossAxisSpacing: 12,
            childAspectRatio: isMobile ? 0.82 : 1.0,
            children: [
              _dashboardShortcutCard(
                title: 'Reportes\nde Equipo',
                subtitle: 'Faltantes y asignaciones',
                icon: Icons.bar_chart_rounded,
                colors: const [Color(0xFFF59E0B), Color(0xFFFB923C)],
                accent: const Color(0xFFF97316),
                onTap: _abrirReportes,
                compact: true,
              ),
              _dashboardShortcutCard(
                title: 'Reportes\nde Operadores',
                subtitle: 'Incidentes y ruta',
                icon: Icons.emergency_share_rounded,
                colors: const [Color(0xFF2E1065), Color(0xFF7C3AED)],
                accent: const Color(0xFFA855F7),
                onTap: _abrirIncidentes,
                compact: true,
              ),
              _dashboardShortcutCard(
                title: 'Reporte de\nGasolina',
                subtitle: 'Cargas y descarga',
                icon: Icons.local_gas_station_rounded,
                colors: const [Color(0xFF0F766E), Color(0xFF14B8A6)],
                accent: const Color(0xFF14B8A6),
                onTap: _abrirReporteGasolina,
                compact: true,
              ),
              _dashboardShortcutCard(
                title: 'Reporte de\nToneladas',
                subtitle: 'Peso de entradas y salidas',
                icon: Icons.scale_rounded,
                colors: const [Color(0xFF1D4ED8), Color(0xFF60A5FA)],
                accent: const Color(0xFF3B82F6),
                onTap: _abrirReporteToneladas,
                compact: true,
              ),
              _dashboardShortcutCard(
                title: 'Reportes de\nCamiones',
                subtitle: 'Incidentes de unidades',
                icon: Icons.local_shipping_rounded,
                colors: const [Color(0xFF0A0A0A), Color(0xFF7F1D1D)],
                accent: const Color(0xFFDC2626),
                onTap: _abrirReportesCamiones,
                compact: true,
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildAjustesTab(bool isMobile) {
    return RefreshIndicator(
      onRefresh: _recargarPanelAdmin,
      child: ListView(
        physics: const AlwaysScrollableScrollPhysics(),
        padding: EdgeInsets.fromLTRB(isMobile ? 12 : 20, 16, isMobile ? 12 : 20, 24),
        children: [
          _sectionHeader('Ajustes'),
          const SizedBox(height: 16),
          _buildDetailedInfoSection(),
        ],
      ),
    );
  }

  Widget _buildBottomNavigationBar() {
    return Container(
      decoration: const BoxDecoration(
        color: Colors.white,
        boxShadow: [
          BoxShadow(
            color: Color(0x14000000),
            blurRadius: 18,
            offset: Offset(0, -4),
          ),
        ],
      ),
      child: NavigationBar(
        selectedIndex: _bottomNavIndex,
        onDestinationSelected: (index) {
          setState(() => _bottomNavIndex = index);
        },
        backgroundColor: Colors.white,
        surfaceTintColor: Colors.transparent,
        indicatorColor: const Color(0xFFDBEAFE),
        labelBehavior: NavigationDestinationLabelBehavior.alwaysShow,
        height: 72,
        destinations: const [
          NavigationDestination(
            icon: Icon(Icons.home_outlined),
            selectedIcon: Icon(Icons.home_rounded),
            label: 'Inicio',
          ),
          NavigationDestination(
            icon: Icon(Icons.people_outline_rounded),
            selectedIcon: Icon(Icons.people_rounded),
            label: 'Usuarios',
          ),
          NavigationDestination(
            icon: Icon(Icons.analytics_outlined),
            selectedIcon: Icon(Icons.analytics_rounded),
            label: 'Reportes',
          ),
          NavigationDestination(
            icon: Icon(Icons.settings_outlined),
            selectedIcon: Icon(Icons.settings_rounded),
            label: 'Ajustes',
          ),
        ],
      ),
    );
  }

  Widget _buildUsuariosPanelEmbed() {
    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(22),
        boxShadow: [
          BoxShadow(
            color: const Color(0xFF0F172A).withValues(alpha: 0.08),
            blurRadius: 18,
            offset: const Offset(0, 8),
          ),
        ],
      ),
      clipBehavior: Clip.antiAlias,
      child: const SizedBox.expand(
        child: UsuariosScreen(),
      ),
    );
  }

  Widget _buildWelcomeBanner() {
    return TweenAnimationBuilder<double>(
      tween: Tween(begin: 0, end: 1),
      duration: const Duration(milliseconds: 800),
      builder: (context, value, child) => Transform.translate(
        offset: Offset(0, 24 * (1 - value)),
        child: Opacity(opacity: value, child: child),
      ),
      child: Container(
        padding: const EdgeInsets.all(20),
        decoration: BoxDecoration(
          gradient: LinearGradient(
            colors: [
              primaryColor.withValues(alpha: 0.98),
              const Color(0xFF2563EB),
            ],
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
          ),
          borderRadius: BorderRadius.circular(22),
          boxShadow: [
            BoxShadow(
              color: primaryColor.withValues(alpha: 0.22),
              blurRadius: 24,
              offset: const Offset(0, 12),
            ),
          ],
        ),
        child: Row(
          children: [
            Container(
              padding: const EdgeInsets.all(14),
              decoration: BoxDecoration(
                color: Colors.white.withValues(alpha: 0.16),
                borderRadius: BorderRadius.circular(16),
              ),
              child: const Icon(
                Icons.workspace_premium_rounded,
                color: Colors.white,
                size: 26,
              ),
            ),
            const SizedBox(width: 16),
            const Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Todo listo para gestionar',
                    style: TextStyle(
                      color: Colors.white,
                      fontSize: 17,
                      fontWeight: FontWeight.w800,
                    ),
                  ),
                  SizedBox(height: 6),
                  Text(
                    'Accede rápidamente a todas las herramientas de gestión y monitoreo.',
                    style: TextStyle(
                      color: Colors.white70,
                      fontSize: 13,
                      height: 1.3,
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _dashboardShortcutCard({
    required String title,
    required String subtitle,
    required IconData icon,
    required List<Color> colors,
    required Color accent,
    required VoidCallback onTap,
    bool compact = false,
  }) {
    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(24),
        child: Container(
          padding: EdgeInsets.all(compact ? 14 : 18),
          decoration: BoxDecoration(
            gradient: LinearGradient(
              colors: colors,
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
            ),
            borderRadius: BorderRadius.circular(24),
            boxShadow: [
              BoxShadow(
                color: colors.last.withValues(alpha: 0.24),
                blurRadius: 22,
                offset: const Offset(0, 12),
              ),
            ],
          ),
          child: Stack(
            children: [
              Positioned(
                right: -8,
                top: -8,
                child: Icon(
                  icon,
                  size: compact ? 62 : 120,
                  color: Colors.white.withValues(alpha: 0.08),
                ),
              ),
              Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisAlignment: MainAxisAlignment.start,
                children: [
                  Container(
                    padding: const EdgeInsets.all(8),
                    decoration: BoxDecoration(
                      color: Colors.white.withValues(alpha: 0.12),
                      shape: BoxShape.circle,
                    ),
                    child: Icon(icon, color: Colors.white, size: compact ? 18 : 26),
                  ),
                  SizedBox(height: compact ? 8 : 18),
                  Text(
                    title,
                    style: TextStyle(
                      color: Colors.white,
                      fontSize: compact ? 10.8 : 15,
                      fontWeight: FontWeight.w800,
                      height: 1.15,
                    ),
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                  ),
                  const SizedBox(height: 2),
                  Text(
                    subtitle,
                    style: TextStyle(
                      color: Colors.white.withValues(alpha: 0.82),
                      fontSize: compact ? 9.2 : 12,
                      height: 1.2,
                    ),
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                  ),
                  const Spacer(),
                  Align(
                    alignment: Alignment.bottomRight,
                    child: Container(
                      padding: EdgeInsets.all(compact ? 8 : 11),
                      decoration: BoxDecoration(
                        color: Colors.white,
                        shape: BoxShape.circle,
                        boxShadow: [
                          BoxShadow(
                            color: Colors.black.withValues(alpha: 0.12),
                            blurRadius: 10,
                            offset: const Offset(0, 6),
                          ),
                        ],
                      ),
                      child: Icon(
                        Icons.arrow_forward_rounded,
                        size: compact ? 13 : 18,
                        color: accent,
                      ),
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildReportOverviewCard() {
    return StreamBuilder<QuerySnapshot<Map<String, dynamic>>>(
      stream: _streamReportesEquipoPendientes(),
      builder: (context, equipoSnapshot) {
        return StreamBuilder<QuerySnapshot<Map<String, dynamic>>>(
          stream: _streamIncidentesOperadores(),
          builder: (context, incidentesSnapshot) {
            return StreamBuilder<QuerySnapshot<Map<String, dynamic>>>(
              stream: _streamReportesCamiones(),
              builder: (context, camionesSnapshot) {
                final reportesEquipoDocs = equipoSnapshot.data?.docs ??
                    <QueryDocumentSnapshot<Map<String, dynamic>>>[];
                final incidentesOperadorDocs = incidentesSnapshot.data?.docs ??
                    <QueryDocumentSnapshot<Map<String, dynamic>>>[];
                final reportesCamionesDocs = camionesSnapshot.data?.docs ??
                    <QueryDocumentSnapshot<Map<String, dynamic>>>[];

                final reportesEquipo = reportesEquipoDocs.length;
                final incidentesOperador = incidentesOperadorDocs.length;
                final reportesCamiones = reportesCamionesDocs.length;
                final totalReportes =
                    reportesEquipo + incidentesOperador + reportesCamiones;
                final hoyEquipo = _contarReportesHoy(reportesEquipoDocs);
                final hoyOperadores = _contarReportesHoy(incidentesOperadorDocs);
                final hoyCamiones = _contarReportesHoy(reportesCamionesDocs);
                final hoyTotal = hoyEquipo + hoyOperadores + hoyCamiones;

                return Container(
                  padding: const EdgeInsets.all(18),
                  decoration: BoxDecoration(
                    gradient: LinearGradient(
                      colors: [
                        const Color(0xFF0F172A),
                        const Color(0xFF1D4ED8).withValues(alpha: 0.88),
                      ],
                      begin: Alignment.topLeft,
                      end: Alignment.bottomRight,
                    ),
                    borderRadius: BorderRadius.circular(22),
                    boxShadow: [
                      BoxShadow(
                        color: const Color(0xFF0F172A).withValues(alpha: 0.12),
                        blurRadius: 20,
                        offset: const Offset(0, 10),
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
                              color: Colors.white.withValues(alpha: 0.12),
                              borderRadius: BorderRadius.circular(14),
                            ),
                            child: const Icon(
                              Icons.analytics_rounded,
                              color: Colors.white,
                            ),
                          ),
                          const SizedBox(width: 12),
                          const Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  'Total de Reportes',
                                  style: TextStyle(
                                    color: Colors.white,
                                    fontSize: 16,
                                    fontWeight: FontWeight.w800,
                                  ),
                                ),
                                SizedBox(height: 4),
                                Text(
                                  'Resumen general de reportes en tiempo real.',
                                  style: TextStyle(
                                    color: Colors.white70,
                                    fontSize: 12.5,
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 16),
                      Text(
                        totalReportes.toString(),
                        style: const TextStyle(
                          color: Colors.white,
                          fontSize: 30,
                          fontWeight: FontWeight.w900,
                        ),
                      ),
                      const SizedBox(height: 6),
                      Text(
                        'Hoy: $hoyTotal',
                        style: const TextStyle(
                          color: Color(0xFFDBEAFE),
                          fontSize: 13,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                      const SizedBox(height: 14),
                      Wrap(
                        spacing: 8,
                        runSpacing: 8,
                        children: [
                          _buildMiniStatPill('Equipo', reportesEquipo, const Color(0xFF60A5FA)),
                          _buildMiniStatPill('Operadores', incidentesOperador, const Color(0xFFA855F7)),
                          _buildMiniStatPill('Camiones', reportesCamiones, const Color(0xFFF97316)),
                        ],
                      ),
                    ],
                  ),
                );
              },
            );
          },
        );
      },
    );
  }

  Widget _buildMiniStatPill(String label, int value, Color color) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
      decoration: BoxDecoration(
        color: Colors.white.withValues(alpha: 0.12),
        borderRadius: BorderRadius.circular(999),
        border: Border.all(color: Colors.white.withValues(alpha: 0.12)),
      ),
      child: Text(
        '$label: $value',
        style: TextStyle(
          color: color,
          fontSize: 11.5,
          fontWeight: FontWeight.w800,
        ),
      ),
    );
  }

  // ── Helpers de UI ─────────────────────────────────────────────────────────
  Widget _sectionHeader(String title) {
    return Padding(
      padding: const EdgeInsets.only(left: 4),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            title,
            style: TextStyle(
              fontSize: 22,
              fontWeight: FontWeight.w700,
              color: primaryColor,
              letterSpacing: -0.5,
            ),
          ),
          const SizedBox(height: 6),
          Container(
            width: 60,
            height: 4,
            decoration: BoxDecoration(
              gradient: LinearGradient(colors: [accentColor, successColor]),
              borderRadius: BorderRadius.circular(2),
            ),
          ),
        ],
      ),
    );
  }

  Widget _animatedButton({
    required int delay,
    required Color color,
    required IconData icon,
    required String label,
    required String tooltip,
    required VoidCallback onPressed,
  }) {
    return TweenAnimationBuilder<double>(
      tween: Tween(begin: 0, end: 1),
      duration: Duration(milliseconds: delay),
      curve: Curves.easeOutCubic,
      builder: (context, value, child) => Transform.translate(
        offset: Offset(0, 12 * (1 - value)),
        child: Opacity(opacity: value, child: child),
      ),
      child: SizedBox(
        width: double.infinity,
        child: Tooltip(
          message: tooltip,
          child: ElevatedButton.icon(
            style: ElevatedButton.styleFrom(
              backgroundColor: color,
              foregroundColor: Colors.white,
              elevation: 3,
              minimumSize: const Size(double.infinity, 50),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(14),
              ),
            ),
            onPressed: onPressed,
            icon: Icon(icon),
            label: Text(
              label,
              style: const TextStyle(
                  fontWeight: FontWeight.w700, letterSpacing: 0.2),
            ),
          ),
        ),
      ),
    );
  }

  // ── Streams ───────────────────────────────────────────────────────────────
  Stream<QuerySnapshot<Map<String, dynamic>>> _streamUsuariosActivos() =>
      FirebaseFirestore.instance
          .collection('usuarios')
          .where('jornada_activa', isEqualTo: true)
          .snapshots();

  Stream<QuerySnapshot<Map<String, dynamic>>> _streamReportesEquipoPendientes() => FirebaseFirestore.instance
      .collection('checklist')
      .where('equipo_completo', isEqualTo: false)
      .snapshots();

  Stream<QuerySnapshot<Map<String, dynamic>>> _streamIncidentesOperadores() => FirebaseFirestore.instance
      .collection('reportes')
      .snapshots();

  Stream<QuerySnapshot<Map<String, dynamic>>> _streamReportesCamiones() => FirebaseFirestore.instance
      .collection('reportes_camiones')
      .snapshots();

  int _contarReportesHoy(
    List<QueryDocumentSnapshot<Map<String, dynamic>>> docs,
  ) {
    final ahora = DateTime.now();
    final inicioHoy = DateTime(ahora.year, ahora.month, ahora.day);
    final finHoy = inicioHoy.add(const Duration(days: 1));

    var total = 0;
    for (final doc in docs) {
      final valorFecha = doc.data()['fecha'];
      DateTime? fecha;
      if (valorFecha is Timestamp) {
        fecha = valorFecha.toDate();
      } else if (valorFecha is DateTime) {
        fecha = valorFecha;
      }

      if (fecha != null && !fecha.isBefore(inicioHoy) && fecha.isBefore(finHoy)) {
        total++;
      }
    }
    return total;
  }

  // ── Stats ─────────────────────────────────────────────────────────────────
  Widget _buildSystemStatsSection() {
    return StreamBuilder<QuerySnapshot<Map<String, dynamic>>>(
      stream: _streamUsuariosActivos(),
      builder: (context, usuariosSnapshot) {
        final usuariosActivos = usuariosSnapshot.data?.docs ?? [];
        final cantidadActivos = usuariosActivos.length;

        return StreamBuilder<QuerySnapshot<Map<String, dynamic>>>(
          stream: _streamReportesEquipoPendientes(),
          builder: (context, equipoSnapshot) {
            return StreamBuilder<QuerySnapshot<Map<String, dynamic>>>(
              stream: _streamIncidentesOperadores(),
              builder: (context, incidentesSnapshot) {
                return StreamBuilder<QuerySnapshot<Map<String, dynamic>>>(
                  stream: _streamReportesCamiones(),
                  builder: (context, camionesSnapshot) {
                    final reportesEquipoDocs = equipoSnapshot.data?.docs ??
                        <QueryDocumentSnapshot<Map<String, dynamic>>>[];
                    final incidentesOperadorDocs =
                        incidentesSnapshot.data?.docs ??
                            <QueryDocumentSnapshot<Map<String, dynamic>>>[];
                    final reportesCamionesDocs = camionesSnapshot.data?.docs ??
                        <QueryDocumentSnapshot<Map<String, dynamic>>>[];

                    final reportesEquipo = reportesEquipoDocs.length;
                    final incidentesOperador = incidentesOperadorDocs.length;
                    final reportesCamiones = reportesCamionesDocs.length;
                    final totalReportes =
                        reportesEquipo + incidentesOperador + reportesCamiones;
                    final hoyEquipo = _contarReportesHoy(reportesEquipoDocs);
                    final hoyOperadores =
                        _contarReportesHoy(incidentesOperadorDocs);
                    final hoyCamiones = _contarReportesHoy(reportesCamionesDocs);
                    final hoyTotal = hoyEquipo + hoyOperadores + hoyCamiones;

                    return LayoutBuilder(
                      builder: (context, constraints) {
                        final isMobileStats = constraints.maxWidth < 700;
                        final columnas = isMobileStats ? 2 : 3;
                        final statAspectRatio = isMobileStats ? 1.28 : 1.42;

                        return GridView.count(
                          crossAxisCount: columnas,
                          shrinkWrap: true,
                          physics: const NeverScrollableScrollPhysics(),
                          mainAxisSpacing: isMobileStats ? 10 : 14,
                          crossAxisSpacing: isMobileStats ? 10 : 14,
                            childAspectRatio: statAspectRatio,
                          children: [
                            _buildStatCard(
                              icon: Icons.people_outline_rounded,
                              label: 'Usuarios Activos',
                              statusText: 'Jornada activa',
                              value: usuariosSnapshot.connectionState ==
                                      ConnectionState.waiting
                                  ? '...'
                                  : cantidadActivos.toString(),
                              color: accentColor,
                              backgroundGradient: [
                                accentColor.withValues(alpha: 0.12),
                                accentColor.withValues(alpha: 0.04),
                              ],
                              onTap: () => _mostrarDetalleUsuariosActivos(
                                  usuariosActivos),
                              compact: isMobileStats,
                            ),
                              _buildReportSummaryCard(
                                totalReportes: totalReportes,
                                reportesEquipo: reportesEquipo,
                                incidentesOperador: incidentesOperador,
                                reportesCamiones: reportesCamiones,
                                hoyTotal: hoyTotal,
                                hoyEquipo: hoyEquipo,
                                hoyOperadores: hoyOperadores,
                                hoyCamiones: hoyCamiones,
                                compact: isMobileStats,
                              ),
                          ],
                        );
                      },
                    );
                  },
                );
              },
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
    String? statusText,
    VoidCallback? onTap,
    bool compact = false,
  }) {
    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(16),
        child: Container(
          padding: EdgeInsets.all(compact ? 12 : 16),
          decoration: BoxDecoration(
            gradient: LinearGradient(
              colors: backgroundGradient,
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
            ),
            borderRadius: BorderRadius.circular(16),
            border: Border.all(color: color.withValues(alpha: 0.2)),
            boxShadow: [
              BoxShadow(
                color: color.withValues(alpha: 0.09),
                blurRadius: compact ? 10 : 14,
                offset: const Offset(0, 6),
              ),
            ],
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisSize: MainAxisSize.min,
            children: [
              Row(
                children: [
                  Container(
                    padding: EdgeInsets.all(compact ? 6 : 8),
                    decoration: BoxDecoration(
                      color: color.withValues(alpha: 0.15),
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child:
                        Icon(icon, color: color, size: compact ? 18 : 20),
                  ),
                  const Spacer(),
                  if (onTap != null)
                    Icon(
                      Icons.open_in_new_rounded,
                      size: compact ? 14 : 16,
                      color: color.withValues(alpha: 0.8),
                    ),
                ],
              ),
              SizedBox(height: compact ? 8 : 12),
              Text(
                value,
                style: TextStyle(
                  fontSize: compact ? 20 : 24,
                  fontWeight: FontWeight.bold,
                  color: color,
                ),
              ),
              SizedBox(height: compact ? 2 : 4),
              Text(
                label,
                style: TextStyle(
                  fontSize: compact ? 11 : 12,
                  color: Colors.grey[600],
                  fontWeight: FontWeight.w500,
                ),
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
              ),
              if (statusText != null) ...[
                SizedBox(height: compact ? 6 : 8),
                Container(
                  padding: EdgeInsets.symmetric(
                    horizontal: compact ? 8 : 10,
                    vertical: compact ? 4 : 5,
                  ),
                  decoration: BoxDecoration(
                    color: color.withValues(alpha: 0.11),
                    borderRadius: BorderRadius.circular(999),
                  ),
                  child: Text(
                    statusText,
                    style: TextStyle(
                      color: color.withValues(alpha: 0.95),
                      fontSize: compact ? 10 : 10.5,
                      fontWeight: FontWeight.w700,
                    ),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildReportSummaryCard({
    required int totalReportes,
    required int reportesEquipo,
    required int incidentesOperador,
    required int reportesCamiones,
    required int hoyTotal,
    required int hoyEquipo,
    required int hoyOperadores,
    required int hoyCamiones,
    required bool compact,
  }) {
    return Container(
      padding: EdgeInsets.all(compact ? 8 : 16),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: [
            successColor.withValues(alpha: 0.12),
            successColor.withValues(alpha: 0.04),
          ],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: successColor.withValues(alpha: 0.2)),
        boxShadow: [
          BoxShadow(
            color: successColor.withValues(alpha: 0.09),
            blurRadius: compact ? 10 : 14,
            offset: const Offset(0, 6),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisSize: MainAxisSize.min,
        children: [
          Row(
            children: [
              Container(
                padding: EdgeInsets.all(compact ? 4 : 8),
                decoration: BoxDecoration(
                  color: successColor.withValues(alpha: 0.15),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Icon(
                  Icons.assignment_rounded,
                  color: successColor,
                  size: compact ? 16 : 20,
                ),
              ),
            ],
          ),
          SizedBox(height: compact ? 4 : 12),
          Text(
            totalReportes.toString(),
            style: TextStyle(
              fontSize: compact ? 17 : 24,
              fontWeight: FontWeight.bold,
              color: successColor,
            ),
          ),
          SizedBox(height: compact ? 2 : 4),
          Text(
            'Total de Reportes',
            style: TextStyle(
              fontSize: compact ? 9.5 : 12,
              color: Colors.grey[600],
              fontWeight: FontWeight.w500,
            ),
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
          ),
          SizedBox(height: compact ? 4 : 10),
          Text(
            compact
                ? 'Eq $reportesEquipo | Op $incidentesOperador | Cam $reportesCamiones'
                : 'Equipo: $reportesEquipo   Operadores: $incidentesOperador   Camiones: $reportesCamiones',
            style: TextStyle(
              fontSize: compact ? 9 : 10.5,
              color: Colors.grey[700],
              fontWeight: FontWeight.w700,
            ),
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
          ),
          SizedBox(height: compact ? 3 : 10),
          Text(
            'Hoy: $hoyTotal',
            style: TextStyle(
              color: successColor.withValues(alpha: 0.95),
              fontSize: compact ? 9 : 10.5,
              fontWeight: FontWeight.w700,
            ),
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
          ),
        ],
      ),
    );
  }

  // ── Detalle usuarios activos ──────────────────────────────────────────────
  void _mostrarDetalleUsuariosActivos(
    List<QueryDocumentSnapshot<Map<String, dynamic>>> usuarios,
  ) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (context) => Container(
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
                      color: accentColor.withValues(alpha: 0.15),
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child:
                        Icon(Icons.people_alt_rounded, color: accentColor),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Text(
                          'Usuarios Activos',
                          style: TextStyle(
                              fontSize: 18, fontWeight: FontWeight.bold),
                        ),
                        Text(
                          '${usuarios.length} en línea',
                          style: TextStyle(
                              color: Colors.grey[600], fontSize: 13),
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
                          Icon(Icons.person_off_rounded,
                              size: 44, color: Colors.grey[350]),
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
                      separatorBuilder: (_, __) => const SizedBox(height: 10),
                      itemBuilder: (context, index) {
                        final data = usuarios[index].data();
                        final nombre =
                            (data['nombre']?.toString().trim().isNotEmpty ??
                                    false)
                                ? data['nombre'].toString().trim()
                                : 'Sin nombre';
                        final rol = data['rol']?.toString() ?? 'usuario';
                        final camion =
                            data['camion_actual']?.toString() ?? '';
                        final inicial = nombre.isNotEmpty
                            ? nombre.substring(0, 1).toUpperCase()
                            : '?';

                        return Container(
                          padding: const EdgeInsets.all(14),
                          decoration: BoxDecoration(
                            gradient: LinearGradient(
                              colors: [
                                accentColor.withValues(alpha: 0.12),
                                accentColor.withValues(alpha: 0.03),
                              ],
                              begin: Alignment.topLeft,
                              end: Alignment.bottomRight,
                            ),
                            borderRadius: BorderRadius.circular(14),
                            border: Border.all(
                              color: accentColor.withValues(alpha: 0.2),
                            ),
                            boxShadow: [
                              BoxShadow(
                                color: accentColor.withValues(alpha: 0.08),
                                blurRadius: 12,
                                offset: const Offset(0, 4),
                              ),
                            ],
                          ),
                          child: Row(
                            children: [
                              CircleAvatar(
                                radius: 24,
                                backgroundColor:
                                    accentColor.withValues(alpha: 0.18),
                                child: Text(
                                  inicial,
                                  style: TextStyle(
                                    color: accentColor,
                                    fontWeight: FontWeight.w700,
                                    fontSize: 15,
                                  ),
                                ),
                              ),
                              const SizedBox(width: 12),
                              Expanded(
                                child: Column(
                                  crossAxisAlignment:
                                      CrossAxisAlignment.start,
                                  children: [
                                    Text(nombre,
                                        style: const TextStyle(
                                            fontWeight: FontWeight.bold,
                                            fontSize: 14)),
                                    const SizedBox(height: 4),
                                    Text(rol,
                                        style: TextStyle(
                                            fontSize: 12,
                                            color: Colors.grey[700])),
                                    if (camion.isNotEmpty)
                                      Padding(
                                        padding:
                                            const EdgeInsets.only(top: 6),
                                        child: Row(
                                          children: [
                                            Icon(
                                                Icons.local_shipping_rounded,
                                                size: 14,
                                                color: successColor),
                                            const SizedBox(width: 6),
                                            Text(
                                              camion,
                                              style: TextStyle(
                                                fontSize: 11,
                                                color: successColor,
                                                fontWeight: FontWeight.w600,
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
                                    horizontal: 12, vertical: 6),
                                decoration: BoxDecoration(
                                  gradient: LinearGradient(
                                    colors: [
                                      successColor.withValues(alpha: 0.18),
                                      successColor.withValues(alpha: 0.08),
                                    ],
                                  ),
                                  borderRadius: BorderRadius.circular(20),
                                  border: Border.all(
                                    color: successColor.withValues(alpha: 0.3),
                                  ),
                                ),
                                child: Row(
                                  mainAxisSize: MainAxisSize.min,
                                  children: [
                                    Icon(Icons.check_circle_rounded,
                                        color: successColor, size: 14),
                                    const SizedBox(width: 4),
                                    Text(
                                      'En jornada',
                                      style: TextStyle(
                                        color: successColor,
                                        fontSize: 12,
                                        fontWeight: FontWeight.w600,
                                      ),
                                    ),
                                  ],
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
      ),
    );
  }

  // ── Info del sistema ──────────────────────────────────────────────────────
  Widget _buildDetailedInfoSection() {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: [
            primaryColor.withValues(alpha: 0.05),
            accentColor.withValues(alpha: 0.02),
          ],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: accentColor.withValues(alpha: 0.15)),
        boxShadow: [
          BoxShadow(
            color: primaryColor.withValues(alpha: 0.08),
            blurRadius: 16,
            offset: const Offset(0, 6),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    colors: [
                      accentColor.withValues(alpha: 0.15),
                      accentColor.withValues(alpha: 0.05),
                    ],
                  ),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Icon(Icons.info_rounded, color: accentColor, size: 22),
              ),
              const SizedBox(width: 16),
              const Expanded(
                child: Text(
                  'Información del Sistema',
                  style: TextStyle(
                    fontWeight: FontWeight.w700,
                    fontSize: 17,
                    letterSpacing: -0.3,
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
          _buildInfoRow(
            'Última Actualización',
            'Hoy a las ${TimeOfDay.now().format(context)}',
          ),
        ],
      ),
    );
  }

  Widget _buildInfoRow(String label, String value, {Color? valueColor}) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Text(label,
            style: TextStyle(color: Colors.grey[600], fontSize: 13)),
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
}

// ─────────────────────────────────────────────────────────────────────────────
// Widget auxiliar para recomendaciones (necesario en este archivo)
// ─────────────────────────────────────────────────────────────────────────────
class _RecomendacionItemAdmin extends StatelessWidget {
  final IconData icon;
  final String texto;

  const _RecomendacionItemAdmin({required this.icon, required this.texto});

  @override
  Widget build(BuildContext context) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Icon(icon, size: 20, color: const Color(0xFF1D4ED8)),
        const SizedBox(width: 10),
        Expanded(child: Text(texto, style: const TextStyle(fontSize: 14))),
      ],
    );
  }
}


