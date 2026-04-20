# Google Sign-In estable para APK interno (sin Play Store)

## Objetivo
Evitar que Google Sign-In dependa del SHA-1 de debug de cada computadora.

## Que se cambio en el proyecto
- `android/app/build.gradle.kts` ahora soporta firma release por `android/key.properties`.
- Si intentas generar una build release sin `key.properties`, Gradle falla con un mensaje claro.
- Se agrego `android/key.properties.example` como plantilla.

## Flujo correcto (una sola vez)

1. Crear un keystore release fijo (solo una vez)

```powershell
cd c:\Users\ADR10\Recicladora\flutter_application_1\android
mkdir ..\keystores
keytool -genkeypair -v -keystore ..\keystores\recicladora-internal.jks -alias recicladora_internal -keyalg RSA -keysize 2048 -validity 10000
```

2. Crear `android/key.properties` desde `android/key.properties.example` y poner claves reales.

3. Obtener SHA-1/SHA-256 del keystore release

```powershell
cd c:\Users\ADR10\Recicladora\flutter_application_1\android
keytool -list -v -keystore ..\keystores\recicladora-internal.jks -alias recicladora_internal
```

4. Registrar ese SHA-1 (y recomendado SHA-256) en Firebase
- Firebase Console -> Project settings -> Your apps -> Android app -> Add fingerprint.

5. Descargar de nuevo `google-services.json` y reemplazar
- `android/app/google-services.json`

6. Generar siempre el APK release con esa misma firma

```powershell
cd c:\Users\ADR10\Recicladora\flutter_application_1
flutter build apk --release
```

## Resultado esperado
Mientras distribuyas el APK release firmado con el mismo keystore, cualquier usuario podra iniciar sesion con Google sin registrar nada en su dispositivo.

## Nota importante
Si cambias de keystore, cambia el SHA y Google Sign-In deja de funcionar hasta registrar el nuevo SHA en Firebase y actualizar `google-services.json`.
