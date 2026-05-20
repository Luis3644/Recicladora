import 'dart:io';
import 'dart:typed_data';
import 'package:flutter/material.dart';
import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_storage/firebase_storage.dart';
import 'package:image_picker/image_picker.dart';

// ─── Helper responsive ────────────────────────────────────────────────────────
class _R {
  final bool isDesktop;
  const _R(this.isDesktop);
  factory _R.of(BuildContext ctx) =>
      _R(MediaQuery.of(ctx).size.width >= 768);
  double s(double m, [double? d]) => isDesktop ? (d ?? m * 0.75) : m;
  double get maxW => isDesktop ? 1100.0 : double.infinity;
}

// ─── Colores globales (evita redeclarar en cada widget) ───────────────────────
const _cPrimary  = Color(0xFF1E293B);
const _cAccent   = Color(0xFF6366F1);
const _cSuccess  = Color(0xFF10B981);
const _cWarning  = Color(0xFFF59E0B);
const _cDanger   = Color(0xFFEF4444);
const _cBg       = Color(0xFFF8FAFC);
const _cSurface  = Color(0xFFFFFFFF);
const _cSlate    = Color(0xFF64748B);
const _cIndigo   = Color(0xFFE0E7FF);

Color _estadoColor(String e) {
  switch (e) {
    case 'Disponible':        return _cSuccess;
    case 'En Mantenimiento':  return _cWarning;
    case 'Fuera de Servicio': return _cDanger;
    default:                  return _cAccent;
  }
}

IconData _estadoIcon(String e) {
  switch (e) {
    case 'Disponible':        return Icons.check_circle_rounded;
    case 'En Mantenimiento':  return Icons.build_circle_rounded;
    case 'Fuera de Servicio': return Icons.cancel_rounded;
    default:                  return Icons.help_rounded;
  }
}

// ─────────────────────────────────────────────────────────────────────────────
class GestionCamionesScreen extends StatelessWidget {
  const GestionCamionesScreen({super.key});

  // Dialogo cambiar estado
  Future<void> _cambiarEstado(BuildContext ctx,
      String camionId, String estadoActual, String tipoCamion) async {
    final resultado = await showDialog<String>(
      context: ctx,
      builder: (_) => _EstadoDialog(
        camionId    : camionId,
        estadoActual: estadoActual,
        tipoCamion  : tipoCamion,
      ),
    );
    if (resultado != null && resultado != estadoActual) {
      await FirebaseFirestore.instance
          .collection('camiones')
          .doc(camionId)
          .update({'estado': resultado});
      if (ctx.mounted) {
        ScaffoldMessenger.of(ctx).showSnackBar(SnackBar(
          content: Row(children: [
            Icon(_estadoIcon(resultado), color: Colors.white, size: 18),
            const SizedBox(width: 8),
            Text('Estado: $resultado',
                style: const TextStyle(fontWeight: FontWeight.w600)),
          ]),
          backgroundColor: _estadoColor(resultado),
          behavior: SnackBarBehavior.floating,
          shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(12)),
        ));
      }
    }
  }

  // Dialogo eliminar
  Future<void> _eliminar(BuildContext ctx,
      String camionId, String tipo) async {
    final r = _R.of(ctx);
    final ok = await showDialog<bool>(
          context: ctx,
          builder: (_) => Dialog(
            shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(r.s(20))),
            child: ConstrainedBox(
              constraints: BoxConstraints(
                  maxWidth: r.isDesktop ? 400 : double.infinity),
              child: Padding(
                padding: EdgeInsets.all(r.s(24)),
                child: Column(mainAxisSize: MainAxisSize.min, children: [
                  Container(
                    padding: EdgeInsets.all(r.s(16)),
                    decoration: BoxDecoration(
                        color: _cDanger.withOpacity(0.1),
                        shape: BoxShape.circle),
                    child: Icon(Icons.delete_outline_rounded,
                        color: _cDanger, size: r.s(32)),
                  ),
                  SizedBox(height: r.s(16)),
                  Text('Eliminar "$tipo"',
                      style: TextStyle(
                          fontSize: r.s(17), fontWeight: FontWeight.w800),
                      textAlign: TextAlign.center),
                  SizedBox(height: r.s(8)),
                  Text('Esta acción no se puede deshacer.',
                      style: TextStyle(
                          fontSize: r.s(13), color: _cSlate),
                      textAlign: TextAlign.center),
                  SizedBox(height: r.s(20)),
                  Row(children: [
                    Expanded(
                      child: OutlinedButton(
                        style: OutlinedButton.styleFrom(
                          foregroundColor: _cSlate,
                          side: const BorderSide(
                              color: Color(0xFFE2E8F0)),
                          shape: RoundedRectangleBorder(
                              borderRadius:
                                  BorderRadius.circular(r.s(10))),
                          padding: EdgeInsets.symmetric(
                              vertical: r.s(12)),
                        ),
                        onPressed: () => Navigator.of(ctx).pop(false),
                        child: Text('Cancelar',
                            style: TextStyle(fontSize: r.s(14))),
                      ),
                    ),
                    SizedBox(width: r.s(10)),
                    Expanded(
                      child: ElevatedButton(
                        style: ElevatedButton.styleFrom(
                          backgroundColor: _cDanger,
                          foregroundColor: Colors.white,
                          elevation: 0,
                          shape: RoundedRectangleBorder(
                              borderRadius:
                                  BorderRadius.circular(r.s(10))),
                          padding: EdgeInsets.symmetric(
                              vertical: r.s(12)),
                        ),
                        onPressed: () => Navigator.of(ctx).pop(true),
                        child: Text('Eliminar',
                            style: TextStyle(
                                fontWeight: FontWeight.w700,
                                fontSize: r.s(14))),
                      ),
                    ),
                  ]),
                ]),
              ),
            ),
          ),
        ) ??
        false;

    if (ok) {
      await FirebaseFirestore.instance
          .collection('camiones')
          .doc(camionId)
          .delete();
      if (ctx.mounted) {
        ScaffoldMessenger.of(ctx).showSnackBar(SnackBar(
          content: const Text('Camión eliminado'),
          backgroundColor: _cSuccess,
          behavior: SnackBarBehavior.floating,
          shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(12)),
        ));
      }
    }
  }

  void _abrirFormulario(BuildContext ctx,
      {String? camionId, Map<String, dynamic>? data}) {
    showModalBottomSheet(
      context: ctx,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (_) => CamionFormScreen(camionId: camionId, data: data),
    );
  }

  @override
  Widget build(BuildContext context) {
    final r = _R.of(context);
    return Scaffold(
      backgroundColor: _cBg,
      appBar: _AppBarFlota(
        r: r,
        onAgregar: () => _abrirFormulario(context),
      ),
      // ── StreamBuilder SOLO alrededor de los datos, no de toda la pantalla
      body: StreamBuilder<QuerySnapshot>(
        stream: FirebaseFirestore.instance
            .collection('camiones')
            .snapshots(),
        builder: (ctx, snap) {
          if (snap.connectionState == ConnectionState.waiting) {
            return const Center(
                child: CircularProgressIndicator(color: _cAccent));
          }

          final docs = snap.data?.docs ?? [];

          if (docs.isEmpty) {
            return _EmptyState(r: r);
          }

          final total        = docs.length;
          final disponibles  = docs.where((d) => d['estado'] == 'Disponible').length;
          final mantenimiento= docs.where((d) => d['estado'] == 'En Mantenimiento').length;

          return Column(children: [
            // Stats — widget separado, no se reconstruye completo
            _StatsBar(
              total: total,
              disponibles: disponibles,
              mantenimiento: mantenimiento,
              r: r,
            ),
            Expanded(
              child: r.isDesktop
                  ? _DesktopGrid(
                      docs    : docs,
                      r       : r,
                      onEstado: (id, est, tipo) =>
                          _cambiarEstado(context, id, est, tipo),
                      onEditar: (id, data) =>
                          _abrirFormulario(context,
                              camionId: id, data: data),
                      onEliminar: (id, tipo) =>
                          _eliminar(context, id, tipo),
                    )
                  : _MobileList(
                      docs    : docs,
                      r       : r,
                      onEstado: (id, est, tipo) =>
                          _cambiarEstado(context, id, est, tipo),
                      onEditar: (id, data) =>
                          _abrirFormulario(context,
                              camionId: id, data: data),
                      onEliminar: (id, tipo) =>
                          _eliminar(context, id, tipo),
                    ),
            ),
          ]);
        },
      ),
    );
  }
}

