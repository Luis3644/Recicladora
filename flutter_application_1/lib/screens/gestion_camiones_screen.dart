import 'dart:io';
import 'dart:typed_data';
import 'package:flutter/material.dart';
import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_storage/firebase_storage.dart';
import 'package:image_picker/image_picker.dart';

// ─── Helper responsive ───────────────────────────────────────────────────────
class _R {
  final bool isDesktop;
  const _R(this.isDesktop);

  factory _R.of(BuildContext ctx) =>
      _R(MediaQuery.of(ctx).size.width >= 768);

  // Escala valores: desktop usa 75 % del valor móvil si no se pasa desktop
  double s(double mobile, [double? desktop]) =>
      isDesktop ? (desktop ?? mobile * 0.75) : mobile;

  double get maxContentWidth => isDesktop ? 1100.0 : double.infinity;
}

class GestionCamionesScreen extends StatefulWidget {
  const GestionCamionesScreen({super.key});

  @override
  State<GestionCamionesScreen> createState() => _GestionCamionesScreenState();
}

class _GestionCamionesScreenState extends State<GestionCamionesScreen>
    with SingleTickerProviderStateMixin {
  late AnimationController _controller;
  bool _contentVisible = false;

  static const Color _primary = Color(0xFF1E293B); // Slate 800
  static const Color _accent  = Color(0xFF6366F1); // Indigo 500
  static const Color _success = Color(0xFF10B981); // Emerald 500
  static const Color _warning = Color(0xFFF59E0B); // Amber 500
  static const Color _danger  = Color(0xFFEF4444); // Red 500
  static const Color _bgColor = Color(0xFFF8FAFC); // Slate 50
  static const Color _surface = Color(0xFFFFFFFF);
  static const Color _slate   = Color(0xFF64748B);
  static const Color _indigoLight = Color(0xFFE0E7FF);

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

  Color _getEstadoColor(String estado) {
    switch (estado) {
      case 'Disponible':        return _success;
      case 'En Mantenimiento':  return _warning;
      case 'Fuera de Servicio': return _danger;
      default:                  return _accent;
    }
  }

  IconData _getEstadoIcon(String estado) {
    switch (estado) {
      case 'Disponible':        return Icons.check_circle_rounded;
      case 'En Mantenimiento':  return Icons.build_circle_rounded;
      case 'Fuera de Servicio': return Icons.cancel_rounded;
      default:                  return Icons.help_rounded;
    }
  }

  Future<void> _cambiarEstadoConDialogo(
      String camionId, String estadoActual, String tipoCamion) async {
    String? nuevoEstado = estadoActual;

    final resultado = await showDialog<String>(
      context: context,
      builder: (ctx) {
        final r = _R.of(ctx);
        return StatefulBuilder(
          builder: (ctx2, setLocal) => Dialog(
            shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(r.s(24))),
            elevation: 0,
            backgroundColor: Colors.transparent,
            child: Center(
              child: ConstrainedBox(
                constraints: BoxConstraints(
                    maxWidth: r.isDesktop ? 480 : double.infinity),
                child: Container(
                  decoration: BoxDecoration(
                    color: _surface,
                    borderRadius: BorderRadius.circular(r.s(24)),
                    boxShadow: [
                      BoxShadow(
                        color: _primary.withOpacity(0.18),
                        blurRadius: 40,
                        offset: const Offset(0, 16),
                      ),
                    ],
                  ),
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      // Header
                      Container(
                        width: double.infinity,
                        padding: EdgeInsets.fromLTRB(
                            r.s(24), r.s(24), r.s(24), r.s(20)),
                        decoration: BoxDecoration(
                          gradient: const LinearGradient(
                            colors: [_primary, Color(0xFF334155)],
                            begin: Alignment.topLeft,
                            end: Alignment.bottomRight,
                          ),
                          borderRadius: BorderRadius.vertical(
                              top: Radius.circular(r.s(24))),
                        ),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Row(children: [
                              Container(
                                padding: EdgeInsets.all(r.s(10)),
                                decoration: BoxDecoration(
                                  color: Colors.white.withOpacity(0.15),
                                  borderRadius:
                                      BorderRadius.circular(r.s(12)),
                                ),
                                child: Icon(Icons.local_shipping_rounded,
                                    color: Colors.white, size: r.s(22)),
                              ),
                              SizedBox(width: r.s(12)),
                              Expanded(
                                child: Column(
                                  crossAxisAlignment:
                                      CrossAxisAlignment.start,
                                  children: [
                                    Text('Modificar Estado',
                                        style: TextStyle(
                                            color: Colors.white,
                                            fontSize: r.s(18),
                                            fontWeight: FontWeight.w800)),
                                    Text(tipoCamion,
                                        style: TextStyle(
                                            color: Colors.white
                                                .withOpacity(0.7),
                                            fontSize: r.s(13))),
                                  ],
                                ),
                              ),
                            ]),
                            SizedBox(height: r.s(16)),
                            Container(
                              padding: EdgeInsets.symmetric(
                                  horizontal: r.s(12), vertical: r.s(8)),
                              decoration: BoxDecoration(
                                color: Colors.white.withOpacity(0.12),
                                borderRadius:
                                    BorderRadius.circular(r.s(10)),
                                border: Border.all(
                                    color: Colors.white.withOpacity(0.2)),
                              ),
                              child: Row(
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  Icon(_getEstadoIcon(estadoActual),
                                      color: _getEstadoColor(estadoActual),
                                      size: r.s(16)),
                                  SizedBox(width: r.s(8)),
                                  Text('Estado actual: $estadoActual',
                                      style: TextStyle(
                                          color: Colors.white,
                                          fontSize: r.s(13),
                                          fontWeight: FontWeight.w600)),
                                ],
                              ),
                            ),
                          ],
                        ),
                      ),
                      // Opciones
                      Padding(
                        padding: EdgeInsets.all(r.s(20)),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text('Selecciona el nuevo estado:',
                                style: TextStyle(
                                    fontSize: r.s(13),
                                    fontWeight: FontWeight.w600,
                                    color: _slate)),
                            SizedBox(height: r.s(14)),
                            ...[
                              ('Disponible', _success,
                                  Icons.check_circle_rounded,
                                  'Listo para ser asignado'),
                              ('En Mantenimiento', _warning,
                                  Icons.build_circle_rounded,
                                  'En taller o revisión'),
                              ('Fuera de Servicio', _danger,
                                  Icons.cancel_rounded,
                                  'No disponible temporalmente'),
                            ].map((item) {
                              final (label, color, icon, desc) = item;
                              final sel = nuevoEstado == label;
                              return GestureDetector(
                                onTap: () =>
                                    setLocal(() => nuevoEstado = label),
                                child: AnimatedContainer(
                                  duration:
                                      const Duration(milliseconds: 180),
                                  margin:
                                      EdgeInsets.only(bottom: r.s(10)),
                                  padding: EdgeInsets.all(r.s(14)),
                                  decoration: BoxDecoration(
                                    color: sel
                                        ? color.withOpacity(0.08)
                                        : const Color(0xFFF8FAFC),
                                    borderRadius:
                                        BorderRadius.circular(r.s(14)),
                                    border: Border.all(
                                        color: sel
                                            ? color
                                            : const Color(0xFFE2E8F0),
                                        width: sel ? 2 : 1),
                                  ),
                                  child: Row(children: [
                                    Container(
                                      padding: EdgeInsets.all(r.s(8)),
                                      decoration: BoxDecoration(
                                          color: color.withOpacity(0.12),
                                          shape: BoxShape.circle),
                                      child: Icon(icon,
                                          color: color, size: r.s(20)),
                                    ),
                                    SizedBox(width: r.s(12)),
                                    Expanded(
                                      child: Column(
                                        crossAxisAlignment:
                                            CrossAxisAlignment.start,
                                        children: [
                                          Text(label,
                                              style: TextStyle(
                                                  fontSize: r.s(15),
                                                  fontWeight:
                                                      FontWeight.w700,
                                                  color: sel
                                                      ? color
                                                      : _primary)),
                                          Text(desc,
                                              style: TextStyle(
                                                  fontSize: r.s(12),
                                                  color: _slate)),
                                        ],
                                      ),
                                    ),
                                    if (sel)
                                      Icon(Icons.check_circle_rounded,
                                          color: color, size: r.s(22)),
                                  ]),
                                ),
                              );
                            }),
                          ],
                        ),
                      ),
                      // Botones
                      Padding(
                        padding: EdgeInsets.fromLTRB(
                            r.s(20), 0, r.s(20), r.s(20)),
                        child: Row(children: [
                          Expanded(
                            child: OutlinedButton(
                              style: OutlinedButton.styleFrom(
                                foregroundColor: _slate,
                                side: const BorderSide(
                                    color: Color(0xFFE2E8F0)),
                                shape: RoundedRectangleBorder(
                                    borderRadius:
                                        BorderRadius.circular(r.s(12))),
                                padding: EdgeInsets.symmetric(
                                    vertical: r.s(14)),
                              ),
                              onPressed: () => Navigator.pop(ctx2),
                              child: Text('Cancelar',
                                  style: TextStyle(
                                      fontWeight: FontWeight.w600,
                                      fontSize: r.s(14))),
                            ),
                          ),
                          SizedBox(width: r.s(10)),
                          Expanded(
                            flex: 2,
                            child: ElevatedButton.icon(
                              style: ElevatedButton.styleFrom(
                                backgroundColor: _accent,
                                foregroundColor: Colors.white,
                                elevation: 4,
                                shadowColor: _accent.withOpacity(0.3),
                                shape: RoundedRectangleBorder(
                                    borderRadius:
                                        BorderRadius.circular(r.s(12))),
                                padding: EdgeInsets.symmetric(
                                    vertical: r.s(14)),
                              ),
                              onPressed: () =>
                                  Navigator.pop(ctx2, nuevoEstado),
                              icon: Icon(Icons.check_rounded,
                                  size: r.s(18)),
                              label: Text('Confirmar Cambio',
                                  style: TextStyle(
                                      fontWeight: FontWeight.w800,
                                      fontSize: r.s(13))),
                            ),
                          ),
                        ]),
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ),
        );
      },
    );

    if (resultado != null && resultado != estadoActual) {
      await FirebaseFirestore.instance
          .collection('camiones')
          .doc(camionId)
          .update({'estado': resultado});
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Row(children: [
              Icon(_getEstadoIcon(resultado),
                  color: Colors.white, size: 18),
              const SizedBox(width: 8),
              Text('Estado actualizado: $resultado',
                  style:
                      const TextStyle(fontWeight: FontWeight.w600)),
            ]),
            backgroundColor: _getEstadoColor(resultado),
            behavior: SnackBarBehavior.floating,
            shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(12)),
          ),
        );
      }
    }
  }

  Future<void> _eliminarCamion(String camionId, String tipo) async {
    final confirmar = await showDialog<bool>(
          context: context,
          builder: (ctx) {
            final r = _R.of(ctx);
            return Dialog(
              shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(r.s(20))),
              child: ConstrainedBox(
                constraints: BoxConstraints(
                    maxWidth: r.isDesktop ? 400 : double.infinity),
                child: Padding(
                  padding: EdgeInsets.all(r.s(24)),
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Container(
                        padding: EdgeInsets.all(r.s(16)),
                        decoration: BoxDecoration(
                            color: _danger.withOpacity(0.1),
                            shape: BoxShape.circle),
                        child: Icon(Icons.delete_outline_rounded,
                            color: _danger, size: r.s(32)),
                      ),
                      SizedBox(height: r.s(16)),
                      Text('Eliminar "$tipo"',
                          style: TextStyle(
                              fontSize: r.s(17),
                              fontWeight: FontWeight.w800),
                          textAlign: TextAlign.center),
                      SizedBox(height: r.s(8)),
                      Text(
                          'Esta acción no se puede deshacer.\n¿Estás seguro?',
                          style:
                              TextStyle(fontSize: r.s(13), color: _slate),
                          textAlign: TextAlign.center),
                      SizedBox(height: r.s(20)),
                      Row(children: [
                        Expanded(
                          child: OutlinedButton(
                            style: OutlinedButton.styleFrom(
                              foregroundColor: _slate,
                              side: const BorderSide(
                                  color: Color(0xFFE2E8F0)),
                              shape: RoundedRectangleBorder(
                                  borderRadius:
                                      BorderRadius.circular(r.s(10))),
                              padding: EdgeInsets.symmetric(
                                  vertical: r.s(12)),
                            ),
                            onPressed: () =>
                                Navigator.of(context).pop(false),
                            child: Text('Cancelar',
                                style: TextStyle(fontSize: r.s(14))),
                          ),
                        ),
                        SizedBox(width: r.s(10)),
                        Expanded(
                          child: ElevatedButton(
                            style: ElevatedButton.styleFrom(
                              backgroundColor: _danger,
                              foregroundColor: Colors.white,
                              elevation: 0,
                              shape: RoundedRectangleBorder(
                                  borderRadius:
                                      BorderRadius.circular(r.s(10))),
                              padding: EdgeInsets.symmetric(
                                  vertical: r.s(12)),
                            ),
                            onPressed: () =>
                                Navigator.of(context).pop(true),
                            child: Text('Eliminar',
                                style: TextStyle(
                                    fontWeight: FontWeight.w700,
                                    fontSize: r.s(14))),
                          ),
                        ),
                      ]),
                    ],
                  ),
                ),
              ),
            );
          },
        ) ??
        false;

    if (confirmar) {
      await FirebaseFirestore.instance
          .collection('camiones')
          .doc(camionId)
          .delete();
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: const Text('Camión eliminado'),
            backgroundColor: _success,
            behavior: SnackBarBehavior.floating,
            shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(12)),
          ),
        );
      }
    }
  }

  void _mostrarFormularioCamion(
      {String? camionId, Map<String, dynamic>? data}) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (_) => CamionFormScreen(camionId: camionId, data: data),
    );
  }

  @override
  Widget build(BuildContext context) {
    final r = _R.of(context);

    return Scaffold(
      backgroundColor: _bgColor,
      extendBodyBehindAppBar: false,
      appBar: AppBar(
        title: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Gestión de Flota',
              style: TextStyle(
                  fontWeight: FontWeight.w900, fontSize: r.s(20), letterSpacing: -0.5),
            ),
            Text(
              'Administración de unidades y estados',
              style: TextStyle(fontSize: r.s(12), color: Colors.white70, fontWeight: FontWeight.w500),
            ),
          ],
        ),
        backgroundColor: Colors.transparent,
        elevation: 0,
        foregroundColor: Colors.white,
        toolbarHeight: r.s(74),
        flexibleSpace: Container(
          decoration: BoxDecoration(
            gradient: const LinearGradient(
              colors: [_primary, Color(0xFF334155)],
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
            ),
          ),
        ),
        actions: [
          Padding(
            padding: EdgeInsets.only(right: r.s(16)),
            child: Center(
              child: Material(
                color: _accent,
                borderRadius: BorderRadius.circular(r.s(12)),
                elevation: 4,
                shadowColor: _accent.withOpacity(0.4),
                child: InkWell(
                  onTap: () => _mostrarFormularioCamion(),
                  borderRadius: BorderRadius.circular(r.s(12)),
                  child: Container(
                    padding: EdgeInsets.symmetric(
                        horizontal: r.s(16), vertical: r.s(10)),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Icon(Icons.add_rounded, size: r.s(20), color: Colors.white),
                        SizedBox(width: r.s(6)),
                        Text('Nueva Unidad',
                            style: TextStyle(
                                color: Colors.white,
                                fontWeight: FontWeight.w800,
                                fontSize: r.s(13))),
                      ],
                    ),
                  ),
                ),
              ),
            ),
          ),
        ],
      ),
      body: StreamBuilder<QuerySnapshot>(
        stream: FirebaseFirestore.instance
            .collection('camiones')
            .snapshots(),
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) {
            return const Center(
                child: CircularProgressIndicator(color: _accent));
          }

          final camiones = snapshot.data?.docs ?? [];

          if (camiones.isEmpty) {
            return Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Container(
                    padding: EdgeInsets.all(r.s(28)),
                    decoration: BoxDecoration(
                        color: _accent.withOpacity(0.08),
                        shape: BoxShape.circle),
                    child: Icon(Icons.local_shipping_outlined,
                        size: r.s(60),
                        color: _accent.withOpacity(0.5)),
                  ),
                  SizedBox(height: r.s(20)),
                  Text('No hay camiones registrados',
                      style: TextStyle(
                          fontSize: r.s(18),
                          fontWeight: FontWeight.w700,
                          color: _primary)),
                  SizedBox(height: r.s(8)),
                  Text('Toca "Nueva Unidad" para registrar el primero',
                      style: TextStyle(
                          fontSize: r.s(14), color: Colors.grey[500])),
                ],
              ),
            );
          }

          // Cálculo de estadísticas rápidas
          final total = camiones.length;
          final disponibles = camiones.where((doc) => doc['estado'] == 'Disponible').length;
          final mantenimiento = camiones.where((doc) => doc['estado'] == 'En Mantenimiento').length;

          return Column(
            children: [
              // Barra de estadísticas premium
              _buildStatsBar(total, disponibles, mantenimiento, r),
              Expanded(
                child: AnimatedOpacity(
                  opacity: _contentVisible ? 1 : 0,
                  duration: const Duration(milliseconds: 600),
                  child: r.isDesktop
                      ? _buildDesktopGrid(camiones, r)
                      : _buildMobileList(camiones, r),
                ),
              ),
            ],
          );
        },
      ),
    );
  }

  Widget _buildStatsBar(int total, int disponibles, int mantenimiento, _R r) {
    return Container(
      padding: EdgeInsets.symmetric(horizontal: r.s(16), vertical: r.s(16)),
      decoration: BoxDecoration(
        color: _surface,
        border: Border(bottom: BorderSide(color: Colors.grey[200]!)),
      ),
      child: Row(
        children: [
          _statItem('Flota Total', total.toString(), _primary, Icons.inventory_2_rounded, r),
          _vDivider(),
          _statItem('Disponibles', disponibles.toString(), _success, Icons.check_circle_rounded, r),
          _vDivider(),
          _statItem('Taller', mantenimiento.toString(), _warning, Icons.build_circle_rounded, r),
        ],
      ),
    );
  }

  Widget _statItem(String label, String value, Color color, IconData icon, _R r) {
    return Expanded(
      child: Column(
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(icon, color: color, size: r.s(14)),
              SizedBox(width: r.s(6)),
              Text(
                value,
                style: TextStyle(
                    fontSize: r.s(18), fontWeight: FontWeight.w900, color: _primary),
              ),
            ],
          ),
          Text(
            label.toUpperCase(),
            style: TextStyle(
                fontSize: r.s(10), fontWeight: FontWeight.w700, color: _slate, letterSpacing: 0.5),
          ),
        ],
      ),
    );
  }

  Widget _vDivider() => Container(height: 24, width: 1, color: Colors.grey[200]);

  // ── Lista móvil — tarjetas con altura natural (mainAxisSize.min) ────────────
  Widget _buildMobileList(List<QueryDocumentSnapshot> docs, _R r) {
    return ListView.builder(
      padding: const EdgeInsets.fromLTRB(16, 20, 16, 32),
      itemCount: docs.length,
      itemBuilder: (ctx, i) => _buildCard(docs[i], i, r),
    );
  }

  // ── Grid desktop — 2 columnas, altura fija por childAspectRatio ─────────────
  Widget _buildDesktopGrid(List<QueryDocumentSnapshot> docs, _R r) {
    return Center(
      child: ConstrainedBox(
        constraints: BoxConstraints(maxWidth: r.maxContentWidth),
        child: GridView.builder(
          padding: EdgeInsets.fromLTRB(r.s(24), r.s(24), r.s(24), r.s(40)),
          gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
            crossAxisCount: 2,
            crossAxisSpacing: r.s(18),
            mainAxisSpacing: r.s(18),
            childAspectRatio: 1.6,
          ),
          itemCount: docs.length,
          itemBuilder: (ctx, i) => _buildCard(docs[i], i, r),
        ),
      ),
    );
  }

  // ── Tarjeta compartida ───────────────────────────────────────────────────────
  // En móvil: altura natural (Column con mainAxisSize.min + foto con altura fija)
  // En desktop: rellena la celda del grid (Column sin mainAxisSize.min)
  Widget _buildCard(QueryDocumentSnapshot doc, int index, _R r) {
    final data      = doc.data() as Map<String, dynamic>;
    final camionId  = doc.id;
    final tipo      = data['tipo']   ?? 'Sin tipo';
    final modelo    = data['modelo'] ?? '—';
    final placas    = data['placas'] ?? '—';
    final foto      = data['foto']   ?? '';
    final estado    = data['estado'] ?? 'Disponible';
    final estadoColor = _getEstadoColor(estado);

    // Altura de la foto: fija siempre para que no rompa el layout
    final fotoH = r.isDesktop ? r.s(130.0) : 160.0;

    return TweenAnimationBuilder<double>(
      tween: Tween(begin: 0.0, end: 1.0),
      duration: Duration(milliseconds: 300 + index * 80),
      curve: Curves.easeOutCubic,
      builder: (ctx, value, child) => Transform.translate(
        offset: Offset(0, 24 * (1 - value)),
        child: Opacity(opacity: value, child: child),
      ),
      child: Container(
        margin: r.isDesktop ? EdgeInsets.zero : const EdgeInsets.only(bottom: 16),
        decoration: BoxDecoration(
          color: _surface,
          borderRadius: BorderRadius.circular(r.s(24)),
          border: Border.all(
              color: Colors.grey[200]!, width: 1),
          boxShadow: [
            BoxShadow(
                color: _primary.withOpacity(0.04),
                blurRadius: r.s(20),
                offset: Offset(0, r.s(10))),
          ],
        ),
        // En desktop llenamos la celda; en móvil altura natural
        child: r.isDesktop
            ? _cardContent(foto, tipo, modelo, placas, estado,
                estadoColor, camionId, data, fotoH, r,
                expand: true)
            : _cardContent(foto, tipo, modelo, placas, estado,
                estadoColor, camionId, data, fotoH, r,
                expand: false),
      ),
    );
  }

  Widget _cardContent(
    String foto,
    String tipo,
    String modelo,
    String placas,
    String estado,
    Color estadoColor,
    String camionId,
    Map<String, dynamic> data,
    double fotoH,
    _R r, {
    required bool expand,
  }) {
    final fotoWidget = ClipRRect(
      borderRadius:
          BorderRadius.vertical(top: Radius.circular(r.s(24))),
      child: SizedBox(
        height: fotoH,
        width: double.infinity,
        child: Stack(
          fit: StackFit.expand,
          children: [
            foto.isNotEmpty
                ? Image.network(foto,
                    fit: BoxFit.cover,
                    errorBuilder: (_, __, ___) =>
                        _fotoPlaceholder(r))
                : _fotoPlaceholder(r),
            // Gradiente oscuro sutil
            Positioned.fill(
              child: Container(
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    begin: Alignment.bottomCenter,
                    end: Alignment.topCenter,
                    colors: [
                      Colors.black.withOpacity(0.7),
                      Colors.transparent,
                    ],
                  ),
                ),
              ),
            ),
            // Placas arriba a la derecha (Estilo Badge)
            Positioned(
              top: r.s(12),
              right: r.s(12),
              child: Container(
                padding: EdgeInsets.symmetric(
                    horizontal: r.s(10), vertical: r.s(5)),
                decoration: BoxDecoration(
                    color: Colors.white.withOpacity(0.25),
                    borderRadius: BorderRadius.circular(r.s(30)),
                    border: Border.all(color: Colors.white30)),
                child: BackdropFilter(
                  filter: ColorFilter.mode(Colors.black.withOpacity(0.1), BlendMode.darken),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(Icons.pin_rounded,
                          size: r.s(10), color: Colors.white),
                      SizedBox(width: r.s(4)),
                      Text(placas,
                          style: TextStyle(
                              fontSize: r.s(11),
                              fontWeight: FontWeight.w900,
                              color: Colors.white,
                              letterSpacing: 0.5)),
                    ],
                  ),
                ),
              ),
            ),
            // Info Texto
            Positioned(
              bottom: r.s(14), left: r.s(16), right: r.s(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(tipo.toUpperCase(),
                      style: TextStyle(
                          color: Colors.white,
                          fontSize: r.s(18),
                          fontWeight: FontWeight.w900,
                          letterSpacing: -0.5)),
                  Text(modelo,
                      style: TextStyle(
                          color: Colors.white70,
                          fontSize: r.s(12),
                          fontWeight: FontWeight.w500)),
                ],
              ),
            ),
          ],
        ),
      ),
    );

    final estadoWidget = Container(
      width: double.infinity,
      padding: EdgeInsets.symmetric(
          horizontal: r.s(16), vertical: r.s(10)),
      decoration: BoxDecoration(
        color: _bgColor,
      ),
      child: Row(children: [
        Container(
          padding: EdgeInsets.all(r.s(6)),
          decoration: BoxDecoration(
            color: estadoColor.withOpacity(0.1),
            borderRadius: BorderRadius.circular(r.s(8)),
          ),
          child: Icon(_getEstadoIcon(estado), color: estadoColor, size: r.s(16)),
        ),
        SizedBox(width: r.s(10)),
        Text(estado,
            style: TextStyle(
                fontSize: r.s(13),
                fontWeight: FontWeight.w800,
                color: estadoColor)),
        const Spacer(),
        Icon(Icons.verified_user_rounded, color: _slate.withOpacity(0.3), size: r.s(14)),
      ]),
    );

    final botonesWidget = Padding(
      padding: EdgeInsets.all(r.s(14)),
      child: Row(children: [
        Expanded(
          flex: 4,
          child: Material(
            color: estadoColor,
            borderRadius: BorderRadius.circular(r.s(12)),
            child: InkWell(
              onTap: () => _cambiarEstadoConDialogo(camionId, estado, tipo),
              borderRadius: BorderRadius.circular(r.s(12)),
              child: Container(
                height: r.s(40),
                alignment: Alignment.center,
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Icon(Icons.swap_horiz_rounded, size: r.s(16), color: Colors.white),
                    SizedBox(width: r.s(6)),
                    Text('ESTADO',
                        style: TextStyle(
                            color: Colors.white,
                            fontWeight: FontWeight.w900,
                            fontSize: r.s(11))),
                  ],
                ),
              ),
            ),
          ),
        ),
        SizedBox(width: r.s(10)),
        Material(
          color: _indigoLight,
          borderRadius: BorderRadius.circular(r.s(12)),
          child: InkWell(
            onTap: () => _mostrarFormularioCamion(camionId: camionId, data: data),
            borderRadius: BorderRadius.circular(r.s(12)),
            child: Container(
              width: r.s(40),
              height: r.s(40),
              child: Icon(Icons.edit_rounded, size: r.s(18), color: _accent),
            ),
          ),
        ),
        SizedBox(width: r.s(10)),
        Material(
          color: _danger.withOpacity(0.1),
          borderRadius: BorderRadius.circular(r.s(12)),
          child: InkWell(
            onTap: () => _eliminarCamion(camionId, tipo),
            borderRadius: BorderRadius.circular(r.s(12)),
            child: Container(
              width: r.s(40),
              height: r.s(40),
              child: Icon(Icons.delete_rounded, color: _danger, size: r.s(18)),
            ),
          ),
        ),
      ]),
    );

    if (expand) {
      // Desktop: rellena la celda del grid
      return Column(
        children: [
          fotoWidget,
          estadoWidget,
          botonesWidget,
        ],
      );
    } else {
      // Móvil: altura natural, no usa Expanded
      return Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          fotoWidget,
          estadoWidget,
          botonesWidget,
        ],
      );
    }
  }

  Widget _fotoPlaceholder(_R r) => Container(
        color: _indigoLight.withOpacity(0.5),
        child: Center(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(Icons.local_shipping_rounded,
                  color: _accent.withOpacity(0.4), size: r.s(48)),
              SizedBox(height: r.s(8)),
              Text('SIN IMAGEN', 
                style: TextStyle(
                  color: _accent.withOpacity(0.4), 
                  fontSize: r.s(10), 
                  fontWeight: FontWeight.w900,
                  letterSpacing: 1.0
                )
              ),
            ],
          ),
        ),
      );
}

