import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'jornada_screen.dart';
import 'operador_screen.dart';

class ChecklistScreen extends StatefulWidget {
  final String nombreUsuario;
  final String camionId;
  final String camion;
  final String placas;

  const ChecklistScreen({
    super.key,
    required this.nombreUsuario,
    required this.camionId,
    required this.camion,
    required this.placas,
  });

  @override
  State<ChecklistScreen> createState() => _ChecklistScreenState();
}

class _ChecklistScreenState extends State<ChecklistScreen> {
  bool? cubrebocas, gafas, guantes, uniforme;
  final TextEditingController reporteController = TextEditingController();
  bool _guardando = false;

  static const Color _primary = Color(0xFF1E3A8A);
  static const Color _success = Color(0xFF10B981);
  static const Color _danger  = Color(0xFFDC2626);
  static const Color _warning = Color(0xFFF59E0B);

  @override
  void dispose() {
    reporteController.dispose();
    super.dispose();
  }

  Future<void> guardarChecklist() async {
    if (cubrebocas == null || gafas == null ||
        guantes == null || uniforme == null) {
      _snack('¡Faltan accesorios por marcar!', _danger);
      return;
    }

    bool faltaAlgo = cubrebocas == false || gafas == false ||
        guantes == false || uniforme == false;

    if (faltaAlgo && reporteController.text.trim().isEmpty) {
      _snack('Explica por qué te falta equipo.', _warning);
      return;
    }

    setState(() => _guardando = true);

    try {
      final db = FirebaseFirestore.instance;
      final camionRef  = db.collection('camiones').doc(widget.camionId);
      final usuarioRef = db.collection('usuarios').doc(widget.nombreUsuario);
      final ahora      = DateTime.now();

      // ── TRANSACCIÓN ATÓMICA ───────────────────────────────────────────────
      // Verifica que el camión NO esté ocupado y lo marca en un solo paso.
      // Si dos operadores llegan al mismo tiempo, solo UNO gana — el otro
      // recibe el error y ve el mensaje de camión ocupado.
      await db.runTransaction((tx) async {
        final camionSnap = await tx.get(camionRef);

        if (!camionSnap.exists) {
          throw Exception('El camión ya no existe.');
        }

        final ocupado   = camionSnap.data()?['ocupado'] == true;
        final operador  = camionSnap.data()?['operador']?.toString() ?? '';

        // Si está ocupado por OTRO operador → rechazar
        if (ocupado && operador != widget.nombreUsuario) {
          throw Exception('CAMION_OCUPADO:$operador');
        }

        // Todo bien → escribir todo en la misma transacción
        tx.update(camionRef, {
          'ocupado':  true,
          'operador': widget.nombreUsuario,
        });

        tx.set(usuarioRef, {
          'nombre':          widget.nombreUsuario,
          'jornada_activa':  true,
          'camion_id':       widget.camionId,
          'camion_actual':   widget.camion,
          'placas_actuales': widget.placas,
        }, SetOptions(merge: true));
      });

      // Guardar checklist fuera de la tx (no es crítico para atomicidad)
      await db.collection('checklist').add({
        'operador':       widget.nombreUsuario,
        'camion':         widget.camion,
        'placas':         widget.placas,
        'cubrebocas':     cubrebocas,
        'gafas':          gafas,
        'guantes':        guantes,
        'uniforme':       uniforme,
        'reporte':        reporteController.text.trim(),
        'fecha':          ahora,
        'equipo_completo': !faltaAlgo,
      });

      if (!mounted) return;
      Navigator.pushReplacement(
        context,
        MaterialPageRoute(
          builder: (_) => JornadaScreen(
            operador: widget.nombreUsuario,
            camion:   widget.camion,
            placas:   widget.placas,
          ),
        ),
      );

    } catch (e) {
      if (!mounted) return;
      final mensaje = e.toString();

      if (mensaje.contains('CAMION_OCUPADO')) {
        // Extraer nombre del operador que lo tomó (si está disponible)
        final otrOp = mensaje.split('CAMION_OCUPADO:').last.trim();
        _mostrarCamionOcupado(otrOp);
      } else {
        _snack('Error: $mensaje', _danger);
      }
    } finally {
      if (mounted) setState(() => _guardando = false);
    }
  }

