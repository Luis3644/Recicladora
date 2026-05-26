# flutter_application_1

A new Flutter project.

## Despliegue web en Netlify

1. Asegúrate de tener Flutter instalado en la máquina o CI que hará el build.
2. Desde la carpeta `flutter_application_1`, ejecuta el despliegue con la configuración ya incluida en `netlify.toml`.
3. Netlify usará `flutter build web --release --base-href /` y publicará `build/web`.
4. Si usas Firebase Auth con Google Sign-In, agrega el dominio de Netlify en Authorized domains dentro de Firebase Authentication.
5. Si la app usa rutas internas y entras directo por una URL profunda, el redirect de `netlify.toml` evita errores 404.

## Getting Started

This project is a starting point for a Flutter application.

A few resources to get you started if this is your first Flutter project:

- [Learn Flutter](https://docs.flutter.dev/get-started/learn-flutter)
- [Write your first Flutter app](https://docs.flutter.dev/get-started/codelab)
- [Flutter learning resources](https://docs.flutter.dev/reference/learning-resources)

For help getting started with Flutter development, view the
[online documentation](https://docs.flutter.dev/), which offers tutorials,
samples, guidance on mobile development, and a full API reference.
