import 'package:flutter/material.dart';
import 'checklist_screen.dart';
import 'widgets_conexion/connection_wrapper.dart';

class ConfirmarCamionScreen extends StatelessWidget {
  final String operador;
  final String camionId;
  final String tipo;
  final String foto;
  final String placas; // <--- AGREGAMOS ESTO

  const ConfirmarCamionScreen({
    super.key,
    required this.operador,
    required this.camionId,
    required this.tipo,
    required this.foto,
    required this.placas, // <--- REQUERIDO
  });

  @override
  Widget build(BuildContext context) {
    return ConnectionWrapper(
      child: Scaffold(
        appBar: AppBar(
          title: const Text("Confirmar camión"),
          automaticallyImplyLeading: false,
        ),
        body: Padding(
          padding: const EdgeInsets.all(20),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Image.network(
                foto,
                height: 200,
                errorBuilder: (context, error, stackTrace) {
                  return const Icon(Icons.local_shipping, size: 120);
                },
              ),
              const SizedBox(height: 20),
              Text(
                tipo,
                style: const TextStyle(fontSize: 26, fontWeight: FontWeight.bold),
              ),
              // --- MOSTRAR LAS PLACAS AQUÍ ---
              Text(
                "Placas: $placas",
                style: const TextStyle(fontSize: 20, color: Colors.blueGrey, fontWeight: FontWeight.w600),
              ),
              const SizedBox(height: 10),
              const Text(
                "¿Este es el camión que operarás hoy?",
                style: TextStyle(fontSize: 18),
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 40),
              ElevatedButton(
                style: ElevatedButton.styleFrom(
                  backgroundColor: Colors.green,
                  minimumSize: const Size(double.infinity, 50),
                ),
                onPressed: () {
                  Navigator.push(
                    context,
                    MaterialPageRoute(
                      builder: (_) => ChecklistScreen(
                        nombreUsuario: operador,
                        camion: tipo,
                        placas: placas, // <--- PASAMOS LAS PLACAS AL CHECKLIST
                      ),
                    ),
                  );
                },
                child: const Text("Confirmar", style: TextStyle(color: Colors.white)),
              ),
              const SizedBox(height: 15),
              ElevatedButton(
                style: ElevatedButton.styleFrom(
                  backgroundColor: Colors.red,
                  minimumSize: const Size(double.infinity, 50),
                ),
                onPressed: () => Navigator.pop(context),
                child: const Text("Cancelar", style: TextStyle(color: Colors.white)),
              )
            ],
          ),
        ),
      ),
    );
  }
}