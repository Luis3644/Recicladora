import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:url_launcher/url_launcher.dart';

class PanelGeneralUsuariosScreen extends StatefulWidget {
  const PanelGeneralUsuariosScreen({super.key});

  @override
  State<PanelGeneralUsuariosScreen> createState() =>
      _PanelGeneralUsuariosScreenState();
}

class _PanelGeneralUsuariosScreenState extends State<PanelGeneralUsuariosScreen>
    with SingleTickerProviderStateMixin {
  static const Color _primary = Color(0xFF0F172A);
  static const Color _accent = Color(0xFF06B6D4);
  static const Color _success = Color(0xFF10B981);
  static const Color _bg = Color(0xFFF0F9FF);

  bool _contentVisible = false;
  late AnimationController _controller;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      duration: const Duration(milliseconds: 650),
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

  Future<void> _llamarTelefono(String telefonoCrudo) async {
    final telefono = telefonoCrudo.trim().replaceAll(RegExp(r'[^0-9+]'), '');
    if (telefono.isEmpty) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Este usuario no tiene teléfono válido')),
      );
      return;
    }

    final uri = Uri(scheme: 'tel', path: telefono);
    if (await canLaunchUrl(uri)) {
      await launchUrl(uri);
      return;
    }

    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text('No se pudo abrir la app de teléfono')),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: _bg,
      appBar: AppBar(
        title: const Text(
          'Panel General de Usuarios',
          style: TextStyle(fontWeight: FontWeight.w700, letterSpacing: 0.2),
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
                blurRadius: 18,
                offset: const Offset(0, 8),
              ),
            ],
          ),
        ),
      ),
      body: Stack(
        children: [
          Positioned(
            top: -95,
            right: -60,
            child: Container(
              width: 240,
              height: 240,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: _accent.withOpacity(0.1),
              ),
            ),
          ),
          Positioned(
            bottom: -85,
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
          Column(
            children: [
              AnimatedOpacity(
                opacity: _contentVisible ? 1 : 0,
                duration: const Duration(milliseconds: 550),
                child: Padding(
                  padding: const EdgeInsets.fromLTRB(16, 16, 16, 8),
                  child: Container(
                    padding: const EdgeInsets.all(14),
                    decoration: BoxDecoration(
                      color: Colors.white.withOpacity(0.9),
                      borderRadius: BorderRadius.circular(14),
                      border: Border.all(color: _accent.withOpacity(0.2)),
                    ),
                    child: Row(
                      children: [
                        Container(
                          padding: const EdgeInsets.all(9),
                          decoration: BoxDecoration(
                            color: _accent.withOpacity(0.15),
                            borderRadius: BorderRadius.circular(10),
                          ),
                          child: const Icon(
                            Icons.groups_rounded,
                            color: _accent,
                            size: 22,
                          ),
                        ),
                        const SizedBox(width: 10),
                        const Expanded(
                          child: Text(
                            'Lista completa de trabajadores y operadores',
                            style: TextStyle(
                              color: _primary,
                              fontSize: 13,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ),
              Expanded(
                child: StreamBuilder<QuerySnapshot<Map<String, dynamic>>>(
                  stream: FirebaseFirestore.instance
                      .collection('usuarios')
                      .snapshots(),
                  builder: (context, snapshot) {
                    if (snapshot.hasError) {
                      return const Center(
                        child: Text('Error cargando usuarios'),
                      );
                    }
                    if (snapshot.connectionState == ConnectionState.waiting) {
                      return const Center(
                        child: CircularProgressIndicator(color: _accent),
                      );
                    }

                    final docs = [...snapshot.data!.docs];
                    docs.sort((a, b) {
                      final an =
                          (a.data()['nombre']?.toString().trim() ?? '').toLowerCase();
                      final bn =
                          (b.data()['nombre']?.toString().trim() ?? '').toLowerCase();
                      return an.compareTo(bn);
                    });

                    if (docs.isEmpty) {
                      return Center(
                        child: Column(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            Icon(
                              Icons.person_search_rounded,
                              size: 70,
                              color: _primary.withOpacity(0.2),
                            ),
                            const SizedBox(height: 10),
                            Text(
                              'No hay usuarios registrados',
                              style: TextStyle(
                                color: _primary.withOpacity(0.6),
                                fontWeight: FontWeight.w600,
                              ),
                            ),
                          ],
                        ),
                      );
                    }

                    return ListView.separated(
                      padding: const EdgeInsets.fromLTRB(16, 8, 16, 20),
                      itemCount: docs.length,
                      separatorBuilder: (_, __) => const SizedBox(height: 10),
                      itemBuilder: (context, index) {
                        final data = docs[index].data();
                        final nombre =
                            data['nombre']?.toString().trim().isNotEmpty == true
                                ? data['nombre'].toString().trim()
                                : 'Sin nombre';
                        final apellido = data['apellido_paterno']
                                    ?.toString()
                                    .trim()
                                    .isNotEmpty ==
                                true
                            ? data['apellido_paterno'].toString().trim()
                            : '';
                        final rol = data['rol']?.toString() ?? 'usuario';
                        final telefono = data['telefono']?.toString().trim() ?? '';
                        final camion = data['camion_actual']?.toString().trim() ?? '';
                        final nombreCompleto =
                            apellido.isNotEmpty ? '$nombre $apellido' : nombre;
                        final inicial =
                            nombreCompleto.isNotEmpty ? nombreCompleto[0] : '?';
                        final rolColor =
                            rol.toLowerCase() == 'operador' ? _success : _accent;

                        return TweenAnimationBuilder<double>(
                          tween: Tween(begin: 0, end: 1),
                          duration: Duration(milliseconds: 320 + (index * 45)),
                          curve: Curves.easeOutCubic,
                          builder: (context, value, child) {
                            return Transform.translate(
                              offset: Offset(0, 18 * (1 - value)),
                              child: Opacity(opacity: value, child: child),
                            );
                          },
                          child: Container(
                            padding: const EdgeInsets.all(14),
                            decoration: BoxDecoration(
                              gradient: LinearGradient(
                                colors: [
                                  Colors.white,
                                  rolColor.withOpacity(0.04),
                                ],
                                begin: Alignment.topLeft,
                                end: Alignment.bottomRight,
                              ),
                              borderRadius: BorderRadius.circular(14),
                              border: Border.all(color: rolColor.withOpacity(0.22)),
                              boxShadow: [
                                BoxShadow(
                                  color: _primary.withOpacity(0.06),
                                  blurRadius: 12,
                                  offset: const Offset(0, 5),
                                ),
                              ],
                            ),
                            child: Row(
                              children: [
                                CircleAvatar(
                                  radius: 22,
                                  backgroundColor: rolColor.withOpacity(0.16),
                                  child: Text(
                                    inicial.toUpperCase(),
                                    style: TextStyle(
                                      color: rolColor,
                                      fontWeight: FontWeight.w800,
                                    ),
                                  ),
                                ),
                                const SizedBox(width: 12),
                                Expanded(
                                  child: Column(
                                    crossAxisAlignment: CrossAxisAlignment.start,
                                    children: [
                                      Text(
                                        nombreCompleto,
                                        style: const TextStyle(
                                          fontWeight: FontWeight.w700,
                                          fontSize: 14,
                                          color: _primary,
                                        ),
                                      ),
                                      const SizedBox(height: 4),
                                      Row(
                                        children: [
                                          Container(
                                            padding: const EdgeInsets.symmetric(
                                              horizontal: 8,
                                              vertical: 4,
                                            ),
                                            decoration: BoxDecoration(
                                              color: rolColor.withOpacity(0.12),
                                              borderRadius: BorderRadius.circular(30),
                                            ),
                                            child: Text(
                                              rol,
                                              style: TextStyle(
                                                color: rolColor,
                                                fontWeight: FontWeight.w700,
                                                fontSize: 11,
                                              ),
                                            ),
                                          ),
                                          if (camion.isNotEmpty) ...[
                                            const SizedBox(width: 6),
                                            Expanded(
                                              child: Text(
                                                'Camión: $camion',
                                                style: TextStyle(
                                                  color: _primary.withOpacity(0.7),
                                                  fontSize: 11,
                                                ),
                                                overflow: TextOverflow.ellipsis,
                                              ),
                                            ),
                                          ],
                                        ],
                                      ),
                                      const SizedBox(height: 4),
                                      Text(
                                        telefono.isNotEmpty
                                            ? telefono
                                            : 'Sin teléfono',
                                        style: TextStyle(
                                          color: _primary.withOpacity(0.58),
                                          fontSize: 12,
                                        ),
                                      ),
                                    ],
                                  ),
                                ),
                                const SizedBox(width: 8),
                                IconButton.filled(
                                  onPressed: telefono.isEmpty
                                      ? null
                                      : () => _llamarTelefono(telefono),
                                  style: IconButton.styleFrom(
                                    backgroundColor: _success,
                                    disabledBackgroundColor:
                                        _primary.withOpacity(0.2),
                                  ),
                                  icon: const Icon(Icons.call_rounded),
                                  color: Colors.white,
                                  tooltip: 'Llamar',
                                ),
                              ],
                            ),
                          ),
                        );
                      },
                    );
                  },
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}