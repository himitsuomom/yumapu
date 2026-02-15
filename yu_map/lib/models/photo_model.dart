// lib/models/photo_model.dart
import 'dart:io';
import 'package:image_picker/image_picker.dart';

/// Represents a photo selected locally by the user
class LocalPhoto {
  final XFile file;
  
  LocalPhoto({
    required this.file,
  });
  
  /// Get the file path of the photo
  String get path => file.path;
  
  /// Get the file name of the photo
  String get name => file.name;
  
  /// Get the file size in bytes
  Future<int> getFileSize() async {
    return File(file.path).length();
  }
  
  /// Get the image dimensions
  Future<Map<String, int>> getImageDimensions() async {
    final image = await file.readAsBytes();
    // Note: This would typically use an image processing library
    // For now, returning a placeholder implementation
    return {'width': 0, 'height': 0}; // Placeholder
  }
}

/// Utility class for photo operations
class PhotoUtils {
  static final ImagePicker _picker = ImagePicker();
  
  /// Pick a single image from gallery
  static Future<XFile?> pickImageFromGallery() async {
    try {
      final XFile? image = await _picker.pickImage(
        source: ImageSource.gallery,
        maxHeight: 1080,
        maxWidth: 1080,
        imageQuality: 80,
      );
      return image;
    } catch (e) {
      print('Error picking image from gallery: $e');
      return null;
    }
  }
  
  /// Take a photo using camera
  static Future<XFile?> takePhotoWithCamera() async {
    try {
      final XFile? photo = await _picker.pickImage(
        source: ImageSource.camera,
        maxHeight: 1080,
        maxWidth: 1080,
        imageQuality: 80,
      );
      return photo;
    } catch (e) {
      print('Error taking photo: $e');
      return null;
    }
  }
  
  /// Pick multiple images from gallery
  static Future<List<XFile>> pickMultipleImages() async {
    try {
      final List<XFile> images = await _picker.pickMultiImage(
        maxHeight: 1080,
        maxWidth: 1080,
        imageQuality: 80,
      );
      return images;
    } catch (e) {
      print('Error picking multiple images: $e');
      return [];
    }
  }
}