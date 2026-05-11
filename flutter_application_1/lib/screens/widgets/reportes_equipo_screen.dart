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
  // ── Colores ───────────────────────────────────────────────────────────────
  static const Color _primary  = Color(0xFF0F172A);
  static const Color _accent   = Color(0xFFF59E0B);
  static const Color _success  = Color(0xFFF59E0B);
  static const Color _warning  = Color(0xFF7C3AED);
  static const Color _danger   = Color(0xFFEF4444);
  static const Color _bgColor  = Color(0xFFF8FAFC);
  static const Color _surface  = Color(0xFFFFFFFF);
  static const Color _slate    = Color(0xFF475569);
  static const Color _border   = Color(0xFFE2E8F0);

  // ── Estado de filtros ─────────────────────────────────────────────────────
  String    _filtroPeriodo  = 'hoy';
  DateTime? _filtroFecha;                  // fecha exacta del calendario
  String?   _filtroOperador;
  List<String> _operadores  = [];
  bool _cargandoOperadores  = true;

  late AnimationController _fadeCtrl;

  @override
  void initState() {
    super.initState();
    _fadeCtrl = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 380),
    )..forward();
    _cargarOperadores();
  }

  @override
  void dispose() {
    _fadeCtrl.dispose();
    super.dispose();
  }

  void _refresh() { _fadeCtrl..reset()..forward(); setState(() {}); }

  // ── Carga operadores únicos A-Z desde 'checklist' ─────────────────────────
  Future<void> _cargarOperadores() async {
    try {
      final snap =
          await FirebaseFirestore.instance.collection('checklist').get();
      final ops = snap.docs
          .map((d) => d.data()['operador']?.toString() ?? '')
          .where((o) => o.isNotEmpty)
          .toSet()
          .toList()
        ..sort((a, b) => a.toLowerCase().compareTo(b.toLowerCase()));
      if (mounted) {
        setState(() { _operadores = ops; _cargandoOperadores = false; });
      }
    } catch (_) {
      if (mounted) setState(() => _cargandoOperadores = false);
    }
  }

  // ── Calendario ────────────────────────────────────────────────────────────
  Future<void> _abrirCalendario() async {
    final picked = await showDatePicker(
      context: context,
      initialDate: _filtroFecha ?? DateTime.now(),
      firstDate: DateTime(2024),
      lastDate: DateTime.now(),
      locale: const Locale('es', 'MX'),
      builder: (ctx, child) => Theme(
        data: Theme.of(ctx).copyWith(
          colorScheme: const ColorScheme.light(
            primary: _primary,
            onPrimary: Colors.white,
            surface: _surface,
            onSurface: _primary,
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

  // ── Bottom sheet operadores ───────────────────────────────────────────────
  void _mostrarOperadores() {
    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      builder: (_) => _OperadorSheet(
        operadores: _operadores,
        seleccionado: _filtroOperador,
        onSelect: (op) { setState(() => _filtroOperador = op); _refresh(); },
      ),
    );
  }

  // ── Eliminar registro ─────────────────────────────────────────────────────
  Future<void> _eliminar(String docId) async {
    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(18)),
        backgroundColor: _surface,
        title: Row(
          children: [
            Container(
              padding: const EdgeInsets.all(8),
              decoration: BoxDecoration(
                color: _danger.withOpacity(0.1),
                borderRadius: BorderRadius.circular(10),
              ),
              child: const Icon(Icons.delete_outline_rounded,
                  color: _danger, size: 22),
            ),
            const SizedBox(width: 12),
            const Expanded(
              child: Text('Eliminar reporte',
                  style: TextStyle(fontSize: 16, fontWeight: FontWeight.w800)),
            ),
          ],
        ),
        content: const Text(
          '¿Estás seguro de que deseas eliminar este reporte?\nEsta acción no se puede deshacer.',
          style: TextStyle(fontSize: 13, height: 1.5, color: _slate),
        ),
        actionsPadding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
        actions: [
          OutlinedButton(
            style: OutlinedButton.styleFrom(
              foregroundColor: _slate,
              side: const BorderSide(color: _border),
              shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(10)),
              padding:
                  const EdgeInsets.symmetric(horizontal: 22, vertical: 11),
            ),
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text('Cancelar',
                style: TextStyle(fontWeight: FontWeight.w600)),
          ),
          ElevatedButton(
            style: ElevatedButton.styleFrom(
              backgroundColor: _danger,
              foregroundColor: Colors.white,
              elevation: 0,
              shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(10)),
              padding:
                  const EdgeInsets.symmetric(horizontal: 22, vertical: 11),
            ),
            onPressed: () => Navigator.pop(ctx, true),
            child: const Text('Sí, eliminar',
                style: TextStyle(fontWeight: FontWeight.w700)),
          ),
        ],
      ),
    );

    if (ok == true) {
      try {
        await FirebaseFirestore.instance
            .collection('checklist')
            .doc(docId)
            .delete();
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(SnackBar(
            content: const Text('Reporte eliminado',
                style: TextStyle(fontWeight: FontWeight.w600)),
            backgroundColor: _success,
            behavior: SnackBarBehavior.floating,
            shape:
                RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
          ));
        }
      } catch (e) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(SnackBar(
            content: Text('Error: $e'),
            backgroundColor: _danger,
            behavior: SnackBarBehavior.floating,
            shape:
                RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
          ));
        }
      }
    }
  }

  // ── Filtro de documentos en memoria ──────────────────────────────────────
  List<QueryDocumentSnapshot> _filtrar(List<QueryDocumentSnapshot> docs) {
    return docs.where((doc) {
      final data = doc.data() as Map<String, dynamic>;

      // Filtro operador
      if (_filtroOperador != null &&
          data['operador']?.toString() != _filtroOperador) return false;

      // Filtro fecha
      final ts = data['fecha'] as Timestamp?;
      if (ts == null) return false;
      final d   = ts.toDate();
      final now = DateTime.now();

      if (_filtroPeriodo == 'fecha' && _filtroFecha != null) {
        return d.year == _filtroFecha!.year &&
            d.month == _filtroFecha!.month &&
            d.day == _filtroFecha!.day;
      }

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
        case 'todo':
          return true;
      }
      if (desde != null && d.isBefore(desde)) return false;
      return true;
    }).toList();
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
            _buildHeroSection(),
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
      toolbarHeight: 74,
      title: const Text(
        'Reportes de Equipo',
        style: TextStyle(
          fontWeight: FontWeight.w800,
          fontSize: 18,
          color: Colors.white,
        ),
      ),
      backgroundColor: Colors.transparent,
      elevation: 0,
      foregroundColor: Colors.white,
      flexibleSpace: Container(
        decoration: const BoxDecoration(
          gradient: LinearGradient(
            colors: [Color(0xFF0A0A0A), Color(0xFF3F2A0A), Color(0xFFF59E0B)],
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
          ),
        ),
      ),
      bottom: const PreferredSize(
        preferredSize: Size.fromHeight(1),
        child: Divider(height: 1, thickness: 1, color: Color(0x33FFF3C4)),
      ),
    );
  }

  Widget _buildHeroSection() {
    return TweenAnimationBuilder<double>(
      tween: Tween(begin: 0, end: 1),
      duration: const Duration(milliseconds: 420),
      curve: Curves.easeOutCubic,
      builder: (context, value, child) => Transform.translate(
        offset: Offset(0, 14 * (1 - value)),
        child: Opacity(opacity: value, child: child),
      ),
      child: Container(
        margin: const EdgeInsets.fromLTRB(14, 14, 14, 10),
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          gradient: const LinearGradient(
            colors: [Color(0xFF0A0A0A), Color(0xFF7C4A07), Color(0xFFF59E0B)],
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
          ),
          borderRadius: BorderRadius.circular(22),
          boxShadow: [
            BoxShadow(
              color: const Color(0xFF0F172A).withValues(alpha: 0.10),
              blurRadius: 20,
              offset: const Offset(0, 10),
            ),
          ],
        ),
        child: Row(
          children: [
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: const Color(0x33FFF7D6),
                borderRadius: BorderRadius.circular(16),
                border: Border.all(color: const Color(0x66FFF3C4)),
              ),
              child: const Icon(
                Icons.assignment_turned_in_rounded,
                color: Colors.white,
                size: 24,
              ),
            ),
            const SizedBox(width: 14),
            const Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Control visual de faltantes',
                    style: TextStyle(
                      color: Colors.white,
                      fontSize: 15,
                      fontWeight: FontWeight.w800,
                    ),
                  ),
                  SizedBox(height: 4),
                  Text(
                    'Revisa equipo incompleto con filtros rápidos y una vista más limpia.',
                    style: TextStyle(
                      color: const Color(0xFFFFF3C4),
                      fontSize: 12.5,
                      height: 1.25,
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  // ── Barra de filtros (fondo oscuro igual que admin) ───────────────────────
  Widget _buildFiltros() {
    final hayActivo = _filtroOperador != null ||
        _filtroPeriodo != 'hoy' ||
        _filtroFecha != null;

    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 14),
      padding: const EdgeInsets.fromLTRB(14, 12, 14, 14),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: const Color(0xFFE2E8F0)),
        boxShadow: const [
          BoxShadow(
            color: Color(0x0F0F172A),
            blurRadius: 14,
            offset: Offset(0, 5),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.center,
        children: [
          // ── Fila 1: chips período + calendario ────────────────────
          SingleChildScrollView(
            scrollDirection: Axis.horizontal,
            child: Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                _chip('hoy',    'Hoy',     Icons.today_rounded),
                _chip('semana', 'Semana',  Icons.date_range_rounded),
                _chip('mes',    'Mes',     Icons.calendar_month_rounded),
                _chip('todo',   'Todo',    Icons.all_inclusive_rounded),
                const SizedBox(width: 8),
                Container(width: 1, height: 24, color: const Color(0xFFE2E8F0)),
                const SizedBox(width: 8),
                // Botón calendario
                GestureDetector(
                  onTap: _abrirCalendario,
                  child: AnimatedContainer(
                    duration: const Duration(milliseconds: 200),
                    padding: const EdgeInsets.symmetric(
                        horizontal: 14, vertical: 9),
                    decoration: BoxDecoration(
                        color: (_filtroPeriodo == 'fecha' && _filtroFecha != null)
                          ? const Color(0xFFFFF7D6)
                          : const Color(0xFFF8FAFC),
                      borderRadius: BorderRadius.circular(22),
                      border: Border.all(
                          color: (_filtroPeriodo == 'fecha' && _filtroFecha != null)
                            ? const Color(0xFFFDE68A).withValues(alpha: 0.35)
                            : const Color(0xFFE2E8F0),
                      ),
                    ),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Icon(Icons.event_rounded, size: 14,
                            color: (_filtroPeriodo == 'fecha' &&
                                    _filtroFecha != null)
                            ? const Color(0xFFB45309)
                          : _slate),
                        const SizedBox(width: 6),
                        Text(
                          (_filtroPeriodo == 'fecha' && _filtroFecha != null)
                              ? DateFormat('dd/MM/yy').format(_filtroFecha!)
                              : 'Fecha',
                          style: TextStyle(
                            fontSize: 13,
                            fontWeight: FontWeight.w700,
                            color: (_filtroPeriodo == 'fecha' &&
                                    _filtroFecha != null)
                                ? const Color(0xFFB45309)
                                : _slate,
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ],
            ),
          ),

          const SizedBox(height: 10),

          // ── Fila 2: operador (centrado) + limpiar ─────────────────
          Row(
            children: [
              Expanded(
                child: _cargandoOperadores
                    ? const SizedBox(
                        height: 38,
                        child: Center(
                          child: CircularProgressIndicator(
                              color: Colors.white38, strokeWidth: 2),
                        ),
                      )
                    : GestureDetector(
                        onTap: _operadores.isEmpty
                            ? null
                            : _mostrarOperadores,
                        child: AnimatedContainer(
                          duration: const Duration(milliseconds: 200),
                          padding: const EdgeInsets.symmetric(
                              horizontal: 14, vertical: 9),
                          decoration: BoxDecoration(
                            color: _filtroOperador != null
                              ? const Color(0xFFB45309)
                                : const Color(0xFFF8FAFC),
                            borderRadius: BorderRadius.circular(22),
                            border: Border.all(
                              color: _filtroOperador != null
                                  ? const Color(0xFFB45309)
                                  : const Color(0xFFE2E8F0),
                            ),
                          ),
                          child: Row(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              Icon(Icons.person_rounded,
                                  size: 14,
                                  color: _filtroOperador != null
                                      ? Colors.white
                                    : _slate),
                              const SizedBox(width: 7),
                              Flexible(
                                child: Text(
                                  _filtroOperador ??
                                      'Todos los operadores',
                                  overflow: TextOverflow.ellipsis,
                                  textAlign: TextAlign.center,
                                  style: TextStyle(
                                    fontSize: 13,
                                    fontWeight: FontWeight.w700,
                                    color: _filtroOperador != null
                                        ? Colors.white
                                        : _slate,
                                  ),
                                ),
                              ),
                              const SizedBox(width: 7),
                              Icon(Icons.expand_more_rounded,
                                  size: 16,
                                  color: _filtroOperador != null
                                      ? Colors.white
                                      : _slate),
                            ],
                          ),
                        ),
                      ),
              ),
              if (hayActivo) ...[
                const SizedBox(width: 8),
                GestureDetector(
                  onTap: () {
                    setState(() {
                      _filtroPeriodo  = 'hoy';
                      _filtroOperador = null;
                      _filtroFecha    = null;
                    });
                    _refresh();
                  },
                  child: Container(
                    padding: const EdgeInsets.symmetric(
                        horizontal: 12, vertical: 9),
                    decoration: BoxDecoration(
                      color: const Color(0xFFF8FAFC),
                      borderRadius: BorderRadius.circular(22),
                      border: Border.all(color: const Color(0xFFE2E8F0)),
                    ),
                    child: const Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Icon(Icons.close_rounded,
                            size: 13, color: Color(0xFF475569)),
                        SizedBox(width: 5),
                        Text('Limpiar',
                            style: TextStyle(
                                fontSize: 12,
                                fontWeight: FontWeight.w700,
                                color: Color(0xFF475569))),
                      ],
                    ),
                  ),
                ),
              ],
            ],
          ),
        ],
      ),
    );
  }

  Widget _chip(String valor, String label, IconData icon) {
    final sel = _filtroPeriodo == valor;
    return GestureDetector(
      onTap: () {
        setState(() { _filtroPeriodo = valor; _filtroFecha = null; });
        _refresh();
      },
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 180),
        margin: const EdgeInsets.only(right: 7),
        padding: const EdgeInsets.symmetric(horizontal: 13, vertical: 9),
        decoration: BoxDecoration(
          color: sel ? const Color(0xFFB45309) : const Color(0xFFF8FAFC),
          borderRadius: BorderRadius.circular(22),
          border: Border.all(color: sel ? const Color(0xFFB45309) : const Color(0xFFE2E8F0)),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(icon, size: 13, color: sel ? Colors.white : const Color(0xFF475569)),
            const SizedBox(width: 5),
            Text(label,
                style: TextStyle(
                    fontSize: 13,
                    fontWeight: FontWeight.w700,
                    color: sel ? Colors.white : const Color(0xFF475569))),
          ],
        ),
      ),
    );
  }

  // ── Lista ─────────────────────────────────────────────────────────────────
  Widget _buildLista() {
    return StreamBuilder<QuerySnapshot>(
      stream: FirebaseFirestore.instance
          .collection('checklist')
          .where('equipo_completo', isEqualTo: false)
          .snapshots(),
      builder: (context, snapshot) {
        if (snapshot.hasError) {
          return Center(
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Icon(Icons.cloud_off_rounded,
                    size: 48, color: _danger.withOpacity(0.4)),
                const SizedBox(height: 12),
                Text('Error al cargar datos',
                    style: TextStyle(
                        color: _primary.withOpacity(0.5),
                        fontWeight: FontWeight.w600)),
              ],
            ),
          );
        }
        if (snapshot.connectionState == ConnectionState.waiting) {
          return const Center(
              child: CircularProgressIndicator(color: _accent));
        }

        final filtrados = _filtrar(snapshot.data!.docs);

        if (filtrados.isEmpty) {
          return Center(
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Container(
                  padding: const EdgeInsets.all(20),
                  decoration: BoxDecoration(
                    color: _success.withOpacity(0.08),
                    shape: BoxShape.circle,
                  ),
                  child: Icon(Icons.fact_check_rounded,
                      size: 48, color: _success.withOpacity(0.4)),
                ),
                const SizedBox(height: 14),
                Text('Sin reportes faltantes',
                    style: TextStyle(
                        fontSize: 15,
                        fontWeight: FontWeight.w700,
                        color: _primary.withOpacity(0.5))),
                const SizedBox(height: 4),
                Text('No hay resultados para los filtros aplicados',
                    style:
                        TextStyle(fontSize: 12, color: Colors.grey[400])),
              ],
            ),
          );
        }

        return ListView.builder(
          padding: const EdgeInsets.fromLTRB(14, 12, 14, 24),
          itemCount: filtrados.length,
          itemBuilder: (context, i) =>
              _buildCard(filtrados[i].data() as Map<String, dynamic>,
                  filtrados[i].id, i),
        );
      },
    );
  }

  // ── Tarjeta compacta ──────────────────────────────────────────────────────
  Widget _buildCard(Map<String, dynamic> r, String docId, int index) {
    final hora = r['fecha'] != null
        ? DateFormat('HH:mm')
            .format((r['fecha'] as Timestamp).toDate())
        : '--:--';

    final fecha = r['fecha'] != null
        ? DateFormat('dd/MM/yy')
            .format((r['fecha'] as Timestamp).toDate())
        : '--';

    final faltantes = <String>[];
    if (r['cubrebocas'] == false) faltantes.add('Cubrebocas');
    if (r['gafas'] == false) faltantes.add('Gafas');
    if (r['guantes'] == false) faltantes.add('Guantes');
    if (r['uniforme'] == false) faltantes.add('Uniforme');

    return TweenAnimationBuilder<double>(
      tween: Tween(begin: 0, end: 1),
      duration: Duration(milliseconds: 280 + (index * 50)),
      curve: Curves.easeOutCubic,
      builder: (context, val, child) => Transform.translate(
        offset: Offset(0, 16 * (1 - val)),
        child: Opacity(opacity: val, child: child),
      ),
      child: Container(
        margin: const EdgeInsets.only(bottom: 10),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(18),
          border: Border.all(color: const Color(0xFFE2E8F0)),
          boxShadow: [
            BoxShadow(
              color: const Color(0xFF0F172A).withOpacity(0.08),
              blurRadius: 18,
              offset: const Offset(0, 10),
            ),
          ],
        ),
        child: ClipRRect(
          borderRadius: BorderRadius.circular(18),
          child: IntrinsicHeight(
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                // Barra lateral
                Container(
                  width: 5,
                  decoration: const BoxDecoration(
                    gradient: LinearGradient(
                      colors: [Color(0xFFB45309), Color(0xFFF59E0B)],
                      begin: Alignment.topCenter,
                      end: Alignment.bottomCenter,
                    ),
                  ),
                ),

                // Contenido
                Expanded(
                  child: Column(
                    children: [
                      // ── Cabecera ────────────────────────────────
                      Padding(
                        padding: const EdgeInsets.fromLTRB(12, 11, 12, 0),
                        child: Row(
                          children: [
                            // Avatar con inicial
                            CircleAvatar(
                              radius: 18,
                                backgroundColor: const Color(0xFFFFFBEB),
                              child: const Icon(
                                  Icons.warning_amber_rounded,
                                  color: Color(0xFFB45309),
                                  size: 18),
                            ),
                            const SizedBox(width: 10),
                            Expanded(
                              child: Column(
                                crossAxisAlignment:
                                    CrossAxisAlignment.start,
                                children: [
                                  Text(
                                    r['operador'] ?? 'Operador',
                                    style: const TextStyle(
                                        fontWeight: FontWeight.w800,
                                        fontSize: 14,
                                      color: Color(0xFF0F172A)),
                                  ),
                                  const SizedBox(height: 2),
                                  Row(
                                    children: [
                                      _miniTag(
                                          Icons.directions_bus_rounded,
                                          'Camión: ${r['camion'] ?? '—'}',
                                          Color(0xFF7C2D12)),
                                      const SizedBox(width: 6),
                                        _miniTag(Icons.access_time_rounded,
                                          '$fecha · $hora', const Color(0xFFB45309)),
                                    ],
                                  ),
                                ],
                              ),
                            ),
                            // Botón eliminar
                            GestureDetector(
                              onTap: () => _eliminar(docId),
                              child: Container(
                                padding: const EdgeInsets.all(7),
                                decoration: BoxDecoration(
                                  color: _danger.withOpacity(0.08),
                                  borderRadius: BorderRadius.circular(9),
                                  border: Border.all(
                                      color: _danger.withOpacity(0.2)),
                                ),
                                child: const Icon(
                                    Icons.delete_outline_rounded,
                                    size: 18,
                                    color: _danger),
                              ),
                            ),
                          ],
                        ),
                      ),

                      // ── Divider ─────────────────────────────────
                      const Padding(
                        padding: EdgeInsets.symmetric(
                            horizontal: 12, vertical: 10),
                        child: Divider(
                          height: 1, color: Color(0xFFE2E8F0)),
                      ),

                      // ── Faltantes ────────────────────────────────
                      Padding(
                        padding: const EdgeInsets.fromLTRB(12, 0, 12, 0),
                        child: Align(
                          alignment: Alignment.centerLeft,
                          child: Text('ARTÍCULOS FALTANTES',
                              style: TextStyle(
                                  fontSize: 10,
                                  fontWeight: FontWeight.w800,
                                color: Color(0xFF64748B),
                                  letterSpacing: 0.6)),
                        ),
                      ),
                      const SizedBox(height: 6),
                      Padding(
                        padding: const EdgeInsets.fromLTRB(12, 0, 12, 0),
                        child: Align(
                          alignment: Alignment.centerLeft,
                          child: faltantes.isEmpty
                              ? _chipOk('Sin faltantes')
                              : Wrap(
                                  spacing: 6,
                                  runSpacing: 6,
                                  children: faltantes
                                      .map(_chipError)
                                      .toList(),
                                ),
                        ),
                      ),

                      // ── Observaciones ────────────────────────────
                      if (r['reporte'] != null &&
                          r['reporte'].toString().trim().isNotEmpty) ...[
                        const Padding(
                          padding: EdgeInsets.symmetric(
                              horizontal: 12, vertical: 8),
                          child: Divider(
                              height: 1, color: Color(0xFFE2E8F0)),
                        ),
                        Padding(
                          padding:
                              const EdgeInsets.fromLTRB(12, 0, 12, 0),
                          child: Align(
                            alignment: Alignment.centerLeft,
                            child: Text('OBSERVACIONES',
                                style: TextStyle(
                                    fontSize: 10,
                                    fontWeight: FontWeight.w800,
                                  color: Color(0xFF64748B),
                                    letterSpacing: 0.6)),
                          ),
                        ),
                        const SizedBox(height: 5),
                        Padding(
                          padding:
                              const EdgeInsets.fromLTRB(12, 0, 12, 0),
                          child: Align(
                            alignment: Alignment.centerLeft,
                            child: Text(
                              r['reporte'].toString(),
                              style: const TextStyle(
                                  color: Color(0xFFB45309),
                                  fontSize: 13,
                                  height: 1.4),
                            ),
                          ),
                        ),
                      ],

                      const SizedBox(height: 12),
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

  Widget _miniTag(IconData icon, String label, Color color) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Icon(icon, size: 11, color: color),
        const SizedBox(width: 3),
        Text(label,
            style: TextStyle(
                fontSize: 11,
                fontWeight: FontWeight.w600,
                color: color)),
      ],
    );
  }

  Widget _chipError(String texto) => Container(
        padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 4),
        decoration: BoxDecoration(
          color: const Color(0xFFFEE2E2),
          borderRadius: BorderRadius.circular(6),
          border: Border.all(color: _danger.withOpacity(0.3)),
        ),
        child: Text(texto,
            style: const TextStyle(
                color: Color(0xFFB91C1C),
                fontSize: 11,
                fontWeight: FontWeight.w700)),
      );

  Widget _chipOk(String texto) => Container(
        padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 4),
        decoration: BoxDecoration(
          color: _success.withOpacity(0.1),
          borderRadius: BorderRadius.circular(6),
          border: Border.all(color: _success.withOpacity(0.25)),
        ),
        child: Text(texto,
            style: TextStyle(
                color: _success,
                fontSize: 11,
                fontWeight: FontWeight.w700)),
      );
}

// ── Bottom sheet operadores ────────────────────────────────────────────────────
class _OperadorSheet extends StatelessWidget {
  final List<String>          operadores;
  final String?               seleccionado;
  final ValueChanged<String?> onSelect;

  static const Color _primary = Color(0xFF0F172A);
  static const Color _accent  = Color(0xFF06B6D4);
  static const Color _success = Color(0xFF10B981);
  static const Color _danger  = Color(0xFFEF4444);
  static const Color _surface = Color(0xFFFFFFFF);
  static const Color _slate   = Color(0xFF64748B);

  const _OperadorSheet({
    required this.operadores,
    required this.seleccionado,
    required this.onSelect,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: const BoxDecoration(
        color: _surface,
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            margin: const EdgeInsets.only(top: 12),
            width: 36, height: 4,
            decoration: BoxDecoration(
                color: Colors.grey[300],
                borderRadius: BorderRadius.circular(4)),
          ),
          Padding(
            padding: const EdgeInsets.fromLTRB(20, 14, 20, 8),
            child: Row(
              children: [
                const Icon(Icons.person_search_rounded,
                    color: _accent, size: 20),
                const SizedBox(width: 8),
                const Text('Seleccionar operador',
                    style: TextStyle(
                        fontSize: 15,
                        fontWeight: FontWeight.w800,
                        color: _primary)),
                const Spacer(),
                if (seleccionado != null)
                  GestureDetector(
                    onTap: () {
                      onSelect(null);
                      Navigator.pop(context);
                    },
                    child: Container(
                      padding: const EdgeInsets.symmetric(
                          horizontal: 10, vertical: 4),
                      decoration: BoxDecoration(
                        color: _danger.withOpacity(0.08),
                        borderRadius: BorderRadius.circular(8),
                        border: Border.all(color: _danger.withOpacity(0.2)),
                      ),
                      child: const Text('Ver todos',
                          style: TextStyle(
                              fontSize: 11,
                              color: _danger,
                              fontWeight: FontWeight.w600)),
                    ),
                  ),
              ],
            ),
          ),
          const Divider(height: 1, color: Color(0xFFE2E8F0)),
          ConstrainedBox(
            constraints: BoxConstraints(
              maxHeight: MediaQuery.of(context).size.height * 0.42,
            ),
            child: ListView.builder(
              shrinkWrap: true,
              itemCount: operadores.length,
              itemBuilder: (_, i) {
                final op  = operadores[i];
                final sel = seleccionado == op;
                return ListTile(
                  dense: true,
                  leading: CircleAvatar(
                    radius: 17,
                    backgroundColor:
                        sel ? _primary : _accent.withOpacity(0.1),
                    child: Text(
                      op.isNotEmpty ? op[0].toUpperCase() : '?',
                      style: TextStyle(
                          fontSize: 13,
                          fontWeight: FontWeight.w800,
                          color: sel ? Colors.white : _accent),
                    ),
                  ),
                  title: Text(op,
                      style: TextStyle(
                          fontSize: 13,
                          fontWeight:
                              sel ? FontWeight.w800 : FontWeight.w500,
                          color: sel ? _primary : _slate)),
                  trailing: sel
                      ? const Icon(Icons.check_circle_rounded,
                          color: _success, size: 18)
                      : null,
                  onTap: () {
                    onSelect(op);
                    Navigator.pop(context);
                  },
                );
              },
            ),
          ),
          const SizedBox(height: 16),
        ],
      ),
    );
  }
}
