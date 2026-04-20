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
  // ── Colores ───────────────────────────────────────────────────────────────
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

  // ── Etiquetas dinámicas ───────────────────────────────────────────────────
  String get _labelMes {
    final raw = DateFormat('MMMM', 'es_MX').format(DateTime.now());
    return raw[0].toUpperCase() + raw.substring(1);
  }
  String get _labelAno => DateFormat('yyyy').format(DateTime.now());

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

  void _refresh() { _fadeCtrl..reset()..forward(); setState(() {}); }

  // ── Query ─────────────────────────────────────────────────────────────────
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

  // ── Filtros — fondo oscuro, mes y año dinámicos ───────────────────────────
  Widget _buildFiltros() {
    return Container(
      color: _primary,
      padding: const EdgeInsets.fromLTRB(14, 10, 14, 14),
      child: SingleChildScrollView(
        scrollDirection: Axis.horizontal,
        child: Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            _chip('hoy',    'Hoy',      Icons.today_rounded),
            _chip('semana', '7 días',   Icons.date_range_rounded),
            _chip('mes',    _labelMes,  Icons.calendar_month_rounded),
            _chip('año',    _labelAno,  Icons.calendar_today_rounded),
            _chip('todo',   'Todos',    Icons.all_inclusive_rounded),
          ],
        ),
      ),
    );
  }

  Widget _chip(String valor, String label, IconData icon) {
    final sel = _filtroPeriodo == valor;
    return GestureDetector(
      onTap: () {
        setState(() => _filtroPeriodo = valor);
        _refresh();
      },
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 180),
        margin: const EdgeInsets.only(right: 8),
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 9),
        decoration: BoxDecoration(
          color: sel ? _accent : Colors.white10,
          borderRadius: BorderRadius.circular(22),
          border: Border.all(color: sel ? _accent : Colors.white24),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(icon, size: 13,
                color: sel ? Colors.white : Colors.white60),
            const SizedBox(width: 6),
            Text(label,
                style: TextStyle(
                    fontSize: 13,
                    fontWeight: FontWeight.w700,
                    color: sel ? Colors.white : Colors.white60)),
          ],
        ),
      ),
    );
  }

  // ── Lista ─────────────────────────────────────────────────────────────────
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
            subtitulo: 'Aún no has enviado reportes en este período',
          );
        }

        return ListView.builder(
          padding: const EdgeInsets.fromLTRB(16, 16, 16, 28),
          itemCount: docs.length,
          itemBuilder: (_, i) => _buildCard(docs[i].data(), i),
        );
      },
    );
  }

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
            child: Icon(icon, size: 48, color: color.withOpacity(0.5)),
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
                style: TextStyle(fontSize: 13, color: Colors.grey[400])),
          ),
        ],
      ),
    );
  }

  // ── Tarjeta ───────────────────────────────────────────────────────────────
  Widget _buildCard(Map<String, dynamic> data, int index) {
    final fecha  = (data['fecha'] as Timestamp?)?.toDate();
    final fotos  = List<String>.from(data['fotosUrl'] ?? []);
    final visto  = data['visto'] == true;

    return TweenAnimationBuilder<double>(
      tween: Tween(begin: 0, end: 1),
      duration: Duration(milliseconds: 280 + (index * 50)),
      curve: Curves.easeOutCubic,
      builder: (context, val, child) => Transform.translate(
        offset: Offset(0, 16 * (1 - val)),
        child: Opacity(opacity: val, child: child),
      ),
      child: Container(
        margin: const EdgeInsets.only(bottom: 16),
        decoration: BoxDecoration(
          color: _surface,
          borderRadius: BorderRadius.circular(18),
          border: Border.all(
            color: visto
                ? _success.withOpacity(0.3)
                : _pending.withOpacity(0.4),
            width: 1.5,
          ),
          boxShadow: [
            BoxShadow(
              color: _primary.withOpacity(0.06),
              blurRadius: 16,
              offset: const Offset(0, 5),
            ),
          ],
        ),
        child: ClipRRect(
          borderRadius: BorderRadius.circular(18),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [

              // ── ALERTA GRANDE DE ESTADO ──────────────────────────────
              Container(
                width: double.infinity,
                padding: const EdgeInsets.symmetric(
                    horizontal: 20, vertical: 18),
                decoration: BoxDecoration(
                  color: visto
                      ? _success.withOpacity(0.10)
                      : _pending.withOpacity(0.10),
                  border: Border(
                    left: BorderSide(
                        color: visto ? _success : _pending, width: 6),
                    bottom: BorderSide(
                        color: (visto ? _success : _pending)
                            .withOpacity(0.2)),
                  ),
                ),
                child: Row(
                  children: [
                    // Ícono grande
                    Container(
                      padding: const EdgeInsets.all(10),
                      decoration: BoxDecoration(
                        color: (visto ? _success : _pending)
                            .withOpacity(0.15),
                        shape: BoxShape.circle,
                      ),
                      child: Icon(
                        visto
                            ? Icons.check_circle_rounded
                            : Icons.watch_later_rounded,
                        color: visto ? _success : _pending,
                        size: 32,
                      ),
                    ),
                    const SizedBox(width: 14),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            visto
                                ? '✅ El admin ya revisó tu reporte'
                                : '⏳ Aún no lo ha visto el admin',
                            style: TextStyle(
                              fontSize: 17,
                              fontWeight: FontWeight.w900,
                              color: visto ? _success : _pending,
                              height: 1.3,
                            ),
                          ),
                          const SizedBox(height: 4),
                          Text(
                            visto
                                ? 'Tu reporte fue revisado por el administrador.'
                                : 'Tu reporte está en espera de revisión.',
                            style: TextStyle(
                              fontSize: 13,
                              color: (visto ? _success : _pending)
                                  .withOpacity(0.8),
                              fontWeight: FontWeight.w500,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),

              // ── Fecha ────────────────────────────────────────────────
              Padding(
                padding:
                    const EdgeInsets.fromLTRB(16, 12, 16, 0),
                child: Row(
                  children: [
                    Icon(Icons.access_time_rounded,
                        size: 14, color: Colors.grey[400]),
                    const SizedBox(width: 5),
                    Text(
                      fecha != null
                          ? DateFormat('dd/MM/yyyy  HH:mm').format(fecha)
                          : '—',
                      style: TextStyle(
                          fontSize: 12,
                          color: Colors.grey[500],
                          fontWeight: FontWeight.w500),
                    ),
                  ],
                ),
              ),

              const SizedBox(height: 14),
              const Padding(
                padding: EdgeInsets.symmetric(horizontal: 16),
                child: Divider(color: Color(0xFFE2E8F0), height: 1),
              ),
              const SizedBox(height: 14),

              // ── DESCRIPCIÓN — texto más grande para adultos mayores ──
              Padding(
                padding: const EdgeInsets.fromLTRB(16, 0, 16, 0),
                child: Text(
                  'DESCRIPCIÓN DEL INCIDENTE',
                  style: TextStyle(
                      fontSize: 11,
                      fontWeight: FontWeight.w800,
                      color: _slate,
                      letterSpacing: 0.8),
                ),
              ),
              const SizedBox(height: 10),
              Padding(
                padding: const EdgeInsets.fromLTRB(16, 0, 16, 0),
                child: Container(
                  width: double.infinity,
                  padding: const EdgeInsets.all(16),
                  decoration: BoxDecoration(
                    color: const Color(0xFFF8FAFC),
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(color: const Color(0xFFE2E8F0)),
                  ),
                  child: Text(
                    data['mensaje'] ?? 'Sin descripción',
                    // ↓ Más grande para adultos mayores
                    style: const TextStyle(
                      fontSize: 17,
                      color: _primary,
                      fontWeight: FontWeight.w500,
                      height: 1.6,
                    ),
                  ),
                ),
              ),

              // ── FOTOS — botón "Ver fotografía" ───────────────────────
              if (fotos.isNotEmpty) ...[
                const SizedBox(height: 16),
                const Padding(
                  padding: EdgeInsets.symmetric(horizontal: 16),
                  child: Divider(color: Color(0xFFE2E8F0), height: 1),
                ),
                const SizedBox(height: 14),
                Padding(
                  padding: const EdgeInsets.fromLTRB(16, 0, 16, 0),
                  child: Text(
                    'EVIDENCIA FOTOGRÁFICA',
                    style: TextStyle(
                        fontSize: 11,
                        fontWeight: FontWeight.w800,
                        color: _slate,
                        letterSpacing: 0.8),
                  ),
                ),
                const SizedBox(height: 10),
                // Un botón por cada foto
                Padding(
                  padding: const EdgeInsets.fromLTRB(16, 0, 16, 0),
                  child: Column(
                    children: fotos.asMap().entries.map((e) {
                      final idx = e.key + 1;
                      final url = e.value;
                      return Padding(
                        padding: const EdgeInsets.only(bottom: 8),
                        child: SizedBox(
                          width: double.infinity,
                          child: OutlinedButton.icon(
                            style: OutlinedButton.styleFrom(
                              foregroundColor: _accent,
                              side: BorderSide(
                                  color: _accent.withOpacity(0.4)),
                              backgroundColor: _accent.withOpacity(0.05),
                              shape: RoundedRectangleBorder(
                                  borderRadius: BorderRadius.circular(12)),
                              padding: const EdgeInsets.symmetric(
                                  vertical: 14),
                            ),
                            onPressed: () => _verFoto(url),
                            icon: const Icon(Icons.photo_rounded, size: 20),
                            label: Text(
                              fotos.length == 1
                                  ? 'Ver fotografía'
                                  : 'Ver fotografía $idx',
                              style: const TextStyle(
                                  fontSize: 15,
                                  fontWeight: FontWeight.w700),
                            ),
                          ),
                        ),
                      );
                    }).toList(),
                  ),
                ),
              ],

              const SizedBox(height: 16),
            ],
          ),
        ),
      ),
    );
  }

  // ── Ver foto pantalla completa (solo lectura, sin descarga) ───────────────
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
}