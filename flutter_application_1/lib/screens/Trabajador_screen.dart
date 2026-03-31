import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import '../config/session_manager.dart';

import 'login_screen.dart';
import 'widgets_conexion/connection_wrapper.dart';

class TrabajadorScreen extends StatefulWidget {
  const TrabajadorScreen({super.key});

  @override
  State<TrabajadorScreen> createState() => _TrabajadorScreen();
}

class _TrabajadorScreen extends State<TrabajadorScreen> {
  String nombreUsuario = '';
  bool isLoading = true;
  bool _avisoPrecaucionMostrado = false;

  final FlutterLocalNotificationsPlugin _notificaciones =
      FlutterLocalNotificationsPlugin();

  @override
  void initState() {
    super.initState();
    obtenerNombre();
    _inicializarAvisoPrecauciones();
  }

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

      const settings = InitializationSettings(
        android: androidInit,
        iOS: iosInit,
      );

      await _notificaciones.initialize(settings);

      final androidImpl = _notificaciones
          .resolvePlatformSpecificImplementation<
            AndroidFlutterLocalNotificationsPlugin
          >();
      await androidImpl?.requestNotificationsPermission();

      final iosImpl = _notificaciones
          .resolvePlatformSpecificImplementation<
            IOSFlutterLocalNotificationsPlugin
          >();
      await iosImpl?.requestPermissions(alert: true, badge: true, sound: true);

      const androidDetails = AndroidNotificationDetails(
        'epp_recomendaciones',
        'Recomendaciones de seguridad',
        channelDescription: 'Avisos de uso de equipo de protección personal',
        importance: Importance.high,
        priority: Priority.high,
      );

      const details = NotificationDetails(
        android: androidDetails,
        iOS: DarwinNotificationDetails(),
      );

      await _notificaciones.show(
        3001,
        'Seguridad en planta',
        'Usa guantes, lentes y botas antes de iniciar.',
        details,
      );
    } catch (e) {
      debugPrint('No se pudo mostrar la notificación en trabajador: $e');
    }
  }

  Future<void> _mostrarDialogoPrecaucionesTrabajo() async {
    await showDialog<void>(
      context: context,
      builder: (_) => AlertDialog(
        title: const Row(
          children: [
            Icon(Icons.health_and_safety_rounded, color: Colors.green),
            SizedBox(width: 8),
            Expanded(child: Text('Precauciones de trabajo')),
          ],
        ),
        content: const SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              _RecomendacionItemTrabajador(
                icon: Icons.back_hand_outlined,
                texto: 'Usa guantes resistentes para manipular vidrio.',
              ),
              SizedBox(height: 8),
              _RecomendacionItemTrabajador(
                icon: Icons.visibility_outlined,
                texto: 'Porta lentes de seguridad para evitar lesiones.',
              ),
              SizedBox(height: 8),
              _RecomendacionItemTrabajador(
                icon: Icons.hiking_outlined,
                texto: 'Trabaja con botas de seguridad antideslizantes.',
              ),
              SizedBox(height: 8),
              _RecomendacionItemTrabajador(
                icon: Icons.construction_outlined,
                texto: 'Si aplica, usa casco y chaleco reflectante.',
              ),
              SizedBox(height: 8),
              _RecomendacionItemTrabajador(
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
    final doc = await _obtenerPerfilUsuario();
    if (!mounted) return;

    setState(() {
      nombreUsuario = doc?.data()?['nombre']?.toString() ?? 'Trabajador';
      isLoading = false;
    });
  }

  Future<void> _recargarPanelTrabajador() async {
    await obtenerNombre();
  }

  Future<void> _cerrarSesion() async {
    try {
      await FirebaseAuth.instance.signOut();
      await SessionManager.limpiarSesion();
      if (!mounted) return;
      Navigator.of(context).pushAndRemoveUntil(
        MaterialPageRoute(builder: (_) => const LoginScreen()),
        (route) => false,
      );
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text('Error al cerrar sesión: $e')));
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

  Widget _buildTrabajadorDrawer(BuildContext context) {
    return Drawer(
      child: Column(
        children: [
          UserAccountsDrawerHeader(
            accountName: Text(isLoading ? 'Cargando...' : nombreUsuario),
            accountEmail: Text(
              FirebaseAuth.instance.currentUser?.email ?? 'Sin correo',
            ),
            currentAccountPicture: const CircleAvatar(
              backgroundColor: Colors.white,
              child: Icon(Icons.person, color: Colors.green),
            ),
            decoration: const BoxDecoration(color: Colors.green),
          ),
          ListTile(
            leading: const Icon(Icons.dashboard_outlined),
            title: const Text('Panel trabajador'),
            onTap: () => Navigator.of(context).pop(),
          ),
          const Spacer(),
          ListTile(
            leading: const Icon(Icons.logout_rounded, color: Colors.red),
            title: const Text('Cerrar sesión'),
            onTap: () async {
              Navigator.of(context).pop();
              await _confirmarYCerrarSesion();
            },
          ),
          const SizedBox(height: 8),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return ConnectionWrapper(
      child: Scaffold(
        drawer: _buildTrabajadorDrawer(context),
        appBar: AppBar(
          title: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(
                isLoading ? 'Trabajador' : 'Trabajador',
                style: const TextStyle(fontWeight: FontWeight.w700),
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
          backgroundColor: Colors.green,
        ),
        body: RefreshIndicator(
          onRefresh: _recargarPanelTrabajador,
          child: ListView(
            physics: const AlwaysScrollableScrollPhysics(),
            padding: const EdgeInsets.all(16),
            children: [
              Container(
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(14),
                  border: Border.all(
                    color: Colors.green.withValues(alpha: 0.2),
                  ),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      isLoading ? 'Cargando...' : 'Hola, $nombreUsuario',
                      style: const TextStyle(
                        fontSize: 20,
                        fontWeight: FontWeight.bold,
                        color: Colors.black87,
                      ),
                    ),
                    const SizedBox(height: 8),
                    Text(
                      'Desliza hacia abajo para recargar la información.',
                      style: TextStyle(color: Colors.grey[700]),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 24),
              const Center(child: Text('Pantalla Trabajador')),
            ],
          ),
        ),
      ),
    );
  }
}

class _RecomendacionItemTrabajador extends StatelessWidget {
  final IconData icon;
  final String texto;

  const _RecomendacionItemTrabajador({required this.icon, required this.texto});

  @override
  Widget build(BuildContext context) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Icon(Icons.shield_outlined, size: 18, color: Colors.green),
        const SizedBox(width: 8),
        Expanded(
          child: Text(
            texto,
            style: const TextStyle(fontSize: 13, height: 1.35),
          ),
        ),
      ],
    );
  }
}
