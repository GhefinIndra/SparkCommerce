// lib/screens/product_detail/widgets/product_sku_section.dart
import 'package:flutter/material.dart';
import '../models/product_detail_model.dart';

class ProductSkuSection extends StatelessWidget {
  final List<ProductSku> skus;

  const ProductSkuSection({
    Key? key,
    required this.skus,
  }) : super(key: key);

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(20),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.04),
            blurRadius: 12,
            offset: Offset(0, 4),
          ),
        ],
      ),
      padding: EdgeInsets.all(20),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Section Header
          Row(
            children: [
              Container(
                padding: EdgeInsets.all(10),
                decoration: BoxDecoration(
                  color: Color(0xFF2196F3).withOpacity(0.1),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Icon(
                  Icons.inventory_2_rounded,
                  color: Color(0xFF2196F3),
                  size: 20,
                ),
              ),
              SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Varian Produk',
                      style: TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.w700,
                        color: Color(0xFF1A237E),
                        letterSpacing: 0.1,
                      ),
                    ),
                    Text(
                      '${skus.length} varian tersedia',
                      style: TextStyle(
                        fontSize: 12,
                        color: Colors.grey[600],
                      ),
                    ),
                  ],
                ),
              ),
              Container(
                padding: EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                decoration: BoxDecoration(
                  color: Color(0xFF2196F3),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Text(
                  '${skus.length}',
                  style: TextStyle(
                    color: Colors.white,
                    fontSize: 12,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ),
            ],
          ),

          SizedBox(height: 20),

          // SKU List
          ...skus.asMap().entries.map((entry) {
            final index = entry.key;
            final sku = entry.value;
            return _buildSkuItem(sku, index);
          }).toList(),
        ],
      ),
    );
  }

  Widget _buildSkuItem(ProductSku sku, int index) {
    return Container(
      margin: EdgeInsets.only(bottom: index < skus.length - 1 ? 16 : 0),
      padding: EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.grey[50],
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: Colors.grey[200]!),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // SKU Header
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
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      sku.displayName,
                      style: TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.w600,
                        color: Colors.grey[800],
                      ),
                    ),
                    if (sku.id.isNotEmpty)
                      Text(
                        'ID: ${sku.id}',
                        style: TextStyle(
                          fontSize: 11,
                          color: Colors.grey[500],
                        ),
                      ),
                  ],
                ),
              ),
            ],
          ),

          SizedBox(height: 16),

          // Price and Stock Info
          Row(
            children: [
              Expanded(
                child: _buildSkuInfoItem(
                  icon: Icons.local_offer_outlined,
                  iconColor: Color(0xFF7C4DFF),
                  label: 'Harga',
                  value: sku.price.displayPrice,
                ),
              ),
              SizedBox(width: 12),
              Expanded(
                child: _buildSkuInfoItem(
                  icon: Icons.inventory_outlined,
                  iconColor: Color(0xFF9575CD),
                  label: 'Stok',
                  value: '${sku.stock}',
                ),
              ),
            ],
          ),

          // Warehouse Info (separate row with elegant design)
          if (sku.warehouseId?.isNotEmpty == true) ...[
            SizedBox(height: 12),
            Container(
              padding: EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(8),
                border: Border.all(color: Colors.grey[300]!),
              ),
              child: Row(
                children: [
                  Icon(
                    Icons.warehouse_outlined,
                    size: 16,
                    color: Colors.grey[600],
                  ),
                  SizedBox(width: 8),
                  Text(
                    'Warehouse: ',
                    style: TextStyle(
                      fontSize: 12,
                      color: Colors.grey[600],
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                  Expanded(
                    child: Text(
                      sku.warehouseId!,
                      style: TextStyle(
                        fontSize: 12,
                        color: Colors.grey[800],
                        fontWeight: FontWeight.w600,
                        letterSpacing: 0.2,
                      ),
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
                ],
              ),
            ),
          ],

          // Attributes
          if (sku.attributes.isNotEmpty) ...[
            SizedBox(height: 16),
            Container(
              width: double.infinity,
              padding: EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(8),
                border: Border.all(color: Colors.grey[300]!),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Icon(
                        Icons.tune,
                        size: 14,
                        color: Colors.grey[600],
                      ),
                      SizedBox(width: 4),
                      Text(
                        'Atribut',
                        style: TextStyle(
                          fontSize: 12,
                          fontWeight: FontWeight.w500,
                          color: Colors.grey[600],
                        ),
                      ),
                    ],
                  ),
                  SizedBox(height: 8),
                  Wrap(
                    spacing: 8,
                    runSpacing: 4,
                    children: sku.attributes
                        .map((attr) => Container(
                              padding: EdgeInsets.symmetric(
                                  horizontal: 8, vertical: 4),
                              decoration: BoxDecoration(
                                color: Color(0xFF2196F3).withOpacity(0.1),
                                borderRadius: BorderRadius.circular(12),
                              ),
                              child: Text(
                                '${attr.name}: ${attr.valueName}',
                                style: TextStyle(
                                  fontSize: 11,
                                  color: Color(0xFF2196F3),
                                  fontWeight: FontWeight.w500,
                                ),
                              ),
                            ))
                        .toList(),
                  ),
                ],
              ),
            ),
          ],
        ],
      ),
    );
  }

  Widget _buildSkuInfoItem({
    required IconData icon,
    required Color iconColor,
    required String label,
    required String value,
  }) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Icon(icon, size: 14, color: iconColor),
            SizedBox(width: 4),
            Text(
              label,
              style: TextStyle(
                fontSize: 11,
                color: Colors.grey[600],
                fontWeight: FontWeight.w500,
              ),
            ),
          ],
        ),
        SizedBox(height: 6),
        Text(
          value,
          style: TextStyle(
            fontSize: 15,
            fontWeight: FontWeight.w700,
            color: iconColor,
            letterSpacing: -0.3,
          ),
        ),
      ],
    );
  }

  Color _getStockColor(int stock) {
    if (stock <= 0) return Colors.red[600]!;
    if (stock <= 10) return Colors.orange[600]!;
    return Color(0xFF4CAF50);
  }
}
