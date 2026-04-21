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
      await iosImpl?.requestPermissions(alert: true, badge: true, sound: true);

      const androidDetails = AndroidNotificationDetails(
        'epp_recomendaciones',
        'Recomendaciones de seguridad',
        channelDescription: 'Avisos de uso de equipo de protección personal',
        importance: Importance.high,
        priority: Priority.high,
      );
      await _notificaciones.show(
        2001,
        'Seguridad en planta',
        'Recordatorio: Usa cubrebocas, guantes y el uniforme',
        const NotificationDetails(
          android: androidDetails,
          iOS: DarwinNotificationDetails(),
        ),
      );
    } catch (e) {
      debugPrint('No se pudo mostrar la notificación en admin: $e');
    }
  }

  Future<void> _mostrarDialogoPrecaucionesTrabajo() async {
    await showDialog<void>(
      context: context,
      builder: (_) => AlertDialog(
        title: const Row(
          children: [
            Icon(Icons.health_and_safety_rounded, color: Color(0xFF1D4ED8)),
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

  // ── Perfil ────────────────────────────────────────────────────────────────
  Future<DocumentSnapshot<Map<String, dynamic>>?> _obtenerPerfilUsuario() async {
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
        nombreUsuario =
            doc?.data()?['nombre']?.toString() ?? 'Administrador';
        isLoading = false;
      });
    } catch (e) {
      debugPrint('Error obteniendo nombre: $e');
      if (!mounted) return;
      setState(() => isLoading = false);
    }
  }

  Future<void> _recargarPanelAdmin() async => obtenerNombre();

  // ── Cerrar sesión ─────────────────────────────────────────────────────────
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
      ScaffoldMessenger.of(context)
          .showSnackBar(SnackBar(content: Text('Error al cerrar sesión: $e')));
    }
  }

  Future<void> _confirmarYCerrarSesion() async {
    final confirmar = await showDialog<bool>(
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

  // ── Navegación ────────────────────────────────────────────────────────────
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

  void _abrirMonitoreoUbicacion() => Navigator.push(
        context,
        MaterialPageRoute(builder: (_) => const MonitoreoUbicacionScreen()),
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
          builder: (_) =>
              AdminNotificacionesScreen(adminNombre: nombreUsuario),
        ),
      );

  void _abrirReporteGasolina() => Navigator.push(
        context,
        MaterialPageRoute(
            builder: (_) => const ReporteGasolinaCamionesScreen()),
      );

  void _abrirReporteToneladas() => Navigator.push(
        context,
        MaterialPageRoute(builder: (_) => ReporteToneladasAdminScreen()),
      );

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
  Widget build(BuildContext context) {
    final isMobile = MediaQuery.of(context).size.width < 600;
    final screenWidth = MediaQuery.of(context).size.width;
    final isTablet = screenWidth >= 600 && screenWidth < 1024;
    final gridColumns = screenWidth >= 1300 ? 4 : (screenWidth >= 900 ? 3 : 2);
    final optionCardAspectRatio =
        isMobile ? 1.28 : (isTablet ? 1.12 : 1.03);

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
          : RefreshIndicator(
              onRefresh: _recargarPanelAdmin,
              child: SingleChildScrollView(
                physics: const AlwaysScrollableScrollPhysics(),
                child: Padding(
                  padding: EdgeInsets.all(isMobile ? 12 : 20),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      // Bienvenida
                      TweenAnimationBuilder<double>(
                        tween: Tween(begin: 0, end: 1),
                        duration: const Duration(milliseconds: 800),
                        builder: (context, value, child) => Transform.translate(
                          offset: Offset(0, 30 * (1 - value)),
                          child: Opacity(opacity: value, child: child),
                        ),
                        child: Container(
                          padding: const EdgeInsets.all(20),
                          decoration: BoxDecoration(
                            gradient: LinearGradient(
                              colors: [
                                accentColor.withValues(alpha: 0.1),
                                successColor.withValues(alpha: 0.05),
                              ],
                              begin: Alignment.topLeft,
                              end: Alignment.bottomRight,
                            ),
                            borderRadius: BorderRadius.circular(18),
                            border: Border.all(
                              color: accentColor.withValues(alpha: 0.2),
                            ),
                            boxShadow: [
                              BoxShadow(
                                color: primaryColor.withValues(alpha: 0.08),
                                blurRadius: 24,
                                offset: const Offset(0, 12),
                              ),
                            ],
                          ),
                          child: Row(
                            children: [
                              Container(
                                padding: const EdgeInsets.all(12),
                                decoration: BoxDecoration(
                                  gradient: LinearGradient(
                                    colors: [
                                      accentColor.withValues(alpha: 0.2),
                                      accentColor.withValues(alpha: 0.1),
                                    ],
                                  ),
                                  borderRadius: BorderRadius.circular(12),
                                ),
                                child: Icon(
                                  Icons.workspace_premium_rounded,
                                  color: accentColor,
                                  size: 24,
                                ),
                              ),
                              const SizedBox(width: 16),
                              Expanded(
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Text(
                                      'Listo para trabajar',
                                      style: TextStyle(
                                        fontSize: 17,
                                        fontWeight: FontWeight.w700,
                                        color: primaryColor,
                                        letterSpacing: 0.3,
                                      ),
                                    ),
                                    const SizedBox(height: 6),
                                    Text(
                                      'Accede a todas las herramientas de gestión',
                                      style: TextStyle(
                                        fontSize: 13,
                                        color: Colors.grey[600],
                                        fontWeight: FontWeight.w400,
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                            ],
                          ),
                        ),
                      ),
                      const SizedBox(height: 12),

                      // Botón Panel General
                      _animatedButton(
                        delay: 900,
                        color: primaryColor,
                        icon: Icons.groups_2_rounded,
                        label: 'Panel General de Usuarios',
                        tooltip:
                            'Resumen de usuarios, altas, bajas y estado general del personal.',
                        onPressed: _abrirPanelGeneralUsuarios,
                      ),
                      const SizedBox(height: 10),

                      // Botón Mapa
                      _animatedButton(
                        delay: 980,
                        color: successColor,
                        icon: Icons.map_rounded,
                        label: 'Mapa General de Operadores',
                        tooltip:
                            'Ubicación en tiempo real de operadores activos y su ruta actual.',
                        onPressed: _abrirMapaGeneralOperadores,
                      ),
                      const SizedBox(height: 10),

                      // Botón Notificaciones
                      _animatedButton(
                        delay: 1020,
                        color: warningColor,
                        icon: Icons.notifications_active_rounded,
                        label: 'Enviar Notificaciones',
                        tooltip:
                            'Envía avisos generales o alertas urgentes a los operadores.',
                        onPressed: _abrirNotificacionesAdmin,
                      ),
                      const SizedBox(height: 28),

                      // Gestiones Principales
                      _sectionHeader('Gestiones Principales'),
                      const SizedBox(height: 16),
                      GridView.count(
                        crossAxisCount: gridColumns,
                        shrinkWrap: true,
                        physics: const NeverScrollableScrollPhysics(),
                        mainAxisSpacing: isMobile ? 10 : 12,
                        crossAxisSpacing: isMobile ? 10 : 12,
                        childAspectRatio: optionCardAspectRatio,
                        children: [
                          _AnimatedOptionCard(
                            icon: Icons.people_alt_rounded,
                            title: 'Usuarios',
                            description:
                                'Ver, editar, agregar y eliminar usuarios del sistema',
                            onTap: _abrirUsuarios,
                            color: const Color(0xFF2563EB),
                            compact: isMobile,
                          ),
                          _AnimatedOptionCard(
                            icon: Icons.bar_chart_rounded,
                            title: 'Reportes de Equipo',
                            description:
                                'Faltantes y asignaciones de equipos',
                            onTap: _abrirReportes,
                            color: const Color(0xFF3B82F6),
                            compact: isMobile,
                          ),
                          _AnimatedOptionCard(
                            icon: Icons.emergency_share,
                            title: 'Reportes de operadores',
                            description:
                                'Tráfico, averías y retrasos en ruta',
                            onTap: _abrirIncidentes,
                            color: const Color(0xFF60A5FA),
                            compact: isMobile,
                          ),
                          _AnimatedOptionCard(
                            icon: Icons.location_on_rounded,
                            title: 'Monitoreo de Ubicación',
                            description:
                                'Seguimiento en tiempo real de operadores',
                            onTap: _abrirMonitoreoUbicacion,
                            color: const Color(0xFF10B981),
                            compact: isMobile,
                          ),
                          _AnimatedOptionCard(
                            icon: Icons.local_gas_station_rounded,
                            title: 'Reporte de Gasolina',
                            description:
                                'Tabla de cargas y descarga en Excel',
                            onTap: _abrirReporteGasolina,
                            color: const Color(0xFFF59E0B),
                            compact: isMobile,
                          ),
                          _AnimatedOptionCard(
                            icon: Icons.scale_rounded,
                            title: 'Reporte de Toneladas',
                            description:
                                'Apartado inicial para cargas de camiones',
                            onTap: _abrirReporteToneladas,
                            color: const Color(0xFF0F766E),
                            compact: isMobile,
                          ),
                        ],
                      ),
                      const SizedBox(height: 32),

                      // Estado del Sistema
                      _sectionHeader('Estado del Sistema'),
                      const SizedBox(height: 16),
                      _buildSystemStatsSection(),
                      const SizedBox(height: 32),

                      // Información detallada
                      _buildDetailedInfoSection(),
                      const SizedBox(height: 20),
                    ],
                  ),
                ),
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

  Stream<int> _streamReportesEquipoPendientes() => FirebaseFirestore.instance
      .collection('checklist')
      .where('equipo_completo', isEqualTo: false)
      .snapshots()
      .map((s) => s.docs.length);

  Stream<int> _streamIncidentesOperadores() => FirebaseFirestore.instance
      .collection('reportes')
      .snapshots()
      .map((s) => s.docs.length);

  Stream<int> _streamReportesCamiones() => FirebaseFirestore.instance
      .collection('reportes_camiones')
      .snapshots()
      .map((s) => s.docs.length);

  // ── Stats ─────────────────────────────────────────────────────────────────
  Widget _buildSystemStatsSection() {
    return StreamBuilder<QuerySnapshot<Map<String, dynamic>>>(
      stream: _streamUsuariosActivos(),
      builder: (context, usuariosSnapshot) {
        final usuariosActivos = usuariosSnapshot.data?.docs ?? [];
        final cantidadActivos = usuariosActivos.length;

        return StreamBuilder<int>(
          stream: _streamReportesEquipoPendientes(),
          builder: (context, equipoSnapshot) {
            return StreamBuilder<int>(
              stream: _streamIncidentesOperadores(),
              builder: (context, incidentesSnapshot) {
                return StreamBuilder<int>(
                  stream: _streamReportesCamiones(),
                  builder: (context, camionesSnapshot) {
                    final reportesEquipo = equipoSnapshot.data ?? 0;
                    final incidentesOperador = incidentesSnapshot.data ?? 0;
                    final reportesCamiones = camionesSnapshot.data ?? 0;
                    final totalReportes =
                        reportesEquipo + incidentesOperador + reportesCamiones;

                    return LayoutBuilder(
                      builder: (context, constraints) {
                        final isMobileStats = constraints.maxWidth < 700;
                        final columnas = isMobileStats ? 2 : 3;
                        final statAspectRatio = isMobileStats ? 1.14 : 1.42;

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
                            _buildStatCard(
                              icon: Icons.bar_chart_rounded,
                              label: 'Reportes de Equipo',
                              statusText: 'Tiempo real',
                              value: reportesEquipo.toString(),
                              color: const Color(0xFF3B82F6),
                              backgroundGradient: [
                                const Color(0xFF3B82F6).withValues(alpha: 0.12),
                                const Color(0xFF3B82F6).withValues(alpha: 0.04),
                              ],
                              onTap: _abrirReportes,
                              compact: isMobileStats,
                            ),
                            _buildStatCard(
                              icon: Icons.emergency_share_rounded,
                              label: 'Incidentes Operadores',
                              statusText: 'Tiempo real',
                              value: incidentesOperador.toString(),
                              color: warningColor,
                              backgroundGradient: [
                                warningColor.withValues(alpha: 0.12),
                                warningColor.withValues(alpha: 0.04),
                              ],
                              onTap: _abrirIncidentes,
                              compact: isMobileStats,
                            ),
                            _buildStatCard(
                              icon: Icons.local_shipping_rounded,
                              label: 'Reportes Camiones',
                              statusText: 'Tiempo real',
                              value: reportesCamiones.toString(),
                              color: const Color(0xFF0F766E),
                              backgroundGradient: [
                                const Color(0xFF0F766E).withValues(alpha: 0.12),
                                const Color(0xFF0F766E).withValues(alpha: 0.04),
                              ],
                              onTap: () => Navigator.push(
                                context,
                                MaterialPageRoute(
                                  builder: (_) =>
                                      const ReportesCamionesAdminScreen(),
                                ),
                              ),
                              compact: isMobileStats,
                            ),
                            _buildStatCard(
                              icon: Icons.assignment_rounded,
                              label: 'Total de Reportes',
                              statusText: 'Suma de todas las áreas',
                              value: totalReportes.toString(),
                              color: successColor,
                              backgroundGradient: [
                                successColor.withValues(alpha: 0.12),
                                successColor.withValues(alpha: 0.04),
                              ],
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

// --- PANTALLA DE MONITOREO DE UBICACIÓN ---
class MonitoreoUbicacionScreen extends StatefulWidget {
  const MonitoreoUbicacionScreen({super.key});

  @override
  State<MonitoreoUbicacionScreen> createState() =>
      _MonitoreoUbicacionScreenState();
}

class _MonitoreoUbicacionScreenState extends State<MonitoreoUbicacionScreen> {
  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF5F7FB),
      appBar: AppBar(
        title: const Text(
          "Monitoreo de Ubicación",
          style: TextStyle(
            fontWeight: FontWeight.bold,
            fontSize: 20,
            letterSpacing: 0.5,
          ),
        ),
        backgroundColor: const Color(0xFF10B981),
        foregroundColor: Colors.white,
        elevation: 0,
        centerTitle: false,
      ),
      body: StreamBuilder<QuerySnapshot>(
        stream: FirebaseFirestore.instance
            .collection("usuarios")
            .where("rol", isEqualTo: "operador")
            .snapshots(),
        builder: (context, snapshot) {
          if (!snapshot.hasData) {
            return const Center(
              child: CircularProgressIndicator(color: Color(0xFF10B981)),
            );
          }

          final operadores = snapshot.data!.docs;
          if (operadores.isEmpty) {
            return Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(Icons.location_off, size: 80, color: Colors.grey[300]),
                  const SizedBox(height: 16),
                  Text(
                    "No hay operadores registrados",
                    style: TextStyle(
                      color: Colors.grey[500],
                      fontSize: 16,
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                ],
              ),
            );
          }

          return ListView.builder(
            padding: const EdgeInsets.all(16),
            itemCount: operadores.length,
            itemBuilder: (context, index) {
              final doc = operadores[index];
              final data = doc.data() as Map<String, dynamic>;

              String nombre =
                  (data["nombre"]?.toString().trim().isNotEmpty ?? false)
                  ? data["nombre"]!.toString().trim()
                  : "Sin nombre";
              String apellido =
                  (data["apellido_paterno"]?.toString().trim().isNotEmpty ??
                      false)
                  ? data["apellido_paterno"]!.toString().trim()
                  : "";
              String inicial = nombre.isNotEmpty
                  ? nombre[0].toUpperCase()
                  : "?";
              String telefono = data["telefono"]?.toString().trim() ?? "S/T";
              String direccion =
                  data["direccion"]?.toString().trim() ??
                  "Ubicación no disponible";

              return Card(
                elevation: 0,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(16),
                  side: BorderSide(color: Colors.grey.withValues(alpha: 0.12)),
                ),
                margin: const EdgeInsets.only(bottom: 12),
                child: Container(
                  decoration: BoxDecoration(
                    borderRadius: BorderRadius.circular(16),
                    gradient: LinearGradient(
                      begin: Alignment.topLeft,
                      end: Alignment.bottomRight,
                      colors: [
                        Colors.white,
                        Colors.grey.withValues(alpha: 0.02),
                      ],
                    ),
                  ),
                  child: ListTile(
                    contentPadding: const EdgeInsets.symmetric(
                      horizontal: 16,
                      vertical: 12,
                    ),
                    leading: CircleAvatar(
                      radius: 28,
                      backgroundColor: const Color(
                        0xFF10B981,
                      ).withValues(alpha: 0.1),
                      child: Text(
                        inicial,
                        style: const TextStyle(
                          color: Color(0xFF10B981),
                          fontWeight: FontWeight.bold,
                          fontSize: 16,
                        ),
                      ),
                    ),
                    title: Text(
                      apellido.isNotEmpty ? "$nombre $apellido" : nombre,
                      style: const TextStyle(
                        fontWeight: FontWeight.w700,
                        fontSize: 15,
                        color: Colors.black87,
                      ),
                    ),
                    subtitle: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const SizedBox(height: 6),
                        Row(
                          children: [
                            const Icon(
                              Icons.phone,
                              size: 14,
                              color: Color(0xFF10B981),
                            ),
                            const SizedBox(width: 6),
                            Text(
                              telefono,
                              style: TextStyle(
                                color: Colors.grey[600],
                                fontSize: 13,
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 4),
                        Row(
                          children: [
                            const Icon(
                              Icons.location_on,
                              size: 14,
                              color: Color(0xFF10B981),
                            ),
                            const SizedBox(width: 6),
                            Expanded(
                              child: Text(
                                direccion,
                                style: TextStyle(
                                  color: Colors.grey[600],
                                  fontSize: 12,
                                ),
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                              ),
                            ),
                          ],
                        ),
                      ],
                    ),
                    trailing: Container(
                      decoration: BoxDecoration(
                        color: const Color(0xFF10B981).withValues(alpha: 0.1),
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: const Padding(
                        padding: EdgeInsets.all(8.0),
                        child: Icon(
                          Icons.location_on_rounded,
                          color: Color(0xFF10B981),
                          size: 22,
                        ),
                      ),
                    ),
                  ),
                ),
              );
            },
          );
        },
      ),
    );
  }
}


