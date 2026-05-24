import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

// ══════════════════════════════════════════════════════════════════════════════
//  PANTALLA — Registro en Origen (Próximamente)
// ══════════════════════════════════════════════════════════════════════════════
class RegistroOrigenScreen extends StatefulWidget {
  final String operador;
  final String camion;
  final String placas;
  const RegistroOrigenScreen({
    super.key,
    required this.operador,
    required this.camion,
    required this.placas,
  });

  @override
  State<RegistroOrigenScreen> createState() => _RegistroOrigenScreenState();
}

class _RegistroOrigenScreenState extends State<RegistroOrigenScreen>
    with TickerProviderStateMixin {

  late final AnimationController _pulseCtrl;
  late final AnimationController _entradaCtrl;
  late final Animation<double>   _pulseAnim;
  late final Animation<double>   _fadeAnim;
  late final Animation<Offset>   _slideAnim;

  @override
  void initState() {
    super.initState();

    // Pulso del ícono
    _pulseCtrl = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1800),
    )..repeat(reverse: true);
    _pulseAnim = Tween<double>(begin: 0.92, end: 1.06).animate(
      CurvedAnimation(parent: _pulseCtrl, curve: Curves.easeInOut),
    );

    // Entrada de contenido
    _entradaCtrl = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 700),
    )..forward();
    _fadeAnim = CurvedAnimation(
        parent: _entradaCtrl, curve: Curves.easeOut);
    _slideAnim = Tween<Offset>(
      begin: const Offset(0, 0.06),
      end: Offset.zero,
    ).animate(CurvedAnimation(
        parent: _entradaCtrl, curve: Curves.easeOutCubic));
  }

  @override
  void dispose() {
    _pulseCtrl.dispose();
    _entradaCtrl.dispose();
    super.dispose();
  }

  // ── Features a mostrar ─────────────────────────────────────────────────────
  static const _features = [
    (
      icon : Icons.location_on_rounded,
      title: 'Registro de ubicación',
      sub  : 'Captura automática del punto de origen',
    ),
    (
      icon : Icons.local_shipping_rounded,
      title: 'Control de carga',
      sub  : 'Registra el material antes de salir',
    ),
    (
      icon : Icons.description_rounded,
      title: 'Folio de viaje',
      sub  : 'Genera comprobante del trayecto',
    ),
  ];

  @override
  Widget build(BuildContext context) {
    SystemChrome.setSystemUIOverlayStyle(const SystemUiOverlayStyle(
      statusBarBrightness: Brightness.dark,
      statusBarIconBrightness: Brightness.light,
    ));

    return Scaffold(
      backgroundColor: const Color(0xFF0F2754),
      appBar: _buildAppBar(),
      body: FadeTransition(
        opacity: _fadeAnim,
        child: SlideTransition(
          position: _slideAnim,
          child: SafeArea(
            child: SingleChildScrollView(
              physics: const ClampingScrollPhysics(),
              padding: const EdgeInsets.fromLTRB(24, 40, 24, 40),
              child: Column(
                children: [
                  // ── Ícono animado ──────────────────────────────
                  _IconoAnimado(pulseAnim: _pulseAnim),
                  const SizedBox(height: 28),

                  // ── Badge PRÓXIMAMENTE ─────────────────────────
                  _Badge(),
                  const SizedBox(height: 16),

                  // ── Título ─────────────────────────────────────
                  const Text(
                    'Registro\nen Origen',
                    textAlign: TextAlign.center,
                    style: TextStyle(
                      color: Colors.white,
                      fontSize: 32,
                      fontWeight: FontWeight.w900,
                      height: 1.15,
                      letterSpacing: -.5,
                    ),
                  ),
                  const SizedBox(height: 14),

                  // ── Subtítulo ──────────────────────────────────
                  Text(
                    'Esta funcionalidad está en desarrollo y estará disponible muy pronto para los operadores.',
                    textAlign: TextAlign.center,
                    style: TextStyle(
                      color: Colors.white.withOpacity(0.55),
                      fontSize: 14,
                      height: 1.6,
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                  const SizedBox(height: 32),

                  // ── Divisor ────────────────────────────────────
                  Container(
                    width: 40,
                    height: 3,
                    decoration: BoxDecoration(
                      color: Colors.white.withOpacity(0.12),
                      borderRadius: BorderRadius.circular(2),
                    ),
                  ),
                  const SizedBox(height: 32),

                  // ── Lista de features ──────────────────────────
                  Column(
                    children: _features.map((f) => _FeatureRow(
                      icon : f.icon,
                      title: f.title,
                      sub  : f.sub,
                    )).toList(),
                  ),
                  const SizedBox(height: 36),

                  // ── Botón notificación ─────────────────────────
                  _NotifyButton(),
                  const SizedBox(height: 16),

                  // ── Nota ───────────────────────────────────────
                  Text(
                    'Te notificaremos en cuanto esté disponible',
                    style: TextStyle(
                      color: Colors.white.withOpacity(0.28),
                      fontSize: 12,
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }

  PreferredSizeWidget _buildAppBar() => AppBar(
        backgroundColor: const Color(0xFF0F2754),
        elevation: 0,
        titleSpacing: 0,
        leading: Padding(
          padding: const EdgeInsets.only(left: 12),
          child: GestureDetector(
            onTap: () => Navigator.maybePop(context),
            child: Container(
              width: 36, height: 36,
              decoration: BoxDecoration(
                color: Colors.white.withOpacity(0.10),
                borderRadius: BorderRadius.circular(10),
              ),
              child: const Icon(Icons.arrow_back_ios_new_rounded,
                  color: Colors.white, size: 16),
            ),
          ),
        ),
        title: Padding(
          padding: const EdgeInsets.only(left: 4),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisSize: MainAxisSize.min,
            children: [
              const Text('Registro en Origen',
                  style: TextStyle(
                      color: Colors.white,
                      fontSize: 15,
                      fontWeight: FontWeight.w800)),
              Text(
                '${widget.operador} · ${widget.camion}',
                style: TextStyle(
                    color: Colors.white.withOpacity(0.45),
                    fontSize: 11,
                    fontWeight: FontWeight.w500),
              ),
            ],
          ),
        ),
        bottom: PreferredSize(
          preferredSize: const Size.fromHeight(1),
          child: Container(
              height: 1, color: Colors.white.withOpacity(0.08)),
        ),
      );
}

// ─── Ícono con pulso ──────────────────────────────────────────────────────────
class _IconoAnimado extends StatelessWidget {
  final Animation<double> pulseAnim;
  const _IconoAnimado({required this.pulseAnim});

  @override
  Widget build(BuildContext context) {
    return ScaleTransition(
      scale: pulseAnim,
      child: Container(
        width: 88, height: 88,
        decoration: BoxDecoration(
          color: Colors.white.withOpacity(0.07),
          borderRadius: BorderRadius.circular(26),
          border: Border.all(color: Colors.white.withOpacity(0.12), width: 1.5),
        ),
        child: const Icon(
          Icons.schedule_rounded,
          color: Color(0xFF60A5FA),
          size: 42,
        ),
      ),
    );
  }
}

// ─── Badge PRÓXIMAMENTE ───────────────────────────────────────────────────────
class _Badge extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 6),
      decoration: BoxDecoration(
        color: const Color(0xFF1D4ED8).withOpacity(0.55),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(
            color: const Color(0xFF3B82F6).withOpacity(0.5)),
      ),
      child: const Text(
        'PRÓXIMAMENTE',
        style: TextStyle(
          color: Color(0xFF93C5FD),
          fontSize: 11,
          fontWeight: FontWeight.w800,
          letterSpacing: .8,
        ),
      ),
    );
  }
}

// ─── Fila de feature ──────────────────────────────────────────────────────────
class _FeatureRow extends StatelessWidget {
  final IconData icon;
  final String   title;
  final String   sub;
  const _FeatureRow({
    required this.icon,
    required this.title,
    required this.sub,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.only(bottom: 10),
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 14),
      decoration: BoxDecoration(
        color: Colors.white.withOpacity(0.06),
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: Colors.white.withOpacity(0.10)),
      ),
      child: Row(children: [
        Container(
          width: 38, height: 38,
          decoration: BoxDecoration(
            color: const Color(0xFF1D4ED8).withOpacity(0.30),
            borderRadius: BorderRadius.circular(11),
          ),
          child: Icon(icon, color: const Color(0xFF60A5FA), size: 20),
        ),
        const SizedBox(width: 13),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(title,
                  style: const TextStyle(
                      color: Colors.white,
                      fontSize: 13,
                      fontWeight: FontWeight.w800)),
              const SizedBox(height: 2),
              Text(sub,
                  style: TextStyle(
                      color: Colors.white.withOpacity(0.45),
                      fontSize: 11,
                      fontWeight: FontWeight.w500)),
            ],
          ),
        ),
      ]),
    );
  }
}

