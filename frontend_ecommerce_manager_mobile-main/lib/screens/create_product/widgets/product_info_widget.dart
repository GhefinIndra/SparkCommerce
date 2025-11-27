// lib/screens/create_product/widgets/product_info_widget.dart
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../models/product_form_data.dart';
import '../../../services/database_service.dart';

// Custom TextInputFormatter untuk price dengan separator titik
class ThousandsSeparatorInputFormatter extends TextInputFormatter {
  @override
  TextEditingValue formatEditUpdate(
    TextEditingValue oldValue,
    TextEditingValue newValue,
  ) {
    if (newValue.text.isEmpty) {
      return newValue.copyWith(text: '');
    }

    // Remove semua karakter non-digit
    String digitsOnly = newValue.text.replaceAll(RegExp(r'[^\d]'), '');

    if (digitsOnly.isEmpty) {
      return newValue.copyWith(text: '');
    }

    // Parse ke number
    int number = int.tryParse(digitsOnly) ?? 0;

    // Format dengan separator titik
    String formatted = number.toString().replaceAllMapped(
      RegExp(r'(\d)(?=(\d{3})+(?!\d))'),
      (Match m) => '${m[1]}.',
    );

    return TextEditingValue(
      text: formatted,
      selection: TextSelection.collapsed(offset: formatted.length),
    );
  }
}

class ProductInfoWidget extends StatefulWidget {
  final ProductFormData formData;
  final Function(ProductFormData) onDataChanged;
  final bool showOnlyBusinessFields;

  const ProductInfoWidget({
    Key? key,
    required this.formData,
    required this.onDataChanged,
    this.showOnlyBusinessFields = false,
  }) : super(key: key);

  @override
  _ProductInfoWidgetState createState() => _ProductInfoWidgetState();
}

