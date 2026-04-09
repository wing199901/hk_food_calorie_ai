import 'dart:convert';
import 'dart:io';
import 'dart:typed_data';

import 'package:image/image.dart' as img;
import 'package:supabase_flutter/supabase_flutter.dart';

/// Domain-specific exception for AI meal analysis failures.
class FoodAnalysisException implements Exception {
  final String message;

  const FoodAnalysisException(this.message);

  @override
  String toString() => 'FoodAnalysisException: $message';
}

/// Upload result reference for one analyzed image.
class UploadedImage {
  final String storagePath;
  final String publicUrl;

  const UploadedImage({required this.storagePath, required this.publicUrl});
}

/// Packed payload used to run upload and analysis in parallel.
class _PreparedImageUpload {
  final UploadedImage uploaded;
  final Uint8List uploadBytes;
  final String imageBase64;

  const _PreparedImageUpload({
    required this.uploaded,
    required this.uploadBytes,
    required this.imageBase64,
  });
}

/// Uploads a meal photo to Supabase Storage, then asks edge function to analyze it.
class FoodAnalysisService {
  FoodAnalysisService({
    SupabaseClient? client,
    DateTime Function()? now,
    Future<UploadedImage> Function(String imagePath)? uploadImage,
    Future<Map<String, dynamic>> Function(String imagePath, String date)?
    invokeAnalyze,
  }) : _client = client,
       _now = now ?? DateTime.now,
       _uploadImageOverride = uploadImage,
       _invokeAnalyzeOverride = invokeAnalyze;

  final SupabaseClient? _client;
  final DateTime Function() _now;
  final Future<UploadedImage> Function(String imagePath)? _uploadImageOverride;
  final Future<Map<String, dynamic>> Function(String imagePath, String date)?
  _invokeAnalyzeOverride;

  static const _bucketName = 'meal-images';
  static const _maxImageBytes = 1_500_000;
  static const _maxLongestEdgePx = 1280;

  SupabaseClient get _resolvedClient {
    final injected = _client;
    if (injected != null) return injected;
    return Supabase.instance.client;
  }

  static const List<String> _validImageExtensions = [
    '.jpg',
    '.jpeg',
    '.png',
    '.heic',
    '.webp',
  ];

  /// Analyzes an image path and returns one normalized meal payload.
  Future<Map<String, dynamic>> analyzeImage(String imagePath) async {
    try {
      _validateImagePath(imagePath);

      final nowUtc = _now().toUtc();
      final date = _formatIsoDate(nowUtc);
      final uploadImage = _uploadImageOverride;

      if (uploadImage != null) {
        final uploaded = await uploadImage(imagePath);
        final rawResponse = await _invokeAnalyzeForPath(
          imagePath: uploaded.storagePath,
          date: date,
          imageBase64: null,
        );

        if (rawResponse['success'] == false) {
          throw FoodAnalysisException(_mapServerError(rawResponse));
        }

        return _normalizeAnalyzeResult(
          rawResponse,
          fallbackImageUrl: uploaded.publicUrl,
        );
      }

      final prepared = await _prepareImageForUpload(imagePath, nowUtc: nowUtc);
      late Map<String, dynamic> rawResponse;

      final uploadFuture = _uploadPreparedImage(prepared);
      final analyzeFuture = _invokeAnalyzeForPath(
        imagePath: prepared.uploaded.storagePath,
        date: date,
        imageBase64: prepared.imageBase64,
      );

      await Future.wait([
        uploadFuture,
        analyzeFuture.then((payload) => rawResponse = payload),
      ]);

      if (rawResponse['success'] == false) {
        throw FoodAnalysisException(_mapServerError(rawResponse));
      }

      return _normalizeAnalyzeResult(
        rawResponse,
        fallbackImageUrl: prepared.uploaded.publicUrl,
      );
    } on FoodAnalysisException {
      rethrow;
    } catch (_) {
      throw const FoodAnalysisException(
        'Unable to analyze this meal right now. Please try again.',
      );
    }
  }

