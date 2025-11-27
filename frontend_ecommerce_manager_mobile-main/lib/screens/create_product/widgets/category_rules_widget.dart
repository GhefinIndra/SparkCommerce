// lib/screens/create_product/widgets/category_rules_widget.dart
import 'package:flutter/material.dart';
import '../../../services/api_service.dart';
import '../models/product_form_data.dart';

class CategoryRulesWidget extends StatefulWidget {
  final String shopId;
  final ProductFormData formData;
  final VoidCallback? onChanged;

  const CategoryRulesWidget({
    Key? key,
    required this.shopId,
    required this.formData,
    this.onChanged,
  }) : super(key: key);

  @override
  _CategoryRulesWidgetState createState() => _CategoryRulesWidgetState();
}

class _CategoryRulesWidgetState extends State<CategoryRulesWidget> {
  final ApiService _apiService = ApiService();
  bool _isLoading = false;
  String? _lastCategoryId;
  int _lastAttributeCount = 0;

  @override
  void initState() {
    super.initState();
    _lastCategoryId = widget.formData.selectedLevel3Id;
    _lastAttributeCount = widget.formData.selectedAttributes.length;

    
    if (widget.formData.selectedLevel3Id != null &&
        !widget.formData.categoryRulesLoaded) {
      print(
          ' CategoryRules: Auto-loading for category ${widget.formData.selectedLevel3Id}');
      WidgetsBinding.instance.addPostFrameCallback((_) {
        _loadCategoryRules();
      });
    }
  }

  @override
  void didUpdateWidget(CategoryRulesWidget oldWidget) {
    super.didUpdateWidget(oldWidget);

    final currentCategoryId = widget.formData.selectedLevel3Id;
    final currentAttributeCount = widget.formData.selectedAttributes.length;

    
    if (_lastCategoryId != currentCategoryId) {
      print(
          ' CategoryRules: Category changed from $_lastCategoryId to $currentCategoryId');
      _lastCategoryId = currentCategoryId;

      if (currentCategoryId != null && currentCategoryId.isNotEmpty) {
        setState(() {
          widget.formData.clearCategoryRulesData();
        });
        _loadCategoryRules();
      } else {
        print('🧹 CategoryRules: Clearing data (no category)');
        setState(() {
          widget.formData.clearCategoryRulesData();
        });
      }
    }

    // Rebuild when attributes change (for conditional certifications)
    if (_lastAttributeCount != currentAttributeCount) {
      _lastAttributeCount = currentAttributeCount;
      // Force rebuild to recalculate active certifications
      setState(() {});
    }
  }

