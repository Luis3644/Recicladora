import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';

class AdminScreen extends StatefulWidget {
  const AdminScreen({super.key});

  @override
  State<AdminScreen> createState() => _AdminScreen();
}

class _AdminScreen extends State<AdminScreen> {

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
            : Text("Admin ($nombreUsuario)"),
        backgroundColor: Colors.green,
      ),
      body: const Center(
        child: Text("Pantalla Admin"),
      ),
    );
  }
}