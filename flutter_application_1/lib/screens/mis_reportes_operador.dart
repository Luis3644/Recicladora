import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

// ─── Paleta recicladora ───────────────────────────────────────────────────────
class _C {
  static const bg         = Color(0xFFF0F4F8);
  static const surface    = Color(0xFFFFFFFF);
  static const navy       = Color(0xFF0F2754);
  static const navyMid    = Color(0xFF1A3A6B);
  static const navyLight  = Color(0xFFE8EEF8);
  static const blue       = Color(0xFF1D4ED8);
  static const text       = Color(0xFF0F172A);
  static const textSub    = Color(0xFF475569);
  static const textMuted  = Color(0xFF94A3B8);
  static const border     = Color(0xFFE2E8F0);
  static const borderSoft = Color(0xFFF1F5F9);
  static const success    = Color(0xFF059669);
  static const successBg  = Color(0xFFF0FDF8);
  static const successLight = Color(0xFF6EE7B7);
  static const pending    = Color(0xFFD97706);
  static const pendingBg  = Color(0xFFFFFBEB);
  static const pendingLight = Color(0xFFFCD34D);
  static const danger     = Color(0xFFDC2626);
}

class MisReportesOperador extends StatefulWidget {
  final String nombreOperador;
  const MisReportesOperador({super.key, required this.nombreOperador});

  @override
  State<MisReportesOperador> createState() => _MisReportesOperadorState();
}

