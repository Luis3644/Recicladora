import 'package:flutter/material.dart';

class OperadorScreen extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: Text("Panel Operador")),
      body: Center(
        child: Text(
          "Bienvenido Operador 👷",
          style: TextStyle(fontSize: 22),
        ),
      ),
    );
  }
}