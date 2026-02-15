// lib/widgets/photo_picker_widget.dart
import 'dart:io';
import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import '../models/photo_model.dart';

class PhotoPickerWidget extends StatefulWidget {
  final List<LocalPhoto> initialPhotos;
  final int maxPhotos;
  final Function(List<LocalPhoto>) onPhotosChanged;

  const PhotoPickerWidget({
    Key? key,
    this.initialPhotos = const [],
    this.maxPhotos = 5,
    required this.onPhotosChanged,
  }) : super(key: key);

  @override
  State<PhotoPickerWidget> createState() => _PhotoPickerWidgetState();
}

class _PhotoPickerWidgetState extends State<PhotoPickerWidget> {
  late List<LocalPhoto> _selectedPhotos;

  @override
  void initState() {
    super.initState();
    _selectedPhotos = List.from(widget.initialPhotos);
  }

  Future<void> _addPhoto() async {
    if (_selectedPhotos.length >= widget.maxPhotos) {
      _showMaxPhotosLimitDialog();
      return;
    }

    final XFile? pickedFile = await PhotoUtils.pickImageFromGallery();
    
    if (pickedFile != null) {
      final newPhoto = LocalPhoto(file: pickedFile);
      setState(() {
        _selectedPhotos.add(newPhoto);
      });
      widget.onPhotosChanged(_selectedPhotos);
    }
  }

  Future<void> _takePhoto() async {
    if (_selectedPhotos.length >= widget.maxPhotos) {
      _showMaxPhotosLimitDialog();
      return;
    }

    final XFile? takenPhoto = await PhotoUtils.takePhotoWithCamera();
    
    if (takenPhoto != null) {
      final newPhoto = LocalPhoto(file: takenPhoto);
      setState(() {
        _selectedPhotos.add(newPhoto);
      });
      widget.onPhotosChanged(_selectedPhotos);
    }
  }

  void _removePhoto(int index) {
    setState(() {
      _selectedPhotos.removeAt(index);
    });
    widget.onPhotosChanged(_selectedPhotos);
  }

  void _showMaxPhotosLimitDialog() {
    showDialog(
      context: context,
      builder: (BuildContext context) {
        return AlertDialog(
          title: const Text('Maximum Photos Reached'),
          content: Text('You can only select up to ${widget.maxPhotos} photos.'),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(context).pop(),
              child: const Text('OK'),
            ),
          ],
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            _buildAddPhotoButton(),
            const SizedBox(width: 8),
            _buildTakePhotoButton(),
          ],
        ),
        const SizedBox(height: 16),
        if (_selectedPhotos.isNotEmpty) ...[
          Text(
            'Selected Photos (${_selectedPhotos.length}/${widget.maxPhotos})',
            style: Theme.of(context).textTheme.titleMedium,
          ),
          const SizedBox(height: 8),
          _buildPhotoGrid(),
        ],
      ],
    );
  }

  Widget _buildAddPhotoButton() {
    return ElevatedButton.icon(
      onPressed: _addPhoto,
      icon: const Icon(Icons.photo_library),
      label: const Text('Add Photos'),
    );
  }

  Widget _buildTakePhotoButton() {
    return ElevatedButton.icon(
      onPressed: _takePhoto,
      icon: const Icon(Icons.camera_alt),
      label: const Text('Take Photo'),
    );
  }

  Widget _buildPhotoGrid() {
    return SizedBox(
      height: 120,
      child: ListView.builder(
        scrollDirection: Axis.horizontal,
        itemCount: _selectedPhotos.length,
        itemBuilder: (context, index) {
          return Container(
            margin: const EdgeInsets.only(right: 8),
            width: 100,
            height: 100,
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(8),
              border: Border.all(color: Colors.grey.shade300),
            ),
            child: Stack(
              fit: StackFit.expand,
              children: [
                ClipRRect(
                  borderRadius: BorderRadius.circular(8),
                  child: Image.file(
                    File(_selectedPhotos[index].file.path),
                    fit: BoxFit.cover,
                  ),
                ),
                Positioned(
                  top: 4,
                  right: 4,
                  child: GestureDetector(
                    onTap: () => _removePhoto(index),
                    child: Container(
                      padding: const EdgeInsets.all(2),
                      decoration: const BoxDecoration(
                        color: Colors.red,
                        shape: BoxShape.circle,
                      ),
                      child: const Icon(
                        Icons.close,
                        color: Colors.white,
                        size: 16,
                      ),
                    ),
                  ),
                ),
              ],
            ),
          );
        },
      ),
    );
  }
}