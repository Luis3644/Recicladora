import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';

class AdminNotificacionesScreen extends StatefulWidget {
  final String adminNombre;

  const AdminNotificacionesScreen({super.key, required this.adminNombre});

  @override
  State<AdminNotificacionesScreen> createState() =>
      _AdminNotificacionesScreenState();
}

class _AdminNotificacionesScreenState extends State<AdminNotificacionesScreen> {
  final TextEditingController _mensajeController = TextEditingController();

  bool _enviando = false;
  String _modoEnvio = 'todos';
  String? _destinatarioDocId;
  String _destinatarioRol = 'operador';

  @override
  void dispose() {
    _mensajeController.dispose();
    super.dispose();
  }

  String _resumenDestino(Map<String, dynamic> data) {
    final tipo = data['destinoTipo']?.toString() ?? '';
    if (tipo == 'todos') return 'Para todos (operadores y trabajadores)';
    if (tipo == 'rol') {
      final rol = data['destinatarioRol']?.toString() ?? 'rol';
      return 'Para rol: $rol';
    }
    if (tipo == 'individual') {
      final nombre = data['destinatarioNombre']?.toString() ?? 'usuario';
      final rol = data['destinatarioRol']?.toString() ?? 'rol';
      return 'Individual: $nombre ($rol)';
    }
    return 'Destino no especificado';
  }

  String _fechaCorta(Timestamp? ts) {
    if (ts == null) return 'Ahora';
    final dt = ts.toDate();
    final hh = dt.hour.toString().padLeft(2, '0');
    final mm = dt.minute.toString().padLeft(2, '0');
    return '${dt.day}/${dt.month}/${dt.year} $hh:$mm';
  }

  Future<void> _enviarNotificacion(
    List<QueryDocumentSnapshot<Map<String, dynamic>>> usuarios,
  ) async {
    final mensaje = _mensajeController.text.trim();
    if (mensaje.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Escribe un mensaje para enviar.')),
      );
      return;
    }

