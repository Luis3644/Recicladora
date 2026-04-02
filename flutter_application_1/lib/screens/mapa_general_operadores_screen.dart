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
  static const Color _primary = Color(0xFF0F172A);
  static const Color _accent = Color(0xFF06B6D4);
  static const Color _success = Color(0xFF10B981);
  static const Color _bg = Color(0xFFF0F9FF);
  static const LatLng _fallbackCenter = LatLng(18.7451879, -98.9083418);

  final MapController _mapController = MapController();
  final Map<String, _OperadorAnimacion> _operadorAnimaciones = {};
  bool _contentVisible = false;
  String _ultimaFirmaSnapshot = '';

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      setState(() => _contentVisible = true);
    });
  }

  @override
  void dispose() {
    for (final animacion in _operadorAnimaciones.values) {
      animacion.controller.dispose();
    }
    super.dispose();
  }

  Color _colorOperador(String operadorId) {
    const palette = [
      Color(0xFF0EA5E9),
      Color(0xFF10B981),
      Color(0xFFF59E0B),
      Color(0xFFEF4444),
      Color(0xFF6366F1),
      Color(0xFF14B8A6),
      Color(0xFFF97316),
      Color(0xFF8B5CF6),
    ];
    return palette[operadorId.hashCode.abs() % palette.length];
  }

  bool _mismaPosicion(LatLng a, LatLng b) {
    const epsilon = 0.000001;
    return (a.latitude - b.latitude).abs() < epsilon &&
        (a.longitude - b.longitude).abs() < epsilon;
  }

  void _sincronizarAnimacionOperador(String operadorId, LatLng nuevaPosicion) {
    final existente = _operadorAnimaciones[operadorId];
    if (existente == null) {
      final controller = AnimationController(
        duration: const Duration(milliseconds: 600),
        vsync: this,
      );
      _operadorAnimaciones[operadorId] = _OperadorAnimacion(
        controller: controller,
        posicionActual: nuevaPosicion,
        objetivo: nuevaPosicion,
      );
      return;
    }

    if (_mismaPosicion(existente.objetivo, nuevaPosicion)) return;

    existente.objetivo = nuevaPosicion;
    final animation =
        _LatLngTween(
          begin: existente.posicionActual,
          end: nuevaPosicion,
        ).animate(
          CurvedAnimation(
            parent: existente.controller,
            curve: Curves.easeInOut,
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
      ..forward(from: 0);
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
      _mapController.move(centro, hayOperadores ? 13.2 : 14.6);
    });
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
              colors: [_primary, Color(0xFF1E293B)],
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
          Positioned(
            top: -90,
            right: -70,
            child: Container(
              width: 260,
              height: 260,
              decoration: BoxDecoration(
                color: _accent.withOpacity(0.1),
                shape: BoxShape.circle,
              ),
            ),
          ),
          Positioned(
            bottom: -100,
            left: -70,
            child: Container(
              width: 240,
              height: 240,
              decoration: BoxDecoration(
                color: _success.withOpacity(0.08),
                shape: BoxShape.circle,
              ),
            ),
          ),
          StreamBuilder<QuerySnapshot<Map<String, dynamic>>>(
            stream: FirebaseFirestore.instance
                .collection('usuarios')
                .where('gps_activo', isEqualTo: true)
                .snapshots(),
            builder: (context, snapshot) {
              if (snapshot.hasError) {
                return const Center(
                  child: Text('Error cargando posiciones de operadores'),
                );
              }
              if (snapshot.connectionState == ConnectionState.waiting) {
                return const Center(
                  child: CircularProgressIndicator(color: _accent),
                );
              }

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
                    return Marker(
                      point: posicionAnimada,
                      width: 128,
                      height: 82,
                      alignment: Alignment.topCenter,
                      child: AnimatedTruckMarker(
                        operadorNombre: operador.nombre,
                        posicion: posicionAnimada,
                        color: operador.color,
                      ),
                    );
                  })
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
                _centrarMapa(center, hayOperadores: operadores.isNotEmpty);
              }

              return Column(
                children: [
                  AnimatedOpacity(
                    opacity: _contentVisible ? 1 : 0,
                    duration: const Duration(milliseconds: 600),
                    child: Padding(
                      padding: const EdgeInsets.fromLTRB(16, 16, 16, 10),
                      child: Container(
                        padding: const EdgeInsets.all(14),
                        decoration: BoxDecoration(
                          color: Colors.white.withOpacity(0.92),
                          borderRadius: BorderRadius.circular(14),
                          border: Border.all(color: _accent.withOpacity(0.2)),
                          boxShadow: [
                            BoxShadow(
                              color: _primary.withOpacity(0.06),
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
                                color: _accent,
                                size: 20,
                              ),
                            ),
                            const SizedBox(width: 10),
                            Expanded(
                              child: Text(
                                'Seguimiento en tiempo real • ${markers.length} operadores con GPS activo',
                                style: const TextStyle(
                                  color: _primary,
                                  fontWeight: FontWeight.w700,
                                  fontSize: 12.5,
                                ),
                              ),
                            ),
                            IconButton(
                              onPressed: () => _centrarMapa(
                                center,
                                hayOperadores: markers.isNotEmpty,
                              ),
                              icon: const Icon(
                                Icons.center_focus_strong_rounded,
                              ),
                              color: _primary,
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
                              color: _accent.withOpacity(0.25),
                              width: 1.5,
                            ),
                            boxShadow: [
                              BoxShadow(
                                color: _primary.withOpacity(0.08),
                                blurRadius: 18,
                                offset: const Offset(0, 7),
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
                            ),
                            children: [
                              TileLayer(
                                urlTemplate:
                                    'https://{s}.basemaps.cartocdn.com/rastertiles/voyager/{z}/{x}/{y}{r}.png',
                                userAgentPackageName:
                                    'com.recicladora.guadalajara',
                                subdomains: const ['a', 'b', 'c', 'd'],
                              ),
                              RichAttributionWidget(
                                attributions: [
                                  TextSourceAttribution(
                                    '© OpenStreetMap contributors © CARTO',
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
                        return Container(
                          width: 270,
                          padding: const EdgeInsets.all(12),
                          decoration: BoxDecoration(
                            gradient: LinearGradient(
                              colors: [Colors.white, _accent.withOpacity(0.05)],
                              begin: Alignment.topLeft,
                              end: Alignment.bottomRight,
                            ),
                            borderRadius: BorderRadius.circular(14),
                            border: Border.all(
                              color: _accent.withOpacity(0.22),
                            ),
                          ),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                item['nombre'] ?? 'Sin nombre',
                                style: const TextStyle(
                                  color: _primary,
                                  fontWeight: FontWeight.w700,
                                  fontSize: 13.5,
                                ),
                              ),
                              const SizedBox(height: 6),
                              Text(
                                item['camion'] ?? 'Sin camión asignado',
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                                style: TextStyle(
                                  color: _success.withOpacity(0.95),
                                  fontWeight: FontWeight.w600,
                                  fontSize: 12,
                                ),
                              ),
                              const SizedBox(height: 6),
                              Text(
                                item['direccion'] ?? 'Ubicación no disponible',
                                maxLines: 2,
                                overflow: TextOverflow.ellipsis,
                                style: TextStyle(
                                  color: _primary.withOpacity(0.65),
                                  fontSize: 11.5,
                                  height: 1.2,
                                ),
                              ),
                            ],
                          ),
                        );
                      },
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
  final LatLng posicion;
  final Color color;

  const AnimatedTruckMarker({
    super.key,
    required this.operadorNombre,
    required this.posicion,
    required this.color,
  });

  @override
  Widget build(BuildContext context) {
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        Icon(Icons.local_shipping, size: 36, color: color),
        const SizedBox(height: 2),
        Container(
          constraints: const BoxConstraints(maxWidth: 120),
          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
          decoration: BoxDecoration(
            color: Colors.white.withValues(alpha: 0.78),
            borderRadius: BorderRadius.circular(10),
            border: Border.all(color: color.withValues(alpha: 0.28)),
          ),
          child: Text(
            operadorNombre,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            textAlign: TextAlign.center,
            style: const TextStyle(
              fontSize: 10.5,
              fontWeight: FontWeight.w700,
              color: _MapaGeneralOperadoresScreenState._primary,
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
  VoidCallback? listener;

  _OperadorAnimacion({
    required this.controller,
    required this.posicionActual,
    required this.objetivo,
  });
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
