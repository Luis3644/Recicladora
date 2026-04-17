import 'dart:typed_data';
import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:intl/intl.dart';
import 'package:http/http.dart' as http;

// ignore: avoid_web_libraries_in_flutter

import 'package:universal_html/html.dart' as html;
import 'dart:io' as io;
import 'package:path_provider/path_provider.dart';
import 'package:open_file/open_file.dart';
import 'package:flutter/foundation.dart' show kIsWeb;

class ReportesCamionesAdminScreen extends StatefulWidget {
  const ReportesCamionesAdminScreen({super.key});

  @override
  State<ReportesCamionesAdminScreen> createState() =>
      _ReportesCamionesAdminScreenState();
}

class _ReportesCamionesAdminScreenState
    extends State<ReportesCamionesAdminScreen>
    with SingleTickerProviderStateMixin {
  // ── Colores ───────────────────────────────────────────────────────────────
  static const Color _primary = Color(0xFF0F172A);
  static const Color _accent  = Color(0xFF06B6D4);
  static const Color _success = Color(0xFF10B981);
  static const Color _danger  = Color(0xFFEF4444);
  static const Color _warning = Color(0xFFF59E0B);
  static const Color _bgColor = Color(0xFFF0F9FF);
  static const Color _surface = Color(0xFFFFFFFF);
  static const Color _slate   = Color(0xFF64748B);
  static const Color _border  = Color(0xFFE2E8F0);

  // ── Filtros ───────────────────────────────────────────────────────────────
  String    _filtroPeriodo = 'hoy';
  String?   _filtroCamion;
  DateTime? _filtroFecha;
  List<String> _camiones = [];
  bool _cargandoCamiones = true;

  late AnimationController _fadeCtrl;

  @override
  void initState() {
    super.initState();
    _fadeCtrl = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 380),
    )..forward();
    _cargarCamiones();
  }

  @override
  void dispose() {
    _fadeCtrl.dispose();
    super.dispose();
  }

  void _refresh() { _fadeCtrl..reset()..forward(); setState(() {}); }

  // ── Carga camiones ────────────────────────────────────────────────────────
  Future<void> _cargarCamiones() async {
    try {
      final snap = await FirebaseFirestore.instance
          .collection('reportes_camiones')
          .get();
      final tipos = snap.docs
          .map((d) => d.data()['tipo']?.toString() ?? '')
          .where((t) => t.isNotEmpty)
          .toSet()
          .toList()
        ..sort();
      if (mounted) {
        setState(() { _camiones = tipos; _cargandoCamiones = false; });
      }
    } catch (_) {
      if (mounted) setState(() => _cargandoCamiones = false);
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
        ),
        child: child!,
      ),
    );
    if (picked != null) {
      setState(() { _filtroFecha = picked; _filtroPeriodo = 'fecha'; });
      _refresh();
    }
  }

  // ── Query ─────────────────────────────────────────────────────────────────
  Query<Map<String, dynamic>> _buildQuery() {
    Query<Map<String, dynamic>> q = FirebaseFirestore.instance
        .collection('reportes_camiones')
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
    if (_filtroCamion == null) return docs;
    return docs
        .where((d) => d.data()['tipo']?.toString() == _filtroCamion)
        .toList();
  }

  // ── Eliminar reporte ──────────────────────────────────────────────────────
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
              padding: const EdgeInsets.symmetric(horizontal: 22, vertical: 11),
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
              padding: const EdgeInsets.symmetric(horizontal: 22, vertical: 11),
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
            .collection('reportes_camiones')
            .doc(docId)
            .delete();
        if (mounted) _snack('Reporte eliminado', _success);
      } catch (e) {
        if (mounted) _snack('Error al eliminar: $e', _danger);
      }
    }
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

  // ── Descarga imagen ───────────────────────────────────────────────────────
  Future<void> _descargarImagen(String url, String nombre) async {
    try {
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
        final file = io.File('${dir.path}/$nombre.jpg');
        await file.writeAsBytes(bytes);
        await OpenFile.open(file.path);
      }
      _snack('Imagen descargada correctamente', _success);
    } catch (e) {
      _snack('Error al descargar: $e', _danger);
    }
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
      title: const Text('Reportes de Camiones',
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

  // ── Barra de filtros oscura ───────────────────────────────────────────────
  Widget _buildFiltros() {
    final hayActivo = _filtroCamion != null ||
        _filtroPeriodo != 'hoy' ||
        _filtroFecha != null;

    return Container(
      color: _primary,
      padding: const EdgeInsets.fromLTRB(14, 10, 14, 14),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.center,
        children: [
          // ── Fila 1: chips período + calendario ────────────────────
          SingleChildScrollView(
            scrollDirection: Axis.horizontal,
            child: Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                _chip('hoy',    'Hoy',       Icons.today_rounded),
                _chip('semana', 'Semana',    Icons.date_range_rounded),
                _chip('mes',    'Mes',       Icons.calendar_month_rounded),
                _chip('año',    'Año',       Icons.calendar_today_rounded),
                _chip('todo',   'Todo',      Icons.all_inclusive_rounded),
                const SizedBox(width: 8),
                Container(width: 1, height: 24, color: Colors.white12),
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
                          ? Colors.amber
                          : Colors.white12,
                      borderRadius: BorderRadius.circular(22),
                      border: Border.all(
                        color: (_filtroPeriodo == 'fecha' && _filtroFecha != null)
                            ? Colors.amber
                            : Colors.white24,
                      ),
                    ),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Icon(Icons.event_rounded, size: 14,
                            color: (_filtroPeriodo == 'fecha' && _filtroFecha != null)
                                ? _primary : Colors.white70),
                        const SizedBox(width: 6),
                        Text(
                          (_filtroPeriodo == 'fecha' && _filtroFecha != null)
                              ? DateFormat('dd/MM/yy').format(_filtroFecha!)
                              : 'Fecha',
                          style: TextStyle(
                            fontSize: 13,
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

          const SizedBox(height: 10),

          // ── Fila 2: camiones (centrado) + limpiar ─────────────────
          Row(
            children: [
              Expanded(
                child: _cargandoCamiones
                    ? const SizedBox(
                        height: 38,
                        child: Center(child: CircularProgressIndicator(
                            color: Colors.white38, strokeWidth: 2)))
                    : _camiones.isEmpty
                        ? const Center(
                            child: Text('Sin datos de camiones',
                                style: TextStyle(
                                    fontSize: 12, color: Colors.white38)))
                        : SingleChildScrollView(
                            scrollDirection: Axis.horizontal,
                            child: Row(
                              mainAxisAlignment: MainAxisAlignment.center,
                              children: [
                                _chipCamion(null, 'Todos'),
                                ..._camiones.map((c) => _chipCamion(c, c)),
                              ],
                            ),
                          ),
              ),
              if (hayActivo) ...[
                const SizedBox(width: 8),
                GestureDetector(
                  onTap: () {
                    setState(() {
                      _filtroPeriodo = 'hoy';
                      _filtroCamion  = null;
                      _filtroFecha   = null;
                    });
                    _refresh();
                  },
                  child: Container(
                    padding: const EdgeInsets.symmetric(
                        horizontal: 12, vertical: 9),
                    decoration: BoxDecoration(
                      color: _danger.withOpacity(0.15),
                      borderRadius: BorderRadius.circular(22),
                      border: Border.all(color: _danger.withOpacity(0.35)),
                    ),
                    child: const Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Icon(Icons.close_rounded,
                            size: 13, color: Colors.redAccent),
                        SizedBox(width: 5),
                        Text('Limpiar',
                            style: TextStyle(
                                fontSize: 12,
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
          color: sel ? _accent : Colors.white10,
          borderRadius: BorderRadius.circular(22),
          border: Border.all(color: sel ? _accent : Colors.white24),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(icon, size: 13,
                color: sel ? Colors.white : Colors.white60),
            const SizedBox(width: 5),
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

  Widget _chipCamion(String? valor, String label) {
    final sel = _filtroCamion == valor;
    return GestureDetector(
      onTap: () {
        setState(() => _filtroCamion = valor);
        _refresh();
      },
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 180),
        margin: const EdgeInsets.only(right: 7),
        padding: const EdgeInsets.symmetric(horizontal: 13, vertical: 9),
        decoration: BoxDecoration(
          color: sel ? Colors.white : Colors.white10,
          borderRadius: BorderRadius.circular(22),
          border: Border.all(color: sel ? Colors.white : Colors.white24),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(
              sel ? Icons.directions_bus_rounded : Icons.directions_bus_outlined,
              size: 13,
              color: sel ? _primary : Colors.white60,
            ),
            const SizedBox(width: 5),
            Text(label,
                style: TextStyle(
                    fontSize: 13,
                    fontWeight: FontWeight.w700,
                    color: sel ? _primary : Colors.white60)),
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
              'Sin reportes', 'No hay reportes para los filtros seleccionados');
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
            padding: const EdgeInsets.all(20),
            decoration: BoxDecoration(
                color: color.withOpacity(0.08), shape: BoxShape.circle),
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

  // ── Tarjeta COMPACTA ──────────────────────────────────────────────────────
  Widget _buildCard(Map<String, dynamic> data, String docId) {
    final fecha  = (data['fecha'] as Timestamp?)?.toDate();
    final fotos  = List<String>.from(data['fotos'] ?? []);
    final estado = data['estado'] ?? '';

    Color    estadoColor;
    IconData estadoIcon;
    String   estadoLabel;
    switch (estado) {
      case 'resuelto':
        estadoColor = _success;
        estadoIcon  = Icons.check_circle_rounded;
        estadoLabel = 'RESUELTO';
        break;
      case 'en proceso':
        estadoColor = _warning;
        estadoIcon  = Icons.timelapse_rounded;
        estadoLabel = 'EN PROCESO';
        break;
      default:
        estadoColor = _danger;
        estadoIcon  = Icons.error_rounded;
        estadoLabel = 'PENDIENTE';
    }

    return Container(
      margin: const EdgeInsets.only(bottom: 10),
      decoration: BoxDecoration(
        color: _surface,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: _border),
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
              // Barra lateral de color según estado
              Container(width: 4, color: estadoColor),

              Expanded(
                child: Padding(
                  padding: const EdgeInsets.all(12),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      // ── Fila superior: estado + fecha + eliminar ──
                      Row(
                        children: [
                          Container(
                            padding: const EdgeInsets.symmetric(
                                horizontal: 8, vertical: 3),
                            decoration: BoxDecoration(
                              color: estadoColor.withOpacity(0.1),
                              borderRadius: BorderRadius.circular(6),
                            ),
                            child: Row(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                Icon(estadoIcon,
                                    size: 10, color: estadoColor),
                                const SizedBox(width: 4),
                                Text(estadoLabel,
                                    style: TextStyle(
                                        fontSize: 9,
                                        fontWeight: FontWeight.w800,
                                        color: estadoColor,
                                        letterSpacing: 0.5)),
                              ],
                            ),
                          ),
                          const Spacer(),
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

                      const SizedBox(height: 10),

                      // ── Fila info: camión + modelo + placas + operador ─
                      Wrap(
                        spacing: 6,
                        runSpacing: 6,
                        children: [
                          _miniTag(Icons.directions_bus_rounded,
                              data['tipo'] ?? '—', _accent),
                          _miniTag(Icons.build_rounded,
                              data['modelo'] ?? '—', _slate),
                          _miniTag(Icons.pin_rounded,
                              data['placas'] ?? '—', _success),
                          _miniTag(Icons.person_rounded,
                              data['operador'] ?? '—', _warning),
                        ],
                      ),

                      const SizedBox(height: 10),

                      // ── Descripción (2 líneas) ─────────────────────
                      Text(
                        data['descripcion'] ?? 'Sin descripción',
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                        style: const TextStyle(
                          fontSize: 13,
                          color: _primary,
                          fontWeight: FontWeight.w500,
                          height: 1.4,
                        ),
                      ),

                      // ── Fotos mini ────────────────────────────────
                      if (fotos.isNotEmpty) ...[
                        const SizedBox(height: 10),
                        SingleChildScrollView(
                          scrollDirection: Axis.horizontal,
                          child: Row(
                            children: fotos.asMap().entries.map((e) {
                              final idx = e.key + 1;
                              final url = e.value;
                              return _fotoMini(url,
                                  '${data['tipo'] ?? 'camion'}_reporte_$idx');
                            }).toList(),
                          ),
                        ),
                      ],
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
          Text(label,
              style: TextStyle(
                  fontSize: 11,
                  fontWeight: FontWeight.w700,
                  color: color == _slate ? _primary : color)),
        ],
      ),
    );
  }

  // ── Foto mini ─────────────────────────────────────────────────────────────
  Widget _fotoMini(String url, String nombre) {
    return GestureDetector(
      onTap: () => _verFotoDialog(url, nombre),
      child: Container(
        margin: const EdgeInsets.only(right: 8),
        child: Stack(
          children: [
            ClipRRect(
              borderRadius: BorderRadius.circular(8),
              child: Image.network(url,
                  width: 72,
                  height: 72,
                  fit: BoxFit.cover,
                  loadingBuilder: (_, child, prog) {
                    if (prog == null) return child;
                    return Container(
                      width: 72,
                      height: 72,
                      decoration: BoxDecoration(
                          color: Colors.grey[100],
                          borderRadius: BorderRadius.circular(8)),
                      child: const Center(
                          child: CircularProgressIndicator(
                              color: _accent, strokeWidth: 2)),
                    );
                  },
                  errorBuilder: (_, __, ___) => Container(
                    width: 72,
                    height: 72,
                    decoration: BoxDecoration(
                        color: Colors.grey[100],
                        borderRadius: BorderRadius.circular(8)),
                    child: Icon(Icons.broken_image_rounded,
                        color: Colors.grey[400], size: 24),
                  )),
            ),
            Positioned(
              bottom: 4,
              right: 4,
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

  // ── Ver foto en diálogo ───────────────────────────────────────────────────
  void _verFotoDialog(String url, String nombre) {
    showDialog(
      context: context,
      barrierColor: Colors.black87,
      builder: (_) => Dialog(
        backgroundColor: Colors.transparent,
        insetPadding: const EdgeInsets.all(16),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            ClipRRect(
              borderRadius: BorderRadius.circular(16),
              child: Image.network(url, fit: BoxFit.contain),
            ),
            const SizedBox(height: 12),
            Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                ElevatedButton.icon(
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Colors.white24,
                    foregroundColor: Colors.white,
                    shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(10)),
                  ),
                  onPressed: () => Navigator.pop(context),
                  icon: const Icon(Icons.close_rounded, size: 16),
                  label: const Text('Cerrar'),
                ),
                const SizedBox(width: 12),
                ElevatedButton.icon(
                  style: ElevatedButton.styleFrom(
                    backgroundColor: _accent,
                    foregroundColor: Colors.white,
                    shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(10)),
                  ),
                  onPressed: () {
                    Navigator.pop(context);
                    _descargarImagen(url, nombre);
                  },
                  icon: const Icon(Icons.download_rounded, size: 16),
                  label: const Text('Descargar'),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}