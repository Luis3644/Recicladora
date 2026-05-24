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
import 'contenedores_operador_screen.dart';

// ─── Paleta recicladora ───────────────────────────────────────────────────────
class _C {
  static const bg        = Color(0xFFF0F4F8);
  static const surface   = Color(0xFFFFFFFF);
  static const navy      = Color(0xFF0F2754);
  static const navyMid   = Color(0xFF1A3A6B);
  static const navyLight = Color(0xFFE8EEF8);
  static const blue      = Color(0xFF1D4ED8);
  static const blueSoft  = Color(0xFFEFF6FF);
  static const danger    = Color(0xFFDC2626);
  static const dangerMid = Color(0xFFEF4444);
  static const dangerBg  = Color(0xFFFFF1F1);
  static const dangerBorder = Color(0xFFFECACA);
  static const success   = Color(0xFF059669);
  static const successBg = Color(0xFFECFDF5);
  static const amber     = Color(0xFFF59E0B);
  static const amberBg   = Color(0xFFFFFBEB);
  static const text      = Color(0xFF0F172A);
  static const textSub   = Color(0xFF475569);
  static const textMuted = Color(0xFF94A3B8);
  static const border    = Color(0xFFDDE3ED);
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

class _ReporteScreenState extends State<ReporteScreen>
    with TickerProviderStateMixin {
  final _desc   = TextEditingController();
  final _picker = ImagePicker();

  final List<XFile>      _xFiles   = [];
  final List<Uint8List?> _webBytes = [];

  bool _subiendo = false;

  late final AnimationController _shakeCtrl;
  late final Animation<double>   _shakeAnim;

  @override
  void initState() {
    super.initState();
    _shakeCtrl = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 400),
    );
    _shakeAnim = TweenSequence([
      TweenSequenceItem(tween: Tween(begin: 0.0, end: -8.0), weight: 1),
      TweenSequenceItem(tween: Tween(begin: -8.0, end: 8.0), weight: 2),
      TweenSequenceItem(tween: Tween(begin: 8.0, end: -6.0), weight: 2),
      TweenSequenceItem(tween: Tween(begin: -6.0, end: 6.0), weight: 2),
      TweenSequenceItem(tween: Tween(begin: 6.0, end: 0.0), weight: 1),
    ]).animate(CurvedAnimation(parent: _shakeCtrl, curve: Curves.easeInOut));
  }

  @override
  void dispose() {
    _desc.dispose();
    _shakeCtrl.dispose();
    super.dispose();
  }

  // ── Fotos ─────────────────────────────────────────────────────────────────
  Future<void> _pick(ImageSource src) async {
    if (_xFiles.length >= 3) {
      _snack('Máximo 3 fotos permitidas', isError: true);
      return;
    }
    final f = await _picker.pickImage(source: src, imageQuality: 70);
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

  // ── Enviar ────────────────────────────────────────────────────────────────
  Future<void> _enviar() async {
    final msg = _desc.text.trim();
    if (msg.isEmpty) {
      _shakeCtrl.forward(from: 0);
      _snack('Describe el problema antes de enviar', isError: true);
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
      await _enviarNotificacionAdmin(
        tipo: 'equipo',
        mensaje:
            'NUEVO REPORTE DE: ${widget.nombreUsuario} (Camión: ${widget.placas}) ha reportado: "$msg".',
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
        'mensaje'         : mensaje,
        'creadoEn'        : FieldValue.serverTimestamp(),
        'enviadoPor'      : widget.nombreUsuario,
        'destinoTipo'     : 'rol',
        'paraTodos'       : false,
        'destinatarioRol' : 'admin',
        'tipo'            : tipo,
        'leidoPor'        : <String, bool>{},
      });
    } catch (e) {
      debugPrint('Error notificación admin: $e');
    }
  }

  void _snack(String msg, {bool isError = false}) {
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(
      content: Row(children: [
        Icon(
          isError ? Icons.error_rounded : Icons.check_circle_rounded,
          color: Colors.white,
          size: 18,
        ),
        const SizedBox(width: 10),
        Expanded(
          child: Text(msg,
              style: const TextStyle(
                  fontWeight: FontWeight.w600, fontSize: 13)),
        ),
      ]),
      backgroundColor: isError ? _C.danger : _C.success,
      behavior: SnackBarBehavior.floating,
      margin: const EdgeInsets.fromLTRB(16, 0, 16, 16),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
      elevation: 8,
    ));
  }

  // ── Navegación ─────────────────────────────────────────────────────────────
  void _irAInicio() => Navigator.of(context).pushReplacement(MaterialPageRoute(
      builder: (_) => JornadaScreen(
          operador: widget.nombreUsuario,
          camion: widget.camion,
          placas: widget.placas)));

  void _irAHistorial() => Navigator.of(context).pushReplacement(MaterialPageRoute(
      builder: (_) => RegistrosJornadaScreen(
          operador: widget.nombreUsuario,
          camion: widget.camion,
          placas: widget.placas,
          historial: true)));

  void _irAContenedores() => Navigator.of(context).pushReplacement(MaterialPageRoute(
      builder: (_) => ContenedoresOperadorScreen(
          operador: widget.nombreUsuario,
          camion: widget.camion,
          placas: widget.placas)));

  void _irAPerfil() => Navigator.of(context).pushReplacement(MaterialPageRoute(
      builder: (_) => PerfilOperadorScreen(
          operador: widget.nombreUsuario,
          camion: widget.camion,
          placas: widget.placas)));

  // ── Build ──────────────────────────────────────────────────────────────────
  @override
  Widget build(BuildContext context) {
    return ConnectionWrapper(
      child: Scaffold(
        backgroundColor: _C.bg,
        appBar: _buildAppBar(),
        bottomNavigationBar: JornadaBottomBar(
          activeIndex   : -1,
          onInicio      : _irAInicio,
          onContenedores: _irAContenedores,
          onHistorial   : _irAHistorial,
          onPerfil      : _irAPerfil,
        ),
        body: SafeArea(
          child: SingleChildScrollView(
            physics: const ClampingScrollPhysics(),
            padding: const EdgeInsets.fromLTRB(16, 20, 16, 40),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // ── Tarjeta operador ─────────────────────────────
                _OperatorCard(
                  nombre: widget.nombreUsuario,
                  camion: widget.camion,
                  placas: widget.placas,
                ),
                const SizedBox(height: 16),

                // ── Banner alerta ─────────────────────────────────
                _AlertBanner(),
                const SizedBox(height: 22),

                // ── Sección: descripción ─────────────────────────
                _SectionHeader(
                  icon : Icons.edit_note_rounded,
                  label: '¿Qué está pasando?',
                  color: _C.navy,
                ),
                const SizedBox(height: 10),
                AnimatedBuilder(
                  animation: _shakeAnim,
                  builder: (_, child) => Transform.translate(
                    offset: Offset(_shakeAnim.value, 0),
                    child: child,
                  ),
                  child: _DescField(controller: _desc),
                ),
                const SizedBox(height: 22),

                // ── Sección: fotos ────────────────────────────────
                _SectionHeader(
                  icon : Icons.camera_alt_rounded,
                  label: 'Evidencia fotográfica',
                  color: _C.navy,
                  badge: '${_xFiles.length}/3',
                ),
                const SizedBox(height: 6),
                
                const SizedBox(height: 12),
                _PhotoArea(
                  xFiles  : _xFiles,
                  webBytes: _webBytes,
                  onPick  : _pick,
                  onRemove: _remove,
                ),
                const SizedBox(height: 28),

                // ── Botón enviar ──────────────────────────────────
                _SendBtn(subiendo: _subiendo, onPressed: _enviar),
                const SizedBox(height: 14),

                // ── Nota ──────────────────────────────────────────
                Center(
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: const [
                      Icon(Icons.lock_outline_rounded,
                          size: 12, color: _C.textMuted),
                      SizedBox(width: 5),
                      Text(
                        'Tu reporte es confidencial y llega al administrador',
                        style: TextStyle(color: _C.textMuted, fontSize: 11.5),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  PreferredSizeWidget _buildAppBar() {
    return AppBar(
      automaticallyImplyLeading: false,
      backgroundColor: _C.navy,
      elevation: 0,
      titleSpacing: 0,
      title: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 16),
        child: Row(children: [
          // Ícono de alerta con fondo rojo
          Container(
            width: 40,
            height: 40,
            decoration: BoxDecoration(
              color: _C.danger,
              borderRadius: BorderRadius.circular(12),
            ),
            child: const Icon(Icons.warning_amber_rounded,
                color: Colors.white, size: 22),
          ),
          const SizedBox(width: 12),
          const Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisSize: MainAxisSize.min,
            children: [
              Text('Reportar Incidente',
                  style: TextStyle(
                      color: Colors.white,
                      fontSize: 16,
                      fontWeight: FontWeight.w800,
                      letterSpacing: 0.2)),
              Text('Notificación inmediata al admin',
                  style: TextStyle(
                      color: Color(0xFF93B4D8),
                      fontSize: 11,
                      fontWeight: FontWeight.w500)),
            ],
          ),
        ]),
      ),
      bottom: PreferredSize(
        preferredSize: const Size.fromHeight(1),
        child: Container(height: 1, color: _C.navyMid.withOpacity(0.6)),
      ),
    );
  }
}

// ─── Tarjeta del operador ─────────────────────────────────────────────────────
class _OperatorCard extends StatelessWidget {
  final String nombre;
  final String camion;
  final String placas;
  const _OperatorCard({
    required this.nombre,
    required this.camion,
    required this.placas,
  });

  @override
  Widget build(BuildContext context) {
    final partes   = nombre.trim().split(' ');
    final iniciales = partes.length >= 2
        ? '${partes[0][0]}${partes[1][0]}'.toUpperCase()
        : nombre.substring(0, nombre.length.clamp(0, 2)).toUpperCase();

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: _C.navy,
        borderRadius: BorderRadius.circular(20),
        boxShadow: [
          BoxShadow(
              color: _C.navy.withOpacity(0.28),
              blurRadius: 18,
              offset: const Offset(0, 6)),
        ],
      ),
      child: Row(children: [
        // Avatar
        Container(
          width: 54,
          height: 54,
          decoration: BoxDecoration(
            color: Colors.white.withOpacity(0.12),
            borderRadius: BorderRadius.circular(15),
            border: Border.all(
                color: Colors.white.withOpacity(0.25), width: 1.5),
          ),
          child: Center(
            child: Text(iniciales,
                style: const TextStyle(
                    color: Colors.white,
                    fontSize: 20,
                    fontWeight: FontWeight.w800)),
          ),
        ),
        const SizedBox(width: 14),

        // Nombre y datos
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(nombre,
                  style: const TextStyle(
                      color: Colors.white,
                      fontSize: 16,
                      fontWeight: FontWeight.w800)),
              const SizedBox(height: 6),
              Row(children: [
                _DataChip(
                  icon: Icons.local_shipping_rounded,
                  label: camion,
                ),
                const SizedBox(width: 8),
                _DataChip(
                  icon: Icons.pin_rounded,
                  label: placas,
                ),
              ]),
            ],
          ),
        ),

        // Badge activo
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
          decoration: BoxDecoration(
            color: _C.success.withOpacity(0.18),
            borderRadius: BorderRadius.circular(20),
            border: Border.all(
                color: _C.success.withOpacity(0.4), width: 1),
          ),
          child: Row(mainAxisSize: MainAxisSize.min, children: [
            Container(
              width: 7, height: 7,
              decoration: const BoxDecoration(
                  color: Color(0xFF34D399), shape: BoxShape.circle),
            ),
            const SizedBox(width: 5),
            const Text('Activo',
                style: TextStyle(
                    color: Color(0xFF34D399),
                    fontSize: 11,
                    fontWeight: FontWeight.w700)),
          ]),
        ),
      ]),
    );
  }
}

