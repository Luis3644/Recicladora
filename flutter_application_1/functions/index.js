const {setGlobalOptions} = require("firebase-functions/v2");
const {onDocumentCreated, onDocumentUpdated} = require("firebase-functions/v2/firestore");
const logger = require("firebase-functions/logger");
const admin = require("firebase-admin");

admin.initializeApp();

// Configuración de rendimiento (Máximo 10 instancias para ahorrar)
setGlobalOptions({maxInstances: 10});

/**
 * 1. TU FUNCIÓN ADAPTADA: Notifica al operador cuando su reporte es marcado como visto.
 * Busca el token FCM comparando el nombre del operador en la colección 'usuarios'.
 */
exports.notificarReporteRevisado = onDocumentUpdated("reportes/{reporteId}", async (event) => {
    const antes = event.data.before.data();
    const despues = event.data.after.data();

    // Solo actuar si visto pasó de false → true
    if (antes.visto === true || despues.visto !== true) return null;

    const nombreOperador = despues.operador; // nombre guardado en el reporte
    const reporteId = event.params.reporteId;

    // Buscar el token FCM del operador en la colección usuarios
    const usuariosSnap = await admin.firestore()
        .collection("usuarios")
        .where("nombre", "==", nombreOperador)
        .limit(1)
        .get();

    if (usuariosSnap.empty) {
        logger.info(`No se encontró usuario para operador: ${nombreOperador}`);
        return null;
    }

    const usuarioData = usuariosSnap.docs[0].data();
    const fcmToken = usuarioData.fcmToken || usuarioData.fcm_token; // Soporta ambos nombres de campo

    if (!fcmToken) {
        logger.info(`El operador ${nombreOperador} no tiene fcmToken registrado`);
        return null;
    }

    const message = {
        token: fcmToken,
        notification: {
            title: "✅ Tu reporte fue revisado",
            body: "El administrador ya revisó tu reporte.",
        },

android: {
            priority: "high",
            ttl: 86400000, 
            directBootOk: true, 
            notification: {
                color: "#10B981",
                channelId: "admin_notificaciones", // OJO: Usa el que tienes en el Manifest
                clickAction: "FLUTTER_NOTIFICATION_CLICK",
                defaultVibrateTimings: true,
                defaultSound: true,
            },
            },

        android: {
            priority: "high",
            notification: {
                color: "#10B981",
                channelId: "reportes_revisados", // Coincide con tu AndroidManifest
                clickAction: "FLUTTER_NOTIFICATION_CLICK",
            },
        },
        apns: {
            payload: {
                aps: {
                    sound: "default",
                    badge: 1,
                },
            },
        },
        data: {
            reporteId: reporteId,
            tipo: "reporte_revisado",
        },
    };

    try {
        await admin.messaging().send(message);
        logger.info(`Notificación enviada a ${nombreOperador}`);
    } catch (err) {
        logger.error("Error enviando notificación FCM:", err);
    }

    return null;
});

/**
 * 2. FUNCIÓN COMPAÑERO: Notifica a los ADMINS sobre nuevos reportes.
 */
exports.sendNotificationOnReport = onDocumentCreated("reportes/{reportId}", async (event) => {
    const reportData = event.data.data();
    const operador = reportData.operador || "Operador";

    const message = {
        topic: "admins",
        notification: {
            title: `Nuevo reporte de ${operador}`,
            body: `${operador} ha enviado un reporte`,
        },
        data: {
            screen: "ListaIncidentesAdmin",
        },
    };

    try {
        await admin.messaging().send(message);
        logger.info("Notificación de nuevo reporte enviada al tema 'admins'");
    } catch (error) {
        logger.error("Error en sendNotificationOnReport:", error);
    }
});

/**
 * 3. FUNCIÓN COMPAÑERO: Notificaciones masivas desde la colección 'notificaciones'.
 */
exports.sendPushOnAdminNotification = onDocumentCreated("notificaciones/{notificacionId}", async (event) => {
    const notificacion = event.data.data() || {};
    const mensaje = (notificacion.mensaje || "").toString().trim();
    if (!mensaje) return;

    const destinatarios = await _obtenerDestinatarios(notificacion);
    const tokens = [...new Set(
        destinatarios
            .map((doc) => (doc.data().fcmToken || doc.data().fcm_token || "").toString().trim())
            .filter((t) => t.length > 0)
    )];

    if (!tokens.length) return;

    const payload = {
        notification: { title: "Mensaje de administración", body: mensaje },
        android: { priority: "high", notification: { channelId: "reportes_revisados" } },
    };

    try {
        await admin.messaging().sendEachForMulticast({ tokens, ...payload });
        logger.info("Push masivo enviado");
    } catch (error) {
        logger.error("Error en sendPushOnAdminNotification:", error);
    }
});

// --- HELPER PARA DESTINATARIOS ---
async function _obtenerDestinatarios(notificacion) {
    const usuariosRef = admin.firestore().collection("usuarios");
    const tipo = notificacion.destinoTipo || "todos";

    if (tipo === "individual") {
        const doc = await usuariosRef.doc(notificacion.destinatarioDocId).get();
        return doc.exists ? [doc] : [];
    }
    if (tipo === "rol") {
        const snap = await usuariosRef.where("rol", "==", notificacion.destinatarioRol).get();
        return snap.docs;
    }
    const snap = await usuariosRef.where("rol", "in", ["operador", "trabajador"]).get();
    return snap.docs;
}