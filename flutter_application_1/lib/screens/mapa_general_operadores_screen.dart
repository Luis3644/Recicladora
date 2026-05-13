import 'dart:math' as math;

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:latlong2/latlong.dart';

class MapaGeneralOperadoresScreen extends StatefulWidget {
  const MapaGeneralOperadoresScreen({super.key});

  @override
  State<MapaGeneralOperadoresScreen> createState() =>
      _MapaGeneralOperadoresScreenState();
}

class _MapaGeneralOperadoresScreenState
    extends State<MapaGeneralOperadoresScreen>
    with TickerProviderStateMixin {
  static const Color _primary = Color(0xFF0B0F14);
  static const Color _accent = Color(0xFF94A3B8);
  static const Color _success = Color(0xFF60A5FA);
  static const Color _bg = Color(0xFF070A0F);
  static const Color _surface = Color(0xFF111827);
  static const Color _surfaceSoft = Color(0xFF1F2937);
  static const Color _textPrimary = Color(0xFFE5E7EB);
  static const Color _textMuted = Color(0xFF9CA3AF);
  static const LatLng _fallbackCenter = LatLng(18.7451879, -98.9083418);

  final MapController _mapController = MapController();
  final Map<String, _OperadorAnimacion> _operadorAnimaciones = {};
  late final AnimationController _cameraController;
  VoidCallback? _cameraListener;
  bool _contentVisible = false;
  bool _seguirOperador = false;
  String? _operadorSeleccionadoId;
  LatLng? _ultimaPosicionSeguida;
  double _ultimoZoom = 14.6;
  String _ultimaFirmaSnapshot = '';

  @override
  void initState() {
    super.initState();
    _cameraController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 820),
    );
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      setState(() => _contentVisible = true);
    });
  }

  @override
  void dispose() {
    if (_cameraListener != null) {
      _cameraController.removeListener(_cameraListener!);
    }
    _cameraController.dispose();
    for (final animacion in _operadorAnimaciones.values) {
      animacion.controller.dispose();
    }
    super.dispose();
  }

  String get _tileUrl => 'https://{s}.tile.openstreetmap.org/{z}/{x}/{y}.png';

  Color _colorOperador(String operadorId) {
    const palette = [
      Color(0xFF60A5FA),
      Color(0xFF818CF8),
      Color(0xFF94A3B8),
      Color(0xFF64748B),
      Color(0xFF38BDF8),
      Color(0xFF6B7280),
      Color(0xFF0EA5E9),
      Color(0xFF475569),
    ];
    return palette[operadorId.hashCode.abs() % palette.length];
  }

  bool _mismaPosicion(LatLng a, LatLng b) {
    const epsilon = 0.000001;
    return (a.latitude - b.latitude).abs() < epsilon &&
        (a.longitude - b.longitude).abs() < epsilon;
  }

  double _bearingDegrees(LatLng from, LatLng to) {
    final lat1 = from.latitude * (math.pi / 180);
    final lat2 = to.latitude * (math.pi / 180);
    final dLon = (to.longitude - from.longitude) * (math.pi / 180);

    final y = math.sin(dLon) * math.cos(lat2);
    final x =
        math.cos(lat1) * math.sin(lat2) -
        math.sin(lat1) * math.cos(lat2) * math.cos(dLon);
    final brng = (180 / math.pi) * math.atan2(y, x);
    return (brng + 360) % 360;
  }

  void _sincronizarAnimacionOperador(String operadorId, LatLng nuevaPosicion) {
    final existente = _operadorAnimaciones[operadorId];
    if (existente == null) {
      final controller = AnimationController(
        duration: const Duration(milliseconds: 1050),
        vsync: this,
      );
      _operadorAnimaciones[operadorId] = _OperadorAnimacion(
        controller: controller,
        posicionActual: nuevaPosicion,
        objetivo: nuevaPosicion,
        trail: [nuevaPosicion],
      );
      return;
    }

    if (_mismaPosicion(existente.objetivo, nuevaPosicion)) return;

    existente.version += 1;
    final versionActual = existente.version;
    existente.enMovimiento = true;
    existente.bearing = _bearingDegrees(
      existente.posicionActual,
      nuevaPosicion,
    );
    existente.trail.add(existente.posicionActual);
    if (existente.trail.length > 10) {
      existente.trail.removeAt(0);
    }

    existente.objetivo = nuevaPosicion;
    final animation =
        _LatLngTween(
          begin: existente.posicionActual,
          end: nuevaPosicion,
        ).animate(
          CurvedAnimation(
            parent: existente.controller,
            curve: Curves.easeInOutCubic,
          ),
        );

    void listener() {
      if (!mounted) return;
      setState(() {
        existente.posicionActual = animation.value;
      });
    }

    if (existente.listener != null) {
      existente.controller.removeListener(existente.listener!);
    }
    existente.listener = listener;

    existente.controller
      ..stop()
      ..addListener(listener)
      ..forward(from: 0).whenCompleteOrCancel(() {
        if (!mounted) return;
        if (versionActual != existente.version) return;
        setState(() {
          existente.enMovimiento = false;
          existente.posicionActual = nuevaPosicion;
          existente.trail.add(nuevaPosicion);
          if (existente.trail.length > 10) {
            existente.trail.removeAt(0);
          }
        });
      });
  }

  void _eliminarOperadoresInactivos(Set<String> activos) {
    final idsActuales = _operadorAnimaciones.keys.toList();
    for (final id in idsActuales) {
      if (activos.contains(id)) continue;
      _operadorAnimaciones[id]?.controller.dispose();
      _operadorAnimaciones.remove(id);
    }
  }

  void _centrarMapa(LatLng centro, {required bool hayOperadores}) {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      _animarCamara(centro, zoom: hayOperadores ? 13.2 : 14.6);
    });
  }

  void _animarCamara(LatLng destino, {double? zoom}) {
    final inicio = _mapController.camera.center;
    final zoomInicio = _mapController.camera.zoom;
    final zoomFinal = zoom ?? zoomInicio;

    final posAnim = _LatLngTween(begin: inicio, end: destino).animate(
      CurvedAnimation(parent: _cameraController, curve: Curves.easeOutCubic),
    );
    final zoomAnim = Tween<double>(begin: zoomInicio, end: zoomFinal).animate(
      CurvedAnimation(parent: _cameraController, curve: Curves.easeOutCubic),
    );

    if (_cameraListener != null) {
      _cameraController.removeListener(_cameraListener!);
    }

    void listener() {
      if (!mounted) return;
      _mapController.move(posAnim.value, zoomAnim.value);
      _ultimoZoom = zoomAnim.value;
    }

    _cameraListener = listener;
    _cameraController
      ..stop()
      ..addListener(listener)
      ..forward(from: 0);
  }

  void _actualizarSeguimiento(List<_OperadorActivo> operadores) {
    if (!_seguirOperador || operadores.isEmpty) return;

    _operadorSeleccionadoId ??= operadores.first.id;
    final seleccionado = operadores
        .where((o) => o.id == _operadorSeleccionadoId)
        .cast<_OperadorActivo?>()
        .firstWhere((o) => o != null, orElse: () => null);

    final objetivo = seleccionado?.posicion ?? operadores.first.posicion;
    if (_ultimaPosicionSeguida != null &&
        _mismaPosicion(_ultimaPosicionSeguida!, objetivo)) {
      return;
    }

    _ultimaPosicionSeguida = objetivo;
    _animarCamara(objetivo, zoom: (_ultimoZoom < 15.2 ? 15.2 : _ultimoZoom));
  }

  String _firmaOperadores(List<_OperadorActivo> operadores) {
    final ordenados = [...operadores]..sort((a, b) => a.id.compareTo(b.id));
    return ordenados
        .map((o) => '${o.id}:${o.posicion.latitude}:${o.posicion.longitude}')
        .join('|');
  }

  LatLng? _extractPosition(Map<String, dynamic> data) {
    final dynamic fromGeoPoint =
        data['ubicacion'] ?? data['ubicacion_actual'] ?? data['posicion'];
    if (fromGeoPoint is GeoPoint) {
      return LatLng(fromGeoPoint.latitude, fromGeoPoint.longitude);
    }

    double? parse(dynamic v) {
      if (v == null) return null;
      if (v is num) return v.toDouble();
      if (v is String) return double.tryParse(v.trim());
      return null;
    }

    final lat = parse(
      data['latitud'] ?? data['latitude'] ?? data['lat'] ?? data['y'],
    );
    final lng = parse(
      data['longitud'] ??
          data['longitude'] ??
          data['lng'] ??
          data['lon'] ??
          data['x'],
    );

    if (lat == null || lng == null) return null;
    if (lat.abs() > 90 || lng.abs() > 180) return null;
    return LatLng(lat, lng);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: _bg,
      appBar: AppBar(
        title: const Text(
          'Mapa General de Operadores',
          style: TextStyle(fontWeight: FontWeight.w700, letterSpacing: 0.2),
        ),
        backgroundColor: Colors.transparent,
        foregroundColor: Colors.white,
        elevation: 0,
        flexibleSpace: Container(
          decoration: BoxDecoration(
            gradient: const LinearGradient(
              colors: [_primary, _surface],
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
          Positioned.fill(
            child: DecoratedBox(
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  colors: [const Color(0xFF0B1020), const Color(0xFF121A2C)],
                  begin: Alignment.topCenter,
                  end: Alignment.bottomCenter,
                ),
              ),
            ),
          ),
          StreamBuilder<QuerySnapshot<Map<String, dynamic>>>(
            stream: FirebaseFirestore.instance
                .collection('usuarios')
                .where('gps_activo', isEqualTo: true)
                .snapshots(),
            builder: (context, snapshot) {
              final isLoading =
                  snapshot.connectionState == ConnectionState.waiting;
              final hasError = snapshot.hasError;
              final docs = snapshot.data?.docs ?? [];
              final operadores = <_OperadorActivo>[];
              final tracked = <Map<String, String>>[];

              for (final doc in docs) {
                final data = doc.data();
                final position = _extractPosition(data);
                if (position == null) continue;

                final nombre =
                    data['nombre']?.toString().trim().isNotEmpty == true
                    ? data['nombre'].toString().trim()
                    : 'Sin nombre';
                final camion = data['camion_actual']?.toString().trim() ?? '';
                final direccion = data['direccion']?.toString().trim() ?? '';

                tracked.add({
                  'id': doc.id,
                  'nombre': nombre,
                  'camion': camion.isEmpty ? 'Sin camión asignado' : camion,
                  'direccion': direccion.isEmpty
                      ? 'Ubicación no disponible'
                      : direccion,
                });

                operadores.add(
                  _OperadorActivo(
                    id: doc.id,
                    nombre: nombre,
                    posicion: position,
                    color: _colorOperador(doc.id),
                  ),
                );
              }

              final idsActivos = operadores.map((o) => o.id).toSet();
              _eliminarOperadoresInactivos(idsActivos);
              for (final operador in operadores) {
                _sincronizarAnimacionOperador(operador.id, operador.posicion);
              }

              final markers = operadores
                  .map((operador) {
                    final posicionAnimada =
                        _operadorAnimaciones[operador.id]?.posicionActual ??
                        operador.posicion;
                    final estado = _operadorAnimaciones[operador.id];
                    return Marker(
                      point: posicionAnimada,
                      width: 146,
                      height: 96,
                      alignment: Alignment.topCenter,
                      child: AnimatedTruckMarker(
                        operadorNombre: operador.nombre,
                        color: operador.color,
                        bearing: estado?.bearing ?? 0,
                        enMovimiento: estado?.enMovimiento ?? false,
                      ),
                    );
                  })
                  .toList(growable: false);

              final trailPolylines = operadores
                  .map((operador) {
                    final estado = _operadorAnimaciones[operador.id];
                    final trail = <LatLng>[...?estado?.trail];
                    final current = estado?.posicionActual ?? operador.posicion;
                    if (trail.isEmpty || !_mismaPosicion(trail.last, current)) {
                      trail.add(current);
                    }
                    if (trail.length < 2) return null;
                    return Polyline(
                      points: trail,
                      strokeWidth: 5,
                      color: operador.color.withValues(alpha: 0.42),
                    );
                  })
                  .whereType<Polyline>()
                  .toList(growable: false);

              LatLng center = _fallbackCenter;
              if (operadores.isNotEmpty) {
                final latAvg =
                    operadores
                        .map((o) => o.posicion.latitude)
                        .reduce((a, b) => a + b) /
                    operadores.length;
                final lngAvg =
                    operadores
                        .map((o) => o.posicion.longitude)
                        .reduce((a, b) => a + b) /
                    operadores.length;
                center = LatLng(latAvg, lngAvg);
              }

              final firma = _firmaOperadores(operadores);
              if (firma != _ultimaFirmaSnapshot) {
                _ultimaFirmaSnapshot = firma;
                if (!_seguirOperador) {
                  _centrarMapa(center, hayOperadores: operadores.isNotEmpty);
                }
              }

              _actualizarSeguimiento(operadores);

              final child = Column(
                children: [
                  AnimatedOpacity(
                    opacity: _contentVisible ? 1 : 0,
                    duration: const Duration(milliseconds: 600),
                    child: Padding(
                      padding: const EdgeInsets.fromLTRB(16, 16, 16, 10),
                      child: Container(
                        padding: const EdgeInsets.all(14),
                        decoration: BoxDecoration(
                          color: _surface.withOpacity(0.82),
                          borderRadius: BorderRadius.circular(14),
                          border: Border.all(color: _accent.withOpacity(0.28)),
                          boxShadow: [
                            BoxShadow(
                              color: Colors.black.withOpacity(0.22),
                              blurRadius: 12,
                              offset: const Offset(0, 4),
                            ),
                          ],
                        ),
                        child: Row(
                          children: [
                            Container(
                              padding: const EdgeInsets.all(8),
                              decoration: BoxDecoration(
                                color: _accent.withOpacity(0.16),
                                borderRadius: BorderRadius.circular(10),
                              ),
                              child: const Icon(
                                Icons.near_me_rounded,
                                color: Color(0xFFCBD5E1),
                                size: 20,
                              ),
                            ),
                            const SizedBox(width: 10),
                            Expanded(
                              child: Text(
                                'Seguimiento en tiempo real • ${markers.length} operadores con GPS activo',
                                style: const TextStyle(
                                  color: _textPrimary,
                                  fontWeight: FontWeight.w700,
                                  fontSize: 12.5,
                                ),
                              ),
                            ),
                            IconButton(
                              onPressed: () {
                                setState(() {
                                  _seguirOperador = !_seguirOperador;
                                  if (_seguirOperador &&
                                      _operadorSeleccionadoId == null &&
                                      operadores.isNotEmpty) {
                                    _operadorSeleccionadoId =
                                        operadores.first.id;
                                  }
                                  if (!_seguirOperador) {
                                    _ultimaPosicionSeguida = null;
                                  }
                                });
                              },
                              icon: Icon(
                                _seguirOperador
                                    ? Icons.location_searching_rounded
                                    : Icons.location_disabled_rounded,
                              ),
                              color: _seguirOperador ? _success : _textPrimary,
                              tooltip: _seguirOperador
                                  ? 'Desactivar seguimiento'
                                  : 'Seguir operador seleccionado',
                            ),
                            IconButton(
                              onPressed: () => _centrarMapa(
                                center,
                                hayOperadores: markers.isNotEmpty,
                              ),
                              icon: const Icon(
                                Icons.center_focus_strong_rounded,
                              ),
                              color: _textPrimary,
                              tooltip: 'Centrar mapa',
                            ),
                          ],
                        ),
                      ),
                    ),
                  ),
                  Expanded(
                    child: Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 16),
                      child: ClipRRect(
                        borderRadius: BorderRadius.circular(20),
                        child: DecoratedBox(
                          decoration: BoxDecoration(
                            border: Border.all(
                              color: const Color(0xFF374151),
                              width: 1,
                            ),
                            boxShadow: [
                              BoxShadow(
                                color: Colors.black.withOpacity(0.22),
                                blurRadius: 10,
                                offset: const Offset(0, 3),
                              ),
                            ],
                          ),
                          child: FlutterMap(
                            mapController: _mapController,
                           
                            options: MapOptions(
                              initialCenter: _fallbackCenter,
                              initialZoom: 14.6,
                              minZoom: 5,
                              maxZoom: 18,
                              onPositionChanged: (position, hasGesture) {
                                final z = position.zoom;
                                if (z != null) {
                                  _ultimoZoom = z;
                                }
                              },
                            ),
                            children: [
                              TileLayer(
                                urlTemplate: _tileUrl,
                                userAgentPackageName:
                                    'com.recicladora.guadalajara',
                                subdomains: const ['a', 'b', 'c'],

                                tileDisplay: const TileDisplay.fadeIn(
                                  duration: Duration(milliseconds: 180),
                                ),
                              ),
                              PolylineLayer(polylines: trailPolylines),
                              RichAttributionWidget(
                                attributions: [
                                  TextSourceAttribution(
                                    '© OpenStreetMap contributors',
                                  ),
                                ],
                              ),
                              MarkerLayer(markers: markers),
                            ],
                          ),
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(height: 10),
                  SizedBox(
                    height: 150,
                    child: ListView.separated(
                      padding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
                      scrollDirection: Axis.horizontal,
                      itemCount: tracked.length,
                      separatorBuilder: (_, __) => const SizedBox(width: 10),
                      itemBuilder: (context, index) {
                        final item = tracked[index];
                        final itemId = item['id'];
                        final seleccionado = itemId == _operadorSeleccionadoId;
                        return Container(
                          width: 270,
                          padding: const EdgeInsets.all(12),
                          decoration: BoxDecoration(
                            gradient: LinearGradient(
                              colors: [_surface, _surfaceSoft],
                              begin: Alignment.topLeft,
                              end: Alignment.bottomRight,
                            ),
                            borderRadius: BorderRadius.circular(14),
                            border: Border.all(
                              color: seleccionado
                                  ? _success.withOpacity(0.75)
                                  : const Color(0xFF374151),
                              width: seleccionado ? 1.8 : 1,
                            ),
                          ),
                          child: InkWell(
                            borderRadius: BorderRadius.circular(12),
                            onTap: () {
                              setState(() {
                                _operadorSeleccionadoId = itemId;
                                _seguirOperador = true;
                                _ultimaPosicionSeguida = null;
                              });
                            },
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Row(
                                  children: [
                                    Expanded(
                                      child: Text(
                                        item['nombre'] ?? 'Sin nombre',
                                        style: const TextStyle(
                                          color: _textPrimary,
                                          fontWeight: FontWeight.w700,
                                          fontSize: 13.5,
                                        ),
                                      ),
                                    ),
                                    if (seleccionado)
                                      Container(
                                        padding: const EdgeInsets.symmetric(
                                          horizontal: 8,
                                          vertical: 3,
                                        ),
                                        decoration: BoxDecoration(
                                          color: _success.withOpacity(0.18),
                                          borderRadius: BorderRadius.circular(
                                            999,
                                          ),
                                        ),
                                        child: const Text(
                                          'Siguiendo',
                                          style: TextStyle(
                                            color: _success,
                                            fontSize: 10.5,
                                            fontWeight: FontWeight.w700,
                                          ),
                                        ),
                                      ),
                                  ],
                                ),
                                const SizedBox(height: 6),
                                Text(
                                  item['camion'] ?? 'Sin camión asignado',
                                  maxLines: 1,
                                  overflow: TextOverflow.ellipsis,
                                  style: TextStyle(
                                    color: _textPrimary,
                                    fontWeight: FontWeight.w600,
                                    fontSize: 12,
                                  ),
                                ),
                                const SizedBox(height: 6),
                                const Text(
                                  'Toca para seguir en tiempo real',
                                  maxLines: 1,
                                  overflow: TextOverflow.ellipsis,
                                  style: TextStyle(
                                    color: _textMuted,
                                    fontSize: 10.5,
                                    fontWeight: FontWeight.w600,
                                  ),
                                ),
                                const SizedBox(height: 4),
                                Text(
                                  item['direccion'] ??
                                      'Ubicación no disponible',
                                  maxLines: 2,
                                  overflow: TextOverflow.ellipsis,
                                  style: const TextStyle(
                                    color: _textMuted,
                                    fontSize: 11.5,
                                    height: 1.2,
                                  ),
                                ),
                              ],
                            ),
                          ),
                        );
                      },
                    ),
                  ),
                ],
              );

              return Stack(
                children: [
                  child,
                  if (hasError)
                    Positioned.fill(
                      child: Container(
                        color: Colors.black.withOpacity(0.35),
                        child: const Center(
                          child: Text(
                            'Error cargando posiciones de operadores',
                            style: TextStyle(color: Colors.white),
                          ),
                        ),
                      ),
                    ),
                  if (isLoading)
                    Positioned.fill(
                      child: Container(
                        color: Colors.black.withOpacity(0.18),
                        child: const Center(
                          child: CircularProgressIndicator(color: _accent),
                        ),
                      ),
                    ),
                ],
              );
            },
          ),
        ],
      ),
    );
  }
}