// ─────────────────────────────────────────────────────────────────────────────
// Formulario Agregar / Editar Camión — responsive
// ─────────────────────────────────────────────────────────────────────────────
class CamionFormScreen extends StatefulWidget {
  final String? camionId;
  final Map<String, dynamic>? data;
  const CamionFormScreen({super.key, this.camionId, this.data});

  @override
  State<CamionFormScreen> createState() => _CamionFormScreenState();
}

class _CamionFormScreenState extends State<CamionFormScreen> {
  final _formKey    = GlobalKey<FormState>();
  final _tipoCtrl   = TextEditingController();
  final _modeloCtrl = TextEditingController();
  final _placasCtrl = TextEditingController();
  final _fotoCtrl   = TextEditingController();

  String _estado       = 'Disponible';
  bool   _guardando    = false;
  bool   _subiendoFoto = false;

  File?      _imagenArchivo;
  Uint8List? _imagenBytes;
  String?    _imagenPreviewUrl;

  static const Color _primary = Color(0xFF1E293B);
  static const Color _accent  = Color(0xFF6366F1);
  static const Color _success = Color(0xFF10B981);
  static const Color _warning = Color(0xFFF59E0B);
  static const Color _danger  = Color(0xFFEF4444);
  static const Color _slate   = Color(0xFF64748B);
  static const Color _bgColor = Color(0xFFF8FAFC);

