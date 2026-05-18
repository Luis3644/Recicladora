import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_analytics/firebase_analytics.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_crashlytics/firebase_crashlytics.dart';
import 'package:intl/date_symbol_data_local.dart';
import 'config/session_manager.dart';
import 'utils/push_notifications_service.dart';
import 'firebase_options.dart';
import 'screens/Trabajador_screen.dart';
import 'screens/admin_screen.dart';
import 'screens/login_screen.dart';
import 'screens/operador_screen.dart';
import 'screens/jornada_screen.dart';
import 'screens/widgets_conexion/connection_wrapper.dart';
import 'screens/mis_reportes_operador.dart';
import 'screens/widgets/lista_incidentes_admin.dart';

// ── Background handler ────────────────────────────────────────────────────────
@pragma('vm:entry-point')
Future<void> _firebaseMessagingBackgroundHandler(RemoteMessage message) async {
  await Firebase.initializeApp(options: DefaultFirebaseOptions.currentPlatform);
}

void main() async {
  WidgetsFlutterBinding.ensureInitialized();

  await Firebase.initializeApp(options: DefaultFirebaseOptions.currentPlatform);
  FirebaseMessaging.onBackgroundMessage(_firebaseMessagingBackgroundHandler);

  FirebaseFirestore.instance.settings = const Settings(
    persistenceEnabled: true,
    cacheSizeBytes: Settings.CACHE_SIZE_UNLIMITED,
  );

  FlutterError.onError = FirebaseCrashlytics.instance.recordFlutterFatalError;

  final FirebaseAnalytics analytics = FirebaseAnalytics.instance;
  await analytics.logEvent(
    name: 'super_prueba',
    parameters: {'timestamp': DateTime.now().toIso8601String()},
  );

  await PushNotificationsService.initialize();
  await initializeDateFormatting('es_ES', null);
  runApp(const MyApp());
}

// ── Estado global del rol ─────────────────────────────────────────────────────
final ValueNotifier<String?> rolActualNotifier = ValueNotifier<String?>(null);

class MyApp extends StatelessWidget {
  const MyApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      debugShowCheckedModeBanner: false,
      title: 'Recicladora App',
      navigatorKey: PushNotificationsService.navigatorKey,
      localizationsDelegates: const [
        GlobalMaterialLocalizations.delegate,
        GlobalWidgetsLocalizations.delegate,
        GlobalCupertinoLocalizations.delegate,
      ],
      supportedLocales: const [
        Locale('es', 'ES'),
        Locale('en', 'US'),
      ],
      locale: const Locale('es', 'ES'),
      theme: ThemeData(
        colorScheme: ColorScheme.fromSeed(
          seedColor: const Color.fromARGB(255, 249, 8, 124),
        ),
        useMaterial3: true,
      ),

      // ── Rutas nombradas para tap en notificaciones ───────────────────────
      onGenerateRoute: (settings) {
        if (settings.name == '/incidentes') {
          return MaterialPageRoute(
            builder: (_) => const ListaIncidentesAdmin(),
          );
        }
        if (settings.name == '/mis_reportes') {
          return MaterialPageRoute(
            builder: (_) => MisReportesOperador(
              nombreOperador: PushNotificationsService.currentNombre,
            ),
          );
        }
        return null;
      },

      builder: (context, child) {
        return ValueListenableBuilder<String?>(
          valueListenable: rolActualNotifier,
          builder: (context, rol, _) {
            if (rol == 'operador') {
              return ConnectionWrapper(child: child!);
            }
            return child!;
          },
        );
      },

      home: const AppSplashScreen(child: SessionBootstrapScreen()),
    );
  }
}

// ── Splash screen ─────────────────────────────────────────────────────────────
class AppSplashScreen extends StatefulWidget {
  const AppSplashScreen({super.key, required this.child});
  final Widget child;

  @override
  State<AppSplashScreen> createState() => _AppSplashScreenState();
}

class _AppSplashScreenState extends State<AppSplashScreen> {
  bool _showChild = false;

  @override
  void initState() {
    super.initState();
    _iniciarSplash();
  }

