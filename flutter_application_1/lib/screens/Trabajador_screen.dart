import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';

class TrabajadorScreen extends StatefulWidget {
  const TrabajadorScreen({super.key});

  @override
  State<TrabajadorScreen> createState() => _TrabajadorScreen();
}

class _TrabajadorScreen extends State<TrabajadorScreen> {

  String nombreUsuario = "";
  bool isLoading = true;

  @override
  void initState() {
    super.initState();
    obtenerNombre();
  }

  Future<void> obtenerNombre() async {
    String uid = FirebaseAuth.instance.currentUser!.uid;

    DocumentSnapshot doc = await FirebaseFirestore.instance
        .collection("usuarios")
        .doc(uid)
        .get();

    setState(() {
      nombreUsuario = doc["nombre"];
      isLoading = false;
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: isLoading
            ? const Text("Cargando...")
            : Text("Hola, $nombreUsuario"),
        backgroundColor: Colors.green,
      ),
      body: const Center(
        child: Text("Pantalla Trabajador"),
      ),
    );
  }
}