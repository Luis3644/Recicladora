import 'dart:async';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/foundation.dart';
import 'package:geolocator/geolocator.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:flutter_foreground_task/flutter_foreground_task.dart';
import 'foreground_location_task.dart';

class UbicacionService {
  static final UbicacionService _instance = UbicacionService._internal();
  factory UbicacionService() => _instance;
  UbicacionService._internal();

  final FlutterLocalNotificationsPlugin _notificaciones = FlutterLocalNotificationsPlugin();
  
  StreamSubscription<Position>? _posicionSub;
  StreamSubscription<ServiceStatus>? _servicioSub;
  Timer? _reintentoTimer;
  bool _reintentoEnCurso = false;

  final ValueNotifier<bool> compartiendoUbicacionActiva = ValueNotifier<bool>(false);
  final ValueNotifier<bool> compartirUbicacionSolicitada = ValueNotifier<bool>(true);
  final ValueNotifier<String> estadoUbicacion = ValueNotifier<String>('Iniciando ubicación...');
  final ValueNotifier<bool> permisoUbicacionOtorgado = ValueNotifier<bool>(false);
  final ValueNotifier<bool> servicioUbicacionActivo = ValueNotifier<bool>(false);
  final ValueNotifier<bool> alertaUbicacionMostrada = ValueNotifier<bool>(false);

  String? _operador;
  bool _ajustesUbicacionSolicitados = false;
  static const String _keyNotiPermisoSolicitado =
      'notificaciones_permiso_solicitado';

  void marcarAjustesUbicacionSolicitados() {
    _ajustesUbicacionSolicitados = true;
  }

  bool get isRunning => _posicionSub != null;

