import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:intl/intl.dart';

class RegistroToneladasScreen extends StatefulWidget {
  final String operador;
  final String camion;
  final String placas;

  const RegistroToneladasScreen({
    super.key,
    required this.operador,
    required this.camion,
    required this.placas,
  });

  @override
  State<RegistroToneladasScreen> createState() =>
      _RegistroToneladasScreenState();
}

class _RegistroToneladasScreenState extends State<RegistroToneladasScreen>
    with TickerProviderStateMixin {

  // ── Colores — CAMBIO 1: un solo color para todos los pasos ───────────────
  static const Color _primary  = Color(0xFF031A47);
  static const Color _success  = Color(0xFF10B981);
  static const Color _warning  = Color(0xFFF59E0B);
  static const Color _danger   = Color(0xFFEF4444);
  static const Color _bgColor  = Color(0xFFF1F5F9);
  static const Color _surface  = Color(0xFFFFFFFF);
  static const Color _slate    = Color(0xFF64748B);

  // ── Pasos: 0=folio, 1=producto, 2=entrada, 3=salida, 4=éxito ────────────
  // CAMBIO 3: separamos entrada (paso 2) y salida (paso 3)
  int _paso = 0;

  // ── Controllers ───────────────────────────────────────────────────────────
  final _folioCtrl   = TextEditingController();
  final _entradaCtrl = TextEditingController();
  final _salidaCtrl  = TextEditingController();

  String? _productoSeleccionado;
  double  _pesoNeto  = 0.0;
  bool    _guardando = false;

  // ── Animaciones éxito ─────────────────────────────────────────────────────
  late AnimationController _successCtrl;
  late AnimationController _scaleCtrl;
  late Animation<double>   _successScale;
  late Animation<double>   _successOpacity;
  late Animation<double>   _checkScale;

  final String _fechaHora =
      DateFormat('dd/MM/yyyy  HH:mm').format(DateTime.now());

  final List<Map<String, String>> _productos = [
    {'valor': 'VG20',           'icono': '🔵'},
    {'valor': 'NX',             'icono': '🟣'},
    {'valor': 'SISMO SUCIO',    'icono': '🟤'},
    {'valor': 'NO RECICLABLE',  'icono': '⛔'},
    {'valor': 'CONTAMINADO',    'icono': '⚠️'},
    {'valor': 'MIXTO SECURY',   'icono': '🟡'},
    {'valor': 'LAMINADO GLASS', 'icono': '🔶'},
  ];

  @override
  void initState() {
    super.initState();

    _successCtrl = AnimationController(
        vsync: this, duration: const Duration(milliseconds: 800));
    _scaleCtrl = AnimationController(
        vsync: this, duration: const Duration(milliseconds: 600));

    _successScale   = CurvedAnimation(
        parent: _successCtrl, curve: Curves.elasticOut);
    _successOpacity = CurvedAnimation(
        parent: _successCtrl, curve: Curves.easeIn);
    _checkScale     = CurvedAnimation(
        parent: _scaleCtrl,   curve: Curves.elasticOut);

    // CAMBIO 4: guardar en Firestore que hay un registro en curso
    // para poder restaurar la pantalla si cierran la app
    _marcarRegistroEnCurso(true);
  }

  @override
  void dispose() {
    _folioCtrl.dispose();
    _entradaCtrl.dispose();
    _salidaCtrl.dispose();
    _successCtrl.dispose();
    _scaleCtrl.dispose();
    super.dispose();
  }

  // ── CAMBIO 4: marcar en Firestore si hay registro en curso ───────────────
  Future<void> _marcarRegistroEnCurso(bool activo) async {
    try {
      await FirebaseFirestore.instance
          .collection('usuarios')
          .doc(widget.operador)
          .set({'registro_en_curso': activo},
              SetOptions(merge: true));
    } catch (_) {}
  }

  void _calcularNeto() {
    final entrada = double.tryParse(_entradaCtrl.text) ?? 0.0;
    final salida  = double.tryParse(_salidaCtrl.text)  ?? 0.0;
    setState(() => _pesoNeto = (entrada - salida).abs());
  }

  // ── Avanzar ───────────────────────────────────────────────────────────────
  void _avanzar() {
    switch (_paso) {
      case 0:
        if (_folioCtrl.text.trim().isEmpty) {
          _snack('Ingresa el folio de la papeleta');
          return;
        }
        break;
      case 1:
        if (_productoSeleccionado == null) {
          _snack('Selecciona el tipo de producto');
          return;
        }
        break;
      case 2:
        if (_entradaCtrl.text.trim().isEmpty) {
          _snack('Ingresa el peso de entrada');
          return;
        }
        if (double.tryParse(_entradaCtrl.text) == null) {
          _snack('El peso debe ser un número válido');
          return;
        }
        break;
      case 3:
        if (_salidaCtrl.text.trim().isEmpty) {
          _snack('Ingresa el peso de salida');
          return;
        }
        if (double.tryParse(_salidaCtrl.text) == null) {
          _snack('El peso debe ser un número válido');
          return;
        }
        _guardar();
        return;
    }
    setState(() => _paso++);
  }

  void _retroceder() {
    if (_paso > 0) setState(() => _paso--);
  }

  // ── CAMBIO 4: cancelar registro ───────────────────────────────────────────
  Future<void> _cancelarRegistro() async {
    final confirmar = await showDialog<bool>(
      context: context,
      barrierDismissible: false,
      builder: (_) => Dialog(
        shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(20)),
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Column(mainAxisSize: MainAxisSize.min, children: [
            Container(
              padding: const EdgeInsets.all(14),
              decoration: BoxDecoration(
                  color: _danger.withOpacity(0.1),
                  shape: BoxShape.circle),
              child: Icon(Icons.cancel_outlined,
                  color: _danger, size: 32),
            ),
            const SizedBox(height: 16),
            const Text('¿Cancelar registro?',
                style: TextStyle(
                    fontSize: 17, fontWeight: FontWeight.w800),
                textAlign: TextAlign.center),
            const SizedBox(height: 8),
            Text(
              'Se perderán todos los datos ingresados.\n¿Deseas salir?',
              style: TextStyle(
                  fontSize: 13, color: _slate, height: 1.5),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 22),
            Row(children: [
              Expanded(
                child: OutlinedButton(
                  style: OutlinedButton.styleFrom(
                    foregroundColor: _slate,
                    side: const BorderSide(color: Color(0xFFE2E8F0)),
                    shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(12)),
                    padding: const EdgeInsets.symmetric(vertical: 13),
                  ),
                  onPressed: () => Navigator.of(context).pop(false),
                  child: const Text('Seguir\nregistrando',
                      textAlign: TextAlign.center,
                      style: TextStyle(
                          fontWeight: FontWeight.w600, fontSize: 13)),
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: ElevatedButton(
                  style: ElevatedButton.styleFrom(
                    backgroundColor: _danger,
                    foregroundColor: Colors.white,
                    elevation: 0,
                    shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(12)),
                    padding: const EdgeInsets.symmetric(vertical: 13),
                  ),
                  onPressed: () => Navigator.of(context).pop(true),
                  child: const Text('Sí, cancelar',
                      style: TextStyle(
                          fontWeight: FontWeight.w700, fontSize: 13)),
                ),
              ),
            ]),
          ]),
        ),
      ),
    ) ?? false;

    if (confirmar) {
      await _marcarRegistroEnCurso(false);
      if (mounted) Navigator.of(context).pop();
    }
  }

  // ── Guardar en Firestore ──────────────────────────────────────────────────
  Future<void> _guardar() async {
    setState(() => _guardando = true);
    try {
      await FirebaseFirestore.instance
          .collection('registros_toneladas')
          .add({
        'folio'         : _folioCtrl.text.trim(),
        'operador'      : widget.operador,
        'camion'        : widget.camion,
        'placas'        : widget.placas,
        'producto'      : _productoSeleccionado,
        'peso_entrada'  : double.tryParse(_entradaCtrl.text) ?? 0.0,
        'peso_salida'   : double.tryParse(_salidaCtrl.text)  ?? 0.0,
        'peso_neto'     : _pesoNeto,
        'fecha_registro': FieldValue.serverTimestamp(),
        'fecha_texto'   : _fechaHora,
      });

      // Limpiar registro en curso al terminar exitosamente
      await _marcarRegistroEnCurso(false);

      setState(() { _guardando = false; _paso = 4; });

      await _enviarNotificacionAdmin(
        tipo   : 'material',
        mensaje:
            '${widget.operador} registró una carga de $_productoSeleccionado '
            '(${_pesoNeto.toStringAsFixed(0)} kg) — ${widget.camion}.',
      );

      await Future.delayed(const Duration(milliseconds: 100));
      _successCtrl.forward();
      await Future.delayed(const Duration(milliseconds: 300));
      _scaleCtrl.forward();
    } catch (e) {
      setState(() => _guardando = false);
      _snack('Error al guardar: $e');
    }
  }

  void _snack(String msg) {
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(
      content: Text(msg,
          style: const TextStyle(fontWeight: FontWeight.w600)),
      backgroundColor: _warning,
      behavior: SnackBarBehavior.floating,
      shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(12)),
    ));
  }

  Future<void> _enviarNotificacionAdmin({
    required String tipo,
    required String mensaje,
  }) async {
    try {
      await FirebaseFirestore.instance.collection('notificaciones').add({
        'mensaje'        : mensaje,
        'creadoEn'       : FieldValue.serverTimestamp(),
        'enviadoPor'     : widget.operador,
        'destinoTipo'    : 'rol',
        'paraTodos'      : false,
        'destinatarioRol': 'admin',
        'tipo'           : tipo,
        'leidoPor'       : <String, bool>{},
      });
    } catch (e) {
      debugPrint('Error notificación admin: $e');
    }
  }

  // ── BUILD ─────────────────────────────────────────────────────────────────
  // CAMBIO 4: PopScope bloquea el botón atrás del teléfono
  @override
  Widget build(BuildContext context) {
    return PopScope(
      canPop: false, // bloquea el botón atrás físico/gesture
      onPopInvokedWithResult: (didPop, _) {
        if (!didPop && _paso < 4) {
          // Si ya está en éxito no hacemos nada, el botón pop normal funciona
        }
      },
      child: Scaffold(
        backgroundColor: _bgColor,
        // CAMBIO 1 y 2: AppBar mismo color en todos los pasos,
        // sin flechita de salir, solo título
        appBar: _paso < 4 ? _buildAppBar() : null,
        body: _paso == 4 ? _buildExito() : _buildFormulario(),
      ),
    );
  }

  // ── AppBar — CAMBIO 1: mismo color todos los pasos, CAMBIO 4: sin leading ─
  PreferredSizeWidget _buildAppBar() {
    return AppBar(
      automaticallyImplyLeading: false, // quita la flechita
      title: const Text(
        'Registro de Carga',
        style: TextStyle(fontWeight: FontWeight.w800, fontSize: 17),
      ),
      backgroundColor: Colors.transparent,
      elevation: 0,
      foregroundColor: Colors.white,
      flexibleSpace: Container(
        decoration: const BoxDecoration(
          gradient: LinearGradient(
            colors: [_primary, Color(0xFF0A2A5E)],
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
          ),
        ),
      ),
      // Botón cancelar en la esquina derecha
      actions: [
        Padding(
          padding: const EdgeInsets.only(right: 12),
          child: TextButton.icon(
            style: TextButton.styleFrom(
              foregroundColor: Colors.white.withOpacity(0.9),
              backgroundColor: Colors.white.withOpacity(0.12),
              padding: const EdgeInsets.symmetric(
                  horizontal: 12, vertical: 6),
              shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(20)),
            ),
            onPressed: _cancelarRegistro,
            icon: const Icon(Icons.close_rounded, size: 16),
            label: const Text('Cancelar Registro',
                style: TextStyle(
                    fontWeight: FontWeight.w700, fontSize: 13)),
          ),
        ),
      ],
    );
  }

  // ── Formulario ────────────────────────────────────────────────────────────
  Widget _buildFormulario() {
    return Column(
      children: [
        _buildHeader(),
        Padding(
          padding: const EdgeInsets.fromLTRB(20, 16, 20, 0),
          child: _buildIndicadorPasos(),
        ),
        Expanded(
          child: AnimatedSwitcher(
            duration: const Duration(milliseconds: 320),
            transitionBuilder: (child, anim) => SlideTransition(
              position: Tween<Offset>(
                begin: const Offset(0.12, 0),
                end: Offset.zero,
              ).animate(CurvedAnimation(
                  parent: anim, curve: Curves.easeOutCubic)),
              child: FadeTransition(opacity: anim, child: child),
            ),
            child: SingleChildScrollView(
              key: ValueKey(_paso),
              padding: const EdgeInsets.fromLTRB(20, 16, 20, 32),
              child: _buildContenidoPaso(),
            ),
          ),
        ),
      ],
    );
  }

  // ── Header — CAMBIO 1 y 2 ────────────────────────────────────────────────
  // Mismo color azul marino siempre, solo nombre + fecha/hora
  Widget _buildHeader() {
    // CAMBIO 2: extraer solo el primer nombre
    final primerNombre = widget.operador.trim().split(' ').first;

    // Mensaje según el paso actual
    final List<Map<String, dynamic>> pasoInfo = [
      {
        'titulo': '¡Hola $primerNombre! Vamos a registrar tu carga',
        'sub'   : 'Primero necesitamos el folio de tu papeleta.',
        'icono' : Icons.assignment_rounded,
      },
      {
        'titulo': 'Perfecto, $primerNombre',
        'sub'   : 'Selecciona el tipo de material que traes.',
        'icono' : Icons.category_rounded,
      },
      {
        'titulo': 'Casi listo, $primerNombre',
        'sub'   : 'Ingresa el peso de entrada del camión.',
        'icono' : Icons.arrow_downward_rounded,
      },
      {
        'titulo': 'Un paso más, $primerNombre',
        'sub'   : 'Ahora ingresa el peso de salida.',
        'icono' : Icons.arrow_upward_rounded,
      },
    ];

    final info = pasoInfo[_paso];

    return Container(
      width: double.infinity,
      // CAMBIO 1: siempre _primary para todos los pasos
      padding: const EdgeInsets.fromLTRB(20, 18, 20, 18),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: [_primary, const Color(0xFF0A2A5E)],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        boxShadow: [
          BoxShadow(
            color: _primary.withOpacity(0.35),
            blurRadius: 16,
            offset: const Offset(0, 6),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // CAMBIO 2: solo nombre del operador y fecha/hora
          Row(children: [
            Container(
              padding: const EdgeInsets.symmetric(
                  horizontal: 10, vertical: 5),
              decoration: BoxDecoration(
                color: Colors.white.withOpacity(0.15),
                borderRadius: BorderRadius.circular(20),
              ),
              child: Row(mainAxisSize: MainAxisSize.min, children: [
                const Icon(Icons.person_rounded,
                    color: Colors.white70, size: 13),
                const SizedBox(width: 5),
                Text(widget.operador,
                    style: const TextStyle(
                        color: Colors.white,
                        fontSize: 12,
                        fontWeight: FontWeight.w700)),
              ]),
            ),
            const SizedBox(width: 8),
            Container(
              padding: const EdgeInsets.symmetric(
                  horizontal: 10, vertical: 5),
              decoration: BoxDecoration(
                color: Colors.white.withOpacity(0.15),
                borderRadius: BorderRadius.circular(20),
              ),
              child: Row(mainAxisSize: MainAxisSize.min, children: [
                const Icon(Icons.access_time_rounded,
                    color: Colors.white70, size: 13),
                const SizedBox(width: 5),
                Text(_fechaHora,
                    style: const TextStyle(
                        color: Colors.white,
                        fontSize: 12,
                        fontWeight: FontWeight.w600)),
              ]),
            ),
          ]),
          const SizedBox(height: 14),
          // Icono + título/subtítulo del paso
          Row(children: [
            Container(
              padding: const EdgeInsets.all(10),
              decoration: BoxDecoration(
                color: Colors.white.withOpacity(0.18),
                borderRadius: BorderRadius.circular(12),
              ),
              child: Icon(info['icono'] as IconData,
                  color: Colors.white, size: 24),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(info['titulo'] as String,
                      style: const TextStyle(
                          color: Colors.white,
                          fontSize: 16,
                          fontWeight: FontWeight.w800,
                          height: 1.3)),
                  const SizedBox(height: 3),
                  Text(info['sub'] as String,
                      style: TextStyle(
                          color: Colors.white.withOpacity(0.8),
                          fontSize: 12.5)),
                ],
              ),
            ),
          ]),
        ],
      ),
    );
  }

  // ── Indicador de pasos — CAMBIO 3: ahora 4 pasos ────────────────────────
  Widget _buildIndicadorPasos() {
    const labels = ['Folio', 'Producto', 'Entrada', 'Salida'];

    return Row(
      children: List.generate(4, (i) {
        final done   = i < _paso;
        final active = i == _paso;

        return Expanded(
          child: Row(children: [
            Expanded(
              child: Column(children: [
                AnimatedContainer(
                  duration: const Duration(milliseconds: 300),
                  width:  active ? 36 : 28,
                  height: active ? 36 : 28,
                  decoration: BoxDecoration(
                    color: done
                        ? _success
                        : active
                            ? _primary
                            : Colors.white,
                    shape: BoxShape.circle,
                    border: Border.all(
                      color: done
                          ? _success
                          : active
                              ? _primary
                              : const Color(0xFFCBD5E1),
                      width: 2,
                    ),
                    boxShadow: active
                        ? [
                            BoxShadow(
                                color: _primary.withOpacity(0.3),
                                blurRadius: 8,
                                offset: const Offset(0, 3))
                          ]
                        : [],
                  ),
                  child: Center(
                    child: done
                        ? const Icon(Icons.check_rounded,
                            color: Colors.white, size: 14)
                        : Text('${i + 1}',
                            style: TextStyle(
                                fontSize: 12,
                                fontWeight: FontWeight.w800,
                                color: active
                                    ? Colors.white
                                    : _slate)),
                  ),
                ),
                const SizedBox(height: 4),
                Text(labels[i],
                    style: TextStyle(
                        fontSize: 9,
                        fontWeight: active
                            ? FontWeight.w700
                            : FontWeight.w500,
                        color: active ? _primary : _slate)),
              ]),
            ),
            if (i < 3)
              Expanded(
                child: Container(
                  height: 2,
                  margin: const EdgeInsets.only(bottom: 16),
                  decoration: BoxDecoration(
                    color: i < _paso
                        ? _success
                        : const Color(0xFFE2E8F0),
                    borderRadius: BorderRadius.circular(1),
                  ),
                ),
              ),
          ]),
        );
      }),
    );
  }

  // ── Contenido según paso ──────────────────────────────────────────────────
  Widget _buildContenidoPaso() {
    switch (_paso) {
      case 0: return _buildPasoFolio();
      case 1: return _buildPasoProducto();
      case 2: return _buildPasoEntrada();   // CAMBIO 3
      case 3: return _buildPasoSalida();    // CAMBIO 3
      default: return const SizedBox.shrink();
    }
  }

  // ── PASO 0: Folio ─────────────────────────────────────────────────────────
  Widget _buildPasoFolio() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _labelCampo('Número de folio',
            Icons.tag_rounded, _primary),
        const SizedBox(height: 10),
        _inputGrande(
          controller: _folioCtrl,
          hint      : 'Ej: 00123',
          tipo      : TextInputType.number,
          formatters: [FilteringTextInputFormatter.digitsOnly],
          onSubmit  : _avanzar,
        ),
        const SizedBox(height: 8),
        Text(
          '💡 Encuentra el folio en la parte superior de tu papeleta.',
          style: TextStyle(fontSize: 12, color: _slate),
        ),
        const SizedBox(height: 28),
        _botonAvanzar(
            'Siguiente — Tipo de producto',
            Icons.arrow_forward_rounded),
      ],
    );
  }

  // ── PASO 1: Producto ──────────────────────────────────────────────────────
  Widget _buildPasoProducto() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _labelCampo('Tipo de material',
            Icons.category_rounded, _primary),
        const SizedBox(height: 12),
        GridView.builder(
          shrinkWrap: true,
          physics: const NeverScrollableScrollPhysics(),
          gridDelegate:
              const SliverGridDelegateWithFixedCrossAxisCount(
            crossAxisCount  : 2,
            crossAxisSpacing: 10,
            mainAxisSpacing : 10,
            childAspectRatio: 2.4,
          ),
          itemCount: _productos.length,
          itemBuilder: (_, i) {
            final prod = _productos[i];
            final sel  = _productoSeleccionado == prod['valor'];
            return GestureDetector(
              onTap: () =>
                  setState(() => _productoSeleccionado = prod['valor']),
              child: AnimatedContainer(
                duration: const Duration(milliseconds: 180),
                decoration: BoxDecoration(
                  color: sel
                      ? _primary.withOpacity(0.08)
                      : _surface,
                  borderRadius: BorderRadius.circular(14),
                  border: Border.all(
                    color: sel
                        ? _primary
                        : const Color(0xFFE2E8F0),
                    width: sel ? 2 : 1,
                  ),
                  boxShadow: sel
                      ? [
                          BoxShadow(
                            color: _primary.withOpacity(0.15),
                            blurRadius: 8,
                            offset: const Offset(0, 3),
                          )
                        ]
                      : [],
                ),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Text(prod['icono']!,
                        style: const TextStyle(fontSize: 18)),
                    const SizedBox(width: 8),
                    Flexible(
                      child: Text(
                        prod['valor']!,
                        style: TextStyle(
                          fontSize: 12,
                          fontWeight: FontWeight.w700,
                          color: sel ? _primary : _slate,
                        ),
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                    if (sel) ...[
                      const SizedBox(width: 4),
                      Icon(Icons.check_circle_rounded,
                          color: _primary, size: 16),
                    ],
                  ],
                ),
              ),
            );
          },
        ),
        const SizedBox(height: 24),
        _botonAvanzar(
            'Siguiente — Peso de entrada',
            Icons.arrow_forward_rounded),
        const SizedBox(height: 8),
        _botonVolver(),
      ],
    );
  }

  // ── PASO 2: Peso entrada — CAMBIO 3 ──────────────────────────────────────
  Widget _buildPasoEntrada() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // Resumen
        _resumenMini(),
        const SizedBox(height: 20),
        _labelCampo('Peso de entrada (kg)',
            Icons.arrow_downward_rounded, _primary),
        const SizedBox(height: 6),
        Text('Es el peso del camión cargado al entrar.',
            style: TextStyle(fontSize: 12, color: _slate)),
        const SizedBox(height: 10),
        _inputGrande(
          controller: _entradaCtrl,
          hint      : 'Ej: 12500',
          tipo      : TextInputType.number,
          formatters: [FilteringTextInputFormatter.digitsOnly],
          onSubmit  : _avanzar,
        ),
        const SizedBox(height: 28),
        _botonAvanzar(
            'Siguiente — Peso de salida',
            Icons.arrow_forward_rounded),
        const SizedBox(height: 8),
        _botonVolver(),
      ],
    );
  }

  // ── PASO 3: Peso salida + neto — CAMBIO 3 ────────────────────────────────
  Widget _buildPasoSalida() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // Resumen con entrada
        _resumenMini(mostrarEntrada: true),
        const SizedBox(height: 20),
        _labelCampo('Peso de salida (kg)',
            Icons.arrow_upward_rounded, _primary),
        const SizedBox(height: 6),
        Text('Es el peso del camión vacío al salir.',
            style: TextStyle(fontSize: 12, color: _slate)),
        const SizedBox(height: 10),
        _inputGrande(
          controller: _salidaCtrl,
          hint      : 'Ej: 2000',
          tipo      : TextInputType.number,
          formatters: [FilteringTextInputFormatter.digitsOnly],
          onChanged : (_) => _calcularNeto(),
          onSubmit  : _avanzar,
        ),
        const SizedBox(height: 20),

        // Peso neto calculado en tiempo real
        AnimatedContainer(
          duration: const Duration(milliseconds: 300),
          padding: const EdgeInsets.all(20),
          decoration: BoxDecoration(
            color: _pesoNeto > 0
                ? _success.withOpacity(0.08)
                : const Color(0xFFF8FAFC),
            borderRadius: BorderRadius.circular(18),
            border: Border.all(
              color: _pesoNeto > 0
                  ? _success.withOpacity(0.4)
                  : const Color(0xFFE2E8F0),
              width: _pesoNeto > 0 ? 2 : 1,
            ),
          ),
          child: Column(children: [
            Row(mainAxisAlignment: MainAxisAlignment.center, children: [
              Icon(Icons.scale_rounded,
                  color: _pesoNeto > 0 ? _success : _slate,
                  size: 20),
              const SizedBox(width: 8),
              Text('PESO NETO CALCULADO',
                  style: TextStyle(
                      fontSize: 12,
                      fontWeight: FontWeight.w800,
                      color: _pesoNeto > 0 ? _success : _slate,
                      letterSpacing: 0.8)),
            ]),
            const SizedBox(height: 8),
            Text(
              _pesoNeto > 0
                  ? '${NumberFormat('#,###.##').format(_pesoNeto)} kg'
                  : '— kg',
              style: TextStyle(
                fontSize: 40,
                fontWeight: FontWeight.w900,
                color: _pesoNeto > 0 ? _success : _slate,
                letterSpacing: -1,
              ),
            ),
            if (_pesoNeto > 0)
              Text(
                '≈ ${(_pesoNeto / 1000).toStringAsFixed(2)} toneladas',
                style: TextStyle(fontSize: 13, color: _slate),
              ),
          ]),
        ),
        const SizedBox(height: 28),

        // Botón guardar
        SizedBox(
          width: double.infinity,
          height: 56,
          child: ElevatedButton.icon(
            style: ElevatedButton.styleFrom(
              backgroundColor: _primary,
              foregroundColor: Colors.white,
              elevation: 4,
              shadowColor: _primary.withOpacity(0.4),
              shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(16)),
            ),
            onPressed: _guardando ? null : _avanzar,
            icon: _guardando
                ? const SizedBox(
                    width: 22, height: 22,
                    child: CircularProgressIndicator(
                        color: Colors.white, strokeWidth: 2.5))
                : const Icon(Icons.cloud_upload_rounded, size: 22),
            label: Text(
              _guardando ? 'Guardando...' : 'Guardar registro',
              style: const TextStyle(
                  fontSize: 17, fontWeight: FontWeight.w800),
            ),
          ),
        ),
        const SizedBox(height: 8),
        _botonVolver(),
      ],
    );
  }

  // ── Resumen mini (arriba de los pasos de pesos) ───────────────────────────
  Widget _resumenMini({bool mostrarEntrada = false}) {
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: _primary.withOpacity(0.05),
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: _primary.withOpacity(0.15)),
      ),
      child: Column(
        children: [
          Row(children: [
            Icon(Icons.summarize_rounded, color: _primary, size: 18),
            const SizedBox(width: 8),
            Text('Folio: ${_folioCtrl.text.trim()}',
                style: const TextStyle(
                    fontSize: 13, fontWeight: FontWeight.w700)),
            const Spacer(),
            Text('$_productoSeleccionado',
                style: TextStyle(
                    fontSize: 12,
                    color: _slate,
                    fontWeight: FontWeight.w600)),
          ]),
          if (mostrarEntrada && _entradaCtrl.text.isNotEmpty) ...[
            const SizedBox(height: 6),
            Row(children: [
              Icon(Icons.arrow_downward_rounded,
                  color: _success, size: 14),
              const SizedBox(width: 6),
              Text(
                'Peso entrada: ${_entradaCtrl.text} kg',
                style: TextStyle(
                    fontSize: 12,
                    color: _success,
                    fontWeight: FontWeight.w700),
              ),
            ]),
          ],
        ],
      ),
    );
  }

  // ── PANTALLA DE ÉXITO (paso 4) ────────────────────────────────────────────
  Widget _buildExito() {
    return Container(
      color: _bgColor,
      child: Center(
        child: FadeTransition(
          opacity: _successOpacity,
          child: Padding(
            padding: const EdgeInsets.all(32),
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                ScaleTransition(
                  scale: _successScale,
                  child: Container(
                    width: 130, height: 130,
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      color: _success.withOpacity(0.1),
                      border: Border.all(
                          color: _success.withOpacity(0.3), width: 3),
                    ),
                    child: Center(
                      child: ScaleTransition(
                        scale: _checkScale,
                        child: Container(
                          width: 90, height: 90,
                          decoration: const BoxDecoration(
                              shape: BoxShape.circle,
                              color: _success),
                          child: const Icon(Icons.check_rounded,
                              color: Colors.white, size: 50),
                        ),
                      ),
                    ),
                  ),
                ),
                const SizedBox(height: 28),
                ScaleTransition(
                  scale: _successScale,
                  child: const Text(
                    '¡Registrado correctamente!',
                    style: TextStyle(
                        fontSize: 24,
                        fontWeight: FontWeight.w900,
                        color: _primary),
                    textAlign: TextAlign.center,
                  ),
                ),
                const SizedBox(height: 12),
                FadeTransition(
                  opacity: _successOpacity,
                  child: Container(
                    padding: const EdgeInsets.all(16),
                    decoration: BoxDecoration(
                      color: _surface,
                      borderRadius: BorderRadius.circular(16),
                      border: Border.all(
                          color: const Color(0xFFE2E8F0)),
                    ),
                    child: Column(children: [
                      _filaResumen(Icons.tag_rounded,
                          'Folio', _folioCtrl.text.trim(), _primary),
                      _filaResumen(Icons.category_rounded,
                          'Producto', _productoSeleccionado ?? '—',
                          _primary),
                      _filaResumen(Icons.arrow_downward_rounded,
                          'Entrada',
                          '${_entradaCtrl.text} kg', _primary),
                      _filaResumen(Icons.arrow_upward_rounded,
                          'Salida',
                          '${_salidaCtrl.text} kg', _primary),
                      _filaResumen(Icons.scale_rounded,
                          'Peso neto',
                          '${NumberFormat('#,###.##').format(_pesoNeto)} kg',
                          _success),
                      _filaResumen(Icons.calendar_today_rounded,
                          'Fecha', _fechaHora, _slate),
                    ]),
                  ),
                ),
                const SizedBox(height: 32),
                ScaleTransition(
                  scale: _successScale,
                  child: SizedBox(
                    width: double.infinity,
                    height: 54,
                    child: ElevatedButton.icon(
                      style: ElevatedButton.styleFrom(
                        backgroundColor: _primary,
                        foregroundColor: Colors.white,
                        elevation: 0,
                        shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(16)),
                      ),
                      onPressed: () => Navigator.pop(context),
                      icon: const Icon(
                          Icons.arrow_back_rounded, size: 20),
                      label: const Text('Volver a jornada',
                          style: TextStyle(
                              fontSize: 16,
                              fontWeight: FontWeight.w700)),
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _filaResumen(
      IconData icon, String label, String valor, Color color) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 6),
      child: Row(children: [
        Icon(icon, size: 16, color: color),
        const SizedBox(width: 8),
        Text('$label:',
            style: TextStyle(
                fontSize: 13,
                color: _slate,
                fontWeight: FontWeight.w600)),
        const Spacer(),
        Text(valor,
            style: const TextStyle(
                fontSize: 13,
                fontWeight: FontWeight.w800,
                color: _primary)),
      ]),
    );
  }

  // ── Helpers UI ────────────────────────────────────────────────────────────
  Widget _labelCampo(String texto, IconData icon, Color color) {
    return Row(children: [
      Icon(icon, size: 18, color: color),
      const SizedBox(width: 8),
      Text(texto,
          style: const TextStyle(
              fontSize: 15,
              fontWeight: FontWeight.w800,
              color: _primary)),
    ]);
  }

  Widget _inputGrande({
    required TextEditingController controller,
    required String hint,
    required TextInputType tipo,
    List<TextInputFormatter>? formatters,
    ValueChanged<String>? onChanged,
    VoidCallback? onSubmit,
  }) {
    return TextField(
      controller     : controller,
      keyboardType   : tipo,
      inputFormatters: formatters,
      autofocus      : true,
      onChanged      : onChanged,
      onSubmitted    : onSubmit != null ? (_) => onSubmit() : null,
      style          : const TextStyle(
          fontSize: 28, fontWeight: FontWeight.w800, color: _primary),
      decoration: InputDecoration(
        hintText : hint,
        hintStyle: TextStyle(
            color: Colors.grey[400],
            fontSize: 22,
            fontWeight: FontWeight.w400),
        filled   : true,
        fillColor: _primary.withOpacity(0.04),
        contentPadding: const EdgeInsets.symmetric(
            horizontal: 18, vertical: 16),
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(14),
          borderSide:
              BorderSide(color: _primary.withOpacity(0.3)),
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(14),
          borderSide:
              BorderSide(color: _primary.withOpacity(0.3)),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(14),
          borderSide: const BorderSide(color: _primary, width: 2.5),
        ),
      ),
    );
  }

  Widget _botonAvanzar(String texto, IconData icon) {
    return SizedBox(
      width: double.infinity,
      height: 54,
      child: ElevatedButton.icon(
        style: ElevatedButton.styleFrom(
          backgroundColor: _primary,
          foregroundColor: Colors.white,
          elevation: 3,
          shadowColor: _primary.withOpacity(0.35),
          shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(16)),
        ),
        onPressed: _avanzar,
        icon : Icon(icon, size: 20),
        label: Text(texto,
            style: const TextStyle(
                fontSize: 15, fontWeight: FontWeight.w700)),
      ),
    );
  }

  Widget _botonVolver() {
    return SizedBox(
      width: double.infinity,
      child: TextButton.icon(
        onPressed: _retroceder,
        icon : const Icon(Icons.arrow_back_rounded, size: 16),
        label: const Text('Volver al paso anterior'),
        style: TextButton.styleFrom(foregroundColor: _slate),
      ),
    );
  }
}