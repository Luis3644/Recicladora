"""
Elimina documentos obsoletos en Firestore/usuarios.
Criterio actual: documentos sin email valido.

Uso:
  Simulacion:
    python cleanup_obsolete_firestore_users.py --dry-run --service-account C:\\ruta\\sa.json
  Aplicar:
    python cleanup_obsolete_firestore_users.py --apply --service-account C:\\ruta\\sa.json
"""

from __future__ import annotations

import argparse

import firebase_admin
from firebase_admin import credentials, firestore


def parse_args() -> argparse.Namespace:
  parser = argparse.ArgumentParser(description="Limpieza de usuarios obsoletos en Firestore")
  mode = parser.add_mutually_exclusive_group(required=False)
  mode.add_argument("--dry-run", action="store_true", help="Solo simular")
  mode.add_argument("--apply", action="store_true", help="Aplicar borrado")
  parser.add_argument("--service-account", required=True, help="Ruta al JSON de service account")
  parser.add_argument("--collection", default="usuarios", help="Coleccion de Firestore")
  return parser.parse_args()


def has_valid_email(data: dict) -> bool:
  email = str(data.get("email") or "").strip()
  return bool(email)


def main() -> int:
  args = parse_args()
  if not args.apply and not args.dry_run:
    args.dry_run = True

  cred = credentials.Certificate(args.service_account)
  firebase_admin.initialize_app(cred)
  db = firestore.client()

  docs = list(db.collection(args.collection).stream())

  obsolete = []
  for doc in docs:
    data = doc.to_dict() or {}
    if not has_valid_email(data):
      obsolete.append(doc)

  print("--- LIMPIEZA USUARIOS OBSOLETOS ---")
  print(f"Coleccion: {args.collection}")
  print(f"Modo: {'APPLY' if args.apply else 'DRY-RUN'}")
  print(f"Total documentos: {len(docs)}")
  print(f"Obsoletos detectados (sin email): {len(obsolete)}")

  for doc in obsolete:
    data = doc.to_dict() or {}
    nombre = str(data.get("nombre") or "").strip() or "(sin nombre)"
    print(f" - {doc.id} | nombre={nombre}")

  if args.apply:
    for doc in obsolete:
      doc.reference.delete()
    print(f"Eliminados: {len(obsolete)}")
  else:
    print("Simulacion completada. No se eliminaron documentos.")

  return 0


if __name__ == "__main__":
  raise SystemExit(main())
