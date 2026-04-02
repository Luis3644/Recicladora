import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';

String _claveUsuarioNotificacion({
  required String rolUsuario,
  required String nombreUsuario,
}) {
  return '$rolUsuario::$nombreUsuario';
}

bool _esParaUsuarioNotificacion(
  Map<String, dynamic> data, {
  required String rolUsuario,
  required String nombreUsuario,
}) {
  if (data['paraTodos'] == true) return true;

  final destinoTipo = data['destinoTipo']?.toString() ?? '';
  final destinoRol = data['destinatarioRol']?.toString() ?? '';
  final destinoNombre = data['destinatarioNombre']?.toString() ?? '';

  if (destinoTipo == 'individual') {
    return destinoRol == rolUsuario && destinoNombre == nombreUsuario;
  }

  if (destinoTipo == 'rol') {
    return destinoRol == rolUsuario;
  }

  return false;
}

bool _estaLeidaPorUsuario(
  Map<String, dynamic> data, {
  required String claveUsuario,
}) {
  final leidoPor = data['leidoPor'];
  if (leidoPor is! Map) return false;
  return leidoPor[claveUsuario] == true;
}

class NotificacionesBellButton extends StatelessWidget {
  final String rolUsuario;
  final String nombreUsuario;
  final VoidCallback onPressed;

  const NotificacionesBellButton({
    super.key,
    required this.rolUsuario,
    required this.nombreUsuario,
    required this.onPressed,
  });

  @override
  Widget build(BuildContext context) {
    final claveUsuario = _claveUsuarioNotificacion(
      rolUsuario: rolUsuario,
      nombreUsuario: nombreUsuario,
    );

    return StreamBuilder<QuerySnapshot<Map<String, dynamic>>>(
      stream: FirebaseFirestore.instance
          .collection('notificaciones')
          .orderBy('creadoEn', descending: true)
          .limit(120)
          .snapshots(),
      builder: (context, snapshot) {
        final docs = snapshot.data?.docs ?? [];
        final noLeidas = docs.where((doc) {
          final data = doc.data();
          final esParaUsuario = _esParaUsuarioNotificacion(
            data,
            rolUsuario: rolUsuario,
            nombreUsuario: nombreUsuario,
          );
          if (!esParaUsuario) return false;
          return !_estaLeidaPorUsuario(data, claveUsuario: claveUsuario);
        }).length;

        return IconButton(
          tooltip: 'Notificaciones',
          onPressed: onPressed,
          icon: Stack(
            clipBehavior: Clip.none,
            children: [
              const Icon(Icons.notifications_none_rounded),
              if (noLeidas > 0)
                Positioned(
                  right: -6,
                  top: -6,
                  child: Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 5,
                      vertical: 1,
                    ),
                    decoration: BoxDecoration(
                      color: const Color(0xFFEF4444),
                      borderRadius: BorderRadius.circular(10),
                      border: Border.all(color: Colors.white, width: 1),
                    ),
                    child: Text(
                      noLeidas > 99 ? '99+' : '$noLeidas',
                      style: const TextStyle(
                        color: Colors.white,
                        fontSize: 10,
                        fontWeight: FontWeight.w800,
                      ),
                    ),
                  ),
                ),
            ],
          ),
        );
      },
    );
  }
}

class NotificacionesDrawer extends StatelessWidget {
  final String rolUsuario;
  final String nombreUsuario;

  const NotificacionesDrawer({
    super.key,
    required this.rolUsuario,
    required this.nombreUsuario,
  });

  Future<void> _marcarComoLeida(
    DocumentSnapshot<Map<String, dynamic>> doc,
  ) async {
    final claveUsuario = _claveUsuarioNotificacion(
      rolUsuario: rolUsuario,
      nombreUsuario: nombreUsuario,
    );

    await doc.reference.set({
      'leidoPor': {claveUsuario: true},
      'leidoEn': {claveUsuario: FieldValue.serverTimestamp()},
    }, SetOptions(merge: true));
  }

  Future<void> _marcarTodasComoLeidas(
    List<QueryDocumentSnapshot<Map<String, dynamic>>> docs,
  ) async {
    final claveUsuario = _claveUsuarioNotificacion(
      rolUsuario: rolUsuario,
      nombreUsuario: nombreUsuario,
    );

    final batch = FirebaseFirestore.instance.batch();
    for (final doc in docs) {
      final data = doc.data();
      final esParaUsuario = _esParaUsuarioNotificacion(
        data,
        rolUsuario: rolUsuario,
        nombreUsuario: nombreUsuario,
      );
      if (!esParaUsuario) continue;

      final leida = _estaLeidaPorUsuario(data, claveUsuario: claveUsuario);
      if (leida) continue;

      batch.set(doc.reference, {
        'leidoPor': {claveUsuario: true},
        'leidoEn': {claveUsuario: FieldValue.serverTimestamp()},
      }, SetOptions(merge: true));
    }

    await batch.commit();
  }

  String _fechaCorta(Timestamp? ts) {
    if (ts == null) return 'Ahora';
    final dt = ts.toDate();
    final hh = dt.hour.toString().padLeft(2, '0');
    final mm = dt.minute.toString().padLeft(2, '0');
    return '${dt.day}/${dt.month} $hh:$mm';
  }

