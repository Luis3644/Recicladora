# 🚨 SOLUCIÓN RÁPIDA: Google Sign-In No Funciona

## El Problema:
```
ClientID not set. Either set it on a <meta name='google-signin-client_id' 
content='CLIENT_ID'/> tag, or pass clientId when initializing GoogleSignIn
```

**Solución:** Necesitas tu **Client ID de Google**

---

## ⚡ PASOS RÁPIDOS (5 minutos):

### **PASO 1: Obtener Client ID**

**En navegador:**
1. Ve a: https://console.cloud.google.com/
2. Selecciona tu proyecto (el de Recicladora)
3. **Menú ☰ (arriba izquierda) → Busca "Credentials"**
4. Click en **"Credentials"** bajo "APIs & Services"

### **PASO 2: Crear OAuth 2.0 para Web**

1. Click **+ CREATE CREDENTIALS** (azul, arriba)
2. Selecciona **OAuth 2.0 Client ID**
3. Si te pide, elige: **Application type → Web application**
4. Nombre (opcional): "Recicladora Web"
5. Click **CREATE**

### **PASO 3: Autorizar localhost**

En la pantalla de la credencial, busca:

**"Authorized JavaScript origins"** 
- Click **+ ADD URI**
- Pega: `http://localhost`
- Click **ADD URI** otra vez
- Pega: `http://localhost:5000`
- Click **SAVE**

### **PASO 4: Copiar Client ID**

Busca en esa pantalla:
```
Client ID: 123456789-abcdefg.apps.googleusercontent.com
```

**Copia SOLO el Client ID** (la parte antes de `.apps.`)

---

## 📝 PASO 5: Pegar el Client ID

**Opción A (Recomendado - Más simple):**

1. Abre: `web/index.html`
2. Busca esta línea (aprox línea 35):
   ```html
   <meta name="google-signin-client_id" content="TU_GOOGLE_CLIENT_ID.apps.googleusercontent.com">
   ```
3. Reemplaza `TU_GOOGLE_CLIENT_ID` con tu Client ID:
   ```html
   <meta name="google-signin-client_id" content="123456789-abcdefg.apps.googleusercontent.com">
   ```
4. **Guarda** (Ctrl+S)

**Opción B (Alternativa):**

1. Abre: `lib/config/google_signin_config.dart`
2. Busca (línea 10):
   ```dart
   static const String googleClientId = 'YOUR_GOOGLE_CLIENT_ID';
   ```
3. Reemplaza:
   ```dart
   static const String googleClientId = '123456789-abcdefg.apps.googleusercontent.com';
   ```
4. **Guarda** (Ctrl+S)

---

## 🧪 PASO 6: Probar

**En Terminal:**
```bash
cd c:\Users\ADR10\Recicladora\flutter_application_1
flutter run -d chrome
```

**En Chrome:**
- Haz click en **"Continuar con Google"**
- ¡Deberías ver la ventana de seleccionar cuenta!

---

## ✅ Checklist:

- [ ] Abrí https://console.cloud.google.com/
- [ ] Fui a Credentials → APIs & Services
- [ ] Creé un OAuth 2.0 Client ID para Web
- [ ] Autorizé `http://localhost` y `http://localhost:5000`
- [ ] Copié el Client ID
- [ ] Lo pegué en **web/index.html** O en **lib/config/google_signin_config.dart**
- [ ] Ejecuté `flutter run -d chrome`
- [ ] Probé el botón de Google

---

## 🐛 Si sigue sin funcionar:

1. Abre **DevTools en Chrome** (F12)
2. Ve a la pestaña **Console**
3. Haz click en "Continuar con Google"
4. Copia el error exacto y verifica:

| Síntoma | Solución |
|---------|----------|
| "not a valid origin" | El localhost NO está autorizado. Ve a paso 3 |
| "Invalid origin" | Vuelve a copiar el Client ID correctamente |
| "Expected 'web' but got 'android'" | Usaste el Client ID de Android. Crea uno NUEVO de tipo Web |
| Sigue en blanco | Borra caché: Ctrl+Shift+Delete, luego recarga |

---

## 📞 Si tienes dudas:

**Verifica que el Client ID tenga este formato:**
```
123456789-abcdefghijklmnopqrstuvwxyz.apps.googleusercontent.com
```

**¿Es un número largo seguido de `.apps.googleusercontent.com`?** ✅ Bien
**¿Es otra cosa?** ❌ Copiaste mal, vuelve a intentar
