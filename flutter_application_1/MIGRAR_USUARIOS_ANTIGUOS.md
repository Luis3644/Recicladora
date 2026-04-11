# Migracion de usuarios antiguos

Este proyecto incluye un script en Python para migrar usuarios legacy de Firestore a Firebase Authentication.

## Que hace

1. Lee la coleccion `usuarios` en Firestore.
2. Si un documento no existe en Authentication y tiene `email` + `contrasena` valida (minimo 6), crea el usuario en Auth.
3. Actualiza Firestore con:
- `uid`
- `email`
- `proveedor_auth`
- `fecha_migracion_auth`
4. Elimina `contrasena` de Firestore (solo en modo apply).

## Requisitos

1. Service Account JSON con permisos para Authentication y Firestore.
2. Python disponible.

## Instalar dependencias del migrador

Desde la raiz del proyecto:

```powershell
c:/Users/ADR10/Recicladora/.venv/Scripts/python.exe -m pip install -r scripts/firebase/requirements.txt
```

Si usas otro Python, reemplaza la ruta del ejecutable.

## Ejecutar primero en simulacion (recomendado)

```powershell
c:/Users/ADR10/Recicladora/.venv/Scripts/python.exe scripts/firebase/migrate_legacy_users.py --dry-run --service-account "C:\ruta\service-account.json"
```

## Ejecutar migracion real

```powershell
c:/Users/ADR10/Recicladora/.venv/Scripts/python.exe scripts/firebase/migrate_legacy_users.py --apply --service-account "C:\ruta\service-account.json"
```

## Opciones adicionales

- `--only-active`: migra solo documentos activos.
- `--collection=usuarios`: permite cambiar coleccion.

Ejemplo:

```powershell
c:/Users/ADR10/Recicladora/.venv/Scripts/python.exe scripts/firebase/migrate_legacy_users.py --apply --only-active --service-account "C:\ruta\service-account.json"
```

## Importante

- Haz backup de Firestore antes de ejecutar en modo apply.
- Prueba primero con dry-run.
- Usuarios creados por Google sin `contrasena` en Firestore no se crean como password user automaticamente (quedan para acceso por Google).
