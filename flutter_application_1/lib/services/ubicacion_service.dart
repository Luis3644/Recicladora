import 'dart:async';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/foundation.dart';
import 'package:geolocator/geolocator.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';

class UbicacionService {
  static final UbicacionService _instance = UbicacionService._internal();
  factory UbicacionService() => _instance;
  UbicacionService._internal();

  final FlutterLocalNotificationsPlugin _notificaciones = FlutterLocalNotificationsPlugin();
  
  StreamSubscription<Position>? _posicionSub;
  StreamSubscription<ServiceStatus>? _servicioSub;

  final ValueNotifier<bool> compartiendoUbicacionActiva = ValueNotifier<bool>(false);
  final ValueNotifier<String> estadoUbicacion = ValueNotifier<String>('Iniciando ubicación...');
  final ValueNotifier<bool> permisoUbicacionOtorgado = ValueNotifier<bool>(false);
  final ValueNotifier<bool> servicioUbicacionActivo = ValueNotifier<bool>(false);
  final ValueNotifier<bool> alertaUbicacionMostrada = ValueNotifier<bool>(false);

  String? _operador;

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

      final androidImpl = _notificaciones
          .resolvePlatformSpecificImplementation<
            AndroidFlutterLocalNotificationsPlugin
          >();
      await androidImpl?.requestNotificationsPermission();
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

    if (permiso == LocationPermission.denied ||
        permiso == LocationPermission.deniedForever) {
      permisoUbicacionOtorgado.value = false;
      await detenerMonitoreo(motivo: 'Sin permiso de ubicación');
      await _mostrarAlertaUbicacionApagada(
        'Permiso de ubicación denegado. Habilítalo para monitoreo en tiempo real.',
      );
      return;
    }

    permisoUbicacionOtorgado.value = true;
    _limpiarAlertaUbicacion();

    await _posicionSub?.cancel();

    final locationSettings = defaultTargetPlatform == TargetPlatform.android
      ? AndroidSettings(
          accuracy: LocationAccuracy.bestForNavigation,
          distanceFilter: 10,
          intervalDuration: const Duration(seconds: 3),
          foregroundNotificationConfig: const ForegroundNotificationConfig(
            notificationTitle: 'GPS Activo',
            notificationText: 'Compartiendo ubicación con administración',
            enableWakeLock: true,
            notificationIcon: AndroidResource(
              name: '@mipmap/ic_launcher',
              defType: 'mipmap',
            ),
          ),
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
        await detenerMonitoreo(motivo: 'Error leyendo ubicación');
      },
    );
  }

  Future<void> detenerMonitoreo({String? motivo}) async {
    await _posicionSub?.cancel();
    _posicionSub = null;

    compartiendoUbicacionActiva.value = false;
    estadoUbicacion.value = motivo ?? 'Compartición detenida';

    await _actualizarGpsEnFirestore(gpsActivo: false, estado: estadoUbicacion.value);
  }

  void dispose() {
    _posicionSub?.cancel();
    _servicioSub?.cancel();
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

    // Actualiza por el identificador del operador
    await FirebaseFirestore.instance
        .collection('usuarios')
        .doc(_operador!)
        .set(data, SetOptions(merge: true));

    // Si el UID es diferente, también actualiza por UID para consistencia
    final uidDocId = FirebaseAuth.instance.currentUser?.uid ?? '';
    if (uidDocId.isNotEmpty && uidDocId != _operador) {
      await FirebaseFirestore.instance
          .collection('usuarios')
          .doc(uidDocId)
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
      await FirebaseFirestore.instance
          .collection('usuarios')
          .doc(_operador!)
          .set(alertaData, SetOptions(merge: true));

      final uidDocId = FirebaseAuth.instance.currentUser?.uid ?? '';
      if (uidDocId.isNotEmpty && uidDocId != _operador) {
        await FirebaseFirestore.instance
            .collection('usuarios')
            .doc(uidDocId)
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

    FirebaseFirestore.instance
        .collection('usuarios')
        .doc(_operador!)
        .set(limpiaData, SetOptions(merge: true));

    final uidDocId = FirebaseAuth.instance.currentUser?.uid ?? '';
    if (uidDocId.isNotEmpty && uidDocId != _operador) {
      FirebaseFirestore.instance
          .collection('usuarios')
          .doc(uidDocId)
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
