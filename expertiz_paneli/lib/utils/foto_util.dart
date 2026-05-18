import 'package:image_picker/image_picker.dart';
import 'dart:io';
import 'package:flutter/foundation.dart'; // EKLENDI

class FotoUtil {
  static final ImagePicker _picker = ImagePicker();

  static Future<String?> fotografCek() async {
    try {
      final XFile? foto = await _picker.pickImage(
        source: ImageSource.camera,
        imageQuality: 85,
        maxWidth: 1200,
      );
      return foto?.path;
    } catch (e) {
      debugPrint('Fotoğraf çekme hatası: $e');
      return null;
    }
  }

  static Future<String?> galeridenSec() async {
    try {
      final XFile? foto = await _picker.pickImage(
        source: ImageSource.gallery,
        imageQuality: 85,
        maxWidth: 1200,
      );
      return foto?.path;
    } catch (e) {
      debugPrint('Galeri seçme hatası: $e');
      return null;
    }
  }

  static Future<List<String>> birdenFazlaSec() async {
    try {
      final List<XFile> fotolar = await _picker.pickMultiImage(
        imageQuality: 85,
        maxWidth: 1200,
      );
      return fotolar.map((foto) => foto.path).toList();
    } catch (e) {
      debugPrint('Çoklu seçim hatası: $e');
      return [];
    }
  }

  static Future<String?> videoCek() async {
    try {
      final XFile? video = await _picker.pickVideo(source: ImageSource.camera);
      return video?.path;
    } catch (e) {
      debugPrint('Video çekme hatası: $e');
      return null;
    }
  }

  static Future<File?> dosyaSec() async {
    try {
      final XFile? dosya = await _picker.pickImage(source: ImageSource.gallery);
      if (dosya != null) {
        return File(dosya.path);
      }
      return null;
    } catch (e) {
      debugPrint('Dosya seçme hatası: $e');
      return null;
    }
  }
}
