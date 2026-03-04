import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'usuarios_screen.dart';

class AdminScreen extends StatefulWidget {
  const AdminScreen({super.key});

  @override
  State<AdminScreen> createState() => _AdminScreenState();
}

class _AdminScreenState extends State<AdminScreen> {

  String nombreUsuario = "";
  bool isLoading = true;

  @override
  void initState() {
    super.initState();
    obtenerNombre();
  }

  Future<void> obtenerNombre() async {
    final uid = FirebaseAuth.instance.currentUser!.uid;

    final doc = await FirebaseFirestore.instance
        .collection("usuarios")
        .doc(uid)
        .get();

    if (doc.exists) {
      setState(() {
        nombreUsuario = doc["nombre"];
        isLoading = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: isLoading
            ? const Text("Cargando...")
            : Text("Admin $nombreUsuario"),
        backgroundColor: const Color.fromARGB(255, 76, 94, 175),
      ),
      body: Center(
        child: ElevatedButton.icon(
          style: ElevatedButton.styleFrom(
            padding: const EdgeInsets.symmetric(horizontal: 30, vertical: 15),
          ),
          onPressed: () {
            Navigator.push(
              context,
              MaterialPageRoute(
                builder: (_) => const UsuariosScreen(),
              ),
            );
          },
          icon: const Icon(Icons.people),
          label: const Text("Ver Usuarios"),
        ),
      ),
    );
  }
}