class _ProductInfoWidgetState extends State<ProductInfoWidget>
    with AutomaticKeepAliveClientMixin {
  @override
  bool get wantKeepAlive => true;

  final DatabaseService _db = DatabaseService();
  
  // SKU Master data
  List<Map<String, dynamic>> availableSKUs = [];
  bool _isLoadingSKUs = false;
  String? _selectedSKU;

  // Controllers
  late TextEditingController _priceController;
  late TextEditingController _stockController;
  late TextEditingController _weightController;
  late TextEditingController _lengthController;
  late TextEditingController _widthController;
  late TextEditingController _heightController;

  // Focus nodes
  final FocusNode _priceFocusNode = FocusNode();
  final FocusNode _stockFocusNode = FocusNode();
  final FocusNode _weightFocusNode = FocusNode();
  final FocusNode _lengthFocusNode = FocusNode();
  final FocusNode _widthFocusNode = FocusNode();
  final FocusNode _heightFocusNode = FocusNode();

  @override
  void initState() {
    super.initState();
    _initControllers();
    _loadSKUs();
  }

  void _initControllers() {
    // Format price jika sudah ada value
    String initialPrice = widget.formData.price.trim().isEmpty
        ? ''
        : _formatPrice(widget.formData.price);

    _priceController = TextEditingController(text: initialPrice);
    _stockController = TextEditingController(text: widget.formData.stock);
    _weightController = TextEditingController(text: widget.formData.weight);
    _lengthController = TextEditingController(text: widget.formData.length);
    _widthController = TextEditingController(text: widget.formData.width);
    _heightController = TextEditingController(text: widget.formData.height);

    _priceController.addListener(() => _updateFieldWithDelay('price', _priceController.text));
    // Stock listener - aktif ketika SKU dikosongkan (empty_sku)
    _stockController.addListener(() {
      if (_selectedSKU == null || _selectedSKU == 'empty_sku') {
        _updateFieldWithDelay('stock', _stockController.text);
      }
    });
    _weightController.addListener(() => _updateFieldWithDelay('weight', _weightController.text));
    _lengthController.addListener(() => _updateFieldWithDelay('length', _lengthController.text));
    _widthController.addListener(() => _updateFieldWithDelay('width', _widthController.text));
    _heightController.addListener(() => _updateFieldWithDelay('height', _heightController.text));
  }

  // Format price dengan separator titik
  String _formatPrice(String price) {
    // Remove semua karakter non-digit
    String digitsOnly = price.replaceAll(RegExp(r'[^\d]'), '');
    if (digitsOnly.isEmpty) return '';

    // Convert ke number
    int number = int.tryParse(digitsOnly) ?? 0;
    if (number == 0) return '';

    // Format dengan separator titik
    String formatted = number.toString().replaceAllMapped(
      RegExp(r'(\d)(?=(\d{3})+(?!\d))'),
      (Match m) => '${m[1]}.',
    );

    return formatted;
  }

  // Parse price kembali ke angka murni untuk disimpan
  String _parsePrice(String formattedPrice) {
    return formattedPrice.replaceAll('.', '');
  }

  Future<void> _loadSKUs() async {
    setState(() => _isLoadingSKUs = true);
    
    try {
      final skus = await _db.getAllSKUs();
      setState(() {
        availableSKUs = skus;
        _isLoadingSKUs = false;
      });
    } catch (e) {
      setState(() => _isLoadingSKUs = false);
    }
  }

  void _onSKUSelected(String? sku) {
    if (sku == null) return;

    setState(() => _selectedSKU = sku);

    // Handle "Kosongkan SKU" option
    if (sku == 'empty_sku') {
      // Clear SKU data and enable manual stock input
      widget.formData.sellerSku = '';
      widget.formData.stock = '';
      _stockController.text = '';
      _stockController.clear();

      widget.onDataChanged(widget.formData);

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('SKU dikosongkan - Input stok manual'),
          backgroundColor: Colors.orange,
          behavior: SnackBarBehavior.floating,
          duration: Duration(seconds: 2),
        ),
      );
      return;
    }

    // Find SKU data
    final skuData = availableSKUs.firstWhere(
      (s) => s['sku'] == sku,
      orElse: () => {},
    );

    if (skuData.isNotEmpty) {
      // Auto-fill from SKU Master
      widget.formData.sellerSku = sku;
      widget.formData.stock = skuData['stock'].toString();
      widget.formData.price = '0'; // Price tetap manual input

      // Update controllers
      _stockController.text = skuData['stock'].toString();
      _priceController.text = '0';

      widget.onDataChanged(widget.formData);

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('SKU ${skuData['name']} dipilih - Stock: ${skuData['stock']}'),
          backgroundColor: Color(0xFF2196F3),
          behavior: SnackBarBehavior.floating,
          duration: Duration(seconds: 2),
        ),
      );
    }
  }

  void _updateFieldWithDelay(String field, String value) {
    Future.delayed(Duration(milliseconds: 100), () {
      if (mounted) _updateField(field, value);
    });
  }

  void _updateField(String field, String value) {
    switch (field) {
      case 'price':
        // Simpan angka murni tanpa separator
        widget.formData.price = _parsePrice(value.trim());
        break;
      case 'stock':
        widget.formData.stock = value.trim();
        break;
      case 'weight':
        widget.formData.weight = value.trim();
        break;
      case 'length':
        widget.formData.length = value.trim();
        break;
      case 'width':
        widget.formData.width = value.trim();
        break;
      case 'height':
        widget.formData.height = value.trim();
        break;
    }
    widget.onDataChanged(widget.formData);
  }

  void _updateBoolField(String field, bool value) {
    switch (field) {
      case 'isPreOrder':
        widget.formData.isPreOrder = value;
        break;
      case 'isCodAllowed':
        widget.formData.isCodAllowed = value;
        break;
    }
    widget.onDataChanged(widget.formData);
  }

  void _updateStringField(String field, String value) {
    switch (field) {
      case 'weightUnit':
        widget.formData.weightUnit = value;
        break;
      case 'shippingInsurance':
        widget.formData.shippingInsurance = value;
        break;
    }
    widget.onDataChanged(widget.formData);
  }

  @override
  void dispose() {
    _priceController.dispose();
    _stockController.dispose();
    _weightController.dispose();
    _lengthController.dispose();
    _widthController.dispose();
    _heightController.dispose();

    _priceFocusNode.dispose();
    _stockFocusNode.dispose();
    _weightFocusNode.dispose();
    _lengthFocusNode.dispose();
    _widthFocusNode.dispose();
    _heightFocusNode.dispose();

    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    super.build(context);

    return Column(
      children: [
        _buildSalesInfoSection(),
        SizedBox(height: 24),
        _buildShippingSection(),
      ],
    );
  }

  Widget _buildSalesInfoSection() {
    return _buildSubSection(
      title: 'Penjualan',
      icon: Icons.sell_outlined,
      children: [
        _buildPreOrderCheckbox(),
        SizedBox(height: 16),
        
        // SKU Dropdown (NEW)
        _buildSKUDropdown(),
        
        SizedBox(height: 16),
        _buildPriceStockRow(),
      ],
    );
  }

  Widget _buildSKUDropdown() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Text(
              'SKU Produk',
              style: TextStyle(
                fontSize: 14,
                fontWeight: FontWeight.w600,
                color: Color(0xFF2D3436),
              ),
            ),
            Container(
              margin: EdgeInsets.only(left: 4),
              padding: EdgeInsets.symmetric(horizontal: 6, vertical: 2),
              decoration: BoxDecoration(
                color: Colors.blue[100],
                borderRadius: BorderRadius.circular(4),
              ),
              child: Text(
                'Opsional',
                style: TextStyle(
                  color: Colors.blue[700],
                  fontSize: 10,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ),
          ],
        ),
        SizedBox(height: 8),

        if (_isLoadingSKUs)
          Container(
            padding: EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: Colors.grey[300]!),
            ),
            child: Row(
              children: [
                SizedBox(
                  width: 16,
                  height: 16,
                  child: CircularProgressIndicator(
                    strokeWidth: 2,
                    color: Color(0xFF2196F3),
                  ),
                ),
                SizedBox(width: 12),
                Text('Memuat SKU...', style: TextStyle(color: Colors.grey[600])),
              ],
            ),
          )
        else if (availableSKUs.isEmpty)
          Container(
            padding: EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: Colors.orange[50],
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: Colors.orange[200]!),
            ),
            child: Row(
              children: [
                Icon(Icons.warning, color: Colors.orange[700], size: 20),
                SizedBox(width: 12),
                Expanded(
                  child: Text(
                    'Belum ada SKU. Buat SKU di menu SKU Master terlebih dahulu.',
                    style: TextStyle(color: Colors.orange[900], fontSize: 13),
                  ),
                ),
              ],
            ),
          )
        else
          InkWell(
            onTap: () => _showSKUDialog(),
            child: Container(
              padding: EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: Colors.grey[300]!),
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withOpacity(0.03),
                    blurRadius: 6,
                    offset: Offset(0, 2),
                  ),
                ],
              ),
              child: Row(
                children: [
                  Icon(Icons.qr_code, color: _selectedSKU != null ? Color(0xFF3949AB) : Colors.grey[400]),
                  SizedBox(width: 12),
                  Expanded(
                    child: Text(
                      _getSelectedSKUText(),
                      style: TextStyle(
                        color: _selectedSKU != null ? Color(0xFF2D3436) : Colors.grey[500],
                        fontSize: 14,
                      ),
                    ),
                  ),
                  Icon(Icons.arrow_drop_down, color: Colors.grey[600]),
                ],
              ),
            ),
          ),
      ],
    );
  }

  String _getSelectedSKUText() {
    if (_selectedSKU == null) return 'Pilih SKU dari Master';
    if (_selectedSKU == 'empty_sku') return 'Kosongkan SKU (Input Manual)';

    final sku = availableSKUs.firstWhere(
      (s) => s['sku'] == _selectedSKU,
      orElse: () => {},
    );
    if (sku.isNotEmpty) {
      return '${sku['sku']} - ${sku['name']} (Stock: ${sku['stock']})';
    }
    return 'SKU dipilih';
  }

  void _showSKUDialog() {
    String? tempSelected = _selectedSKU;

    showDialog(
      context: context,
      builder: (BuildContext dialogContext) {
        return StatefulBuilder(
          builder: (context, setDialogState) {
            return Dialog(
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
              child: Container(
                constraints: BoxConstraints(maxHeight: MediaQuery.of(context).size.height * 0.7),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    // Premium Header
                    Container(
                      padding: EdgeInsets.all(20),
                      decoration: BoxDecoration(
                        gradient: LinearGradient(
                          colors: [Color(0xFF1A237E), Color(0xFF283593), Color(0xFF3949AB)],
                          begin: Alignment.topLeft,
                          end: Alignment.bottomRight,
                        ),
                        borderRadius: BorderRadius.only(
                          topLeft: Radius.circular(20),
                          topRight: Radius.circular(20),
                        ),
                      ),
                      child: Row(
                        children: [
                          Icon(Icons.qr_code, color: Colors.white, size: 24),
                          SizedBox(width: 12),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  'Pilih SKU Produk',
                                  style: TextStyle(
                                    color: Colors.white,
                                    fontSize: 18,
                                    fontWeight: FontWeight.bold,
                                  ),
                                ),
                                Text(
                                  '${availableSKUs.length + 1} opsi tersedia',
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
                    // Options List
                    Flexible(
                      child: ListView(
                        shrinkWrap: true,
                        padding: EdgeInsets.symmetric(vertical: 8),
                        children: [
                          // Empty SKU option
                          _buildSKUOption(
                            value: 'empty_sku',
                            icon: Icons.clear,
                            iconColor: Colors.orange,
                            title: 'Kosongkan SKU (Input Manual)',
                            titleColor: Colors.orange[700],
                            isSelected: tempSelected == 'empty_sku',
                            onTap: () {
                              setDialogState(() => tempSelected = 'empty_sku');
                            },
                          ),
                          Divider(height: 1),
                          // SKU Master items
                          ...availableSKUs.map((sku) {
                            final skuCode = sku['sku'];
                            final isSelected = tempSelected == skuCode;
                            return _buildSKUOption(
                              value: skuCode,
                              icon: Icons.inventory_2,
                              iconColor: Color(0xFF3949AB),
                              title: sku['name'],
                              subtitle: '${sku['sku']}  Stock: ${sku['stock']}',
                              isSelected: isSelected,
                              onTap: () {
                                setDialogState(() => tempSelected = skuCode);
                              },
                            );
                          }).toList(),
                        ],
                      ),
                    ),
                    // Footer Actions
                    Container(
                      padding: EdgeInsets.all(16),
                      decoration: BoxDecoration(
                        color: Colors.grey[50],
                        border: Border(top: BorderSide(color: Colors.grey[200]!)),
                      ),
                      child: Row(
                        mainAxisAlignment: MainAxisAlignment.end,
                        children: [
                          TextButton(
                            onPressed: () => Navigator.pop(dialogContext),
                            child: Text('Batal', style: TextStyle(color: Colors.grey[600])),
                          ),
                          SizedBox(width: 12),
                          ElevatedButton(
                            onPressed: () {
                              setState(() => _selectedSKU = tempSelected);
                              _onSKUSelected(tempSelected);
                              Navigator.pop(dialogContext);
                            },
                            style: ElevatedButton.styleFrom(
                              backgroundColor: Color(0xFF3949AB),
                              padding: EdgeInsets.symmetric(horizontal: 24, vertical: 12),
                              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                            ),
                            child: Text('Simpan', style: TextStyle(color: Colors.white)),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
            );
          },
        );
      },
    );
  }

  Widget _buildSKUOption({
    required String value,
    required IconData icon,
    required Color iconColor,
    required String title,
    String? subtitle,
    Color? titleColor,
    required bool isSelected,
    required VoidCallback onTap,
  }) {
    return InkWell(
      onTap: onTap,
      child: Container(
        padding: EdgeInsets.symmetric(horizontal: 20, vertical: 16),
        color: isSelected ? Color(0xFF3949AB).withOpacity(0.1) : Colors.transparent,
        child: Row(
          children: [
            Container(
              padding: EdgeInsets.all(8),
              decoration: BoxDecoration(
                color: iconColor.withOpacity(0.1),
                borderRadius: BorderRadius.circular(8),
              ),
              child: Icon(icon, color: iconColor, size: 20),
            ),
            SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    title,
                    style: TextStyle(
                      fontSize: 14,
                      fontWeight: isSelected ? FontWeight.w600 : FontWeight.w500,
                      color: titleColor ?? (isSelected ? Color(0xFF3949AB) : Color(0xFF2D3436)),
                    ),
                  ),
                  if (subtitle != null) ...[
                    SizedBox(height: 4),
                    Text(
                      subtitle,
                      style: TextStyle(
                        fontSize: 12,
                        color: Colors.grey[600],
                      ),
                    ),
                  ],
                ],
              ),
            ),
            if (isSelected)
              Icon(Icons.check_circle, color: Color(0xFF3949AB), size: 24),
          ],
        ),
      ),
    );
  }

  Widget _buildShippingSection() {
    return _buildSubSection(
      title: 'Pengiriman',
      icon: Icons.local_shipping_outlined,
      children: [
        _buildWeightSection(),
        SizedBox(height: 16),
        _buildDimensionSection(),
        SizedBox(height: 16),
        _buildCodSwitch(),
        SizedBox(height: 16),
        _buildShippingInsuranceSelector(),
      ],
    );
  }

  Widget _buildSubSection({
    required String title,
    required IconData icon,
    required List<Widget> children,
  }) {
    return Container(
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
              Icon(icon, size: 20, color: Color(0xFF2196F3)),
              SizedBox(width: 8),
              Text(
                title,
                style: TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.bold,
                  color: Color(0xFF2D3436),
                ),
              ),
            ],
          ),
          SizedBox(height: 16),
          ...children,
        ],
      ),
    );
  }

  Widget _buildTextField({
    required TextEditingController controller,
    required FocusNode focusNode,
    required String label,
    required String hint,
    int maxLines = 1,
    TextInputType? keyboardType,
    String? Function(String?)? validator,
    bool isRequired = false,
    Widget? suffix,
    bool readOnly = false,
  }) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Text(
              label,
              style: TextStyle(
                fontSize: 14,
                fontWeight: FontWeight.w600,
                color: Color(0xFF2D3436),
              ),
            ),
            if (isRequired)
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
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(12),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withOpacity(0.03),
                blurRadius: 6,
                offset: Offset(0, 2),
              ),
            ],
          ),
          child: TextFormField(
            controller: controller,
            focusNode: focusNode,
            maxLines: maxLines,
            keyboardType: keyboardType,
            validator: validator,
            readOnly: readOnly,
            decoration: InputDecoration(
              hintText: hint,
              hintStyle: TextStyle(color: Colors.grey[500]),
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(12),
                borderSide: BorderSide(color: Colors.grey[300]!),
              ),
              focusedBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(12),
                borderSide: BorderSide(color: Color(0xFF2196F3), width: 2),
              ),
              enabledBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(12),
                borderSide: BorderSide(color: Colors.grey[300]!),
              ),
              contentPadding: EdgeInsets.all(16),
              filled: true,
              fillColor: readOnly ? Colors.grey[100] : Colors.white,
              suffix: suffix,
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildPreOrderCheckbox() {
    return Container(
      padding: EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: Colors.grey[300]!),
      ),
      child: Row(
        children: [
          Checkbox(
            value: widget.formData.isPreOrder,
            onChanged: (value) {
              _updateBoolField('isPreOrder', value ?? false);
            },
            activeColor: Color(0xFF2196F3),
          ),
          SizedBox(width: 8),
          Icon(Icons.schedule, size: 16, color: Colors.grey[600]),
          SizedBox(width: 8),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Pre-order',
                  style: TextStyle(
                    fontSize: 14,
                    fontWeight: FontWeight.w600,
                    color: Color(0xFF2D3436),
                  ),
                ),
                Text(
                  'Produk akan disiapkan setelah pesanan',
                  style: TextStyle(
                    fontSize: 12,
                    color: Colors.grey[600],
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildPriceStockRow() {
    return Row(
      children: [
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Text(
                    'Harga',
                    style: TextStyle(
                      fontSize: 14,
                      fontWeight: FontWeight.w600,
                      color: Color(0xFF2D3436),
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
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(12),
                  boxShadow: [
                    BoxShadow(
                      color: Colors.black.withOpacity(0.03),
                      blurRadius: 6,
                      offset: Offset(0, 2),
                    ),
                  ],
                ),
                child: TextFormField(
                  controller: _priceController,
                  focusNode: _priceFocusNode,
                  keyboardType: TextInputType.number,
                  inputFormatters: [
                    FilteringTextInputFormatter.digitsOnly,
                    ThousandsSeparatorInputFormatter(), // Auto-format dengan separator titik
                  ],
                  decoration: InputDecoration(
                    hintText: 'Contoh: 50.000',
                    hintStyle: TextStyle(color: Colors.grey[500]),
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(12),
                      borderSide: BorderSide(color: Colors.grey[300]!),
                    ),
                    focusedBorder: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(12),
                      borderSide: BorderSide(color: Color(0xFF2196F3), width: 2),
                    ),
                    enabledBorder: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(12),
                      borderSide: BorderSide(color: Colors.grey[300]!),
                    ),
                    contentPadding: EdgeInsets.all(16),
                    filled: true,
                    fillColor: Colors.white,
                    prefixText: 'Rp ',
                    prefixStyle: TextStyle(
                      color: Color(0xFF2D3436),
                      fontWeight: FontWeight.w600,
                      fontSize: 16,
                    ),
                  ),
                  validator: (value) {
                    if (value == null || value.trim().isEmpty) {
                      return 'Harga wajib diisi';
                    }
                    // Validate angka murni (tanpa separator)
                    final cleanValue = value.replaceAll('.', '');
                    if (int.tryParse(cleanValue) == null) {
                      return 'Harga harus berupa angka';
                    }
                    return null;
                  },
                ),
              ),
            ],
          ),
        ),
        SizedBox(width: 16),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Text(
                    'Stok',
                    style: TextStyle(
                      fontSize: 14,
                      fontWeight: FontWeight.w600,
                      color: Color(0xFF2D3436),
                    ),
                  ),
                  if (_selectedSKU == 'empty_sku')
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
                decoration: BoxDecoration(
                  color: _selectedSKU == null ? Colors.grey[100] : Colors.white,
                  borderRadius: BorderRadius.circular(12),
                  boxShadow: _selectedSKU != null
                      ? [
                          BoxShadow(
                            color: Colors.black.withOpacity(0.03),
                            blurRadius: 6,
                            offset: Offset(0, 2),
                          ),
                        ]
                      : [],
                ),
                child: TextFormField(
                  controller: _stockController,
                  focusNode: _stockFocusNode,
                  keyboardType: TextInputType.number,
                  
                  enabled: _selectedSKU != null,
                  // ReadOnly jika pilih dari SKU Master (bukan empty_sku)
                  readOnly: _selectedSKU != null && _selectedSKU != 'empty_sku',
                  decoration: InputDecoration(
                    hintText: _selectedSKU == null
                        ? 'Pilih SKU terlebih dahulu'
                        : (_selectedSKU == 'empty_sku' ? 'Input manual' : 'Auto dari SKU'),
                    hintStyle: TextStyle(
                      color: _selectedSKU == null ? Colors.orange[700] : Colors.grey[500],
                      fontSize: 13,
                    ),
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(12),
                      borderSide: BorderSide(color: Colors.grey[300]!),
                    ),
                    focusedBorder: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(12),
                      borderSide: BorderSide(color: Color(0xFF2196F3), width: 2),
                    ),
                    enabledBorder: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(12),
                      borderSide: BorderSide(color: Colors.grey[300]!),
                    ),
                    disabledBorder: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(12),
                      borderSide: BorderSide(color: Colors.orange[200]!),
                    ),
                    contentPadding: EdgeInsets.all(16),
                    filled: true,
                    fillColor: _selectedSKU == null
                        ? Colors.grey[100]
                        : (_selectedSKU != 'empty_sku' ? Colors.grey[50] : Colors.white),
                    suffix: Text('pcs', style: TextStyle(color: Colors.grey[600])),
                    // Info icon untuk user
                    prefixIcon: _selectedSKU == null
                        ? Icon(Icons.lock_outline, color: Colors.orange[700], size: 20)
                        : null,
                  ),
                  validator: (value) {
                    // Jika stock kosong
                    if (value == null || value.trim().isEmpty) {
                      // Jika user pilih "Kosongkan SKU", wajib input manual
                      if (_selectedSKU == 'empty_sku') {
                        return 'Stok wajib diisi';
                      }
                      // Jika user belum pilih SKU atau pilih SKU dari master, boleh kosong
                      return null;
                    }

                    // Jika ada value, harus angka
                    if (int.tryParse(value.trim()) == null)
                      return 'Stok harus berupa angka';

                    return null;
                  },
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }

  // ... (sisanya sama dengan kode sebelumnya: weight, dimension, COD, insurance)
  // Copy paste dari code sebelumnya untuk _buildWeightSection, _buildDimensionSection, 
  // _buildCodSwitch, _buildShippingInsuranceSelector
  
  Widget _buildWeightSection() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Text(
              'Berat',
              style: TextStyle(
                fontSize: 14,
                fontWeight: FontWeight.w600,
                color: Color(0xFF2D3436),
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
        Row(
          children: [
            Expanded(
              flex: 2,
              child: Container(
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(12),
                  boxShadow: [
                    BoxShadow(
                      color: Colors.black.withOpacity(0.03),
                      blurRadius: 6,
                      offset: Offset(0, 2),
                    ),
                  ],
                ),
                child: TextFormField(
                  controller: _weightController,
                  focusNode: _weightFocusNode,
                  keyboardType: TextInputType.numberWithOptions(decimal: true),
                  validator: (value) {
                    if (value == null || value.trim().isEmpty)
                      return 'Berat wajib diisi';
                    if (double.tryParse(value.trim()) == null)
                      return 'Berat harus berupa angka';
                    return null;
                  },
                  decoration: InputDecoration(
                    hintText: 'Contoh: 0.5',
                    hintStyle: TextStyle(color: Colors.grey[500]),
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(12),
                      borderSide: BorderSide(color: Colors.grey[300]!),
                    ),
                    focusedBorder: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(12),
                      borderSide: BorderSide(color: Color(0xFF2196F3), width: 2),
                    ),
                    enabledBorder: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(12),
                      borderSide: BorderSide(color: Colors.grey[300]!),
                    ),
                    contentPadding: EdgeInsets.all(16),
                    filled: true,
                    fillColor: Colors.white,
                  ),
                ),
              ),
            ),
            SizedBox(width: 12),
            Expanded(
              child: InkWell(
                onTap: () => _showWeightUnitDialog(),
                child: Container(
                  padding: EdgeInsets.all(16),
                  decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(color: Colors.grey[300]!),
                    boxShadow: [
                      BoxShadow(
                        color: Colors.black.withOpacity(0.03),
                        blurRadius: 6,
                        offset: Offset(0, 2),
                      ),
                    ],
                  ),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Text(
                        widget.formData.weightUnit,
                        style: TextStyle(
                          color: Color(0xFF2D3436),
                          fontSize: 14,
                          fontWeight: FontWeight.w500,
                        ),
                      ),
                      Icon(Icons.arrow_drop_down, color: Colors.grey[600]),
                    ],
                  ),
                ),
              ),
            ),
          ],
        ),
      ],
    );
  }

  Widget _buildDimensionSection() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Text(
              'Dimensi Paket (cm)',
              style: TextStyle(
                fontSize: 14,
                fontWeight: FontWeight.w600,
                color: Color(0xFF2D3436),
              ),
            ),
            if (widget.formData.packageDimensionsRequired)
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
            color: Colors.white,
            borderRadius: BorderRadius.circular(12),
            border: Border.all(color: Colors.grey[300]!),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withOpacity(0.03),
                blurRadius: 6,
                offset: Offset(0, 2),
              ),
            ],
          ),
          child: Row(
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Icon(Icons.straighten,
                            size: 14, color: Colors.grey[600]),
                        SizedBox(width: 4),
                        Text('Panjang',
                            style: TextStyle(
                                fontSize: 12, color: Colors.grey[600])),
                      ],
                    ),
                    SizedBox(height: 4),
                    TextFormField(
                      controller: _lengthController,
                      focusNode: _lengthFocusNode,
                      keyboardType: TextInputType.number,
                      validator: widget.formData.packageDimensionsRequired
                          ? (value) {
                              if (value == null || value.trim().isEmpty)
                                return 'Wajib';
                              if (double.tryParse(value.trim()) == null)
                                return 'Angka';
                              return null;
                            }
                          : null,
                      decoration: InputDecoration(
                        hintText: '10',
                        hintStyle: TextStyle(color: Colors.grey[400]),
                        border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(6),
                          borderSide: BorderSide(color: Colors.grey[300]!),
                        ),
                        focusedBorder: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(6),
                          borderSide:
                              BorderSide(color: Color(0xFF2196F3), width: 2),
                        ),
                        contentPadding: EdgeInsets.all(12),
                        isDense: true,
                      ),
                    ),
                  ],
                ),
              ),
              SizedBox(width: 8),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Icon(Icons.straighten,
                            size: 14, color: Colors.grey[600]),
                        SizedBox(width: 4),
                        Text('Lebar',
                            style: TextStyle(
                                fontSize: 12, color: Colors.grey[600])),
                      ],
                    ),
                    SizedBox(height: 4),
                    TextFormField(
                      controller: _widthController,
                      focusNode: _widthFocusNode,
                      keyboardType: TextInputType.number,
                      validator: widget.formData.packageDimensionsRequired
                          ? (value) {
                              if (value == null || value.trim().isEmpty)
                                return 'Wajib';
                              if (double.tryParse(value.trim()) == null)
                                return 'Angka';
                              return null;
                            }
                          : null,
                      decoration: InputDecoration(
                        hintText: '10',
                        hintStyle: TextStyle(color: Colors.grey[400]),
                        border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(6),
                          borderSide: BorderSide(color: Colors.grey[300]!),
                        ),
                        focusedBorder: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(6),
                          borderSide:
                              BorderSide(color: Color(0xFF2196F3), width: 2),
                        ),
                        contentPadding: EdgeInsets.all(12),
                        isDense: true,
                      ),
                    ),
                  ],
                ),
              ),
              SizedBox(width: 8),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Icon(Icons.straighten,
                            size: 14, color: Colors.grey[600]),
                        SizedBox(width: 4),
                        Text('Tinggi',
                            style: TextStyle(
                                fontSize: 12, color: Colors.grey[600])),
                      ],
                    ),
                    SizedBox(height: 4),
                    TextFormField(
                      controller: _heightController,
                      focusNode: _heightFocusNode,
                      keyboardType: TextInputType.number,
                      validator: widget.formData.packageDimensionsRequired
                          ? (value) {
                              if (value == null || value.trim().isEmpty)
                                return 'Wajib';
                              if (double.tryParse(value.trim()) == null)
                                return 'Angka';
                              return null;
                            }
                          : null,
                      decoration: InputDecoration(
                        hintText: '10',
                        hintStyle: TextStyle(color: Colors.grey[400]),
                        border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(6),
                          borderSide: BorderSide(color: Colors.grey[300]!),
                        ),
                        focusedBorder: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(6),
                          borderSide:
                              BorderSide(color: Color(0xFF2196F3), width: 2),
                        ),
                        contentPadding: EdgeInsets.all(12),
                        isDense: true,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildCodSwitch() {
    return Container(
      padding: EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: Colors.grey[300]!),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.03),
            blurRadius: 6,
            offset: Offset(0, 2),
          ),
        ],
      ),
      child: Row(
        children: [
          Icon(Icons.payment, size: 20, color: Colors.grey[600]),
          SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Bayar di Tempat (COD)',
                  style: TextStyle(
                    fontSize: 14,
                    fontWeight: FontWeight.w600,
                    color: Color(0xFF2D3436),
                  ),
                ),
                Text(
                  'Pelanggan dapat bayar saat produk diterima',
                  style: TextStyle(
                    fontSize: 12,
                    color: Colors.grey[600],
                  ),
                ),
              ],
            ),
          ),
          Switch(
            value: widget.formData.isCodAllowed,
            onChanged: (value) {
              setState(() {
                _updateBoolField('isCodAllowed', value);
              });
            },
            activeColor: Color(0xFF2196F3),
            materialTapTargetSize: MaterialTapTargetSize.shrinkWrap,
          ),
        ],
      ),
    );
  }

  Widget _buildShippingInsuranceSelector() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'Asuransi Pengiriman',
          style: TextStyle(
            fontSize: 14,
            fontWeight: FontWeight.w600,
            color: Color(0xFF2D3436),
          ),
        ),
        SizedBox(height: 8),
        InkWell(
          onTap: () => _showShippingInsuranceDialog(),
          child: Container(
            padding: EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: Colors.grey[300]!),
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withOpacity(0.03),
                  blurRadius: 6,
                  offset: Offset(0, 2),
                ),
              ],
            ),
            child: Row(
              children: [
                Icon(
                  _getInsuranceIcon(widget.formData.shippingInsurance),
                  color: _getInsuranceColor(widget.formData.shippingInsurance),
                  size: 20,
                ),
                SizedBox(width: 12),
                Expanded(
                  child: Text(
                    _getInsuranceText(widget.formData.shippingInsurance),
                    style: TextStyle(
                      color: Color(0xFF2D3436),
                      fontSize: 14,
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                ),
                Icon(Icons.arrow_drop_down, color: Colors.grey[600]),
              ],
            ),
          ),
        ),
      ],
    );
  }

  IconData _getInsuranceIcon(String value) {
    switch (value) {
      case 'REQUIRED':
        return Icons.security;
      case 'NOT_SUPPORTED':
        return Icons.block;
      default:
        return Icons.check_circle_outline;
    }
  }

  Color _getInsuranceColor(String value) {
    switch (value) {
      case 'NOT_SUPPORTED':
        return Colors.red;
      default:
        return Color(0xFF3949AB);
    }
  }

  String _getInsuranceText(String value) {
    switch (value) {
      case 'REQUIRED':
        return 'Wajib';
      case 'NOT_SUPPORTED':
        return 'Tidak Didukung';
      default:
        return 'Opsional';
    }
  }

  void _showWeightUnitDialog() {
    String? tempSelected = widget.formData.weightUnit;

    showDialog(
      context: context,
      builder: (BuildContext dialogContext) {
        return StatefulBuilder(
          builder: (context, setDialogState) {
            return Dialog(
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
              child: Container(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    // Premium Header
                    Container(
                      padding: EdgeInsets.all(20),
                      decoration: BoxDecoration(
                        gradient: LinearGradient(
                          colors: [Color(0xFF1A237E), Color(0xFF283593), Color(0xFF3949AB)],
                          begin: Alignment.topLeft,
                          end: Alignment.bottomRight,
                        ),
                        borderRadius: BorderRadius.only(
                          topLeft: Radius.circular(20),
                          topRight: Radius.circular(20),
                        ),
                      ),
                      child: Row(
                        children: [
                          Icon(Icons.monitor_weight, color: Colors.white, size: 24),
                          SizedBox(width: 12),
                          Expanded(
                            child: Text(
                              'Pilih Satuan Berat',
                              style: TextStyle(
                                color: Colors.white,
                                fontSize: 18,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                    // Options List
                    ...['Gram', 'Kg'].map((unit) {
                      final isSelected = tempSelected == unit;
                      return InkWell(
                        onTap: () {
                          setDialogState(() => tempSelected = unit);
                        },
                        child: Container(
                          padding: EdgeInsets.symmetric(horizontal: 20, vertical: 16),
                          color: isSelected ? Color(0xFF3949AB).withOpacity(0.1) : Colors.transparent,
                          child: Row(
                            children: [
                              Container(
                                padding: EdgeInsets.all(8),
                                decoration: BoxDecoration(
                                  color: Color(0xFF3949AB).withOpacity(0.1),
                                  borderRadius: BorderRadius.circular(8),
                                ),
                                child: Icon(Icons.scale, color: Color(0xFF3949AB), size: 20),
                              ),
                              SizedBox(width: 12),
                              Expanded(
                                child: Text(
                                  unit,
                                  style: TextStyle(
                                    fontSize: 14,
                                    fontWeight: isSelected ? FontWeight.w600 : FontWeight.w500,
                                    color: isSelected ? Color(0xFF3949AB) : Color(0xFF2D3436),
                                  ),
                                ),
                              ),
                              if (isSelected)
                                Icon(Icons.check_circle, color: Color(0xFF3949AB), size: 24),
                            ],
                          ),
                        ),
                      );
                    }).toList(),
                    // Footer Actions
                    Container(
                      padding: EdgeInsets.all(16),
                      decoration: BoxDecoration(
                        color: Colors.grey[50],
                        border: Border(top: BorderSide(color: Colors.grey[200]!)),
                      ),
                      child: Row(
                        mainAxisAlignment: MainAxisAlignment.end,
                        children: [
                          TextButton(
                            onPressed: () => Navigator.pop(dialogContext),
                            child: Text('Batal', style: TextStyle(color: Colors.grey[600])),
                          ),
                          SizedBox(width: 12),
                          ElevatedButton(
                            onPressed: () {
                              setState(() {
                                _updateStringField('weightUnit', tempSelected ?? 'Gram');
                              });
                              Navigator.pop(dialogContext);
                            },
                            style: ElevatedButton.styleFrom(
                              backgroundColor: Color(0xFF3949AB),
                              padding: EdgeInsets.symmetric(horizontal: 24, vertical: 12),
                              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                            ),
                            child: Text('Simpan', style: TextStyle(color: Colors.white)),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
            );
          },
        );
      },
    );
  }

  void _showShippingInsuranceDialog() {
    String? tempSelected = widget.formData.shippingInsurance;

    final options = [
      {'value': 'OPTIONAL', 'label': 'Opsional', 'icon': Icons.check_circle_outline, 'color': Color(0xFF3949AB)},
      {'value': 'REQUIRED', 'label': 'Wajib', 'icon': Icons.security, 'color': Color(0xFF3949AB)},
      {'value': 'NOT_SUPPORTED', 'label': 'Tidak Didukung', 'icon': Icons.block, 'color': Colors.red},
    ];

    showDialog(
      context: context,
      builder: (BuildContext dialogContext) {
        return StatefulBuilder(
          builder: (context, setDialogState) {
            return Dialog(
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
              child: Container(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    // Premium Header
                    Container(
                      padding: EdgeInsets.all(20),
                      decoration: BoxDecoration(
                        gradient: LinearGradient(
                          colors: [Color(0xFF1A237E), Color(0xFF283593), Color(0xFF3949AB)],
                          begin: Alignment.topLeft,
                          end: Alignment.bottomRight,
                        ),
                        borderRadius: BorderRadius.only(
                          topLeft: Radius.circular(20),
                          topRight: Radius.circular(20),
                        ),
                      ),
                      child: Row(
                        children: [
                          Icon(Icons.local_shipping, color: Colors.white, size: 24),
                          SizedBox(width: 12),
                          Expanded(
                            child: Text(
                              'Asuransi Pengiriman',
                              style: TextStyle(
                                color: Colors.white,
                                fontSize: 18,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                    // Options List
                    ...options.map((option) {
                      final isSelected = tempSelected == option['value'];
                      return InkWell(
                        onTap: () {
                          setDialogState(() => tempSelected = option['value'] as String);
                        },
                        child: Container(
                          padding: EdgeInsets.symmetric(horizontal: 20, vertical: 16),
                          color: isSelected ? Color(0xFF3949AB).withOpacity(0.1) : Colors.transparent,
                          child: Row(
                            children: [
                              Container(
                                padding: EdgeInsets.all(8),
                                decoration: BoxDecoration(
                                  color: (option['color'] as Color).withOpacity(0.1),
                                  borderRadius: BorderRadius.circular(8),
                                ),
                                child: Icon(option['icon'] as IconData, color: option['color'] as Color, size: 20),
                              ),
                              SizedBox(width: 12),
                              Expanded(
                                child: Text(
                                  option['label'] as String,
                                  style: TextStyle(
                                    fontSize: 14,
                                    fontWeight: isSelected ? FontWeight.w600 : FontWeight.w500,
                                    color: isSelected ? Color(0xFF3949AB) : Color(0xFF2D3436),
                                  ),
                                ),
                              ),
                              if (isSelected)
                                Icon(Icons.check_circle, color: Color(0xFF3949AB), size: 24),
                            ],
                          ),
                        ),
                      );
                    }).toList(),
                    // Footer Actions
                    Container(
                      padding: EdgeInsets.all(16),
                      decoration: BoxDecoration(
                        color: Colors.grey[50],
                        border: Border(top: BorderSide(color: Colors.grey[200]!)),
                      ),
                      child: Row(
                        mainAxisAlignment: MainAxisAlignment.end,
                        children: [
                          TextButton(
                            onPressed: () => Navigator.pop(dialogContext),
                            child: Text('Batal', style: TextStyle(color: Colors.grey[600])),
                          ),
                          SizedBox(width: 12),
                          ElevatedButton(
                            onPressed: () {
                              setState(() {
                                _updateStringField('shippingInsurance', tempSelected ?? 'OPTIONAL');
                              });
                              Navigator.pop(dialogContext);
                            },
                            style: ElevatedButton.styleFrom(
                              backgroundColor: Color(0xFF3949AB),
                              padding: EdgeInsets.symmetric(horizontal: 24, vertical: 12),
                              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                            ),
                            child: Text('Simpan', style: TextStyle(color: Colors.white)),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
            );
          },
        );
      },
    );
  }
}
