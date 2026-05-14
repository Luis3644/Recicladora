import 'dart:io';
import 'dart:typed_data';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import 'package:firebase_storage/firebase_storage.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'widgets_conexion/connection_wrapper.dart';
import '../widgets/jornada_bottom_bar.dart';
import 'jornada_screen.dart';

// ─── Paleta de colores ────────────────────────────────────────────────────────
class _C {
  static const bg       = Color(0xFFF5F7FA); // fondo general
  static const surface  = Color(0xFFFFFFFF); // tarjetas
  static const navy     = Color(0xFF0F2754); // azul marino principal
  static const navyMid  = Color(0xFF1A3A6B); // azul marino medio
  static const blue     = Color(0xFF1D4ED8); // acento botones
  static const blueSoft = Color(0xFFEFF6FF); // fondo suave azul
  static const sky      = Color(0xFF3B82F6); // highlights
  static const danger   = Color(0xFFEF4444);
  static const dangerBg = Color(0xFFFEF2F2);
  static const success  = Color(0xFF10B981);
  static const successBg= Color(0xFFECFDF5);
  static const text     = Color(0xFF0F172A); // texto principal
  static const textSub  = Color(0xFF64748B); // texto secundario
  static const border   = Color(0xFFE2E8F0); // bordes
}

class ReporteScreen extends StatefulWidget {
  final String nombreUsuario;
  final String camion;
  final String placas;

  const ReporteScreen({
    super.key,
    required this.nombreUsuario,
    required this.camion,
    required this.placas,
  });

  @override
  State<ReporteScreen> createState() => _ReporteScreenState();
}

class _ReporteScreenState extends State<ReporteScreen> {
  final _desc   = TextEditingController();
  final _picker = ImagePicker();

  final List<XFile>     _xFiles   = [];
  final List<Uint8List?> _webBytes = [];

  bool _subiendo = false;

  // ── Seleccionar imagen ────────────────────────────────────────────────────
  Future<void> _pick(ImageSource src) async {
    if (_xFiles.length >= 3) {
      _snack('Máximo 3 fotos permitidas', isError: true);
      return;
    }
    final f = await _picker.pickImage(source: src, imageQuality: 65);
    if (f == null) return;
    if (kIsWeb) {
      final b = await f.readAsBytes();
      setState(() { _xFiles.add(f); _webBytes.add(b); });
    } else {
      setState(() { _xFiles.add(f); _webBytes.add(null); });
    }
  }

  void _remove(int i) =>
      setState(() { _xFiles.removeAt(i); _webBytes.removeAt(i); });

  // ── Enviar reporte ────────────────────────────────────────────────────────
  Future<void> _enviar() async {
    final msg = _desc.text.trim();
    if (msg.isEmpty) {
      _snack('Por favor describe el problema antes de enviar', isError: true);
      return;
    }
    setState(() => _subiendo = true);
    try {
      final urls = <String>[];
      for (var i = 0; i < _xFiles.length; i++) {
        final path = 'reportes/${DateTime.now().millisecondsSinceEpoch}_$i.jpg';
        final ref  = FirebaseStorage.instance.ref().child(path);
        final meta = SettableMetadata(contentType: 'image/jpeg');
        final task = kIsWeb
            ? ref.putData(_webBytes[i]!, meta)
            : ref.putFile(File(_xFiles[i].path), meta);
        urls.add(await (await task).ref.getDownloadURL());
      }

      await FirebaseFirestore.instance.collection('reportes').add({
        'camion'  : widget.camion,
        'fecha'   : FieldValue.serverTimestamp(),
        'mensaje' : msg,
        'operador': widget.nombreUsuario,
        'placas'  : widget.placas,
        'fotosUrl': urls,
        'visto'   : false,
      });

      // Notificar al administrador
      await _enviarNotificacionAdmin(
        tipo: 'equipo',
        mensaje:
            'NUEVO REPORTE DE EQUIPO: ${widget.nombreUsuario} (Camión: ${widget.placas}) ha reportado un incidente: "$msg".',
      );

      if (mounted) {
        Navigator.pop(context);
        _snack('✓ Reporte enviado al Administrador');
      }
    } catch (e) {
      _snack('Error al enviar: $e', isError: true);
    } finally {
      if (mounted) setState(() => _subiendo = false);
    }
  }

  Future<void> _enviarNotificacionAdmin({
    required String tipo,
    required String mensaje,
  }) async {
    try {
      await FirebaseFirestore.instance.collection('notificaciones').add({
        'mensaje': mensaje,
        'creadoEn': FieldValue.serverTimestamp(),
        'enviadoPor': widget.nombreUsuario,
        'destinoTipo': 'rol',
        'paraTodos': false,
        'destinatarioRol': 'admin',
        'tipo': tipo,
        'leidoPor': <String, bool>{},
      });
    } catch (e) {
      debugPrint('Error enviando notificación al admin: $e');
    }
  }

