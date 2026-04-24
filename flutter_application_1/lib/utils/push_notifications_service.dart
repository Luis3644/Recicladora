import 'dart:async';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';

class PushNotificationsService {
  PushNotificationsService._();

  static final FlutterLocalNotificationsPlugin _localNotifications =
      FlutterLocalNotificationsPlugin();

  static bool _initialized = false;
  static bool _foregroundListenerReady = false;
  static bool _tokenRefreshListenerReady = false;
  static String _currentUsuarioDocId = '';
  static String _currentRol = '';
  static String _currentNombre = '';
  static StreamSubscription<QuerySnapshot<Map<String, dynamic>>>?
      _inAppMessagesSubscription;
  static final Set<String> _notificacionesMostradas = <String>{};
  static DateTime _inicioEscuchaMensajes = DateTime.now();

  static const AndroidNotificationChannel _channel = AndroidNotificationChannel(
    'admin_notificaciones',
    'Notificaciones de administracion',
    description: 'Canal para notificaciones enviadas por administracion.',
    importance: Importance.high,
  );

  static ({String title, String body})? _extraerContenidoNotificacion(
    RemoteMessage message,
  ) {
    final notification = message.notification;
    final title =
        (notification?.title ?? message.data['title'] ?? 'Nuevo mensaje')
            .toString()
            .trim();
    final body =
        (notification?.body ?? message.data['body'] ?? message.data['mensaje'] ?? '')
            .toString()
            .trim();

    if (title.isEmpty && body.isEmpty) return null;
    return (title: title.isEmpty ? 'Nuevo mensaje' : title, body: body);
  }

  static Future<void> showSystemNotificationFromMessage(
    RemoteMessage message,
  ) async {
    if (kIsWeb) return;
    final contenido = _extraerContenidoNotificacion(message);
    if (contenido == null) return;

    await _localNotifications.show(
      message.hashCode,
      contenido.title,
      contenido.body,
      NotificationDetails(
        android: AndroidNotificationDetails(
          _channel.id,
          _channel.name,
          channelDescription: _channel.description,
          importance: Importance.high,
          priority: Priority.high,
          icon: message.notification?.android?.smallIcon,
        ),
        iOS: const DarwinNotificationDetails(),
      ),
    );
  }

  static bool _esParaUsuario(
    Map<String, dynamic> data, {
    required String rol,
    required String nombre,
    required String usuarioDocId,
  }) {
    if (data['paraTodos'] == true) return true;

    final destinoTipo = data['destinoTipo']?.toString() ?? '';
    final destinoRol = data['destinatarioRol']?.toString() ?? '';
    final destinoNombre = data['destinatarioNombre']?.toString() ?? '';
    final destinoDocId = data['destinatarioDocId']?.toString() ?? '';

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

    final notifId = id.hashCode;
    await _localNotifications.show(
      notifId,
      'Nuevo mensaje de $enviadoPor',
      mensaje,
      NotificationDetails(
        android: AndroidNotificationDetails(
          'admin_notificaciones',
          'Notificaciones de administracion',
          channelDescription: 'Mensajes enviados desde el panel de administracion',
          importance: Importance.max,
          priority: Priority.high,
        ),
        iOS: DarwinNotificationDetails(
          subtitle: enviadoPor,
        ),
      ),
    );
  }

