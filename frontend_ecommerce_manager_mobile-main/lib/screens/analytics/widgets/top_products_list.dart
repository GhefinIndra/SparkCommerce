// screens/analytics/widgets/top_products_list.dart
import 'package:flutter/material.dart';

class TopProductsList extends StatelessWidget {
  final List<Map<String, dynamic>> products;

  const TopProductsList({Key? key, required this.products}) : super(key: key);

  @override
  Widget build(BuildContext context) {
    if (products.isEmpty) {
      return Center(
        child: Text(
          'No products data',
          style: TextStyle(color: Colors.grey[600]),
        ),
      );
    }

    return ListView.separated(
      shrinkWrap: true,
      physics: NeverScrollableScrollPhysics(),
      itemCount: products.length > 5 ? 5 : products.length,
      separatorBuilder: (context, index) => SizedBox(height: 12),
      itemBuilder: (context, index) {
        final product = products[index];
        final rank = product['rank'] ?? (index + 1);
        final name = product['productName'] ?? 'Unknown';
        final quantity = product['totalQuantity'] ?? 0;
        final revenue = product['totalRevenue'] ?? 0.0;

        return Container(
          padding: EdgeInsets.all(12),
          decoration: BoxDecoration(
            color: Colors.grey[50],
            borderRadius: BorderRadius.circular(8),
            border: Border.all(color: Colors.grey[200]!),
          ),
          child: Row(
            children: [
              // Rank badge
              Container(
                width: 28,
                height: 28,
                decoration: BoxDecoration(
                  color: _getRankColor(rank),
                  shape: BoxShape.circle,
                ),
                child: Center(
                  child: Text(
                    '$rank',
                    style: TextStyle(
                      color: Colors.white,
                      fontSize: 12,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ),
              ),
              SizedBox(width: 12),
              // Product info
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      name,
                      style: TextStyle(
                        fontSize: 13,
                        fontWeight: FontWeight.w600,
                        color: Color(0xFF1A237E),
                      ),
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                    ),
                    SizedBox(height: 4),
                    Row(
                      children: [
                        Icon(Icons.shopping_cart, size: 12, color: Colors.grey[600]),
                        SizedBox(width: 4),
                        Text(
                          '$quantity pcs',
                          style: TextStyle(fontSize: 11, color: Colors.grey[600]),
                        ),
                        SizedBox(width: 12),
                        Icon(Icons.attach_money, size: 12, color: Colors.green),
                        Text(
                          _formatRevenue(revenue),
                          style: TextStyle(
                            fontSize: 11,
                            color: Colors.green,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            ],
          ),
        );
      },
    );
  }

  Color _getRankColor(int rank) {
    if (rank == 1) return Color(0xFFFFD700); // Gold
    if (rank == 2) return Color(0xFFC0C0C0); // Silver
    if (rank == 3) return Color(0xFFCD7F32); // Bronze
    return Color(0xFF3949AB);
  }

  String _formatRevenue(double revenue) {
    if (revenue >= 1000000) {
      return '${(revenue / 1000000).toStringAsFixed(1)}M';
    } else if (revenue >= 1000) {
      return '${(revenue / 1000).toStringAsFixed(1)}K';
    }
    return revenue.toStringAsFixed(0);
  }
}
