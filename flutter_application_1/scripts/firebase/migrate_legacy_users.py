r"""
Migra usuarios legacy desde Firestore (coleccion usuarios) hacia Firebase Authentication.

Uso recomendado:
    1) Simulacion: python migrate_legacy_users.py --dry-run --service-account C:\\ruta\\sa.json
    2) Real:       python migrate_legacy_users.py --apply --service-account C:\\ruta\\sa.json
"""

from __future__ import annotations

import argparse
from dataclasses import dataclass
from typing import Optional

import firebase_admin
from firebase_admin import auth, credentials, firestore


@dataclass
class Stats:
    total_docs: int = 0
    processed: int = 0
    skipped: int = 0
    created_auth: int = 0
    already_in_auth: int = 0
    updated_firestore: int = 0
    failed: int = 0


def parse_args() -> argparse.Namespace:
    parser = argparse.ArgumentParser(description="Migrador usuarios legacy a Firebase Auth")
    mode = parser.add_mutually_exclusive_group(required=False)
    mode.add_argument("--dry-run", action="store_true", help="Solo simula")
    mode.add_argument("--apply", action="store_true", help="Aplica cambios")
    parser.add_argument("--service-account", required=True, help="Ruta JSON service account")
    parser.add_argument("--collection", default="usuarios", help="Coleccion Firestore")
    parser.add_argument("--only-active", action="store_true", help="Solo usuarios activos")
    return parser.parse_args()


def normalize_email(value: object) -> str:
    return str(value or "").strip().lower()


def normalize_password(value: object) -> str:
    return str(value or "").strip()


def get_auth_user(uid_candidate: str, email: str) -> Optional[auth.UserRecord]:
    try:
        return auth.get_user(uid_candidate)
    except auth.UserNotFoundError:
        pass

    if not email:
        return None

    try:
        return auth.get_user_by_email(email)
    except auth.UserNotFoundError:
        return None


def main() -> int:
    args = parse_args()
    if not args.apply and not args.dry_run:
        args.dry_run = True

    cred = credentials.Certificate(args.service_account)
    firebase_admin.initialize_app(cred)

    db = firestore.client()
    col = db.collection(args.collection)
    docs = list(col.stream())

    stats = Stats(total_docs=len(docs))

    print("--- MIGRACION LEGACY USERS ---")
    print(f"Coleccion: {args.collection}")
    print(f"Modo: {'APPLY' if args.apply else 'DRY-RUN'}")
    print(f"Documentos encontrados: {len(docs)}")

    for doc in docs:
        stats.processed += 1
        data = doc.to_dict() or {}

        email = normalize_email(data.get("email"))
        password = normalize_password(data.get("contrasena"))
        activo = data.get("activo", True) is not False
        uid_field = str(data.get("uid") or "").strip()
        uid_candidate = uid_field or doc.id

        if args.only_active and not activo:
            stats.skipped += 1
            print(f"[SKIP][{doc.id}] inactivo")
            continue

        if not email:
            stats.skipped += 1
            print(f"[SKIP][{doc.id}] sin email")
            continue

        try:
            existing = get_auth_user(uid_candidate, email)

            if existing is None:
                if len(password) < 6:
                    stats.skipped += 1
                    print(
                        f"[SKIP][{doc.id}] sin usuario en Auth y contrasena invalida (<6)."
                    )
                    continue

                if args.apply:
                    display_name = f"{data.get('nombre', '')} {data.get('apellido_paterno', '')}".strip()
                    auth.create_user(
                        uid=uid_candidate,
                        email=email,
                        password=password,
                        display_name=display_name or None,
                        disabled=not activo,
                    )

                stats.created_auth += 1
                print(f"[CREATE][{doc.id}] Auth user creado uid={uid_candidate}")
            else:
                stats.already_in_auth += 1
                print(f"[OK][{doc.id}] ya existe en Auth uid={existing.uid}")

            if args.apply:
                auth_user = existing or auth.get_user(uid_candidate)
                provider_ids = {p.provider_id for p in auth_user.provider_data}
                provider = "google" if "google.com" in provider_ids else "password"

                updates = {
                    "uid": auth_user.uid,
                    "email": auth_user.email or email,
                    "proveedor_auth": provider,
                    "fecha_migracion_auth": firestore.SERVER_TIMESTAMP,
                }

                if "contrasena" in data:
                    updates["contrasena"] = firestore.DELETE_FIELD

                doc.reference.set(updates, merge=True)
                stats.updated_firestore += 1

        except Exception as exc:
            stats.failed += 1
            print(f"[FAIL][{doc.id}] {exc}")

    print("--- RESUMEN ---")
    print(stats)

    if args.dry_run:
        print("DRY-RUN finalizado. No se escribieron cambios.")

    return 0


if __name__ == "__main__":
    raise SystemExit(main())