class _DataChip extends StatelessWidget {
  final IconData icon;
  final String   label;
  const _DataChip({required this.icon, required this.label});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(
        color: Colors.white.withOpacity(0.10),
        borderRadius: BorderRadius.circular(8),
      ),
      child: Row(mainAxisSize: MainAxisSize.min, children: [
        Icon(icon, size: 12, color: const Color(0xFF93B4D8)),
        const SizedBox(width: 4),
        Text(label,
            style: const TextStyle(
                color: Color(0xFFCBDAEE),
                fontSize: 11.5,
                fontWeight: FontWeight.w600)),
      ]),
    );
  }
}

// ─── Banner de alerta ─────────────────────────────────────────────────────────
class _AlertBanner extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 13),
      decoration: BoxDecoration(
        color: _C.amberBg,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: _C.amber.withOpacity(0.35), width: 1.5),
      ),
      child: Row(children: [
        Container(
          padding: const EdgeInsets.all(8),
          decoration: BoxDecoration(
            color: _C.amber.withOpacity(0.15),
            borderRadius: BorderRadius.circular(10),
          ),
          child: const Icon(Icons.bolt_rounded, color: _C.amber, size: 18),
        ),
        const SizedBox(width: 12),
        const Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text('Envío inmediato',
                  style: TextStyle(
                      color: Color(0xFF92400E),
                      fontSize: 13,
                      fontWeight: FontWeight.w800)),
              SizedBox(height: 2),
              Text(
                'El administrador recibirá tu reporte en tiempo real.',
                style: TextStyle(
                    color: Color(0xFFB45309),
                    fontSize: 12,
                    height: 1.4,
                    fontWeight: FontWeight.w500),
              ),
            ],
          ),
        ),
      ]),
    );
  }
}

