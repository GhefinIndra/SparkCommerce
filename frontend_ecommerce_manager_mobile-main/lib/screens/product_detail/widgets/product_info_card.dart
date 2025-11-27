// lib/screens/product_detail/widgets/product_info_card.dart
import 'package:flutter/material.dart';
import 'package:flutter_html/flutter_html.dart';
import '../models/product_detail_model.dart';

class ProductInfoCard extends StatelessWidget {
  final ProductDetailModel product;

  const ProductInfoCard({
    Key? key,
    required this.product,
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
          // Product Title
          Text(
            product.title,
            style: TextStyle(
              fontSize: 18,
              fontWeight: FontWeight.w700,
              color: Color(0xFF1A237E),
              height: 1.3,
              letterSpacing: 0.1,
            ),
          ),

          SizedBox(height: 16),

          // Price and Stock Row
          Row(
            children: [
              Expanded(
                child: _buildInfoItem(
                  icon: Icons.attach_money,
                  iconColor: Color(0xFF4CAF50),
                  title: 'Harga',
                  value: product.priceRange,
                ),
              ),
              Container(
                width: 1,
                height: 40,
                color: Colors.grey[300],
                margin: EdgeInsets.symmetric(horizontal: 16),
              ),
              Expanded(
                child: _buildInfoItem(
                  icon: Icons.inventory_2_outlined,
                  iconColor: Color(0xFF2196F3),
                  title: 'Total Stok',
                  value: '${product.totalStock} pcs',
                ),
              ),
            ],
          ),

          SizedBox(height: 20),

          // Status Badge
          Row(
            children: [
              _buildInfoItem(
                icon: Icons.info_outline,
                iconColor: Colors.grey[600]!,
                title: 'Status',
                value: '',
              ),
              SizedBox(width: 8),
              Container(
                padding: EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                decoration: BoxDecoration(
                  color: product.statusBackgroundColor,
                  borderRadius: BorderRadius.circular(20),
                  border: Border.all(
                    color: product.statusColor.withOpacity(0.3),
                    width: 1,
                  ),
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Container(
                      width: 6,
                      height: 6,
                      decoration: BoxDecoration(
                        color: product.statusColor,
                        shape: BoxShape.circle,
                      ),
                    ),
                    SizedBox(width: 6),
                    Text(
                      product.statusText,
                      style: TextStyle(
                        fontSize: 12,
                        color: product.statusColor,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),

          SizedBox(height: 20),

          // Description Section
          Container(
            width: double.infinity,
            padding: EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: Colors.grey[50],
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: Colors.grey[200]!),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Icon(
                      Icons.description_outlined,
                      size: 18,
                      color: Colors.grey[600],
                    ),
                    SizedBox(width: 8),
                    Text(
                      'Deskripsi Produk',
                      style: TextStyle(
                        fontSize: 14,
                        fontWeight: FontWeight.w600,
                        color: Colors.grey[700],
                      ),
                    ),
                  ],
                ),
                SizedBox(height: 12),
                product.description.isNotEmpty
                    ? Html(
                        data: product.description,
                        style: {
                          "body": Style(
                            fontSize: FontSize(14),
                            color: Colors.grey[700],
                            margin: Margins.zero,
                            padding: HtmlPaddings.all(0),
                            lineHeight: LineHeight(1.5),
                          ),
                          "p": Style(
                            margin: Margins.only(bottom: 8),
                          ),
                          "ul": Style(
                            margin: Margins.only(left: 16, bottom: 8),
                          ),
                          "li": Style(
                            margin: Margins.only(bottom: 4),
                          ),
                        },
                      )
                    : Text(
                        'Tidak ada deskripsi produk',
                        style: TextStyle(
                          fontSize: 14,
                          color: Colors.grey[500],
                          fontStyle: FontStyle.italic,
                        ),
                      ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildInfoItem({
    required IconData icon,
    required Color iconColor,
    required String title,
    required String value,
  }) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Icon(icon, size: 16, color: iconColor),
            SizedBox(width: 6),
            Text(
              title,
              style: TextStyle(
                fontSize: 12,
                color: Colors.grey[600],
                fontWeight: FontWeight.w500,
              ),
            ),
          ],
        ),
        if (value.isNotEmpty) ...[
          SizedBox(height: 4),
          Text(
            value,
            style: TextStyle(
              fontSize: 16,
              fontWeight: FontWeight.bold,
              color: Colors.grey[800],
            ),
          ),
        ],
      ],
    );
  }
}
