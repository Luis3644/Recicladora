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
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(15)),
        title: const Row(
          children: [
            Icon(Icons.warning_amber_rounded, color: Colors.red),
            SizedBox(width: 10),
            Text("Confirmar"),
          ],
        ),
        content: const Text("¿Estás seguro de que quieres eliminar este usuario? Esta acción no se puede deshacer."),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text("CANCELAR", style: TextStyle(color: Colors.grey)),
          ),
          ElevatedButton(
            style: ElevatedButton.styleFrom(backgroundColor: Colors.red),
            onPressed: () {
              FirebaseFirestore.instance.collection("usuarios").doc(uid).delete();
              Navigator.pop(context);
            },
            child: const Text("ELIMINAR", style: TextStyle(color: Colors.white)),
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
    final contrasena = TextEditingController();
    final rfc = TextEditingController(text: esEdicion ? data!["rfc"] : "");
    final tipoLicencia = TextEditingController(text: esEdicion ? data!["tipo_licencia"] : "");

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (context) => Container(
        decoration: const BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.vertical(top: Radius.circular(25)),
        ),
        padding: EdgeInsets.only(
          bottom: MediaQuery.of(context).viewInsets.bottom + 20,
          top: 20, left: 20, right: 20
        ),
        child: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Container(width: 50, height: 5, decoration: BoxDecoration(color: Colors.grey[300], borderRadius: BorderRadius.circular(10))),
              const SizedBox(height: 20),
              Text(
                esEdicion ? "Editar Usuario" : "Agregar Nuevo Usuario",
                style: const TextStyle(fontSize: 20, fontWeight: FontWeight.bold, color: Color.fromARGB(255, 76, 94, 175)),
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
              _buildPasswordField(contrasena, esEdicion),
              _buildTextField(direccion, "Dirección", Icons.home),
              
              if (filtroRol == "operador") ...[
                const Divider(height: 30),
                const Align(alignment: Alignment.centerLeft, child: Text("Información de Trabajo", style: TextStyle(fontWeight: FontWeight.bold, color: Colors.blueGrey))),
                const SizedBox(height: 10),
                _buildTextField(rfc, "RFC", Icons.article),
                _buildTextField(tipoLicencia, "Tipo de Licencia", Icons.drive_eta),
              ],
              
              const SizedBox(height: 20),
              Row(
                children: [
                  Expanded(
                    child: OutlinedButton(
                      style: OutlinedButton.styleFrom(
                        padding: const EdgeInsets.symmetric(vertical: 15),
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                      ),
                      onPressed: () => Navigator.pop(context),
                      child: const Text("CANCELAR", style: TextStyle(color: Colors.grey)),
                    ),
                  ),
                  const SizedBox(width: 15),
                  Expanded(
                    child: ElevatedButton(
                      style: ElevatedButton.styleFrom(
                        backgroundColor: const Color.fromARGB(255, 76, 94, 175),
                        padding: const EdgeInsets.symmetric(vertical: 15),
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                      ),
                      onPressed: () async {
                        // --- VALIDACIÓN DE CAMPOS VACÍOS ---
                        bool camposBasicosVacios = nombre.text.trim().isEmpty || 
                            apellidoP.text.trim().isEmpty || 
                            apellidoM.text.trim().isEmpty || 
                            email.text.trim().isEmpty || 
                            telefono.text.trim().isEmpty || 
                            curp.text.trim().isEmpty || 
                            direccion.text.trim().isEmpty;

                        bool contrasenaVacia = !esEdicion && contrasena.text.trim().isEmpty;

                        bool camposOperadorVacios = filtroRol == "operador" && 
                            (rfc.text.trim().isEmpty || tipoLicencia.text.trim().isEmpty);

                        if (camposBasicosVacios || camposOperadorVacios || contrasenaVacia) {
                          ScaffoldMessenger.of(context).showSnackBar(
                            const SnackBar(
                              content: Text("Por favor, llena todos los campos obligatorios"),
                              backgroundColor: Colors.red,
                            ),
                          );
                          return; // Detiene la ejecución si hay campos vacíos
                        }
                        
                        // Si pasa la validación, procedemos a guardar
                        Map<String, dynamic> datos = {
                          "nombre": nombre.text.trim(),
                          "apellido_paterno": apellidoP.text.trim(),
                          "apellido_materno": apellidoM.text.trim(),
                          "email": email.text.trim(),
                          "telefono": telefono.text.trim(),
                          "curp": curp.text.trim(),
                          "direccion": direccion.text.trim(),
                          "rol": filtroRol,
                          "activo": esEdicion ? (data!["activo"] ?? true) : true,
                        };

                        // Agregar contraseña solo si se proporciona
                        if (contrasena.text.trim().isNotEmpty) {
                          datos["contrasena"] = contrasena.text.trim();
                        }

                        if (filtroRol == "operador") {
                          datos.addAll({"rfc": rfc.text.trim(), "tipo_licencia": tipoLicencia.text.trim()});
                        }

                        if (esEdicion) {
                          await FirebaseFirestore.instance.collection("usuarios").doc(uid).update(datos);
                        } else {
                          await FirebaseFirestore.instance.collection("usuarios").add(datos);
                        }
                        
                        if (mounted) Navigator.pop(context);
                      },
                      child: Text(esEdicion ? "GUARDAR" : "AGREGAR", style: const TextStyle(color: Colors.white)),
                    ),
                  ),
                ],
              ),
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
          prefixIcon: Icon(icon, size: 20, color: const Color.fromARGB(255, 76, 94, 175)),
          border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
          filled: true,
          fillColor: Colors.grey[50],
          contentPadding: const EdgeInsets.symmetric(horizontal: 15),
        ),
      ),
    );
  }

  Widget _buildPasswordField(TextEditingController controller, bool esEdicion) {
    return StatefulBuilder(
      builder: (context, setState) {
        bool mostrarContrasena = false;
        return Padding(
          padding: const EdgeInsets.only(bottom: 12),
          child: StatefulBuilder(
            builder: (BuildContext context, StateSetter setPasswordState) {
              return TextField(
                controller: controller,
                obscureText: !mostrarContrasena,
                decoration: InputDecoration(
                  labelText: esEdicion ? "Contraseña (dejar en blanco para no cambiar)" : "Contraseña",
                  prefixIcon: const Icon(
                    Icons.lock_outline,
                    size: 20,
                    color: Color.fromARGB(255, 76, 94, 175),
                  ),
                  suffixIcon: IconButton(
                    icon: Icon(
                      mostrarContrasena ? Icons.visibility_rounded : Icons.visibility_off_rounded,
                      size: 20,
                      color: const Color.fromARGB(255, 76, 94, 175),
                    ),
                    onPressed: () {
                      setPasswordState(() {
                        mostrarContrasena = !mostrarContrasena;
                      });
                    },
                  ),
                  border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
                  filled: true,
                  fillColor: Colors.grey[50],
                  contentPadding: const EdgeInsets.symmetric(horizontal: 15),
                ),
              );
            },
          ),
        );
      },
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
        icon: const Icon(Icons.person_add_alt_1, color: Colors.white),
        label: const Text("Nuevo Usuario", style: TextStyle(color: Colors.white)),
      ),
      body: Column(
        children: [
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 15),
            color: Colors.white,
            child: Row(
              children: [
                const Text("Ver:", style: TextStyle(fontWeight: FontWeight.bold)),
                const SizedBox(width: 15),
                _roleButton("operador", "Operadores"),
                const SizedBox(width: 10),
                _roleButton("trabajador", "Trabajadores"),
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
                if (usuarios.isEmpty) {
                  return Center(child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Icon(Icons.group_off, size: 60, color: Colors.grey[300]),
                      Text("No hay ${filtroRol}es registrados", style: const TextStyle(color: Colors.grey)),
                    ],
                  ));
                }

                return ListView.builder(
                  padding: const EdgeInsets.all(12),
                  itemCount: usuarios.length,
                  itemBuilder: (context, index) {
                    final doc = usuarios[index];
                    final data = doc.data() as Map<String, dynamic>;
                    
                    String nombre = data["nombre"] ?? "";
                    String inicial = nombre.isNotEmpty ? nombre[0].toUpperCase() : "U";

                    return Card(
                      elevation: 0,
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(15), side: BorderSide(color: Colors.grey.withValues(alpha: 0.2))),
                      margin: const EdgeInsets.only(bottom: 10),
                      child: ListTile(
                        leading: CircleAvatar(
                          backgroundColor: const Color.fromARGB(255, 76, 94, 175).withValues(alpha: 0.1),
                          child: Text(inicial, style: const TextStyle(color: Color.fromARGB(255, 76, 94, 175))),
                        ),
                        title: Text("${data["nombre"] ?? ""} ${data["apellido_paterno"] ?? ""}", style: const TextStyle(fontWeight: FontWeight.bold)),
                        subtitle: Text("📞 ${data["telefono"] ?? 'S/T'}"),
                        trailing: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            IconButton(icon: const Icon(Icons.edit_outlined, color: Colors.blue), onPressed: () => mostrarFormulario(uid: doc.id, data: data)),
                            IconButton(icon: const Icon(Icons.delete_outline, color: Colors.red), onPressed: () => eliminarUsuario(doc.id)),
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

  Widget _roleButton(String value, String label) {
    bool isSelected = filtroRol == value;
    return GestureDetector(
      onTap: () => setState(() => filtroRol = value),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
        decoration: BoxDecoration(
          color: isSelected ? const Color.fromARGB(255, 76, 94, 175) : Colors.grey[200],
          borderRadius: BorderRadius.circular(20),
        ),
        child: Text(label, style: TextStyle(color: isSelected ? Colors.white : Colors.black54, fontWeight: FontWeight.bold, fontSize: 13)),
      ),
    );
  }
}