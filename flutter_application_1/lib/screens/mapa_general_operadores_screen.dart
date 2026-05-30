import 'dart:math' as math;

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:latlong2/latlong.dart';

// ─── Paleta (fondo blanco / azul marino) ─────────────────────────────────────
class _C {
  // Fondos
  static const bg = Color(0xFFF1F5F9); // fondo general
  static const surface = Color(0xFFFFFFFF); // tarjetas
  static const surfaceSub = Color(0xFFF8FAFC); // tarjeta secundaria

  // Azul marino principal
  static const navy = Color(0xFF0F2754);
  static const navyMid = Color(0xFF1A3A6B);
  static const navyLight = Color(0xFFEFF6FF); // azul muy suave

  // Acento / estado
  static const blue = Color(0xFF1D4ED8);
  static const sky = Color(0xFF38BDF8);
  static const success = Color(0xFF10B981);
  static const successBg = Color(0xFFECFDF5);
  static const warning = Color(0xFFF59E0B);
  static const danger = Color(0xFFEF4444);

  // Texto
  static const text = Color(0xFF0F172A);
  static const textSub = Color(0xFF64748B);
  static const textMuted = Color(0xFF94A3B8);

  // Borde
  static const border = Color(0xFFE2E8F0);
  static const borderMid = Color(0xFFCBD5E1);

  // Mapa
  static const mapBg = Color(0xFFF8FAFC); // borde alrededor del mapa
}

class MapaGeneralOperadoresScreen extends StatefulWidget {
  const MapaGeneralOperadoresScreen({super.key});

  @override
  State<MapaGeneralOperadoresScreen> createState() =>
      _MapaGeneralOperadoresScreenState();
}

