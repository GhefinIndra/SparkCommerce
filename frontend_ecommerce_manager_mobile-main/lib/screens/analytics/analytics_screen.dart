// screens/analytics/analytics_screen.dart
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../../services/analytics_service.dart';
import 'widgets/metric_card.dart';
import 'widgets/revenue_trend_chart.dart';
import 'widgets/order_status_donut_chart.dart';
import 'widgets/top_products_list.dart';
import 'widgets/shop_comparison_widget.dart';

/// Multi-platform analytics dashboard with:
/// - Sales summary (revenue, orders, AOV)
/// - Revenue trend chart
/// - Order status breakdown
/// - Top selling products
/// - Shop performance comparison
class AnalyticsScreen extends StatefulWidget {
  @override
  _AnalyticsScreenState createState() => _AnalyticsScreenState();
}

class _AnalyticsScreenState extends State<AnalyticsScreen> {
  final AnalyticsService _analyticsService = AnalyticsService();

  // Date range filter
  DateTime _startDate = DateTime.now().subtract(Duration(days: 30));
  DateTime _endDate = DateTime.now();

  // Platform filter
  String _selectedPlatform = 'all'; // 'all', 'tiktok', 'shopee'

  // Loading states
  bool _isLoadingSummary = true;
  bool _isLoadingTrend = true;
  bool _isLoadingOrderStatus = true;
  bool _isLoadingTopProducts = true;

  // Data
  Map<String, dynamic>? _salesSummary;
  List<Map<String, dynamic>>? _revenueTrend;
  Map<String, dynamic>? _orderStatusBreakdown;
  List<Map<String, dynamic>>? _topProducts;

  @override
  void initState() {
    super.initState();
    _loadAllAnalytics();
  }

  Future<void> _loadAllAnalytics() async {
    await Future.wait([
      _loadSalesSummary(),
      _loadRevenueTrend(),
      _loadOrderStatusBreakdown(),
      _loadTopProducts(),
    ]);
  }

  Future<void> _loadSalesSummary() async {
    setState(() => _isLoadingSummary = true);
    try {
      final data = await _analyticsService.getSalesSummary(
        platform: _selectedPlatform,
        startDate: _startDate,
        endDate: _endDate,
      );
      setState(() {
        _salesSummary = data;
        _isLoadingSummary = false;
      });
    } catch (e) {
      print('Error loading sales summary: $e');
      setState(() => _isLoadingSummary = false);
    }
  }

  Future<void> _loadRevenueTrend() async {
    setState(() => _isLoadingTrend = true);
    try {
      final data = await _analyticsService.getRevenueTrend(
        platform: _selectedPlatform,
        startDate: _startDate,
        endDate: _endDate,
        groupBy: 'day',
      );
      setState(() {
        _revenueTrend = data;
        _isLoadingTrend = false;
      });
    } catch (e) {
      print('Error loading revenue trend: $e');
      setState(() => _isLoadingTrend = false);
    }
  }

  Future<void> _loadOrderStatusBreakdown() async {
    setState(() => _isLoadingOrderStatus = true);
    try {
      final data = await _analyticsService.getOrderStatusBreakdown(
        platform: _selectedPlatform,
        startDate: _startDate,
        endDate: _endDate,
      );
      setState(() {
        _orderStatusBreakdown = data;
        _isLoadingOrderStatus = false;
      });
    } catch (e) {
      print('Error loading order status: $e');
      setState(() => _isLoadingOrderStatus = false);
    }
  }

  Future<void> _loadTopProducts() async {
    setState(() => _isLoadingTopProducts = true);
    try {
      final data = await _analyticsService.getTopProducts(
        platform: _selectedPlatform,
        startDate: _startDate,
        endDate: _endDate,
        sortBy: 'quantity',
        limit: 10,
      );
      setState(() {
        _topProducts = data;
        _isLoadingTopProducts = false;
      });
    } catch (e) {
      print('Error loading top products: $e');
      setState(() => _isLoadingTopProducts = false);
    }
  }

  void _showDateRangePicker() async {
    final DateTimeRange? picked = await showDateRangePicker(
      context: context,
      firstDate: DateTime(2020),
      lastDate: DateTime.now(),
      initialDateRange: DateTimeRange(start: _startDate, end: _endDate),
      builder: (context, child) {
        return Theme(
          data: Theme.of(context).copyWith(
            colorScheme: ColorScheme.light(
              primary: Color(0xFF3949AB),
              onPrimary: Colors.white,
              surface: Colors.white,
              onSurface: Colors.black,
            ),
          ),
          child: child!,
        );
      },
    );

    if (picked != null) {
      setState(() {
        _startDate = picked.start;
        _endDate = picked.end;
      });
      _loadAllAnalytics();
    }
  }

