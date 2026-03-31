import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'operador_screen.dart';
import 'widgets_conexion/connection_wrapper.dart';
import 'widgets/menu_lateral.dart';

class JornadaScreen extends StatefulWidget {
  

  final String operador;
  final String camion;
  final String placas;
  

  const JornadaScreen({
    super.key,
    required this.operador,
    required this.camion,
    required this.placas,
 
  });

  @override
  State<JornadaScreen> createState() => _JornadaScreenState();
}

class _JornadaScreenState extends State<JornadaScreen> {
  final TextEditingController toneladasController = TextEditingController();
  final TextEditingController gasolinaController = TextEditingController();
  bool _contentVisible = false;

  static const Color _primary = Color(0xFF0F172A);
  static const Color _accent = Color(0xFF06B6D4);
  static const Color _success = Color(0xFF10B981);
  static const Color _danger = Color(0xFFDC2626);

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
    toneladasController.dispose();
    gasolinaController.dispose();
    super.dispose();
  }



  Future<void> guardarRegistro() async {

    if (toneladasController.text.isEmpty || gasolinaController.text.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text("Completa todos los campos")),
      );
      return;
    }

    await FirebaseFirestore.instance.collection("jornadas").add({
      "operador": widget.operador,
      "camion": widget.camion,
      "placas": widget.placas,
      "toneladas": toneladasController.text,
      "gasolina": gasolinaController.text,
      "fecha": DateTime.now()
    });

    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text("Registro guardado")),
    );

    toneladasController.clear();
    gasolinaController.clear();
  }

  Future<void> finalizarJornada() async {

    /// liberar camion
    var snapshot = await FirebaseFirestore.instance
        .collection("camiones")
        .where("operador", isEqualTo: widget.operador)
        .get();

    for (var doc in snapshot.docs) {
      await doc.reference.update({
        "ocupado": false,
        "operador": ""
      });
    }

    /// cerrar jornada del operador
    await FirebaseFirestore.instance
        .collection("usuarios")
        .doc(widget.operador)
        .update({
      "jornada_activa": false,
      "camion_actual": "",
      "placas_actuales": "",
    });

    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text("Jornada finalizada")),
    );

    Navigator.pushAndRemoveUntil(
      context,
      MaterialPageRoute(
        builder: (_) => OperadorScreen(
          nombreUsuario: widget.operador,
        ),
      ),
      (route) => false,
    );
  }

  @override
  Widget build(BuildContext context) {
    return ConnectionWrapper(
      child: Scaffold(
        backgroundColor: const Color(0xFFF0F9FF),
        appBar: AppBar(
          elevation: 0,
          foregroundColor: Colors.white,
          title: const Text(
            "Jornada activa",
            style: TextStyle(fontWeight: FontWeight.w700, letterSpacing: 0.3),
          ),
          backgroundColor: Colors.transparent,
          flexibleSpace: Container(
            decoration: const BoxDecoration(
              gradient: LinearGradient(
                colors: [_primary, Color(0xFF1E293B)],
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
              ),
            ),
          ),
        ),
        drawer: MenuLateral(
          nombreUsuario: widget.operador,
          camion: widget.camion,
          placas: widget.placas,
        ),
        body: Stack(
          children: [
            Positioned(
              top: -120,
              right: -80,
              child: Container(
                width: 280,
                height: 280,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  color: _accent.withValues(alpha: 0.08),
                ),
              ),
            ),
            Positioned(
              bottom: -90,
              left: -70,
              child: Container(
                width: 220,
                height: 220,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  color: _success.withValues(alpha: 0.08),
                ),
              ),
            ),
            AnimatedOpacity(
              duration: const Duration(milliseconds: 550),
              opacity: _contentVisible ? 1 : 0,
              child: AnimatedSlide(
                duration: const Duration(milliseconds: 550),
                offset: _contentVisible ? Offset.zero : const Offset(0, 0.05),
                curve: Curves.easeOutCubic,
                child: SingleChildScrollView(
                  padding: const EdgeInsets.all(20),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      Container(
                        padding: const EdgeInsets.all(18),
                        decoration: BoxDecoration(
                          borderRadius: BorderRadius.circular(20),
                          gradient: LinearGradient(
                            colors: [
                              _accent.withValues(alpha: 0.16),
                              _success.withValues(alpha: 0.08),
                            ],
                            begin: Alignment.topLeft,
                            end: Alignment.bottomRight,
                          ),
                          border: Border.all(
                            color: _accent.withValues(alpha: 0.24),
                          ),
                          boxShadow: [
                            BoxShadow(
                              color: _primary.withValues(alpha: 0.08),
                              blurRadius: 20,
                              offset: const Offset(0, 8),
                            ),
                          ],
                        ),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Row(
                              children: [
                                Container(
                                  padding: const EdgeInsets.all(10),
                                  decoration: BoxDecoration(
                                    color: Colors.white.withValues(alpha: 0.55),
                                    borderRadius: BorderRadius.circular(12),
                                  ),
                                  child: const Icon(
                                    Icons.route_rounded,
                                    color: _primary,
                                  ),
                                ),
                                const SizedBox(width: 10),
                                const Expanded(
                                  child: Text(
                                    "Datos de Jornada",
                                    style: TextStyle(
                                      fontSize: 18,
                                      fontWeight: FontWeight.w700,
                                      color: _primary,
                                    ),
                                  ),
                                ),
                              ],
                            ),
                            const SizedBox(height: 14),
                            Text(
                              "Operador: ${widget.operador}",
                              style: const TextStyle(
                                fontSize: 18,
                                fontWeight: FontWeight.w600,
                                color: _primary,
                              ),
                            ),
                            const SizedBox(height: 6),
                            Text(
                              "Camión: ${widget.camion}",
                              style: const TextStyle(
                                fontSize: 17,
                                fontWeight: FontWeight.w600,
                                color: _primary,
                              ),
                            ),
                            const SizedBox(height: 4),
                            Text(
                              "Placas: ${widget.placas}",
                              style: TextStyle(
                                fontSize: 15,
                                color: Colors.blueGrey[800],
                              ),
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(height: 22),
                      Container(
                        padding: const EdgeInsets.all(18),
                        decoration: BoxDecoration(
                          color: Colors.white,
                          borderRadius: BorderRadius.circular(18),
                          border: Border.all(color: _primary.withValues(alpha: 0.08)),
                          boxShadow: [
                            BoxShadow(
                              color: _primary.withValues(alpha: 0.06),
                              blurRadius: 14,
                              offset: const Offset(0, 6),
                            ),
                          ],
                        ),
                        child: Column(
                          children: [
                            TextField(
                              controller: toneladasController,
                              keyboardType: TextInputType.number,
                              decoration: InputDecoration(
                                labelText: "Toneladas cargadas",
                                prefixIcon: const Icon(Icons.scale_rounded),
                                filled: true,
                                fillColor: const Color(0xFFF8FAFC),
                                border: OutlineInputBorder(
                                  borderRadius: BorderRadius.circular(14),
                                ),
                              ),
                            ),
                            const SizedBox(height: 14),
                            TextField(
                              controller: gasolinaController,
                              keyboardType: TextInputType.number,
                              decoration: InputDecoration(
                                labelText: "Gasolina usada",
                                prefixIcon: const Icon(Icons.local_gas_station_rounded),
                                filled: true,
                                fillColor: const Color(0xFFF8FAFC),
                                border: OutlineInputBorder(
                                  borderRadius: BorderRadius.circular(14),
                                ),
                              ),
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(height: 24),
                      LayoutBuilder(
                        builder: (context, constraints) {
                          final isNarrow = constraints.maxWidth < 420;
                          if (isNarrow) {
                            return Column(
                              crossAxisAlignment: CrossAxisAlignment.stretch,
                              children: [
                                ElevatedButton.icon(
                                  style: ElevatedButton.styleFrom(
                                    backgroundColor: _success,
                                    foregroundColor: Colors.white,
                                    padding: const EdgeInsets.symmetric(vertical: 14),
                                    shape: RoundedRectangleBorder(
                                      borderRadius: BorderRadius.circular(14),
                                    ),
                                  ),
                                  onPressed: guardarRegistro,
                                  icon: const Icon(Icons.save_rounded),
                                  label: const Text("Guardar registro"),
                                ),
                                const SizedBox(height: 12),
                                ElevatedButton.icon(
                                  style: ElevatedButton.styleFrom(
                                    backgroundColor: _danger,
                                    foregroundColor: Colors.white,
                                    padding: const EdgeInsets.symmetric(vertical: 14),
                                    shape: RoundedRectangleBorder(
                                      borderRadius: BorderRadius.circular(14),
                                    ),
                                  ),
                                  onPressed: finalizarJornada,
                                  icon: const Icon(Icons.logout_rounded),
                                  label: const Text("Finalizar jornada"),
                                ),
                              ],
                            );
                          }

                          return Row(
                            children: [
                              Expanded(
                                child: ElevatedButton.icon(
                                  style: ElevatedButton.styleFrom(
                                    backgroundColor: _success,
                                    foregroundColor: Colors.white,
                                    padding: const EdgeInsets.symmetric(vertical: 14),
                                    shape: RoundedRectangleBorder(
                                      borderRadius: BorderRadius.circular(14),
                                    ),
                                  ),
                                  onPressed: guardarRegistro,
                                  icon: const Icon(Icons.save_rounded),
                                  label: const Text("Guardar registro"),
                                ),
                              ),
                              const SizedBox(width: 12),
                              Expanded(
                                child: ElevatedButton.icon(
                                  style: ElevatedButton.styleFrom(
                                    backgroundColor: _danger,
                                    foregroundColor: Colors.white,
                                    padding: const EdgeInsets.symmetric(vertical: 14),
                                    shape: RoundedRectangleBorder(
                                      borderRadius: BorderRadius.circular(14),
                                    ),
                                  ),
                                  onPressed: finalizarJornada,
                                  icon: const Icon(Icons.logout_rounded),
                                  label: const Text("Finalizar jornada"),
                                ),
                              ),
                            ],
                          );
                        },
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}