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

bool _esEventoInicioSesion(Map<String, dynamic> data) {
  final tipo = data['tipo']?.toString().toLowerCase() ?? '';
  final mensaje = data['mensaje']?.toString().toLowerCase() ?? '';

  // Tipos explícitos que indican sesión/login
  if (tipo.contains('login') || tipo.contains('sesion') || tipo.contains('session')) return true;

  // Frases comunes en español (con y sin acento) - inicio de sesión, inicio/fin de jornada
  final patrones = [
    'ha iniciado sesión',
    'ha iniciado sesion',
    'inició sesión',
    'inicio de sesión',
    'inicio de sesion',
    'se ha conectado',
    'ha conectado',
    'se conectó',
    'se ha logueado',
    'logueado',
    'ha iniciado su jornada',
    'ha finalizado su jornada',
    'ha FINALIZADO su jornada',
  ];

  for (final p in patrones) {
    if (mensaje.contains(p)) return true;
  }

  return false;
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
          if (_esEventoInicioSesion(data)) return false; // ocultar eventos de inicio de sesión
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

  static const Color _primary = Color(0xFF0B1F3A);
  static const Color _secondary = Color(0xFF1D4ED8);
  static const Color _accent = Color(0xFF0891B2);
  static const Color _surface = Colors.white;
  static const Color _bg = Color(0xFFF4F7FB);
  static const Color _muted = Color(0xFF64748B);

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

  Future<void> _borrarTodasLasNotificaciones(
    List<QueryDocumentSnapshot<Map<String, dynamic>>> docs,
  ) async {
    final batch = FirebaseFirestore.instance.batch();
    for (final doc in docs) {
      final data = doc.data();
      final esParaUsuario = _esParaUsuarioNotificacion(
        data,
        rolUsuario: rolUsuario,
        nombreUsuario: nombreUsuario,
      );
      if (!esParaUsuario) continue;

      batch.delete(doc.reference);
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

  IconData _obtenerIcono(String? tipo) {
    switch (tipo) {
      case 'gasolina':
        return Icons.local_gas_station_rounded;
      case 'material':
        return Icons.inventory_2_rounded;
      case 'equipo':
        return Icons.engineering_rounded;
      case 'camion':
        return Icons.local_shipping_rounded;
      case 'operador':
        return Icons.person_search_rounded;
      default:
        return Icons.notifications_rounded;
    }
  }

  Color _obtenerColor(String? tipo) {
    switch (tipo) {
      case 'gasolina':
        return const Color(0xFFF59E0B);
      case 'material':
        return const Color(0xFF10B981);
      case 'equipo':
        return const Color(0xFF6366F1);
      case 'camion':
        return const Color(0xFFEF4444);
      case 'operador':
        return const Color(0xFF8B5CF6);
      default:
        return _secondary;
    }
  }

  BoxDecoration _cardNotificacion({required bool leida}) {
    return BoxDecoration(
      gradient: LinearGradient(
        colors: leida
            ? [_surface, const Color(0xFFF8FBFF)]
            : [const Color(0xFFEFF5FF), const Color(0xFFE6F8FF)],
        begin: Alignment.topLeft,
        end: Alignment.bottomRight,
      ),
      borderRadius: BorderRadius.circular(14),
      border: Border.all(
        color: leida
            ? const Color(0xFFD5DFEE)
            : _secondary.withValues(alpha: 0.35),
      ),
      boxShadow: [
        BoxShadow(
          color: _primary.withValues(alpha: 0.07),
          blurRadius: 12,
          offset: const Offset(0, 6),
        ),
      ],
    );
  }

  @override
  Widget build(BuildContext context) {
    final claveUsuario = _claveUsuarioNotificacion(
      rolUsuario: rolUsuario,
      nombreUsuario: nombreUsuario,
    );

    return Drawer(
      child: SafeArea(
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
                  child: Text('No se pudieron cargar las notificaciones.'),
                ),
              );
            }

            final docs = snapshot.data?.docs ?? [];
            final filtradas = docs.where((doc) {
              final data = doc.data();
              if (_esEventoInicioSesion(data)) return false; // ocultar eventos de inicio de sesión
              return _esParaUsuarioNotificacion(
                data,
                rolUsuario: rolUsuario,
                nombreUsuario: nombreUsuario,
              );
            }).toList();
            final noLeidas = filtradas.where((doc) {
              return !_estaLeidaPorUsuario(doc.data(), claveUsuario: claveUsuario);
            }).toList();

            return Stack(
              children: [
                Positioned(
                  top: -70,
                  right: -55,
                  child: Container(
                    width: 220,
                    height: 220,
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      color: _secondary.withValues(alpha: 0.09),
                    ),
                  ),
                ),
                Positioned(
                  bottom: -85,
                  left: -75,
                  child: Container(
                    width: 220,
                    height: 220,
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      color: _accent.withValues(alpha: 0.08),
                    ),
                  ),
                ),
                Column(
                  children: [
                    Container(
                      width: double.infinity,
                      padding: const EdgeInsets.fromLTRB(16, 14, 16, 13),
                      decoration: BoxDecoration(
                        gradient: const LinearGradient(
                          colors: [_primary, _secondary],
                          begin: Alignment.topLeft,
                          end: Alignment.bottomRight,
                        ),
                        boxShadow: [
                          BoxShadow(
                            color: _primary.withValues(alpha: 0.26),
                            blurRadius: 14,
                            offset: const Offset(0, 6),
                          ),
                        ],
                      ),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Row(
                            children: [
                              Container(
                                padding: const EdgeInsets.all(8),
                                decoration: BoxDecoration(
                                  color: Colors.white.withValues(alpha: 0.16),
                                  borderRadius: BorderRadius.circular(10),
                                ),
                                child: const Icon(
                                  Icons.notifications_active_rounded,
                                  color: Colors.white,
                                  size: 18,
                                ),
                              ),
                              const SizedBox(width: 10),
                              Expanded(
                                child: Text(
                                  'Notificaciones ${noLeidas.isEmpty ? '' : '(${noLeidas.length} nuevas)'}',
                                  style: const TextStyle(
                                    color: Colors.white,
                                    fontSize: 17,
                                    fontWeight: FontWeight.w800,
                                  ),
                                ),
                              ),
                            ],
                          ),
                          const SizedBox(height: 10),
                          Row(
                            children: [
                              Container(
                                padding: const EdgeInsets.symmetric(
                                  horizontal: 10,
                                  vertical: 5,
                                ),
                                decoration: BoxDecoration(
                                  color: Colors.white.withValues(alpha: 0.14),
                                  borderRadius: BorderRadius.circular(999),
                                  border: Border.all(
                                    color: Colors.white.withValues(alpha: 0.22),
                                  ),
                                ),
                                child: Text(
                                  'Total ${filtradas.length}',
                                  style: const TextStyle(
                                    color: Colors.white,
                                    fontWeight: FontWeight.w700,
                                    fontSize: 11.5,
                                  ),
                                ),
                              ),
                              const SizedBox(width: 8),
                              Container(
                                padding: const EdgeInsets.symmetric(
                                  horizontal: 10,
                                  vertical: 5,
                                ),
                                decoration: BoxDecoration(
                                  color: Colors.white.withValues(alpha: 0.14),
                                  borderRadius: BorderRadius.circular(999),
                                  border: Border.all(
                                    color: Colors.white.withValues(alpha: 0.22),
                                  ),
                                ),
                                child: Text(
                                  'Sin leer ${noLeidas.length}',
                                  style: const TextStyle(
                                    color: Colors.white,
                                    fontWeight: FontWeight.w700,
                                    fontSize: 11.5,
                                  ),
                                ),
                              ),
                              const Spacer(),
                              Tooltip(
                                message: 'Marcar todas como leídas',
                                child: IconButton(
                                  icon: const Icon(Icons.done_all_rounded, size: 18),
                                  color: Colors.white,
                                  onPressed: noLeidas.isEmpty
                                      ? null
                                      : () async {
                                          await _marcarTodasComoLeidas(docs);
                                        },
                                  style: IconButton.styleFrom(
                                    backgroundColor:
                                        Colors.white.withValues(alpha: 0.14),
                                    disabledBackgroundColor:
                                        Colors.white.withValues(alpha: 0.07),
                                    padding: const EdgeInsets.all(8),
                                  ),
                                ),
                              ),
                              const SizedBox(width: 8),
                              Tooltip(
                                message: 'Eliminar todas las notificaciones',
                                child: IconButton(
                                  icon: const Icon(Icons.delete_sweep_rounded, size: 18),
                                  color: Colors.white,
                                  onPressed: filtradas.isEmpty
                                      ? null
                                      : () async {
                                          final confirmar =
                                              await showDialog<bool>(
                                                    context: context,
                                                    builder: (_) => AlertDialog(
                                                      title: const Text(
                                                          'Eliminar todas las notificaciones'),
                                                      content: const Text(
                                                          '¿Estás seguro de que deseas eliminar todas tus notificaciones? Esta acción no se puede deshacer.'),
                                                      actions: [
                                                        TextButton(
                                                          onPressed: () =>
                                                              Navigator.of(
                                                                      context)
                                                                  .pop(false),
                                                          child: const Text(
                                                              'Cancelar'),
                                                        ),
                                                        FilledButton(
                                                          onPressed: () =>
                                                              Navigator.of(
                                                                      context)
                                                                  .pop(true),
                                                          style: FilledButton
                                                              .styleFrom(
                                                            backgroundColor:
                                                                const Color(
                                                                    0xFFDC2626),
                                                          ),
                                                          child: const Text(
                                                              'Eliminar'),
                                                        ),
                                                      ],
                                                    ),
                                                  ) ??
                                              false;
                                          if (confirmar) {
                                            await _borrarTodasLasNotificaciones(
                                                docs);
                                          }
                                        },
                                  style: IconButton.styleFrom(
                                    backgroundColor:
                                        Colors.white.withValues(alpha: 0.14),
                                    disabledBackgroundColor:
                                        Colors.white.withValues(alpha: 0.07),
                                    padding: const EdgeInsets.all(8),
                                  ),
                                ),
                              ),
                            ],
                          ),
                        ],
                      ),
                    ),
                    Expanded(
                      child: Container(
                        color: _bg,
                        child: filtradas.isEmpty
                            ? Center(
                                child: Padding(
                                  padding: const EdgeInsets.all(24),
                                  child: Container(
                                    padding: const EdgeInsets.all(18),
                                    decoration: BoxDecoration(
                                      color: _surface,
                                      borderRadius: BorderRadius.circular(16),
                                      border: Border.all(
                                        color: const Color(0xFFD5DFEE),
                                      ),
                                    ),
                                    child: const Column(
                                      mainAxisSize: MainAxisSize.min,
                                      children: [
                                        Icon(
                                          Icons.notifications_none_rounded,
                                          size: 36,
                                          color: Color(0xFF64748B),
                                        ),
                                        SizedBox(height: 10),
                                        Text(
                                          'No hay mensajes por ahora.',
                                          textAlign: TextAlign.center,
                                          style: TextStyle(
                                            fontWeight: FontWeight.w700,
                                            color: Color(0xFF1E293B),
                                          ),
                                        ),
                                        SizedBox(height: 4),
                                        Text(
                                          'Aquí verás avisos enviados por administración.',
                                          textAlign: TextAlign.center,
                                          style: TextStyle(
                                            color: Color(0xFF64748B),
                                            fontSize: 12.5,
                                          ),
                                        ),
                                      ],
                                    ),
                                  ),
                                ),
                              )
                            : ListView.separated(
                                padding: const EdgeInsets.fromLTRB(12, 12, 12, 16),
                                itemBuilder: (context, index) {
                                  final doc = filtradas[index];
                                  final data = doc.data();
                                  final mensaje =
                                      data['mensaje']?.toString() ?? 'Sin mensaje';
                                  final enviadoPor =
                                      data['enviadoPor']?.toString() ?? 'Administración';
                                  final creadoEn = data['creadoEn'] as Timestamp?;
                                  final leida = _estaLeidaPorUsuario(
                                    data,
                                    claveUsuario: claveUsuario,
                                  );

                                  return TweenAnimationBuilder<double>(
                                    tween: Tween(begin: 0, end: 1),
                                    duration: Duration(
                                      milliseconds: 280 + (index * 40),
                                    ),
                                    curve: Curves.easeOutCubic,
                                    builder: (context, value, child) {
                                      return Transform.translate(
                                        offset: Offset(0, 14 * (1 - value)),
                                        child: Opacity(opacity: value, child: child),
                                      );
                                    },
                                    child: InkWell(
                                      borderRadius: BorderRadius.circular(14),
                                      onTap: () async {
                                        if (!leida) {
                                          await _marcarComoLeida(doc);
                                        }
                                      },
                                      child: Container(
                                        padding: const EdgeInsets.all(12),
                                        decoration: _cardNotificacion(leida: leida),
                                        child: Column(
                                          crossAxisAlignment:
                                              CrossAxisAlignment.start,
                                          children: [
                                            Row(
                                              children: [
                                                Container(
                                                  padding:
                                                      const EdgeInsets.all(6),
                                                  decoration: BoxDecoration(
                                                    color: _secondary.withValues(
                                                      alpha: leida ? 0.10 : 0.20,
                                                    ),
                                                    borderRadius:
                                                        BorderRadius.circular(9),
                                                  ),
                                                  child: Icon(
                                                    _obtenerIcono(data['tipo']),
                                                    color: _obtenerColor(
                                                        data['tipo']),
                                                    size: 16,
                                                  ),
                                                ),
                                                const SizedBox(width: 8),
                                                Expanded(
                                                  child: Text(
                                                    data['tipo'] != null
                                                        ? 'SISTEMA: ${data['enviadoPor']}'
                                                        : 'Admin: $enviadoPor',
                                                    maxLines: 1,
                                                    overflow:
                                                        TextOverflow.ellipsis,
                                                    style: const TextStyle(
                                                      fontWeight: FontWeight.w800,
                                                      fontSize: 12.5,
                                                      color: Color(0xFF0F172A),
                                                    ),
                                                  ),
                                                ),
                                                Container(
                                                  padding:
                                                      const EdgeInsets.symmetric(
                                                    horizontal: 8,
                                                    vertical: 3,
                                                  ),
                                                  decoration: BoxDecoration(
                                                    color: Colors.white
                                                        .withValues(alpha: 0.72),
                                                    borderRadius:
                                                        BorderRadius.circular(999),
                                                    border: Border.all(
                                                      color: const Color(0xFFD6E0EF),
                                                    ),
                                                  ),
                                                  child: Text(
                                                    _fechaCorta(creadoEn),
                                                    style: const TextStyle(
                                                      color: _muted,
                                                      fontSize: 10.8,
                                                      fontWeight: FontWeight.w600,
                                                    ),
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
                                                height: 1.32,
                                              ),
                                            ),
                                          ],
                                        ),
                                      ),
                                    ),
                                  );
                                },
                                separatorBuilder: (_, __) =>
                                    const SizedBox(height: 8),
                                itemCount: filtradas.length,
                              ),
                      ),
                    ),
                  ],
                ),
              ],
            );
          },
        ),
      ),
    );
  }
}