  @override
  Widget build(BuildContext context) {
    return AnnotatedRegion<SystemUiOverlayStyle>(
      value: SystemUiOverlayStyle(
        statusBarColor: Colors.transparent,
        statusBarBrightness: Brightness.dark,
        statusBarIconBrightness: Brightness.light,
      ),
      child: Scaffold(
        backgroundColor: Color(0xFF1A237E),
        body: Container(
          decoration: BoxDecoration(
            gradient: LinearGradient(
              colors: [
                Color(0xFF1A237E),
                Color(0xFF283593),
                Color(0xFF3949AB),
              ],
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
            ),
          ),
          child: Column(
            children: [
              // Premium Header
              _buildHeader(),

              // Main Content
              Expanded(
                child: Container(
                  decoration: BoxDecoration(
                    color: Color(0xFFF5F7FA),
                    borderRadius: BorderRadius.only(
                      topLeft: Radius.circular(30),
                      topRight: Radius.circular(30),
                    ),
                    boxShadow: [
                      BoxShadow(
                        color: Color(0xFF1A237E).withOpacity(0.1),
                        blurRadius: 10,
                        offset: Offset(0, -5),
                      ),
                    ],
                  ),
                  child: RefreshIndicator(
                    onRefresh: _loadAllAnalytics,
                    color: Color(0xFF3949AB),
                    child: SingleChildScrollView(
                      physics: AlwaysScrollableScrollPhysics(
                        parent: BouncingScrollPhysics(),
                      ),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          SizedBox(height: 24),

                          // Filters Section
                          _buildFilters(),

                          SizedBox(height: 24),

                          // Sales Summary Cards
                          _buildSalesSummaryCards(),

                          SizedBox(height: 24),

                          // Revenue Trend Chart
                          _buildRevenueTrendSection(),

                          SizedBox(height: 24),

                          // Order Status & Top Products (2 columns)
                          _buildOrderAndProductsSection(),

                          SizedBox(height: 24),
                        ],
                      ),
                    ),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildHeader() {
    return Container(
      padding: EdgeInsets.only(top: MediaQuery.of(context).viewPadding.top),
      child: Column(
        children: [
          Padding(
            padding: EdgeInsets.fromLTRB(24, 20, 24, 20),
            child: Row(
              children: [
                IconButton(
                  icon: Icon(Icons.arrow_back, color: Colors.white),
                  onPressed: () => Navigator.pop(context),
                ),
                SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Analytics Dashboard',
                        style: TextStyle(
                          color: Colors.white,
                          fontSize: 24,
                          fontWeight: FontWeight.w700,
                          letterSpacing: -0.5,
                        ),
                      ),
                      SizedBox(height: 4),
                      Text(
                        'Business Performance Insights',
                        style: TextStyle(
                          color: Colors.white.withOpacity(0.9),
                          fontSize: 13,
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildFilters() {
    return Padding(
      padding: EdgeInsets.symmetric(horizontal: 20),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Filters',
            style: TextStyle(
              fontSize: 16,
              fontWeight: FontWeight.w700,
              color: Color(0xFF1A237E),
            ),
          ),
          SizedBox(height: 12),
          Row(
            children: [
              // Date Range Filter
              Expanded(
                child: InkWell(
                  onTap: _showDateRangePicker,
                  child: Container(
                    padding: EdgeInsets.all(14),
                    decoration: BoxDecoration(
                      color: Colors.white,
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(color: Color(0xFF3949AB).withOpacity(0.2)),
                    ),
                    child: Row(
                      children: [
                        Icon(Icons.calendar_today, color: Color(0xFF3949AB), size: 18),
                        SizedBox(width: 8),
                        Expanded(
                          child: Text(
                            '${_formatDate(_startDate)} - ${_formatDate(_endDate)}',
                            style: TextStyle(fontSize: 12, fontWeight: FontWeight.w500),
                            overflow: TextOverflow.ellipsis,
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ),
              SizedBox(width: 12),
              // Platform Filter
              Container(
                padding: EdgeInsets.symmetric(horizontal: 12, vertical: 14),
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(color: Color(0xFF3949AB).withOpacity(0.2)),
                ),
                child: DropdownButton<String>(
                  value: _selectedPlatform,
                  underline: SizedBox(),
                  icon: Icon(Icons.arrow_drop_down, color: Color(0xFF3949AB)),
                  items: [
                    DropdownMenuItem(value: 'all', child: Text('All', style: TextStyle(fontSize: 13))),
                    DropdownMenuItem(value: 'tiktok', child: Text('TikTok', style: TextStyle(fontSize: 13))),

                    // DropdownMenuItem(value: 'shopee', child: Text('Shopee')),
                  ],
                  onChanged: (value) {
                    if (value != null) {
                      setState(() => _selectedPlatform = value);
                      _loadAllAnalytics();
                    }
                  },
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildSalesSummaryCards() {
    if (_isLoadingSummary) {
      return Padding(
        padding: EdgeInsets.symmetric(horizontal: 20),
        child: Row(
          children: [
            Expanded(child: _buildLoadingCard()),
            SizedBox(width: 12),
            Expanded(child: _buildLoadingCard()),
            SizedBox(width: 12),
            Expanded(child: _buildLoadingCard()),
          ],
        ),
      );
    }

    if (_salesSummary == null) {
      return SizedBox();
    }

    final revenue = _salesSummary!['totalRevenue'] ?? 0.0;
    final orders = _salesSummary!['orderCount'] ?? 0;
    final aov = _salesSummary!['avgOrderValue'] ?? 0.0;
    final growth = _salesSummary!['growth'];

    return Padding(
      padding: EdgeInsets.symmetric(horizontal: 20),
      child: Row(
        children: [
          Expanded(
            child: MetricCard(
              icon: Icons.attach_money,
              label: 'Revenue',
              value: 'Rp ${_formatNumber(revenue)}',
              growth: growth != null ? growth['revenue'] : null,
              color: Color(0xFF00AA5B),
            ),
          ),
          SizedBox(width: 12),
          Expanded(
            child: MetricCard(
              icon: Icons.shopping_bag,
              label: 'Orders',
              value: '$orders',
              growth: growth != null ? growth['orders'] : null,
              color: Color(0xFF2196F3),
            ),
          ),
          SizedBox(width: 12),
          Expanded(
            child: MetricCard(
              icon: Icons.trending_up,
              label: 'AOV',
              value: 'Rp ${_formatNumber(aov)}',
              color: Color(0xFF9C27B0),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildRevenueTrendSection() {
    return Padding(
      padding: EdgeInsets.symmetric(horizontal: 20),
      child: Container(
        padding: EdgeInsets.all(20),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(16),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withOpacity(0.04),
              blurRadius: 10,
              offset: Offset(0, 2),
            ),
          ],
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(
                  'Revenue Trend',
                  style: TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.w700,
                    color: Color(0xFF1A237E),
                  ),
                ),
                Icon(Icons.show_chart, color: Color(0xFF3949AB)),
              ],
            ),
            SizedBox(height: 20),
            _isLoadingTrend
                ? Center(
                    child: Padding(
                      padding: EdgeInsets.all(40),
                      child: CircularProgressIndicator(color: Color(0xFF3949AB)),
                    ),
                  )
                : RevenueTrendChart(data: _revenueTrend ?? []),
          ],
        ),
      ),
    );
  }

  Widget _buildOrderAndProductsSection() {
    return Padding(
      padding: EdgeInsets.symmetric(horizontal: 20),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Order Status Donut Chart
          Expanded(
            child: Container(
              padding: EdgeInsets.all(20),
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(16),
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withOpacity(0.04),
                    blurRadius: 10,
                    offset: Offset(0, 2),
                  ),
                ],
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Order Status',
                    style: TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.w700,
                      color: Color(0xFF1A237E),
                    ),
                  ),
                  SizedBox(height: 16),
                  _isLoadingOrderStatus
                      ? Center(
                          child: Padding(
                            padding: EdgeInsets.all(30),
                            child: CircularProgressIndicator(color: Color(0xFF3949AB)),
                          ),
                        )
                      : OrderStatusDonutChart(data: _orderStatusBreakdown),
                ],
              ),
            ),
          ),
          SizedBox(width: 16),
          // Top Products
          Expanded(
            child: Container(
              padding: EdgeInsets.all(20),
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(16),
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withOpacity(0.04),
                    blurRadius: 10,
                    offset: Offset(0, 2),
                  ),
                ],
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Top Products',
                    style: TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.w700,
                      color: Color(0xFF1A237E),
                    ),
                  ),
                  SizedBox(height: 16),
                  _isLoadingTopProducts
                      ? Center(
                          child: Padding(
                            padding: EdgeInsets.all(30),
                            child: CircularProgressIndicator(color: Color(0xFF3949AB)),
                          ),
                        )
                      : TopProductsList(products: _topProducts ?? []),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildLoadingCard() {
    return Container(
      height: 100,
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
      ),
      child: Center(
        child: CircularProgressIndicator(
          color: Color(0xFF3949AB),
          strokeWidth: 2,
        ),
      ),
    );
  }

  String _formatDate(DateTime date) {
    return '${date.day}/${date.month}/${date.year}';
  }

  String _formatNumber(double number) {
    if (number >= 1000000) {
      return '${(number / 1000000).toStringAsFixed(1)}M';
    } else if (number >= 1000) {
      return '${(number / 1000).toStringAsFixed(1)}K';
    }
    return number.toStringAsFixed(0);
  }
}
