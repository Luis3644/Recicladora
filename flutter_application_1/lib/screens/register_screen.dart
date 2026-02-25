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
      prefixIcon: Icon(icono),
      border: OutlineInputBorder(
        borderRadius: BorderRadius.circular(15),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {

    return Scaffold(
      appBar: AppBar(title: const Text("Registro")),
      body: SingleChildScrollView(
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

                const SizedBox(height: 15),

                TextFormField(
                  controller: nombreController,
                  validator: (value) =>
                      value!.isEmpty ? "Campo obligatorio" : null,
                  decoration: estiloCampo("Nombre", Icons.person),
                ),

                const SizedBox(height: 15),

                TextFormField(
                  controller: paternoController,
                  validator: (value) =>
                      value!.isEmpty ? "Campo obligatorio" : null,
                  decoration: estiloCampo("Apellido paterno", Icons.badge),
                ),

                const SizedBox(height: 15),

                TextFormField(
                  controller: maternoController,
                  decoration: estiloCampo("Apellido materno", Icons.badge),
                ),

                const SizedBox(height: 15),

                TextFormField(
                  controller: telefonoController,
                  validator: (value) =>
                      value!.isEmpty ? "Campo obligatorio" : null,
                  decoration: estiloCampo("Teléfono", Icons.phone),
                ),

                const SizedBox(height: 15),

                TextFormField(
                  controller: direccionController,
                  decoration: estiloCampo("Dirección", Icons.home),
                ),

                const SizedBox(height: 15),

                TextFormField(
                  controller: curpController,
                  decoration: estiloCampo("CURP", Icons.credit_card),
                ),

                const SizedBox(height: 15),

                TextFormField(
                  controller: emailController,
                  validator: (value) =>
                      value!.isEmpty ? "Campo obligatorio" : null,
                  decoration: estiloCampo("Correo", Icons.email),
                ),

                const SizedBox(height: 15),

                TextFormField(
                  controller: passwordController,
                  obscureText: true,
                  validator: (value) {
                    if (value!.isEmpty) return "Campo obligatorio";
                    if (value.length < 6) return "Mínimo 6 caracteres";
                    return null;
                  },
                  decoration: estiloCampo("Contraseña", Icons.lock),
                ),

                // 🔥 CAMPOS SOLO OPERADOR
                if (rolSeleccionado == "operador") ...[

                  const SizedBox(height: 20),

                  const Divider(),

                  const Text(
                    "Datos del Operador",
                    style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
                  ),

                  const SizedBox(height: 15),

                  TextFormField(
                    controller: rfcController,
                    decoration: estiloCampo("RFC", Icons.assignment),
                  ),

                  const SizedBox(height: 15),

                  TextFormField(
                    controller: licenciaController,
                    decoration: estiloCampo("Tipo de Licencia", Icons.car_rental),
                  ),

                  const SizedBox(height: 15),

                  TextFormField(
                    controller: vigenciaController,
                    decoration: estiloCampo("Vigencia de Licencia", Icons.date_range),
                  ),
                ],

                const SizedBox(height: 25),

                SizedBox(
                  width: double.infinity,
                  height: 50,
                  child: ElevatedButton(
                    onPressed: registrarUsuario,
                    child: const Text("Registrar"),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}