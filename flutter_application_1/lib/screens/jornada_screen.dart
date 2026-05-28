import 'dart:async';
import 'dart:typed_data';


import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_storage/firebase_storage.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:geolocator/geolocator.dart';
import 'package:image_picker/image_picker.dart';
import 'package:intl/intl.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'operador_screen.dart';
import 'reporte_screen.dart'; // Asegúrate de que esta línea esté presente
import 'widgets_conexion/connection_wrapper.dart';
import 'widgets/menu_lateral.dart';
import 'widgets/notificaciones_drawer.dart';
import '../widgets/jornada_bottom_bar.dart';
import 'contenedores_operador_screen.dart';
import 'registro_origen_screen.dart';
import 'registro_toneladas_screen.dart';
import 'package:flutter/foundation.dart' show defaultTargetPlatform, TargetPlatform;
import 'package:geolocator_android/geolocator_android.dart';
import 'package:geolocator_apple/geolocator_apple.dart';
import '../services/ubicacion_service.dart';

Widget _buildReportAppBarAction(VoidCallback onPressed) {
  return Padding(
    padding: const EdgeInsets.only(right: 8),
    child: TextButton(
      style: TextButton.styleFrom(
        backgroundColor: const Color(0xFFFFF8E1),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
      ),
      onPressed: onPressed,
      child: Row(
        children: const [
          Icon(Icons.report_problem_rounded, color: Color(0xFFBF360C), size: 24),
          SizedBox(width: 6),
          Text(
            'Reportar',
            style: TextStyle(
              color: Color(0xFFBF360C),
              fontWeight: FontWeight.w800,
              fontSize: 14,
            ),
          ),
        ],
      ),
    ),
  );
}


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
  static const String _keyRecosBase = 'ubicacion_recos_jornada_mostradas_';

  @override
  void initState() {
    super.initState();
    
    // Inicializar y arrancar el servicio de ubicación persistente global
    UbicacionService().inicializar(widget.operador).then((_) {
      if (mounted && _compartirUbicacion) {
        _iniciarMonitoreoUbicacion();
      }
    });

    // Escuchar notificaciones para redibujar cambios en tiempo real
    UbicacionService().compartiendoUbicacionActiva.addListener(_onUbicacionStateChanged);
    UbicacionService().compartirUbicacionSolicitada.addListener(_onUbicacionStateChanged);
    UbicacionService().estadoUbicacion.addListener(_onUbicacionStateChanged);
    UbicacionService().permisoUbicacionOtorgado.addListener(_onUbicacionStateChanged);
    UbicacionService().servicioUbicacionActivo.addListener(_onUbicacionStateChanged);

    _sincronizarVariablesUbicacion();

    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      setState(() => _contentVisible = true);
      _mostrarGuiaPermisoUbicacionPrimeraVez();
      _mostrarRecomendacionesUbicacion();
    });
  }

  void _onUbicacionStateChanged() {
    if (mounted) {
      setState(() {
        _sincronizarVariablesUbicacion();
      });
    }
  }

  void _sincronizarVariablesUbicacion() {
    final service = UbicacionService();
    _compartiendoUbicacionActiva = service.compartiendoUbicacionActiva.value;
    _compartirUbicacion = service.compartirUbicacionSolicitada.value;
    _estadoUbicacion = service.estadoUbicacion.value;
    _permisoUbicacionOtorgado = service.permisoUbicacionOtorgado.value;
    _servicioUbicacionActivo = service.servicioUbicacionActivo.value;
    _alertaUbicacionMostrada = service.alertaUbicacionMostrada.value;
  }

  Future<void> _refrescarJornada() async {
    _sincronizarVariablesUbicacion();
    if (_compartirUbicacion) {
      await _iniciarMonitoreoUbicacion();
    }
    if (mounted) setState(() {});
  }

  Future<void> _mostrarGuiaPermisoUbicacionPrimeraVez() async {
    if (defaultTargetPlatform != TargetPlatform.android) return;

    final prefs = await SharedPreferences.getInstance();
    final yaMostrada = prefs.getBool('ubicacion_guia_mostrada') ?? false;
    if (yaMostrada) return;

    final permiso = await Geolocator.checkPermission();
    if (permiso == LocationPermission.always) {
      await prefs.setBool('ubicacion_guia_mostrada', true);
      return;
    }

    if (!mounted) return;
    await prefs.setBool('ubicacion_guia_mostrada', true);

    await showDialog<void>(
      context: context,
      barrierDismissible: true,
      builder: (context) {
        return AlertDialog(
          title: const Text('Permitir ubicacion'),
          content: const Text(
            'Para compartir tu ubicacion:\n'
            '1) Permite el acceso a ubicacion.\n'
            '2) Puedes elegir "Mientras se usa" o "Solo esta vez".',
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(context).pop(),
              child: const Text('Ahora no'),
            ),
            TextButton(
              onPressed: () async {
                Navigator.of(context).pop();
                UbicacionService().marcarAjustesUbicacionSolicitados();
                await Geolocator.openAppSettings();
              },
              child: const Text('Ir a Ajustes'),
            ),
          ],
        );
      },
    );
  }

  Future<void> _mostrarRecomendacionesUbicacion() async {
    final prefs = await SharedPreferences.getInstance();
    final uid = FirebaseAuth.instance.currentUser?.uid ?? widget.operador;
    final key = '$_keyRecosBase$uid';
    final yaMostrada = prefs.getBool(key) ?? false;
    if (yaMostrada) return;
    await prefs.setBool(key, true);

    if (!mounted) return;
    await showDialog<void>(
      context: context,
      barrierDismissible: true,
      builder: (context) {
        return AlertDialog(
          title: const Text('Recomendaciones de ubicacion'),
          content: const Text(
            'Activa la ubicacion solo cuando salgas a ruta de recoleccion.\n'
            'La ubicacion en tiempo real requiere acceso a internet (datos o WiFi).\n'
            'Desactiva la ubicacion cuando no se use para ahorrar bateria.',
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(context).pop(),
              child: const Text('Entendido'),
            ),
          ],
        );
      },
    );
  }

  Future<bool> _confirmarGpsApagado() async {
    if (!mounted) return false;

    final confirmar = await showDialog<bool>(
      context: context,
      barrierDismissible: true,
      builder: (context) => AlertDialog(
        title: const Text('GPS desactivado'),
        content: const Text('Deseas mostrar los ajustes de ubicacion?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(false),
            child: const Text('Ahora no'),
          ),
          TextButton(
            onPressed: () => Navigator.of(context).pop(true),
            child: const Text('OK'),
          ),
        ],
      ),
    );

    if (confirmar == true) {
      await Geolocator.openLocationSettings();
    }

    return confirmar == true;
  }

  @override
  void dispose() {
    // IMPORTANTE: NO detenemos el servicio aquí, ya que queremos que siga transmitiendo
    // en segundo plano o cuando el operador navegue a otras pantallas.
    // Solo removemos los escuchas del ciclo de vida del Widget.
    UbicacionService().compartiendoUbicacionActiva.removeListener(_onUbicacionStateChanged);
    UbicacionService().compartirUbicacionSolicitada.removeListener(_onUbicacionStateChanged);
    UbicacionService().estadoUbicacion.removeListener(_onUbicacionStateChanged);
    UbicacionService().permisoUbicacionOtorgado.removeListener(_onUbicacionStateChanged);
    UbicacionService().servicioUbicacionActivo.removeListener(_onUbicacionStateChanged);

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


void _mostrarSeleccionEntradaMaterial() {
  showDialog(
    context: context,
    builder: (_) => Dialog(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(24)),
      backgroundColor: Colors.transparent,
      child: Container(
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(24),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withOpacity(0.18),
              blurRadius: 40,
              offset: const Offset(0, 16),
            ),
          ],
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            // --- ENCABEZADO (Diseño Azul) ---
            Container(
              width: double.infinity,
              padding: const EdgeInsets.fromLTRB(24, 24, 24, 20),
              decoration: const BoxDecoration(
                gradient: LinearGradient(
                  colors: [Color(0xFF031A47), Color(0xFF022A60)],
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                ),
                borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Container(
                        padding: const EdgeInsets.all(10),
                        decoration: BoxDecoration(
                          color: Colors.white.withOpacity(0.15),
                          borderRadius: BorderRadius.circular(12),
                        ),
                        child: const Icon(Icons.where_to_vote_rounded,
                            color: Colors.white, size: 22),
                      ),
                      const SizedBox(width: 12),
                      const Expanded(
                        child: Text(
                          'Antes de registrar el material',
                          style: TextStyle(
                            color: Colors.white,
                            fontSize: 17,
                            fontWeight: FontWeight.w800,
                          ),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 10),
                  Text(
                    'Selecciona dónde realizarás la carga',
                    style: TextStyle(
                      color: Colors.white.withOpacity(0.75),
                      fontSize: 13,
                    ),
                  ),
                ],
              ),
            ),

            // --- CUERPO (Opciones de selección) ---
            Padding(
              padding: const EdgeInsets.all(20),
              child: Column(
                children: [
                  
                  // OPCIÓN 1: DENTRO (Registro de Toneladas Normal)
                  GestureDetector(
                    onTap: () {
                      Navigator.pop(context); // Cierra el modal
                      Navigator.push(
                        context,
                        MaterialPageRoute(
                          builder: (context) => RegistroToneladasScreen(
                            operador: widget.operador,
                            camion:   widget.camion,
                            placas:   widget.placas,
                          ),
                        ),
                      );
                    },
                    child: Container(
                      padding: const EdgeInsets.all(16),
                      decoration: BoxDecoration(
                        color: const Color(0xFF06B6D4).withOpacity(0.05),
                        borderRadius: BorderRadius.circular(16),
                        border: Border.all(
                            color: const Color(0xFF06B6D4).withOpacity(0.35),
                            width: 1.5),
                      ),
                      child: Row(
                        children: [
                          Container(
                            padding: const EdgeInsets.all(12),
                            decoration: BoxDecoration(
                              color: const Color(0xFF06B6D4).withOpacity(0.12),
                              borderRadius: BorderRadius.circular(12),
                            ),
                            child: const Icon(Icons.factory_rounded,
                                color: Color(0xFF06B6D4), size: 26),
                          ),
                          const SizedBox(width: 14),
                          const Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text('Dentro de la recicladora',
                                    style: TextStyle(
                                        fontSize: 15,
                                        fontWeight: FontWeight.w800,
                                        color: Color(0xFF0F172A))),
                                SizedBox(height: 3),
                                Text('El material entra directamente a planta.',
                                    style: TextStyle(
                                        fontSize: 12,
                                        color: Color(0xFF64748B))),
                              ],
                            ),
                          ),
                          const Icon(Icons.arrow_forward_ios_rounded,
                              size: 14, color: Color(0xFF06B6D4)),
                        ],
                      ),
                    ),
                  ),
                  
                  const SizedBox(height: 12),

                  // OPCIÓN 2: FUERA (Pantalla Externa Nueva)
                  GestureDetector(
                    onTap: () {
                      Navigator.pop(context); // Cierra el modal
                      Navigator.push(
                        context,
                        MaterialPageRoute(
                          builder: (context) => RegistroOrigenScreen(
                            operador: widget.operador,
                            camion:   widget.camion,
                            placas:   widget.placas,
                          ),
                        ),
                      );
                    },
                    child: Container(
                      padding: const EdgeInsets.all(16),
                      decoration: BoxDecoration(
                        color: const Color(0xFF10B981).withOpacity(0.05),
                        borderRadius: BorderRadius.circular(16),
                        border: Border.all(
                            color: const Color(0xFF10B981).withOpacity(0.35),
                            width: 1.5),
                      ),
                      child: Row(
                        children: [
                          Container(
                            padding: const EdgeInsets.all(12),
                            decoration: BoxDecoration(
                              color: const Color(0xFF10B981).withOpacity(0.12),
                              borderRadius: BorderRadius.circular(12),
                            ),
                            child: const Icon(Icons.local_shipping_rounded,
                                color: Color(0xFF10B981), size: 26),
                          ),
                          const SizedBox(width: 14),
                          const Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text('Fuera de la recicladora',
                                    style: TextStyle(
                                        fontSize: 15,
                                        fontWeight: FontWeight.w800,
                                        color: Color(0xFF0F172A))),
                                SizedBox(height: 3),
                                Text('Saldrás a recoger material externo.',
                                    style: TextStyle(
                                        fontSize: 12,
                                        color: Color(0xFF64748B))),
                              ],
                            ),
                          ),
                          const Icon(Icons.arrow_forward_ios_rounded,
                              size: 14, color: Color(0xFF10B981)),
                        ],
                      ),
                    ),
                  ),

                  const SizedBox(height: 8),

                  // BOTÓN CANCELAR
                  TextButton(
                    onPressed: () => Navigator.pop(context),
                    child: const Text('Cancelar',
                        style: TextStyle(color: Color(0xFF64748B))),
                  ),
                ],
              ),
            ),
          ],
        ),
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

  void _irAInicio() {
    return;
  }

  void _irARegistros() {
    Navigator.of(context).pushReplacement(
      MaterialPageRoute(
        builder: (_) => RegistrosJornadaScreen(
          operador: widget.operador,
          camion: widget.camion,
          placas: widget.placas,
          historial: false,
        ),
      ),
    );
  }

  void _irAHistorial() {
    Navigator.of(context).pushReplacement(
      MaterialPageRoute(
        builder: (_) => RegistrosJornadaScreen(
          operador: widget.operador,
          camion: widget.camion,
          placas: widget.placas,
          historial: true,
        ),
      ),
    );
  }

  void _irAPerfil() {
    Navigator.of(context).pushReplacement(
      MaterialPageRoute(
        builder: (_) => PerfilOperadorScreen(
          operador: widget.operador,
          camion: widget.camion,
          placas: widget.placas,
        ),
      ),
    );
  }

  void _irAReporte() {
    Navigator.of(context).push(
      MaterialPageRoute(
        builder: (_) => ReporteScreen(
          nombreUsuario: widget.operador,
          camion: widget.camion,
          placas: widget.placas,
        ),
      ),
    );
  }

  void _irAContenedores() {
    Navigator.of(context).pushReplacement(
      MaterialPageRoute(builder: (_) => ContenedoresOperadorScreen(
        operador: widget.operador,
        camion: widget.camion,
        placas: widget.placas,
      )),
    );
  }

  Widget _buildContenedoresMiniRow() {
    final ids = ['contenedor-1', 'contenedor-2', 'contenedor-3'];
    return StreamBuilder<QuerySnapshot<Map<String, dynamic>>>(
      stream: FirebaseFirestore.instance.collection('contenedores').where(FieldPath.documentId, whereIn: ids).snapshots(),
      builder: (context, snap) {
        final docs = snap.data?.docs ?? [];
        Map<String, Map<String, dynamic>> map = {};
        for (final d in docs) map[d.id] = d.data();

        Color _colorFor(String estado) {
          switch (estado) {
            case 'En proceso de llenado': return const Color(0xFFF59E0B);
            case 'Lleno': return const Color(0xFF10B981);
            case 'Fuera de servicio': return const Color(0xFFEF4444);
            default: return const Color(0xFF64748B);
          }
        }

        IconData _iconFor(String estado) {
          switch (estado) {
            case 'En proceso de llenado': return Icons.hourglass_top_rounded;
            case 'Lleno': return Icons.done_all_rounded;
            case 'Fuera de servicio': return Icons.build_circle_rounded;
            default: return Icons.inventory_2_outlined;
          }
        }

        return Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: ids.map((id) {
            final d = map[id];
            final estado = d?['estado']?.toString() ?? 'Fuera de servicio';
            final color = _colorFor(estado);
            final icon = _iconFor(estado);

            return Expanded(
              child: GestureDetector(
                onTap: _irAContenedores,
                child: Container(
                  margin: const EdgeInsets.symmetric(horizontal: 6),
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    gradient: LinearGradient(
                      colors: [color.withOpacity(0.12), Colors.white],
                      begin: Alignment.topLeft,
                      end: Alignment.bottomRight,
                    ),
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(color: color.withOpacity(0.22)),
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.center,
                    children: [
                      CircleAvatar(
                        backgroundColor: color,
                        child: Icon(icon, color: Colors.white, size: 18),
                        radius: 18,
                      ),
                      const SizedBox(height: 8),
                      Text('C ${id.split('-').last}', style: const TextStyle(fontWeight: FontWeight.w700)),
                      const SizedBox(height: 4),
                      Text(estado, textAlign: TextAlign.center, style: const TextStyle(fontSize: 11, color: Color(0xFF475569))),
                    ],
                  ),
                ),
              ),
            );
          }).toList(),
        );
      },
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

  Future<void> _inicializarNotificacionesUbicacion() async {}
  
  Future<void> _actualizarGpsEnFirestore({
    required bool gpsActivo,
    Position? posicion,
    String? estado,
  }) async {}

  Future<void> _mostrarAlertaUbicacionApagada(String motivo) async {}

  void _limpiarAlertaUbicacion() {}

  Future<void> _cargarEstadoAlertaUbicacion() async {}

  Future<void> _inicializarMonitoreoUbicacion() async {}

  Future<void> _detenerMonitoreoUbicacion({String? motivo}) async {
    await UbicacionService().detenerMonitoreo(motivo: motivo);
  }

  Future<void> _iniciarMonitoreoUbicacion() async {
    final servicioActivo = await Geolocator.isLocationServiceEnabled();
    if (!servicioActivo) {
      await _confirmarGpsApagado();
      return;
    }
    await UbicacionService().iniciarMonitoreo();
  }

  void _escucharCambiosServicioUbicacion() {}

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
                child: const Icon(Icons.scale_rounded, color: _accent),
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

    final usuariosRef = FirebaseFirestore.instance.collection("usuarios");
    final userRef = usuariosRef.doc(widget.operador);
    final userDoc = await userRef.get();
    final camionId = (userDoc.data()?['camion_id'] ?? '').toString();
    final uidDocId = FirebaseAuth.instance.currentUser?.uid ?? '';

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

    final cierreJornada = <String, dynamic>{
      "jornada_activa": false,
      "camion_id": "",
      "camion_actual": "",
      "placas_actuales": "",
      "gps_activo": false,
      "alerta_ubicacion_desactivada_mostrada": false,
    };

    /// Cerrar jornada del operador priorizando el UID para evitar duplicados.
    if (uidDocId.isNotEmpty) {
      await usuariosRef.doc(uidDocId).set(cierreJornada, SetOptions(merge: true));
      
      // Si el operador (nombre) es distinto al UID, intentamos actualizarlo 
      // pero sin crearlo si no existe (usando update en lugar de set).
      if (widget.operador != uidDocId) {
        try {
          await usuariosRef.doc(widget.operador).update(cierreJornada);
        } catch (_) {
          // Si el documento por nombre no existe, ignoramos.
        }
      }
    } else {
      // Fallback si no hay UID (por seguridad)
      await userRef.set(cierreJornada, SetOptions(merge: true));
    }

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

  Future<void> _enviarNotificacionAdmin({
    required String tipo,
    required String mensaje,
  }) async {
    try {
      await FirebaseFirestore.instance.collection('notificaciones').add({
        'mensaje': mensaje,
        'creadoEn': FieldValue.serverTimestamp(),
        'enviadoPor': widget.operador,
        'destinoTipo': 'rol',
        'paraTodos': false,
        'destinatarioRol': 'admin',
        'tipo': tipo,
        'leidoPor': <String, bool>{},
      });
    } catch (e) {
      debugPrint('Error enviando notificación al admin: $e');
    }
  }

  @override
  Widget build(BuildContext context) {
    final gpsActivoVisual =
        _compartiendoUbicacionActiva && _servicioUbicacionActivo;

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
          backgroundColor: const Color(0xFFF1F3F6),
          endDrawer: NotificacionesDrawer(
            rolUsuario: 'operador',
            nombreUsuario: widget.operador,
          ),
          appBar: AppBar(
            toolbarHeight: 74,
            elevation: 0,
            foregroundColor: Colors.white,
            titleSpacing: 0,
            title: Row(
              children: [
                Expanded(
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: const [
                      Text(
                        'Jornada activa',
                        style: TextStyle(
                          fontWeight: FontWeight.w700,
                          letterSpacing: 0.2,
                          fontSize: 24,
                        ),
                      ),
                      SizedBox(height: 2),
                      Row(
                        children: [
                          Icon(Icons.circle, size: 8, color: Color(0xFF22C55E)),
                          SizedBox(width: 6),
                          Text(
                            'En curso',
                            style: TextStyle(
                              fontSize: 13,
                              color: Color(0xFFBFDBFE),
                              fontWeight: FontWeight.w500,
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
                ClipRRect(
                  borderRadius: BorderRadius.circular(10),
                  child: Image.asset(
                    'assets/logo circular.jpeg',
                    height: 38,
                    width: 38,
                    fit: BoxFit.cover,
                  ),
                ),
                const SizedBox(width: 6),
              ],
            ),
            backgroundColor: const Color(0xFF031A47),
            flexibleSpace: Container(
              decoration: const BoxDecoration(
                gradient: LinearGradient(
                  colors: [Color(0xFF031A47), Color(0xFF022A60)],
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                ),
              ),
            ),
            actions: [
              _buildReportAppBarAction(_irAReporte),
              Builder(
                builder: (context) => NotificacionesBellButton(
                  rolUsuario: 'operador',
                  nombreUsuario: widget.operador,
                  iconColor: Colors.yellow,
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
          bottomNavigationBar: JornadaBottomBar(
            activeIndex: 0,
            onInicio: _irAInicio,
            onContenedores: _irAContenedores,
            onHistorial: _irAHistorial,
            onPerfil: _irAPerfil,
          ),
          body: RefreshIndicator(
            onRefresh: _refrescarJornada,
            child: SingleChildScrollView(
              physics: const AlwaysScrollableScrollPhysics(),
              child: AnimatedOpacity(
                duration: const Duration(milliseconds: 550),
                opacity: _contentVisible ? 1 : 0,
                child: AnimatedSlide(
                  duration: const Duration(milliseconds: 550),
                  offset: _contentVisible
                      ? Offset.zero
                      : const Offset(0, 0.05),
                  curve: Curves.easeOutCubic,
                  child: Padding(
                    padding: const EdgeInsets.fromLTRB(10, 8, 10, 10),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                          // ── Tarjeta Datos de Jornada (compacta) ──
                          Container(
                            padding: const EdgeInsets.fromLTRB(12, 10, 12, 10),
                            decoration: BoxDecoration(
                              borderRadius: BorderRadius.circular(16),
                              gradient: const LinearGradient(
                                colors: [Color(0xFF05316D), Color(0xFF03275A)],
                                begin: Alignment.topLeft,
                                end: Alignment.bottomRight,
                              ),
                              border: Border.all(
                                color: const Color(0xFF0B4A95),
                              ),
                              boxShadow: [
                                BoxShadow(
                                  color: Colors.black.withValues(alpha: 0.16),
                                  blurRadius: 10,
                                  offset: const Offset(0, 4),
                                ),
                              ],
                            ),
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                const Text(
                                  'Datos de Jornada',
                                  style: TextStyle(
                                    fontSize: 16,
                                    fontWeight: FontWeight.w700,
                                    color: Color(0xFFE2E8F0),
                                  ),
                                ),
                                const SizedBox(height: 8),
                                Row(
                                  crossAxisAlignment: CrossAxisAlignment.center,
                                  children: [
                                    Container(
                                      width: 46,
                                      height: 46,
                                      decoration: BoxDecoration(
                                        shape: BoxShape.circle,
                                        gradient: const LinearGradient(
                                          colors: [
                                            Color(0xFF10B981),
                                            Color(0xFF059669),
                                          ],
                                          begin: Alignment.topLeft,
                                          end: Alignment.bottomRight,
                                        ),
                                      ),
                                      child: const Icon(
                                        Icons.local_shipping_outlined,
                                        size: 22,
                                        color: Color(0xFFE8FFF4),
                                      ),
                                    ),
                                    const SizedBox(width: 10),
                                    Expanded(
                                      child: Column(
                                        crossAxisAlignment:
                                            CrossAxisAlignment.start,
                                        children: [
                                          _DataRowInfo(
                                            icon: Icons.person_outline_rounded,
                                            label: 'Operador',
                                            value: widget.operador,
                                          ),
                                          const SizedBox(height: 4),
                                          _DataRowInfo(
                                            icon: Icons.local_shipping_outlined,
                                            label: 'Camión',
                                            value: widget.camion,
                                          ),
                                          const SizedBox(height: 4),
                                          _DataRowInfo(
                                            icon: Icons.credit_card_rounded,
                                            label: 'Placas',
                                            value: widget.placas,
                                          ),
                                        ],
                                      ),
                                    ),
                                    const SizedBox(width: 8),
                                    Container(
                                      width: 82,
                                      padding: const EdgeInsets.symmetric(
                                        vertical: 8,
                                        horizontal: 6,
                                      ),
                                      decoration: BoxDecoration(
                                        borderRadius: BorderRadius.circular(50),
                                        gradient: LinearGradient(
                                          colors: gpsActivoVisual
                                              ? const [
                                                  Color(0xFF14532D),
                                                  Color(0xFF166534),
                                                ]
                                              : const [
                                                  Color(0xFF5D1B39),
                                                  Color(0xFF4A1630),
                                                ],
                                        ),
                                      ),
                                      child: Column(
                                        children: [
                                          Icon(
                                            gpsActivoVisual
                                                ? Icons.gps_fixed_rounded
                                                : Icons.gps_off_rounded,
                                            color: gpsActivoVisual
                                                ? const Color(0xFF86EFAC)
                                                : const Color(0xFFF87171),
                                            size: 26,
                                          ),
                                          const SizedBox(height: 3),
                                          Text(
                                            gpsActivoVisual
                                                ? 'GPS\nactivo'
                                                : 'GPS\napagado',
                                            textAlign: TextAlign.center,
                                            style: TextStyle(
                                              fontSize: 10,
                                              height: 1.2,
                                              fontWeight: FontWeight.w700,
                                              color: gpsActivoVisual
                                                  ? const Color(0xFFBBF7D0)
                                                  : const Color(0xFFFCA5A5),
                                            ),
                                          ),
                                        ],
                                      ),
                                    ),
                                  ],
                                ),
                                const SizedBox(height: 8),
                                Divider(
                                  color: Colors.white.withValues(alpha: 0.22),
                                  height: 8,
                                ),

                                const SizedBox(height: 2),
                                Row(
                                  children: [
                                    Expanded(
                                      child: Text(
                                        !_servicioUbicacionActivo
                                            ? 'Ubicación del dispositivo apagada'
                                            : (!_permisoUbicacionOtorgado
                                                  ? 'Permiso de ubicación pendiente'
                                                  : (_compartiendoUbicacionActiva
                                                        ? 'Compartiendo ubicación activa'
                                                        : _estadoUbicacion)),
                                        style: const TextStyle(
                                          fontSize: 12,
                                          color: Color(0xFFB4CFF2),
                                          fontWeight: FontWeight.w500,
                                        ),
                                      ),
                                    ),
                                    const SizedBox(width: 8),
                                    Switch.adaptive(
                                      value: _compartirUbicacion,
                                      activeColor: Colors.white,
                                      activeTrackColor: const Color(0xFF22C55E),
                                      inactiveThumbColor: Colors.white,
                                      inactiveTrackColor: const Color(
                                        0xFF3A4F77,
                                      ),
                                      onChanged: (value) async {
                                        setState(
                                          () => _compartirUbicacion = value,
                                        );
                                        if (value) {
                                          await _iniciarMonitoreoUbicacion();
                                        } else {
                                          await _detenerMonitoreoUbicacion(
                                            motivo:
                                                'Compartición manualmente desactivada',
                                          );
                                        }
                                      },
                                    ),
                                  ],
                                ),
                              ],
                            ),
                          ),
                          const SizedBox(height: 8),
                          // ── Tarjeta Registros de Jornada (compacta) ──
                          Container(
                            padding: const EdgeInsets.fromLTRB(10, 10, 10, 10),
                            decoration: BoxDecoration(
                              color: const Color(0xFFEFF1F4),
                              borderRadius: BorderRadius.circular(16),
                              boxShadow: [
                                BoxShadow(
                                  color: Colors.black.withValues(alpha: 0.05),
                                  blurRadius: 8,
                                  offset: const Offset(0, 3),
                                ),
                              ],
                            ),
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.stretch,
                              children: [
                                Row(
                                  children: [
                                    Container(
                                      width: 30,
                                      height: 30,
                                      decoration: BoxDecoration(
                                        color: const Color(0xFFDDF3EB),
                                        borderRadius: BorderRadius.circular(8),
                                      ),
                                      child: const Icon(
                                        Icons.assignment_outlined,
                                        color: Color(0xFF10B981),
                                        size: 18,
                                      ),
                                    ),
                                    const SizedBox(width: 8),
                                    const Text(
                                      'Registros de Jornada',
                                      style: TextStyle(
                                        fontSize: 16,
                                        fontWeight: FontWeight.w700,
                                        color: Color(0xFF1E293B),
                                      ),
                                    ),
                                  ],
                                ),
                                const SizedBox(height: 1),
                                const Padding(
                                  padding: EdgeInsets.only(left: 38),
                                  child: Text(
                                    'Selecciona el tipo de registro que quieres capturar.',
                                    style: TextStyle(
                                      fontSize: 12,
                                      color: Color(0xFF6B7280),
                                    ),
                                  ),
                                ),
                                const SizedBox(height: 8),
                                _RegistroActionCard(
                                  onPressed: _abrirRegistroGasolina,
                                  icon: Icons.local_gas_station_rounded,
                                  title: 'Registro de Gasolina',
                                  subtitle:
                                      'Captura información de carga de combustible.',
                                  gradient: const [
                                    Color(0xFF0D6E5E),
                                    Color(0xFF084F43),
                                  ],
                                ),
                                const SizedBox(height: 7),
                                _RegistroActionCard(
                                  onPressed: _mostrarSeleccionEntradaMaterial, 
                                  icon: Icons.scale_outlined,
                                  title: 'Entrada de material',
                                  subtitle:
                                      'Registra la entrada de materiales al equipo.',
                                  gradient: const [
                                    Color(0xFF1E3A6E),
                                    Color(0xFF122548),
                                  ],
                                ),
                              ],
                            ),
                          ),
                          const SizedBox(height: 8),
                          // ── Tarjeta Finalizar Jornada (compacta) ──
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
                                        'Finalizar jornada',
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
                                  _finalizandoJornada
                                      ? 'Finalizando...'
                                      : 'Desliza izquierda a derecha para confirmar',
                                  style: const TextStyle(
                                    fontSize: 12,
                                    color: Color(0xFF8E95A3),
                                  ),
                                ),
                                const SizedBox(height: 8),
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
            ),
          ),
        ), // Scaffold
      ), // ConnectionWrapper
    ); // return PopScope
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

  final TextEditingController _folioController = TextEditingController();
  final TextEditingController _cantidadController = TextEditingController();
  final TextEditingController _montoController = TextEditingController();

  String? _concepto;
  String? _unidad;
  String? _metodoPago;
  XFile? _imagenTicket;
  String? _ticketUrl;
  String? _ticketStoragePath;
  bool _subiendoImagen = false;
  bool _guardando = false;
  late final AnimationController _entryController;
  late final Animation<double> _fadeAnimation;
  late final Animation<Offset> _slideAnimation;

  static const Color _primary = Color(0xFF0B1220);
  static const Color _accent = Color(0xFF06B6D4);
  static const Color _success = Color(0xFF10B981);

  @override
  void initState() {
    super.initState();
    _concepto = 'gasolina';
    _unidad = 'litros';
    _metodoPago = 'efectivo';
    _entryController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 850),
    );
    _fadeAnimation = CurvedAnimation(
      parent: _entryController,
      curve: Curves.easeOut,
    );
    _slideAnimation =
        Tween<Offset>(begin: const Offset(0, 0.06), end: Offset.zero).animate(
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

  void _mostrarMensaje(String mensaje, {bool error = false}) {
    if (!mounted) return;

    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        backgroundColor: error ? Colors.red.shade700 : Colors.green.shade700,
        content: Text(mensaje),
      ),
    );
  }

  Future<void> _tomarFotoTicket() async {
    final esMovil =
        !kIsWeb &&
        (defaultTargetPlatform == TargetPlatform.android ||
            defaultTargetPlatform == TargetPlatform.iOS);

    if (!esMovil) {
      _mostrarMensaje(
        'La captura de foto de ticket solo está disponible en Android e iPhone.',
        error: true,
      );
      return;
    }

    try {
      final imagen = await _imagePicker.pickImage(
        source: ImageSource.camera,
        imageQuality: 92,
        preferredCameraDevice: CameraDevice.rear,
      );

      if (imagen == null) return;

      setState(() {
        _imagenTicket = imagen;
        _ticketUrl = null;
        _ticketStoragePath = null;
      });
      _mostrarMensaje('Foto del ticket capturada.');
      _mostrarVistaPreviaDialog();
    } catch (_) {
      _mostrarMensaje(
        'No fue posible abrir la camara. Intenta de nuevo.',
        error: true,
      );
    }
  }

  Future<void> _seleccionarDeGaleria() async {
    try {
      final imagen = await _imagePicker.pickImage(
        source: ImageSource.gallery,
        imageQuality: 92,
      );

      if (imagen == null) return;

      setState(() {
        _imagenTicket = imagen;
        _ticketUrl = null;
        _ticketStoragePath = null;
      });
      _mostrarMensaje('Foto seleccionada de la galería.');
      _mostrarVistaPreviaDialog();
    } catch (_) {
      _mostrarMensaje(
        'No fue posible abrir la galería. Intenta de nuevo.',
        error: true,
      );
    }
  }

  void _borrarFoto() {
    setState(() {
      _imagenTicket = null;
      _ticketUrl = null;
      _ticketStoragePath = null;
    });
    _mostrarMensaje('Foto eliminada.');
  }

  void _mostrarVistaPreviaDialog() {
    if (_imagenTicket == null) return;

    showDialog(
      context: context,
      builder: (context) => Dialog(
        backgroundColor: Colors.transparent,
        insetPadding: const EdgeInsets.all(10),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(20),
              ),
              clipBehavior: Clip.antiAlias,
              child: Column(
                children: [
                  AppBar(
                    title: const Text('Revisar Ticket',
                        style: TextStyle(
                            color: Colors.black87, fontWeight: FontWeight.bold)),
                    backgroundColor: Colors.white,
                    elevation: 0,
                    centerTitle: true,
                    automaticallyImplyLeading: false,
                    actions: [
                      IconButton(
                        icon: const Icon(Icons.close, color: Colors.black54),
                        onPressed: () => Navigator.pop(context),
                      ),
                    ],
                  ),
                  FutureBuilder<Uint8List>(
                    future: _imagenTicket!.readAsBytes(),
                    builder: (context, snapshot) {
                      if (!snapshot.hasData) {
                        return const SizedBox(
                            height: 200,
                            child: Center(child: CircularProgressIndicator()));
                      }
                      return InteractiveViewer(
                        minScale: 0.5,
                        maxScale: 4.0,
                        child: ConstrainedBox(
                          constraints: BoxConstraints(
                            maxHeight: MediaQuery.of(context).size.height * 0.7,
                          ),
                          child: Image.memory(
                            snapshot.data!,
                            fit: BoxFit.contain,
                          ),
                        ),
                      );
                    },
                  ),
                  Padding(
                    padding: const EdgeInsets.all(16.0),
                    child: Row(
                      children: [
                        Expanded(
                          child: OutlinedButton.icon(
                            onPressed: () {
                              Navigator.pop(context);
                              _borrarFoto();
                            },
                            icon: const Icon(Icons.delete_sweep_rounded),
                            label: const Text('Borrar / Cambiar'),
                            style: OutlinedButton.styleFrom(
                              foregroundColor: Colors.red.shade700,
                              side: BorderSide(color: Colors.red.shade700),
                              padding: const EdgeInsets.symmetric(vertical: 12),
                              shape: RoundedRectangleBorder(
                                  borderRadius: BorderRadius.circular(12)),
                            ),
                          ),
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: FilledButton.icon(
                            onPressed: () => Navigator.pop(context),
                            icon: const Icon(Icons.check_circle_outline_rounded),
                            label: const Text('Se ve bien'),
                            style: FilledButton.styleFrom(
                              backgroundColor: _success,
                              padding: const EdgeInsets.symmetric(vertical: 12),
                              shape: RoundedRectangleBorder(
                                  borderRadius: BorderRadius.circular(12)),
                            ),
                          ),
                        ),
                      ],
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

  Future<({String url, String storagePath})?> _subirImagenSiExiste() async {
    if (_imagenTicket == null) return null;

    setState(() {
      _subiendoImagen = true;
    });

    try {
      final bytes = await _imagenTicket!.readAsBytes();
      final nombreArchivo =
          '${DateTime.now().millisecondsSinceEpoch}_${widget.operador}.jpg';
      final storagePath = 'tickets_gasolina/${widget.operador}/$nombreArchivo';

      final ref = FirebaseStorage.instance.ref().child(storagePath);
      await ref.putData(bytes, SettableMetadata(contentType: 'image/jpeg'));
      final url = await ref.getDownloadURL();

      if (mounted) {
        setState(() {
          _ticketUrl = url;
          _ticketStoragePath = storagePath;
        });
      }

      return (url: url, storagePath: storagePath);
    } catch (_) {
      _mostrarMensaje('No se pudo subir la foto del ticket.', error: true);
      rethrow;
    } finally {
      if (mounted) {
        setState(() {
          _subiendoImagen = false;
        });
      }
    }
  }

  Future<void> _enviarNotificacionAdmin({
    required String tipo,
    required String mensaje,
  }) async {
    try {
      await FirebaseFirestore.instance.collection('notificaciones').add({
        'mensaje': mensaje,
        'creadoEn': FieldValue.serverTimestamp(),
        'enviadoPor': widget.operador,
        'destinoTipo': 'rol',
        'paraTodos': false,
        'destinatarioRol': 'admin',
        'tipo': tipo,
        'leidoPor': <String, bool>{},
      });
    } catch (e) {
      debugPrint('Error enviando notificación al admin: $e');
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
    if (_guardando) return;

    final folio = _folioController.text.trim();
    final cantidad = double.tryParse(
      _cantidadController.text.trim().replaceAll(',', '.'),
    );
    final monto = double.tryParse(
      _montoController.text.trim().replaceAll(',', '.'),
    );

    if (_imagenTicket == null) {
      _mostrarMensaje(
        'Primero toma la foto del ticket de gasolina.',
        error: true,
      );
      return;
    }

    // Si no hay imagen, si es obligatorio completar todo.
    // Si hay imagen, permitimos que los campos esten vacios para que admin los capture.
    if (_imagenTicket == null) {
      if (folio.isEmpty ||
          cantidad == null ||
          monto == null ||
          _concepto == null ||
          _unidad == null ||
          _metodoPago == null) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text(
              'Completa todos los campos o toma una foto del ticket.',
            ),
          ),
        );
        return;
      }
    }

    final confirmar = await _confirmarAccion(
      titulo: 'Confirmar registro',
      mensaje: '¿Estás seguro de registrar este consumo?',
      textoConfirmar: 'REGISTRAR',
    );

    if (!confirmar) return;

    setState(() {
      _guardando = true;
    });

    try {
      final fechaActual = DateTime.now();
      final ticketSubido = await _subirImagenSiExiste();

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
        'ticket_url': ticketSubido?.url,
        'ticket_storage_path': ticketSubido?.storagePath,
        'ticket_subido_en': FieldValue.serverTimestamp(),
        'captura_pendiente_admin': true,
        'creadoEn': FieldValue.serverTimestamp(),
      });

      // Notificar al administrador
      await _enviarNotificacionAdmin(
        tipo: 'gasolina',
        mensaje:
            '${widget.operador} ha registrado un consumo de combustible para el camión ${widget.camion}.',
      );

      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Registro guardado con ticket.')),
      );
      Navigator.of(context).pop();
    } finally {
      if (mounted) {
        setState(() {
          _guardando = false;
        });
      }
    }
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

  void _irAReporte() {
    Navigator.of(context).push(
      MaterialPageRoute(
        builder: (_) => ReporteScreen(
          nombreUsuario: widget.operador,
          camion: widget.camion,
          placas: widget.placas,
        ),
      ),
    );
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

    return PopScope(
      canPop: false,
      onPopInvokedWithResult: (didPop, result) async {
        if (didPop) return;

        final bool tieneCambios = _imagenTicket != null ||
            _folioController.text.trim().isNotEmpty ||
            _cantidadController.text.trim().isNotEmpty ||
            _montoController.text.trim().isNotEmpty;

        if (!tieneCambios) {
          Navigator.of(context).pop();
          return;
        }

        final confirmar = await _confirmarAccion(
          titulo: '¿Salir sin guardar?',
          mensaje:
              'Tienes un registro incompleto. Si sales ahora, se perderán los datos y la foto cargada.',
          textoConfirmar: 'SALIR',
        );

        if (confirmar && context.mounted) {
          Navigator.of(context).pop();
        }
      },
      child: Scaffold(
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
          style: TextStyle(fontWeight: FontWeight.w800, color: Colors.white),
        ),
        actions: [
          _buildReportAppBarAction(_irAReporte),
        ],
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
                                  'Toma una foto o carga la foto del ticket desde tu galería, o registra manualmente los datos de la compra del combustible para que administración pueda revisarlos.',
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
                          Row(
                            children: [
                              Expanded(
                                child: FilledButton.icon(
                                  onPressed: _subiendoImagen
                                      ? null
                                      : _tomarFotoTicket,
                                  icon: _subiendoImagen
                                      ? const SizedBox(
                                          width: 18,
                                          height: 18,
                                          child: CircularProgressIndicator(
                                            strokeWidth: 2,
                                            color: Colors.white,
                                          ),
                                        )
                                      : const Icon(Icons.photo_camera_rounded),
                                  label: const Text('Cámara'),
                                  style: FilledButton.styleFrom(
                                    backgroundColor: const Color(0xFF0F766E),
                                    foregroundColor: Colors.white,
                                    padding: const EdgeInsets.symmetric(
                                      vertical: 15,
                                    ),
                                    shape: RoundedRectangleBorder(
                                      borderRadius: BorderRadius.circular(16),
                                    ),
                                  ),
                                ),
                              ),
                              const SizedBox(width: 10),
                              Expanded(
                                child: FilledButton.icon(
                                  onPressed: _subiendoImagen
                                      ? null
                                      : _seleccionarDeGaleria,
                                  icon: const Icon(Icons.photo_library_rounded),
                                  label: const Text('Galería'),
                                  style: FilledButton.styleFrom(
                                    backgroundColor: const Color(0xFF1E3A8A),
                                    foregroundColor: Colors.white,
                                    padding: const EdgeInsets.symmetric(
                                      vertical: 15,
                                    ),
                                    shape: RoundedRectangleBorder(
                                      borderRadius: BorderRadius.circular(16),
                                    ),
                                  ),
                                ),
                              ),
                            ],
                          ),
                          if (_imagenTicket != null) ...[
                            const SizedBox(height: 10),
                            GestureDetector(
                              onTap: _mostrarVistaPreviaDialog,
                              child: ClipRRect(
                                borderRadius: BorderRadius.circular(14),
                                child: FutureBuilder<Uint8List>(
                                  future: _imagenTicket!.readAsBytes(),
                                  builder: (context, snapshot) {
                                    if (!snapshot.hasData) {
                                      return Container(
                                        height: 170,
                                        color: const Color(0xFFF1F5F9),
                                        alignment: Alignment.center,
                                        child: const CircularProgressIndicator(),
                                      );
                                    }

                                    return Stack(
                                      alignment: Alignment.center,
                                      children: [
                                        Image.memory(
                                          snapshot.data!,
                                          height: 190,
                                          width: double.infinity,
                                          fit: BoxFit.cover,
                                        ),
                                        Container(
                                          padding: const EdgeInsets.all(8),
                                          decoration: BoxDecoration(
                                            color: Colors.black45,
                                            borderRadius:
                                                BorderRadius.circular(10),
                                          ),
                                          child: const Row(
                                            mainAxisSize: MainAxisSize.min,
                                            children: [
                                              Icon(Icons.zoom_in_rounded,
                                                  color: Colors.white, size: 16),
                                              SizedBox(width: 4),
                                              Text(
                                                'Toca para revisar',
                                                style: TextStyle(
                                                    color: Colors.white,
                                                    fontSize: 12,
                                                    fontWeight: FontWeight.w600),
                                              ),
                                            ],
                                          ),
                                        ),
                                      ],
                                    );
                                  },
                                ),
                              ),
                            ),
                            const SizedBox(height: 8),
                            const Align(
                              alignment: Alignment.centerLeft,
                              child: Text(
                                'La foto se sube automaticamente al guardar el registro.',
                                style: TextStyle(
                                  fontSize: 12,
                                  color: Color(0xFF64748B),
                                  fontWeight: FontWeight.w600,
                                ),
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
                              prefixIcon: const Icon(
                                Icons.receipt_long_rounded,
                              ),
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
                          _buildFieldLabel('Concepto'),
                          const SizedBox(height: 6),
                          DropdownButtonFormField<String>(
                            initialValue: _concepto,
                            hint: const Text('Selecciona concepto'),
                            items: const [
                              DropdownMenuItem(
                                value: 'gasolina',
                                child: Text('Gasolina'),
                              ),
                              DropdownMenuItem(
                                value: 'diesel',
                                child: Text('Diesel'),
                              ),
                              DropdownMenuItem(
                                value: 'gas',
                                child: Text('Gas'),
                              ),
                            ],
                            onChanged: (value) {
                              if (value != null) {
                                setState(() {
                                  _concepto = value;
                                });
                              }
                            },
                            decoration: InputDecoration(
                              prefixIcon: const Icon(Icons.category_rounded),
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
                              if (value != null)
                                setState(() => _unidad = value);
                            },
                            decoration: InputDecoration(
                              prefixIcon: const Icon(Icons.straighten_rounded),
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
                              if (value != null)
                                setState(() => _metodoPago = value);
                            },
                            decoration: InputDecoration(
                              prefixIcon: const Icon(Icons.payment_rounded),
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
                              prefixIcon: const Icon(
                                Icons.attach_money_rounded,
                              ),
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
                          onPressed: (_guardando || _subiendoImagen)
                              ? null
                              : _guardarRegistro,
                          style: FilledButton.styleFrom(
                            backgroundColor: const Color(0xFF10B981),
                            foregroundColor: Colors.white,
                            padding: const EdgeInsets.symmetric(vertical: 15),
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(16),
                            ),
                            elevation: 4,
                          ),
                          icon: _guardando
                              ? const SizedBox(
                                  width: 16,
                                  height: 16,
                                  child: CircularProgressIndicator(
                                    strokeWidth: 2,
                                    color: Colors.white,
                                  ),
                                )
                              : const Icon(Icons.check_circle_rounded),
                          label: Text(
                            _guardando ? 'Guardando...' : 'Registrar',
                            style: const TextStyle(fontWeight: FontWeight.w700),
                          ),
                        );

                        final cancelarButton = OutlinedButton.icon(
                          onPressed: _cancelarRegistro,
                          style: OutlinedButton.styleFrom(
                            backgroundColor: const Color(0xFFDC2626),
                            foregroundColor: Colors.white,
                            side: BorderSide(color: const Color(0xFFDC2626)),
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

class _DataRowInfo extends StatelessWidget {
  final IconData icon;
  final String label;
  final String value;

  const _DataRowInfo({
    required this.icon,
    required this.label,
    required this.value,
  });

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Icon(icon, color: const Color(0xFF22D3EE), size: 18),
        const SizedBox(width: 8),
        Expanded(
          child: RichText(
            text: TextSpan(
              style: const TextStyle(
                fontSize: 15,
                color: Color(0xFFD1E7FF),
                height: 1.15,
              ),
              children: [
                TextSpan(
                  text: '$label\n',
                  style: const TextStyle(
                    fontWeight: FontWeight.w500,
                    fontSize: 13,
                    color: Color(0xFF9EC3F0),
                  ),
                ),
                TextSpan(
                  text: value,
                  style: const TextStyle(
                    fontWeight: FontWeight.w700,
                    color: Colors.white,
                  ),
                ),
              ],
            ),
          ),
        ),
      ],
    );
  }
}

class _RegistroActionCard extends StatelessWidget {
  final VoidCallback onPressed;
  final IconData icon;
  final String title;
  final String subtitle;
  final List<Color> gradient;

  const _RegistroActionCard({
    required this.onPressed,
    required this.icon,
    required this.title,
    required this.subtitle,
    required this.gradient,
  });

  @override
  Widget build(BuildContext context) {
    return Material(
      color: Colors.transparent,
      borderRadius: BorderRadius.circular(12),
      child: InkWell(
        onTap: onPressed,
        borderRadius: BorderRadius.circular(12),
        child: Ink(
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(12),
            gradient: LinearGradient(
              colors: gradient,
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
            ),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withValues(alpha: 0.18),
                blurRadius: 10,
                offset: const Offset(0, 4),
              ),
            ],
          ),
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
            child: SizedBox(
              height: 56,
              child: Row(
                children: [
                  Container(
                    width: 44,
                    height: 44,
                    decoration: BoxDecoration(
                      color: Colors.white.withValues(alpha: 0.20),
                      shape: BoxShape.circle,
                    ),
                    child: Center(
                      child: Icon(icon, color: Colors.white, size: 22),
                    ),
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          title,
                          style: const TextStyle(
                            color: Colors.white,
                            fontSize: 14,
                            fontWeight: FontWeight.w700,
                          ),
                        ),
                        const SizedBox(height: 3),
                        Text(
                          subtitle,
                          style: TextStyle(
                            color: Colors.white.withValues(alpha: 0.85),
                            fontSize: 11,
                          ),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(width: 6),
                  const Icon(
                    Icons.chevron_right_rounded,
                    color: Colors.white70,
                    size: 28,
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}

DateTime? _fechaDesdeFirestore(dynamic value) {
  if (value is Timestamp) return value.toDate();
  if (value is DateTime) return value;
  return null;
}

String _textoSeguro(dynamic value, {String fallback = '-'}) {
  final text = value?.toString().trim() ?? '';
  return text.isEmpty ? fallback : text;
}

String _numeroSeguro(dynamic value) {
  final parsed = value is num
      ? value.toDouble()
      : double.tryParse('${value ?? ''}');
  if (parsed == null) return '-';
  return parsed.toStringAsFixed(2);
}

class RegistrosJornadaScreen extends StatelessWidget {
  final String operador;
  final String camion;
  final String placas;
  final bool historial;

  const RegistrosJornadaScreen({
    super.key,
    required this.operador,
    required this.camion,
    required this.placas,
    required this.historial,
  });

  Future<void> _refrescar() async {
    await Future.delayed(const Duration(milliseconds: 300));
  }

  void _irAInicio(BuildContext context) {
    Navigator.of(context).pushReplacement(
      MaterialPageRoute(
        builder: (_) =>
            JornadaScreen(operador: operador, camion: camion, placas: placas),
      ),
    );
  }

  void _irARegistros(BuildContext context) {
    Navigator.of(context).pushReplacement(
      MaterialPageRoute(
        builder: (_) => RegistrosJornadaScreen(
          operador: operador,
          camion: camion,
          placas: placas,
          historial: false,
        ),
      ),
    );
  }

  void _irAHistorial(BuildContext context) {
    Navigator.of(context).pushReplacement(
      MaterialPageRoute(
        builder: (_) => RegistrosJornadaScreen(
          operador: operador,
          camion: camion,
          placas: placas,
          historial: true,
        ),
      ),
    );
  }

  void _irAPerfil(BuildContext context) {
    Navigator.of(context).pushReplacement(
      MaterialPageRoute(
        builder: (_) => PerfilOperadorScreen(
          operador: operador,
          camion: camion,
          placas: placas,
        ),
      ),
    );
  }

  void _irAContenedores(BuildContext context) {
    Navigator.of(context).pushReplacement(
      MaterialPageRoute(
        builder: (_) => ContenedoresOperadorScreen(
          operador: operador,
          camion: camion,
          placas: placas,
        ),
      ),
    );
  }

  void _irAReporte(BuildContext context) {
    Navigator.of(context).push(
      MaterialPageRoute(
        builder: (_) => ReporteScreen(
          nombreUsuario: operador,
          camion: camion,
          placas: placas,
        ),
      ),
    );
  }

  Query<Map<String, dynamic>> _consulta(String collection) {
    return FirebaseFirestore.instance
        .collection(collection)
        .where('operador', isEqualTo: operador);
  }

  Widget _buildRecordsSection({
    required String title,
    required IconData icon,
    required Color accent,
    required String collection,
  }) {
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(18),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.05),
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
                width: 36,
                height: 36,
                decoration: BoxDecoration(
                  color: accent.withValues(alpha: 0.12),
                  borderRadius: BorderRadius.circular(10),
                ),
                child: Icon(icon, color: accent, size: 20),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: Text(
                  title,
                  style: const TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.w700,
                    color: Color(0xFF1F2937),
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          StreamBuilder<QuerySnapshot>(
            stream: _consulta(collection).snapshots(),
            builder: (context, snapshot) {
              if (snapshot.connectionState == ConnectionState.waiting) {
                return const Padding(
                  padding: EdgeInsets.symmetric(vertical: 20),
                  child: Center(child: CircularProgressIndicator()),
                );
              }

              final docs = snapshot.data?.docs.toList() ?? [];
              docs.sort((a, b) {
                final dataA = a.data() as Map<String, dynamic>;
                final dataB = b.data() as Map<String, dynamic>;
                final fechaA = _fechaDesdeFirestore(
                  dataA['fecha'] ??
                      dataA['fecha_registro'] ??
                      dataA['creadoEn'],
                );
                final fechaB = _fechaDesdeFirestore(
                  dataB['fecha'] ??
                      dataB['fecha_registro'] ??
                      dataB['creadoEn'],
                );
                return (fechaB ?? DateTime.fromMillisecondsSinceEpoch(0))
                    .compareTo(
                      fechaA ?? DateTime.fromMillisecondsSinceEpoch(0),
                    );
              });

              if (docs.isEmpty) {
                final mensajeVacio = collection == 'registros_gasolina'
                    ? 'Aún no hay gasolina registrada.'
                    : 'Aún no hay entradas de material.';

                return Container(
                  width: double.infinity,
                  padding: const EdgeInsets.all(18),
                  decoration: BoxDecoration(
                    color: const Color(0xFFF8FAFC),
                    borderRadius: BorderRadius.circular(16),
                    border: Border.all(color: const Color(0xFFE5E7EB)),
                  ),
                  child: Column(
                    children: [
                      Icon(
                        icon,
                        size: 36,
                        color: accent.withValues(alpha: 0.5),
                      ),
                      const SizedBox(height: 8),
                      Text(
                        mensajeVacio,
                        textAlign: TextAlign.center,
                        style: const TextStyle(
                          color: Color(0xFF64748B),
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ],
                  ),
                );
              }

              return Column(
                children: docs.map((doc) {
                  final data = doc.data() as Map<String, dynamic>;
                  final fecha = _fechaDesdeFirestore(
                    data['fecha'] ?? data['fecha_registro'] ?? data['creadoEn'],
                  );
                  final titulo = collection == 'registros_gasolina'
                      ? 'Gasolina / Diésel / Gas'
                      : 'Entrada de material';
                  final subtitulo = collection == 'registros_gasolina'
                      ? 'Folio ${_textoSeguro(data['folio'])} · ${_textoSeguro(data['concepto'])} · ${_numeroSeguro(data['cantidad'])} ${_textoSeguro(data['unidad'])} · ${_numeroSeguro(data['monto'])} MXN'
                      : 'Folio ${_textoSeguro(data['folio'])} · ${_textoSeguro(data['producto'])} · Entrada ${_numeroSeguro(data['peso_entrada'])} · Salida ${_numeroSeguro(data['peso_salida'])} · Neto ${_numeroSeguro(data['peso_neto'])}';

                  return Padding(
                    padding: const EdgeInsets.only(bottom: 10),
                    child: _RegistroItemCard(
                      accent: accent,
                      icon: icon,
                      titulo: titulo,
                      subtitulo: subtitulo,
                      fecha: fecha == null
                          ? _textoSeguro(
                              data['fecha_texto'] ?? data['fecha_registro'],
                            )
                          : DateFormat('dd/MM/yyyy HH:mm').format(fecha),
                    ),
                  );
                }).toList(),
              );
            },
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final titulo = historial ? 'Historial' : 'Registros';
    final subtitulo = historial
        ? 'Consulta el historial reciente de la jornada.'
        : 'Aquí puedes ver lo que has registrado durante la jornada.';

    return Scaffold(
      backgroundColor: const Color(0xFFF1F3F6),
      appBar: AppBar(
        elevation: 0,
        foregroundColor: Colors.white,
        backgroundColor: const Color(0xFF031A47),
        automaticallyImplyLeading: false,
        leading: Builder(
          builder: (context) => IconButton(
            icon: const Icon(Icons.menu_rounded),
            tooltip: 'Menú',
            onPressed: () => Scaffold.of(context).openDrawer(),
          ),
        ),
        flexibleSpace: Container(
          decoration: const BoxDecoration(
            gradient: LinearGradient(
              colors: [Color(0xFF031A47), Color(0xFF022A60)],
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
            ),
          ),
        ),
        title: Text(
          titulo,
          style: const TextStyle(fontWeight: FontWeight.w700),
        ),
        actions: [
          _buildReportAppBarAction(() => _irAReporte(context)),
          Builder(
            builder: (context) => NotificacionesBellButton(
              rolUsuario: 'operador',
              nombreUsuario: operador,
              iconColor: Colors.white,
              onPressed: () => Scaffold.of(context).openEndDrawer(),
            ),
          ),
        ],
      ),
      drawer: MenuLateral(
        nombreUsuario: operador,
        camion: camion,
        placas: placas,
        mostrarCerrarSesion: false,
      ),
      endDrawer: NotificacionesDrawer(
        rolUsuario: 'operador',
        nombreUsuario: operador,
      ),
      bottomNavigationBar: JornadaBottomBar(
        activeIndex: historial ? 2 : 0,
        onInicio: () => _irAInicio(context),
        onContenedores: () => _irAContenedores(context),
        onHistorial: () => _irAHistorial(context),
        onPerfil: () => _irAPerfil(context),
      ),
      body: RefreshIndicator(
        onRefresh: _refrescar,
        child: SingleChildScrollView(
          physics: const AlwaysScrollableScrollPhysics(),
          padding: const EdgeInsets.fromLTRB(12, 12, 12, 16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Container(
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  borderRadius: BorderRadius.circular(18),
                  gradient: const LinearGradient(
                    colors: [Color(0xFF05316D), Color(0xFF03275A)],
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                  ),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      historial
                          ? 'Historial de la jornada'
                          : 'Registros de la jornada',
                      style: const TextStyle(
                        color: Colors.white,
                        fontSize: 22,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                    const SizedBox(height: 6),
                    Text(
                      subtitulo,
                      style: TextStyle(
                        color: Colors.white.withValues(alpha: 0.82),
                        height: 1.35,
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 12),
              _buildRecordsSection(
                title: 'Gasolina registrada',
                icon: Icons.local_gas_station_rounded,
                accent: const Color(0xFF15A56A),
                collection: 'registros_gasolina',
              ),
              const SizedBox(height: 12),
              _buildRecordsSection(
                title: 'Entrada de material',
                icon: Icons.scale_outlined,
                accent: const Color(0xFF2D68B2),
                collection: 'registros_toneladas',
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _RegistroItemCard extends StatelessWidget {
  final Color accent;
  final IconData icon;
  final String titulo;
  final String subtitulo;
  final String fecha;

  const _RegistroItemCard({
    required this.accent,
    required this.icon,
    required this.titulo,
    required this.subtitulo,
    required this.fecha,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: accent.withValues(alpha: 0.18)),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            width: 42,
            height: 42,
            decoration: BoxDecoration(
              color: accent.withValues(alpha: 0.12),
              borderRadius: BorderRadius.circular(12),
            ),
            child: Icon(icon, color: accent, size: 22),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  titulo,
                  style: const TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.w700,
                    color: Color(0xFF111827),
                  ),
                ),
                const SizedBox(height: 3),
                Text(
                  subtitulo,
                  style: const TextStyle(
                    fontSize: 13,
                    color: Color(0xFF475569),
                    height: 1.3,
                  ),
                ),
                const SizedBox(height: 6),
                Text(
                  fecha,
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
}

class PerfilOperadorScreen extends StatelessWidget {
  final String operador;
  final String camion;
  final String placas;

  const PerfilOperadorScreen({
    super.key,
    required this.operador,
    required this.camion,
    required this.placas,
  });

  Future<void> _refrescar() async {
    await Future.delayed(const Duration(milliseconds: 300));
  }

  void _irAInicio(BuildContext context) {
    Navigator.of(context).pushReplacement(
      MaterialPageRoute(
        builder: (_) =>
            JornadaScreen(operador: operador, camion: camion, placas: placas),
      ),
    );
  }

  void _irARegistros(BuildContext context) {
    Navigator.of(context).pushReplacement(
      MaterialPageRoute(
        builder: (_) => RegistrosJornadaScreen(
          operador: operador,
          camion: camion,
          placas: placas,
          historial: false,
        ),
      ),
    );
  }

  void _irAHistorial(BuildContext context) {
    Navigator.of(context).pushReplacement(
      MaterialPageRoute(
        builder: (_) => RegistrosJornadaScreen(
          operador: operador,
          camion: camion,
          placas: placas,
          historial: true,
        ),
      ),
    );
  }

  void _irAPerfil(BuildContext context) {
    Navigator.of(context).pushReplacement(
      MaterialPageRoute(
        builder: (_) => PerfilOperadorScreen(
          operador: operador,
          camion: camion,
          placas: placas,
        ),
      ),
    );
  }

  void _irAContenedores(BuildContext context) {
    Navigator.of(context).pushReplacement(
      MaterialPageRoute(
        builder: (_) => ContenedoresOperadorScreen(
          operador: operador,
          camion: camion,
          placas: placas,
        ),
      ),
    );
  }

  void _irAReporte(BuildContext context) {
    Navigator.of(context).push(
      MaterialPageRoute(
        builder: (_) => ReporteScreen(
          nombreUsuario: operador,
          camion: camion,
          placas: placas,
        ),
      ),
    );
  }

  Widget _infoCard({
    required String label,
    required String value,
    required IconData icon,
    required Color color,
  }) {
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: color.withValues(alpha: 0.18)),
      ),
      child: Row(
        children: [
          Container(
            width: 42,
            height: 42,
            decoration: BoxDecoration(
              color: color.withValues(alpha: 0.12),
              borderRadius: BorderRadius.circular(12),
            ),
            child: Icon(icon, color: color, size: 22),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  label,
                  style: const TextStyle(
                    fontSize: 12,
                    color: Color(0xFF64748B),
                    fontWeight: FontWeight.w600,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  value,
                  style: const TextStyle(
                    fontSize: 16,
                    color: Color(0xFF111827),
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

  @override
  Widget build(BuildContext context) {
    final usuarioDocId = FirebaseAuth.instance.currentUser?.uid ?? operador;

    return Scaffold(
      backgroundColor: const Color(0xFFF1F3F6),
      appBar: AppBar(
        elevation: 0,
        foregroundColor: Colors.white,
        backgroundColor: const Color(0xFF031A47),
        automaticallyImplyLeading: false,
        flexibleSpace: Container(
          decoration: const BoxDecoration(
            gradient: LinearGradient(
              colors: [Color(0xFF031A47), Color(0xFF022A60)],
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
            ),
          ),
        ),
        title: const Text(
          'Perfil',
          style: TextStyle(fontWeight: FontWeight.w700),
        ),
        actions: [
          _buildReportAppBarAction(() => _irAReporte(context)),
        ],
      ),
      bottomNavigationBar: JornadaBottomBar(
        activeIndex: 3,
        onInicio: () => _irAInicio(context),
        onContenedores: () => _irAContenedores(context),
        onHistorial: () => _irAHistorial(context),
        onPerfil: () => _irAPerfil(context),
      ),
      body: StreamBuilder<DocumentSnapshot>(
        stream: FirebaseFirestore.instance
            .collection('usuarios')
            .doc(usuarioDocId)
            .snapshots(),
        builder: (context, snapshot) {
          final data = snapshot.data?.data() as Map<String, dynamic>?;
          final jornadaActiva = data?['jornada_activa'] == true;
          final gpsActivo = data?['gps_activo'] == true;
          final estadoGps = _textoSeguro(
            data?['estado_gps'],
            fallback: 'Sin estado GPS',
          );

          return RefreshIndicator(
            onRefresh: _refrescar,
            child: SingleChildScrollView(
              physics: const AlwaysScrollableScrollPhysics(),
              padding: const EdgeInsets.fromLTRB(12, 12, 12, 16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  Container(
                    padding: const EdgeInsets.all(16),
                    decoration: BoxDecoration(
                      borderRadius: BorderRadius.circular(18),
                      gradient: const LinearGradient(
                        colors: [Color(0xFF05316D), Color(0xFF03275A)],
                        begin: Alignment.topLeft,
                        end: Alignment.bottomRight,
                      ),
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Text(
                          'Datos del usuario',
                          style: TextStyle(
                            color: Colors.white,
                            fontSize: 22,
                            fontWeight: FontWeight.w700,
                          ),
                        ),
                        const SizedBox(height: 6),
                        Text(
                          'Información visible del operador durante la jornada.',
                          style: TextStyle(
                            color: Colors.white.withValues(alpha: 0.82),
                            height: 1.35,
                          ),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 12),
                  _infoCard(
                    label: 'Operador',
                    value: operador,
                    icon: Icons.person_outline_rounded,
                    color: const Color(0xFF15A56A),
                  ),
                  const SizedBox(height: 10),
                  _infoCard(
                    label: 'Camión',
                    value: camion,
                    icon: Icons.local_shipping_outlined,
                    color: const Color(0xFF2D68B2),
                  ),
                  const SizedBox(height: 10),
                  _infoCard(
                    label: 'Placas',
                    value: placas,
                    icon: Icons.credit_card_rounded,
                    color: const Color(0xFF7C3AED),
                  ),
                  const SizedBox(height: 10),
                  _infoCard(
                    label: 'Jornada',
                    value: jornadaActiva ? 'Activa' : 'Inactiva',
                    icon: Icons.route_rounded,
                    color: jornadaActiva
                        ? const Color(0xFF10B981)
                        : const Color(0xFFDC2626),
                  ),
                  const SizedBox(height: 10),
                  _infoCard(
                    label: 'GPS',
                    value: gpsActivo ? estadoGps : 'GPS apagado',
                    icon: gpsActivo
                        ? Icons.gps_fixed_rounded
                        : Icons.gps_off_rounded,
                    color: gpsActivo
                        ? const Color(0xFF10B981)
                        : const Color(0xFFDC2626),
                  ),
                  const SizedBox(height: 12),
                  Container(
                    padding: const EdgeInsets.all(16),
                    decoration: BoxDecoration(
                      color: Colors.white,
                      borderRadius: BorderRadius.circular(18),
                      boxShadow: [
                        BoxShadow(
                          color: Colors.black.withValues(alpha: 0.05),
                          blurRadius: 12,
                          offset: const Offset(0, 4),
                        ),
                      ],
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Text(
                          'Resumen',
                          style: TextStyle(
                            fontSize: 18,
                            fontWeight: FontWeight.w700,
                            color: Color(0xFF1F2937),
                          ),
                        ),
                        const SizedBox(height: 8),
                        Text(
                          data == null
                              ? 'No se encontró información adicional del usuario en Firestore.'
                              : 'Aquí puedes ampliar los datos del perfil si el documento de usuario contiene más campos.',
                          style: const TextStyle(
                            color: Color(0xFF64748B),
                            height: 1.35,
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
          );
        },
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
                    style: TextStyle(
                      fontWeight: FontWeight.w700,
                      color: const Color(0xFFDF3B3B),
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
                          color: Colors.black.withValues(alpha: 0.22),
                          blurRadius: 8,
                          offset: const Offset(0, 2),
                        ),
                      ],
                    ),
                    child: _loading
                        ? const Padding(
                            padding: EdgeInsets.all(16),
                            child: CircularProgressIndicator(
                              strokeWidth: 2,
                              valueColor: AlwaysStoppedAnimation<Color>(
                                Colors.white,
                              ),
                            ),
                          )
                        : const Icon(
                            Icons.keyboard_double_arrow_right_rounded,
                            color: Colors.white,
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




