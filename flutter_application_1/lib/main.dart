import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_analytics/firebase_analytics.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_crashlytics/firebase_crashlytics.dart';
import 'package:intl/date_symbol_data_local.dart';
import 'config/session_manager.dart';
import 'firebase_options.dart';
import 'screens/Trabajador_screen.dart';
import 'screens/admin_screen.dart';
import 'screens/login_screen.dart';
import 'screens/operador_screen.dart';
import 'screens/jornada_screen.dart';

void main() async {
  // 1. Asegurar que Flutter esté listo
  WidgetsFlutterBinding.ensureInitialized();

  // 2. Inicializar Firebase
  await Firebase.initializeApp(options: DefaultFirebaseOptions.currentPlatform);

  // 3. Configuración de Firestore (Persistencia)
  FirebaseFirestore.instance.settings = const Settings(
    persistenceEnabled: true,
    cacheSizeBytes: Settings.CACHE_SIZE_UNLIMITED,
  );

  // 4. Configuración de Crashlytics
  FlutterError.onError = FirebaseCrashlytics.instance.recordFlutterFatalError;

  // 5. Configuración de Analytics y evento de prueba
  final FirebaseAnalytics analytics = FirebaseAnalytics.instance;
  await analytics.logEvent(
    name: "super_prueba",
    parameters: {"timestamp": DateTime.now().toIso8601String()},
  );

  // 6. Inicializar fechas en español y lanzar la App
  await initializeDateFormatting('es_ES', null);

  runApp(const MyApp());
}

class MyApp extends StatelessWidget {
  const MyApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      debugShowCheckedModeBanner: false,
      title: 'Recicladora App',

      // --- CONFIGURACIÓN DE IDIOMA PARA CALENDARIOS Y WIDGETS ---
      localizationsDelegates: const [
        GlobalMaterialLocalizations.delegate,
        GlobalWidgetsLocalizations.delegate,
        GlobalCupertinoLocalizations.delegate,
      ],
      supportedLocales: const [
        Locale('es', 'ES'), // Español
        Locale('en', 'US'), // Inglés por si acaso
      ],
      locale: const Locale('es', 'ES'), // Forzamos la app a español
      // ---------------------------------------------------------
      theme: ThemeData(
        colorScheme: ColorScheme.fromSeed(
          seedColor: const Color.fromARGB(255, 249, 8, 124),
        ),
        useMaterial3: true,
      ),
      home: const AppSplashScreen(child: SessionBootstrapScreen()),
    );
  }
}

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
        final usarPc = _usarSplashPc(constraints);
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

class SessionBootstrapScreen extends StatelessWidget {
  const SessionBootstrapScreen({super.key});

  static const Duration _firebaseTimeout = Duration(seconds: 10);

  String _normalizarCorreo(String value) => value.trim().toLowerCase();

  Future<Widget> _resolverPantallaInicial() async {
    try {
      final sesionGuardada = await SessionManager.obtenerSesion();
      String? rol;
      String? nombre;

      if (sesionGuardada != null) {
        if (!_rolValido(sesionGuardada.rol)) {
          await SessionManager.limpiarSesion();
        } else {
          rol = sesionGuardada.rol;
          nombre = sesionGuardada.nombre;
        }
      }

      if (rol == null) {
        final currentUser = FirebaseAuth.instance.currentUser;
        if (currentUser == null) return const LoginScreen();

        final userDoc = await _obtenerPerfilUsuarioFirebase(currentUser);
        final data = userDoc?.data();
        rol = data?['rol']?.toString();
        nombre = data?['nombre']?.toString() ?? '';

        if (rol == null || rol.isEmpty) {
          await FirebaseAuth.instance.signOut();
          return const LoginScreen();
        }

        await SessionManager.guardarSesion(
          rol: rol,
          nombre: nombre,
          usuarioDocId: userDoc!.id,
          dispositivoId: data?['sesion_dispositivo_id'] ?? 'bootstrap-device',
        );
      }

      // --- Lógica de redirección por Rol (Ahora dentro del flujo async) ---
      if (rol == 'admin') return const AdminScreen();
      if (rol == 'trabajador') return const TrabajadorScreen();

      if (rol == 'operador') {
        // Ahora aquí el await sí es válido
        final jornadaDoc = await FirebaseFirestore.instance
            .collection('usuarios')
            .doc(nombre)
            .get()
            .timeout(_firebaseTimeout);

        final data = jornadaDoc.data();
        if (data?['jornada_activa'] == true) {
          return JornadaScreen(
            operador: nombre!,
            camion: data?['camion_actual'] ?? '',
            placas: data?['placas_actuales'] ?? 'S/P',
          );
        }
        return OperadorScreen(nombreUsuario: nombre!);
      }

      return const LoginScreen();
    } catch (_) {
      return const LoginScreen();
    }
  }

  // Eliminamos _pantallaPorRol porque la lógica ya está arriba
  
  Future<DocumentSnapshot<Map<String, dynamic>>?> _obtenerPerfilUsuarioFirebase(
    User currentUser,
  ) async {
    final porUid = await FirebaseFirestore.instance
        .collection('usuarios')
        .doc(currentUser.uid)
        .get()
        .timeout(_firebaseTimeout);

    if (porUid.exists) return porUid;

    final email = currentUser.email;
    if (email == null || email.isEmpty) return null;
    final emailNormalizado = _normalizarCorreo(email);

    final porEmail = await FirebaseFirestore.instance
        .collection('usuarios')
        .where('email', isEqualTo: emailNormalizado)
        .limit(1)
        .get()
        .timeout(_firebaseTimeout);

    if (porEmail.docs.isEmpty) return null;
    return porEmail.docs.first;
  }

  bool _rolValido(String rol) {
    return rol == 'admin' || rol == 'operador' || rol == 'trabajador';
  }

  @override
  Widget build(BuildContext context) {
    return FutureBuilder<Widget>(
      future: _resolverPantallaInicial(),
      builder: (context, snapshot) {
        if (snapshot.connectionState != ConnectionState.done) {
          return const Scaffold(
            body: Center(child: CircularProgressIndicator()),
          );
        }
        return snapshot.data ?? const LoginScreen();
      },
    );
  }
}