  Future<void> inicializar(String operador) async {
    _operador = operador;
    await _inicializarNotificacionesUbicacion();
    await _cargarEstadoAlertaUbicacion();
    _escucharCambiosServicioUbicacion();
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

      if (defaultTargetPlatform == TargetPlatform.android) {
        final androidImpl = _notificaciones
            .resolvePlatformSpecificImplementation<
              AndroidFlutterLocalNotificationsPlugin
            >();
        final prefs = await SharedPreferences.getInstance();
        final yaSolicitado =
            prefs.getBool(_keyNotiPermisoSolicitado) ?? false;

        final granted =
            await androidImpl?.requestNotificationsPermission() ?? true;
        if (!granted && !yaSolicitado) {
          await prefs.setBool(_keyNotiPermisoSolicitado, true);
          await Geolocator.openAppSettings();
        }
      }
    } catch (_) {}
  }

  Future<void> _cargarEstadoAlertaUbicacion() async {
    if (_operador == null) return;
    try {
      final doc = await FirebaseFirestore.instance
          .collection('usuarios')
          .doc(_operador!)
          .get();
      final data = doc.data();
      alertaUbicacionMostrada.value = data?['alerta_ubicacion_desactivada_mostrada'] == true;
    } catch (_) {
      alertaUbicacionMostrada.value = false;
    }
  }

  Future<void> iniciarMonitoreo() async {
    if (_operador == null) return;

    final servicioActivo = await Geolocator.isLocationServiceEnabled();
    servicioUbicacionActivo.value = servicioActivo;

    if (!servicioActivo) {
      await detenerMonitoreo(motivo: 'GPS del dispositivo apagado');
      await _mostrarAlertaUbicacionApagada(
        'Activa la ubicación del celular para compartir tu posición con administración.',
      );
      return;
    }

    var permiso = await Geolocator.checkPermission();
    if (permiso == LocationPermission.denied) {
      permiso = await Geolocator.requestPermission();
    }

    var redirigioAjustes = false;

    if (permiso == LocationPermission.denied ||
        permiso == LocationPermission.deniedForever) {
      permisoUbicacionOtorgado.value = false;
      await detenerMonitoreo(motivo: 'Sin permiso de ubicación');
      if (defaultTargetPlatform == TargetPlatform.android &&
          permiso == LocationPermission.deniedForever &&
          !_ajustesUbicacionSolicitados) {
        _ajustesUbicacionSolicitados = true;
        await Geolocator.openAppSettings();
        redirigioAjustes = true;
      }
      if (!redirigioAjustes) {
        await _mostrarAlertaUbicacionApagada(
          'Permiso de ubicacion denegado. Habilitalo para monitoreo en tiempo real.',
        );
      }
      return;
    }

    _ajustesUbicacionSolicitados = false;

    permisoUbicacionOtorgado.value = true;
    _limpiarAlertaUbicacion();

    compartirUbicacionSolicitada.value = true;
    await _iniciarServicioForeground();

    await _posicionSub?.cancel();

    final locationSettings = defaultTargetPlatform == TargetPlatform.android
      ? AndroidSettings(
          accuracy: LocationAccuracy.bestForNavigation,
          distanceFilter: 10,
          intervalDuration: const Duration(seconds: 3),
        )
      : AppleSettings(
          accuracy: LocationAccuracy.bestForNavigation,
          distanceFilter: 10,
          pauseLocationUpdatesAutomatically: false,
          showBackgroundLocationIndicator: true,
          activityType: ActivityType.automotiveNavigation,
        );

    _posicionSub = Geolocator.getPositionStream(
      locationSettings: locationSettings,
    ).listen(
      (position) async {
        compartiendoUbicacionActiva.value = true;
        estadoUbicacion.value = 'Compartiendo ubicación activa';
        await _actualizarGpsEnFirestore(
          gpsActivo: true,
          posicion: position,
          estado: estadoUbicacion.value,
        );
      },
      onError: (_) async {
        await _posicionSub?.cancel();
        _posicionSub = null;
        compartiendoUbicacionActiva.value = false;
        estadoUbicacion.value = 'Error leyendo ubicación. Reintentando...';
        await _actualizarGpsEnFirestore(
          gpsActivo: false,
          estado: estadoUbicacion.value,
        );
        _programarReintentoMonitoreo();
      },
    );
  }

  Future<void> detenerMonitoreo({String? motivo}) async {
    _reintentoTimer?.cancel();
    _reintentoEnCurso = false;
    compartirUbicacionSolicitada.value = false;
    await _detenerServicioForeground();
    await _posicionSub?.cancel();
    _posicionSub = null;

    compartiendoUbicacionActiva.value = false;
    estadoUbicacion.value = motivo ?? 'Compartición detenida';

    await _actualizarGpsEnFirestore(gpsActivo: false, estado: estadoUbicacion.value);
  }

  void dispose() {
    _reintentoTimer?.cancel();
    _posicionSub?.cancel();
    _servicioSub?.cancel();
    _removerForegroundCallback();
  }

  Future<void> _iniciarServicioForeground() async {
    if (defaultTargetPlatform != TargetPlatform.android) return;
    final isRunning = await FlutterForegroundTask.isRunningService;
    if (!isRunning) {
      await FlutterForegroundTask.startService(
        notificationTitle: 'Ubicacion en tiempo real',
        notificationText: 'Compartiendo ubicacion con administrador',
        notificationButtons: const [
          NotificationButton(id: kStopLocationAction, text: 'Detener ubicacion'),
        ],
        callback: startLocationCallback,
      );
    }

    _registrarForegroundCallback();
  }

  Future<void> _detenerServicioForeground() async {
    if (defaultTargetPlatform != TargetPlatform.android) return;
    final isRunning = await FlutterForegroundTask.isRunningService;
    if (isRunning) {
      await FlutterForegroundTask.stopService();
    }
  }

  void _registrarForegroundCallback() {
    FlutterForegroundTask.addTaskDataCallback(_onForegroundData);
  }

  void _removerForegroundCallback() {
    FlutterForegroundTask.removeTaskDataCallback(_onForegroundData);
  }

  void _onForegroundData(Object data) {
    if (data is Map && data['action'] == kStopLocationAction) {
      detenerMonitoreo(motivo: 'Comparticion detenida desde notificacion');
    }
  }

  void _programarReintentoMonitoreo() {
    if (_reintentoEnCurso) return;
    _reintentoEnCurso = true;
    _reintentoTimer?.cancel();
    _reintentoTimer = Timer(const Duration(seconds: 3), () async {
      _reintentoEnCurso = false;
      final servicioActivo = await Geolocator.isLocationServiceEnabled();
      if (!servicioActivo) return;

      final permiso = await Geolocator.checkPermission();
      if (permiso == LocationPermission.denied ||
          permiso == LocationPermission.deniedForever) {
        return;
      }

      await iniciarMonitoreo();
    });
  }

  Future<void> _actualizarGpsEnFirestore({
    required bool gpsActivo,
    Position? posicion,
    String? estado,
  }) async {
    if (_operador == null) return;
    
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

    // Usar el UID del usuario autenticado como identificador principal.
    final uidDocId = FirebaseAuth.instance.currentUser?.uid ?? '';
    final operadorTrim = _operador?.trim() ?? '';
    if (uidDocId.isNotEmpty) {
      data['uid'] = uidDocId;
    }
    if (operadorTrim.isNotEmpty) {
      data['nombre'] = operadorTrim;
    }
    
    if (uidDocId.isNotEmpty) {
      // Actualizamos el documento maestro (UID)
      await FirebaseFirestore.instance
          .collection('usuarios')
          .doc(uidDocId)
          .set(data, SetOptions(merge: true));

      // Si existe un documento legacy por nombre, desactivar su GPS para evitar duplicados.
      if (operadorTrim.isNotEmpty && operadorTrim != uidDocId) {
        try {
          await FirebaseFirestore.instance
              .collection('usuarios')
              .doc(operadorTrim)
              .update({'gps_activo': false});
        } catch (_) {
          // Si no existe el documento por nombre, no lo creamos.
        }
      }
    } else if (operadorTrim.isNotEmpty) {
      // Fallback si no hay UID (por seguridad)
      await FirebaseFirestore.instance
          .collection('usuarios')
          .doc(operadorTrim)
          .set(data, SetOptions(merge: true));
    }
  }

  Future<void> _mostrarAlertaUbicacionApagada(String motivo) async {
    if (_operador == null) return;
    if (alertaUbicacionMostrada.value) return;
    alertaUbicacionMostrada.value = true;

    final alertaData = {
      'alerta_ubicacion_desactivada_mostrada': true,
      'alerta_ubicacion_desactivada_en': FieldValue.serverTimestamp(),
    };

    try {
      final uidDocId = FirebaseAuth.instance.currentUser?.uid ?? '';
      if (uidDocId.isNotEmpty) {
        await FirebaseFirestore.instance
            .collection('usuarios')
            .doc(uidDocId)
            .set(alertaData, SetOptions(merge: true));
            
        if (_operador != null && _operador != uidDocId) {
          try {
            await FirebaseFirestore.instance
                .collection('usuarios')
                .doc(_operador!)
                .update(alertaData);
          } catch (_) {}
        }
      } else if (_operador != null) {
        await FirebaseFirestore.instance
            .collection('usuarios')
            .doc(_operador!)
            .set(alertaData, SetOptions(merge: true));
      }
    } catch (_) {}

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
    if (_operador == null) return;
    alertaUbicacionMostrada.value = false;

    final limpiaData = {
      'alerta_ubicacion_desactivada_mostrada': false,
    };

    final uidDocId = FirebaseAuth.instance.currentUser?.uid ?? '';
    if (uidDocId.isNotEmpty) {
      FirebaseFirestore.instance
          .collection('usuarios')
          .doc(uidDocId)
          .set(limpiaData, SetOptions(merge: true));
          
      if (_operador != null && _operador != uidDocId) {
        FirebaseFirestore.instance
            .collection('usuarios')
            .doc(_operador!)
            .update(limpiaData)
            .catchError((_) => null);
      }
    } else if (_operador != null) {
      FirebaseFirestore.instance
          .collection('usuarios')
          .doc(_operador!)
          .set(limpiaData, SetOptions(merge: true));
    }
  }

  void _escucharCambiosServicioUbicacion() {
    if (kIsWeb) return;

    _servicioSub = Geolocator.getServiceStatusStream().listen((status) async {
      final activo = status == ServiceStatus.enabled;
      servicioUbicacionActivo.value = activo;

      if (!activo) {
        await detenerMonitoreo(motivo: 'GPS del dispositivo apagado');
        await _mostrarAlertaUbicacionApagada(
          'La ubicación del celular se desactivó. Actívala para continuar el monitoreo.',
        );
      } else {
        _limpiarAlertaUbicacion();
        await iniciarMonitoreo();
      }
    });
  }
}
