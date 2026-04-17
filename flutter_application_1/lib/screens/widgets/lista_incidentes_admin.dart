import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:intl/intl.dart';
import 'package:http/http.dart' as http;
import 'package:path_provider/path_provider.dart';
import 'package:open_file/open_file.dart';

// Solo en Web
// ignore: avoid_web_libraries_in_flutter
import 'dart:html' as html;

class ListaIncidentesAdmin extends StatefulWidget {
  const ListaIncidentesAdmin({super.key});

  @override
  State<ListaIncidentesAdmin> createState() => _ListaIncidentesAdminState();
}

class _ListaIncidentesAdminState extends State<ListaIncidentesAdmin>
    with SingleTickerProviderStateMixin {
  // ── Colores ───────────────────────────────────────────────────────────────
  static const Color _primary  = Color(0xFF0F172A);
  static const Color _accent   = Color(0xFF06B6D4);
  static const Color _success  = Color(0xFF10B981);
  static const Color _danger   = Color(0xFFEF4444);
  static const Color _bgColor  = Color(0xFFF0F9FF);
  static const Color _surface  = Color(0xFFFFFFFF);
  static const Color _slate    = Color(0xFF64748B);
  static const Color _border   = Color(0xFFE2E8F0);

  // ── Filtros ───────────────────────────────────────────────────────────────
  String   _filtroPeriodo  = 'hoy';
  String?  _filtroOperador;
  DateTime? _filtroFecha;          // ← fecha exacta del calendario
  List<String> _operadores = [];
  bool _cargandoOperadores = true;

  // ── Animación ─────────────────────────────────────────────────────────────
  late AnimationController _fadeCtrl;

  @override
  void initState() {
    super.initState();
    _fadeCtrl = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 350),
    )..forward();
    _cargarOperadores();
  }

  @override
  void dispose() {
    _fadeCtrl.dispose();
    super.dispose();
  }

  void _refresh() {
    _fadeCtrl..reset()..forward();
    setState(() {});
  }

  // ── Operadores A-Z ────────────────────────────────────────────────────────
  Future<void> _cargarOperadores() async {
    try {
      final snap =
          await FirebaseFirestore.instance.collection('reportes').get();
      final ops = snap.docs
          .map((d) => d.data()['operador']?.toString() ?? '')
          .where((o) => o.isNotEmpty)
          .toSet()
          .toList()
        ..sort((a, b) => a.toLowerCase().compareTo(b.toLowerCase()));
      if (mounted) setState(() { _operadores = ops; _cargandoOperadores = false; });
    } catch (_) {
      if (mounted) setState(() => _cargandoOperadores = false);
    }
  }

  // ── Calendario ────────────────────────────────────────────────────────────
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
            primary: _primary,
            onPrimary: Colors.white,
            surface: _surface,
            onSurface: _primary,
          ),
          dialogBackgroundColor: _surface,
        ),
        child: child!,
      ),
    );
    if (picked != null) {
      setState(() {
        _filtroFecha   = picked;
        _filtroPeriodo = 'fecha'; // modo especial
      });
      _refresh();
    }
  }

  // ── Dropdown operadores ───────────────────────────────────────────────────
  void _mostrarDropdownOperadores() {
    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      builder: (_) => _OperadorSheet(
        operadores: _operadores,
        seleccionado: _filtroOperador,
        onSelect: (op) {
          setState(() => _filtroOperador = op);
          _refresh();
        },
      ),
    );
  }

  // ── Marcar visto ──────────────────────────────────────────────────────────
  Future<void> _marcarVisto(String docId, bool visto) async {
    try {
      await FirebaseFirestore.instance
          .collection('reportes')
          .doc(docId)
          .update({'visto': visto});
    } catch (e) {
      _snack('Error al actualizar: $e', _danger);
    }
  }

  // ── Eliminar reporte ──────────────────────────────────────────────────────
  Future<void> _eliminarReporte(String docId) async {
    final confirmar = await showDialog<bool>(
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
                  color: _danger, size: 20),
            ),
            const SizedBox(width: 12),
            const Text('Eliminar reporte',
                style: TextStyle(fontSize: 16, fontWeight: FontWeight.w800)),
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
              padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 10),
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
              padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 10),
            ),
            onPressed: () => Navigator.pop(ctx, true),
            child: const Text('Sí, eliminar',
                style: TextStyle(fontWeight: FontWeight.w700)),
          ),
        ],
      ),
    );

    if (confirmar == true) {
      try {
        await FirebaseFirestore.instance
            .collection('reportes')
            .doc(docId)
            .delete();
        _snack('Reporte eliminado', _success);
      } catch (e) {
        _snack('Error al eliminar: $e', _danger);
      }
    }
  }

  // ── Query ─────────────────────────────────────────────────────────────────
  Query<Map<String, dynamic>> _buildQuery() {
    Query<Map<String, dynamic>> q = FirebaseFirestore.instance
        .collection('reportes')
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
      }
    }

    if (desde != null) {
      q = q.where('fecha', isGreaterThanOrEqualTo: Timestamp.fromDate(desde));
    }
    if (hasta != null) {
      q = q.where('fecha', isLessThan: Timestamp.fromDate(hasta));
    }
    return q;
  }

  List<QueryDocumentSnapshot<Map<String, dynamic>>> _filtrarDocs(
      List<QueryDocumentSnapshot<Map<String, dynamic>>> docs) {
    if (_filtroOperador == null) return docs;
    return docs
        .where((d) => d.data()['operador']?.toString() == _filtroOperador)
        .toList();
  }

  // ── Descarga imagen ───────────────────────────────────────────────────────
  Future<void> _descargarImagen(String url, String nombre) async {
    try {
      _snack('Iniciando descarga...', _accent);
      final response = await http.get(Uri.parse(url));
      final bytes = response.bodyBytes;
      if (kIsWeb) {
        final blob = html.Blob([bytes]);
        final blobUrl = html.Url.createObjectUrlFromBlob(blob);
        final anchor = html.AnchorElement(href: blobUrl)
          ..setAttribute('download', '$nombre.jpg')
          ..click();
        html.Url.revokeObjectUrl(blobUrl);
      } else {
        final dir = await getTemporaryDirectory();
        final file = File('${dir.path}/$nombre.jpg');
        await file.writeAsBytes(bytes);
        await OpenFile.open(file.path);
      }
      _snack('Imagen descargada', _success);
    } catch (e) {
      _snack('Error: $e', _danger);
    }
  }

  // ── Ver foto ──────────────────────────────────────────────────────────────
  void _verFoto(String url, String nombre) {
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
              onPressed: () => Navigator.pop(ctx)),
          title: const Text('Evidencia',
              style: TextStyle(fontSize: 15, fontWeight: FontWeight.w600)),
          actions: [
            IconButton(
              icon: const Icon(Icons.download_rounded),
              onPressed: () { Navigator.pop(ctx); _descargarImagen(url, nombre); },
            ),
          ],
        ),
        body: Center(
          child: InteractiveViewer(
            minScale: 0.5,
            maxScale: 4.0,
            child: Image.network(url, fit: BoxFit.contain,
              errorBuilder: (_, __, ___) => const Icon(
                  Icons.broken_image_rounded, color: Colors.white38, size: 64)),
          ),
        ),
      ),
    );
  }

  void _snack(String msg, Color color) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(
      content: Text(msg, style: const TextStyle(fontWeight: FontWeight.w600)),
      backgroundColor: color,
      behavior: SnackBarBehavior.floating,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
    ));
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
      title: const Text('Reportes',
          style: TextStyle(fontWeight: FontWeight.w800, fontSize: 18)),
      backgroundColor: Colors.transparent,
      elevation: 0,
      foregroundColor: Colors.white,
      flexibleSpace: Container(
        decoration: const BoxDecoration(
          gradient: LinearGradient(
            colors: [_primary, Color(0xFF1E3A5F)],
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
          ),
        ),
      ),
    );
  }

  // ── Filtros compactos ─────────────────────────────────────────────────────
  Widget _buildFiltros() {
    final hayFiltroActivo = _filtroOperador != null ||
        _filtroPeriodo != 'hoy' ||
        _filtroFecha != null;

    return Container(
      color: _primary,
      padding: const EdgeInsets.fromLTRB(12, 8, 12, 12),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // ── Fila 1: chips de período + calendario ──────────────────
          SingleChildScrollView(
            scrollDirection: Axis.horizontal,
            child: Row(
              children: [
                _chipPeriodo('hoy',    'Hoy',      Icons.today_rounded),
                _chipPeriodo('semana', '7 días',   Icons.date_range_rounded),
                _chipPeriodo('mes',    'Mes',      Icons.calendar_month_rounded),
                _chipPeriodo('año',    'Año',      Icons.calendar_today_rounded),
                _chipPeriodo('todo',   'Todo',     Icons.all_inclusive_rounded),
                const SizedBox(width: 6),
                // Separador visual
                Container(width: 1, height: 22, color: Colors.white12),
                const SizedBox(width: 6),
                // Botón calendario
                GestureDetector(
                  onTap: _abrirCalendario,
                  child: AnimatedContainer(
                    duration: const Duration(milliseconds: 200),
                    padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 7),
                    decoration: BoxDecoration(
                      color: (_filtroPeriodo == 'fecha' && _filtroFecha != null)
                          ? Colors.amber
                          : Colors.white12,
                      borderRadius: BorderRadius.circular(20),
                      border: Border.all(
                        color: (_filtroPeriodo == 'fecha' && _filtroFecha != null)
                            ? Colors.amber
                            : Colors.white24,
                      ),
                    ),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Icon(Icons.event_rounded, size: 13,
                          color: (_filtroPeriodo == 'fecha' && _filtroFecha != null)
                              ? _primary : Colors.white70),
                        const SizedBox(width: 5),
                        Text(
                          (_filtroPeriodo == 'fecha' && _filtroFecha != null)
                              ? DateFormat('dd/MM/yy').format(_filtroFecha!)
                              : 'Fecha',
                          style: TextStyle(
                            fontSize: 12,
                            fontWeight: FontWeight.w700,
                            color: (_filtroPeriodo == 'fecha' && _filtroFecha != null)
                                ? _primary : Colors.white70,
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ],
            ),
          ),

          const SizedBox(height: 8),

          // ── Fila 2: filtro operador + limpiar ─────────────────────
          Row(
            children: [
              // Botón operador
              Expanded(
                child: _cargandoOperadores
                    ? const SizedBox(height: 34,
                        child: Center(child: CircularProgressIndicator(
                            color: Colors.white38, strokeWidth: 2)))
                    : GestureDetector(
                        onTap: _operadores.isEmpty ? null : _mostrarDropdownOperadores,
                        child: AnimatedContainer(
                          duration: const Duration(milliseconds: 200),
                          padding: const EdgeInsets.symmetric(
                              horizontal: 12, vertical: 7),
                          decoration: BoxDecoration(
                            color: _filtroOperador != null
                                ? _accent : Colors.white10,
                            borderRadius: BorderRadius.circular(20),
                            border: Border.all(
                              color: _filtroOperador != null
                                  ? _accent : Colors.white24,
                            ),
                          ),
                          child: Row(
                            children: [
                              Icon(Icons.person_rounded, size: 13,
                                  color: _filtroOperador != null
                                      ? Colors.white : Colors.white60),
                              const SizedBox(width: 6),
                              Expanded(
                                child: Text(
                                  _filtroOperador ?? 'Todos los operadores',
                                  overflow: TextOverflow.ellipsis,
                                  style: TextStyle(
                                    fontSize: 12,
                                    fontWeight: FontWeight.w700,
                                    color: _filtroOperador != null
                                        ? Colors.white : Colors.white60,
                                  ),
                                ),
                              ),
                              Icon(Icons.expand_more_rounded, size: 15,
                                  color: _filtroOperador != null
                                      ? Colors.white : Colors.white38),
                            ],
                          ),
                        ),
                      ),
              ),

              // Botón limpiar (solo si hay filtros activos)
              if (hayFiltroActivo) ...[
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
                        horizontal: 10, vertical: 7),
                    decoration: BoxDecoration(
                      color: _danger.withOpacity(0.15),
                      borderRadius: BorderRadius.circular(20),
                      border: Border.all(color: _danger.withOpacity(0.4)),
                    ),
                    child: const Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Icon(Icons.close_rounded, size: 12, color: Colors.redAccent),
                        SizedBox(width: 4),
                        Text('Limpiar',
                            style: TextStyle(
                                fontSize: 11,
                                fontWeight: FontWeight.w700,
                                color: Colors.redAccent)),
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

  Widget _chipPeriodo(String valor, String label, IconData icon) {
    final sel = _filtroPeriodo == valor;
    return GestureDetector(
      onTap: () {
        setState(() { _filtroPeriodo = valor; _filtroFecha = null; });
        _refresh();
      },
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 180),
        margin: const EdgeInsets.only(right: 6),
        padding: const EdgeInsets.symmetric(horizontal: 11, vertical: 7),
        decoration: BoxDecoration(
          color: sel ? _accent : Colors.white10,
          borderRadius: BorderRadius.circular(20),
          border: Border.all(color: sel ? _accent : Colors.white24),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(icon, size: 12, color: sel ? Colors.white : Colors.white60),
            const SizedBox(width: 5),
            Text(label,
                style: TextStyle(
                    fontSize: 12,
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
          return const Center(child: CircularProgressIndicator(color: _accent));
        }
        if (snap.hasError) {
          return _estadoVacio(Icons.cloud_off_rounded, _danger,
              'Error al cargar', snap.error.toString());
        }
        final todos = snap.data?.docs ?? [];
        final docs  = _filtrarDocs(todos);

        if (docs.isEmpty) {
          return _estadoVacio(Icons.inbox_rounded, _slate,
              'Sin reportes', 'No hay resultados para los filtros aplicados');
        }

        return ListView.builder(
          padding: const EdgeInsets.fromLTRB(12, 12, 12, 24),
          itemCount: docs.length,
          itemBuilder: (_, i) => _buildCard(docs[i].data(), docs[i].id),
        );
      },
    );
  }

  Widget _estadoVacio(
      IconData icon, Color color, String titulo, String subtitulo) {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Container(
            padding: const EdgeInsets.all(18),
            decoration: BoxDecoration(
                color: color.withOpacity(0.08), shape: BoxShape.circle),
            child: Icon(icon, size: 40, color: color.withOpacity(0.4)),
          ),
          const SizedBox(height: 14),
          Text(titulo,
              style: TextStyle(
                  fontSize: 15,
                  fontWeight: FontWeight.w700,
                  color: _primary.withOpacity(0.5))),
          const SizedBox(height: 4),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 40),
            child: Text(subtitulo,
                textAlign: TextAlign.center,
                style: TextStyle(fontSize: 12, color: Colors.grey[400])),
          ),
        ],
      ),
    );
  }

  // ── Tarjeta COMPACTA ──────────────────────────────────────────────────────
  Widget _buildCard(Map<String, dynamic> data, String docId) {
    final fecha    = (data['fecha'] as Timestamp?)?.toDate();
    final fotos    = List<String>.from(data['fotosUrl'] ?? []);
    final operador = data['operador'] ?? '—';
    final visto    = data['visto'] == true;

    return Container(
      margin: const EdgeInsets.only(bottom: 10),
      decoration: BoxDecoration(
        color: _surface,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(
          color: visto ? _border : _danger.withOpacity(0.2),
          width: 1,
        ),
        boxShadow: [
          BoxShadow(
            color: _primary.withOpacity(0.05),
            blurRadius: 10,
            offset: const Offset(0, 3),
          ),
        ],
      ),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(14),
        child: IntrinsicHeight(
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              // ── Barra lateral de color ─────────────────────────────
              Container(
                width: 4,
                color: visto ? _success : _danger,
              ),

              // ── Contenido ─────────────────────────────────────────
              Expanded(
                child: Padding(
                  padding: const EdgeInsets.all(12),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      // ── Fila superior: estado + fecha + acciones ──
                      Row(
                        children: [
                          // Badge estado
                          Container(
                            padding: const EdgeInsets.symmetric(
                                horizontal: 8, vertical: 3),
                            decoration: BoxDecoration(
                              color: (visto ? _success : _danger)
                                  .withOpacity(0.1),
                              borderRadius: BorderRadius.circular(6),
                            ),
                            child: Row(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                Icon(
                                  visto
                                      ? Icons.check_circle_rounded
                                      : Icons.radio_button_unchecked_rounded,
                                  size: 10,
                                  color: visto ? _success : _danger,
                                ),
                                const SizedBox(width: 4),
                                Text(
                                  visto ? 'VISTO' : 'PENDIENTE',
                                  style: TextStyle(
                                    fontSize: 9,
                                    fontWeight: FontWeight.w800,
                                    color: visto ? _success : _danger,
                                    letterSpacing: 0.5,
                                  ),
                                ),
                              ],
                            ),
                          ),
                          const Spacer(),
                          // Fecha
                          Text(
                            fecha != null
                                ? DateFormat('dd/MM/yy · HH:mm').format(fecha)
                                : '—',
                            style: const TextStyle(
                                fontSize: 10,
                                color: _slate,
                                fontWeight: FontWeight.w500),
                          ),
                          const SizedBox(width: 8),
                          // Botón eliminar
                          GestureDetector(
                            onTap: () => _eliminarReporte(docId),
                            child: Container(
                              padding: const EdgeInsets.all(5),
                              decoration: BoxDecoration(
                                color: _danger.withOpacity(0.08),
                                borderRadius: BorderRadius.circular(7),
                              ),
                              child: const Icon(Icons.delete_outline_rounded,
                                  size: 14, color: _danger),
                            ),
                          ),
                        ],
                      ),

                      const SizedBox(height: 10),

                      // ── Fila info: operador + camión + placas ─────
                      Row(
                        children: [
                          _miniTag(Icons.person_rounded, operador, _accent),
                          const SizedBox(width: 6),
                          _miniTag(Icons.directions_bus_rounded,
                              data['camion'] ?? '—', _slate),
                          const SizedBox(width: 6),
                          _miniTag(Icons.pin_rounded,
                              data['placas'] ?? '—', _success),
                        ],
                      ),

                      const SizedBox(height: 10),

                      // ── Mensaje (truncado 2 líneas) ───────────────
                      Text(
                        data['mensaje'] ?? 'Sin descripción',
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                        style: const TextStyle(
                          fontSize: 13,
                          color: _primary,
                          fontWeight: FontWeight.w500,
                          height: 1.4,
                        ),
                      ),

                      // ── Fotos en miniatura ────────────────────────
                      if (fotos.isNotEmpty) ...[
                        const SizedBox(height: 10),
                        SingleChildScrollView(
                          scrollDirection: Axis.horizontal,
                          child: Row(
                            children: fotos.asMap().entries.map((e) {
                              final idx = e.key + 1;
                              final url = e.value;
                              return _fotoMini(
                                  url, '${operador}_incidente_$idx');
                            }).toList(),
                          ),
                        ),
                      ],

                      const SizedBox(height: 10),

                      // ── Botón visto (compacto) ────────────────────
                      SizedBox(
                        width: double.infinity,
                        height: 34,
                        child: visto
                            ? OutlinedButton.icon(
                                style: OutlinedButton.styleFrom(
                                  foregroundColor: _slate,
                                  side: const BorderSide(color: _border),
                                  shape: RoundedRectangleBorder(
                                      borderRadius: BorderRadius.circular(8)),
                                  padding: EdgeInsets.zero,
                                ),
                                onPressed: () => _marcarVisto(docId, false),
                                icon: const Icon(
                                    Icons.remove_circle_outline_rounded,
                                    size: 14),
                                label: const Text('Marcar no visto',
                                    style: TextStyle(
                                        fontSize: 12,
                                        fontWeight: FontWeight.w600)),
                              )
                            : ElevatedButton.icon(
                                style: ElevatedButton.styleFrom(
                                  backgroundColor: _success,
                                  foregroundColor: Colors.white,
                                  elevation: 0,
                                  shape: RoundedRectangleBorder(
                                      borderRadius: BorderRadius.circular(8)),
                                  padding: EdgeInsets.zero,
                                ),
                                onPressed: () => _marcarVisto(docId, true),
                                icon: const Icon(Icons.check_circle_rounded,
                                    size: 14),
                                label: const Text('Marcar como visto',
                                    style: TextStyle(
                                        fontSize: 12,
                                        fontWeight: FontWeight.w700)),
                              ),
                      ),
                    ],
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  // ── Mini tag (operador / camión / placas) ─────────────────────────────────
  Widget _miniTag(IconData icon, String label, Color color) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(
        color: color.withOpacity(0.07),
        borderRadius: BorderRadius.circular(6),
        border: Border.all(color: color.withOpacity(0.15)),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 11, color: color),
          const SizedBox(width: 4),
          Text(
            label,
            style: TextStyle(
                fontSize: 11,
                fontWeight: FontWeight.w700,
                color: color == _slate ? _primary : color),
          ),
        ],
      ),
    );
  }

  // ── Foto mini ─────────────────────────────────────────────────────────────
  Widget _fotoMini(String url, String nombre) {
    return GestureDetector(
      onTap: () => _verFoto(url, nombre),
      child: Container(
        margin: const EdgeInsets.only(right: 8),
        child: Stack(
          children: [
            ClipRRect(
              borderRadius: BorderRadius.circular(8),
              child: Image.network(url,
                width: 72, height: 72, fit: BoxFit.cover,
                errorBuilder: (_, __, ___) => Container(
                  width: 72, height: 72,
                  decoration: BoxDecoration(
                    color: Colors.grey[100],
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Icon(Icons.broken_image_rounded,
                      color: Colors.grey[400], size: 24),
                ),
              ),
            ),
            Positioned(
              bottom: 4, right: 4,
              child: GestureDetector(
                onTap: () => _descargarImagen(url, nombre),
                child: Container(
                  padding: const EdgeInsets.all(4),
                  decoration: BoxDecoration(
                    color: _primary.withOpacity(0.8),
                    borderRadius: BorderRadius.circular(5),
                  ),
                  child: const Icon(Icons.download_rounded,
                      color: Colors.white, size: 11),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

// ── Bottom sheet de operadores ────────────────────────────────────────────────
class _OperadorSheet extends StatelessWidget {
  final List<String>  operadores;
  final String?       seleccionado;
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
              borderRadius: BorderRadius.circular(4),
            ),
          ),
          Padding(
            padding: const EdgeInsets.fromLTRB(20, 14, 20, 8),
            child: Row(
              children: [
                const Icon(Icons.person_search_rounded, color: _accent, size: 18),
                const SizedBox(width: 8),
                const Text('Seleccionar operador',
                    style: TextStyle(fontSize: 15, fontWeight: FontWeight.w800,
                        color: _primary)),
                const Spacer(),
                if (seleccionado != null)
                  GestureDetector(
                    onTap: () { onSelect(null); Navigator.pop(context); },
                    child: Container(
                      padding: const EdgeInsets.symmetric(
                          horizontal: 10, vertical: 4),
                      decoration: BoxDecoration(
                        color: _danger.withOpacity(0.08),
                        borderRadius: BorderRadius.circular(8),
                        border: Border.all(color: _danger.withOpacity(0.2)),
                      ),
                      child: const Text('Ver todos',
                          style: TextStyle(fontSize: 11, color: _danger,
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
                    radius: 16,
                    backgroundColor:
                        sel ? _primary : _accent.withOpacity(0.1),
                    child: Text(
                      op.isNotEmpty ? op[0].toUpperCase() : '?',
                      style: TextStyle(
                          fontSize: 12,
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