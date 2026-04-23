import 'dart:async';
import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:geolocator/geolocator.dart';
import 'package:http/http.dart' as http;
import 'package:image_picker/image_picker.dart';
import 'package:google_mlkit_text_recognition/google_mlkit_text_recognition.dart';
import 'package:intl/intl.dart';
import 'operador_screen.dart';
import 'reporte_screen.dart'; // Asegúrate de que esta línea esté presente
import 'widgets_conexion/connection_wrapper.dart';
import 'widgets/menu_lateral.dart';
import 'widgets/notificaciones_drawer.dart';

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
            initialValue: _conceptoGasolina,
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
            initialValue: _unidadGasolina,
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
            initialValue: _metodoPagoGasolina,
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

class _RegistroGasolinaScreenState extends State<RegistroGasolinaScreen>
    with SingleTickerProviderStateMixin {
  final ImagePicker _imagePicker = ImagePicker();
  static const String _geminiApiKey = String.fromEnvironment(
    'GEMINI_API_KEY',
    defaultValue: 'AIzaSyBPZB9FGs_o97EOWS1EcLZco0wlh1Vvsmo',
  );
  static const String _geminiModel = 'gemini-2.0-flash';

  final TextEditingController _folioController = TextEditingController();
  final TextEditingController _cantidadController = TextEditingController();
  final TextEditingController _montoController = TextEditingController();

  String? _concepto;
  String? _unidad;
  String? _metodoPago;
  bool _escaneoEnProgreso = false;
  bool _mejoraIaEnProgreso = false;
  int _intentosEscaneoFallidos = 0;
  XFile? _ultimaImagenEscaneada;
  late final AnimationController _entryController;
  late final Animation<double> _fadeAnimation;
  late final Animation<Offset> _slideAnimation;

  static const Color _primary = Color(0xFF0B1220);
  static const Color _accent = Color(0xFF06B6D4);
  static const Color _success = Color(0xFF10B981);
  static const Color _warning = Color(0xFFF59E0B);

  @override
  void initState() {
    super.initState();
    _entryController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 850),
    );
    _fadeAnimation = CurvedAnimation(
      parent: _entryController,
      curve: Curves.easeOut,
    );
    _slideAnimation = Tween<Offset>(
      begin: const Offset(0, 0.06),
      end: Offset.zero,
    ).animate(
      CurvedAnimation(parent: _entryController, curve: Curves.easeOutCubic),
    );
    _entryController.forward();
  }

  @override
  void dispose() {
    _entryController.dispose();
    _folioController.dispose();
    _cantidadController.dispose();
    _montoController.dispose();
    super.dispose();
  }

  String _formatearFecha(DateTime fecha) {
    return DateFormat('dd/MM/yyyy HH:mm').format(fecha);
  }

  String _normalizarTextoEscaneado(String texto) {
    return texto
        .toUpperCase()
        .replaceAll('Á', 'A')
        .replaceAll('É', 'E')
        .replaceAll('Í', 'I')
        .replaceAll('Ó', 'O')
        .replaceAll('Ú', 'U')
        .replaceAll('Ü', 'U')
        .replaceAll('Ñ', 'N');
  }

  String? _normalizarMontoEscaneado(String valor) {
    var limpio = valor.replaceAll(RegExp(r'[^0-9,.-]'), '');
    if (limpio.isEmpty) return null;

    final ultimoPunto = limpio.lastIndexOf('.');
    final ultimaComa = limpio.lastIndexOf(',');
    if (ultimoPunto >= 0 && ultimaComa >= 0) {
      if (ultimaComa > ultimoPunto) {
        limpio = limpio.replaceAll('.', '').replaceAll(',', '.');
      } else {
        limpio = limpio.replaceAll(',', '');
      }
    } else if (ultimaComa >= 0) {
      limpio = limpio.replaceAll('.', '').replaceAll(',', '.');
    } else {
      limpio = limpio.replaceAll(',', '');
    }

    return limpio;
  }

  String _normalizarTokenNumerico(String token) {
    if (!RegExp(r'\d').hasMatch(token)) return token;

    return token
        .replaceAll('O', '0')
        .replaceAll('Q', '0')
        .replaceAll('I', '1')
        .replaceAll('L', '1')
        .replaceAll('S', '5')
        .replaceAll('B', '8');
  }

  String _normalizarTextoParaNumeros(String texto) {
    return texto.split(RegExp(r'\s+')).map(_normalizarTokenNumerico).join(' ');
  }

  String? _normalizarCantidadEscaneada(String valor) {
    final limpio = _normalizarMontoEscaneado(_normalizarTokenNumerico(valor));
    if (limpio == null || limpio.isEmpty) return null;

    final numero = double.tryParse(limpio);
    if (numero == null) return null;

    if (numero == numero.truncateToDouble()) {
      return numero.toStringAsFixed(0);
    }

    return numero.toString();
  }

  String? _detectarFolio(String texto) {
    final folioRegex = RegExp(
      r'(?:FOLIO|FOL|FCT|FACTURA|UUID|UUID:|FISCAL)[^A-Z0-9]*([A-Z0-9\-]{4,})',
      caseSensitive: false,
    );
    final match = folioRegex.firstMatch(texto);
    if (match != null) return match.group(1)?.trim();

    final lineas = texto.split(RegExp(r'\s+'));
    for (final linea in lineas) {
      if (RegExp(r'^[A-Z]?[0-9]{3,}[-A-Z0-9]*$').hasMatch(linea)) {
        return linea.trim();
      }
    }
    return null;
  }

  String? _detectarLitros(String texto) {
    final regex = RegExp(
      r'([0-9]+(?:[\.,][0-9]+)?)\s*(?:LITROS?|LTS?|LT)\b',
      caseSensitive: false,
    );
    final match = regex.firstMatch(texto);
    if (match != null) {
      return _normalizarCantidadEscaneada(match.group(1) ?? '');
    }

    final litrosRegex = RegExp(r'\b([0-9]+(?:[\.,][0-9]+)?)\b');
    final candidates = litrosRegex.allMatches(texto).toList();
    for (final candidate in candidates) {
      final valor = candidate.group(1) ?? '';
      final start = candidate.start;
      final end = candidate.end;
      final contexto = texto.substring(
        (start - 18).clamp(0, texto.length),
        (end + 18).clamp(0, texto.length),
      );
      if (contexto.contains('LITRO') || contexto.contains('LT') || contexto.contains('LTS')) {
        return _normalizarCantidadEscaneada(valor);
      }
    }

    return null;
  }

  String? _detectarMontoTotal(String texto) {
    final regex = RegExp(
      r'(?:MONTO|TOTAL|IMPORTE|PAGO|SUBTOTAL)[^0-9]{0,12}([0-9]+(?:[\.,][0-9]{1,2})?)',
      caseSensitive: false,
    );
    final match = regex.firstMatch(texto);
    if (match != null) {
      return _normalizarMontoEscaneado(match.group(1) ?? '');
    }

    final montoRegex = RegExp(r'\b([0-9]+(?:[\.,][0-9]{1,2})?)\b');
    for (final matchCandidate in montoRegex.allMatches(texto)) {
      final valor = matchCandidate.group(1) ?? '';
      final contexto = texto.substring(
        (matchCandidate.start - 18).clamp(0, texto.length),
        (matchCandidate.end + 18).clamp(0, texto.length),
      );
      if (contexto.contains('TOTAL') ||
          contexto.contains('IMPORTE') ||
          contexto.contains('MONTO') ||
          contexto.contains(r'$')) {
        return _normalizarMontoEscaneado(valor);
      }
    }

    return null;
  }

  String? _detectarFormaPago(String texto) {
    final normalizado = texto.toUpperCase();
    if (normalizado.contains('EFECTIVO') || normalizado.contains('CONTADO')) {
      return 'efectivo';
    }
    if (normalizado.contains('DEBITO') || normalizado.contains('TARJETA DE DEBITO')) {
      return 'debito';
    }
    if (normalizado.contains('CREDITO') || normalizado.contains('TARJETA DE CREDITO')) {
      return 'credito';
    }
    if (normalizado.contains('PAGO EN EFECTIVO') || normalizado.contains('CASH')) {
      return 'efectivo';
    }
    return null;
  }

  String? _detectarConcepto(String texto) {
    final normalizado = texto.toUpperCase();
    if (normalizado.contains('DIESEL') || normalizado.contains('DISEL')) {
      return 'diesel';
    }
    if (normalizado.contains('GASOLINA')) return 'gasolina';
    if (normalizado.contains('GAS')) return 'gas';
    return null;
  }

  String? _normalizarFormaPagoIa(String? valor) {
    if (valor == null) return null;
    final texto = _normalizarTextoEscaneado(valor);
    if (texto.contains('EFECTIVO') || texto == '01') return 'efectivo';
    if (texto.contains('DEBITO') || texto == '28') return 'debito';
    if (texto.contains('CREDITO') || texto == '04') return 'credito';
    return null;
  }

  String? _normalizarConceptoIa(String? valor) {
    if (valor == null) return null;
    final texto = _normalizarTextoEscaneado(valor);
    if (texto.contains('DIESEL') || texto.contains('DISEL')) return 'diesel';
    if (texto.contains('GASOLINA')) return 'gasolina';
    if (texto.contains('GAS')) return 'gas';
    return null;
  }

  String? _normalizarUnidadIa(String? valor) {
    if (valor == null) return null;
    final texto = _normalizarTextoEscaneado(valor);
    if (texto.contains('LITRO') || texto == 'LT' || texto == 'LTS') {
      return 'litros';
    }
    if (texto.contains('KILOGRAM') || texto == 'KG') {
      return 'kilogramos';
    }
    return null;
  }

  String _limpiarRespuestaIa(String texto) {
    var limpio = texto.trim();
    if (limpio.startsWith('```json')) {
      limpio = limpio.substring(7).trim();
    } else if (limpio.startsWith('```')) {
      limpio = limpio.substring(3).trim();
    }
    if (limpio.endsWith('```')) {
      limpio = limpio.substring(0, limpio.length - 3).trim();
    }
    return limpio;
  }

  Map<String, dynamic>? _parsearJsonIa(String texto) {
    final limpio = _limpiarRespuestaIa(texto);
    try {
      final jsonObj = jsonDecode(limpio);
      if (jsonObj is Map<String, dynamic>) return jsonObj;
    } catch (_) {}

    final inicio = limpio.indexOf('{');
    final fin = limpio.lastIndexOf('}');
    if (inicio >= 0 && fin > inicio) {
      try {
        final jsonObj = jsonDecode(limpio.substring(inicio, fin + 1));
        if (jsonObj is Map<String, dynamic>) return jsonObj;
      } catch (_) {}
    }
    return null;
  }

  String? _extraerTextoDeGemini(Map<String, dynamic> body) {
    final candidates = body['candidates'];
    if (candidates is! List || candidates.isEmpty) return null;
    final content = candidates.first['content'];
    if (content is! Map<String, dynamic>) return null;
    final parts = content['parts'];
    if (parts is! List || parts.isEmpty) return null;

    for (final part in parts) {
      if (part is Map<String, dynamic>) {
        final text = part['text'];
        if (text is String && text.trim().isNotEmpty) return text;
      }
    }
    return null;
  }

  bool _geminiDisponible() {
    return _geminiApiKey.trim().isNotEmpty;
  }

  Future<({
    String? folio,
    String? litros,
    String? monto,
    String? formaPago,
    String? concepto,
    String? unidad,
    bool esCfdi,
  })?> _extraerDatosConIa(XFile imagen) async {
    if (!_geminiDisponible()) return null;

    final bytes = await imagen.readAsBytes();
    final base64Imagen = base64Encode(bytes);

    final uri = Uri.parse(
      'https://generativelanguage.googleapis.com/v1beta/models/$_geminiModel:generateContent?key=$_geminiApiKey',
    );

    final prompt = '''
Extrae datos de un comprobante de combustible (ticket o factura CFDI) y responde SOLO un JSON valido.

Reglas:
- No escribas explicaciones.
- Si un dato no se detecta, usa null.
- Campos esperados: folio, litros, monto_total, forma_pago, concepto, unidad, tipo_comprobante.
- forma_pago solo puede ser: efectivo, debito, credito o null.
- concepto solo puede ser: gasolina, diesel, gas o null.
- unidad solo puede ser: litros, kilogramos o null.
- tipo_comprobante solo puede ser: cfdi, ticket, desconocido.

Formato de salida obligatorio:
{
  "folio": "...",
  "litros": "...",
  "monto_total": "...",
  "forma_pago": "...",
  "concepto": "...",
  "unidad": "...",
  "tipo_comprobante": "..."
}
''';

    final response = await http.post(
      uri,
      headers: {'Content-Type': 'application/json'},
      body: jsonEncode({
        'contents': [
          {
            'parts': [
              {'text': prompt},
              {
                'inline_data': {'mime_type': 'image/jpeg', 'data': base64Imagen},
              },
            ],
          },
        ],
        'generationConfig': {
          'temperature': 0.1,
          'topP': 0.8,
          'responseMimeType': 'application/json',
        },
      }),
    );

    if (response.statusCode < 200 || response.statusCode >= 300) return null;

    final body = jsonDecode(response.body);
    if (body is! Map<String, dynamic>) return null;

    final texto = _extraerTextoDeGemini(body);
    if (texto == null || texto.trim().isEmpty) return null;

    final jsonIa = _parsearJsonIa(texto);
    if (jsonIa == null) return null;

    final folio = (jsonIa['folio'] as String?)?.trim();
    final litros = _normalizarCantidadEscaneada(
      (jsonIa['litros'] as String?)?.trim() ?? '',
    );
    final monto = _normalizarMontoEscaneado(
      _normalizarTokenNumerico((jsonIa['monto_total'] as String?)?.trim() ?? ''),
    );
    final formaPago = _normalizarFormaPagoIa(jsonIa['forma_pago'] as String?);
    final concepto = _normalizarConceptoIa(jsonIa['concepto'] as String?);
    final unidad = _normalizarUnidadIa(jsonIa['unidad'] as String?) ??
        (litros != null ? 'litros' : null);
    final tipo = _normalizarTextoEscaneado(
      (jsonIa['tipo_comprobante'] as String?)?.trim() ?? '',
    );

    return (
      folio: (folio == null || folio.isEmpty) ? null : folio,
      litros: litros,
      monto: monto,
      formaPago: formaPago,
      concepto: concepto,
      unidad: unidad,
      esCfdi: tipo == 'CFDI',
    );
  }

  ({String? folio, String? litros, String? monto, String? formaPago, String? concepto, String? unidad, bool esCfdi})
  _extraerDatosComprobante(String textoOriginal) {
    final texto = _normalizarTextoEscaneado(textoOriginal);
    final esCfdi = texto.contains('CFDI') ||
        texto.contains('COMPROBANTE FISCAL') ||
        texto.contains('FOLIO FISCAL') ||
        texto.contains('UUID') ||
        texto.contains('FACTURA');

    final folio = _detectarFolio(texto);
    final litros = _detectarLitros(texto);
    final monto = _detectarMontoTotal(texto);
    final formaPago = _detectarFormaPago(texto);
    final concepto = _detectarConcepto(texto);

    return (
      folio: folio,
      litros: litros,
      monto: monto,
      formaPago: formaPago,
      concepto: concepto,
      unidad: litros != null ? 'litros' : null,
      esCfdi: esCfdi,
    );
  }

  void _limpiarCamposEscaneo() {
    _folioController.clear();
    _cantidadController.clear();
    _montoController.clear();
    _concepto = null;
    _unidad = null;
    _metodoPago = null;
  }

  void _aplicarDatosEscaneados({
    String? folio,
    String? litros,
    String? monto,
    String? formaPago,
    String? concepto,
    String? unidad,
    bool reemplazarTodo = true,
  }) {
    setState(() {
      if (reemplazarTodo) {
        _limpiarCamposEscaneo();
      }

      if (folio != null && folio.isNotEmpty) {
        _folioController.text = folio;
      }
      if (litros != null && litros.isNotEmpty) {
        _cantidadController.text = litros;
      }
      if (monto != null && monto.isNotEmpty) {
        _montoController.text = monto;
      }

      if (concepto != null && concepto.isNotEmpty) {
        _concepto = concepto;
      }
      if (unidad != null && unidad.isNotEmpty) {
        _unidad = unidad;
      }
      if (formaPago != null && formaPago.isNotEmpty) {
        _metodoPago = formaPago;
      }
    });
  }

  int _contarCamposDetectados({
    String? folio,
    String? litros,
    String? monto,
    String? formaPago,
    String? concepto,
  }) {
    var total = 0;
    if (folio != null && folio.isNotEmpty) total++;
    if (litros != null && litros.isNotEmpty) total++;
    if (monto != null && monto.isNotEmpty) total++;
    if (formaPago != null && formaPago.isNotEmpty) total++;
    if (concepto != null && concepto.isNotEmpty) total++;
    return total;
  }

  Future<void> _intentarMejoraConIa({
    required XFile imagen,
    required int camposLocales,
    required bool fallbackAutomatico,
  }) async {
    if (_mejoraIaEnProgreso) return;

    if (!_geminiDisponible()) {
      if (!fallbackAutomatico) {
        _mostrarMensajeEscaneo(
          'Falta configurar GEMINI_API_KEY. Ejecuta la app con --dart-define=GEMINI_API_KEY=TU_API_KEY.',
          error: true,
        );
      }
      return;
    }

    setState(() {
      _mejoraIaEnProgreso = true;
    });

    try {
      final datosIa = await _extraerDatosConIa(imagen);
      if (datosIa == null) {
        if (!fallbackAutomatico) {
          _mostrarMensajeEscaneo(
            'La IA no pudo extraer datos en este intento.',
            error: true,
          );
        }
        return;
      }

      final camposIa = _contarCamposDetectados(
        folio: datosIa.folio,
        litros: datosIa.litros,
        monto: datosIa.monto,
        formaPago: datosIa.formaPago,
        concepto: datosIa.concepto,
      );

      if (camposIa == 0) {
        if (!fallbackAutomatico) {
          _mostrarMensajeEscaneo(
            'La IA no encontró datos utilizables en la imagen.',
            error: true,
          );
        }
        return;
      }

      _aplicarDatosEscaneados(
        folio: datosIa.folio,
        litros: datosIa.litros,
        monto: datosIa.monto,
        formaPago: datosIa.formaPago,
        concepto: datosIa.concepto,
        unidad: datosIa.unidad,
        reemplazarTodo: camposLocales == 0,
      );

      final tipo = datosIa.esCfdi ? 'factura CFDI' : 'ticket simple';
      _mostrarMensajeEscaneo(
        fallbackAutomatico
            ? 'Se mejoró el escaneo automáticamente con IA ($tipo).'
            : 'Mejora con IA completada ($tipo). Verifica la información.',
      );
      await _mostrarAvisoVerificacion();
    } catch (_) {
      if (!fallbackAutomatico) {
        _mostrarMensajeEscaneo(
          'Ocurrió un error al consultar la IA.',
          error: true,
        );
      }
    } finally {
      if (mounted) {
        setState(() {
          _mejoraIaEnProgreso = false;
        });
      }
    }
  }

  void _mostrarMensajeEscaneo(String mensaje, {bool error = false}) {
    if (!mounted) return;

    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        backgroundColor: error ? Colors.red.shade700 : Colors.green.shade700,
        content: Text(mensaje),
      ),
    );
  }

  Future<void> _mostrarAvisoVerificacion() async {
    if (!mounted) return;

    await showDialog<void>(
      context: context,
      builder: (_) => AlertDialog(
        title: const Text('Verifica los datos'),
        content: const Text(
          'El escaneo se completó. Revisa y corrige manualmente cualquier dato antes de registrar, porque el OCR puede cometer errores.',
        ),
        actions: [
          FilledButton(
            onPressed: () => Navigator.of(context).pop(),
            child: const Text('Entendido'),
          ),
        ],
      ),
    );
  }

  Future<void> _mostrarDialogoManual() async {
    if (!mounted) return;

    await showDialog<void>(
      context: context,
      builder: (_) => AlertDialog(
        title: const Text('Comprobante no legible'),
        content: const Text(
          'No se pudo detectar el comprobante después de 3 intentos. Te sugerimos capturar los datos manualmente para continuar.',
        ),
        actions: [
          FilledButton(
            onPressed: () => Navigator.of(context).pop(),
            child: const Text('Entendido'),
          ),
        ],
      ),
    );
  }

  Future<void> _escanearComprobante() async {
    if (_escaneoEnProgreso) return;

    final esMovil = !kIsWeb &&
        (defaultTargetPlatform == TargetPlatform.android ||
            defaultTargetPlatform == TargetPlatform.iOS);

    if (!esMovil) {
      _mostrarMensajeEscaneo(
        'El escaneo de comprobantes solo está disponible en Android e iPhone.',
        error: true,
      );
      return;
    }

    setState(() {
      _escaneoEnProgreso = true;
    });

    try {
      final imagen = await _imagePicker.pickImage(
        source: ImageSource.camera,
        imageQuality: 100,
        preferredCameraDevice: CameraDevice.rear,
      );

      if (imagen == null) return;

      _ultimaImagenEscaneada = imagen;

      final inputImage = InputImage.fromFilePath(imagen.path);
      final recognizer = TextRecognizer(script: TextRecognitionScript.latin);

      try {
        final recognizedText = await recognizer.processImage(inputImage);
        final texto = recognizedText.text.trim();

        if (texto.isEmpty) {
          _intentosEscaneoFallidos += 1;
          _mostrarMensajeEscaneo(
            'El comprobante no fue legible. Toma la foto de nuevo con más luz y enfoque.',
            error: true,
          );
          if (_intentosEscaneoFallidos >= 3) {
            await _mostrarDialogoManual();
          }
          return;
        }

        final datos = _extraerDatosComprobante(texto);
        final camposLocales = _contarCamposDetectados(
          folio: datos.folio,
          litros: datos.litros,
          monto: datos.monto,
          formaPago: datos.formaPago,
          concepto: datos.concepto,
        );
        final hayDatos = camposLocales > 0;

        if (hayDatos) {
          _aplicarDatosEscaneados(
            folio: datos.folio,
            litros: datos.litros,
            monto: datos.monto,
            formaPago: datos.formaPago,
            concepto: datos.concepto,
            unidad: datos.unidad,
          );
        }

        if (camposLocales < 3) {
          await _intentarMejoraConIa(
            imagen: imagen,
            camposLocales: camposLocales,
            fallbackAutomatico: true,
          );
        }

        if (!hayDatos) {
          _intentosEscaneoFallidos += 1;
          _mostrarMensajeEscaneo(
            'Se leyó la imagen pero no se pudieron detectar folio, litros, monto o forma de pago. Acerca el ticket, evita reflejos e intenta de nuevo.',
            error: true,
          );
          if (_intentosEscaneoFallidos >= 3) {
            await _mostrarDialogoManual();
          }
          return;
        }

        _intentosEscaneoFallidos = 0;

        final tipo = datos.esCfdi ? 'factura CFDI' : 'ticket simple';
        if (camposLocales >= 3) {
          _mostrarMensajeEscaneo('Escaneo completado: se detectó $tipo.');
        } else {
          _mostrarMensajeEscaneo(
            _geminiDisponible()
                ? 'Escaneo parcial detectado ($tipo). Se aplicó mejora automática con IA para completar más campos.'
                : 'Escaneo parcial detectado ($tipo). Puedes completar los campos faltantes manualmente.',
          );
        }
        await _mostrarAvisoVerificacion();
      } finally {
        await recognizer.close();
      }
    } catch (_) {
      _intentosEscaneoFallidos += 1;
      _mostrarMensajeEscaneo(
        'No fue posible leer el comprobante. Intenta tomar la foto de nuevo.',
        error: true,
      );
      if (_intentosEscaneoFallidos >= 3) {
        await _mostrarDialogoManual();
      }
    } finally {
      if (mounted) {
        setState(() {
          _escaneoEnProgreso = false;
        });
      }
    }
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
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text('Registro guardado')),
    );
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

  Widget _buildFieldLabel(String text) {
    return Text(
      text,
      style: const TextStyle(
        fontWeight: FontWeight.w800,
        fontSize: 12,
        letterSpacing: 0.3,
        color: Color(0xFF334155),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final inputBorder = OutlineInputBorder(
      borderRadius: BorderRadius.circular(14),
      borderSide: BorderSide(color: _primary.withValues(alpha: 0.15)),
    );

    return Scaffold(
      extendBodyBehindAppBar: true,
      backgroundColor: const Color(0xFFF3F6FB),
      appBar: AppBar(
        elevation: 0,
        backgroundColor: Colors.transparent,
        foregroundColor: Colors.white,
        centerTitle: true,
        flexibleSpace: Container(
          decoration: const BoxDecoration(
            gradient: LinearGradient(
              colors: [Color(0xFF14532D), Color(0xFF0F766E)],
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
            ),
          ),
        ),
        title: const Text(
          'Registro de Combustible',
          style: TextStyle(
            fontWeight: FontWeight.w800,
            color: Colors.white,
          ),
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
          FadeTransition(
            opacity: _fadeAnimation,
            child: SlideTransition(
              position: _slideAnimation,
              child: SingleChildScrollView(
                padding: const EdgeInsets.fromLTRB(16, 92, 16, 20),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    Container(
                      padding: const EdgeInsets.all(18),
                      decoration: BoxDecoration(
                        borderRadius: BorderRadius.circular(22),
                        gradient: const LinearGradient(
                          colors: [Color(0xFF14532D), Color(0xFF0F766E)],
                          begin: Alignment.topLeft,
                          end: Alignment.bottomRight,
                        ),
                        boxShadow: [
                          BoxShadow(
                            color: _primary.withValues(alpha: 0.18),
                            blurRadius: 24,
                            offset: const Offset(0, 10),
                          ),
                        ],
                      ),
                      child: Row(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Container(
                            width: 54,
                            height: 54,
                            decoration: BoxDecoration(
                              color: Colors.white.withValues(alpha: 0.12),
                              borderRadius: BorderRadius.circular(16),
                              border: Border.all(
                                color: Colors.white.withValues(alpha: 0.14),
                              ),
                            ),
                            child: const Icon(
                              Icons.local_gas_station_rounded,
                              color: Colors.white,
                              size: 28,
                            ),
                          ),
                          const SizedBox(width: 14),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                const Text(
                                  'Nuevo registro de combustible',
                                  style: TextStyle(
                                    fontSize: 20,
                                    fontWeight: FontWeight.w800,
                                    color: Colors.white,
                                  ),
                                ),
                                const SizedBox(height: 6),
                                Text(
                                  'Al escanear, los datos se autorellenan automáticamente. Si el escaneo no lee bien, revisa y modifica manualmente antes de registrar.',
                                  style: TextStyle(
                                    color: Colors.white.withValues(alpha: 0.82),
                                    height: 1.35,
                                  ),
                                ),
                              ],
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
                        borderRadius: BorderRadius.circular(20),
                        border: Border.all(
                          color: _primary.withValues(alpha: 0.08),
                        ),
                        boxShadow: [
                          BoxShadow(
                            color: _primary.withValues(alpha: 0.06),
                            blurRadius: 18,
                            offset: const Offset(0, 8),
                          ),
                        ],
                      ),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.stretch,
                        children: [
                          FilledButton.icon(
                            onPressed:
                                (_escaneoEnProgreso || _mejoraIaEnProgreso)
                                    ? null
                                    : _escanearComprobante,
                            icon: (_escaneoEnProgreso || _mejoraIaEnProgreso)
                                ? const SizedBox(
                                    width: 18,
                                    height: 18,
                                    child: CircularProgressIndicator(
                                      strokeWidth: 2,
                                      color: Colors.white,
                                    ),
                                  )
                                : const Icon(Icons.document_scanner_rounded),
                            label: Text(
                              _escaneoEnProgreso
                                  ? 'Escaneando comprobante...'
                                  : (_mejoraIaEnProgreso
                                        ? 'Mejorando con IA...'
                                        : 'Escanear comprobante (auto IA)'),
                            ),
                            style: FilledButton.styleFrom(
                              backgroundColor: const Color(0xFF0F766E),
                              foregroundColor: Colors.white,
                              padding: const EdgeInsets.symmetric(
                                vertical: 15,
                                horizontal: 16,
                              ),
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(16),
                              ),
                            ),
                          ),
                          if (!_geminiDisponible()) ...[
                            const SizedBox(height: 10),
                            Container(
                              padding: const EdgeInsets.all(12),
                              decoration: BoxDecoration(
                                color: _warning.withValues(alpha: 0.12),
                                borderRadius: BorderRadius.circular(14),
                                border: Border.all(
                                  color: _warning.withValues(alpha: 0.25),
                                ),
                              ),
                              child: Row(
                                children: [
                                  const Icon(
                                    Icons.auto_awesome_rounded,
                                    color: Color(0xFFB45309),
                                  ),
                                  const SizedBox(width: 10),
                                  Expanded(
                                    child: Text(
                                      'La mejora automática con IA requiere GEMINI_API_KEY.',
                                      style: TextStyle(
                                        fontSize: 12,
                                        color: _primary.withValues(alpha: 0.76),
                                        fontWeight: FontWeight.w600,
                                      ),
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          ],
                        ],
                      ),
                    ),
                    const SizedBox(height: 14),
                    Container(
                      padding: const EdgeInsets.all(16),
                      decoration: BoxDecoration(
                        color: Colors.white,
                        borderRadius: BorderRadius.circular(20),
                        border: Border.all(
                          color: _primary.withValues(alpha: 0.08),
                        ),
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
                          _buildFieldLabel('Folio'),
                          const SizedBox(height: 6),
                          TextField(
                            controller: _folioController,
                            textInputAction: TextInputAction.next,
                            decoration: InputDecoration(
                              hintText: 'Ej: F-00124',
                              prefixIcon: const Icon(Icons.receipt_long_rounded),
                              filled: true,
                              fillColor: const Color(0xFFF8FAFC),
                              border: inputBorder,
                              enabledBorder: inputBorder,
                              focusedBorder: inputBorder.copyWith(
                                borderSide: BorderSide(color: _accent, width: 1.6),
                              ),
                            ),
                          ),
                          const SizedBox(height: 12),
                          _buildFieldLabel('Unidad'),
                          const SizedBox(height: 6),
                          DropdownButtonFormField<String>(
                            initialValue: _unidad,
                            hint: const Text('Selecciona unidad'),
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
                              if (value != null) setState(() => _unidad = value);
                            },
                            decoration: InputDecoration(
                              prefixIcon: const Icon(Icons.straighten_rounded),
                              filled: true,
                              fillColor: const Color(0xFFF8FAFC),
                              border: inputBorder,
                              enabledBorder: inputBorder,
                              focusedBorder: inputBorder.copyWith(
                                borderSide: BorderSide(color: _accent, width: 1.6),
                              ),
                            ),
                          ),
                          const SizedBox(height: 12),
                          _buildFieldLabel('Cantidad'),
                          const SizedBox(height: 6),
                          TextField(
                            controller: _cantidadController,
                            textInputAction: TextInputAction.next,
                            keyboardType: const TextInputType.numberWithOptions(
                              decimal: true,
                            ),
                            decoration: InputDecoration(
                              hintText: '0.00',
                              prefixIcon: const Icon(Icons.numbers_rounded),
                              filled: true,
                              fillColor: const Color(0xFFF8FAFC),
                              border: inputBorder,
                              enabledBorder: inputBorder,
                              focusedBorder: inputBorder.copyWith(
                                borderSide: BorderSide(
                                  color: _accent,
                                  width: 1.6,
                                ),
                              ),
                            ),
                          ),
                          const SizedBox(height: 12),
                          _buildFieldLabel('Método de pago'),
                          const SizedBox(height: 6),
                          DropdownButtonFormField<String>(
                            initialValue: _metodoPago,
                            hint: const Text('Selecciona forma de pago'),
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
                              if (value != null) setState(() => _metodoPago = value);
                            },
                            decoration: InputDecoration(
                              prefixIcon: const Icon(Icons.payment_rounded),
                              filled: true,
                              fillColor: const Color(0xFFF8FAFC),
                              border: inputBorder,
                              enabledBorder: inputBorder,
                              focusedBorder: inputBorder.copyWith(
                                borderSide: BorderSide(color: _accent, width: 1.6),
                              ),
                            ),
                          ),
                          const SizedBox(height: 12),
                          _buildFieldLabel('Monto'),
                          const SizedBox(height: 6),
                          TextField(
                            controller: _montoController,
                            textInputAction: TextInputAction.next,
                            keyboardType: const TextInputType.numberWithOptions(
                              decimal: true,
                            ),
                            decoration: InputDecoration(
                              hintText: '0.00',
                              prefixIcon: const Icon(Icons.attach_money_rounded),
                              filled: true,
                              fillColor: const Color(0xFFF8FAFC),
                              border: inputBorder,
                              enabledBorder: inputBorder,
                              focusedBorder: inputBorder.copyWith(
                                borderSide: BorderSide(
                                  color: _accent,
                                  width: 1.6,
                                ),
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

                        final registrarButton = FilledButton.icon(
                          onPressed: _guardarRegistro,
                          style: FilledButton.styleFrom(
                            backgroundColor: const Color(0xFF10B981),
                            foregroundColor: Colors.white,
                            padding: const EdgeInsets.symmetric(vertical: 15),
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(16),
                            ),
                            elevation: 4,
                          ),
                          icon: const Icon(Icons.check_circle_rounded),
                          label: const Text(
                            'Registrar',
                            style: TextStyle(fontWeight: FontWeight.w700),
                          ),
                        );

                        final cancelarButton = OutlinedButton.icon(
                          onPressed: _cancelarRegistro,
                          style: OutlinedButton.styleFrom(
                            backgroundColor: const Color(0xFFDC2626),
                            foregroundColor: Colors.white,
                            side: BorderSide(
                              color: const Color(0xFFDC2626),
                            ),
                            padding: const EdgeInsets.symmetric(vertical: 15),
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(16),
                            ),
                          ),
                          icon: const Icon(Icons.cancel_rounded),
                          label: const Text(
                            'Cancelar',
                            style: TextStyle(fontWeight: FontWeight.w700),
                          ),
                        );

                        if (isNarrow) {
                          return Column(
                            crossAxisAlignment: CrossAxisAlignment.stretch,
                            children: [
                              registrarButton,
                              const SizedBox(height: 10),
                              cancelarButton,
                            ],
                          );
                        }

                        return Row(
                          children: [
                            Expanded(child: registrarButton),
                            const SizedBox(width: 10),
                            Expanded(child: cancelarButton),
                          ],
                        );
                      },
                    ),
                  ],
                ),
              ),
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
