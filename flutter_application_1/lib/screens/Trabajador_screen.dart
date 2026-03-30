import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';

import 'widgets_conexion/connection_wrapper.dart';

class TrabajadorScreen extends StatefulWidget {
  const TrabajadorScreen({super.key});

  @override
  State<TrabajadorScreen> createState() => _TrabajadorScreen();
}

class _TrabajadorScreen extends State<TrabajadorScreen> {
  String nombreUsuario = '';
  bool isLoading = true;

  @override
  void initState() {
    super.initState();
    obtenerNombre();
  }

  Future<DocumentSnapshot<Map<String, dynamic>>?>
  _obtenerPerfilUsuario() async {
    final currentUser = FirebaseAuth.instance.currentUser;
    if (currentUser == null) return null;

    final doc = await FirebaseFirestore.instance
        .collection('usuarios')
        .doc(currentUser.uid)
        .get();

    if (doc.exists) return doc;

    final email = currentUser.email;
    if (email == null || email.isEmpty) return null;

    final query = await FirebaseFirestore.instance
        .collection('usuarios')
        .where('email', isEqualTo: email)
        .limit(1)
        .get();

    if (query.docs.isEmpty) return null;
    return query.docs.first;
  }

  Future<void> obtenerNombre() async {
    final doc = await _obtenerPerfilUsuario();
    if (!mounted) return;

    setState(() {
      nombreUsuario = doc?.data()?['nombre']?.toString() ?? 'Trabajador';
      isLoading = false;
    });
  }

  @override
  Widget build(BuildContext context) {
    return ConnectionWrapper(
      child: Scaffold(
        appBar: AppBar(
          title: isLoading
              ? const Text('Cargando...')
              : Text('Hola, $nombreUsuario'),
          backgroundColor: Colors.green,
        ),
        body: const Center(child: Text('Pantalla Trabajador')),
      ),
    );
  }
}
