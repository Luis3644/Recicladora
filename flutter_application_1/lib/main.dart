import 'package:flutter/material.dart';
// 1. IMPORTANTE: Agregamos esta línea para las localizaciones
import 'package:flutter_localizations/flutter_localizations.dart'; 
import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_analytics/firebase_analytics.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_crashlytics/firebase_crashlytics.dart';
import 'package:intl/date_symbol_data_local.dart';
import 'firebase_options.dart';
import 'screens/login_screen.dart';

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
      home: const LoginScreen(),
    );
  }
}