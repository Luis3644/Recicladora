import 'dart:async';
import 'dart:math';
import 'dart:io';
import 'package:http/http.dart' as http;

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:connectivity_plus/connectivity_plus.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:google_sign_in/google_sign_in.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../config/session_manager.dart';
import 'package:flutter_application_1/main.dart';
import '../utils/push_notifications_service.dart';
import 'Trabajador_screen.dart';
import 'admin_screen.dart';
import 'operador_screen.dart';

class LavaLampPainter extends CustomPainter {
  final double animationValue;

  LavaLampPainter({required this.animationValue});

  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint();

    final colors = [
      Color.lerp(
            const Color(0xFF1E3A8A),
            const Color(0xFF2563EB),
            animationValue % 1.0,
          ) ??
          const Color(0xFF1E3A8A),
      Color.lerp(
            const Color(0xFF2563EB),
            const Color(0xFF38BDF8),
            (animationValue + 0.33) % 1.0,
          ) ??
          const Color(0xFF2563EB),
      Color.lerp(
            const Color(0xFF38BDF8),
            const Color(0xFF1E3A8A),
            (animationValue + 0.66) % 1.0,
          ) ??
          const Color(0xFF38BDF8),
    ];

    for (int i = 0; i < colors.length; i++) {
      paint.color = colors[i].withValues(
        alpha: 0.3 + 0.3 * sin(animationValue * 2 + i),
      );

      final offsetX = size.width * (0.25 + 0.2 * sin(animationValue + i));
      final offsetY =
          size.height * (0.3 + 0.25 * cos(animationValue * 0.8 + i * 2));
      final radius =
          size.width * (0.12 + 0.05 * sin(animationValue * 1.5 + i));

      canvas.drawCircle(Offset(offsetX, offsetY), radius, paint);
    }

    for (int i = 0; i < 2; i++) {
      paint.color = colors[(i + 1) % colors.length].withValues(
        alpha: 0.15 + 0.15 * cos(animationValue * 1.2 + i),
      );

      final offsetX =
          size.width * (0.7 + 0.15 * cos(animationValue * 0.7 + i * 1.5));
      final offsetY =
          size.height * (0.6 + 0.2 * sin(animationValue * 0.9 + i));
      final radius =
          size.width * (0.15 + 0.08 * cos(animationValue + i * 3));

      canvas.drawCircle(Offset(offsetX, offsetY), radius, paint);
    }

    final gradientPaint = Paint()
      ..shader = LinearGradient(
        colors: [
          Colors.transparent,
          const Color(0xFF1E3A8A).withValues(alpha: 0.06),
        ],
        begin: Alignment.topCenter,
        end: Alignment.bottomCenter,
      ).createShader(Rect.fromLTWH(0, 0, size.width, size.height));

    canvas.drawRect(
      Rect.fromLTWH(0, 0, size.width, size.height),
      gradientPaint,
    );
  }

  @override
  bool shouldRepaint(LavaLampPainter oldDelegate) => true;
}

class AnimatedLavaBackground extends StatefulWidget {
  final Widget child;

  const AnimatedLavaBackground({super.key, required this.child});

  @override
  State<AnimatedLavaBackground> createState() => _AnimatedLavaBackgroundState();
}

class _AnimatedLavaBackgroundState extends State<AnimatedLavaBackground>
    with SingleTickerProviderStateMixin {
  late final AnimationController _controller;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      duration: const Duration(seconds: 20),
      vsync: this,
    )..repeat();
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: _controller,
      builder: (context, _) {
        return Container(
          width: double.infinity,
          height: double.infinity,
          decoration: const BoxDecoration(
            gradient: LinearGradient(
              colors: [Color(0xFF050B1E), Color(0xFF0B1B3A)],
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
            ),
          ),
          child: CustomPaint(
            painter:
                LavaLampPainter(animationValue: _controller.value * 6.28),
            child: widget.child,
          ),
        );
      },
    );
  }
}

class LoginScreen extends StatefulWidget {
  const LoginScreen({super.key});

  @override
  State<LoginScreen> createState() => _LoginScreenState();
}

class _LoginScreenState extends State<LoginScreen> {
  final TextEditingController emailController = TextEditingController();
  final TextEditingController passwordController = TextEditingController();

  final FirebaseAuth _auth = FirebaseAuth.instance;
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  late final GoogleSignIn _googleSignIn;

  final _formKey = GlobalKey<FormState>();

  bool isLoading = false;
  bool isPasswordVisible = false;
  String _dispositivoIdActual = '';

  static const String _keyDispositivoUnico = 'dispositivo_unico_id';
  static const Duration _firebaseTimeout = Duration(seconds: 12);
  static const String _googleWebClientId =
      '940984773428-55ivvst2ec661mg3nvuggssr9jvk3166.apps.googleusercontent.com';

  String _normalizarCorreo(String value) => value.trim().toLowerCase();

