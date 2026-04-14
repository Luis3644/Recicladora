import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';

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
  static const Color _accent = Color(0xFF06B6D4);
  static const Color _success = Color(0xFF10B981);
  static const Color _warning = Color(0xFFF59E0B);
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
        title: const Text('Eliminar Camión'),
        content: Text('¿Eliminar el camión "$tipo"? Esta acción no se puede deshacer.'),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(false),
            child: const Text('Cancelar'),
          ),
          ElevatedButton(
            style: ElevatedButton.styleFrom(backgroundColor: _danger),
            onPressed: () => Navigator.of(context).pop(true),
            child: const Text('Eliminar'),
          ),
        ],
      ),
    ) ?? false;

    if (confirmar) {
      await FirebaseFirestore.instance.collection('camiones').doc(camionId).delete();
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Camión eliminado')),
        );
      }
    }
  }

  void _mostrarFormularioCamion({String? camionId, Map<String, dynamic>? data}) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (_) => CamionFormScreen(
        camionId: camionId,
        data: data,
      ),
    );
  }

  Color _getEstadoColor(String estado) {
    switch (estado) {
      case 'Disponible':
        return _success;
      case 'En Mantenimiento':
        return _warning;
      case 'Fuera de Servicio':
        return _danger;
      default:
        return _accent;
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: _bgColor,
      appBar: AppBar(
        title: const Text(
          "Gestión de Camiones",
          style: TextStyle(fontWeight: FontWeight.w700, letterSpacing: 0.3),
        ),
        backgroundColor: Colors.transparent,
        elevation: 0,
        foregroundColor: Colors.white,
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
        actions: [
          IconButton(
            icon: const Icon(Icons.add_rounded),
            onPressed: () => _mostrarFormularioCamion(),
            tooltip: 'Agregar Camión',
          ),
        ],
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
          StreamBuilder<QuerySnapshot>(
            stream: FirebaseFirestore.instance.collection('camiones').snapshots(),
            builder: (context, snapshot) {
              if (snapshot.connectionState == ConnectionState.waiting) {
                return const Center(
                  child: CircularProgressIndicator(color: _accent),
                );
              }

              if (!snapshot.hasData || snapshot.data!.docs.isEmpty) {
                return Center(
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Icon(
                        Icons.local_shipping,
                        size: 80,
                        color: Colors.grey[300],
                      ),
                      const SizedBox(height: 16),
                      Text(
                        'No hay camiones registrados',
                        style: TextStyle(
                          color: Colors.grey[600],
                          fontSize: 16,
                          fontWeight: FontWeight.w500,
                        ),
                      ),
                      const SizedBox(height: 24),
                      ElevatedButton.icon(
                        style: ElevatedButton.styleFrom(
                          backgroundColor: _accent,
                          foregroundColor: Colors.white,
                        ),
                        onPressed: () => _mostrarFormularioCamion(),
                        icon: const Icon(Icons.add),
                        label: const Text('Agregar Primer Camión'),
                      ),
                    ],
                  ),
                );
              }

              final camiones = snapshot.data!.docs;

              return AnimatedOpacity(
                opacity: _contentVisible ? 1 : 0,
                duration: const Duration(milliseconds: 600),
                child: ListView.builder(
                  padding: const EdgeInsets.all(20),
                  itemCount: camiones.length,
                  itemBuilder: (context, index) {
                    final doc = camiones[index];
                    final data = doc.data() as Map<String, dynamic>;
                    final camionId = doc.id;
                    final tipo = data['tipo'] ?? 'Sin tipo';
                    final modelo = data['modelo'] ?? 'Sin modelo';
                    final placas = data['placas'] ?? 'Sin placas';
                    final foto = data['foto'] ?? '';
                    final estado = data['estado'] ?? 'Disponible';

                    return TweenAnimationBuilder<double>(
                      tween: Tween(begin: 0.0, end: 1.0),
                      duration: Duration(milliseconds: 400 + index * 100),
                      builder: (context, value, child) {
                        return Transform.translate(
                          offset: Offset(0, 50 * (1 - value)),
                          child: Opacity(opacity: value, child: child),
                        );
                      },
                      child: Container(
                        margin: const EdgeInsets.only(bottom: 16),
                        decoration: BoxDecoration(
                          gradient: LinearGradient(
                            colors: [
                              Colors.white.withOpacity(0.9),
                              Colors.white.withOpacity(0.7),
                            ],
                            begin: Alignment.topLeft,
                            end: Alignment.bottomRight,
                          ),
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
                          children: [
                            // Imagen del camión
                            if (foto.isNotEmpty)
                              ClipRRect(
                                borderRadius: const BorderRadius.vertical(
                                  top: Radius.circular(16),
                                ),
                                child: Image.network(
                                  foto,
                                  height: 120,
                                  width: double.infinity,
                                  fit: BoxFit.cover,
                                  errorBuilder: (context, error, stackTrace) {
                                    return Container(
                                      height: 120,
                                      color: Colors.grey[200],
                                      child: const Icon(
                                        Icons.broken_image,
                                        size: 40,
                                        color: Colors.grey,
                                      ),
                                    );
                                  },
                                ),
                              ),

                            Padding(
                              padding: const EdgeInsets.all(16),
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Row(
                                    children: [
                                      Expanded(
                                        child: Text(
                                          tipo,
                                          style: const TextStyle(
                                            fontSize: 18,
                                            fontWeight: FontWeight.w700,
                                            color: _primary,
                                          ),
                                        ),
                                      ),
                                      Container(
                                        padding: const EdgeInsets.symmetric(
                                          horizontal: 8,
                                          vertical: 4,
                                        ),
                                        decoration: BoxDecoration(
                                          color: _getEstadoColor(estado).withOpacity(0.15),
                                          borderRadius: BorderRadius.circular(12),
                                          border: Border.all(
                                            color: _getEstadoColor(estado).withOpacity(0.3),
                                          ),
                                        ),
                                        child: Text(
                                          estado,
                                          style: TextStyle(
                                            fontSize: 12,
                                            fontWeight: FontWeight.w600,
                                            color: _getEstadoColor(estado),
                                          ),
                                        ),
                                      ),
                                    ],
                                  ),
                                  const SizedBox(height: 8),
                                  Text(
                                    'Modelo: $modelo',
                                    style: TextStyle(
                                      color: _primary.withOpacity(0.7),
                                      fontSize: 14,
                                    ),
                                  ),
                                  const SizedBox(height: 4),
                                  Text(
                                    'Placas: $placas',
                                    style: TextStyle(
                                      color: _primary.withOpacity(0.7),
                                      fontSize: 14,
                                    ),
                                  ),
                                  const SizedBox(height: 16),
                                  Row(
                                    children: [
                                      Expanded(
                                        child: DropdownButtonFormField<String>(
                                          value: ['Disponible', 'En Mantenimiento', 'Fuera de Servicio'].contains(estado) ? estado : 'Disponible',
                                          decoration: InputDecoration(
                                            labelText: 'Cambiar Estado',
                                            border: OutlineInputBorder(
                                              borderRadius: BorderRadius.circular(8),
                                            ),
                                            contentPadding: const EdgeInsets.symmetric(
                                              horizontal: 12,
                                              vertical: 8,
                                            ),
                                          ),
                                          items: const [
                                            DropdownMenuItem(
                                              value: 'Disponible',
                                              child: Text('Disponible'),
                                            ),
                                            DropdownMenuItem(
                                              value: 'En Mantenimiento',
                                              child: Text('En Mantenimiento'),
                                            ),
                                            DropdownMenuItem(
                                              value: 'Fuera de Servicio',
                                              child: Text('Fuera de Servicio'),
                                            ),
                                          ],
                                          onChanged: (value) {
                                            if (value != null) {
                                              _cambiarEstado(camionId, value);
                                            }
                                          },
                                        ),
                                      ),
                                      const SizedBox(width: 8),
                                      IconButton(
                                        icon: const Icon(Icons.edit_rounded),
                                        color: _accent,
                                        onPressed: () => _mostrarFormularioCamion(
                                          camionId: camionId,
                                          data: data,
                                        ),
                                        tooltip: 'Editar',
                                      ),
                                      IconButton(
                                        icon: const Icon(Icons.delete_rounded),
                                        color: _danger,
                                        onPressed: () => _eliminarCamion(camionId, tipo),
                                        tooltip: 'Eliminar',
                                      ),
                                    ],
                                  ),
                                ],
                              ),
                            ),
                          ],
                        ),
                      ),
                    );
                  },
                ),
              );
            },
          ),
        ],
      ),
    );
  }
}

