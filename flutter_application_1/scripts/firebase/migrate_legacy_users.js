/*
  Migra usuarios legacy desde Firestore (coleccion usuarios) hacia Firebase Authentication.

  Requisitos:
  - Archivo de service account JSON (GOOGLE_APPLICATION_CREDENTIALS o --serviceAccount=path)
  - Campo email en Firestore
  - Campo contrasena en Firestore para cuentas que se quieran crear en Auth

  Modos:
  - --dry-run  : no escribe cambios, solo reporta
  - --apply    : crea usuarios en Auth y limpia contrasena en Firestore
*/

const fs = require('fs');
const path = require('path');
const admin = require('firebase-admin');

function parseArgs(argv) {
  const args = {
    dryRun: false,
    apply: false,
    serviceAccount: process.env.GOOGLE_APPLICATION_CREDENTIALS || '',
    collection: 'usuarios',
    onlyActive: false,
  };

  for (const raw of argv.slice(2)) {
    if (raw === '--dry-run') args.dryRun = true;
    else if (raw === '--apply') args.apply = true;
    else if (raw === '--only-active') args.onlyActive = true;
    else if (raw.startsWith('--serviceAccount=')) {
      args.serviceAccount = raw.split('=')[1] || '';
    } else if (raw.startsWith('--collection=')) {
      args.collection = raw.split('=')[1] || 'usuarios';
    }
  }

  if (!args.dryRun && !args.apply) {
    args.dryRun = true;
  }

  return args;
}

function loadServiceAccount(serviceAccountPath) {
  if (!serviceAccountPath) {
    throw new Error(
      'No se encontro service account. Usa GOOGLE_APPLICATION_CREDENTIALS o --serviceAccount=RUTA_JSON',
    );
  }

  const resolved = path.resolve(serviceAccountPath);
  if (!fs.existsSync(resolved)) {
    throw new Error(`No existe el archivo service account: ${resolved}`);
  }

  return require(resolved);
}

async function getAuthUserByUidOrEmail(uidCandidate, email) {
  try {
    return await admin.auth().getUser(uidCandidate);
  } catch (e) {
    if (e && e.code !== 'auth/user-not-found') throw e;
  }

  if (!email) return null;

  try {
    return await admin.auth().getUserByEmail(email);
  } catch (e) {
    if (e && e.code !== 'auth/user-not-found') throw e;
    return null;
  }
}

function normalizeEmail(raw) {
  return (raw || '').toString().trim().toLowerCase();
}

function normalizePassword(raw) {
  return (raw || '').toString().trim();
}

async function main() {
  const args = parseArgs(process.argv);
  const serviceAccount = loadServiceAccount(args.serviceAccount);

  admin.initializeApp({
    credential: admin.credential.cert(serviceAccount),
  });

  const db = admin.firestore();
  const snap = await db.collection(args.collection).get();

  const stats = {
    totalDocs: snap.size,
    processed: 0,
    skipped: 0,
    createdAuth: 0,
    alreadyInAuth: 0,
    cleanedFirestore: 0,
    failed: 0,
  };

  console.log('--- MIGRACION LEGACY USERS ---');
  console.log(`Coleccion: ${args.collection}`);
  console.log(`Modo: ${args.apply ? 'APPLY' : 'DRY-RUN'}`);
  console.log(`Documentos encontrados: ${snap.size}`);

  for (const doc of snap.docs) {
    const data = doc.data() || {};
    const email = normalizeEmail(data.email);
    const password = normalizePassword(data.contrasena);
    const activo = data.activo !== false;
    const uidField = (data.uid || '').toString().trim();
    const uidCandidate = uidField || doc.id;

    stats.processed += 1;

    if (args.onlyActive && !activo) {
      stats.skipped += 1;
      console.log(`[SKIP][${doc.id}] inactivo`);
      continue;
    }

    if (!email) {
      stats.skipped += 1;
      console.log(`[SKIP][${doc.id}] sin email`);
      continue;
    }

    try {
      const existingAuth = await getAuthUserByUidOrEmail(uidCandidate, email);

      if (!existingAuth) {
        if (!password || password.length < 6) {
          stats.skipped += 1;
          console.log(
            `[SKIP][${doc.id}] no existe en Auth y no tiene contrasena valida (min 6).`,
          );
          continue;
        }

        if (args.apply) {
          await admin.auth().createUser({
            uid: uidCandidate,
            email,
            password,
            displayName: [data.nombre, data.apellido_paterno]
              .filter(Boolean)
              .join(' ')
              .trim() || undefined,
            disabled: !activo,
          });
        }

        stats.createdAuth += 1;
        console.log(`[CREATE][${doc.id}] Auth user creado uid=${uidCandidate}`);
      } else {
        stats.alreadyInAuth += 1;
        console.log(`[OK][${doc.id}] ya existe en Auth uid=${existingAuth.uid}`);
      }

      if (args.apply) {
        const authUser = existingAuth || (await admin.auth().getUser(uidCandidate));
        const updates = {
          uid: authUser.uid,
          email: authUser.email || email,
          proveedor_auth: (authUser.providerData || []).some(
            (p) => p.providerId === 'google.com',
          )
            ? 'google'
            : 'password',
          fecha_migracion_auth: admin.firestore.FieldValue.serverTimestamp(),
        };

        if (Object.prototype.hasOwnProperty.call(data, 'contrasena')) {
          updates.contrasena = admin.firestore.FieldValue.delete();
        }

        await doc.ref.set(updates, { merge: true });
        stats.cleanedFirestore += 1;
      }
    } catch (e) {
      stats.failed += 1;
      console.error(`[FAIL][${doc.id}] ${e.message || e}`);
    }
  }

  console.log('--- RESUMEN ---');
  console.log(stats);

  if (args.dryRun) {
    console.log('DRY-RUN finalizado. No se escribieron cambios.');
  }
}

main()
  .then(() => process.exit(0))
  .catch((err) => {
    console.error('Error fatal en migracion:', err.message || err);
    process.exit(1);
  });
