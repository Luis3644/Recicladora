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
import '../services/update_service.dart';
 

// ConnectionWrapper ya NO se importa aquí — se aplica globalmente desde main.dart

class OperadorScreen extends StatefulWidget {
  final String nombreUsuario;
 
  

  const OperadorScreen({super.key, required this.nombreUsuario});

  @override
  State<OperadorScreen> createState() => _OperadorScreenState();
}

class _OperadorScreenState extends State<OperadorScreen> {
  static const _primary  = Color(0xFF1E3A8A);
  static const _primary2 = Color(0xFF2563EB);
  static const _bg       = Color(0xFFF5F7FF);

  final FlutterLocalNotificationsPlugin _notificaciones =
      FlutterLocalNotificationsPlugin();
  bool _avisoMostrado = false;
  bool _modoDescanso = false;
  bool _cargandoModoDescanso = true;

  String _usuarioDocIdPreferido() {
    return FirebaseAuth.instance.currentUser?.uid ?? widget.nombreUsuario;
  }

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
          .showSnackBar(SnackBar(content: Text("Error al cerrar sesión: $e")));
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

  // ── initState ─────────────────────────────────────────────────────────────
  @override
  void initState() {
    super.initState();
    _cargarEstadoModoDescanso();
    _inicializarFlujoIngreso();
  }

  Future<void> _cargarEstadoModoDescanso() async {
    try {
      final doc = await FirebaseFirestore.instance
          .collection("usuarios")
          .doc(_usuarioDocIdPreferido())
          .get();
      if (doc.exists && mounted) {
        setState(() {
          _modoDescanso = doc.data()?["modo_descanso"] ?? false;
          _cargandoModoDescanso = false;
        });
      }
    } catch (e) {
      debugPrint("Error cargando modo descanso: $e");
      if (mounted) setState(() => _cargandoModoDescanso = false);
    }
  }

