const {setGlobalOptions}    = require("firebase-functions/v2");
const {onDocumentCreated, onDocumentUpdated, onDocumentWritten} = require("firebase-functions/v2/firestore");
const logger                = require("firebase-functions/logger");
const admin                 = require("firebase-admin");

admin.initializeApp();
setGlobalOptions({maxInstances: 10});

// ── HELPER: obtener token FCM ─────────────────────────────────────────────────
function _getToken(docData) {
  return (docData.fcm_token || docData.fcmToken || "").toString().trim();
}

async function _notificarUsuariosConToken({ usuariosSnap, titulo, cuerpo, tipo, dataExtra = {} }) {
  const envios = [];

  for (const doc of usuariosSnap.docs) {
    const token = _getToken(doc.data());
    if (!token) continue;

    envios.push(
      admin.messaging().send({
        token,
        notification: {
          title: titulo,
          body: cuerpo,
        },
        android: {
          priority: "high",
          ttl: 86400000,
          directBootOk: true,
          notification: {
            defaultVibrateTimings: true,
            defaultSound: true,
          },
        },
        apns: {
          payload: { aps: { sound: "default", badge: 1 } },
        },
        data: {
          tipo,
          ...dataExtra,
        },
      }).catch(err => logger.error(`Error enviando push a ${doc.id}:`, err))
    );
  }

  await Promise.allSettled(envios);
}

// ─────────────────────────────────────────────────────────────────────────────
// 1. Notifica al OPERADOR cuando su reporte es marcado como visto
// ─────────────────────────────────────────────────────────────────────────────
exports.notificarReporteRevisado = onDocumentUpdated(
  "reportes/{reporteId}",
  async (event) => {
    const antes   = event.data.before.data();
    const despues = event.data.after.data();

    if (antes.visto === true || despues.visto !== true) return null;

    const nombreOperador = (despues.operador || "").toString().trim();
    const reporteId      = event.params.reporteId;

    if (!nombreOperador) {
      logger.warn("Reporte sin campo 'operador':", reporteId);
      return null;
    }

    // Buscar por nombre + rol operador
    let usuariosSnap = await admin.firestore()
      .collection("usuarios")
      .where("nombre", "==", nombreOperador)
      .where("rol", "==", "operador")
      .get();

    // Fallback: buscar solo por nombre excluyendo admins
    let docs = usuariosSnap.docs;
    if (docs.length === 0) {
      const fallback = await admin.firestore()
        .collection("usuarios")
        .where("nombre", "==", nombreOperador)
        .get();
      docs = fallback.docs.filter(d => d.data().rol !== "admin");
    }

    if (docs.length === 0) {
      logger.warn(`No se encontró operador con nombre: "${nombreOperador}"`);
      return null;
    }

    const envios = [];
    for (const doc of docs) {
      const token = _getToken(doc.data());
      if (!token) continue;

      envios.push(
        admin.messaging().send({
          token,
          notification: {
            title: "✅ Tu reporte fue revisado",
            body:  "El administrador ya revisó tu reporte. Toca para verlo.",
          },
          android: {
            priority: "high",
            ttl: 86400000,
            directBootOk: true,
            notification: {
              color:                "#10B981",
              channelId:            "reportes_revisados",
              clickAction:          "FLUTTER_NOTIFICATION_CLICK",
              defaultVibrateTimings: true,
              defaultSound:         true,
            },
          },
          apns: {
            payload: { aps: { sound: "default", badge: 1 } },
          },
          data: {
            reporteId,
            tipo:     "reporte_revisado",
            operador: nombreOperador,
          },
        })
        .then(() => logger.info(`✅ Notificado a ${doc.id} (${nombreOperador})`))
        .catch(err => logger.error(`Error enviando a ${doc.id}:`, err))
      );
    }

    await Promise.all(envios);
    return null;
  }
);

