// lib/screens/product_detail/widgets/edit_dialogs/edit_price_dialog.dart
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../../models/product_detail_model.dart';

class EditPriceDialog extends StatefulWidget {
  final List<ProductSku> skus;
  final Function(List<ProductSku> updatedSkus) onSave;

  const EditPriceDialog({
    Key? key,
    required this.skus,
    required this.onSave,
  }) : super(key: key);

  @override
  _EditPriceDialogState createState() => _EditPriceDialogState();
}

class _EditPriceDialogState extends State<EditPriceDialog> {
  late List<TextEditingController> _controllers;
  late List<ProductSku> _workingSkus;
  bool _isSaving = false;

  @override
  void initState() {
    super.initState();
    _workingSkus = widget.skus.map((sku) => sku).toList();
    _controllers = _workingSkus.map((sku) {
      return TextEditingController(text: sku.price.amount);
    }).toList();
  }

  @override
  void dispose() {
    for (var controller in _controllers) {
      controller.dispose();
    }
    super.dispose();
  }

  bool get _canSave {
    return !_isSaving &&
        _controllers.every((controller) {
          final text = controller.text.trim();
          return text.isNotEmpty && (int.tryParse(text) ?? 0) > 0;
        });
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
                      Icons.attach_money,
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
                          'Edit Harga Produk',
                          style: TextStyle(
                            fontSize: 18,
                            fontWeight: FontWeight.bold,
                            color: Colors.grey[800],
                          ),
                        ),
                        Text(
                          'Ubah harga untuk ${_workingSkus.length} varian',
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
                  children: [
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
                              'Masukkan harga dalam Rupiah (tanpa titik atau koma)',
                              style: TextStyle(
                                fontSize: 12,
                                color: Colors.blue[700],
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),

                    SizedBox(height: 20),

                    // SKU Price List
                    ...List.generate(_workingSkus.length, (index) {
                      final sku = _workingSkus[index];
                      final controller = _controllers[index];

                      return Container(
                        margin: EdgeInsets.only(bottom: 16),
                        padding: EdgeInsets.all(16),
                        decoration: BoxDecoration(
                          color: Colors.grey[50],
                          borderRadius: BorderRadius.circular(12),
                          border: Border.all(color: Colors.grey[200]!),
                        ),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            // SKU Info
                            Row(
                              children: [
                                Container(
                                  width: 32,
                                  height: 32,
                                  decoration: BoxDecoration(
                                    color: Color(0xFF2196F3).withOpacity(0.15),
                                    borderRadius: BorderRadius.circular(8),
                                  ),
                                  child: Center(
                                    child: Text(
                                      '${index + 1}',
                                      style: TextStyle(
                                        color: Color(0xFF2196F3),
                                        fontSize: 14,
                                        fontWeight: FontWeight.bold,
                                      ),
                                    ),
                                  ),
                                ),
                                SizedBox(width: 12),
                                Expanded(
                                  child: Column(
                                    crossAxisAlignment:
                                        CrossAxisAlignment.start,
                                    children: [
                                      Text(
                                        sku.displayName,
                                        style: TextStyle(
                                          fontSize: 14,
                                          fontWeight: FontWeight.w600,
                                          color: Colors.grey[800],
                                        ),
                                      ),
                                      Text(
                                        'Harga saat ini: ${sku.price.displayPrice}',
                                        style: TextStyle(
                                          fontSize: 12,
                                          color: Colors.grey[600],
                                        ),
                                      ),
                                    ],
                                  ),
                                ),
                              ],
                            ),

                            SizedBox(height: 12),

                            // Price Input
                            TextField(
                              controller: controller,
                              enabled: !_isSaving,
                              decoration: InputDecoration(
                                labelText: 'Harga Baru (IDR)',
                                hintText: 'Contoh: 150000',
                                border: OutlineInputBorder(
                                  borderRadius: BorderRadius.circular(8),
                                ),
                                focusedBorder: OutlineInputBorder(
                                  borderRadius: BorderRadius.circular(8),
                                  borderSide:
                                      BorderSide(color: Color(0xFF2196F3)),
                                ),
                                prefixText: 'Rp ',
                                suffixIcon: controller.text.isNotEmpty
                                    ? IconButton(
                                        onPressed: _isSaving
                                            ? null
                                            : () {
                                                controller.clear();
                                                setState(() {});
                                              },
                                        icon: Icon(Icons.clear, size: 18),
                                      )
                                    : null,
                              ),
                              keyboardType: TextInputType.number,
                              inputFormatters: [
                                FilteringTextInputFormatter.digitsOnly,
                                LengthLimitingTextInputFormatter(10),
                              ],
                              onChanged: (value) {
                                setState(() {}); // Refresh validation
                              },
                            ),

                            // Show formatted price
                            if (controller.text.isNotEmpty &&
                                (int.tryParse(controller.text) ?? 0) > 0)
                              Padding(
                                padding: EdgeInsets.only(top: 8),
                                child: Text(
                                  'Preview: ${_formatRupiah(controller.text)}',
                                  style: TextStyle(
                                    fontSize: 12,
                                    color: Color(0xFF4CAF50),
                                    fontWeight: FontWeight.w500,
                                  ),
                                ),
                              ),
                          ],
                        ),
                      );
                    }),
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

  String _formatRupiah(String price) {
    if (price.isEmpty) return 'Rp 0';
    final number = int.tryParse(price) ?? 0;
    return 'Rp ${number.toString().replaceAllMapped(
          RegExp(r'(\d{1,3})(?=(\d{3})+(?!\d))'),
          (Match m) => '${m[1]}.',
        )}';
  }

  Future<void> _handleSave() async {
    if (!_canSave) return;

    setState(() {
      _isSaving = true;
    });

    try {
      // Update working SKUs with new prices
      for (int i = 0; i < _workingSkus.length; i++) {
        final newAmount = _controllers[i].text.trim();
        _workingSkus[i] = _workingSkus[i].copyWith(
          price: _workingSkus[i].price.copyWith(amount: newAmount),
        );
      }

      await widget.onSave(_workingSkus);

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
            content: Text('Gagal menyimpan harga: $e'),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
  }
}
