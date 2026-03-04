import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';

class UsuariosScreen extends StatefulWidget {
  const UsuariosScreen({super.key});

  @override
  State<UsuariosScreen> createState() => _UsuariosScreenState();
}

class _UsuariosScreenState extends State<UsuariosScreen> {

  String filtroRol = "operador";

  void eliminarUsuario(String uid) {
    FirebaseFirestore.instance
        .collection("usuarios")
        .doc(uid)
        .delete();
  }

  void cambiarRol(String uid, String nuevoRol) {
    FirebaseFirestore.instance
        .collection("usuarios")
        .doc(uid)
        .update({"rol": nuevoRol});
  }

  void editarUsuario(String uid, Map<String, dynamic> data) {

  String rolActual = data["rol"] ?? "";

  TextEditingController nombre =
      TextEditingController(text: data["nombre"] ?? "");

  TextEditingController apellidoPaterno =
      TextEditingController(text: data["apellido_paterno"] ?? "");

  TextEditingController apellidoMaterno =
      TextEditingController(text: data["apellido_materno"] ?? "");

  TextEditingController curp =
      TextEditingController(text: data["curp"] ?? "");

  TextEditingController direccion =
      TextEditingController(text: data["direccion"] ?? "");

  TextEditingController email =
      TextEditingController(text: data["email"] ?? "");

  TextEditingController telefono =
      TextEditingController(text: data["telefono"] ?? "");

  TextEditingController rfc =
      TextEditingController(text: data["rfc"] ?? "");

  TextEditingController tipoLicencia =
      TextEditingController(text: data["tipo_licencia"] ?? "");

  TextEditingController vigenciaLicencia =
      TextEditingController(text: data["vigencia_licencia"] ?? "");

  showDialog(
    context: context,
    builder: (_) => AlertDialog(
      title: const Text("Editar Usuario"),
      content: SingleChildScrollView(
        child: Column(
          children: [

            TextField(controller: nombre, decoration: const InputDecoration(labelText: "Nombre")),
            TextField(controller: apellidoPaterno, decoration: const InputDecoration(labelText: "Apellido Paterno")),
            TextField(controller: apellidoMaterno, decoration: const InputDecoration(labelText: "Apellido Materno")),
            TextField(controller: curp, decoration: const InputDecoration(labelText: "CURP")),
            TextField(controller: direccion, decoration: const InputDecoration(labelText: "Dirección")),
            TextField(controller: email, decoration: const InputDecoration(labelText: "Email")),
            TextField(controller: telefono, decoration: const InputDecoration(labelText: "Teléfono")),

            /// 🔥 SOLO SI ES OPERADOR
            if (rolActual == "operador") ...[
              TextField(controller: rfc, decoration: const InputDecoration(labelText: "RFC")),
              TextField(controller: tipoLicencia, decoration: const InputDecoration(labelText: "Tipo Licencia")),
              TextField(controller: vigenciaLicencia, decoration: const InputDecoration(labelText: "Vigencia Licencia")),
            ],

          ],
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(context),
          child: const Text("Cancelar"),
        ),
        ElevatedButton(
          onPressed: () {

            Map<String, dynamic> datosActualizar = {
              "nombre": nombre.text,
              "apellido_paterno": apellidoPaterno.text,
              "apellido_materno": apellidoMaterno.text,
              "curp": curp.text,
              "direccion": direccion.text,
              "email": email.text,
              "telefono": telefono.text,
            };

            /// 🔥 SOLO ACTUALIZA ESTOS CAMPOS SI ES OPERADOR
            if (rolActual == "operador") {
              datosActualizar.addAll({
                "rfc": rfc.text,
                "tipo_licencia": tipoLicencia.text,
                "vigencia_licencia": vigenciaLicencia.text,
              });
            }

            FirebaseFirestore.instance
                .collection("usuarios")
                .doc(uid)
                .update(datosActualizar);

            Navigator.pop(context);
          },
          child: const Text("Guardar"),
        )
      ],
    ),
  );
}

