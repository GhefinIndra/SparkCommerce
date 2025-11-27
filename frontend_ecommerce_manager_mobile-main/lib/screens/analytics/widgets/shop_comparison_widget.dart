// screens/analytics/widgets/shop_comparison_widget.dart
import 'package:flutter/material.dart';

class ShopComparisonWidget extends StatelessWidget {
  final List<Map<String, dynamic>> shops;

  const ShopComparisonWidget({Key? key, required this.shops}) : super(key: key);

  @override
  Widget build(BuildContext context) {
    if (shops.isEmpty) {
      return Center(
        child: Text(
          'No shop data',
          style: TextStyle(color: Colors.grey[600]),
        ),
      );
    }

    return ListView.separated(
      shrinkWrap: true,
      physics: NeverScrollableScrollPhysics(),
      itemCount: shops.length,
      separatorBuilder: (context, index) => SizedBox(height: 12),
      itemBuilder: (context, index) {
        final shop = shops[index];
        return Container(
          padding: EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(12),
            border: Border.all(color: Colors.grey[200]!),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                shop['shopName'] ?? 'Shop',
                style: TextStyle(fontWeight: FontWeight.bold),
              ),
              SizedBox(height: 8),
              Text('Revenue: ${shop['revenue']}'),
              Text('Orders: ${shop['orderCount']}'),
            ],
          ),
        );
      },
    );
  }
}
