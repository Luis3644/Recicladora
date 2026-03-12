import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'operador_screen.dart';

class JornadaScreen extends StatefulWidget {

  final String operador;
  final String camion;

  const JornadaScreen({
    super.key,
    required this.operador,
    required this.camion,
  });

  @override
  State<JornadaScreen> createState() => _JornadaScreenState();
}

class _JornadaScreenState extends State<JornadaScreen> {

  final TextEditingController toneladasController = TextEditingController();
  final TextEditingController gasolinaController = TextEditingController();

  Future<void> guardarRegistro() async {

    if (toneladasController.text.isEmpty || gasolinaController.text.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text("Completa todos los campos")),
      );
      return;
    }

    await FirebaseFirestore.instance.collection("jornadas").add({
      "operador": widget.operador,
      "camion": widget.camion,
      "toneladas": toneladasController.text,
      "gasolina": gasolinaController.text,
      "fecha": DateTime.now()
    });

    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text("Registro guardado")),
    );

    toneladasController.clear();
    gasolinaController.clear();
  }

  Future<void> finalizarJornada() async {

    /// liberar camion
    var snapshot = await FirebaseFirestore.instance
        .collection("camiones")
        .where("operador", isEqualTo: widget.operador)
        .get();

    for (var doc in snapshot.docs) {
      await doc.reference.update({
        "ocupado": false,
        "operador": ""
      });
    }

    /// cerrar jornada del operador
    await FirebaseFirestore.instance
        .collection("usuarios")
        .doc(widget.operador)
        .update({
      "jornada_activa": false,
      "camion_actual": ""
    });

    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text("Jornada finalizada")),
    );

    Navigator.pushAndRemoveUntil(
      context,
      MaterialPageRoute(
        builder: (_) => OperadorScreen(
          nombreUsuario: widget.operador,
        ),
      ),
      (route) => false,
    );
  }

  @override
  Widget build(BuildContext context) {

    return Scaffold(
      appBar: AppBar(
        title: const Text("Jornada activa"),
        backgroundColor: Colors.green,
      ),

      body: Padding(
        padding: const EdgeInsets.all(20),

        child: Column(
          children: [

            Text(
              "Operador: ${widget.operador}",
              style: const TextStyle(fontSize: 22),
            ),

            const SizedBox(height: 10),

            Text(
              "Camión: ${widget.camion}",
              style: const TextStyle(fontSize: 22),
            ),

            const SizedBox(height: 30),

            TextField(
              controller: toneladasController,
              keyboardType: TextInputType.number,
              decoration: const InputDecoration(
                labelText: "Toneladas cargadas",
                border: OutlineInputBorder(),
              ),
            ),

            const SizedBox(height: 20),

            TextField(
              controller: gasolinaController,
              keyboardType: TextInputType.number,
              decoration: const InputDecoration(
                labelText: "Gasolina usada",
                border: OutlineInputBorder(),
              ),
            ),

            const SizedBox(height: 30),

            ElevatedButton(
              onPressed: guardarRegistro,
              child: const Text("Guardar registro"),
            ),

            const SizedBox(height: 20),

            ElevatedButton(
              style: ElevatedButton.styleFrom(
                backgroundColor: Colors.red,
              ),
              onPressed: finalizarJornada,
              child: const Text("Finalizar jornada"),
            ),

          ],
        ),
      ),
    );
  }
}