class AnimatedTruckMarker extends StatelessWidget {
  final String operadorNombre;
  final Color color;
  final double bearing;
  final bool enMovimiento;

  const AnimatedTruckMarker({
    super.key,
    required this.operadorNombre,
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
        const SizedBox(height: 2),
        Container(
          constraints: const BoxConstraints(maxWidth: 120),
          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
          decoration: BoxDecoration(
            color: const Color(0xFF111827).withValues(alpha: 0.9),
            borderRadius: BorderRadius.circular(10),
            border: Border.all(color: const Color(0xFF475569)),
          ),
          child: Text(
            operadorNombre,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            textAlign: TextAlign.center,
            style: const TextStyle(
              fontSize: 10.5,
              fontWeight: FontWeight.w700,
              color: Color(0xFFE5E7EB),
            ),
          ),
        ),
      ],
    );
  }
}

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
  LatLng posicionActual;
  LatLng objetivo;
  List<LatLng> trail;
  VoidCallback? listener;
  bool enMovimiento;
  double bearing;
  int version;

  _OperadorAnimacion({
    required this.controller,
    required this.posicionActual,
    required this.objetivo,
    required this.trail,
    this.enMovimiento = false,
    this.bearing = 0,
    this.version = 0,
  });
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
  late final AnimationController _pulseController;

  @override
  void initState() {
    super.initState();
    _pulseController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1400),
    )..repeat();
  }

  @override
  void dispose() {
    _pulseController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: _pulseController,
      builder: (context, _) {
        final t = _pulseController.value;
        final pulse = widget.enMovimiento ? (0.78 + (t * 0.48)) : 0.82;
        final opacity = widget.enMovimiento ? (0.24 * (1 - t)) : 0.1;

        return Stack(
          alignment: Alignment.center,
          children: [
            Container(
              width: 36 * pulse,
              height: 36 * pulse,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: widget.color.withValues(alpha: opacity),
              ),
            ),
            Container(
              width: 35,
              height: 35,
              decoration: BoxDecoration(
                color: const Color(0xFF0F172A),
                shape: BoxShape.circle,
                border: Border.all(color: const Color(0xFF94A3B8), width: 2),
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withValues(alpha: 0.35),
                    blurRadius: 12,
                    offset: const Offset(0, 3),
                  ),
                ],
              ),
              child: Transform.rotate(
                angle: widget.bearing * (3.141592653589793 / 180),
                child: Icon(
                  Icons.local_shipping_rounded,
                  size: 18,
                  color: const Color(0xFFE5E7EB),
                ),
              ),
            ),
          ],
        );
      },
    );
  }
}

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
