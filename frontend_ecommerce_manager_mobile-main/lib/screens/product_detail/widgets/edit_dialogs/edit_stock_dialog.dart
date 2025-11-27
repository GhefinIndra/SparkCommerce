// lib/screens/product_detail/widgets/edit_dialogs/edit_stock_dialog.dart
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../../models/product_detail_model.dart';

class EditStockDialog extends StatefulWidget {
  final List<ProductSku> skus;
  final Function(List<ProductSku> updatedSkus) onSave;

  const EditStockDialog({
    Key? key,
    required this.skus,
    required this.onSave,
  }) : super(key: key);

  @override
  _EditStockDialogState createState() => _EditStockDialogState();
}

class _EditStockDialogState extends State<EditStockDialog> {
  late List<TextEditingController> _controllers;
  late List<ProductSku> _workingSkus;
  bool _isSaving = false;

  @override
  void initState() {
    super.initState();
    _workingSkus = widget.skus.map((sku) => sku).toList();
    _controllers = _workingSkus.map((sku) {
      return TextEditingController(text: sku.stock.toString());
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
          return text.isNotEmpty && (int.tryParse(text) ?? -1) >= 0;
        });
  }

  int get _totalNewStock {
    return _controllers.fold(0, (total, controller) {
      return total + (int.tryParse(controller.text.trim()) ?? 0);
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
        constraints: const BoxConstraints(maxHeight: 600),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            // Header
            Container(
              padding: const EdgeInsets.all(20),
              decoration: BoxDecoration(
                color: const Color(0xFFFF9800).withOpacity(0.1),
                borderRadius: const BorderRadius.only(
                  topLeft: Radius.circular(16),
                  topRight: Radius.circular(16),
                ),
              ),
              child: Row(
                children: [
                  Container(
                    padding: const EdgeInsets.all(8),
                    decoration: BoxDecoration(
                      color: const Color(0xFFFF9800),
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: const Icon(
                      Icons.inventory_2,
                      color: Colors.white,
                      size: 20,
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'Edit Stok Produk',
                          style: TextStyle(
                            fontSize: 18,
                            fontWeight: FontWeight.bold,
                            color: Colors.grey[800],
                          ),
                        ),
                        Text(
                          'Ubah stok untuk ${_workingSkus.length} varian',
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
                padding: const EdgeInsets.all(20),
                child: Column(
                  children: [
                    // Summary Box
                    Container(
                      padding: const EdgeInsets.all(16),
                      decoration: BoxDecoration(
                        color: const Color(0xFFFF9800).withOpacity(0.1),
                        borderRadius: BorderRadius.circular(12),
                        border: Border.all(
                            color: const Color(0xFFFF9800).withOpacity(0.3)),
                      ),
                      child: Row(
                        children: [
                          const Icon(
                            Icons.assessment_outlined,
                            color: Color(0xFFFF9800),
                            size: 24,
                          ),
                          const SizedBox(width: 12),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  'Total Stok Baru',
                                  style: TextStyle(
                                    fontSize: 12,
                                    color: Colors.grey[600],
                                    fontWeight: FontWeight.w500,
                                  ),
                                ),
                                Text(
                                  '$_totalNewStock pcs',
                                  style: const TextStyle(
                                    fontSize: 18,
                                    color: Color(0xFFFF9800),
                                    fontWeight: FontWeight.bold,
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ],
                      ),
                    ),

                    const SizedBox(height: 20),

                    // Info Box
                    Container(
                      padding: const EdgeInsets.all(12),
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
                          const SizedBox(width: 8),
                          Expanded(
                            child: Text(
                              'Masukkan jumlah stok untuk setiap varian. Gunakan 0 untuk stok habis.',
                              style: TextStyle(
                                fontSize: 12,
                                color: Colors.blue[700],
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),

                    const SizedBox(height: 20),

                    // SKU Stock List
                    ...List.generate(_workingSkus.length, (index) {
                      final sku = _workingSkus[index];
                      final controller = _controllers[index];
                      final currentStock = int.tryParse(controller.text) ?? 0;

                      return Container(
                        margin: const EdgeInsets.only(bottom: 16),
                        padding: const EdgeInsets.all(16),
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
                                    color: const Color(0xFFFF9800)
                                        .withOpacity(0.15),
                                    borderRadius: BorderRadius.circular(8),
                                  ),
                                  child: Center(
                                    child: Text(
                                      '${index + 1}',
                                      style: const TextStyle(
                                        color: Color(0xFFFF9800),
                                        fontSize: 14,
                                        fontWeight: FontWeight.bold,
                                      ),
                                    ),
                                  ),
                                ),
                                const SizedBox(width: 12),
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
                                        'Stok saat ini: ${sku.stock} pcs',
                                        style: TextStyle(
                                          fontSize: 12,
                                          color: Colors.grey[600],
                                        ),
                                      ),
                                    ],
                                  ),
                                ),
                                // Stock Status Indicator
                                Container(
                                  padding: const EdgeInsets.symmetric(
                                      horizontal: 8, vertical: 4),
                                  decoration: BoxDecoration(
                                    color: _getStockStatusColor(currentStock)
                                        .withOpacity(0.1),
                                    borderRadius: BorderRadius.circular(12),
                                  ),
                                  child: Row(
                                    mainAxisSize: MainAxisSize.min,
                                    children: [
                                      Icon(
                                        _getStockStatusIcon(currentStock),
                                        color:
                                            _getStockStatusColor(currentStock),
                                        size: 14,
                                      ),
                                      const SizedBox(width: 4),
                                      Text(
                                        _getStockStatusText(currentStock),
                                        style: TextStyle(
                                          fontSize: 10,
                                          color: _getStockStatusColor(
                                              currentStock),
                                          fontWeight: FontWeight.w600,
                                        ),
                                      ),
                                    ],
                                  ),
                                ),
                              ],
                            ),

                            const SizedBox(height: 12),

                            // Stock Input
                            TextField(
                              controller: controller,
                              enabled: !_isSaving,
                              decoration: InputDecoration(
                                labelText: 'Jumlah Stok',
                                hintText: 'Contoh: 100',
                                border: OutlineInputBorder(
                                  borderRadius: BorderRadius.circular(8),
                                ),
                                focusedBorder: OutlineInputBorder(
                                  borderRadius: BorderRadius.circular(8),
                                  borderSide: const BorderSide(
                                      color: Color(0xFFFF9800)),
                                ),
                                suffixText: 'pcs',
                                suffixIcon: Row(
                                  mainAxisSize: MainAxisSize.min,
                                  children: [
                                    // Decrease button
                                    IconButton(
                                      onPressed: _isSaving
                                          ? null
                                          : () {
                                              final current = int.tryParse(
                                                      controller.text) ??
                                                  0;
                                              if (current > 0) {
                                                controller.text =
                                                    (current - 1).toString();
                                                setState(() {});
                                              }
                                            },
                                      icon: const Icon(Icons.remove, size: 18),
                                      constraints: const BoxConstraints(
                                          minWidth: 32, minHeight: 32),
                                    ),
                                    // Increase button
                                    IconButton(
                                      onPressed: _isSaving
                                          ? null
                                          : () {
                                              final current = int.tryParse(
                                                      controller.text) ??
                                                  0;
                                              controller.text =
                                                  (current + 1).toString();
                                              setState(() {});
                                            },
                                      icon: const Icon(Icons.add, size: 18),
                                      constraints: const BoxConstraints(
                                          minWidth: 32, minHeight: 32),
                                    ),
                                  ],
                                ),
                              ),
                              keyboardType: TextInputType.number,
                              inputFormatters: [
                                FilteringTextInputFormatter.digitsOnly,
                                LengthLimitingTextInputFormatter(6),
                              ],
                              onChanged: (value) {
                                setState(() {}); // Refresh validation and total
                              },
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
              padding: const EdgeInsets.all(20),
              decoration: BoxDecoration(
                color: Colors.grey[50],
                borderRadius: const BorderRadius.only(
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
                      child: const Text('Batal'),
                      style: OutlinedButton.styleFrom(
                        padding: const EdgeInsets.symmetric(vertical: 12),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(8),
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: ElevatedButton(
                      onPressed: _canSave ? _handleSave : null,
                      child: _isSaving
                          ? const SizedBox(
                              width: 16,
                              height: 16,
                              child: CircularProgressIndicator(
                                color: Colors.white,
                                strokeWidth: 2,
                              ),
                            )
                          : const Text('Simpan'),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: const Color(0xFFFF9800),
                        foregroundColor: Colors.white,
                        padding: const EdgeInsets.symmetric(vertical: 12),
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

  Color _getStockStatusColor(int stock) {
    if (stock <= 0) return Colors.red[600]!;
    if (stock <= 10) return Colors.orange[600]!;
    return const Color(0xFF4CAF50);
  }

  IconData _getStockStatusIcon(int stock) {
    if (stock <= 0) return Icons.error;
    if (stock <= 10) return Icons.warning;
    return Icons.check_circle;
  }

  String _getStockStatusText(int stock) {
    if (stock <= 0) return 'Habis';
    if (stock <= 10) return 'Sedikit';
    return 'Aman';
  }

  Future<void> _handleSave() async {
    if (!_canSave) return;

    setState(() {
      _isSaving = true;
    });

    try {
      // Update working SKUs with new stock
      for (int i = 0; i < _workingSkus.length; i++) {
        final newStock = int.tryParse(_controllers[i].text.trim()) ?? 0;
        _workingSkus[i] = _workingSkus[i].copyWith(stock: newStock);
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
            content: Text('Gagal menyimpan stok: $e'),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
  }
}