class CamionFormScreen extends StatefulWidget {
  final String? camionId;
  final Map<String, dynamic>? data;

  const CamionFormScreen({super.key, this.camionId, this.data});

  @override
  State<CamionFormScreen> createState() => _CamionFormScreenState();
}

class _CamionFormScreenState extends State<CamionFormScreen> {
  final _formKey = GlobalKey<FormState>();
  final _tipoController = TextEditingController();
  final _modeloController = TextEditingController();
  final _placasController = TextEditingController();
  final _fotoController = TextEditingController();
  String _estado = 'Disponible';

  static const Color _primary = Color(0xFF0F172A);
  static const Color _accent = Color(0xFF06B6D4);
  static const Color _success = Color(0xFF10B981);
  static const Color _danger = Color(0xFFDC2626);

  @override
  void initState() {
    super.initState();
    if (widget.data != null) {
      _tipoController.text = widget.data!['tipo'] ?? '';
      _modeloController.text = widget.data!['modelo'] ?? '';
      _placasController.text = widget.data!['placas'] ?? '';
      _fotoController.text = widget.data!['foto'] ?? '';
      _estado = widget.data!['estado'] ?? 'Disponible';
    }
  }

  @override
  void dispose() {
    _tipoController.dispose();
    _modeloController.dispose();
    _placasController.dispose();
    _fotoController.dispose();
    super.dispose();
  }

