import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'jornada_screen.dart';

class ChecklistScreen extends StatefulWidget {

  final String nombreUsuario;
  final String camion;

  const ChecklistScreen({
    super.key,
    required this.nombreUsuario,
    required this.camion
  });

  @override
  State<ChecklistScreen> createState() => _ChecklistScreenState();
}

class _ChecklistScreenState extends State<ChecklistScreen> {

  bool casco = false;
  bool botas = false;
  bool pantalon = false;
  bool chaleco = false;

  final TextEditingController reporteController = TextEditingController();

  Future<void> guardarChecklist() async {

    DateTime ahora = DateTime.now();

    /// Validar que al menos revisó equipo
    if (!casco && !botas && !pantalon && !chaleco) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text("Debes revisar tu equipo antes de iniciar"),
        ),
      );
      return;
    }

    await FirebaseFirestore.instance.collection("checklist").add({
      "operador": widget.nombreUsuario,
      "camion": widget.camion,
      "casco": casco,
      "botas": botas,
      "pantalon": pantalon,
      "chaleco": chaleco,
      "reporte": reporteController.text,
      "fecha": ahora,
      "hora": "${ahora.hour}:${ahora.minute}"
    });

    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text("Checklist guardado"))
    );

    /// Ir a jornada
    Navigator.pushReplacement(
      context,
      MaterialPageRoute(
        builder: (_) => JornadaScreen(
          operador: widget.nombreUsuario,
          camion: widget.camion,
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {

    return Scaffold(
      appBar: AppBar(
        title: const Text("Checklist de seguridad"),
        backgroundColor: Colors.green,
      ),

      body: Padding(
        padding: const EdgeInsets.all(20),

        child: Column(
          children: [

            Text(
              "Hola ${widget.nombreUsuario}",
              style: const TextStyle(
                fontSize: 22,
                fontWeight: FontWeight.bold
              ),
            ),

            const SizedBox(height: 10),

            Text(
              "Camión: ${widget.camion}",
              style: const TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.bold
              ),
            ),

            const SizedBox(height: 20),

            const Text(
              "Antes de iniciar revisa tu equipo",
              style: TextStyle(fontSize: 16),
            ),

            const SizedBox(height: 30),

            CheckboxListTile(
              title: const Text("Casco"),
              value: casco,
              onChanged: (value) {
                setState(() {
                  casco = value!;
                });
              },
            ),

            CheckboxListTile(
              title: const Text("Botas de seguridad"),
              value: botas,
              onChanged: (value) {
                setState(() {
                  botas = value!;
                });
              },
            ),

            CheckboxListTile(
              title: const Text("Pantalón de seguridad"),
              value: pantalon,
              onChanged: (value) {
                setState(() {
                  pantalon = value!;
                });
              },
            ),

            CheckboxListTile(
              title: const Text("Chaleco reflectante"),
              value: chaleco,
              onChanged: (value) {
                setState(() {
                  chaleco = value!;
                });
              },
            ),

            const SizedBox(height: 20),

            TextField(
              controller: reporteController,
              decoration: const InputDecoration(
                labelText: "Reportar problema (opcional)",
                border: OutlineInputBorder()
              ),
            ),

            const SizedBox(height: 25),

            ElevatedButton(
              onPressed: guardarChecklist,
              child: const Text("Iniciar jornada"),
            )

          ],
        ),
      ),
    );
  }
}