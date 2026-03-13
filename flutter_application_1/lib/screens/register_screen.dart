import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';

class RegisterScreen extends StatefulWidget {
  const RegisterScreen({super.key});

  @override
  State<RegisterScreen> createState() => _RegisterScreenState();
}

class _RegisterScreenState extends State<RegisterScreen> {

  final _formKey = GlobalKey<FormState>();

  // 🔹 Controllers generales
  final nombreController = TextEditingController();
  final paternoController = TextEditingController();
  final maternoController = TextEditingController();
  final telefonoController = TextEditingController();
  final direccionController = TextEditingController();
  final curpController = TextEditingController();

  final emailController = TextEditingController();
  final passwordController = TextEditingController();

  // 🔥 SOLO operador
  final rfcController = TextEditingController();
  final licenciaController = TextEditingController();
  final vigenciaController = TextEditingController();

  String rolSeleccionado = "trabajador";

  final FirebaseAuth _auth = FirebaseAuth.instance;
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;

  bool _obscurePassword = true;
  Future<void> registrarUsuario() async {

    if (!_formKey.currentState!.validate()) return;

    try {

      UserCredential userCredential =
          await _auth.createUserWithEmailAndPassword(
        email: emailController.text.trim(),
        password: passwordController.text.trim(),
      );

      String uid = userCredential.user!.uid;

      await _firestore.collection("usuarios").doc(uid).set({

        "nombre": nombreController.text.trim(),
        "apellido_paterno": paternoController.text.trim(),
        "apellido_materno": maternoController.text.trim(),
        "telefono": telefonoController.text.trim(),
        "direccion": direccionController.text.trim(),
        "curp": curpController.text.trim(),

        "email": emailController.text.trim(),
        "rol": rolSeleccionado,

        // 🔥 Operador
        "rfc": rolSeleccionado == "operador"
            ? rfcController.text.trim()
            : null,

        "tipo_licencia": rolSeleccionado == "operador"
            ? licenciaController.text.trim()
            : null,

        "vigencia_licencia": rolSeleccionado == "operador"
            ? vigenciaController.text.trim()
            : null,

        // Extras útiles
        "activo": true,
        "fecha_registro": FieldValue.serverTimestamp(),
      });

      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text("Usuario registrado correctamente")),
      );