class _MapaGeneralOperadoresScreenState
    extends State<MapaGeneralOperadoresScreen>
    with TickerProviderStateMixin {
  static const LatLng _fallbackCenter = LatLng(18.7451879, -98.9083418);

  // Paleta de colores para marcadores — vibrante sobre fondo claro
  static const _palette = [
    Color(0xFF1D4ED8), // azul
    Color(0xFF7C3AED), // violeta
    Color(0xFF059669), // verde
    Color(0xFFD97706), // ámbar
    Color(0xFFDC2626), // rojo
    Color(0xFF0891B2), // cian
    Color(0xFF9333EA), // púrpura
    Color(0xFF0F766E), // teal
  ];

  final MapController _mapController = MapController();
  final Map<String, _OperadorAnimacion> _animaciones = {};
  late final AnimationController _cameraCtrl;
  VoidCallback? _camListener;

  bool _seguirOperador = false;
  String? _seleccionadoId;
  LatLng? _ultimaPosSeguida;
  double _zoomActual = 14.6;
  String _firmaSnapshot = '';

  @override
  void initState() {
    super.initState();
    _cameraCtrl = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 820),
    );
  }

  @override
  void dispose() {
    if (_camListener != null) _cameraCtrl.removeListener(_camListener!);
    _cameraCtrl.dispose();
    for (final a in _animaciones.values) a.controller.dispose();
    super.dispose();
  }

  // ── Helpers ──────────────────────────────────────────────────────────────

  Color _colorOp(String id) => _palette[id.hashCode.abs() % _palette.length];

  bool _samePt(LatLng a, LatLng b) =>
      (a.latitude - b.latitude).abs() < 1e-6 &&
      (a.longitude - b.longitude).abs() < 1e-6;

  double _bearing(LatLng from, LatLng to) {
    final la1 = from.latitude * (math.pi / 180);
    final la2 = to.latitude * (math.pi / 180);
    final dLon = (to.longitude - from.longitude) * (math.pi / 180);
    final y = math.sin(dLon) * math.cos(la2);
    final x =
        math.cos(la1) * math.sin(la2) -
        math.sin(la1) * math.cos(la2) * math.cos(dLon);
    return (180 / math.pi * math.atan2(y, x) + 360) % 360;
  }

  // ── Animación de posición ─────────────────────────────────────────────────

  void _syncAnim(String id, LatLng newPos) {
    final ex = _animaciones[id];
    if (ex == null) {
      final ctrl = AnimationController(
        duration: const Duration(milliseconds: 1050),
        vsync: this,
      );
      _animaciones[id] = _OperadorAnimacion(
        controller: ctrl,
        pos: newPos,
        target: newPos,
        trail: [newPos],
      );
      return;
    }
    if (_samePt(ex.target, newPos)) return;

    ex.version++;
    final ver = ex.version;
    ex.moving = true;
    ex.bearing = _bearing(ex.pos, newPos);
    ex.trail.add(ex.pos);
    if (ex.trail.length > 10) ex.trail.removeAt(0);
    ex.target = newPos;

    final anim = _LatLngTween(begin: ex.pos, end: newPos).animate(
      CurvedAnimation(parent: ex.controller, curve: Curves.easeInOutCubic),
    );

    void listener() {
      if (!mounted) return;
      setState(() => ex.pos = anim.value);
    }

    if (ex.listener != null) ex.controller.removeListener(ex.listener!);
    ex.listener = listener;
    ex.controller
      ..stop()
      ..addListener(listener)
      ..forward(from: 0).whenCompleteOrCancel(() {
        if (!mounted || ver != ex.version) return;
        setState(() {
          ex.moving = false;
          ex.pos = newPos;
          ex.trail.add(newPos);
          if (ex.trail.length > 10) ex.trail.removeAt(0);
        });
      });
  }

  void _removeInactive(Set<String> active) {
    for (final id in _animaciones.keys.toList()) {
      if (!active.contains(id)) {
        _animaciones[id]?.controller.dispose();
        _animaciones.remove(id);
      }
    }
  }

  // ── Cámara ────────────────────────────────────────────────────────────────

  void _centerMap(LatLng center, {required bool hasOps}) {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      _animCamera(center, zoom: hasOps ? 13.2 : 14.6);
    });
  }

  void _animCamera(LatLng dest, {double? zoom}) {
    final from = _mapController.camera.center;
    final zFrom = _mapController.camera.zoom;
    final zTo = zoom ?? zFrom;

    final posAnim = _LatLngTween(
      begin: from,
      end: dest,
    ).animate(CurvedAnimation(parent: _cameraCtrl, curve: Curves.easeOutCubic));
    final zoomAnim = Tween<double>(
      begin: zFrom,
      end: zTo,
    ).animate(CurvedAnimation(parent: _cameraCtrl, curve: Curves.easeOutCubic));

    if (_camListener != null) _cameraCtrl.removeListener(_camListener!);
    void listener() {
      if (!mounted) return;
      _mapController.move(posAnim.value, zoomAnim.value);
      _zoomActual = zoomAnim.value;
    }

    _camListener = listener;
    _cameraCtrl
      ..stop()
      ..addListener(listener)
      ..forward(from: 0);
  }

  void _followUpdate(List<_OperadorActivo> ops) {
    if (!_seguirOperador || ops.isEmpty) return;
    _seleccionadoId ??= ops.first.id;
    final sel = ops
        .where((o) => o.id == _seleccionadoId)
        .cast<_OperadorActivo?>()
        .firstWhere((_) => true, orElse: () => null);
    final target = sel?.posicion ?? ops.first.posicion;
    if (_ultimaPosSeguida != null && _samePt(_ultimaPosSeguida!, target))
      return;
    _ultimaPosSeguida = target;
    _animCamera(target, zoom: _zoomActual < 15.2 ? 15.2 : _zoomActual);
  }

  String _firma(List<_OperadorActivo> ops) {
    final sorted = [...ops]..sort((a, b) => a.id.compareTo(b.id));
    return sorted
        .map((o) => '${o.id}:${o.posicion.latitude}:${o.posicion.longitude}')
        .join('|');
  }

  // ── Parse posición Firestore ──────────────────────────────────────────────

  // ── Parse posición Firestore ──────────────────────────────────────────────

  LatLng? _parsePos(Map<String, dynamic> data) {
    // Cambiamos el nombre de 'num' a 'parsear' para evitar el conflicto
    double? parsear(dynamic v) {
      if (v == null) return null;
      if (v is num)
        return v.toDouble(); // Ahora 'is num' funciona correctamente
      if (v is String) return double.tryParse(v.trim());
      return null;
    }

    final lat = parsear(
      data['latitud'] ?? data['latitude'] ?? data['lat'] ?? data['y'],
    );
    final lng = parsear(
      data['longitud'] ??
          data['longitude'] ??
          data['lng'] ??
          data['lon'] ??
          data['x'],
    );

    if (lat != null && lng != null && lat.abs() <= 90 && lng.abs() <= 180) {
      return LatLng(lat, lng);
    }

    final gpActual = data['ubicacion_actual'];
    if (gpActual is GeoPoint)
      return LatLng(gpActual.latitude, gpActual.longitude);

    final gp = data['ubicacion'] ?? data['posicion'];
    if (gp is GeoPoint) return LatLng(gp.latitude, gp.longitude);

    return null;
  }

  // ─────────────────────────────────────────────────────────────────────────

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: _C.bg,
      appBar: _buildAppBar(),
      body: StreamBuilder<QuerySnapshot<Map<String, dynamic>>>(
        stream: FirebaseFirestore.instance
            .collection('usuarios')
            .where('gps_activo', isEqualTo: true)
            .snapshots(),
        builder: (context, snap) {
          final loading = snap.connectionState == ConnectionState.waiting;
          final hasError = snap.hasError;
          final docs = snap.data?.docs ?? [];

          final ops = <_OperadorActivo>[];
          final tracked = <Map<String, String>>[];

          for (final doc in docs) {
            final d = doc.data();
            final uid = d['uid']?.toString().trim() ?? '';
            if (uid.isNotEmpty && doc.id != uid) {
              // Evitar duplicados: ignorar documentos legacy por nombre
              // cuando ya existe el documento maestro por UID.
              continue;
            }
            final pos = _parsePos(d);
            if (pos == null) continue;

            final nombre = d['nombre']?.toString().trim().isNotEmpty == true
                ? d['nombre'].toString().trim()
                : 'Sin nombre';
            final camion = d['camion_actual']?.toString().trim() ?? '';
            final direccion = d['direccion']?.toString().trim() ?? '';

            ops.add(
              _OperadorActivo(
                id: doc.id,
                nombre: nombre,
                posicion: pos,
                color: _colorOp(doc.id),
              ),
            );
            tracked.add({
              'id': doc.id,
              'nombre': nombre,
              'camion': camion.isEmpty ? 'Sin camión asignado' : camion,
              'direccion': direccion.isEmpty
                  ? 'Ubicación no disponible'
                  : direccion,
            });
          }

          _removeInactive(ops.map((o) => o.id).toSet());
          for (final op in ops) _syncAnim(op.id, op.posicion);

          // Marcadores
          final markers = ops
              .map((op) {
                final a = _animaciones[op.id];
                final cur = a?.pos ?? op.posicion;
                return Marker(
                  point: cur,
                  width: 150,
                  height: 90,
                  alignment: Alignment.topCenter,
                  child: _TruckMarker(
                    nombre: op.nombre,
                    color: op.color,
                    bearing: a?.bearing ?? 0,
                    enMovimiento: a?.moving ?? false,
                  ),
                );
              })
              .toList(growable: false);

          // Centro
          LatLng center = _fallbackCenter;
          if (ops.isNotEmpty) {
            center = LatLng(
              ops.map((o) => o.posicion.latitude).reduce((a, b) => a + b) /
                  ops.length,
              ops.map((o) => o.posicion.longitude).reduce((a, b) => a + b) /
                  ops.length,
            );
          }

          final firma = _firma(ops);
          if (firma != _firmaSnapshot) {
            _firmaSnapshot = firma;
            if (!_seguirOperador) _centerMap(center, hasOps: ops.isNotEmpty);
          }
          _followUpdate(ops);

          return Stack(
            children: [
              Column(
                children: [
                  // ── Barra de estado ─────────────────────────────────────
                  _StatusBar(
                    count: ops.length,
                    seguir: _seguirOperador,
                    onToggleSeguir: () => setState(() {
                      _seguirOperador = !_seguirOperador;
                      if (_seguirOperador &&
                          _seleccionadoId == null &&
                          ops.isNotEmpty) {
                        _seleccionadoId = ops.first.id;
                      }
                      if (!_seguirOperador) _ultimaPosSeguida = null;
                    }),
                    onCenter: () => _centerMap(center, hasOps: ops.isNotEmpty),
                  ),

                  // ── Mapa ────────────────────────────────────────────────
                  Expanded(
                    child: Padding(
                      padding: const EdgeInsets.fromLTRB(14, 0, 14, 0),
                      child: ClipRRect(
                        borderRadius: BorderRadius.circular(20),
                        child: Container(
                          decoration: BoxDecoration(
                            border: Border.all(color: _C.border, width: 1.5),
                            borderRadius: BorderRadius.circular(20),
                            boxShadow: [
                              BoxShadow(
                                color: Colors.black.withOpacity(0.08),
                                blurRadius: 12,
                                offset: const Offset(0, 4),
                              ),
                            ],
                          ),
                          child: ClipRRect(
                            borderRadius: BorderRadius.circular(19),
                            child: FlutterMap(
                              mapController: _mapController,
                              options: MapOptions(
                                initialCenter: _fallbackCenter,
                                initialZoom: 14.6,
                                minZoom: 5,
                                maxZoom: 18,
                                onPositionChanged: (pos, _) {
                                  final z = pos.zoom;
                                  if (z != null) _zoomActual = z;
                                },
                              ),
                              children: [
                                // Tile con estilo claro
                                TileLayer(
                                  urlTemplate:
                                      'https://a.basemaps.cartocdn.com/rastertiles/voyager/{z}/{x}/{y}.png',
                                  userAgentPackageName:
                                      'com.recicladora.guadalajara',
                                  tileDisplay: const TileDisplay.fadeIn(
                                    duration: Duration(milliseconds: 200),
                                  ),
                                ),
                                MarkerLayer(markers: markers),
                                RichAttributionWidget(
                                  attributions: [
                                    TextSourceAttribution(
                                      '© OpenStreetMap contributors',
                                    ),
                                  ],
                                ),
                              ],
                            ),
                          ),
                        ),
                      ),
                    ),
                  ),

                  const SizedBox(height: 12),

                  // ── Lista horizontal de operadores ──────────────────────
                  SizedBox(
                    height: 148,
                    child: ops.isEmpty
                        ? Center(
                            child: Text(
                              'No hay operadores con GPS activo',
                              style: TextStyle(color: _C.textSub, fontSize: 14),
                            ),
                          )
                        : ListView.separated(
                            padding: const EdgeInsets.fromLTRB(14, 0, 14, 12),
                            scrollDirection: Axis.horizontal,
                            itemCount: tracked.length,
                            separatorBuilder: (_, __) =>
                                const SizedBox(width: 10),
                            itemBuilder: (ctx, i) {
                              final item = tracked[i];
                              final id = item['id']!;
                              final sel = id == _seleccionadoId;
                              final color = _colorOp(id);
                              return _OperadorCard(
                                item: item,
                                color: color,
                                sel: sel,
                                onTap: () => setState(() {
                                  _seleccionadoId = id;
                                  _seguirOperador = true;
                                  _ultimaPosSeguida = null;
                                }),
                              );
                            },
                          ),
                  ),
                ],
              ),

              // ── Overlays ───────────────────────────────────────────────
              if (hasError)
                _Overlay(
                  color: Colors.red.withOpacity(0.08),
                  child: const Text(
                    'Error cargando posiciones',
                    style: TextStyle(
                      color: _C.danger,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                ),
              if (loading && ops.isEmpty)
                _Overlay(
                  color: Colors.white.withOpacity(0.7),
                  child: const Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      CircularProgressIndicator(color: _C.navy, strokeWidth: 3),
                      SizedBox(height: 14),
                      Text(
                        'Cargando operadores…',
                        style: TextStyle(
                          color: _C.navy,
                          fontWeight: FontWeight.w700,
                          fontSize: 14,
                        ),
                      ),
                    ],
                  ),
                ),
            ],
          );
        },
      ),
    );
  }

  PreferredSizeWidget _buildAppBar() => AppBar(
    title: const Text(
      'Monitoreo en Tiempo Real',
      style: TextStyle(
        fontWeight: FontWeight.w800,
        fontSize: 17,
        color: Colors.white,
      ),
    ),
    backgroundColor: _C.navy,
    elevation: 0,
    automaticallyImplyLeading: false,
    // ícono de satélite animado
    leading: Container(
      margin: const EdgeInsets.all(10),
      padding: const EdgeInsets.all(6),
      decoration: BoxDecoration(
        color: Colors.white.withOpacity(0.12),
        borderRadius: BorderRadius.circular(10),
      ),
      child: const Icon(
        Icons.satellite_alt_rounded,
        color: Colors.white,
        size: 20,
      ),
    ),
    bottom: PreferredSize(
      preferredSize: const Size.fromHeight(1),
      child: Container(height: 1, color: _C.navyMid.withOpacity(0.5)),
    ),
  );
}

