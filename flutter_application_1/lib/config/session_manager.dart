import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:shared_preferences/shared_preferences.dart';

class SessionData {
  final String rol;
  final String nombre;
  final String usuarioDocId;
  final String dispositivoId;

  const SessionData({
    required this.rol,
    required this.nombre,
    required this.usuarioDocId,
    required this.dispositivoId,
  });
}

class SessionManager {
  static const String _keySesionActiva = 'sesion_activa';
  static const String _keyRol = 'sesion_rol';
  static const String _keyNombre = 'sesion_nombre';
  static const String _keyUsuarioDocId = 'sesion_usuario_doc_id';
  static const String _keyDispositivoId = 'sesion_dispositivo_id';

  static Future<void> guardarSesion({
    required String rol,
    required String nombre,
    required String usuarioDocId,
    required String dispositivoId,
  }) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool(_keySesionActiva, true);
    await prefs.setString(_keyRol, rol);
    await prefs.setString(_keyNombre, nombre);
    await prefs.setString(_keyUsuarioDocId, usuarioDocId);
    await prefs.setString(_keyDispositivoId, dispositivoId);
    // Registrar sesión en Firestore (colección de sesiones por usuario)
    try {
      final ref = FirebaseFirestore.instance
          .collection('usuarios')
          .doc(usuarioDocId)
          .collection('sesiones')
          .doc(dispositivoId);

      await ref.set({
        'dispositivo_id': dispositivoId,
        'dispositivo_nombre': dispositivoId,
        'inicio': FieldValue.serverTimestamp(),
        'last_active': FieldValue.serverTimestamp(),
      }, SetOptions(merge: true));
    } catch (_) {
      // no interrumpir el flujo si falla el registro en Firestore
    }
  }

  static Future<List<Map<String, dynamic>>> listarSesionesUsuario(
      String usuarioDocId) async {
    try {
      final snap = await FirebaseFirestore.instance
          .collection('usuarios')
          .doc(usuarioDocId)
          .collection('sesiones')
          .orderBy('inicio', descending: true)
          .limit(10)
          .get();

      return snap.docs.map((d) {
        final data = d.data();
        return {
          'id': d.id,
          'dispositivo_id': data['dispositivo_id'] ?? d.id,
          'dispositivo_nombre': data['dispositivo_nombre'] ?? d.id,
          'inicio': data['inicio'],
          'last_active': data['last_active'],
        };
      }).toList();
    } catch (_) {
      return [];
    }
  }

  static Future<void> cerrarSesionRemota(
      {required String usuarioDocId, required String dispositivoId}) async {
    try {
      final ref = FirebaseFirestore.instance
          .collection('usuarios')
          .doc(usuarioDocId)
          .collection('sesiones')
          .doc(dispositivoId);

      await ref.delete();
    } catch (_) {
      // ignore
    }
  }

  static Future<void> guardarSesionDesdePerfil(
    Map<String, dynamic> perfil,
  ) async {
    final rol = perfil['rol']?.toString() ?? '';
    final nombre = perfil['nombre']?.toString() ?? '';
    final usuarioDocId = perfil['usuario_doc_id']?.toString() ?? '';
    final dispositivoId = perfil['dispositivo_id']?.toString() ?? '';

    if (rol.isEmpty || usuarioDocId.isEmpty || dispositivoId.isEmpty) return;
    await guardarSesion(
      rol: rol,
      nombre: nombre,
      usuarioDocId: usuarioDocId,
      dispositivoId: dispositivoId,
    );
  }

  static Future<SessionData?> obtenerSesion() async {
    final prefs = await SharedPreferences.getInstance();
    final activa = prefs.getBool(_keySesionActiva) ?? false;

    if (!activa) return null;

    final rol = prefs.getString(_keyRol) ?? '';
    final nombre = prefs.getString(_keyNombre) ?? '';
    final usuarioDocId = prefs.getString(_keyUsuarioDocId) ?? '';
    final dispositivoId = prefs.getString(_keyDispositivoId) ?? '';

    if (rol.isEmpty || usuarioDocId.isEmpty || dispositivoId.isEmpty) {
      return null;
    }

    return SessionData(
      rol: rol,
      nombre: nombre,
      usuarioDocId: usuarioDocId,
      dispositivoId: dispositivoId,
    );
  }

  static Future<void> limpiarSesionRemota() async {
    final sesion = await obtenerSesion();
    if (sesion == null) return;
    final usuarioRef = FirebaseFirestore.instance.collection('usuarios').doc(sesion.usuarioDocId);
    await usuarioRef.set({
      'sesion_activa': false,
      'sesion_dispositivo_id': '',
      'sesion_dispositivo_nombre': '',
      'sesion_ultima_salida': FieldValue.serverTimestamp(),
    }, SetOptions(merge: true));

    try {
      await usuarioRef.collection('sesiones').doc(sesion.dispositivoId).delete();
    } catch (_) {}
  }

  static Future<void> limpiarSesion() async {
    final prefs = await SharedPreferences.getInstance();
    final sesion = await obtenerSesion();
    if (sesion != null) {
      try {
        await FirebaseFirestore.instance
            .collection('usuarios')
            .doc(sesion.usuarioDocId)
            .collection('sesiones')
            .doc(sesion.dispositivoId)
            .delete();
      } catch (_) {}
    }

    await prefs.remove(_keySesionActiva);
    await prefs.remove(_keyRol);
    await prefs.remove(_keyNombre);
    await prefs.remove(_keyUsuarioDocId);
    await prefs.remove(_keyDispositivoId);
  }
}