import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'checklist_screen.dart';
import 'jornada_screen.dart';
import 'confirmar_camion_screen.dart';

class OperadorScreen extends StatefulWidget {
  final String nombreUsuario;

  const OperadorScreen({super.key, required this.nombreUsuario});

  @override
  State<OperadorScreen> createState() => _OperadorScreenState();
}

class _OperadorScreenState extends State<OperadorScreen> {

  @override
  void initState() {
    super.initState();
    verificarJornada();
  }

  Future<void> verificarJornada() async {

    var doc = await FirebaseFirestore.instance
        .collection("usuarios")
        .doc(widget.nombreUsuario)
        .get();

    if (!doc.exists) return;

    bool jornadaActiva = doc.data()?["jornada_activa"] ?? false;

    if (jornadaActiva) {

      String camion = doc.data()?["camion_actual"] ?? "";

      WidgetsBinding.instance.addPostFrameCallback((_) {
        Navigator.pushReplacement(
          context,
          MaterialPageRoute(
            builder: (_) => JornadaScreen(
              operador: widget.nombreUsuario,
              camion: camion,
            ),
          ),
        );
      });

    }
  }

  Future<void> seleccionarCamion(String camionId, String tipoCamion) async {

    try {

      /// marcar camion ocupado
      await FirebaseFirestore.instance
          .collection("camiones")
          .doc(camionId)
          .update({
        "ocupado": true,
        "operador": widget.nombreUsuario
      });

      /// guardar jornada activa del usuario
      await FirebaseFirestore.instance
          .collection("usuarios")
          .doc(widget.nombreUsuario)
          .set({
        "jornada_activa": true,
        "camion_actual": tipoCamion
      }, SetOptions(merge: true));

      /// ir al checklist
      if (!mounted) return;

      Navigator.push(
        context,
        MaterialPageRoute(
          builder: (_) => ChecklistScreen(
            nombreUsuario: widget.nombreUsuario,
            camion: tipoCamion,
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
        title: Text("Hola, ${widget.nombreUsuario}"),
        backgroundColor: Colors.blue,
      ),

      body: Column(
        children: [

          const SizedBox(height: 20),

          const Text(
            "Selecciona el camión que operarás hoy",
            style: TextStyle(
              fontSize: 20,
              fontWeight: FontWeight.bold,
            ),
          ),

          const SizedBox(height: 20),

          Expanded(
            child: StreamBuilder<QuerySnapshot>(
              stream: FirebaseFirestore.instance
                  .collection("camiones")
                  .where("activo", isEqualTo: true)
                  .where("ocupado", isEqualTo: false)
                  .snapshots(),

              builder: (context, snapshot) {

                if (snapshot.connectionState == ConnectionState.waiting) {
                  return const Center(child: CircularProgressIndicator());
                }

                if (!snapshot.hasData || snapshot.data!.docs.isEmpty) {
                  return const Center(
                    child: Text(
                      "No hay camiones disponibles",
                      style: TextStyle(fontSize: 18),
                    ),
                  );
                }

                final camiones = snapshot.data!.docs;

                return ListView.builder(
                  itemCount: camiones.length,
                  itemBuilder: (context, index) {

                    final data =
                        camiones[index].data() as Map<String, dynamic>;

                    return Card(
                      margin: const EdgeInsets.all(12),

                      child: ListTile(
                        contentPadding: const EdgeInsets.all(20),

                        leading: const Icon(
                          Icons.local_shipping,
                          size: 40,
                        ),

                        title: Text(
                          data["tipo"] ?? "Camión",
                          style: const TextStyle(
                            fontSize: 22,
                            fontWeight: FontWeight.bold,
                          ),
                        ),

                        subtitle: Text(
                          "Placas: ${data["placas"] ?? ""}",
                          style: const TextStyle(fontSize: 18),
                        ),

                        onTap: () {

  Navigator.push(
    context,
    MaterialPageRoute(
      builder: (_) => ConfirmarCamionScreen(
        operador: widget.nombreUsuario,
        camionId: camiones[index].id,
        tipo: data["tipo"],
        placas: data["placas"],
        foto: data["foto"],
      ),
    ),
  );

}

                      ),
                    );

                  },
                );
              },
            ),
          ),
        ],
      ),
    );
  }
}