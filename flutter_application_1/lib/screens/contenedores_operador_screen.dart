import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import '../widgets/jornada_bottom_bar.dart';
import 'jornada_screen.dart';

class ContenedoresOperadorScreen extends StatelessWidget {
  final String? operador;
  final String? camion;
  final String? placas;

  const ContenedoresOperadorScreen({
    super.key,
    this.operador,
    this.camion,
    this.placas,
  });

  String _formatTimestamp(Timestamp? ts) {
    if (ts == null) return '—';
    final d = ts.toDate();
    return '${d.day.toString().padLeft(2, '0')}/${d.month.toString().padLeft(2, '0')} ${d.hour.toString().padLeft(2, '0')}:${d.minute.toString().padLeft(2, '0')}';
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
        return Icons.done_all_rounded;
      case 'Fuera de servicio':
        return Icons.build_circle_rounded;
      default:
        return Icons.inventory_2_outlined;
    }
  }

  void _mostrarDetallesContenedor(
    BuildContext context,
    String id,
    Map<String, dynamic> data,
  ) {
    final estado = data['estado']?.toString() ?? 'Fuera de servicio';
    final actualizadoPor = data['actualizadoPor']?.toString() ?? '—';
    final ts = data['actualizadoEn'] is Timestamp
        ? data['actualizadoEn'] as Timestamp
        : null;
    final color = _colorFor(estado);
    final icon = _iconFor(estado);
    final labelId = id.replaceAll('contenedor-', 'C');
    final fechaStr = _formatTimestamp(ts);

    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      isScrollControlled: true,
      builder: (context) {
        return Container(
          decoration: const BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.vertical(top: Radius.circular(28)),
          ),
          padding: const EdgeInsets.fromLTRB(24, 12, 24, 24),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
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
                        Text(
                          'Contenedor $labelId',
                          style: const TextStyle(
                            fontSize: 22,
                            fontWeight: FontWeight.w800,
                            color: Color(0xFF0F172A),
                          ),
                        ),
                        Text(
                          'Código: $id',
                          style: const TextStyle(
                            fontSize: 13,
                            color: Color(0xFF64748B),
                            fontWeight: FontWeight.w500,
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 24),
              const Text(
                'Información General',
                style: TextStyle(
                  fontSize: 15,
                  fontWeight: FontWeight.w800,
                  color: Color(0xFF0F172A),
                ),
              ),
              const SizedBox(height: 12),
              _buildDetailRow(
                icon: Icons.info_outline_rounded,
                label: 'Estado actual',
                value: estado,
                valueColor: color,
                fontWeight: FontWeight.w800,
              ),
              const SizedBox(height: 8),
              _buildDetailRow(
                icon: Icons.person_pin_rounded,
                label: 'Última actualización por',
                value: actualizadoPor,
              ),
              const SizedBox(height: 8),
              _buildDetailRow(
                icon: Icons.access_time_rounded,
                label: 'Fecha y hora',
                value: fechaStr,
              ),
              const SizedBox(height: 24),
              Container(
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: color.withOpacity(0.06),
                  borderRadius: BorderRadius.circular(16),
                  border: Border.all(color: color.withOpacity(0.12)),
                ),
                child: Row(
                  children: [
                    Icon(
                      estado == 'Lleno'
                          ? Icons.warning_amber_rounded
                          : (estado == 'En proceso de llenado'
                                ? Icons.hourglass_empty_rounded
                                : Icons.construction_rounded),
                      color: color,
                      size: 20,
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Text(
                        estado == 'Lleno'
                            ? 'El contenedor está al 100% de su capacidad. Se requiere recolección a la brevedad.'
                            : (estado == 'En proceso de llenado'
                                  ? 'El contenedor tiene capacidad disponible para seguir depositando material.'
                                  : 'Este contenedor está fuera de servicio por mantenimiento o reubicación.'),
                        style: TextStyle(
                          fontSize: 12,
                          color: color.withOpacity(0.9),
                          height: 1.4,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 24),
              SizedBox(
                width: double.infinity,
                height: 52,
                child: OutlinedButton(
                  onPressed: () => Navigator.pop(context),
                  style: OutlinedButton.styleFrom(
                    side: const BorderSide(
                      color: Color(0xFFE2E8F0),
                      width: 1.5,
                    ),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(14),
                    ),
                  ),
                  child: const Text(
                    'Cerrar Detalles',
                    style: TextStyle(
                      color: Color(0xFF475569),
                      fontWeight: FontWeight.w700,
                      fontSize: 14,
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

  Widget _buildDetailRow({
    required IconData icon,
    required String label,
    required String value,
    Color? valueColor,
    FontWeight? fontWeight,
  }) {
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
          Text(
            label,
            style: const TextStyle(
              fontSize: 12,
              color: Color(0xFF64748B),
              fontWeight: FontWeight.w600,
            ),
          ),
          const Spacer(),
          Text(
            value,
            style: TextStyle(
              fontSize: 13,
              color: valueColor ?? const Color(0xFF0F172A),
              fontWeight: fontWeight ?? FontWeight.w700,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildContainerCard({
    required String id,
    required String estado,
    required String actualizadoPor,
    required Timestamp? ts,
    required BuildContext context,
    required Map<String, dynamic> data,
  }) {
    final color = _colorFor(estado);
    final icon = _iconFor(estado);
    final labelId = id.replaceAll('contenedor-', 'C');
    final fechaStr = _formatTimestamp(ts);

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
      child: ClipRRect(
        borderRadius: BorderRadius.circular(18),
        child: Material(
          color: Colors.transparent,
          child: InkWell(
            onTap: () => _mostrarDetallesContenedor(context, id, data),
            child: Stack(
              children: [
                Positioned(
                  left: 0,
                  top: 0,
                  bottom: 0,
                  child: Container(width: 6, color: color),
                ),
                Padding(
                  padding: const EdgeInsets.all(16),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Expanded(
                            child: Row(
                              children: [
                                Container(
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
                                    crossAxisAlignment:
                                        CrossAxisAlignment.start,
                                    children: [
                                      Text(
                                        'Contenedor $labelId',
                                        style: const TextStyle(
                                          fontSize: 16,
                                          fontWeight: FontWeight.w800,
                                          color: Color(0xFF0F172A),
                                          letterSpacing: -0.2,
                                        ),
                                        overflow: TextOverflow.ellipsis,
                                      ),
                                      const SizedBox(height: 2),
                                      Text(
                                        id,
                                        style: const TextStyle(
                                          fontSize: 11,
                                          color: Color(0xFF94A3B8),
                                          fontWeight: FontWeight.w500,
                                        ),
                                        overflow: TextOverflow.ellipsis,
                                      ),
                                    ],
                                  ),
                                ),
                              ],
                            ),
                          ),
                          const SizedBox(width: 8),
                          Container(
                            padding: const EdgeInsets.symmetric(
                              horizontal: 10,
                              vertical: 4,
                            ),
                            decoration: BoxDecoration(
                              color: statusBgColor,
                              borderRadius: BorderRadius.circular(30),
                              border: Border.all(
                                color: statusTextColor.withOpacity(0.15),
                                width: 1,
                              ),
                            ),
                            child: Row(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                Container(
                                  width: 6,
                                  height: 6,
                                  decoration: BoxDecoration(
                                    color: statusTextColor,
                                    shape: BoxShape.circle,
                                  ),
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
                      const SizedBox(height: 16),
                      if (estado == 'En proceso de llenado' ||
                          estado == 'Lleno') ...[
                        Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Row(
                              mainAxisAlignment: MainAxisAlignment.spaceBetween,
                              children: [
                                Text(
                                  estado == 'Lleno'
                                      ? 'Nivel de capacidad: 100%'
                                      : 'Nivel aproximado: 65%',
                                  style: TextStyle(
                                    fontSize: 12,
                                    fontWeight: FontWeight.w700,
                                    color: statusTextColor,
                                  ),
                                ),
                                Icon(
                                  estado == 'Lleno'
                                      ? Icons.battery_full_rounded
                                      : Icons.battery_charging_full_rounded,
                                  size: 16,
                                  color: statusTextColor,
                                ),
                              ],
                            ),
                            const SizedBox(height: 6),
                            ClipRRect(
                              borderRadius: BorderRadius.circular(10),
                              child: LinearProgressIndicator(
                                value: estado == 'Lleno' ? 1.0 : 0.65,
                                backgroundColor: color.withOpacity(0.1),
                                valueColor: AlwaysStoppedAnimation<Color>(
                                  color,
                                ),
                                minHeight: 8,
                              ),
                            ),
                            const SizedBox(height: 12),
                          ],
                        ),
                      ] else ...[
                        Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            const Row(
                              mainAxisAlignment: MainAxisAlignment.spaceBetween,
                              children: [
                                Text(
                                  'Fuera de servicio / En mantenimiento',
                                  style: TextStyle(
                                    fontSize: 12,
                                    fontWeight: FontWeight.w700,
                                    color: Color(0xFF64748B),
                                  ),
                                ),
                                Icon(
                                  Icons.block_flipped,
                                  size: 16,
                                  color: Color(0xFF64748B),
                                ),
                              ],
                            ),
                            const SizedBox(height: 6),
                            ClipRRect(
                              borderRadius: BorderRadius.circular(10),
                              child: const LinearProgressIndicator(
                                value: 0.0,
                                backgroundColor: Color(0xFFE2E8F0),
                                valueColor: AlwaysStoppedAnimation<Color>(
                                  Color(0xFF64748B),
                                ),
                                minHeight: 8,
                              ),
                            ),
                            const SizedBox(height: 12),
                          ],
                        ),
                      ],
                      Divider(color: const Color(0xFFF1F5F9), height: 1),
                      const SizedBox(height: 10),
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Row(
                            children: [
                              const Icon(
                                Icons.person_pin_rounded,
                                size: 14,
                                color: Color(0xFF64748B),
                              ),
                              const SizedBox(width: 4),
                              Text(
                                'Por: $actualizadoPor',
                                style: const TextStyle(
                                  fontSize: 12,
                                  color: Color(0xFF64748B),
                                  fontWeight: FontWeight.w600,
                                ),
                              ),
                            ],
                          ),
                          Row(
                            children: [
                              const Icon(
                                Icons.access_time_rounded,
                                size: 14,
                                color: Color(0xFF64748B),
                              ),
                              const SizedBox(width: 4),
                              Text(
                                fechaStr,
                                style: const TextStyle(
                                  fontSize: 12,
                                  color: Color(0xFF64748B),
                                  fontWeight: FontWeight.w600,
                                ),
                              ),
                            ],
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF8FAFC),
      appBar: AppBar(
        automaticallyImplyLeading: false,
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
      ),
      body: StreamBuilder<QuerySnapshot<Map<String, dynamic>>>(
        stream: FirebaseFirestore.instance
            .collection('contenedores')
            .where(
              FieldPath.documentId,
              whereIn: ['contenedor-1', 'contenedor-2', 'contenedor-3'],
            )
            .snapshots(),
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) {
            return const Center(child: CircularProgressIndicator());
          }

          Map<String, Map<String, dynamic>> contenedoresMap = {
            'contenedor-1': {'estado': 'Fuera de servicio'},
            'contenedor-2': {'estado': 'Fuera de servicio'},
            'contenedor-3': {'estado': 'Fuera de servicio'},
          };

          for (final doc in (snapshot.data?.docs ?? [])) {
            contenedoresMap[doc.id] = doc.data();
          }

          final ids = ['contenedor-1', 'contenedor-2', 'contenedor-3'];

          return Padding(
            padding: const EdgeInsets.all(16),
            child: Column(
              children: [
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
                    boxShadow: [
                      BoxShadow(
                        color: const Color(0xFF0F172A).withOpacity(0.08),
                        blurRadius: 10,
                        offset: const Offset(0, 4),
                      ),
                    ],
                  ),
                  child: Row(
                    children: [
                      Container(
                        padding: const EdgeInsets.all(10),
                        decoration: BoxDecoration(
                          color: Colors.white.withOpacity(0.1),
                          shape: BoxShape.circle,
                        ),
                        child: const Icon(
                          Icons.info_outline_rounded,
                          color: Color(0xFF38BDF8),
                          size: 20,
                        ),
                      ),
                      const SizedBox(width: 12),
                      const Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              'Monitoreo en Tiempo Real',
                              style: TextStyle(
                                color: Colors.white,
                                fontWeight: FontWeight.w800,
                                fontSize: 14,
                              ),
                            ),
                            SizedBox(height: 2),
                            Text(
                              'Los estados de los contenedores se actualizan automáticamente. Presiona uno para ver detalles.',
                              style: TextStyle(
                                color: Color(0xFF94A3B8),
                                fontSize: 11,
                                height: 1.3,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),
                Expanded(
                  child: ListView.builder(
                    itemCount: ids.length,
                    itemBuilder: (context, index) {
                      final id = ids[index];
                      final d = contenedoresMap[id] ?? {};
                      final estado =
                          d['estado']?.toString() ?? 'Fuera de servicio';
                      final actualizadoPor =
                          d['actualizadoPor']?.toString() ?? '—';
                      final ts = d['actualizadoEn'] is Timestamp
                          ? d['actualizadoEn'] as Timestamp
                          : null;

                      return _buildContainerCard(
                        id: id,
                        estado: estado,
                        actualizadoPor: actualizadoPor,
                        ts: ts,
                        context: context,
                        data: d,
                      );
                    },
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
              operador: operador ?? '',
              camion: camion ?? '',
              placas: placas ?? '',
            ),
          ),
        ),
        onContenedores: () {},
        onHistorial: () => Navigator.of(context).pushReplacement(
          MaterialPageRoute(
            builder: (_) => RegistrosJornadaScreen(
              operador: operador ?? '',
              camion: camion ?? '',
              placas: placas ?? '',
              historial: true,
            ),
          ),
        ),
        onPerfil: () => Navigator.of(context).pushReplacement(
          MaterialPageRoute(
            builder: (_) => PerfilOperadorScreen(
              operador: operador ?? '',
              camion: camion ?? '',
              placas: placas ?? '',
            ),
          ),
        ),
      ),
    );
  }
}