  void _snack(String msg, {bool isError = false}) {
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(
      content: Text(msg,
          style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 14)),
      backgroundColor: isError ? _C.danger : _C.success,
      behavior: SnackBarBehavior.floating,
      margin: const EdgeInsets.all(16),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
    ));
  }

  // ── Navegación ────────────────────────────────────────────────────────────
  void _irAInicio() => Navigator.of(context).pushReplacement(MaterialPageRoute(
      builder: (_) => JornadaScreen(
          operador: widget.nombreUsuario,
          camion: widget.camion,
          placas: widget.placas)));

  void _irAHistorial() =>
      Navigator.of(context).pushReplacement(MaterialPageRoute(
          builder: (_) => RegistrosJornadaScreen(
              operador: widget.nombreUsuario,
              camion: widget.camion,
              placas: widget.placas,
              historial: true)));

  void _irAReporte() {}

  void _irAPerfil() => Navigator.of(context).pushReplacement(MaterialPageRoute(
      builder: (_) => PerfilOperadorScreen(
          operador: widget.nombreUsuario,
          camion: widget.camion,
          placas: widget.placas)));

  // ─────────────────────────────────────────────────────────────────────────
  @override
  Widget build(BuildContext context) {
    return ConnectionWrapper(
      child: Scaffold(
        backgroundColor: _C.bg,
        appBar: _appBar(),
        bottomNavigationBar: JornadaBottomBar(
          activeIndex: 3,
          onInicio   : _irAInicio,
          onHistorial: _irAHistorial,
          onReporte  : _irAReporte,
          onPerfil   : _irAPerfil,
        ),
        body: SafeArea(
          child: SingleChildScrollView(
            physics: const ClampingScrollPhysics(),
            padding: const EdgeInsets.fromLTRB(16, 20, 16, 40),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // ── Tarjeta del operador ─────────────────────────
                _OperatorCard(nombre: widget.nombreUsuario, placas: widget.placas),
                const SizedBox(height: 20),

                // ── Aviso ────────────────────────────────────────
                _InfoBanner(),
                const SizedBox(height: 24),

                // ── Campo descripción ────────────────────────────
                _Label(text: '¿Qué está pasando?'),
                const SizedBox(height: 8),
                _DescField(controller: _desc),
                const SizedBox(height: 24),

                // ── Fotos ────────────────────────────────────────
                _Label(text: 'Fotos del incidente'),
                const SizedBox(height: 4),
                Text('',
                    style: TextStyle(color: _C.textSub, fontSize: 12)),
                const SizedBox(height: 12),
                _PhotoArea(
                  xFiles   : _xFiles,
                  webBytes : _webBytes,
                  onPick   : _pick,
                  onRemove : _remove,
                ),
                const SizedBox(height: 32),

                // ── Botón enviar ─────────────────────────────────
                _SendBtn(subiendo: _subiendo, onPressed: _enviar),
                const SizedBox(height: 12),

                // ── Nota final ───────────────────────────────────
                Center(
                  child: Text(
                    '',
                    style: TextStyle(color: _C.textSub, fontSize: 12),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  PreferredSizeWidget _appBar() => AppBar(
        automaticallyImplyLeading: false,
        backgroundColor: _C.navy,
        elevation: 0,
        titleSpacing: 16,
        title: Row(children: [
          Container(
            padding: const EdgeInsets.all(8),
            decoration: BoxDecoration(
              color: Colors.white.withOpacity(0.12),
              borderRadius: BorderRadius.circular(10),
            ),
            child: const Icon(Icons.report_problem_rounded,
                color: Colors.white, size: 20),
          ),
          const SizedBox(width: 12),
          const Text('Reportar Incidente',
              style: TextStyle(
                  color: Colors.white,
                  fontSize: 17,
                  fontWeight: FontWeight.w800)),
        ]),
      );

  @override
  void dispose() {
    _desc.dispose();
    super.dispose();
  }
}

// ─── Tarjeta del operador ─────────────────────────────────────────────────────
class _OperatorCard extends StatelessWidget {
  final String nombre;
  final String placas;
  const _OperatorCard({required this.nombre, required this.placas});

  @override
  Widget build(BuildContext context) {
    // Iniciales del operador
    final partes = nombre.trim().split(' ');
    final iniciales = partes.length >= 2
        ? '${partes[0][0]}${partes[1][0]}'.toUpperCase()
        : nombre.substring(0, nombre.length.clamp(0, 2)).toUpperCase();

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: _C.surface,
        borderRadius: BorderRadius.circular(18),
        boxShadow: [
          BoxShadow(
              color: _C.navy.withOpacity(0.08),
              blurRadius: 16,
              offset: const Offset(0, 4)),
        ],
        border: Border.all(color: _C.border),
      ),
      child: Row(children: [
        // Avatar con iniciales
        Container(
          width: 52,
          height: 52,
          decoration: BoxDecoration(
            gradient: const LinearGradient(
              colors: [_C.navy, _C.navyMid],
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
            ),
            borderRadius: BorderRadius.circular(14),
          ),
          child: Center(
            child: Text(iniciales,
                style: const TextStyle(
                    color: Colors.white,
                    fontSize: 18,
                    fontWeight: FontWeight.w800)),
          ),
        ),
        const SizedBox(width: 14),

        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(nombre,
                  style: const TextStyle(
                      color: _C.text,
                      fontSize: 16,
                      fontWeight: FontWeight.w800)),
              const SizedBox(height: 4),
              Row(children: [
                const Icon(Icons.pin_rounded, size: 14, color: _C.textSub),
                const SizedBox(width: 4),
                Text(placas,
                    style: const TextStyle(
                        color: _C.textSub,
                        fontSize: 13,
                        fontWeight: FontWeight.w600)),
              ]),
            ],
          ),
        ),

        // Punto activo
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
          decoration: BoxDecoration(
            color: _C.successBg,
            borderRadius: BorderRadius.circular(20),
          ),
          child: Row(mainAxisSize: MainAxisSize.min, children: [
            Container(
              width: 7, height: 7,
              decoration: const BoxDecoration(
                  color: _C.success, shape: BoxShape.circle),
            ),
            const SizedBox(width: 5),
            const Text('En turno',
                style: TextStyle(
                    color: _C.success,
                    fontSize: 11,
                    fontWeight: FontWeight.w700)),
          ]),
        ),
      ]),
    );
  }
}

