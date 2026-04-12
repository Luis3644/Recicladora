import 'package:flutter/material.dart';

class ReporteToneladasCamionesScreen extends StatelessWidget {
  const ReporteToneladasCamionesScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF4F7FB),
      appBar: AppBar(
        title: const Text(
          'Reporte de Toneladas de Camiones',
          style: TextStyle(fontWeight: FontWeight.w700),
        ),
        backgroundColor: const Color(0xFF0F766E),
        foregroundColor: Colors.white,
      ),
      body: Center(
        child: Container(
          margin: const EdgeInsets.all(24),
          padding: const EdgeInsets.all(20),
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(16),
            border: Border.all(color: const Color(0xFFCBD5E1)),
          ),
          child: const Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(
                Icons.local_shipping_outlined,
                size: 48,
                color: Color(0xFF0F766E),
              ),
              SizedBox(height: 12),
              Text(
                'Apartado listo',
                style: TextStyle(
                  fontWeight: FontWeight.w700,
                  fontSize: 18,
                  color: Color(0xFF0F172A),
                ),
              ),
              SizedBox(height: 8),
              Text(
                'Aqui se agregara el reporte de toneladas de carga\ncuando nos compartas los campos y calculos.',
                textAlign: TextAlign.center,
                style: TextStyle(color: Color(0xFF475569)),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
