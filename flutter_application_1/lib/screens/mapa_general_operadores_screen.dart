import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:latlong2/latlong.dart';

enum _MapVisualStyle { streets, light, satellite }

class MapaGeneralOperadoresScreen extends StatefulWidget {
  const MapaGeneralOperadoresScreen({super.key});

  @override
  State<MapaGeneralOperadoresScreen> createState() =>
      _MapaGeneralOperadoresScreenState();
}

class _MapaGeneralOperadoresScreenState extends State<MapaGeneralOperadoresScreen>
    with SingleTickerProviderStateMixin {
  static const Color _primary = Color(0xFF0F172A);
  static const Color _accent = Color(0xFF06B6D4);
  static const Color _success = Color(0xFF10B981);
  static const Color _bg = Color(0xFFF0F9FF);

  final MapController _mapController = MapController();
  late AnimationController _pulseController;
  bool _contentVisible = false;
  bool _autoCentered = false;
  _MapVisualStyle _mapStyle = _MapVisualStyle.streets;

  String get _tileUrlTemplate {
    switch (_mapStyle) {
      case _MapVisualStyle.streets:
        return 'https://server.arcgisonline.com/ArcGIS/rest/services/World_Street_Map/MapServer/tile/{z}/{y}/{x}';
      case _MapVisualStyle.light:
        return 'https://{s}.basemaps.cartocdn.com/light_all/{z}/{x}/{y}{r}.png';
      case _MapVisualStyle.satellite:
        return 'https://server.arcgisonline.com/ArcGIS/rest/services/World_Imagery/MapServer/tile/{z}/{y}/{x}';
    }
  }

  String get _styleLabel {
    switch (_mapStyle) {
      case _MapVisualStyle.streets:
        return 'Calles Pro';
      case _MapVisualStyle.light:
        return 'Claro';
      case _MapVisualStyle.satellite:
        return 'Satélite';
    }
  }

  String get _attributionText {
    switch (_mapStyle) {
      case _MapVisualStyle.streets:
      case _MapVisualStyle.satellite:
        return 'Tiles © Esri';
      case _MapVisualStyle.light:
        return '© OpenStreetMap contributors © CARTO';
    }
  }

  @override
  void initState() {
    super.initState();
    _pulseController = AnimationController(
      duration: const Duration(milliseconds: 1400),
      vsync: this,
    )..repeat();

    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      setState(() => _contentVisible = true);
    });
  }

  @override
  void dispose() {
    _pulseController.dispose();
    super.dispose();
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
      data['longitud'] ?? data['longitude'] ?? data['lng'] ?? data['lon'] ?? data['x'],
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
                .where('rol', isEqualTo: 'operador')
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
              final markers = <Marker>[];
              final tracked = <Map<String, String>>[];

              for (final doc in docs) {
                final data = doc.data();
                final position = _extractPosition(data);
                final nombre =
                    data['nombre']?.toString().trim().isNotEmpty == true
                        ? data['nombre'].toString().trim()
                        : 'Sin nombre';
                final camion = data['camion_actual']?.toString().trim() ?? '';
                final direccion = data['direccion']?.toString().trim() ?? '';

                tracked.add({
                  'nombre': nombre,
                  'camion': camion.isEmpty ? 'Sin camión asignado' : camion,
                  'direccion':
                      direccion.isEmpty ? 'Ubicación no disponible' : direccion,
                });

                if (position == null) continue;

                markers.add(
                  Marker(
                    point: position,
                    width: 54,
                    height: 54,
                    child: AnimatedBuilder(
                      animation: _pulseController,
                      builder: (context, child) {
                        final t = _pulseController.value;
                        final ringScale = 0.7 + (t * 0.8);
                        final ringOpacity = (1 - t).clamp(0.0, 1.0) * 0.35;
                        return Stack(
                          alignment: Alignment.center,
                          children: [
                            Transform.scale(
                              scale: ringScale,
                              child: Container(
                                width: 48,
                                height: 48,
                                decoration: BoxDecoration(
                                  shape: BoxShape.circle,
                                  color: _accent.withOpacity(ringOpacity),
                                ),
                              ),
                            ),
                            Container(
                              width: 18,
                              height: 18,
                              decoration: BoxDecoration(
                                color: _success,
                                shape: BoxShape.circle,
                                border: Border.all(color: Colors.white, width: 2.4),
                              ),
                            ),
                          ],
                        );
                      },
                    ),
                  ),
                );
              }

              LatLng center = const LatLng(19.4326, -99.1332);
              if (markers.isNotEmpty) {
                final latAvg =
                    markers.map((m) => m.point.latitude).reduce((a, b) => a + b) /
                        markers.length;
                final lngAvg =
                    markers.map((m) => m.point.longitude).reduce((a, b) => a + b) /
                        markers.length;
                center = LatLng(latAvg, lngAvg);
              }

              if (!_autoCentered && markers.isNotEmpty) {
                _autoCentered = true;
                WidgetsBinding.instance.addPostFrameCallback((_) {
                  _mapController.move(center, 13.2);
                });
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
                                'Seguimiento en tiempo real • ${markers.length} operadores con GPS • $_styleLabel',
                                style: const TextStyle(
                                  color: _primary,
                                  fontWeight: FontWeight.w700,
                                  fontSize: 12.5,
                                ),
                              ),
                            ),
                            PopupMenuButton<_MapVisualStyle>(
                              tooltip: 'Estilo de mapa',
                              icon: const Icon(Icons.layers_rounded),
                              color: Colors.white,
                              onSelected: (style) {
                                setState(() {
                                  _mapStyle = style;
                                });
                              },
                              itemBuilder: (_) => const [
                                PopupMenuItem(
                                  value: _MapVisualStyle.streets,
                                  child: Text('Calles Pro'),
                                ),
                                PopupMenuItem(
                                  value: _MapVisualStyle.light,
                                  child: Text('Claro'),
                                ),
                                PopupMenuItem(
                                  value: _MapVisualStyle.satellite,
                                  child: Text('Satélite'),
                                ),
                              ],
                            ),
                            IconButton(
                              onPressed: markers.isEmpty
                                  ? null
                                  : () => _mapController.move(center, 13.2),
                              icon: const Icon(Icons.center_focus_strong_rounded),
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
                              initialCenter: center,
                              initialZoom: 12.2,
                              minZoom: 5,
                              maxZoom: 18,
                            ),
                            children: [
                              TileLayer(
                                urlTemplate: _tileUrlTemplate,
                                userAgentPackageName: 'com.recicladora.app',
                                subdomains: _mapStyle == _MapVisualStyle.light
                                    ? const ['a', 'b', 'c', 'd']
                                    : const [],
                              ),
                              if (_mapStyle == _MapVisualStyle.satellite)
                                TileLayer(
                                  urlTemplate:
                                      'https://services.arcgisonline.com/ArcGIS/rest/services/Reference/World_Boundaries_and_Places/MapServer/tile/{z}/{y}/{x}',
                                  userAgentPackageName: 'com.recicladora.app',
                                ),
                              RichAttributionWidget(
                                attributions: [
                                  TextSourceAttribution(_attributionText),
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
                            border: Border.all(color: _accent.withOpacity(0.22)),
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
