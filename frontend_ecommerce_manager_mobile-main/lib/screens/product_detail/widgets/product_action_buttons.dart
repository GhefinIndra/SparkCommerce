// lib/screens/product_detail/widgets/product_action_buttons.dart
import 'package:flutter/material.dart';

class ProductActionButtons extends StatelessWidget {
  final VoidCallback onEditInfo;
  final VoidCallback onEditPrice;
  final VoidCallback onEditStock;
  final VoidCallback onEditImage;
  final VoidCallback onDelete;
  final VoidCallback? onUnlist; // Optional - for Shopee platform
  final String platform; // Platform identifier
  final bool isUnlisted; // Current unlist status for Shopee

  const ProductActionButtons({
    Key? key,
    required this.onEditInfo,
    required this.onEditPrice,
    required this.onEditStock,
    required this.onEditImage,
    required this.onDelete,
    this.onUnlist,
    this.platform = 'TikTok Shop',
    this.isUnlisted = false,
  }) : super(key: key);

  // Helper getter to check if platform is Shopee
  bool get _isShopee => platform.toLowerCase().contains('shopee');

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(20),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.04),
            blurRadius: 12,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      padding: const EdgeInsets.all(20),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Section Title
          Row(
            children: [
              Container(
                padding: const EdgeInsets.all(10),
                decoration: BoxDecoration(
                  color: Color(0xFF2196F3).withOpacity(0.1),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: const Icon(
                  Icons.build_rounded,
                  color: Color(0xFF2196F3),
                  size: 20,
                ),
              ),
              const SizedBox(width: 12),
              Text(
                'Kelola Produk',
                style: TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.w700,
                  color: Color(0xFF1A237E),
                  letterSpacing: 0.1,
                ),
              ),
            ],
          ),

          const SizedBox(height: 20),

          // Primary Actions (2x2 Grid)
          Row(
            children: [
              Expanded(
                child: _buildActionButton(
                  onPressed: onEditInfo,
                  icon: Icons.edit_outlined,
                  label: 'Edit Info',
                  color: const Color(0xFF2196F3),
                  description: 'Nama & deskripsi',
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: _buildActionButton(
                  onPressed: onEditPrice,
                  icon: Icons.attach_money_outlined,
                  label: 'Edit Harga',
                  color: const Color(0xFF2196F3),
                  description: 'Harga semua SKU',
                ),
              ),
            ],
          ),

          const SizedBox(height: 12),

          Row(
            children: [
              Expanded(
                child: _buildActionButton(
                  onPressed: onEditStock,
                  icon: Icons.inventory_2_outlined,
                  label: 'Edit Stok',
                  color: const Color(0xFFFF9800),
                  description: 'Stok semua varian',
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: _buildActionButton(
                  onPressed: onEditImage,
                  icon: Icons.image_outlined,
                  label: 'Edit Gambar',
                  color: const Color(0xFF9C27B0),
                  description: 'Gambar produk',
                ),
              ),
            ],
          ),

          const SizedBox(height: 20),

          // Dangerous Actions Section
          // Show Unlist button for Shopee, Delete button for all platforms
          if (_isShopee) ...[
            // Unlist/List button (Shopee only)
            Container(
              width: double.infinity,
              margin: const EdgeInsets.only(bottom: 12),
              decoration: BoxDecoration(
                border: Border.all(color: Colors.orange[300]!),
                borderRadius: BorderRadius.circular(12),
              ),
              child: Material(
                color: Colors.transparent,
                child: InkWell(
                  onTap: onUnlist,
                  borderRadius: BorderRadius.circular(12),
                  child: Container(
                    padding: const EdgeInsets.symmetric(vertical: 16, horizontal: 20),
                    child: Row(
                      children: [
                        Container(
                          padding: const EdgeInsets.all(8),
                          decoration: BoxDecoration(
                            color: Colors.orange[50],
                            borderRadius: BorderRadius.circular(8),
                          ),
                          child: Icon(
                            isUnlisted ? Icons.visibility : Icons.visibility_off,
                            color: Colors.orange[600],
                            size: 20,
                          ),
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                isUnlisted ? 'Aktifkan Produk' : 'Nonaktifkan Produk',
                                style: TextStyle(
                                  fontSize: 16,
                                  fontWeight: FontWeight.w600,
                                  color: Colors.orange[700],
                                ),
                              ),
                              Text(
                                isUnlisted
                                    ? 'Tampilkan produk di marketplace'
                                    : 'Sembunyikan produk dari marketplace',
                                style: TextStyle(
                                  fontSize: 12,
                                  color: Colors.orange[600],
                                ),
                              ),
                            ],
                          ),
                        ),
                        Icon(
                          Icons.chevron_right,
                          color: Colors.orange[400],
                          size: 20,
                        ),
                      ],
                    ),
                  ),
                ),
              ),
            ),
          ],

          // Delete button (all platforms)
          Container(
            width: double.infinity,
            decoration: BoxDecoration(
              border: Border.all(color: Colors.red[300]!),
              borderRadius: BorderRadius.circular(12),
            ),
            child: Material(
              color: Colors.transparent,
              child: InkWell(
                onTap: onDelete,
                borderRadius: BorderRadius.circular(12),
                child: Container(
                  padding:
                      const EdgeInsets.symmetric(vertical: 16, horizontal: 20),
                  child: Row(
                    children: [
                      Container(
                        padding: const EdgeInsets.all(8),
                        decoration: BoxDecoration(
                          color: Colors.red[50],
                          borderRadius: BorderRadius.circular(8),
                        ),
                        child: Icon(
                          Icons.delete_outlined,
                          color: Colors.red[600],
                          size: 20,
                        ),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              'Hapus Produk',
                              style: TextStyle(
                                fontSize: 16,
                                fontWeight: FontWeight.w600,
                                color: Colors.red[700],
                              ),
                            ),
                            Text(
                              'Tindakan ini tidak dapat dibatalkan',
                              style: TextStyle(
                                fontSize: 12,
                                color: Colors.red[600],
                              ),
                            ),
                          ],
                        ),
                      ),
                      Icon(
                        Icons.chevron_right,
                        color: Colors.red[400],
                        size: 20,
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildActionButton({
    required VoidCallback onPressed,
    required IconData icon,
    required String label,
    required Color color,
    required String description,
  }) {
    return Container(
      decoration: BoxDecoration(
        border: Border.all(color: color.withOpacity(0.3)),
        borderRadius: BorderRadius.circular(12),
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [
            color.withOpacity(0.05),
            color.withOpacity(0.1),
          ],
        ),
      ),
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          onTap: onPressed,
          borderRadius: BorderRadius.circular(12),
          child: Container(
            padding: const EdgeInsets.all(16),
            child: Column(
              children: [
                Container(
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: color.withOpacity(0.15),
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: Icon(
                    icon,
                    color: color,
                    size: 24,
                  ),
                ),
                const SizedBox(height: 12),
                Text(
                  label,
                  style: TextStyle(
                    fontSize: 14,
                    fontWeight: FontWeight.w600,
                    color: Colors.grey[800],
                  ),
                  textAlign: TextAlign.center,
                ),
                const SizedBox(height: 4),
                Text(
                  description,
                  style: TextStyle(
                    fontSize: 11,
                    color: Colors.grey[600],
                  ),
                  textAlign: TextAlign.center,
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