  List<String> _obtenerAuthProviders(User? user) {
    final providers =
        user?.providerData.map((provider) => provider.providerId).toSet() ??
        <String>{};

    if (providers.contains('google.com') && providers.contains('password')) {
      return ['google', 'password'];
    }
    if (providers.contains('google.com')) return ['google'];
    if (providers.contains('password')) return ['password'];
    return <String>[];
  }

  String _obtenerProveedorAuth(User? user) {
    final providers = _obtenerAuthProviders(user).toSet();
    if (providers.contains('google') && providers.contains('password')) {
      return 'password_google';
    }
    if (providers.contains('google')) return 'google';
    if (providers.contains('password')) return 'password';
    return 'unknown';
  }

  // ── Verificación de conexión — idéntica a ConnectionWrapper ─────────────
  // Web (Chrome/Windows): HTTP GET porque Socket TCP está bloqueado
  // Nativo (Android/iOS): Socket TCP directo — funciona con WiFi y datos móviles
  Future<bool> _tieneConexion() async {
    if (kIsWeb) {
      const urls = [
        'https://www.google.com/generate_204',
        'https://connectivitycheck.gstatic.com/generate_204',
        'https://www.cloudflare.com/cdn-cgi/trace',
      ];
      for (final url in urls) {
        try {
          final response = await http
              .get(Uri.parse(url))
              .timeout(const Duration(seconds: 5));
          if (response.statusCode > 0) return true;
        } catch (_) {
          continue;
        }
      }
      return false;
    }

    // Nativo: checar interfaz de red primero
    final connectivity = await Connectivity().checkConnectivity();
    final sinRed = connectivity.isEmpty ||
        (connectivity.length == 1 &&
            connectivity.first == ConnectivityResult.none);
    if (sinRed) return false;

    // Luego ping TCP real
    const hosts = [
      ('google.com',     80),
      ('cloudflare.com', 80),
      ('1.1.1.1',        53),
      ('8.8.8.8',        53),
    ];
    for (final (host, port) in hosts) {
      try {
        final socket = await Socket.connect(
          host, port,
          timeout: const Duration(seconds: 4),
        );
        socket.destroy();
        return true;
      } catch (_) {
        continue;
      }
    }
    return false;
  }