// ─── Barra de estado superior ─────────────────────────────────────────────────
class _StatusBar extends StatelessWidget {
  final int count;
  final bool seguir;
  final VoidCallback onToggleSeguir;
  final VoidCallback onCenter;
  const _StatusBar({
    required this.count,
    required this.seguir,
    required this.onToggleSeguir,
    required this.onCenter,
  });

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(14, 14, 14, 10),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
        decoration: BoxDecoration(
          color: _C.surface,
          borderRadius: BorderRadius.circular(14),
          border: Border.all(color: _C.border),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withOpacity(0.05),
              blurRadius: 8,
              offset: const Offset(0, 2),
            ),
          ],
        ),
        child: Row(
          children: [
            // Punto verde pulsante
            _PulseDot(),
            const SizedBox(width: 10),
            Expanded(
              child: RichText(
                text: TextSpan(
                  style: const TextStyle(fontSize: 13, color: _C.text),
                  children: [
                    TextSpan(
                      text: '$count ',
                      style: const TextStyle(
                        fontWeight: FontWeight.w800,
                        fontSize: 14,
                        color: _C.navy,
                      ),
                    ),
                    TextSpan(
                      text: count == 1
                          ? 'operador con GPS activo'
                          : 'operadores con GPS activo',
                      style: const TextStyle(
                        fontWeight: FontWeight.w600,
                        color: _C.textSub,
                      ),
                    ),
                  ],
                ),
              ),
            ),
            // Botón seguir
            _IconBtn(
              icon: seguir
                  ? Icons.location_searching_rounded
                  : Icons.location_disabled_rounded,
              color: seguir ? _C.success : _C.textMuted,
              bg: seguir ? _C.successBg : const Color(0xFFF1F5F9),
              tooltip: seguir ? 'Desactivar seguimiento' : 'Seguir operador',
              onTap: onToggleSeguir,
            ),
            const SizedBox(width: 6),
            // Botón centrar
            _IconBtn(
              icon: Icons.center_focus_strong_rounded,
              color: _C.navy,
              bg: const Color(0xFFEFF6FF),
              tooltip: 'Centrar mapa',
              onTap: onCenter,
            ),
          ],
        ),
      ),
    );
  }
}