    if (_modoEnvio == 'individual' &&
        (_destinatarioDocId == null || _destinatarioDocId!.isEmpty)) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Selecciona un destinatario individual.')),
      );
      return;
    }

    if (_modoEnvio == 'rol' && _destinatarioRol.trim().isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Selecciona el rol para envío masivo.')),
      );
      return;
    }

    setState(() => _enviando = true);

    try {
      final seleccionado = _modoEnvio == 'individual'
          ? usuarios.firstWhere((u) => u.id == _destinatarioDocId)
          : null;

      await FirebaseFirestore.instance.collection('notificaciones').add({
        'mensaje': mensaje,
        'creadoEn': FieldValue.serverTimestamp(),
        'enviadoPor': widget.adminNombre.isEmpty
            ? 'Administración'
            : widget.adminNombre,
        'destinoTipo': _modoEnvio,
        'paraTodos': _modoEnvio == 'todos',
        'destinatarioDocId': seleccionado?.id ?? '',
        'destinatarioNombre': seleccionado?.data()['nombre']?.toString() ?? '',
        'destinatarioRol': _modoEnvio == 'rol'
            ? _destinatarioRol
            : (seleccionado?.data()['rol']?.toString() ?? ''),
        'leidoPor': <String, bool>{},
      });

      _mensajeController.clear();
      if (!mounted) return;

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            _modoEnvio == 'todos'
                ? 'Notificación enviada a operadores y trabajadores.'
                : (_modoEnvio == 'rol'
                      ? 'Notificación enviada a $_destinatarioRol.'
                      : 'Notificación enviada al usuario seleccionado.'),
          ),
          backgroundColor: const Color(0xFF16A34A),
        ),
      );
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('No se pudo enviar la notificación: $e'),
          backgroundColor: const Color(0xFFDC2626),
        ),
      );
    } finally {
      if (mounted) setState(() => _enviando = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF8FAFC),
      appBar: AppBar(
        title: const Text('Notificaciones a personal'),
        backgroundColor: const Color(0xFF0F172A),
        foregroundColor: Colors.white,
      ),
      body: StreamBuilder<QuerySnapshot<Map<String, dynamic>>>(
        stream: FirebaseFirestore.instance
            .collection('usuarios')
            .where('rol', whereIn: const ['operador', 'trabajador'])
            .snapshots(),
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) {
            return const Center(child: CircularProgressIndicator());
          }

          if (snapshot.hasError) {
            return const Center(
              child: Text('No se pudieron cargar los usuarios.'),
            );
          }

          final usuarios = snapshot.data?.docs ?? [];

          return ListView(
            padding: const EdgeInsets.all(16),
            children: [
              Container(
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(16),
                  border: Border.all(color: const Color(0xFFE2E8F0)),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text(
                      'Destino del mensaje',
                      style: TextStyle(
                        fontSize: 15,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                    const SizedBox(height: 10),
                    SegmentedButton<String>(
                      segments: const [
                        ButtonSegment(
                          value: 'todos',
                          icon: Icon(Icons.groups_rounded),
                          label: Text('Todos'),
                        ),
                        ButtonSegment(
                          value: 'rol',
                          icon: Icon(Icons.badge_rounded),
                          label: Text('Por rol'),
                        ),
                        ButtonSegment(
                          value: 'individual',
                          icon: Icon(Icons.person_pin_rounded),
                          label: Text('Individual'),
                        ),
                      ],
                      selected: {_modoEnvio},
                      onSelectionChanged: (value) {
                        setState(() {
                          _modoEnvio = value.first;
                          if (_modoEnvio != 'individual') {
                            _destinatarioDocId = null;
                          }
                        });
                      },
                    ),
                    if (_modoEnvio == 'individual') ...[
                      const SizedBox(height: 12),
                      DropdownButtonFormField<String>(
                        isExpanded: true,
                        value: _destinatarioDocId,
                        decoration: InputDecoration(
                          labelText: 'Selecciona destinatario',
                          border: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(12),
                          ),
                        ),
                        items: usuarios.map((doc) {
                          final data = doc.data();
                          final nombre =
                              data['nombre']?.toString() ?? 'Sin nombre';
                          final rol = data['rol']?.toString() ?? 'sin rol';
                          return DropdownMenuItem(
                            value: doc.id,
                            child: Text('$nombre ($rol)'),
                          );
                        }).toList(),
                        onChanged: (value) {
                          setState(() => _destinatarioDocId = value);
                        },
                      ),
                    ],
                    if (_modoEnvio == 'rol') ...[
                      const SizedBox(height: 12),
                      DropdownButtonFormField<String>(
                        value: _destinatarioRol,
                        decoration: InputDecoration(
                          labelText: 'Rol destino',
                          border: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(12),
                          ),
                        ),
                        items: const [
                          DropdownMenuItem(
                            value: 'operador',
                            child: Text('Operadores'),
                          ),
                          DropdownMenuItem(
                            value: 'trabajador',
                            child: Text('Trabajadores'),
                          ),
                        ],
                        onChanged: (value) {
                          if (value == null) return;
                          setState(() => _destinatarioRol = value);
                        },
                      ),
                    ],
                  ],
                ),
              ),
              const SizedBox(height: 14),
              Container(
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(16),
                  border: Border.all(color: const Color(0xFFE2E8F0)),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text(
                      'Mensaje',
                      style: TextStyle(
                        fontSize: 15,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                    const SizedBox(height: 10),
                    TextField(
                      controller: _mensajeController,
                      maxLines: 5,
                      decoration: InputDecoration(
                        hintText:
                            'Ejemplo: Recuerden usar equipo de seguridad completo antes de salir a ruta.',
                        border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(12),
                        ),
                      ),
                    ),
                    const SizedBox(height: 14),
                    SizedBox(
                      width: double.infinity,
                      child: FilledButton.icon(
                        onPressed: _enviando
                            ? null
                            : () => _enviarNotificacion(usuarios),
                        icon: _enviando
                            ? const SizedBox(
                                width: 18,
                                height: 18,
                                child: CircularProgressIndicator(
                                  strokeWidth: 2,
                                ),
                              )
                            : const Icon(Icons.send_rounded),
                        label: Text(
                          _modoEnvio == 'todos'
                              ? 'Enviar a operadores y trabajadores'
                              : (_modoEnvio == 'rol'
                                    ? 'Enviar a rol seleccionado'
                                    : 'Enviar notificación individual'),
                        ),
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 14),
              Container(
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(16),
                  border: Border.all(color: const Color(0xFFE2E8F0)),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text(
                      'Historial enviado',
                      style: TextStyle(fontSize: 15, fontWeight: FontWeight.w700),
                    ),
                    const SizedBox(height: 10),
                    StreamBuilder<QuerySnapshot<Map<String, dynamic>>>(
                      stream: FirebaseFirestore.instance
                          .collection('notificaciones')
                          .orderBy('creadoEn', descending: true)
                          .limit(80)
                          .snapshots(),
                      builder: (context, historySnapshot) {
                        if (historySnapshot.connectionState ==
                            ConnectionState.waiting) {
                          return const Padding(
                            padding: EdgeInsets.symmetric(vertical: 14),
                            child: Center(child: CircularProgressIndicator()),
                          );
                        }

                        if (historySnapshot.hasError) {
                          return const Padding(
                            padding: EdgeInsets.symmetric(vertical: 10),
                            child: Text('No se pudo cargar el historial.'),
                          );
                        }

                        final docs = historySnapshot.data?.docs ?? [];
                        final historial = docs.where((d) {
                          final data = d.data();
                          final enviadoPor = data['enviadoPor']?.toString() ?? '';
                          if (widget.adminNombre.trim().isEmpty) return true;
                          return enviadoPor == widget.adminNombre;
                        }).toList();

                        if (historial.isEmpty) {
                          return const Padding(
                            padding: EdgeInsets.symmetric(vertical: 12),
                            child: Text('Aún no has enviado notificaciones.'),
                          );
                        }

                        return ListView.separated(
                          shrinkWrap: true,
                          physics: const NeverScrollableScrollPhysics(),
                          itemCount: historial.length,
                          separatorBuilder: (_, __) =>
                              const SizedBox(height: 8),
                          itemBuilder: (context, index) {
                            final data = historial[index].data();
                            final mensaje =
                                data['mensaje']?.toString() ?? 'Sin mensaje';
                            final creadoEn = data['creadoEn'] as Timestamp?;

                            return Container(
                              padding: const EdgeInsets.all(12),
                              decoration: BoxDecoration(
                                borderRadius: BorderRadius.circular(12),
                                color: const Color(0xFFF8FAFC),
                                border: Border.all(
                                  color: const Color(0xFFCBD5E1),
                                ),
                              ),
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Row(
                                    children: [
                                      const Icon(
                                        Icons.history_rounded,
                                        size: 16,
                                        color: Color(0xFF334155),
                                      ),
                                      const SizedBox(width: 6),
                                      Expanded(
                                        child: Text(
                                          _resumenDestino(data),
                                          style: const TextStyle(
                                            fontSize: 12,
                                            fontWeight: FontWeight.w700,
                                            color: Color(0xFF0F172A),
                                          ),
                                          maxLines: 1,
                                          overflow: TextOverflow.ellipsis,
                                        ),
                                      ),
                                      Text(
                                        _fechaCorta(creadoEn),
                                        style: const TextStyle(
                                          fontSize: 11,
                                          color: Color(0xFF64748B),
                                        ),
                                      ),
                                    ],
                                  ),
                                  const SizedBox(height: 7),
                                  Text(
                                    mensaje,
                                    style: const TextStyle(
                                      fontSize: 13.5,
                                      color: Color(0xFF0F172A),
                                      height: 1.28,
                                    ),
                                  ),
                                ],
                              ),
                            );
                          },
                        );
                      },
                    ),
                  ],
                ),
              ),
            ],
          );
        },
      ),
    );
  }
}
