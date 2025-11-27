// lib/screens/product_detail/widgets/edit_dialogs/edit_info_dialog.dart
import 'package:flutter/material.dart';
import '../../models/product_detail_model.dart';

class EditInfoDialog extends StatefulWidget {
  final ProductDetailModel product;
  final Function(String title, String description) onSave;

  const EditInfoDialog({
    Key? key,
    required this.product,
    required this.onSave,
  }) : super(key: key);

  @override
  _EditInfoDialogState createState() => _EditInfoDialogState();
}

class _EditInfoDialogState extends State<EditInfoDialog> {
  late TextEditingController _titleController;
  late TextEditingController _descriptionController;
  bool _isSaving = false;
  String? _titleError;

  @override
  void initState() {
    super.initState();
    _titleController = TextEditingController(text: widget.product.title);
    _descriptionController = TextEditingController(
      text: widget.product.description.replaceAll(RegExp(r'<[^>]*>'), ''),
    );
    _titleController.addListener(_validateTitle);
  }

  @override
  void dispose() {
    _titleController.dispose();
    _descriptionController.dispose();
    super.dispose();
  }

  void _validateTitle() {
    setState(() {
      final text = _titleController.text.trim();
      if (text.length < 25) {
        _titleError = 'Nama produk minimal 25 karakter';
      } else if (text.length > 255) {
        _titleError = 'Nama produk maksimal 255 karakter';
      } else {
        _titleError = null;
      }
    });
  }

  bool get _canSave {
    return _titleError == null &&
        _titleController.text.trim().length >= 25 &&
        !_isSaving;
  }

  @override
  Widget build(BuildContext context) {
    return Dialog(
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(16),
      ),
      child: Container(
        width: double.maxFinite,
        constraints: BoxConstraints(maxHeight: 600),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            // Header
            Container(
              padding: EdgeInsets.all(20),
              decoration: BoxDecoration(
                color: Color(0xFF2196F3).withOpacity(0.1),
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
                      color: Color(0xFF2196F3),
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: Icon(
                      Icons.edit,
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
                          'Edit Info Produk',
                          style: TextStyle(
                            fontSize: 18,
                            fontWeight: FontWeight.bold,
                            color: Colors.grey[800],
                          ),
                        ),
                        Text(
                          'Ubah nama dan deskripsi produk',
                          style: TextStyle(
                            fontSize: 12,
                            color: Colors.grey[600],
                          ),
                        ),
                      ],
                    ),
                  ),
                  if (!_isSaving)
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
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // Title Field
                    Text(
                      'Nama Produk *',
                      style: TextStyle(
                        fontSize: 14,
                        fontWeight: FontWeight.w600,
                        color: Colors.grey[700],
                      ),
                    ),
                    SizedBox(height: 8),
                    TextField(
                      controller: _titleController,
                      enabled: !_isSaving,
                      decoration: InputDecoration(
                        hintText: 'Masukkan nama produk',
                        border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(12),
                        ),
                        focusedBorder: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(12),
                          borderSide: BorderSide(color: Color(0xFF2196F3)),
                        ),
                        errorText: _titleError,
                        helperText:
                            '${_titleController.text.length}/255 karakter (min: 25)',
                        counterText: '',
                        suffixIcon: _titleController.text.isNotEmpty
                            ? IconButton(
                                onPressed: _isSaving
                                    ? null
                                    : () {
                                        _titleController.clear();
                                      },
                                icon: Icon(Icons.clear, size: 18),
                              )
                            : null,
                      ),
                      maxLines: 3,
                      maxLength: 255,
                    ),

                    SizedBox(height: 20),

                    // Description Field
                    Text(
                      'Deskripsi Produk',
                      style: TextStyle(
                        fontSize: 14,
                        fontWeight: FontWeight.w600,
                        color: Colors.grey[700],
                      ),
                    ),
                    SizedBox(height: 8),
                    TextField(
                      controller: _descriptionController,
                      enabled: !_isSaving,
                      decoration: InputDecoration(
                        hintText: 'Masukkan deskripsi produk (opsional)',
                        border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(12),
                        ),
                        focusedBorder: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(12),
                          borderSide: BorderSide(color: Color(0xFF2196F3)),
                        ),
                        alignLabelWithHint: true,
                        suffixIcon: _descriptionController.text.isNotEmpty
                            ? IconButton(
                                onPressed: _isSaving
                                    ? null
                                    : () {
                                        _descriptionController.clear();
                                      },
                                icon: Icon(Icons.clear, size: 18),
                              )
                            : null,
                      ),
                      maxLines: 5,
                      textInputAction: TextInputAction.newline,
                    ),

                    SizedBox(height: 20),

                    // Info Box
                    Container(
                      padding: EdgeInsets.all(12),
                      decoration: BoxDecoration(
                        color: Colors.blue[50],
                        borderRadius: BorderRadius.circular(8),
                        border: Border.all(color: Colors.blue[200]!),
                      ),
                      child: Row(
                        children: [
                          Icon(
                            Icons.info_outline,
                            color: Colors.blue[700],
                            size: 20,
                          ),
                          SizedBox(width: 8),
                          Expanded(
                            child: Text(
                              'Nama produk harus minimal 25 karakter. Deskripsi akan otomatis diformat ke HTML.',
                              style: TextStyle(
                                fontSize: 12,
                                color: Colors.blue[700],
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
            ),

            // Footer
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
                      onPressed:
                          _isSaving ? null : () => Navigator.of(context).pop(),
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
                      onPressed: _canSave ? _handleSave : null,
                      child: _isSaving
                          ? SizedBox(
                              width: 16,
                              height: 16,
                              child: CircularProgressIndicator(
                                color: Colors.white,
                                strokeWidth: 2,
                              ),
                            )
                          : Text('Simpan'),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: Color(0xFF2196F3),
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

  Future<void> _handleSave() async {
    if (!_canSave) return;

    setState(() {
      _isSaving = true;
    });

    try {
      final title = _titleController.text.trim();
      final description = _descriptionController.text.trim();

      await widget.onSave(title, description);

      if (mounted) {
        Navigator.of(context).pop();
      }
    } catch (e) {
      setState(() {
        _isSaving = false;
      });

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Gagal menyimpan: $e'),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
  }
}