class _MisReportesOperadorState extends State<MisReportesOperador>
    with SingleTickerProviderStateMixin {

  String    _filtroPeriodo = 'hoy';
  DateTime? _filtroFecha;

  String get _labelMes {
    final raw = DateFormat('MMMM', 'es_MX').format(DateTime.now());
    return raw[0].toUpperCase() + raw.substring(1);
  }
  String get _labelAno => DateFormat('yyyy').format(DateTime.now());

  late AnimationController _fadeCtrl;
  late String _operadorActivo;

  @override
  void initState() {
    super.initState();
    _operadorActivo = widget.nombreOperador;
    _fadeCtrl = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 350),
    )..forward();
  }

  @override
  void didUpdateWidget(MisReportesOperador oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.nombreOperador != widget.nombreOperador) {
      setState(() {
        _operadorActivo = widget.nombreOperador;
        _filtroPeriodo  = 'hoy';
        _filtroFecha    = null;
      });
      _refresh();
    }
  }

  @override
  void dispose() { _fadeCtrl.dispose(); super.dispose(); }

  void _refresh() { _fadeCtrl..reset()..forward(); setState(() {}); }

  Future<void> _abrirCalendario() async {
    final picked = await showDatePicker(
      context: context,
      initialDate: _filtroFecha ?? DateTime.now(),
      firstDate: DateTime(2020),
      lastDate: DateTime.now(),
      locale: const Locale('es', 'MX'),
      builder: (ctx, child) => Theme(
        data: Theme.of(ctx).copyWith(
          colorScheme: const ColorScheme.light(
            primary: _C.navy,
            onPrimary: Colors.white,
            surface: _C.surface,
            onSurface: _C.text,
          ),
        ),
        child: child!,
      ),
    );
    if (picked != null) {
      setState(() { _filtroFecha = picked; _filtroPeriodo = 'fecha'; });
      _refresh();
    }
  }

  Query<Map<String, dynamic>> _buildQuery() {
    Query<Map<String, dynamic>> q = FirebaseFirestore.instance
        .collection('reportes')
        .where('operador', isEqualTo: _operadorActivo)
        .orderBy('fecha', descending: true);

    final now = DateTime.now();
    DateTime? desde;
    DateTime? hasta;

    if (_filtroPeriodo == 'fecha' && _filtroFecha != null) {
      desde = DateTime(_filtroFecha!.year, _filtroFecha!.month, _filtroFecha!.day);
      hasta = desde.add(const Duration(days: 1));
    } else {
      switch (_filtroPeriodo) {
        case 'hoy':
          desde = DateTime(now.year, now.month, now.day); break;
        case 'semana':
          desde = now.subtract(const Duration(days: 7)); break;
        case 'mes':
          desde = DateTime(now.year, now.month, 1); break;
        case 'año':
          desde = DateTime(now.year, 1, 1); break;
        case 'todo': desde = null; break;
      }
    }

    if (desde != null)
      q = q.where('fecha', isGreaterThanOrEqualTo: Timestamp.fromDate(desde));
    if (hasta != null)
      q = q.where('fecha', isLessThan: Timestamp.fromDate(hasta));
    return q;
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: _C.bg,
      appBar: _buildAppBar(),
      body: FadeTransition(
        opacity: _fadeCtrl,
        child: Column(children: [
          _buildFiltros(),
          Expanded(child: _buildLista()),
        ]),
      ),
    );
  }

  // ── AppBar ─────────────────────────────────────────────────────────────────
  PreferredSizeWidget _buildAppBar() {
    return AppBar(
      backgroundColor: _C.navy,
      elevation: 0,
      titleSpacing: 0,
      automaticallyImplyLeading: false,
      title: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 16),
        child: Row(children: [
          // Botón back
          GestureDetector(
            onTap: () => Navigator.of(context).pop(),
            child: Container(
              width: 36, height: 36,
              decoration: BoxDecoration(
                color: Colors.white.withOpacity(0.10),
                borderRadius: BorderRadius.circular(10),
              ),
              child: const Icon(Icons.arrow_back_ios_new_rounded,
                  color: Colors.white, size: 16),
            ),
          ),
          const SizedBox(width: 12),
          // Ícono + títulos
          Container(
            padding: const EdgeInsets.all(8),
            decoration: BoxDecoration(
              color: _C.blue.withOpacity(0.30),
              borderRadius: BorderRadius.circular(11),
            ),
            child: const Icon(Icons.assignment_rounded,
                color: Colors.white, size: 18),
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                const Text('Mis Reportes',
                    style: TextStyle(
                        color: Colors.white,
                        fontSize: 15,
                        fontWeight: FontWeight.w800)),
                Text(_operadorActivo,
                    style: const TextStyle(
                        color: Color(0xFF93B4D8),
                        fontSize: 11,
                        fontWeight: FontWeight.w500)),
              ],
            ),
          ),
          // Badge total
          StreamBuilder<QuerySnapshot>(
            stream: FirebaseFirestore.instance
                .collection('reportes')
                .where('operador', isEqualTo: _operadorActivo)
                .snapshots(),
            builder: (_, snap) {
              final n = snap.data?.docs.length ?? 0;
              return Container(
                padding: const EdgeInsets.symmetric(
                    horizontal: 10, vertical: 5),
                decoration: BoxDecoration(
                  color: Colors.white.withOpacity(0.12),
                  borderRadius: BorderRadius.circular(20),
                  border: Border.all(
                      color: Colors.white.withOpacity(0.20)),
                ),
                child: Text('$n reportes',
                    style: const TextStyle(
                        color: Colors.white,
                        fontSize: 11,
                        fontWeight: FontWeight.w700)),
              );
            },
          ),
        ]),
      ),
      bottom: PreferredSize(
        preferredSize: const Size.fromHeight(1),
        child: Container(height: 1, color: _C.navyMid.withOpacity(0.6)),
      ),
    );
  }

  // ── Barra de filtros ───────────────────────────────────────────────────────
  Widget _buildFiltros() {
    return Container(
      color: _C.navy,
      padding: const EdgeInsets.fromLTRB(14, 8, 14, 14),
      child: SingleChildScrollView(
        scrollDirection: Axis.horizontal,
        child: Row(children: [
          _FilterChip(
            valor: 'hoy', label: 'Hoy',
            icon: Icons.today_rounded,
            activo: _filtroPeriodo == 'hoy',
            onTap: () { setState(() { _filtroPeriodo = 'hoy'; _filtroFecha = null; }); _refresh(); },
          ),
          _FilterChip(
            valor: 'semana', label: '7 días',
            icon: Icons.date_range_rounded,
            activo: _filtroPeriodo == 'semana',
            onTap: () { setState(() { _filtroPeriodo = 'semana'; _filtroFecha = null; }); _refresh(); },
          ),
          _FilterChip(
            valor: 'mes', label: _labelMes,
            icon: Icons.calendar_month_rounded,
            activo: _filtroPeriodo == 'mes',
            onTap: () { setState(() { _filtroPeriodo = 'mes'; _filtroFecha = null; }); _refresh(); },
          ),
          _FilterChip(
            valor: 'año', label: _labelAno,
            icon: Icons.calendar_today_rounded,
            activo: _filtroPeriodo == 'año',
            onTap: () { setState(() { _filtroPeriodo = 'año'; _filtroFecha = null; }); _refresh(); },
          ),
          _FilterChip(
            valor: 'todo', label: 'Todos',
            icon: Icons.all_inclusive_rounded,
            activo: _filtroPeriodo == 'todo',
            onTap: () { setState(() { _filtroPeriodo = 'todo'; _filtroFecha = null; }); _refresh(); },
          ),
          const SizedBox(width: 8),
          Container(width: 1, height: 24, color: Colors.white12),
          const SizedBox(width: 8),
          // Selector de fecha
          GestureDetector(
            onTap: _abrirCalendario,
            child: AnimatedContainer(
              duration: const Duration(milliseconds: 200),
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
              decoration: BoxDecoration(
                color: (_filtroPeriodo == 'fecha' && _filtroFecha != null)
                    ? const Color(0xFFF59E0B)
                    : Colors.white10,
                borderRadius: BorderRadius.circular(20),
                border: Border.all(
                  color: (_filtroPeriodo == 'fecha' && _filtroFecha != null)
                      ? const Color(0xFFF59E0B)
                      : Colors.white24,
                ),
              ),
              child: Row(mainAxisSize: MainAxisSize.min, children: [
                Icon(Icons.event_rounded, size: 13,
                    color: (_filtroPeriodo == 'fecha' && _filtroFecha != null)
                        ? _C.navy : Colors.white70),
                const SizedBox(width: 5),
                Text(
                  (_filtroPeriodo == 'fecha' && _filtroFecha != null)
                      ? DateFormat('dd/MM/yy').format(_filtroFecha!)
                      : 'Fecha',
                  style: TextStyle(
                    fontSize: 12,
                    fontWeight: FontWeight.w700,
                    color: (_filtroPeriodo == 'fecha' && _filtroFecha != null)
                        ? _C.navy : Colors.white70,
                  ),
                ),
              ]),
            ),
          ),
        ]),
      ),
    );
  }

  // ── Lista ──────────────────────────────────────────────────────────────────
  Widget _buildLista() {
    return StreamBuilder<QuerySnapshot<Map<String, dynamic>>>(
      key: ValueKey('$_operadorActivo-$_filtroPeriodo-$_filtroFecha'),
      stream: _buildQuery().snapshots(),
      builder: (context, snap) {
        if (snap.connectionState == ConnectionState.waiting) {
          return const Center(
            child: CircularProgressIndicator(
                color: _C.navy, strokeWidth: 2.5),
          );
        }
        if (snap.hasError) {
          return _EstadoVacio(
            icon: Icons.cloud_off_rounded,
            color: _C.danger,
            titulo: 'Error al cargar',
            subtitulo: 'Verifica tu conexión e intenta de nuevo',
          );
        }
        final docs = snap.data?.docs ?? [];
        if (docs.isEmpty) {
          return _EstadoVacio(
            icon: Icons.assignment_outlined,
            color: _C.textMuted,
            titulo: 'Sin reportes',
            subtitulo: _filtroPeriodo == 'hoy'
                ? 'No enviaste reportes hoy'
                : 'No hay reportes en este período',
          );
        }
        return ListView.builder(
          padding: const EdgeInsets.fromLTRB(14, 16, 14, 28),
          itemCount: docs.length,
          itemBuilder: (_, i) => _ReporteCard(
            data : docs[i].data(),
            index: i,
            onVerFoto: _verFoto,
          ),
        );
      },
    );
  }

  void _verFoto(String url) {
    showGeneralDialog(
      context: context,
      barrierDismissible: true,
      barrierLabel: 'Cerrar',
      barrierColor: Colors.black87,
      transitionDuration: const Duration(milliseconds: 220),
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
              style: TextStyle(fontSize: 15, fontWeight: FontWeight.w600)),
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
                return const Center(
                  child: CircularProgressIndicator(color: Colors.white),
                );
              },
              errorBuilder: (_, __, ___) => const Icon(
                  Icons.broken_image_rounded,
                  color: Colors.white38, size: 64),
            ),
          ),
        ),
      ),
    );
  }
}

