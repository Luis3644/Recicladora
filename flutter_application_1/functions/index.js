/**
 * Import function triggers from their respective submodules:
 *
 * const {onCall} = require("firebase-functions/v2/https");
 * const {onDocumentWritten} = require("firebase-functions/v2/firestore");
 *
 * See a full list of supported triggers at https://firebase.google.com/docs/functions
 */

const {setGlobalOptions} = require("firebase-functions");
const {onRequest} = require("firebase-functions/https");
const logger = require("firebase-functions/logger");

// For cost control, you can set the maximum number of containers that can be
// running at the same time. This helps mitigate the impact of unexpected
// traffic spikes by instead downgrading performance. This limit is a
// per-function limit. You can override the limit for each function using the
// `maxInstances` option in the function's options, e.g.
// `onRequest({ maxInstances: 5 }, (req, res) => { ... })`.
// NOTE: setGlobalOptions does not apply to functions using the v1 API. V1
// functions should each use functions.runWith({ maxInstances: 10 }) instead.
// In the v1 API, each function can only serve one request per container, so
// this will be the maximum concurrent request count.
setGlobalOptions({ maxInstances: 10 });

// Create and deploy your first functions
// https://firebase.google.com/docs/functions/get-started

// exports.helloWorld = onRequest((request, response) => {
//   logger.info("Hello logs!", {structuredData: true});
//   response.send("Hello from Firebase!");
// });

const functions = require('firebase-functions');
const admin = require('firebase-admin');
admin.initializeApp();

exports.sendNotificationOnReport = functions.firestore
  .document('reportes/{reportId}')
  .onCreate(async (snap, context) => {
    const reportData = snap.data();
    const operador = reportData.operador || 'Operador';

    const message = {
      topic: 'admins',
      notification: {
        title: `Nuevo reporte de ${operador}`,
        body: `${operador} ha enviado un reporte`,
      },
      data: {
        screen: 'ListaIncidentesAdmin',
      },
    };

    try {
      await admin.messaging().send(message);
      console.log('Notificación enviada');
    } catch (error) {
      console.error('Error enviando notificación:', error);
    }
  });

function _crearPayloadNotificacion({title, body, data = {}}) {
  return {
    notification: {
      title,
      body,
    },
    data,
    android: {
      priority: 'high',
      notification: {
        channelId: 'admin_notificaciones',
      },
    },
    apns: {
      headers: {
        'apns-priority': '10',
      },
      payload: {
        aps: {
          sound: 'default',
        },
      },
    },
  };
}

async function _obtenerDestinatariosNotificacion(notificacion) {
  const usuariosRef = admin.firestore().collection('usuarios');
  const tipo = (notificacion.destinoTipo || 'todos').toString();

  if (tipo === 'individual') {
    const docId = (notificacion.destinatarioDocId || '').toString().trim();
    if (!docId) return [];

    const doc = await usuariosRef.doc(docId).get();
    if (!doc.exists) return [];
    return [doc];
  }

  if (tipo === 'rol') {
    const rol = (notificacion.destinatarioRol || '').toString().trim();
    if (!rol) return [];

    const snapshot = await usuariosRef.where('rol', '==', rol).get();
    return snapshot.docs;
  }

  const snapshot = await usuariosRef
      .where('rol', 'in', ['operador', 'trabajador'])
      .get();

  return snapshot.docs;
}

exports.sendPushOnAdminNotification = functions.firestore
    .document('notificaciones/{notificacionId}')
    .onCreate(async (snap) => {
      const notificacion = snap.data() || {};
      const mensaje = (notificacion.mensaje || '').toString().trim();

      if (!mensaje) {
        logger.warn('Notificación sin mensaje; se omite push', {
          notificacionId: snap.id,
        });
        return;
      }

      const enviadoPor =
        (notificacion.enviadoPor || 'Administracion').toString().trim() ||
        'Administracion';

      const destinatarios = await _obtenerDestinatariosNotificacion(notificacion);

      if (!destinatarios.length) {
        logger.info('Sin destinatarios para notificación push', {
          notificacionId: snap.id,
        });
        return;
      }

      const tokens = [...new Set(
        destinatarios
            .map((doc) => (doc.data().fcm_token || '').toString().trim())
            .filter((token) => token.length > 0),
      )];

      if (!tokens.length) {
        logger.info('Destinatarios sin token FCM; no se envía push', {
          notificacionId: snap.id,
          destinatarios: destinatarios.length,
        });
        return;
      }

      const payload = _crearPayloadNotificacion({
        title: 'Mensaje de administracion',
        body: mensaje,
        data: {
          type: 'admin_notificacion',
          notificacionId: snap.id,
          enviadoPor,
          title: 'Mensaje de administracion',
          body: mensaje,
          mensaje,
        },
      });

      const respuesta = await admin.messaging().sendEachForMulticast({
        tokens,
        ...payload,
      });

      const tokensInvalidos = [];
      respuesta.responses.forEach((item, index) => {
        if (item.success) return;
        const code = item.error && item.error.code ? item.error.code : '';
        if (
          code === 'messaging/registration-token-not-registered' ||
          code === 'messaging/invalid-registration-token'
        ) {
          tokensInvalidos.push(tokens[index]);
        }
      });

      if (tokensInvalidos.length) {
        const limpieza = destinatarios
            .filter((doc) => tokensInvalidos.includes((doc.data().fcm_token || '').toString().trim()))
            .map((doc) => doc.ref.set({fcm_token: ''}, {merge: true}));
        await Promise.all(limpieza);
      }

      logger.info('Push de notificación admin procesado', {
        notificacionId: snap.id,
        tokens: tokens.length,
        enviadas: respuesta.successCount,
        fallidas: respuesta.failureCount,
      });
    });