      Navigator.pop(context);

    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text("Error: $e")),
      );
    }
  }

  InputDecoration estiloCampo(String texto, IconData icono) {
    return InputDecoration(
      labelText: texto,
      prefixIcon: Icon(icono, color: const Color(0xFF1E3A8A)),
      border: OutlineInputBorder(
        borderRadius: BorderRadius.circular(12),
        borderSide: const BorderSide(color: Color(0xFFE0E0E0)),
      ),
      focusedBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(12),
        borderSide: const BorderSide(color: Color(0xFF1E3A8A), width: 2),
      ),
      filled: true,
      fillColor: const Color(0xFFFAFAFA),
      contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
    );
  }

  @override
  Widget build(BuildContext context) {

    return Scaffold(
      backgroundColor: const Color(0xFFFAFAFA),
      appBar: AppBar(
        title: const Text("Crear Cuenta", style: TextStyle(fontWeight: FontWeight.bold, color: Colors.white)),
        elevation: 0,
        backgroundColor: const Color(0xFF1E3A8A),
        centerTitle: true,
        iconTheme: const IconThemeData(color: Colors.white), // flecha regresar blanca
      ),
      body: SingleChildScrollView(
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 24),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              // Encabezado visual
              Container(
                padding: const EdgeInsets.all(20),
                decoration: BoxDecoration(
                  gradient: const LinearGradient(
                    colors: [Color(0xFF1E3A8A), Color(0xFF2563EB)],
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                  ),
                  borderRadius: BorderRadius.circular(16),
                ),
                child: Column(
                  children: [
                    Container(
                      padding: const EdgeInsets.all(12),
                      decoration: BoxDecoration(
                        color: Colors.white.withOpacity(0.2),
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: const Icon(Icons.app_registration, color: Colors.white, size: 40),
                    ),
                    const SizedBox(height: 14),
                    const Text(
                      "Regístrate ahora",
                      style: TextStyle(
                        fontSize: 22,
                        fontWeight: FontWeight.bold,
                        color: Colors.white,
                        letterSpacing: 0.5,
                      ),
                    ),
                    const SizedBox(height: 6),
                    const Text(
                      "Completa todos los datos para crear tu cuenta",
                      style: TextStyle(
                        fontSize: 13,
                        color: Colors.white70,
                      ),
                      textAlign: TextAlign.center,
                    ),
                  ],
                ),
              ),

              const SizedBox(height: 24),

              // Tarjeta con el formulario
              Card(
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                elevation: 4,
                shadowColor: Colors.black.withOpacity(0.1),
                child: Padding(
                  padding: const EdgeInsets.all(20),
                  child: Form(
                    key: _formKey,
                    child: Column(
                      children: [
                        DropdownButtonFormField<String>(
                          value: rolSeleccionado,
                          decoration: estiloCampo("Tipo de usuario", Icons.person),
                          items: const [
                            DropdownMenuItem(
                              value: "operador",
                              child: Text("Operador (Tráiler)"),
                            ),
                            DropdownMenuItem(
                              value: "trabajador",
                              child: Text("Trabajador"),
                            ),
                          ],
                          onChanged: (value) {
                            setState(() {
                              rolSeleccionado = value!;
                            });
                          },
                        ),

                        const SizedBox(height: 12),

                        // Nombres en una fila flexible
                        Row(
                          children: [
                            Expanded(
                              child: TextFormField(
                                controller: nombreController,
                                validator: (value) => value!.isEmpty ? "Campo obligatorio" : null,
                                decoration: estiloCampo("Nombre", Icons.person),
                              ),
                            ),
                            const SizedBox(width: 10),
                            Expanded(
                              child: TextFormField(
                                controller: paternoController,
                                validator: (value) => value!.isEmpty ? "Campo obligatorio" : null,
                                decoration: estiloCampo("Apellido paterno", Icons.badge),
                              ),
                            ),
                          ],
                        ),

                        const SizedBox(height: 12),

                        TextFormField(
                          controller: maternoController,
                          decoration: estiloCampo("Apellido materno", Icons.badge),
                        ),

                        const SizedBox(height: 12),

                        TextFormField(
                          controller: telefonoController,
                          keyboardType: TextInputType.phone,
                          validator: (value) => value!.isEmpty ? "Campo obligatorio" : null,
                          decoration: estiloCampo("Teléfono", Icons.phone),
                        ),

                        const SizedBox(height: 12),

                        TextFormField(
                          controller: direccionController,
                          decoration: estiloCampo("Dirección", Icons.home),
                        ),

                        const SizedBox(height: 12),

                        TextFormField(
                          controller: curpController,
                          decoration: estiloCampo("CURP", Icons.credit_card),
                        ),

                        const SizedBox(height: 12),

                        TextFormField(
                          controller: emailController,
                          keyboardType: TextInputType.emailAddress,
                          validator: (value) => value!.isEmpty ? "Campo obligatorio" : null,
                          decoration: estiloCampo("Correo", Icons.email),
                        ),

                        const SizedBox(height: 12),

                        TextFormField(
                          controller: passwordController,
                          obscureText: _obscurePassword,
                          validator: (value) {
                            if (value!.isEmpty) return "Campo obligatorio";
                            if (value.length < 6) return "Mínimo 6 caracteres";
                            return null;
                          },
                          decoration: estiloCampo("Contraseña", Icons.lock).copyWith(
                            suffixIcon: IconButton(
                              icon: Icon(
                                _obscurePassword ? Icons.visibility : Icons.visibility_off,
                                color: const Color(0xFF1E3A8A),
                              ),
                              onPressed: () => setState(() => _obscurePassword = !_obscurePassword),
                            ),
                          ),
                        ),

                        // Campos para operador
                        if (rolSeleccionado == "operador") ...[
                          const SizedBox(height: 18),
                          const Divider(),
                          const SizedBox(height: 6),
                          const Align(
                            alignment: Alignment.centerLeft,
                            child: Text("Datos del Operador", style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
                          ),
                          const SizedBox(height: 12),
                          TextFormField(
                            controller: rfcController,
                            decoration: estiloCampo("RFC", Icons.assignment),
                          ),
                          const SizedBox(height: 12),
                          TextFormField(
                            controller: licenciaController,
                            decoration: estiloCampo("Tipo de Licencia", Icons.car_rental),
                          ),
                          const SizedBox(height: 12),
                          TextFormField(
                            controller: vigenciaController,
                            decoration: estiloCampo("Vigencia de Licencia", Icons.date_range),
                          ),
                        ],

                        const SizedBox(height: 18),

                        SizedBox(
                          width: double.infinity,
                          height: 52,
                          child: ElevatedButton(
                            style: ElevatedButton.styleFrom(
                              backgroundColor: const Color(0xFF1E3A8A),
                              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                              elevation: 3,
                            ),
                            onPressed: registrarUsuario,
                            child: const Text(
                              "Registrar",
                              style: TextStyle(
                                fontSize: 16,
                                fontWeight: FontWeight.bold,
                                letterSpacing: 0.5,
                                color: Colors.white,
                              ),
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ),

              const SizedBox(height: 16),
              Center(
                child: Text(
                  "Al registrarte aceptas nuestros términos y políticas.",
                  style: TextStyle(color: Colors.grey[600], fontSize: 12),
                  textAlign: TextAlign.center,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}