// ─── Banner informativo ───────────────────────────────────────────────────────
class _InfoBanner extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
      decoration: BoxDecoration(
        color: _C.blueSoft,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: _C.sky.withOpacity(0.3)),
      ),
      child: Row(children: [
        const Icon(Icons.bolt_rounded, color: _C.blue, size: 20),
        const SizedBox(width: 10),
        Expanded(
          child: Text(
            'Tu reporte llegará inmediatamente al administrador. '
            '',
            style: TextStyle(
                color: _C.navyMid, fontSize: 12, height: 1.5,
                fontWeight: FontWeight.w500),
          ),
        ),
      ]),
    );
  }
}

// ─── Etiqueta de sección ──────────────────────────────────────────────────────
class _Label extends StatelessWidget {
  final String text;
  const _Label({required this.text});

  @override
  Widget build(BuildContext context) {
    return Text(text,
        style: const TextStyle(
            color: _C.text,
            fontSize: 15,
            fontWeight: FontWeight.w800));
  }
}

// ─── Campo descripción ────────────────────────────────────────────────────────
class _DescField extends StatelessWidget {
  final TextEditingController controller;
  const _DescField({required this.controller});

  @override
  Widget build(BuildContext context) {
    return TextField(
      controller: controller,
      maxLines: 5,
      style: const TextStyle(color: _C.text, fontSize: 14, height: 1.6),
      cursorColor: _C.blue,
      decoration: InputDecoration(
        hintText: 'Escribe a qui...',
        hintStyle: TextStyle(color: _C.textSub.withOpacity(0.7), fontSize: 13),
        filled: true,
        fillColor: _C.surface,
        contentPadding:
            const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(14),
          borderSide: const BorderSide(color: _C.border, width: 1.5),
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(14),
          borderSide: const BorderSide(color: _C.border, width: 1.5),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(14),
          borderSide: const BorderSide(color: _C.blue, width: 2),
        ),
      ),
    );
  }
}

// ─── Área de fotos ────────────────────────────────────────────────────────────
class _PhotoArea extends StatelessWidget {
  final List<XFile>      xFiles;
  final List<Uint8List?> webBytes;
  final Future<void> Function(ImageSource) onPick;
  final void Function(int) onRemove;

  const _PhotoArea({
    required this.xFiles,
    required this.webBytes,
    required this.onPick,
    required this.onRemove,
  });

  @override
  Widget build(BuildContext context) {
    return Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
      // Scroll horizontal de fotos ya seleccionadas
      if (xFiles.isNotEmpty) ...[
        SizedBox(
          height: 100,
          child: ListView.separated(
            scrollDirection: Axis.horizontal,
            itemCount: xFiles.length,
            separatorBuilder: (_, __) => const SizedBox(width: 10),
            itemBuilder: (_, i) => _Thumb(
              xFile: xFiles[i],
              bytes: webBytes[i],
              onRemove: () => onRemove(i),
            ),
          ),
        ),
        const SizedBox(height: 12),
      ],

      // Botones Cámara y Galería siempre visibles
      Row(children: [
        Expanded(
          child: _PhotoBtn(
            label   : 'Cámara',
            icon    : Icons.photo_camera_rounded,
            disabled: xFiles.length >= 3,
            onTap   : () => onPick(ImageSource.camera),
            primary : true,
          ),
        ),
        const SizedBox(width: 10),
        Expanded(
          child: _PhotoBtn(
            label   : 'Galería',
            icon    : Icons.photo_library_rounded,
            disabled: xFiles.length >= 3,
            onTap   : () => onPick(ImageSource.gallery),
            primary : false,
          ),
        ),
      ]),
    ]);
  }
}