  Future<void> _iniciarSplash() async {
    await Future<void>.delayed(const Duration(seconds: 2));
    if (!mounted) return;
    setState(() => _showChild = true);
  }

  bool _usarSplashPc(BoxConstraints constraints) {
    if (!kIsWeb &&
        (defaultTargetPlatform == TargetPlatform.windows ||
            defaultTargetPlatform == TargetPlatform.macOS ||
            defaultTargetPlatform == TargetPlatform.linux)) {
      return true;
    }
    return constraints.maxWidth >= 900;
  }

  @override
  Widget build(BuildContext context) {
    if (_showChild) return widget.child;
    return LayoutBuilder(
      builder: (context, constraints) {
        final usarPc    = _usarSplashPc(constraints);
        final imagePath = usarPc
            ? 'assets/splash screen pc.jpeg'
            : 'assets/imagen splassh screen movil.jpeg';
        return Scaffold(
          body: SizedBox.expand(
            child: Image.asset(imagePath, fit: BoxFit.cover),
          ),
        );
      },
    );
  }
}

// ── Session Bootstrap ─────────────────────────────────────────────────────────
class SessionBootstrapScreen extends StatefulWidget {
  const SessionBootstrapScreen({super.key});

  @override
  State<SessionBootstrapScreen> createState() => _SessionBootstrapScreenState();
}

class _SessionBootstrapScreenState extends State<SessionBootstrapScreen> {
  static const Duration _firebaseTimeout = Duration(seconds: 10);

  // Mensaje pendiente si la app estaba killed cuando llegó la notificación
  String? _tipoPendiente;

  @override
  void initState() {
    super.initState();
    _leerMensajeInicial();
  }

  Future<void> _leerMensajeInicial() async {
    try {
      final message = await FirebaseMessaging.instance.getInitialMessage();
      if (message != null) {
        final tipo = message.data['tipo']?.toString() ?? '';
        if (tipo.isNotEmpty) _tipoPendiente = tipo;
      }
    } catch (_) {}
  }

  String _normalizarCorreo(String value) => value.trim().toLowerCase();