// ─────────────────────────────────────────────────────────────────────────────
// 2. Notifica a los ADMINS cuando un operador envía un reporte nuevo
// ─────────────────────────────────────────────────────────────────────────────
exports.notificarReporteNuevo = onDocumentCreated(
  "reportes/{reporteId}",
  async (event) => {
    const data      = event.data.data();
    const operador  = (data.operador || "Un operador").toString().trim();
    const mensaje   = (data.mensaje  || "Sin descripción").toString().trim();
    const reporteId = event.params.reporteId;

    const adminsSnap = await admin.firestore()
      .collection("usuarios")
      .where("rol", "==", "admin")
      .get();

    if (adminsSnap.empty) {
      logger.info("No hay admins registrados");
      return null;
    }

    const cuerpo = mensaje.length > 80
      ? mensaje.substring(0, 80) + "…"
      : mensaje;

    const envios = [];
    for (const adminDoc of adminsSnap.docs) {
      const token = _getToken(adminDoc.data());
      if (!token) continue;

      envios.push(
        admin.messaging().send({
          token,
          notification: {
            title: `🚨 Nuevo reporte de ${operador}`,
            body:  cuerpo,
          },
          android: {
            priority: "high",
            ttl: 86400000,
            directBootOk: true,
            notification: {
              color:                "#F97316",
              channelId:            "nuevos_reportes",
              clickAction:          "FLUTTER_NOTIFICATION_CLICK",
              defaultVibrateTimings: true,
              defaultSound:         true,
            },
          },
          apns: {
            payload: { aps: { sound: "default", badge: 1 } },
          },
          data: {
            reporteId,
            tipo:     "reporte_nuevo",
            operador,
          },
        })
        .catch(err => logger.error(`Error enviando a admin ${adminDoc.id}:`, err))
      );
    }

    await Promise.all(envios);
    logger.info(`🚨 Reporte nuevo notificado a ${envios.length} admin(s)`);
    return null;
  }
);

// ─────────────────────────────────────────────────────────────────────────────
// 3. Mensajes masivos desde colección 'notificaciones'
//    FIX: usa send() individual en lugar de sendEachForMulticast()
//         para que el campo data.tipo llegue correctamente a Flutter
//         y el filtro if (tipo == 'admin_mensaje') return; funcione.
// ─────────────────────────────────────────────────────────────────────────────
exports.sendPushOnAdminNotification = onDocumentCreated(
  "notificaciones/{notificacionId}",
  async (event) => {
    const notificacion    = event.data.data() || {};
    const mensaje         = (notificacion.mensaje || "").toString().trim();
    const enviadoPorDocId = (notificacion.enviadoPorDocId || "").toString().trim();

    if (!mensaje) return;

    const tipo = notificacion.destinoTipo || "todos";
    let destinatariosSnap;

    if (tipo === "individual") {
      const doc = await admin.firestore()
        .collection("usuarios")
        .doc(notificacion.destinatarioDocId)
        .get();
      destinatariosSnap = doc.exists ? [doc] : [];
    } else if (tipo === "rol") {
      const snap = await admin.firestore()
        .collection("usuarios")
        .where("rol", "==", notificacion.destinatarioRol)
        .get();
      destinatariosSnap = snap.docs;
    } else {
      // todos: operadores y trabajadores
      const snap = await admin.firestore()
        .collection("usuarios")
        .where("rol", "in", ["operador", "trabajador"])
        .get();
      destinatariosSnap = snap.docs;
    }

    // Excluir al remitente y obtener tokens únicos
    const tokensVistos = new Set();
    const destinatarios = destinatariosSnap
      .filter(doc => doc.id !== enviadoPorDocId)
      .filter(doc => {
        const t = _getToken(doc.data());
        if (!t || tokensVistos.has(t)) return false;
        tokensVistos.add(t);
        return true;
      });

    if (!destinatarios.length) {
      logger.info("No hay destinatarios para enviar notificación masiva");
      return;
    }

    // ── FIX CLAVE: enviar con send() individual ────────────────────────────
    // sendEachForMulticast no propaga data.tipo correctamente cuando viene
    // junto con notification{}, por lo que Flutter no puede filtrar el mensaje
    // y se muestra duplicado. Con send() individual sí llega el campo tipo.
    const envios = [];
    for (const doc of destinatarios) {
      const token = _getToken(doc.data());

      envios.push(
        admin.messaging().send({
          token,
          notification: {
            title: "📢 Mensaje de administración",
            body:  mensaje,
          },
          android: {
            priority: "high",
            ttl: 86400000,
            directBootOk: true,
            notification: {
              channelId:             "admin_notificaciones",
              defaultVibrateTimings: true,
              defaultSound:          true,
            },
          },
          apns: {
            payload: { aps: { sound: "default", badge: 1 } },
          },
          // ── data.tipo llega correctamente con send() individual ────────────
          data: {
            tipo: "admin_mensaje",
          },
        })
        .catch(err => logger.error(`Error enviando a ${doc.id}:`, err))
      );
    }

    const resultados = await Promise.allSettled(envios);
    const exitosos   = resultados.filter(r => r.status === "fulfilled").length;
    const fallidos   = resultados.filter(r => r.status === "rejected").length;
    logger.info(`📢 Push masivo: ${exitosos} enviados, ${fallidos} fallidos`);

    // Reenviar notificaciones de contenedores desde el aviso del admin
    // hacia todos los operadores que estén en jornada activa.
    const tipoNormalizado = (notificacion.tipo || "").toString();
    const esContenedor = tipoNormalizado === "contenedor_llenando" || tipoNormalizado === "contenedor_lleno";
    const destinoRol = (notificacion.destinatarioRol || "").toString();
    const destinoTipo = (notificacion.destinoTipo || "").toString();

    if (esContenedor && destinoRol === "admin" && destinoTipo === "rol") {
      const operadoresActivos = await admin.firestore()
        .collection("usuarios")
        .where("rol", "==", "operador")
        .where("jornada_activa", "==", true)
        .get();

      if (operadoresActivos.empty) {
        logger.info("No hay operadores activos para reenviar notificación de contenedor");
        return null;
      }

      const relayBatch = admin.firestore().batch();
      for (const op of operadoresActivos.docs) {
        relayBatch.set(admin.firestore().collection("notificaciones").doc(), {
          mensaje,
          enviadoPor: notificacion.enviadoPor || "Administración",
          creadoEn: admin.firestore.FieldValue.serverTimestamp(),
          tipo: notificacion.tipo,
          destinoTipo: "individual",
          destinatarioDocId: op.id,
          destinatarioNombre: (op.data().nombre || "").toString(),
          destinatarioRol: "operador",
          paraTodos: false,
          contenedorId: notificacion.contenedorId || "",
          estadoContenedor: notificacion.estadoContenedor || "",
          origenReenvio: "admin",
        });
      }

      await relayBatch.commit();
      logger.info(`🔁 Notificación de contenedor reenviada a ${operadoresActivos.size} operador(es)`);
    }
  }
);

