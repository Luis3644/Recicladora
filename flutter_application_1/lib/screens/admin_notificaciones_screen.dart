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

  static const Color _primary = Color(0xFF0B1F3A);
  static const Color _secondary = Color(0xFF1D4ED8);
  static const Color _accent = Color(0xFF0891B2);
  static const Color _bg = Color(0xFFF4F7FB);
  static const Color _card = Colors.white;
  static const Color _textMuted = Color(0xFF64748B);

  bool _enviando = false;
  String _modoEnvio = 'todos';
  String? _destinatarioDocId;
  String _destinatarioRol = 'operador';
  bool _entradaVisible = false;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      setState(() => _entradaVisible = true);
    });
  }

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

  String _etiquetaDestino() {
    if (_modoEnvio == 'todos') return 'Operadores y trabajadores';
    if (_modoEnvio == 'rol') {
      return _destinatarioRol == 'operador'
          ? 'Operadores'
          : 'Trabajadores';
    }
    return 'Usuario individual';
  }

  BoxDecoration _cardDecoration() {
    return BoxDecoration(
      color: _card,
      borderRadius: BorderRadius.circular(18),
      border: Border.all(color: const Color(0xFFDCE5F2)),
      boxShadow: [
        BoxShadow(
          color: _primary.withValues(alpha: 0.06),
          blurRadius: 18,
          offset: const Offset(0, 8),
        ),
      ],
    );
  }

  InputDecoration _inputDecoration({required String label}) {
    return InputDecoration(
      labelText: label,
      labelStyle: const TextStyle(color: _textMuted),
      filled: true,
      fillColor: const Color(0xFFF8FAFF),
      contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
      border: OutlineInputBorder(
        borderRadius: BorderRadius.circular(12),
        borderSide: const BorderSide(color: Color(0xFFD1DBEB)),
      ),
      enabledBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(12),
        borderSide: const BorderSide(color: Color(0xFFD1DBEB)),
      ),
      focusedBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(12),
        borderSide: const BorderSide(color: _secondary, width: 1.4),
      ),
    );
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
      backgroundColor: _bg,
      appBar: AppBar(
        title: const Text(
          'Notificaciones a personal',
          style: TextStyle(fontWeight: FontWeight.w700, letterSpacing: 0.2),
        ),
        backgroundColor: Colors.transparent,
        elevation: 0,
        foregroundColor: Colors.white,
        flexibleSpace: Container(
          decoration: BoxDecoration(
            gradient: const LinearGradient(
              colors: [_primary, _secondary],
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
            ),
            boxShadow: [
              BoxShadow(
                color: _primary.withValues(alpha: 0.35),
                blurRadius: 20,
                offset: const Offset(0, 10),
              ),
            ],
          ),
        ),
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

          return Stack(
            children: [
              Positioned(
                top: -80,
                right: -50,
                child: Container(
                  width: 230,
                  height: 230,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    color: _secondary.withValues(alpha: 0.10),
                  ),
                ),
              ),
              Positioned(
                bottom: -90,
                left: -80,
                child: Container(
                  width: 250,
                  height: 250,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    color: _accent.withValues(alpha: 0.10),
                  ),
                ),
              ),
              ListView(
                padding: const EdgeInsets.fromLTRB(16, 16, 16, 22),
                children: [
                  AnimatedOpacity(
                    opacity: _entradaVisible ? 1 : 0,
                    duration: const Duration(milliseconds: 500),
                    child: Container(
                      padding: const EdgeInsets.all(14),
                      decoration: BoxDecoration(
                        gradient: LinearGradient(
                          colors: [
                            _card,
                            const Color(0xFFEFF4FF).withValues(alpha: 0.95),
                          ],
                          begin: Alignment.topLeft,
                          end: Alignment.bottomRight,
                        ),
                        borderRadius: BorderRadius.circular(16),
                        border: Border.all(color: _secondary.withValues(alpha: 0.18)),
                        boxShadow: [
                          BoxShadow(
                            color: _primary.withValues(alpha: 0.06),
                            blurRadius: 14,
                            offset: const Offset(0, 8),
                          ),
                        ],
                      ),
                      child: Row(
                        children: [
                          Container(
                            padding: const EdgeInsets.all(10),
                            decoration: BoxDecoration(
                              gradient: LinearGradient(
                                colors: [
                                  _secondary.withValues(alpha: 0.18),
                                  _accent.withValues(alpha: 0.12),
                                ],
                              ),
                              borderRadius: BorderRadius.circular(12),
                            ),
                            child: const Icon(
                              Icons.campaign_rounded,
                              color: _primary,
                            ),
                          ),
                          const SizedBox(width: 10),
                          const Expanded(
                            child: Text(
                              'Comunicación centralizada para el personal operativo.',
                              style: TextStyle(
                                color: _primary,
                                fontWeight: FontWeight.w700,
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                  const SizedBox(height: 14),
                  TweenAnimationBuilder<double>(
                    tween: Tween(begin: 0, end: _entradaVisible ? 1 : 0),
                    duration: const Duration(milliseconds: 520),
                    curve: Curves.easeOutCubic,
                    builder: (context, value, child) {
                      return Transform.translate(
                        offset: Offset(0, 16 * (1 - value)),
                        child: Opacity(opacity: value, child: child),
                      );
                    },
                    child: Container(
                      padding: const EdgeInsets.all(16),
                      decoration: _cardDecoration(),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          const Text(
                            'Destino del mensaje',
                            style: TextStyle(
                              fontSize: 16,
                              fontWeight: FontWeight.w800,
                              color: _primary,
                            ),
                          ),
                          const SizedBox(height: 4),
                          Text(
                            'Selecciona el alcance de tu comunicación.',
                            style: TextStyle(
                              fontSize: 12.5,
                              color: _textMuted.withValues(alpha: 0.95),
                            ),
                          ),
                          const SizedBox(height: 12),
                          SegmentedButton<String>(
                            style: ButtonStyle(
                              backgroundColor: WidgetStateProperty.resolveWith((states) {
                                if (states.contains(WidgetState.selected)) {
                                  return _secondary.withValues(alpha: 0.14);
                                }
                                return const Color(0xFFF7FAFF);
                              }),
                              foregroundColor: WidgetStateProperty.resolveWith((states) {
                                if (states.contains(WidgetState.selected)) {
                                  return _primary;
                                }
                                return _textMuted;
                              }),
                            ),
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
                          const SizedBox(height: 12),
                          Wrap(
                            spacing: 8,
                            runSpacing: 8,
                            children: [
                              Container(
                                padding: const EdgeInsets.symmetric(
                                  horizontal: 10,
                                  vertical: 6,
                                ),
                                decoration: BoxDecoration(
                                  color: _secondary.withValues(alpha: 0.10),
                                  borderRadius: BorderRadius.circular(999),
                                  border: Border.all(
                                    color: _secondary.withValues(alpha: 0.22),
                                  ),
                                ),
                                child: Text(
                                  'Destino: ${_etiquetaDestino()}',
                                  style: const TextStyle(
                                    color: _primary,
                                    fontWeight: FontWeight.w700,
                                    fontSize: 12,
                                  ),
                                ),
                              ),
                            ],
                          ),
                          if (_modoEnvio == 'individual') ...[
                            const SizedBox(height: 12),
                            DropdownButtonFormField<String>(
                              isExpanded: true,
                              value: _destinatarioDocId,
                              decoration:
                                  _inputDecoration(label: 'Selecciona destinatario'),
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
                              decoration: _inputDecoration(label: 'Rol destino'),
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
                  ),
                  const SizedBox(height: 14),
                  TweenAnimationBuilder<double>(
                    tween: Tween(begin: 0, end: _entradaVisible ? 1 : 0),
                    duration: const Duration(milliseconds: 620),
                    curve: Curves.easeOutCubic,
                    builder: (context, value, child) {
                      return Transform.translate(
                        offset: Offset(0, 18 * (1 - value)),
                        child: Opacity(opacity: value, child: child),
                      );
                    },
                    child: Container(
                      padding: const EdgeInsets.all(16),
                      decoration: _cardDecoration(),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          const Text(
                            'Mensaje',
                            style: TextStyle(
                              fontSize: 16,
                              fontWeight: FontWeight.w800,
                              color: _primary,
                            ),
                          ),
                          const SizedBox(height: 10),
                          TextField(
                            controller: _mensajeController,
                            maxLines: 5,
                            decoration: _inputDecoration(
                              label: 'Escribe el mensaje a enviar',
                            ).copyWith(
                              hintText:
                                  'Ejemplo: Recuerden usar equipo de seguridad completo antes de salir a ruta.',
                            ),
                          ),
                          const SizedBox(height: 14),
                          SizedBox(
                            width: double.infinity,
                            child: FilledButton.icon(
                              style: FilledButton.styleFrom(
                                backgroundColor: _secondary,
                                foregroundColor: Colors.white,
                                elevation: 0,
                                padding:
                                    const EdgeInsets.symmetric(vertical: 13.5),
                                shape: RoundedRectangleBorder(
                                  borderRadius: BorderRadius.circular(12),
                                ),
                              ),
                              onPressed: _enviando
                                  ? null
                                  : () => _enviarNotificacion(usuarios),
                              icon: _enviando
                                  ? const SizedBox(
                                      width: 18,
                                      height: 18,
                                      child: CircularProgressIndicator(
                                        strokeWidth: 2,
                                        color: Colors.white,
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
                  ),
                  const SizedBox(height: 14),
                  Container(
                    padding: const EdgeInsets.all(16),
                    decoration: _cardDecoration(),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Text(
                          'Historial enviado',
                          style: TextStyle(
                            fontSize: 16,
                            fontWeight: FontWeight.w800,
                            color: _primary,
                          ),
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
                                    color: const Color(0xFFF7FAFF),
                                    border: Border.all(
                                      color: const Color(0xFFD8E3F3),
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
              ),
            ],
          );
        },
      ),
    );
  }
}
