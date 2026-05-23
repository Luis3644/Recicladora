import 'dart:async';
import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';

class PushNotificationsService {
  PushNotificationsService._();

  // ── Navigator key global — asígnalo en MaterialApp ───────────────────────
  static final GlobalKey<NavigatorState> navigatorKey =
      GlobalKey<NavigatorState>();

  // Getter para que main.dart pueda leer el nombre actual
  static String get currentNombre => _currentNombre;

  static final FlutterLocalNotificationsPlugin _localNotifications =
      FlutterLocalNotificationsPlugin();

  static bool _initialized               = false;
  static bool _foregroundListenerReady   = false;
  static bool _tokenRefreshListenerReady = false;
  static String _currentUsuarioDocId    = '';
  static String _currentRol             = '';
  static String _currentNombre          = '';
  static StreamSubscription<QuerySnapshot<Map<String, dynamic>>>?
      _inAppMessagesSubscription;
  static final Set<String> _notificacionesMostradas = <String>{};
  static DateTime _inicioEscuchaMensajes = DateTime.now();

  // ── Canales Android ───────────────────────────────────────────────────────
  static const AndroidNotificationChannel _channel = AndroidNotificationChannel(
    'admin_notificaciones',
    'Notificaciones de administracion',
    description: 'Canal para notificaciones enviadas por administracion.',
    importance: Importance.high,
  );

  static const AndroidNotificationChannel _channelReportes =
      AndroidNotificationChannel(
    'reportes_revisados',
    'Reportes revisados',
    description: 'Notificaciones cuando el admin revisa tus reportes.',
    importance: Importance.high,
  );

  static const AndroidNotificationChannel _channelNuevosReportes =
      AndroidNotificationChannel(
    'nuevos_reportes',
    'Nuevos reportes de operadores',
    description: 'Notificaciones cuando un operador envía un reporte.',
    importance: Importance.high,
  );

  // ── Navegación al tocar la notificación ──────────────────────────────────
  static void _navegarSegunTipo(String tipo) {
      
    final nav = navigatorKey.currentState;
    if (nav == null) return;

    if (tipo == 'reporte_nuevo') {
      // Admin → lista de incidentes
      nav.pushNamedAndRemoveUntil('/incidentes', (route) => route.isFirst);
    } else if (tipo == 'reporte_revisado') {
      // Operador → mis reportes
      nav.pushNamedAndRemoveUntil('/mis_reportes', (route) => route.isFirst);
    }
  }
static void navegarSegunTipo(String tipo) {
  _navegarSegunTipo(tipo);
}
  

  // ── Mostrar notificación local desde FCM (foreground) ─────────────────────
  static Future<void> showSystemNotificationFromMessage(
    RemoteMessage message,
  ) async {
    if (kIsWeb) return;

    // Usar EXACTAMENTE el título que manda la Cloud Function
    // así foreground y background dicen lo mismo
    final title = (message.notification?.title ??
            message.data['title'] ??
            'Nuevo mensaje')
        .toString()
        .trim();

    final body = (message.notification?.body ??
            message.data['body'] ??
            message.data['mensaje'] ??
            '')
        .toString()
        .trim();

    if (body.isEmpty) return;

    final tipo       = message.data['tipo']?.toString() ?? '';
    final esRevisado = tipo == 'reporte_revisado';
    final esNuevo    = tipo == 'reporte_nuevo';

    final String channelId   = esRevisado ? _channelReportes.id
                             : esNuevo    ? _channelNuevosReportes.id
                             : _channel.id;
    final String channelName = esRevisado ? _channelReportes.name
                             : esNuevo    ? _channelNuevosReportes.name
                             : _channel.name;
    final String? channelDesc = esRevisado ? _channelReportes.description
                              : esNuevo    ? _channelNuevosReportes.description
                              : _channel.description;
    final Color? color       = esRevisado ? const Color(0xFF10B981)
                             : esNuevo    ? const Color(0xFFF97316)
                             : null;

    await _localNotifications.show(
      message.hashCode,
      title,  // ← título de la Cloud Function, igual en foreground y background
      body,
      NotificationDetails(
        android: AndroidNotificationDetails(
          channelId,
          channelName,
          channelDescription: channelDesc,
          importance: Importance.high,
          priority:   Priority.high,
          color:      color,
        ),
        iOS: const DarwinNotificationDetails(),
      ),
      payload: tipo, // ← para navegar al tocar
    );
  }

