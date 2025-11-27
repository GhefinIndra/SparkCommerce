// screens/analytics/widgets/metric_card.dart
import 'package:flutter/material.dart';

class MetricCard extends StatelessWidget {
  final IconData icon;
  final String label;
  final String value;
  final double? growth;
  final Color color;

  const MetricCard({
    Key? key,
    required this.icon,
    required this.label,
    required this.value,
    this.growth,
    required this.color,
  }) : super(key: key);

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.04),
            blurRadius: 8,
            offset: Offset(0, 2),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            padding: EdgeInsets.all(8),
            decoration: BoxDecoration(
              color: color.withOpacity(0.1),
              borderRadius: BorderRadius.circular(8),
            ),
            child: Icon(icon, color: color, size: 20),
          ),
          SizedBox(height: 12),
          Text(
            label,
            style: TextStyle(
              fontSize: 12,
              color: Colors.grey[600],
              fontWeight: FontWeight.w500,
            ),
          ),
          SizedBox(height: 4),
          Text(
            value,
            style: TextStyle(
              fontSize: 18,
              fontWeight: FontWeight.bold,
              color: Color(0xFF1A237E),
            ),
          ),
          if (growth != null) ...[
            SizedBox(height: 8),
            Row(
              children: [
                Icon(
                  growth! >= 0 ? Icons.trending_up : Icons.trending_down,
                  size: 14,
                  color: growth! >= 0 ? Colors.green : Colors.red,
                ),
                SizedBox(width: 4),
                Text(
                  '${growth! >= 0 ? '+' : ''}${growth!.toStringAsFixed(1)}%',
                  style: TextStyle(
                    fontSize: 12,
                    fontWeight: FontWeight.w600,
                    color: growth! >= 0 ? Colors.green : Colors.red,
                  ),
                ),
              ],
            ),
          ],
        ],
      ),
    );
  }
}
