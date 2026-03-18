import 'dart:io';
import 'dart:typed_data'; // Importante para WEB
import 'package:flutter/foundation.dart'; // Para detectar kIsWeb
import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import 'package:firebase_storage/firebase_storage.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'widgets_conexion/connection_wrapper.dart';

class ReporteScreen extends StatefulWidget {
  final String nombreUsuario;
  final String camion;
  final String placas;

  const ReporteScreen({
    super.key, 
    required this.nombreUsuario, 
    required this.camion, 
    required this.placas
  });

  @override
  State<ReporteScreen> createState() => _ReporteScreenState();
}

class _ReporteScreenState extends State<ReporteScreen> {
  final TextEditingController _descripcionController = TextEditingController();
  
  XFile? _imagenXFile; // Cambio: Usamos XFile en lugar de File
  Uint8List? _webImage; // Para mostrar la imagen en el navegador
  bool _subiendo = false;

  final ImagePicker _picker = ImagePicker();

  // Función para elegir imagen (Cámara o Galería)
  Future<void> _seleccionarImagen(ImageSource source) async {
    final pickedFile = await _picker.pickImage(source: source, imageQuality: 50);
    
    if (pickedFile != null) {
      if (kIsWeb) {
        var f = await pickedFile.readAsBytes();
        setState(() {
          _webImage = f;
          _imagenXFile = pickedFile;
        });
      } else {
        setState(() {
          _imagenXFile = pickedFile;
        });
      }
    }
  }

  Future<void> _enviarReporte() async {
    if (_descripcionController.text.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text("Escribe el mensaje del problema")));
      return;
    }

    setState(() => _subiendo = true);

    try {
      String? imageUrl;
      if (_imagenXFile != null) {
        String fileName = 'reportes/${DateTime.now().millisecondsSinceEpoch}.jpg';
      
        Reference storageRef = FirebaseStorage.instance.ref().child(fileName);
        UploadTask uploadTask;
        // CORRECCIÓN PARA WEB: Usamos putData o putBlob en lugar de putFile
        if (kIsWeb) {
         uploadTask = storageRef.putData(_webImage!, SettableMetadata(contentType: 'image/jpeg'));
        } else {
         uploadTask = storageRef.putFile(File(_imagenXFile!.path), SettableMetadata(contentType: 'image/jpeg'));
        }
        
        TaskSnapshot snapshot = await uploadTask;
        imageUrl = await snapshot.ref.getDownloadURL();
      }

      await FirebaseFirestore.instance.collection("reportes").add({
        "camion": widget.camion,
        "fecha": FieldValue.serverTimestamp(),
        "mensaje": _descripcionController.text,
        "operador": widget.nombreUsuario,
        "placas": widget.placas,
        "fotoUrl": imageUrl ?? "",
        "visto": false,
      });

      if (mounted) {
        Navigator.pop(context);
        ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text("Reporte enviado al Administrador")));
      }
    } catch (e) {
      print("ERROR DETECTADO: $e"); // Esto te dirá más en la consola de VS Code/Android Studio
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text("Error al enviar: $e")));
    } finally {
      if (mounted) setState(() => _subiendo = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return ConnectionWrapper(
      child: Scaffold(
        appBar: AppBar(
          title: const Text("Reportar Incidente"),
          backgroundColor: const Color(0xFF1E3A8A),
        ),
        body: SingleChildScrollView(
          padding: const EdgeInsets.all(20),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text("Camión: ${widget.camion} (${widget.placas})", 
                style: const TextStyle(fontWeight: FontWeight.bold, color: Colors.grey)),
              const SizedBox(height: 20),
              const Text("¿Cuál es el problema?", style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
              const SizedBox(height: 10),
              TextField(
                controller: _descripcionController,
                maxLines: 3,
                decoration: const InputDecoration(
                  hintText: "Escribe aquí tu reporte...",
                  border: OutlineInputBorder(),
                ),
              ),
              const SizedBox(height: 20),
              
              // --- VISTA PREVIA ADAPTADA ---
              Center(
                child: Container(
                  height: 180,
                  width: double.infinity,
                  decoration: BoxDecoration(
                    border: Border.all(color: Colors.grey.shade300),
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: _imagenXFile != null
                      ? (kIsWeb 
                          ? Image.memory(_webImage!, fit: BoxFit.contain) 
                          : Image.file(File(_imagenXFile!.path), fit: BoxFit.contain))
                      : const Icon(Icons.camera_alt_outlined, size: 80, color: Colors.grey),
                ),
              ),
              const SizedBox(height: 15),

              // --- BOTONES PARA EL OPERADOR ---
              Row(
                children: [
                  Expanded(
                    child: ElevatedButton.icon(
                      style: ElevatedButton.styleFrom(backgroundColor: Colors.blueGrey),
                      onPressed: () => _seleccionarImagen(ImageSource.camera),
                      icon: const Icon(Icons.photo_camera, color: Colors.white),
                      label: const Text("Tomar Foto", style: TextStyle(color: Colors.white)),
                    ),
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: ElevatedButton.icon(
                      style: ElevatedButton.styleFrom(backgroundColor: Colors.blueGrey),
                      onPressed: () => _seleccionarImagen(ImageSource.gallery),
                      icon: const Icon(Icons.image, color: Colors.white),
                      label: const Text("Galería", style: TextStyle(color: Colors.white)),
                    ),
                  ),
                ],
              ),

              const SizedBox(height: 30),
              _subiendo
                  ? const Center(child: CircularProgressIndicator())
                  : SizedBox(
                      width: double.infinity,
                      height: 50,
                      child: ElevatedButton(
                        style: ElevatedButton.styleFrom(backgroundColor: Colors.redAccent),
                        onPressed: _enviarReporte,
                        child: const Text("ENVIAR AHORA", style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
                      ),
                    ),
            ],
          ),
        ),
      ),
    );
  }
}