// ─── Encabezado de sección ────────────────────────────────────────────────────
class _SectionHeader extends StatelessWidget {
  final IconData icon;
  final String   label;
  final Color    color;
  final String?  badge;
  const _SectionHeader({
    required this.icon,
    required this.label,
    required this.color,
    this.badge,
  });

  @override
  Widget build(BuildContext context) {
    return Row(children: [
      Container(
        padding: const EdgeInsets.all(7),
        decoration: BoxDecoration(
          color: _C.navyLight,
          borderRadius: BorderRadius.circular(9),
        ),
        child: Icon(icon, size: 16, color: color),
      ),
      const SizedBox(width: 10),
      Text(label,
          style: TextStyle(
              color: color,
              fontSize: 14,
              fontWeight: FontWeight.w800)),
      if (badge != null) ...[
        const SizedBox(width: 8),
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
          decoration: BoxDecoration(
            color: _C.border,
            borderRadius: BorderRadius.circular(20),
          ),
          child: Text(badge!,
              style: const TextStyle(
                  color: _C.textSub,
                  fontSize: 11,
                  fontWeight: FontWeight.w700)),
        ),
      ],
    ]);
  }
}

class _SubLabel extends StatelessWidget {
  final String text;
  const _SubLabel({required this.text});
  @override
  Widget build(BuildContext context) => Padding(
    padding: const EdgeInsets.only(left: 2),
    child: Text(text,
        style: const TextStyle(
            color: _C.textMuted,
            fontSize: 12,
            fontWeight: FontWeight.w500)),
  );
}

