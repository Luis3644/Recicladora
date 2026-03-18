import 'dart:async';
import 'package:connectivity_plus/connectivity_plus.dart';
import 'package:flutter/material.dart';
import 'pantalla_sin_conexion.dart'; // Importamos la pantalla que creamos arriba

class ConnectionWrapper extends StatefulWidget {
  final Widget child;
  const ConnectionWrapper({super.key, required this.child});

  @override
  State<ConnectionWrapper> createState() => _ConnectionWrapperState();
}

class _ConnectionWrapperState extends State<ConnectionWrapper> {
  // Variable para guardar el estado del internet
  bool _tieneInternet = true;
  late StreamSubscription<List<ConnectivityResult>> _subscription;

  @override
  void initState() {
    super.initState();
    // Empezamos a escuchar cambios en el internet
    _subscription = Connectivity().onConnectivityChanged.listen((List<ConnectivityResult> result) {
      setState(() {
        // Si la lista contiene 'none', es que no hay nada de internet
        _tieneInternet = !result.contains(ConnectivityResult.none);
      });
    });
  }

  @override
  void dispose() {
    _subscription.cancel(); // Cerramos el vigilante cuando no se necesite
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    // SI NO HAY INTERNET: Muestra la pantalla roja de error
    if (!_tieneInternet) {
      return const PantallaSinConexion();
    }
    // SI HAY INTERNET: Muestra la pantalla normal (Trabajador u Operador)
    return widget.child;
  }
}