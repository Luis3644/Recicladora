import 'package:url_launcher/url_launcher.dart';

Future<bool> openManualPdfImpl() async {
  final manualUri = Uri.parse('MANUAL%20PROYECTO.pdf');
  return launchUrl(manualUri, mode: LaunchMode.platformDefault);
}