class _PulseDot extends StatefulWidget {
  @override
  State<_PulseDot> createState() => _PulseDotState();
}

class _PulseDotState extends State<_PulseDot>
    with SingleTickerProviderStateMixin {
  late final AnimationController _c;

  @override
  void initState() {
    super.initState();
    _c = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1200),
    )..repeat();
  }

  @override
  void dispose() {
    _c.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: _c,
      builder: (_, __) {
        final t = _c.value;
        return Stack(
          alignment: Alignment.center,
          children: [
            Container(
              width: 18 * (0.8 + t * 0.5),
              height: 18 * (0.8 + t * 0.5),
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: _C.success.withOpacity(0.22 * (1 - t)),
              ),
            ),
            Container(
              width: 10,
              height: 10,
              decoration: const BoxDecoration(
                shape: BoxShape.circle,
                color: _C.success,
              ),
            ),
          ],
        );
      },
    );
  }
}

class _IconBtn extends StatelessWidget {
  final IconData icon;
  final Color color;
  final Color bg;
  final String tooltip;
  final VoidCallback onTap;
  const _IconBtn({
    required this.icon,
    required this.color,
    required this.bg,
    required this.tooltip,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return Tooltip(
      message: tooltip,
      child: GestureDetector(
        onTap: onTap,
        child: Container(
          padding: const EdgeInsets.all(8),
          decoration: BoxDecoration(
            color: bg,
            borderRadius: BorderRadius.circular(10),
          ),
          child: Icon(icon, color: color, size: 20),
        ),
      ),
    );
  }
}

// ─── Tarjeta de operador ──────────────────────────────────────────────────────
class _OperadorCard extends StatelessWidget {
  final Map<String, String> item;
  final Color color;
  final bool sel;
  final VoidCallback onTap;
  const _OperadorCard({
    required this.item,
    required this.color,
    required this.sel,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final nombre = item['nombre'] ?? 'Sin nombre';
    final partes = nombre.trim().split(' ');
    final iniciales = partes.length >= 2
        ? '${partes[0][0]}${partes[1][0]}'.toUpperCase()
        : nombre.substring(0, nombre.length.clamp(0, 2)).toUpperCase();

    return GestureDetector(
      onTap: onTap,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 200),
        width: 220,
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(
          color: _C.surface,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(
            color: sel ? color : _C.border,
            width: sel ? 2 : 1.2,
          ),
          boxShadow: [
            BoxShadow(
              color: sel
                  ? color.withOpacity(0.15)
                  : Colors.black.withOpacity(0.05),
              blurRadius: sel ? 12 : 6,
              offset: const Offset(0, 3),
            ),
          ],
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                // Avatar
                Container(
                  width: 36,
                  height: 36,
                  decoration: BoxDecoration(
                    color: color.withOpacity(0.15),
                    borderRadius: BorderRadius.circular(10),
                    border: Border.all(color: color.withOpacity(0.35)),
                  ),
                  child: Center(
                    child: Text(
                      iniciales,
                      style: TextStyle(
                        color: color,
                        fontWeight: FontWeight.w800,
                        fontSize: 13,
                      ),
                    ),
                  ),
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        nombre,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: const TextStyle(
                          color: _C.text,
                          fontWeight: FontWeight.w800,
                          fontSize: 13,
                        ),
                      ),
                      const SizedBox(height: 2),
                      if (sel)
                        Container(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 6,
                            vertical: 2,
                          ),
                          decoration: BoxDecoration(
                            color: _C.successBg,
                            borderRadius: BorderRadius.circular(6),
                          ),
                          child: const Text(
                            'Siguiendo',
                            style: TextStyle(
                              color: _C.success,
                              fontSize: 10,
                              fontWeight: FontWeight.w700,
                            ),
                          ),
                        ),
                    ],
                  ),
                ),
                // Indicador de movimiento
                Container(
                  width: 8,
                  height: 8,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    color: color,
                    boxShadow: [
                      BoxShadow(color: color.withOpacity(0.4), blurRadius: 6),
                    ],
                  ),
                ),
              ],
            ),
            const SizedBox(height: 10),
            // Camión
            Row(
              children: [
                Icon(Icons.local_shipping_rounded, size: 13, color: _C.textSub),
                const SizedBox(width: 4),
                Expanded(
                  child: Text(
                    item['camion'] ?? 'Sin camión',
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(
                      color: _C.textSub,
                      fontSize: 11.5,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 4),
            // Dirección
            Row(
              children: [
                Icon(Icons.location_on_rounded, size: 13, color: _C.textMuted),
                const SizedBox(width: 4),
                Expanded(
                  child: Text(
                    item['direccion'] ?? '',
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(
                      color: _C.textMuted,
                      fontSize: 11,
                      height: 1.3,
                    ),
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

// ─── Marcador del camión en el mapa ──────────────────────────────────────────
class _TruckMarker extends StatelessWidget {
  final String nombre;
  final Color color;
  final double bearing;
  final bool enMovimiento;
  const _TruckMarker({
    required this.nombre,
    required this.color,
    required this.bearing,
    required this.enMovimiento,
  });

  @override
  Widget build(BuildContext context) {
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        _PulseTruckIcon(
          color: color,
          bearing: bearing,
          enMovimiento: enMovimiento,
        ),
        const SizedBox(height: 3),
        Container(
          constraints: const BoxConstraints(maxWidth: 110),
          padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 3),
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(8),
            border: Border.all(color: color.withOpacity(0.4)),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withOpacity(0.1),
                blurRadius: 6,
                offset: const Offset(0, 2),
              ),
            ],
          ),
          child: Text(
            nombre,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            textAlign: TextAlign.center,
            style: TextStyle(
              fontSize: 10,
              fontWeight: FontWeight.w800,
              color: color,
            ),
          ),
        ),
      ],
    );
  }
}

class _PulseTruckIcon extends StatefulWidget {
  final Color color;
  final double bearing;
  final bool enMovimiento;
  const _PulseTruckIcon({
    required this.color,
    required this.bearing,
    required this.enMovimiento,
  });

  @override
  State<_PulseTruckIcon> createState() => _PulseTruckIconState();
}

class _PulseTruckIconState extends State<_PulseTruckIcon>
    with SingleTickerProviderStateMixin {
  late final AnimationController _c;

  @override
  void initState() {
    super.initState();
    _c = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1400),
    )..repeat();
  }

  @override
  void dispose() {
    _c.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: _c,
      builder: (_, __) {
        final t = _c.value;
        final pulse = widget.enMovimiento ? (0.78 + t * 0.48) : 0.82;
        final alpha = widget.enMovimiento ? (0.25 * (1 - t)) : 0.08;

        return Stack(
          alignment: Alignment.center,
          children: [
            // Halo
            Container(
              width: 38 * pulse,
              height: 38 * pulse,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: widget.color.withOpacity(alpha),
              ),
            ),
            // Fondo blanco del ícono
            Container(
              width: 36,
              height: 36,
              decoration: BoxDecoration(
                color: Colors.white,
                shape: BoxShape.circle,
                border: Border.all(color: widget.color, width: 2.5),
                boxShadow: [
                  BoxShadow(
                    color: widget.color.withOpacity(0.3),
                    blurRadius: 10,
                    offset: const Offset(0, 3),
                  ),
                ],
              ),
              child: Transform.rotate(
                angle: widget.bearing * (math.pi / 180),
                child: Icon(
                  Icons.local_shipping_rounded,
                  size: 18,
                  color: widget.color,
                ),
              ),
            ),
          ],
        );
      },
    );
  }
}