// ─────────────────────────────────────────────────────────────────────────────
// 4. Crea la notificación inicial del admin cuando un trabajador actualiza
//    un contenedor a "En proceso de llenado" o "Lleno".
// ─────────────────────────────────────────────────────────────────────────────
exports.notificarContenedorActualizado = onDocumentWritten(
  "contenedores/{contenedorId}",
  async (event) => {
    const before = event.data.before.exists ? event.data.before.data() : null;
    const after = event.data.after.exists ? event.data.after.data() : null;
    if (!after) return null;

    const estadoAntes = (before?.estado || "").toString();
    const estadoDespues = (after?.estado || "").toString();
    if (estadoAntes === estadoDespues) return null;

    const estadosValidos = new Set(["En proceso de llenado", "Lleno"]);
    if (!estadosValidos.has(estadoDespues)) return null;

    const contenedorId = event.params.contenedorId;
    const labelId = contenedorId.replace("contenedor-", "C");
    const actualizadoPor = (after.actualizadoPor || "Un trabajador").toString().trim();
    const mensaje = estadoDespues === "Lleno"
      ? `Contenedor ${labelId} listo para recoger. Aparta este contenedor si estás disponible. Reportado por ${actualizadoPor}.`
      : `Contenedor ${labelId} en proceso de llenado, reportado por ${actualizadoPor}.`;

    const operadoresSnap = await admin.firestore()
      .collection("usuarios")
      .where("rol", "==", "operador")
      .where("jornada_activa", "==", true)
      .get();

    if (operadoresSnap.empty) {
      logger.info(`No hay operadores activos para notificar sobre ${contenedorId}`);
      return null;
    }

    const batch = admin.firestore().batch();
    for (const operadorDoc of operadoresSnap.docs) {
      const operadorData = operadorDoc.data() || {};
      batch.set(admin.firestore().collection("notificaciones").doc(), {
        mensaje,
        enviadoPor: actualizadoPor,
        creadoEn: admin.firestore.FieldValue.serverTimestamp(),
        tipo: estadoDespues === "Lleno" ? "contenedor_lleno" : "contenedor_llenando",
        destinoTipo: "individual",
        destinatarioDocId: operadorDoc.id,
        destinatarioNombre: (operadorData.nombre || "").toString().trim(),
        destinatarioRol: "operador",
        paraTodos: false,
        contenedorId,
        estadoContenedor: estadoDespues,
      });
    }
    await batch.commit();

    await _notificarUsuariosConToken({
      usuariosSnap: operadoresSnap,
      titulo: estadoDespues === "Lleno" ? "♻️ Contenedor listo" : "🟡 Contenedor en proceso",
      cuerpo: mensaje,
      tipo: estadoDespues === "Lleno" ? "contenedor_lleno" : "contenedor_llenando",
      dataExtra: {
        contenedorId,
        estadoContenedor: estadoDespues,
      },
    });

    logger.info(`Contenedor ${contenedorId} actualizado a ${estadoDespues} y notificado a operadores activos`);
    return null;
  }
);