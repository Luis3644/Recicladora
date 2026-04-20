import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import '../config/session_manager.dart';
import 'checklist_screen.dart';
import 'jornada_screen.dart';
import 'confirmar_camion_screen.dart';
import 'login_screen.dart';
import 'widgets/notificaciones_drawer.dart';
import 'widgets_conexion/connection_wrapper.dart';

class OperadorScreen extends StatefulWidget {
  final String nombreUsuario;

  const OperadorScreen({super.key, required this.nombreUsuario});

  @override
  State<OperadorScreen> createState() => _OperadorScreenState();
}

class _OperadorScreenState extends State<OperadorScreen> {
  static const _primary = Color(0xFF1E3A8A); // azul oscuro
  static const _primary2 = Color(0xFF2563EB); // azul
  static const _bg = Color(0xFFF5F7FF); // fondo azul muy claro
  final FlutterLocalNotificationsPlugin _notificaciones =
      FlutterLocalNotificationsPlugin();
  bool _avisoMostrado = false;

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
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text("Error al cerrar sesión: $e")));
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

  @override
  void initState() {
    super.initState();
    _inicializarFlujoIngreso();
  }

  Future<void> _inicializarFlujoIngreso() async {
    await _sanearCamionesDelOperadorSiNoHayJornada();

    final redirigido = await verificarJornada();

    if (!mounted || redirigido || _avisoMostrado) return;

    _avisoMostrado = true;
    await _mostrarNotificacionEpp();

    if (!mounted) return;

    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      _mostrarDialogoRecomendaciones();
    });
  }

  Future<void> _sanearCamionesDelOperadorSiNoHayJornada() async {
    final userRef = FirebaseFirestore.instance
        .collection("usuarios")
        .doc(widget.nombreUsuario);
    final userDoc = await userRef.get();
    if (!userDoc.exists) return;

    final data = userDoc.data() ?? <String, dynamic>{};
    final jornadaActiva = data["jornada_activa"] == true;
    if (jornadaActiva) return;

    final camionesOcupados = await FirebaseFirestore.instance
        .collection("camiones")
        .where("operador", isEqualTo: widget.nombreUsuario)
        .get();

    for (final doc in camionesOcupados.docs) {
      await doc.reference.update({"ocupado": false, "operador": ""});
    }

    if ((data["camion_actual"] ?? "").toString().isNotEmpty ||
        (data["placas_actuales"] ?? "").toString().isNotEmpty ||
        (data["camion_id"] ?? "").toString().isNotEmpty) {
      await userRef.set({
        "camion_actual": "",
        "placas_actuales": "",
        "camion_id": "",
      }, SetOptions(merge: true));
    }
  }

  Future<void> _recargarPanelOperador() async {
    await verificarJornada();
    if (!mounted) return;
    setState(() {});
  }

  Future<bool> verificarJornada() async {
    var doc = await FirebaseFirestore.instance
        .collection("usuarios")
        .doc(widget.nombreUsuario)
        .get();

    if (!doc.exists) return false;

    bool jornadaActiva = doc.data()?["jornada_activa"] ?? false;

    if (jornadaActiva) {
      String camion = doc.data()?["camion_actual"] ?? "";
      String placas = doc.data()?["placas_actuales"] ?? "S/P";

      WidgetsBinding.instance.addPostFrameCallback((_) {
  if (!mounted) return;
  Navigator.pushAndRemoveUntil(
    context,
    MaterialPageRoute(
      builder: (_) => JornadaScreen(
        operador: widget.nombreUsuario,
        camion: camion,
        placas: placas,
      ),
    ),
    (route) => false, // elimina TODO el historial
  );
});

      return true;
    }

    return false;
  }

  Future<void> _mostrarNotificacionEpp() async {
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
      const iosDetails = DarwinNotificationDetails();

      const details = NotificationDetails(
        android: androidDetails,
        iOS: iosDetails,
      );

      await _notificaciones.show(
        1001,
        'Seguridad en planta',
        'Recordatorio Usa cubrebocas, guantes y el uniforme',
        details,
      );
    } catch (e) {
      debugPrint('No se pudo mostrar la notificación: $e');
    }
  }

  Future<void> _mostrarDialogoRecomendaciones() async {
    await showDialog<void>(
      context: context,
      builder: (_) => AlertDialog(
        title: const Row(
          children: [
            Icon(Icons.health_and_safety_rounded, color: _primary),
            SizedBox(width: 8),
            Expanded(child: Text('Recomendaciones de seguridad')),
          ],
        ),
        content: const SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              _RecomendacionItem(
                icon: Icons.back_hand_outlined,
                texto: 'Usa guantes resistentes para manipular vidrio.',
              ),
              SizedBox(height: 8),
              _RecomendacionItem(
                icon: Icons.visibility_outlined,
                texto: 'Porta lentes de seguridad para evitar lesiones.',
              ),
              SizedBox(height: 8),
              _RecomendacionItem(
                icon: Icons.hiking_outlined,
                texto: 'Utiliza cubrebocas en todo momento.',
              ),
              SizedBox(height: 8),
              _RecomendacionItem(
                icon: Icons.construction_outlined,
                texto: 'Usa el uniforme para mayor seguridad.',
              ),
              SizedBox(height: 8),
              _RecomendacionItem(
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

  Future<void> seleccionarCamion(
    String camionId,
    String tipoCamion,
    String placasRecibidas,
  ) async {
    try {
      /// marcar camion ocupado
      await FirebaseFirestore.instance
          .collection("camiones")
          .doc(camionId)
          .update({"ocupado": true, "operador": widget.nombreUsuario});

      /// guardar jornada activa del usuario
      await FirebaseFirestore.instance
          .collection("usuarios")
          .doc(widget.nombreUsuario)
          .set({
            "nombre": widget.nombreUsuario,
            "jornada_activa": true,
            "camion_id": camionId,
            "camion_actual": tipoCamion,
            "placas_actuales": placasRecibidas,
          }, SetOptions(merge: true));

      /// ir al checklist
      if (!mounted) return;

      Navigator.push(
        context,
        MaterialPageRoute(
          builder: (_) => ChecklistScreen(
            nombreUsuario: widget.nombreUsuario,
            camionId: camionId,
            camion: tipoCamion,
            placas: placasRecibidas,
          ),
        ),
      );
    } catch (e) {
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text("Error: $e")));
    }
  }

  @override
  Widget build(BuildContext context) {
    final nombre = widget.nombreUsuario;
    return ConnectionWrapper(
      child: Scaffold(
        backgroundColor: _bg,
        drawer: Drawer(
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
                          widget.nombreUsuario,
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
                leading: const Icon(Icons.logout_rounded, color: _primary),
                title: const Text(
                  "Cerrar sesión",
                  style: TextStyle(fontWeight: FontWeight.w700),
                ),
                subtitle: const Text("Volver a la pantalla de inicio"),
                onTap: () async {
                  Navigator.of(context).pop(); // cerrar drawer
                  await _confirmarYCerrarSesion();
                },
              ),
              const Spacer(),
              const Padding(
                padding: EdgeInsets.all(16),
                child: Text(
                  "Recicladora",
                  style: TextStyle(color: Color(0xFF94A3B8)),
                ),
              ),
            ],
          ),
        ),
        endDrawer: NotificacionesDrawer(
          rolUsuario: 'operador',
          nombreUsuario: widget.nombreUsuario,
        ),
        appBar: AppBar(
          elevation: 0,
          backgroundColor: Colors.transparent,
          foregroundColor: Colors.white,
          centerTitle: false,
          title: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Text(
                "Operador",
                style: TextStyle(fontWeight: FontWeight.w700),
              ),
              const SizedBox(width: 10),
              ClipRRect(
                borderRadius: BorderRadius.circular(10),
                child: Image.asset(
                  'assets/logo circular.jpeg',
                  height: 42,
                  width: 42,
                  fit: BoxFit.cover,
                ),
              ),
            ],
          ),
          flexibleSpace: Container(
            decoration: const BoxDecoration(
              gradient: LinearGradient(
                colors: [_primary, _primary2],
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
              ),
            ),
          ),
          actions: [
            Builder(
              builder: (context) => NotificacionesBellButton(
                rolUsuario: 'operador',
                nombreUsuario: widget.nombreUsuario,
                onPressed: () => Scaffold.of(context).openEndDrawer(),
              ),
            ),
          ],
        ),
        body: SafeArea(
          top: false,
          child: RefreshIndicator(
            onRefresh: _recargarPanelOperador,
            child: CustomScrollView(
              physics: const AlwaysScrollableScrollPhysics(),
              slivers: [
                SliverToBoxAdapter(
                  child: Container(
                    decoration: const BoxDecoration(
                      gradient: LinearGradient(
                        colors: [_primary, _primary2],
                        begin: Alignment.topLeft,
                        end: Alignment.bottomRight,
                      ),
                      borderRadius: BorderRadius.only(
                        bottomLeft: Radius.circular(22),
                        bottomRight: Radius.circular(22),
                      ),
                    ),
                    padding: const EdgeInsets.fromLTRB(16, 8, 16, 18),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          "Hola, $nombre",
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: const TextStyle(
                            color: Colors.white,
                            fontSize: 22,
                            fontWeight: FontWeight.w800,
                            letterSpacing: 0.2,
                          ),
                        ),
                        const SizedBox(height: 6),
                        const Text(
                          "Selecciona el camión que operarás hoy. Solo se muestran camiones activos y disponibles.",
                          style: TextStyle(color: Colors.white70, height: 1.25),
                        ),
                      ],
                    ),
                  ),
                ),
                SliverPadding(
                  padding: const EdgeInsets.fromLTRB(16, 16, 16, 18),
                  sliver: StreamBuilder<QuerySnapshot>(
                    stream: FirebaseFirestore.instance
                        .collection("camiones")
                        .where("ocupado", isEqualTo: false) // Quitar .where("activo", isEqualTo: true)
                        .snapshots(),
                    builder: (context, snapshot) {
                      if (snapshot.connectionState == ConnectionState.waiting) {
                        return const SliverFillRemaining(
                          hasScrollBody: false,
                          child: Center(child: CircularProgressIndicator()),
                        );
                      }

                      if (!snapshot.hasData || snapshot.data!.docs.isEmpty) {
                        return const SliverFillRemaining(
                          hasScrollBody: false,
                          child: Center(
                            child: Column(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                Icon(
                                  Icons.local_shipping_outlined,
                                  size: 56,
                                  color: Color(0xFF1E3A8A),
                                ),
                                SizedBox(height: 12),
                                Text(
                                  "No hay camiones disponibles",
                                  style: TextStyle(
                                    fontSize: 18,
                                    fontWeight: FontWeight.w700,
                                    color: Color(0xFF0F172A),
                                  ),
                                ),
                                SizedBox(height: 6),
                                Text(
                                  "Intenta más tarde o consulta con administración.",
                                  style: TextStyle(color: Color(0xFF475569)),
                                  textAlign: TextAlign.center,
                                ),
                              ],
                            ),
                          ),
                        );
                      }

                      final camiones = snapshot.data!.docs;

                      return SliverList.separated(
                        itemCount: camiones.length,
                        separatorBuilder: (_, __) => const SizedBox(height: 12),
                        itemBuilder: (context, index) {
                          final data = camiones[index].data() as Map<String, dynamic>;
                          final tipo = (data["tipo"] ?? "Camión").toString();
                          final placas = (data["placas"] ?? "").toString();
                          final estado = data["estado"] ?? "Disponible";
                          final disponible = estado == "Disponible";

                          return InkWell(
                            borderRadius: BorderRadius.circular(18),
                            onTap: disponible
                                ? () {
                                    Navigator.push(
                                      context,
                                      MaterialPageRoute(
                                        builder: (_) => ConfirmarCamionScreen(
                                          operador: widget.nombreUsuario,
                                          camionId: camiones[index].id,
                                          tipo: data["tipo"],
                                          foto: data["foto"],
                                          placas: data["placas"] ?? "S/P",
                                          modelo: data['modelo'] ?? "N/A",
                                        ),
                                      ),
                                    );
                                  }
                                : () {
                                    ScaffoldMessenger.of(context).showSnackBar(
                                      SnackBar(
                                        content: Text(
                                          estado == "En Mantenimiento"
                                              ? "Este camión está en mantenimiento y no se puede seleccionar."
                                              : "Este camión está fuera de servicio y no se puede seleccionar.",
                                        ),
                                      ),
                                    );
                                  },
                            child: Container(
                              decoration: BoxDecoration(
                                color: disponible ? Colors.white : Colors.grey[100], // Gris si no disponible
                                borderRadius: BorderRadius.circular(18),
                                border: Border.all(
                                  color: disponible ? const Color(0xFFE6ECFF) : Colors.grey.shade300,
                                ),
                                boxShadow: [
                                  BoxShadow(
                                    color: Colors.black.withOpacity(disponible ? 0.06 : 0.03),
                                    blurRadius: 18,
                                    offset: const Offset(0, 10),
                                  ),
                                ],
                              ),
                              padding: const EdgeInsets.all(14),
                              child: Row(
                                children: [
                                  Container(
                                    width: 52,
                                    height: 52,
                                    decoration: BoxDecoration(
                                      gradient: disponible
                                          ? const LinearGradient(
                                              colors: [_primary, _primary2],
                                              begin: Alignment.topLeft,
                                              end: Alignment.bottomRight,
                                            )
                                          : const LinearGradient(
                                              colors: [Colors.grey, Colors.grey],
                                            ),
                                      borderRadius: BorderRadius.circular(16),
                                    ),
                                    child: Icon(
                                      Icons.local_shipping_rounded,
                                      color: disponible ? Colors.white : Colors.grey[600],
                                      size: 28,
                                    ),
                                  ),
                                  const SizedBox(width: 12),
                                  Expanded(
                                    child: Column(
                                      crossAxisAlignment:
                                          CrossAxisAlignment.start,
                                      children: [
                                        Text(
                                          tipo,
                                          maxLines: 1,
                                          overflow: TextOverflow.ellipsis,
                                          style: TextStyle(
                                            fontSize: 18,
                                            fontWeight: FontWeight.w800,
                                            color: disponible ? const Color(0xFF0F172A) : Colors.grey[600],
                                          ),
                                        ),
                                        const SizedBox(height: 4),
                                        Text(
                                          placas.isEmpty
                                              ? "Sin placas registradas"
                                              : "Placas: $placas",
                                          maxLines: 1,
                                          overflow: TextOverflow.ellipsis,
                                          style: TextStyle(
                                            fontSize: 14,
                                            color: disponible ? const Color(0xFF475569) : Colors.grey[500],
                                            height: 1.1,
                                          ),
                                        ),
                                      ],
                                    ),
                                  ),
                                  const SizedBox(width: 8),
                                  Container(
                                    padding: const EdgeInsets.symmetric(
                                      horizontal: 10,
                                      vertical: 6,
                                    ),
                                    decoration: BoxDecoration(
                                      color: _getEstadoColor(estado).withOpacity(0.15),
                                      borderRadius: BorderRadius.circular(999),
                                      border: Border.all(
                                        color: _getEstadoColor(estado).withOpacity(0.3),
                                      ),
                                    ),
                                    child: Text(
                                      estado,
                                      style: TextStyle(
                                        color: _getEstadoColor(estado),
                                        fontWeight: FontWeight.w700,
                                        fontSize: 12,
                                      ),
                                    ),
                                  ),
                                  const SizedBox(width: 6),
                                  Icon(
                                    disponible ? Icons.chevron_right_rounded : Icons.block_rounded,
                                    color: disponible ? const Color(0xFF94A3B8) : Colors.grey[400],
                                    size: 26,
                                  ),
                                ],
                              ),
                            ),
                          );
                        },
                      );
                    },
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _RecomendacionItem extends StatelessWidget {
  final IconData icon;
  final String texto;

  const _RecomendacionItem({required this.icon, required this.texto});

  @override
  Widget build(BuildContext context) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Icon(icon, size: 20, color: _OperadorScreenState._primary),
        const SizedBox(width: 8),
        Expanded(child: Text(texto, style: const TextStyle(height: 1.25))),
      ],
    );
  }
}

Color _getEstadoColor(String estado) {
  switch (estado) {
    case 'Disponible':
      return const Color(0xFF10B981); // verde
    case 'En Mantenimiento':
      return const Color(0xFFF59E0B); // amarillo
    case 'Fuera de Servicio':
      return const Color(0xFFDC2626); // rojo
    default:
      return const Color(0xFF1D4ED8); // azul
  }
}
