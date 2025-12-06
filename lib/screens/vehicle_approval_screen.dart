// screens/vehicle_approval_screen.dart
import 'package:flutter/material.dart';
import '/services/database_service.dart';
import '/services/auth_service.dart';

class VehicleApprovalScreen extends StatefulWidget {
  @override
  State<VehicleApprovalScreen> createState() => _VehicleApprovalScreenState();
}

class _VehicleApprovalScreenState extends State<VehicleApprovalScreen> {
  final DatabaseService _dbService = DatabaseService();
  final AuthService _authService = AuthService();

  List<Map<String, dynamic>> _pendingVehicles = [];
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _loadPendingVehicles();
  }

  Future<void> _loadPendingVehicles() async {
    try {
      print('🔄🔄 BEKLEYEN ARAÇLAR YÜKLENİYOR...');
      final vehicles = await _dbService.getAllVehicles();

      print('🔄 Tüm araçlar: ${vehicles.length}');

      // HER ARACIN DURUMUNU LOGLA
      for (var vehicle in vehicles) {
        print('🚗 ${vehicle['plate']} - is_approved: ${vehicle['is_approved']} - rejection: ${vehicle['rejection_reason']}');
      }

      // BEKLEYEN ARAÇLARI FİLTRELE
      final pendingVehicles = vehicles.where((v) {
        final isPending = v['is_approved'] == false;
        print('🔍 ${v['plate']} - is_approved: ${v['is_approved']} -> Bekleyen mi?: $isPending');
        return isPending;
      }).toList();

      print('🔄 Bekleyen araçlar: ${pendingVehicles.length}');

      if (!mounted) return;

      setState(() {
        _pendingVehicles = pendingVehicles;
        _isLoading = false;
      });

      print('✅ UI güncellendi - ${_pendingVehicles.length} bekleyen araç');

    } catch (e) {
      print('❌ Bekleyen araç yükleme hatası: $e');

      if (!mounted) return;

      setState(() => _isLoading = false);
    }
  }

  Future<void> _approveVehicle(Map<String, dynamic> vehicle) async {
    try {
      final currentUser = await _authService.getCurrentUser();
      final userId = currentUser?['id']?.toString() ?? '';

      print('✅ Araç onaylanıyor: ${vehicle['plate']} - Kullanıcı: $userId');

      await _dbService.approveVehicle(vehicle['id'].toString(), userId);

      _showSnackBar('${vehicle['plate']} onaylandı', Colors.green);

      // MOUNTED KONTROLÜ
      if (mounted) {
        await _loadPendingVehicles();
      }

    } catch (e) {
      print('❌ Onay hatası: $e');
      _showSnackBar('Onay hatası: ${e.toString()}', Colors.red);
    }
  }

  /// VehicleApprovalScreen.dart - DIALOG İÇİN DOĞRU CONTEXT KULLANIMI

  Future<void> _rejectVehicle(Map<String, dynamic> vehicle) async {
    final reasonController = TextEditingController();

    // showDialog sonucunu bekle
    final result = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: Text('Başvuruyu Reddet'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('${vehicle['plate']} başvurusunu reddetmek istediğinizden emin misiniz?'),
            SizedBox(height: 16),
            Text('Red Sebebi:'),
            SizedBox(height: 8),
            TextField(
              controller: reasonController,
              decoration: InputDecoration(
                hintText: 'Red sebebini yazın...',
                border: OutlineInputBorder(),
                contentPadding: EdgeInsets.all(12),
              ),
              maxLines: 3,
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(false), // SADECE DIALOG'U KAPAT
            child: Text('İptal'),
          ),
          ElevatedButton(
            onPressed: () {
              if (reasonController.text.trim().isEmpty) {
                ScaffoldMessenger.of(context).showSnackBar(
                  SnackBar(content: Text('Lütfen red sebebi yazın')),
                );
                return;
              }
              Navigator.of(context).pop(true); // SADECE DIALOG'U KAPAT
            },
            style: ElevatedButton.styleFrom(backgroundColor: Colors.red),
            child: Text('REDDET'),
          ),
        ],
      ),
    );

    // Dialog kapandıktan SONRA reddetme işlemini yap
    if (result == true) {
      await _performRejection(vehicle, reasonController.text.trim());
    }
    // BU SATIRDA EKRAN KAPANMAMALI - BURADA NAVIGATOR.POP OLMAMALI
  }



  // VehicleApprovalScreen.dart - EN BASİT ÇÖZÜM

  Future<void> _performRejection(Map<String, dynamic> vehicle, String reason) async {
    try {
      final currentUser = await _authService.getCurrentUser();
      final userId = currentUser?['id']?.toString() ?? '';

      print('❌ Araç reddediliyor: ${vehicle['plate']} - Sebep: $reason');

      // 1. ÖNCE REDDETME İŞLEMİNİ YAP
      await _dbService.rejectVehicle(
        vehicle['id'].toString(),
        userId,
        reason,
      );

      print('✅ Reddetme başarılı: ${vehicle['plate']}');

      // 2. SADECE MANUEL OLARAK LİSTEDEN KALDIR - YENİDEN YÜKLEME YAPMA!
      if (mounted) {
        setState(() {
          _pendingVehicles.removeWhere((v) => v['id'] == vehicle['id']);
        });
        print('✅ Manuel olarak listeden kaldırıldı: ${vehicle['plate']}');
        print('✅ Kalan bekleyen araç sayısı: ${_pendingVehicles.length}');
      }

      _showSnackBar('${vehicle['plate']} başvurusu reddedildi', Colors.orange);

    } catch (e) {
      print('❌ Reddetme hatası: $e');
      _showSnackBar('Reddetme hatası: ${e.toString()}', Colors.red);

      // Hata durumunda listeyi yeniden yükle
      if (mounted) {
        await _loadPendingVehicles();
      }
    }
  }


  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text('Onay Bekleyen Araçlar (${_pendingVehicles.length})'),
        backgroundColor: Color(0xFFE3F2FD),
        actions: [
          IconButton(
            icon: Icon(Icons.refresh),
            onPressed: _loadPendingVehicles,
            tooltip: 'Yenile',
          ),
        ],
      ),
      body: _isLoading
          ? _buildLoading()
          : _pendingVehicles.isEmpty
          ? _buildEmptyState()
          : _buildPendingList(),
    );
  }

  Widget _buildLoading() {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          CircularProgressIndicator(),
          SizedBox(height: 16),
          Text('Onay bekleyen araçlar yükleniyor...'),
        ],
      ),
    );
  }

  Widget _buildEmptyState() {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(Icons.check_circle_outline, size: 64, color: Colors.green),
          SizedBox(height: 16),
          Text(
            'Tüm araçlar onaylandı!',
            style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
          ),
          SizedBox(height: 8),
          Text(
            'Onay bekleyen yeni araç başvurusu bulunmuyor.',
            style: TextStyle(color: Colors.grey[600]),
            textAlign: TextAlign.center,
          ),
        ],
      ),
    );
  }

  Widget _buildPendingList() {
    return RefreshIndicator(
      onRefresh: _loadPendingVehicles,
      child: ListView.builder(
        padding: EdgeInsets.all(8),
        itemCount: _pendingVehicles.length,
        itemBuilder: (context, index) {
          final vehicle = _pendingVehicles[index];
          return _buildVehicleApprovalCard(vehicle);
        },
      ),
    );
  }

  // Onay kartına red butonu ekle
  Widget _buildVehicleApprovalCard(Map<String, dynamic> vehicle) {
    return Card(
      margin: EdgeInsets.all(8),
      child: ExpansionTile(
        title: Text(vehicle['plate'], style: TextStyle(fontWeight: FontWeight.bold)),
        subtitle: Text('${vehicle['driver_name']} - ${vehicle['model']}'),
        leading: Icon(Icons.pending, color: Colors.orange),
        children: [
          Padding(
            padding: EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // ... araç bilgileri ...

                SizedBox(height: 16),
                Row(
                  children: [
                    Expanded(
                      child: ElevatedButton(
                        onPressed: () => _approveVehicle(vehicle), // DOĞRUDAN ONAYLA
                        style: ElevatedButton.styleFrom(backgroundColor: Colors.green),
                        child: Text('ONAYLA'),
                      ),
                    ),
                    SizedBox(width: 12),
                    Expanded(
                      child: ElevatedButton(
                        onPressed: () => _rejectVehicle(vehicle), // DOĞRUDAN REDDET
                        style: ElevatedButton.styleFrom(backgroundColor: Colors.red),
                        child: Text('REDDET'),
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }



  // Araç detay popup'ı
  void _showVehicleDetails(Map<String, dynamic> vehicle) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      builder: (context) => _buildVehicleDetailPopup(vehicle),
    );
  }

  Widget _buildVehicleDetailPopup(Map<String, dynamic> vehicle) {
    final transportType = vehicle['transport_type'] ?? 'private';

    return Container(
      padding: EdgeInsets.all(20),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Center(
            child: Container(
              width: 60,
              height: 4,
              decoration: BoxDecoration(
                color: Colors.grey[300],
                borderRadius: BorderRadius.circular(2),
              ),
            ),
          ),
          SizedBox(height: 20),

          // Başlık ve Durum
          Row(
            children: [
              Icon(Icons.pending, color: Colors.orange, size: 24),
              SizedBox(width: 8),
              Text(
                'Onay Bekleyen Araç',
                style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
              ),
              Spacer(),
              Container(
                padding: EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                decoration: BoxDecoration(
                  color: Colors.orange.withOpacity(0.1),
                  borderRadius: BorderRadius.circular(20),
                ),
                child: Text(
                  'BEKLİYOR',
                  style: TextStyle(color: Colors.orange, fontWeight: FontWeight.bold, fontSize: 12),
                ),
              ),
            ],
          ),
          SizedBox(height: 16),

          // Temel Bilgiler
          _buildDetailCard('Temel Bilgiler', [
            _buildDetailRow('Plaka', vehicle['plate'] ?? 'Belirtilmemiş'),
            _buildDetailRow('Model', vehicle['model'] ?? 'Belirtilmemiş'),
            _buildDetailRow('Model Yılı', vehicle['model_year']?.toString() ?? 'Belirtilmemiş'),
            _buildDetailRow('Kapasite', vehicle['capacity']?.toString() ?? 'Belirtilmemiş'),
            _buildDetailRow('Taşıma Türü', _getTransportTypeText(transportType)),
          ]),

          // Sürücü Bilgileri
          _buildDetailCard('Sürücü Bilgileri', [
            _buildDetailRow('Ad Soyad', vehicle['driver_name'] ?? 'Belirtilmemiş'),
            _buildDetailRow('Telefon', vehicle['driver_phone'] ?? 'Belirtilmemiş'),
            _buildDetailRow('Ehliyet', _formatDate(vehicle['driver_license_expiry'])),
            _buildDetailRow('SRC Belge', _formatDate(vehicle['src_certificate_expiry'])),
          ]),

          // Evrak Tarihleri
          _buildDetailCard('Evrak Geçerlilik', [
            _buildDetailRow('Sigorta', _formatDate(vehicle['insurance_expiry'])),
            _buildDetailRow('Muayene', _formatDate(vehicle['inspection_expiry'])),
            if (vehicle['route_permit_expiry'] != null)
              _buildDetailRow('Güzergah İzni', _formatDate(vehicle['route_permit_expiry'])),
            if (vehicle['g_certificate_expiry'] != null)
              _buildDetailRow('G Belgesi', _formatDate(vehicle['g_certificate_expiry'])),
          ]),

          // Bağlı Okullar
          // Bağlı Okullar kısmını düzeltelim
          FutureBuilder<List<Map<String, dynamic>>>(
            future: _dbService.getVehicleSchools(vehicle['id']),
            builder: (context, snapshot) {
              if (snapshot.connectionState == ConnectionState.waiting) {
                return Padding(
                  padding: EdgeInsets.symmetric(vertical: 8),
                  child: Center(child: CircularProgressIndicator(strokeWidth: 2)),
                );
              }

              if (snapshot.hasError) {
                print('❌ Okul bilgisi yükleme hatası: ${snapshot.error}');
                return _buildDetailCard('Başvuru Yapan Okullar', [
                  Text('Okul bilgileri yüklenemedi', style: TextStyle(color: Colors.grey)),
                ]);
              }

              final schools = snapshot.data ?? [];
              if (schools.isNotEmpty) {
                return _buildDetailCard('Başvuru Yapan Okullar', [
                  ...schools.map((vs) {
                    final school = vs['schools'] is Map ? vs['schools'] : {};
                    return Padding(
                      padding: EdgeInsets.symmetric(vertical: 2),
                      child: Text('• ${school['name'] ?? 'Bilinmeyen'} - ${school['district'] ?? ''}'),
                    );
                  }).toList(),
                ]);
              }

              return SizedBox();
            },
          ),

          SizedBox(height: 20),

          // Aksiyon Butonları
          Row(
            children: [
              Expanded(
                child: ElevatedButton(
                  onPressed: () {
                    Navigator.pop(context); // SADECE POPUP'ı KAPAT
                    _approveVehicle(vehicle);
                  },
                  style: ElevatedButton.styleFrom(backgroundColor: Colors.green),
                  child: Text('ONAYLA'),
                ),
              ),
              SizedBox(width: 12),
              Expanded(
                child: ElevatedButton(
                  onPressed: () {
                    Navigator.pop(context); // SADECE POPUP'ı KAPAT
                    _rejectVehicle(vehicle); // REDDETME DIALOG'U AÇ
                  },
                  style: ElevatedButton.styleFrom(backgroundColor: Colors.red),
                  child: Text('REDDET'),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildDetailCard(String title, List<Widget> children) {
    return Card(
      margin: EdgeInsets.only(bottom: 12),
      child: Padding(
        padding: EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(title, style: TextStyle(fontWeight: FontWeight.bold)),
            SizedBox(height: 12),
            ...children,
          ],
        ),
      ),
    );
  }

  void _showRejectDialog(Map<String, dynamic> vehicle) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: Text('Başvuruyu Reddet'),
        content: Text('${vehicle['plate']} başvurusunu reddetmek istediğinizden emin misiniz?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: Text('İptal'),
          ),
          TextButton(
            onPressed: () {
              Navigator.pop(context);
              // TODO: Reddetme işlemi
              _showSnackBar('${vehicle['plate']} başvurusu reddedildi');
              _loadPendingVehicles();
            },
            child: Text('Reddet', style: TextStyle(color: Colors.red)),
          ),
        ],
      ),
    );
  }


  String _formatDate(String? dateString) {
    if (dateString == null) return 'Belirtilmemiş';
    try {
      final date = DateTime.parse(dateString);
      return '${date.day}/${date.month}/${date.year}';
    } catch (e) {
      return dateString;
    }
  }

  String _getTransportTypeText(String transportType) {
    switch (transportType) {
      case 'private': return 'Özel Taşıma';
      case 'state': return 'Devlet Taşıması';
      default: return transportType;
    }
  }

  Widget _buildDetailRow(String label, String value) {
    return Padding(
      padding: EdgeInsets.symmetric(vertical: 4),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            width: 120,
            child: Text(
              '$label:',
              style: TextStyle(fontWeight: FontWeight.bold),
            ),
          ),
          SizedBox(width: 8),
          Expanded(child: Text(value)),
        ],
      ),
    );
  }


  void _showSnackBar(String message, [Color color = Colors.blue]) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(message),
        backgroundColor: color,
        duration: Duration(seconds: 3), // 3 saniye göster
        behavior: SnackBarBehavior.floating,
      ),
    );
  }
}