// ─── AppBar ───────────────────────────────────────────────────────────────────
class _AppBarFlota extends StatelessWidget implements PreferredSizeWidget {
  final _R r;
  final VoidCallback onAgregar;
  const _AppBarFlota({required this.r, required this.onAgregar});

  @override
  Size get preferredSize => Size.fromHeight(r.s(74));

  @override
  Widget build(BuildContext context) {
    return AppBar(
      titleSpacing: 16,
      title: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text('Gestión de Flota',
              style: TextStyle(
                  fontWeight: FontWeight.w900,
                  fontSize: r.s(20),
                  letterSpacing: -0.5)),
          Text('Administración de unidades',
              style: TextStyle(
                  fontSize: r.s(11),
                  color: Colors.white70,
                  fontWeight: FontWeight.w500)),
        ],
      ),
      backgroundColor: Colors.transparent,
      elevation: 0,
      foregroundColor: Colors.white,
      toolbarHeight: r.s(74),
      flexibleSpace: Container(
        decoration: const BoxDecoration(
          gradient: LinearGradient(
            colors: [_cPrimary, Color(0xFF334155)],
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
              color: _cAccent,
              borderRadius: BorderRadius.circular(r.s(12)),
              elevation: 4,
              shadowColor: _cAccent.withOpacity(0.4),
              child: InkWell(
                onTap: onAgregar,
                borderRadius: BorderRadius.circular(r.s(12)),
                child: Padding(
                  padding: EdgeInsets.symmetric(
                      horizontal: r.s(16), vertical: r.s(10)),
                  child: Row(mainAxisSize: MainAxisSize.min, children: [
                    Icon(Icons.add_rounded,
                        size: r.s(20), color: Colors.white),
                    SizedBox(width: r.s(6)),
                    Text('Nueva Unidad',
                        style: TextStyle(
                            color: Colors.white,
                            fontWeight: FontWeight.w800,
                            fontSize: r.s(13))),
                  ]),
                ),
              ),
            ),
          ),
        ),
      ],
    );
  }
}

// ─── Stats bar ────────────────────────────────────────────────────────────────
// RepaintBoundary evita que se repinte cuando cambia otra parte del árbol
class _StatsBar extends StatelessWidget {
  final int total, disponibles, mantenimiento;
  final _R r;
  const _StatsBar({
    required this.total,
    required this.disponibles,
    required this.mantenimiento,
    required this.r,
  });

  @override
  Widget build(BuildContext context) {
    return RepaintBoundary(
      child: Container(
        padding: EdgeInsets.symmetric(
            horizontal: r.s(16), vertical: r.s(14)),
        decoration: BoxDecoration(
          color: _cSurface,
          border: Border(
              bottom: BorderSide(color: Colors.grey[200]!)),
        ),
        child: Row(children: [
          _Item('Flota Total', '$total',
              _cPrimary, Icons.inventory_2_rounded, r),
          _Divider(),
          _Item('Disponibles', '$disponibles',
              _cSuccess, Icons.check_circle_rounded, r),
          _Divider(),
          _Item('Taller', '$mantenimiento',
              _cWarning, Icons.build_circle_rounded, r),
        ]),
      ),
    );
  }
}

