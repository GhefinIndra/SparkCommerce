import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../services/api_service.dart';
import '../models/order.dart';

class ShippingActionWidget extends StatefulWidget {
  final Order order;
  final String shopId;
  final String shopName;
  final VoidCallback? onShippingSuccess;

  const ShippingActionWidget({
    Key? key,
    required this.order,
    required this.shopId,
    required this.shopName,
    this.onShippingSuccess,
  }) : super(key: key);

  @override
  _ShippingActionWidgetState createState() => _ShippingActionWidgetState();
}

class _ShippingActionWidgetState extends State<ShippingActionWidget> {
  final ApiService _apiService = ApiService();
  bool _isShipping = false;
  bool _isGettingLabel = false;
  String? _shippingDocumentUrl;
  String? _trackingNumber;

  // Check if order can be shipped
  bool get canShip {
    // Order should be AWAITING_SHIPMENT or similar status
    final shippableStatuses = ['AWAITING_SHIPMENT', 'TO_FULFILL'];
    return shippableStatuses.contains(widget.order.statusCode);
  }

  // Get package ID from order (assuming it's available in order data)
  String? get packageId {
    // This should be available from order detail API response
    // For now, using order ID as fallback
    return widget.order.packageId ?? widget.order.orderId;
  }

  @override
  Widget build(BuildContext context) {
    if (!canShip) {
      return _buildNotShippableCard();
    }

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(24),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(20),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.04),
            blurRadius: 10,
            offset: const Offset(0, 4),
          ),
          BoxShadow(
            color: Colors.black.withOpacity(0.02),
            blurRadius: 20,
            offset: const Offset(0, 8),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _buildHeaderSection(),
          const SizedBox(height: 20),
          _buildActionButtons(),
          if (_shippingDocumentUrl != null) ...[
            const SizedBox(height: 20),
            _buildShippingDocumentSection(),
          ],
        ],
      ),
    );
  }

  Widget _buildNotShippableCard() {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: Colors.grey[50],
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: Colors.grey[200]!),
      ),
      child: Row(
        children: [
          Icon(Icons.info_outline, color: Colors.grey[600], size: 20),
          const SizedBox(width: 12),
          Expanded(
            child: Text(
              'Pesanan ini belum dapat dikirim. Status: ${widget.order.orderStatusName}',
              style: TextStyle(
                color: Colors.grey[600],
                fontSize: 14,
                fontWeight: FontWeight.w500,
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildHeaderSection() {
    return Row(
      children: [
        Container(
          padding: const EdgeInsets.all(8),
          decoration: BoxDecoration(
            color: Colors.blue.withOpacity(0.1),
            borderRadius: BorderRadius.circular(12),
          ),
          child: const Icon(Icons.local_shipping, color: Colors.blue, size: 20),
        ),
        const SizedBox(width: 12),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'Pengiriman Paket',
                style: TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.w700,
                  color: Colors.grey[800],
                  letterSpacing: -0.3,
                ),
              ),
              Text(
                'Package ID: ${packageId ?? 'N/A'}',
                style: TextStyle(
                  fontSize: 12,
                  color: Colors.grey[600],
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildActionButtons() {
    return Column(
      children: [
        // Ship Package Button
        SizedBox(
          width: double.infinity,
          child: ElevatedButton(
            onPressed: (_isShipping || _isGettingLabel)
                ? null
                : _showShipPackageDialog,
            style: ElevatedButton.styleFrom(
              backgroundColor: const Color(0xFF00AA5B),
              foregroundColor: Colors.white,
              padding: const EdgeInsets.symmetric(vertical: 16),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(16),
              ),
              elevation: 0,
            ),
            child: _isShipping
                ? Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      SizedBox(
                        width: 16,
                        height: 16,
                        child: CircularProgressIndicator(
                          strokeWidth: 2,
                          valueColor:
                              AlwaysStoppedAnimation<Color>(Colors.white),
                        ),
                      ),
                      const SizedBox(width: 12),
                      const Text(
                        'Mengirim Paket...',
                        style: TextStyle(fontWeight: FontWeight.w600),
                      ),
                    ],
                  )
                : const Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Icon(Icons.send, size: 18),
                      SizedBox(width: 8),
                      Text(
                        'Kirim Paket',
                        style: TextStyle(fontWeight: FontWeight.w600),
                      ),
                    ],
                  ),
          ),
        ),

        const SizedBox(height: 12),

        // Get Shipping Label Button (only show if package is already shipped)
        if (_trackingNumber != null || widget.order.trackingNumber.isNotEmpty)
          SizedBox(
            width: double.infinity,
            child: OutlinedButton(
              onPressed: (_isShipping || _isGettingLabel)
                  ? null
                  : _getShippingDocument,
              style: OutlinedButton.styleFrom(
                foregroundColor: Colors.blue,
                side: const BorderSide(color: Colors.blue, width: 1.5),
                padding: const EdgeInsets.symmetric(vertical: 16),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(16),
                ),
              ),
              child: _isGettingLabel
                  ? Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        SizedBox(
                          width: 16,
                          height: 16,
                          child: CircularProgressIndicator(
                            strokeWidth: 2,
                            valueColor:
                                AlwaysStoppedAnimation<Color>(Colors.blue),
                          ),
                        ),
                        const SizedBox(width: 12),
                        const Text('Mengambil Label...'),
                      ],
                    )
                  : const Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Icon(Icons.download, size: 18),
                        SizedBox(width: 8),
                        Text('Ambil Label Pengiriman'),
                      ],
                    ),
            ),
          ),
      ],
    );
  }

  Widget _buildShippingDocumentSection() {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.green.withOpacity(0.05),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: Colors.green.withOpacity(0.2)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(Icons.check_circle, color: Colors.green[600], size: 20),
              const SizedBox(width: 8),
              const Text(
                'Label Pengiriman Tersedia',
                style: TextStyle(
                  fontWeight: FontWeight.w600,
                  fontSize: 14,
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          if (_trackingNumber != null) ...[
            _buildDocumentInfoRow('No. Resi', _trackingNumber!),
            const SizedBox(height: 8),
          ],
          Row(
            children: [
              Expanded(
                child: OutlinedButton(
                  onPressed: _openShippingDocument,
                  style: OutlinedButton.styleFrom(
                    foregroundColor: Colors.green[600],
                    side: BorderSide(color: Colors.green[600]!),
                    padding: const EdgeInsets.symmetric(vertical: 12),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
                  ),
                  child: const Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Icon(Icons.open_in_new, size: 16),
                      SizedBox(width: 6),
                      Text('Buka Label', style: TextStyle(fontSize: 13)),
                    ],
                  ),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: OutlinedButton(
                  onPressed: _downloadShippingDocument,
                  style: OutlinedButton.styleFrom(
                    foregroundColor: Colors.blue[600],
                    side: BorderSide(color: Colors.blue[600]!),
                    padding: const EdgeInsets.symmetric(vertical: 12),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
                  ),
                  child: const Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Icon(Icons.download, size: 16),
                      SizedBox(width: 6),
                      Text('Download', style: TextStyle(fontSize: 13)),
                    ],
                  ),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildDocumentInfoRow(String label, String value) {
    return Row(
      children: [
        Text(
          '$label: ',
          style: TextStyle(
            fontSize: 12,
            color: Colors.grey[600],
          ),
        ),
        Text(
          value,
          style: const TextStyle(
            fontSize: 12,
            fontWeight: FontWeight.w600,
          ),
        ),
        const SizedBox(width: 8),
        InkWell(
          onTap: () {
            Clipboard.setData(ClipboardData(text: value));
            ScaffoldMessenger.of(context).showSnackBar(
              SnackBar(
                content: Text('$label disalin'),
                backgroundColor: const Color(0xFF00AA5B),
                behavior: SnackBarBehavior.floating,
                duration: const Duration(seconds: 2),
              ),
            );
          },
          child: Icon(Icons.copy, size: 14, color: Colors.grey[600]),
        ),
      ],
    );
  }

  void _showShipPackageDialog() {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(20),
        ),
        title: Row(
          children: [
            Container(
              padding: const EdgeInsets.all(8),
              decoration: BoxDecoration(
                color: const Color(0xFF00AA5B).withOpacity(0.1),
                borderRadius: BorderRadius.circular(12),
              ),
              child: const Icon(Icons.send, color: Color(0xFF00AA5B)),
            ),
            const SizedBox(width: 12),
            const Text(
              'Kirim Paket',
              style: TextStyle(
                fontWeight: FontWeight.w700,
                fontSize: 18,
              ),
            ),
          ],
        ),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Apakah Anda yakin ingin mengirim paket untuk pesanan ini?',
              style: TextStyle(
                color: Colors.grey[600],
                height: 1.5,
              ),
            ),
            const SizedBox(height: 16),
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: Colors.grey[50],
                borderRadius: BorderRadius.circular(12),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Detail Pengiriman:',
                    style: TextStyle(
                      fontWeight: FontWeight.w600,
                      color: Colors.grey[700],
                    ),
                  ),
                  const SizedBox(height: 8),
                  Text('Order ID: ${widget.order.orderId}',
                      style: TextStyle(fontSize: 12, color: Colors.grey[600])),
                  Text('Package ID: ${packageId ?? 'N/A'}',
                      style: TextStyle(fontSize: 12, color: Colors.grey[600])),
                  Text('Metode: TikTok Shipping (PICKUP)',
                      style: TextStyle(fontSize: 12, color: Colors.grey[600])),
                ],
              ),
            ),
          ],
        ),
        actions: [
          Row(
            children: [
              Expanded(
                child: OutlinedButton(
                  onPressed: () => Navigator.pop(context),
                  style: OutlinedButton.styleFrom(
                    foregroundColor: Colors.grey[600],
                    side: BorderSide(color: Colors.grey[300]!),
                    padding: const EdgeInsets.symmetric(vertical: 12),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
                  ),
                  child: const Text('Batal'),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: ElevatedButton(
                  onPressed: () {
                    Navigator.pop(context);
                    _shipPackage();
                  },
                  style: ElevatedButton.styleFrom(
                    backgroundColor: const Color(0xFF00AA5B),
                    foregroundColor: Colors.white,
                    padding: const EdgeInsets.symmetric(vertical: 12),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
                    elevation: 0,
                  ),
                  child: const Text(
                    'Kirim Paket',
                    style: TextStyle(fontWeight: FontWeight.w600),
                  ),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Future<void> _shipPackage() async {
    if (packageId == null) {
      _showErrorSnackBar('Package ID tidak tersedia');
      return;
    }

    setState(() {
      _isShipping = true;
    });

    try {
      final response = await _apiService.shipPackage(
        widget.shopId,
        packageId!,
        handoverMethod: 'PICKUP',
      );

      if (response['success']) {
        _showSuccessSnackBar('Paket berhasil dikirim!');

        // Automatically get shipping document after successful shipment
        await _getShippingDocument(showSnackBar: false);

        // Call callback to refresh parent widget
        widget.onShippingSuccess?.call();
      } else {
        _showErrorSnackBar(response['message'] ?? 'Gagal mengirim paket');
      }
    } catch (error) {
      _showErrorSnackBar('Error: $error');
    } finally {
      setState(() {
        _isShipping = false;
      });
    }
  }

  Future<void> _getShippingDocument({bool showSnackBar = true}) async {
    if (packageId == null) {
      if (showSnackBar) _showErrorSnackBar('Package ID tidak tersedia');
      return;
    }

    setState(() {
      _isGettingLabel = true;
    });

    try {
      final response = await _apiService.getShippingDocument(
        widget.shopId,
        packageId!,
        documentType: 'SHIPPING_LABEL',
        documentSize: 'A6',
        documentFormat: 'PDF',
      );

      if (response['success']) {
        setState(() {
          _shippingDocumentUrl = response['data']['doc_url'];
          _trackingNumber = response['data']['tracking_number'];
        });

        if (showSnackBar) {
          _showSuccessSnackBar('Label pengiriman berhasil diambil!');
        }
      } else {
        if (showSnackBar) {
          _showErrorSnackBar(response['message'] ?? 'Gagal mengambil label');
        }
      }
    } catch (error) {
      if (showSnackBar) {
        _showErrorSnackBar('Error: $error');
      }
    } finally {
      setState(() {
        _isGettingLabel = false;
      });
    }
  }

  void _openShippingDocument() {
    if (_shippingDocumentUrl != null) {
      
      // For now, copy URL to clipboard
      Clipboard.setData(ClipboardData(text: _shippingDocumentUrl!));
      _showSuccessSnackBar('URL label disalin ke clipboard');
    }
  }

  void _downloadShippingDocument() {
    if (_shippingDocumentUrl != null) {
      
      // For now, copy URL to clipboard
      Clipboard.setData(ClipboardData(text: _shippingDocumentUrl!));
      _showSuccessSnackBar('URL download disalin ke clipboard');
    }
  }

  void _showSuccessSnackBar(String message) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(message),
        backgroundColor: const Color(0xFF00AA5B),
        behavior: SnackBarBehavior.floating,
        duration: const Duration(seconds: 3),
      ),
    );
  }

  void _showErrorSnackBar(String message) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(message),
        backgroundColor: Colors.red,
        behavior: SnackBarBehavior.floating,
        duration: const Duration(seconds: 4),
      ),
    );
  }
}