// ─── Chip de filtro ───────────────────────────────────────────────────────────
class _FilterChip extends StatelessWidget {
  final String     valor;
  final String     label;
  final IconData   icon;
  final bool       activo;
  final VoidCallback onTap;
  const _FilterChip({
    required this.valor, required this.label, required this.icon,
    required this.activo, required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 180),
        margin: const EdgeInsets.only(right: 8),
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
        decoration: BoxDecoration(
          color: activo ? _C.blue : Colors.white10,
          borderRadius: BorderRadius.circular(20),
          border: Border.all(
              color: activo ? _C.blue : Colors.white24),
        ),
        child: Row(mainAxisSize: MainAxisSize.min, children: [
          Icon(icon, size: 12,
              color: activo ? Colors.white : Colors.white60),
          const SizedBox(width: 5),
          Text(label,
              style: TextStyle(
                  fontSize: 12,
                  fontWeight: FontWeight.w700,
                  color: activo ? Colors.white : Colors.white60)),
        ]),
      ),
    );
  }
}

// ─── Tarjeta de reporte ───────────────────────────────────────────────────────
class _ReporteCard extends StatelessWidget {
  final Map<String, dynamic> data;
  final int   index;
  final void Function(String) onVerFoto;

  const _ReporteCard({
    required this.data,
    required this.index,
    required this.onVerFoto,
  });

