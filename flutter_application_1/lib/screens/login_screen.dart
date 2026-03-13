import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'dart:math';
import 'register_screen.dart';
import 'admin_screen.dart';
import 'operador_screen.dart';
import 'Trabajador_screen.dart';

// CustomPainter para el fondo animado tipo lava lámpara
class LavaLampPainter extends CustomPainter {
  final double animationValue;
  
  LavaLampPainter({required this.animationValue});

  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint();
    
    // Colores que cambian suavemente
    // Paleta azul (consistente con el UI)
    List<Color> colors = [
      Color.lerp(const Color(0xFF1E3A8A), const Color(0xFF2563EB),
              animationValue % 1.0) ??
          const Color(0xFF1E3A8A),
      Color.lerp(const Color(0xFF2563EB), const Color(0xFF38BDF8),
              (animationValue + 0.33) % 1.0) ??
          const Color(0xFF2563EB),
      Color.lerp(const Color(0xFF38BDF8), const Color(0xFF1E3A8A),
              (animationValue + 0.66) % 1.0) ??
          const Color(0xFF38BDF8),
    ];

    // Dibujar blobs animados
    for (int i = 0; i < colors.length; i++) {
      paint.color = colors[i].withOpacity(0.3 + 0.3 * sin(animationValue * 2 + i));
      
      double offsetX = size.width * (0.25 + 0.2 * sin(animationValue + i));
      double offsetY = size.height * (0.3 + 0.25 * cos(animationValue * 0.8 + i * 2));
      
      double radius = size.width * (0.12 + 0.05 * sin(animationValue * 1.5 + i));
      
      canvas.drawCircle(
        Offset(offsetX, offsetY),
        radius,
        paint,
      );
    }

    // Dibujar blobs secundarios
    for (int i = 0; i < 2; i++) {
      paint.color = colors[(i + 1) % colors.length].withOpacity(0.15 + 0.15 * cos(animationValue * 1.2 + i));
      
      double offsetX = size.width * (0.7 + 0.15 * cos(animationValue * 0.7 + i * 1.5));
      double offsetY = size.height * (0.6 + 0.2 * sin(animationValue * 0.9 + i));
      
      double radius = size.width * (0.15 + 0.08 * cos(animationValue + i * 3));
      
      canvas.drawCircle(
        Offset(offsetX, offsetY),
        radius,
        paint,
      );
    }

    // Efecto de degradado suave sobre los blobs
    final gradientPaint = Paint()
      ..shader = LinearGradient(
        colors: [
          Colors.transparent,
          const Color(0xFF1E3A8A).withOpacity(0.06),
        ],
        begin: Alignment.topCenter,
        end: Alignment.bottomCenter,
      ).createShader(Rect.fromLTWH(0, 0, size.width, size.height));
    
    canvas.drawRect(Rect.fromLTWH(0, 0, size.width, size.height), gradientPaint);
  }

  @override
  bool shouldRepaint(LavaLampPainter oldDelegate) => true;
}

// Widget del fondo animado
class AnimatedLavaBackground extends StatefulWidget {
  final Widget child;

  const AnimatedLavaBackground({required this.child});

  @override
  State<AnimatedLavaBackground> createState() => _AnimatedLavaBackgroundState();
}

