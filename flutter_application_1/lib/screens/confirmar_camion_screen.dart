import 'package:flutter/material.dart';
import 'checklist_screen.dart';
import 'widgets_conexion/connection_wrapper.dart';

class ConfirmarCamionScreen extends StatelessWidget {
  final String operador;
  final String camionId;
  final String tipo;
  final String foto; // Esta debe ser la URL REAL de Firebase Storage o una URL web válida
  final String placas;
  final String modelo; 

  const ConfirmarCamionScreen({
    super.key,
    required this.operador,
    required this.camionId,
    required this.tipo,
    required this.foto,
    required this.placas,
    required this.modelo, 
  });

  @override
  Widget build(BuildContext context) {
    return ConnectionWrapper(
      child: Scaffold(
        appBar: AppBar(
          title: const Text("Confirmar camión"),
          automaticallyImplyLeading: false,
          backgroundColor: const Color.fromARGB(255, 61, 91, 211), // Azul profesional
        ),
        body: SingleChildScrollView( // Añadido para evitar errores de espacio en pantallas chicas
          padding: const EdgeInsets.all(20),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              const SizedBox(height: 20),
              // --- CONTENEDOR DE LA IMAGEN REAL ---
              Container(
                decoration: BoxDecoration(
                  boxShadow: [
                    BoxShadow(
                      color: const Color.fromARGB(255, 0, 0, 0).withOpacity(0.2),
                      spreadRadius: 2,
                      blurRadius: 10,
                      offset: const Offset(0, 5),
                    ),
                  ],
                ),
                child: ClipRRect(
                  borderRadius: BorderRadius.circular(15),
                  child: Image.network(
                    foto, // <--- Aquí cargamos TU foto real
                    height: 220,
                    width: double.infinity,
                    fit: BoxFit.cover,
                    // MIENTRAS CARGA, MOSTRAR UN CIRCULO DE CARGA
                    loadingBuilder: (context, child, loadingProgress) {
                      if (loadingProgress == null) return child;
                      return Container(
                        height: 220,
                        color: Colors.grey[100],
                        child: const Center(
                          child: CircularProgressIndicator(color: Color(0xFF1E3A8A)),
                        ),
                      );
                    },
                    // SI HAY ERROR (URL MAL, SIN INTERNET), MOSTRAR ICONO
                    errorBuilder: (context, error, stackTrace) {
                      print("Error cargando imagen: $error"); // Para que lo veas en consola
                      return Container(
                        height: 220,
                        width: double.infinity,
                        color: Colors.grey[200],
                        child: Column(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: const [
                            Icon(Icons.broken_image, size: 80, color: Colors.grey),
                            SizedBox(height: 10),
                            Text("No se pudo cargar la imagen real", style: TextStyle(color: Colors.grey),)
                          ],
                        ),
                      );
                    },
                  ),
                ),
              ),
              const SizedBox(height: 30),
              
              // Tipo de Camión
              Text(
                tipo,
                style: const TextStyle(fontSize: 28, fontWeight: FontWeight.bold),
              ),
              
              const SizedBox(height: 15),

              // --- FILA DE MODELO Y PLACAS ---
              Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  _buildInfoBadge("Modelo: $modelo", Colors.grey[200]!, Colors.black87),
                  const SizedBox(width: 15),
                  _buildInfoBadge("Placas: $placas", const Color(0xFFDBEAFE), const Color(0xFF1E40AF)),
                ],
              ),

              const SizedBox(height: 40),
              
              const Text(
                "¿Este es el camión que operarás hoy?",
                style: TextStyle(fontSize: 18, color: Colors.black87),
                textAlign: TextAlign.center,
              ),
              
              const SizedBox(height: 50),

              // Botón Confirmar
              ElevatedButton(
                style: ElevatedButton.styleFrom(
                  backgroundColor: Colors.green,
                  foregroundColor: Colors.white,
                  minimumSize: const Size(double.infinity, 55),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                  elevation: 5,
                ),
                onPressed: () {
                  Navigator.push(
                    context,
                    MaterialPageRoute(
                      builder: (_) => ChecklistScreen(
                        nombreUsuario: operador,
                        camion: tipo,
                        placas: placas,
                      ),
                    ),
                  );
                },
                child: const Text(
                  "SI, ES CORRECTO", 
                  style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)
                ),
              ),
              
              const SizedBox(height: 20),

              // Botón Cancelar
              TextButton(
                onPressed: () => Navigator.pop(context),
                child: const Text(
                  "No, volver a seleccionar", 
                  style: TextStyle(color: Colors.red, fontSize: 16, fontWeight: FontWeight.w600)
                ),
              )
            ],
          ),
        ),
      ),
    );
  }

  // Widget auxiliar para las etiquetas de info
  Widget _buildInfoBadge(String text, Color bgColor, Color textColor) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
      decoration: BoxDecoration(
        color: bgColor,
        borderRadius: BorderRadius.circular(10),
      ),
      child: Text(
        text,
        style: TextStyle(fontSize: 16, color: textColor, fontWeight: FontWeight.bold),
      ),
    );
  }
}