  @override
  Widget build(BuildContext context) {
    final fecha = (data['fecha'] as Timestamp?)?.toDate();
    final fotos = List<String>.from(data['fotosUrl'] ?? []);
    final visto = data['visto'] == true;

    final barColor    = visto ? _C.success    : _C.pending;
    final bgColor     = visto ? _C.successBg  : _C.pendingBg;
    final iconColor   = visto ? _C.success    : _C.pending;
    final titulo      = visto ? 'Admin revisó tu reporte' : 'En espera de revisión';
    final subtitulo   = visto
        ? 'Tu reporte fue atendido'
        : 'El admin aún no lo ha visto';
    final statusIcon  = visto
        ? Icons.check_circle_rounded
        : Icons.access_time_rounded;

    return TweenAnimationBuilder<double>(
      tween: Tween(begin: 0, end: 1),
      duration: Duration(milliseconds: 260 + (index * 45)),
      curve: Curves.easeOutCubic,
      builder: (_, val, child) => Transform.translate(
        offset: Offset(0, 18 * (1 - val)),
        child: Opacity(opacity: val, child: child),
      ),
      child: Container(
        margin: const EdgeInsets.only(bottom: 14),
        decoration: BoxDecoration(
          color: _C.surface,
          borderRadius: BorderRadius.circular(18),
          border: Border.all(
              color: barColor.withOpacity(0.25), width: 1.5),
          boxShadow: [
            BoxShadow(
                color: _C.navy.withOpacity(0.07),
                blurRadius: 14,
                offset: const Offset(0, 5)),
          ],
        ),
        child: ClipRRect(
          borderRadius: BorderRadius.circular(17),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // ── Barra de color superior ──────────────────────
              Container(
                height: 4,
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    colors: visto
                        ? [_C.success, const Color(0xFF34D399)]
                        : [_C.pending, const Color(0xFFFCD34D)],
                  ),
                ),
              ),

              // ── Encabezado de estado ─────────────────────────
              Container(
                padding: const EdgeInsets.fromLTRB(14, 13, 14, 13),
                color: bgColor,
                child: Row(children: [
                  // Ícono de estado
                  Container(
                    width: 40, height: 40,
                    decoration: BoxDecoration(
                      color: iconColor.withOpacity(0.12),
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: Icon(statusIcon,
                        color: iconColor, size: 22),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(titulo,
                            style: TextStyle(
                                fontSize: 13,
                                fontWeight: FontWeight.w800,
                                color: iconColor)),
                        const SizedBox(height: 2),
                        Text(subtitulo,
                            style: TextStyle(
                                fontSize: 11,
                                color: iconColor.withOpacity(0.75),
                                fontWeight: FontWeight.w500)),
                      ],
                    ),
                  ),
                  // Hora
                  Container(
                    padding: const EdgeInsets.symmetric(
                        horizontal: 9, vertical: 4),
                    decoration: BoxDecoration(
                      color: _C.surface,
                      borderRadius: BorderRadius.circular(10),
                      border: Border.all(color: _C.border),
                    ),
                    child: Row(mainAxisSize: MainAxisSize.min, children: [
                      const Icon(Icons.access_time_rounded,
                          size: 11, color: _C.textMuted),
                      const SizedBox(width: 4),
                      Text(
                        fecha != null
                            ? DateFormat('HH:mm').format(fecha)
                            : '—',
                        style: const TextStyle(
                            fontSize: 11,
                            color: _C.textSub,
                            fontWeight: FontWeight.w700),
                      ),
                    ]),
                  ),
                ]),
              ),

              // ── Separador ────────────────────────────────────
              Container(height: 1, color: _C.borderSoft),

              // ── Descripción ──────────────────────────────────
              Padding(
                padding: const EdgeInsets.fromLTRB(14, 14, 14, 0),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(children: [
                      Container(
                        padding: const EdgeInsets.all(5),
                        decoration: BoxDecoration(
                          color: _C.navyLight,
                          borderRadius: BorderRadius.circular(7),
                        ),
                        child: const Icon(Icons.notes_rounded,
                            size: 13, color: _C.navy),
                      ),
                      const SizedBox(width: 7),
                      const Text('DESCRIPCIÓN DEL INCIDENTE',
                          style: TextStyle(
                              fontSize: 10,
                              fontWeight: FontWeight.w800,
                              color: _C.textMuted,
                              letterSpacing: .8)),
                    ]),
                    const SizedBox(height: 10),
                    Container(
                      width: double.infinity,
                      padding: const EdgeInsets.all(13),
                      decoration: BoxDecoration(
                        color: const Color(0xFFF8FAFC),
                        borderRadius: BorderRadius.circular(12),
                        border: Border.all(color: _C.border),
                      ),
                      child: Text(
                        data['mensaje'] ?? 'Sin descripción',
                        style: const TextStyle(
                            fontSize: 13.5,
                            color: _C.text,
                            fontWeight: FontWeight.w500,
                            height: 1.65),
                      ),
                    ),
                  ],
                ),
              ),

              // ── Fotos ────────────────────────────────────────
              if (fotos.isNotEmpty) ...[
                const SizedBox(height: 12),
                Padding(
                  padding: const EdgeInsets.fromLTRB(14, 0, 14, 0),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(children: [
                        Container(
                          padding: const EdgeInsets.all(5),
                          decoration: BoxDecoration(
                            color: _C.navyLight,
                            borderRadius: BorderRadius.circular(7),
                          ),
                          child: const Icon(Icons.photo_library_rounded,
                              size: 13, color: _C.navy),
                        ),
                        const SizedBox(width: 7),
                        Text(
                          'EVIDENCIA FOTOGRÁFICA (${fotos.length})',
                          style: const TextStyle(
                              fontSize: 10,
                              fontWeight: FontWeight.w800,
                              color: _C.textMuted,
                              letterSpacing: .8),
                        ),
                      ]),
                      const SizedBox(height: 10),
                      SizedBox(
                        height: 80,
                        child: ListView.separated(
                          scrollDirection: Axis.horizontal,
                          itemCount: fotos.length,
                          separatorBuilder: (_, __) =>
                              const SizedBox(width: 8),
                          itemBuilder: (_, i) => _FotoThumb(
                            url  : fotos[i],
                            index: i + 1,
                            onTap: () => onVerFoto(fotos[i]),
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ],

              // ── Footer: fecha + indicador de fotos ───────────
              Padding(
                padding: const EdgeInsets.fromLTRB(14, 12, 14, 14),
                child: Row(children: [
                  const Icon(Icons.calendar_today_rounded,
                      size: 12, color: _C.textMuted),
                  const SizedBox(width: 5),
                  Text(
                    fecha != null
                        ? DateFormat('dd/MM/yyyy · HH:mm').format(fecha)
                        : '—',
                    style: const TextStyle(
                        fontSize: 11.5,
                        color: _C.textMuted,
                        fontWeight: FontWeight.w600),
                  ),
                  const Spacer(),
                  if (fotos.isEmpty)
                    Container(
                      padding: const EdgeInsets.symmetric(
                          horizontal: 10, vertical: 4),
                      decoration: BoxDecoration(
                        color: _C.pendingBg,
                        borderRadius: BorderRadius.circular(8),
                        border: Border.all(
                            color: _C.pending.withOpacity(0.3)),
                      ),
                      child: const Text('Sin fotos',
                          style: TextStyle(
                              fontSize: 11,
                              fontWeight: FontWeight.w700,
                              color: _C.pending)),
                    ),
                ]),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

// ─── Miniatura de foto ────────────────────────────────────────────────────────
class _FotoThumb extends StatelessWidget {
  final String url;
  final int    index;
  final VoidCallback onTap;
  const _FotoThumb({
    required this.url, required this.index, required this.onTap});

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Stack(children: [
        Container(
          width: 80, height: 80,
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(12),
            border: Border.all(color: _C.border, width: 1.5),
            boxShadow: [
              BoxShadow(color: Colors.black.withOpacity(0.07),
                  blurRadius: 8, offset: const Offset(0, 2)),
            ],
          ),
          child: ClipRRect(
            borderRadius: BorderRadius.circular(11),
            child: Image.network(
              url, fit: BoxFit.cover,
              loadingBuilder: (_, child, prog) => prog == null
                  ? child
                  : const Center(
                      child: SizedBox(width: 18, height: 18,
                          child: CircularProgressIndicator(
                              color: _C.navy, strokeWidth: 2))),
              errorBuilder: (_, __, ___) => Container(
                color: _C.navyLight,
                child: const Icon(Icons.broken_image_rounded,
                    color: _C.textMuted, size: 28)),
            ),
          ),
        ),
        // Etiqueta "Foto N"
        Positioned(
          bottom: 0, left: 0, right: 0,
          child: ClipRRect(
            borderRadius: const BorderRadius.vertical(
                bottom: Radius.circular(11)),
            child: Container(
              padding: const EdgeInsets.symmetric(vertical: 4),
              color: _C.navy.withOpacity(0.65),
              child: Text('Foto $index',
                  textAlign: TextAlign.center,
                  style: const TextStyle(
                      color: Colors.white,
                      fontSize: 9,
                      fontWeight: FontWeight.w800)),
            ),
          ),
        ),
        // Ícono de lupa encima
        Positioned(
          top: 6, right: 6,
          child: Container(
            padding: const EdgeInsets.all(4),
            decoration: BoxDecoration(
              color: Colors.white.withOpacity(0.85),
              borderRadius: BorderRadius.circular(6),
            ),
            child: const Icon(Icons.zoom_in_rounded,
                size: 12, color: _C.navy),
          ),
        ),
      ]),
    );
  }
}

// ─── Estado vacío ─────────────────────────────────────────────────────────────
class _EstadoVacio extends StatelessWidget {
  final IconData icon;
  final Color    color;
  final String   titulo;
  final String   subtitulo;
  const _EstadoVacio({
    required this.icon, required this.color,
    required this.titulo, required this.subtitulo,
  });

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Container(
            padding: const EdgeInsets.all(22),
            decoration: BoxDecoration(
              color: color.withOpacity(0.07),
              shape: BoxShape.circle,
              border: Border.all(
                  color: color.withOpacity(0.15), width: 1.5),
            ),
            child: Icon(icon, size: 40, color: color.withOpacity(0.5)),
          ),
          const SizedBox(height: 18),
          Text(titulo,
              style: TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.w800,
                  color: _C.text.withOpacity(0.5))),
          const SizedBox(height: 6),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 40),
            child: Text(subtitulo,
                textAlign: TextAlign.center,
                style: const TextStyle(
                    fontSize: 13, color: _C.textMuted, height: 1.5)),
          ),
        ],
      ),
    );
  }
}