  // ── Helpers ───────────────────────────────────────────────────────────────
  static bool _esParaUsuario(
    Map<String, dynamic> data, {
    required String rol,
    required String nombre,
    required String usuarioDocId,
  }) {
    if (data['paraTodos'] == true) return true;

    final destinoTipo   = data['destinoTipo']?.toString() ?? '';
    final destinoRol    = data['destinatarioRol']?.toString() ?? '';
    final destinoNombre = data['destinatarioNombre']?.toString() ?? '';
    final destinoDocId  = data['destinatarioDocId']?.toString() ?? '';

    if (destinoTipo == 'rol') return destinoRol == rol;
    if (destinoTipo == 'individual') {
      if (destinoDocId.isNotEmpty) return destinoDocId == usuarioDocId;
      return destinoRol == rol && destinoNombre == nombre;
    }
    return false;
  }

  static Future<void> _showInAppMessageNotification(
    String id,
    String mensaje,
    String enviadoPor,
  ) async {
    if (kIsWeb) return;
    if (mensaje.trim().isEmpty) return;

    await _localNotifications.show(
      id.hashCode,
      '📢 Mensaje de administración',
      mensaje,
      const NotificationDetails(
        android: AndroidNotificationDetails(
          'admin_notificaciones',
          'Notificaciones de administracion',
          channelDescription:
              'Mensajes enviados desde el panel de administracion',
          importance: Importance.max,
          priority:   Priority.high,
        ),
        iOS: DarwinNotificationDetails(),
      ),
      payload: 'admin_mensaje',
    );
  }

  // ── Listener mensajes admin desde Firestore ───────────────────────────────
  static Future<void> startInAppMessagesListener({
    required String usuarioDocId,
    required String rol,
    required String nombre,
  }) async {
    if (usuarioDocId.trim().isEmpty || rol.trim().isEmpty) return;

    await initialize();

    _currentUsuarioDocId = usuarioDocId;
    _currentRol          = rol;
    _currentNombre       = nombre;

    await _inAppMessagesSubscription?.cancel();
    _notificacionesMostradas.clear();
    _inicioEscuchaMensajes = DateTime.now();

    _inAppMessagesSubscription = FirebaseFirestore.instance
        .collection('notificaciones')
        .orderBy('creadoEn', descending: true)
        .limit(120)
        .snapshots()
        .listen((snapshot) async {
      final appState         = WidgetsBinding.instance.lifecycleState;
      final estaEnForeground = appState == AppLifecycleState.resumed;

      for (final doc in snapshot.docs) {
        final data = doc.data();

        if (_notificacionesMostradas.contains(doc.id)) continue;
        if (!_esParaUsuario(
          data,
          rol:          _currentRol,
          nombre:       _currentNombre,
          usuarioDocId: _currentUsuarioDocId,
        )) continue;

        final creadoEn = data['creadoEn'];
        DateTime? fecha;
        if (creadoEn is Timestamp) fecha = creadoEn.toDate();
        if (creadoEn is DateTime)  fecha = creadoEn;
        if (fecha == null) continue;

        if (fecha.isBefore(_inicioEscuchaMensajes)) {
          _notificacionesMostradas.add(doc.id);
          continue;
        }

        final tipoContenedor = (data['tipo']?.toString() ?? '').toLowerCase();
        if (tipoContenedor == 'contenedor_llenando' || tipoContenedor == 'contenedor_lleno') {
          _notificacionesMostradas.add(doc.id);
          continue;
        }

        if (estaEnForeground) {
          final mensaje    = data['mensaje']?.toString() ?? '';
          final enviadoPor = data['enviadoPor']?.toString() ?? 'Administración';

          final tipoLow = (data['tipo']?.toString() ?? '').toLowerCase();
          final mensajeLow = mensaje.toLowerCase();
          // Ignorar notificaciones de inicio de sesión e inicio/fin de jornada
          if (tipoLow.contains('login') || tipoLow.contains('sesion') || tipoLow.contains('session') || 
              mensajeLow.contains('ha iniciado sesión') || mensajeLow.contains('inició sesión') || 
              mensajeLow.contains('se ha conectado') || mensajeLow.contains('ha iniciado su jornada') ||
              mensajeLow.contains('ha finalizado su jornada')) {
            // no mostrar
          } else {
            await _showInAppMessageNotification(doc.id, mensaje, enviadoPor);
          }
        }

        _notificacionesMostradas.add(doc.id);
      }
    });
  }

