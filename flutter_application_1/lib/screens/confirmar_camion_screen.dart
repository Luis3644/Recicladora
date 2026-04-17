import 'dart:io';
import 'package:flutter/material.dart';
import 'checklist_screen.dart';
import 'widgets_conexion/connection_wrapper.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:image_picker/image_picker.dart';
import 'package:firebase_storage/firebase_storage.dart';

class _ConfirmarCamionContent extends StatefulWidget {
  final String operador;
  final String camionId;
  final String tipo;
  final String foto;
  final String placas;
  final String modelo;

  const _ConfirmarCamionContent({
    required this.operador,
    required this.camionId,
    required this.tipo,
    required this.foto,
    required this.placas,
    required this.modelo,
  });

  @override
  State<_ConfirmarCamionContent> createState() =>
      _ConfirmarCamionContentState();
}

class _ConfirmarCamionContentState extends State<_ConfirmarCamionContent>
    with SingleTickerProviderStateMixin {
  late AnimationController _controller;
  bool _contentVisible = false;

  static const Color _primary = Color(0xFF0F172A);
  static const Color _accent = Color(0xFF06B6D4);
  static const Color _success = Color(0xFF10B981);
  static const Color _danger = Color(0xFFDC2626);
  static const Color _warning = Color(0xFFF59E0B);
  static const Color _bgColor = Color(0xFFF0F9FF);

  // --- Estado del reporte de problema ---
  final TextEditingController _reporteController = TextEditingController();
  final List<File> _fotosReporte = [];
  bool _enviandoReporte = false;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      duration: const Duration(milliseconds: 700),
      vsync: this,
    );
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      setState(() => _contentVisible = true);
      _controller.forward();
    });
  }

  @override
  void dispose() {
    _controller.dispose();
    _reporteController.dispose();
    super.dispose();
  }

  Future<void> _seleccionarFoto() async {
    if (_fotosReporte.length >= 3) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: const Text('Máximo 3 fotos permitidas'),
          backgroundColor: _warning,
          behavior: SnackBarBehavior.floating,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
        ),
      );
      return;
    }
    final picker = ImagePicker();
    final picked = await picker.pickImage(source: ImageSource.gallery, imageQuality: 70);
    if (picked != null) {
      setState(() => _fotosReporte.add(File(picked.path)));
    }
  }

  Future<List<String>> _subirFotos() async {
    List<String> urls = [];
    for (final foto in _fotosReporte) {
      final ref = FirebaseStorage.instance
          .ref()
          .child('reportes_camiones/${widget.camionId}_${DateTime.now().millisecondsSinceEpoch}.jpg');
      await ref.putFile(foto);
      urls.add(await ref.getDownloadURL());
    }
    return urls;
  }

  Future<void> _enviarReporte() async {
    if (_reporteController.text.trim().isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: const Text('Por favor describe el problema'),
          backgroundColor: _danger,
          behavior: SnackBarBehavior.floating,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
        ),
      );
      return;
    }

    setState(() => _enviandoReporte = true);

    try {
      final fotosUrls = await _subirFotos();
      await FirebaseFirestore.instance.collection('reportes_camiones').add({
        'camionId': widget.camionId,
        'modelo': widget.modelo,
        'placas': widget.placas,
        'tipo': widget.tipo,
        'operador': widget.operador,
        'descripcion': _reporteController.text.trim(),
        'fotos': fotosUrls,
        'fecha': FieldValue.serverTimestamp(),
        'estado': 'pendiente',
      });

      if (!mounted) return;
      Navigator.pop(context);
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: const Text('✅ Reporte enviado correctamente'),
          backgroundColor: _success,
          behavior: SnackBarBehavior.floating,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
        ),
      );
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Error al enviar reporte: $e'),
          backgroundColor: _danger,
          behavior: SnackBarBehavior.floating,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
        ),
      );
    } finally {
      if (mounted) setState(() => _enviandoReporte = false);
    }
  }

  void _mostrarReporteBottomSheet() {
    _reporteController.clear();
    _fotosReporte.clear();

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setModalState) {
          return Container(
            padding: EdgeInsets.only(
              bottom: MediaQuery.of(ctx).viewInsets.bottom + 24,
              top: 24,
              left: 20,
              right: 20,
            ),
            decoration: const BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.vertical(top: Radius.circular(28)),
            ),
            child: SingleChildScrollView(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisSize: MainAxisSize.min,
                children: [
                  // Handle bar
                  Center(
                    child: Container(
                      width: 40,
                      height: 4,
                      decoration: BoxDecoration(
                        color: Colors.grey[300],
                        borderRadius: BorderRadius.circular(4),
                      ),
                    ),
                  ),
                  const SizedBox(height: 20),

                  // Título
                  Row(
                    children: [
                      Container(
                        padding: const EdgeInsets.all(10),
                        decoration: BoxDecoration(
                          color: _warning.withOpacity(0.15),
                          borderRadius: BorderRadius.circular(12),
                        ),
                        child: const Icon(Icons.warning_amber_rounded, color: _warning, size: 26),
                      ),
                      const SizedBox(width: 14),
                      const Text(
                        'Reportar problema',
                        style: TextStyle(
                          fontSize: 20,
                          fontWeight: FontWeight.w800,
                          color: _primary,
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 20),

                  // Campo de descripción
                  const Text(
                    'Descripción del problema',
                    style: TextStyle(
                      fontSize: 14,
                      fontWeight: FontWeight.w700,
                      color: _primary,
                    ),
                  ),
                  const SizedBox(height: 8),
                  TextField(
                    controller: _reporteController,
                    maxLines: 4,
                    style: const TextStyle(fontSize: 14, color: _primary),
                    decoration: InputDecoration(
                      hintText: 'Describe el problema del camión...',
                      hintStyle: TextStyle(color: Colors.grey[400], fontSize: 14),
                      filled: true,
                      fillColor: const Color(0xFFF8FAFC),
                      contentPadding: const EdgeInsets.all(16),
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(14),
                        borderSide: BorderSide(color: Colors.grey[200]!),
                      ),
                      enabledBorder: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(14),
                        borderSide: BorderSide(color: Colors.grey[200]!),
                      ),
                      focusedBorder: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(14),
                        borderSide: const BorderSide(color: _accent, width: 1.5),
                      ),
                    ),
                  ),
                  const SizedBox(height: 20),

                  // Fotos opcionales
                  Row(
                    children: [
                      const Text(
                        'Adjuntar fotos',
                        style: TextStyle(
                          fontSize: 14,
                          fontWeight: FontWeight.w700,
                          color: _primary,
                        ),
                      ),
                      const SizedBox(width: 8),
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                        decoration: BoxDecoration(
                          color: Colors.grey[100],
                          borderRadius: BorderRadius.circular(8),
                        ),
                        child: Text(
                          'Opcional · máx. 3',
                          style: TextStyle(fontSize: 11, color: Colors.grey[500], fontWeight: FontWeight.w600),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 10),
                  SingleChildScrollView(
                    scrollDirection: Axis.horizontal,
                    child: Row(
                      children: [
                        ...List.generate(_fotosReporte.length, (i) => Padding(
                          padding: const EdgeInsets.only(right: 10),
                          child: Stack(
                            children: [
                              ClipRRect(
                                borderRadius: BorderRadius.circular(12),
                                child: Image.file(
                                  _fotosReporte[i],
                                  width: 80,
                                  height: 80,
                                  fit: BoxFit.cover,
                                ),
                              ),
                              Positioned(
                                top: 4,
                                right: 4,
                                child: GestureDetector(
                                  onTap: () => setModalState(() => _fotosReporte.removeAt(i)),
                                  child: Container(
                                    padding: const EdgeInsets.all(2),
                                    decoration: const BoxDecoration(
                                      color: _danger,
                                      shape: BoxShape.circle,
                                    ),
                                    child: const Icon(Icons.close, color: Colors.white, size: 14),
                                  ),
                                ),
                              ),
                            ],
                          ),
                        )),
                        if (_fotosReporte.length < 3)
                          GestureDetector(
                            onTap: () async {
                              await _seleccionarFoto();
                              setModalState(() {});
                            },
                            child: Container(
                              width: 80,
                              height: 80,
                              decoration: BoxDecoration(
                                color: const Color(0xFFF8FAFC),
                                borderRadius: BorderRadius.circular(12),
                                border: Border.all(
                                  color: _accent.withOpacity(0.4),
                                  width: 1.5,
                                ),
                              ),
                              child: const Column(
                                mainAxisAlignment: MainAxisAlignment.center,
                                children: [
                                  Icon(Icons.add_a_photo_rounded, color: _accent, size: 26),
                                  SizedBox(height: 4),
                                  Text('Agregar', style: TextStyle(fontSize: 10, color: _accent, fontWeight: FontWeight.w600)),
                                ],
                              ),
                            ),
                          ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 24),

                  // Botón enviar
                  SizedBox(
                    width: double.infinity,
                    height: 54,
                    child: ElevatedButton.icon(
                      style: ElevatedButton.styleFrom(
                        backgroundColor: _warning,
                        foregroundColor: Colors.white,
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                        elevation: 3,
                      ),
                      onPressed: _enviandoReporte
                          ? null
                          : () async {
                              await _enviarReporte();
                              setModalState(() {});
                            },
                      icon: _enviandoReporte
                          ? const SizedBox(
                              width: 20,
                              height: 20,
                              child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2.5),
                            )
                          : const Icon(Icons.send_rounded),
                      label: Text(
                        _enviandoReporte ? 'Enviando...' : 'ENVIAR REPORTE',
                        style: const TextStyle(fontSize: 15, fontWeight: FontWeight.w700, letterSpacing: 0.5),
                      ),
                    ),
                  ),
                ],
              ),
            ),
          );
        },
      ),
    );
  }

  Widget _buildDatoCamion(IconData icon, String label, String valor) {
    return Row(
      children: [
        Icon(icon, size: 16, color: _accent),
        const SizedBox(width: 8),
        Text(
          '$label: ',
          style: const TextStyle(fontSize: 13, color: Colors.grey, fontWeight: FontWeight.w500),
        ),
        Text(
          valor,
          style: const TextStyle(fontSize: 13, color: _primary, fontWeight: FontWeight.w700),
        ),
      ],
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: _bgColor,
      appBar: AppBar(
        title: const Text(
          "Confirmar camión",
          style: TextStyle(fontWeight: FontWeight.w700, letterSpacing: 0.3),
        ),
        automaticallyImplyLeading: false,
        backgroundColor: Colors.transparent,
        elevation: 0,
        foregroundColor: Colors.white,
        actions: [
          // ⚠️ Botón reportar problema en el AppBar
          Padding(
            padding: const EdgeInsets.only(right: 12),
            child: GestureDetector(
              onTap: _mostrarReporteBottomSheet,
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                decoration: BoxDecoration(
                  color: _warning.withOpacity(0.2),
                  borderRadius: BorderRadius.circular(20),
                  border: Border.all(color: _warning.withOpacity(0.5), width: 1.2),
                ),
                child: const Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(Icons.warning_amber_rounded, color: _warning, size: 18),
                    SizedBox(width: 5),
                    Text(
                      'Problema',
                      style: TextStyle(
                        color: _warning,
                        fontSize: 12,
                        fontWeight: FontWeight.w700,
                        letterSpacing: 0.3,
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ],
        flexibleSpace: Container(
          decoration: BoxDecoration(
            gradient: LinearGradient(
              colors: [_primary, const Color(0xFF1E293B)],
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
            ),
            boxShadow: [
              BoxShadow(
                color: _primary.withOpacity(0.3),
                blurRadius: 20,
                offset: const Offset(0, 8),
              ),
            ],
          ),
        ),
      ),
      body: Stack(
        children: [
          Positioned(
            top: -100,
            right: -60,
            child: Container(
              width: 260,
              height: 260,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: _accent.withOpacity(0.1),
              ),
            ),
          ),
          Positioned(
            bottom: -80,
            left: -80,
            child: Container(
              width: 240,
              height: 240,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: _success.withOpacity(0.08),
              ),
            ),
          ),
          SingleChildScrollView(
            padding: const EdgeInsets.all(20),
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                AnimatedOpacity(
                  duration: const Duration(milliseconds: 600),
                  opacity: _contentVisible ? 1 : 0,
                  child: AnimatedSlide(
                    duration: const Duration(milliseconds: 600),
                    offset: _contentVisible ? Offset.zero : const Offset(0, 0.05),
                    curve: Curves.easeOutCubic,
                    child: Container(
                      decoration: BoxDecoration(
                        borderRadius: BorderRadius.circular(24),
                        boxShadow: [
                          BoxShadow(
                            color: _primary.withOpacity(0.12),
                            blurRadius: 28,
                            offset: const Offset(0, 12),
                            spreadRadius: 2,
                          ),
                        ],
                      ),
                      child: ClipRRect(
                        borderRadius: BorderRadius.circular(24),
                        child: Stack(
                          children: [
                            Image.network(
                              widget.foto,
                              height: 260,
                              width: double.infinity,
                              fit: BoxFit.cover,
                              loadingBuilder: (context, child, loadingProgress) {
                                if (loadingProgress == null) return child;
                                return Container(
                                  height: 260,
                                  color: Colors.grey[100],
                                  child: const Center(
                                    child: CircularProgressIndicator(color: _accent, strokeWidth: 3),
                                  ),
                                );
                              },
                              errorBuilder: (context, error, stackTrace) {
                                return Container(
                                  height: 260,
                                  width: double.infinity,
                                  decoration: BoxDecoration(
                                    gradient: LinearGradient(
                                      colors: [Colors.grey[100]!, Colors.grey[200]!],
                                    ),
                                  ),
                                  child: Column(
                                    mainAxisAlignment: MainAxisAlignment.center,
                                    children: [
                                      Icon(Icons.broken_image_rounded, size: 80, color: Colors.grey[400]),
                                      const SizedBox(height: 12),
                                      Text(
                                        "No se pudo cargar la imagen",
                                        style: TextStyle(color: Colors.grey[600], fontSize: 14),
                                      ),
                                    ],
                                  ),
                                );
                              },
                            ),
                            Positioned(
                              top: 0, left: 0, right: 0, bottom: 0,
                              child: Container(
                                decoration: BoxDecoration(
                                  gradient: LinearGradient(
                                    begin: Alignment.topCenter,
                                    end: Alignment.bottomCenter,
                                    colors: [Colors.transparent, Colors.black.withOpacity(0.3)],
                                  ),
                                ),
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                  ),
                ),
                const SizedBox(height: 28),
                ScaleTransition(
                  scale: Tween<double>(begin: 0.8, end: 1.0).animate(
                    CurvedAnimation(parent: _controller, curve: Curves.easeOutBack),
                  ),
                  child: FadeTransition(
                    opacity: Tween<double>(begin: 0, end: 1).animate(
                      CurvedAnimation(parent: _controller, curve: Curves.easeOut),
                    ),
                    child: Text(
                      widget.tipo,
                      style: const TextStyle(
                        fontSize: 32,
                        fontWeight: FontWeight.w800,
                        color: _primary,
                        letterSpacing: -0.5,
                      ),
                    ),
                  ),
                ),
                const SizedBox(height: 16),
                AnimatedOpacity(
                  opacity: _contentVisible ? 1 : 0,
                  duration: const Duration(milliseconds: 800),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      _buildInfoBadge("Modelo: ${widget.modelo}", _accent.withOpacity(0.14), _primary),
                      const SizedBox(width: 12),
                      _buildInfoBadge("Placas: ${widget.placas}", _success.withOpacity(0.14), _success),
                    ],
                  ),
                ),
                const SizedBox(height: 32),
                AnimatedOpacity(
                  opacity: _contentVisible ? 1 : 0,
                  duration: const Duration(milliseconds: 900),
                  child: const Text(
                    "¿Este es el camión que operarás hoy?",
                    style: TextStyle(fontSize: 18, fontWeight: FontWeight.w600, color: _primary),
                    textAlign: TextAlign.center,
                  ),
                ),
                const SizedBox(height: 32),
                ScaleTransition(
                  scale: Tween<double>(begin: 0.7, end: 1.0).animate(
                    CurvedAnimation(parent: _controller, curve: Curves.easeOutBack),
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      ElevatedButton.icon(
                        style: ElevatedButton.styleFrom(
                          backgroundColor: _success,
                          foregroundColor: Colors.white,
                          minimumSize: const Size(double.infinity, 56),
                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                          elevation: 4,
                        ),
                        onPressed: () {
                          Navigator.push(
                            context,
                            MaterialPageRoute(
                              builder: (_) => ChecklistScreen(
                                nombreUsuario: widget.operador,
                                camionId: widget.camionId,
                                camion: widget.tipo,
                                placas: widget.placas,
                              ),
                            ),
                          );
                        },
                        icon: const Icon(Icons.check_circle_rounded),
                        label: const Text(
                          "SÍ, ES CORRECTO",
                          style: TextStyle(fontSize: 16, fontWeight: FontWeight.w700, letterSpacing: 0.5),
                        ),
                      ),
                      const SizedBox(height: 12),
                      TextButton.icon(
                        style: TextButton.styleFrom(
                          foregroundColor: _danger,
                          minimumSize: const Size(double.infinity, 48),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(14),
                            side: BorderSide(color: _danger.withOpacity(0.3), width: 1.5),
                          ),
                        ),
                        onPressed: () => Navigator.pop(context),
                        icon: const Icon(Icons.arrow_back_rounded),
                        label: const Text(
                          "No, volver a seleccionar",
                          style: TextStyle(fontSize: 15, fontWeight: FontWeight.w600),
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildInfoBadge(String text, Color bgColor, Color textColor) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
      decoration: BoxDecoration(
        color: bgColor,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: textColor.withOpacity(0.2)),
      ),
      child: Text(
        text,
        style: TextStyle(
          fontSize: 15,
          color: textColor,
          fontWeight: FontWeight.w700,
          letterSpacing: 0.2,
        ),
      ),
    );
  }
}

class ConfirmarCamionScreen extends StatelessWidget {
  final String operador;
  final String camionId;
  final String tipo;
  final String foto;
  final String placas;
  final String modelo;

  const ConfirmarCamionScreen({
    super.key,
    required this.operador,
    required this.camionId,
    required this.tipo,
    required this.foto,
    required this.placas,
    required this.modelo,
  });

  @override
  Widget build(BuildContext context) {
    return ConnectionWrapper(
      child: _ConfirmarCamionContent(
        operador: operador,
        camionId: camionId,
        tipo: tipo,
        foto: foto,
        placas: placas,
        modelo: modelo,
      ),
    );
  }
}