import 'dart:io';
import 'dart:typed_data'; // Importante para WEB
import 'package:flutter/foundation.dart'; // Para detectar kIsWeb
import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import 'package:firebase_storage/firebase_storage.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_messaging/firebase_messaging.dart';
import 'widgets_conexion/connection_wrapper.dart';
import '../widgets/jornada_bottom_bar.dart';
import 'jornada_screen.dart';
import 'operador_screen.dart'; // RegistrosJornadaScreen está aquí? No, está en jornada_screen.dart según findstr anterior.
// Wait, findstr said lib\screens\jornada_screen.dart:class RegistrosJornadaScreen extends StatelessWidget {
// so I just need jornada_screen.dart for JornadaScreen, RegistrosJornadaScreen and PerfilOperadorScreen.

class ReporteScreen extends StatefulWidget {
  final String nombreUsuario;
  final String camion;
  final String placas;

  const ReporteScreen({
    super.key, 
    required this.nombreUsuario, 
    required this.camion, 
    required this.placas
  });

  @override
  State<ReporteScreen> createState() => _ReporteScreenState();
}

class _ReporteScreenState extends State<ReporteScreen>
    with SingleTickerProviderStateMixin {
  final TextEditingController _descripcionController = TextEditingController();
  
  List<XFile> _imagenesXFile = []; // Cambio: Lista de imágenes
  List<Uint8List?> _webImages = []; // Para web
  bool _subiendo = false;
  bool _contentVisible = false;
  late AnimationController _controller;

  final ImagePicker _picker = ImagePicker();

  static const Color _primary = Color(0xFF0F172A);
  static const Color _accent = Color(0xFF06B6D4);
  static const Color _success = Color(0xFF10B981);
  static const Color _danger = Color(0xFFDC2626);
  static const Color _bgColor = Color(0xFFF0F9FF);

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
    _descripcionController.dispose();
    super.dispose();
  }

  // Función para elegir imagen (Cámara o Galería)
  Future<void> _seleccionarImagen(ImageSource source) async {
    if (_imagenesXFile.length >= 3) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text("Máximo 3 imágenes permitidas")),
      );
      return;
    }

    final pickedFile = await _picker.pickImage(source: source, imageQuality: 50);
    
    if (pickedFile != null) {
      if (kIsWeb) {
        var f = await pickedFile.readAsBytes();
        setState(() {
          _webImages.add(f);
          _imagenesXFile.add(pickedFile);
        });
      } else {
        setState(() {
          _imagenesXFile.add(pickedFile);
          _webImages.add(null);
        });
      }
    }
  }

  // Eliminar imagen
  void _eliminarImagen(int index) {
    setState(() {
      _imagenesXFile.removeAt(index);
      _webImages.removeAt(index);
    });
  }

  Future<void> _enviarReporte() async {
    if (_descripcionController.text.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text("Escribe el mensaje del problema")),
      );
      return;
    }

    setState(() => _subiendo = true);

    try {
      List<String> imageUrls = [];
      
      // Subir cada imagen
      for (int i = 0; i < _imagenesXFile.length; i++) {
        String fileName = 'reportes/${DateTime.now().millisecondsSinceEpoch}_$i.jpg';
        
        Reference storageRef = FirebaseStorage.instance.ref().child(fileName);
        UploadTask uploadTask;
        
        if (kIsWeb) {
          uploadTask = storageRef.putData(
            _webImages[i]!,
            SettableMetadata(contentType: 'image/jpeg'),
          );
        } else {
          uploadTask = storageRef.putFile(
            File(_imagenesXFile[i].path),
            SettableMetadata(contentType: 'image/jpeg'),
          );
        }
        
        TaskSnapshot snapshot = await uploadTask;
        String imageUrl = await snapshot.ref.getDownloadURL();
        imageUrls.add(imageUrl);
      }

      await FirebaseFirestore.instance.collection("reportes").add({
        "camion": widget.camion,
        "fecha": FieldValue.serverTimestamp(),
        "mensaje": _descripcionController.text,
        "operador": widget.nombreUsuario,
        "placas": widget.placas,
        "fotosUrl": imageUrls,
        "visto": false,
      });

      // La notificación se envía automáticamente con Cloud Functions
      if (mounted) {
        Navigator.pop(context);
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text("Reporte enviado al Administrador")),
        );
      }
    } catch (e) {
      print("ERROR DETECTADO: $e");
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text("Error al enviar: $e")),
      );
    } finally {
      if (mounted) setState(() => _subiendo = false);
    }
  }

  void _irAInicio() {
    Navigator.of(context).pushReplacement(
      MaterialPageRoute(
        builder: (_) => JornadaScreen(
          operador: widget.nombreUsuario,
          camion: widget.camion,
          placas: widget.placas,
        ),
      ),
    );
  }

  void _irAHistorial() {
    Navigator.of(context).pushReplacement(
      MaterialPageRoute(
        builder: (_) => RegistrosJornadaScreen(
          operador: widget.nombreUsuario,
          camion: widget.camion,
          placas: widget.placas,
          historial: true,
        ),
      ),
    );
  }

  void _irAReporte() {
    // Ya estamos aquí
    return;
  }

  void _irAPerfil() {
    Navigator.of(context).pushReplacement(
      MaterialPageRoute(
        builder: (_) => PerfilOperadorScreen(
          operador: widget.nombreUsuario,
          camion: widget.camion,
          placas: widget.placas,
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return ConnectionWrapper(
      child: Scaffold(
        backgroundColor: _bgColor,
        appBar: AppBar(
          title: const Text(
            "Reportar Incidente",
            style: TextStyle(fontWeight: FontWeight.w700, letterSpacing: 0.3),
          ),
          automaticallyImplyLeading: false,
          backgroundColor: Colors.transparent,
          elevation: 0,
          foregroundColor: Colors.white,
          flexibleSpace: Container(
            decoration: const BoxDecoration(
              gradient: LinearGradient(
                colors: [_primary, Color(0xFF1E293B)],
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
              ),
              boxShadow: [
                BoxShadow(
                  color: Color(0xFF0F172A),
                  blurRadius: 20,
                  offset: Offset(0, 8),
                ),
              ],
            ),
          ),
        ),
        bottomNavigationBar: JornadaBottomBar(
          activeIndex: 3,
          onInicio: _irAInicio,
          onHistorial: _irAHistorial,
          onReporte: _irAReporte,
          onPerfil: _irAPerfil,
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
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  AnimatedOpacity(
                    duration: const Duration(milliseconds: 600),
                    opacity: _contentVisible ? 1 : 0,
                    child: AnimatedSlide(
                      duration: const Duration(milliseconds: 600),
                      offset: _contentVisible ? Offset.zero : const Offset(0, 0.05),
                      curve: Curves.easeOutCubic,
                      child: Container(
                        padding: const EdgeInsets.all(16),
                        decoration: BoxDecoration(
                          color: Colors.white.withOpacity(0.8),
                          borderRadius: BorderRadius.circular(16),
                          border: Border.all(
                            color: _accent.withOpacity(0.2),
                            width: 1.5,
                          ),
                          boxShadow: [
                            BoxShadow(
                              color: _primary.withOpacity(0.08),
                              blurRadius: 16,
                              offset: const Offset(0, 4),
                            ),
                          ],
                        ),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Row(
                              children: [
                                Container(
                                  padding: const EdgeInsets.all(8),
                                  decoration: BoxDecoration(
                                    color: _accent.withOpacity(0.15),
                                    borderRadius: BorderRadius.circular(10),
                                  ),
                                  child: const Icon(Icons.local_shipping_rounded,
                                      color: _accent, size: 24),
                                ),
                                const SizedBox(width: 12),
                                Expanded(
                                  child: Column(
                                    crossAxisAlignment:
                                        CrossAxisAlignment.start,
                                    children: [
                                      Text(
                                        widget.camion,
                                        style: const TextStyle(
                                            fontSize: 16,
                                            fontWeight: FontWeight.w700,
                                            color: _primary),
                                      ),
                                      Text(
                                        widget.placas,
                                        style: TextStyle(
                                            fontSize: 13,
                                            color: _primary.withOpacity(0.7)),
                                      ),
                                    ],
                                  ),
                                ),
                              ],
                            ),
                          ],
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(height: 20),
                  AnimatedOpacity(
                    opacity: _contentVisible ? 1 : 0,
                    duration: const Duration(milliseconds: 700),
                    child: Text(
                      "¿Cuál es el problema?",
                      style: const TextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.w700,
                        color: _primary,
                        letterSpacing: 0.2,
                      ),
                    ),
                  ),
                  const SizedBox(height: 12),
                  AnimatedOpacity(
                    opacity: _contentVisible ? 1 : 0,
                    duration: const Duration(milliseconds: 800),
                    child: TextField(
                      controller: _descripcionController,
                      maxLines: 4,
                      style: const TextStyle(color: _primary),
                      decoration: InputDecoration(
                        hintText: "Describe el problema detalladamente...",
                        hintStyle: TextStyle(
                            color: _primary.withOpacity(0.5),
                            fontSize: 14),
                        prefixIcon: Padding(
                          padding: const EdgeInsets.all(12),
                          child: Icon(Icons.description_rounded,
                              color: _accent, size: 22),
                        ),
                        filled: true,
                        fillColor: Colors.white,
                        border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(14),
                          borderSide: BorderSide(
                              color: _accent.withOpacity(0.2), width: 1.5),
                        ),
                        enabledBorder: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(14),
                          borderSide: BorderSide(
                              color: _accent.withOpacity(0.2), width: 1.5),
                        ),
                        focusedBorder: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(14),
                          borderSide:
                              const BorderSide(color: _accent, width: 2),
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(height: 24),
                  AnimatedOpacity(
                    opacity: _contentVisible ? 1 : 0,
                    duration: const Duration(milliseconds: 850),
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Text(
                          "Adjuntar fotos (${_imagenesXFile.length}/3)",
                          style: const TextStyle(
                            fontSize: 16,
                            fontWeight: FontWeight.w700,
                            color: _primary,
                            letterSpacing: 0.2,
                          ),
                        ),
                       
                      ],
                    ),
                  ),
                  const SizedBox(height: 12),
                  // Grid de imágenes
                  if (_imagenesXFile.isNotEmpty)
                    GridView.builder(
                      shrinkWrap: true,
                      physics: const NeverScrollableScrollPhysics(),
                      gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                        crossAxisCount: 3,
                        childAspectRatio: 1,
                        crossAxisSpacing: 12,
                        mainAxisSpacing: 12,
                      ),
                      itemCount: _imagenesXFile.length,
                      itemBuilder: (context, index) {
                        return Stack(
                          children: [
                            Container(
                              decoration: BoxDecoration(
                                border: Border.all(
                                  color: _accent.withOpacity(0.3),
                                  width: 2,
                                ),
                                borderRadius: BorderRadius.circular(12),
                                color: Colors.white,
                              ),
                              child: ClipRRect(
                                borderRadius: BorderRadius.circular(10),
                                child: kIsWeb
                                    ? Image.memory(
                                        _webImages[index]!,
                                        fit: BoxFit.cover,
                                      )
                                    : Image.file(
                                        File(_imagenesXFile[index].path),
                                        fit: BoxFit.cover,
                                      ),
                              ),
                            ),
                            Positioned(
                              top: 4,
                              right: 4,
                              child: GestureDetector(
                                onTap: () => _eliminarImagen(index),
                                child: Container(
                                  decoration: BoxDecoration(
                                    color: _danger,
                                    shape: BoxShape.circle,
                                  ),
                                  padding: const EdgeInsets.all(4),
                                  child: const Icon(
                                    Icons.close,
                                    color: Colors.white,
                                    size: 16,
                                  ),
                                ),
                              ),
                            ),
                          ],
                        );
                      },
                    ),
                  if (_imagenesXFile.isEmpty)
                    Container(
                      height: 150,
                      width: double.infinity,
                      decoration: BoxDecoration(
                        border: Border.all(
                          color: _accent.withOpacity(0.3),
                          width: 2,
                        ),
                        borderRadius: BorderRadius.circular(16),
                        color: Colors.white,
                      ),
                      child: Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Icon(Icons.image_rounded,
                              size: 48, color: _accent.withOpacity(0.4)),
                          const SizedBox(height: 8),
                          Text(
                            "Sin fotos adjuntas",
                            style: TextStyle(
                              color: _primary.withOpacity(0.6),
                              fontSize: 14,
                            ),
                          ),
                        ],
                      ),
                    ),
                  const SizedBox(height: 16),
                  Row(
                    children: [
                      Expanded(
                        child: ElevatedButton.icon(
                          style: ElevatedButton.styleFrom(
                            backgroundColor: _accent,
                            foregroundColor: Colors.white,
                            minimumSize: const Size(double.infinity, 48),
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(12),
                            ),
                            elevation: 3,
                          ),
                          onPressed: _imagenesXFile.length >= 3
                              ? null
                              : () => _seleccionarImagen(ImageSource.camera),
                          icon: const Icon(Icons.photo_camera_rounded),
                          label: const Text(
                            "Cámara",
                            style: TextStyle(
                              fontWeight: FontWeight.w600,
                              fontSize: 14,
                            ),
                          ),
                        ),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: ElevatedButton.icon(
                          style: ElevatedButton.styleFrom(
                            backgroundColor: _accent.withOpacity(0.8),
                            foregroundColor: Colors.white,
                            minimumSize: const Size(double.infinity, 48),
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(12),
                            ),
                            elevation: 3,
                          ),
                          onPressed: _imagenesXFile.length >= 3
                              ? null
                              : () => _seleccionarImagen(ImageSource.gallery),
                          icon: const Icon(Icons.image_rounded),
                          label: const Text(
                            "Galería",
                            style: TextStyle(
                              fontWeight: FontWeight.w600,
                              fontSize: 14,
                            ),
                          ),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 32),
                  _subiendo
                      ? Container(
                          width: double.infinity,
                          height: 56,
                          decoration: BoxDecoration(
                            gradient: LinearGradient(
                              colors: [_danger, const Color(0xFFEF4444)],
                              begin: Alignment.topLeft,
                              end: Alignment.bottomRight,
                            ),
                            borderRadius: BorderRadius.circular(14),
                            boxShadow: [
                              BoxShadow(
                                color: _danger.withOpacity(0.3),
                                blurRadius: 12,
                                offset: const Offset(0, 4),
                              ),
                            ],
                          ),
                          child: const Center(
                            child: CircularProgressIndicator(
                              color: Colors.white,
                              strokeWidth: 3,
                            ),
                          ),
                        )
                      : ElevatedButton.icon(
                          style: ElevatedButton.styleFrom(
                            backgroundColor: _danger,
                            foregroundColor: Colors.white,
                            minimumSize: const Size(double.infinity, 56),
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(14),
                            ),
                            elevation: 4,
                          ),
                          onPressed: _enviarReporte,
                          icon: const Icon(Icons.send_rounded, size: 22),
                          label: const Text(
                            "ENVIAR REPORTE",
                            style: TextStyle(
                              fontSize: 16,
                              fontWeight: FontWeight.w700,
                              letterSpacing: 0.5,
                            ),
                          ),
                        ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}