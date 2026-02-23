import 'package:flutter/material.dart';

class AdminScreen extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: Text("Panel Administrador")),
      body: Center(
        child: Text(
          "Bienvenido ADMIN 👑",
          style: TextStyle(fontSize: 22),
        ),
      ),
    );
  }
}