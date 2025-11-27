// widgets/image_selector_widget.dart
import 'dart:io';
import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';

class ImageSelectorWidget extends StatefulWidget {
  final List<XFile> selectedImages;
  final Function(List<XFile>) onImagesChanged;
  final int maxImages;
  final int maxImageSizeMB;

  const ImageSelectorWidget({
    Key? key,
    required this.selectedImages,
    required this.onImagesChanged,
    this.maxImages = 9,
    this.maxImageSizeMB = 10,
  }) : super(key: key);

  @override
  _ImageSelectorWidgetState createState() => _ImageSelectorWidgetState();
}

class _ImageSelectorWidgetState extends State<ImageSelectorWidget> {
  final ImagePicker _picker = ImagePicker();

  Future<void> _pickImages() async {
    try {
      final List<XFile>? images = await _picker.pickMultiImage();
      if (images != null) {
        List<XFile> validImages = [];
        List<XFile> currentImages = List.from(widget.selectedImages);

        for (XFile image in images) {
          if (currentImages.length + validImages.length >= widget.maxImages) {
            _showSnackBar('Maksimal ${widget.maxImages} gambar', Colors.orange);
            break;
          }

          final File file = File(image.path);
          final int fileSizeInBytes = file.lengthSync();
          final double fileSizeInMB = fileSizeInBytes / (1024 * 1024);

          if (fileSizeInMB > widget.maxImageSizeMB) {
            _showSnackBar(
                'Gambar terlalu besar (maks ${widget.maxImageSizeMB}MB)',
                Colors.red);
            continue;
          }

          validImages.add(image);
        }

        currentImages.addAll(validImages);
        widget.onImagesChanged(currentImages);
      }
    } catch (e) {
      _showSnackBar('Gagal memilih gambar: $e', Colors.red);
    }
  }

  void _removeImage(int index) {
    List<XFile> currentImages = List<XFile>.from(widget.selectedImages);
    currentImages.removeAt(index);
    widget.onImagesChanged(currentImages);
  }

  void _showSnackBar(String message, Color color) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(message),
        backgroundColor: color,
        behavior: SnackBarBehavior.floating,
        margin: EdgeInsets.all(16),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // Description & Counter Row
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Expanded(
              child: Text(
                'Format: JPG, PNG  Max: ${widget.maxImageSizeMB}MB  Dimensi: 600x600px',
                style: TextStyle(
                  fontSize: 12,
                  color: Colors.grey[600],
                  height: 1.4,
                ),
              ),
            ),
          ],
        ),
        SizedBox(height: 10),

        // Counter with icon
        Container(
          padding: EdgeInsets.symmetric(horizontal: 12, vertical: 6),
          decoration: BoxDecoration(
            color: Color(0xFF2196F3).withOpacity(0.1),
            borderRadius: BorderRadius.circular(20),
            border: Border.all(
              color: Color(0xFF2196F3).withOpacity(0.3),
              width: 1,
            ),
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(
                Icons.image,
                size: 14,
                color: Color(0xFF2196F3),
              ),
              SizedBox(width: 6),
              Text(
                '${widget.selectedImages.length}/${widget.maxImages} gambar',
                style: TextStyle(
                  fontSize: 12,
                  color: Color(0xFF1A237E),
                  fontWeight: FontWeight.w600,
                ),
              ),
            ],
          ),
        ),
        SizedBox(height: 16),

        // Image Grid
        GridView.builder(
          shrinkWrap: true,
          physics: NeverScrollableScrollPhysics(),
          gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
            crossAxisCount: 3,
            crossAxisSpacing: 12,
            mainAxisSpacing: 12,
            childAspectRatio: 1,
          ),
          itemCount: widget.selectedImages.length +
              (widget.selectedImages.length < widget.maxImages ? 1 : 0),
          itemBuilder: (context, index) {
            // Add Image Button
            if (index == widget.selectedImages.length) {
              return GestureDetector(
                onTap: _pickImages,
                child: Container(
                  decoration: BoxDecoration(
                    gradient: LinearGradient(
                      begin: Alignment.topLeft,
                      end: Alignment.bottomRight,
                      colors: [
                        Color(0xFF2196F3).withOpacity(0.1),
                        Color(0xFF1976D2).withOpacity(0.15),
                      ],
                    ),
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(
                      color: Color(0xFF2196F3).withOpacity(0.4),
                      width: 2,
                    ),
                  ),
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Container(
                        padding: EdgeInsets.all(8),
                        decoration: BoxDecoration(
                          color: Color(0xFF2196F3).withOpacity(0.2),
                          shape: BoxShape.circle,
                        ),
                        child: Icon(
                          Icons.add_photo_alternate_outlined,
                          size: 24,
                          color: Color(0xFF2196F3),
                        ),
                      ),
                      SizedBox(height: 6),
                      Text(
                        'Tambah\nGambar',
                        textAlign: TextAlign.center,
                        style: TextStyle(
                          fontSize: 10,
                          color: Color(0xFF1A237E),
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ],
                  ),
                ),
              );
            }

            // Selected Image
            return Stack(
              children: [
                Container(
                  decoration: BoxDecoration(
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(
                      color: index == 0
                          ? Color(0xFF2196F3)
                          : Colors.grey[300]!,
                      width: index == 0 ? 3 : 2,
                    ),
                    boxShadow: [
                      BoxShadow(
                        color: Colors.black.withOpacity(0.1),
                        blurRadius: 8,
                        offset: Offset(0, 2),
                      ),
                    ],
                  ),
                  child: ClipRRect(
                    borderRadius: BorderRadius.circular(10),
                    child: Image.file(
                      File(widget.selectedImages[index].path),
                      width: double.infinity,
                      height: double.infinity,
                      fit: BoxFit.cover,
                    ),
                  ),
                ),

                // Remove Button
                Positioned(
                  top: 6,
                  right: 6,
                  child: GestureDetector(
                    onTap: () => _removeImage(index),
                    child: Container(
                      padding: EdgeInsets.all(6),
                      decoration: BoxDecoration(
                        color: Colors.red.shade600,
                        shape: BoxShape.circle,
                        boxShadow: [
                          BoxShadow(
                            color: Colors.black.withOpacity(0.3),
                            blurRadius: 4,
                            offset: Offset(0, 2),
                          ),
                        ],
                      ),
                      child: Icon(Icons.close, size: 14, color: Colors.white),
                    ),
                  ),
                ),

                // Main Image Badge
                if (index == 0)
                  Positioned(
                    bottom: 6,
                    left: 6,
                    child: Container(
                      padding: EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                      decoration: BoxDecoration(
                        gradient: LinearGradient(
                          colors: [
                            Color(0xFF2196F3),
                            Color(0xFF1976D2),
                          ],
                        ),
                        borderRadius: BorderRadius.circular(6),
                        boxShadow: [
                          BoxShadow(
                            color: Color(0xFF2196F3).withOpacity(0.4),
                            blurRadius: 4,
                            offset: Offset(0, 2),
                          ),
                        ],
                      ),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Icon(Icons.star, size: 10, color: Colors.white),
                          SizedBox(width: 4),
                          Text(
                            'Utama',
                            style: TextStyle(
                              color: Colors.white,
                              fontSize: 10,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
              ],
            );
          },
        ),
      ],
    );
  }
}