  // ── Diálogo camión ocupado ────────────────────────────────────────────────
  void _mostrarCamionOcupado(String otroOperador) {
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (_) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        icon: Container(
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: _danger.withOpacity(0.1),
            shape: BoxShape.circle,
          ),
          child: const Icon(Icons.directions_bus_rounded,
              color: _danger, size: 40),
        ),
        title: const Text(
          'Camión ocupado',
          textAlign: TextAlign.center,
          style: TextStyle(fontWeight: FontWeight.w800, fontSize: 18),
        ),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(
              'El camión ${widget.camion} (${widget.placas}) '
              'acaba de ser tomado por otro operador.',
              textAlign: TextAlign.center,
              style: const TextStyle(fontSize: 14, height: 1.5),
            ),
            if (otroOperador.isNotEmpty &&
                otroOperador != 'Exception') ...[
              const SizedBox(height: 8),
              Container(
                padding: const EdgeInsets.symmetric(
                    horizontal: 14, vertical: 8),
                decoration: BoxDecoration(
                  color: _danger.withOpacity(0.08),
                  borderRadius: BorderRadius.circular(10),
                ),
                child: Text(
                  'Asignado a: $otroOperador',
                  style: TextStyle(
                    fontSize: 13,
                    fontWeight: FontWeight.w700,
                    color: _danger,
                  ),
                ),
              ),
            ],
            const SizedBox(height: 12),
            const Text(
              'Por favor regresa y selecciona otro camión disponible.',
              textAlign: TextAlign.center,
              style: TextStyle(fontSize: 13, color: Colors.grey),
            ),
          ],
        ),
        actionsAlignment: MainAxisAlignment.center,
        actions: [
          ElevatedButton.icon(
            style: ElevatedButton.styleFrom(
              backgroundColor: _primary,
              foregroundColor: Colors.white,
              shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12)),
              padding: const EdgeInsets.symmetric(
                  horizontal: 28, vertical: 12),
            ),
            onPressed: () {
              Navigator.pop(context); // cierra el dialog
              // Regresa directo a OperadorScreen limpiando todo el historial
              Navigator.pushAndRemoveUntil(
                context,
                MaterialPageRoute(
                  builder: (_) => OperadorScreen(
                    nombreUsuario: widget.nombreUsuario,
                  ),
                ),
                (route) => false,
              );
            },
            icon: const Icon(Icons.arrow_back_rounded),
            label: const Text('Seleccionar otro camión',
                style: TextStyle(fontWeight: FontWeight.w700)),
          ),
        ],
      ),
    );
  }

  void _snack(String msg, Color color) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(
      content: Text(msg, style: const TextStyle(fontWeight: FontWeight.w600)),
      backgroundColor: color,
      behavior: SnackBarBehavior.floating,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
    ));
  }

  @override
  Widget build(BuildContext context) {
    bool faltaAlgo = cubrebocas == false || gafas == false ||
        guantes == false || uniforme == false;

    return Scaffold(
      backgroundColor: const Color(0xFFF3F4F6),
      appBar: AppBar(
        title: const Text(
          'Revisión de Uniforme',
          style: TextStyle(fontWeight: FontWeight.bold),
        ),
        backgroundColor: _primary,
        foregroundColor: Colors.white,
        centerTitle: true,
        elevation: 0,
      ),
      body: Column(
        children: [
          // Panel superior
          Container(
            width: double.infinity,
            padding: const EdgeInsets.all(15),
            decoration: const BoxDecoration(
              color: _primary,
              borderRadius: BorderRadius.only(
                bottomLeft:  Radius.circular(30),
                bottomRight: Radius.circular(30),
              ),
            ),
            child: Column(
              children: [
                Text(
                  widget.camion.toUpperCase(),
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 18,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                Text(
                  'Placas: ${widget.placas}',
                  style: const TextStyle(color: Colors.white70, fontSize: 14),
                ),
              ],
            ),
          ),

          Expanded(
            child: Padding(
              padding: const EdgeInsets.all(15),
              child: Column(
                children: [
                  const Text(
                    'Selecciona tu equipo actual:',
                    style: TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.bold,
                      color: Colors.black87,
                    ),
                  ),
                  const SizedBox(height: 15),

                  Expanded(
                    child: GridView.count(
                      crossAxisCount: 2,
                      crossAxisSpacing: 12,
                      mainAxisSpacing: 12,
                      childAspectRatio: 1.15,
                      children: [
                        _buildGridItem('Cubrebocas', Icons.masks_rounded,
                            cubrebocas, (v) => setState(() => cubrebocas = v)),
                        _buildGridItem('Gafas', Icons.visibility,
                            gafas, (v) => setState(() => gafas = v)),
                        _buildGridItem('Guantes', Icons.pan_tool,
                            guantes, (v) => setState(() => guantes = v)),
                        _buildGridItem('Uniforme', Icons.checkroom,
                            uniforme, (v) => setState(() => uniforme = v)),
                      ],
                    ),
                  ),

                  if (faltaAlgo) ...[
                    const SizedBox(height: 10),
                    TextField(
                      controller: reporteController,
                      decoration: InputDecoration(
                        hintText: 'Razón del equipo faltante...',
                        prefixIcon: const Icon(Icons.edit, color: Colors.red),
                        filled: true,
                        fillColor: Colors.white,
                        border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(15),
                          borderSide: BorderSide.none,
                        ),
                        contentPadding: const EdgeInsets.all(15),
                      ),
                    ),
                  ],

                  const SizedBox(height: 20),

                  // Botón iniciar jornada
                  SizedBox(
                    width: double.infinity,
                    height: 65,
                    child: ElevatedButton(
                      style: ElevatedButton.styleFrom(
                        backgroundColor: _guardando
                            ? Colors.grey
                            : (faltaAlgo ? Colors.orange[800] : _success),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(18),
                        ),
                        elevation: _guardando ? 0 : 5,
                      ),
                      onPressed: _guardando ? null : guardarChecklist,
                      child: _guardando
                          ? const Row(
                              mainAxisAlignment: MainAxisAlignment.center,
                              children: [
                                SizedBox(
                                  width: 22,
                                  height: 22,
                                  child: CircularProgressIndicator(
                                      color: Colors.white, strokeWidth: 2.5),
                                ),
                                SizedBox(width: 12),
                                Text('Verificando disponibilidad...',
                                    style: TextStyle(
                                        color: Colors.white,
                                        fontSize: 15,
                                        fontWeight: FontWeight.bold)),
                              ],
                            )
                          : Row(
                              mainAxisAlignment: MainAxisAlignment.center,
                              children: [
                                Icon(
                                  faltaAlgo ? Icons.warning : Icons.play_arrow,
                                  color: Colors.white,
                                ),
                                const SizedBox(width: 10),
                                Text(
                                  faltaAlgo
                                      ? 'CONFIRMAR FALTANTES'
                                      : 'INICIAR JORNADA',
                                  style: const TextStyle(
                                    color: Colors.white,
                                    fontSize: 18,
                                    fontWeight: FontWeight.bold,
                                  ),
                                ),
                              ],
                            ),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildGridItem(String title, IconData icon, bool? state,
      Function(bool) onSelect) {
    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(20),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.05),
            blurRadius: 10,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(icon, size: 28,
              color: state == null ? Colors.grey
                  : (state ? Colors.green : Colors.red)),
          const SizedBox(height: 5),
          Text(title,
              style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 13)),
          const SizedBox(height: 8),
          Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              _choiceBtn(Icons.close, false, state == false, onSelect),
              const SizedBox(width: 14),
              _choiceBtn(Icons.done,  true,  state == true,  onSelect),
            ],
          ),
        ],
      ),
    );
  }

  Widget _choiceBtn(IconData icon, bool value, bool isSelected,
      Function(bool) onSelect) {
    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: () => onSelect(value),
        borderRadius: BorderRadius.circular(27),
        child: Container(
          width: 54,
          height: 54,
          alignment: Alignment.center,
          decoration: BoxDecoration(
            color: isSelected
                ? (value ? Colors.green : Colors.red)
                : Colors.grey[100],
            shape: BoxShape.circle,
            border: isSelected
                ? null
                : Border.all(color: Colors.grey.shade300, width: 1.5),
          ),
          child: Icon(icon, size: 30,
              color: isSelected ? Colors.white : Colors.grey[400]),
        ),
      ),
    );
  }
}