// ─── Campo descripción ────────────────────────────────────────────────────────
class _DescField extends StatefulWidget {
  final TextEditingController controller;
  const _DescField({required this.controller});
  @override
  State<_DescField> createState() => _DescFieldState();
}

class _DescFieldState extends State<_DescField> {
  bool _focused = false;

  @override
  Widget build(BuildContext context) {
    return Focus(
      onFocusChange: (v) => setState(() => _focused = v),
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 200),
        decoration: BoxDecoration(
          color: _C.surface,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(
            color: _focused ? _C.navy : _C.border,
            width: _focused ? 2 : 1.5,
          ),
          boxShadow: _focused
              ? [BoxShadow(
                  color: _C.navy.withOpacity(0.10),
                  blurRadius: 12,
                  offset: const Offset(0, 4))]
              : [BoxShadow(
                  color: Colors.black.withOpacity(0.04),
                  blurRadius: 6,
                  offset: const Offset(0, 2))],
        ),
        child: Column(
          children: [
            // Cabecera del campo
            Container(
              padding: const EdgeInsets.fromLTRB(14, 11, 14, 11),
              decoration: BoxDecoration(
                color: _focused ? _C.navyLight : _C.bg,
                borderRadius: const BorderRadius.vertical(
                    top: Radius.circular(14)),
                border: Border(
                  bottom: BorderSide(
                    color: _focused ? _C.navy.withOpacity(0.15) : _C.border,
                    width: 1,
                  ),
                ),
              ),
              child: Row(children: [
                Icon(
                  Icons.chat_bubble_outline_rounded,
                  size: 14,
                  color: _focused ? _C.navy : _C.textMuted,
                ),
                const SizedBox(width: 7),
                Text(
                  'Descripción del incidente',
                  style: TextStyle(
                      fontSize: 11.5,
                      fontWeight: FontWeight.w700,
                      color: _focused ? _C.navy : _C.textMuted,
                      letterSpacing: 0.3),
                ),
              ]),
            ),
            // Área de texto
            TextField(
              controller: widget.controller,
              maxLines: 5,
              style: const TextStyle(
                  color: _C.text, fontSize: 14, height: 1.7),
              cursorColor: _C.navy,
              decoration: const InputDecoration(
                hintText:
                    'Escribe a qui...',
                hintStyle: TextStyle(
                    color: _C.textMuted,
                    fontSize: 13,
                    height: 1.6),
                filled: false,
                contentPadding: EdgeInsets.symmetric(
                    horizontal: 14, vertical: 14),
                border     : InputBorder.none,
                enabledBorder: InputBorder.none,
                focusedBorder: InputBorder.none,
              ),
            ),
          ],
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
      // Grid de fotos seleccionadas
      if (xFiles.isNotEmpty) ...[
        SizedBox(
          height: 108,
          child: ListView.separated(
            scrollDirection: Axis.horizontal,
            itemCount: xFiles.length,
            separatorBuilder: (_, __) => const SizedBox(width: 10),
            itemBuilder: (_, i) => _Thumb(
              xFile   : xFiles[i],
              bytes   : webBytes[i],
              index   : i + 1,
              onRemove: () => onRemove(i),
            ),
          ),
        ),
        const SizedBox(height: 14),
      ],

      // Botones cámara / galería
      Row(children: [
        Expanded(
          child: _PhotoBtn(
            label   : 'Cámara',
            icon    : Icons.photo_camera_rounded,
            sublabel: 'Tomar foto',
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
            sublabel: 'Elegir foto',
            disabled: xFiles.length >= 3,
            onTap   : () => onPick(ImageSource.gallery),
            primary : false,
          ),
        ),
      ]),
    ]);
  }
}