// ─── Miniatura de foto ────────────────────────────────────────────────────────
class _Thumb extends StatelessWidget {
  final XFile      xFile;
  final Uint8List? bytes;
  final VoidCallback onRemove;
  const _Thumb({required this.xFile, required this.bytes, required this.onRemove});

  @override
  Widget build(BuildContext context) {
    return Stack(clipBehavior: Clip.none, children: [
      Container(
        width: 100, height: 100,
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(14),
          border: Border.all(color: _C.border, width: 1.5),
          boxShadow: [
            BoxShadow(color: Colors.black.withOpacity(0.06),
                blurRadius: 8, offset: const Offset(0, 2)),
          ],
        ),
        child: ClipRRect(
          borderRadius: BorderRadius.circular(12),
          child: kIsWeb && bytes != null
              ? Image.memory(bytes!, fit: BoxFit.cover)
              : Image.file(File(xFile.path), fit: BoxFit.cover),
        ),
      ),
      Positioned(
        top: -7, right: -7,
        child: GestureDetector(
          onTap: onRemove,
          child: Container(
            padding: const EdgeInsets.all(5),
            decoration: BoxDecoration(
              color: _C.danger,
              shape: BoxShape.circle,
              border: Border.all(color: Colors.white, width: 2),
              boxShadow: [BoxShadow(
                  color: _C.danger.withOpacity(0.35), blurRadius: 6)],
            ),
            child: const Icon(Icons.close_rounded,
                color: Colors.white, size: 12),
          ),
        ),
      ),
    ]);
  }
}

// ─── Botón de foto ────────────────────────────────────────────────────────────
class _PhotoBtn extends StatelessWidget {
  final String     label;
  final IconData   icon;
  final bool       disabled;
  final bool       primary;
  final VoidCallback onTap;
  const _PhotoBtn({
    required this.label, required this.icon,
    required this.disabled, required this.onTap,
    required this.primary,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: disabled ? null : onTap,
      child: Container(
        height: 50,
        decoration: BoxDecoration(
          color: disabled
              ? _C.bg
              : (primary ? _C.navy : _C.surface),
          borderRadius: BorderRadius.circular(13),
          border: Border.all(
            color: disabled ? _C.border : (primary ? _C.navy : _C.border),
            width: 1.5,
          ),
          boxShadow: disabled
              ? null
              : [BoxShadow(
                  color: Colors.black.withOpacity(0.06),
                  blurRadius: 8, offset: const Offset(0, 2))],
        ),
        child: Row(mainAxisAlignment: MainAxisAlignment.center, children: [
          Icon(icon,
              color: disabled
                  ? _C.border
                  : (primary ? Colors.white : _C.navy),
              size: 20),
          const SizedBox(width: 8),
          Text(label,
              style: TextStyle(
                  color: disabled
                      ? _C.border
                      : (primary ? Colors.white : _C.navy),
                  fontSize: 14,
                  fontWeight: FontWeight.w700)),
        ]),
      ),
    );
  }
}

// ─── Botón enviar ─────────────────────────────────────────────────────────────
class _SendBtn extends StatelessWidget {
  final bool         subiendo;
  final VoidCallback onPressed;
  const _SendBtn({required this.subiendo, required this.onPressed});

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: subiendo ? null : onPressed,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 200),
        width: double.infinity,
        height: 58,
        decoration: BoxDecoration(
          color: subiendo ? _C.danger.withOpacity(0.7) : _C.danger,
          borderRadius: BorderRadius.circular(16),
          boxShadow: subiendo
              ? []
              : [
                  BoxShadow(
                      color: _C.danger.withOpacity(0.35),
                      blurRadius: 16,
                      offset: const Offset(0, 6)),
                ],
        ),
        child: subiendo
            ? const Center(
                child: SizedBox(
                  width: 26, height: 26,
                  child: CircularProgressIndicator(
                      color: Colors.white, strokeWidth: 2.5),
                ),
              )
            : const Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(Icons.send_rounded, color: Colors.white, size: 22),
                  SizedBox(width: 10),
                  Text('ENVIAR REPORTE',
                      style: TextStyle(
                          color: Colors.white,
                          fontSize: 16,
                          fontWeight: FontWeight.w800,
                          letterSpacing: 0.6)),
                ],
              ),
      ),
    );
  }
}