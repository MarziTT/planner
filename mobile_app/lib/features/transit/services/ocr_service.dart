/// OCR service for train ticket images.
///
/// Uploads image to backend `/api/v1/transit/ocr` and returns parsed ticket data.
///
/// Spec: §6.2 — 高铁票 OCR → 由后端视觉 LLM 处理。

import 'package:dio/dio.dart';
import 'package:image_picker/image_picker.dart';

import '../models/transit.dart';

class OcrService {
  final Dio _dio;
  final ImagePicker _picker;

  OcrService({required Dio dio, ImagePicker? picker})
      : _dio = dio,
        _picker = picker ?? ImagePicker();

  /// Pick an image from gallery.
  Future<XFile?> pickFromGallery() async {
    return _picker.pickImage(
      source: ImageSource.gallery,
      imageQuality: 85,
      maxWidth: 1920,
    );
  }

  /// Take a photo with the camera.
  Future<XFile?> takePhoto() async {
    return _picker.pickImage(
      source: ImageSource.camera,
      imageQuality: 85,
      maxWidth: 1920,
    );
  }

  /// Upload the image file to backend OCR endpoint and parse the result.
  Future<TransitTrip> ocrTicket(XFile imageFile) async {
    final bytes = await imageFile.readAsBytes();
    final fileName = imageFile.name;

    final formData = FormData.fromMap({
      'image': MultipartFile.fromBytes(bytes, filename: fileName),
    });

    final response = await _dio.post(
      '/transit/ocr',
      data: formData,
    );

    final body = response.data as Map<String, dynamic>;
    final data = body['data'] as Map<String, dynamic>? ?? {};

    return TransitTrip(
      tripId: DateTime.now().millisecondsSinceEpoch.toString(),
      trainNumber: data['train_number'] as String? ?? '',
      departureDate:
          DateTime.tryParse(data['departure_date'] as String? ?? '') ??
              DateTime.now(),
      departureStation: data['departure_station'] as String? ?? '',
      arrivalStation: data['arrival_station'] as String? ?? '',
      carriage: data['carriage'] as String?,
      seatNumber: data['seat_number'] as String?,
      departureTime: data['departure_time'] as String?,
    );
  }
}
