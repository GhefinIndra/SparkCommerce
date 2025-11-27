// screens/analytics/widgets/order_status_donut_chart.dart
import 'package:flutter/material.dart';

class OrderStatusDonutChart extends StatelessWidget {
  final Map<String, dynamic>? data;

  const OrderStatusDonutChart({Key? key, this.data}) : super(key: key);

  @override
  Widget build(BuildContext context) {
    if (data == null || data!['breakdown'] == null) {
      return Center(
        child: Text(
          'No data available',
          style: TextStyle(color: Colors.grey[600]),
        ),
      );
    }

    final breakdown = data!['breakdown'] as List;
    if (breakdown.isEmpty) {
      return Center(
        child: Text(
          'No orders yet',
          style: TextStyle(color: Colors.grey[600]),
        ),
      );
    }

    return Column(
      children: [
        // Simplified donut visualization
        Container(
          height: 120,
          child: Center(
            child: Stack(
              alignment: Alignment.center,
              children: [
                Container(
                  width: 120,
                  height: 120,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    gradient: LinearGradient(
                      colors: [
                        Color(0xFF3949AB),
                        Color(0xFF1A237E),
                      ],
                    ),
                  ),
                ),
                Container(
                  width: 80,
                  height: 80,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    color: Colors.white,
                  ),
                  child: Center(
                    child: Text(
                      '${data!['total']}',
                      style: TextStyle(
                        fontSize: 24,
                        fontWeight: FontWeight.bold,
                        color: Color(0xFF1A237E),
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
        SizedBox(height: 16),
        // Legend
        ...breakdown.take(5).map((item) {
          final color = _parseColor(item['color']);
          return Padding(
            padding: EdgeInsets.only(bottom: 8),
            child: Row(
              children: [
                Container(
                  width: 12,
                  height: 12,
                  decoration: BoxDecoration(
                    color: color,
                    borderRadius: BorderRadius.circular(2),
                  ),
                ),
                SizedBox(width: 8),
                Expanded(
                  child: Text(
                    item['label'],
                    style: TextStyle(fontSize: 12, color: Colors.grey[800]),
                  ),
                ),
                Text(
                  '${item['count']}',
                  style: TextStyle(
                    fontSize: 12,
                    fontWeight: FontWeight.bold,
                    color: Color(0xFF1A237E),
                  ),
                ),
              ],
            ),
          );
        }).toList(),
      ],
    );
  }

  Color _parseColor(String colorString) {
    try {
      return Color(int.parse(colorString.replaceFirst('#', '0xFF')));
    } catch (e) {
      return Color(0xFF3949AB);
    }
  }
}
