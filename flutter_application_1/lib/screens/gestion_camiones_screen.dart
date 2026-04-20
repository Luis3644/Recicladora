import 'dart:io';
import 'dart:typed_data';
import 'package:flutter/material.dart';
import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_storage/firebase_storage.dart';
import 'package:image_picker/image_picker.dart';

class GestionCamionesScreen extends StatefulWidget {
  const GestionCamionesScreen({super.key});

  @override
  State<GestionCamionesScreen> createState() => _GestionCamionesScreenState();
}

class _GestionCamionesScreenState extends State<GestionCamionesScreen>
    with SingleTickerProviderStateMixin {
  late AnimationController _controller;
  bool _contentVisible = false;

  static const Color _primary = Color(0xFF0F172A);
  static const Color _accent  = Color(0xFF06B6D4);
  static const Color _success = Color(0xFF10B981);
  static const Color _warning = Color(0xFFF59E0B);
  static const Color _danger  = Color(0xFFDC2626);
  static const Color _bgColor = Color(0xFFF0F9FF);
  static const Color _surface = Color(0xFFFFFFFF);
  static const Color _slate   = Color(0xFF64748B);

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
    super.dispose();
  }

  Future<void> _cambiarEstado(String camionId, String nuevoEstado) async {
    await FirebaseFirestore.instance
        .collection('camiones')
        .doc(camionId)
        .update({'estado': nuevoEstado});
  }

  Future<void> _eliminarCamion(String camionId, String tipo) async {
    final confirmar = await showDialog<bool>(
      context: context,
      builder: (_) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(18)),
        title: Row(
          children: [
            Container(
              padding: const EdgeInsets.all(8),
              decoration: BoxDecoration(
                color: _danger.withOpacity(0.1),
                borderRadius: BorderRadius.circular(10),
              ),
              child: const Icon(Icons.delete_outline_rounded,
                  color: _danger, size: 22),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Text('Eliminar "$tipo"',
                  style: const TextStyle(
                      fontSize: 15, fontWeight: FontWeight.w800)),
            ),
          ],
        ),
        content: const Text(
          'Esta acción no se puede deshacer.',
          style: TextStyle(fontSize: 13, color: _slate),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(false),
            child: const Text('Cancelar'),
          ),
          ElevatedButton(
            style: ElevatedButton.styleFrom(
              backgroundColor: _danger,
              foregroundColor: Colors.white,
              shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(10)),
            ),
            onPressed: () => Navigator.of(context).pop(true),
            child: const Text('Eliminar',
                style: TextStyle(fontWeight: FontWeight.w700)),
          ),
        ],
      ),
    ) ?? false;

    if (confirmar) {
      await FirebaseFirestore.instance
          .collection('camiones')
          .doc(camionId)
          .delete();
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: const Text('Camión eliminado'),
            backgroundColor: _success,
            behavior: SnackBarBehavior.floating,
            shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(12)),
          ),
        );
      }
    }
  }

  void _mostrarFormularioCamion(
      {String? camionId, Map<String, dynamic>? data}) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (_) => CamionFormScreen(camionId: camionId, data: data),
    );
  }

  Color _getEstadoColor(String estado) {
    switch (estado) {
      case 'Disponible':        return _success;
      case 'En Mantenimiento':  return _warning;
      case 'Fuera de Servicio': return _danger;
      default:                  return _accent;
    }
  }

  IconData _getEstadoIcon(String estado) {
    switch (estado) {
      case 'Disponible':        return Icons.check_circle_rounded;
      case 'En Mantenimiento':  return Icons.build_circle_rounded;
      case 'Fuera de Servicio': return Icons.cancel_rounded;
      default:                  return Icons.help_rounded;
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: _bgColor,
      appBar: AppBar(
        title: const Text(
          'Gestión de Camiones',
          style: TextStyle(fontWeight: FontWeight.w800, fontSize: 17),
        ),
        backgroundColor: Colors.transparent,
        elevation: 0,
        foregroundColor: Colors.white,
        flexibleSpace: Container(
          decoration: BoxDecoration(
            gradient: const LinearGradient(
              colors: [_primary, Color(0xFF1E293B)],
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
        actions: [
          Padding(
            padding: const EdgeInsets.only(right: 12),
            child: ElevatedButton.icon(
              style: ElevatedButton.styleFrom(
                backgroundColor: _accent,
                foregroundColor: Colors.white,
                elevation: 0,
                shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(20)),
                padding:
                    const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
              ),
              onPressed: () => _mostrarFormularioCamion(),
              icon: const Icon(Icons.add_rounded, size: 18),
              label: const Text('Agregar',
                  style: TextStyle(fontWeight: FontWeight.w700, fontSize: 13)),
            ),
          ),
        ],
      ),
      body: StreamBuilder<QuerySnapshot>(
        stream:
            FirebaseFirestore.instance.collection('camiones').snapshots(),
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) {
            return const Center(
                child: CircularProgressIndicator(color: _accent));
          }

          if (!snapshot.hasData || snapshot.data!.docs.isEmpty) {
            return Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Container(
                    padding: const EdgeInsets.all(24),
                    decoration: BoxDecoration(
                      color: _accent.withOpacity(0.08),
                      shape: BoxShape.circle,
                    ),
                    child: Icon(Icons.local_shipping_outlined,
                        size: 56, color: _accent.withOpacity(0.5)),
                  ),
                  const SizedBox(height: 16),
                  const Text('No hay camiones registrados',
                      style: TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.w700,
                          color: _primary)),
                  const SizedBox(height: 8),
                  Text('Toca "Agregar" para registrar el primero',
                      style: TextStyle(fontSize: 13, color: Colors.grey[500])),
                ],
              ),
            );
          }

          final camiones = snapshot.data!.docs;

          return AnimatedOpacity(
            opacity: _contentVisible ? 1 : 0,
            duration: const Duration(milliseconds: 600),
            child: ListView.builder(
              padding: const EdgeInsets.fromLTRB(16, 16, 16, 28),
              itemCount: camiones.length,
              itemBuilder: (context, index) {
                final doc  = camiones[index];
                final data = doc.data() as Map<String, dynamic>;
                final camionId = doc.id;
                final tipo   = data['tipo']   ?? 'Sin tipo';
                final modelo = data['modelo'] ?? '—';
                final placas = data['placas'] ?? '—';
                final foto   = data['foto']   ?? '';
                final estado = data['estado'] ?? 'Disponible';
                final estadoColor = _getEstadoColor(estado);

                return TweenAnimationBuilder<double>(
                  tween: Tween(begin: 0.0, end: 1.0),
                  duration: Duration(milliseconds: 300 + index * 80),
                  curve: Curves.easeOutCubic,
                  builder: (context, value, child) => Transform.translate(
                    offset: Offset(0, 20 * (1 - value)),
                    child: Opacity(opacity: value, child: child),
                  ),
                  child: Container(
                    margin: const EdgeInsets.only(bottom: 12),
                    decoration: BoxDecoration(
                      color: _surface,
                      borderRadius: BorderRadius.circular(16),
                      border: Border.all(color: const Color(0xFFE2E8F0)),
                      boxShadow: [
                        BoxShadow(
                          color: _primary.withOpacity(0.06),
                          blurRadius: 12,
                          offset: const Offset(0, 4),
                        ),
                      ],
                    ),
                    child: ClipRRect(
                      borderRadius: BorderRadius.circular(16),
                      child: IntrinsicHeight(
                        child: Row(
                          crossAxisAlignment: CrossAxisAlignment.stretch,
                          children: [
                            // Barra lateral de color
                            Container(width: 4, color: estadoColor),

                            // Foto cuadrada
                            if (foto.isNotEmpty)
                              SizedBox(
                                width: 90,
                                child: Image.network(
                                  foto,
                                  fit: BoxFit.cover,
                                  errorBuilder: (_, __, ___) => Container(
                                    width: 90,
                                    color: Colors.grey[100],
                                    child: Icon(Icons.broken_image_rounded,
                                        color: Colors.grey[400], size: 28),
                                  ),
                                ),
                              )
                            else
                              Container(
                                width: 90,
                                color: _accent.withOpacity(0.07),
                                child: Icon(Icons.local_shipping_rounded,
                                    color: _accent.withOpacity(0.4), size: 32),
                              ),

                            // Info
                            Expanded(
                              child: Padding(
                                padding: const EdgeInsets.fromLTRB(12, 10, 8, 10),
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    // Tipo + badge estado
                                    Row(
                                      children: [
                                        Expanded(
                                          child: Text(
                                            tipo,
                                            style: const TextStyle(
                                              fontSize: 15,
                                              fontWeight: FontWeight.w800,
                                              color: _primary,
                                            ),
                                            overflow: TextOverflow.ellipsis,
                                          ),
                                        ),
                                        Container(
                                          padding: const EdgeInsets.symmetric(
                                              horizontal: 7, vertical: 3),
                                          decoration: BoxDecoration(
                                            color:
                                                estadoColor.withOpacity(0.1),
                                            borderRadius:
                                                BorderRadius.circular(6),
                                            border: Border.all(
                                                color: estadoColor
                                                    .withOpacity(0.25)),
                                          ),
                                          child: Row(
                                            mainAxisSize: MainAxisSize.min,
                                            children: [
                                              Icon(_getEstadoIcon(estado),
                                                  size: 10,
                                                  color: estadoColor),
                                              const SizedBox(width: 3),
                                              Text(
                                                estado,
                                                style: TextStyle(
                                                  fontSize: 9,
                                                  fontWeight: FontWeight.w800,
                                                  color: estadoColor,
                                                  letterSpacing: 0.3,
                                                ),
                                              ),
                                            ],
                                          ),
                                        ),
                                      ],
                                    ),
                                    const SizedBox(height: 4),
                                    // Modelo y placas en una línea
                                    Row(
                                      children: [
                                        Icon(Icons.build_rounded,
                                            size: 11, color: _slate),
                                        const SizedBox(width: 3),
                                        Text(modelo,
                                            style: TextStyle(
                                                fontSize: 11, color: _slate)),
                                        const SizedBox(width: 10),
                                        Icon(Icons.pin_rounded,
                                            size: 11, color: _accent),
                                        const SizedBox(width: 3),
                                        Text(placas,
                                            style: const TextStyle(
                                                fontSize: 11,
                                                color: _accent,
                                                fontWeight: FontWeight.w600)),
                                      ],
                                    ),
                                    const SizedBox(height: 8),
                                    // Dropdown estado + botones
                                    Row(
                                      children: [
                                        Expanded(
                                          child: SizedBox(
                                            height: 32,
                                            child: DropdownButtonFormField<
                                                String>(
                                              value: [
                                                'Disponible',
                                                'En Mantenimiento',
                                                'Fuera de Servicio'
                                              ].contains(estado)
                                                  ? estado
                                                  : 'Disponible',
                                              isDense: true,
                                              decoration: InputDecoration(
                                                contentPadding:
                                                    const EdgeInsets.symmetric(
                                                        horizontal: 10,
                                                        vertical: 0),
                                                border: OutlineInputBorder(
                                                  borderRadius:
                                                      BorderRadius.circular(8),
                                                  borderSide: BorderSide(
                                                      color: Colors.grey
                                                          .shade300),
                                                ),
                                                enabledBorder:
                                                    OutlineInputBorder(
                                                  borderRadius:
                                                      BorderRadius.circular(8),
                                                  borderSide: BorderSide(
                                                      color: Colors.grey
                                                          .shade300),
                                                ),
                                              ),
                                              style: const TextStyle(
                                                  fontSize: 11,
                                                  color: _primary,
                                                  fontWeight: FontWeight.w600),
                                              items: const [
                                                DropdownMenuItem(
                                                    value: 'Disponible',
                                                    child:
                                                        Text('Disponible')),
                                                DropdownMenuItem(
                                                    value: 'En Mantenimiento',
                                                    child: Text(
                                                        'Mantenimiento')),
                                                DropdownMenuItem(
                                                    value: 'Fuera de Servicio',
                                                    child: Text('Fuera srv.')),
                                              ],
                                              onChanged: (value) {
                                                if (value != null) {
                                                  _cambiarEstado(
                                                      camionId, value);
                                                }
                                              },
                                            ),
                                          ),
                                        ),
                                        const SizedBox(width: 6),
                                        // Editar
                                        GestureDetector(
                                          onTap: () =>
                                              _mostrarFormularioCamion(
                                                  camionId: camionId,
                                                  data: data),
                                          child: Container(
                                            padding: const EdgeInsets.all(7),
                                            decoration: BoxDecoration(
                                              color:
                                                  _accent.withOpacity(0.1),
                                              borderRadius:
                                                  BorderRadius.circular(8),
                                            ),
                                            child: const Icon(
                                                Icons.edit_rounded,
                                                size: 16,
                                                color: _accent),
                                          ),
                                        ),
                                        const SizedBox(width: 4),
                                        // Eliminar
                                        GestureDetector(
                                          onTap: () =>
                                              _eliminarCamion(camionId, tipo),
                                          child: Container(
                                            padding: const EdgeInsets.all(7),
                                            decoration: BoxDecoration(
                                              color:
                                                  _danger.withOpacity(0.1),
                                              borderRadius:
                                                  BorderRadius.circular(8),
                                            ),
                                            child: const Icon(
                                                Icons.delete_rounded,
                                                size: 16,
                                                color: _danger),
                                          ),
                                        ),
                                      ],
                                    ),
                                  ],
                                ),
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                  ),
                );
              },
            ),
          );
        },
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// Formulario Agregar / Editar Camión
// ─────────────────────────────────────────────────────────────────────────────
class CamionFormScreen extends StatefulWidget {
  final String? camionId;
  final Map<String, dynamic>? data;
  const CamionFormScreen({super.key, this.camionId, this.data});

  @override
  State<CamionFormScreen> createState() => _CamionFormScreenState();
}

class _CamionFormScreenState extends State<CamionFormScreen> {
  final _formKey    = GlobalKey<FormState>();
  final _tipoCtrl   = TextEditingController();
  final _modeloCtrl = TextEditingController();
  final _placasCtrl = TextEditingController();
  final _fotoCtrl   = TextEditingController(); // URL manual (opcional)

  String  _estado            = 'Disponible';
  bool    _guardando         = false;
  bool    _subiendoFoto      = false;

  // Imagen seleccionada de galería
  File?       _imagenArchivo;    // Android/iOS
  Uint8List?  _imagenBytes;      // Web
  String?     _imagenPreviewUrl; // URL subida a Storage

  static const Color _primary = Color(0xFF0F172A);
  static const Color _accent  = Color(0xFF06B6D4);
  static const Color _success = Color(0xFF10B981);
  static const Color _slate   = Color(0xFF64748B);

  @override
  void initState() {
    super.initState();
    if (widget.data != null) {
      _tipoCtrl.text   = widget.data!['tipo']   ?? '';
      _modeloCtrl.text = widget.data!['modelo'] ?? '';
      _placasCtrl.text = widget.data!['placas'] ?? '';
      _fotoCtrl.text   = widget.data!['foto']   ?? '';
      _estado          = widget.data!['estado'] ?? 'Disponible';
      _imagenPreviewUrl = widget.data!['foto']?.toString();
    }
  }

  @override
  void dispose() {
    _tipoCtrl.dispose();
    _modeloCtrl.dispose();
    _placasCtrl.dispose();
    _fotoCtrl.dispose();
    super.dispose();
  }

  // ── Seleccionar imagen de galería ─────────────────────────────────────────
  Future<void> _seleccionarImagen() async {
    final picker = ImagePicker();
    final picked = await picker.pickImage(
        source: ImageSource.gallery, imageQuality: 80);
    if (picked == null) return;

    setState(() => _subiendoFoto = true);

    try {
      final nombreArchivo =
          'camiones/${DateTime.now().millisecondsSinceEpoch}.jpg';
      final ref = FirebaseStorage.instance.ref().child(nombreArchivo);

      if (kIsWeb) {
        final bytes = await picked.readAsBytes();
        await ref.putData(bytes);
        setState(() => _imagenBytes = bytes);
      } else {
        final file = File(picked.path);
        await ref.putFile(file);
        setState(() => _imagenArchivo = file);
      }

      final url = await ref.getDownloadURL();
      setState(() {
        _imagenPreviewUrl = url;
        _fotoCtrl.text    = url; // guarda la URL en el campo
      });
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Error al subir imagen: $e'),
            backgroundColor: Colors.red,
          ),
        );
      }
    } finally {
      if (mounted) setState(() => _subiendoFoto = false);
    }
  }

  // ── Guardar camión en Firestore con TODOS los campos ──────────────────────
  Future<void> _guardar() async {
    if (!_formKey.currentState!.validate()) return;
    setState(() => _guardando = true);

    // Determinar URL final de la foto
    final fotoUrl = _imagenPreviewUrl ?? _fotoCtrl.text.trim();

    final data = {
      'tipo':               _tipoCtrl.text.trim(),
      'modelo':             _modeloCtrl.text.trim(),
      'placas':             _placasCtrl.text.trim(),
      'foto':               fotoUrl,
      'estado':             _estado,
      // Campos extra que existen en tu base de datos
      'activo':             true,
      'ocupado':            false,
      'operador':           '',
      'capacidad_toneladas': 0,
    };

    try {
      if (widget.camionId != null) {
        // Editar — no sobreescribe ocupado/operador si ya tienen valor
        await FirebaseFirestore.instance
            .collection('camiones')
            .doc(widget.camionId)
            .update({
          'tipo':    data['tipo'],
          'modelo':  data['modelo'],
          'placas':  data['placas'],
          'foto':    data['foto'],
          'estado':  data['estado'],
          'activo':  true,
        });
      } else {
        // Nuevo camión — todos los campos
        await FirebaseFirestore.instance.collection('camiones').add(data);
      }

      if (mounted) {
        Navigator.of(context).pop();
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(widget.camionId != null
                ? 'Camión actualizado correctamente'
                : 'Camión agregado correctamente'),
            backgroundColor: _success,
            behavior: SnackBarBehavior.floating,
            shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(12)),
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Error: $e'),
            backgroundColor: Colors.red,
          ),
        );
      }
    } finally {
      if (mounted) setState(() => _guardando = false);
    }
  }

  // ── Preview de la imagen ──────────────────────────────────────────────────
  Widget _buildImagenPreview() {
    return GestureDetector(
      onTap: _seleccionarImagen,
      child: Container(
        height: 140,
        width: double.infinity,
        decoration: BoxDecoration(
          color: const Color(0xFFF8FAFC),
          borderRadius: BorderRadius.circular(14),
          border: Border.all(
            color: _subiendoFoto
                ? _accent
                : const Color(0xFFE2E8F0),
            width: _subiendoFoto ? 2 : 1,
          ),
        ),
        child: _subiendoFoto
            ? const Center(
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    CircularProgressIndicator(color: _accent),
                    SizedBox(height: 10),
                    Text('Subiendo imagen...',
                        style: TextStyle(fontSize: 12, color: _slate)),
                  ],
                ),
              )
            : _imagenPreviewUrl != null && _imagenPreviewUrl!.isNotEmpty
                ? Stack(
                    children: [
                      ClipRRect(
                        borderRadius: BorderRadius.circular(13),
                        child: _imagenArchivo != null && !kIsWeb
                            ? Image.file(_imagenArchivo!,
                                width: double.infinity,
                                height: 140,
                                fit: BoxFit.cover)
                            : _imagenBytes != null && kIsWeb
                                ? Image.memory(_imagenBytes!,
                                    width: double.infinity,
                                    height: 140,
                                    fit: BoxFit.cover)
                                : Image.network(_imagenPreviewUrl!,
                                    width: double.infinity,
                                    height: 140,
                                    fit: BoxFit.cover),
                      ),
                      Positioned(
                        bottom: 8,
                        right: 8,
                        child: Container(
                          padding: const EdgeInsets.symmetric(
                              horizontal: 10, vertical: 5),
                          decoration: BoxDecoration(
                            color: Colors.black54,
                            borderRadius: BorderRadius.circular(8),
                          ),
                          child: const Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Icon(Icons.edit_rounded,
                                  color: Colors.white, size: 12),
                              SizedBox(width: 4),
                              Text('Cambiar',
                                  style: TextStyle(
                                      color: Colors.white, fontSize: 11)),
                            ],
                          ),
                        ),
                      ),
                    ],
                  )
                : Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Icon(Icons.add_photo_alternate_rounded,
                          size: 36, color: _accent.withOpacity(0.6)),
                      const SizedBox(height: 8),
                      const Text('Toca para subir foto',
                          style: TextStyle(
                              fontSize: 13,
                              color: _slate,
                              fontWeight: FontWeight.w600)),
                      const SizedBox(height: 4),
                      Text('Desde tu galería',
                          style: TextStyle(
                              fontSize: 11, color: Colors.grey[400])),
                    ],
                  ),
      ),
    );
  }

  InputDecoration _inputDec(String label, IconData icon) {
    return InputDecoration(
      labelText: label,
      prefixIcon: Icon(icon, size: 18),
      filled: true,
      fillColor: const Color(0xFFF8FAFC),
      contentPadding:
          const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
      border: OutlineInputBorder(
        borderRadius: BorderRadius.circular(12),
        borderSide: const BorderSide(color: Color(0xFFE2E8F0)),
      ),
      enabledBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(12),
        borderSide: const BorderSide(color: Color(0xFFE2E8F0)),
      ),
      focusedBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(12),
        borderSide: const BorderSide(color: _accent, width: 1.5),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      height: MediaQuery.of(context).size.height * 0.92,
      decoration: const BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      child: Column(
        children: [
          // Handle
          Container(
            margin: const EdgeInsets.only(top: 12),
            width: 40,
            height: 4,
            decoration: BoxDecoration(
              color: Colors.grey[300],
              borderRadius: BorderRadius.circular(4),
            ),
          ),
          // Título
          Padding(
            padding: const EdgeInsets.fromLTRB(20, 16, 20, 0),
            child: Row(
              children: [
                Container(
                  padding: const EdgeInsets.all(8),
                  decoration: BoxDecoration(
                    color: _accent.withOpacity(0.1),
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: Icon(
                    widget.camionId != null
                        ? Icons.edit_rounded
                        : Icons.add_rounded,
                    color: _accent,
                    size: 20,
                  ),
                ),
                const SizedBox(width: 12),
                Text(
                  widget.camionId != null ? 'Editar Camión' : 'Agregar Camión',
                  style: const TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.w800,
                    color: _primary,
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 4),
          const Divider(height: 20, color: Color(0xFFE2E8F0)),

          // Formulario
          Expanded(
            child: SingleChildScrollView(
              padding: const EdgeInsets.fromLTRB(20, 4, 20, 20),
              child: Form(
                key: _formKey,
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // Imagen
                    const Text('FOTO DEL CAMIÓN',
                        style: TextStyle(
                            fontSize: 10,
                            fontWeight: FontWeight.w800,
                            color: _slate,
                            letterSpacing: 0.8)),
                    const SizedBox(height: 8),
                    _buildImagenPreview(),
                    const SizedBox(height: 16),

                    // Tipo
                    TextFormField(
                      controller: _tipoCtrl,
                      decoration: _inputDec(
                          'Tipo de camión', Icons.local_shipping_rounded),
                      validator: (v) =>
                          (v?.isEmpty ?? true) ? 'Campo requerido' : null,
                    ),
                    const SizedBox(height: 12),

                    // Modelo
                    TextFormField(
                      controller: _modeloCtrl,
                      decoration:
                          _inputDec('Modelo / Año', Icons.build_rounded),
                      validator: (v) =>
                          (v?.isEmpty ?? true) ? 'Campo requerido' : null,
                    ),
                    const SizedBox(height: 12),

                    // Placas
                    TextFormField(
                      controller: _placasCtrl,
                      textCapitalization: TextCapitalization.characters,
                      decoration: _inputDec('Placas', Icons.pin_rounded),
                      validator: (v) =>
                          (v?.isEmpty ?? true) ? 'Campo requerido' : null,
                    ),
                    const SizedBox(height: 12),

                    // Estado
                    DropdownButtonFormField<String>(
                      value: _estado,
                      decoration:
                          _inputDec('Estado', Icons.flag_rounded),
                      items: const [
                        DropdownMenuItem(
                            value: 'Disponible',
                            child: Text('Disponible')),
                        DropdownMenuItem(
                            value: 'En Mantenimiento',
                            child: Text('En Mantenimiento')),
                        DropdownMenuItem(
                            value: 'Fuera de Servicio',
                            child: Text('Fuera de Servicio')),
                      ],
                      onChanged: (v) => setState(() => _estado = v!),
                    ),
                    const SizedBox(height: 24),

                    // Botón guardar
                    SizedBox(
                      width: double.infinity,
                      height: 52,
                      child: ElevatedButton.icon(
                        style: ElevatedButton.styleFrom(
                          backgroundColor: _success,
                          foregroundColor: Colors.white,
                          elevation: 2,
                          shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(14)),
                        ),
                        onPressed: _guardando ? null : _guardar,
                        icon: _guardando
                            ? const SizedBox(
                                width: 20,
                                height: 20,
                                child: CircularProgressIndicator(
                                    color: Colors.white, strokeWidth: 2.5))
                            : const Icon(Icons.save_rounded),
                        label: Text(
                          _guardando
                              ? 'Guardando...'
                              : widget.camionId != null
                                  ? 'ACTUALIZAR CAMIÓN'
                                  : 'GUARDAR CAMIÓN',
                          style: const TextStyle(
                              fontSize: 15, fontWeight: FontWeight.w700),
                        ),
                      ),
                    ),
                    const SizedBox(height: 10),

                    // Cancelar
                    SizedBox(
                      width: double.infinity,
                      child: TextButton(
                        onPressed: () => Navigator.of(context).pop(),
                        child: const Text('Cancelar',
                            style: TextStyle(color: _slate)),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}