  @override
  void initState() {
    super.initState();
    if (widget.data != null) {
      _tipoCtrl.text    = widget.data!['tipo']   ?? '';
      _modeloCtrl.text  = widget.data!['modelo'] ?? '';
      _placasCtrl.text  = widget.data!['placas'] ?? '';
      _fotoCtrl.text    = widget.data!['foto']   ?? '';
      _estado           = widget.data!['estado'] ?? 'Disponible';
      _imagenPreviewUrl = widget.data!['foto']?.toString();
    }
  }

  @override
  void dispose() {
    _tipoCtrl.dispose();
    _modeloCtrl.dispose();
    _placasCtrl.dispose();
    _fotoCtrl.dispose();
    super.dispose();
  }

  Color _getEstadoColor(String e) {
    switch (e) {
      case 'Disponible':        return _success;
      case 'En Mantenimiento':  return _warning;
      case 'Fuera de Servicio': return _danger;
      default:                  return _accent;
    }
  }

  IconData _getEstadoIcon(String e) {
    switch (e) {
      case 'Disponible':        return Icons.check_circle_rounded;
      case 'En Mantenimiento':  return Icons.build_circle_rounded;
      case 'Fuera de Servicio': return Icons.cancel_rounded;
      default:                  return Icons.help_rounded;
    }
  }

