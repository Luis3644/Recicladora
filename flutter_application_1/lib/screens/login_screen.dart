import 'dart:math';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:google_sign_in/google_sign_in.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../config/session_manager.dart';
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
      final radius = size.width * (0.12 + 0.05 * sin(animationValue * 1.5 + i));

      canvas.drawCircle(Offset(offsetX, offsetY), radius, paint);
    }

    for (int i = 0; i < 2; i++) {
      paint.color = colors[(i + 1) % colors.length].withValues(
        alpha: 0.15 + 0.15 * cos(animationValue * 1.2 + i),
      );

      final offsetX =
          size.width * (0.7 + 0.15 * cos(animationValue * 0.7 + i * 1.5));
      final offsetY = size.height * (0.6 + 0.2 * sin(animationValue * 0.9 + i));
      final radius = size.width * (0.15 + 0.08 * cos(animationValue + i * 3));

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
            painter: LavaLampPainter(animationValue: _controller.value * 6.28),
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

  @override
  void initState() {
    super.initState();
    _googleSignIn = GoogleSignIn(scopes: const ['email', 'profile']);
  }

  Future<DocumentSnapshot<Map<String, dynamic>>?> _obtenerPerfilUsuario({
    String? uid,
    String? email,
  }) async {
    final emailNormalizado = email?.trim().toLowerCase();

    if (uid != null && uid.isNotEmpty) {
      final doc = await _firestore.collection('usuarios').doc(uid).get();
      if (doc.exists) {
        final data = doc.data();
        final emailDoc = data?['email']?.toString().trim().toLowerCase();

        // Usa coincidencia por uid solo si el correo también coincide.
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
          .where('email', isEqualTo: email.trim())
          .get();

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
    if (data == null) {
      throw Exception('Usuario sin datos en Firestore');
    }

    final rol = data['rol']?.toString() ?? '';
    final nombre = data['nombre']?.toString() ?? '';
    final usuarioDocId = userDoc.id;

    if (_dispositivoIdActual.isEmpty) {
      _dispositivoIdActual = await _obtenerDispositivoId();
    }

    if (rol == 'admin') {
      await SessionManager.guardarSesion(
        rol: rol,
        nombre: nombre,
        usuarioDocId: usuarioDocId,
        dispositivoId: _dispositivoIdActual,
      );
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
      Navigator.pushReplacement(
        context,
        MaterialPageRoute(
          builder: (_) => OperadorScreen(nombreUsuario: nombre),
        ),
      );
      return;
    }

    if (rol == 'trabajador') {
      await SessionManager.guardarSesion(
        rol: rol,
        nombre: nombre,
        usuarioDocId: usuarioDocId,
        dispositivoId: _dispositivoIdActual,
      );
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
      case TargetPlatform.android:
        return 'Android';
      case TargetPlatform.iOS:
        return 'iOS';
      case TargetPlatform.windows:
        return 'Windows';
      case TargetPlatform.macOS:
        return 'macOS';
      case TargetPlatform.linux:
        return 'Linux';
      case TargetPlatform.fuchsia:
        return 'Fuchsia';
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
    final data = userDoc.data() ?? {};
    final dispositivoId = await _obtenerDispositivoId();
    final dispositivoActualNombre = _nombreDispositivoActual();
    _dispositivoIdActual = dispositivoId;

    final sesionActiva = data['sesion_activa'] == true;
    final dispositivoRemoto = data['sesion_dispositivo_id']?.toString() ?? '';

    if (sesionActiva &&
        dispositivoRemoto.isNotEmpty &&
        dispositivoRemoto != dispositivoId) {
      await _auth.signOut();
      await _googleSignIn.signOut();
      await SessionManager.limpiarSesion();

      await _mostrarDialogoSesionActivaBloqueada(
        nombre: data['nombre']?.toString() ?? 'Sin nombre',
        rol: data['rol']?.toString() ?? 'sin rol',
      );
      return false;
    }

    await _firestore.collection('usuarios').doc(userDoc.id).set({
      'sesion_activa': true,
      'sesion_dispositivo_id': dispositivoId,
      'sesion_dispositivo_nombre': dispositivoActualNombre,
      'sesion_ultimo_inicio': FieldValue.serverTimestamp(),
    }, SetOptions(merge: true));

    return true;
  }

  Future<DocumentSnapshot<Map<String, dynamic>>?>
  _autenticarContrasenaFirestore() async {
    final email = emailController.text.trim();
    final password = passwordController.text.trim();

    if (email.isEmpty || password.isEmpty) return null;

    final query = await _firestore
        .collection('usuarios')
        .where('email', isEqualTo: email)
        .limit(1)
        .get();

    if (query.docs.isEmpty) return null;

    final doc = query.docs.first;
    final data = doc.data();
    final contrasenaGuardada = data['contrasena']?.toString() ?? '';

    if (contrasenaGuardada.isEmpty || contrasenaGuardada != password) {
      return null;
    }

    return doc;
  }

  Future<void> loginUsuario() async {
    if (!_formKey.currentState!.validate()) return;

    setState(() {
      isLoading = true;
    });

    try {
      final userCredential = await _auth.signInWithEmailAndPassword(
        email: emailController.text.trim(),
        password: passwordController.text.trim(),
      );

      final firebaseUser = userCredential.user;
      final userDoc = await _obtenerPerfilUsuario(
        uid: firebaseUser?.uid,
        email: firebaseUser?.email ?? emailController.text.trim(),
      );

      if (userDoc == null) {
        await _mostrarErrorNoRegistrado();
        return;
      }

      final permitido = await _validarYRegistrarSesionUnica(userDoc);
      if (!permitido) return;

      await _redirigirSegunRol(userDoc);
    } on FirebaseAuthException catch (e) {
      // Respaldo para usuarios registrados directamente en Firestore.
      if (e.code == 'user-not-found' ||
          e.code == 'wrong-password' ||
          e.code == 'invalid-credential' ||
          e.code == 'invalid-login-credentials') {
        final userDoc = await _autenticarContrasenaFirestore();
        if (userDoc != null) {
          final permitido = await _validarYRegistrarSesionUnica(userDoc);
          if (!permitido) return;
          await _redirigirSegunRol(userDoc);
          return;
        }
      }

      var mensaje = 'Error al iniciar sesión';

      if (e.code == 'user-not-found') {
        mensaje = 'Usuario no encontrado';
      } else if (e.code == 'wrong-password') {
        mensaje = 'Contraseña incorrecta';
      } else if (e.code == 'invalid-email') {
        mensaje = 'Correo inválido';
      }

      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(mensaje), backgroundColor: Colors.red),
      );
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Error: $e'), backgroundColor: Colors.red),
      );
    } finally {
      if (mounted) {
        setState(() {
          isLoading = false;
        });
      }
    }
  }

  Future<void> loginConGoogle() async {
    setState(() {
      isLoading = true;
    });

    try {
      UserCredential userCredential;
      if (kIsWeb) {
        final provider = GoogleAuthProvider();
        provider.addScope('email');
        provider.addScope('profile');
        provider.setCustomParameters({'prompt': 'select_account'});
        userCredential = await _auth.signInWithPopup(provider);
      } else {
        // Fuerza el selector de cuentas para evitar reingreso automático.
        try {
          await _googleSignIn.disconnect();
        } catch (_) {
          await _googleSignIn.signOut();
        }

        final googleUser = await _googleSignIn.signIn();
        if (googleUser == null) return;

        final googleAuth = await googleUser.authentication;
        final credential = GoogleAuthProvider.credential(
          accessToken: googleAuth.accessToken,
          idToken: googleAuth.idToken,
        );
        userCredential = await _auth.signInWithCredential(credential);
      }

      final firebaseUser = userCredential.user;
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

      final permitido = await _validarYRegistrarSesionUnica(userDoc);
      if (!permitido) return;

      await _redirigirSegunRol(userDoc);
    } on FirebaseAuthException catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Error con Google: ${e.message ?? e.code}'),
          backgroundColor: Colors.red,
        ),
      );
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Error al iniciar con Google: $e'),
          backgroundColor: Colors.red,
        ),
      );
    } finally {
      if (mounted) {
        setState(() {
          isLoading = false;
        });
      }
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
                          'RECICLADORA GUADALAJARA',
                          style: TextStyle(
                            fontSize: 26,
                            fontWeight: FontWeight.bold,
                            color: Color(0xFF1F1F1F),
                            letterSpacing: 0.5,
                          ),
                        ),
                        const SizedBox(height: 8),
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
                              borderSide: const BorderSide(
                                color: Color(0xFFE0E0E0),
                              ),
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
                              onPressed: () {
                                setState(() {
                                  isPasswordVisible = !isPasswordVisible;
                                });
                              },
                            ),
                            border: OutlineInputBorder(
                              borderRadius: BorderRadius.circular(12),
                              borderSide: const BorderSide(
                                color: Color(0xFFE0E0E0),
                              ),
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
                                    color: Colors.white,
                                  )
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
                              side: const BorderSide(color: Color(0xFFDADCE0)),
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(12),
                              ),
                            ),
                            child: isLoading
                                ? const SizedBox(
                                    width: 22,
                                    height: 22,
                                    child: CircularProgressIndicator(
                                      strokeWidth: 2,
                                    ),
                                  )
                                : const Row(
                                    mainAxisAlignment: MainAxisAlignment.center,
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
