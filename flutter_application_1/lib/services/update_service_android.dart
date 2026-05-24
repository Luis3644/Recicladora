import 'dart:async';
import 'dart:io';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_storage/firebase_storage.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:package_info_plus/package_info_plus.dart';
import 'package:path_provider/path_provider.dart';

class UpdateService {
  static const String _versionDocPath = 'config/app_version';
  static const MethodChannel _installerChannel =
      MethodChannel('recicladora_update_installer');

  static Future<void> checkAndShowUpdateDialog(
    BuildContext context, {
    bool showNoUpdateDialog = true,
  }) async {
    if (kIsWeb || defaultTargetPlatform != TargetPlatform.android) {
      return;
    }

    try {
      final updateData = await _obtenerDatosActualizacion();
      if (updateData == null || !context.mounted) return;

      if (updateData.isNewVersion) {
        await _mostrarDialogoActualizacion(context, updateData);
      } else if (showNoUpdateDialog) {
        await _mostrarDialogoSinActualizacion(context);
      }
    } catch (e) {
      if (!context.mounted || !showNoUpdateDialog) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('No se pudo comprobar actualizaciones: $e')),
      );
    }
  }

  static Future<_UpdateData?> _obtenerDatosActualizacion() async {
    final doc = await FirebaseFirestore.instance.doc(_versionDocPath).get();
    final data = doc.data();
    if (data == null) return null;

    final version = data['version']?.toString().trim() ?? '';
    final changelog = data['changelog']?.toString().trim() ?? '';
    final urlApk = data['url_apk']?.toString().trim() ?? '';
    final remoteBuildNumber = _parseInt(data['build_number']);

    if (version.isEmpty || urlApk.isEmpty || remoteBuildNumber == null) {
      return null;
    }

    final packageInfo = await PackageInfo.fromPlatform();
    final localBuildNumber = int.tryParse(packageInfo.buildNumber) ?? 0;

    return _UpdateData(
      version: version,
      buildNumber: remoteBuildNumber,
      localBuildNumber: localBuildNumber,
      changelog: changelog,
      urlApk: urlApk,
    );
  }

  static int? _parseInt(dynamic value) {
    if (value is int) return value;
    if (value is num) return value.toInt();
    return int.tryParse(value?.toString() ?? '');
  }

  static Future<void> _mostrarDialogoActualizacion(
    BuildContext context,
    _UpdateData updateData,
  ) async {
    if (!context.mounted) return;

    final shouldUpdate = await showDialog<bool>(
      context: context,
      barrierDismissible: false,
      builder: (dialogContext) {
        return AlertDialog(
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(22),
          ),
          title: const Text(
            'Nueva versión disponible',
            style: TextStyle(fontWeight: FontWeight.w800),
          ),
          content: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Versión ${updateData.version} (build ${updateData.buildNumber})',
                  style: const TextStyle(
                    fontWeight: FontWeight.w600,
                    color: Color(0xFF334155),
                  ),
                ),
                const SizedBox(height: 12),
                const Text(
                  'Cambios incluidos:',
                  style: TextStyle(fontWeight: FontWeight.w700),
                ),
                const SizedBox(height: 6),
                Text(
                  updateData.changelog.isEmpty
                      ? 'No hay changelog disponible.'
                      : updateData.changelog,
                  style: const TextStyle(height: 1.4),
                ),
              ],
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(dialogContext).pop(false),
              child: const Text('Ahora no'),
            ),
            ElevatedButton(
              onPressed: () => Navigator.of(dialogContext).pop(true),
              child: const Text('Actualizar ahora'),
            ),
          ],
        );
      },
    );

    if (shouldUpdate == true && context.mounted) {
      await _descargarYEjecutarInstalador(context, updateData);
    }
  }

  static Future<void> _mostrarDialogoSinActualizacion(
    BuildContext context,
  ) async {
    if (!context.mounted) return;

    await showDialog<void>(
      context: context,
      barrierDismissible: true,
      builder: (dialogContext) {
        return AlertDialog(
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(22),
          ),
          title: const Text(
            '¡Todo al día!',
            style: TextStyle(fontWeight: FontWeight.w800),
          ),
          content: const Text('Tienes la versión más reciente instalada.'),
          actions: [
            ElevatedButton(
              onPressed: () => Navigator.of(dialogContext).pop(),
              child: const Text('Aceptar'),
            ),
          ],
        );
      },
    );
  }

  static Future<void> _descargarYEjecutarInstalador(
    BuildContext context,
    _UpdateData updateData,
  ) async {
    final navigator = Navigator.of(context, rootNavigator: true);
    var progress = 0.0;
    var status = 'Preparando descarga...';
    var showingDialog = true;

    void cerrarDialogoProgreso() {
      if (showingDialog && navigator.canPop()) {
        navigator.pop();
      }
      showingDialog = false;
    }

    Future<void> mostrarError(String message) async {
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(message)),
        );
      }
    }

    Future<void> iniciarDescarga(StateSetter setState) async {
      try {
        final file = await _descargarApk(
          updateData,
          onProgress: (value, newStatus) {
            if (!context.mounted) return;
            setState(() {
              progress = value;
              status = newStatus;
            });
          },
        );

        cerrarDialogoProgreso();
        await _abrirInstaladorNativo(file.path);
      } on PlatformException catch (e) {
        cerrarDialogoProgreso();
        await mostrarError('No se pudo abrir el instalador: ${e.message ?? e.code}');
      } catch (e) {
        cerrarDialogoProgreso();
        await mostrarError('Error al descargar la actualización: $e');
      }
    }

    await showDialog<void>(
      context: context,
      barrierDismissible: false,
      builder: (dialogContext) {
        var started = false;
        return StatefulBuilder(
          builder: (context, setState) {
            if (!started) {
              started = true;
              unawaited(iniciarDescarga(setState));
            }

            return AlertDialog(
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(22),
              ),
              title: const Text(
                'Descargando actualización',
                style: TextStyle(fontWeight: FontWeight.w800),
              ),
              content: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  LinearProgressIndicator(value: progress == 0 ? null : progress),
                  const SizedBox(height: 14),
                  Text(
                    status,
                    style: const TextStyle(fontWeight: FontWeight.w600),
                  ),
                  const SizedBox(height: 6),
                  Text('${(progress * 100).toStringAsFixed(0)}%'),
                ],
              ),
            );
          },
        );
      },
    );
  }

  static Future<File> _descargarApk(
    _UpdateData updateData, {
    required void Function(double progress, String status) onProgress,
  }) async {
    final directory = await getTemporaryDirectory();
    final fileName = 'recicladora_${updateData.version}_${updateData.buildNumber}.apk';
    final file = File('${directory.path}/$fileName');
    final ref = FirebaseStorage.instance.refFromURL(updateData.urlApk);
    final task = ref.writeToFile(file);

    final subscription = task.snapshotEvents.listen((snapshot) {
      if (snapshot.totalBytes <= 0) {
        onProgress(0, 'Descargando archivo...');
        return;
      }

      final progress = snapshot.bytesTransferred / snapshot.totalBytes;
      onProgress(progress, 'Descargando archivo...');
    });

    try {
      await task;
      onProgress(1, 'Descarga completada');
      return file;
    } finally {
      await subscription.cancel();
    }
  }

  static Future<void> _abrirInstaladorNativo(String apkPath) async {
    if (kIsWeb || defaultTargetPlatform != TargetPlatform.android) {
      return;
    }

    try {
      await _installerChannel.invokeMethod<void>(
        'openInstaller',
        {'apkPath': apkPath},
      );
    } on PlatformException catch (e) {
      throw PlatformException(
        code: e.code,
        message: e.message ?? 'No se pudo abrir el instalador de Android',
        details: e.details,
      );
    }
  }
}

class _UpdateData {
  const _UpdateData({
    required this.version,
    required this.buildNumber,
    required this.localBuildNumber,
    required this.changelog,
    required this.urlApk,
  });

  final String version;
  final int buildNumber;
  final int localBuildNumber;
  final String changelog;
  final String urlApk;

  bool get isNewVersion => buildNumber > localBuildNumber;
}