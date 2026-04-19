import 'dart:async';

import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:geolocator/geolocator.dart';
import 'package:intl/intl.dart';
import 'operador_screen.dart';
import 'reporte_screen.dart'; // Asegúrate de que esta línea esté presente
import 'widgets_conexion/connection_wrapper.dart';
import 'widgets/menu_lateral.dart';
import 'widgets/notificaciones_drawer.dart';
import 'package:intl/intl.dart';

class JornadaScreen extends StatefulWidget {
  final String operador;
  final String camion;
  final String placas;

  const JornadaScreen({
    super.key,
    required this.operador,
    required this.camion,
    required this.placas,
  });

  @override
  State<JornadaScreen> createState() => _JornadaScreenState();
}

class _JornadaScreenState extends State<JornadaScreen> {
  final TextEditingController toneladasController = TextEditingController();
  final TextEditingController gasolinaController = TextEditingController();

  // Controllers para formulario de gasolina
  final TextEditingController folioGasolinaController = TextEditingController();
  final TextEditingController cantidadGasolinaController =
      TextEditingController();
  final TextEditingController montoGasolinaController = TextEditingController();

  // Controllers para toneladas
  final TextEditingController folioToneladaController = TextEditingController();
  final TextEditingController cantidadToneladaController =
      TextEditingController();

  final FlutterLocalNotificationsPlugin _notificaciones =
      FlutterLocalNotificationsPlugin();

  StreamSubscription<Position>? _posicionSub;
  StreamSubscription<ServiceStatus>? _servicioSub;

  bool _contentVisible = false;
  bool _compartirUbicacion = true;
  bool _compartiendoUbicacionActiva = false;
  bool _permisoUbicacionOtorgado = false;
  bool _servicioUbicacionActivo = false;
  bool _alertaUbicacionMostrada = false;
  bool _finalizandoJornada = false;
  String _estadoUbicacion = 'Iniciando ubicación...';
  String _conceptoGasolina = 'gasolina';
  String _unidadGasolina = 'litros';
  String _metodoPagoGasolina = 'efectivo';

  static const Color _primary = Color(0xFF0F172A);
  static const Color _accent = Color(0xFF06B6D4);
  static const Color _success = Color(0xFF10B981);
  static const Color _danger = Color(0xFFDC2626);

