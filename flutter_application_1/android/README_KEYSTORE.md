Preparar keystore para firmar APKs release

1) Copia `key.properties.example` a `android/key.properties` y reemplaza los valores:

   - `storePassword`: contraseña del keystore
   - `keyPassword`: contraseña de la clave
   - `keyAlias`: alias de la clave
   - `storeFile`: ruta relativa al archivo JKS dentro del proyecto (por ejemplo `keystores/my-release-key.jks`)

2) Coloca tu archivo JKS en la ruta indicada (`android/keystores/...`).

Importante:

- La firma de release es única para toda la app. Todos los APK/AAB publicados deben usar siempre la misma keystore.
- Si un dispositivo ya tiene instalada una versión firmada con otra clave, Android no permite actualizarla sin desinstalar primero.
- Esto no es un error de Firebase ni del código OTA; es una restricción de Android.

3) Opcional: generar un keystore nuevo (si aún no tienes uno):

```bash
keytool -genkeypair -v -keystore android/keystores/my-release-key.jks -keyalg RSA -keysize 2048 -validity 10000 -alias MI_ALIAS
```

4) Para construir el APK release firmado:

```bash
# desde la raíz del proyecto
flutter clean
flutter build apk --release --build-number=2
```

5) Sube el APK generado `build/app/outputs/flutter-apk/app-release.apk` a Firebase Storage y actualiza `config/app_version` en Firestore con `build_number` y `url_apk`.

Seguridad: nunca subas `android/key.properties` ni tu `.jks` a un repositorio público.
