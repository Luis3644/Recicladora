import 'dart:async';
import 'dart:io';
import 'package:connectivity_plus/connectivity_plus.dart';
import 'package:flutter/material.dart';
import 'pantalla_sin_conexion.dart';

class ConnectionWrapper extends StatefulWidget {
  final Widget child;
  const ConnectionWrapper({super.key, required this.child});

  @override
  State<ConnectionWrapper> createState() => _ConnectionWrapperState();
}

class _ConnectionWrapperState extends State<ConnectionWrapper> {
  bool? _tieneInternet; // null = verificando
  late StreamSubscription<List<ConnectivityResult>> _sub;

  @override
  void initState() {
    super.initState();
    _verificar();
    _sub = Connectivity().onConnectivityChanged.listen((_) => _verificar());
  }

  @override
  void dispose() {
    _sub.cancel();
    super.dispose();
  }

  Future<void> _verificar() async {
    try {
      final result = await InternetAddress.lookup('8.8.8.8')
          .timeout(const Duration(seconds: 4));
      if (mounted) {
        setState(() =>
            _tieneInternet = result.isNotEmpty && result[0].rawAddress.isNotEmpty);
      }
    } catch (_) {
      if (mounted) setState(() => _tieneInternet = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    if (_tieneInternet == null) {
      return const Scaffold(body: Center(child: CircularProgressIndicator()));
    }
    if (!_tieneInternet!) {
      return PantallaSinConexion(onReintentar: _verificar);
    }
    return widget.child;
  }
}