class _AnimatedLavaBackgroundState extends State<AnimatedLavaBackground>
    with SingleTickerProviderStateMixin {
  late AnimationController _controller;

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
              colors: [
                Color(0xFF050B1E),
                Color(0xFF0B1B3A),
              ],
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

  final _formKey = GlobalKey<FormState>();

  bool isLoading = false;
  bool isPasswordVisible = false;

  Future<void> loginUsuario() async {

    if (!_formKey.currentState!.validate()) return;

    setState(() {
      isLoading = true;
    });

    try {

      UserCredential userCredential =
          await _auth.signInWithEmailAndPassword(
        email: emailController.text.trim(),
        password: passwordController.text.trim(),
      );

      String uid = userCredential.user!.uid;

      DocumentSnapshot userDoc =
          await _firestore.collection("usuarios").doc(uid).get();

      if (!userDoc.exists) {
        throw Exception("Usuario sin datos en Firestore");
      }

      String rol = userDoc["rol"];

      if (rol == "admin") {

        Navigator.pushReplacement(
          context,
          MaterialPageRoute(builder: (_) =>  AdminScreen()),
        );

      } else if (rol == "operador") {

       final nombre = userDoc["nombre"];

      Navigator.pushReplacement(
         context,
         MaterialPageRoute(
          builder: (_) => OperadorScreen(nombreUsuario: nombre),
  ),
);

      } else if (rol == "trabajador") {

        Navigator.pushReplacement(
          context,
          MaterialPageRoute(builder: (_) =>  TrabajadorScreen()),
        );

      } else {

        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text("Rol no válido"),
            backgroundColor: Colors.red,
          ),
        );
      }

    } on FirebaseAuthException catch (e) {

      String mensaje = "Error al iniciar sesión";

      if (e.code == 'user-not-found') {
        mensaje = "Usuario no encontrado";
      } else if (e.code == 'wrong-password') {
        mensaje = "Contraseña incorrecta";
      } else if (e.code == 'invalid-email') {
        mensaje = "Correo inválido";
      }

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(mensaje),
          backgroundColor: Colors.red,
        ),
      );

    } catch (e) {

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text("Error: $e"),
          backgroundColor: Colors.red,
        ),
      );
    }

    setState(() {
      isLoading = false;
    });
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
                shadowColor: Colors.black.withOpacity(0.3),
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
                            color: Colors.white.withOpacity(0.75),
                            borderRadius: BorderRadius.circular(18),
                          ),
                          child: ClipRRect(
                            borderRadius: BorderRadius.circular(14),
                            child: Image.asset(
                              'lib/assets/logo recicladora.png',
                              width: 320,
                              height: 140,
                              fit: BoxFit.cover,
                              alignment: Alignment.center,
                            ),
                          ),
                        ),

                        const SizedBox(height: 20),

                        const Text(
                          "RECICLADORA GUADALAJARA",
                          style: TextStyle(
                            fontSize: 26,
                            fontWeight: FontWeight.bold,
                            color: Color(0xFF1F1F1F),
                            letterSpacing: 0.5,
                          ),
                        ),

                        const SizedBox(height: 8),

                        const Text(
                          "Inicia sesión en tu cuenta",
                          style: TextStyle(
                            fontSize: 14,
                            color: Color(0xFF666666),
                            fontWeight: FontWeight.w500,
                          ),
                        ),

                        const SizedBox(height: 32),

                        /// EMAIL
                        TextFormField(
                          controller: emailController,
                          validator: (value) {
                            if (value == null || value.isEmpty) {
                              return "Ingresa tu correo";
                            }
                            return null;
                          },
                          decoration: InputDecoration(
                            labelText: "Correo electrónico",
                            prefixIcon: const Icon(Icons.email, color: Color(0xFF1E3A8A)),
                            border: OutlineInputBorder(
                              borderRadius: BorderRadius.circular(12),
                              borderSide: const BorderSide(color: Color(0xFFE0E0E0)),
                            ),
                            focusedBorder: OutlineInputBorder(
                              borderRadius: BorderRadius.circular(12),
                              borderSide: const BorderSide(color: Color(0xFF1E3A8A), width: 2),
                            ),
                            filled: true,
                            fillColor: Color(0xFFFAFAFA),
                          ),
                          style: const TextStyle(color: Color(0xFF1F1F1F)),
                        ),

                        const SizedBox(height: 18),

                        /// PASSWORD
                        TextFormField(
                          controller: passwordController,
                          obscureText: !isPasswordVisible,
                          validator: (value) {
                            if (value == null || value.isEmpty) {
                              return "Ingresa tu contraseña";
                            }
                            if (value.length < 6) {
                              return "Mínimo 6 caracteres";
                            }
                            return null;
                          },
                          decoration: InputDecoration(
                            labelText: "Contraseña",
                            prefixIcon: const Icon(Icons.lock, color: Color(0xFF1E3A8A)),
                            suffixIcon: IconButton(
                              icon: Icon(
                                isPasswordVisible
                                    ? Icons.visibility
                                    : Icons.visibility_off,
                                color: Color(0xFF1E3A8A),
                              ),
                              onPressed: () {
                                setState(() {
                                  isPasswordVisible = !isPasswordVisible;
                                });
                              },
                            ),
                            border: OutlineInputBorder(
                              borderRadius: BorderRadius.circular(12),
                              borderSide: const BorderSide(color: Color(0xFFE0E0E0)),
                            ),
                            focusedBorder: OutlineInputBorder(
                              borderRadius: BorderRadius.circular(12),
                              borderSide: const BorderSide(color: Color(0xFF1E3A8A), width: 2),
                            ),
                            filled: true,
                            fillColor: Color(0xFFFAFAFA),
                          ),
                          style: const TextStyle(color: Color(0xFF1F1F1F)),
                        ),

                        const SizedBox(height: 28),

                        /// BOTÓN LOGIN
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
                                    "Iniciar Sesión",
                                    style: TextStyle(
                                      fontSize: 16,
                                      fontWeight: FontWeight.bold,
                                      letterSpacing: 0.5,
                                      color: Colors.white,
                                    ),
                                  ),
                          ),
                        ),

                        const SizedBox(height: 16),

                        /// CREAR CUENTA
                        TextButton(
                          onPressed: () {
                            Navigator.push(
                              context,
                              MaterialPageRoute(
                                  builder: (_) => RegisterScreen()),
                            );
                          },
                          child: const Text(
                            "¿No tienes cuenta? Registrate aquí",
                            style: TextStyle(
                              color: Color(0xFF1E3A8A),
                              fontWeight: FontWeight.w600,
                              fontSize: 14,
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