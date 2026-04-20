import 'package:flutter/material.dart';

class PantallaSinConexion extends StatefulWidget {
  final Future<void> Function()? onReintentar;

  const PantallaSinConexion({super.key, this.onReintentar});

  @override
  State<PantallaSinConexion> createState() => _PantallaSinConexionState();
}

class _PantallaSinConexionState extends State<PantallaSinConexion> {
  bool _verificando = false;

  Future<void> _reintentar() async {
    if (widget.onReintentar == null) return;
    setState(() => _verificando = true);
    await widget.onReintentar!();
    if (mounted) setState(() => _verificando = false);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFFFF5F5),
      body: Center(
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 36),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              // Ícono animado
              Container(
                padding: const EdgeInsets.all(28),
                decoration: BoxDecoration(
                  color: Colors.redAccent.withOpacity(0.1),
                  shape: BoxShape.circle,
                ),
                child: const Icon(
                  Icons.signal_wifi_off_rounded,
                  size: 80,
                  color: Colors.redAccent,
                ),
              ),
              const SizedBox(height: 28),

              const Text(
                'Sin conexión a Internet',
                style: TextStyle(
                  fontSize: 22,
                  fontWeight: FontWeight.w800,
                  color: Color(0xFF1E293B),
                ),
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 12),

              const Text(
                'Necesitas internet para registrar datos de logística.\n'
                'Revisa tu señal WiFi o datos móviles e intenta de nuevo.',
                textAlign: TextAlign.center,
                style: TextStyle(
                  fontSize: 15,
                  color: Color(0xFF64748B),
                  height: 1.5,
                ),
              ),
              const SizedBox(height: 36),

              // Botón de reintentar
              SizedBox(
                width: double.infinity,
                child: ElevatedButton.icon(
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Colors.redAccent,
                    foregroundColor: Colors.white,
                    padding: const EdgeInsets.symmetric(vertical: 14),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(14),
                    ),
                    elevation: 2,
                  ),
                  onPressed: _verificando ? null : _reintentar,
                  icon: _verificando
                      ? const SizedBox(
                          width: 18,
                          height: 18,
                          child: CircularProgressIndicator(
                            color: Colors.white,
                            strokeWidth: 2.5,
                          ),
                        )
                      : const Icon(Icons.refresh_rounded),
                  label: Text(
                    _verificando ? 'Verificando...' : 'Reintentar conexión',
                    style: const TextStyle(
                      fontSize: 15,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                ),
              ),

              const SizedBox(height: 20),

              // Indicador automático
              if (!_verificando)
                Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    const SizedBox(
                      width: 14,
                      height: 14,
                      child: CircularProgressIndicator(
                        color: Colors.redAccent,
                        strokeWidth: 2,
                      ),
                    ),
                    const SizedBox(width: 10),
                    Text(
                      'Buscando señal automáticamente...',
                      style: TextStyle(
                        fontSize: 12,
                        color: Colors.grey[500],
                        fontStyle: FontStyle.italic,
                      ),
                    ),
                  ],
                ),
            ],
          ),
        ),
      ),
    );
  }
}