// ─── Miniatura ────────────────────────────────────────────────────────────────
class _Thumb extends StatelessWidget {
  final XFile      xFile;
  final Uint8List? bytes;
  final int        index;
  final VoidCallback onRemove;
  const _Thumb({
    required this.xFile,
    required this.bytes,
    required this.index,
    required this.onRemove,
  });

  @override
  Widget build(BuildContext context) {
    return Stack(clipBehavior: Clip.none, children: [
      Container(
        width: 108, height: 108,
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: _C.border, width: 1.5),
          boxShadow: [
            BoxShadow(color: Colors.black.withOpacity(0.08),
                blurRadius: 10, offset: const Offset(0, 3)),
          ],
        ),
        child: ClipRRect(
          borderRadius: BorderRadius.circular(14),
          child: kIsWeb && bytes != null
              ? Image.memory(bytes!, fit: BoxFit.cover)
              : Image.file(File(xFile.path), fit: BoxFit.cover),
        ),
      ),
      // Número de foto
      Positioned(
        left: 8, bottom: 8,
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 3),
          decoration: BoxDecoration(
            color: _C.navy.withOpacity(0.75),
            borderRadius: BorderRadius.circular(6),
          ),
          child: Text('Foto $index',
              style: const TextStyle(
                  color: Colors.white,
                  fontSize: 10,
                  fontWeight: FontWeight.w700)),
        ),
      ),
      // Botón eliminar
      Positioned(
        top: -6, right: -6,
        child: GestureDetector(
          onTap: onRemove,
          child: Container(
            padding: const EdgeInsets.all(5),
            decoration: BoxDecoration(
              color: _C.danger,
              shape: BoxShape.circle,
              border: Border.all(color: Colors.white, width: 2),
              boxShadow: [
                BoxShadow(color: _C.danger.withOpacity(0.4), blurRadius: 8),
              ],
            ),
            child: const Icon(Icons.close_rounded,
                color: Colors.white, size: 13),
          ),
        ),
      ),
    ]);
  }
}

