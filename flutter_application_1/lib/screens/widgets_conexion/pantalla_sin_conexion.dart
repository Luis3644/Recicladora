import 'package:flutter/material.dart';

class PantallaSinConexion extends StatelessWidget {
  const PantallaSinConexion({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.white,
      body: Center(
        child: Padding(
          padding: const EdgeInsets.all(30.0),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              const Icon(Icons.signal_wifi_off, size: 100, color: Colors.redAccent),
              const SizedBox(height: 20),
              const Text(
                "Sin conexión a Internet",
                style: TextStyle(fontSize: 22, fontWeight: FontWeight.bold),
              ),
              const SizedBox(height: 15),
              const Text(
                "Para registrar datos de logística necesitas estar conectado. Por favor, revisa tu señal.",
                textAlign: TextAlign.center,
                style: TextStyle(fontSize: 16, color: Colors.grey),
              ),
              const SizedBox(height: 30),
              const CircularProgressIndicator(color: Colors.redAccent),
              const SizedBox(height: 10),
              const Text("Buscando señal...", style: TextStyle(fontStyle: FontStyle.italic)),
            ],
          ),
        ),
      ),
    );
  }
}