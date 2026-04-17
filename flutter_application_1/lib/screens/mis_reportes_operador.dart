import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

class MisReportesOperador extends StatefulWidget {
  final String nombreOperador;

  const MisReportesOperador({super.key, required this.nombreOperador});

  @override
  State<MisReportesOperador> createState() => _MisReportesOperadorState();
}

class _MisReportesOperadorState extends State<MisReportesOperador>
    with SingleTickerProviderStateMixin {
  // ── Colores (idénticos al admin) ──────────────────────────────────────────
  static const Color _primary = Color(0xFF0F172A);
  static const Color _accent  = Color(0xFF06B6D4);
  static const Color _success = Color(0xFF10B981);
  static const Color _danger  = Color(0xFFDC2626);
  static const Color _bgColor = Color(0xFFF0F9FF);
  static const Color _surface = Color(0xFFFFFFFF);
  static const Color _slate   = Color(0xFF64748B);
  static const Color _pending = Color(0xFFF59E0B);

  // ── Filtro de período ─────────────────────────────────────────────────────
  String _filtroPeriodo = 'todo';

  // ── Animación ─────────────────────────────────────────────────────────────
  late AnimationController _fadeCtrl;

  @override
  void initState() {
    super.initState();
    _fadeCtrl = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 400),
    )..forward();
  }

  @override
  void dispose() {
    _fadeCtrl.dispose();
    super.dispose();
  }

  // ── Query filtrada por período ─────────────────────────────────────────────
  Query<Map<String, dynamic>> _buildQuery() {
    Query<Map<String, dynamic>> q = FirebaseFirestore.instance
        .collection('reportes')
        .where('operador', isEqualTo: widget.nombreOperador)
        .orderBy('fecha', descending: true);

    final now = DateTime.now();
    DateTime? desde;
    switch (_filtroPeriodo) {
      case 'hoy':
        desde = DateTime(now.year, now.month, now.day);
        break;
      case 'semana':
        desde = now.subtract(const Duration(days: 7));
        break;
      case 'mes':
        desde = DateTime(now.year, now.month, 1);
        break;
      case 'año':
        desde = DateTime(now.year, 1, 1);
        break;
      case 'todo':
        desde = null;
        break;
    }
    if (desde != null) {
      q = q.where('fecha', isGreaterThanOrEqualTo: Timestamp.fromDate(desde));
    }
    return q;
  }

  // ─────────────────────────────────────────────────────────────────────────
  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: _bgColor,
      appBar: _buildAppBar(),
      body: FadeTransition(
        opacity: _fadeCtrl,
        child: Column(
          children: [
            _buildFiltros(),
            const SizedBox(height: 4),
            Expanded(child: _buildLista()),
          ],
        ),
      ),
    );
  }

  // ── AppBar ────────────────────────────────────────────────────────────────
  PreferredSizeWidget _buildAppBar() {
    return AppBar(
      title: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            'Mis Reportes',
            style: TextStyle(
                fontWeight: FontWeight.w800,
                fontSize: 17,
                letterSpacing: 0.2),
          ),
          Text(
            widget.nombreOperador,
            style: TextStyle(
                fontSize: 11,
                color: Colors.white.withOpacity(0.6),
                fontWeight: FontWeight.w400),
          ),
        ],
      ),
      backgroundColor: Colors.transparent,
      elevation: 0,
      foregroundColor: Colors.white,
      flexibleSpace: Container(
        decoration: BoxDecoration(
          gradient: const LinearGradient(
            colors: [_primary, Color(0xFF1E3A5F)],
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
          ),
          boxShadow: [
            BoxShadow(
              color: _primary.withOpacity(0.4),
              blurRadius: 24,
              offset: const Offset(0, 8),
            ),
          ],
        ),
      ),
    );
  }

  // ── Filtros de período ────────────────────────────────────────────────────
  Widget _buildFiltros() {
    return Container(
      margin: const EdgeInsets.fromLTRB(16, 16, 16, 8),
      decoration: BoxDecoration(
        color: _surface,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: const Color(0xFFE2E8F0)),
        boxShadow: [
          BoxShadow(
            color: _primary.withOpacity(0.06),
            blurRadius: 12,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Column(
        children: [
          // Encabezado
          Container(
            padding:
                const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
            decoration: const BoxDecoration(
              color: Color(0xFFF8FAFC),
              borderRadius:
                  BorderRadius.vertical(top: Radius.circular(16)),
              border: Border(
                  bottom: BorderSide(color: Color(0xFFE2E8F0))),
            ),
            child: Row(
              children: [
                Container(
                  padding: const EdgeInsets.all(6),
                  decoration: BoxDecoration(
                    color: _accent.withOpacity(0.1),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: const Icon(Icons.filter_list_rounded,
                      color: _accent, size: 16),
                ),
                const SizedBox(width: 10),
                const Text('Filtrar por período',
                    style: TextStyle(
                        fontSize: 13,
                        fontWeight: FontWeight.w700,
                        color: _primary,
                        letterSpacing: 0.2)),
              ],
            ),
          ),
          // Chips
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 12, 16, 14),
            child: SingleChildScrollView(
              scrollDirection: Axis.horizontal,
              child: Row(
                children: [
                  _chipPeriodo(
                      'hoy', 'Hoy', Icons.today_rounded),
                  _chipPeriodo(
                      'semana', 'Semana', Icons.date_range_rounded),
                  _chipPeriodo(
                      'mes', 'Este mes', Icons.calendar_month_rounded),
                  _chipPeriodo(
                      'año', 'Este año', Icons.calendar_today_rounded),
                  _chipPeriodo(
                      'todo', 'Todos', Icons.all_inclusive_rounded),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _chipPeriodo(String valor, String label, IconData icon) {
    final sel = _filtroPeriodo == valor;
    return GestureDetector(
      onTap: () {
        setState(() => _filtroPeriodo = valor);
        _fadeCtrl..reset()..forward();
      },
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 200),
        curve: Curves.easeOut,
        margin: const EdgeInsets.only(right: 8),
        padding:
            const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
        decoration: BoxDecoration(
          color: sel ? _accent : const Color(0xFFF1F5F9),
          borderRadius: BorderRadius.circular(10),
          boxShadow: sel
              ? [
                  BoxShadow(
                      color: _accent.withOpacity(0.35),
                      blurRadius: 8,
                      offset: const Offset(0, 3))
                ]
              : [],
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(icon,
                size: 13,
                color: sel ? Colors.white : Colors.grey[500]),
            const SizedBox(width: 5),
            Text(label,
                style: TextStyle(
                    fontSize: 12,
                    fontWeight: FontWeight.w700,
                    color: sel ? Colors.white : Colors.grey[600])),
          ],
        ),
      ),
    );
  }

  // ── Lista de reportes ─────────────────────────────────────────────────────
  Widget _buildLista() {
    return StreamBuilder<QuerySnapshot<Map<String, dynamic>>>(
      stream: _buildQuery().snapshots(),
      builder: (context, snap) {
        if (snap.connectionState == ConnectionState.waiting) {
          return const Center(
              child: CircularProgressIndicator(color: _accent));
        }
        if (snap.hasError) {
          return _estadoVacio(
            icon: Icons.cloud_off_rounded,
            color: _danger,
            titulo: 'Error al cargar',
            subtitulo: snap.error.toString(),
          );
        }

        final docs = snap.data?.docs ?? [];

        if (docs.isEmpty) {
          return _estadoVacio(
            icon: Icons.inbox_rounded,
            color: _slate,
            titulo: 'Sin reportes',
            subtitulo:
                'Aún no has enviado reportes en este período',
          );
        }

        // ── Resumen rápido ─────────────────────────────────────────────
        final vistos =
            docs.where((d) => d.data()['visto'] == true).length;
        final pendientes = docs.length - vistos;

        return Column(
          children: [
            // Banner de resumen
            _buildResumen(docs.length, vistos, pendientes),
            // Lista
            Expanded(
              child: ListView.builder(
                padding:
                    const EdgeInsets.fromLTRB(16, 4, 16, 28),
                itemCount: docs.length,
                itemBuilder: (_, i) =>
                    _buildCard(docs[i].data()),
              ),
            ),
          ],
        );
      },
    );
  }

  // ── Banner de resumen ─────────────────────────────────────────────────────
  Widget _buildResumen(int total, int vistos, int pendientes) {
    return Container(
      margin: const EdgeInsets.fromLTRB(16, 0, 16, 12),
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      decoration: BoxDecoration(
        color: _surface,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: const Color(0xFFE2E8F0)),
        boxShadow: [
          BoxShadow(
            color: _primary.withOpacity(0.05),
            blurRadius: 10,
            offset: const Offset(0, 3),
          )
        ],
      ),
      child: Row(
        children: [
          _statItem(total.toString(), 'Total', _accent),
          _dividerStat(),
          _statItem(vistos.toString(), 'Revisados', _success),
          _dividerStat(),
          _statItem(pendientes.toString(), 'Pendientes', _pending),
        ],
      ),
    );
  }

  Widget _statItem(String valor, String label, Color color) {
    return Expanded(
      child: Column(
        children: [
          Text(valor,
              style: TextStyle(
                  fontSize: 20,
                  fontWeight: FontWeight.w900,
                  color: color)),
          const SizedBox(height: 2),
          Text(label,
              style: const TextStyle(
                  fontSize: 10,
                  fontWeight: FontWeight.w600,
                  color: _slate)),
        ],
      ),
    );
  }

  Widget _dividerStat() => Container(
      width: 1, height: 32, color: const Color(0xFFE2E8F0));

  // ── Estado vacío ──────────────────────────────────────────────────────────
  Widget _estadoVacio({
    required IconData icon,
    required Color color,
    required String titulo,
    required String subtitulo,
  }) {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Container(
            padding: const EdgeInsets.all(20),
            decoration: BoxDecoration(
              color: color.withOpacity(0.08),
              shape: BoxShape.circle,
            ),
            child:
                Icon(icon, size: 48, color: color.withOpacity(0.5)),
          ),
          const SizedBox(height: 16),
          Text(titulo,
              style: TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.w700,
                  color: _primary.withOpacity(0.6))),
          const SizedBox(height: 6),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 40),
            child: Text(subtitulo,
                textAlign: TextAlign.center,
                style:
                    TextStyle(fontSize: 13, color: Colors.grey[400])),
          ),
        ],
      ),
    );
  }

  // ── Tarjeta de reporte ────────────────────────────────────────────────────
  Widget _buildCard(Map<String, dynamic> data) {
    final fecha  = (data['fecha'] as Timestamp?)?.toDate();
    final fotos  = List<String>.from(data['fotosUrl'] ?? []);
    final visto  = data['visto'] == true;

    return Container(
      margin: const EdgeInsets.only(bottom: 16),
      decoration: BoxDecoration(
        color: _surface,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: visto
              ? _success.withOpacity(0.25)
              : _pending.withOpacity(0.35),
        ),
        boxShadow: [
          BoxShadow(
            color: _primary.withOpacity(visto ? 0.05 : 0.08),
            blurRadius: 16,
            offset: const Offset(0, 5),
          ),
        ],
      ),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // ── Encabezado con estado ────────────────────────────────
            Container(
              padding: const EdgeInsets.symmetric(
                  horizontal: 16, vertical: 11),
              decoration: BoxDecoration(
                color: visto
                    ? _success.withOpacity(0.05)
                    : _pending.withOpacity(0.05),
                border: Border(
                  bottom: const BorderSide(color: Color(0xFFE2E8F0)),
                  left: BorderSide(
                      color: visto ? _success : _pending, width: 4),
                ),
              ),
              child: Row(
                children: [
                  // Ícono de estado
                  Icon(
                    visto
                        ? Icons.check_circle_rounded
                        : Icons.watch_later_rounded,
                    color: visto ? _success : _pending,
                    size: 15,
                  ),
                  const SizedBox(width: 6),
                  // Texto de estado
                  Text(
                    visto
                        ? 'ADMIN YA REVISÓ TU REPORTE'
                        : 'AÚN NO LO HA VISTO EL ADMIN',
                    style: TextStyle(
                        fontSize: 10,
                        fontWeight: FontWeight.w800,
                        color: visto ? _success : _pending,
                        letterSpacing: 0.8),
                  ),
                  const Spacer(),
                  Icon(Icons.access_time_rounded,
                      size: 12, color: Colors.grey[400]),
                  const SizedBox(width: 4),
                  Text(
                    fecha != null
                        ? DateFormat('dd/MM/yyyy  HH:mm').format(fecha)
                        : '—',
                    style: TextStyle(
                        fontSize: 11,
                        color: Colors.grey[500],
                        fontWeight: FontWeight.w500),
                  ),
                ],
              ),
            ),

            // ── Banner informativo según estado ──────────────────────
            Container(
              width: double.infinity,
              padding: const EdgeInsets.symmetric(
                  horizontal: 16, vertical: 8),
              color: visto
                  ? _success.withOpacity(0.07)
                  : _pending.withOpacity(0.07),
              child: Row(
                children: [
                  Icon(
                    visto
                        ? Icons.visibility_rounded
                        : Icons.hourglass_empty_rounded,
                    size: 13,
                    color: visto ? _success : _pending,
                  ),
                  const SizedBox(width: 6),
                  Expanded(
                    child: Text(
                      visto
                          ? 'Tu reporte fue revisado por el administrador.'
                          : 'Tu reporte está en espera de revisión por el administrador.',
                      style: TextStyle(
                          fontSize: 11,
                          color: visto
                              ? _success.withOpacity(0.85)
                              : _pending.withOpacity(0.85),
                          fontWeight: FontWeight.w500),
                    ),
                  ),
                ],
              ),
            ),

            // ── Cuerpo ───────────────────────────────────────────────
            Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // Fila: Camión + Placas
                  Row(
                    children: [
                      Expanded(
                        child: _datoItem(
                            Icons.directions_bus_rounded,
                            'CAMIÓN',
                            data['camion'] ?? '—',
                            _accent),
                      ),
                      const SizedBox(width: 10),
                      Expanded(
                        child: _datoItem(
                            Icons.pin_rounded,
                            'PLACAS',
                            data['placas'] ?? '—',
                            _success),
                      ),
                    ],
                  ),

                  const SizedBox(height: 14),
                  const Divider(color: Color(0xFFE2E8F0), height: 1),
                  const SizedBox(height: 14),

                  // Descripción
                  const Text('DESCRIPCIÓN DEL INCIDENTE',
                      style: TextStyle(
                          fontSize: 10,
                          fontWeight: FontWeight.w800,
                          color: _slate,
                          letterSpacing: 0.8)),
                  const SizedBox(height: 8),
                  Container(
                    width: double.infinity,
                    padding: const EdgeInsets.all(14),
                    decoration: BoxDecoration(
                      color: const Color(0xFFF8FAFC),
                      borderRadius: BorderRadius.circular(10),
                      border: Border.all(
                          color: const Color(0xFFE2E8F0)),
                    ),
                    child: Text(
                      data['mensaje'] ?? 'Sin descripción',
                      style: const TextStyle(
                          fontSize: 14,
                          color: _primary,
                          fontWeight: FontWeight.w500,
                          height: 1.5),
                    ),
                  ),

                  // Fotos (solo vista previa, sin descarga)
                  if (fotos.isNotEmpty) ...[
                    const SizedBox(height: 14),
                    const Text('EVIDENCIA FOTOGRÁFICA',
                        style: TextStyle(
                            fontSize: 10,
                            fontWeight: FontWeight.w800,
                            color: _slate,
                            letterSpacing: 0.8)),
                    const SizedBox(height: 8),
                    SingleChildScrollView(
                      scrollDirection: Axis.horizontal,
                      child: Row(
                        children: fotos.map((url) {
                          return GestureDetector(
                            onTap: () => _verFoto(url),
                            child: Container(
                              margin: const EdgeInsets.only(right: 12),
                              child: ClipRRect(
                                borderRadius:
                                    BorderRadius.circular(12),
                                child: Image.network(
                                  url,
                                  width: 110,
                                  height: 110,
                                  fit: BoxFit.cover,
                                  loadingBuilder: (_, child, prog) {
                                    if (prog == null) return child;
                                    return Container(
                                      width: 110,
                                      height: 110,
                                      decoration: BoxDecoration(
                                        color: Colors.grey[100],
                                        borderRadius:
                                            BorderRadius.circular(12),
                                      ),
                                      child:
                                          const Center(
                                        child:
                                            CircularProgressIndicator(
                                                color: _accent,
                                                strokeWidth: 2),
                                      ),
                                    );
                                  },
                                  errorBuilder: (_, __, ___) =>
                                      Container(
                                    width: 110,
                                    height: 110,
                                    decoration: BoxDecoration(
                                      color: Colors.grey[100],
                                      borderRadius:
                                          BorderRadius.circular(12),
                                    ),
                                    child: Icon(
                                        Icons.broken_image_rounded,
                                        color: Colors.grey[400],
                                        size: 32),
                                  ),
                                ),
                              ),
                            ),
                          );
                        }).toList(),
                      ),
                    ),
                  ] else ...[
                    const SizedBox(height: 12),
                    Row(
                      children: [
                        Icon(Icons.image_not_supported_rounded,
                            size: 14, color: Colors.grey[400]),
                        const SizedBox(width: 6),
                        Text('Sin evidencia fotográfica',
                            style: TextStyle(
                                fontSize: 12,
                                color: Colors.grey[400],
                                fontStyle: FontStyle.italic)),
                      ],
                    ),
                  ],
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  // ── Ver foto en pantalla completa (solo lectura) ───────────────────────────
  void _verFoto(String url) {
    showGeneralDialog(
      context: context,
      barrierDismissible: true,
      barrierLabel: 'Cerrar',
      barrierColor: Colors.black87,
      transitionDuration: const Duration(milliseconds: 250),
      transitionBuilder: (_, anim, __, child) =>
          FadeTransition(opacity: anim, child: child),
      pageBuilder: (ctx, _, __) => Scaffold(
        backgroundColor: Colors.black,
        appBar: AppBar(
          backgroundColor: Colors.black,
          elevation: 0,
          foregroundColor: Colors.white,
          leading: IconButton(
            icon: const Icon(Icons.close_rounded),
            onPressed: () => Navigator.pop(ctx),
          ),
          title: const Text('Evidencia fotográfica',
              style: TextStyle(
                  fontSize: 15, fontWeight: FontWeight.w600)),
        ),
        body: Center(
          child: InteractiveViewer(
            minScale: 0.5,
            maxScale: 4.0,
            child: Image.network(
              url,
              fit: BoxFit.contain,
              loadingBuilder: (_, child, prog) {
                if (prog == null) return child;
                return const CircularProgressIndicator(
                    color: Colors.white);
              },
              errorBuilder: (_, __, ___) => const Icon(
                  Icons.broken_image_rounded,
                  color: Colors.white38,
                  size: 64),
            ),
          ),
        ),
      ),
    );
  }

  // ── Dato individual ───────────────────────────────────────────────────────
  Widget _datoItem(
      IconData icon, String label, String valor, Color color) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
      decoration: BoxDecoration(
        color: color.withOpacity(0.06),
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: color.withOpacity(0.15)),
      ),
      child: Row(
        children: [
          Icon(icon, size: 14, color: color),
          const SizedBox(width: 8),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(label,
                    style: TextStyle(
                        fontSize: 9,
                        fontWeight: FontWeight.w700,
                        color: color.withOpacity(0.7),
                        letterSpacing: 0.5)),
                const SizedBox(height: 2),
                Text(valor,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(
                        fontSize: 13,
                        fontWeight: FontWeight.w700,
                        color: color == _slate ? _primary : color)),
              ],
            ),
          ),
        ],
      ),
    );
  }
}