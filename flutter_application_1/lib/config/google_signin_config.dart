/// Configuración de Google Sign-In para la aplicación
/// 
/// IMPORTANTE: Reemplaza 'YOUR_GOOGLE_CLIENT_ID' con tu Client ID de Google Cloud Console
/// 
/// Cómo obtenerlo:
/// 1. Ve a: https://console.cloud.google.com/
/// 2. Selecciona tu proyecto
/// 3. Ve a APIs & Services → Credentials
/// 4. Crea un nuevo OAuth 2.0 Client ID para aplicación Web
/// 5. Copia el Client ID y reemplázalo abajo

class GoogleSignInConfig {
  /// Client ID de Google OAuth 2.0 para Web
  /// Formato: xxxxx-xxxxx.apps.googleusercontent.com
  static const String googleClientId = 'YOUR_GOOGLE_CLIENT_ID';

  /// Scopes de Google Sign-In
  static const List<String> scopes = [
    'email',
    'profile',
  ];

  /// ¿Está configurado correctamente?
  static bool get isConfigured {
    return googleClientId != 'YOUR_GOOGLE_CLIENT_ID' &&
        googleClientId.contains('.apps.googleusercontent.com');
  }

  /// Mensaje de validación
  static String get validationMessage {
    if (!isConfigured) {
      return '''
❌ Google Sign-In NO está configurado.

Pasos:
1. Abre: lib/config/google_signin_config.dart
2. Reemplaza 'YOUR_GOOGLE_CLIENT_ID' con tu Client ID
3. El Client ID debe estar en Google Cloud Console

Obtenerlo:
→ https://console.cloud.google.com/
→ APIs & Services → Credentials
→ Create OAuth 2.0 Client ID (Web)
→ Copia el Client ID en este archivo
''';
    }
    return '✅ Google Sign-In está configurado correctamente.';
  }
}