  void _validateImagePath(String imagePath) {
    final normalized = imagePath.trim().toLowerCase();
    if (normalized.isEmpty) {
      throw const FoodAnalysisException(
        'Invalid photo. Please select a valid image file.',
      );
    }

    final isSupported = _validImageExtensions.any(normalized.endsWith);
    if (!isSupported) {
      throw const FoodAnalysisException(
        'Invalid photo format. Please use JPG, PNG, HEIC, or WEBP.',
      );
    }
  }

  Future<_PreparedImageUpload> _prepareImageForUpload(
    String imagePath, {
    required DateTime nowUtc,
  }) async {
    final client = _resolvedClient;
    final userId = client.auth.currentUser?.id;
    if (userId == null) {
      throw const FoodAnalysisException(
        'Please sign in before analyzing a meal photo.',
      );
    }

    final sourceFile = File(imagePath);
    if (!await sourceFile.exists()) {
      throw const FoodAnalysisException(
        'Selected photo was not found. Please pick the image again.',
      );
    }

    final rawBytes = await sourceFile.readAsBytes();
    final uploadBytes = _compressForUpload(rawBytes);

    final dateFolder = _formatIsoDate(nowUtc).replaceAll('-', '');
    final fileName = '${nowUtc.microsecondsSinceEpoch}.jpg';
    final storagePath = '$userId/$dateFolder/$fileName';
    final publicUrl = client.storage.from(_bucketName).getPublicUrl(storagePath);

    return _PreparedImageUpload(
      uploaded: UploadedImage(storagePath: storagePath, publicUrl: publicUrl),
      uploadBytes: uploadBytes,
      imageBase64: base64Encode(uploadBytes),
    );
  }

  Future<void> _uploadPreparedImage(_PreparedImageUpload prepared) async {
    final client = _resolvedClient;

    try {
      await client.storage.from(_bucketName).uploadBinary(
        prepared.uploaded.storagePath,
        prepared.uploadBytes,
        fileOptions: const FileOptions(contentType: 'image/jpeg', upsert: false),
      );
    } catch (error) {
      final message = error.toString().toLowerCase();
      if (message.contains('bucket not found')) {
        throw const FoodAnalysisException(
          'Image storage is not ready yet. Please apply the latest Supabase migration and try again.',
        );
      }

      throw const FoodAnalysisException(
        'Unable to upload image right now. Please try again.',
      );
    }
  }

  Uint8List _compressForUpload(Uint8List rawBytes) {
    final decoded = img.decodeImage(rawBytes);
    if (decoded == null) {
      throw const FoodAnalysisException(
        'Unable to read this photo. Please select another image.',
      );
    }

    var processed = decoded;
    final longestEdge = processed.width > processed.height
        ? processed.width
        : processed.height;

    if (longestEdge > _maxLongestEdgePx) {
      if (processed.width >= processed.height) {
        processed = img.copyResize(processed, width: _maxLongestEdgePx);
      } else {
        processed = img.copyResize(processed, height: _maxLongestEdgePx);
      }
    }

    for (var quality = 90; quality >= 45; quality -= 5) {
      final encoded = Uint8List.fromList(
        img.encodeJpg(processed, quality: quality),
      );
      if (encoded.lengthInBytes <= _maxImageBytes) {
        return encoded;
      }
    }

    throw const FoodAnalysisException(
      'Photo is too large after compression. Please crop the image and try again.',
    );
  }

  Future<Map<String, dynamic>> _invokeAnalyzeForPath({
    required String imagePath,
    required String date,
    required String? imageBase64,
  }) async {
    final invokeAnalyze = _invokeAnalyzeOverride;
    if (invokeAnalyze != null) {
      return invokeAnalyze(imagePath, date);
    }

    return _invokeAnalyzeMeal(
      imagePath: imagePath,
      date: date,
      imageBase64: imageBase64,
    );
  }

