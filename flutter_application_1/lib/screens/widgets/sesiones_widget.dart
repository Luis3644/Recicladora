import 'package:flutter/material.dart';
import '../../config/session_manager.dart';

class SesionesWidget extends StatefulWidget {
  const SesionesWidget({super.key});

  @override
  State<SesionesWidget> createState() => _SesionesWidgetState();
}

class _SesionesWidgetState extends State<SesionesWidget> {
  Future<List<Map<String, dynamic>>>? _future;

  @override
  void initState() {
    super.initState();
    _load();
  }

  void _load() async {
    final sesion = await SessionManager.obtenerSesion();
    if (sesion == null) return;
    setState(() {
      _future = SessionManager.listarSesionesUsuario(sesion.usuarioDocId);
    });
  }

  @override
  Widget build(BuildContext context) {
    return FutureBuilder<List<Map<String, dynamic>>>(
      future: _future,
      builder: (context, snapshot) {
        if (!snapshot.hasData) return const SizedBox.shrink();
        final sesiones = snapshot.data!;
        if (sesiones.isEmpty) return const SizedBox.shrink();

        return Column(
          children: [
            const Divider(),
            const Padding(
              padding: EdgeInsets.symmetric(horizontal: 16, vertical: 8),
              child: Align(
                alignment: Alignment.centerLeft,
                child: Text('Sesiones abiertas (máx. 5)', style: TextStyle(fontWeight: FontWeight.w700)),
              ),
            ),
            ...sesiones.take(5).map((s) {
              final name = s['dispositivo_nombre']?.toString() ?? s['dispositivo_id'];
              final id = s['dispositivo_id']?.toString() ?? '';
              final inicio = s['inicio']?.toString() ?? '';
              return ListTile(
                leading: const Icon(Icons.devices_other_outlined),
                title: Text(name),
                subtitle: Text(inicio),
                trailing: FutureBuilder(
                  future: SessionManager.obtenerSesion(),
                  builder: (context, localSnap) {
                    final localId = localSnap.data?.dispositivoId;
                    if (localId == id) return const SizedBox.shrink();
                    return IconButton(
                      icon: const Icon(Icons.logout_rounded, color: Colors.redAccent),
                      tooltip: 'Cerrar sesión remota',
                      onPressed: () async {
                        final ses = await SessionManager.obtenerSesion();
                        if (ses == null) return;
                        await SessionManager.cerrarSesionRemota(usuarioDocId: ses.usuarioDocId, dispositivoId: id);
                        ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Sesión remota cerrada.')));
                        _load();
                      },
                    );
                  },
                ),
              );
            }).toList(),
          ],
        );
      },
    );
  }
}
