// lib/screens/create_product/widgets/shopee_hazardous_field_widget.dart
import 'package:flutter/material.dart';
import '../models/product_form_data.dart';

/// Hazardous Product Field Widget for Shopee (Indonesia & Malaysia only)
/// Shows radio buttons:
/// - Tidak (0)
/// - Mengandung baterai/magnet/cairan/bahan mudah terbakar (1)
class ShopeeHazardousFieldWidget extends StatefulWidget {
  final ProductFormData formData;
  final Function() onChanged;
  final bool isRequired;

  const ShopeeHazardousFieldWidget({
    Key? key,
    required this.formData,
    required this.onChanged,
    this.isRequired = true,
  }) : super(key: key);

  @override
  _ShopeeHazardousFieldWidgetState createState() =>
      _ShopeeHazardousFieldWidgetState();
}

class _ShopeeHazardousFieldWidgetState
    extends State<ShopeeHazardousFieldWidget> {
  @override
  Widget build(BuildContext context) {
    return Container(
      padding: EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: Colors.grey[300]!),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Label
          Row(
            children: [
              Text(
                'Produk Berbahaya',
                style: TextStyle(
                  fontSize: 14,
                  fontWeight: FontWeight.w600,
                  color: Color(0xFF2D3436),
                ),
              ),
              if (widget.isRequired)
                Text(
                  ' *',
                  style: TextStyle(
                    fontSize: 14,
                    fontWeight: FontWeight.w600,
                    color: Colors.red,
                  ),
                ),
              SizedBox(width: 8),
              Tooltip(
                message:
                    'Produk yang mengandung baterai, magnet, cairan, atau bahan mudah terbakar',
                child: Icon(
                  Icons.info_outline,
                  size: 16,
                  color: Colors.grey[600],
                ),
              ),
            ],
          ),
          SizedBox(height: 12),

          // Radio Option 1: Tidak
          InkWell(
            onTap: () {
              setState(() {
                widget.formData.itemDangerous = '0';
                widget.onChanged();
              });
            },
            child: Container(
              padding: EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: widget.formData.itemDangerous == '0'
                    ? Color(0xFF3949AB).withOpacity(0.1)
                    : Colors.grey[50],
                borderRadius: BorderRadius.circular(8),
                border: Border.all(
                  color: widget.formData.itemDangerous == '0'
                      ? Color(0xFF3949AB)
                      : Colors.grey[300]!,
                  width: widget.formData.itemDangerous == '0' ? 2 : 1,
                ),
              ),
              child: Row(
                children: [
                  Radio<String>(
                    value: '0',
                    groupValue: widget.formData.itemDangerous,
                    onChanged: (value) {
                      setState(() {
                        widget.formData.itemDangerous = value ?? '0';
                        widget.onChanged();
                      });
                    },
                    activeColor: Color(0xFF3949AB),
                  ),
                  SizedBox(width: 8),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'Tidak',
                          style: TextStyle(
                            fontSize: 14,
                            fontWeight: FontWeight.w600,
                            color: widget.formData.itemDangerous == '0'
                                ? Color(0xFF3949AB)
                                : Color(0xFF2D3436),
                          ),
                        ),
                        SizedBox(height: 2),
                        Text(
                          'Produk tidak mengandung bahan berbahaya',
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
            ),
          ),

          SizedBox(height: 12),

          // Radio Option 2: Ya (Berbahaya)
          InkWell(
            onTap: () {
              setState(() {
                widget.formData.itemDangerous = '1';
                widget.onChanged();
              });
            },
            child: Container(
              padding: EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: widget.formData.itemDangerous == '1'
                    ? Colors.orange.withOpacity(0.1)
                    : Colors.grey[50],
                borderRadius: BorderRadius.circular(8),
                border: Border.all(
                  color: widget.formData.itemDangerous == '1'
                      ? Colors.orange
                      : Colors.grey[300]!,
                  width: widget.formData.itemDangerous == '1' ? 2 : 1,
                ),
              ),
              child: Row(
                children: [
                  Radio<String>(
                    value: '1',
                    groupValue: widget.formData.itemDangerous,
                    onChanged: (value) {
                      setState(() {
                        widget.formData.itemDangerous = value ?? '0';
                        widget.onChanged();
                      });
                    },
                    activeColor: Colors.orange,
                  ),
                  SizedBox(width: 8),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'Mengandung bahan berbahaya',
                          style: TextStyle(
                            fontSize: 14,
                            fontWeight: FontWeight.w600,
                            color: widget.formData.itemDangerous == '1'
                                ? Colors.orange
                                : Color(0xFF2D3436),
                          ),
                        ),
                        SizedBox(height: 2),
                        Text(
                          'Baterai, magnet, cairan, atau bahan mudah terbakar',
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
            ),
          ),

          // Warning if dangerous
          if (widget.formData.itemDangerous == '1') ...[
            SizedBox(height: 12),
            Container(
              padding: EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: Colors.orange.withOpacity(0.1),
                borderRadius: BorderRadius.circular(8),
                border: Border.all(color: Colors.orange.withOpacity(0.3)),
              ),
              child: Row(
                children: [
                  Icon(
                    Icons.warning_amber_rounded,
                    color: Colors.orange,
                    size: 20,
                  ),
                  SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      'Produk berbahaya mungkin memiliki batasan pengiriman. Pastikan produk Anda sesuai dengan ketentuan Shopee.',
                      style: TextStyle(
                        fontSize: 12,
                        color: Colors.orange[800],
                        height: 1.4,
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ],
        ],
      ),
    );
  }
}
