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

    /// validar equipo
    if (!casco && !botas && !pantalon && !chaleco) {

      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text("Debes revisar tu equipo antes de iniciar"),
        ),
      );

      return;
    }

    try {

      /// buscar el camión
      var snapshot = await FirebaseFirestore.instance
          .collection("camiones")
          .where("tipo", isEqualTo: widget.camion)
          .get();

      if (snapshot.docs.isEmpty) {

        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text("Camión no encontrado")),
        );

        return;
      }

      var camionDoc = snapshot.docs.first;

      bool ocupado = camionDoc["ocupado"] ?? false;

      /// si ya está ocupado
      if (ocupado) {

        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text("Este camión ya fue tomado por otro operador"),
          ),
        );

       Navigator.popUntil(context, (route) => route.isFirst);
        return;
      }

      /// guardar checklist
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

      /// marcar camión ocupado
      await camionDoc.reference.update({
        "ocupado": true,
        "operador": widget.nombreUsuario
      });

      /// guardar jornada activa
      await FirebaseFirestore.instance
          .collection("usuarios")
          .doc(widget.nombreUsuario)
          .set({

        "jornada_activa": true,
        "camion_actual": widget.camion

      }, SetOptions(merge: true));

      /// mensaje
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text("Checklist guardado")),
      );

      /// ir a jornada
      Navigator.pushReplacement(
        context,
        MaterialPageRoute(
          builder: (_) => JornadaScreen(
            operador: widget.nombreUsuario,
            camion: widget.camion,
          ),
        ),
      );

    } catch (e) {

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text("Error: $e")),
      );

    }

  }

  @override
  Widget build(BuildContext context) {

    return Scaffold(

      appBar: AppBar(
        title: const Text("Equipo de seguridad personal"),
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
              "Tu camion hoy es: ${widget.camion}",
              style: const TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.bold
              ),
            ),

            const SizedBox(height: 20),

            const Text(
              "Antes de iniciar revisa tu equipo de seguridad personal",
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