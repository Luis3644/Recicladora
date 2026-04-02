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

    await FirebaseFirestore.instance
        .collection('usuarios')
        .doc(sesion.usuarioDocId)
        .set({
          'sesion_activa': false,
          'sesion_dispositivo_id': '',
          'sesion_dispositivo_nombre': '',
          'sesion_ultima_salida': FieldValue.serverTimestamp(),
        }, SetOptions(merge: true));
  }

  static Future<void> limpiarSesion() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove(_keySesionActiva);
    await prefs.remove(_keyRol);
    await prefs.remove(_keyNombre);
    await prefs.remove(_keyUsuarioDocId);
    await prefs.remove(_keyDispositivoId);
  }
}