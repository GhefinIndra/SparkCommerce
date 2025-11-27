// lib/screens/product_detail/widgets/edit_dialogs/edit_image_dialog.dart
import 'dart:io';
import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import '../../../../services/api_service.dart';

class EditImageDialog extends StatefulWidget {
  final String shopId;
  final String productId;
  final ApiService apiService;
  final VoidCallback onSave;
  final String platform; // Platform identifier (TikTok Shop, Shopee, etc)

  const EditImageDialog({
    Key? key,
    required this.shopId,
    required this.productId,
    required this.apiService,
    required this.onSave,
    this.platform = 'TikTok Shop', // Default for backward compatibility
  }) : super(key: key);

  @override
  _EditImageDialogState createState() => _EditImageDialogState();
}

class _EditImageDialogState extends State<EditImageDialog> {
  final ImagePicker _picker = ImagePicker();
  List<XFile> _selectedImages = [];
  bool _isUploading = false;
  String _uploadProgress = '';

  @override
  Widget build(BuildContext context) {
    return Dialog(
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(16),
      ),
      child: Container(
        width: double.maxFinite,
        constraints: BoxConstraints(
          maxHeight: MediaQuery.of(context).size.height * 0.8,
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            // Header
            Container(
              padding: EdgeInsets.all(20),
              decoration: BoxDecoration(
                color: Color(0xFF9C27B0).withOpacity(0.1),
                borderRadius: BorderRadius.only(
                  topLeft: Radius.circular(16),
                  topRight: Radius.circular(16),
                ),
              ),
              child: Row(
                children: [
                  Container(
                    padding: EdgeInsets.all(8),
                    decoration: BoxDecoration(
                      color: Color(0xFF9C27B0),
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: Icon(
                      Icons.image,
                      color: Colors.white,
                      size: 20,
                    ),
                  ),
                  SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'Edit Gambar Produk',
                          style: TextStyle(
                            fontSize: 18,
                            fontWeight: FontWeight.bold,
                            color: Colors.grey[800],
                          ),
                        ),
                        Text(
                          'Upload gambar baru untuk produk',
                          style: TextStyle(
                            fontSize: 12,
                            color: Colors.grey[600],
                          ),
                        ),
                      ],
                    ),
                  ),
                  if (!_isUploading)
                    IconButton(
                      onPressed: () => Navigator.of(context).pop(),
                      icon: Icon(Icons.close, color: Colors.grey[600]),
                    ),
                ],
              ),
            ),

