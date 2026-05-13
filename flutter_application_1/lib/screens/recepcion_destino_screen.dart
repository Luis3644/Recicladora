import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:intl/intl.dart';

// ══════════════════════════════════════════════════════════════════════════════
//  PANTALLA 2 — Recepción en Destino (recicladora)
//  Busca el folio, agrega pesos de llegada y calcula merma/ganancia
// ══════════════════════════════════════════════════════════════════════════════

class RecepcionDestinoScreen extends StatefulWidget {
  final String operador;
  final String camion;
  final String placas;

  const RecepcionDestinoScreen({
    super.key,
    required this.operador,
    required this.camion,
    required this.placas,
  });

  @override
  State<RecepcionDestinoScreen> createState() => _RecepcionDestinoScreenState();
}

class _RecepcionDestinoScreenState extends State<RecepcionDestinoScreen>
    with TickerProviderStateMixin {

  // ── Colores ───────────────────────────────────────────────────────────────
  static const Color _primary  = Color(0xFF031A47);
  static const Color _accent   = Color(0xFF0F766E);
  static const Color _success  = Color(0xFF10B981);
  static const Color _warning  = Color(0xFFF59E0B);
  static const Color _bgColor  = Color(0xFFF1F5F9);
  static const Color _surface  = Color(0xFFFFFFFF);
  static const Color _slate    = Color(0xFF64748B);
  static const Color _merma    = Color(0xFFDC2626);    // rojo  = perdió peso
  static const Color _ganancia = Color(0xFF7C3AED);    // violeta = ganó peso

  // ── Estados: 'buscar' | 'pesos' | 'resultado' ─────────────────────────────
  String _estado = 'buscar';

  // ── Controllers ───────────────────────────────────────────────────────────
  final _folioCtrl   = TextEditingController();
  final _entradaCtrl = TextEditingController();
  final _salidaCtrl  = TextEditingController();

  // ── Datos del viaje encontrado ────────────────────────────────────────────
  Map<String, dynamic>? _viajeData;
  bool _buscando  = false;
  bool _guardando = false;

  // ── Pesos calculados ──────────────────────────────────────────────────────
  double _pesoNetoDestino  = 0.0;
  double _pesoNetoOrigen   = 0.0;
  double _diferencia       = 0.0;      // positivo = ganó, negativo = perdió
  String _tipoDiferencia   = '';       // 'merma' | 'ganancia' | 'igual'

  // ── Animaciones ───────────────────────────────────────────────────────────
  late AnimationController _successCtrl;
  late AnimationController _scaleCtrl;
  late Animation<double>   _successScale;
  late Animation<double>   _successOpacity;
  late Animation<double>   _checkScale;

  final String _fechaHora =
      DateFormat('dd/MM/yyyy  HH:mm').format(DateTime.now());

  @override
  void initState() {
    super.initState();
    _successCtrl = AnimationController(vsync: this, duration: const Duration(milliseconds: 800));
    _scaleCtrl   = AnimationController(vsync: this, duration: const Duration(milliseconds: 600));
    _successScale   = CurvedAnimation(parent: _successCtrl, curve: Curves.elasticOut);
    _successOpacity = CurvedAnimation(parent: _successCtrl, curve: Curves.easeIn);
    _checkScale     = CurvedAnimation(parent: _scaleCtrl,   curve: Curves.elasticOut);
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

  // ── Buscar folio en Firestore ─────────────────────────────────────────────
  Future<void> _buscarFolio() async {
    final folio = _folioCtrl.text.trim();
    if (folio.isEmpty) { _snack('Ingresa el número de folio'); return; }

    setState(() => _buscando = true);
    try {
      final doc = await FirebaseFirestore.instance
          .collection('registros_transporte')
          .doc(folio)
          .get();

      if (!doc.exists) {
        _snack('❌ No se encontró ningún viaje con el folio "$folio"');
        setState(() => _buscando = false);
        return;
      }

      final data = doc.data()!;

      if (data['estado'] == 'completado') {
        _snack('⚠️ Este viaje ya fue recibido en la recicladora');
        setState(() => _buscando = false);
        return;
      }

      setState(() {
        _viajeData         = data;
        _pesoNetoOrigen    = (data['peso_neto_origen'] ?? 0.0).toDouble();
        _buscando          = false;
        _estado            = 'pesos';
      });
    } catch (e) {
      setState(() => _buscando = false);
      _snack('Error al buscar: $e');
    }
  }

  void _calcularNeto() {
    final entrada = double.tryParse(_entradaCtrl.text) ?? 0.0;
    final salida  = double.tryParse(_salidaCtrl.text)  ?? 0.0;
    final neto    = (entrada - salida).abs();
    final diff    = neto - _pesoNetoOrigen;

    setState(() {
      _pesoNetoDestino = neto;
      _diferencia      = diff;
      _tipoDiferencia  = diff < -0.5
          ? 'merma'
          : diff > 0.5
              ? 'ganancia'
              : 'igual';
    });
  }

  // ── Guardar pesos de destino en Firestore ─────────────────────────────────
  Future<void> _guardar() async {
    if (_entradaCtrl.text.trim().isEmpty || _salidaCtrl.text.trim().isEmpty) {
      _snack('Ingresa ambos pesos'); return;
    }
    if (double.tryParse(_entradaCtrl.text) == null ||
        double.tryParse(_salidaCtrl.text) == null) {
      _snack('Los pesos deben ser números válidos'); return;
    }

    setState(() => _guardando = true);
    try {
      final folio = _folioCtrl.text.trim();
      await FirebaseFirestore.instance
          .collection('registros_transporte')
          .doc(folio)
          .update({
        'peso_entrada_destino': double.tryParse(_entradaCtrl.text) ?? 0.0,
        'peso_salida_destino':  double.tryParse(_salidaCtrl.text)  ?? 0.0,
        'peso_neto_destino':    _pesoNetoDestino,
        'diferencia_kg':        _diferencia,
        'tipo_diferencia':      _tipoDiferencia,
        'estado':               'completado',
        'fecha_destino':        FieldValue.serverTimestamp(),
        'fecha_destino_texto':  _fechaHora,
      });

      setState(() { _guardando = false; _estado = 'resultado'; });
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
      appBar: _estado != 'resultado' ? _buildAppBar() : null,
      body: AnimatedSwitcher(
        duration: const Duration(milliseconds: 350),
        child: _estado == 'buscar'
            ? _buildBuscar()
            : _estado == 'pesos'
                ? _buildPesos()
                : _buildResultado(),
      ),
    );
  }

  PreferredSizeWidget _buildAppBar() {
    return AppBar(
      title: Text(
        _estado == 'buscar' ? 'Recepción en Recicladora' : 'Pesos de llegada',
        style: const TextStyle(fontWeight: FontWeight.w800, fontSize: 17),
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
      leading: _estado == 'pesos'
          ? IconButton(
              icon: const Icon(Icons.arrow_back_rounded),
              onPressed: () => setState(() {
                _estado = 'buscar';
                _viajeData = null;
                _entradaCtrl.clear();
                _salidaCtrl.clear();
              }))
          : null,
    );
  }

  // ══════════════════════════════════════════════════════════════════════════
  //  ESTADO 1: Buscar folio
  // ══════════════════════════════════════════════════════════════════════════
  Widget _buildBuscar() {
    return SingleChildScrollView(
      key: const ValueKey('buscar'),
      padding: const EdgeInsets.all(24),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Tarjeta operador
          Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: _surface,
              borderRadius: BorderRadius.circular(16),
              border: Border.all(color: const Color(0xFFE2E8F0)),
              boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.04), blurRadius: 8)],
            ),
            child: Row(children: [
              Container(
                padding: const EdgeInsets.all(10),
                decoration: BoxDecoration(color: _primary.withOpacity(0.08), shape: BoxShape.circle),
                child: const Icon(Icons.local_shipping_rounded, color: _primary, size: 24),
              ),
              const SizedBox(width: 12),
              Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                Text(widget.operador,
                    style: const TextStyle(fontSize: 15, fontWeight: FontWeight.w800, color: _primary)),
                Text('${widget.camion}  •  ${widget.placas}',
                    style: TextStyle(fontSize: 12, color: _slate)),
              ]),
            ]),
          ),
          const SizedBox(height: 28),

          // Título
          Row(children: [
            Container(
              padding: const EdgeInsets.all(10),
              decoration: BoxDecoration(
                  color: _accent.withOpacity(0.1), borderRadius: BorderRadius.circular(12)),
              child: const Icon(Icons.search_rounded, color: _accent, size: 22),
            ),
            const SizedBox(width: 12),
            const Expanded(
              child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                Text('¿Cuál es tu folio?',
                    style: TextStyle(fontSize: 18, fontWeight: FontWeight.w800, color: _primary)),
                Text('Ingresa el folio del viaje que registraste en origen.',
                    style: TextStyle(fontSize: 12, color: _slate)),
              ]),
            ),
          ]),
          const SizedBox(height: 20),

          // Input folio
          TextField(
            controller: _folioCtrl,
            keyboardType: TextInputType.number,
            inputFormatters: [FilteringTextInputFormatter.digitsOnly],
            autofocus: true,
            onSubmitted: (_) => _buscarFolio(),
            style: const TextStyle(fontSize: 32, fontWeight: FontWeight.w900, color: _primary),
            textAlign: TextAlign.center,
            decoration: InputDecoration(
              hintText: '00000',
              hintStyle: TextStyle(color: Colors.grey[300], fontSize: 32),
              filled: true,
              fillColor: _accent.withOpacity(0.04),
              contentPadding: const EdgeInsets.symmetric(vertical: 20),
              border:        OutlineInputBorder(borderRadius: BorderRadius.circular(16), borderSide: BorderSide(color: _accent.withOpacity(0.3))),
              enabledBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(16), borderSide: BorderSide(color: _accent.withOpacity(0.3))),
              focusedBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(16), borderSide: const BorderSide(color: _accent, width: 2.5)),
            ),
          ),
          const SizedBox(height: 28),

          SizedBox(
            width: double.infinity,
            height: 56,
            child: ElevatedButton.icon(
              style: ElevatedButton.styleFrom(
                backgroundColor: _accent,
                foregroundColor: Colors.white,
                elevation: 4,
                shadowColor: _accent.withOpacity(0.4),
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
              ),
              onPressed: _buscando ? null : _buscarFolio,
              icon: _buscando
                  ? const SizedBox(width: 22, height: 22,
                      child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2.5))
                  : const Icon(Icons.search_rounded, size: 22),
              label: Text(
                _buscando ? 'Buscando...' : 'Buscar viaje',
                style: const TextStyle(fontSize: 17, fontWeight: FontWeight.w800),
              ),
            ),
          ),
        ],
      ),
    );
  }

  // ══════════════════════════════════════════════════════════════════════════
  //  ESTADO 2: Ingresar pesos de llegada
  // ══════════════════════════════════════════════════════════════════════════
  Widget _buildPesos() {
    final data = _viajeData!;
    return SingleChildScrollView(
      key: const ValueKey('pesos'),
      padding: const EdgeInsets.all(20),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // ── Tarjeta resumen del viaje ──────────────────────────────────
          Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: _surface,
              borderRadius: BorderRadius.circular(16),
              border: Border.all(color: const Color(0xFFE2E8F0)),
              boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.04), blurRadius: 8)],
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(children: [
                  const Icon(Icons.local_shipping_rounded, color: _accent, size: 18),
                  const SizedBox(width: 8),
                  Text('Viaje encontrado — Folio ${_folioCtrl.text.trim()}',
                      style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w800, color: _accent)),
                ]),
                const Divider(height: 16),
                _infoFila('📍 Origen',   data['lugar_origen']  ?? '—'),
                _infoFila('🌤️ Clima',    data['clima_origen']  ?? '—'),
                _infoFila('📦 Producto', data['producto']      ?? '—'),
                _infoFila('🕐 Salió',    data['fecha_origen_texto'] ?? '—'),
                if ((data['observaciones'] ?? '').toString().isNotEmpty)
                  _infoFila('📝 Nota',   data['observaciones']),
                const Divider(height: 16),
                // Peso neto en origen
                Row(children: [
                  const Icon(Icons.scale_rounded, color: _slate, size: 16),
                  const SizedBox(width: 6),
                  const Text('Peso neto en origen:',
                      style: TextStyle(fontSize: 13, color: _slate, fontWeight: FontWeight.w600)),
                  const Spacer(),
                  Text(
                    '${NumberFormat('#,###.##').format(_pesoNetoOrigen)} kg',
                    style: const TextStyle(
                        fontSize: 15, fontWeight: FontWeight.w900, color: _primary),
                  ),
                ]),
              ],
            ),
          ),
          const SizedBox(height: 24),

          // ── Pesos de llegada ───────────────────────────────────────────
          _labelCampo('Peso de entrada aquí (kg)', Icons.arrow_downward_rounded, _accent),
          const SizedBox(height: 10),
          _inputGrande(
            controller: _entradaCtrl,
            hint: 'Ej: 12200',
            color: _accent,
            onChanged: (_) => _calcularNeto(),
          ),
          const SizedBox(height: 16),

          _labelCampo('Peso de salida aquí (kg)', Icons.arrow_upward_rounded, _merma),
          const SizedBox(height: 10),
          _inputGrande(
            controller: _salidaCtrl,
            hint: 'Ej: 2000',
            color: _merma,
            onChanged: (_) => _calcularNeto(),
            onSubmit: _guardar,
          ),
          const SizedBox(height: 20),

          // ── Panel de diferencia ────────────────────────────────────────
          if (_pesoNetoDestino > 0) ...[
            _buildPanelDiferencia(),
            const SizedBox(height: 24),
          ],

          // ── Botón guardar ──────────────────────────────────────────────
          SizedBox(
            width: double.infinity,
            height: 56,
            child: ElevatedButton.icon(
              style: ElevatedButton.styleFrom(
                backgroundColor: _primary,
                foregroundColor: Colors.white,
                elevation: 4,
                shadowColor: _primary.withOpacity(0.4),
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
              ),
              onPressed: _guardando ? null : _guardar,
              icon: _guardando
                  ? const SizedBox(width: 22, height: 22,
                      child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2.5))
                  : const Icon(Icons.check_circle_rounded, size: 22),
              label: Text(
                _guardando ? 'Cerrando registro...' : 'Confirmar recepción',
                style: const TextStyle(fontSize: 17, fontWeight: FontWeight.w800),
              ),
            ),
          ),
        ],
      ),
    );
  }

  // ── Panel visual de merma/ganancia ────────────────────────────────────────
  Widget _buildPanelDiferencia() {
    final esMerma    = _tipoDiferencia == 'merma';
    final esGanancia = _tipoDiferencia == 'ganancia';
    final color      = esMerma ? _merma : esGanancia ? _ganancia : _success;
    final emoji      = esMerma ? '📉' : esGanancia ? '📈' : '✅';
    final etiqueta   = esMerma ? 'MERMA' : esGanancia ? 'GANANCIA DE PESO' : 'SIN DIFERENCIA';
    final diffAbs    = _diferencia.abs();
    final pct        = _pesoNetoOrigen > 0
        ? (diffAbs / _pesoNetoOrigen * 100).toStringAsFixed(1)
        : '0.0';

    return Container(
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: color.withOpacity(0.06),
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: color.withOpacity(0.35), width: 2),
      ),
      child: Column(
        children: [
          // Comparativa Origen vs Destino
          Row(children: [
            Expanded(
              child: _cajaComparativa(
                'ORIGEN', _pesoNetoOrigen, const Color(0xFF0891B2)),
            ),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 8),
              child: Text('→',
                  style: TextStyle(fontSize: 22, color: color, fontWeight: FontWeight.w900)),
            ),
            Expanded(
              child: _cajaComparativa(
                'DESTINO', _pesoNetoDestino, color),
            ),
          ]),
          const SizedBox(height: 16),
          const Divider(height: 1),
          const SizedBox(height: 14),

          // Resultado
          Row(mainAxisAlignment: MainAxisAlignment.center, children: [
            Text(emoji, style: const TextStyle(fontSize: 22)),
            const SizedBox(width: 8),
            Text(etiqueta,
                style: TextStyle(
                    fontSize: 13, fontWeight: FontWeight.w900,
                    color: color, letterSpacing: 0.5)),
          ]),
          const SizedBox(height: 8),
          Text(
            esMerma || esGanancia
                ? '${esMerma ? '-' : '+'}${NumberFormat('#,###.##').format(diffAbs)} kg  ($pct%)'
                : 'El peso llegó igual al registrado en origen',
            style: TextStyle(
                fontSize: esMerma || esGanancia ? 24 : 14,
                fontWeight: FontWeight.w900,
                color: color,
                letterSpacing: -0.5),
            textAlign: TextAlign.center,
          ),
          if (esMerma) ...[
            const SizedBox(height: 6),
            Text(
              'Posible causa: material caído en trayecto o agua evaporada.',
              style: TextStyle(fontSize: 11, color: _slate),
              textAlign: TextAlign.center,
            ),
          ] else if (esGanancia) ...[
            const SizedBox(height: 6),
            Text(
              'Posible causa: lluvia o humedad acumulada durante el viaje.',
              style: TextStyle(fontSize: 11, color: _slate),
              textAlign: TextAlign.center,
            ),
          ],
        ],
      ),
    );
  }

  Widget _cajaComparativa(String label, double valor, Color color) {
    return Container(
      padding: const EdgeInsets.symmetric(vertical: 10, horizontal: 8),
      decoration: BoxDecoration(
        color: color.withOpacity(0.08),
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: color.withOpacity(0.2)),
      ),
      child: Column(
        children: [
          Text(label, style: TextStyle(fontSize: 9, fontWeight: FontWeight.w800, color: color, letterSpacing: 0.5)),
          const SizedBox(height: 4),
          Text(
            NumberFormat('#,###').format(valor),
            style: TextStyle(fontSize: 20, fontWeight: FontWeight.w900, color: color),
          ),
          Text('kg', style: TextStyle(fontSize: 10, color: color)),
        ],
      ),
    );
  }

  // ══════════════════════════════════════════════════════════════════════════
  //  ESTADO 3: Resultado final
  // ══════════════════════════════════════════════════════════════════════════
  Widget _buildResultado() {
    final esMerma    = _tipoDiferencia == 'merma';
    final esGanancia = _tipoDiferencia == 'ganancia';
    final color      = esMerma ? _merma : esGanancia ? _ganancia : _success;
    final emoji      = esMerma ? '📉' : esGanancia ? '📈' : '✅';
    final diffAbs    = _diferencia.abs();
    final pct        = _pesoNetoOrigen > 0
        ? (diffAbs / _pesoNetoOrigen * 100).toStringAsFixed(1)
        : '0.0';

    return Container(
      key: const ValueKey('resultado'),
      color: _bgColor,
      child: Center(
        child: FadeTransition(
          opacity: _successOpacity,
          child: SingleChildScrollView(
            padding: const EdgeInsets.all(28),
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                // Ícono animado
                ScaleTransition(
                  scale: _successScale,
                  child: Container(
                    width: 130, height: 130,
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      color: color.withOpacity(0.1),
                      border: Border.all(color: color.withOpacity(0.3), width: 3),
                    ),
                    child: Center(
                      child: ScaleTransition(
                        scale: _checkScale,
                        child: Container(
                          width: 90, height: 90,
                          decoration: BoxDecoration(shape: BoxShape.circle, color: color),
                          child: Center(
                            child: Text(emoji, style: const TextStyle(fontSize: 40)),
                          ),
                        ),
                      ),
                    ),
                  ),
                ),
                const SizedBox(height: 20),
                ScaleTransition(
                  scale: _successScale,
                  child: const Text('¡Recepción completada!',
                      style: TextStyle(fontSize: 24, fontWeight: FontWeight.w900, color: _primary),
                      textAlign: TextAlign.center),
                ),
                const SizedBox(height: 6),
                FadeTransition(
                  opacity: _successOpacity,
                  child: Text('Folio ${_folioCtrl.text.trim()} cerrado',
                      style: TextStyle(fontSize: 14, color: _slate)),
                ),
                const SizedBox(height: 20),

                // Tarjeta de resumen completo
                FadeTransition(
                  opacity: _successOpacity,
                  child: Container(
                    padding: const EdgeInsets.all(18),
                    decoration: BoxDecoration(
                      color: _surface,
                      borderRadius: BorderRadius.circular(18),
                      border: Border.all(color: const Color(0xFFE2E8F0)),
                      boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.04), blurRadius: 10)],
                    ),
                    child: Column(
                      children: [
                        // Info viaje
                        _infoFila('📍 Origen',   _viajeData?['lugar_origen'] ?? '—'),
                        _infoFila('🌤️ Clima',    _viajeData?['clima_origen'] ?? '—'),
                        _infoFila('📦 Producto', _viajeData?['producto']     ?? '—'),
                        const Divider(height: 20),

                        // Comparativa de pesos
                        Row(children: [
                          Expanded(child: _cajaComparativa('ORIGEN',  _pesoNetoOrigen,  const Color(0xFF0891B2))),
                          Padding(
                            padding: const EdgeInsets.symmetric(horizontal: 8),
                            child: Text('→', style: TextStyle(fontSize: 20, color: color, fontWeight: FontWeight.w900)),
                          ),
                          Expanded(child: _cajaComparativa('DESTINO', _pesoNetoDestino, color)),
                        ]),
                        const SizedBox(height: 16),

                        // Resultado diferencia
                        Container(
                          width: double.infinity,
                          padding: const EdgeInsets.symmetric(vertical: 14),
                          decoration: BoxDecoration(
                            color: color.withOpacity(0.08),
                            borderRadius: BorderRadius.circular(12),
                            border: Border.all(color: color.withOpacity(0.2)),
                          ),
                          child: Column(
                            children: [
                              Text(
                                esMerma || esGanancia
                                    ? '${esMerma ? '-' : '+'}${NumberFormat('#,###.##').format(diffAbs)} kg ($pct%)'
                                    : '✅ Sin diferencia de peso',
                                style: TextStyle(
                                    fontSize: 22, fontWeight: FontWeight.w900,
                                    color: color, letterSpacing: -0.5),
                                textAlign: TextAlign.center,
                              ),
                              const SizedBox(height: 4),
                              Text(
                                esMerma ? 'Merma en tránsito' : esGanancia ? 'Ganancia de peso' : 'Peso exacto',
                                style: TextStyle(fontSize: 12, color: color, fontWeight: FontWeight.w700),
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
                const SizedBox(height: 28),

                ScaleTransition(
                  scale: _successScale,
                  child: SizedBox(
                    width: double.infinity,
                    height: 54,
                    child: ElevatedButton.icon(
                      style: ElevatedButton.styleFrom(
                        backgroundColor: _primary,
                        foregroundColor: Colors.white,
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                      ),
                      onPressed: () => Navigator.pop(context),
                      icon: const Icon(Icons.arrow_back_rounded, size: 20),
                      label: const Text('Volver a jornada',
                          style: TextStyle(fontSize: 16, fontWeight: FontWeight.w700)),
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

  // ── Helpers ───────────────────────────────────────────────────────────────
  Widget _infoFila(String label, String valor) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 3),
      child: Row(children: [
        Text(label, style: TextStyle(fontSize: 12, color: _slate, fontWeight: FontWeight.w600)),
        const Spacer(),
        Flexible(
          child: Text(valor,
              style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w800, color: _primary),
              textAlign: TextAlign.right),
        ),
      ]),
    );
  }

  Widget _labelCampo(String texto, IconData icon, Color color) {
    return Row(children: [
      Icon(icon, size: 18, color: color),
      const SizedBox(width: 8),
      Text(texto, style: const TextStyle(fontSize: 15, fontWeight: FontWeight.w800, color: _primary)),
    ]);
  }

  Widget _inputGrande({
    required TextEditingController controller,
    required String hint,
    required Color color,
    ValueChanged<String>? onChanged,
    VoidCallback? onSubmit,
  }) {
    return TextField(
      controller: controller,
      keyboardType: TextInputType.number,
      inputFormatters: [FilteringTextInputFormatter.digitsOnly],
      onChanged: onChanged,
      onSubmitted: onSubmit != null ? (_) => onSubmit() : null,
      style: const TextStyle(fontSize: 26, fontWeight: FontWeight.w800, color: _primary),
      decoration: InputDecoration(
        hintText: hint,
        hintStyle: TextStyle(color: Colors.grey[400], fontSize: 22, fontWeight: FontWeight.w400),
        filled: true,
        fillColor: color.withOpacity(0.04),
        contentPadding: const EdgeInsets.symmetric(horizontal: 18, vertical: 16),
        border:        OutlineInputBorder(borderRadius: BorderRadius.circular(14), borderSide: BorderSide(color: color.withOpacity(0.3))),
        enabledBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(14), borderSide: BorderSide(color: color.withOpacity(0.3))),
        focusedBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(14), borderSide: BorderSide(color: color, width: 2.5)),
      ),
    );
  }
}