class _Item extends StatelessWidget {
  final String label, value;
  final Color color;
  final IconData icon;
  final _R r;
  const _Item(this.label, this.value, this.color, this.icon, this.r);

  @override
  Widget build(BuildContext context) {
    return Expanded(
      child: Column(children: [
        Row(mainAxisAlignment: MainAxisAlignment.center, children: [
          Icon(icon, color: color, size: r.s(14)),
          SizedBox(width: r.s(5)),
          Text(value,
              style: TextStyle(
                  fontSize: r.s(18),
                  fontWeight: FontWeight.w900,
                  color: _cPrimary)),
        ]),
        Text(label.toUpperCase(),
            style: TextStyle(
                fontSize: r.s(10),
                fontWeight: FontWeight.w700,
                color: _cSlate,
                letterSpacing: 0.5)),
      ]),
    );
  }
}

class _Divider extends StatelessWidget {
  const _Divider();
  @override
  Widget build(BuildContext context) =>
      Container(height: 24, width: 1, color: Colors.grey[200]);
}

// ─── Empty state ──────────────────────────────────────────────────────────────
class _EmptyState extends StatelessWidget {
  final _R r;
  const _EmptyState({required this.r});

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Column(mainAxisAlignment: MainAxisAlignment.center, children: [
        Container(
          padding: EdgeInsets.all(r.s(28)),
          decoration: BoxDecoration(
              color: _cAccent.withOpacity(0.08), shape: BoxShape.circle),
          child: Icon(Icons.local_shipping_outlined,
              size: r.s(60), color: _cAccent.withOpacity(0.5)),
        ),
        SizedBox(height: r.s(20)),
        Text('No hay camiones registrados',
            style: TextStyle(
                fontSize: r.s(18),
                fontWeight: FontWeight.w700,
                color: _cPrimary)),
        SizedBox(height: r.s(8)),
        Text('Toca "Nueva Unidad" para registrar el primero',
            style: TextStyle(fontSize: r.s(14), color: Colors.grey[500])),
      ]),
    );
  }
}

// ─── Lista móvil ──────────────────────────────────────────────────────────────
class _MobileList extends StatelessWidget {
  final List<QueryDocumentSnapshot> docs;
  final _R r;
  final void Function(String, String, String) onEstado;
  final void Function(String, Map<String, dynamic>) onEditar;
  final void Function(String, String) onEliminar;

  const _MobileList({
    required this.docs,
    required this.r,
    required this.onEstado,
    required this.onEditar,
    required this.onEliminar,
  });

  @override
  Widget build(BuildContext context) {
    return ListView.builder(
      padding: const EdgeInsets.fromLTRB(16, 20, 16, 32),
      itemCount: docs.length,
      // itemExtent fijo evita que Flutter recalcule alturas en cada scroll
      itemBuilder: (_, i) => _CamionCard(
        key      : ValueKey(docs[i].id), // key por ID evita reconstrucciones
        doc      : docs[i],
        r        : r,
        onEstado : onEstado,
        onEditar : onEditar,
        onEliminar: onEliminar,
        isDesktop: false,
      ),
    );
  }
}

// ─── Grid desktop ─────────────────────────────────────────────────────────────
class _DesktopGrid extends StatelessWidget {
  final List<QueryDocumentSnapshot> docs;
  final _R r;
  final void Function(String, String, String) onEstado;
  final void Function(String, Map<String, dynamic>) onEditar;
  final void Function(String, String) onEliminar;

  const _DesktopGrid({
    required this.docs,
    required this.r,
    required this.onEstado,
    required this.onEditar,
    required this.onEliminar,
  });

  @override
  Widget build(BuildContext context) {
    return Center(
      child: ConstrainedBox(
        constraints: BoxConstraints(maxWidth: r.maxW),
        child: GridView.builder(
          padding:
              EdgeInsets.fromLTRB(r.s(24), r.s(24), r.s(24), r.s(40)),
          gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
            crossAxisCount  : 2,
            crossAxisSpacing: r.s(18),
            mainAxisSpacing : r.s(18),
            childAspectRatio: 1.6,
          ),
          itemCount: docs.length,
          itemBuilder: (_, i) => _CamionCard(
            key      : ValueKey(docs[i].id),
            doc      : docs[i],
            r        : r,
            onEstado : onEstado,
            onEditar : onEditar,
            onEliminar: onEliminar,
            isDesktop: true,
          ),
        ),
      ),
    );
  }
}

// ─── Tarjeta de camión ────────────────────────────────────────────────────────
// Separado como StatelessWidget con KEY por ID:
// Flutter reutiliza el widget si el ID no cambia → cero reconstrucción innecesaria
class _CamionCard extends StatelessWidget {
  final QueryDocumentSnapshot doc;
  final _R r;
  final void Function(String, String, String) onEstado;
  final void Function(String, Map<String, dynamic>) onEditar;
  final void Function(String, String) onEliminar;
  final bool isDesktop;

  const _CamionCard({
    super.key,
    required this.doc,
    required this.r,
    required this.onEstado,
    required this.onEditar,
    required this.onEliminar,
    required this.isDesktop,
  });

