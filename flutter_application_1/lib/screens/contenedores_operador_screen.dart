import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'widgets/menu_lateral.dart';
import 'widgets/notificaciones_drawer.dart';
import '../widgets/jornada_bottom_bar.dart';
import 'jornada_screen.dart';
import 'reporte_screen.dart';

class ContenedoresOperadorScreen extends StatefulWidget {
  final String? operador;
  final String? camion;
  final String? placas;

  const ContenedoresOperadorScreen({
    super.key,
    this.operador,
    this.camion,
    this.placas,
  });

  @override
  State<ContenedoresOperadorScreen> createState() =>
      _ContenedoresOperadorScreenState();
}

class _ContenedoresOperadorScreenState
    extends State<ContenedoresOperadorScreen>
    with SingleTickerProviderStateMixin {
  late AnimationController _pulseController;
  late Animation<double> _pulseScale;
  late Animation<double> _pulseOpacity;

  @override
  void initState() {
    super.initState();
    _pulseController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 800),
    )..repeat(reverse: true);

    _pulseScale = Tween<double>(begin: 1.0, end: 1.04).animate(
      CurvedAnimation(parent: _pulseController, curve: Curves.easeInOut),
    );

    _pulseOpacity = Tween<double>(begin: 0.5, end: 1.0).animate(
      CurvedAnimation(parent: _pulseController, curve: Curves.easeInOut),
    );
  }

  @override
  void dispose() {
    _pulseController.dispose();
    super.dispose();
  }

  // ─── Helpers ──────────────────────────────────────────────────────────────

  String _formatTimestamp(Timestamp? ts) {
    if (ts == null) return '—';
    final d = ts.toDate();
    return '${d.day.toString().padLeft(2, '0')}/${d.month.toString().padLeft(2, '0')} '
        '${d.hour.toString().padLeft(2, '0')}:${d.minute.toString().padLeft(2, '0')}';
  }

  Color _colorFor(String estado) {
    switch (estado) {
      case 'En proceso de llenado':
        return const Color(0xFFF59E0B);
      case 'Lleno':
        return const Color(0xFF10B981);
      case 'Fuera de servicio':
        return const Color(0xFFEF4444);
      default:
        return const Color(0xFF64748B);
    }
  }

  IconData _iconFor(String estado) {
    switch (estado) {
      case 'En proceso de llenado':
        return Icons.hourglass_top_rounded;
      case 'Lleno':
        return Icons.warning_rounded;
      case 'Fuera de servicio':
        return Icons.build_circle_rounded;
      default:
        return Icons.inventory_2_outlined;
    }
  }

  // ─── Diálogo recoger material ──────────────────────────────────────────────

  void _mostrarDialogoRecogerMaterial(
    BuildContext context,
    String contenedorId,
    Map<String, dynamic> data,
  ) {
    final cantidadController = TextEditingController();
    String unidad = 'minutos';

    showDialog(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setDialogState) => AlertDialog(
          shape:
              RoundedRectangleBorder(borderRadius: BorderRadius.circular(24)),
          title: const Row(
            children: [
              Icon(Icons.local_shipping_rounded,
                  color: Color(0xFF10B981), size: 28),
              SizedBox(width: 10),
              Expanded(
                child: Text(
                  'Recoger Material',
                  style: TextStyle(
                    fontWeight: FontWeight.w800,
                    fontSize: 18,
                    color: Color(0xFF0F172A),
                  ),
                ),
              ),
            ],
          ),
          content: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text(
                  '¿En cuánto tiempo pasarás por el material?',
                  style: TextStyle(
                    fontSize: 13,
                    color: Color(0xFF64748B),
                    height: 1.4,
                  ),
                ),
                const SizedBox(height: 20),
                // Campo numérico + selector de unidad
                Row(
                  children: [
                    Expanded(
                      child: TextField(
                        controller: cantidadController,
                        keyboardType: TextInputType.number,
                        inputFormatters: [
                          FilteringTextInputFormatter.digitsOnly,
                        ],
                        decoration: InputDecoration(
                          hintText: 'Ej: 30',
                          hintStyle:
                              const TextStyle(color: Color(0xFFCBD5E1)),
                          prefixIcon: const Icon(Icons.schedule_rounded,
                              color: Color(0xFF10B981)),
                          border: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(12),
                            borderSide:
                                const BorderSide(color: Color(0xFFE2E8F0)),
                          ),
                          focusedBorder: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(12),
                            borderSide: const BorderSide(
                                color: Color(0xFF10B981), width: 2),
                          ),
                        ),
                      ),
                    ),
                    const SizedBox(width: 10),
                    // Selector minutos / horas
                    Container(
                      decoration: BoxDecoration(
                        border: Border.all(color: const Color(0xFFE2E8F0)),
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: Column(
                        children: ['minutos', 'horas'].map((u) {
                          final selected = unidad == u;
                          return GestureDetector(
                            onTap: () => setDialogState(() => unidad = u),
                            child: Container(
                              padding: const EdgeInsets.symmetric(
                                  horizontal: 14, vertical: 10),
                              decoration: BoxDecoration(
                                color: selected
                                    ? const Color(0xFF10B981)
                                    : Colors.transparent,
                                borderRadius: BorderRadius.circular(10),
                              ),
                              child: Text(
                                u,
                                style: TextStyle(
                                  fontSize: 12,
                                  fontWeight: FontWeight.w700,
                                  color: selected
                                      ? Colors.white
                                      : const Color(0xFF64748B),
                                ),
                              ),
                            ),
                          );
                        }).toList(),
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(ctx).pop(),
              child: const Text('Cancelar',
                  style: TextStyle(color: Color(0xFF64748B))),
            ),
            ElevatedButton(
              onPressed: () async {
                if (cantidadController.text.isEmpty) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(
                        content: Text('Ingresa el tiempo estimado')),
                  );
                  return;
                }
                final tiempoTexto =
                    '${cantidadController.text} $unidad';
                Navigator.of(ctx).pop();
                await _comprometereRecogerMaterial(
                    contenedorId, tiempoTexto, data);
              },
              style: ElevatedButton.styleFrom(
                backgroundColor: const Color(0xFF10B981),
                foregroundColor: Colors.white,
                elevation: 0,
                shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(10)),
              ),
              child: const Text('Confirmar',
                  style: TextStyle(fontWeight: FontWeight.w700)),
            ),
          ],
        ),
      ),
    );
  }

  // ─── Guardar compromiso en Firestore ──────────────────────────────────────

  Future<void> _comprometereRecogerMaterial(
    String contenedorId,
    String tiempoEstimado,
    Map<String, dynamic> data,
  ) async {
    try {
      final now = FieldValue.serverTimestamp();
      final currentUser = FirebaseAuth.instance.currentUser;
      if (currentUser == null) return;

      final opDoc = await FirebaseFirestore.instance
          .collection('usuarios')
          .doc(currentUser.uid)
          .get();

      final operadorNombre =
          opDoc.data()?['nombre']?.toString() ?? 'Operador';
      final camion = opDoc.data()?['camion']?.toString() ?? '';
      final placas = opDoc.data()?['placas']?.toString() ?? '';

      await FirebaseFirestore.instance
          .collection('contenedores')
          .doc(contenedorId)
          .set({
        'estadoRecogida': 'comprometido',
        'operadorRecogida': operadorNombre,
        'tiempoEstimadoRecogida': tiempoEstimado,
        'operadorAsignado': currentUser.uid,
        'fechaCompromisoRecogida': now,
      }, SetOptions(merge: true));

      // Notificar al trabajador que reportó el contenedor
      final trabajadorNombre = data['actualizadoPor']?.toString() ?? '';
      if (trabajadorNombre.isNotEmpty) {
        final tQuery = await FirebaseFirestore.instance
            .collection('usuarios')
            .where('nombre', isEqualTo: trabajadorNombre)
            .limit(1)
            .get();

        if (tQuery.docs.isNotEmpty) {
          await FirebaseFirestore.instance
              .collection('notificaciones')
              .add({
            'mensaje':
                '$operadorNombre ($camion - $placas) recogerá el material en $tiempoEstimado.',
            'enviadoPor': operadorNombre,
            'creadoEn': now,
            'tipo': 'operador_compromiso_recogida',
            'destinoTipo': 'individual',
            'destinatarioDocId': tQuery.docs.first.id,
            'destinatarioNombre': trabajadorNombre,
            'destinatarioRol': 'trabajador',
            'contenedorId': contenedorId,
          });
        }
      }

      final otrosOperadoresSnap = await FirebaseFirestore.instance
          .collection('usuarios')
          .where('rol', isEqualTo: 'operador')
          .where('jornada_activa', isEqualTo: true)
          .get();

      final labelId = contenedorId.replaceAll('contenedor-', 'C');
      for (final op in otrosOperadoresSnap.docs) {
        if (op.id == currentUser.uid) continue;

        await FirebaseFirestore.instance.collection('notificaciones').add({
          'mensaje':
              '$operadorNombre tomó el Contenedor $labelId y lo recogerá en $tiempoEstimado.',
          'enviadoPor': operadorNombre,
          'creadoEn': now,
          'tipo': 'operador_compromiso_recogida',
          'destinoTipo': 'individual',
          'destinatarioDocId': op.id,
          'destinatarioNombre': op.data()['nombre']?.toString() ?? '',
          'destinatarioRol': 'operador',
          'contenedorId': contenedorId,
          'paraTodos': false,
        });
      }

      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
              '¡Listo! Recogerás el material en $tiempoEstimado.'),
          backgroundColor: const Color(0xFF10B981),
        ),
      );
    } catch (e) {
      debugPrint('Error compromiso: $e');
    }
  }

  // ─── Bottom sheet detalles ─────────────────────────────────────────────────

  void _mostrarDetalles(
      BuildContext context, String id, Map<String, dynamic> data) {
    final estado = data['estado']?.toString() ?? 'Fuera de servicio';
    final actualizadoPor = data['actualizadoPor']?.toString() ?? '—';
    final ts = data['actualizadoEn'] is Timestamp
        ? data['actualizadoEn'] as Timestamp
        : null;
    final color = _colorFor(estado);
    final icon = _iconFor(estado);
    final labelId = id.replaceAll('contenedor-', 'C');
    final fechaStr = _formatTimestamp(ts);
    final estadoRecogida =
        data['estadoRecogida']?.toString() ?? 'pendiente';
    final operadorRecogida =
        data['operadorRecogida']?.toString() ?? '';
    final tiempoEstimado =
        data['tiempoEstimadoRecogida']?.toString() ?? '';

    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      isScrollControlled: true,
      builder: (_) => Container(
        decoration: const BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.vertical(top: Radius.circular(28)),
        ),
        padding: EdgeInsets.fromLTRB(
            24, 12, 24, MediaQuery.of(context).viewInsets.bottom + 24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Handle
            Center(
              child: Container(
                width: 40,
                height: 4,
                decoration: BoxDecoration(
                  color: const Color(0xFFE2E8F0),
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
            ),
            const SizedBox(height: 24),
            // Encabezado
            Row(
              children: [
                Container(
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: color.withOpacity(0.12),
                    shape: BoxShape.circle,
                  ),
                  child: Icon(icon, color: color, size: 28),
                ),
                const SizedBox(width: 16),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text('Contenedor $labelId',
                          style: const TextStyle(
                            fontSize: 22,
                            fontWeight: FontWeight.w800,
                            color: Color(0xFF0F172A),
                          )),
                      Text('Código: $id',
                          style: const TextStyle(
                            fontSize: 13,
                            color: Color(0xFF64748B),
                            fontWeight: FontWeight.w500,
                          )),
                    ],
                  ),
                ),
              ],
            ),
            const SizedBox(height: 20),
            _detailRow(Icons.info_outline_rounded, 'Estado', estado,
                valueColor: color, fw: FontWeight.w800),
            const SizedBox(height: 8),
            _detailRow(Icons.person_pin_rounded, 'Actualizado por',
                actualizadoPor),
            const SizedBox(height: 8),
            _detailRow(
                Icons.access_time_rounded, 'Fecha y hora', fechaStr),
            const SizedBox(height: 20),

            // ── Sección acción cuando está Lleno ──────────────────────────
            if (estado == 'Lleno') ...[
              if (estadoRecogida == 'comprometido') ...[
                // Ya hay operador — solo mostrar info, no permitir otra recogida
                Container(
                  padding: const EdgeInsets.all(16),
                  decoration: BoxDecoration(
                    color: const Color(0xFFECFDF5),
                    borderRadius: BorderRadius.circular(16),
                    border:
                        Border.all(color: const Color(0xFFD1FAE5)),
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Row(
                        children: [
                          Icon(Icons.lock_rounded,
                              color: Color(0xFF059669), size: 18),
                          SizedBox(width: 8),
                          Text(
                            'Recogida asignada',
                            style: TextStyle(
                              fontSize: 13,
                              fontWeight: FontWeight.w800,
                              color: Color(0xFF059669),
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 10),
                      Text(
                        'Este contenedor será recogido por $operadorRecogida.',
                        style: const TextStyle(
                          fontSize: 13,
                          color: Color(0xFF047857),
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                      if (tiempoEstimado.isNotEmpty) ...[
                        const SizedBox(height: 6),
                        Row(
                          children: [
                            const Icon(Icons.schedule_rounded,
                                color: Color(0xFF059669), size: 16),
                            const SizedBox(width: 6),
                            Text(
                              'Llega en: $tiempoEstimado',
                              style: const TextStyle(
                                fontSize: 12,
                                color: Color(0xFF059669),
                                fontWeight: FontWeight.w600,
                              ),
                            ),
                          ],
                        ),
                      ],
                    ],
                  ),
                ),
              ] else ...[
                // Nadie se ha comprometido — mostrar botón
                SizedBox(
                  width: double.infinity,
                  height: 52,
                  child: ElevatedButton.icon(
                    onPressed: () {
                      Navigator.pop(context);
                      _mostrarDialogoRecogerMaterial(
                          context, id, data);
                    },
                    icon: const Icon(Icons.local_shipping_rounded,
                        size: 20),
                    label: const Text(
                      'Recoger Material',
                      style: TextStyle(
                          fontWeight: FontWeight.w800, fontSize: 15),
                    ),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: const Color(0xFF10B981),
                      foregroundColor: Colors.white,
                      elevation: 0,
                      shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(14)),
                    ),
                  ),
                ),
              ],
              const SizedBox(height: 12),
            ],

            // Botón cerrar
            SizedBox(
              width: double.infinity,
              height: 48,
              child: OutlinedButton(
                onPressed: () => Navigator.pop(context),
                style: OutlinedButton.styleFrom(
                  side: const BorderSide(
                      color: Color(0xFFE2E8F0), width: 1.5),
                  shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(14)),
                ),
                child: const Text('Cerrar',
                    style: TextStyle(
                        color: Color(0xFF475569),
                        fontWeight: FontWeight.w700)),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _detailRow(IconData icon, String label, String value,
      {Color? valueColor, FontWeight? fw}) {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: const Color(0xFFF8FAFC),
        borderRadius: BorderRadius.circular(12),
      ),
      child: Row(
        children: [
          Icon(icon, size: 16, color: const Color(0xFF64748B)),
          const SizedBox(width: 10),
          Text(label,
              style: const TextStyle(
                  fontSize: 12,
                  color: Color(0xFF64748B),
                  fontWeight: FontWeight.w600)),
          const Spacer(),
          Text(value,
              style: TextStyle(
                fontSize: 13,
                color: valueColor ?? const Color(0xFF0F172A),
                fontWeight: fw ?? FontWeight.w700,
              )),
        ],
      ),
    );
  }

  // ─── Card individual ───────────────────────────────────────────────────────

  Widget _buildCard(BuildContext context, String id,
      Map<String, dynamic> data) {
    final estado = data['estado']?.toString() ?? 'Fuera de servicio';
    final actualizadoPor = data['actualizadoPor']?.toString() ?? '—';
    final ts = data['actualizadoEn'] is Timestamp
        ? data['actualizadoEn'] as Timestamp
        : null;
    final color = _colorFor(estado);
    final icon = _iconFor(estado);
    final labelId = id.replaceAll('contenedor-', 'C');
    final fechaStr = _formatTimestamp(ts);
    final esLleno = estado == 'Lleno';
    final estadoRecogida =
        data['estadoRecogida']?.toString() ?? 'pendiente';
    final operadorRecogida =
        data['operadorRecogida']?.toString() ?? '';
    final tiempoEstimado =
        data['tiempoEstimadoRecogida']?.toString() ?? '';

    Color statusBgColor;
    Color statusTextColor;
    switch (estado) {
      case 'En proceso de llenado':
        statusBgColor = const Color(0xFFFFF7ED);
        statusTextColor = const Color(0xFFEA580C);
        break;
      case 'Lleno':
        statusBgColor = const Color(0xFFECFDF5);
        statusTextColor = const Color(0xFF059669);
        break;
      case 'Fuera de servicio':
        statusBgColor = const Color(0xFFFEF2F2);
        statusTextColor = const Color(0xFFDC2626);
        break;
      default:
        statusBgColor = const Color(0xFFF8FAFC);
        statusTextColor = const Color(0xFF475569);
    }

    Widget cardContent = ClipRRect(
      borderRadius: BorderRadius.circular(18),
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          onTap: () => _mostrarDetalles(context, id, data),
          child: Stack(
            children: [
              // Barra lateral
              Positioned(
                left: 0, top: 0, bottom: 0,
                child: Container(width: 6, color: color),
              ),
              Padding(
                padding: const EdgeInsets.all(16),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // ── Header ──────────────────────────────────────────
                    Row(
                      children: [
                        // Ícono (con pulso si lleno)
                        esLleno
                            ? AnimatedBuilder(
                                animation: _pulseScale,
                                builder: (_, child) => Transform.scale(
                                  scale: _pulseScale.value,
                                  child: child,
                                ),
                                child: Container(
                                  padding: const EdgeInsets.all(10),
                                  decoration: BoxDecoration(
                                    color: color.withOpacity(0.15),
                                    shape: BoxShape.circle,
                                  ),
                                  child:
                                      Icon(icon, color: color, size: 22),
                                ),
                              )
                            : Container(
                                padding: const EdgeInsets.all(10),
                                decoration: BoxDecoration(
                                  color: color.withOpacity(0.1),
                                  shape: BoxShape.circle,
                                ),
                                child: Icon(icon, color: color, size: 20),
                              ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                'Contenedor $labelId',
                                style: const TextStyle(
                                  fontSize: 16,
                                  fontWeight: FontWeight.w800,
                                  color: Color(0xFF0F172A),
                                  letterSpacing: -0.2,
                                ),
                              ),
                              Text(
                                id,
                                style: const TextStyle(
                                  fontSize: 11,
                                  color: Color(0xFF94A3B8),
                                  fontWeight: FontWeight.w500,
                                ),
                              ),
                            ],
                          ),
                        ),
                        // Badge estado
                        Container(
                          padding: const EdgeInsets.symmetric(
                              horizontal: 10, vertical: 4),
                          decoration: BoxDecoration(
                            color: statusBgColor,
                            borderRadius: BorderRadius.circular(30),
                            border: Border.all(
                                color: statusTextColor.withOpacity(0.2)),
                          ),
                          child: Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Container(
                                width: 6, height: 6,
                                decoration: BoxDecoration(
                                    color: statusTextColor,
                                    shape: BoxShape.circle),
                              ),
                              const SizedBox(width: 6),
                              Text(
                                estado,
                                style: TextStyle(
                                  color: statusTextColor,
                                  fontSize: 11,
                                  fontWeight: FontWeight.w800,
                                ),
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),

                    const SizedBox(height: 14),

                    // ── Banner ALERTA si está lleno ──────────────────────
                    if (esLleno) ...[
                      AnimatedBuilder(
                        animation: _pulseOpacity,
                        builder: (_, child) => Opacity(
                          opacity: _pulseOpacity.value,
                          child: child,
                        ),
                        child: Container(
                          width: double.infinity,
                          padding: const EdgeInsets.symmetric(
                              horizontal: 14, vertical: 10),
                          decoration: BoxDecoration(
                            color: const Color(0xFFDCFCE7),
                            borderRadius: BorderRadius.circular(12),
                            border: Border.all(
                                color: const Color(0xFF10B981),
                                width: 1.5),
                          ),
                          child: Row(
                            children: [
                              const Icon(
                                Icons.priority_high_rounded,
                                color: Color(0xFF047857),
                                size: 20,
                              ),
                              const SizedBox(width: 8),
                              const Expanded(
                                child: Text(
                                  '¡Este contenedor necesita ser recogido!',
                                  style: TextStyle(
                                    fontSize: 12,
                                    fontWeight: FontWeight.w800,
                                    color: Color(0xFF047857),
                                  ),
                                ),
                              ),
                            ],
                          ),
                        ),
                      ),
                      const SizedBox(height: 10),
                    ],

                    // ── Barra de progreso ────────────────────────────────
                    if (estado == 'En proceso de llenado' ||
                        estado == 'Lleno') ...[
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Text(
                            estado == 'Lleno'
                                ? 'Capacidad: 100%'
                                : 'Nivel aprox: 65%',
                            style: TextStyle(
                              fontSize: 11,
                              fontWeight: FontWeight.w700,
                              color: statusTextColor,
                            ),
                          ),
                          Icon(
                            estado == 'Lleno'
                                ? Icons.battery_full_rounded
                                : Icons.battery_charging_full_rounded,
                            size: 15,
                            color: statusTextColor,
                          ),
                        ],
                      ),
                      const SizedBox(height: 5),
                      ClipRRect(
                        borderRadius: BorderRadius.circular(10),
                        child: LinearProgressIndicator(
                          value: estado == 'Lleno' ? 1.0 : 0.65,
                          backgroundColor: color.withOpacity(0.1),
                          valueColor:
                              AlwaysStoppedAnimation<Color>(color),
                          minHeight: 7,
                        ),
                      ),
                    ] else ...[
                      ClipRRect(
                        borderRadius: BorderRadius.circular(10),
                        child: const LinearProgressIndicator(
                          value: 0.0,
                          backgroundColor: Color(0xFFE2E8F0),
                          valueColor: AlwaysStoppedAnimation<Color>(
                              Color(0xFF94A3B8)),
                          minHeight: 7,
                        ),
                      ),
                    ],

                    const SizedBox(height: 12),
                    Divider(color: const Color(0xFFF1F5F9), height: 1),
                    const SizedBox(height: 10),

                    // ── Footer por/hora ──────────────────────────────────
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Row(children: [
                          const Icon(Icons.person_pin_rounded,
                              size: 13, color: Color(0xFF94A3B8)),
                          const SizedBox(width: 4),
                          Text('Por: $actualizadoPor',
                              style: const TextStyle(
                                  fontSize: 11,
                                  color: Color(0xFF64748B),
                                  fontWeight: FontWeight.w600)),
                        ]),
                        Row(children: [
                          const Icon(Icons.access_time_rounded,
                              size: 13, color: Color(0xFF94A3B8)),
                          const SizedBox(width: 4),
                          Text(fechaStr,
                              style: const TextStyle(
                                  fontSize: 11,
                                  color: Color(0xFF64748B),
                                  fontWeight: FontWeight.w600)),
                        ]),
                      ],
                    ),

                    // ── Acción directa en el card ────────────────────────
                    if (esLleno) ...[
                      const SizedBox(height: 12),
                      if (estadoRecogida == 'comprometido') ...[
                        // Bloqueado — mostrar quién lo va a recoger
                        Container(
                          padding: const EdgeInsets.all(12),
                          decoration: BoxDecoration(
                            color: const Color(0xFFECFDF5),
                            borderRadius: BorderRadius.circular(12),
                            border: Border.all(
                                color: const Color(0xFFD1FAE5)),
                          ),
                          child: Row(
                            children: [
                              const Icon(Icons.lock_rounded,
                                  color: Color(0xFF059669), size: 16),
                              const SizedBox(width: 8),
                              Expanded(
                                child: Text(
                                  'Será recogido por $operadorRecogida'
                                  '${tiempoEstimado.isNotEmpty ? ' · $tiempoEstimado' : ''}',
                                  style: const TextStyle(
                                    fontSize: 11,
                                    fontWeight: FontWeight.w700,
                                    color: Color(0xFF059669),
                                  ),
                                ),
                              ),
                            ],
                          ),
                        ),
                      ] else ...[
                        // Disponible — botón recoger
                        SizedBox(
                          width: double.infinity,
                          height: 44,
                          child: ElevatedButton.icon(
                            onPressed: () => _mostrarDialogoRecogerMaterial(
                                context, id, data),
                            icon: const Icon(
                                Icons.local_shipping_rounded,
                                size: 18),
                            label: const Text(
                              'Recoger Material',
                              style: TextStyle(
                                  fontWeight: FontWeight.w800,
                                  fontSize: 13),
                            ),
                            style: ElevatedButton.styleFrom(
                              backgroundColor: const Color(0xFF10B981),
                              foregroundColor: Colors.white,
                              elevation: 0,
                              shape: RoundedRectangleBorder(
                                  borderRadius:
                                      BorderRadius.circular(12)),
                            ),
                          ),
                        ),
                      ],
                    ],
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );

    // Envolver en AnimatedBuilder para pulso del borde si está lleno
    if (esLleno) {
      return AnimatedBuilder(
        animation: _pulseOpacity,
        builder: (_, child) => Container(
          margin: const EdgeInsets.only(bottom: 14),
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(18),
            boxShadow: [
              BoxShadow(
                color: const Color(0xFF10B981)
                    .withOpacity(_pulseOpacity.value * 0.3),
                blurRadius: 16,
                spreadRadius: 2,
                offset: const Offset(0, 4),
              ),
            ],
            border: Border.all(
              color: const Color(0xFF10B981)
                  .withOpacity(0.3 + _pulseOpacity.value * 0.4),
              width: 1.5 + _pulseOpacity.value,
            ),
          ),
          child: child,
        ),
        child: cardContent,
      );
    }

    return Container(
      margin: const EdgeInsets.only(bottom: 14),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(18),
        boxShadow: [
          BoxShadow(
            color: const Color(0xFF0F172A).withOpacity(0.04),
            blurRadius: 12,
            offset: const Offset(0, 6),
          ),
        ],
        border: Border.all(color: color.withOpacity(0.15), width: 1.5),
      ),
      child: cardContent,
    );
  }

  // ─── Build ─────────────────────────────────────────────────────────────────

  @override
  Widget build(BuildContext context) {
    final nombreUsuario = widget.operador ?? 'Operador';

    return Scaffold(
      backgroundColor: const Color(0xFFF8FAFC),
      drawer: MenuLateral(
        nombreUsuario: nombreUsuario,
        camion: widget.camion ?? '',
        placas: widget.placas ?? '',
        mostrarCerrarSesion: false,
      ),
      endDrawer: NotificacionesDrawer(
        rolUsuario: 'operador',
        nombreUsuario: nombreUsuario,
      ),
      appBar: AppBar(
        automaticallyImplyLeading: false,
        leading: Builder(
          builder: (context) => IconButton(
            icon: const Icon(Icons.menu_rounded, color: Colors.white),
            onPressed: () => Scaffold.of(context).openDrawer(),
            tooltip: 'Menú',
          ),
        ),
        title: const Text(
          'Contenedores',
          style: TextStyle(color: Colors.white, fontWeight: FontWeight.w800),
        ),
        centerTitle: false,
        flexibleSpace: Container(
          decoration: const BoxDecoration(
            gradient: LinearGradient(
              colors: [Color(0xFF031A47), Color(0xFF022A60)],
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
            ),
          ),
        ),
        actions: [
          IconButton(
            tooltip: 'Reportar problema',
            icon: const Icon(Icons.report_problem_rounded,
                color: Color(0xFFFFD54F), size: 28),
            onPressed: () {
              final nombre = nombreUsuario;
              Navigator.of(context).push(
                MaterialPageRoute(
                  builder: (_) => ReporteScreen(
                    nombreUsuario: nombre,
                    camion: widget.camion ?? '',
                    placas: widget.placas ?? '',
                  ),
                ),
              );
            },
          ),
          Builder(
            builder: (context) => NotificacionesBellButton(
              rolUsuario: 'operador',
              nombreUsuario: nombreUsuario,
              iconColor: Colors.white,
              onPressed: () => Scaffold.of(context).openEndDrawer(),
            ),
          ),
        ],
      ),
      body: StreamBuilder<QuerySnapshot<Map<String, dynamic>>>(
        stream: FirebaseFirestore.instance
            .collection('contenedores')
            .where(FieldPath.documentId,
                whereIn: [
                  'contenedor-1',
                  'contenedor-2',
                  'contenedor-3'
                ])
            .snapshots(),
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) {
            return const Center(child: CircularProgressIndicator());
          }

          final Map<String, Map<String, dynamic>> map = {
            'contenedor-1': {'estado': 'Fuera de servicio'},
            'contenedor-2': {'estado': 'Fuera de servicio'},
            'contenedor-3': {'estado': 'Fuera de servicio'},
          };
          for (final doc in (snapshot.data?.docs ?? [])) {
            map[doc.id] = doc.data();
          }

          final ids = ['contenedor-1', 'contenedor-2', 'contenedor-3'];

          return Padding(
            padding: const EdgeInsets.all(16),
            child: Column(
              children: [
                // Banner info
                Container(
                  padding: const EdgeInsets.all(16),
                  margin: const EdgeInsets.only(bottom: 16),
                  decoration: BoxDecoration(
                    gradient: const LinearGradient(
                      colors: [Color(0xFF0F172A), Color(0xFF1E293B)],
                      begin: Alignment.topLeft,
                      end: Alignment.bottomRight,
                    ),
                    borderRadius: BorderRadius.circular(16),
                  ),
                  child: const Row(
                    children: [
                      Icon(Icons.info_outline_rounded,
                          color: Color(0xFF38BDF8), size: 20),
                      SizedBox(width: 12),
                      Expanded(
                        child: Text(
                          'Los contenedores en verde necesitan ser recogidos. Toca uno para ver detalles o presiona el botón directo.',
                          style: TextStyle(
                            color: Color(0xFF94A3B8),
                            fontSize: 11,
                            height: 1.3,
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
                // Lista
                Expanded(
                  child: ListView.builder(
                    itemCount: ids.length,
                    itemBuilder: (ctx, i) =>
                        _buildCard(ctx, ids[i], map[ids[i]] ?? {}),
                  ),
                ),
              ],
            ),
          );
        },
      ),
      bottomNavigationBar: JornadaBottomBar(
        activeIndex: 1,
        onInicio: () => Navigator.of(context).pushReplacement(
          MaterialPageRoute(
            builder: (_) => JornadaScreen(
              operador: widget.operador ?? '',
              camion: widget.camion ?? '',
              placas: widget.placas ?? '',
            ),
          ),
        ),
        onContenedores: () {},
        onHistorial: () => Navigator.of(context).pushReplacement(
          MaterialPageRoute(
            builder: (_) => RegistrosJornadaScreen(
              operador: widget.operador ?? '',
              camion: widget.camion ?? '',
              placas: widget.placas ?? '',
              historial: true,
            ),
          ),
        ),
        onPerfil: () => Navigator.of(context).pushReplacement(
          MaterialPageRoute(
            builder: (_) => PerfilOperadorScreen(
              operador: widget.operador ?? '',
              camion: widget.camion ?? '',
              placas: widget.placas ?? '',
            ),
          ),
        ),
      ),
    );
  }
}