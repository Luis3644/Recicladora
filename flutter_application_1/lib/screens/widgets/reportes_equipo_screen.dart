import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

class ReportesEquipoScreen extends StatefulWidget {
  const ReportesEquipoScreen({super.key});

  @override
  State<ReportesEquipoScreen> createState() => _ReportesEquipoScreenState();
}

class _ReportesEquipoScreenState extends State<ReportesEquipoScreen>
    with SingleTickerProviderStateMixin {
  static const Color _primary = Color(0xFF0F172A);
  static const Color _accent = Color(0xFF06B6D4);
  static const Color _success = Color(0xFF10B981);
  static const Color _warning = Color(0xFFF59E0B);
  static const Color _bgColor = Color(0xFFF0F9FF);

  DateTime _fechaSeleccionada = DateTime.now();
  bool _contentVisible = false;
  late AnimationController _controller;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      duration: const Duration(milliseconds: 700),
      vsync: this,
    );
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      setState(() => _contentVisible = true);
      _controller.forward();
    });
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  Future<void> _seleccionarFecha(BuildContext context) async {
    final DateTime? seleccionado = await showDatePicker(
      context: context,
      initialDate: _fechaSeleccionada,
      firstDate: DateTime(2024),
      lastDate: DateTime.now(),
      locale: const Locale('es', 'ES'),
      builder: (context, child) {
        return Theme(
          data: Theme.of(context).copyWith(
            colorScheme: const ColorScheme.light(
              primary: _primary,
              onPrimary: Colors.white,
              onSurface: _primary,
            ),
          ),
          child: child!,
        );
      },
    );

    if (seleccionado != null) {
      setState(() => _fechaSeleccionada = seleccionado);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: _bgColor,
      appBar: AppBar(
        title: const Text(
          'Reportes de Equipo',
          style: TextStyle(fontWeight: FontWeight.w700, letterSpacing: 0.2),
        ),
        backgroundColor: Colors.transparent,
        elevation: 0,
        foregroundColor: Colors.white,
        actions: [
          IconButton(
            icon: const Icon(Icons.calendar_month_rounded),
            onPressed: () => _seleccionarFecha(context),
            tooltip: 'Filtrar fecha',
          ),
        ],
        flexibleSpace: Container(
          decoration: BoxDecoration(
            gradient: const LinearGradient(
              colors: [_primary, Color(0xFF1E293B)],
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
            ),
            boxShadow: [
              BoxShadow(
                color: _primary.withOpacity(0.3),
                blurRadius: 20,
                offset: const Offset(0, 8),
              ),
            ],
          ),
        ),
      ),
      body: Stack(
        children: [
          Positioned(
            top: -100,
            right: -60,
            child: Container(
              width: 260,
              height: 260,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: _accent.withOpacity(0.1),
              ),
            ),
          ),
          Positioned(
            bottom: -70,
            left: -80,
            child: Container(
              width: 230,
              height: 230,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: _success.withOpacity(0.08),
              ),
            ),
          ),
          Column(
            children: [
              Padding(
                padding: const EdgeInsets.fromLTRB(16, 16, 16, 8),
                child: AnimatedOpacity(
                  opacity: _contentVisible ? 1 : 0,
                  duration: const Duration(milliseconds: 550),
                  child: Container(
                    width: double.infinity,
                    padding: const EdgeInsets.all(14),
                    decoration: BoxDecoration(
                      color: Colors.white.withOpacity(0.9),
                      borderRadius: BorderRadius.circular(14),
                      border: Border.all(color: _accent.withOpacity(0.18)),
                      boxShadow: [
                        BoxShadow(
                          color: _primary.withOpacity(0.05),
                          blurRadius: 12,
                          offset: const Offset(0, 4),
                        ),
                      ],
                    ),
                    child: Row(
                      children: [
                        Container(
                          padding: const EdgeInsets.all(9),
                          decoration: BoxDecoration(
                            color: _accent.withOpacity(0.15),
                            borderRadius: BorderRadius.circular(10),
                          ),
                          child: const Icon(
                            Icons.event_note_rounded,
                            color: _accent,
                            size: 20,
                          ),
                        ),
                        const SizedBox(width: 10),
                        Expanded(
                          child: Text(
                            DateFormat(
                              'EEEE, d MMMM',
                              'es_ES',
                            ).format(_fechaSeleccionada).toUpperCase(),
                            style: const TextStyle(
                              color: _primary,
                              fontWeight: FontWeight.w700,
                              fontSize: 12.5,
                            ),
                          ),
                        ),
                        if (DateFormat('yyyyMMdd').format(_fechaSeleccionada) !=
                            DateFormat('yyyyMMdd').format(DateTime.now()))
                          TextButton(
                            onPressed: () => setState(
                              () => _fechaSeleccionada = DateTime.now(),
                            ),
                            child: const Text('VER HOY'),
                          ),
                      ],
                    ),
                  ),
                ),
              ),
              Expanded(
                child: StreamBuilder<QuerySnapshot>(
                  stream: FirebaseFirestore.instance
                      .collection('checklist')
                      .where('equipo_completo', isEqualTo: false)
                      .snapshots(),
                  builder: (context, snapshot) {
                    if (snapshot.hasError) {
                      return const Center(child: Text('Error al cargar datos'));
                    }
                    if (snapshot.connectionState == ConnectionState.waiting) {
                      return const Center(
                        child: CircularProgressIndicator(color: _accent),
                      );
                    }

                    final todosLosFaltantes = snapshot.data!.docs;
                    final filtrados = todosLosFaltantes.where((doc) {
                      final ts = doc['fecha'] as Timestamp?;
                      if (ts == null) return false;
                      final d = ts.toDate();
                      return d.year == _fechaSeleccionada.year &&
                          d.month == _fechaSeleccionada.month &&
                          d.day == _fechaSeleccionada.day;
                    }).toList();

                    if (filtrados.isEmpty) {
                      return Center(
                        child: Column(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            Icon(
                              Icons.fact_check_rounded,
                              size: 78,
                              color: _primary.withOpacity(0.2),
                            ),
                            const SizedBox(height: 10),
                            Text(
                              'Sin reportes faltantes para este día',
                              style: TextStyle(
                                color: _primary.withOpacity(0.6),
                                fontWeight: FontWeight.w600,
                              ),
                            ),
                          ],
                        ),
                      );
                    }

                    return ListView.builder(
                      padding: const EdgeInsets.fromLTRB(16, 6, 16, 20),
                      itemCount: filtrados.length,
                      itemBuilder: (context, index) {
                        final reporte =
                            filtrados[index].data() as Map<String, dynamic>;
                        return _buildCardBonita(reporte, index);
                      },
                    );
                  },
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildCardBonita(Map<String, dynamic> r, int index) {
    final hora = r['fecha'] != null
        ? DateFormat('HH:mm').format((r['fecha'] as Timestamp).toDate())
        : '--:--';

    final faltantes = <String>[];
    if (r['cubrebocas'] == false) faltantes.add('Cubrebocas');
    if (r['gafas'] == false) faltantes.add('Gafas');
    if (r['guantes'] == false) faltantes.add('Guantes');
    if (r['uniforme'] == false) faltantes.add('Uniforme');

    return TweenAnimationBuilder<double>(
      tween: Tween(begin: 0, end: 1),
      duration: Duration(milliseconds: 320 + (index * 60)),
      curve: Curves.easeOutCubic,
      builder: (context, value, child) {
        return Transform.translate(
          offset: Offset(0, 20 * (1 - value)),
          child: Opacity(opacity: value, child: child),
        );
      },
      child: Container(
        margin: const EdgeInsets.only(bottom: 12),
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(16),
          gradient: LinearGradient(
            colors: [Colors.white, _warning.withOpacity(0.05)],
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
          ),
          border: Border.all(color: _warning.withOpacity(0.22)),
          boxShadow: [
            BoxShadow(
              color: _primary.withOpacity(0.06),
              blurRadius: 14,
              offset: const Offset(0, 5),
            ),
          ],
        ),
        child: ExpansionTile(
          tilePadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 3),
          childrenPadding: const EdgeInsets.fromLTRB(14, 0, 14, 14),
          leading: CircleAvatar(
            backgroundColor: _warning.withOpacity(0.14),
            child: const Icon(Icons.warning_amber_rounded, color: _warning),
          ),
          title: Text(
            r['operador'] ?? 'Operador',
            style: const TextStyle(
              fontWeight: FontWeight.w700,
              fontSize: 14,
              color: _primary,
            ),
          ),
          subtitle: Text(
            'Camión: ${r['camion']}  •  $hora hrs',
            style: TextStyle(color: _primary.withOpacity(0.65), fontSize: 12),
          ),
          children: [
            Align(
              alignment: Alignment.centerLeft,
              child: Text(
                'ARTÍCULOS FALTANTES',
                style: TextStyle(
                  fontWeight: FontWeight.w800,
                  fontSize: 11,
                  color: _primary.withOpacity(0.7),
                  letterSpacing: 0.4,
                ),
              ),
            ),
            const SizedBox(height: 10),
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: faltantes.isEmpty
                  ? [
                      Chip(
                        label: const Text('No hay faltantes marcados'),
                        backgroundColor: _success.withOpacity(0.12),
                      ),
                    ]
                  : faltantes.map(_chipError).toList(),
            ),
            if (r['reporte'] != null &&
                r['reporte'].toString().trim().isNotEmpty) ...[
              const SizedBox(height: 14),
              Divider(color: _primary.withOpacity(0.15)),
              const SizedBox(height: 8),
              Text(
                'OBSERVACIONES',
                style: TextStyle(
                  fontWeight: FontWeight.w800,
                  fontSize: 11,
                  color: _primary.withOpacity(0.7),
                  letterSpacing: 0.4,
                ),
              ),
              const SizedBox(height: 6),
              Text(
                r['reporte'].toString(),
                style: const TextStyle(
                  color: Color(0xFFB91C1C),
                  fontSize: 13,
                  height: 1.35,
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }

  Widget _chipError(String texto) {
    return Chip(
      label: Text(
        texto,
        style: const TextStyle(
          color: Color(0xFFB91C1C),
          fontSize: 11,
          fontWeight: FontWeight.w700,
        ),
      ),
      backgroundColor: const Color(0xFFFEE2E2),
      side: BorderSide(color: const Color(0xFFEF4444).withOpacity(0.4)),
      visualDensity: VisualDensity.compact,
    );
  }
}