// ─── Overlay de estado ────────────────────────────────────────────────────────
class _Overlay extends StatelessWidget {
  final Color color;
  final Widget child;
  const _Overlay({required this.color, required this.child});

  @override
  Widget build(BuildContext context) {
    return Positioned.fill(
      child: Container(
        color: color,
        child: Center(child: child),
      ),
    );
  }
}

// ─── Modelos ──────────────────────────────────────────────────────────────────
class _OperadorActivo {
  final String id;
  final String nombre;
  final LatLng posicion;
  final Color color;
  const _OperadorActivo({
    required this.id,
    required this.nombre,
    required this.posicion,
    required this.color,
  });
}

class _OperadorAnimacion {
  final AnimationController controller;
  LatLng pos;
  LatLng target;
  List<LatLng> trail;
  VoidCallback? listener;
  bool moving;
  double bearing;
  int version;

  _OperadorAnimacion({
    required this.controller,
    required this.pos,
    required this.target,
    required this.trail,
    this.moving = false,
    this.bearing = 0,
    this.version = 0,
  });
}

// ─── Tween de coordenadas ─────────────────────────────────────────────────────
class _LatLngTween extends Tween<LatLng> {
  _LatLngTween({required super.begin, required super.end});

  @override
  LatLng lerp(double t) {
    final b = begin!;
    final e = end!;
    return LatLng(
      b.latitude + (e.latitude - b.latitude) * t,
      b.longitude + (e.longitude - b.longitude) * t,
    );
  }
}
