import 'package:flutter/material.dart';

class TrabajadorScreen extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: Text("Panel del trabajador")),
      body: Center(
        child: Text(
          "Bienvenido Trabajador 👷",
          style: TextStyle(fontSize: 22),
        ),
      ),
    );
  }
}