  Future<Map<String, dynamic>> _invokeAnalyzeMeal({
    required String imagePath,
    required String date,
    required String? imageBase64,
  }) async {
    try {
      final body = <String, dynamic>{'image_path': imagePath, 'date': date};
      if (imageBase64 != null && imageBase64.isNotEmpty) {
        body['image_base64'] = imageBase64;
      }

      final response = await _resolvedClient.functions.invoke(
        'analyze-meal',
        body: body,
      );

      final data = response.data;
      if (data is! Map) {
        throw const FoodAnalysisException(
          'Unexpected response from analysis service.',
        );
      }

      final payload = Map<String, dynamic>.from(data);
      final success = payload['success'] == true;
      if (!success) {
        throw FoodAnalysisException(_mapServerError(payload));
      }

      return payload;
    } on FoodAnalysisException {
      rethrow;
    } catch (error) {
      final message = error.toString().toLowerCase();
      if (message.contains('401') || message.contains('unauthorized')) {
        throw const FoodAnalysisException(
          'Your session expired. Please sign in again.',
        );
      }

      if (message.contains('network') ||
          message.contains('socket') ||
          message.contains('timed out')) {
        throw const FoodAnalysisException(
          'Network error. Please check your connection and try again.',
        );
      }

      throw const FoodAnalysisException(
        'Unable to analyze this meal right now. Please try again.',
      );
    }
  }

  Map<String, dynamic> _normalizeAnalyzeResult(
    Map<String, dynamic> payload, {
    required String fallbackImageUrl,
  }) {
    final rawItems = payload['items'];
    final items = rawItems is List
        ? rawItems
              .whereType<Map>()
              .map((item) => Map<String, dynamic>.from(item))
              .toList()
        : <Map<String, dynamic>>[];

    if (items.isEmpty) {
      throw const FoodAnalysisException(
        'No food or drink detected. Please retake the photo.',
      );
    }

    final firstItem = items.first;
    final firstName = _readString(firstItem['name_en']).isNotEmpty
        ? _readString(firstItem['name_en'])
        : _readString(firstItem['name_zh']);

    final mealName = items.length > 1
        ? '${firstName.isEmpty ? 'AI Scanned Meal' : firstName} + ${items.length - 1} more'
        : (firstName.isEmpty ? 'AI Scanned Meal' : firstName);

    final imageUrl = _readString(payload['image_url']).isNotEmpty
        ? _readString(payload['image_url'])
        : fallbackImageUrl;

    return {
      'name': mealName,
      'calories': _readInt(payload['total_calories']),
      'protein': _readInt(payload['total_protein']),
      'carbs': _readInt(payload['total_carbs']),
      'fat': _readInt(payload['total_fat']),
      'sugar': _readInt(payload['total_sugar']),
      'image_url': imageUrl,
      'image_path': payload['image_path'],
      'items': items,
    };
  }

  String _mapServerError(Map<String, dynamic> payload) {
    final code = _readString(payload['code']);
    final errorMessage = _readString(payload['error']);

    switch (code) {
      case 'NO_FOOD_DETECTED':
        return errorMessage.isNotEmpty
            ? errorMessage
            : 'No food or drink detected. Please retake the photo.';
      case 'IMAGE_NOT_FOUND':
      case 'MISSING_IMAGE_PATH':
      case 'MISSING_IMAGE':
        return 'Uploaded image was not found. Please upload the photo again.';
      case 'INVALID_IMAGE_BASE64':
        return 'Unable to read this photo. Please select another image.';
      case 'IMAGE_TOO_LARGE':
        return 'Photo is too large. Please try a smaller image.';
      case 'IMAGE_EMPTY':
        return 'Uploaded image is empty. Please pick another photo.';
      case 'UNAUTHORIZED':
        return 'Your session expired. Please sign in again.';
      case 'AI_UNAVAILABLE':
      case 'AI_ERROR':
      case 'AI_PARSE_ERROR':
        return 'Unable to analyze this meal right now. Please try again.';
      default:
        return errorMessage.isNotEmpty
            ? errorMessage
            : 'Unable to analyze this meal right now. Please try again.';
    }
  }

  String _formatIsoDate(DateTime value) {
    final year = value.year.toString().padLeft(4, '0');
    final month = value.month.toString().padLeft(2, '0');
    final day = value.day.toString().padLeft(2, '0');
    return '$year-$month-$day';
  }

  int _readInt(dynamic value) {
    if (value is int) return value;
    if (value is num) return value.round();
    if (value is String) {
      return int.tryParse(value) ?? 0;
    }
    return 0;
  }

  String _readString(dynamic value) {
    return value is String ? value : '';
  }
}