  @override
  Widget build(BuildContext context) {
    final data       = doc.data() as Map<String, dynamic>;
    final camionId   = doc.id;
    final tipo       = data['tipo']   as String? ?? 'Sin tipo';
    final modelo     = data['modelo'] as String? ?? '—';
    final placas     = data['placas'] as String? ?? '—';
    final foto       = data['foto']   as String? ?? '';
    final estado     = data['estado'] as String? ?? 'Disponible';
    final eColor     = _estadoColor(estado);
    final fotoH      = isDesktop ? r.s(130.0) : 160.0;

    // RepaintBoundary: si solo cambia el estado, solo se repinta esa sección
    return RepaintBoundary(
      child: Container(
        margin: isDesktop ? EdgeInsets.zero : const EdgeInsets.only(bottom: 16),
        decoration: BoxDecoration(
          color: _cSurface,
          borderRadius: BorderRadius.circular(r.s(24)),
          border: Border.all(color: Colors.grey[200]!, width: 1),
          boxShadow: [
            BoxShadow(
                color: _cPrimary.withOpacity(0.04),
                blurRadius: r.s(20),
                offset: Offset(0, r.s(10))),
          ],
        ),
        child: isDesktop
            ? Column(children: [
                _Foto(foto: foto, tipo: tipo, modelo: modelo,
                    placas: placas, fotoH: fotoH, r: r),
                _EstadoBadge(estado: estado, eColor: eColor, r: r),
                _Botones(
                    camionId: camionId, estado: estado, tipo: tipo,
                    data: data, eColor: eColor, r: r,
                    onEstado: onEstado, onEditar: onEditar,
                    onEliminar: onEliminar),
              ])
            : Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  _Foto(foto: foto, tipo: tipo, modelo: modelo,
                      placas: placas, fotoH: fotoH, r: r),
                  _EstadoBadge(estado: estado, eColor: eColor, r: r),
                  _Botones(
                      camionId: camionId, estado: estado, tipo: tipo,
                      data: data, eColor: eColor, r: r,
                      onEstado: onEstado, onEditar: onEditar,
                      onEliminar: onEliminar),
                ],
              ),
      ),
    );
  }
}

// ─── Foto del camión ──────────────────────────────────────────────────────────
class _Foto extends StatelessWidget {
  final String foto, tipo, modelo, placas;
  final double fotoH;
  final _R r;
  const _Foto({
    required this.foto, required this.tipo, required this.modelo,
    required this.placas, required this.fotoH, required this.r,
  });

  @override
  Widget build(BuildContext context) {
    return ClipRRect(
      borderRadius: BorderRadius.vertical(top: Radius.circular(r.s(24))),
      child: SizedBox(
        height: fotoH, width: double.infinity,
        child: Stack(fit: StackFit.expand, children: [
          // Imagen — cacheada automáticamente por Flutter
          foto.isNotEmpty
              ? Image.network(foto,
                  fit: BoxFit.cover,
                  // gaplessPlayback evita parpadeo al recargar
                  gaplessPlayback: true,
                  errorBuilder: (_, __, ___) => const _FotoPlaceholder())
              : const _FotoPlaceholder(),
          // Gradiente
          DecoratedBox(
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
          // Placas badge
          Positioned(
            top: 12, right: 12,
            child: Container(
              padding: const EdgeInsets.symmetric(
                  horizontal: 10, vertical: 5),
              decoration: BoxDecoration(
                  color: Colors.white.withOpacity(0.25),
                  borderRadius: BorderRadius.circular(30),
                  border: Border.all(color: Colors.white30)),
              child: Row(mainAxisSize: MainAxisSize.min, children: [
                const Icon(Icons.pin_rounded,
                    size: 10, color: Colors.white),
                const SizedBox(width: 4),
                Text(placas,
                    style: const TextStyle(
                        fontSize: 11,
                        fontWeight: FontWeight.w900,
                        color: Colors.white,
                        letterSpacing: 0.5)),
              ]),
            ),
          ),
          // Tipo + modelo
          Positioned(
            bottom: 14, left: 16, right: 16,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(tipo.toUpperCase(),
                    style: const TextStyle(
                        color: Colors.white,
                        fontSize: 18,
                        fontWeight: FontWeight.w900,
                        letterSpacing: -0.5)),
                Text(modelo,
                    style: const TextStyle(
                        color: Colors.white70,
                        fontSize: 12,
                        fontWeight: FontWeight.w500)),
              ],
            ),
          ),
        ]),
      ),
    );
  }
}

class _FotoPlaceholder extends StatelessWidget {
  const _FotoPlaceholder();
  @override
  Widget build(BuildContext context) {
    return Container(
      color: _cIndigo.withOpacity(0.5),
      child: const Center(
        child: Column(mainAxisSize: MainAxisSize.min, children: [
          Icon(Icons.local_shipping_rounded,
              color: Color(0x666366F1), size: 48),
          SizedBox(height: 8),
          Text('SIN IMAGEN',
              style: TextStyle(
                  color: Color(0x666366F1),
                  fontSize: 10,
                  fontWeight: FontWeight.w900,
                  letterSpacing: 1.0)),
        ]),
      ),
    );
  }
}

// ─── Estado badge ─────────────────────────────────────────────────────────────
class _EstadoBadge extends StatelessWidget {
  final String estado;
  final Color eColor;
  final _R r;
  const _EstadoBadge({
    required this.estado, required this.eColor, required this.r});

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: EdgeInsets.symmetric(
          horizontal: r.s(16), vertical: r.s(10)),
      color: _cBg,
      child: Row(children: [
        Container(
          padding: EdgeInsets.all(r.s(6)),
          decoration: BoxDecoration(
              color: eColor.withOpacity(0.1),
              borderRadius: BorderRadius.circular(r.s(8))),
          child: Icon(_estadoIcon(estado),
              color: eColor, size: r.s(16)),
        ),
        SizedBox(width: r.s(10)),
        Text(estado,
            style: TextStyle(
                fontSize: r.s(13),
                fontWeight: FontWeight.w800,
                color: eColor)),
        const Spacer(),
        Icon(Icons.verified_user_rounded,
            color: _cSlate.withOpacity(0.3), size: r.s(14)),
      ]),
    );
  }
}

