import 'package:shared_preferences/shared_preferences.dart';

class SessionData {
  final String rol;
  final String nombre;

  const SessionData({required this.rol, required this.nombre});
}

class SessionManager {
  static const String _keySesionActiva = 'sesion_activa';
  static const String _keyRol = 'sesion_rol';
  static const String _keyNombre = 'sesion_nombre';

  static Future<void> guardarSesion({
    required String rol,
    required String nombre,
  }) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool(_keySesionActiva, true);
    await prefs.setString(_keyRol, rol);
    await prefs.setString(_keyNombre, nombre);
  }

  static Future<void> guardarSesionDesdePerfil(
    Map<String, dynamic> perfil,
  ) async {
    final rol = perfil['rol']?.toString() ?? '';
    final nombre = perfil['nombre']?.toString() ?? '';

    if (rol.isEmpty) return;
    await guardarSesion(rol: rol, nombre: nombre);
  }

  static Future<SessionData?> obtenerSesion() async {
    final prefs = await SharedPreferences.getInstance();
    final activa = prefs.getBool(_keySesionActiva) ?? false;

    if (!activa) return null;

    final rol = prefs.getString(_keyRol) ?? '';
    final nombre = prefs.getString(_keyNombre) ?? '';

    if (rol.isEmpty) return null;

    return SessionData(rol: rol, nombre: nombre);
  }

  static Future<void> limpiarSesion() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove(_keySesionActiva);
    await prefs.remove(_keyRol);
    await prefs.remove(_keyNombre);
  }
}