// ─── Botón notificación ───────────────────────────────────────────────────────
class _NotifyButton extends StatefulWidget {
  @override
  State<_NotifyButton> createState() => _NotifyButtonState();
}

class _NotifyButtonState extends State<_NotifyButton> {
  bool _activado = false;

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: () {
        setState(() => _activado = !_activado);
        if (!_activado) return;
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: const Row(children: [
              Icon(Icons.check_circle_rounded,
                  color: Colors.white, size: 18),
              SizedBox(width: 10),
              Text('Te avisaremos cuando esté listo',
                  style: TextStyle(
                      color: Colors.white, fontWeight: FontWeight.w600)),
            ]),
            backgroundColor: const Color(0xFF059669),
            behavior: SnackBarBehavior.floating,
            margin: const EdgeInsets.all(16),
            shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(12)),
          ),
        );
      },
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 250),
        width: double.infinity,
        height: 54,
        decoration: BoxDecoration(
          color: _activado
              ? const Color(0xFF059669)
              : const Color(0xFF1D4ED8),
          borderRadius: BorderRadius.circular(14),
          boxShadow: [
            BoxShadow(
              color: (_activado
                  ? const Color(0xFF059669)
                  : const Color(0xFF1D4ED8)).withOpacity(0.35),
              blurRadius: 14,
              offset: const Offset(0, 5),
            ),
          ],
        ),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(
              _activado
                  ? Icons.check_rounded
                  : Icons.notifications_outlined,
              color: Colors.white,
              size: 20,
            ),
            const SizedBox(width: 10),
            Text(
              _activado ? 'Notificación activada' : 'Avisarme cuando esté listo',
              style: const TextStyle(
                  color: Colors.white,
                  fontSize: 14,
                  fontWeight: FontWeight.w800),
            ),
          ],
        ),
      ),
    );
  }
}