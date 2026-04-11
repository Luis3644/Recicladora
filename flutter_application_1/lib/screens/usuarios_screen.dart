import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_core/firebase_core.dart';

class UsuariosScreen extends StatefulWidget {
  const UsuariosScreen({super.key});

  @override
  State<UsuariosScreen> createState() => _UsuariosScreenState();
}

class _UsuariosScreenState extends State<UsuariosScreen> {
  String filtroRol = "operador";

  Future<String> _crearUsuarioAuthDesdeAdmin({
    required String email,
    required String password,
  }) async {
    final appName = 'admin-create-${DateTime.now().microsecondsSinceEpoch}';
    FirebaseApp? appSecundaria;

    try {
      appSecundaria = await Firebase.initializeApp(
        name: appName,
        options: Firebase.app().options,
      );

      final authSecundaria = FirebaseAuth.instanceFor(app: appSecundaria);
      final cred = await authSecundaria.createUserWithEmailAndPassword(
        email: email,
        password: password,
      );

      final uid = cred.user?.uid;
      if (uid == null || uid.isEmpty) {
        throw FirebaseAuthException(
          code: 'internal-error',
          message: 'No se pudo obtener el UID del usuario creado.',
        );
      }

      return uid;
    } finally {
      if (appSecundaria != null) {
        try {
          await FirebaseAuth.instanceFor(app: appSecundaria).signOut();
        } catch (_) {}
        await appSecundaria.delete();
      }
    }
  }

