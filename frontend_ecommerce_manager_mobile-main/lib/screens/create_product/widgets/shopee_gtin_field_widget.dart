// lib/screens/create_product/widgets/shopee_gtin_field_widget.dart
import 'package:flutter/material.dart';
import '../models/product_form_data.dart';

/// GTIN Field Widget for Shopee
/// Shows:
/// - Text field for GTIN input (8-14 digits)
/// - Checkbox "Produk tanpa GTIN"
class ShopeeGTINFieldWidget extends StatefulWidget {
  final ProductFormData formData;
  final Function() onChanged;
  final bool isMandatory;
  final String validationRule; // "Mandatory", "Flexible", "Optional"

  const ShopeeGTINFieldWidget({
    Key? key,
    required this.formData,
    required this.onChanged,
    this.isMandatory = false,
    this.validationRule = 'Optional',
  }) : super(key: key);

  @override
  _ShopeeGTINFieldWidgetState createState() => _ShopeeGTINFieldWidgetState();
}

class _ShopeeGTINFieldWidgetState extends State<ShopeeGTINFieldWidget> {
  late TextEditingController _gtinController;
  late bool _noGtin;

  @override
  void initState() {
    super.initState();
    _gtinController = TextEditingController(text: widget.formData.gtin ?? '');
    _noGtin = widget.formData.productWithoutGtin;
  }

  @override
  void dispose() {
    _gtinController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    // Show field based on validation rule
    final showField = widget.validationRule != 'Optional' ||
                      widget.formData.gtin != null ||
                      widget.formData.productWithoutGtin;

    if (!showField && widget.validationRule == 'Optional') {
      return SizedBox.shrink(); // Don't show if optional and not filled
    }

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
                'GTIN',
                style: TextStyle(
                  fontSize: 14,
                  fontWeight: FontWeight.w600,
                  color: Color(0xFF2D3436),
                ),
              ),
              if (widget.validationRule == 'Mandatory' ||
                  widget.validationRule == 'Flexible')
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
                message: 'GTIN (8-14 digits): UPC, EAN, JAN, ISBN.\nMembantu produk muncul di pencarian Google & Facebook.',
                child: Icon(
                  Icons.info_outline,
                  size: 16,
                  color: Colors.grey[600],
                ),
              ),
            ],
          ),
          SizedBox(height: 12),

          // GTIN Text Field
          TextFormField(
            controller: _gtinController,
            enabled: !_noGtin,
            keyboardType: TextInputType.number,
            decoration: InputDecoration(
              hintText: _noGtin ? 'Produk tanpa GTIN' : 'Masukkan GTIN (8-14 digit)',
              filled: true,
              fillColor: _noGtin ? Colors.grey[100] : Colors.white,
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(8),
                borderSide: BorderSide(color: Colors.grey[300]!),
              ),
              enabledBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(8),
                borderSide: BorderSide(color: Colors.grey[300]!),
              ),
              focusedBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(8),
                borderSide: BorderSide(color: Color(0xFF3949AB), width: 2),
              ),
              contentPadding: EdgeInsets.symmetric(horizontal: 12, vertical: 14),
            ),
            onChanged: (value) {
              widget.formData.gtin = value.trim();
              widget.onChanged();
            },
            validator: (value) {
              // Skip validation if "No GTIN" is checked
              if (_noGtin) return null;

              // Mandatory: must have valid GTIN
              if (widget.validationRule == 'Mandatory') {
                if (value == null || value.trim().isEmpty) {
                  return 'GTIN wajib diisi';
                }
                if (!_isValidGTIN(value.trim())) {
                  return 'GTIN harus 8-14 digit';
                }
              }

              // Flexible: must have valid GTIN or "00"
              if (widget.validationRule == 'Flexible') {
                if (value == null || value.trim().isEmpty) {
                  return 'GTIN wajib diisi atau centang "Produk tanpa GTIN"';
                }
                if (!_isValidGTIN(value.trim())) {
                  return 'GTIN harus 8-14 digit';
                }
              }

              // Optional: validate format only if filled
              if (value != null && value.trim().isNotEmpty) {
                if (!_isValidGTIN(value.trim())) {
                  return 'GTIN harus 8-14 digit';
                }
              }

              return null;
            },
          ),

          SizedBox(height: 12),

          // Checkbox "Produk tanpa GTIN" (only for Flexible and Optional)
          if (widget.validationRule != 'Mandatory')
            InkWell(
              onTap: () {
                setState(() {
                  _noGtin = !_noGtin;
                  widget.formData.productWithoutGtin = _noGtin;
                  if (_noGtin) {
                    _gtinController.clear();
                    widget.formData.gtin = null;
                  }
                  widget.onChanged();
                });
              },
              child: Row(
                children: [
                  Checkbox(
                    value: _noGtin,
                    onChanged: (value) {
                      setState(() {
                        _noGtin = value ?? false;
                        widget.formData.productWithoutGtin = _noGtin;
                        if (_noGtin) {
                          _gtinController.clear();
                          widget.formData.gtin = null;
                        }
                        widget.onChanged();
                      });
                    },
                    activeColor: Color(0xFF3949AB),
                  ),
                  Expanded(
                    child: Text(
                      'Produk tanpa GTIN',
                      style: TextStyle(
                        fontSize: 13,
                        color: Color(0xFF2D3436),
                      ),
                    ),
                  ),
                ],
              ),
            ),

          // Help text
          SizedBox(height: 8),
          Text(
            'GTIN membantu produk Anda muncul di pencarian Google, Facebook, dan rekomendasi Shopee.',
            style: TextStyle(
              fontSize: 12,
              color: Colors.grey[600],
              height: 1.4,
            ),
          ),
        ],
      ),
    );
  }

  bool _isValidGTIN(String value) {
    // GTIN must be 8-14 digits
    if (value.isEmpty) return false;
    if (value.length < 8 || value.length > 14) return false;

    // Must be all digits
    final numericRegex = RegExp(r'^[0-9]+$');
    return numericRegex.hasMatch(value);
  }
}
