import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';

class UsuariosScreen extends StatefulWidget {
  const UsuariosScreen({super.key});

  @override
  State<UsuariosScreen> createState() => _UsuariosScreenState();
}

class _UsuariosScreenState extends State<UsuariosScreen> {
  String filtroRol = "operador";

  // --- MÉTODOS CRUD ---

  void eliminarUsuario(String uid) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text("¿Eliminar usuario?"),
        content: const Text("Esta acción no se puede deshacer."),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context), child: const Text("Cancelar")),
          TextButton(
            onPressed: () {
              FirebaseFirestore.instance.collection("usuarios").doc(uid).delete();
              Navigator.pop(context);
            },
            child: const Text("Eliminar", style: TextStyle(color: Colors.red)),
          ),
        ],
      ),
    );
  }

  void mostrarFormulario({String? uid, Map<String, dynamic>? data}) {
    final bool esEdicion = uid != null;
    
    final nombre = TextEditingController(text: esEdicion ? data!["nombre"] : "");
    final apellidoP = TextEditingController(text: esEdicion ? data!["apellido_paterno"] : "");
    final apellidoM = TextEditingController(text: esEdicion ? data!["apellido_materno"] : "");
    final email = TextEditingController(text: esEdicion ? data!["email"] : "");
    final telefono = TextEditingController(text: esEdicion ? data!["telefono"] : "");
    final curp = TextEditingController(text: esEdicion ? data!["curp"] : "");
    final direccion = TextEditingController(text: esEdicion ? data!["direccion"] : "");
    
    // Campos exclusivos de operador
    final rfc = TextEditingController(text: esEdicion ? data!["rfc"] : "");
    final tipoLicencia = TextEditingController(text: esEdicion ? data!["tipo_licencia"] : "");

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(25))),
      builder: (context) => Padding(
        padding: EdgeInsets.only(
          bottom: MediaQuery.of(context).viewInsets.bottom,
          top: 20, left: 20, right: 20
        ),
        child: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(
                esEdicion ? "Editar Usuario" : "Nuevo ${filtroRol.toUpperCase()}",
                style: const TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
              ),
              const SizedBox(height: 20),
              _buildTextField(nombre, "Nombre", Icons.person),
              Row(
                children: [
                  Expanded(child: _buildTextField(apellidoP, "Ap. Paterno", Icons.person_outline)),
                  const SizedBox(width: 10),
                  Expanded(child: _buildTextField(apellidoM, "Ap. Materno", Icons.person_outline)),
                ],
              ),
              _buildTextField(email, "Correo Electrónico", Icons.email, keyboard: TextInputType.emailAddress),
              _buildTextField(telefono, "Teléfono", Icons.phone, keyboard: TextInputType.phone),
              _buildTextField(curp, "CURP", Icons.badge),
              _buildTextField(direccion, "Dirección", Icons.home),
              
              if (filtroRol == "operador") ...[
                const Divider(),
                const Text("Datos de Licencia", style: TextStyle(fontWeight: FontWeight.bold, color: Colors.grey)),
                _buildTextField(rfc, "RFC", Icons.article),
                _buildTextField(tipoLicencia, "Tipo de Licencia", Icons.drive_eta),
              ],
              
              const SizedBox(height: 20),
              SizedBox(
                width: double.infinity,
                height: 50,
                child: ElevatedButton(
                  style: ElevatedButton.styleFrom(
                    backgroundColor: const Color.fromARGB(255, 76, 94, 175),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(15))
                  ),
                  onPressed: () async {
                    Map<String, dynamic> datos = {
                      "nombre": nombre.text,
                      "apellido_paterno": apellidoP.text,
                      "apellido_materno": apellidoM.text,
                      "email": email.text,
                      "telefono": telefono.text,
                      "curp": curp.text,
                      "direccion": direccion.text,
                      "rol": filtroRol,
                      "activo": esEdicion ? data!["activo"] : true,
                    };

                    if (filtroRol == "operador") {
                      datos.addAll({"rfc": rfc.text, "tipo_licencia": tipoLicencia.text});
                    }

                    if (esEdicion) {
                      await FirebaseFirestore.instance.collection("usuarios").doc(uid).update(datos);
                    } else {
                      await FirebaseFirestore.instance.collection("usuarios").add(datos);
                    }
                    Navigator.pop(context);
                  },
                  child: Text(esEdicion ? "Actualizar" : "Crear Usuario", style: const TextStyle(color: Colors.white)),
                ),
              ),
              const SizedBox(height: 20),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildTextField(TextEditingController controller, String label, IconData icon, {TextInputType keyboard = TextInputType.text}) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: TextField(
        controller: controller,
        keyboardType: keyboard,
        decoration: InputDecoration(
          labelText: label,
          prefixIcon: Icon(icon, size: 20),
          border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
          contentPadding: const EdgeInsets.symmetric(horizontal: 15),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF5F7FB),
      appBar: AppBar(
        title: const Text("Gestión de Usuarios", style: TextStyle(fontWeight: FontWeight.bold)),
        backgroundColor: const Color.fromARGB(255, 76, 94, 175),
        foregroundColor: Colors.white,
        elevation: 0,
      ),
      floatingActionButton: FloatingActionButton.extended(
        backgroundColor: const Color.fromARGB(255, 76, 94, 175),
        onPressed: () => mostrarFormulario(),
        icon: const Icon(Icons.add, color: Colors.white),
        label: const Text("Nuevo", style: TextStyle(color: Colors.white)),
      ),
      body: Column(
        children: [
          // Selector de Rol Estilizado
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 10),
            color: Colors.white,
            child: Row(
              children: [
                const Text("Mostrar:", style: TextStyle(fontWeight: FontWeight.bold)),
                const SizedBox(width: 15),
                Expanded(
                  child: SegmentedButton<String>(
                    segments: const [
                      ButtonSegment(value: "operador", label: Text("Operadores"), icon: Icon(Icons.drive_eta)),
                      ButtonSegment(value: "trabajador", label: Text("Trabajadores"), icon: Icon(Icons.engineering)),
                    ],
                    selected: {filtroRol},
                    onSelectionChanged: (val) => setState(() => filtroRol = val.first),
                    style: SegmentedButton.styleFrom(
                      selectedBackgroundColor: const Color.fromARGB(255, 76, 94, 175),
                      selectedForegroundColor: Colors.white,
                    ),
                  ),
                ),
              ],
            ),
          ),

          Expanded(
            child: StreamBuilder<QuerySnapshot>(
              stream: FirebaseFirestore.instance
                  .collection("usuarios")
                  .where("rol", isEqualTo: filtroRol)
                  .snapshots(),
              builder: (context, snapshot) {
                if (!snapshot.hasData) return const Center(child: CircularProgressIndicator());
                
                final usuarios = snapshot.data!.docs;
                if (usuarios.isEmpty) return const Center(child: Text("No hay registros disponibles"));

                return ListView.builder(
                  padding: const EdgeInsets.all(12),
                  itemCount: usuarios.length,
                  itemBuilder: (context, index) {
                    final doc = usuarios[index];
                    final data = doc.data() as Map<String, dynamic>;
                    
                    return Card(
                      elevation: 0,
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(15),
                        side: BorderSide(color: Colors.grey.withOpacity(0.2))
                      ),
                      margin: const EdgeInsets.only(bottom: 10),
                      child: ListTile(
                        contentPadding: const EdgeInsets.symmetric(horizontal: 15, vertical: 8),
                        leading: CircleAvatar(
                          backgroundColor: const Color.fromARGB(255, 76, 94, 175).withOpacity(0.1),
                          child: Text(data["nombre"][0].toUpperCase(), 
                            style: const TextStyle(color: Color.fromARGB(255, 76, 94, 175), fontWeight: FontWeight.bold)),
                        ),
                        title: Text("${data["nombre"]} ${data["apellido_paterno"]}", 
                          style: const TextStyle(fontWeight: FontWeight.bold)),
                        subtitle: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(data["email"] ?? "", style: const TextStyle(fontSize: 12)),
                            const SizedBox(height: 4),
                            Text("📞 ${data["telefono"]}", style: const TextStyle(fontSize: 12)),
                          ],
                        ),
                        trailing: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            IconButton(
                              icon: const Icon(Icons.edit_outlined, color: Colors.blue),
                              onPressed: () => mostrarFormulario(uid: doc.id, data: data),
                            ),
                            IconButton(
                              icon: const Icon(Icons.delete_outline, color: Colors.red),
                              onPressed: () => eliminarUsuario(doc.id),
                            ),
                          ],
                        ),
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