  @override
  Widget build(BuildContext context) {
    final claveUsuario = _claveUsuarioNotificacion(
      rolUsuario: rolUsuario,
      nombreUsuario: nombreUsuario,
    );

    return Drawer(
      child: SafeArea(
        child: Column(
          children: [
            Expanded(
              child: StreamBuilder<QuerySnapshot<Map<String, dynamic>>>(
                stream: FirebaseFirestore.instance
                    .collection('notificaciones')
                    .orderBy('creadoEn', descending: true)
                    .limit(120)
                    .snapshots(),
                builder: (context, snapshot) {
                  if (snapshot.connectionState == ConnectionState.waiting) {
                    return const Center(child: CircularProgressIndicator());
                  }

                  if (snapshot.hasError) {
                    return const Center(
                      child: Padding(
                        padding: EdgeInsets.all(16),
                        child: Text(
                          'No se pudieron cargar las notificaciones.',
                        ),
                      ),
                    );
                  }

                  final docs = snapshot.data?.docs ?? [];
                  final filtradas = docs.where((doc) {
                    final data = doc.data();
                    return _esParaUsuarioNotificacion(
                      data,
                      rolUsuario: rolUsuario,
                      nombreUsuario: nombreUsuario,
                    );
                  }).toList();
                  final noLeidas = filtradas.where((doc) {
                    return !_estaLeidaPorUsuario(
                      doc.data(),
                      claveUsuario: claveUsuario,
                    );
                  }).toList();

                  return Column(
                    children: [
                      Container(
                        width: double.infinity,
                        padding: const EdgeInsets.fromLTRB(16, 14, 16, 12),
                        decoration: BoxDecoration(
                          color: const Color(
                            0xFF0F172A,
                          ).withValues(alpha: 0.96),
                        ),
                        child: Row(
                          children: [
                            const Icon(
                              Icons.notifications_active_rounded,
                              color: Colors.white,
                            ),
                            const SizedBox(width: 8),
                            Expanded(
                              child: Text(
                                'Notificaciones (${noLeidas.length} nuevas)',
                                style: const TextStyle(
                                  color: Colors.white,
                                  fontSize: 17,
                                  fontWeight: FontWeight.w700,
                                ),
                              ),
                            ),
                            TextButton(
                              onPressed: noLeidas.isEmpty
                                  ? null
                                  : () async {
                                      await _marcarTodasComoLeidas(docs);
                                    },
                              child: const Text(
                                'Marcar todo',
                                style: TextStyle(color: Colors.white),
                              ),
                            ),
                          ],
                        ),
                      ),
                      Expanded(
                        child: filtradas.isEmpty
                            ? const Center(
                                child: Padding(
                                  padding: EdgeInsets.all(16),
                                  child: Text(
                                    'No hay mensajes por ahora.\nAquí verás avisos de administración.',
                                    textAlign: TextAlign.center,
                                  ),
                                ),
                              )
                            : ListView.separated(
                                padding: const EdgeInsets.all(12),
                                itemBuilder: (context, index) {
                                  final doc = filtradas[index];
                                  final data = doc.data();
                                  final mensaje =
                                      data['mensaje']?.toString() ??
                                      'Sin mensaje';
                                  final enviadoPor =
                                      data['enviadoPor']?.toString() ??
                                      'Administración';
                                  final creadoEn =
                                      data['creadoEn'] as Timestamp?;
                                  final leida = _estaLeidaPorUsuario(
                                    data,
                                    claveUsuario: claveUsuario,
                                  );

                                  return InkWell(
                                    borderRadius: BorderRadius.circular(12),
                                    onTap: () async {
                                      if (!leida) {
                                        await _marcarComoLeida(doc);
                                      }
                                    },
                                    child: Container(
                                      padding: const EdgeInsets.all(12),
                                      decoration: BoxDecoration(
                                        color: leida
                                            ? Colors.white
                                            : const Color(0xFFEFF6FF),
                                        borderRadius: BorderRadius.circular(12),
                                        border: Border.all(
                                          color: leida
                                              ? const Color(0xFFCBD5E1)
                                              : const Color(0xFF93C5FD),
                                        ),
                                        boxShadow: [
                                          BoxShadow(
                                            color: Colors.black.withValues(
                                              alpha: 0.04,
                                            ),
                                            blurRadius: 8,
                                            offset: const Offset(0, 3),
                                          ),
                                        ],
                                      ),
                                      child: Column(
                                        crossAxisAlignment:
                                            CrossAxisAlignment.start,
                                        children: [
                                          Row(
                                            children: [
                                              Icon(
                                                leida
                                                    ? Icons
                                                          .mark_email_read_rounded
                                                    : Icons
                                                          .mark_email_unread_rounded,
                                                color: const Color(0xFF1D4ED8),
                                                size: 18,
                                              ),
                                              const SizedBox(width: 6),
                                              Expanded(
                                                child: Text(
                                                  'Admin: $enviadoPor',
                                                  maxLines: 1,
                                                  overflow:
                                                      TextOverflow.ellipsis,
                                                  style: const TextStyle(
                                                    fontWeight: FontWeight.w700,
                                                    fontSize: 12.5,
                                                  ),
                                                ),
                                              ),
                                              Text(
                                                _fechaCorta(creadoEn),
                                                style: const TextStyle(
                                                  color: Color(0xFF64748B),
                                                  fontSize: 11,
                                                ),
                                              ),
                                            ],
                                          ),
                                          const SizedBox(height: 8),
                                          Text(
                                            mensaje,
                                            style: const TextStyle(
                                              fontSize: 13.5,
                                              color: Color(0xFF0F172A),
                                              height: 1.3,
                                            ),
                                          ),
                                        ],
                                      ),
                                    ),
                                  );
                                },
                                separatorBuilder: (_, __) =>
                                    const SizedBox(height: 8),
                                itemCount: filtradas.length,
                              ),
                      ),
                    ],
                  );
                },
              ),
            ),
          ],
        ),
      ),
    );
  }
}