  Future<void> _loadCategoryRules() async {
    if (widget.formData.selectedLevel3Id == null || !mounted) return;

    print(
        ' CategoryRules: Loading rules for category ${widget.formData.selectedLevel3Id}');

    try {
      setState(() => _isLoading = true);

      final response = await _apiService.getCategoryRulesWithSizeChart(
        widget.shopId,
        widget.formData.selectedLevel3Id!,
      );

      if (!mounted) return;

      if (response is Map<String, dynamic> &&
          response['success'] == true &&
          response['data'] != null) {
        final data = response['data'] as Map<String, dynamic>;

        // DEBUG: Print untuk melihat struktur response
        print(
            ' CategoryRules: Backend response structure: ${data.keys.toList()}');
        print(
            ' CategoryRules: Size chart data: ${data['size_chart']?.runtimeType}');

        // Gabungkan rules dengan size_chart info dari backend
        Map<String, dynamic> combinedRules = {};

        // Copy rules data jika ada
        if (data['rules'] != null && data['rules'] is Map<String, dynamic>) {
          combinedRules.addAll(data['rules'] as Map<String, dynamic>);
        }

        // Add size chart info dari backend response
        if (data['size_chart'] != null &&
            data['size_chart'] is Map<String, dynamic>) {
          combinedRules['size_chart'] = data['size_chart'];
        }

        // Add category_id for reference
        if (data['category_id'] != null) {
          combinedRules['category_id'] = data['category_id'];
        }

        print(
            ' CategoryRules: Combined rules keys: ${combinedRules.keys.toList()}');

        setState(() {
          widget.formData.updateCategoryRules(combinedRules);
        });

        print(
            ' CategoryRules: Category rules loaded: size_chart_required=${widget.formData.sizeChartRequired}');
        print(
            ' CategoryRules: Category rules loaded: size_chart_supported=${widget.formData.sizeChartSupported}');
        print(
            ' CategoryRules: Available templates: ${widget.formData.availableSizeChartTemplates.length}');

        widget.onChanged?.call();
      } else {
        throw Exception('Invalid response from server');
      }
    } catch (e) {

      // Show user-friendly error message
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Gagal memuat persyaratan kategori: ${e.toString()}'),
            backgroundColor: Colors.red,
            behavior: SnackBarBehavior.floating,
          ),
        );
      }
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    if (widget.formData.selectedLevel3Id == null) {
      return Container(
        padding: EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: Colors.grey[50],
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: Colors.grey[200]!),
        ),
        child: Row(
          children: [
            Icon(Icons.info_outline, color: Colors.grey[600], size: 20),
            SizedBox(width: 12),
            Expanded(
              child: Text(
                'Pilih kategori terlebih dahulu untuk melihat persyaratan',
                style: TextStyle(
                  color: Colors.grey[600],
                  fontWeight: FontWeight.w500,
                ),
              ),
            ),
          ],
        ),
      );
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        if (_isLoading)
          Container(
            padding: EdgeInsets.all(24),
            child: Center(
              child: Column(
                children: [
                  Container(
                    width: 32,
                    height: 32,
                    child: CircularProgressIndicator(
                      color: Color(0xFF2196F3),
                      strokeWidth: 3,
                    ),
                  ),
                  SizedBox(height: 16),
                  Text(
                    'Memuat persyaratan kategori...',
                    style: TextStyle(
                      color: Colors.grey[600],
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                ],
              ),
            ),
          )
        else if (!widget.formData.categoryRulesLoaded)
          Container(
            padding: EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: Colors.orange[50],
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: Colors.orange[200]!),
            ),
            child: Row(
              children: [
                Icon(Icons.info_outline, color: Colors.orange[600]),
                SizedBox(width: 8),
                Expanded(
                  child: Text(
                    'Gagal memuat persyaratan kategori. Beberapa field mungkin tidak tersedia.',
                    style: TextStyle(color: Colors.orange[800]),
                  ),
                ),
              ],
            ),
          )
        else
          ..._buildRulesWidgets(),
      ],
    );
  }

  List<Widget> _buildRulesWidgets() {
    List<Widget> widgets = [];

    // Size Chart Section - moved to Detail Produk section in create_product_screen.dart
    // No longer shown here

    // Certifications Section - Only show if there are certifications that apply to current selection
    if (widget.formData.certificationsRequired) {
      print('   Total certifications: ${widget.formData.requiredCertifications.length}');
      print('   Selected attributes: ${widget.formData.selectedAttributes.length}');

      // Get certifications that are actually required for current selection
      final activeCerts = widget.formData.requiredCertifications
          .where((cert) {
            final isRequired = cert.isRequiredForCurrentSelection(widget.formData.selectedAttributes);
            print('   ${cert.name}: required=$isRequired, hasConditions=${cert.requirementConditions?.length ?? 0}');
            return isRequired;
          })
          .toList();

      print('   Active certifications: ${activeCerts.length}');

      if (activeCerts.isNotEmpty) {
        widgets.add(SizedBox(height: 24));
        widgets.add(_buildCertificationsSection(activeCerts));
      }
    }

    // Package Dimensions Section
    if (widget.formData.packageDimensionsRequired) {
      widgets.add(SizedBox(height: 24));
      widgets.add(_buildPackageDimensionsSection());
    }

    // If no special requirements
    if (widgets.isEmpty) {
      widgets.add(Container(
        padding: EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: Color(0xFF2196F3).withOpacity(0.1),
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: Color(0xFF2196F3).withOpacity(0.3)),
        ),
        child: Row(
          children: [
            Icon(Icons.check_circle_outline, color: Color(0xFF2196F3)),
            SizedBox(width: 8),
            Expanded(
              child: Text(
                'Kategori ini tidak memerlukan persyaratan khusus',
                style: TextStyle(color: Color(0xFF2196F3).withOpacity(0.8)),
              ),
            ),
          ],
        ),
      ));
    }

    return widgets;
  }

  Widget _buildCertificationsSection(List<CertificationRequirement> activeCerts) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Text(
              'Sertifikasi Produk',
              style: TextStyle(
                fontSize: 14,
                fontWeight: FontWeight.w600,
                color: Colors.grey[800],
              ),
            ),
            Container(
              margin: EdgeInsets.only(left: 4),
              padding: EdgeInsets.symmetric(horizontal: 6, vertical: 2),
              decoration: BoxDecoration(
                color: Colors.red[100],
                borderRadius: BorderRadius.circular(4),
              ),
              child: Text(
                'Wajib',
                style: TextStyle(
                  color: Colors.red[700],
                  fontSize: 10,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ),
          ],
        ),
        SizedBox(height: 8),
        // Only show certifications that are actually required based on current selection
        ...activeCerts
            .map((cert) => _buildCertificationItem(cert))
            .toList(),
      ],
    );
  }

  Widget _buildCertificationItem(CertificationRequirement cert) {
    return Container(
      margin: EdgeInsets.only(bottom: 16),
      padding: EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: Colors.grey[300]!),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            cert.name,
            style: TextStyle(
              fontSize: 14,
              fontWeight: FontWeight.w600,
              color: Colors.grey[800],
            ),
          ),

          if (cert.documentDetails != null)
            Padding(
              padding: EdgeInsets.only(top: 8),
              child: Text(
                cert.documentDetails!,
                style: TextStyle(
                  fontSize: 12,
                  color: Colors.grey[600],
                ),
              ),
            ),

          SizedBox(height: 12),

          ElevatedButton.icon(
            onPressed: () => _pickCertificationFiles(cert),
            icon: Icon(Icons.file_upload, size: 16),
            label: Text('Upload Sertifikat'),
            style: ElevatedButton.styleFrom(
              backgroundColor: Color(0xFF2196F3),
              foregroundColor: Colors.white,
              padding: EdgeInsets.symmetric(horizontal: 16, vertical: 8),
            ),
          ),

          // Show selected files (simplified)
          
          Text(
            'Upload sertifikat: Belum diimplementasi',
            style: TextStyle(
              fontSize: 12,
              color: Colors.grey[600],
              fontStyle: FontStyle.italic,
            ),
          ),
        ],
      ),
    );
  }

  void _pickCertificationFiles(CertificationRequirement cert) {
    
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
          content: Text('File picker untuk sertifikat akan diimplementasi')),
    );
  }

  Widget _buildPackageDimensionsSection() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Text(
              'Dimensi Kemasan (Wajib)',
              style: TextStyle(
                fontSize: 14,
                fontWeight: FontWeight.w600,
                color: Colors.grey[800],
              ),
            ),
            Container(
              margin: EdgeInsets.only(left: 4),
              padding: EdgeInsets.symmetric(horizontal: 6, vertical: 2),
              decoration: BoxDecoration(
                color: Colors.red[100],
                borderRadius: BorderRadius.circular(4),
              ),
              child: Text(
                'Wajib',
                style: TextStyle(
                  color: Colors.red[700],
                  fontSize: 10,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ),
          ],
        ),
        SizedBox(height: 8),
        Container(
          padding: EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: Colors.orange[50],
            borderRadius: BorderRadius.circular(12),
            border: Border.all(color: Colors.orange[200]!),
          ),
          child: Row(
            children: [
              Icon(Icons.info_outline, color: Colors.orange[600]),
              SizedBox(width: 8),
              Expanded(
                child: Text(
                  'Kategori ini mewajibkan pengisian dimensi kemasan. Pastikan Anda mengisi panjang, lebar, dan tinggi kemasan pada bagian "Info Produk".',
                  style: TextStyle(color: Colors.orange[800], fontSize: 12),
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }
}
