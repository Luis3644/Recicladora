import 'package:flutter/material.dart';
import 'checklist_screen.dart';

class ConfirmarCamionScreen extends StatelessWidget {

  final String operador;
  final String camionId;
  final String tipo;
  final String placas;
  final String foto;

  const ConfirmarCamionScreen({
    super.key,
    required this.operador,
    required this.camionId,
    required this.tipo,
    required this.placas,
    required this.foto,
  });

  @override
  Widget build(BuildContext context) {

    return Scaffold(

      appBar: AppBar(
        title: const Text("Confirmar camión"),
        automaticallyImplyLeading: false,
      ),

      body: Padding(
        padding: const EdgeInsets.all(20),

        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [

            /// FOTO DEL CAMION
            Image.network(
              foto,
              height: 200,
              errorBuilder: (context, error, stackTrace) {
                return const Icon(
                  Icons.local_shipping,
                  size: 120,
                );
              },
            ),

            const SizedBox(height: 20),

            Text(
              tipo,
              style: const TextStyle(
                fontSize: 26,
                fontWeight: FontWeight.bold,
              ),
            ),

            const SizedBox(height: 10),

            Text(
              "Placas: $placas",
              style: const TextStyle(fontSize: 20),
            ),

            const SizedBox(height: 40),

            const Text(
              "¿Este es el camión que operarás hoy?",
              style: TextStyle(fontSize: 18),
              textAlign: TextAlign.center,
            ),

            const SizedBox(height: 40),

            /// BOTON CONFIRMAR
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
                    ),
                  ),
                );

              },

              child: const Text("Confirmar"),
            ),

            const SizedBox(height: 15),

            /// BOTON CANCELAR
            ElevatedButton(

              style: ElevatedButton.styleFrom(
                backgroundColor: Colors.red,
                minimumSize: const Size(double.infinity, 50),
              ),

              onPressed: () {

                Navigator.pop(context);

              },

              child: const Text(" Cancelar"),
            )

          ],
        ),
      ),
    );
  }
}