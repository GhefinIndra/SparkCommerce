// lib/screens/sku_master_screen.dart
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../services/database_service.dart';
import '../services/sku_sync_service.dart';

class SKUMasterScreen extends StatefulWidget {
  const SKUMasterScreen({Key? key}) : super(key: key);

  @override
  _SKUMasterScreenState createState() => _SKUMasterScreenState();
}

class _SKUMasterScreenState extends State<SKUMasterScreen>
    with SingleTickerProviderStateMixin {
  final DatabaseService _db = DatabaseService();
  final SKUSyncService _syncService = SKUSyncService();
  List<Map<String, dynamic>> skuList = [];
  Map<String, List<Map<String, dynamic>>> skuMappings = {};
  bool _isLoading = true;
  final Set<String> _syncingSkus = {};
  late AnimationController _animationController;
  late Animation<double> _fadeAnimation;
  late Animation<Offset> _slideAnimation;
  bool _isAnimationInitialized = false;

  @override
  void initState() {
    super.initState();
    _initializeAnimation();
    _loadSKUs();
  }

  void _initializeAnimation() {
    _animationController = AnimationController(
      duration: Duration(milliseconds: 800),
      vsync: this,
    );
    _fadeAnimation = Tween<double>(begin: 0.0, end: 1.0).animate(
      CurvedAnimation(parent: _animationController, curve: Curves.easeOut),
    );
    _slideAnimation = Tween<Offset>(
      begin: Offset(0, 0.3),
      end: Offset.zero,
    ).animate(
        CurvedAnimation(parent: _animationController, curve: Curves.easeOut));
    _isAnimationInitialized = true;
  }

  @override
  void dispose() {
    _animationController.dispose();
    super.dispose();
  }

  Future<void> _loadSKUs() async {
    setState(() => _isLoading = true);

    try {
      final data = await _db.getAllSKUs();

      for (var sku in data) {
        final mappings = await _db.getMappingsBySKU(sku['sku']);
        print(' SKU: ${sku['sku']} has ${mappings.length} mappings');
        for (var mapping in mappings) {
          print('   - ${mapping['marketplace']} (Product: ${mapping['product_id']}, Variation: ${mapping['variation_id']})');
        }
        skuMappings[sku['sku']] = mappings;
      }

      setState(() {
        skuList = data;
        _isLoading = false;
      });
      
      // Start animation after data is loaded
      if (_isAnimationInitialized && mounted) {
        _animationController.reset();
        _animationController.forward();
      }
    } catch (e) {
      setState(() => _isLoading = false);
      _showSnackBar('Gagal memuat data: ${e.toString()}', Colors.red[400]!);
    }
  }

  Future<void> _syncStock(Map<String, dynamic> sku) async {
    final skuCode = sku['sku'];
    setState(() => _syncingSkus.add(skuCode));

    try {
      final result = await _syncService.syncStockToMarketplace(
        sku: skuCode,
        stock: sku['stock'],
      );

      if (result['success']) {
        _showSnackBar(result['message'], Colors.green[600]!);
        await _loadSKUs();
      } else {
        _showSnackBar(result['message'], Colors.red[400]!);
      }
    } catch (e) {
      _showSnackBar('Error: ${e.toString()}', Colors.red[400]!);
    } finally {
      setState(() => _syncingSkus.remove(skuCode));
    }
  }

  void _showAddSKUDialog() {
    final skuController = TextEditingController();
    final nameController = TextEditingController();
    final stockController = TextEditingController();

    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        title: Row(
          children: [
            Container(
              padding: EdgeInsets.all(10),
              decoration: BoxDecoration(
                color: Color(0xFF2196F3).withOpacity(0.1),
                borderRadius: BorderRadius.circular(12),
              ),
              child: Icon(Icons.add_rounded, color: Color(0xFF2196F3), size: 22),
            ),
            SizedBox(width: 12),
            Text(
              'Tambah SKU',
              style: TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.w700,
                color: Color(0xFF1A237E),
              ),
            ),
          ],
        ),
        content: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              _buildDialogTextField(
                controller: skuController,
                label: 'SKU',
                hint: 'Contoh: SKU001',
                icon: Icons.qr_code_rounded,
                textCapitalization: TextCapitalization.characters,
              ),
              SizedBox(height: 16),
              _buildDialogTextField(
                controller: nameController,
                label: 'Nama Produk',
                hint: 'Contoh: Baju Merah',
                icon: Icons.label_outline,
              ),
              SizedBox(height: 16),
              _buildDialogTextField(
                controller: stockController,
                label: 'Stok',
                hint: 'Contoh: 100',
                icon: Icons.inventory_2_outlined,
                keyboardType: TextInputType.number,
              ),
            ],
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: Text(
              'Batal',
              style: TextStyle(
                color: Colors.grey[600],
                fontWeight: FontWeight.w600,
              ),
            ),
          ),
          ElevatedButton(
            onPressed: () async {
              if (skuController.text.isEmpty ||
                  nameController.text.isEmpty ||
                  stockController.text.isEmpty) {
                _showSnackBar('Semua field harus diisi', Colors.red[400]!);
                return;
              }

              try {
                await _db.insertSKU(
                  sku: skuController.text.toUpperCase(),
                  name: nameController.text,
                  stock: int.parse(stockController.text),
                );

                Navigator.pop(context);
                _loadSKUs();
                _showSnackBar('SKU berhasil ditambahkan', Colors.green[600]!);
              } catch (e) {
                _showSnackBar(
                    'Gagal menambahkan SKU: ${e.toString()}', Colors.red[400]!);
              }
            },
            style: ElevatedButton.styleFrom(
              backgroundColor: Color(0xFF2196F3),
              foregroundColor: Colors.white,
              padding: EdgeInsets.symmetric(horizontal: 24, vertical: 12),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(12),
              ),
              elevation: 0,
            ),
            child: Text(
              'Simpan',
              style: TextStyle(fontWeight: FontWeight.w600),
            ),
          ),
        ],
      ),
    );
  }

  void _showEditSKUDialog(Map<String, dynamic> sku) {
    final nameController = TextEditingController(text: sku['name']);
    final stockController =
        TextEditingController(text: sku['stock'].toString());

    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        title: Row(
          children: [
            Container(
              padding: EdgeInsets.all(10),
              decoration: BoxDecoration(
                color: Color(0xFF2196F3).withOpacity(0.1),
                borderRadius: BorderRadius.circular(12),
              ),
              child:
                  Icon(Icons.edit_outlined, color: Color(0xFF2196F3), size: 22),
            ),
            SizedBox(width: 12),
            Text(
              'Edit SKU',
              style: TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.w700,
                color: Color(0xFF1A237E),
              ),
            ),
          ],
        ),
        content: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Container(
                padding: EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: Color(0xFF2196F3).withOpacity(0.08),
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(
                    color: Color(0xFF2196F3).withOpacity(0.2),
                    width: 1,
                  ),
                ),
                child: Row(
                  children: [
                    Icon(Icons.qr_code_rounded,
                        size: 20, color: Color(0xFF2196F3)),
                    SizedBox(width: 10),
                    Text(
                      sku['sku'],
                      style: TextStyle(
                        fontWeight: FontWeight.bold,
                        fontSize: 16,
                        color: Color(0xFF1A237E),
                      ),
                    ),
                  ],
                ),
              ),
              SizedBox(height: 20),
              _buildDialogTextField(
                controller: nameController,
                label: 'Nama Produk',
                hint: 'Nama produk',
                icon: Icons.label_outline,
              ),
              SizedBox(height: 16),
              _buildDialogTextField(
                controller: stockController,
                label: 'Stok',
                hint: 'Jumlah stok',
                icon: Icons.inventory_2_outlined,
                keyboardType: TextInputType.number,
              ),
            ],
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: Text(
              'Batal',
              style: TextStyle(
                color: Colors.grey[600],
                fontWeight: FontWeight.w600,
              ),
            ),
          ),
          ElevatedButton(
            onPressed: () async {
              try {
                await _db.insertSKU(
                  sku: sku['sku'],
                  name: nameController.text,
                  stock: int.parse(stockController.text),
                );

                Navigator.pop(context);
                _loadSKUs();
                _showSnackBar('SKU berhasil diupdate', Colors.green[600]!);
              } catch (e) {
                _showSnackBar('Gagal update SKU: ${e.toString()}', Colors.red[400]!);
              }
            },
            style: ElevatedButton.styleFrom(
              backgroundColor: Color(0xFF2196F3),
              foregroundColor: Colors.white,
              padding: EdgeInsets.symmetric(horizontal: 24, vertical: 12),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(12),
              ),
              elevation: 0,
            ),
            child: Text(
              'Update',
              style: TextStyle(fontWeight: FontWeight.w600),
            ),
          ),
        ],
      ),
    );
  }

  void _showDeleteConfirmation(String sku) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        title: Row(
          children: [
            Container(
              padding: EdgeInsets.all(10),
              decoration: BoxDecoration(
                color: Colors.red.withOpacity(0.1),
                borderRadius: BorderRadius.circular(12),
              ),
              child: Icon(Icons.warning_rounded, color: Colors.red[400], size: 22),
            ),
            SizedBox(width: 12),
            Text(
              'Hapus SKU',
              style: TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.w700,
                color: Color(0xFF1A237E),
              ),
            ),
          ],
        ),
        content: Text(
          'Apakah Anda yakin ingin menghapus SKU "$sku"? Tindakan ini tidak dapat dibatalkan.',
          style: TextStyle(
            fontSize: 15,
            color: Colors.grey[700],
            height: 1.5,
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: Text(
              'Batal',
              style: TextStyle(
                color: Colors.grey[600],
                fontWeight: FontWeight.w600,
              ),
            ),
          ),
          ElevatedButton(
            onPressed: () async {
              try {
                await _db.deleteSKU(sku);
                Navigator.pop(context);
                _loadSKUs();
                _showSnackBar('SKU berhasil dihapus', Colors.green[600]!);
              } catch (e) {
                _showSnackBar('Gagal hapus SKU: ${e.toString()}', Colors.red[400]!);
              }
            },
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.red[400],
              foregroundColor: Colors.white,
              padding: EdgeInsets.symmetric(horizontal: 24, vertical: 12),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(12),
              ),
              elevation: 0,
            ),
            child: Text(
              'Hapus',
              style: TextStyle(fontWeight: FontWeight.w600),
            ),
          ),
        ],
      ),
    );
  }

  void _showSnackBar(String message, Color backgroundColor) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Row(
          children: [
            Icon(
              backgroundColor == Colors.green[600]
                  ? Icons.check_circle
                  : Icons.error_outline,
              color: Colors.white,
              size: 20,
            ),
            SizedBox(width: 12),
            Expanded(
              child: Text(
                message,
                style: TextStyle(fontWeight: FontWeight.w500),
              ),
            ),
          ],
        ),
        backgroundColor: backgroundColor,
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
        margin: EdgeInsets.all(16),
        elevation: 3,
      ),
    );
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
          child: SafeArea(
            child: Column(
              children: [
                _buildHeader(),
                Expanded(
                  child: Container(
                    decoration: BoxDecoration(
                      color: Color(0xFFF5F7FA),
                      borderRadius: BorderRadius.only(
                        topLeft: Radius.circular(30),
                        topRight: Radius.circular(30),
                      ),
                    ),
                    child: _buildBody(),
                  ),
                ),
              ],
            ),
          ),
        ),
        floatingActionButton: FloatingActionButton.extended(
          onPressed: _showAddSKUDialog,
          backgroundColor: Color(0xFF1A237E),
          foregroundColor: Colors.white,
          icon: Icon(Icons.add_rounded, size: 24),
          label: Text(
            'Tambah SKU',
            style: TextStyle(
              fontWeight: FontWeight.w600,
              fontSize: 15,
              letterSpacing: 0.2,
              color: Colors.white,
            ),
          ),
          elevation: 4,
        ),
      ),
    );
  }

  Widget _buildHeader() {
    return Container(
      padding: EdgeInsets.fromLTRB(24, 16, 24, 24),
      child: Column(
        children: [
          Row(
            children: [
              Container(
                decoration: BoxDecoration(
                  color: Colors.white.withOpacity(0.15),
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(
                    color: Colors.white.withOpacity(0.2),
                    width: 1,
                  ),
                ),
                child: IconButton(
                  onPressed: () => Navigator.pop(context),
                  icon: Icon(
                    Icons.arrow_back_ios_new_rounded,
                    color: Colors.white,
                    size: 20,
                  ),
                ),
              ),
              Expanded(
                child: Text(
                  'SKU Master',
                  textAlign: TextAlign.center,
                  style: TextStyle(
                    color: Colors.white,
                    fontSize: 20,
                    fontWeight: FontWeight.w600,
                    letterSpacing: 0.3,
                  ),
                ),
              ),
              SizedBox(width: 56),
            ],
          ),
          SizedBox(height: 20),
          Container(
            padding: EdgeInsets.symmetric(horizontal: 20, vertical: 14),
            decoration: BoxDecoration(
              color: Colors.white.withOpacity(0.15),
              borderRadius: BorderRadius.circular(16),
              border: Border.all(
                color: Colors.white.withOpacity(0.2),
                width: 1,
              ),
            ),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceAround,
              children: [
                _buildStatItem(
                  icon: Icons.inventory_2_outlined,
                  label: 'Total SKU',
                  value: '${skuList.length}',
                ),
                Container(
                  width: 1,
                  height: 30,
                  color: Colors.white.withOpacity(0.3),
                ),
                _buildStatItem(
                  icon: Icons.sync_rounded,
                  label: 'Syncing',
                  value: '${_syncingSkus.length}',
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildStatItem({
    required IconData icon,
    required String label,
    required String value,
  }) {
    return Column(
      children: [
        Icon(icon, color: Colors.white, size: 24),
        SizedBox(height: 6),
        Text(
          value,
          style: TextStyle(
            color: Colors.white,
            fontSize: 20,
            fontWeight: FontWeight.bold,
          ),
        ),
        Text(
          label,
          style: TextStyle(
            color: Colors.white.withOpacity(0.9),
            fontSize: 12,
            fontWeight: FontWeight.w500,
          ),
        ),
      ],
    );
  }

  Widget _buildBody() {
    if (_isLoading) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Container(
              padding: EdgeInsets.all(24),
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(24),
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withOpacity(0.08),
                    blurRadius: 20,
                    offset: Offset(0, 8),
                  ),
                ],
              ),
              child: CircularProgressIndicator(
                color: Color(0xFF2196F3),
                strokeWidth: 3,
              ),
            ),
            SizedBox(height: 24),
            Text(
              'Memuat data SKU...',
              style: TextStyle(
                color: Color(0xFF1A237E),
                fontSize: 16,
                fontWeight: FontWeight.w600,
              ),
            ),
          ],
        ),
      );
    }

    if (skuList.isEmpty) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Container(
              padding: EdgeInsets.all(32),
              decoration: BoxDecoration(
                color: Color(0xFF2196F3).withOpacity(0.1),
                borderRadius: BorderRadius.circular(100),
              ),
              child: Icon(
                Icons.inventory_2_outlined,
                size: 80,
                color: Color(0xFF2196F3),
              ),
            ),
            SizedBox(height: 24),
            Text(
              'Belum Ada SKU',
              style: TextStyle(
                fontSize: 22,
                fontWeight: FontWeight.bold,
                color: Color(0xFF1A237E),
              ),
            ),
            SizedBox(height: 12),
            Text(
              'Tap tombol + untuk menambahkan SKU pertama',
              style: TextStyle(
                color: Colors.grey[600],
                fontSize: 15,
              ),
              textAlign: TextAlign.center,
            ),
          ],
        ),
      );
    }

    if (!_isAnimationInitialized) {
      return ListView.builder(
        padding: EdgeInsets.all(20),
        physics: BouncingScrollPhysics(),
        itemCount: skuList.length,
        itemBuilder: (context, index) {
          final sku = skuList[index];
          return _buildSKUCard(sku);
        },
      );
    }

    return AnimatedBuilder(
      animation: _fadeAnimation,
      builder: (context, child) {
        return FadeTransition(
          opacity: _fadeAnimation,
          child: SlideTransition(
            position: _slideAnimation,
            child: ListView.builder(
              padding: EdgeInsets.all(20),
              physics: BouncingScrollPhysics(),
              itemCount: skuList.length,
              itemBuilder: (context, index) {
                final sku = skuList[index];
                return _buildSKUCard(sku);
              },
            ),
          ),
        );
      },
    );
  }

  Widget _buildSKUCard(Map<String, dynamic> sku) {
    final skuCode = sku['sku'];
    final mappings = skuMappings[skuCode] ?? [];
    final isSyncing = _syncingSkus.contains(skuCode);
    final lastSync = sku['last_sync_at'];

    return Container(
      margin: EdgeInsets.only(bottom: 16),
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
      child: Padding(
        padding: EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Header with SKU Code and Actions
            Row(
              children: [
                // SKU Icon
                Container(
                  width: 56,
                  height: 56,
                  decoration: BoxDecoration(
                    gradient: LinearGradient(
                      colors: [
                        Color(0xFF1A237E),
                        Color(0xFF283593),
                      ],
                      begin: Alignment.topLeft,
                      end: Alignment.bottomRight,
                    ),
                    borderRadius: BorderRadius.circular(16),
                  ),
                  child: Icon(Icons.qr_code_rounded, color: Colors.white, size: 28),
                ),
                SizedBox(width: 14),
                // SKU Code and Name
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        skuCode,
                        style: TextStyle(
                          fontWeight: FontWeight.bold,
                          fontSize: 18,
                          color: Color(0xFF1A237E),
                          letterSpacing: 0.3,
                        ),
                      ),
                      SizedBox(height: 4),
                      Text(
                        sku['name'],
                        style: TextStyle(
                          fontSize: 14,
                          color: Colors.grey[600],
                          fontWeight: FontWeight.w500,
                        ),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ],
                  ),
                ),
                // Action Buttons
                Container(
                  decoration: BoxDecoration(
                    color: Color(0xFF2196F3).withOpacity(0.1),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: IconButton(
                    icon: Icon(Icons.edit_outlined,
                        color: Color(0xFF2196F3), size: 20),
                    onPressed: () => _showEditSKUDialog(sku),
                    padding: EdgeInsets.all(8),
                    constraints: BoxConstraints(),
                  ),
                ),
                SizedBox(width: 8),
                Container(
                  decoration: BoxDecoration(
                    color: Colors.red.withOpacity(0.1),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: IconButton(
                    icon: Icon(Icons.delete_outline,
                        color: Colors.red[400], size: 20),
                    onPressed: () => _showDeleteConfirmation(skuCode),
                    padding: EdgeInsets.all(8),
                    constraints: BoxConstraints(),
                  ),
                ),
              ],
            ),

            SizedBox(height: 16),

            // Stock Info
            Container(
              padding: EdgeInsets.all(14),
              decoration: BoxDecoration(
                color: Color(0xFFF5F7FA),
                borderRadius: BorderRadius.circular(12),
              ),
              child: Row(
                children: [
                  Icon(Icons.inventory_2_outlined,
                      size: 20, color: Color(0xFF1A237E)),
                  SizedBox(width: 10),
                  Text(
                    'Stok: ',
                    style: TextStyle(
                      fontSize: 14,
                      color: Colors.grey[700],
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                  Text(
                    '${sku['stock']} pcs',
                    style: TextStyle(
                      fontWeight: FontWeight.bold,
                      color: Color(0xFF1A237E),
                      fontSize: 16,
                    ),
                  ),
                  Spacer(),
                  if (lastSync != null)
                    Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Icon(Icons.access_time,
                            size: 14, color: Colors.grey[500]),
                        SizedBox(width: 4),
                        Text(
                          _formatTime(lastSync),
                          style: TextStyle(
                            fontSize: 12,
                            color: Colors.grey[600],
                            fontWeight: FontWeight.w500,
                          ),
                        ),
                      ],
                    )
                  else
                    Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Icon(Icons.sync_disabled,
                            size: 14, color: Colors.grey[400]),
                        SizedBox(width: 4),
                        Text(
                          'Belum pernah sync',
                          style: TextStyle(
                            fontSize: 12,
                            color: Colors.grey[500],
                            fontWeight: FontWeight.w500,
                          ),
                        ),
                      ],
                    ),
                ],
              ),
            ),

            // Marketplace Badges and Sync Button
            if (mappings.isEmpty) ...[
              // No mappings yet - show "not connected" message
              SizedBox(height: 12),
              Container(
                padding: EdgeInsets.all(14),
                decoration: BoxDecoration(
                  color: Colors.grey[100],
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Row(
                  children: [
                    Icon(Icons.link_off, size: 18, color: Colors.grey[600]),
                    SizedBox(width: 8),
                    Text(
                      'Belum Terhubung ke Marketplace',
                      style: TextStyle(
                        fontSize: 13,
                        color: Colors.grey[600],
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                  ],
                ),
              ),
            ] else ...[
              // Has mappings - show platform badges
              SizedBox(height: 12),
              Wrap(
                spacing: 8,
                runSpacing: 8,
                children: mappings.map((mapping) {
                  final marketplace = mapping['marketplace'] as String;
                  final isShopee = marketplace.toUpperCase() == 'SHOPEE';
                  final isTikTok = marketplace.toUpperCase() == 'TIKTOK';

                  return Container(
                    padding: EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                    decoration: BoxDecoration(
                      color: isShopee
                          ? Color(0xFFEE4D2D).withOpacity(0.1)
                          : isTikTok
                              ? Colors.black.withOpacity(0.05)
                              : Colors.blue.withOpacity(0.1),
                      borderRadius: BorderRadius.circular(8),
                      border: Border.all(
                        color: isShopee
                            ? Color(0xFFEE4D2D).withOpacity(0.3)
                            : isTikTok
                                ? Colors.black.withOpacity(0.2)
                                : Colors.blue.withOpacity(0.3),
                        width: 1,
                      ),
                    ),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Icon(
                          isShopee
                              ? Icons.shopping_bag
                              : isTikTok
                                  ? Icons.music_note
                                  : Icons.store,
                          size: 14,
                          color: isShopee
                              ? Color(0xFFEE4D2D)
                              : isTikTok
                                  ? Colors.black87
                                  : Colors.blue,
                        ),
                        SizedBox(width: 6),
                        Text(
                          marketplace.toUpperCase(),
                          style: TextStyle(
                            fontSize: 11,
                            fontWeight: FontWeight.w600,
                            color: isShopee
                                ? Color(0xFFEE4D2D)
                                : isTikTok
                                    ? Colors.black87
                                    : Colors.blue,
                          ),
                        ),
                      ],
                    ),
                  );
                }).toList(),
              ),

              // Sync button
              SizedBox(height: 12),
              ElevatedButton(
                onPressed: isSyncing ? null : () => _syncStock(sku),
                style: ElevatedButton.styleFrom(
                  backgroundColor: Color(0xFF1A237E),
                  foregroundColor: Colors.white,
                  disabledBackgroundColor: Color(0xFF1A237E).withOpacity(0.6),
                  padding: EdgeInsets.symmetric(vertical: 14),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                  elevation: 0,
                  minimumSize: Size(double.infinity, 48),
                ),
                child: isSyncing
                    ? Row(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          SizedBox(
                            width: 18,
                            height: 18,
                            child: CircularProgressIndicator(
                              strokeWidth: 2.5,
                              color: Colors.white,
                            ),
                          ),
                          SizedBox(width: 12),
                          Text(
                            'Syncing...',
                            style: TextStyle(
                              fontWeight: FontWeight.w600,
                              fontSize: 15,
                              letterSpacing: 0.2,
                            ),
                          ),
                        ],
                      )
                    : Row(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Icon(Icons.sync_rounded, size: 20),
                          SizedBox(width: 8),
                          Text(
                            'Sync Stock ke Marketplace',
                            style: TextStyle(
                              fontWeight: FontWeight.w600,
                              fontSize: 15,
                              letterSpacing: 0.2,
                            ),
                          ),
                        ],
                      ),
              ),
            ],
          ],
        ),
      ),
    );
  }

  Widget _buildDialogTextField({
    required TextEditingController controller,
    required String label,
    required String hint,
    required IconData icon,
    TextInputType? keyboardType,
    TextCapitalization textCapitalization = TextCapitalization.none,
  }) {
    return TextFormField(
      controller: controller,
      keyboardType: keyboardType,
      textCapitalization: textCapitalization,
      inputFormatters: keyboardType == TextInputType.number
          ? [FilteringTextInputFormatter.digitsOnly]
          : null,
      style: TextStyle(
        fontSize: 15,
        color: Colors.grey[800],
        fontWeight: FontWeight.w500,
      ),
      decoration: InputDecoration(
        labelText: label,
        hintText: hint,
        labelStyle: TextStyle(
          color: Colors.grey[600],
          fontSize: 14,
          fontWeight: FontWeight.w500,
        ),
        hintStyle: TextStyle(
          color: Colors.grey[400],
          fontSize: 14,
        ),
        prefixIcon: Container(
          margin: EdgeInsets.all(12),
          padding: EdgeInsets.all(8),
          decoration: BoxDecoration(
            color: Color(0xFF2196F3).withOpacity(0.1),
            borderRadius: BorderRadius.circular(10),
          ),
          child: Icon(
            icon,
            color: Color(0xFF2196F3),
            size: 20,
          ),
        ),
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(14),
          borderSide: BorderSide(color: Colors.grey[300]!, width: 1.5),
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(14),
          borderSide: BorderSide(color: Colors.grey[300]!, width: 1.5),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(14),
          borderSide: BorderSide(color: Color(0xFF2196F3), width: 2),
        ),
        errorBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(14),
          borderSide: BorderSide(color: Colors.red[400]!, width: 1.5),
        ),
        focusedErrorBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(14),
          borderSide: BorderSide(color: Colors.red[400]!, width: 2),
        ),
        filled: true,
        fillColor: Colors.grey[50],
        contentPadding: EdgeInsets.symmetric(horizontal: 16, vertical: 18),
      ),
    );
  }

  String _formatTime(String isoTime) {
    try {
      final dt = DateTime.parse(isoTime);
      final now = DateTime.now();
      final diff = now.difference(dt);

      if (diff.inMinutes < 1) return 'Baru saja';
      if (diff.inHours < 1) return '${diff.inMinutes}m lalu';
      if (diff.inDays < 1) return '${diff.inHours}h lalu';
      return '${diff.inDays}d lalu';
    } catch (e) {
      return '-';
    }
  }
}