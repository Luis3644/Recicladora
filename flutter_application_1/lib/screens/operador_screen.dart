import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';

class OperadorScreen extends StatelessWidget {
  final String nombreUsuario;

  const OperadorScreen({super.key, required this.nombreUsuario});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text("Hola, $nombreUsuario"),
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
                  .snapshots(),

              builder: (context, snapshot) {

                if (!snapshot.hasData) {
                  return const Center(child: CircularProgressIndicator());
                }

                final camiones = snapshot.data!.docs;

                return ListView.builder(
                  itemCount: camiones.length,
                  itemBuilder: (context, index) {

                    final data = camiones[index].data() as Map<String, dynamic>;

                    return Card(
                      margin: const EdgeInsets.all(12),

                      child: ListTile(
                        contentPadding: const EdgeInsets.all(20),

                        leading: const Icon(
                          Icons.local_shipping,
                          size: 40,
                        ),

                        title: Text(
                          data["tipo"],
                          style: const TextStyle(
                            fontSize: 22,
                            fontWeight: FontWeight.bold,
                          ),
                        ),

                        subtitle: Text(
                          "Placas: ${data["placas"]}",
                          style: const TextStyle(fontSize: 18),
                        ),

                        onTap: () {

                          ScaffoldMessenger.of(context).showSnackBar(
                            SnackBar(
                              content: Text(
                                  "Seleccionaste ${data["tipo"]}"),
                            ),
                          );
                        },
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