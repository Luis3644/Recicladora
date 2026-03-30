# 🔐 Configurración Google Sign-In - Guía Rápida

## ✅ Ya realizaste:
- ✅ Removido botón "Regístrate aquí" - solo admins pueden registrar
- ✅ Actualizado index.html con Google Sign SDK
- ✅ Creado archivo de configuración

## 🚀 PRÓXIMOS PASOS (3 pasos):

### **PASO 1: Obtener Cliente ID de Google**

1. **Abre Google Cloud Console:**
   ```
   https://console.cloud.google.com/
   ```

2. **Selecciona tu Proyecto** (el de Recicladora)

3. **Ve a: APIs & Services → Credentials**
   - Click en el icono de menú (☰) arriba a la izquierda
   - Busca "APIs & Services"  
   - Click "Credentials"

4. **Crea nuevo OAuth 2.0 Client ID:**
   - Click `+ CREATE CREDENTIALS`
   - Selecciona `OAuth 2.0 Client ID`
   - Tipo: `Web application`
   - Nombre: "Recicladora Guadalajara Web"
   - Click `CREATE`

### **PASO 2: Configurar localhost**

En la pantalla de credenciales, busca:
- **Authorized JavaScript origins** 
  - Agrega: `http://localhost:5000`
  - Agrega: `http://localhost:8000`

- **Authorized redirect URIs**
  - Agrega: `http://localhost:5000/`
  - Agrega: `http://localhost:8000/`

> Si usas otro PUERTO (mira en tu terminal cuando ejecutes Flutter), reemplaza


### **PASO 3: Copiar Client ID**

1. Cuando crees la credencial, aparecerá un modal con:
   ```
   Client ID: xxxxx-xxxxx.apps.googleusercontent.com
   Client Secret: xxxxxxxxxxxxx
   ```

2. **Copia el Client ID**

3. **Abre el archivo:**
   ```
   lib/config/google_signin_config.dart
   ```

4. **Reemplaza:** 
   ```dart
   // ANTES:
   static const String googleClientId = 'YOUR_GOOGLE_CLIENT_ID';

   // DESPUÉS:
   static const String googleClientId = '123456789-xxx.apps.googleusercontent.com';
   ```

---

## 🧪 Probar en Chrome

**En Terminal:**
```bash
cd c:\Users\ADR10\Recicladora\flutter_application_1
flutter run -d chrome
```

**Resultado esperado:**
1. Se abre Chrome con tu app
2. Ves los 2 botones de login
3. **Al hacer click en "Continuar con Google"** → Aparece la ventana de selección de cuentas (como en la imagen)
4. Seleccionas una cuenta
5. La app verifica que exista en Firestore (`usuarios` collection)
6. Te redirige al dashboard según tu rol

---

## 🐛 Si aparecen errores:

**En Chrome:**
1. Abre DevTools: `F12`
2. Ve a la pestaña `Console`
3. Mira qué error aparece
4. Verificaciones comunes:

| Error | Solución |
|-------|----------|
| "Not authorized to access this resource" | Client ID no está registrado. Revisa paso 3 |
| "Expected 'web' but got 'android'" | El Client ID es para Android, no web. Create uno nuevo de tipo Web |
| "Invalid origin" | El localhost no está autorizado en Google Cloud Console |
| "Could not find specified property" | Falta agregar el SDK de Google en index.html |

---

## 📋 Checklist final:

- [ ] Creaste OAuth 2.0 Client ID en Google Cloud Console
- [ ] El tipo es **"Web application"**
- [ ] Autorizaste `http://localhost:5000` y `http://localhost:8000`
- [ ] Copiaste el Client ID
- [ ] Pegaste el Client ID en `lib/config/google_signin_config.dart`
- [ ] Ejecutaste `flutter run -d chrome`
- [ ] Pruebas el botón de Google Sign-In

---

**¿Problemas aún?** Verifica la consola del navegador (F12) y comparte el error exacto.