// ─── Botón de foto ────────────────────────────────────────────────────────────
class _PhotoBtn extends StatelessWidget {
  final String     label;
  final String     sublabel;
  final IconData   icon;
  final bool       disabled;
  final bool       primary;
  final VoidCallback onTap;
  const _PhotoBtn({
    required this.label,
    required this.sublabel,
    required this.icon,
    required this.disabled,
    required this.onTap,
    required this.primary,
  });

  @override
  Widget build(BuildContext context) {
    final active = !disabled;
    return GestureDetector(
      onTap: active ? onTap : null,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 150),
        height: 62,
        decoration: BoxDecoration(
          color: disabled
              ? const Color(0xFFF8FAFC)
              : (primary ? _C.navy : _C.surface),
          borderRadius: BorderRadius.circular(14),
          border: Border.all(
            color: disabled
                ? _C.border
                : (primary ? _C.navy : _C.border),
            width: 1.5,
          ),
          boxShadow: disabled
              ? null
              : [
                  BoxShadow(
                    color: primary
                        ? _C.navy.withOpacity(0.20)
                        : Colors.black.withOpacity(0.06),
                    blurRadius: 10,
                    offset: const Offset(0, 3),
                  ),
                ],
        ),
        child: Row(mainAxisAlignment: MainAxisAlignment.center, children: [
          Container(
            padding: const EdgeInsets.all(7),
            decoration: BoxDecoration(
              color: disabled
                  ? _C.border.withOpacity(0.4)
                  : (primary
                      ? Colors.white.withOpacity(0.15)
                      : _C.navyLight),
              borderRadius: BorderRadius.circular(9),
            ),
            child: Icon(icon,
                color: disabled
                    ? _C.textMuted
                    : (primary ? Colors.white : _C.navy),
                size: 18),
          ),
          const SizedBox(width: 10),
          Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(label,
                  style: TextStyle(
                      color: disabled
                          ? _C.textMuted
                          : (primary ? Colors.white : _C.navy),
                      fontSize: 13,
                      fontWeight: FontWeight.w800)),
              Text(sublabel,
                  style: TextStyle(
                      color: disabled
                          ? _C.textMuted.withOpacity(0.6)
                          : (primary
                              ? Colors.white.withOpacity(0.65)
                              : _C.textSub),
                      fontSize: 11)),
            ],
          ),
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
        height: 60,
        decoration: BoxDecoration(
          color: subiendo ? _C.danger.withOpacity(0.75) : _C.danger,
          borderRadius: BorderRadius.circular(18),
          boxShadow: subiendo
              ? []
              : [
                  BoxShadow(
                      color: _C.danger.withOpacity(0.40),
                      blurRadius: 18,
                      offset: const Offset(0, 6)),
                  BoxShadow(
                      color: _C.danger.withOpacity(0.15),
                      blurRadius: 4,
                      offset: const Offset(0, 2)),
                ],
        ),
        child: subiendo
            ? const Center(
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    SizedBox(
                      width: 20, height: 20,
                      child: CircularProgressIndicator(
                          color: Colors.white, strokeWidth: 2.5),
                    ),
                    SizedBox(width: 12),
                    Text('Enviando reporte…',
                        style: TextStyle(
                            color: Colors.white,
                            fontSize: 14,
                            fontWeight: FontWeight.w700)),
                  ],
                ),
              )
            : const Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(Icons.send_rounded, color: Colors.white, size: 20),
                  SizedBox(width: 10),
                  Text('ENVIAR REPORTE',
                      style: TextStyle(
                          color: Colors.white,
                          fontSize: 16,
                          fontWeight: FontWeight.w800,
                          letterSpacing: 0.8)),
                ],
              ),
      ),
    );
  }
}