// ─── Botones de acción ────────────────────────────────────────────────────────
class _Botones extends StatelessWidget {
  final String camionId, estado, tipo;
  final Map<String, dynamic> data;
  final Color eColor;
  final _R r;
  final void Function(String, String, String) onEstado;
  final void Function(String, Map<String, dynamic>) onEditar;
  final void Function(String, String) onEliminar;

  const _Botones({
    required this.camionId, required this.estado,
    required this.tipo,     required this.data,
    required this.eColor,   required this.r,
    required this.onEstado, required this.onEditar,
    required this.onEliminar,
  });

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: EdgeInsets.all(r.s(14)),
      child: Row(children: [
        Expanded(
          flex: 4,
          child: Material(
            color: eColor,
            borderRadius: BorderRadius.circular(r.s(12)),
            child: InkWell(
              onTap: () => onEstado(camionId, estado, tipo),
              borderRadius: BorderRadius.circular(r.s(12)),
              child: SizedBox(
                height: r.s(40),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Icon(Icons.swap_horiz_rounded,
                        size: r.s(16), color: Colors.white),
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
        _IconBtn(
          color: _cIndigo,
          icon : Icons.edit_rounded,
          iconColor: _cAccent,
          size : r.s(40),
          r    : r,
          onTap: () => onEditar(camionId, data),
        ),
        SizedBox(width: r.s(10)),
        _IconBtn(
          color: _cDanger.withOpacity(0.1),
          icon : Icons.delete_rounded,
          iconColor: _cDanger,
          size : r.s(40),
          r    : r,
          onTap: () => onEliminar(camionId, tipo),
        ),
      ]),
    );
  }
}

class _IconBtn extends StatelessWidget {
  final Color color, iconColor;
  final IconData icon;
  final double size;
  final _R r;
  final VoidCallback onTap;
  const _IconBtn({
    required this.color,  required this.icon,
    required this.iconColor, required this.size,
    required this.r,      required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return Material(
      color: color,
      borderRadius: BorderRadius.circular(r.s(12)),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(r.s(12)),
        child: SizedBox(
          width: size, height: size,
          child: Icon(icon, size: r.s(18), color: iconColor),
        ),
      ),
    );
  }
}

// ─── Diálogo cambiar estado ───────────────────────────────────────────────────
class _EstadoDialog extends StatefulWidget {
  final String camionId, estadoActual, tipoCamion;
  const _EstadoDialog({
    required this.camionId,
    required this.estadoActual,
    required this.tipoCamion,
  });

  @override
  State<_EstadoDialog> createState() => _EstadoDialogState();
}

class _EstadoDialogState extends State<_EstadoDialog> {
  late String _sel;

  @override
  void initState() {
    super.initState();
    _sel = widget.estadoActual;
  }

  @override
  Widget build(BuildContext context) {
    final r = _R.of(context);
    return Dialog(
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
              color: _cSurface,
              borderRadius: BorderRadius.circular(r.s(24)),
              boxShadow: [
                BoxShadow(
                    color: _cPrimary.withOpacity(0.18),
                    blurRadius: 40,
                    offset: const Offset(0, 16)),
              ],
            ),
            child: Column(mainAxisSize: MainAxisSize.min, children: [
              // Header
              Container(
                width: double.infinity,
                padding: EdgeInsets.fromLTRB(
                    r.s(24), r.s(24), r.s(24), r.s(20)),
                decoration: BoxDecoration(
                  gradient: const LinearGradient(
                    colors: [_cPrimary, Color(0xFF334155)],
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
                          borderRadius: BorderRadius.circular(r.s(12))),
                      child: Icon(Icons.local_shipping_rounded,
                          color: Colors.white, size: r.s(22)),
                    ),
                    SizedBox(width: r.s(12)),
                    Expanded(
                      child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                        Text('Modificar Estado',
                            style: TextStyle(
                                color: Colors.white,
                                fontSize: r.s(18),
                                fontWeight: FontWeight.w800)),
                        Text(widget.tipoCamion,
                            style: TextStyle(
                                color: Colors.white70,
                                fontSize: r.s(13))),
                      ]),
                    ),
                  ]),
                  SizedBox(height: r.s(14)),
                  Container(
                    padding: EdgeInsets.symmetric(
                        horizontal: r.s(12), vertical: r.s(8)),
                    decoration: BoxDecoration(
                        color: Colors.white.withOpacity(0.12),
                        borderRadius: BorderRadius.circular(r.s(10)),
                        border: Border.all(
                            color: Colors.white.withOpacity(0.2))),
                    child: Row(mainAxisSize: MainAxisSize.min, children: [
                      Icon(_estadoIcon(widget.estadoActual),
                          color: _estadoColor(widget.estadoActual),
                          size: r.s(15)),
                      SizedBox(width: r.s(8)),
                      Text('Actual: ${widget.estadoActual}',
                          style: TextStyle(
                              color: Colors.white,
                              fontSize: r.s(12),
                              fontWeight: FontWeight.w600)),
                    ]),
                  ),
                ]),
              ),
              // Opciones
              Padding(
                padding: EdgeInsets.all(r.s(18)),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text('Selecciona el nuevo estado:',
                        style: TextStyle(
                            fontSize: r.s(13),
                            fontWeight: FontWeight.w600,
                            color: _cSlate)),
                    SizedBox(height: r.s(12)),
                    ...[
                      ('Disponible', _cSuccess,
                          Icons.check_circle_rounded,
                          'Listo para ser asignado'),
                      ('En Mantenimiento', _cWarning,
                          Icons.build_circle_rounded,
                          'En taller o revisión'),
                      ('Fuera de Servicio', _cDanger,
                          Icons.cancel_rounded,
                          'No disponible'),
                    ].map((item) {
                      final (label, color, icon, desc) = item;
                      final sel = _sel == label;
                      return GestureDetector(
                        onTap: () => setState(() => _sel = label),
                        child: AnimatedContainer(
                          duration: const Duration(milliseconds: 180),
                          margin: EdgeInsets.only(bottom: r.s(10)),
                          padding: EdgeInsets.all(r.s(13)),
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
                                  color: color, size: r.s(18)),
                            ),
                            SizedBox(width: r.s(12)),
                            Expanded(
                              child: Column(
                                crossAxisAlignment:
                                    CrossAxisAlignment.start,
                                children: [
                                  Text(label,
                                      style: TextStyle(
                                          fontSize: r.s(14),
                                          fontWeight: FontWeight.w700,
                                          color: sel
                                              ? color
                                              : _cPrimary)),
                                  Text(desc,
                                      style: TextStyle(
                                          fontSize: r.s(11),
                                          color: _cSlate)),
                                ],
                              ),
                            ),
                            if (sel)
                              Icon(Icons.check_circle_rounded,
                                  color: color, size: r.s(20)),
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
                    r.s(18), 0, r.s(18), r.s(18)),
                child: Row(children: [
                  Expanded(
                    child: OutlinedButton(
                      style: OutlinedButton.styleFrom(
                        foregroundColor: _cSlate,
                        side: const BorderSide(
                            color: Color(0xFFE2E8F0)),
                        shape: RoundedRectangleBorder(
                            borderRadius:
                                BorderRadius.circular(r.s(12))),
                        padding: EdgeInsets.symmetric(
                            vertical: r.s(13)),
                      ),
                      onPressed: () => Navigator.pop(context),
                      child: Text('Cancelar',
                          style: TextStyle(
                              fontWeight: FontWeight.w600,
                              fontSize: r.s(13))),
                    ),
                  ),
                  SizedBox(width: r.s(10)),
                  Expanded(
                    flex: 2,
                    child: ElevatedButton.icon(
                      style: ElevatedButton.styleFrom(
                        backgroundColor: _cAccent,
                        foregroundColor: Colors.white,
                        elevation: 4,
                        shadowColor: _cAccent.withOpacity(0.3),
                        shape: RoundedRectangleBorder(
                            borderRadius:
                                BorderRadius.circular(r.s(12))),
                        padding: EdgeInsets.symmetric(
                            vertical: r.s(13)),
                      ),
                      onPressed: () => Navigator.pop(context, _sel),
                      icon: Icon(Icons.check_rounded, size: r.s(18)),
                      label: Text('Confirmar',
                          style: TextStyle(
                              fontWeight: FontWeight.w800,
                              fontSize: r.s(13))),
                    ),
                  ),
                ]),
              ),
            ]),
          ),
        ),
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// Formulario Agregar / Editar Camión
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

  File?      _imgFile;
  Uint8List? _imgBytes;
  String?    _imgUrl;

  @override
  void initState() {
    super.initState();
    if (widget.data != null) {
      _tipoCtrl.text   = widget.data!['tipo']   ?? '';
      _modeloCtrl.text = widget.data!['modelo'] ?? '';
      _placasCtrl.text = widget.data!['placas'] ?? '';
      _fotoCtrl.text   = widget.data!['foto']   ?? '';
      _estado          = widget.data!['estado'] ?? 'Disponible';
      _imgUrl          = widget.data!['foto']?.toString();
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

  Color _eColor(String e) {
    switch (e) {
      case 'Disponible':        return _cSuccess;
      case 'En Mantenimiento':  return _cWarning;
      case 'Fuera de Servicio': return _cDanger;
      default:                  return _cAccent;
    }
  }

  IconData _eIcon(String e) {
    switch (e) {
      case 'Disponible':        return Icons.check_circle_rounded;
      case 'En Mantenimiento':  return Icons.build_circle_rounded;
      case 'Fuera de Servicio': return Icons.cancel_rounded;
      default:                  return Icons.help_rounded;
    }
  }

  Future<void> _pickImagen() async {
    final picked = await ImagePicker()
        .pickImage(source: ImageSource.gallery, imageQuality: 80);
    if (picked == null) return;
    setState(() => _subiendoFoto = true);
    try {
      final ref = FirebaseStorage.instance
          .ref()
          .child('camiones/${DateTime.now().millisecondsSinceEpoch}.jpg');
      if (kIsWeb) {
        final b = await picked.readAsBytes();
        await ref.putData(b);
        setState(() => _imgBytes = b);
      } else {
        final f = File(picked.path);
        await ref.putFile(f);
        setState(() => _imgFile = f);
      }
      final url = await ref.getDownloadURL();
      setState(() { _imgUrl = url; _fotoCtrl.text = url; });
    } catch (e) {
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error imagen: $e'),
              backgroundColor: Colors.red));
    } finally {
      if (mounted) setState(() => _subiendoFoto = false);
    }
  }

  Future<void> _guardar() async {
    if (!_formKey.currentState!.validate()) return;
    setState(() => _guardando = true);
    final fotoUrl = _imgUrl ?? _fotoCtrl.text.trim();
    try {
      if (widget.camionId != null) {
        await FirebaseFirestore.instance
            .collection('camiones')
            .doc(widget.camionId)
            .update({
          'tipo'  : _tipoCtrl.text.trim(),
          'modelo': _modeloCtrl.text.trim(),
          'placas': _placasCtrl.text.trim(),
          'foto'  : fotoUrl,
          'estado': _estado,
          'activo': true,
        });
      } else {
        await FirebaseFirestore.instance.collection('camiones').add({
          'tipo'               : _tipoCtrl.text.trim(),
          'modelo'             : _modeloCtrl.text.trim(),
          'placas'             : _placasCtrl.text.trim(),
          'foto'               : fotoUrl,
          'estado'             : _estado,
          'activo'             : true,
          'ocupado'            : false,
          'operador'           : '',
          'capacidad_toneladas': 0,
        });
      }
      if (mounted) {
        Navigator.of(context).pop();
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(
          content: Text(widget.camionId != null
              ? 'Camión actualizado' : 'Camión agregado'),
          backgroundColor: _cSuccess,
          behavior: SnackBarBehavior.floating,
          shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(12)),
        ));
      }
    } catch (e) {
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error: $e'),
              backgroundColor: Colors.red));
    } finally {
      if (mounted) setState(() => _guardando = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final r        = _R.of(context);
    final esEdicion = widget.camionId != null;

    return Center(
      child: ConstrainedBox(
        constraints: BoxConstraints(
          maxWidth : r.isDesktop ? 640 : double.infinity,
          maxHeight: MediaQuery.of(context).size.height * 0.94,
        ),
        child: Container(
          height: MediaQuery.of(context).size.height * 0.94,
          decoration: BoxDecoration(
            color: const Color(0xFFF8FAFC),
            borderRadius: BorderRadius.vertical(
                top: Radius.circular(r.s(28))),
          ),
          child: Column(children: [
            // Handle
            Container(
              margin: EdgeInsets.only(top: r.s(12)),
              width: r.s(44), height: r.s(4),
              decoration: BoxDecoration(
                  color: Colors.grey[300],
                  borderRadius: BorderRadius.circular(r.s(4))),
            ),
            // Header
            Container(
              margin: EdgeInsets.fromLTRB(
                  r.s(16), r.s(16), r.s(16), 0),
              padding: EdgeInsets.all(r.s(20)),
              decoration: BoxDecoration(
                gradient: const LinearGradient(
                  colors: [_cPrimary, Color(0xFF334155)],
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                ),
                borderRadius: BorderRadius.circular(r.s(20)),
                boxShadow: [
                  BoxShadow(
                      color: _cPrimary.withOpacity(0.25),
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
                    color: Colors.white, size: r.s(24),
                  ),
                ),
                SizedBox(width: r.s(14)),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        esEdicion ? 'Editar Camión' : 'Agregar Camión',
                        style: TextStyle(
                            color: Colors.white,
                            fontSize: r.s(20),
                            fontWeight: FontWeight.w800)),
                      Text(
                        esEdicion
                            ? 'Modifica la información'
                            : 'Registra un nuevo camión',
                        style: TextStyle(
                            color: Colors.white.withOpacity(0.7),
                            fontSize: r.s(13))),
                    ],
                  ),
                ),
              ]),
            ),
            // Form
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
                      Text('📷  Foto del camión',
                          style: TextStyle(
                              fontSize: r.s(15),
                              fontWeight: FontWeight.w800,
                              color: const Color(0xFF0F172A))),
                      SizedBox(height: r.s(10)),
                      GestureDetector(
                        onTap: _pickImagen,
                        child: Container(
                          height: r.s(180),
                          width: double.infinity,
                          decoration: BoxDecoration(
                            color: Colors.white,
                            borderRadius:
                                BorderRadius.circular(r.s(22)),
                            border: Border.all(
                              color: _subiendoFoto
                                  ? _cAccent
                                  : Colors.grey[200]!,
                              width: _subiendoFoto ? 2 : 1.5,
                            ),
                          ),
                          child: ClipRRect(
                            borderRadius:
                                BorderRadius.circular(r.s(21)),
                            child: _subiendoFoto
                                ? Center(
                                    child: Column(
                                      mainAxisAlignment:
                                          MainAxisAlignment.center,
                                      children: [
                                        const CircularProgressIndicator(
                                            color: _cAccent),
                                        SizedBox(height: r.s(10)),
                                        Text('Subiendo...',
                                            style: TextStyle(
                                                color: _cSlate,
                                                fontSize: r.s(13))),
                                      ],
                                    ),
                                  )
                                : _imgUrl != null &&
                                        _imgUrl!.isNotEmpty
                                    ? Stack(
                                        fit: StackFit.expand,
                                        children: [
                                          _imgFile != null && !kIsWeb
                                              ? Image.file(
                                                  _imgFile!,
                                                  fit: BoxFit.cover,
                                                  gaplessPlayback: true)
                                              : _imgBytes != null && kIsWeb
                                                  ? Image.memory(
                                                      _imgBytes!,
                                                      fit: BoxFit.cover)
                                                  : Image.network(
                                                      _imgUrl!,
                                                      fit: BoxFit.cover,
                                                      gaplessPlayback: true),
                                          Positioned(
                                            bottom: r.s(10),
                                            right: r.s(10),
                                            child: Container(
                                              padding: EdgeInsets.symmetric(
                                                  horizontal: r.s(10),
                                                  vertical: r.s(5)),
                                              decoration: BoxDecoration(
                                                  color: Colors.black54,
                                                  borderRadius:
                                                      BorderRadius.circular(
                                                          r.s(10))),
                                              child: Row(
                                                mainAxisSize:
                                                    MainAxisSize.min,
                                                children: [
                                                  Icon(Icons.edit_rounded,
                                                      color: Colors.white,
                                                      size: r.s(13)),
                                                  SizedBox(width: r.s(4)),
                                                  Text('Cambiar',
                                                      style: TextStyle(
                                                          color: Colors.white,
                                                          fontSize: r.s(11),
                                                          fontWeight:
                                                              FontWeight.w600)),
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
                                                EdgeInsets.all(r.s(14)),
                                            decoration: BoxDecoration(
                                                color:
                                                    _cAccent.withOpacity(0.1),
                                                shape: BoxShape.circle),
                                            child: Icon(
                                                Icons
                                                    .add_photo_alternate_rounded,
                                                size: r.s(32),
                                                color: _cAccent),
                                          ),
                                          SizedBox(height: r.s(10)),
                                          Text('Toca para subir foto',
                                              style: TextStyle(
                                                  fontSize: r.s(14),
                                                  fontWeight:
                                                      FontWeight.w700,
                                                  color: _cPrimary)),
                                          Text('Desde tu galería',
                                              style: TextStyle(
                                                  fontSize: r.s(12),
                                                  color: Colors.grey[400])),
                                        ],
                                      ),
                          ),
                        ),
                      ),
                      SizedBox(height: r.s(24)),

                      // Datos
                      Text('🚛  Datos del camión',
                          style: TextStyle(
                              fontSize: r.s(15),
                              fontWeight: FontWeight.w800,
                              color: const Color(0xFF0F172A))),
                      SizedBox(height: r.s(12)),
                      Container(
                        padding: EdgeInsets.all(r.s(16)),
                        decoration: BoxDecoration(
                          color: Colors.white,
                          borderRadius: BorderRadius.circular(r.s(18)),
                          border: Border.all(
                              color: const Color(0xFFE2E8F0)),
                        ),
                        child: Column(children: [
                          _campo(_tipoCtrl, 'Tipo de camión',
                              'Ej: Pipa, Caja seca...', r),
                          SizedBox(height: r.s(12)),
                          _campo(_modeloCtrl, 'Modelo / Año',
                              'Ej: Kenworth T680 2022', r),
                          SizedBox(height: r.s(12)),
                          _campo(_placasCtrl, 'Placas', 'Ej: ABC-123-D',
                              r, caps: TextCapitalization.characters),
                        ]),
                      ),
                      SizedBox(height: r.s(24)),

                      // Estado
                      Text('🔖  Estado del camión',
                          style: TextStyle(
                              fontSize: r.s(15),
                              fontWeight: FontWeight.w800,
                              color: const Color(0xFF0F172A))),
                      SizedBox(height: r.s(12)),
                      Container(
                        padding: EdgeInsets.all(r.s(16)),
                        decoration: BoxDecoration(
                          color: Colors.white,
                          borderRadius: BorderRadius.circular(r.s(18)),
                          border: Border.all(
                              color: const Color(0xFFE2E8F0)),
                        ),
                        child: Column(children: [
                          ...[
                            ('Disponible', _cSuccess,
                                Icons.check_circle_rounded),
                            ('En Mantenimiento', _cWarning,
                                Icons.build_circle_rounded),
                            ('Fuera de Servicio', _cDanger,
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
                                    vertical: r.s(11)),
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
                                      color: sel ? color : _cSlate,
                                      size: r.s(20)),
                                  SizedBox(width: r.s(12)),
                                  Text(label,
                                      style: TextStyle(
                                          fontSize: r.s(14),
                                          fontWeight: FontWeight.w700,
                                          color: sel
                                              ? color
                                              : _cPrimary)),
                                  const Spacer(),
                                  if (sel)
                                    Icon(Icons.check_circle_rounded,
                                        color: color, size: r.s(18)),
                                ]),
                              ),
                            );
                          }),
                        ]),
                      ),
                      SizedBox(height: r.s(28)),

                      // Guardar
                      SizedBox(
                        width: double.infinity,
                        height: r.s(54),
                        child: ElevatedButton.icon(
                          style: ElevatedButton.styleFrom(
                            backgroundColor:
                                esEdicion ? _cAccent : _cSuccess,
                            foregroundColor: Colors.white,
                            elevation: 3,
                            shadowColor:
                                (esEdicion ? _cAccent : _cSuccess)
                                    .withOpacity(0.4),
                            shape: RoundedRectangleBorder(
                                borderRadius:
                                    BorderRadius.circular(r.s(12))),
                          ),
                          onPressed: _guardando ? null : _guardar,
                          icon: _guardando
                              ? SizedBox(
                                  width: r.s(20), height: r.s(20),
                                  child: const CircularProgressIndicator(
                                      color: Colors.white,
                                      strokeWidth: 2.5))
                              : Icon(
                                  esEdicion
                                      ? Icons.update_rounded
                                      : Icons.save_rounded,
                                  size: r.s(20)),
                          label: Text(
                            _guardando
                                ? 'Guardando...'
                                : esEdicion
                                    ? 'ACTUALIZAR CAMIÓN'
                                    : 'GUARDAR CAMIÓN',
                            style: TextStyle(
                                fontSize: r.s(14),
                                fontWeight: FontWeight.w800)),
                        ),
                      ),
                      SizedBox(height: r.s(10)),
                      SizedBox(
                        width: double.infinity,
                        height: r.s(46),
                        child: OutlinedButton(
                          style: OutlinedButton.styleFrom(
                            foregroundColor: _cSlate,
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
          ]),
        ),
      ),
    );
  }

  Widget _campo(
    TextEditingController ctrl,
    String label,
    String hint,
    _R r, {
    TextCapitalization caps = TextCapitalization.sentences,
  }) {
    return TextFormField(
      controller     : ctrl,
      textCapitalization: caps,
      style          : TextStyle(
          fontSize: r.s(14),
          fontWeight: FontWeight.w600,
          color: const Color(0xFF0F172A)),
      decoration: InputDecoration(
        labelText : label,
        hintText  : hint,
        hintStyle : TextStyle(
            color: Colors.grey[400], fontSize: r.s(12)),
        filled    : true,
        fillColor : const Color(0xFFF8FAFC),
        contentPadding: EdgeInsets.symmetric(
            horizontal: r.s(14), vertical: r.s(13)),
        border: OutlineInputBorder(
            borderRadius: BorderRadius.circular(r.s(12)),
            borderSide: const BorderSide(color: Color(0xFFE2E8F0))),
        enabledBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(r.s(12)),
            borderSide: const BorderSide(color: Color(0xFFE2E8F0))),
        focusedBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(r.s(12)),
            borderSide: const BorderSide(color: _cAccent, width: 2)),
        errorBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(r.s(12)),
            borderSide: const BorderSide(color: _cDanger)),
      ),
      validator: (v) =>
          (v?.trim().isEmpty ?? true) ? 'Campo requerido' : null,
    );
  }
}