  // ── Inicializar ───────────────────────────────────────────────────────────
  static Future<void> initialize() async {
    if (_initialized) return;

    final messaging = FirebaseMessaging.instance;

    try {
      await messaging.requestPermission(alert: true, badge: true, sound: true);
    } catch (_) {}

    // Desactivar presentación automática en foreground —
    // lo manejamos nosotros con flutter_local_notifications
    try {
      await messaging.setForegroundNotificationPresentationOptions(
        alert: false, badge: false, sound: false,
      );
    } catch (_) {}

    if (!kIsWeb) {
      const androidSettings =
          AndroidInitializationSettings('@mipmap/ic_launcher');
      const iosSettings     = DarwinInitializationSettings();
      const initSettings    = InitializationSettings(
        android: androidSettings,
        iOS:     iosSettings,
      );

      try {
        await _localNotifications.initialize(
          initSettings,
          // Tap en notificación local (foreground / background con app viva)
          onDidReceiveNotificationResponse: (details) {
            final tipo = details.payload ?? '';
            _navegarSegunTipo(tipo);
          },
        );
      } catch (_) {}

      final androidPlatform = _localNotifications
          .resolvePlatformSpecificImplementation<
              AndroidFlutterLocalNotificationsPlugin>();

      await androidPlatform?.createNotificationChannel(_channel);
      await androidPlatform?.createNotificationChannel(_channelReportes);
      await androidPlatform?.createNotificationChannel(_channelNuevosReportes);

      await _localNotifications
          .resolvePlatformSpecificImplementation<
              IOSFlutterLocalNotificationsPlugin>()
          ?.requestPermissions(alert: true, badge: true, sound: true);
    }

    // Tap en notificación FCM con app en background (no killed)
    FirebaseMessaging.onMessageOpenedApp.listen((RemoteMessage message) {
      final tipo = message.data['tipo']?.toString() ?? '';
      _navegarSegunTipo(tipo);
    });

    // Tap en notificación FCM con app killed
    final initialMessage = await messaging.getInitialMessage();
    if (initialMessage != null) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        final tipo = initialMessage.data['tipo']?.toString() ?? '';
        _navegarSegunTipo(tipo);
      });
    }

    _setupForegroundListener();
    _initialized = true;
  }




static void _setupForegroundListener() {
  if (_foregroundListenerReady) return;

  FirebaseMessaging.onMessage.listen((RemoteMessage message) async {
    final tipo = message.data['tipo']?.toString() ?? '';

    // El admin NO ve notificaciones de "reporte_revisado" (son para el operador)
    if (_currentRol == 'admin' && tipo == 'reporte_revisado') return;

    // El operador NO ve notificaciones de "reporte_nuevo" (son para los admins)
    if (_currentRol == 'operador' && tipo == 'reporte_nuevo') return;

    // ← Agrega esta línea:
    // Mensajes admin a operadores/trabajadores ya los muestra
    // el listener de Firestore — ignorar aquí para evitar duplicado
    if (tipo == 'admin_mensaje') return;

    // Ignorar notificaciones de inicio de sesión, inicio/fin de jornada (login/sesión)
    final tipoLower = tipo.toLowerCase();
    if (tipoLower.contains('login') || tipoLower.contains('sesion') || tipoLower.contains('session')) return;
    
    final body = (message.notification?.body ?? message.data['body'] ?? '').toString().toLowerCase();
    if (body.contains('ha iniciado su jornada') || body.contains('ha finalizado su jornada')) return;

    await showSystemNotificationFromMessage(message);
  });

  _foregroundListenerReady = true;
}

  // ── Registrar token FCM ───────────────────────────────────────────────────
  static Future<void> registerUserToken({
    required String usuarioDocId,
    required String rol,
  }) async {
    if (usuarioDocId.trim().isEmpty) return;
    _currentUsuarioDocId = usuarioDocId;
    _currentRol          = rol;

    try {
      await initialize();

      final messaging = FirebaseMessaging.instance;
      final token     = await messaging.getToken();
      if (token == null || token.trim().isEmpty) return;

      await FirebaseFirestore.instance
          .collection('usuarios')
          .doc(usuarioDocId)
          .set({
        'fcm_token':            token,
        'fcm_token_updated_at': FieldValue.serverTimestamp(),
        'fcm_rol':              rol,
      }, SetOptions(merge: true));

      if (rol == 'operador' || rol == 'trabajador') {
        await messaging.subscribeToTopic('rol_$rol');
        await messaging.subscribeToTopic('personal');
      }

      if (rol == 'admin' || rol == 'encargado') {
        await messaging.subscribeToTopic('admins');
      }

      await messaging.subscribeToTopic('usuario_$usuarioDocId');

      if (!_tokenRefreshListenerReady) {
        messaging.onTokenRefresh.listen((nuevoToken) async {
          if (nuevoToken.trim().isEmpty) return;
          if (_currentUsuarioDocId.isEmpty) return;
          await FirebaseFirestore.instance
              .collection('usuarios')
              .doc(_currentUsuarioDocId)
              .set({
            'fcm_token':            nuevoToken,
            'fcm_token_updated_at': FieldValue.serverTimestamp(),
            'fcm_rol':              _currentRol,
          }, SetOptions(merge: true));
        });
        _tokenRefreshListenerReady = true;
      }
    } catch (_) {}
  }
}