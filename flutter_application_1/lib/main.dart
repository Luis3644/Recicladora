import 'package:flutter/material.dart';
// 1. IMPORTANTE: Agregamos esta línea para las localizaciones
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

void main() async {
  // 1. Asegurar que Flutter esté listo
  WidgetsFlutterBinding.ensureInitialized();

  // 2. Inicializar Firebase
  await Firebase.initializeApp(
    options: DefaultFirebaseOptions.currentPlatform,
  );

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
    parameters: {
      "timestamp": DateTime.now().toIso8601String(),
    },
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
        colorScheme: ColorScheme.fromSeed(seedColor: const Color.fromARGB(255, 249, 8, 124)),
        useMaterial3: true,
      ),
      home: const SessionBootstrapScreen(),
    );
  }
}

class SessionBootstrapScreen extends StatelessWidget {
  const SessionBootstrapScreen({super.key});

  Future<Widget> _resolverPantallaInicial() async {
    final sesionGuardada = await SessionManager.obtenerSesion();
    if (sesionGuardada != null) {
      if (!_rolValido(sesionGuardada.rol)) {
        await SessionManager.limpiarSesion();
      } else {
      return _pantallaPorRol(sesionGuardada.rol, sesionGuardada.nombre);
      }
    }

    final currentUser = FirebaseAuth.instance.currentUser;
    if (currentUser == null) {
      return const LoginScreen();
    }

    final userDoc = await _obtenerPerfilUsuarioFirebase(currentUser);
    final data = userDoc?.data();
    final rol = data?['rol']?.toString();
    final nombre = data?['nombre']?.toString() ?? '';

    if (rol == null || rol.isEmpty) {
      await FirebaseAuth.instance.signOut();
      return const LoginScreen();
    }

    await SessionManager.guardarSesion(rol: rol, nombre: nombre);
    return _pantallaPorRol(rol, nombre);
  }

  Future<DocumentSnapshot<Map<String, dynamic>>?> _obtenerPerfilUsuarioFirebase(
    User currentUser,
  ) async {
    final porUid = await FirebaseFirestore.instance
        .collection('usuarios')
        .doc(currentUser.uid)
        .get();

    if (porUid.exists) return porUid;

    final email = currentUser.email;
    if (email == null || email.isEmpty) return null;

    final porEmail = await FirebaseFirestore.instance
        .collection('usuarios')
        .where('email', isEqualTo: email)
        .limit(1)
        .get();

    if (porEmail.docs.isEmpty) return null;
    return porEmail.docs.first;
  }

  Widget _pantallaPorRol(String rol, String nombre) {
    if (rol == 'admin') return const AdminScreen();
    if (rol == 'operador') return OperadorScreen(nombreUsuario: nombre);
    if (rol == 'trabajador') return const TrabajadorScreen();
    return const LoginScreen();
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