  Future<void> _toggleModoDescanso(bool valor) async {
    setState(() => _modoDescanso = valor);
    try {
      await FirebaseFirestore.instance
          .collection("usuarios")
          .doc(_usuarioDocIdPreferido())
          .set({"modo_descanso": valor}, SetOptions(merge: true));
      
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(valor 
              ? "Modo Descanso activado. Notificaciones silenciadas." 
              : "Modo Descanso desactivado."),
            backgroundColor: valor ? const Color(0xFF1E293B) : _primary,
            duration: const Duration(seconds: 2),
            behavior: SnackBarBehavior.floating,
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
          ),
        );
      }
    } catch (e) {
      debugPrint("Error guardando modo descanso: $e");
    }
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

  // ── Limpiar camiones si no hay jornada ────────────────────────────────────
  Future<void> _sanearCamionesDelOperadorSiNoHayJornada() async {
      final currentUser = FirebaseAuth.instance.currentUser;
      final refs = <DocumentReference<Map<String, dynamic>>>[];

      if (currentUser != null) {
        refs.add(FirebaseFirestore.instance.collection("usuarios").doc(currentUser.uid));
      }
      refs.add(FirebaseFirestore.instance.collection("usuarios").doc(widget.nombreUsuario));

      final docs = <DocumentSnapshot<Map<String, dynamic>>>[];
      for (final ref in refs) {
        final doc = await ref.get();
        if (doc.exists) docs.add(doc);
      }

      final tieneJornadaActiva = docs.any((doc) => doc.data()?['jornada_activa'] == true);
      if (tieneJornadaActiva) return;

    final camionesOcupados = await FirebaseFirestore.instance
        .collection("camiones")
        .where("operador", isEqualTo: widget.nombreUsuario)
        .get();
    for (final doc in camionesOcupados.docs) {
      await doc.reference.update({"ocupado": false, "operador": ""});
    }
  }

  Future<void> _recargarPanelOperador() async {
    await verificarJornada();
    if (!mounted) return;
    setState(() {});
  }

  // ── Verificar jornada activa → ir directo a JornadaScreen ─────────────────
  Future<bool> verificarJornada() async {
    final currentUser = FirebaseAuth.instance.currentUser;
    final usuarioDocs = <DocumentSnapshot<Map<String, dynamic>>>[];

    if (currentUser != null) {
      final porUid = await FirebaseFirestore.instance
          .collection("usuarios")
          .doc(currentUser.uid)
          .get();
      if (porUid.exists) usuarioDocs.add(porUid);
    }

    final porNombre = await FirebaseFirestore.instance
        .collection("usuarios")
        .doc(widget.nombreUsuario)
        .get();
    if (porNombre.exists) usuarioDocs.add(porNombre);

    if (usuarioDocs.isEmpty) return false;

    final doc = usuarioDocs.firstWhere(
      (d) => d.data()?['jornada_activa'] == true,
      orElse: () => usuarioDocs.first,
    );

    final jornadaActiva = doc.data()?["jornada_activa"] ?? false;
    if (!jornadaActiva) return false;

    final camion = doc.data()?["camion_actual"] ?? "";
    final placas = doc.data()?["placas_actuales"] ?? "S/P";

    if (currentUser != null && doc.id != currentUser.uid) {
      final uidRef = FirebaseFirestore.instance
          .collection('usuarios')
          .doc(currentUser.uid);
      await uidRef.set({
        'nombre': doc.data()?['nombre']?.toString() ?? widget.nombreUsuario,
        'jornada_activa': true,
        'camion_id': doc.data()?['camion_id'] ?? '',
        'camion_actual': doc.data()?['camion_actual'] ?? '',
        'placas_actuales': doc.data()?['placas_actuales'] ?? '',
      }, SetOptions(merge: true));
    }

    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      Navigator.pushAndRemoveUntil(         // limpia TODO el historial
        context,
        MaterialPageRoute(
          builder: (_) => JornadaScreen(
            operador: widget.nombreUsuario,
            camion: camion,
            placas: placas,
          ),
        ),
        (route) => false,
      );
    });
    return true;
  }

  // ── Notificación EPP ──────────────────────────────────────────────────────
  Future<void> _mostrarNotificacionEpp() async {
    try {
      const androidInit = AndroidInitializationSettings('@mipmap/ic_launcher');
      const iosInit = DarwinInitializationSettings(
        requestAlertPermission: false,
        requestBadgePermission: false,
        requestSoundPermission: false,
      );
      await _notificaciones.initialize(
          const InitializationSettings(android: androidInit, iOS: iosInit));

      await _notificaciones
          .resolvePlatformSpecificImplementation<
              AndroidFlutterLocalNotificationsPlugin>()
          ?.requestNotificationsPermission();
      await _notificaciones
          .resolvePlatformSpecificImplementation<
              IOSFlutterLocalNotificationsPlugin>()
          ?.requestPermissions(alert: true, badge: true, sound: true);

      await _notificaciones.show(
        1001,
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

  // ── Seleccionar camión ────────────────────────────────────────────────────
  Future<void> seleccionarCamion(
    String camionId,
    String tipoCamion,
    String placasRecibidas,
  ) async {
    try {
      final currentUser = FirebaseAuth.instance.currentUser;
      final usuarioRef = FirebaseFirestore.instance
          .collection("usuarios")
          .doc(currentUser?.uid ?? widget.nombreUsuario);

      await FirebaseFirestore.instance
          .collection("camiones")
          .doc(camionId)
          .update({"ocupado": true, "operador": widget.nombreUsuario});

      await usuarioRef.set({
        "nombre": widget.nombreUsuario,
        "jornada_activa": true,
        "camion_id": camionId,
        "camion_actual": tipoCamion,
        "placas_actuales": placasRecibidas,
      }, SetOptions(merge: true));

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
      ScaffoldMessenger.of(context)
          .showSnackBar(SnackBar(content: Text("Error: $e")));
    }
  }

  // ── Build ─────────────────────────────────────────────────────────────────
  // NOTA: ConnectionWrapper se quitó de aquí.
  // Ahora vive en main.dart envolviendo OperadorScreen globalmente,
  // así TODAS las pantallas del operador quedan cubiertas sin tocar cada una.
  @override
  Widget build(BuildContext context) {
    final nombre = widget.nombreUsuario;

    return Scaffold(
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
              leading: const Icon(Icons.system_update, color: _primary2),
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
            ListTile(
              leading: const Icon(Icons.logout_rounded, color: _primary),
              title: const Text(
                "Cerrar sesión",
                style: TextStyle(fontWeight: FontWeight.w700),
              ),
              subtitle: const Text("Volver a la pantalla de inicio"),
              onTap: () async {
                Navigator.of(context).pop();
                await _confirmarYCerrarSesion();
              },
            ),

            // Sesiones UI removed per UX request; session logic unchanged.

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
                        "Selecciona el camión que operarás hoy. Solo se muestran  camiones activos y disponibles.",
                        style: TextStyle(color: Colors.white70, height: 1.25),
                      ),
                    ],
                  ),
                ),
              ),
              SliverToBoxAdapter(
                child: Padding(
                  padding: const EdgeInsets.fromLTRB(16, 16, 16, 0),
                  child: Container(
                    padding: const EdgeInsets.all(16),
                    decoration: BoxDecoration(
                      color: _modoDescanso ? const Color(0xFFF1F5F9) : Colors.white,
                      borderRadius: BorderRadius.circular(20),
                      border: Border.all(
                        color: _modoDescanso ? const Color(0xFFCBD5E1) : const Color(0xFFE2E8F0),
                        width: 1.5,
                      ),
                      boxShadow: [
                        BoxShadow(
                          color: Colors.black.withOpacity(0.03),
                          blurRadius: 10,
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
                                color: (_modoDescanso ? Colors.blueGrey : _primary).withOpacity(0.1),
                                shape: BoxShape.circle,
                              ),
                              child: Icon(
                                _modoDescanso ? Icons.nightlight_round : Icons.notifications_active_rounded,
                                color: _modoDescanso ? Colors.blueGrey : _primary,
                                size: 22,
                              ),
                            ),
                            const SizedBox(width: 12),
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(
                                    "Modo Descanso",
                                    style: TextStyle(
                                      fontSize: 16,
                                      fontWeight: FontWeight.w800,
                                      color: _modoDescanso ? Colors.blueGrey[700] : _primary,
                                    ),
                                  ),
                                  Text(
                                    _modoDescanso ? "Activado · No molestar" : "Desactivado",
                                    style: TextStyle(
                                      fontSize: 12,
                                      fontWeight: FontWeight.w600,
                                      color: _modoDescanso ? Colors.blueGrey[400] : Colors.grey[500],
                                    ),
                                  ),
                                ],
                              ),
                            ),
                            _cargandoModoDescanso
                                ? const SizedBox(
                                    width: 24,
                                    height: 24,
                                    child: CircularProgressIndicator(strokeWidth: 2),
                                  )
                                : Switch.adaptive(
                                    value: _modoDescanso,
                                    onChanged: _toggleModoDescanso,
                                    activeColor: _primary2,
                                  ),
                          ],
                        ),
                        const SizedBox(height: 12),
                        const Divider(height: 1),
                        const SizedBox(height: 12),
                        Row(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Icon(Icons.info_outline_rounded, size: 14, color: Colors.grey[500]),
                            const SizedBox(width: 6),
                            const Expanded(
                              child: Text(
                                "Activa este modo fuera de tu horario laboral para silenciar las notificaciones y alertas de la aplicación, permitiéndote descansar sin interrupciones.",
                                style: TextStyle(
                                  fontSize: 11,
                                  color: Color(0xFF64748B),
                                  height: 1.3,
                                ),
                              ),
                            ),
                          ],
                        ),
                      ],
                    ),
                  ),
                ),
              ),
              SliverPadding(
                padding: const EdgeInsets.fromLTRB(16, 16, 16, 18),
                sliver: StreamBuilder<QuerySnapshot>(
                  stream: FirebaseFirestore.instance
                      .collection("camiones")
                      .where("ocupado", isEqualTo: false)
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
                              Icon(Icons.local_shipping_outlined,
                                  size: 56, color: Color(0xFF1E3A8A)),
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
                        final data =
                            camiones[index].data() as Map<String, dynamic>;
                        final tipo = (data["tipo"] ?? "Camión").toString();
                        final placas = (data["placas"] ?? "").toString();
                        final estado = data["estado"] ?? "Disponible";
                        final disponible = estado == "Disponible";

                        return InkWell(
                          borderRadius: BorderRadius.circular(18),
                          onTap: disponible
                              ? () async {
                                  // Si el modo descanso está activo, lo desactivamos automáticamente al iniciar jornada
                                  if (_modoDescanso) {
                                    await _toggleModoDescanso(false);
                                  }
                                  if (!mounted) return;
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
                                            ? "Este camión está en mantenimiento."
                                            : "Este camión está fuera de servicio.",
                                      ),
                                    ),
                                  );
                                },
                          child: Container(
                            decoration: BoxDecoration(
                              color: disponible
                                  ? Colors.white
                                  : Colors.grey[100],
                              borderRadius: BorderRadius.circular(18),
                              border: Border.all(
                                color: disponible
                                    ? const Color(0xFFE6ECFF)
                                    : Colors.grey.shade300,
                              ),
                              boxShadow: [
                                BoxShadow(
                                  color: Colors.black
                                      .withOpacity(disponible ? 0.06 : 0.03),
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
                                            colors: [
                                              Colors.grey,
                                              Colors.grey
                                            ],
                                          ),
                                    borderRadius: BorderRadius.circular(16),
                                  ),
                                  child: Icon(
                                    Icons.local_shipping_rounded,
                                    color: disponible
                                        ? Colors.white
                                        : Colors.grey[600],
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
                                          color: disponible
                                              ? const Color(0xFF0F172A)
                                              : Colors.grey[600],
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
                                          color: disponible
                                              ? const Color(0xFF475569)
                                              : Colors.grey[500],
                                          height: 1.1,
                                        ),
                                      ),
                                    ],
                                  ),
                                ),
                                const SizedBox(width: 8),
                                Container(
                                  padding: const EdgeInsets.symmetric(
                                      horizontal: 10, vertical: 6),
                                  decoration: BoxDecoration(
                                    color: _getEstadoColor(estado)
                                        .withOpacity(0.15),
                                    borderRadius: BorderRadius.circular(999),
                                    border: Border.all(
                                      color: _getEstadoColor(estado)
                                          .withOpacity(0.3),
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
                                  disponible
                                      ? Icons.chevron_right_rounded
                                      : Icons.block_rounded,
                                  color: disponible
                                      ? const Color(0xFF94A3B8)
                                      : Colors.grey[400],
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
    case 'Disponible':      return const Color(0xFF10B981);
    case 'En Mantenimiento': return const Color(0xFFF59E0B);
    case 'Fuera de Servicio': return const Color(0xFFDC2626);
    default:                return const Color(0xFF1D4ED8);
  }
}