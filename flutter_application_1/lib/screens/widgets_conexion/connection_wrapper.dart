import 'dart:async';
import 'dart:io';
import 'package:connectivity_plus/connectivity_plus.dart';
import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:http/http.dart' as http;
import 'package:flutter/material.dart';
import 'pantalla_sin_conexion.dart';

class ConnectionWrapper extends StatefulWidget {
  final Widget child;
  const ConnectionWrapper({super.key, required this.child});

  @override
  State<ConnectionWrapper> createState() => _ConnectionWrapperState();
}

class _ConnectionWrapperState extends State<ConnectionWrapper> {
  bool? _tieneInternet; // null = verificando por primera vez
  late StreamSubscription<List<ConnectivityResult>> _sub;
  Timer? _timerReintento;

  @override
  void initState() {
    super.initState();
    _verificar();

    // Escucha cambios de red: WiFi, datos móviles, sin conexión
    _sub = Connectivity().onConnectivityChanged.listen((results) {
      // Si el SO dice que NO hay ninguna red → sin internet inmediatamente
      if (results.isEmpty ||
          (results.length == 1 && results.first == ConnectivityResult.none)) {
        if (mounted) setState(() => _tieneInternet = false);
      } else {
        // Hay alguna interfaz de red activa → verificar conectividad real
        _verificar();
      }
    });

    // Reintento automático cada 8 segundos cuando no hay internet
    _timerReintento = Timer.periodic(const Duration(seconds: 8), (_) {
      if (_tieneInternet == false) _verificar();
    });
  }

  @override
  void dispose() {
    _sub.cancel();
    _timerReintento?.cancel();
    super.dispose();
  }

  Future<void> _verificar() async {
    // Primero revisamos si el SO tiene alguna interfaz activa
    final connectivity = await Connectivity().checkConnectivity();
    final sinRed = connectivity.isEmpty ||
        (connectivity.length == 1 &&
            connectivity.first == ConnectivityResult.none);

    if (sinRed) {
      if (mounted) setState(() => _tieneInternet = false);
      return;
    }

    // Con red activa, hacemos un ping real a múltiples servidores
    // para confirmar que hay internet (WiFi o datos móviles)
    final hayInternet = await _pingReal();
    if (mounted) setState(() => _tieneInternet = hayInternet);
  }

  /// Detecta internet según la plataforma:
  /// - Web (Chrome/Edge/Safari): HTTP GET porque Socket TCP está bloqueado
  /// - Nativo (Android/iOS/Windows): Socket TCP directo
  Future<bool> _pingReal() async {
    // ── WEB ───────────────────────────────────────────────────────────────
    if (kIsWeb) {
      const urls = [
        'https://www.google.com/generate_204',
        'https://connectivitycheck.gstatic.com/generate_204',
        'https://www.cloudflare.com/cdn-cgi/trace',
      ];
      for (final url in urls) {
        try {
          final response = await http
              .get(Uri.parse(url))
              .timeout(const Duration(seconds: 5));
          if (response.statusCode > 0) return true;
        } catch (_) {
          continue;
        }
      }
      return false;
    }

    // ── NATIVO (Android, iOS, Windows, macOS) ─────────────────────────────
    final connectivity = await Connectivity().checkConnectivity();
    final sinRed = connectivity.isEmpty ||
        (connectivity.length == 1 &&
            connectivity.first == ConnectivityResult.none);
    if (sinRed) return false;

    const hosts = [
      ('google.com',     80),
      ('cloudflare.com', 80),
      ('1.1.1.1',        53),
      ('8.8.8.8',        53),
    ];
    for (final (host, port) in hosts) {
      try {
        final socket = await Socket.connect(
          host, port,
          timeout: const Duration(seconds: 4),
        );
        socket.destroy();
        return true;
      } catch (_) {
        continue;
      }
    }
    return false;
  }

  @override
  Widget build(BuildContext context) {
    // Mientras verificamos por primera vez mostramos un indicador suave
    if (_tieneInternet == null) {
      return const Scaffold(
        body: Center(child: CircularProgressIndicator()),
      );
    }

    if (!_tieneInternet!) {
      return PantallaSinConexion(onReintentar: _verificar);
    }

    return widget.child;
  }
}