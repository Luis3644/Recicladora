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

  // ── Colores ───────────────────────────────────────────────────────────────
  static const Color _primary  = Color(0xFF031A47);
  static const Color _accent   = Color(0xFF0F766E);
  static const Color _success  = Color(0xFF10B981);
  static const Color _warning  = Color(0xFFF59E0B);
  static const Color _bgColor  = Color(0xFFF1F5F9);
  static const Color _surface  = Color(0xFFFFFFFF);
  static const Color _slate    = Color(0xFF64748B);

  // ── Paso actual (0 = folio, 1 = producto, 2 = pesos, 3 = éxito) ──────────
  int _paso = 0;

  // ── Controllers ───────────────────────────────────────────────────────────
  final _folioCtrl   = TextEditingController();
  final _entradaCtrl = TextEditingController();
  final _salidaCtrl  = TextEditingController();

  String? _productoSeleccionado;
  double  _pesoNeto = 0.0;
  bool    _guardando = false;

  // ── Animaciones ───────────────────────────────────────────────────────────
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
      vsync: this,
      duration: const Duration(milliseconds: 800),
    );
    _scaleCtrl = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 600),
    );

    _successScale = CurvedAnimation(
      parent: _successCtrl,
      curve: Curves.elasticOut,
    );
    _successOpacity = CurvedAnimation(
      parent: _successCtrl,
      curve: Curves.easeIn,
    );
    _checkScale = CurvedAnimation(
      parent: _scaleCtrl,
      curve: Curves.elasticOut,
    );
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

  void _calcularNeto() {
    final entrada = double.tryParse(_entradaCtrl.text) ?? 0.0;
    final salida  = double.tryParse(_salidaCtrl.text) ?? 0.0;
    setState(() => _pesoNeto = (entrada - salida).abs());
  }

  // ── Validar paso y avanzar ────────────────────────────────────────────────
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
        if (_entradaCtrl.text.trim().isEmpty ||
            _salidaCtrl.text.trim().isEmpty) {
          _snack('Ingresa ambos pesos');
          return;
        }
        if (double.tryParse(_entradaCtrl.text) == null ||
            double.tryParse(_salidaCtrl.text) == null) {
          _snack('Los pesos deben ser números válidos');
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

  // ── Guardar en Firestore ──────────────────────────────────────────────────
  Future<void> _guardar() async {
    setState(() => _guardando = true);
    try {
      await FirebaseFirestore.instance.collection('registros_toneladas').add({
        'folio':          _folioCtrl.text.trim(),
        'operador':       widget.operador,
        'camion':         widget.camion,
        'placas':         widget.placas,
        'producto':       _productoSeleccionado,
        'peso_entrada':   double.tryParse(_entradaCtrl.text) ?? 0.0,
        'peso_salida':    double.tryParse(_salidaCtrl.text) ?? 0.0,
        'peso_neto':      _pesoNeto,
        'fecha_registro': FieldValue.serverTimestamp(),
        'fecha_texto':    _fechaHora,
      });

      setState(() { _guardando = false; _paso = 3; });

      // Lanzar animación de éxito
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
      content: Text(msg, style: const TextStyle(fontWeight: FontWeight.w600)),
      backgroundColor: _warning,
      behavior: SnackBarBehavior.floating,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
    ));
  }

  // ── Build ─────────────────────────────────────────────────────────────────
  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: _bgColor,
      appBar: _paso < 3 ? _buildAppBar() : null,
      body: _paso == 3 ? _buildExito() : _buildFormulario(),
    );
  }

  // ── AppBar ────────────────────────────────────────────────────────────────
  PreferredSizeWidget _buildAppBar() {
    return AppBar(
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
            colors: [_primary, Color(0xFF0A3A6B)],
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
          ),
        ),
      ),
      leading: _paso > 0
          ? IconButton(
              icon: const Icon(Icons.arrow_back_rounded),
              onPressed: _retroceder,
            )
          : null,
    );
  }

  // ── Formulario principal ──────────────────────────────────────────────────
  Widget _buildFormulario() {
    return Column(
      children: [
        // ── Bienvenida + tarjeta operador ────────────────────────────
        _buildHeader(),

        // ── Indicador de pasos ───────────────────────────────────────
        Padding(
          padding: const EdgeInsets.fromLTRB(20, 16, 20, 0),
          child: _buildIndicadorPasos(),
        ),

        // ── Contenido del paso ───────────────────────────────────────
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

  // ── Header con bienvenida ─────────────────────────────────────────────────
  Widget _buildHeader() {
    final List<Map<String, dynamic>> pasoInfo = [
      {
        'titulo':      '¡Vamos a registrar tu carga!',
        'sub':         'Primero necesitamos el folio de tu papeleta.',
        'icono':       Icons.assignment_rounded,
        'color':       _primary,
      },
      {
        'titulo':      '¿Qué material cargas?',
        'sub':         'Selecciona el tipo de producto que traes.',
        'icono':       Icons.category_rounded,
        'color':       const Color(0xFF7C3AED),
      },
      {
        'titulo':      'Ahora los pesos',
        'sub':         'Ingresa el peso de entrada y salida.',
        'icono':       Icons.scale_rounded,
        'color':       _accent,
      },
    ];

    final info  = pasoInfo[_paso];
    final color = info['color'] as Color;

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.fromLTRB(20, 20, 20, 20),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: [color, color.withOpacity(0.75)],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        boxShadow: [
          BoxShadow(
            color: color.withOpacity(0.3),
            blurRadius: 16,
            offset: const Offset(0, 6),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Operador / camión / fecha
          Row(
            children: [
              _chip(Icons.person_rounded, widget.operador),
              const SizedBox(width: 8),
              _chip(Icons.local_shipping_rounded, widget.camion),
            ],
          ),
          const SizedBox(height: 4),
          Row(
            children: [
              _chip(Icons.pin_rounded, widget.placas),
              const SizedBox(width: 8),
              _chip(Icons.access_time_rounded, _fechaHora),
            ],
          ),
          const SizedBox(height: 14),
          // Mensaje del paso
          Row(
            children: [
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
                            fontSize: 17,
                            fontWeight: FontWeight.w800)),
                    const SizedBox(height: 3),
                    Text(info['sub'] as String,
                        style: TextStyle(
                            color: Colors.white.withOpacity(0.8),
                            fontSize: 12.5)),
                  ],
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _chip(IconData icon, String label) => Container(
        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
        decoration: BoxDecoration(
          color: Colors.white.withOpacity(0.15),
          borderRadius: BorderRadius.circular(20),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(icon, color: Colors.white70, size: 12),
            const SizedBox(width: 4),
            Text(label,
                style: const TextStyle(
                    color: Colors.white,
                    fontSize: 11,
                    fontWeight: FontWeight.w600)),
          ],
        ),
      );

  // ── Indicador de pasos ────────────────────────────────────────────────────
  Widget _buildIndicadorPasos() {
    final labels = ['Folio', 'Producto', 'Pesos'];
    final colors = [_primary, const Color(0xFF7C3AED), _accent];

    return Row(
      children: List.generate(3, (i) {
        final done   = i < _paso;
        final active = i == _paso;
        final color  = colors[i];

        return Expanded(
          child: Row(
            children: [
              Expanded(
                child: Column(
                  children: [
                    AnimatedContainer(
                      duration: const Duration(milliseconds: 300),
                      width:  active ? 38 : 30,
                      height: active ? 38 : 30,
                      decoration: BoxDecoration(
                        color: done
                            ? _success
                            : active
                                ? color
                                : Colors.white,
                        shape: BoxShape.circle,
                        border: Border.all(
                          color: done
                              ? _success
                              : active
                                  ? color
                                  : const Color(0xFFCBD5E1),
                          width: 2,
                        ),
                        boxShadow: active
                            ? [
                                BoxShadow(
                                    color: color.withOpacity(0.35),
                                    blurRadius: 10,
                                    offset: const Offset(0, 3))
                              ]
                            : [],
                      ),
                      child: Center(
                        child: done
                            ? const Icon(Icons.check_rounded,
                                color: Colors.white, size: 16)
                            : Text('${i + 1}',
                                style: TextStyle(
                                    fontSize: 13,
                                    fontWeight: FontWeight.w800,
                                    color: active
                                        ? Colors.white
                                        : _slate)),
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(labels[i],
                        style: TextStyle(
                            fontSize: 10,
                            fontWeight: active
                                ? FontWeight.w700
                                : FontWeight.w500,
                            color: active ? color : _slate)),
                  ],
                ),
              ),
              if (i < 2)
                Expanded(
                  child: Container(
                    height: 2,
                    margin: const EdgeInsets.only(bottom: 18),
                    decoration: BoxDecoration(
                      color: i < _paso
                          ? _success
                          : const Color(0xFFE2E8F0),
                      borderRadius: BorderRadius.circular(1),
                    ),
                  ),
                ),
            ],
          ),
        );
      }),
    );
  }

  // ── Contenido según el paso ───────────────────────────────────────────────
  Widget _buildContenidoPaso() {
    switch (_paso) {
      case 0: return _buildPasoFolio();
      case 1: return _buildPasoProducto();
      case 2: return _buildPasoPesos();
      default: return const SizedBox.shrink();
    }
  }

  // ── PASO 0: Folio ─────────────────────────────────────────────────────────
  Widget _buildPasoFolio() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _labelCampo('Número de folio', Icons.tag_rounded, _primary),
        const SizedBox(height: 10),
        _inputGrande(
          controller: _folioCtrl,
          hint: 'Ej: 00123',
          tipo: TextInputType.number,
          formatters: [FilteringTextInputFormatter.digitsOnly],
          color: _primary,
          onSubmit: _avanzar,
        ),
        const SizedBox(height: 8),
        Text(
          '💡 Encuentra el folio en la parte superior de tu papeleta.',
          style: TextStyle(fontSize: 12, color: _slate),
        ),
        const SizedBox(height: 28),
        _botonAvanzar('Siguiente — Tipo de producto',
            Icons.arrow_forward_rounded, _primary),
      ],
    );
  }

  // ── PASO 1: Producto ──────────────────────────────────────────────────────
  Widget _buildPasoProducto() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _labelCampo(
            'Selecciona el tipo de material', Icons.category_rounded,
            const Color(0xFF7C3AED)),
        const SizedBox(height: 12),
        // Grid de productos
        GridView.builder(
          shrinkWrap: true,
          physics: const NeverScrollableScrollPhysics(),
          gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
            crossAxisCount:   2,
            crossAxisSpacing: 10,
            mainAxisSpacing:  10,
            childAspectRatio: 2.4,
          ),
          itemCount: _productos.length,
          itemBuilder: (_, i) {
            final prod     = _productos[i];
            final selected = _productoSeleccionado == prod['valor'];
            return GestureDetector(
              onTap: () =>
                  setState(() => _productoSeleccionado = prod['valor']),
              child: AnimatedContainer(
                duration: const Duration(milliseconds: 180),
                decoration: BoxDecoration(
                  color: selected
                      ? const Color(0xFF7C3AED).withOpacity(0.1)
                      : _surface,
                  borderRadius: BorderRadius.circular(14),
                  border: Border.all(
                    color: selected
                        ? const Color(0xFF7C3AED)
                        : const Color(0xFFE2E8F0),
                    width: selected ? 2 : 1,
                  ),
                  boxShadow: selected
                      ? [
                          BoxShadow(
                            color: const Color(0xFF7C3AED).withOpacity(0.15),
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
                          color: selected
                              ? const Color(0xFF7C3AED)
                              : _primary,
                        ),
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                    if (selected) ...[
                      const SizedBox(width: 4),
                      const Icon(Icons.check_circle_rounded,
                          color: Color(0xFF7C3AED), size: 16),
                    ],
                  ],
                ),
              ),
            );
          },
        ),
        const SizedBox(height: 24),
        _botonAvanzar('Siguiente — Ingresar pesos',
            Icons.arrow_forward_rounded, const Color(0xFF7C3AED)),
        const SizedBox(height: 8),
        _botonVolver(),
      ],
    );
  }

  // ── PASO 2: Pesos ─────────────────────────────────────────────────────────
  Widget _buildPasoPesos() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // Resumen de lo anterior
        Container(
          padding: const EdgeInsets.all(14),
          decoration: BoxDecoration(
            color: _accent.withOpacity(0.06),
            borderRadius: BorderRadius.circular(14),
            border: Border.all(color: _accent.withOpacity(0.2)),
          ),
          child: Row(
            children: [
              Icon(Icons.summarize_rounded, color: _accent, size: 20),
              const SizedBox(width: 10),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text('Folio: ${_folioCtrl.text.trim()}',
                        style: const TextStyle(
                            fontSize: 13, fontWeight: FontWeight.w700)),
                    Text('Producto: $_productoSeleccionado',
                        style:
                            TextStyle(fontSize: 12, color: _slate)),
                  ],
                ),
              ),
            ],
          ),
        ),
        const SizedBox(height: 20),

        // Peso entrada
        _labelCampo('Peso de entrada (kg)',
            Icons.arrow_downward_rounded, _accent),
        const SizedBox(height: 10),
        _inputGrande(
          controller: _entradaCtrl,
          hint: 'Ej: 12500',
          tipo: TextInputType.number,
          formatters: [FilteringTextInputFormatter.digitsOnly],
          color: _accent,
          onChanged: (_) => _calcularNeto(),
        ),
        const SizedBox(height: 16),

        // Peso salida
        _labelCampo('Peso de salida (kg)',
            Icons.arrow_upward_rounded, const Color(0xFFDC2626)),
        const SizedBox(height: 10),
        _inputGrande(
          controller: _salidaCtrl,
          hint: 'Ej: 2000',
          tipo: TextInputType.number,
          formatters: [FilteringTextInputFormatter.digitsOnly],
          color: const Color(0xFFDC2626),
          onChanged: (_) => _calcularNeto(),
          onSubmit: _avanzar,
        ),
        const SizedBox(height: 20),

        // Peso neto calculado
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
          child: Column(
            children: [
              Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
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
                ],
              ),
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
            ],
          ),
        ),
        const SizedBox(height: 28),

        // Botón guardar
        SizedBox(
          width:  double.infinity,
          height: 56,
          child: ElevatedButton.icon(
            style: ElevatedButton.styleFrom(
              backgroundColor: _accent,
              foregroundColor: Colors.white,
              elevation: 4,
              shadowColor: _accent.withOpacity(0.4),
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

  // ── PANTALLA DE ÉXITO ─────────────────────────────────────────────────────
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
                // Círculo con palomita animada
                ScaleTransition(
                  scale: _successScale,
                  child: Container(
                    width: 130,
                    height: 130,
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
                          width: 90,
                          height: 90,
                          decoration: const BoxDecoration(
                            shape: BoxShape.circle,
                            color: _success,
                          ),
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
                      color: _primary,
                    ),
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
                      border: Border.all(color: const Color(0xFFE2E8F0)),
                    ),
                    child: Column(
                      children: [
                        _resumenFila(Icons.tag_rounded, 'Folio',
                            _folioCtrl.text.trim(), _primary),
                        _resumenFila(Icons.category_rounded, 'Producto',
                            _productoSeleccionado ?? '—',
                            const Color(0xFF7C3AED)),
                        _resumenFila(Icons.scale_rounded, 'Peso neto',
                            '${NumberFormat('#,###.##').format(_pesoNeto)} kg',
                            _success),
                        _resumenFila(Icons.calendar_today_rounded,
                            'Fecha', _fechaHora, _slate),
                      ],
                    ),
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
                      icon: const Icon(Icons.arrow_back_rounded,
                          size: 20),
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

  Widget _resumenFila(
      IconData icon, String label, String valor, Color color) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 6),
      child: Row(
        children: [
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
        ],
      ),
    );
  }

  // ── Helpers de UI ─────────────────────────────────────────────────────────
  Widget _labelCampo(String texto, IconData icon, Color color) {
    return Row(
      children: [
        Icon(icon, size: 18, color: color),
        const SizedBox(width: 8),
        Text(texto,
            style: const TextStyle(
                fontSize: 15,
                fontWeight: FontWeight.w800,
                color: _primary)),
      ],
    );
  }

  Widget _inputGrande({
    required TextEditingController controller,
    required String hint,
    required TextInputType tipo,
    required Color color,
    List<TextInputFormatter>? formatters,
    ValueChanged<String>? onChanged,
    VoidCallback? onSubmit,
  }) {
    return TextField(
      controller:      controller,
      keyboardType:    tipo,
      inputFormatters: formatters,
      autofocus:       true,
      onChanged:       onChanged,
      onSubmitted:     onSubmit != null ? (_) => onSubmit() : null,
      style: const TextStyle(
          fontSize: 26, fontWeight: FontWeight.w800, color: _primary),
      decoration: InputDecoration(
        hintText: hint,
        hintStyle: TextStyle(
            color: Colors.grey[400],
            fontSize: 22,
            fontWeight: FontWeight.w400),
        filled:    true,
        fillColor: color.withOpacity(0.04),
        contentPadding: const EdgeInsets.symmetric(
            horizontal: 18, vertical: 16),
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(14),
          borderSide: BorderSide(color: color.withOpacity(0.3)),
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(14),
          borderSide: BorderSide(color: color.withOpacity(0.3)),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(14),
          borderSide: BorderSide(color: color, width: 2.5),
        ),
      ),
    );
  }

  Widget _botonAvanzar(String texto, IconData icon, Color color) {
    return SizedBox(
      width:  double.infinity,
      height: 54,
      child: ElevatedButton.icon(
        style: ElevatedButton.styleFrom(
          backgroundColor: color,
          foregroundColor: Colors.white,
          elevation: 3,
          shadowColor: color.withOpacity(0.35),
          shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(16)),
        ),
        onPressed: _avanzar,
        icon:  Icon(icon, size: 20),
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
        icon: const Icon(Icons.arrow_back_rounded, size: 16),
        label: const Text('Volver al paso anterior'),
        style: TextButton.styleFrom(foregroundColor: _slate),
      ),
    );
  }
}