  Future<void> _seleccionarImagen() async {
    final picker = ImagePicker();
    final picked = await picker.pickImage(
        source: ImageSource.gallery, imageQuality: 80);
    if (picked == null) return;

    setState(() => _subiendoFoto = true);
    try {
      final nombre =
          'camiones/${DateTime.now().millisecondsSinceEpoch}.jpg';
      final ref = FirebaseStorage.instance.ref().child(nombre);

      if (kIsWeb) {
        final bytes = await picked.readAsBytes();
        await ref.putData(bytes);
        setState(() => _imagenBytes = bytes);
      } else {
        final file = File(picked.path);
        await ref.putFile(file);
        setState(() => _imagenArchivo = file);
      }

      final url = await ref.getDownloadURL();
      setState(() {
        _imagenPreviewUrl = url;
        _fotoCtrl.text    = url;
      });
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(
            content: Text('Error al subir imagen: $e'),
            backgroundColor: Colors.red));
      }
    } finally {
      if (mounted) setState(() => _subiendoFoto = false);
    }
  }

  Future<void> _guardar() async {
    if (!_formKey.currentState!.validate()) return;
    setState(() => _guardando = true);

    final fotoUrl = _imagenPreviewUrl ?? _fotoCtrl.text.trim();
    final data = {
      'tipo':                _tipoCtrl.text.trim(),
      'modelo':              _modeloCtrl.text.trim(),
      'placas':              _placasCtrl.text.trim(),
      'foto':                fotoUrl,
      'estado':              _estado,
      'activo':              true,
      'ocupado':             false,
      'operador':            '',
      'capacidad_toneladas': 0,
    };

    try {
      if (widget.camionId != null) {
        await FirebaseFirestore.instance
            .collection('camiones')
            .doc(widget.camionId)
            .update({
          'tipo':   data['tipo'],
          'modelo': data['modelo'],
          'placas': data['placas'],
          'foto':   data['foto'],
          'estado': data['estado'],
          'activo': true,
        });
      } else {
        await FirebaseFirestore.instance.collection('camiones').add(data);
      }
      if (mounted) {
        Navigator.of(context).pop();
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(
          content: Text(widget.camionId != null
              ? 'Camión actualizado correctamente'
              : 'Camión agregado correctamente'),
          backgroundColor: _success,
          behavior: SnackBarBehavior.floating,
          shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(12)),
        ));
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(
            content: Text('Error: $e'), backgroundColor: Colors.red));
      }
    } finally {
      if (mounted) setState(() => _guardando = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final r = _R.of(context);
    final esEdicion = widget.camionId != null;
    final screenH = MediaQuery.of(context).size.height;

    return Center(
      child: ConstrainedBox(
        constraints: BoxConstraints(
          // En desktop limita el ancho; en móvil ocupa todo
          maxWidth: r.isDesktop ? 640 : double.infinity,
          maxHeight: screenH * 0.94,
        ),
        child: Container(
          height: screenH * 0.94,
          decoration: BoxDecoration(
            color: const Color(0xFFF8FAFC),
            borderRadius:
                BorderRadius.vertical(top: Radius.circular(r.s(28))),
          ),
          child: Column(
            children: [
              // Handle
              Container(
                margin: EdgeInsets.only(top: r.s(12)),
                width: r.s(44),
                height: r.s(4),
                decoration: BoxDecoration(
                    color: Colors.grey[300],
                    borderRadius: BorderRadius.circular(r.s(4))),
              ),
              // Header
              Container(
                margin:
                    EdgeInsets.fromLTRB(r.s(16), r.s(16), r.s(16), 0),
                padding: EdgeInsets.all(r.s(20)),
                decoration: BoxDecoration(
                  gradient: const LinearGradient(
                    colors: [_primary, Color(0xFF334155)],
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                  ),
                  borderRadius: BorderRadius.circular(r.s(20)),
                  boxShadow: [
                    BoxShadow(
                        color: _primary.withOpacity(0.25),
                        blurRadius: r.s(16),
                        offset: Offset(0, r.s(8)))
                  ],
                ),
                child: Row(children: [
                  Container(
                    padding: EdgeInsets.all(r.s(12)),
                    decoration: BoxDecoration(
                        color: Colors.white.withOpacity(0.15),
                        borderRadius: BorderRadius.circular(r.s(14))),
                    child: Icon(
                      esEdicion
                          ? Icons.edit_rounded
                          : Icons.add_circle_outline_rounded,
                      color: Colors.white,
                      size: r.s(24),
                    ),
                  ),
                  SizedBox(width: r.s(14)),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          esEdicion
                              ? 'Editar Camión'
                              : 'Agregar Camión',
                          style: TextStyle(
                              color: Colors.white,
                              fontSize: r.s(20),
                              fontWeight: FontWeight.w800),
                        ),
                        Text(
                          esEdicion
                              ? 'Modifica la información del camión'
                              : 'Registra un nuevo camión a la flota',
                          style: TextStyle(
                              color: Colors.white.withOpacity(0.7),
                              fontSize: r.s(13)),
                        ),
                      ],
                    ),
                  ),
                ]),
              ),
              // Formulario scrollable
              Expanded(
                child: SingleChildScrollView(
                  padding: EdgeInsets.fromLTRB(
                      r.s(16), r.s(20), r.s(16), r.s(24)),
                  child: Form(
                    key: _formKey,
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        // Foto
                        _label('📷  Foto del camión', r),
                        SizedBox(height: r.s(10)),
                        GestureDetector(
                          onTap: _seleccionarImagen,
                          child: Container(
                            height: r.s(180),
                            width: double.infinity,
                            decoration: BoxDecoration(
                              color: Colors.white,
                              borderRadius:
                                  BorderRadius.circular(r.s(22)),
                              border: Border.all(
                                color: _subiendoFoto
                                    ? _accent
                                    : Colors.grey[200]!,
                                width: _subiendoFoto ? 2 : 1.5,
                              ),
                              boxShadow: [
                                BoxShadow(
                                    color: Colors.black.withOpacity(0.04),
                                    blurRadius: r.s(8),
                                    offset: Offset(0, r.s(3)))
                              ],
                            ),
                            child: ClipRRect(
                              borderRadius:
                                  BorderRadius.circular(r.s(17)),
                              child: _subiendoFoto
                                  ? Center(
                                      child: Column(
                                        mainAxisAlignment:
                                            MainAxisAlignment.center,
                                        children: [
                                          const CircularProgressIndicator(
                                              color: _accent),
                                          SizedBox(height: r.s(12)),
                                          Text('Subiendo imagen...',
                                              style: TextStyle(
                                                  color: _slate,
                                                  fontSize: r.s(13))),
                                        ],
                                      ),
                                    )
                                  : _imagenPreviewUrl != null &&
                                          _imagenPreviewUrl!.isNotEmpty
                                      ? Stack(
                                          fit: StackFit.expand,
                                          children: [
                                            _imagenArchivo != null &&
                                                    !kIsWeb
                                                ? Image.file(
                                                    _imagenArchivo!,
                                                    fit: BoxFit.cover)
                                                : _imagenBytes != null &&
                                                        kIsWeb
                                                    ? Image.memory(
                                                        _imagenBytes!,
                                                        fit: BoxFit.cover)
                                                    : Image.network(
                                                        _imagenPreviewUrl!,
                                                        fit: BoxFit.cover),
                                            Positioned(
                                              bottom: r.s(10),
                                              right: r.s(10),
                                              child: Container(
                                                padding: EdgeInsets.symmetric(
                                                    horizontal: r.s(12),
                                                    vertical: r.s(6)),
                                                decoration: BoxDecoration(
                                                    color: Colors.black54,
                                                    borderRadius:
                                                        BorderRadius.circular(
                                                            r.s(10))),
                                                child: Row(
                                                  mainAxisSize:
                                                      MainAxisSize.min,
                                                  children: [
                                                    Icon(
                                                        Icons.edit_rounded,
                                                        color: Colors.white,
                                                        size: r.s(14)),
                                                    SizedBox(
                                                        width: r.s(5)),
                                                    Text('Cambiar foto',
                                                        style: TextStyle(
                                                            color: Colors
                                                                .white,
                                                            fontSize:
                                                                r.s(12),
                                                            fontWeight:
                                                                FontWeight
                                                                    .w600)),
                                                  ],
                                                ),
                                              ),
                                            ),
                                          ],
                                        )
                                      : Column(
                                          mainAxisAlignment:
                                              MainAxisAlignment.center,
                                          children: [
                                            Container(
                                              padding:
                                                  EdgeInsets.all(r.s(16)),
                                              decoration: BoxDecoration(
                                                  color: _accent
                                                      .withOpacity(0.1),
                                                  shape: BoxShape.circle),
                                              child: Icon(
                                                  Icons
                                                      .add_photo_alternate_rounded,
                                                  size: r.s(36),
                                                  color: _accent),
                                            ),
                                            SizedBox(height: r.s(10)),
                                            Text('Toca para subir foto',
                                                style: TextStyle(
                                                    fontSize: r.s(15),
                                                    fontWeight:
                                                        FontWeight.w700,
                                                    color: _primary)),
                                            SizedBox(height: r.s(4)),
                                            Text('Desde tu galería',
                                                style: TextStyle(
                                                    fontSize: r.s(12),
                                                    color: Colors
                                                        .grey[400])),
                                          ],
                                        ),
                            ),
                          ),
                        ),
                        SizedBox(height: r.s(24)),

                        // Datos
                        _label('🚛  Datos del camión', r),
                        SizedBox(height: r.s(12)),
                        _tarjeta(
                          r,
                          child: Column(children: [
                            _campo(_tipoCtrl, 'Tipo de camión',
                                'Ej: Pipa, Caja seca, Plataforma...',
                                Icons.local_shipping_rounded, r),
                            SizedBox(height: r.s(14)),
                            _campo(_modeloCtrl, 'Modelo / Año',
                                'Ej: Kenworth T680 2022',
                                Icons.build_rounded, r),
                            SizedBox(height: r.s(14)),
                            _campo(_placasCtrl, 'Placas',
                                'Ej: ABC-123-D', Icons.pin_rounded, r,
                                caps: TextCapitalization.characters),
                          ]),
                        ),
                        SizedBox(height: r.s(24)),

                        // Estado
                        _label('🔖  Estado del camión', r),
                        SizedBox(height: r.s(12)),
                        _tarjeta(
                          r,
                          child: Column(children: [
                            ...[
                              ('Disponible', _success,
                                  Icons.check_circle_rounded),
                              ('En Mantenimiento', _warning,
                                  Icons.build_circle_rounded),
                              ('Fuera de Servicio', _danger,
                                  Icons.cancel_rounded),
                            ].map((item) {
                              final (label, color, icon) = item;
                              final sel = _estado == label;
                              return GestureDetector(
                                onTap: () =>
                                    setState(() => _estado = label),
                                child: AnimatedContainer(
                                  duration:
                                      const Duration(milliseconds: 180),
                                  margin:
                                      EdgeInsets.only(bottom: r.s(10)),
                                  padding: EdgeInsets.symmetric(
                                      horizontal: r.s(14),
                                      vertical: r.s(12)),
                                  decoration: BoxDecoration(
                                    color: sel
                                        ? color.withOpacity(0.08)
                                        : const Color(0xFFF8FAFC),
                                    borderRadius:
                                        BorderRadius.circular(r.s(12)),
                                    border: Border.all(
                                        color: sel
                                            ? color
                                            : const Color(0xFFE2E8F0),
                                        width: sel ? 2 : 1),
                                  ),
                                  child: Row(children: [
                                    Icon(icon,
                                        color: sel ? color : _slate,
                                        size: r.s(22)),
                                    SizedBox(width: r.s(12)),
                                    Text(label,
                                        style: TextStyle(
                                            fontSize: r.s(15),
                                            fontWeight: FontWeight.w700,
                                            color:
                                                sel ? color : _primary)),
                                    const Spacer(),
                                    if (sel)
                                      Icon(Icons.check_circle_rounded,
                                          color: color, size: r.s(20)),
                                  ]),
                                ),
                              );
                            }),
                          ]),
                        ),
                        SizedBox(height: r.s(32)),

                        // Guardar
                        SizedBox(
                          width: double.infinity,
                          height: r.s(56),
                          child: ElevatedButton.icon(
                            style: ElevatedButton.styleFrom(
                              backgroundColor:
                                  esEdicion ? _accent : _success,
                              foregroundColor: Colors.white,
                              elevation: 3,
                              shadowColor:
                                  (esEdicion ? _accent : _success)
                                      .withOpacity(0.4),
                              shape: RoundedRectangleBorder(
                                  borderRadius:
                                      BorderRadius.circular(r.s(12))),
                            ),
                            onPressed: _guardando ? null : _guardar,
                            icon: _guardando
                                ? SizedBox(
                                    width: r.s(22),
                                    height: r.s(22),
                                    child: const CircularProgressIndicator(
                                        color: Colors.white,
                                        strokeWidth: 2.5))
                                : Icon(
                                    esEdicion
                                        ? Icons.update_rounded
                                        : Icons.save_rounded,
                                    size: r.s(22)),
                            label: Text(
                              _guardando
                                  ? 'Guardando...'
                                  : esEdicion
                                      ? 'ACTUALIZAR CAMIÓN'
                                      : 'GUARDAR CAMIÓN',
                              style: TextStyle(
                                  fontSize: r.s(15),
                                  fontWeight: FontWeight.w800),
                            ),
                          ),
                        ),
                        SizedBox(height: r.s(10)),
                        SizedBox(
                          width: double.infinity,
                          height: r.s(48),
                          child: OutlinedButton(
                            style: OutlinedButton.styleFrom(
                              foregroundColor: _slate,
                              side: const BorderSide(
                                  color: Color(0xFFE2E8F0)),
                              shape: RoundedRectangleBorder(
                                  borderRadius:
                                      BorderRadius.circular(r.s(16))),
                            ),
                            onPressed: () => Navigator.of(context).pop(),
                            child: Text('Cancelar',
                                style: TextStyle(
                                    fontSize: r.s(14),
                                    fontWeight: FontWeight.w600)),
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _label(String t, _R r) => Text(t,
      style: TextStyle(
          fontSize: r.s(15),
          fontWeight: FontWeight.w800,
          color: const Color(0xFF0F172A)));

  Widget _tarjeta(_R r, {required Widget child}) => Container(
        padding: EdgeInsets.all(r.s(18)),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(r.s(18)),
          border: Border.all(color: const Color(0xFFE2E8F0)),
          boxShadow: [
            BoxShadow(
                color: Colors.black.withOpacity(0.04),
                blurRadius: r.s(8),
                offset: Offset(0, r.s(3)))
          ],
        ),
        child: child,
      );

  Widget _campo(
    TextEditingController ctrl,
    String label,
    String hint,
    IconData icon,
    _R r, {
    TextCapitalization caps = TextCapitalization.sentences,
  }) {
    return TextFormField(
      controller: ctrl,
      textCapitalization: caps,
      style: TextStyle(
          fontSize: r.s(15),
          fontWeight: FontWeight.w600,
          color: const Color(0xFF0F172A)),
      decoration: InputDecoration(
        labelText: label,
        hintText: hint,
        hintStyle:
            TextStyle(color: Colors.grey[400], fontSize: r.s(13)),
        prefixIcon: Icon(icon, size: r.s(20), color: _accent),
        filled: true,
        fillColor: const Color(0xFFF8FAFC),
        contentPadding: EdgeInsets.symmetric(
            horizontal: r.s(14), vertical: r.s(14)),
        border: OutlineInputBorder(
            borderRadius: BorderRadius.circular(r.s(12)),
            borderSide: const BorderSide(color: Color(0xFFE2E8F0))),
        enabledBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(r.s(12)),
            borderSide: const BorderSide(color: Color(0xFFE2E8F0))),
        focusedBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(r.s(12)),
            borderSide: const BorderSide(color: _accent, width: 2)),
        errorBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(r.s(12)),
            borderSide: const BorderSide(color: Color(0xFFDC2626))),
      ),
      validator: (v) => (v?.trim().isEmpty ?? true)
          ? 'Este campo es requerido'
          : null,
    );
  }
}