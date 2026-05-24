import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:flutter/services.dart';
import '../config/session_manager.dart';
import '../services/update_service.dart';

import 'login_screen.dart';
import 'widgets/notificaciones_drawer.dart';
import 'widgets_conexion/connection_wrapper.dart';

class TrabajadorScreen extends StatefulWidget {
  const TrabajadorScreen({super.key});

  @override
  State<TrabajadorScreen> createState() => _TrabajadorScreen();
}

class _TrabajadorScreen extends State<TrabajadorScreen>
    with SingleTickerProviderStateMixin {
  String nombreUsuario = '';
  bool isLoading = true;
  bool _avisoPrecaucionMostrado = false;
  bool _monitoreoContenedoresActivo = false;
  bool _cargandoActivacionMonitoreo = false;
  bool _finalizandoMonitoreoContenedores = false;

  late AnimationController _pulseController;
  late Animation<double> _pulseOpacity;

  final FlutterLocalNotificationsPlugin _notificaciones =
      FlutterLocalNotificationsPlugin();

  @override
  void initState() {
    super.initState();
    obtenerNombre();
    _inicializarAvisoPrecauciones();

    _pulseController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 800),
    )..repeat(reverse: true);

    _pulseOpacity = Tween<double>(begin: 0.5, end: 1.0).animate(
      CurvedAnimation(parent: _pulseController, curve: Curves.easeInOut),
    );
  }

  @override
  void dispose() {
    _pulseController.dispose();
    super.dispose();
  }

  static const List<String> _estadosContenedor = [
    'Fuera de servicio',
    'En proceso de llenado',
    'Lleno',
  ];

  static const List<String> _idsContenedoresMonitoreo = [
    'contenedor-1',
    'contenedor-2',
    'contenedor-3',
  ];

  String _formatTimestamp(Timestamp? ts) {
    if (ts == null) return '—';
    final d = ts.toDate();
    return '${d.day.toString().padLeft(2, '0')}/'
        '${d.month.toString().padLeft(2, '0')} '
        '${d.hour.toString().padLeft(2, '0')}:'
        '${d.minute.toString().padLeft(2, '0')}';
  }

  Color _colorFor(String estado) {
    switch (estado) {
      case 'En proceso de llenado':
        return const Color(0xFFF59E0B);
      case 'Lleno':
        return const Color(0xFF10B981);
      case 'Fuera de servicio':
        return const Color(0xFFEF4444);
      default:
        return const Color(0xFF64748B);
    }
  }

  Color _colorForStatusBg(String estado) {
    switch (estado) {
      case 'En proceso de llenado':
        return const Color(0xFFFFF7ED);
      case 'Lleno':
        return const Color(0xFFECFDF5);
      case 'Fuera de servicio':
        return const Color(0xFFFEF2F2);
      default:
        return const Color(0xFFF8FAFC);
    }
  }

  Color _colorForStatusText(String estado) {
    switch (estado) {
      case 'En proceso de llenado':
        return const Color(0xFFEA580C);
      case 'Lleno':
        return const Color(0xFF059669);
      case 'Fuera de servicio':
        return const Color(0xFFDC2626);
      default:
        return const Color(0xFF475569);
    }
  }

  Widget _buildMetricCard({
    required String title,
    required String value,
    required String subtitle,
    required IconData icon,
    required Color color,
  }) {
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [
            color.withValues(alpha: 0.16),
            color.withValues(alpha: 0.06),
          ],
        ),
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: color.withValues(alpha: 0.14)),
      ),
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(10),
            decoration: BoxDecoration(
              color: color.withValues(alpha: 0.14),
              shape: BoxShape.circle,
            ),
            child: Icon(icon, color: color, size: 20),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  style: const TextStyle(
                    fontSize: 11,
                    color: Color(0xFF64748B),
                    fontWeight: FontWeight.w700,
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  value,
                  style: const TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.w900,
                    color: Color(0xFF0F172A),
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  subtitle,
                  style: const TextStyle(
                    fontSize: 11,
                    color: Color(0xFF64748B),
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  IconData _iconFor(String estado) {
    switch (estado) {
      case 'En proceso de llenado':
        return Icons.hourglass_top_rounded;
      case 'Lleno':
        return Icons.warning_rounded;
      case 'Fuera de servicio':
        return Icons.build_circle_rounded;
      default:
        return Icons.inventory_2_outlined;
    }
  }

  // ─── Cambiar estado del contenedor ────────────────────────────────────────

  Future<void> _cambiarEstadoContenedor(
    String contenedorId,
    String nuevoEstado,
  ) async {
    try {
      final now = FieldValue.serverTimestamp();

      // Si se cambia a cualquier estado que no sea Lleno, limpiar recogida
      final Map<String, dynamic> update = {
        'estado': nuevoEstado,
        'actualizadoPor': nombreUsuario,
        'actualizadoEn': now,
      };

      if (nuevoEstado != 'Lleno') {
        update['estadoRecogida'] = 'pendiente';
        update['operadorRecogida'] = '';
        update['tiempoEstimadoRecogida'] = '';
        update['operadorAsignado'] = '';
      }

      await FirebaseFirestore.instance
          .collection('contenedores')
          .doc(contenedorId)
          .set(update, SetOptions(merge: true));

      final labelId = contenedorId.replaceAll('contenedor-', 'C');

      if (nuevoEstado == 'En proceso de llenado') {
      } else if (nuevoEstado == 'Lleno') {
      } else {}

      if (!mounted) return;
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(const SnackBar(content: Text('Estado actualizado')));
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text('Error al actualizar: $e')));
    }
  }

  // ─── Confirmar que el material fue recogido ────────────────────────────────

  Future<void> _confirmarMaterialRecogido(
    String contenedorId,
    String operadorNombre,
  ) async {
    final confirmar =
        await showDialog<bool>(
          context: context,
          builder: (_) => AlertDialog(
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(22),
            ),
            title: const Row(
              children: [
                Icon(
                  Icons.done_all_rounded,
                  color: Color(0xFF059669),
                  size: 26,
                ),
                SizedBox(width: 10),
                Expanded(
                  child: Text(
                    'Confirmar Recogida',
                    style: TextStyle(
                      fontWeight: FontWeight.w800,
                      fontSize: 17,
                      color: Color(0xFF0F172A),
                    ),
                  ),
                ),
              ],
            ),
            content: Text(
              '¿$operadorNombre ya recogió el material de este contenedor?',
              style: const TextStyle(
                color: Color(0xFF64748B),
                fontSize: 13,
                height: 1.4,
              ),
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.of(context).pop(false),
                child: const Text(
                  'No',
                  style: TextStyle(color: Color(0xFF64748B)),
                ),
              ),
              ElevatedButton(
                onPressed: () => Navigator.of(context).pop(true),
                style: ElevatedButton.styleFrom(
                  backgroundColor: const Color(0xFF059669),
                  foregroundColor: Colors.white,
                  elevation: 0,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(10),
                  ),
                ),
                child: const Text(
                  'Sí, fue recogido',
                  style: TextStyle(fontWeight: FontWeight.w700),
                ),
              ),
            ],
          ),
        ) ??
        false;

    if (!confirmar) return;

    try {
      final now = FieldValue.serverTimestamp();
      final labelId = contenedorId.replaceAll('contenedor-', 'C');

      // Reiniciar el contenedor a cero
      await FirebaseFirestore.instance
          .collection('contenedores')
          .doc(contenedorId)
          .set({
            'estado': 'Fuera de servicio',
            'estadoRecogida': 'pendiente',
            'actualizadoPor': nombreUsuario,
            'actualizadoEn': now,
            'operadorRecogida': '',
            'tiempoEstimadoRecogida': '',
            'operadorAsignado': '',
            'fechaCompromisoRecogida': null,
          }, SetOptions(merge: true));

      final mensaje =
          '$nombreUsuario confirmó que el material del Contenedor $labelId fue recogido por $operadorNombre.';

      // Notificar a admins
      await FirebaseFirestore.instance.collection('notificaciones').add({
        'mensaje': mensaje,
        'enviadoPor': nombreUsuario,
        'creadoEn': now,
        'tipo': 'material_recogido',
        'destinoTipo': 'rol',
        'destinatarioRol': 'admin',
        'paraTodos': false,
      });

      // Notificar a operadores activos
      final opsSnapshot = await FirebaseFirestore.instance
          .collection('usuarios')
          .where('rol', isEqualTo: 'operador')
          .where('jornada_activa', isEqualTo: true)
          .get();

      for (final op in opsSnapshot.docs) {
        await FirebaseFirestore.instance.collection('notificaciones').add({
          'mensaje': mensaje,
          'enviadoPor': nombreUsuario,
          'creadoEn': now,
          'tipo': 'material_recogido',
          'destinoTipo': 'individual',
          'destinatarioDocId': op.id,
          'destinatarioNombre': op.data()['nombre']?.toString() ?? '',
          'destinatarioRol': 'operador',
        });
      }

      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('¡Recogida confirmada! Contenedor reiniciado.'),
          backgroundColor: Color(0xFF059669),
        ),
      );
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text('Error al confirmar: $e')));
    }
  }

  // ─── Precauciones ─────────────────────────────────────────────────────────

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
            AndroidFlutterLocalNotificationsPlugin
          >();
      await androidImpl?.requestNotificationsPermission();

      await _notificaciones.show(
        3001,
        'Seguridad en planta',
        'Recordatorio: Usa cubrebocas, guantes y el uniforme',
        const NotificationDetails(
          android: AndroidNotificationDetails(
            'epp_recomendaciones',
            'Recomendaciones de seguridad',
            channelDescription:
                'Avisos de uso de equipo de protección personal',
            importance: Importance.high,
            priority: Priority.high,
          ),
          iOS: DarwinNotificationDetails(),
        ),
      );
    } catch (e) {
      debugPrint('No se pudo mostrar la notificación: $e');
    }
  }

  Future<void> _mostrarDialogoPrecaucionesTrabajo() async {
    await showDialog<void>(
      context: context,
      builder: (_) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(24)),
        title: const Row(
          children: [
            Icon(
              Icons.health_and_safety_rounded,
              color: Color(0xFF10B981),
              size: 28,
            ),
            SizedBox(width: 10),
            Expanded(
              child: Text(
                'Seguridad en Planta',
                style: TextStyle(
                  fontWeight: FontWeight.w800,
                  fontSize: 18,
                  color: Color(0xFF0F172A),
                ),
              ),
            ),
          ],
        ),
        content: const SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(
                'Recuerda utilizar tu equipo de protección personal.',
                style: TextStyle(
                  fontSize: 13,
                  color: Color(0xFF64748B),
                  height: 1.4,
                ),
              ),
              SizedBox(height: 16),
              _RecomendacionItemTrabajador(
                icon: Icons.pan_tool_rounded,
                texto: 'Usa guantes resistentes para manipular vidrio.',
              ),
              _RecomendacionItemTrabajador(
                icon: Icons.remove_red_eye_rounded,
                texto: 'Porta lentes de seguridad en áreas de carga.',
              ),
              _RecomendacionItemTrabajador(
                icon: Icons.masks_rounded,
                texto: 'Utiliza cubrebocas en todo momento.',
              ),
              _RecomendacionItemTrabajador(
                icon: Icons.checkroom_rounded,
                texto: 'Usa el uniforme oficial de planta.',
              ),
              _RecomendacionItemTrabajador(
                icon: Icons.shield_rounded,
                texto: 'Revisa tu equipo antes de iniciar la jornada.',
              ),
            ],
          ),
        ),
        actions: [
          SizedBox(
            width: double.infinity,
            height: 48,
            child: ElevatedButton(
              onPressed: () => Navigator.of(context).pop(),
              style: ElevatedButton.styleFrom(
                backgroundColor: const Color(0xFF10B981),
                foregroundColor: Colors.white,
                elevation: 0,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
              ),
              child: const Text(
                'Entendido, ¡cuidarme es primero!',
                style: TextStyle(fontWeight: FontWeight.w700, fontSize: 13),
              ),
            ),
          ),
        ],
      ),
    );
  }

  // ─── Perfil / sesión ───────────────────────────────────────────────────────

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
      _monitoreoContenedoresActivo =
          doc?.data()?['jornada_activa'] == true ||
          doc?.data()?['sesion_activa'] == true;
      isLoading = false;
    });
  }

  Future<DocumentReference<Map<String, dynamic>>?>
  _referenciaUsuarioActual() async {
    final currentUser = FirebaseAuth.instance.currentUser;
    if (currentUser == null) return null;

    final usuariosRef = FirebaseFirestore.instance.collection('usuarios');
    final uidRef = usuariosRef.doc(currentUser.uid);
    final uidDoc = await uidRef.get();
    if (uidDoc.exists) return uidRef;

    final email = currentUser.email;
    if (email == null || email.isEmpty) return null;

    final query = await usuariosRef
        .where('email', isEqualTo: email)
        .limit(1)
        .get();
    if (query.docs.isEmpty) return null;
    return query.docs.first.reference;
  }

  Future<void> _actualizarEstadoMonitoreo({required bool activo}) async {
    final ref = await _referenciaUsuarioActual();
    if (ref == null) return;

    await ref.set({
      'jornada_activa': activo,
      'sesion_activa': activo,
      'estado_jornada': activo
          ? 'Monitoreando contenedores'
          : 'Monitoreo detenido',
      'ultima_actualizacion_jornada': FieldValue.serverTimestamp(),
    }, SetOptions(merge: true));
  }

  bool _todosContenedoresFueraDeServicio(
    Map<String, Map<String, dynamic>> contenedores,
  ) {
    return _idsContenedoresMonitoreo.every((id) {
      final estado = contenedores[id]?['estado']?.toString() ?? '';
      return estado == 'Fuera de servicio';
    });
  }

  List<String> _contenedoresPendientes(
    Map<String, Map<String, dynamic>> contenedores,
  ) {
    return _idsContenedoresMonitoreo
        .where((id) {
          final estado = contenedores[id]?['estado']?.toString() ?? '';
          return estado != 'Fuera de servicio';
        })
        .map((id) => id.replaceAll('contenedor-', 'Contenedor '))
        .toList();
  }

  Future<void> _finalizarMonitoreoContenedores({
    required bool puedeFinalizar,
    required List<String> contenedoresPendientes,
  }) async {
    if (_finalizandoMonitoreoContenedores) return;

    if (!puedeFinalizar) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          backgroundColor: const Color(0xFFB91C1C),
          content: Text(
            contenedoresPendientes.isEmpty
                ? 'No puedes finalizar todavía. Todos los contenedores deben estar fuera de servicio.'
                : 'Aún quedan activos: ${contenedoresPendientes.join(', ')}.',
          ),
        ),
      );
      return;
    }

    setState(() {
      _finalizandoMonitoreoContenedores = true;
    });

    try {
      await _actualizarEstadoMonitoreo(activo: false);
      if (!mounted) return;
      setState(() {
        _monitoreoContenedoresActivo = false;
      });
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          backgroundColor: Color(0xFF059669),
          content: Text('Monitoreo de contenedores finalizado'),
        ),
      );
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('No se pudo finalizar el monitoreo: $e')),
      );
    } finally {
      if (mounted) {
        setState(() {
          _finalizandoMonitoreoContenedores = false;
        });
      }
    }
  }

  Future<void> _iniciarMonitoreoContenedores() async {
    if (_cargandoActivacionMonitoreo || _monitoreoContenedoresActivo) return;

    setState(() {
      _cargandoActivacionMonitoreo = true;
    });

    try {
      await _actualizarEstadoMonitoreo(activo: true);
      if (!mounted) return;
      setState(() {
        _monitoreoContenedoresActivo = true;
      });
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Monitoreo de contenedores activado'),
          backgroundColor: Color(0xFF059669),
        ),
      );
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('No se pudo activar el monitoreo: $e')),
      );
    } finally {
      if (mounted) {
        setState(() {
          _cargandoActivacionMonitoreo = false;
        });
      }
    }
  }

  Future<void> _cerrarSesion() async {
    try {
      await _actualizarEstadoMonitoreo(activo: false);
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
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text('Error: $e')));
    }
  }

  Future<void> _confirmarYCerrarSesion() async {
    final confirmar =
        await showDialog<bool>(
          context: context,
          builder: (_) => AlertDialog(
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(20),
            ),
            title: const Text(
              'Cerrar sesión',
              style: TextStyle(
                fontWeight: FontWeight.w800,
                color: Color(0xFF0F172A),
              ),
            ),
            content: const Text('¿Estás seguro de salir de la sesión?'),
            actions: [
              TextButton(
                onPressed: () => Navigator.of(context).pop(false),
                child: const Text(
                  'Cancelar',
                  style: TextStyle(color: Color(0xFF64748B)),
                ),
              ),
              ElevatedButton(
                onPressed: () => Navigator.of(context).pop(true),
                style: ElevatedButton.styleFrom(
                  backgroundColor: const Color(0xFFEF4444),
                  foregroundColor: Colors.white,
                  elevation: 0,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(10),
                  ),
                ),
                child: const Text(
                  'Sí, salir',
                  style: TextStyle(fontWeight: FontWeight.w700),
                ),
              ),
            ],
          ),
        ) ??
        false;
    if (!confirmar) return;
    await _cerrarSesion();
  }

  // ─── Drawer ────────────────────────────────────────────────────────────────

  Widget _buildDrawer(BuildContext context) {
    return Drawer(
      backgroundColor: Colors.white,
      child: Column(
        children: [
          UserAccountsDrawerHeader(
            accountName: Text(
              isLoading ? 'Cargando...' : nombreUsuario,
              style: const TextStyle(fontWeight: FontWeight.w800, fontSize: 16),
            ),
            accountEmail: Text(
              FirebaseAuth.instance.currentUser?.email ?? 'Sin correo',
              style: const TextStyle(fontWeight: FontWeight.w500),
            ),
            currentAccountPicture: const CircleAvatar(
              backgroundColor: Colors.white,
              child: Icon(
                Icons.person_rounded,
                color: Color(0xFF059669),
                size: 36,
              ),
            ),
            decoration: const BoxDecoration(
              gradient: LinearGradient(
                colors: [Color(0xFF047857), Color(0xFF065F46)],
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
              ),
            ),
          ),
          ListTile(
            leading: const Icon(
              Icons.dashboard_rounded,
              color: Color(0xFF059669),
            ),
            title: const Text(
              'Panel trabajador',
              style: TextStyle(
                fontWeight: FontWeight.w700,
                color: Color(0xFF0F172A),
              ),
            ),
            onTap: () => Navigator.of(context).pop(),
          ),
          const Divider(height: 1),
          ListTile(
            leading: const Icon(Icons.system_update, color: Color(0xFF059669)),
            title: const Text(
              'Buscar actualización',
              style: TextStyle(fontWeight: FontWeight.w700),
            ),
            onTap: () async {
              Navigator.of(context).pop();
              await UpdateService.checkAndShowUpdateDialog(context);
            },
          ),
          const Divider(height: 1),
          const Spacer(),
          ListTile(
            leading: const Icon(Icons.logout_rounded, color: Color(0xFFEF4444)),
            title: const Text(
              'Cerrar sesión',
              style: TextStyle(
                fontWeight: FontWeight.w700,
                color: Color(0xFFEF4444),
              ),
            ),
            onTap: () async {
              Navigator.of(context).pop();
              await _confirmarYCerrarSesion();
            },
          ),
          const SizedBox(height: 16),
        ],
      ),
    );
  }

  // ─── Card contenedor ───────────────────────────────────────────────────────

  Widget _buildContenedorCard(String id) {
    return StreamBuilder<DocumentSnapshot<Map<String, dynamic>>>(
      stream: FirebaseFirestore.instance
          .collection('contenedores')
          .doc(id)
          .snapshots(),
      builder: (context, snap) {
        final data = snap.data?.data() ?? {};
        final estado = data['estado']?.toString() ?? 'Fuera de servicio';
        final actualizadoPor = data['actualizadoPor']?.toString() ?? '—';
        final ts = data['actualizadoEn'] is Timestamp
            ? data['actualizadoEn'] as Timestamp
            : null;
        final estadoRecogida =
            data['estadoRecogida']?.toString() ?? 'pendiente';
        final operadorRecogida = data['operadorRecogida']?.toString() ?? '';
        final tiempoEstimado = data['tiempoEstimadoRecogida']?.toString() ?? '';

        final color = _colorFor(estado);
        final icon = _iconFor(estado);
        final labelId = id.replaceAll('contenedor-', 'C');
        final fechaStr = _formatTimestamp(ts);
        final esLleno = estado == 'Lleno';
        final hayOperador = esLleno && estadoRecogida == 'comprometido';

        final statusBgColor = _colorForStatusBg(estado);
        final statusTextColor = _colorForStatusText(estado);

        // Card base
        final cardInner = ClipRRect(
          borderRadius: BorderRadius.circular(20),
          child: Stack(
            children: [
              // Barra lateral
              Positioned(
                left: 0,
                top: 0,
                bottom: 0,
                child: Container(width: 6, color: color),
              ),
              Padding(
                padding: const EdgeInsets.all(16),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // ── Header ────────────────────────────────────────
                    Row(
                      children: [
                        Container(
                          padding: const EdgeInsets.all(10),
                          decoration: BoxDecoration(
                            color: color.withOpacity(0.1),
                            shape: BoxShape.circle,
                          ),
                          child: Icon(icon, color: color, size: 20),
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                'Contenedor $labelId',
                                style: const TextStyle(
                                  fontSize: 16,
                                  fontWeight: FontWeight.w800,
                                  color: Color(0xFF0F172A),
                                  letterSpacing: -0.2,
                                ),
                                overflow: TextOverflow.ellipsis,
                              ),
                              Text(
                                id,
                                style: const TextStyle(
                                  fontSize: 11,
                                  color: Color(0xFF94A3B8),
                                  fontWeight: FontWeight.w500,
                                ),
                              ),
                            ],
                          ),
                        ),
                        const SizedBox(width: 8),
                        // Menú cambiar estado
                        PopupMenuButton<String>(
                          initialValue: estado,
                          onSelected: (v) => _cambiarEstadoContenedor(id, v),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(16),
                          ),
                          itemBuilder: (context) => _estadosContenedor.map((e) {
                            final eColor = _colorFor(e);
                            return PopupMenuItem(
                              value: e,
                              child: Row(
                                children: [
                                  Container(
                                    width: 8,
                                    height: 8,
                                    decoration: BoxDecoration(
                                      color: eColor,
                                      shape: BoxShape.circle,
                                    ),
                                  ),
                                  const SizedBox(width: 10),
                                  Text(
                                    e,
                                    style: const TextStyle(
                                      fontSize: 13,
                                      fontWeight: FontWeight.w700,
                                    ),
                                  ),
                                ],
                              ),
                            );
                          }).toList(),
                          child: Container(
                            padding: const EdgeInsets.symmetric(
                              horizontal: 12,
                              vertical: 6,
                            ),
                            decoration: BoxDecoration(
                              color: statusBgColor,
                              borderRadius: BorderRadius.circular(30),
                              border: Border.all(
                                color: statusTextColor.withOpacity(0.15),
                              ),
                            ),
                            child: Row(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                Container(
                                  width: 6,
                                  height: 6,
                                  decoration: BoxDecoration(
                                    color: statusTextColor,
                                    shape: BoxShape.circle,
                                  ),
                                ),
                                const SizedBox(width: 6),
                                Text(
                                  estado,
                                  style: TextStyle(
                                    color: statusTextColor,
                                    fontSize: 11,
                                    fontWeight: FontWeight.w800,
                                  ),
                                ),
                                const SizedBox(width: 4),
                                Icon(
                                  Icons.keyboard_arrow_down_rounded,
                                  size: 14,
                                  color: statusTextColor,
                                ),
                              ],
                            ),
                          ),
                        ),
                      ],
                    ),

                    const SizedBox(height: 14),

                    // ── Barra de progreso ──────────────────────────────
                    if (estado == 'En proceso de llenado' ||
                        estado == 'Lleno') ...[
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Text(
                            estado == 'Lleno'
                                ? 'Nivel de capacidad: 100%'
                                : 'Nivel aproximado: 65%',
                            style: TextStyle(
                              fontSize: 12,
                              fontWeight: FontWeight.w700,
                              color: statusTextColor,
                            ),
                          ),
                          Icon(
                            estado == 'Lleno'
                                ? Icons.battery_full_rounded
                                : Icons.battery_charging_full_rounded,
                            size: 16,
                            color: statusTextColor,
                          ),
                        ],
                      ),
                      const SizedBox(height: 6),
                      ClipRRect(
                        borderRadius: BorderRadius.circular(10),
                        child: LinearProgressIndicator(
                          value: estado == 'Lleno' ? 1.0 : 0.65,
                          backgroundColor: color.withOpacity(0.1),
                          valueColor: AlwaysStoppedAnimation<Color>(color),
                          minHeight: 8,
                        ),
                      ),
                    ] else ...[
                      ClipRRect(
                        borderRadius: BorderRadius.circular(10),
                        child: const LinearProgressIndicator(
                          value: 0.0,
                          backgroundColor: Color(0xFFE2E8F0),
                          valueColor: AlwaysStoppedAnimation<Color>(
                            Color(0xFF94A3B8),
                          ),
                          minHeight: 8,
                        ),
                      ),
                    ],

                    const SizedBox(height: 12),
                    Divider(color: const Color(0xFFF1F5F9), height: 1),
                    const SizedBox(height: 10),

                    // ── Footer por/hora ────────────────────────────────
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Row(
                          children: [
                            const Icon(
                              Icons.person_pin_rounded,
                              size: 13,
                              color: Color(0xFF94A3B8),
                            ),
                            const SizedBox(width: 4),
                            Text(
                              'Por: $actualizadoPor',
                              style: const TextStyle(
                                fontSize: 11,
                                color: Color(0xFF64748B),
                                fontWeight: FontWeight.w600,
                              ),
                            ),
                          ],
                        ),
                        Row(
                          children: [
                            const Icon(
                              Icons.access_time_rounded,
                              size: 13,
                              color: Color(0xFF94A3B8),
                            ),
                            const SizedBox(width: 4),
                            Text(
                              fechaStr,
                              style: const TextStyle(
                                fontSize: 11,
                                color: Color(0xFF64748B),
                                fontWeight: FontWeight.w600,
                              ),
                            ),
                          ],
                        ),
                      ],
                    ),

                    // ── Sección recogida (solo si está Lleno) ──────────
                    if (esLleno) ...[
                      const SizedBox(height: 14),

                      if (hayOperador) ...[
                        // Operador comprometido — mostrar info + botón confirmar
                        Container(
                          padding: const EdgeInsets.all(14),
                          decoration: BoxDecoration(
                            color: const Color(0xFFECFDF5),
                            borderRadius: BorderRadius.circular(14),
                            border: Border.all(
                              color: const Color(0xFFD1FAE5),
                              width: 1.5,
                            ),
                          ),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              // Encabezado
                              const Row(
                                children: [
                                  Icon(
                                    Icons.local_shipping_rounded,
                                    color: Color(0xFF059669),
                                    size: 18,
                                  ),
                                  SizedBox(width: 8),
                                  Text(
                                    'Operador en camino',
                                    style: TextStyle(
                                      fontSize: 13,
                                      fontWeight: FontWeight.w800,
                                      color: Color(0xFF047857),
                                    ),
                                  ),
                                ],
                              ),
                              const SizedBox(height: 10),
                              // Nombre operador
                              Row(
                                children: [
                                  const Icon(
                                    Icons.person_rounded,
                                    size: 15,
                                    color: Color(0xFF059669),
                                  ),
                                  const SizedBox(width: 6),
                                  Expanded(
                                    child: Text(
                                      operadorRecogida,
                                      style: const TextStyle(
                                        fontSize: 13,
                                        fontWeight: FontWeight.w700,
                                        color: Color(0xFF047857),
                                      ),
                                    ),
                                  ),
                                ],
                              ),
                              if (tiempoEstimado.isNotEmpty) ...[
                                const SizedBox(height: 6),
                                Row(
                                  children: [
                                    const Icon(
                                      Icons.schedule_rounded,
                                      size: 15,
                                      color: Color(0xFF059669),
                                    ),
                                    const SizedBox(width: 6),
                                    Text(
                                      'Llega en: $tiempoEstimado',
                                      style: const TextStyle(
                                        fontSize: 12,
                                        fontWeight: FontWeight.w600,
                                        color: Color(0xFF059669),
                                      ),
                                    ),
                                  ],
                                ),
                              ],
                              const SizedBox(height: 12),
                              // Botón confirmar recogida
                              SizedBox(
                                width: double.infinity,
                                height: 44,
                                child: ElevatedButton.icon(
                                  onPressed: () => _confirmarMaterialRecogido(
                                    id,
                                    operadorRecogida,
                                  ),
                                  icon: const Icon(
                                    Icons.done_all_rounded,
                                    size: 18,
                                  ),
                                  label: const Text(
                                    'Confirmar Material Recogido',
                                    style: TextStyle(
                                      fontWeight: FontWeight.w800,
                                      fontSize: 13,
                                    ),
                                  ),
                                  style: ElevatedButton.styleFrom(
                                    backgroundColor: const Color(0xFF047857),
                                    foregroundColor: Colors.white,
                                    elevation: 0,
                                    shape: RoundedRectangleBorder(
                                      borderRadius: BorderRadius.circular(12),
                                    ),
                                  ),
                                ),
                              ),
                            ],
                          ),
                        ),
                      ] else ...[
                        // Nadie aún — banner esperando operador
                        AnimatedBuilder(
                          animation: _pulseOpacity,
                          builder: (_, child) => Opacity(
                            opacity: _pulseOpacity.value,
                            child: child,
                          ),
                          child: Container(
                            padding: const EdgeInsets.symmetric(
                              horizontal: 14,
                              vertical: 10,
                            ),
                            decoration: BoxDecoration(
                              color: const Color(0xFFFFF7ED),
                              borderRadius: BorderRadius.circular(12),
                              border: Border.all(
                                color: const Color(0xFFFDE68A),
                                width: 1.5,
                              ),
                            ),
                            child: const Row(
                              children: [
                                Icon(
                                  Icons.hourglass_top_rounded,
                                  color: Color(0xFFD97706),
                                  size: 18,
                                ),
                                SizedBox(width: 8),
                                Expanded(
                                  child: Text(
                                    'Esperando que un operador se comprometa a recoger...',
                                    style: TextStyle(
                                      fontSize: 11,
                                      fontWeight: FontWeight.w700,
                                      color: Color(0xFF92400E),
                                    ),
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ),
                      ],
                    ],
                  ],
                ),
              ),
            ],
          ),
        );

        // Si está lleno envolver con pulso en el borde
        if (esLleno) {
          return AnimatedBuilder(
            animation: _pulseOpacity,
            builder: (_, child) => Container(
              margin: const EdgeInsets.only(bottom: 14),
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(20),
                boxShadow: [
                  BoxShadow(
                    color: const Color(
                      0xFF10B981,
                    ).withOpacity(_pulseOpacity.value * 0.2),
                    blurRadius: 16,
                    spreadRadius: 1,
                    offset: const Offset(0, 4),
                  ),
                ],
                border: Border.all(
                  color: const Color(
                    0xFF10B981,
                  ).withOpacity(0.3 + _pulseOpacity.value * 0.4),
                  width: 1.5 + _pulseOpacity.value * 0.5,
                ),
              ),
              child: child,
            ),
            child: cardInner,
          );
        }

        return Container(
          margin: const EdgeInsets.only(bottom: 14),
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(20),
            boxShadow: [
              BoxShadow(
                color: const Color(0xFF0F172A).withOpacity(0.04),
                blurRadius: 12,
                offset: const Offset(0, 6),
              ),
            ],
            border: Border.all(color: color.withOpacity(0.15), width: 1.5),
          ),
          child: cardInner,
        );
      },
    );
  }

  // ─── Sección contenedores ──────────────────────────────────────────────────

  Widget _buildContenedoresSection() {
    return StreamBuilder<QuerySnapshot<Map<String, dynamic>>>(
      stream: FirebaseFirestore.instance.collection('contenedores').snapshots(),
      builder: (context, snapshot) {
        final contenedores = <String, Map<String, dynamic>>{};
        for (final doc in snapshot.data?.docs ?? const []) {
          contenedores[doc.id] = doc.data();
        }

        final activos = contenedores.values.where((item) {
          final estado = item['estado']?.toString() ?? '';
          return estado != 'Fuera de servicio';
        }).length;
        final llenos = contenedores.values.where((item) {
          return item['estado']?.toString() == 'Lleno';
        }).length;
        final enProceso = contenedores.values.where((item) {
          return item['estado']?.toString() == 'En proceso de llenado';
        }).length;
        final fuera = contenedores.values.where((item) {
          return item['estado']?.toString() == 'Fuera de servicio';
        }).length;

        final puedeFinalizar = _todosContenedoresFueraDeServicio(contenedores);
        final contenedoresPendientes = _contenedoresPendientes(contenedores);

        return Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Row(
              children: [
                Container(
                  padding: const EdgeInsets.all(10),
                  decoration: BoxDecoration(
                    color: const Color(0xFF059669).withValues(alpha: 0.12),
                    shape: BoxShape.circle,
                  ),
                  child: const Icon(
                    Icons.view_kanban_rounded,
                    color: Color(0xFF059669),
                    size: 20,
                  ),
                ),
                const SizedBox(width: 10),
                const Expanded(
                  child: Text(
                    'Monitoreo de Contenedores',
                    style: TextStyle(
                      fontSize: 18,
                      fontWeight: FontWeight.w900,
                      color: Color(0xFF0F172A),
                      letterSpacing: -0.5,
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 14),
            GridView.count(
              crossAxisCount: 2,
              crossAxisSpacing: 12,
              mainAxisSpacing: 12,
              shrinkWrap: true,
              physics: const NeverScrollableScrollPhysics(),
              childAspectRatio: 1.95,
              children: [
                _buildMetricCard(
                  title: 'Activos',
                  value: activos.toString(),
                  subtitle: 'Contenedores monitoreados',
                  icon: Icons.inventory_2_rounded,
                  color: const Color(0xFF2563EB),
                ),
                _buildMetricCard(
                  title: 'Llenos',
                  value: llenos.toString(),
                  subtitle: 'Requieren atención',
                  icon: Icons.warning_amber_rounded,
                  color: const Color(0xFFD97706),
                ),
                _buildMetricCard(
                  title: 'En proceso',
                  value: enProceso.toString(),
                  subtitle: 'Crecimiento de carga',
                  icon: Icons.hourglass_top_rounded,
                  color: const Color(0xFF7C3AED),
                ),
                _buildMetricCard(
                  title: 'Fuera de servicio',
                  value: fuera.toString(),
                  subtitle: 'Listos para reiniciar',
                  icon: Icons.build_circle_rounded,
                  color: const Color(0xFF059669),
                ),
              ],
            ),
            const SizedBox(height: 16),
            Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                gradient: const LinearGradient(
                  colors: [Color(0xFFF8FAFC), Color(0xFFFFFFFF)],
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                ),
                borderRadius: BorderRadius.circular(18),
                border: Border.all(color: const Color(0xFFE2E8F0)),
              ),
              child: const Row(
                children: [
                  Icon(Icons.touch_app_rounded, color: Color(0xFF2563EB)),
                  SizedBox(width: 10),
                  Expanded(
                    child: Text(
                      'Toca una tarjeta para cambiar el estado del contenedor. Cuando uno esté lleno podrás confirmar la recogida.',
                      style: TextStyle(
                        color: Color(0xFF334155),
                        fontSize: 12,
                        height: 1.4,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ),
                ],
              ),
            ),
            ..._idsContenedoresMonitoreo.map((id) => _buildContenedorCard(id)),
            const SizedBox(height: 8),
            Container(
              padding: const EdgeInsets.all(14),
              decoration: BoxDecoration(
                color: const Color(0xFFEFF6FF),
                borderRadius: BorderRadius.circular(16),
                border: Border.all(color: const Color(0xFFBFDBFE)),
              ),
              child: const Row(
                children: [
                  Icon(
                    Icons.notification_important_rounded,
                    color: Color(0xFF2563EB),
                    size: 20,
                  ),
                  SizedBox(width: 12),
                  Expanded(
                    child: Text(
                      'Cuando un operador se comprometa a recoger verás su nombre y tiempo estimado aquí.',
                      style: TextStyle(
                        color: Color(0xFF1E40AF),
                        fontSize: 11,
                        height: 1.4,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 14),
            Container(
              padding: const EdgeInsets.all(14),
              decoration: BoxDecoration(
                color: puedeFinalizar
                    ? const Color(0xFFECFDF5)
                    : const Color(0xFFFFF7ED),
                borderRadius: BorderRadius.circular(16),
                border: Border.all(
                  color: puedeFinalizar
                      ? const Color(0xFFA7F3D0)
                      : const Color(0xFFFCD34D),
                ),
              ),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Icon(
                    puedeFinalizar
                        ? Icons.check_circle_rounded
                        : Icons.info_rounded,
                    color: puedeFinalizar
                        ? const Color(0xFF059669)
                        : const Color(0xFFD97706),
                    size: 20,
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: Text(
                      puedeFinalizar
                          ? 'Todos los contenedores están fuera de servicio. Ya puedes deslizar para finalizar el monitoreo.'
                          : contenedoresPendientes.isEmpty
                          ? 'No puedes finalizar todavía. Todos los contenedores deben estar fuera de servicio.'
                          : 'No puedes finalizar todavía. Deben estar fuera de servicio: ${contenedoresPendientes.join(', ')}.',
                      style: TextStyle(
                        color: puedeFinalizar
                            ? const Color(0xFF047857)
                            : const Color(0xFF92400E),
                        fontSize: 11.5,
                        height: 1.4,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 14),
            Container(
              padding: const EdgeInsets.fromLTRB(10, 8, 10, 10),
              decoration: BoxDecoration(
                color: const Color(0xFFF1F0F1),
                borderRadius: BorderRadius.circular(16),
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withValues(alpha: 0.04),
                    blurRadius: 6,
                    offset: const Offset(0, 3),
                  ),
                ],
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  const Row(
                    children: [
                      Icon(
                        Icons.flag_outlined,
                        color: Color(0xFFE53E3E),
                        size: 20,
                      ),
                      SizedBox(width: 6),
                      Expanded(
                        child: Text(
                          'Finalizar monitoreo de los contenedores',
                          style: TextStyle(
                            fontSize: 18,
                            fontWeight: FontWeight.w700,
                            color: Color(0xFF1F2937),
                          ),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 1),
                  Text(
                    puedeFinalizar
                        ? _finalizandoMonitoreoContenedores
                              ? 'Finalizando...'
                              : 'Desliza izquierda a derecha para confirmar'
                        : 'Debes dejar todos los contenedores fuera de servicio antes de finalizar.',
                    style: const TextStyle(
                      fontSize: 12,
                      color: Color(0xFF8E95A3),
                    ),
                  ),
                  const SizedBox(height: 8),
                  _SwipeToConfirmButton(
                    text: _finalizandoMonitoreoContenedores
                        ? 'Finalizando monitoreo...'
                        : 'Desliza para finalizar monitoreo de los contenedores',
                    enabled:
                        puedeFinalizar && !_finalizandoMonitoreoContenedores,
                    onCompleted: () => _finalizarMonitoreoContenedores(
                      puedeFinalizar: puedeFinalizar,
                      contenedoresPendientes: contenedoresPendientes,
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 24),
          ],
        );
      },
    );
  }

  Widget _buildPantallaInicioMonitoreo() {
    return Center(
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 24),
        child: Container(
          width: double.infinity,
          constraints: const BoxConstraints(maxWidth: 560),
          padding: const EdgeInsets.all(22),
          decoration: BoxDecoration(
            gradient: const LinearGradient(
              colors: [Color(0xFFFFFFFF), Color(0xFFF8FAFC)],
              begin: Alignment.topCenter,
              end: Alignment.bottomCenter,
            ),
            borderRadius: BorderRadius.circular(28),
            border: Border.all(color: const Color(0xFFE2E8F0)),
            boxShadow: [
              BoxShadow(
                color: const Color(0xFF0F172A).withValues(alpha: 0.06),
                blurRadius: 24,
                offset: const Offset(0, 12),
              ),
            ],
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              AnimatedBuilder(
                animation: _pulseOpacity,
                builder: (context, child) {
                  return Transform.scale(
                    scale: 0.94 + (_pulseOpacity.value * 0.08),
                    child: Opacity(opacity: _pulseOpacity.value, child: child),
                  );
                },
                child: Container(
                  width: 104,
                  height: 104,
                  decoration: BoxDecoration(
                    gradient: const LinearGradient(
                      colors: [Color(0xFFECFDF5), Color(0xFFD1FAE5)],
                      begin: Alignment.topLeft,
                      end: Alignment.bottomRight,
                    ),
                    shape: BoxShape.circle,
                    boxShadow: [
                      BoxShadow(
                        color: const Color(0xFF059669).withValues(alpha: 0.18),
                        blurRadius: 26,
                        offset: const Offset(0, 12),
                      ),
                    ],
                  ),
                  child: const Icon(
                    Icons.inventory_2_rounded,
                    size: 48,
                    color: Color(0xFF059669),
                  ),
                ),
              ),
              const SizedBox(height: 20),
              const Text(
                'Panel de monitoreo de contenedores',
                textAlign: TextAlign.center,
                style: TextStyle(
                  fontSize: 22,
                  fontWeight: FontWeight.w900,
                  color: Color(0xFF0F172A),
                  height: 1.15,
                ),
              ),
              const SizedBox(height: 10),
              const Text(
                'Inicia tu jornada para abrir el panel operativo, monitorear estados y coordinar la recogida cuando un contenedor esté lleno.',
                textAlign: TextAlign.center,
                style: TextStyle(
                  fontSize: 13,
                  color: Color(0xFF64748B),
                  height: 1.45,
                ),
              ),
              const SizedBox(height: 18),
              Container(
                padding: const EdgeInsets.all(14),
                decoration: BoxDecoration(
                  color: const Color(0xFFF0FDF4),
                  borderRadius: BorderRadius.circular(18),
                  border: Border.all(color: const Color(0xFFDCFCE7)),
                ),
                child: const Row(
                  children: [
                    Icon(Icons.verified_user_rounded, color: Color(0xFF059669)),
                    SizedBox(width: 10),
                    Expanded(
                      child: Text(
                        'Tu usuario quedará activo para administración mientras dure el monitoreo.',
                        style: TextStyle(
                          fontSize: 12,
                          color: Color(0xFF14532D),
                          height: 1.35,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 18),
              SizedBox(
                width: double.infinity,
                height: 56,
                child: ElevatedButton.icon(
                  onPressed: _cargandoActivacionMonitoreo
                      ? null
                      : _iniciarMonitoreoContenedores,
                  style: ElevatedButton.styleFrom(
                    backgroundColor: const Color(0xFF059669),
                    foregroundColor: Colors.white,
                    elevation: 0,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(18),
                    ),
                  ),
                  icon: _cargandoActivacionMonitoreo
                      ? const SizedBox(
                          width: 18,
                          height: 18,
                          child: CircularProgressIndicator(
                            strokeWidth: 2.2,
                            valueColor: AlwaysStoppedAnimation<Color>(
                              Colors.white,
                            ),
                          ),
                        )
                      : const Icon(Icons.play_arrow_rounded),
                  label: Text(
                    _cargandoActivacionMonitoreo
                        ? 'Activando monitoreo...'
                        : 'Empezar monitoreo',
                    style: const TextStyle(
                      fontSize: 15,
                      fontWeight: FontWeight.w800,
                    ),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildPanelContenedoresActivo() {
    return RefreshIndicator(
      color: const Color(0xFF059669),
      onRefresh: () async => await obtenerNombre(),
      child: ListView(
        physics: const AlwaysScrollableScrollPhysics(),
        padding: const EdgeInsets.all(16),
        children: [
          Container(
            width: double.infinity,
            padding: const EdgeInsets.all(20),
            decoration: BoxDecoration(
              gradient: const LinearGradient(
                colors: [Color(0xFF0F766E), Color(0xFF047857)],
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
              ),
              borderRadius: BorderRadius.circular(28),
              boxShadow: [
                BoxShadow(
                  color: const Color(0xFF059669).withValues(alpha: 0.18),
                  blurRadius: 22,
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
                        shape: BoxShape.circle,
                      ),
                      child: const Icon(
                        Icons.account_circle_rounded,
                        color: Colors.white,
                        size: 24,
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            isLoading ? 'Cargando...' : '¡Hola, $nombreUsuario!',
                            style: const TextStyle(
                              fontSize: 22,
                              fontWeight: FontWeight.w900,
                              color: Colors.white,
                              letterSpacing: -0.5,
                            ),
                          ),
                          const SizedBox(height: 4),
                          const Text(
                            'Monitoreo activo en tiempo real',
                            style: TextStyle(
                              color: Color(0xFFD1FAE5),
                              fontSize: 12,
                              height: 1.4,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 18),
                Row(
                  children: [
                    Expanded(
                      child: Container(
                        padding: const EdgeInsets.all(12),
                        decoration: BoxDecoration(
                          color: Colors.white.withValues(alpha: 0.12),
                          borderRadius: BorderRadius.circular(16),
                          border: Border.all(
                            color: Colors.white.withValues(alpha: 0.14),
                          ),
                        ),
                        child: const Row(
                          children: [
                            Icon(Icons.speed_rounded, color: Colors.white, size: 18),
                            SizedBox(width: 8),
                            Expanded(
                              child: Text(
                                'Estados y seguimiento centralizados',
                                style: TextStyle(
                                  color: Colors.white,
                                  fontSize: 12,
                                  fontWeight: FontWeight.w700,
                                ),
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 10),
                const Text(
                  'Desde aquí administras el estado de cada contenedor y confirmas recogidas cuando corresponda.',
                  style: TextStyle(
                    color: Color(0xFFD1FAE5),
                    fontSize: 12,
                    height: 1.45,
                    fontWeight: FontWeight.w500,
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 24),
          _buildContenedoresSection(),
        ],
      ),
    );
  }

  // ─── Build ─────────────────────────────────────────────────────────────────

  @override
  Widget build(BuildContext context) {
    return ConnectionWrapper(
      child: Scaffold(
        backgroundColor: const Color(0xFFF8FAFC),
        drawer: _buildDrawer(context),
        endDrawer: NotificacionesDrawer(
          rolUsuario: 'trabajador',
          nombreUsuario: nombreUsuario,
        ),
        appBar: AppBar(
          automaticallyImplyLeading: true,
          title: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Text(
                'Trabajador',
                style: TextStyle(
                  color: Colors.white,
                  fontWeight: FontWeight.w800,
                ),
              ),
              const SizedBox(width: 10),
              ClipRRect(
                borderRadius: BorderRadius.circular(10),
                child: Image.asset(
                  'assets/logo circular.jpeg',
                  height: 34,
                  width: 34,
                  fit: BoxFit.cover,
                ),
              ),
            ],
          ),
          centerTitle: false,
          elevation: 0,
          foregroundColor: Colors.white,
          flexibleSpace: Container(
            decoration: const BoxDecoration(
              gradient: LinearGradient(
                colors: [Color(0xFF047857), Color(0xFF065F46)],
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
              ),
            ),
          ),
          actions: [
            Builder(
              builder: (context) => NotificacionesBellButton(
                rolUsuario: 'trabajador',
                nombreUsuario: nombreUsuario,
                iconColor: Colors.white,
                onPressed: () => Scaffold.of(context).openEndDrawer(),
              ),
            ),
          ],
        ),
        body: _monitoreoContenedoresActivo
            ? _buildPanelContenedoresActivo()
            : _buildPantallaInicioMonitoreo(),
      ),
    );
  }
}

// ─── Widget recomendación ──────────────────────────────────────────────────────

class _RecomendacionItemTrabajador extends StatelessWidget {
  final IconData icon;
  final String texto;

  const _RecomendacionItemTrabajador({required this.icon, required this.texto});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
      margin: const EdgeInsets.only(bottom: 8),
      decoration: BoxDecoration(
        color: const Color(0xFFF0FDF4),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: const Color(0xFFDCFCE7)),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(icon, size: 20, color: const Color(0xFF16A34A)),
          const SizedBox(width: 12),
          Expanded(
            child: Text(
              texto,
              style: const TextStyle(
                fontSize: 13,
                height: 1.4,
                color: Color(0xFF14532D),
                fontWeight: FontWeight.w600,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _SwipeToConfirmButton extends StatefulWidget {
  final String text;
  final bool enabled;
  final Future<void> Function() onCompleted;

  const _SwipeToConfirmButton({
    required this.text,
    required this.enabled,
    required this.onCompleted,
  });

  @override
  State<_SwipeToConfirmButton> createState() => _SwipeToConfirmButtonState();
}

class _SwipeToConfirmButtonState extends State<_SwipeToConfirmButton> {
  double _dragX = 0;
  bool _loading = false;

  @override
  void didUpdateWidget(covariant _SwipeToConfirmButton oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.enabled) {
      _loading = false;
    } else {
      _dragX = 0;
      _loading = true;
    }
  }

  Future<void> _handlePanEnd(double maxDrag) async {
    if (_loading || !widget.enabled) {
      setState(() => _dragX = 0);
      return;
    }

    final progress = maxDrag <= 0 ? 0.0 : (_dragX / maxDrag);
    if (progress >= 0.85) {
      HapticFeedback.mediumImpact();
      setState(() {
        _dragX = maxDrag;
        _loading = true;
      });
      await widget.onCompleted();
      return;
    }

    setState(() => _dragX = 0);
  }

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        const knobSize = 66.0;
        final double maxDrag = (constraints.maxWidth - knobSize)
            .clamp(0.0, double.infinity)
            .toDouble();
        final double fillWidth = (_dragX + knobSize)
            .clamp(knobSize, constraints.maxWidth)
            .toDouble();

        return Container(
          height: 74,
          decoration: BoxDecoration(
            color: const Color(0xFFFDECEC),
            borderRadius: BorderRadius.circular(40),
            border: Border.all(color: const Color(0xFFF2B7B7)),
          ),
          child: Stack(
            alignment: Alignment.centerLeft,
            children: [
              AnimatedContainer(
                duration: const Duration(milliseconds: 120),
                curve: Curves.easeOut,
                width: fillWidth,
                height: 74,
                decoration: BoxDecoration(
                  color: const Color(0xFFE11D48).withValues(alpha: 0.20),
                  borderRadius: BorderRadius.circular(40),
                ),
              ),
              Center(
                child: AnimatedOpacity(
                  duration: const Duration(milliseconds: 180),
                  opacity: _dragX > maxDrag * 0.2 ? 0.35 : 1,
                  child: Text(
                    widget.text,
                    textAlign: TextAlign.center,
                    style: const TextStyle(
                      fontWeight: FontWeight.w700,
                      color: Color(0xFFDF3B3B),
                    ),
                  ),
                ),
              ),
              Positioned(
                left: _dragX,
                child: GestureDetector(
                  onHorizontalDragUpdate: (!widget.enabled || _loading)
                      ? null
                      : (details) {
                          setState(() {
                            _dragX = (_dragX + details.delta.dx)
                                .clamp(0.0, maxDrag)
                                .toDouble();
                          });
                        },
                  onHorizontalDragEnd: (!widget.enabled || _loading)
                      ? null
                      : (_) {
                          _handlePanEnd(maxDrag);
                        },
                  child: Container(
                    width: knobSize,
                    height: knobSize,
                    decoration: BoxDecoration(
                      color: const Color(0xFFE53935),
                      shape: BoxShape.circle,
                      boxShadow: [
                        BoxShadow(
                          color: Colors.black.withValues(alpha: 0.18),
                          blurRadius: 8,
                          offset: const Offset(0, 3),
                        ),
                      ],
                    ),
                    child: const Icon(
                      Icons.arrow_forward_rounded,
                      color: Colors.white,
                      size: 30,
                    ),
                  ),
                ),
              ),
            ],
          ),
        );
      },
    );
  }
}