  Future<String?> _pedirContrasenaParaVincular(String email) async {
    final controller = TextEditingController();
    bool visible = false;

    final result = await showDialog<String>(
      context: context,
      builder: (dialogContext) {
        return StatefulBuilder(
          builder: (context, setDialogState) {
            return AlertDialog(
              title: const Text('Vincular acceso con Google'),
              content: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(
                    'Esta cuenta ya existe con correo. Ingresa la contraseña de $email para habilitar también acceso con Google.',
                  ),
                  const SizedBox(height: 12),
                  TextField(
                    controller: controller,
                    obscureText: !visible,
                    decoration: InputDecoration(
                      labelText: 'Contraseña',
                      border: const OutlineInputBorder(),
                      suffixIcon: IconButton(
                        icon: Icon(
                          visible ? Icons.visibility : Icons.visibility_off,
                        ),
                        onPressed: () {
                          setDialogState(() => visible = !visible);
                        },
                      ),
                    ),
                  ),
                ],
              ),
              actions: [
                TextButton(
                  onPressed: () => Navigator.of(dialogContext).pop(),
                  child: const Text('Cancelar'),
                ),
                FilledButton(
                  onPressed: () =>
                      Navigator.of(dialogContext).pop(controller.text.trim()),
                  child: const Text('Vincular'),
                ),
              ],
            );
          },
        );
      },
    );

    controller.dispose();
    return result;
  }

  Future<void> _continuarPostAuth(User? firebaseUser) async {
    if (firebaseUser?.email != null) {
      emailController.text = firebaseUser!.email!;
    }

    final userDoc = await _obtenerPerfilUsuario(
      uid: firebaseUser?.uid,
      email: firebaseUser?.email,
    );

    if (userDoc == null) {
      await _mostrarErrorNoRegistrado();
      return;
    }

    final permitido =
        await _validarYRegistrarSesionUnica(userDoc).timeout(_firebaseTimeout);
    if (!permitido) return;

    await _redirigirSegunRol(userDoc);
  }

  String _mensajeDiagnosticoError({required String etapa, Object? error}) {
    if (error is TimeoutException) {
      final etapaNormalizada = etapa.toLowerCase();
      if (etapaNormalizada.contains('google play services')) {
        return 'Fallo en $etapa: Google Play Services no respondió a tiempo.';
      }
      if (etapaNormalizada.contains('firebase auth') ||
          etapaNormalizada.contains('inicio de sesión con correo') ||
          etapaNormalizada.contains('inicio de sesión con google') ||
          etapaNormalizada.contains('autenticación con firebase') ||
          etapaNormalizada.contains('intercambio de credencial')) {
        return 'Fallo en $etapa: Firebase Auth no respondió. Revisa internet.';
      }
      if (etapaNormalizada.contains('firestore') ||
          etapaNormalizada.contains('perfil del usuario') ||
          etapaNormalizada.contains('sesión única')) {
        return 'Fallo en $etapa: Firestore no respondió. Revisa internet.';
      }
      return 'Fallo en $etapa: la respuesta tardó demasiado.';
    }

    if (error is PlatformException) {
      final mensaje = error.message ?? '';
      if (error.code == 'network_error' ||
          mensaje.contains('ApiException: 7')) {
        return 'Fallo en $etapa: Google Play Services no pudo autenticar (ApiException 7).';
      }
      return 'Fallo en $etapa: ${error.code}${mensaje.isNotEmpty ? ' - $mensaje' : ''}';
    }

    if (error is FirebaseAuthException) {
      final mensaje = error.message ?? '';
      return 'Fallo en $etapa: Firebase Auth (${error.code})${mensaje.isNotEmpty ? ' - $mensaje' : ''}';
    }

    if (error is FirebaseException) {
      final mensaje = error.message ?? '';
      return 'Fallo en $etapa: Firestore/Firebase (${error.plugin}:${error.code})${mensaje.isNotEmpty ? ' - $mensaje' : ''}';
    }

    return 'Fallo en $etapa: $error';
  }

  void _mostrarErrorDiagnostico({required String etapa, Object? error}) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(_mensajeDiagnosticoError(etapa: etapa, error: error)),
        backgroundColor: Colors.red,
        duration: const Duration(seconds: 5),
      ),
    );
  }

  @override
  void initState() {
    super.initState();
    _googleSignIn = GoogleSignIn(
      scopes: const ['email', 'profile'],
      serverClientId: _googleWebClientId,
    );
  }

  Future<DocumentSnapshot<Map<String, dynamic>>?> _obtenerPerfilUsuario({
    String? uid,
    String? email,
  }) async {
    final emailNormalizado = email == null ? null : _normalizarCorreo(email);

    if (uid != null && uid.isNotEmpty) {
      final doc = await _firestore
          .collection('usuarios')
          .doc(uid)
          .get()
          .timeout(_firebaseTimeout);
      if (doc.exists) {
        final data = doc.data();
        final emailDoc = data?['email']?.toString().trim().toLowerCase();
        if (emailNormalizado == null ||
            emailNormalizado.isEmpty ||
            emailDoc == emailNormalizado) {
          return doc;
        }
      }
    }

    if (email != null && email.isNotEmpty) {
      final query = await _firestore
          .collection('usuarios')
          .where('email', isEqualTo: emailNormalizado)
          .get()
          .timeout(_firebaseTimeout);

      if (query.docs.isEmpty) return null;
      if (query.docs.length == 1) return query.docs.first;

      final matchByUid = query.docs.where((doc) {
        final value = doc.data()['uid']?.toString();
        return uid != null && uid.isNotEmpty && value == uid;
      }).toList();

      if (matchByUid.length == 1) return matchByUid.first;

      if (!mounted) return null;
      return _seleccionarPerfilDuplicado(query.docs);
    }

    return null;
  }

  Future<DocumentSnapshot<Map<String, dynamic>>?> _seleccionarPerfilDuplicado(
    List<QueryDocumentSnapshot<Map<String, dynamic>>> perfiles,
  ) async {
    return showDialog<DocumentSnapshot<Map<String, dynamic>>>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: const Text('Selecciona tu perfil'),
        content: SizedBox(
          width: 420,
          child: ListView.separated(
            shrinkWrap: true,
            itemCount: perfiles.length,
            separatorBuilder: (_, __) => const Divider(height: 1),
            itemBuilder: (_, index) {
              final doc = perfiles[index];
              final data = doc.data();
              final nombre = data['nombre']?.toString() ?? 'Sin nombre';
              final apellido = data['apellido_paterno']?.toString() ?? '';
              final rol = data['rol']?.toString() ?? 'sin rol';

              return ListTile(
                leading: const Icon(Icons.person_outline),
                title: Text('$nombre $apellido'.trim()),
                subtitle: Text('Rol: $rol'),
                onTap: () => Navigator.of(dialogContext).pop(doc),
              );
            },
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(dialogContext).pop(),
            child: const Text('Cancelar'),
          ),
        ],
      ),
    );
  }

  Future<void> _mostrarErrorNoRegistrado() async {
    await _auth.signOut();
    await _googleSignIn.signOut();
    await SessionManager.limpiarSesion();

    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(
        content: Text(
          'Tu cuenta no está registrada. Contacta a tu administrador.',
        ),
        backgroundColor: Colors.red,
      ),
    );
  }

  Future<void> _redirigirSegunRol(
    DocumentSnapshot<Map<String, dynamic>> userDoc,
  ) async {
    final data = userDoc.data();
    if (data == null) throw Exception('Usuario sin datos en Firestore');

    final rol = data['rol']?.toString() ?? '';
    final nombre = data['nombre']?.toString() ?? '';
    final usuarioDocId = userDoc.id;

    if (_dispositivoIdActual.isEmpty) {
      _dispositivoIdActual = await _obtenerDispositivoId();
    }

    if (rol == 'admin') {
      // Admin y trabajador: desactivar ConnectionWrapper
      rolActualNotifier.value = null;

      await SessionManager.guardarSesion(
        rol: rol,
        nombre: nombre,
        usuarioDocId: usuarioDocId,
        dispositivoId: _dispositivoIdActual,
      );
      await PushNotificationsService.registerUserToken(
        usuarioDocId: usuarioDocId,
        rol: rol,
      );
      await PushNotificationsService.startInAppMessagesListener(
        usuarioDocId: usuarioDocId,
        rol: rol,
        nombre: nombre,
      );
      if (!mounted) return;
      Navigator.pushReplacement(
        context,
        MaterialPageRoute(builder: (_) => const AdminScreen()),
      );
      return;
    }

    if (rol == 'operador') {
      await SessionManager.guardarSesion(
        rol: rol,
        nombre: nombre,
        usuarioDocId: usuarioDocId,
        dispositivoId: _dispositivoIdActual,
      );
      await PushNotificationsService.registerUserToken(
        usuarioDocId: usuarioDocId,
        rol: rol,
      );
      await PushNotificationsService.startInAppMessagesListener(
        usuarioDocId: usuarioDocId,
        rol: rol,
        nombre: nombre,
      );

      // ── CLAVE: activar ConnectionWrapper ANTES de navegar ──────────────
      // Esto hace que el builder global de main.dart envuelva
      // TODAS las pantallas del operador con ConnectionWrapper,
      // incluyendo JornadaScreen, ChecklistScreen, etc.
      rolActualNotifier.value = 'operador';

      if (!mounted) return;
      Navigator.pushReplacement(
        context,
        MaterialPageRoute(
          builder: (_) => OperadorScreen(nombreUsuario: nombre),
        ),
      );
      return;
    }

    if (rol == 'trabajador') {
      // Trabajador: desactivar ConnectionWrapper
      rolActualNotifier.value = null;

      await SessionManager.guardarSesion(
        rol: rol,
        nombre: nombre,
        usuarioDocId: usuarioDocId,
        dispositivoId: _dispositivoIdActual,
      );
      await PushNotificationsService.registerUserToken(
        usuarioDocId: usuarioDocId,
        rol: rol,
      );
      await PushNotificationsService.startInAppMessagesListener(
        usuarioDocId: usuarioDocId,
        rol: rol,
        nombre: nombre,
      );
      if (!mounted) return;
      Navigator.pushReplacement(
        context,
        MaterialPageRoute(builder: (_) => const TrabajadorScreen()),
      );
      return;
    }

    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(
        content: Text('Rol no válido'),
        backgroundColor: Colors.red,
      ),
    );
  }

  Future<String> _obtenerDispositivoId() async {
    final prefs = await SharedPreferences.getInstance();
    final existente = prefs.getString(_keyDispositivoUnico) ?? '';
    if (existente.isNotEmpty) return existente;

    final nuevo =
        '${DateTime.now().microsecondsSinceEpoch}-${Random().nextInt(999999)}';
    await prefs.setString(_keyDispositivoUnico, nuevo);
    return nuevo;
  }

  String _nombreDispositivoActual() {
    if (kIsWeb) return 'Web';
    switch (defaultTargetPlatform) {
      case TargetPlatform.android:   return 'Android';
      case TargetPlatform.iOS:       return 'iOS';
      case TargetPlatform.windows:   return 'Windows';
      case TargetPlatform.macOS:     return 'macOS';
      case TargetPlatform.linux:     return 'Linux';
      case TargetPlatform.fuchsia:   return 'Fuchsia';
    }
  }

  Future<void> _mostrarDialogoSesionActivaBloqueada({
    required String nombre,
    required String rol,
  }) async {
    if (!mounted) return;

    await showDialog<void>(
      context: context,
      barrierDismissible: false,
      builder: (dialogContext) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: const Row(
          children: [
            Icon(Icons.security_rounded, color: Color(0xFFDC2626)),
            SizedBox(width: 8),
            Expanded(child: Text('Sesión ya iniciada')),
          ],
        ),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              'No se permite iniciar la misma cuenta en dos dispositivos al mismo tiempo.',
              style: TextStyle(fontWeight: FontWeight.w600),
            ),
            const SizedBox(height: 10),
            Text('Cuenta: $nombre'),
            Text('Rol: $rol'),
            const SizedBox(height: 8),
            const Text(
              'Cierra la sesión en el otro dispositivo para continuar.',
              style: TextStyle(color: Color(0xFF475569)),
            ),
          ],
        ),
        actions: [
          FilledButton.icon(
            onPressed: () => Navigator.of(dialogContext).pop(),
            icon: const Icon(Icons.check_circle_outline),
            label: const Text('Entendido'),
          ),
        ],
      ),
    );
  }

  Future<bool> _validarYRegistrarSesionUnica(
    DocumentSnapshot<Map<String, dynamic>> userDoc,
  ) async {
    // Nuevo comportamiento: permitir hasta 2 sesiones simultáneas por cuenta.
    final data = userDoc.data() ?? {};
    final uidAuth = _auth.currentUser?.uid ?? '';
    final emailAuth = _auth.currentUser?.email == null
        ? ''
        : _normalizarCorreo(_auth.currentUser!.email!);
    final dispositivoId = await _obtenerDispositivoId();
    final dispositivoActualNombre = _nombreDispositivoActual();
    _dispositivoIdActual = dispositivoId;

    final sesionesRef = _firestore
        .collection('usuarios')
        .doc(userDoc.id)
        .collection('sesiones');

    // Asegurar campos básicos en el documento de usuario
    await _firestore
        .collection('usuarios')
        .doc(userDoc.id)
        .set({
      if (uidAuth.isNotEmpty &&
          (data['uid'] == null || data['uid'].toString().trim().isEmpty))
        'uid': uidAuth,
      if (emailAuth.isNotEmpty) 'email': emailAuth,
      'email_normalizado': emailAuth,
      'proveedor_auth': _obtenerProveedorAuth(_auth.currentUser),
      'auth_providers': _obtenerAuthProviders(_auth.currentUser),
    }, SetOptions(merge: true));

    final snap = await sesionesRef.get();
    final sesiones = snap.docs
        .map((d) => {
              'id': d.id,
              'dispositivo_id': d.data()['dispositivo_id'] ?? d.id,
              'dispositivo_nombre': d.data()['dispositivo_nombre'] ?? d.id,
              'inicio': d.data()['inicio'],
              'last_active': d.data()['last_active'],
            })
        .toList();

    // Si ya existe sesión para este dispositivo, actualizar timestamps y continuar
    final existeActual = sesiones.any((s) => s['dispositivo_id'] == dispositivoId);
    if (existeActual) {
      await sesionesRef.doc(dispositivoId).set({
        'last_active': FieldValue.serverTimestamp(),
        'dispositivo_nombre': dispositivoActualNombre,
      }, SetOptions(merge: true));
      return true;
    }

    // Si hay menos de 2 sesiones, y ya existe una distinta -> mostrar aviso
    if (sesiones.length < 2) {
      if (sesiones.length == 1 && !existeActual) {
        // Mostrar alerta simple con 2 botones: Mantener sesión o Cerrar en el otro dispositivo
        final otra = sesiones.first;
        final otraId = otra['dispositivo_id']?.toString() ?? '';
        final otraNombre = otra['dispositivo_nombre']?.toString() ?? otraId;

        final opcion = await showDialog<String?>(
          context: context,
          barrierDismissible: false,
          builder: (dialogCtx) => AlertDialog(
            title: const Text('Sesión activa en otro dispositivo'),
            content: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text('Tu cuenta está activa en: $otraNombre'),
                const SizedBox(height: 8),
                const Text('¿Deseas mantener la sesión en ambos dispositivos, o cerrar la sesión en el otro dispositivo?'),
              ],
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.of(dialogCtx).pop('mantener'),
                child: const Text('Mantener sesión'),
              ),
              FilledButton(
                onPressed: () => Navigator.of(dialogCtx).pop('cerrar_otro'),
                child: const Text('Cerrar en otro dispositivo'),
              ),
            ],
          ),
        );

        if (opcion == 'mantener') {
          // crear la segunda sesión y permitir
          await sesionesRef.doc(dispositivoId).set({
            'dispositivo_id': dispositivoId,
            'dispositivo_nombre': dispositivoActualNombre,
            'inicio': FieldValue.serverTimestamp(),
            'last_active': FieldValue.serverTimestamp(),
          }, SetOptions(merge: true));
          return true;
        }

        if (opcion == 'cerrar_otro') {
          // cerrar la otra sesión y crear la actual
          try {
            if (otraId.isNotEmpty) await sesionesRef.doc(otraId).delete();
          } catch (_) {}

          await sesionesRef.doc(dispositivoId).set({
            'dispositivo_id': dispositivoId,
            'dispositivo_nombre': dispositivoActualNombre,
            'inicio': FieldValue.serverTimestamp(),
            'last_active': FieldValue.serverTimestamp(),
          }, SetOptions(merge: true));
          return true;
        }

        // si el usuario cierra el dialog sin elegir o cancela
        await _auth.signOut();
        await _googleSignIn.signOut();
        await SessionManager.limpiarSesion();
        return false;
      }

      // Si no existe sesión previa (sesiones.length == 0) o ya existe la actual, crearla
      await sesionesRef.doc(dispositivoId).set({
        'dispositivo_id': dispositivoId,
        'dispositivo_nombre': dispositivoActualNombre,
        'inicio': FieldValue.serverTimestamp(),
        'last_active': FieldValue.serverTimestamp(),
      }, SetOptions(merge: true));
      return true;
    }

    // Hay 2 sesiones distintas ya abiertas: mostrar diálogo y ofrecer cerrar una remota
    if (!mounted) return false;

    final cerrar = await showDialog<String?>(
      context: context,
      barrierDismissible: false,
      builder: (dialogCtx) {
        return AlertDialog(
          title: const Text('Cuenta abierta en otros dispositivos'),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text(
                'Tu cuenta ya tiene 2 sesiones abiertas. Puedes cerrar una sesión remota para iniciar aquí.',
              ),
              const SizedBox(height: 12),
              ...sesiones.map((s) {
                final name = s['dispositivo_nombre']?.toString() ?? s['dispositivo_id'];
                return ListTile(
                  title: Text(name),
                  subtitle: Text(s['inicio']?.toString() ?? ''),
                  trailing: FilledButton(
                    onPressed: () => Navigator.of(dialogCtx).pop(s['dispositivo_id'] as String),
                    child: const Text('Cerrar en ese dispositivo'),
                  ),
                );
              }).toList(),
              const SizedBox(height: 8),
              TextButton(
                onPressed: () => Navigator.of(dialogCtx).pop(null),
                child: const Text('Cancelar inicio de sesión'),
              ),
            ],
          ),
        );
      },
    );

    if (cerrar == null) {
      // usuario cancela: cerrar sesión local y no permitir login
      await _auth.signOut();
      await _googleSignIn.signOut();
      await SessionManager.limpiarSesion();
      return false;
    }

    // Usuario eligió cerrar una sesión remota
    try {
      await sesionesRef.doc(cerrar).delete();
    } catch (_) {}

    // Crear la sesión actual
    await sesionesRef.doc(dispositivoId).set({
      'dispositivo_id': dispositivoId,
      'dispositivo_nombre': dispositivoActualNombre,
      'inicio': FieldValue.serverTimestamp(),
      'last_active': FieldValue.serverTimestamp(),
    }, SetOptions(merge: true));

    return true;
  }

  Future<void> loginUsuario() async {
    if (!_formKey.currentState!.validate()) return;

    // Verificación con Socket TCP — igual que ConnectionWrapper
    if (!await _tieneConexion()) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text(
              'Sin conexión a internet. Revisa tu WiFi o datos móviles.'),
          backgroundColor: Colors.red,
        ),
      );
      return;
    }

    setState(() => isLoading = true);

    final email = _normalizarCorreo(emailController.text);
    final password = passwordController.text.trim();

    try {
      final userCredential = await _auth
          .signInWithEmailAndPassword(email: email, password: password)
          .timeout(_firebaseTimeout);

      await _continuarPostAuth(userCredential.user);
    } on FirebaseAuthException catch (e) {
      final mensaje = switch (e.code) {
        'user-not-found' => 'El correo no existe en Firebase Authentication.',
        'wrong-password' => 'La contraseña es incorrecta.',
        'invalid-credential' ||
        'invalid-login-credentials' =>
          'Correo o contraseña inválidos.',
        _ => e.message ?? 'Error al iniciar sesión con correo',
      };
      _mostrarErrorDiagnostico(
        etapa: 'inicio de sesión con correo',
        error: FirebaseAuthException(code: e.code, message: mensaje),
      );
    } on TimeoutException {
      _mostrarErrorDiagnostico(
        etapa: 'inicio de sesión con correo',
        error: TimeoutException('Firebase Auth no respondió'),
      );
    } catch (e) {
      _mostrarErrorDiagnostico(etapa: 'inicio de sesión con correo', error: e);
    } finally {
      if (mounted) setState(() => isLoading = false);
    }
  }

  Future<void> loginConGoogle() async {
    if (!await _tieneConexion()) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text(
              'Sin conexión a internet. Revisa tu WiFi o datos móviles.'),
          backgroundColor: Colors.red,
        ),
      );
      return;
    }

    setState(() => isLoading = true);

    try {
      UserCredential userCredential;
      if (kIsWeb) {
        final provider = GoogleAuthProvider();
        provider.addScope('email');
        provider.addScope('profile');
        provider.setCustomParameters({'prompt': 'select_account'});
        try {
          userCredential = await _auth
              .signInWithPopup(provider)
              .timeout(_firebaseTimeout);
        } on TimeoutException catch (e) {
          _mostrarErrorDiagnostico(
              etapa: 'inicio de sesión con Google en web', error: e);
          return;
        }
      } else {
        try {
          await _googleSignIn.disconnect();
        } catch (_) {
          await _googleSignIn.signOut();
        }

        final googleUser = await _googleSignIn.signIn();
        if (googleUser == null) return;

        GoogleSignInAuthentication googleAuth;
        try {
          googleAuth =
              await googleUser.authentication.timeout(_firebaseTimeout);
        } on TimeoutException catch (e) {
          _mostrarErrorDiagnostico(
              etapa: 'obtención de tokens de Google', error: e);
          return;
        }

        final credential = GoogleAuthProvider.credential(
          accessToken: googleAuth.accessToken,
          idToken: googleAuth.idToken,
        );

        try {
          userCredential = await _auth
              .signInWithCredential(credential)
              .timeout(_firebaseTimeout);
        } on PlatformException catch (e) {
          final mensaje = e.message ?? '';
          final esPlayServices =
              e.code == 'network_error' || mensaje.contains('ApiException: 7');
          if (!esPlayServices) rethrow;

          try {
            final provider = GoogleAuthProvider();
            provider.addScope('email');
            provider.addScope('profile');
            userCredential = await _auth
                .signInWithProvider(provider)
                .timeout(_firebaseTimeout);
          } on TimeoutException catch (te) {
            _mostrarErrorDiagnostico(
                etapa: 'fallback Google con FirebaseAuth provider', error: te);
            return;
          }
        } on TimeoutException catch (e) {
          _mostrarErrorDiagnostico(
              etapa: 'intercambio de credencial con Firebase Auth', error: e);
          return;
        }
      }

      await _continuarPostAuth(userCredential.user);
    } on FirebaseAuthException catch (e) {
      if (e.code == 'account-exists-with-different-credential') {
        final dynamic ex = e;
        final AuthCredential? pending = ex.credential as AuthCredential?;
        final emailCuenta =
            ((ex.email as String?) ?? emailController.text.trim())
                .trim()
                .toLowerCase();

        if (emailCuenta.isEmpty) {
          _mostrarErrorDiagnostico(
            etapa: 'vinculación de cuenta con Google',
            error: FirebaseAuthException(
              code: e.code,
              message:
                  'No se pudo resolver el correo. Intenta con correo manual primero.',
            ),
          );
          return;
        }

        final pass = await _pedirContrasenaParaVincular(emailCuenta);
        if (pass == null || pass.isEmpty) return;

        try {
          final baseCred = await _auth
              .signInWithEmailAndPassword(
                  email: emailCuenta, password: pass)
              .timeout(_firebaseTimeout);

          if (pending != null) {
            try {
              await baseCred.user?.linkWithCredential(pending);
            } on FirebaseAuthException catch (linkError) {
              if (linkError.code != 'provider-already-linked') rethrow;
            }
          }

          await _continuarPostAuth(_auth.currentUser ?? baseCred.user);
          return;
        } catch (linkProcessError) {
          _mostrarErrorDiagnostico(
              etapa: 'vinculación de cuenta con Google',
              error: linkProcessError);
          return;
        }
      }

      _mostrarErrorDiagnostico(
          etapa: 'autenticación con Firebase', error: e);
    } on PlatformException catch (e) {
      _mostrarErrorDiagnostico(etapa: 'Google Play Services', error: e);
    } on FirebaseException catch (e) {
      _mostrarErrorDiagnostico(etapa: 'Firestore/Firebase', error: e);
    } catch (e) {
      _mostrarErrorDiagnostico(
          etapa: 'inicio de sesión con Google', error: e);
    } finally {
      if (mounted) setState(() => isLoading = false);
    }
  }

  @override
  void dispose() {
    emailController.dispose();
    passwordController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedLavaBackground(
      child: Scaffold(
        backgroundColor: Colors.transparent,
        body: Center(
          child: SingleChildScrollView(
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 24),
              child: Card(
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(24),
                ),
                elevation: 20,
                shadowColor: Colors.black.withValues(alpha: 0.3),
                child: Padding(
                  padding: const EdgeInsets.all(32),
                  child: Form(
                    key: _formKey,
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Container(
                          padding: const EdgeInsets.all(16),
                          decoration: BoxDecoration(
                            color: Colors.white.withValues(alpha: 0.75),
                            borderRadius: BorderRadius.circular(18),
                          ),
                          child: ClipRRect(
                            borderRadius: BorderRadius.circular(14),
                            child: Image.asset(
                              'assets/logo recicladora.png',
                              width: 320,
                              height: 140,
                              fit: BoxFit.cover,
                              alignment: Alignment.center,
                            ),
                          ),
                        ),
                        const SizedBox(height: 20),
                        const Text(
                          'Inicia sesión en tu cuenta',
                          style: TextStyle(
                            fontSize: 14,
                            color: Color(0xFF666666),
                            fontWeight: FontWeight.w500,
                          ),
                        ),
                        const SizedBox(height: 32),
                        TextFormField(
                          controller: emailController,
                          validator: (value) {
                            if (value == null || value.isEmpty) {
                              return 'Ingresa tu correo';
                            }
                            return null;
                          },
                          decoration: InputDecoration(
                            labelText: 'Correo electrónico',
                            prefixIcon: const Icon(
                              Icons.email,
                              color: Color(0xFF1E3A8A),
                            ),
                            border: OutlineInputBorder(
                              borderRadius: BorderRadius.circular(12),
                              borderSide:
                                  const BorderSide(color: Color(0xFFE0E0E0)),
                            ),
                            focusedBorder: OutlineInputBorder(
                              borderRadius: BorderRadius.circular(12),
                              borderSide: const BorderSide(
                                color: Color(0xFF1E3A8A),
                                width: 2,
                              ),
                            ),
                            filled: true,
                            fillColor: const Color(0xFFFAFAFA),
                          ),
                          style: const TextStyle(color: Color(0xFF1F1F1F)),
                        ),
                        const SizedBox(height: 18),
                        TextFormField(
                          controller: passwordController,
                          obscureText: !isPasswordVisible,
                          validator: (value) {
                            if (value == null || value.isEmpty) {
                              return 'Ingresa tu contraseña';
                            }
                            return null;
                          },
                          decoration: InputDecoration(
                            labelText: 'Contraseña',
                            prefixIcon: const Icon(
                              Icons.lock,
                              color: Color(0xFF1E3A8A),
                            ),
                            suffixIcon: IconButton(
                              icon: Icon(
                                isPasswordVisible
                                    ? Icons.visibility
                                    : Icons.visibility_off,
                                color: const Color(0xFF1E3A8A),
                              ),
                              onPressed: () => setState(
                                  () => isPasswordVisible = !isPasswordVisible),
                            ),
                            border: OutlineInputBorder(
                              borderRadius: BorderRadius.circular(12),
                              borderSide:
                                  const BorderSide(color: Color(0xFFE0E0E0)),
                            ),
                            focusedBorder: OutlineInputBorder(
                              borderRadius: BorderRadius.circular(12),
                              borderSide: const BorderSide(
                                color: Color(0xFF1E3A8A),
                                width: 2,
                              ),
                            ),
                            filled: true,
                            fillColor: const Color(0xFFFAFAFA),
                          ),
                          style: const TextStyle(color: Color(0xFF1F1F1F)),
                        ),
                        const SizedBox(height: 28),
                        SizedBox(
                          width: double.infinity,
                          height: 52,
                          child: ElevatedButton(
                            onPressed: isLoading ? null : loginUsuario,
                            style: ElevatedButton.styleFrom(
                              backgroundColor: const Color(0xFF1E3A8A),
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(12),
                              ),
                              elevation: 3,
                            ),
                            child: isLoading
                                ? const CircularProgressIndicator(
                                    color: Colors.white)
                                : const Text(
                                    'Iniciar Sesión',
                                    style: TextStyle(
                                      fontSize: 16,
                                      fontWeight: FontWeight.bold,
                                      letterSpacing: 0.5,
                                      color: Colors.white,
                                    ),
                                  ),
                          ),
                        ),
                        const SizedBox(height: 14),
                        SizedBox(
                          width: double.infinity,
                          height: 52,
                          child: OutlinedButton(
                            onPressed: isLoading ? null : loginConGoogle,
                            style: OutlinedButton.styleFrom(
                              backgroundColor: Colors.white,
                              side: const BorderSide(
                                  color: Color(0xFFDADCE0)),
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(12),
                              ),
                            ),
                            child: isLoading
                                ? const SizedBox(
                                    width: 22,
                                    height: 22,
                                    child: CircularProgressIndicator(
                                        strokeWidth: 2),
                                  )
                                : const Row(
                                    mainAxisAlignment:
                                        MainAxisAlignment.center,
                                    children: [
                                      _GoogleLogo(),
                                      SizedBox(width: 12),
                                      Text(
                                        'Continuar con Google',
                                        style: TextStyle(
                                          fontSize: 15,
                                          fontWeight: FontWeight.w600,
                                          color: Color(0xFF1F1F1F),
                                        ),
                                      ),
                                    ],
                                  ),
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class _GoogleLogo extends StatelessWidget {
  const _GoogleLogo();

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: 18,
      height: 18,
      child: CustomPaint(painter: _GoogleLogoPainter()),
    );
  }
}

class _GoogleLogoPainter extends CustomPainter {
  @override
  void paint(Canvas canvas, Size size) {
    const strokeWidth = 2.6;
    final rect = Offset.zero & size;
    final center = rect.center;
    final radius = (size.width / 2) - (strokeWidth / 2);

    void drawArc(Color color, double startAngle, double sweepAngle) {
      final paint = Paint()
        ..color = color
        ..style = PaintingStyle.stroke
        ..strokeWidth = strokeWidth
        ..strokeCap = StrokeCap.round;
      canvas.drawArc(
        Rect.fromCircle(center: center, radius: radius),
        startAngle,
        sweepAngle,
        false,
        paint,
      );
    }

    drawArc(const Color(0xFF4285F4), -0.15, 1.25);
    drawArc(const Color(0xFF34A853), 1.1, 1.15);
    drawArc(const Color(0xFFFBBC05), 2.3, 0.9);
    drawArc(const Color(0xFFEA4335), 3.15, 1.15);

    final blueBar = Paint()
      ..color = const Color(0xFF4285F4)
      ..style = PaintingStyle.stroke
      ..strokeWidth = strokeWidth
      ..strokeCap = StrokeCap.round;

    final midY = size.height / 2;
    canvas.drawLine(
      Offset(size.width * 0.52, midY),
      Offset(size.width * 0.94, midY),
      blueBar,
    );
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}