            // Content
            Flexible(
              child: SingleChildScrollView(
                padding: EdgeInsets.all(20),
                child: Column(
                  children: [
                    // Info Guidelines
                    Container(
                      padding: EdgeInsets.all(16),
                      decoration: BoxDecoration(
                        color: Colors.blue[50],
                        borderRadius: BorderRadius.circular(12),
                        border: Border.all(color: Colors.blue[200]!),
                      ),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Row(
                            children: [
                              Icon(
                                Icons.info_outline,
                                color: Colors.blue[700],
                                size: 20,
                              ),
                              SizedBox(width: 8),
                              Text(
                                'Panduan Upload Gambar',
                                style: TextStyle(
                                  fontSize: 14,
                                  fontWeight: FontWeight.w600,
                                  color: Colors.blue[700],
                                ),
                              ),
                            ],
                          ),
                          SizedBox(height: 8),
                          _buildGuidelineItem(' Pilih 1-9 gambar'),
                          _buildGuidelineItem(
                              ' Format: JPG, PNG, WEBP, HEIC, BMP'),
                          _buildGuidelineItem(
                              ' Ukuran maksimal: 10MB per gambar'),
                          _buildGuidelineItem(
                              ' Resolusi optimal: 600x600 piksel'),
                          _buildGuidelineItem(
                              ' Gambar pertama akan menjadi gambar utama'),
                        ],
                      ),
                    ),

                    SizedBox(height: 20),

                    // Image Selection Button
                    if (!_isUploading)
                      SizedBox(
                        width: double.infinity,
                        child: ElevatedButton.icon(
                          onPressed: _selectImages,
                          icon: Icon(Icons.add_photo_alternate),
                          label: Text('Pilih Gambar'),
                          style: ElevatedButton.styleFrom(
                            backgroundColor: Color(0xFF9C27B0),
                            foregroundColor: Colors.white,
                            padding: EdgeInsets.symmetric(vertical: 16),
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(12),
                            ),
                          ),
                        ),
                      ),

                    // Selected Images Preview
                    if (_selectedImages.isNotEmpty && !_isUploading) ...[
                      SizedBox(height: 20),
                      Container(
                        width: double.infinity,
                        padding: EdgeInsets.all(16),
                        decoration: BoxDecoration(
                          color: Colors.grey[50],
                          borderRadius: BorderRadius.circular(12),
                          border: Border.all(color: Colors.grey[300]!),
                        ),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Row(
                              children: [
                                Icon(
                                  Icons.photo_library,
                                  color: Color(0xFF9C27B0),
                                  size: 20,
                                ),
                                SizedBox(width: 8),
                                Text(
                                  'Gambar Terpilih (${_selectedImages.length})',
                                  style: TextStyle(
                                    fontSize: 14,
                                    fontWeight: FontWeight.w600,
                                    color: Colors.grey[800],
                                  ),
                                ),
                              ],
                            ),
                            SizedBox(height: 12),
                            Container(
                              height: 200,
                              child: GridView.builder(
                                scrollDirection: Axis.horizontal,
                                gridDelegate:
                                    SliverGridDelegateWithFixedCrossAxisCount(
                                  crossAxisCount: 2,
                                  crossAxisSpacing: 8,
                                  mainAxisSpacing: 8,
                                ),
                                itemCount: _selectedImages.length,
                                itemBuilder: (context, index) {
                                  return Stack(
                                    children: [
                                      ClipRRect(
                                        borderRadius: BorderRadius.circular(8),
                                        child: Image.file(
                                          File(_selectedImages[index].path),
                                          fit: BoxFit.cover,
                                          width: double.infinity,
                                          height: double.infinity,
                                        ),
                                      ),
                                      // Remove button
                                      Positioned(
                                        top: 4,
                                        right: 4,
                                        child: GestureDetector(
                                          onTap: () {
                                            setState(() {
                                              _selectedImages.removeAt(index);
                                            });
                                          },
                                          child: Container(
                                            decoration: BoxDecoration(
                                              color: Colors.red[600],
                                              shape: BoxShape.circle,
                                              boxShadow: [
                                                BoxShadow(
                                                  color: Colors.black
                                                      .withOpacity(0.2),
                                                  blurRadius: 4,
                                                ),
                                              ],
                                            ),
                                            padding: EdgeInsets.all(4),
                                            child: Icon(
                                              Icons.close,
                                              size: 14,
                                              color: Colors.white,
                                            ),
                                          ),
                                        ),
                                      ),
                                      // Main image indicator
                                      if (index == 0)
                                        Positioned(
                                          bottom: 4,
                                          left: 4,
                                          child: Container(
                                            padding: EdgeInsets.symmetric(
                                                horizontal: 6, vertical: 2),
                                            decoration: BoxDecoration(
                                              color: Color(0xFF9C27B0),
                                              borderRadius:
                                                  BorderRadius.circular(8),
                                            ),
                                            child: Text(
                                              'UTAMA',
                                              style: TextStyle(
                                                color: Colors.white,
                                                fontSize: 10,
                                                fontWeight: FontWeight.bold,
                                              ),
                                            ),
                                          ),
                                        ),
                                    ],
                                  );
                                },
                              ),
                            ),
                          ],
                        ),
                      ),
                    ],

                    // Upload Progress
                    if (_isUploading) ...[
                      SizedBox(height: 20),
                      Container(
                        width: double.infinity,
                        padding: EdgeInsets.all(20),
                        decoration: BoxDecoration(
                          color: Color(0xFF9C27B0).withOpacity(0.1),
                          borderRadius: BorderRadius.circular(12),
                        ),
                        child: Column(
                          children: [
                            CircularProgressIndicator(
                              color: Color(0xFF9C27B0),
                              strokeWidth: 3,
                            ),
                            SizedBox(height: 16),
                            Text(
                              'Mengupload Gambar...',
                              style: TextStyle(
                                fontSize: 16,
                                fontWeight: FontWeight.w600,
                                color: Color(0xFF9C27B0),
                              ),
                            ),
                            if (_uploadProgress.isNotEmpty) ...[
                              SizedBox(height: 8),
                              Text(
                                _uploadProgress,
                                style: TextStyle(
                                  fontSize: 12,
                                  color: Colors.grey[600],
                                ),
                                textAlign: TextAlign.center,
                              ),
                            ],
                          ],
                        ),
                      ),
                    ],
                  ],
                ),
              ),
            ),

            // Footer
            if (!_isUploading)
              Container(
                padding: EdgeInsets.all(20),
                decoration: BoxDecoration(
                  color: Colors.grey[50],
                  borderRadius: BorderRadius.only(
                    bottomLeft: Radius.circular(16),
                    bottomRight: Radius.circular(16),
                  ),
                ),
                child: Row(
                  children: [
                    Expanded(
                      child: OutlinedButton(
                        onPressed: () => Navigator.of(context).pop(),
                        child: Text('Batal'),
                        style: OutlinedButton.styleFrom(
                          padding: EdgeInsets.symmetric(vertical: 12),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(8),
                          ),
                        ),
                      ),
                    ),
                    SizedBox(width: 12),
                    Expanded(
                      child: ElevatedButton(
                        onPressed: _selectedImages.isNotEmpty
                            ? _uploadAndUpdateImages
                            : null,
                        child: Text('Upload & Simpan'),
                        style: ElevatedButton.styleFrom(
                          backgroundColor: Color(0xFF9C27B0),
                          foregroundColor: Colors.white,
                          padding: EdgeInsets.symmetric(vertical: 12),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(8),
                          ),
                        ),
                      ),
                    ),
                  ],
                ),
              ),
          ],
        ),
      ),
    );
  }

  Widget _buildGuidelineItem(String text) {
    return Padding(
      padding: EdgeInsets.only(bottom: 2),
      child: Text(
        text,
        style: TextStyle(
          fontSize: 12,
          color: Colors.blue[600],
        ),
      ),
    );
  }

  Future<void> _selectImages() async {
    try {
      final List<XFile> images = await _picker.pickMultiImage(
        maxWidth: 4000,
        maxHeight: 4000,
        imageQuality: 90,
      );

      if (images.isNotEmpty) {
        if (images.length > 9) {
          _showError('Maksimal 9 gambar yang dapat dipilih');
          return;
        }

        // Check file sizes
        bool allValid = true;
        for (XFile image in images) {
          final size = await image.length();
          if (size > 10 * 1024 * 1024) {
            // 10MB
            allValid = false;
            break;
          }
        }

        if (!allValid) {
          _showError('Ada gambar yang melebihi batas ukuran 10MB');
          return;
        }

        setState(() {
          _selectedImages = images;
        });
      }
    } catch (e) {
      _showError('Gagal memilih gambar: $e');
    }
  }

  Future<void> _uploadAndUpdateImages() async {
    if (_selectedImages.isEmpty) return;

    setState(() {
      _isUploading = true;
      _uploadProgress = 'Mempersiapkan upload...';
    });

    try {
      List<Map<String, dynamic>> uploadedImages = [];

      // Platform detection: Shopee or TikTok
      final isShopee = widget.platform.toLowerCase().contains('shopee');

      // Upload images one by one
      for (int i = 0; i < _selectedImages.length; i++) {
        setState(() {
          _uploadProgress =
              'Mengupload gambar ${i + 1} dari ${_selectedImages.length}...';
        });

        final file = File(_selectedImages[i].path);

        // Call appropriate API based on platform
        final result = isShopee
            ? await widget.apiService.uploadShopeeProductImage(
                widget.shopId,
                file,
                scene: 'normal', // Product image
                ratio: '1:1',    // Default ratio
              )
            : await widget.apiService.uploadProductImage(
                widget.shopId,
                file,
                useCase: 'MAIN_IMAGE',
              );

        uploadedImages.add({
          'uri': result['uri'],
          'url': result['url'],
        });
      }

      setState(() {
        _uploadProgress = 'Memperbarui produk...';
      });

      // Update product with all uploaded images (platform-specific)
      if (isShopee) {
        // For Shopee: send only image_ids
        final imageIds = uploadedImages.map((img) => img['uri'] as String).toList();
        await widget.apiService.updateShopeeProductImages(
          widget.shopId,
          widget.productId,
          imageIds,
        );
      } else {
        // For TikTok: send full image objects
        await widget.apiService.updateProductImages(
          widget.shopId,
          widget.productId,
          uploadedImages,
        );
      }

      widget.onSave();

      if (mounted) {
        Navigator.of(context).pop();
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Gambar berhasil diupdate'),
            backgroundColor: Colors.green,
          ),
        );
      }
    } catch (e) {
      setState(() {
        _isUploading = false;
        _uploadProgress = '';
      });

      _showError('Gagal upload gambar: $e');
    }
  }

  void _showError(String message) {
    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(message),
          backgroundColor: Colors.red,
        ),
      );
    }
  }
}
