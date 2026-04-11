r"""
Borra todos los usuarios de Firebase Authentication y todos los documentos
de Firestore en la coleccion `usuarios`.

Uso:
  Simulacion:
    python reset_users_database.py --dry-run --service-account C:\ruta\sa.json
  Aplicar:
    python reset_users_database.py --apply --confirm-delete-all-users --service-account C:\ruta\sa.json

Advertencia:
  Este script es destructivo. Elimina las cuentas de Authentication y los
  perfiles de Firestore. Ejecutalo solo cuando quieras reiniciar la base de
  usuarios desde cero.

Si pasas --keep-email, ese usuario se conserva en Authentication y su perfil
se reconstruye o actualiza en Firestore con rol admin.
"""

from __future__ import annotations

import argparse
from typing import Iterable

import firebase_admin
from firebase_admin import auth, credentials, firestore


AUTH_BATCH_SIZE = 1000
FIRESTORE_BATCH_SIZE = 450


def parse_args() -> argparse.Namespace:
    parser = argparse.ArgumentParser(description="Reseteo total de usuarios")
    mode = parser.add_mutually_exclusive_group(required=False)
    mode.add_argument("--dry-run", action="store_true", help="Solo simular")
    mode.add_argument("--apply", action="store_true", help="Aplicar cambios")
    parser.add_argument("--service-account", required=True, help="Ruta al JSON de service account")
    parser.add_argument("--collection", default="usuarios", help="Coleccion Firestore")
    parser.add_argument(
        "--keep-email",
        help="Correo del usuario que se conservara como administrador",
    )
    parser.add_argument(
        "--confirm-delete-all-users",
        action="store_true",
        help="Confirma que deseas borrar todos los usuarios",
    )
    parser.add_argument(
        "--delete-auth-only",
        action="store_true",
        help="Borra solo Authentication y conserva Firestore",
    )
    parser.add_argument(
        "--delete-firestore-only",
        action="store_true",
        help="Borra solo Firestore y conserva Authentication",
    )
    return parser.parse_args()


def chunked(values: list[str], size: int) -> Iterable[list[str]]:
    for index in range(0, len(values), size):
        yield values[index : index + size]


def normalize_email(value: str | None) -> str:
    return str(value or "").strip().lower()


def load_auth_uids() -> list[str]:
    uids: list[str] = []
    for user in auth.list_users().iterate_all():
        uids.append(user.uid)
    return uids


def load_firestore_docs(db: firestore.Client, collection: str):
    return list(db.collection(collection).stream())


def obtener_usuario_por_email(email: str):
    try:
        return auth.get_user_by_email(email)
    except auth.UserNotFoundError:
        return None


def proveedor_auth_desde_usuario(usuario: auth.UserRecord) -> str:
    provider_ids = {provider.provider_id for provider in usuario.provider_data}
    if "google.com" in provider_ids and "password" in provider_ids:
        return "password_google"
    if "google.com" in provider_ids:
        return "google"
    if "password" in provider_ids:
        return "password"
    return "unknown"


def auth_providers_desde_usuario(usuario: auth.UserRecord) -> list[str]:
    provider_ids = {provider.provider_id for provider in usuario.provider_data}
    providers: list[str] = []
    if "google.com" in provider_ids:
        providers.append("google")
    if "password" in provider_ids:
        providers.append("password")
    return providers


def asegurar_perfil_admin(
    db: firestore.Client,
    collection: str,
    usuario: auth.UserRecord,
) -> None:
    email = normalize_email(usuario.email)
    datos = {
        "uid": usuario.uid,
        "email": email,
        "email_normalizado": email,
        "rol": "admin",
        "activo": True,
        "proveedor_auth": proveedor_auth_desde_usuario(usuario),
        "auth_providers": auth_providers_desde_usuario(usuario),
        "sesion_activa": False,
        "sesion_dispositivo_id": "",
        "sesion_dispositivo_nombre": "",
    }

    if usuario.display_name:
        datos["nombre"] = usuario.display_name

    db.collection(collection).document(usuario.uid).set(datos, merge=True)


def main() -> int:
    args = parse_args()
    if not args.apply and not args.dry_run:
        args.dry_run = True

    if args.apply and not args.confirm_delete_all_users:
        raise SystemExit(
            "Debes confirmar el borrado total con --confirm-delete-all-users"
        )

    keep_email = normalize_email(args.keep_email)

    cred = credentials.Certificate(args.service_account)
    firebase_admin.initialize_app(cred)

    db = firestore.client()
    borrar_auth = not args.delete_firestore_only
    borrar_firestore = not args.delete_auth_only

    auth_uids = load_auth_uids() if borrar_auth else []
    firestore_docs = load_firestore_docs(db, args.collection) if borrar_firestore else []
    usuario_conservado = obtener_usuario_por_email(keep_email) if keep_email else None

    if keep_email and usuario_conservado is None:
        raise SystemExit(
            f"No se encontro el usuario a conservar en Authentication: {keep_email}"
        )

    uid_conservado = usuario_conservado.uid if usuario_conservado else ""

    print("--- RESET TOTAL DE USUARIOS ---")
    print(f"Coleccion: {args.collection}")
    print(f"Modo: {'APPLY' if args.apply else 'DRY-RUN'}")
    print(f"Borrar Authentication: {borrar_auth}")
    print(f"Borrar Firestore: {borrar_firestore}")
    print(f"Mantener usuario: {keep_email or '(ninguno)'}")
    print(f"Usuarios en Auth: {len(auth_uids)}")
    print(f"Documentos en Firestore: {len(firestore_docs)}")

    if args.dry_run:
        if usuario_conservado is not None:
            print(f"Usuario conservado en Auth: {usuario_conservado.uid}")
        print("DRY-RUN finalizado. No se eliminaron datos.")
        return 0

    if borrar_auth and auth_uids:
        ids_a_borrar = [uid for uid in auth_uids if uid != uid_conservado]
        total_deleted = 0
        for batch in chunked(ids_a_borrar, AUTH_BATCH_SIZE):
            result = auth.delete_users(batch)
            total_deleted += result.success_count
            if result.failure_count:
                print(f"Auth: fallos en lote -> {result.errors}")
        print(f"Usuarios eliminados de Authentication: {total_deleted}")

    if usuario_conservado is not None:
        asegurar_perfil_admin(db, args.collection, usuario_conservado)
        print(f"Usuario conservado y sincronizado como admin: {usuario_conservado.uid}")

    if borrar_firestore and firestore_docs:
        ids_a_borrar = {doc.id for doc in firestore_docs if doc.id != uid_conservado}
        total_deleted = 0
        batch = db.batch()
        pending = 0

        for doc in firestore_docs:
            if doc.id not in ids_a_borrar:
                continue
            batch.delete(doc.reference)
            pending += 1
            total_deleted += 1

            if pending >= FIRESTORE_BATCH_SIZE:
                batch.commit()
                batch = db.batch()
                pending = 0

        if pending:
            batch.commit()

        print(f"Documentos eliminados de Firestore: {total_deleted}")

    print("Reseteo total completado.")
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
