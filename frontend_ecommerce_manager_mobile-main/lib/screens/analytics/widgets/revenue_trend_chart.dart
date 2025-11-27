// screens/analytics/widgets/revenue_trend_chart.dart
import 'package:flutter/material.dart';

class RevenueTrendChart extends StatelessWidget {
  final List<Map<String, dynamic>> data;

  const RevenueTrendChart({Key? key, required this.data}) : super(key: key);

  @override
  Widget build(BuildContext context) {
    if (data.isEmpty) {
      return Center(
        child: Padding(
          padding: EdgeInsets.all(40),
          child: Text(
            'No data available',
            style: TextStyle(color: Colors.grey[600]),
          ),
        ),
      );
    }

    // Find max revenue for scaling
    double maxRevenue = data.map((e) => e['revenue'] as double).reduce((a, b) => a > b ? a : b);
    if (maxRevenue == 0) maxRevenue = 1;

    return Container(
      height: 200,
      child: Column(
        children: [
          // Simple bar chart visualization
          Expanded(
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.end,
              children: data.take(15).map((item) {
                final revenue = item['revenue'] as double;
                final height = (revenue / maxRevenue) * 150;

                return Expanded(
                  child: Padding(
                    padding: EdgeInsets.symmetric(horizontal: 2),
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.end,
                      children: [
                        Container(
                          height: height,
                          decoration: BoxDecoration(
                            gradient: LinearGradient(
                              colors: [Color(0xFF3949AB), Color(0xFF1A237E)],
                              begin: Alignment.topCenter,
                              end: Alignment.bottomCenter,
                            ),
                            borderRadius: BorderRadius.vertical(top: Radius.circular(4)),
                          ),
                        ),
                      ],
                    ),
                  ),
                );
              }).toList(),
            ),
          ),
          SizedBox(height: 12),
          // Legend
          Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Container(
                width: 12,
                height: 12,
                decoration: BoxDecoration(
                  color: Color(0xFF3949AB),
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
              SizedBox(width: 6),
              Text(
                'Daily Revenue',
                style: TextStyle(fontSize: 12, color: Colors.grey[600]),
              ),
            ],
          ),
        ],
      ),
    );
  }
}