  @override
  Widget build(BuildContext context) {

   Query query = FirebaseFirestore.instance
    .collection("usuarios")
    .where("rol", isEqualTo: filtroRol);

    return Scaffold(
      appBar: AppBar(
        title: const Text("Gestión de Usuarios"),
        backgroundColor: Colors.red,
      ),
      body: Column(
        children: [

         /// 🔥 FILTRO POR ROL
Padding(
  padding: const EdgeInsets.all(10),
  child: DropdownButton<String>(
    value: filtroRol,
    items: const [
      DropdownMenuItem(
        value: "operador",
        child: Text("Operadores"),
      ),
      DropdownMenuItem(
        value: "trabajador",
        child: Text("Trabajadores"),
      ),
    ],
    onChanged: (value) {
      setState(() {
        filtroRol = value!;
      });
    },
  ),
),




          /// 🔥 TABLA
          Expanded(
            child: StreamBuilder<QuerySnapshot>(
              stream: query.snapshots(),
              builder: (context, snapshot) {

                if (!snapshot.hasData) {
                  return const Center(child: CircularProgressIndicator());
                }

                final usuarios = snapshot.data!.docs;

                if (usuarios.isEmpty) {
                  return const Center(child: Text("No hay usuarios"));
                }

                return SingleChildScrollView(
                  scrollDirection: Axis.horizontal,
                  child: DataTable(
                    columns: const [
                      DataColumn(label: Text("Nombre")),
                      DataColumn(label: Text("Ap. Paterno")),
                      DataColumn(label: Text("Ap. Materno")),
                      DataColumn(label: Text("Email")),
                      DataColumn(label: Text("Teléfono")),
                      DataColumn(label: Text("Dirección")),
                      DataColumn(label: Text("CURP")),
                      DataColumn(label: Text("Rol")),
                      DataColumn(label: Text("Activo")),
                      DataColumn(label: Text("Acciones")),
                    ],
                    rows: usuarios.map((doc) {

                      final data =
                          doc.data() as Map<String, dynamic>;

                      return DataRow(cells: [

                        DataCell(Text(data["nombre"] ?? "")),
                        DataCell(Text(data["apellido_paterno"] ?? "")),
                        DataCell(Text(data["apellido_materno"] ?? "")),
                        DataCell(Text(data["email"] ?? "")),
                        DataCell(Text(data["telefono"] ?? "")),
                        DataCell(Text(data["direccion"] ?? "")),
                        DataCell(Text(data["curp"] ?? "")),

                        /// CAMBIAR ROL
                        DataCell(
                          DropdownButton<String>(
                            value: data["rol"],
                            items: const [
                              DropdownMenuItem(value: "admin", child: Text("Admin")),
                              DropdownMenuItem(value: "operador", child: Text("Operador")),
                              DropdownMenuItem(value: "trabajador", child: Text("Trabajador")),
                            ],
                            onChanged: (value) {
                              cambiarRol(doc.id, value!);
                            },
                          ),
                        ),

                        /// ACTIVO
                        DataCell(
                          Switch(
                            value: data["activo"] ?? false,
                            onChanged: (value) {
                              FirebaseFirestore.instance
                                  .collection("usuarios")
                                  .doc(doc.id)
                                  .update({"activo": value});
                            },
                          ),
                        ),

                        /// ACCIONES
                        DataCell(Row(
                          children: [
                            IconButton(
                              icon: const Icon(Icons.edit, color: Colors.blue),
                              onPressed: () {
                                editarUsuario(doc.id, data);
                              },
                            ),
                            IconButton(
                              icon: const Icon(Icons.delete, color: Colors.red),
                              onPressed: () {
                                eliminarUsuario(doc.id);
                              },
                            ),
                          ],
                        )),

                      ]);

                    }).toList(),
                  ),
                );
              },
            ),
          ),
        ],
      ),
    );
  }
}