  @override
  void initState() {
    super.initState();
    _inicializarNotificacionesUbicacion();
    _iniciarMonitoreoUbicacion();
    _escucharCambiosServicioUbicacion();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      setState(() => _contentVisible = true);
    });
  }

  @override
  void dispose() {
    _posicionSub?.cancel();
    _servicioSub?.cancel();
    toneladasController.dispose();
    gasolinaController.dispose();
    folioGasolinaController.dispose();
    cantidadGasolinaController.dispose();
    montoGasolinaController.dispose();
    folioToneladaController.dispose();
    cantidadToneladaController.dispose();
    super.dispose();
  }

  String _formatearFecha(DateTime fecha) {
    return DateFormat('dd/MM/yyyy HH:mm').format(fecha);
  }

  Future<void> _abrirRegistroGasolina() async {
    await Navigator.of(context).push(
      MaterialPageRoute(
        builder: (_) => RegistroGasolinaScreen(
          operador: widget.operador,
          camion: widget.camion,
          placas: widget.placas,
        ),
      ),
    );
  }

  Future<void> _abrirRegistroToneladas() async {
    await Navigator.of(context).push(
      MaterialPageRoute(
        builder: (_) => RegistroToneladasScreen(
          operador: widget.operador,
          camion: widget.camion,
          placas: widget.placas,
        ),
      ),
    );
  }

  Future<void> _finalizarPorSwipe() async {
    if (_finalizandoJornada) return;

    setState(() {
      _finalizandoJornada = true;
    });
    await finalizarJornada();
  }

  Future<bool> _confirmarAccion({
    required String titulo,
    required String mensaje,
    required String textoConfirmar,
  }) async {
    final confirmar = await showDialog<bool>(
      context: context,
      builder: (_) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: Text(
          titulo,
          style: const TextStyle(fontWeight: FontWeight.w700),
        ),
        content: Text(mensaje),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(false),
            child: const Text('Cancelar'),
          ),
          FilledButton(
            onPressed: () => Navigator.of(context).pop(true),
            child: Text(textoConfirmar),
          ),
        ],
      ),
    );

    return confirmar ?? false;
  }

  void _limpiarFormularioGasolina() {
    folioGasolinaController.clear();
    cantidadGasolinaController.clear();
    montoGasolinaController.clear();
    setState(() {
      _conceptoGasolina = 'gasolina';
      _unidadGasolina = 'litros';
      _metodoPagoGasolina = 'efectivo';
    });
  }

  Future<void> _registrarGasolina() async {
    final folio = folioGasolinaController.text.trim();
    final cantidad = double.tryParse(
      cantidadGasolinaController.text.trim().replaceAll(',', '.'),
    );
    final monto = double.tryParse(
      montoGasolinaController.text.trim().replaceAll(',', '.'),
    );

    if (folio.isEmpty || cantidad == null || monto == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Completa folio, cantidad y monto correctamente.'),
        ),
      );
      return;
    }

    final confirmar = await _confirmarAccion(
      titulo: 'Confirmar registro de gasolina',
      mensaje:
          '¿Estás seguro de guardar este registro de gasolina? Una vez guardado quedará en el historial.',
      textoConfirmar: 'REGISTRAR',
    );

    if (!confirmar) return;

    final fechaActual = DateTime.now();

    await FirebaseFirestore.instance.collection('registros_gasolina').add({
      'tipo_registro': 'gasolina',
      'fecha': fechaActual,
      'fecha_texto': _formatearFecha(fechaActual),
      'folio': folio,
      'concepto': _conceptoGasolina,
      'automovil': widget.camion,
      'placas': widget.placas,
      'cantidad': cantidad,
      'unidad': _unidadGasolina,
      'monto': monto,
      'metodo_pago': _metodoPagoGasolina,
      'operador': widget.operador,
      'camion': widget.camion,
      'creadoEn': FieldValue.serverTimestamp(),
    });

    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text('Registro de gasolina guardado')),
    );
    _limpiarFormularioGasolina();
  }

  Future<void> _cancelarRegistroGasolina() async {
    final confirmar = await _confirmarAccion(
      titulo: 'Cancelar registro',
      mensaje:
          '¿Estás seguro de cancelar? Se perderán los datos capturados en este registro de gasolina.',
      textoConfirmar: 'CANCELAR',
    );

    if (!confirmar) return;

    _limpiarFormularioGasolina();
    if (!mounted) return;
    ScaffoldMessenger.of(
      context,
    ).showSnackBar(const SnackBar(content: Text('Registro cancelado')));
  }

  Future<void> _inicializarNotificacionesUbicacion() async {
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
    } catch (_) {}
  }

  Future<void> _actualizarGpsEnFirestore({
    required bool gpsActivo,
    Position? posicion,
    String? estado,
  }) async {
    final data = <String, dynamic>{
      'gps_activo': gpsActivo,
      'ultima_actualizacion_gps': FieldValue.serverTimestamp(),
      if (estado != null) 'estado_gps': estado,
    };

    if (posicion != null) {
      data.addAll({
        'latitud': posicion.latitude,
        'longitud': posicion.longitude,
        'ubicacion_actual': GeoPoint(posicion.latitude, posicion.longitude),
      });
    }

    await FirebaseFirestore.instance
        .collection('usuarios')
        .doc(widget.operador)
        .set(data, SetOptions(merge: true));
  }

  Future<void> _mostrarAlertaUbicacionApagada(String motivo) async {
    if (_alertaUbicacionMostrada) return;
    _alertaUbicacionMostrada = true;

    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          backgroundColor: _danger,
          content: Text('Alerta de ubicación: $motivo'),
        ),
      );
    }

    try {
      const details = NotificationDetails(
        android: AndroidNotificationDetails(
          'ubicacion_alertas',
          'Alertas de ubicación',
          channelDescription: 'Alertas cuando la ubicación está desactivada',
          importance: Importance.high,
          priority: Priority.high,
        ),
        iOS: DarwinNotificationDetails(),
      );

      await _notificaciones.show(
        3001,
        'Ubicación desactivada',
        motivo,
        details,
      );
    } catch (_) {}
  }

  void _limpiarAlertaUbicacion() {
    _alertaUbicacionMostrada = false;
  }

  Future<void> _detenerMonitoreoUbicacion({String? motivo}) async {
    await _posicionSub?.cancel();
    _posicionSub = null;

    setState(() {
      _compartiendoUbicacionActiva = false;
      _estadoUbicacion = motivo ?? 'Compartición detenida';
    });

    await _actualizarGpsEnFirestore(gpsActivo: false, estado: _estadoUbicacion);
  }

  Future<void> _iniciarMonitoreoUbicacion() async {
    if (!_compartirUbicacion) {
      await _detenerMonitoreoUbicacion(
        motivo: 'Compartición manualmente desactivada',
      );
      return;
    }

    final servicioActivo = await Geolocator.isLocationServiceEnabled();
    _servicioUbicacionActivo = servicioActivo;

    if (!servicioActivo) {
      await _detenerMonitoreoUbicacion(motivo: 'GPS del dispositivo apagado');
      await _mostrarAlertaUbicacionApagada(
        'Activa la ubicación del celular para compartir tu posición con administración.',
      );
      return;
    }

    var permiso = await Geolocator.checkPermission();
    if (permiso == LocationPermission.denied) {
      permiso = await Geolocator.requestPermission();
    }

    if (permiso == LocationPermission.denied ||
        permiso == LocationPermission.deniedForever) {
      _permisoUbicacionOtorgado = false;
      await _detenerMonitoreoUbicacion(motivo: 'Sin permiso de ubicación');
      await _mostrarAlertaUbicacionApagada(
        'Permiso de ubicación denegado. Habilítalo para monitoreo en tiempo real.',
      );
      return;
    }

    _permisoUbicacionOtorgado = true;
    _limpiarAlertaUbicacion();

    await _posicionSub?.cancel();
    _posicionSub =
        Geolocator.getPositionStream(
          locationSettings: const LocationSettings(
            accuracy: LocationAccuracy.bestForNavigation,
            distanceFilter: 10,
          ),
        ).listen(
          (position) async {
            if (!mounted) return;
            setState(() {
              _compartiendoUbicacionActiva = true;
              _estadoUbicacion = 'Compartiendo ubicación activa';
            });

            await _actualizarGpsEnFirestore(
              gpsActivo: true,
              posicion: position,
              estado: _estadoUbicacion,
            );
          },
          onError: (_) async {
            await _detenerMonitoreoUbicacion(motivo: 'Error leyendo ubicación');
          },
        );
  }

  void _escucharCambiosServicioUbicacion() {
    if (kIsWeb) {
      // En web geolocator no soporta getServiceStatusStream.
      return;
    }

    _servicioSub = Geolocator.getServiceStatusStream().listen((status) async {
      final activo = status == ServiceStatus.enabled;
      if (!mounted) return;

      setState(() {
        _servicioUbicacionActivo = activo;
      });

      if (!activo) {
        await _detenerMonitoreoUbicacion(motivo: 'GPS del dispositivo apagado');
        await _mostrarAlertaUbicacionApagada(
          'La ubicación del celular se desactivó. Actívala para continuar el monitoreo.',
        );
      } else if (_compartirUbicacion) {
        _limpiarAlertaUbicacion();
        await _iniciarMonitoreoUbicacion();
      }
    });
  }

  // CONSTRUCTORES PARA FORMULARIOS
  Widget _construirSecccionRegistroGasolina() {
    return Container(
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: _primary.withValues(alpha: 0.08)),
        boxShadow: [
          BoxShadow(
            color: _primary.withValues(alpha: 0.06),
            blurRadius: 14,
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
                padding: const EdgeInsets.all(10),
                decoration: BoxDecoration(
                  color: _accent.withValues(alpha: 0.12),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: const Icon(
                  Icons.local_gas_station_rounded,
                  color: _accent,
                ),
              ),
              const SizedBox(width: 12),
              const Expanded(
                child: Text(
                  'Registro de Gasolina/Diésel/Gas',
                  style: TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.w700,
                    color: _primary,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),
          // Fecha (autorrelleno - solo lectura)
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
            decoration: BoxDecoration(
              color: const Color(0xFFF8FAFC),
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: _primary.withValues(alpha: 0.1)),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Fecha',
                  style: TextStyle(
                    fontSize: 12,
                    fontWeight: FontWeight.w600,
                    color: _primary.withValues(alpha: 0.7),
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  _formatearFecha(DateTime.now()),
                  style: const TextStyle(
                    fontSize: 14,
                    fontWeight: FontWeight.w600,
                    color: _primary,
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 12),
          // Folio
          TextField(
            controller: folioGasolinaController,
            decoration: InputDecoration(
              labelText: 'Folio',
              hintText: 'Ej: F001, F002',
              prefixIcon: const Icon(Icons.receipt_long_rounded),
              filled: true,
              fillColor: const Color(0xFFF8FAFC),
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(12),
              ),
            ),
          ),
          const SizedBox(height: 12),
          // Concepto (dropdown)
          DropdownButtonFormField<String>(
            value: _conceptoGasolina,
            items: const [
              DropdownMenuItem(value: 'gasolina', child: Text('Gasolina')),
              DropdownMenuItem(value: 'diesel', child: Text('Diésel')),
              DropdownMenuItem(value: 'gas', child: Text('Gas')),
            ],
            onChanged: (value) {
              if (value != null) {
                setState(() => _conceptoGasolina = value);
              }
            },
            decoration: InputDecoration(
              labelText: 'Concepto',
              prefixIcon: const Icon(Icons.category_rounded),
              filled: true,
              fillColor: const Color(0xFFF8FAFC),
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(12),
              ),
            ),
          ),
          const SizedBox(height: 12),
          // Automóvil (autorrelleno - solo lectura)
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
            decoration: BoxDecoration(
              color: const Color(0xFFF8FAFC),
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: _primary.withValues(alpha: 0.1)),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Automóvil',
                  style: TextStyle(
                    fontSize: 12,
                    fontWeight: FontWeight.w600,
                    color: _primary.withValues(alpha: 0.7),
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  '${widget.camion} (${widget.placas})',
                  style: const TextStyle(
                    fontSize: 14,
                    fontWeight: FontWeight.w600,
                    color: _primary,
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 12),
          // Cantidad
          TextField(
            controller: cantidadGasolinaController,
            keyboardType: const TextInputType.numberWithOptions(decimal: true),
            decoration: InputDecoration(
              labelText: 'Cantidad',
              hintText: 'Ej: 50.5',
              prefixIcon: const Icon(Icons.numbers_rounded),
              filled: true,
              fillColor: const Color(0xFFF8FAFC),
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(12),
              ),
            ),
          ),
          const SizedBox(height: 12),
          // Unidad (litros o kg)
          DropdownButtonFormField<String>(
            value: _unidadGasolina,
            items: const [
              DropdownMenuItem(value: 'litros', child: Text('Litros')),
              DropdownMenuItem(
                value: 'kilogramos',
                child: Text('Kilogramos (kg)'),
              ),
            ],
            onChanged: (value) {
              if (value != null) {
                setState(() => _unidadGasolina = value);
              }
            },
            decoration: InputDecoration(
              labelText: 'Unidad',
              prefixIcon: const Icon(Icons.straighten_rounded),
              filled: true,
              fillColor: const Color(0xFFF8FAFC),
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(12),
              ),
            ),
          ),
          const SizedBox(height: 12),
          // Monto
          TextField(
            controller: montoGasolinaController,
            keyboardType: const TextInputType.numberWithOptions(decimal: true),
            decoration: InputDecoration(
              labelText: 'Monto',
              hintText: 'Ej: 1500.50',
              prefixIcon: const Icon(Icons.attach_money_rounded),
              filled: true,
              fillColor: const Color(0xFFF8FAFC),
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(12),
              ),
            ),
          ),
          const SizedBox(height: 12),
          // Método de pago
          DropdownButtonFormField<String>(
            value: _metodoPagoGasolina,
            items: const [
              DropdownMenuItem(value: 'efectivo', child: Text('Efectivo')),
              DropdownMenuItem(
                value: 'debito',
                child: Text('Tarjeta de Débito'),
              ),
              DropdownMenuItem(
                value: 'credito',
                child: Text('Tarjeta de Crédito'),
              ),
            ],
            onChanged: (value) {
              if (value != null) {
                setState(() => _metodoPagoGasolina = value);
              }
            },
            decoration: InputDecoration(
              labelText: 'Método de Pago',
              prefixIcon: const Icon(Icons.payment_rounded),
              filled: true,
              fillColor: const Color(0xFFF8FAFC),
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(12),
              ),
            ),
          ),
          const SizedBox(height: 18),
          // Botones Registrar y Cancelar
          LayoutBuilder(
            builder: (context, constraints) {
              final isNarrow = constraints.maxWidth < 380;
              if (isNarrow) {
                return Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    FilledButton.icon(
                      onPressed: _registrarGasolina,
                      icon: const Icon(Icons.check_circle_rounded),
                      label: const Text('Registrar Gasolina'),
                      style: FilledButton.styleFrom(
                        backgroundColor: _success,
                        padding: const EdgeInsets.symmetric(vertical: 12),
                      ),
                    ),
                    const SizedBox(height: 10),
                    OutlinedButton.icon(
                      onPressed: _cancelarRegistroGasolina,
                      icon: const Icon(Icons.cancel_rounded),
                      label: const Text('Cancelar'),
                      style: OutlinedButton.styleFrom(
                        padding: const EdgeInsets.symmetric(vertical: 12),
                      ),
                    ),
                  ],
                );
              }
              return Row(
                children: [
                  Expanded(
                    child: FilledButton.icon(
                      onPressed: _registrarGasolina,
                      icon: const Icon(Icons.check_circle_rounded),
                      label: const Text('Registrar'),
                      style: FilledButton.styleFrom(
                        backgroundColor: _success,
                        padding: const EdgeInsets.symmetric(vertical: 12),
                      ),
                    ),
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: OutlinedButton.icon(
                      onPressed: _cancelarRegistroGasolina,
                      icon: const Icon(Icons.cancel_rounded),
                      label: const Text('Cancelar'),
                      style: OutlinedButton.styleFrom(
                        padding: const EdgeInsets.symmetric(vertical: 12),
                      ),
                    ),
                  ),
                ],
              );
            },
          ),
        ],
      ),
    );
  }

  Widget _construirSecccionRegistroToneladas() {
    return Container(
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: _primary.withValues(alpha: 0.08)),
        boxShadow: [
          BoxShadow(
            color: _primary.withValues(alpha: 0.06),
            blurRadius: 14,
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
                padding: const EdgeInsets.all(10),
                decoration: BoxDecoration(
                  color: _accent.withValues(alpha: 0.12),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: const Icon(
                  Icons.scale_rounded, color: _accent,
                ),
              ),
              const SizedBox(width: 12),
              const Expanded(
                child: Text(
                  'Registro de Toneladas',
                  style: TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.w700,
                    color: _primary,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),
          Center(
            child: Column(
              children: [
                Icon(
                  Icons.construction_rounded,
                  size: 48,
                  color: _primary.withValues(alpha: 0.3),
                ),
                const SizedBox(height: 12),
                Text(
                  'En construcción',
                  style: TextStyle(
                    fontSize: 14,
                    fontWeight: FontWeight.w600,
                    color: _primary.withValues(alpha: 0.6),
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  'El registro de toneladas estará disponible próximamente',
                  textAlign: TextAlign.center,
                  style: TextStyle(
                    fontSize: 12,
                    color: _primary.withValues(alpha: 0.5),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Future<void> finalizarJornada() async {
    await _detenerMonitoreoUbicacion(motivo: 'Jornada finalizada');

    final userRef = FirebaseFirestore.instance
        .collection("usuarios")
        .doc(widget.operador);
    final userDoc = await userRef.get();
    final camionId = (userDoc.data()?['camion_id'] ?? '').toString();

    if (camionId.isNotEmpty) {
      await FirebaseFirestore.instance.collection("camiones").doc(camionId).set(
        {"ocupado": false, "operador": ""},
        SetOptions(merge: true),
      );
    }

    // Fallback para limpiar cualquier registro atascado por versiones anteriores.
    var snapshot = await FirebaseFirestore.instance
        .collection("camiones")
        .where("operador", isEqualTo: widget.operador)
        .get();

    for (var doc in snapshot.docs) {
      await doc.reference.update({"ocupado": false, "operador": ""});
    }

    /// cerrar jornada del operador
    await userRef.update({
      "jornada_activa": false,
      "camion_id": "",
      "camion_actual": "",
      "placas_actuales": "",
      "gps_activo": false,
    });

    ScaffoldMessenger.of(
      context,
    ).showSnackBar(const SnackBar(content: Text("Jornada finalizada")));

    Navigator.pushAndRemoveUntil(
      context,
      MaterialPageRoute(
        builder: (_) => OperadorScreen(nombreUsuario: widget.operador),
      ),
      (route) => false,
    );
  }

 @override
  Widget build(BuildContext context) {
    // 1. Iniciamos con PopScope usando la lógica !didPop
    return PopScope(
      canPop: false,
      onPopInvokedWithResult: (didPop, result) {
        if (!didPop) {
          SystemNavigator.pop(); // Minimiza la app si intentan ir atrás
        }
      },
      child: ConnectionWrapper(
        child: Scaffold(
          backgroundColor: const Color(0xFFF0F9FF),
          endDrawer: NotificacionesDrawer(
            rolUsuario: 'operador',
            nombreUsuario: widget.operador,
          ),
          appBar: AppBar(
            elevation: 0,
            foregroundColor: Colors.white,
            title: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                const Text(
                  'Jornada activa',
                  style: TextStyle(
                    fontWeight: FontWeight.w700,
                    letterSpacing: 0.3,
                  ),
                ),
                const SizedBox(width: 10),
                ClipRRect(
                  borderRadius: BorderRadius.circular(10),
                  child: Image.asset(
                    'assets/logo circular.jpeg',
                    height: 36,
                    width: 36,
                    fit: BoxFit.cover,
                  ),
                ),
              ],
            ),
            backgroundColor: Colors.transparent,
            flexibleSpace: Container(
              decoration: const BoxDecoration(
                gradient: LinearGradient(
                  colors: [_primary, Color(0xFF1E293B)],
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                ),
              ),
            ),
            actions: [
              IconButton(
                icon: const Icon(
                  Icons.warning_rounded,
                  color: Colors.orangeAccent,
                ),
                tooltip: 'Reportar problema',
                onPressed: () {
                  Navigator.of(context).push(
                    MaterialPageRoute(
                      builder: (_) => ReporteScreen(
                        nombreUsuario: widget.operador,
                        camion: widget.camion,
                        placas: widget.placas,
                      ),
                    ),
                  );
                },
              ),
              Builder(
                builder: (context) => NotificacionesBellButton(
                  rolUsuario: 'operador',
                  nombreUsuario: widget.operador,
                  onPressed: () => Scaffold.of(context).openEndDrawer(),
                ),
              ),
            ],
          ),
          drawer: MenuLateral(
            nombreUsuario: widget.operador,
            camion: widget.camion,
            placas: widget.placas,
            mostrarCerrarSesion: false,
          ),
          body: Stack(
            children: [
              Positioned(
                top: -120,
                right: -80,
                child: Container(
                  width: 280,
                  height: 280,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    color: _accent.withValues(alpha: 0.08),
                  ),
                ),
              ),
              Positioned(
                bottom: -90,
                left: -70,
                child: Container(
                  width: 220,
                  height: 220,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    color: _success.withValues(alpha: 0.08),
                  ),
                ),
              ),
              AnimatedOpacity(
                duration: const Duration(milliseconds: 550),
                opacity: _contentVisible ? 1 : 0,
                child: AnimatedSlide(
                  duration: const Duration(milliseconds: 550),
                  offset: _contentVisible ? Offset.zero : const Offset(0, 0.05),
                  curve: Curves.easeOutCubic,
                  child: SingleChildScrollView(
                    padding: const EdgeInsets.all(20),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                        Container(
                          padding: const EdgeInsets.all(18),
                          decoration: BoxDecoration(
                            borderRadius: BorderRadius.circular(20),
                            gradient: LinearGradient(
                              colors: [
                                _accent.withValues(alpha: 0.16),
                                _success.withValues(alpha: 0.08),
                              ],
                              begin: Alignment.topLeft,
                              end: Alignment.bottomRight,
                            ),
                            border: Border.all(
                              color: _accent.withValues(alpha: 0.24),
                            ),
                            boxShadow: [
                              BoxShadow(
                                color: _primary.withValues(alpha: 0.08),
                                blurRadius: 20,
                                offset: const Offset(0, 8),
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
                                      color: Colors.white.withValues(alpha: 0.55),
                                      borderRadius: BorderRadius.circular(12),
                                    ),
                                    child: const Icon(
                                      Icons.route_rounded,
                                      color: _primary,
                                    ),
                                  ),
                                  const SizedBox(width: 10),
                                  const Expanded(
                                    child: Text(
                                      "Datos de Jornada",
                                      style: TextStyle(
                                        fontSize: 18,
                                        fontWeight: FontWeight.w700,
                                        color: _primary,
                                      ),
                                    ),
                                  ),
                                ],
                              ),
                              const SizedBox(height: 14),
                              Text(
                                "Operador: ${widget.operador}",
                                style: const TextStyle(
                                  fontSize: 18,
                                  fontWeight: FontWeight.w600,
                                  color: _primary,
                                ),
                              ),
                              const SizedBox(height: 6),
                              Text(
                                "Camión: ${widget.camion}",
                                style: const TextStyle(
                                  fontSize: 17,
                                  fontWeight: FontWeight.w600,
                                  color: _primary,
                                ),
                              ),
                              const SizedBox(height: 4),
                              Text(
                                "Placas: ${widget.placas}",
                                style: TextStyle(
                                  fontSize: 15,
                                  color: Colors.blueGrey[800],
                                ),
                              ),
                              const SizedBox(height: 10),
                              Container(
                                width: double.infinity,
                                padding: const EdgeInsets.symmetric(
                                  horizontal: 12,
                                  vertical: 10,
                                ),
                                decoration: BoxDecoration(
                                  color: _compartiendoUbicacionActiva
                                      ? _success.withValues(alpha: 0.14)
                                      : _danger.withValues(alpha: 0.10),
                                  borderRadius: BorderRadius.circular(12),
                                  border: Border.all(
                                    color: _compartiendoUbicacionActiva
                                        ? _success.withValues(alpha: 0.35)
                                        : _danger.withValues(alpha: 0.35),
                                  ),
                                ),
                                child: Row(
                                  children: [
                                    Icon(
                                      _compartiendoUbicacionActiva
                                          ? Icons.gps_fixed_rounded
                                          : Icons.gps_off_rounded,
                                      color: _compartiendoUbicacionActiva
                                          ? _success
                                          : _danger,
                                    ),
                                    const SizedBox(width: 8),
                                    Expanded(
                                      child: Text(
                                        _compartiendoUbicacionActiva
                                            ? 'Compartiendo ubicación activa'
                                            : _estadoUbicacion,
                                        style: const TextStyle(
                                          fontSize: 13.2,
                                          fontWeight: FontWeight.w700,
                                          color: _primary,
                                        ),
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                              const SizedBox(height: 8),
                              SwitchListTile.adaptive(
                                contentPadding: EdgeInsets.zero,
                                value: _compartirUbicacion,
                                onChanged: (value) async {
                                  setState(() => _compartirUbicacion = value);
                                  if (value) {
                                    await _iniciarMonitoreoUbicacion();
                                  } else {
                                    await _detenerMonitoreoUbicacion(
                                      motivo: 'Compartición manualmente desactivada',
                                    );
                                  }
                                },
                                title: const Text(
                                  'Compartir ubicación con administración',
                                  style: TextStyle(
                                    fontSize: 13,
                                    fontWeight: FontWeight.w700,
                                    color: _primary,
                                  ),
                                ),
                                subtitle: Text(
                                  !_servicioUbicacionActivo
                                      ? 'Ubicación del dispositivo apagada'
                                      : (!_permisoUbicacionOtorgado
                                          ? 'Permiso de ubicación pendiente'
                                          : 'Monitoreo en tiempo real habilitado'),
                                  style: TextStyle(
                                    color: _primary.withValues(alpha: 0.72),
                                    fontSize: 12,
                                  ),
                                ),
                              ),
                            ],
                          ),
                        ),
                        const SizedBox(height: 22),
                        Container(
                          padding: const EdgeInsets.all(18),
                          decoration: BoxDecoration(
                            color: Colors.white,
                            borderRadius: BorderRadius.circular(18),
                            border: Border.all(
                              color: _primary.withValues(alpha: 0.08),
                            ),
                            boxShadow: [
                              BoxShadow(
                                color: _primary.withValues(alpha: 0.06),
                                blurRadius: 14,
                                offset: const Offset(0, 6),
                              ),
                            ],
                          ),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.stretch,
                            children: [
                              const Text(
                                'Registros de Jornada',
                                style: TextStyle(
                                  fontSize: 16,
                                  fontWeight: FontWeight.w700,
                                  color: _primary,
                                ),
                              ),
                              const SizedBox(height: 6),
                              Text(
                                'Selecciona el tipo de registro que quieres capturar.',
                                style: TextStyle(
                                  fontSize: 12.5,
                                  color: _primary.withValues(alpha: 0.7),
                                ),
                              ),
                              const SizedBox(height: 14),
                              FilledButton.icon(
                                onPressed: _abrirRegistroGasolina,
                                style: FilledButton.styleFrom(
                                  backgroundColor: _success,
                                  foregroundColor: Colors.white,
                                  padding: const EdgeInsets.symmetric(
                                    vertical: 13,
                                  ),
                                  shape: RoundedRectangleBorder(
                                    borderRadius: BorderRadius.circular(14),
                                  ),
                                ),
                                icon: const Icon(Icons.local_gas_station_rounded),
                                label: const Text('Registro de Gasolina'),
                              ),
                              const SizedBox(height: 10),
                              OutlinedButton.icon(
                                onPressed: _abrirRegistroToneladas,
                                style: OutlinedButton.styleFrom(
                                  foregroundColor: _primary,
                                  side: BorderSide(
                                    color: _primary.withValues(alpha: 0.28),
                                  ),
                                  padding: const EdgeInsets.symmetric(
                                    vertical: 13,
                                  ),
                                  shape: RoundedRectangleBorder(
                                    borderRadius: BorderRadius.circular(14),
                                  ),
                                ),
                                icon: const Icon(Icons.scale_rounded),
                                label: const Text('Entrada de material'),
                              ),
                            ],
                          ),
                        ),
                        const SizedBox(height: 22),
                        Container(
                          padding: const EdgeInsets.all(14),
                          decoration: BoxDecoration(
                            color: Colors.white,
                            borderRadius: BorderRadius.circular(18),
                            border: Border.all(
                              color: _danger.withValues(alpha: 0.25),
                            ),
                            boxShadow: [
                              BoxShadow(
                                color: _danger.withValues(alpha: 0.08),
                                blurRadius: 16,
                                offset: const Offset(0, 6),
                              ),
                            ],
                          ),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.stretch,
                            children: [
                              const Row(
                                children: [
                                  Icon(Icons.logout_rounded, color: _danger),
                                  SizedBox(width: 8),
                                  Expanded(
                                    child: Text(
                                      'Desliza para finalizar jornada',
                                      style: TextStyle(
                                        fontSize: 14,
                                        fontWeight: FontWeight.w700,
                                        color: _primary,
                                      ),
                                    ),
                                  ),
                                ],
                              ),
                              const SizedBox(height: 8),
                              Text(
                                _finalizandoJornada
                                    ? 'Finalizando...'
                                    : 'Desliza de izquierda a derecha para confirmar',
                                style: TextStyle(
                                  fontSize: 12,
                                  color: _primary.withValues(alpha: 0.68),
                                ),
                              ),
                              const SizedBox(height: 10),
                              _SwipeToConfirmButton(
                                text: _finalizandoJornada
                                    ? 'Finalizando jornada...'
                                    : 'Desliza para finalizar jornada',
                                enabled: !_finalizandoJornada,
                                onCompleted: _finalizarPorSwipe,
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ),
            ],
          ),
        ), // Cierre de Scaffold
      ), // Cierre de ConnectionWrapper
    ); // Cierre de PopScope
  }
}

class RegistroGasolinaScreen extends StatefulWidget {
  final String operador;
  final String camion;
  final String placas;

  const RegistroGasolinaScreen({
    super.key,
    required this.operador,
    required this.camion,
    required this.placas,
  });

  @override
  State<RegistroGasolinaScreen> createState() => _RegistroGasolinaScreenState();
}

class _RegistroGasolinaScreenState extends State<RegistroGasolinaScreen> {
  final TextEditingController _folioController = TextEditingController();
  final TextEditingController _cantidadController = TextEditingController();
  final TextEditingController _montoController = TextEditingController();

  String _concepto = 'gasolina';
  String _unidad = 'litros';
  String _metodoPago = 'efectivo';

  static const Color _primary = Color(0xFF0F172A);
  static const Color _accent = Color(0xFF0891B2);
  static const Color _success = Color(0xFF10B981);

  @override
  void dispose() {
    _folioController.dispose();
    _cantidadController.dispose();
    _montoController.dispose();
    super.dispose();
  }

  String _formatearFecha(DateTime fecha) {
    return DateFormat('dd/MM/yyyy HH:mm').format(fecha);
  }

  Future<bool> _confirmarAccion({
    required String titulo,
    required String mensaje,
    required String textoConfirmar,
  }) async {
    final confirmar = await showDialog<bool>(
      context: context,
      builder: (_) => AlertDialog(
        title: Text(titulo),
        content: Text(mensaje),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(false),
            child: const Text('Cancelar'),
          ),
          FilledButton(
            onPressed: () => Navigator.of(context).pop(true),
            child: Text(textoConfirmar),
          ),
        ],
      ),
    );

    return confirmar ?? false;
  }

  Future<void> _guardarRegistro() async {
    final folio = _folioController.text.trim();
    final cantidad = double.tryParse(
      _cantidadController.text.trim().replaceAll(',', '.'),
    );
    final monto = double.tryParse(
      _montoController.text.trim().replaceAll(',', '.'),
    );

    if (folio.isEmpty || cantidad == null || monto == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Completa folio, cantidad y monto correctamente.'),
        ),
      );
      return;
    }

    final confirmar = await _confirmarAccion(
      titulo: 'Confirmar registro',
      mensaje: '¿Estás seguro de registrar este consumo?',
      textoConfirmar: 'REGISTRAR',
    );

    if (!confirmar) return;

    final fechaActual = DateTime.now();

    await FirebaseFirestore.instance.collection('registros_gasolina').add({
      'tipo_registro': 'gasolina',
      'fecha': fechaActual,
      'fecha_texto': _formatearFecha(fechaActual),
      'folio': folio,
      'concepto': _concepto,
      'automovil': widget.camion,
      'placas': widget.placas,
      'cantidad': cantidad,
      'unidad': _unidad,
      'monto': monto,
      'metodo_pago': _metodoPago,
      'operador': widget.operador,
      'camion': widget.camion,
      'creadoEn': FieldValue.serverTimestamp(),
    });

    if (!mounted) return;
    ScaffoldMessenger.of(
      context,
    ).showSnackBar(const SnackBar(content: Text('Registro guardado')));
    Navigator.of(context).pop();
  }

  Future<void> _cancelarRegistro() async {
    final confirmar = await _confirmarAccion(
      titulo: 'Cancelar registro',
      mensaje: '¿Estás seguro de cancelar? Se perderán los datos capturados.',
      textoConfirmar: 'CANCELAR',
    );

    if (!confirmar) return;
    if (!mounted) return;
    Navigator.of(context).pop();
  }

  @override
  Widget build(BuildContext context) {
    final inputBorder = OutlineInputBorder(
      borderRadius: BorderRadius.circular(14),
      borderSide: BorderSide(color: _primary.withValues(alpha: 0.15)),
    );

    return Scaffold(
      backgroundColor: const Color(0xFFF4F8FC),
      appBar: AppBar(
        elevation: 0,
        backgroundColor: Colors.transparent,
        foregroundColor: _primary,
        title: const Text(
          'Registro de Combustible',
          style: TextStyle(fontWeight: FontWeight.w700),
        ),
      ),
      body: Stack(
        children: [
          Positioned(
            top: -90,
            right: -70,
            child: Container(
              width: 220,
              height: 220,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: _accent.withValues(alpha: 0.10),
              ),
            ),
          ),
          Positioned(
            bottom: -110,
            left: -70,
            child: Container(
              width: 240,
              height: 240,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: _success.withValues(alpha: 0.08),
              ),
            ),
          ),
          SingleChildScrollView(
            padding: const EdgeInsets.fromLTRB(16, 8, 16, 20),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Container(
                  padding: const EdgeInsets.all(18),
                  decoration: BoxDecoration(
                    borderRadius: BorderRadius.circular(20),
                    gradient: LinearGradient(
                      colors: [
                        _accent.withValues(alpha: 0.18),
                        _success.withValues(alpha: 0.12),
                      ],
                      begin: Alignment.topLeft,
                      end: Alignment.bottomRight,
                    ),
                    border: Border.all(color: _accent.withValues(alpha: 0.20)),
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text(
                        'Nuevo registro',
                        style: TextStyle(
                          fontSize: 22,
                          fontWeight: FontWeight.w800,
                          color: _primary,
                        ),
                      ),
                      const SizedBox(height: 6),
                      Text(
                        'Captura los datos del consumo de combustible para la jornada activa.',
                        style: TextStyle(
                          color: _primary.withValues(alpha: 0.72),
                          height: 1.35,
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 14),
                Container(
                  padding: const EdgeInsets.all(16),
                  decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(18),
                    border: Border.all(color: _primary.withValues(alpha: 0.08)),
                    boxShadow: [
                      BoxShadow(
                        color: _primary.withValues(alpha: 0.06),
                        blurRadius: 16,
                        offset: const Offset(0, 6),
                      ),
                    ],
                  ),
                  child: Column(
                    children: [
                      Row(
                        children: [
                          Expanded(
                            child: _InfoPill(
                              label: 'Fecha',
                              value: _formatearFecha(DateTime.now()),
                              icon: Icons.calendar_month_rounded,
                            ),
                          ),
                          const SizedBox(width: 10),
                          Expanded(
                            child: _InfoPill(
                              label: 'Automóvil',
                              value: '${widget.camion} (${widget.placas})',
                              icon: Icons.local_shipping_rounded,
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 14),
                      TextField(
                        controller: _folioController,
                        decoration: InputDecoration(
                          labelText: 'Folio',
                          hintText: 'Ej: F-00124',
                          prefixIcon: const Icon(Icons.receipt_long_rounded),
                          filled: true,
                          fillColor: const Color(0xFFF8FAFC),
                          border: inputBorder,
                          enabledBorder: inputBorder,
                          focusedBorder: inputBorder.copyWith(
                            borderSide: BorderSide(color: _accent, width: 1.5),
                          ),
                        ),
                      ),
                      const SizedBox(height: 12),
                      DropdownButtonFormField<String>(
                        value: _concepto,
                        items: const [
                          DropdownMenuItem(
                            value: 'gasolina',
                            child: Text('Gasolina'),
                          ),
                          DropdownMenuItem(
                            value: 'diesel',
                            child: Text('Diésel'),
                          ),
                          DropdownMenuItem(value: 'gas', child: Text('Gas')),
                        ],
                        onChanged: (value) {
                          if (value != null) setState(() => _concepto = value);
                        },
                        decoration: InputDecoration(
                          labelText: 'Concepto',
                          prefixIcon: const Icon(Icons.category_rounded),
                          filled: true,
                          fillColor: const Color(0xFFF8FAFC),
                          border: inputBorder,
                          enabledBorder: inputBorder,
                          focusedBorder: inputBorder.copyWith(
                            borderSide: BorderSide(color: _accent, width: 1.5),
                          ),
                        ),
                      ),
                      const SizedBox(height: 12),
                      LayoutBuilder(
                        builder: (context, constraints) {
                          final narrow = constraints.maxWidth < 430;

                          final cantidadField = TextField(
                            controller: _cantidadController,
                            keyboardType: const TextInputType.numberWithOptions(
                              decimal: true,
                            ),
                            decoration: InputDecoration(
                              labelText: 'Cantidad',
                              hintText: '0.00',
                              prefixIcon: const Icon(Icons.numbers_rounded),
                              filled: true,
                              fillColor: const Color(0xFFF8FAFC),
                              border: inputBorder,
                              enabledBorder: inputBorder,
                              focusedBorder: inputBorder.copyWith(
                                borderSide: BorderSide(
                                  color: _accent,
                                  width: 1.5,
                                ),
                              ),
                            ),
                          );

                          final unidadField = DropdownButtonFormField<String>(
                            value: _unidad,
                            isExpanded: true,
                            items: const [
                              DropdownMenuItem(
                                value: 'litros',
                                child: Text('Litros'),
                              ),
                              DropdownMenuItem(
                                value: 'kilogramos',
                                child: Text('Kilogramos (kg)'),
                              ),
                            ],
                            onChanged: (value) {
                              if (value != null)
                                setState(() => _unidad = value);
                            },
                            decoration: InputDecoration(
                              labelText: 'Unidad',
                              filled: true,
                              fillColor: const Color(0xFFF8FAFC),
                              border: inputBorder,
                              enabledBorder: inputBorder,
                              focusedBorder: inputBorder.copyWith(
                                borderSide: BorderSide(
                                  color: _accent,
                                  width: 1.5,
                                ),
                              ),
                            ),
                          );

                          if (narrow) {
                            return Column(
                              children: [
                                cantidadField,
                                const SizedBox(height: 10),
                                unidadField,
                              ],
                            );
                          }

                          return Row(
                            children: [
                              Expanded(child: cantidadField),
                              const SizedBox(width: 10),
                              Expanded(child: unidadField),
                            ],
                          );
                        },
                      ),
                      const SizedBox(height: 12),
                      TextField(
                        controller: _montoController,
                        keyboardType: const TextInputType.numberWithOptions(
                          decimal: true,
                        ),
                        decoration: InputDecoration(
                          labelText: 'Monto',
                          hintText: '0.00',
                          prefixIcon: const Icon(Icons.attach_money_rounded),
                          filled: true,
                          fillColor: const Color(0xFFF8FAFC),
                          border: inputBorder,
                          enabledBorder: inputBorder,
                          focusedBorder: inputBorder.copyWith(
                            borderSide: BorderSide(color: _accent, width: 1.5),
                          ),
                        ),
                      ),
                      const SizedBox(height: 12),
                      DropdownButtonFormField<String>(
                        value: _metodoPago,
                        items: const [
                          DropdownMenuItem(
                            value: 'efectivo',
                            child: Text('Efectivo'),
                          ),
                          DropdownMenuItem(
                            value: 'debito',
                            child: Text('T. Débito'),
                          ),
                          DropdownMenuItem(
                            value: 'credito',
                            child: Text('T. Crédito'),
                          ),
                        ],
                        onChanged: (value) {
                          if (value != null)
                            setState(() => _metodoPago = value);
                        },
                        decoration: InputDecoration(
                          labelText: 'Método de pago',
                          prefixIcon: const Icon(Icons.payment_rounded),
                          filled: true,
                          fillColor: const Color(0xFFF8FAFC),
                          border: inputBorder,
                          enabledBorder: inputBorder,
                          focusedBorder: inputBorder.copyWith(
                            borderSide: BorderSide(color: _accent, width: 1.5),
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 16),
                LayoutBuilder(
                  builder: (context, constraints) {
                    final isNarrow = constraints.maxWidth < 410;
                    if (isNarrow) {
                      return Column(
                        crossAxisAlignment: CrossAxisAlignment.stretch,
                        children: [
                          FilledButton.icon(
                            onPressed: _guardarRegistro,
                            style: FilledButton.styleFrom(
                              backgroundColor: _success,
                              foregroundColor: Colors.white,
                              padding: const EdgeInsets.symmetric(vertical: 14),
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(14),
                              ),
                            ),
                            icon: const Icon(Icons.check_circle_rounded),
                            label: const Text('Registrar'),
                          ),
                          const SizedBox(height: 10),
                          OutlinedButton.icon(
                            onPressed: _cancelarRegistro,
                            style: OutlinedButton.styleFrom(
                              foregroundColor: _primary,
                              padding: const EdgeInsets.symmetric(vertical: 14),
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(14),
                              ),
                            ),
                            icon: const Icon(Icons.cancel_rounded),
                            label: const Text('Cancelar'),
                          ),
                        ],
                      );
                    }

                    return Row(
                      children: [
                        Expanded(
                          child: FilledButton.icon(
                            onPressed: _guardarRegistro,
                            style: FilledButton.styleFrom(
                              backgroundColor: _success,
                              foregroundColor: Colors.white,
                              padding: const EdgeInsets.symmetric(vertical: 14),
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(14),
                              ),
                            ),
                            icon: const Icon(Icons.check_circle_rounded),
                            label: const Text('Registrar'),
                          ),
                        ),
                        const SizedBox(width: 10),
                        Expanded(
                          child: OutlinedButton.icon(
                            onPressed: _cancelarRegistro,
                            style: OutlinedButton.styleFrom(
                              foregroundColor: _primary,
                              padding: const EdgeInsets.symmetric(vertical: 14),
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(14),
                              ),
                            ),
                            icon: const Icon(Icons.cancel_rounded),
                            label: const Text('Cancelar'),
                          ),
                        ),
                      ],
                    );
                  },
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _InfoPill extends StatelessWidget {
  final String label;
  final String value;
  final IconData icon;

  const _InfoPill({
    required this.label,
    required this.value,
    required this.icon,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(10),
      decoration: BoxDecoration(
        color: const Color(0xFFF8FAFC),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: const Color(0xFFE5E7EB)),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(icon, size: 18, color: const Color(0xFF0F172A)),
          const SizedBox(width: 8),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  label,
                  style: const TextStyle(
                    fontSize: 11,
                    color: Color(0xFF64748B),
                    fontWeight: FontWeight.w600,
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  value,
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(
                    fontSize: 12,
                    color: Color(0xFF0F172A),
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ],
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
    if (!widget.enabled) {
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
        const knobSize = 54.0;
        final double maxDrag = (constraints.maxWidth - knobSize)
            .clamp(0.0, double.infinity)
            .toDouble();
        final double fillWidth = (_dragX + knobSize)
            .clamp(knobSize, constraints.maxWidth)
            .toDouble();

        return Container(
          height: 58,
          decoration: BoxDecoration(
            color: const Color(0xFFFEE2E2),
            borderRadius: BorderRadius.circular(40),
            border: Border.all(color: const Color(0xFFFCA5A5)),
          ),
          child: Stack(
            alignment: Alignment.centerLeft,
            children: [
              AnimatedContainer(
                duration: const Duration(milliseconds: 120),
                curve: Curves.easeOut,
                width: fillWidth,
                height: 58,
                decoration: BoxDecoration(
                  color: const Color(0xFFDC2626),
                  borderRadius: BorderRadius.circular(40),
                ),
              ),
              Center(
                child: AnimatedOpacity(
                  duration: const Duration(milliseconds: 180),
                  opacity: _dragX > maxDrag * 0.2 ? 0.15 : 1,
                  child: Text(
                    widget.text,
                    style: TextStyle(
                      fontWeight: FontWeight.w700,
                      color: _loading ? Colors.white : const Color(0xFF7F1D1D),
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
                      color: Colors.white,
                      shape: BoxShape.circle,
                      boxShadow: [
                        BoxShadow(
                          color: Colors.black.withValues(alpha: 0.16),
                          blurRadius: 10,
                          offset: const Offset(0, 3),
                        ),
                      ],
                    ),
                    child: _loading
                        ? const Padding(
                            padding: EdgeInsets.all(16),
                            child: CircularProgressIndicator(strokeWidth: 2),
                          )
                        : const Icon(
                            Icons.keyboard_double_arrow_right_rounded,
                            color: Color(0xFFDC2626),
                            size: 28,
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

class RegistroToneladasScreen extends StatefulWidget {
  final String operador;
  final String camion;
  final String placas;

  const RegistroToneladasScreen({
    super.key,
    required this.operador,
    required this.camion,
    required this.placas,
  });

  @override
  State<RegistroToneladasScreen> createState() => _RegistroToneladasScreenState();
}

class _RegistroToneladasScreenState extends State<RegistroToneladasScreen> {
  // Controladores para los campos que llena el operador
  final TextEditingController _folioController = TextEditingController();
  final TextEditingController _entradaController = TextEditingController();
  final TextEditingController _salidaController = TextEditingController();

  String? _productoSeleccionado;
  double _pesoNeto = 0.0;
  
  // Capturamos la fecha y hora al momento de abrir el registro
  final String _fechaHoraActual = DateFormat('dd/MM/yyyy HH:mm:ss').format(DateTime.now());

  // Lista de productos solicitada
  final List<String> _productos = [
    'VG20', 
    'NX', 
    'SISMO SUCIO', 
    'NO RECICLABLE', 
    'CONTAMINADO', 
    'MIXTO SECURY', 
    'LAMINADO GLASS'
  ];

  // Función para guardar en Firebase
  Future<void> _guardarEnFirebase() async {
    // Validar que los campos no estén vacíos
    if (_folioController.text.isEmpty || _productoSeleccionado == null || _entradaController.text.isEmpty || _salidaController.text.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Por favor llena todos los campos (Folio, Producto y Pesos)')),
      );
      return;
    }

    try {
      // Mostrar círculo de carga (Loading)
      showDialog(
        context: context,
        barrierDismissible: false,
        builder: (context) => const Center(child: CircularProgressIndicator(color: Color(0xFF0F766E))),
      );

      // Guardar en la colección 'registros_toneladas'
      await FirebaseFirestore.instance.collection('registros_toneladas').add({
        'folio': _folioController.text,
        'operador': widget.operador,
        'camion': widget.camion,
        'placas': widget.placas,
        'producto': _productoSeleccionado,
        'peso_entrada': double.tryParse(_entradaController.text) ?? 0.0,
        'peso_salida': double.tryParse(_salidaController.text) ?? 0.0,
        'peso_neto': _pesoNeto,
        'fecha_registro': FieldValue.serverTimestamp(), // Para filtros de Admin precisos
        'fecha_texto': _fechaHoraActual,
      });

      if (!mounted) return;
      Navigator.pop(context); // Quitar círculo de carga

      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(backgroundColor: Colors.green, content: Text('Registro guardado exitosamente')),
      );
      
      Navigator.pop(context); // Regresar a la pantalla anterior o Admin screen

    } catch (e) {
      if (!mounted) return;
      Navigator.pop(context); // Quitar círculo de carga
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(backgroundColor: Colors.red, content: Text('Error al guardar en base de datos: $e')),
      );
    }
  }

  void _calcularNeto() {
    double entrada = double.tryParse(_entradaController.text) ?? 0.0;
    double salida = double.tryParse(_salidaController.text) ?? 0.0;
    setState(() {
      // Cálculo automático del peso neto (valor absoluto para evitar negativos)
      _pesoNeto = (entrada - salida).abs();
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF4F7FB),
      appBar: AppBar(
        title: const Text('Registro de Carga', style: TextStyle(fontWeight: FontWeight.bold)),
        backgroundColor: const Color(0xFF0F766E),
        foregroundColor: Colors.white,
        centerTitle: true,
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            // --- BLOQUE DE INFORMACIÓN DEL VEHÍCULO Y OPERADOR ---
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(10),
                border: Border.all(color: Colors.blueGrey.shade100),
                boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.05), blurRadius: 5)],
              ),
              child: Column(
                children: [
                  _buildFilaInfo("OPERADOR", widget.operador),
                  _buildFilaInfo("CAMIÓN", widget.camion),
                  _buildFilaInfo("PLACAS", widget.placas),
                  _buildFilaInfo("FECHA/HORA", _fechaHoraActual),
                ],
              ),
            ),

            const SizedBox(height: 16),

            // --- CAMPO DE FOLIO (MANUAL) ---
            const Text(" FOLIO DE PAPELETA", style: TextStyle(fontWeight: FontWeight.bold, color: Color(0xFF1E293B))),
            const SizedBox(height: 5),
            TextField(
              controller: _folioController,
              keyboardType: TextInputType.number,
              style: const TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
              decoration: InputDecoration(
                hintText: "Ingrese el Folio",
                filled: true,
                fillColor: Colors.white,
                prefixIcon: const Icon(Icons.numbers),
                border: OutlineInputBorder(borderRadius: BorderRadius.circular(10)),
              ),
            ),

            const SizedBox(height: 16),

            // --- SELECTOR DE PRODUCTO ---
            const Text(" TIPO DE PRODUCTO", style: TextStyle(fontWeight: FontWeight.bold, color: Color(0xFF1E293B))),
            const SizedBox(height: 5),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(10),
                border: Border.all(color: Colors.grey.shade400),
              ),
              child: DropdownButtonHideUnderline(
                child: DropdownButton<String>(
                  value: _productoSeleccionado,
                  hint: const Text("Seleccione el producto"),
                  isExpanded: true,
                  icon: const Icon(Icons.arrow_drop_down_circle, color: Color(0xFF0F766E)),
                  items: _productos.map((String value) {
                    return DropdownMenuItem<String>(
                      value: value,
                      child: Text(value, style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
                    );
                  }).toList(),
                  onChanged: (nuevoValor) => setState(() => _productoSeleccionado = nuevoValor),
                ),
              ),
            ),

            const SizedBox(height: 16),

            // --- PESOS ENTRADA Y SALIDA ---
            Row(
              children: [
                Expanded(child: _buildInputPeso("PESO ENTRADA (KG)", _entradaController)),
                const SizedBox(width: 10),
                Expanded(child: _buildInputPeso("PESO SALIDA (KG)", _salidaController)),
              ],
            ),

            const SizedBox(height: 20),

            // --- PESO NETO AUTOMÁTICO ---
            Container(
              padding: const EdgeInsets.all(15),
              decoration: BoxDecoration(
                color: const Color(0xFFF0FDF4),
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: Colors.green.shade700, width: 2),
              ),
              child: Column(
                children: [
                  Text("PESO NETO CALCULADO", 
                    style: TextStyle(fontWeight: FontWeight.bold, color: Colors.green.shade800)),
                  Text(
                    "${NumberFormat('#,###.##').format(_pesoNeto)} Kg",
                    style: const TextStyle(fontSize: 42, fontWeight: FontWeight.w900, color: Color(0xFF166534)),
                  ),
                ],
              ),
            ),

            const SizedBox(height: 24),

            // --- BOTÓN DE GUARDAR ---
            SizedBox(
              height: 60,
              child: FilledButton.icon(
                onPressed: _guardarEnFirebase,
                icon: const Icon(Icons.cloud_upload),
                label: const Text("GUARDAR REGISTRO", 
                  style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold)),
                style: FilledButton.styleFrom(
                  backgroundColor: const Color(0xFF0F766E),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                  elevation: 4,
                ),
              ),
            ),
            
            const SizedBox(height: 10),
            
            TextButton(
              onPressed: () => Navigator.pop(context),
              child: const Text("Cancelar", style: TextStyle(color: Colors.grey, fontSize: 16)),
            )
          ],
        ),
      ),
    );
  }

  Widget _buildFilaInfo(String label, String valor) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 3),
      child: Row(
        children: [
          Text("$label: ", style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 14, color: Colors.blueGrey)),
          Expanded(child: Text(valor, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 14, color: Colors.black87))),
        ],
      ),
    );
  }

  Widget _buildInputPeso(String etiqueta, TextEditingController controller) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(etiqueta, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 12, color: Color(0xFF475569))),
        const SizedBox(height: 5),
        TextField(
          controller: controller,
          keyboardType: TextInputType.number,
          style: const TextStyle(fontSize: 24, fontWeight: FontWeight.bold),
          decoration: InputDecoration(
            filled: true,
            fillColor: Colors.white,
            contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 15),
            border: OutlineInputBorder(borderRadius: BorderRadius.circular(10)),
            focusedBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(10),
              borderSide: const BorderSide(color: Color(0xFF0F766E), width: 2),
            ),
          ),
          onChanged: (value) => _calcularNeto(),
        ),
      ],
    );
  }
}