  Future<void> _guardarCamion() async {
    if (!_formKey.currentState!.validate()) return;

    final data = {
      'tipo': _tipoController.text.trim(),
      'modelo': _modeloController.text.trim(),
      'placas': _placasController.text.trim(),
      'foto': _fotoController.text.trim(),
      'estado': _estado,
    };

    try {
      if (widget.camionId != null) {
        await FirebaseFirestore.instance
            .collection('camiones')
            .doc(widget.camionId)
            .update(data);
      } else {
        await FirebaseFirestore.instance.collection('camiones').add(data);
      }

      if (mounted) {
        Navigator.of(context).pop();
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              widget.camionId != null ? 'Camión actualizado' : 'Camión agregado',
            ),
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error: $e')),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      height: MediaQuery.of(context).size.height * 0.9,
      decoration: const BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      child: Column(
        children: [
          const SizedBox(height: 12),
          Container(
            width: 52,
            height: 5,
            decoration: BoxDecoration(
              color: Colors.grey[300],
              borderRadius: BorderRadius.circular(10),
            ),
          ),
          const SizedBox(height: 16),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 20),
            child: Text(
              widget.camionId != null ? 'Editar Camión' : 'Agregar Camión',
              style: const TextStyle(
                fontSize: 20,
                fontWeight: FontWeight.w700,
                color: _primary,
              ),
            ),
          ),
          const SizedBox(height: 20),
          Expanded(
            child: SingleChildScrollView(
              padding: const EdgeInsets.symmetric(horizontal: 20),
              child: Form(
                key: _formKey,
                child: Column(
                  children: [
                    TextFormField(
                      controller: _tipoController,
                      decoration: const InputDecoration(
                        labelText: 'Tipo de Camión',
                        prefixIcon: Icon(Icons.local_shipping_rounded),
                      ),
                      validator: (value) {
                        if (value?.isEmpty ?? true) return 'Campo requerido';
                        return null;
                      },
                    ),
                    const SizedBox(height: 16),
                    TextFormField(
                      controller: _modeloController,
                      decoration: const InputDecoration(
                        labelText: 'Modelo',
                        prefixIcon: Icon(Icons.build_rounded),
                      ),
                      validator: (value) {
                        if (value?.isEmpty ?? true) return 'Campo requerido';
                        return null;
                      },
                    ),
                    const SizedBox(height: 16),
                    TextFormField(
                      controller: _placasController,
                      decoration: const InputDecoration(
                        labelText: 'Placas',
                        prefixIcon: Icon(Icons.pin_rounded),
                      ),
                      validator: (value) {
                        if (value?.isEmpty ?? true) return 'Campo requerido';
                        return null;
                      },
                    ),
                    const SizedBox(height: 16),
                    TextFormField(
                      controller: _fotoController,
                      decoration: const InputDecoration(
                        labelText: 'URL de Foto',
                        prefixIcon: Icon(Icons.image_rounded),
                      ),
                    ),
                    const SizedBox(height: 16),
                    DropdownButtonFormField<String>(
                      value: _estado,
                      decoration: const InputDecoration(
                        labelText: 'Estado',
                        prefixIcon: Icon(Icons.flag_rounded),
                      ),
                      items: const [
                        DropdownMenuItem(
                          value: 'Disponible',
                          child: Text('Disponible'),
                        ),
                        DropdownMenuItem(
                          value: 'En Mantenimiento',
                          child: Text('En Mantenimiento'),
                        ),
                        DropdownMenuItem(
                          value: 'Fuera de Servicio',
                          child: Text('Fuera de Servicio'),
                        ),
                      ],
                      onChanged: (value) {
                        setState(() => _estado = value!);
                      },
                    ),
                    const SizedBox(height: 32),
                    ElevatedButton.icon(
                      style: ElevatedButton.styleFrom(
                        backgroundColor: _success,
                        foregroundColor: Colors.white,
                        minimumSize: const Size(double.infinity, 48),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(12),
                        ),
                      ),
                      onPressed: _guardarCamion,
                      icon: const Icon(Icons.save_rounded),
                      label: const Text(
                        'GUARDAR',
                        style: TextStyle(fontWeight: FontWeight.w700),
                      ),
                    ),
                    const SizedBox(height: 20),
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