import 'dart:io';

import 'package:dio/dio.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:image_picker/image_picker.dart';

import '../config/env.dart';

final cloudinaryServiceProvider = Provider<CloudinaryService>((ref) {
  return CloudinaryService();
});

class CloudinaryException implements Exception {
  final String message;
  CloudinaryException(this.message);
  @override
  String toString() => message;
}

class CloudinaryService {
  final _picker = ImagePicker();
  final _dio = Dio();

  /// Pick an image from [source] and upload it to Cloudinary.
  /// Returns the secure URL, or null if the user cancelled.
  Future<String?> pickAndUpload({
    ImageSource source = ImageSource.gallery,
    String folder = 'trackparty',
  }) async {
    if (!Env.cloudinaryConfigured) {
      throw CloudinaryException('Cloudinary non configuré (CLOUDINARY_CLOUD_NAME / CLOUDINARY_UPLOAD_PRESET manquants).');
    }

    final picked = await _picker.pickImage(
      source: source,
      imageQuality: 85,
      maxWidth: 1200,
    );
    if (picked == null) return null;

    return _upload(File(picked.path), folder: folder);
  }

  Future<String> _upload(File file, {required String folder}) async {
    final url =
        'https://api.cloudinary.com/v1_1/${Env.cloudinaryCloudName}/image/upload';

    final formData = FormData.fromMap({
      'file': await MultipartFile.fromFile(file.path),
      'upload_preset': Env.cloudinaryUploadPreset,
      'folder': folder,
    });

    try {
      final res = await _dio.post(url, data: formData);
      final secureUrl = res.data['secure_url'] as String?;
      if (secureUrl == null) throw CloudinaryException('Réponse Cloudinary invalide.');
      return secureUrl;
    } on DioException catch (e) {
      final msg = (e.response?.data as Map?)?['error']?['message'] as String?;
      throw CloudinaryException(msg ?? 'Erreur upload Cloudinary.');
    }
  }
}
