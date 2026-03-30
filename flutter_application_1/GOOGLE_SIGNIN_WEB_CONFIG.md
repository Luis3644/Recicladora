# Configuración Google Sign-In para Web

## 🔴 PASOS OBLIGATORIOS:

### 1. Crear OAuth 2.0 Client ID en Google Cloud Console

1. Ve a: https://console.cloud.google.com/
2. Selecciona tu proyecto
3. Ve a **APIs & Services → Credentials**
4. Haz click en **+ CREATE CREDENTIALS**
5. Selecciona **OAuth 2.0 Client ID**
6. Elige **Web application**
7. Nombra como: "Recicladora Guadalajara Web"

### 2. Configurar URLs permitidas

**Authorized JavaScript origins:**
```
http://localhost:5000
http://localhost:8000
http://localhost
```

**Authorized redirect URIs:**
```
http://localhost:5000/
http://localhost:8000/
http://localhost/
```

> 📌 Usa el puerto donde ejecutarás `flutter run -d chrome`

### 3. Copiar el Client ID

Cuando crees la credencial, verás un popup con:
- **Client ID** → Guárdalo
- **Client Secret** → Guárdalo (solo para respaldo)

### 4. OPCIONAL - Si deseas pasar el Client ID programáticamente

En `lib/screens/login_screen.dart`, en el método `loginConGoogle()`, antes de `_googleSignIn.signIn()`:

```dart
// Reemplaza con tu Client ID de OAuth
_googleSignIn = GoogleSignIn(
  clientId: 'TU_OAUTH_CLIENT_ID.apps.googleusercontent.com', // Reemplaza aquí
  scopes: ['email', 'profile'],
);
```

## ✅ Para probar en Chrome local:

```bash
# Terminal 1: Ejecuta Flutter web
flutter run -d chrome

# La app debería abrirse en: http://localhost:PUERTO
```

## 🐛 Si sigue sin funcionar:

1. **Abre la consola del navegador** (F12)
2. Verifica los mensajes de error
3. Asegúrate que el dominio coincida exactamente (http vs https, localhost vs 127.0.0.1)
4. Limpia el caché del navegador (Ctrl+Shift+Delete)

## 📦 Firestore check

La colección `usuarios` debe existir con al menos un documento:
```json
{
  "uid": "google-user-id",
  "email": "usuario@gmail.com",
  "rol": "admin|operador|trabajador",
  "nombre": "Nombre Usuario"
}
```