  static Future<void> startInAppMessagesListener({
    required String usuarioDocId,
    required String rol,
    required String nombre,
  }) async {
    if (usuarioDocId.trim().isEmpty || rol.trim().isEmpty) return;

    await initialize();

    _currentUsuarioDocId = usuarioDocId;
    _currentRol = rol;
    _currentNombre = nombre;

    await _inAppMessagesSubscription?.cancel();
    _notificacionesMostradas.clear();
    _inicioEscuchaMensajes = DateTime.now();

    _inAppMessagesSubscription = FirebaseFirestore.instance
        .collection('notificaciones')
        .orderBy('creadoEn', descending: true)
        .limit(120)
        .snapshots()
        .listen((snapshot) async {
      for (final doc in snapshot.docs) {
        final data = doc.data();

        if (_notificacionesMostradas.contains(doc.id)) continue;
        if (!_esParaUsuario(
          data,
          rol: _currentRol,
          nombre: _currentNombre,
          usuarioDocId: _currentUsuarioDocId,
        )) {
          continue;
        }

        final creadoEn = data['creadoEn'];
        DateTime? fecha;
        if (creadoEn is Timestamp) fecha = creadoEn.toDate();
        if (creadoEn is DateTime) fecha = creadoEn;
        if (fecha == null) continue;

        // Evita avisar mensajes viejos al arrancar listener.
        if (fecha.isBefore(_inicioEscuchaMensajes)) {
          _notificacionesMostradas.add(doc.id);
          continue;
        }

        final mensaje = data['mensaje']?.toString() ?? '';
        final enviadoPor = data['enviadoPor']?.toString() ?? 'Administracion';
        await _showInAppMessageNotification(doc.id, mensaje, enviadoPor);
        _notificacionesMostradas.add(doc.id);
      }
    });
  }

  static Future<void> initialize() async {
    if (_initialized) return;

    final messaging = FirebaseMessaging.instance;

    try {
      await messaging.requestPermission(alert: true, badge: true, sound: true);
    } catch (_) {}

    try {
      await messaging.setForegroundNotificationPresentationOptions(
        alert: true,
        badge: true,
        sound: true,
      );
    } catch (_) {}

    if (!kIsWeb) {
      const androidSettings =
          AndroidInitializationSettings('@mipmap/ic_launcher');
      const iosSettings = DarwinInitializationSettings();
      const initSettings = InitializationSettings(
        android: androidSettings,
        iOS: iosSettings,
      );

      try {
        await _localNotifications.initialize(initSettings);
      } catch (_) {}

      await _localNotifications
          .resolvePlatformSpecificImplementation<
            AndroidFlutterLocalNotificationsPlugin
          >()
          ?.createNotificationChannel(_channel);

      await _localNotifications
          .resolvePlatformSpecificImplementation<
            IOSFlutterLocalNotificationsPlugin
          >()
          ?.requestPermissions(alert: true, badge: true, sound: true);
    }

    _setupForegroundListener();
    _initialized = true;
  }

  static void _setupForegroundListener() {
    if (_foregroundListenerReady) return;

    FirebaseMessaging.onMessage.listen((RemoteMessage message) async {
      await showSystemNotificationFromMessage(message);
    });

    _foregroundListenerReady = true;
  }

  static Future<void> registerUserToken({
    required String usuarioDocId,
    required String rol,
  }) async {
    if (usuarioDocId.trim().isEmpty) return;
    _currentUsuarioDocId = usuarioDocId;
    _currentRol = rol;

    try {
      await initialize();

      final messaging = FirebaseMessaging.instance;
      final token = await messaging.getToken();
      if (token == null || token.trim().isEmpty) return;

      await FirebaseFirestore.instance
          .collection('usuarios')
          .doc(usuarioDocId)
          .set({
            'fcm_token': token,
            'fcm_token_updated_at': FieldValue.serverTimestamp(),
            'fcm_rol': rol,
          }, SetOptions(merge: true));

      if (rol == 'operador' || rol == 'trabajador') {
        await messaging.subscribeToTopic('rol_$rol');
        await messaging.subscribeToTopic('personal');
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
                'fcm_token': nuevoToken,
                'fcm_token_updated_at': FieldValue.serverTimestamp(),
                'fcm_rol': _currentRol,
              }, SetOptions(merge: true));
        });
        _tokenRefreshListenerReady = true;
      }
    } catch (_) {
      // No bloquea el login si FCM no está disponible en la plataforma actual.
    }
  }
}
