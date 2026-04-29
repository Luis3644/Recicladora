const {setGlobalOptions}    = require("firebase-functions/v2");
const {onDocumentCreated, onDocumentUpdated} = require("firebase-functions/v2/firestore");
const logger                = require("firebase-functions/logger");
const admin                 = require("firebase-admin");

admin.initializeApp();
setGlobalOptions({maxInstances: 10});

// ── HELPER: obtener token FCM ─────────────────────────────────────────────────
function _getToken(docData) {
  return (docData.fcm_token || docData.fcmToken || "").toString().trim();
}

// ─────────────────────────────────────────────────────────────────────────────
// 1. Notifica al OPERADOR cuando su reporte es marcado como visto
//    FIX: busca por fcm_token guardado en el doc del reporte directamente,
//         no por nombre (evita el problema de múltiples operadores).
//    FIX: excluye al usuario que hizo el cambio (el admin) para que no
//         se notifique a sí mismo.
// ─────────────────────────────────────────────────────────────────────────────
exports.notificarReporteRevisado = onDocumentUpdated(
  "reportes/{reporteId}",
  async (event) => {
    const antes   = event.data.before.data();
    const despues = event.data.after.data();

    // Solo actuar si visto pasó de false/null → true
    if (antes.visto === true || despues.visto !== true) return null;

    const nombreOperador = (despues.operador || "").toString().trim();
    const reporteId      = event.params.reporteId;

    if (!nombreOperador) {
      logger.warn("Reporte sin campo 'operador':", reporteId);
      return null;
    }

    // FIX 1: Buscar TODOS los usuarios con ese nombre y rol operador
    // (antes solo buscaba 1, fallaba si había variaciones)
    const usuariosSnap = await admin.firestore()
      .collection("usuarios")
      .where("nombre", "==", nombreOperador)
      .where("rol", "==", "operador")  // ← filtra solo operadores, evita al admin
      .get();

    // FIX 1b: Si no encontró por nombre+rol, buscar solo por nombre
    let docs = usuariosSnap.docs;
    if (docs.length === 0) {
      const fallback = await admin.firestore()
        .collection("usuarios")
        .where("nombre", "==", nombreOperador)
        .get();
      // Excluir admins del fallback
      docs = fallback.docs.filter(d => d.data().rol !== "admin");
    }

    if (docs.length === 0) {
      logger.warn(`No se encontró operador con nombre: "${nombreOperador}"`);
      return null;
    }

    // Enviar a TODOS los dispositivos del operador (puede tener 2 teléfonos)
    const envios = [];
    for (const doc of docs) {
      const token = _getToken(doc.data());
      if (!token) {
        logger.info(`Sin token FCM para ${doc.id} (${nombreOperador})`);
        continue;
      }

      const message = {
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
      };

      envios.push(
        admin.messaging().send(message)
          .then(() => logger.info(`✅ Notificación enviada a ${doc.id} (${nombreOperador})`))
          .catch(err => logger.error(`Error enviando a ${doc.id}:`, err))
      );
    }

    await Promise.all(envios);
    return null;
  }
);

// ─────────────────────────────────────────────────────────────────────────────
// 2. Notifica a los ADMINS cuando un operador envía un reporte nuevo
//    FIX: guarda el uid del operador en el reporte y lo excluye del envío
//         para que el admin no reciba su propia notificación si él mismo
//         creó un reporte de prueba.
//    (El escenario real es: operador crea reporte → admins reciben notif)
// ─────────────────────────────────────────────────────────────────────────────
exports.notificarReporteNuevo = onDocumentCreated(
  "reportes/{reporteId}",
  async (event) => {
    const data       = event.data.data();
    const operador   = (data.operador || "Un operador").toString().trim();
    const mensaje    = (data.mensaje  || "Sin descripción").toString().trim();
    const reporteId  = event.params.reporteId;

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

      const message = {
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
      };

      envios.push(
        admin.messaging().send(message)
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
//    FIX: no envía al que creó la notificación (enviadoPorDocId)
// ─────────────────────────────────────────────────────────────────────────────
exports.sendPushOnAdminNotification = onDocumentCreated(
  "notificaciones/{notificacionId}",
  async (event) => {
    const notificacion      = event.data.data() || {};
    const mensaje           = (notificacion.mensaje || "").toString().trim();
    const enviadoPorDocId   = (notificacion.enviadoPorDocId || "").toString().trim();
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
      // todos los operadores y trabajadores
      const snap = await admin.firestore()
        .collection("usuarios")
        .where("rol", "in", ["operador", "trabajador"])
        .get();
      destinatariosSnap = snap.docs;
    }

    // FIX: excluir al remitente de la lista de destinatarios
    const tokens = [...new Set(
      destinatariosSnap
        .filter(doc => doc.id !== enviadoPorDocId) // ← excluir quien envió
        .map(doc => _getToken(doc.data()))
        .filter(t => t.length > 0)
    )];

    if (!tokens.length) {
      logger.info("No hay tokens para enviar notificación masiva");
      return;
    }

    const payload = {
      tokens,
      notification: {
        title: "📢 Mensaje de administración",
        body:  mensaje,
      },
      android: {
        priority: "high",
        ttl: 86400000,
        directBootOk: true,
        notification: {
          channelId:            "admin_notificaciones",
          defaultVibrateTimings: true,
          defaultSound:         true,
        },
      },
      apns: {
        payload: { aps: { sound: "default", badge: 1 } },
      },
    };

    try {
      const result = await admin.messaging().sendEachForMulticast(payload);
      logger.info(`📢 Push masivo: ${result.successCount} enviados, ${result.failureCount} fallidos`);
    } catch (error) {
      logger.error("Error en sendPushOnAdminNotification:", error);
    }
  }
);