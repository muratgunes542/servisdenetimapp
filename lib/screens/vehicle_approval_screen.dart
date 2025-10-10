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
      final vehicles = await _dbService.getAllVehicles();
      setState(() {
        _pendingVehicles = vehicles.where((v) => v['is_approved'] == false).toList();
        _isLoading = false;
      });
    } catch (e) {
      print('Bekleyen araç yükleme hatası: $e');
      setState(() => _isLoading = false);
    }
  }

  Future<void> _approveVehicle(Map<String, dynamic> vehicle) async {
    try {
      final currentUser = await _authService.getCurrentUser();
      // vehicle['id'] integer geliyor, string'e çevir
      await _dbService.approveVehicle(vehicle['id'].toString(), currentUser?['id']?.toString() ?? '');
      _showSnackBar('${vehicle['plate']} onaylandı', Colors.green);
      _loadPendingVehicles();
    } catch (e) {
      _showSnackBar('Onay hatası: $e', Colors.red);
    }
  }

  Future<void> _rejectVehicle(Map<String, dynamic> vehicle) async {
    final reasonController = TextEditingController();

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
              ),
              maxLines: 3,
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
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
              Navigator.pop(context, true);
            },
            style: ElevatedButton.styleFrom(backgroundColor: Colors.red),
            child: Text('REDDET'),
          ),
        ],
      ),
    );

    if (result == true) {
      await _performRejection(vehicle, reasonController.text.trim());
    }
  }

  Future<void> _performRejection(Map<String, dynamic> vehicle, String reason) async {
    try {
      final currentUser = await _authService.getCurrentUser();
      await _dbService.rejectVehicle(
        vehicle['id'].toString(),
        currentUser?['id']?.toString() ?? '',
        reason,
      );

      _showSnackBar('${vehicle['plate']} başvurusu reddedildi', Colors.orange);
      _loadPendingVehicles();
    } catch (e) {
      _showSnackBar('Reddetme hatası: $e', Colors.red);
    }
  }
  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text('Onay Bekleyen Araçlar (${_pendingVehicles.length})'),
        backgroundColor: Color(0xFFE3F2FD),
      ),
      body: _isLoading ? _buildLoading() : _buildPendingList(),
    );
  }

  Widget _buildLoading() => Center(child: CircularProgressIndicator());

  Widget _buildPendingList() {
    if (_pendingVehicles.isEmpty) {
      return Center(child: Text('Onay bekleyen araç bulunmuyor'));
    }

    return ListView.builder(
      itemCount: _pendingVehicles.length,
      itemBuilder: (context, index) {
        final vehicle = _pendingVehicles[index];
        return _buildVehicleApprovalCard(vehicle);
      },
    );
  }

  // Onay kartına red butonu ekle
  Widget _buildVehicleApprovalCard(Map<String, dynamic> vehicle) {
    return FutureBuilder<List<Map<String, dynamic>>>(
      future: _dbService.getVehicleSchools(vehicle['id']),
      builder: (context, snapshot) {
        final schools = snapshot.data ?? [];

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
                    // ... mevcut araç bilgileri

                    SizedBox(height: 16),
                    Row(
                      children: [
                        Expanded(
                          child: ElevatedButton(
                            onPressed: () => _approveVehicle(vehicle),
                            style: ElevatedButton.styleFrom(backgroundColor: Colors.green),
                            child: Text('ONAYLA'),
                          ),
                        ),
                        SizedBox(width: 12),
                        Expanded(
                          child: ElevatedButton(
                            onPressed: () => _rejectVehicle(vehicle),
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
      },
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
          FutureBuilder<List<Map<String, dynamic>>>(
            future: _dbService.getVehicleSchools(vehicle['id']),
            builder: (context, snapshot) {
              final schools = snapshot.data ?? [];
              if (schools.isNotEmpty) {
                return _buildDetailCard('Başvuru Yapan Okullar', [
                  ...schools.map((vs) =>
                      Text('• ${vs['schools']['name']} - ${vs['schools']['district']}')
                  ).toList(),
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
                    Navigator.pop(context);
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
                    Navigator.pop(context);
                    _rejectVehicle(vehicle);
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
      SnackBar(content: Text(message), backgroundColor: color),
    );
  }
}