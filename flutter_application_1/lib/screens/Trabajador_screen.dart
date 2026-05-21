import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import '../config/session_manager.dart';

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

      String mensaje = '';
      String tipo = '';
      if (nuevoEstado == 'En proceso de llenado') {
        mensaje =
            'Contenedor $contenedorId en proceso de llenado (reportado por $nombreUsuario).';
        tipo = 'contenedor_llenando';
      } else if (nuevoEstado == 'Lleno') {
        mensaje =
            'Contenedor $contenedorId lleno y en espera de recolección (reportado por $nombreUsuario).';
        tipo = 'contenedor_lleno';
      } else {
        mensaje =
            'Contenedor $contenedorId fuera de servicio (reportado por $nombreUsuario).';
        tipo = 'contenedor_fuera_servicio';
      }

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
          'tipo': tipo,
          'destinoTipo': 'individual',
          'destinatarioDocId': op.id,
          'destinatarioRol': 'operador',
        });
      }

      // Notificar a admin
      await FirebaseFirestore.instance.collection('notificaciones').add({
        'mensaje': mensaje,
        'enviadoPor': nombreUsuario,
        'creadoEn': now,
        'tipo': tipo,
        'destinoTipo': 'rol',
        'destinatarioRol': 'admin',
        'paraTodos': false,
      });

      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Estado actualizado')),
      );
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Error al actualizar: $e')),
      );
    }
  }

  // ─── Confirmar que el material fue recogido ────────────────────────────────

  Future<void> _confirmarMaterialRecogido(
    String contenedorId,
    String operadorNombre,
  ) async {
    final confirmar = await showDialog<bool>(
      context: context,
      builder: (_) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(22)),
        title: const Row(
          children: [
            Icon(Icons.done_all_rounded, color: Color(0xFF059669), size: 26),
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
            child: const Text('No',
                style: TextStyle(color: Color(0xFF64748B))),
          ),
          ElevatedButton(
            onPressed: () => Navigator.of(context).pop(true),
            style: ElevatedButton.styleFrom(
              backgroundColor: const Color(0xFF059669),
              foregroundColor: Colors.white,
              elevation: 0,
              shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(10)),
            ),
            child: const Text('Sí, fue recogido',
                style: TextStyle(fontWeight: FontWeight.w700)),
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
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Error al confirmar: $e')),
      );
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
      const androidInit =
          AndroidInitializationSettings('@mipmap/ic_launcher');
      const iosInit = DarwinInitializationSettings(
        requestAlertPermission: false,
        requestBadgePermission: false,
        requestSoundPermission: false,
      );
      await _notificaciones.initialize(
          const InitializationSettings(android: androidInit, iOS: iosInit));

      final androidImpl = _notificaciones
          .resolvePlatformSpecificImplementation<
              AndroidFlutterLocalNotificationsPlugin>();
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
        shape:
            RoundedRectangleBorder(borderRadius: BorderRadius.circular(24)),
        title: const Row(
          children: [
            Icon(Icons.health_and_safety_rounded,
                color: Color(0xFF10B981), size: 28),
            SizedBox(width: 10),
            Expanded(
              child: Text('Seguridad en Planta',
                  style: TextStyle(
                      fontWeight: FontWeight.w800,
                      fontSize: 18,
                      color: Color(0xFF0F172A))),
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
                    height: 1.4),
              ),
              SizedBox(height: 16),
              _RecomendacionItemTrabajador(
                  icon: Icons.pan_tool_rounded,
                  texto:
                      'Usa guantes resistentes para manipular vidrio.'),
              _RecomendacionItemTrabajador(
                  icon: Icons.remove_red_eye_rounded,
                  texto:
                      'Porta lentes de seguridad en áreas de carga.'),
              _RecomendacionItemTrabajador(
                  icon: Icons.masks_rounded,
                  texto: 'Utiliza cubrebocas en todo momento.'),
              _RecomendacionItemTrabajador(
                  icon: Icons.checkroom_rounded,
                  texto: 'Usa el uniforme oficial de planta.'),
              _RecomendacionItemTrabajador(
                  icon: Icons.shield_rounded,
                  texto:
                      'Revisa tu equipo antes de iniciar la jornada.'),
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
                    borderRadius: BorderRadius.circular(12)),
              ),
              child: const Text('Entendido, ¡cuidarme es primero!',
                  style: TextStyle(
                      fontWeight: FontWeight.w700, fontSize: 13)),
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
      nombreUsuario =
          doc?.data()?['nombre']?.toString() ?? 'Trabajador';
      isLoading = false;
    });
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
      ScaffoldMessenger.of(context)
          .showSnackBar(SnackBar(content: Text('Error: $e')));
    }
  }

  Future<void> _confirmarYCerrarSesion() async {
    final confirmar = await showDialog<bool>(
          context: context,
          builder: (_) => AlertDialog(
            shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(20)),
            title: const Text('Cerrar sesión',
                style: TextStyle(
                    fontWeight: FontWeight.w800,
                    color: Color(0xFF0F172A))),
            content:
                const Text('¿Estás seguro de salir de la sesión?'),
            actions: [
              TextButton(
                onPressed: () => Navigator.of(context).pop(false),
                child: const Text('Cancelar',
                    style: TextStyle(color: Color(0xFF64748B))),
              ),
              ElevatedButton(
                onPressed: () => Navigator.of(context).pop(true),
                style: ElevatedButton.styleFrom(
                  backgroundColor: const Color(0xFFEF4444),
                  foregroundColor: Colors.white,
                  elevation: 0,
                  shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(10)),
                ),
                child: const Text('Sí, salir',
                    style: TextStyle(fontWeight: FontWeight.w700)),
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
              style: const TextStyle(
                  fontWeight: FontWeight.w800, fontSize: 16),
            ),
            accountEmail: Text(
              FirebaseAuth.instance.currentUser?.email ?? 'Sin correo',
              style: const TextStyle(fontWeight: FontWeight.w500),
            ),
            currentAccountPicture: const CircleAvatar(
              backgroundColor: Colors.white,
              child: Icon(Icons.person_rounded,
                  color: Color(0xFF059669), size: 36),
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
            leading: const Icon(Icons.dashboard_rounded,
                color: Color(0xFF059669)),
            title: const Text('Panel trabajador',
                style: TextStyle(
                    fontWeight: FontWeight.w700,
                    color: Color(0xFF0F172A))),
            onTap: () => Navigator.of(context).pop(),
          ),
          const Spacer(),
          ListTile(
            leading: const Icon(Icons.logout_rounded,
                color: Color(0xFFEF4444)),
            title: const Text('Cerrar sesión',
                style: TextStyle(
                    fontWeight: FontWeight.w700,
                    color: Color(0xFFEF4444))),
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
        final estado =
            data['estado']?.toString() ?? 'Fuera de servicio';
        final actualizadoPor =
            data['actualizadoPor']?.toString() ?? '—';
        final ts = data['actualizadoEn'] is Timestamp
            ? data['actualizadoEn'] as Timestamp
            : null;
        final estadoRecogida =
            data['estadoRecogida']?.toString() ?? 'pendiente';
        final operadorRecogida =
            data['operadorRecogida']?.toString() ?? '';
        final tiempoEstimado =
            data['tiempoEstimadoRecogida']?.toString() ?? '';

        final color = _colorFor(estado);
        final icon = _iconFor(estado);
        final labelId = id.replaceAll('contenedor-', 'C');
        final fechaStr = _formatTimestamp(ts);
        final esLleno = estado == 'Lleno';
        final hayOperador =
            esLleno && estadoRecogida == 'comprometido';

        Color statusBgColor;
        Color statusTextColor;
        switch (estado) {
          case 'En proceso de llenado':
            statusBgColor = const Color(0xFFFFF7ED);
            statusTextColor = const Color(0xFFEA580C);
            break;
          case 'Lleno':
            statusBgColor = const Color(0xFFECFDF5);
            statusTextColor = const Color(0xFF059669);
            break;
          case 'Fuera de servicio':
            statusBgColor = const Color(0xFFFEF2F2);
            statusTextColor = const Color(0xFFDC2626);
            break;
          default:
            statusBgColor = const Color(0xFFF8FAFC);
            statusTextColor = const Color(0xFF475569);
        }

        // Card base
        final cardInner = ClipRRect(
          borderRadius: BorderRadius.circular(20),
          child: Stack(
            children: [
              // Barra lateral
              Positioned(
                left: 0, top: 0, bottom: 0,
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
                            crossAxisAlignment:
                                CrossAxisAlignment.start,
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
                          onSelected: (v) =>
                              _cambiarEstadoContenedor(id, v),
                          shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(16)),
                          itemBuilder: (context) =>
                              _estadosContenedor.map((e) {
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
                                        shape: BoxShape.circle),
                                  ),
                                  const SizedBox(width: 10),
                                  Text(e,
                                      style: const TextStyle(
                                          fontSize: 13,
                                          fontWeight:
                                              FontWeight.w700)),
                                ],
                              ),
                            );
                          }).toList(),
                          child: Container(
                            padding: const EdgeInsets.symmetric(
                                horizontal: 12, vertical: 6),
                            decoration: BoxDecoration(
                              color: statusBgColor,
                              borderRadius: BorderRadius.circular(30),
                              border: Border.all(
                                  color:
                                      statusTextColor.withOpacity(0.15)),
                            ),
                            child: Row(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                Container(
                                  width: 6,
                                  height: 6,
                                  decoration: BoxDecoration(
                                      color: statusTextColor,
                                      shape: BoxShape.circle),
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
                                Icon(Icons.keyboard_arrow_down_rounded,
                                    size: 14, color: statusTextColor),
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
                        mainAxisAlignment:
                            MainAxisAlignment.spaceBetween,
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
                          valueColor:
                              AlwaysStoppedAnimation<Color>(color),
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
                              Color(0xFF94A3B8)),
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
                        Row(children: [
                          const Icon(Icons.person_pin_rounded,
                              size: 13, color: Color(0xFF94A3B8)),
                          const SizedBox(width: 4),
                          Text('Por: $actualizadoPor',
                              style: const TextStyle(
                                  fontSize: 11,
                                  color: Color(0xFF64748B),
                                  fontWeight: FontWeight.w600)),
                        ]),
                        Row(children: [
                          const Icon(Icons.access_time_rounded,
                              size: 13, color: Color(0xFF94A3B8)),
                          const SizedBox(width: 4),
                          Text(fechaStr,
                              style: const TextStyle(
                                  fontSize: 11,
                                  color: Color(0xFF64748B),
                                  fontWeight: FontWeight.w600)),
                        ]),
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
                                width: 1.5),
                          ),
                          child: Column(
                            crossAxisAlignment:
                                CrossAxisAlignment.start,
                            children: [
                              // Encabezado
                              const Row(
                                children: [
                                  Icon(Icons.local_shipping_rounded,
                                      color: Color(0xFF059669),
                                      size: 18),
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
                                      color: Color(0xFF059669)),
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
                                    const Icon(Icons.schedule_rounded,
                                        size: 15,
                                        color: Color(0xFF059669)),
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
                                  onPressed: () =>
                                      _confirmarMaterialRecogido(
                                          id, operadorRecogida),
                                  icon: const Icon(
                                      Icons.done_all_rounded,
                                      size: 18),
                                  label: const Text(
                                    'Confirmar Material Recogido',
                                    style: TextStyle(
                                        fontWeight: FontWeight.w800,
                                        fontSize: 13),
                                  ),
                                  style: ElevatedButton.styleFrom(
                                    backgroundColor:
                                        const Color(0xFF047857),
                                    foregroundColor: Colors.white,
                                    elevation: 0,
                                    shape: RoundedRectangleBorder(
                                        borderRadius:
                                            BorderRadius.circular(
                                                12)),
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
                                horizontal: 14, vertical: 10),
                            decoration: BoxDecoration(
                              color: const Color(0xFFFFF7ED),
                              borderRadius:
                                  BorderRadius.circular(12),
                              border: Border.all(
                                  color: const Color(0xFFFDE68A),
                                  width: 1.5),
                            ),
                            child: const Row(
                              children: [
                                Icon(Icons.hourglass_top_rounded,
                                    color: Color(0xFFD97706),
                                    size: 18),
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
                    color: const Color(0xFF10B981)
                        .withOpacity(_pulseOpacity.value * 0.2),
                    blurRadius: 16,
                    spreadRadius: 1,
                    offset: const Offset(0, 4),
                  ),
                ],
                border: Border.all(
                  color: const Color(0xFF10B981)
                      .withOpacity(0.3 + _pulseOpacity.value * 0.4),
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
            border: Border.all(
                color: color.withOpacity(0.15), width: 1.5),
          ),
          child: cardInner,
        );
      },
    );
  }

  // ─── Sección contenedores ──────────────────────────────────────────────────

  Widget _buildContenedoresSection() {
    final ids = ['contenedor-1', 'contenedor-2', 'contenedor-3'];
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        const Text(
          'Monitoreo de Contenedores',
          style: TextStyle(
            fontSize: 18,
            fontWeight: FontWeight.w800,
            color: Color(0xFF0F172A),
            letterSpacing: -0.5,
          ),
        ),
        const SizedBox(height: 14),
        ...ids.map((id) => _buildContenedorCard(id)),
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
              Icon(Icons.notification_important_rounded,
                  color: Color(0xFF2563EB), size: 20),
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
        const SizedBox(height: 24),
      ],
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
              const Text('Trabajador',
                  style: TextStyle(
                      color: Colors.white,
                      fontWeight: FontWeight.w800)),
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
                onPressed: () =>
                    Scaffold.of(context).openEndDrawer(),
              ),
            ),
          ],
        ),
        body: RefreshIndicator(
          color: const Color(0xFF059669),
          onRefresh: () async => await obtenerNombre(),
          child: ListView(
            physics: const AlwaysScrollableScrollPhysics(),
            padding: const EdgeInsets.all(16),
            children: [
              // Banner bienvenida
              Container(
                width: double.infinity,
                padding: const EdgeInsets.all(20),
                decoration: BoxDecoration(
                  gradient: const LinearGradient(
                    colors: [Color(0xFF065F46), Color(0xFF047857)],
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                  ),
                  borderRadius: BorderRadius.circular(24),
                  boxShadow: [
                    BoxShadow(
                      color:
                          const Color(0xFF059669).withOpacity(0.15),
                      blurRadius: 16,
                      offset: const Offset(0, 8),
                    ),
                  ],
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      isLoading
                          ? 'Cargando...'
                          : '¡Hola, $nombreUsuario!',
                      style: const TextStyle(
                        fontSize: 22,
                        fontWeight: FontWeight.w900,
                        color: Colors.white,
                        letterSpacing: -0.5,
                      ),
                    ),
                    const SizedBox(height: 6),
                    const Text(
                      'Administra el estado de los contenedores. Cuando un operador confirme la recogida verás su información aquí.',
                      style: TextStyle(
                        color: Color(0xFFD1FAE5),
                        fontSize: 12,
                        height: 1.4,
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
        ),
      ),
    );
  }
}

// ─── Widget recomendación ──────────────────────────────────────────────────────

class _RecomendacionItemTrabajador extends StatelessWidget {
  final IconData icon;
  final String texto;

  const _RecomendacionItemTrabajador(
      {required this.icon, required this.texto});

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