  Future<void> _liberarSesionUsuario({
    required String uid,
    required String nombre,
    required bool sesionActiva,
  }) async {
    if (!sesionActiva) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('La cuenta de $nombre no tiene una sesión activa.'),
          backgroundColor: const Color(0xFF64748B),
        ),
      );
      return;
    }

    final confirmar = await _confirmarAccion(
      titulo: 'Liberar sesión activa',
      mensaje:
          'Se cerrará la sesión remota de $nombre para permitir iniciar en otro dispositivo. ¿Deseas continuar?',
      textoConfirmar: 'LIBERAR',
    );

    if (!confirmar) return;

    try {
      await FirebaseFirestore.instance.collection('usuarios').doc(uid).set({
        'sesion_activa': false,
        'sesion_dispositivo_id': '',
        'sesion_dispositivo_nombre': '',
        'sesion_ultima_salida': FieldValue.serverTimestamp(),
      }, SetOptions(merge: true));

      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Sesión liberada para $nombre.'),
          backgroundColor: const Color(0xFF16A34A),
        ),
      );
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('No se pudo liberar la sesión: $e'),
          backgroundColor: Colors.red,
        ),
      );
    }
  }

  Future<bool> _confirmarAccion({
    required String titulo,
    required String mensaje,
    String textoConfirmar = "CONFIRMAR",
  }) async {
    final result = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: Text(
          titulo,
          style: const TextStyle(
            fontWeight: FontWeight.w700,
            fontSize: 18,
            color: Colors.black87,
          ),
        ),
        content: Text(
          mensaje,
          style: TextStyle(color: Colors.grey[700], fontSize: 14, height: 1.5),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(dialogContext, false),
            child: const Text(
              "CANCELAR",
              style: TextStyle(
                color: Colors.grey,
                fontWeight: FontWeight.w600,
                fontSize: 13,
              ),
            ),
          ),
          ElevatedButton(
            style: ElevatedButton.styleFrom(
              backgroundColor: const Color(0xFF1D4ED8),
              foregroundColor: Colors.white,
              elevation: 2,
              padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 10),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(8),
              ),
            ),
            onPressed: () => Navigator.pop(dialogContext, true),
            child: Text(
              textoConfirmar,
              style: const TextStyle(
                color: Colors.white,
                fontWeight: FontWeight.w700,
                fontSize: 13,
              ),
            ),
          ),
        ],
      ),
    );

    return result ?? false;
  }

  // --- MÉTODOS CRUD ---

  void eliminarUsuario(String uid) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: Row(
          children: [
            const Icon(
              Icons.warning_amber_rounded,
              color: Colors.red,
              size: 24,
            ),
            const SizedBox(width: 12),
            const Text(
              "Confirmar eliminar",
              style: TextStyle(
                fontWeight: FontWeight.w700,
                fontSize: 18,
                color: Colors.black87,
              ),
            ),
          ],
        ),
        content: Text(
          "¿Estás seguro de que quieres eliminar este usuario? Esta acción no se puede deshacer.",
          style: TextStyle(color: Colors.grey[700], fontSize: 14, height: 1.5),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text(
              "CANCELAR",
              style: TextStyle(
                color: Colors.grey,
                fontWeight: FontWeight.w600,
                fontSize: 13,
              ),
            ),
          ),
          ElevatedButton(
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.red,
              foregroundColor: Colors.white,
              elevation: 2,
              padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 10),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(8),
              ),
            ),
            onPressed: () async {
              await FirebaseFirestore.instance
                  .collection("usuarios")
                  .doc(uid)
                  .set({
                    'activo': false,
                    'sesion_activa': false,
                    'sesion_dispositivo_id': '',
                    'sesion_dispositivo_nombre': '',
                    'fecha_baja': FieldValue.serverTimestamp(),
                  }, SetOptions(merge: true));
              Navigator.pop(context);
              ScaffoldMessenger.of(context).showSnackBar(
                const SnackBar(
                  content: Text("Usuario desactivado correctamente"),
                  backgroundColor: Colors.green,
                  duration: Duration(seconds: 2),
                ),
              );
            },
            child: const Text(
              "ELIMINAR",
              style: TextStyle(
                color: Colors.white,
                fontWeight: FontWeight.w700,
                fontSize: 13,
              ),
            ),
          ),
        ],
      ),
    );
  }

  void mostrarFormulario({String? uid, Map<String, dynamic>? data}) {
    final bool esEdicion = uid != null;

    final nombre = TextEditingController(
      text: esEdicion ? data!["nombre"] : "",
    );
    final apellidoP = TextEditingController(
      text: esEdicion ? data!["apellido_paterno"] : "",
    );
    final apellidoM = TextEditingController(
      text: esEdicion ? data!["apellido_materno"] : "",
    );
    final email = TextEditingController(text: esEdicion ? data!["email"] : "");
    final telefono = TextEditingController(
      text: esEdicion ? data!["telefono"] : "",
    );
    final curp = TextEditingController(text: esEdicion ? data!["curp"] : "");
    final direccion = TextEditingController(
      text: esEdicion ? data!["direccion"] : "",
    );
    final contrasenaNueva = TextEditingController();
    final rfc = TextEditingController(text: esEdicion ? data!["rfc"] : "");
    final tipoLicencia = TextEditingController(
      text: esEdicion ? data!["tipo_licencia"] : "",
    );

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (context) => Container(
        decoration: const BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.vertical(top: Radius.circular(30)),
        ),
        padding: EdgeInsets.only(
          bottom: MediaQuery.of(context).viewInsets.bottom + 24,
          top: 24,
          left: 24,
          right: 24,
        ),
        child: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              // --- BARRA DE ARRASTRE ---
              Container(
                width: 48,
                height: 4,
                decoration: BoxDecoration(
                  color: Colors.grey[300],
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
              const SizedBox(height: 24),

              // --- TÍTULO ---
              Text(
                esEdicion ? "Editar Usuario" : "Agregar Nuevo Usuario",
                style: const TextStyle(
                  fontSize: 22,
                  fontWeight: FontWeight.w800,
                  color: Color(0xFF1D4ED8),
                  letterSpacing: 0.4,
                ),
              ),
              const SizedBox(height: 24),

              // --- CAMPOS BÁSICOS ---
              _buildTextField(nombre, "Nombre", Icons.person),
              Row(
                children: [
                  Expanded(
                    child: _buildTextField(
                      apellidoP,
                      "Ap. Paterno",
                      Icons.person_outline,
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: _buildTextField(
                      apellidoM,
                      "Ap. Materno",
                      Icons.person_outline,
                    ),
                  ),
                ],
              ),
              _buildTextField(
                email,
                "Correo Electrónico",
                Icons.email,
                keyboard: TextInputType.emailAddress,
                readOnly: esEdicion,
              ),
              _buildTextField(
                telefono,
                "Teléfono",
                Icons.phone,
                keyboard: TextInputType.phone,
              ),
              _buildTextField(curp, "CURP", Icons.badge),
              if (!esEdicion)
                _buildNewPasswordField(contrasenaNueva, esEdicion),
              _buildTextField(direccion, "Dirección", Icons.home),

              // --- CAMPOS OPERADOR ---
              if (filtroRol == "operador") ...[
                const SizedBox(height: 24),
                Container(
                  padding: const EdgeInsets.all(16),
                  decoration: BoxDecoration(
                    color: const Color(0xFF1D4ED8).withValues(alpha: 0.05),
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(
                      color: const Color(0xFF1D4ED8).withValues(alpha: 0.2),
                    ),
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          Icon(
                            Icons.work_outline,
                            size: 20,
                            color: Colors.grey[600],
                          ),
                          const SizedBox(width: 8),
                          const Text(
                            "Información de Trabajo",
                            style: TextStyle(
                              fontWeight: FontWeight.w700,
                              fontSize: 14,
                              color: Colors.black87,
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 16),
                      _buildTextField(rfc, "RFC", Icons.article),
                      _buildTextField(
                        tipoLicencia,
                        "Tipo de Licencia",
                        Icons.drive_eta,
                      ),
                    ],
                  ),
                ),
              ],

              const SizedBox(height: 28),

              // --- BOTONES DE ACCIÓN ---
              Row(
                children: [
                  Expanded(
                    child: OutlinedButton(
                      style: OutlinedButton.styleFrom(
                        padding: const EdgeInsets.symmetric(vertical: 14),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(12),
                        ),
                        side: const BorderSide(color: Colors.grey, width: 1.2),
                      ),
                      onPressed: () => Navigator.pop(context),
                      child: const Text(
                        "CANCELAR",
                        style: TextStyle(
                          color: Colors.grey,
                          fontWeight: FontWeight.w700,
                          fontSize: 14,
                          letterSpacing: 0.5,
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: ElevatedButton(
                      style: ElevatedButton.styleFrom(
                        backgroundColor: const Color(0xFF1D4ED8),
                        padding: const EdgeInsets.symmetric(vertical: 14),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(12),
                        ),
                        elevation: 4,
                        shadowColor: const Color(
                          0xFF1D4ED8,
                        ).withValues(alpha: 0.4),
                      ),
                      onPressed: () async {
                        // --- VALIDACIÓN DE CAMPOS VACÍOS ---
                        List<String> camposFaltantes = [];

                        // Validar campos básicos
                        if (nombre.text.trim().isEmpty)
                          camposFaltantes.add("Nombre");
                        if (apellidoP.text.trim().isEmpty)
                          camposFaltantes.add("Apellido Paterno");
                        if (apellidoM.text.trim().isEmpty)
                          camposFaltantes.add("Apellido Materno");
                        if (email.text.trim().isEmpty)
                          camposFaltantes.add("Email");
                        if (telefono.text.trim().isEmpty)
                          camposFaltantes.add("Teléfono");
                        if (curp.text.trim().isEmpty)
                          camposFaltantes.add("CURP");
                        if (direccion.text.trim().isEmpty)
                          camposFaltantes.add("Dirección");

                        // Validar contraseña solo en creación
                        if (!esEdicion && contrasenaNueva.text.trim().isEmpty) {
                          camposFaltantes.add("Contraseña");
                        }

                        // Validar campos del operador
                        if (filtroRol == "operador") {
                          if (rfc.text.trim().isEmpty)
                            camposFaltantes.add("RFC");
                          if (tipoLicencia.text.trim().isEmpty)
                            camposFaltantes.add("Tipo de Licencia");
                        }

                        if (camposFaltantes.isNotEmpty) {
                          ScaffoldMessenger.of(context).showSnackBar(
                            SnackBar(
                              content: Text(
                                "Campos faltantes: ${camposFaltantes.join(', ')}",
                              ),
                              backgroundColor: Colors.red,
                              duration: const Duration(seconds: 4),
                            ),
                          );
                          return;
                        }

                        final confirmarGuardado = await _confirmarAccion(
                          titulo: esEdicion
                              ? "Confirmar cambios"
                              : "Confirmar registro",
                          mensaje: esEdicion
                              ? "¿Seguro que deseas guardar los cambios de este usuario?"
                              : "¿Seguro que deseas agregar este usuario?",
                          textoConfirmar: esEdicion ? "GUARDAR" : "AGREGAR",
                        );

                        if (!confirmarGuardado) return;

                        try {
                          final emailNormalizado = email.text
                              .trim()
                              .toLowerCase();

                          Map<String, dynamic> datos = {
                            "nombre": nombre.text.trim(),
                            "apellido_paterno": apellidoP.text.trim(),
                            "apellido_materno": apellidoM.text.trim(),
                            "email": emailNormalizado,
                            "email_normalizado": emailNormalizado,
                            "telefono": telefono.text.trim(),
                            "curp": curp.text.trim(),
                            "direccion": direccion.text.trim(),
                            "rol": filtroRol,
                            "activo": esEdicion
                                ? (data!["activo"] ?? true)
                                : true,
                            "proveedor_auth": esEdicion
                                ? (data!["proveedor_auth"] ?? "password")
                                : "password",
                            "auth_providers": esEdicion
                                ? (data!["auth_providers"] ?? ["password"])
                                : ["password"],
                            "fecha_actualizacion": FieldValue.serverTimestamp(),
                          };

                          if (filtroRol == "operador") {
                            datos.addAll({
                              "rfc": rfc.text.trim(),
                              "tipo_licencia": tipoLicencia.text.trim(),
                            });
                          }

                          if (esEdicion) {
                            await FirebaseFirestore.instance
                                .collection("usuarios")
                                .doc(uid)
                                .update(datos);
                          } else {
                            final existeEmail = await FirebaseFirestore.instance
                                .collection('usuarios')
                                .where('email', isEqualTo: emailNormalizado)
                                .limit(1)
                                .get();

                            if (existeEmail.docs.isNotEmpty) {
                              throw Exception(
                                'Ya existe un perfil en Firestore con ese correo.',
                              );
                            }

                            final uidNuevo = await _crearUsuarioAuthDesdeAdmin(
                              email: emailNormalizado,
                              password: contrasenaNueva.text.trim(),
                            );

                            datos.addAll({
                              "uid": uidNuevo,
                              "fecha_registro": FieldValue.serverTimestamp(),
                              "sesion_activa": false,
                              "sesion_dispositivo_id": '',
                              "sesion_dispositivo_nombre": '',
                            });

                            await FirebaseFirestore.instance
                                .collection("usuarios")
                                .doc(uidNuevo)
                                .set(datos);
                          }

                          if (mounted) Navigator.pop(context);
                        } catch (e) {
                          String mensaje = "Error al guardar: $e";
                          if (e is FirebaseAuthException) {
                            if (e.code == 'email-already-in-use') {
                              mensaje =
                                  'Ya existe una cuenta en Authentication con ese correo.';
                            } else if (e.code == 'weak-password') {
                              mensaje =
                                  'La contraseña es débil. Usa al menos 6 caracteres.';
                            } else if (e.message != null &&
                                e.message!.isNotEmpty) {
                              mensaje = e.message!;
                            }
                          }

                          if (mounted) {
                            ScaffoldMessenger.of(context).showSnackBar(
                              SnackBar(
                                content: Text(mensaje),
                                backgroundColor: Colors.red,
                                duration: const Duration(seconds: 5),
                              ),
                            );
                          }
                        }
                      },
                      child: Text(
                        esEdicion ? "GUARDAR" : "AGREGAR",
                        style: const TextStyle(
                          color: Colors.white,
                          fontWeight: FontWeight.w700,
                          fontSize: 14,
                          letterSpacing: 0.5,
                        ),
                      ),
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

  Widget _buildTextField(
    TextEditingController controller,
    String label,
    IconData icon, {
    TextInputType keyboard = TextInputType.text,
    bool readOnly = false,
  }) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 14),
      child: TextField(
        controller: controller,
        keyboardType: keyboard,
        readOnly: readOnly,
        decoration: InputDecoration(
          labelText: label,
          labelStyle: const TextStyle(
            color: Colors.grey,
            fontWeight: FontWeight.w500,
            fontSize: 13,
          ),
          prefixIcon: Icon(icon, size: 20, color: const Color(0xFF1D4ED8)),
          border: OutlineInputBorder(
            borderRadius: BorderRadius.circular(12),
            borderSide: const BorderSide(color: Colors.grey, width: 1),
          ),
          enabledBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(12),
            borderSide: BorderSide(color: Colors.grey[300]!, width: 1),
          ),
          focusedBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(12),
            borderSide: const BorderSide(color: Color(0xFF1D4ED8), width: 2),
          ),
          filled: true,
          fillColor: Colors.grey[50],
          contentPadding: const EdgeInsets.symmetric(
            horizontal: 16,
            vertical: 14,
          ),
        ),
      ),
    );
  }

  Widget _buildNewPasswordField(
    TextEditingController controller,
    bool esEdicion,
  ) {
    bool mostrarContrasena = false;

    return StatefulBuilder(
      builder: (BuildContext context, StateSetter setPasswordState) {
        return Padding(
          padding: const EdgeInsets.only(bottom: 14),
          child: TextField(
            controller: controller,
            obscureText: !mostrarContrasena,
            decoration: InputDecoration(
              labelText: esEdicion ? "Nueva contraseña" : "Contraseña",
              labelStyle: const TextStyle(
                color: Colors.grey,
                fontWeight: FontWeight.w500,
                fontSize: 13,
              ),
              helperText: esEdicion
                  ? "Déjala vacía para mantener la contraseña actual."
                  : "Obligatoria solo para cuentas de correo y contraseña.",
              helperStyle: TextStyle(color: Colors.grey[500], fontSize: 12),
              prefixIcon: const Icon(
                Icons.lock_outline,
                size: 20,
                color: Color(0xFF1D4ED8),
              ),
              suffixIcon: IconButton(
                icon: Icon(
                  mostrarContrasena
                      ? Icons.visibility_rounded
                      : Icons.visibility_off_rounded,
                  size: 20,
                  color: const Color(0xFF1D4ED8),
                ),
                onPressed: () {
                  setPasswordState(() {
                    mostrarContrasena = !mostrarContrasena;
                  });
                },
              ),
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(12),
              ),
              enabledBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(12),
                borderSide: BorderSide(color: Colors.grey[300]!, width: 1),
              ),
              focusedBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(12),
                borderSide: const BorderSide(
                  color: Color(0xFF1D4ED8),
                  width: 2,
                ),
              ),
              filled: true,
              fillColor: Colors.grey[50],
              contentPadding: const EdgeInsets.symmetric(
                horizontal: 16,
                vertical: 14,
              ),
            ),
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
        title: const Text(
          "Gestión de Usuarios",
          style: TextStyle(
            fontWeight: FontWeight.bold,
            fontSize: 20,
            letterSpacing: 0.5,
          ),
        ),
        backgroundColor: const Color(0xFF1D4ED8),
        foregroundColor: Colors.white,
        elevation: 0,
        centerTitle: false,
      ),
      floatingActionButton: FloatingActionButton.extended(
        backgroundColor: const Color(0xFF1D4ED8),
        onPressed: () => mostrarFormulario(),
        icon: const Icon(Icons.person_add_alt_1, color: Colors.white),
        label: const Text(
          "Nuevo Usuario",
          style: TextStyle(color: Colors.white, fontWeight: FontWeight.w600),
        ),
      ),
      body: Column(
        children: [
          // --- FILTRO DE ROLES ---
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 18),
            color: Colors.white,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text(
                  "Filtrar por rol:",
                  style: TextStyle(
                    fontWeight: FontWeight.bold,
                    fontSize: 14,
                    color: Colors.grey,
                    letterSpacing: 0.3,
                  ),
                ),
                const SizedBox(height: 12),
                Row(
                  children: [
                    _roleButton("operador", "👷 Operadores"),
                    const SizedBox(width: 12),
                    _roleButton("trabajador", "👨‍💼 Trabajadores"),
                  ],
                ),
              ],
            ),
          ),

          // --- LISTA DE USUARIOS ---
          Expanded(
            child: StreamBuilder<QuerySnapshot>(
              stream: FirebaseFirestore.instance
                  .collection("usuarios")
                  .where("rol", isEqualTo: filtroRol)
                  .snapshots(),
              builder: (context, snapshot) {
                if (!snapshot.hasData)
                  return const Center(
                    child: CircularProgressIndicator(color: Color(0xFF1D4ED8)),
                  );

                final usuarios = snapshot.data!.docs.where((doc) {
                  final data = doc.data() as Map<String, dynamic>;
                  return data['activo'] != false;
                }).toList();

                if (usuarios.isEmpty) {
                  return Center(
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Icon(
                          Icons.group_off,
                          size: 80,
                          color: Colors.grey[300],
                        ),
                        const SizedBox(height: 16),
                        Text(
                          "No hay ${filtroRol}es registrados",
                          style: TextStyle(
                            color: Colors.grey[500],
                            fontSize: 16,
                            fontWeight: FontWeight.w500,
                          ),
                        ),
                      ],
                    ),
                  );
                }

                return ListView.builder(
                  padding: const EdgeInsets.all(16),
                  itemCount: usuarios.length,
                  itemBuilder: (context, index) {
                    final doc = usuarios[index];
                    final data = doc.data() as Map<String, dynamic>;
                    final sesionActiva = data['sesion_activa'] == true;
                    final sesionDispositivo =
                        data['sesion_dispositivo_nombre']?.toString() ?? '';

                    String nombre = data["nombre"] ?? "";
                    String inicial = nombre.isNotEmpty
                        ? nombre[0].toUpperCase()
                        : "U";

                    return Card(
                      elevation: 0,
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(16),
                        side: BorderSide(
                          color: Colors.grey.withValues(alpha: 0.12),
                        ),
                      ),
                      margin: const EdgeInsets.only(bottom: 12),
                      child: Container(
                        decoration: BoxDecoration(
                          borderRadius: BorderRadius.circular(16),
                          gradient: LinearGradient(
                            begin: Alignment.topLeft,
                            end: Alignment.bottomRight,
                            colors: [
                              Colors.white,
                              Colors.grey.withValues(alpha: 0.02),
                            ],
                          ),
                        ),
                        child: ListTile(
                          contentPadding: const EdgeInsets.symmetric(
                            horizontal: 16,
                            vertical: 12,
                          ),
                          leading: CircleAvatar(
                            radius: 28,
                            backgroundColor: const Color(
                              0xFF1D4ED8,
                            ).withValues(alpha: 0.1),
                            child: Text(
                              inicial,
                              style: const TextStyle(
                                color: Color(0xFF1D4ED8),
                                fontWeight: FontWeight.bold,
                                fontSize: 16,
                              ),
                            ),
                          ),
                          title: Text(
                            "${data["nombre"] ?? ""} ${data["apellido_paterno"] ?? ""}",
                            style: const TextStyle(
                              fontWeight: FontWeight.w700,
                              fontSize: 15,
                              color: Colors.black87,
                            ),
                          ),
                          subtitle: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              const SizedBox(height: 6),
                              Text(
                                "📞 ${data["telefono"] ?? 'S/T'}",
                                style: TextStyle(
                                  color: Colors.grey[600],
                                  fontSize: 13,
                                ),
                              ),
                              const SizedBox(height: 2),
                              Text(
                                "✉️ ${data["email"] ?? 'S/E'}",
                                style: TextStyle(
                                  color: Colors.grey[600],
                                  fontSize: 12,
                                ),
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                              ),
                              const SizedBox(height: 5),
                              Row(
                                children: [
                                  Icon(
                                    sesionActiva
                                        ? Icons.lock_person_rounded
                                        : Icons.lock_open_rounded,
                                    size: 14,
                                    color: sesionActiva
                                        ? const Color(0xFFEA580C)
                                        : const Color(0xFF16A34A),
                                  ),
                                  const SizedBox(width: 4),
                                  Expanded(
                                    child: Text(
                                      sesionActiva
                                          ? 'Sesión activa ${sesionDispositivo.isEmpty ? '' : 'en $sesionDispositivo'}'
                                          : 'Sin sesión activa',
                                      style: TextStyle(
                                        color: sesionActiva
                                            ? const Color(0xFF9A3412)
                                            : const Color(0xFF166534),
                                        fontSize: 11.5,
                                        fontWeight: FontWeight.w600,
                                      ),
                                      maxLines: 1,
                                      overflow: TextOverflow.ellipsis,
                                    ),
                                  ),
                                ],
                              ),
                            ],
                          ),
                          trailing: Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Container(
                                decoration: BoxDecoration(
                                  color: const Color(
                                    0xFFEA580C,
                                  ).withValues(alpha: 0.12),
                                  borderRadius: BorderRadius.circular(12),
                                ),
                                child: IconButton(
                                  icon: const Icon(
                                    Icons.lock_reset_rounded,
                                    color: Color(0xFFEA580C),
                                    size: 20,
                                  ),
                                  onPressed: () => _liberarSesionUsuario(
                                    uid: doc.id,
                                    nombre: nombre,
                                    sesionActiva: sesionActiva,
                                  ),
                                  tooltip: 'Liberar sesión activa',
                                ),
                              ),
                              const SizedBox(width: 8),
                              Container(
                                decoration: BoxDecoration(
                                  color: Colors.blue.withValues(alpha: 0.1),
                                  borderRadius: BorderRadius.circular(12),
                                ),
                                child: IconButton(
                                  icon: const Icon(
                                    Icons.edit_rounded,
                                    color: Color(0xFF1D4ED8),
                                    size: 20,
                                  ),
                                  onPressed: () async {
                                    final confirmarEdicion = await _confirmarAccion(
                                      titulo: "Editar usuario",
                                      mensaje:
                                          "¿Deseas editar la información de este usuario?",
                                      textoConfirmar: "EDITAR",
                                    );

                                    if (!confirmarEdicion) return;
                                    mostrarFormulario(uid: doc.id, data: data);
                                  },
                                  tooltip: "Editar usuario",
                                ),
                              ),
                              const SizedBox(width: 8),
                              Container(
                                decoration: BoxDecoration(
                                  color: Colors.red.withValues(alpha: 0.1),
                                  borderRadius: BorderRadius.circular(12),
                                ),
                                child: IconButton(
                                  icon: const Icon(
                                    Icons.delete_rounded,
                                    color: Colors.red,
                                    size: 20,
                                  ),
                                  onPressed: () => eliminarUsuario(doc.id),
                                  tooltip: "Eliminar usuario",
                                ),
                              ),
                            ],
                          ),
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
    return Expanded(
      child: GestureDetector(
        onTap: () => setState(() => filtroRol = value),
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 11),
          decoration: BoxDecoration(
            gradient: isSelected
                ? const LinearGradient(
                    colors: [Color(0xFF1D4ED8), Color(0xFF102A75)],
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                  )
                : null,
            color: isSelected ? null : Colors.grey[100],
            borderRadius: BorderRadius.circular(12),
            border: isSelected
                ? Border.all(color: const Color(0xFF1D4ED8), width: 0)
                : Border.all(color: Colors.grey[300]!, width: 1),
            boxShadow: isSelected
                ? [
                    BoxShadow(
                      color: const Color(0xFF1D4ED8).withValues(alpha: 0.3),
                      blurRadius: 8,
                      offset: const Offset(0, 2),
                    ),
                  ]
                : null,
          ),
          child: Text(
            label,
            style: TextStyle(
              color: isSelected ? Colors.white : Colors.grey[700],
              fontWeight: isSelected ? FontWeight.w700 : FontWeight.w600,
              fontSize: 13,
              letterSpacing: 0.3,
            ),
            textAlign: TextAlign.center,
          ),
        ),
      ),
    );
  }
}