  // ─────────────────────────────────────────────────────────────────────────
  // FIX PRINCIPAL: esperar a que Firebase Auth restaure la sesión ANTES
  // de hacer cualquier lectura en Firestore. En Android, Auth tarda entre
  // 500 ms y 2 s en restaurar el token; sin esta espera Firestore recibe
  // request.auth == null y lanza permission-denied aunque el usuario ya
  // haya iniciado sesión anteriormente.
  // ─────────────────────────────────────────────────────────────────────────
  Future<Widget> _resolverPantallaInicial() async {
    try {
      // 1. Intentar obtener el usuario actual de manera inmediata
      User? currentUser = FirebaseAuth.instance.currentUser;

      // 2. Si no está disponible aún (común en Android al arrancar),
      //    esperar hasta 5 segundos a que Auth emita su primer evento.
      if (currentUser == null) {
        currentUser = await FirebaseAuth.instance
            .authStateChanges()
            .first
            .timeout(
              const Duration(seconds: 5),
              onTimeout: () => null,
            );
      }

      // 3. Si tras esperar no hay usuario autenticado → ir al Login
      if (currentUser == null) {
        await SessionManager.limpiarSesion();
        return const LoginScreen();
      }

      // ── A partir de aquí Auth está listo y Firestore puede leer ────────

      final sesionGuardada = await SessionManager.obtenerSesion();
      String? rol;
      String? nombre;
      String? usuarioDocId;

      // Intentar usar sesión en caché local primero (más rápido)
      if (sesionGuardada != null && _rolValido(sesionGuardada.rol)) {
        rol          = sesionGuardada.rol;
        nombre       = sesionGuardada.nombre;
        usuarioDocId = sesionGuardada.usuarioDocId;
      } else {
        // Sesión no válida en caché → leer perfil desde Firestore
        final userDoc = await _obtenerPerfilUsuarioFirebase(currentUser);
        final data    = userDoc?.data();
        rol          = data?['rol']?.toString();
        nombre       = data?['nombre']?.toString() ?? '';
        usuarioDocId  = userDoc?.id;

        if (rol == null || rol.isEmpty) {
          await FirebaseAuth.instance.signOut();
          return const LoginScreen();
        }

        await SessionManager.guardarSesion(
          rol:           rol,
          nombre:        nombre,
          usuarioDocId:  userDoc!.id,
          dispositivoId: data?['sesion_dispositivo_id'] ?? 'bootstrap-device',
        );
      }

      rolActualNotifier.value = rol;

      // Registrar token FCM y arrancar listener de mensajes
      if (usuarioDocId != null && usuarioDocId.isNotEmpty) {
        await PushNotificationsService.registerUserToken(
          usuarioDocId: usuarioDocId,
          rol:          rol!,
        );
        await PushNotificationsService.startInAppMessagesListener(
          usuarioDocId: usuarioDocId,
          rol:          rol,
          nombre:       nombre ?? '',
        );
      }

      // ── Resolver pantalla destino según rol ─────────────────────────────
      Widget pantallaDestino;

      if (rol == 'admin') {
        pantallaDestino = const AdminScreen();
      } else if (rol == 'trabajador') {
        pantallaDestino = const TrabajadorScreen();
      } else if (rol == 'operador') {
        final jornadaDoc = await FirebaseFirestore.instance
            .collection('usuarios')
            .doc(nombre)
            .get()
            .timeout(_firebaseTimeout);

        final data = jornadaDoc.data();
        if (data?['jornada_activa'] == true) {
          pantallaDestino = JornadaScreen(
            operador: nombre!,
            camion:   data?['camion_actual']    ?? '',
            placas:   data?['placas_actuales']  ?? 'S/P',
          );
        } else {
          pantallaDestino = OperadorScreen(nombreUsuario: nombre!);
        }
      } else {
        return const LoginScreen();
      }

      // Consumir navegación pendiente por notificación (app killed)
      if (_tipoPendiente != null && _tipoPendiente!.isNotEmpty) {
        final tipo = _tipoPendiente!;
        _tipoPendiente = null;
        Future.delayed(const Duration(milliseconds: 500), () {
          PushNotificationsService.navegarSegunTipo(tipo);
        });
      }

      return pantallaDestino;
    } catch (_) {
      // Cualquier error inesperado → Login
      return const LoginScreen();
    }
  }

  Future<DocumentSnapshot<Map<String, dynamic>>?> _obtenerPerfilUsuarioFirebase(
    User currentUser,
  ) async {
    // Buscar primero por UID
    final porUid = await FirebaseFirestore.instance
        .collection('usuarios')
        .doc(currentUser.uid)
        .get()
        .timeout(_firebaseTimeout);

    if (porUid.exists) return porUid;

    // Si no existe por UID, intentar por email
    final email = currentUser.email;
    if (email == null || email.isEmpty) return null;

    final porEmail = await FirebaseFirestore.instance
        .collection('usuarios')
        .where('email', isEqualTo: _normalizarCorreo(email))
        .limit(1)
        .get()
        .timeout(_firebaseTimeout);

    if (porEmail.docs.isEmpty) return null;
    return porEmail.docs.first;
  }

  bool _rolValido(String rol) =>
      rol == 'admin' || rol == 'operador' || rol == 'trabajador';

  @override
  Widget build(BuildContext context) {
    return FutureBuilder<Widget>(
      future: _resolverPantallaInicial(),
      builder: (context, snapshot) {
        if (snapshot.connectionState != ConnectionState.done) {
          return const Scaffold(
            backgroundColor: Colors.white,
            body: Center(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  CircularProgressIndicator(
                    color: Color(0xFF0F2754),
                    strokeWidth: 3,
                  ),
                  SizedBox(height: 16),
                  Text(
                    'Verificando sesión…',
                    style: TextStyle(
                      color: Color(0xFF64748B),
                      fontSize: 14,
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                ],
              ),
            ),
          );
        }

        if (snapshot.hasError) {
          return const LoginScreen();
        }

        return snapshot.data ?? const LoginScreen();
      },
    );
  }
}