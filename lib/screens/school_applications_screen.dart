// screens/school_applications_screen.dart
import 'package:flutter/material.dart';
import '/services/database_service.dart';
import '/services/auth_service.dart';

class SchoolApplicationsScreen extends StatefulWidget {
  @override
  State<SchoolApplicationsScreen> createState() => _SchoolApplicationsScreenState();
}

class _SchoolApplicationsScreenState extends State<SchoolApplicationsScreen> {
  final DatabaseService _dbService = DatabaseService();
  final AuthService _authService = AuthService();

  List<Map<String, dynamic>> _schools = [];
  List<Map<String, dynamic>> _selectedSchoolVehicles = [];
  Map<String, dynamic>? _selectedSchool;
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _loadSchoolsWithApplications();
  }

  Future<void> _loadSchoolsWithApplications() async {
    try {
      final schools = await _dbService.getSchools();
      final vehicles = await _dbService.getAllVehicles();

      // Başvurusu olan okulları filtrele
      final schoolsWithApplications = schools.where((school) {
        final schoolVehicles = vehicles.where((vehicle) {
          // Bu okula ait bekleyen araç var mı?
          // TODO: Gerçek veritabanı sorgusu ile değiştir
          return vehicle['is_approved'] == false;
        }).toList();
        return schoolVehicles.isNotEmpty;
      }).toList();

      setState(() {
        _schools = schoolsWithApplications;
        _isLoading = false;
      });
    } catch (e) {
      print('Okul başvuruları yükleme hatası: $e');
      setState(() => _isLoading = false);
    }
  }

  Future<void> _loadSchoolVehicles(dynamic schoolId) async {
    try {
      // schoolId hem string hem int gelebilir
      final id = schoolId is String ? schoolId : schoolId.toString();
      final vehicles = await _dbService.getSchoolVehicles(id);
      setState(() {
        _selectedSchoolVehicles = vehicles.where((v) => v['is_approved'] == false).toList();
      });
    } catch (e) {
      print('Okul araçları yükleme hatası: $e');
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text('Okul Başvuruları'),
        backgroundColor: Color(0xFFE3F2FD),
      ),
      body: _isLoading ? _buildLoading() : _buildContent(),
    );
  }

  Widget _buildLoading() => Center(child: CircularProgressIndicator());

  Widget _buildContent() {
    if (_selectedSchool == null) {
      return _buildSchoolsList();
    } else {
      return _buildSchoolVehicles();
    }
  }

  Widget _buildSchoolsList() {
    return Column(
      children: [
        Padding(
          padding: EdgeInsets.all(16),
          child: Card(
            child: Padding(
              padding: EdgeInsets.all(16),
              child: Row(
                children: [
                  Icon(Icons.school, color: Color(0xFF2196F3)),
                  SizedBox(width: 12),
                  Expanded(
                    child: Text(
                      'Başvurusu olan okullar listeleniyor. Okula tıklayarak başvurularını görüntüleyin.',
                      style: TextStyle(color: Colors.grey[600]),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
        Expanded(
          child: ListView.builder(
            itemCount: _schools.length,
            itemBuilder: (context, index) {
              final school = _schools[index];
              return _buildSchoolCard(school);
            },
          ),
        ),
      ],
    );
  }

  Widget _buildSchoolCard(Map<String, dynamic> school) {
    return FutureBuilder<int>(
      future: _getPendingApplicationsCount(school['id']),
      builder: (context, snapshot) {
        final pendingCount = snapshot.data ?? 0;

        return Card(
          margin: EdgeInsets.symmetric(horizontal: 16, vertical: 8),
          child: ListTile(
            leading: Icon(Icons.school, color: Color(0xFF2196F3)),
            title: Text(school['name']),
            subtitle: Text('${school['district']} • $pendingCount bekleyen başvuru'),
            trailing: Chip(
              label: Text('$pendingCount', style: TextStyle(color: Colors.white)),
              backgroundColor: Colors.orange,
            ),
            onTap: () {
              setState(() {
                _selectedSchool = school;
              });
              _loadSchoolVehicles(school['id'].toString());
            },
          ),
        );
      },
    );
  }

  Widget _buildSchoolVehicles() {
    return Column(
      children: [
        // Header
        Card(
          margin: EdgeInsets.all(16),
          child: ListTile(
            leading: IconButton(
              icon: Icon(Icons.arrow_back),
              onPressed: () {
                setState(() {
                  _selectedSchool = null;
                  _selectedSchoolVehicles = [];
                });
              },
            ),
            title: Text(_selectedSchool!['name']),
            subtitle: Text('${_selectedSchoolVehicles.length} bekleyen araç başvurusu'),
            trailing: Chip(
              label: Text('${_selectedSchoolVehicles.length}', style: TextStyle(color: Colors.white)),
              backgroundColor: Colors.orange,
            ),
          ),
        ),

        // Araç Listesi
        Expanded(
          child: _selectedSchoolVehicles.isEmpty
              ? Center(child: Text('Bu okulun bekleyen başvurusu bulunmuyor'))
              : ListView.builder(
            itemCount: _selectedSchoolVehicles.length,
            itemBuilder: (context, index) {
              final vehicle = _selectedSchoolVehicles[index];
              return _buildVehicleApplicationCard(vehicle);
            },
          ),
        ),
      ],
    );
  }

  Widget _buildVehicleApplicationCard(Map<String, dynamic> vehicle) {
    final transportType = vehicle['transport_type'] ?? 'private';

    return Card(
      margin: EdgeInsets.symmetric(horizontal: 16, vertical: 4),
      child: ListTile(
        leading: Icon(Icons.pending, color: Colors.orange),
        title: Text(vehicle['plate'] ?? 'Plaka Yok'),
        subtitle: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('${vehicle['driver_name']} • ${vehicle['model']}'),
            Text(
              _getTransportTypeText(transportType),
              style: TextStyle(fontSize: 12, color: Colors.grey[600]),
            ),
          ],
        ),
        trailing: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            IconButton(
              icon: Icon(Icons.check_circle, color: Colors.green),
              onPressed: () => _approveVehicle(vehicle),
            ),
            IconButton(
              icon: Icon(Icons.cancel, color: Colors.red),
              onPressed: () => _rejectVehicle(vehicle),
            ),
          ],
        ),
        onTap: () => _showVehicleDetails(vehicle),
      ),
    );
  }

  // Vehicle detail popup (ilce_vehicles_screen'deki gibi)
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

          // Başlık
          Row(
            children: [
              Icon(Icons.directions_bus, color: Color(0xFF2196F3), size: 24),
              SizedBox(width: 8),
              Text(
                'Araç Detayları',
                style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
              ),
            ],
          ),
          SizedBox(height: 16),

          // Temel Bilgiler
          Card(
            child: Padding(
              padding: EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text('Temel Bilgiler', style: TextStyle(fontWeight: FontWeight.bold)),
                  SizedBox(height: 12),
                  _buildDetailRow('Plaka', vehicle['plate'] ?? 'Belirtilmemiş'),
                  _buildDetailRow('Model', vehicle['model'] ?? 'Belirtilmemiş'),
                  _buildDetailRow('Model Yılı', vehicle['model_year']?.toString() ?? 'Belirtilmemiş'),
                  _buildDetailRow('Kapasite', vehicle['capacity']?.toString() ?? 'Belirtilmemiş'),
                  _buildDetailRow('Taşıma Türü', _getTransportTypeText(transportType)),
                  _buildDetailRow('Durum', vehicle['is_approved'] == true ? 'ONAYLI' : 'ONAY BEKLİYOR'),
                ],
              ),
            ),
          ),

          // Sürücü Bilgileri
          Card(
            child: Padding(
              padding: EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text('Sürücü Bilgileri', style: TextStyle(fontWeight: FontWeight.bold)),
                  SizedBox(height: 12),
                  _buildDetailRow('Ad Soyad', vehicle['driver_name'] ?? 'Belirtilmemiş'),
                  _buildDetailRow('Telefon', vehicle['driver_phone'] ?? 'Belirtilmemiş'),
                  _buildDetailRow('Ehliyet', _formatDate(vehicle['driver_license_expiry'])),
                  _buildDetailRow('SRC Belge', _formatDate(vehicle['src_certificate_expiry'])),
                ],
              ),
            ),
          ),

          // Evrak Tarihleri
          Card(
            child: Padding(
              padding: EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text('Evrak Geçerlilik Tarihleri', style: TextStyle(fontWeight: FontWeight.bold)),
                  SizedBox(height: 12),
                  _buildDetailRow('Sigorta', _formatDate(vehicle['insurance_expiry'])),
                  _buildDetailRow('Muayene', _formatDate(vehicle['inspection_expiry'])),
                  if (vehicle['route_permit_expiry'] != null)
                    _buildDetailRow('Güzergah İzni', _formatDate(vehicle['route_permit_expiry'])),
                  if (vehicle['g_certificate_expiry'] != null)
                    _buildDetailRow('G Belgesi', _formatDate(vehicle['g_certificate_expiry'])),
                ],
              ),
            ),
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

  // Yardımcı metodlar
  String _formatDate(String? dateString) {
    if (dateString == null) return 'Belirtilmemiş';
    try {
      final date = DateTime.parse(dateString);
      return '${date.day}/${date.month}/${date.year}';
    } catch (e) {
      return dateString;
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


  Future<int> _getPendingApplicationsCount(dynamic schoolId) async {
    try {
      final id = schoolId is String ? schoolId : schoolId.toString();
      final vehicles = await _dbService.getSchoolVehicles(id);
      return vehicles.where((v) => v['is_approved'] == false).length;
    } catch (e) {
      return 0;
    }
  }

  Future<void> _approveVehicle(Map<String, dynamic> vehicle) async {
    try {
      final currentUser = await _authService.getCurrentUser();
      await _dbService.approveVehicle(
        vehicle['id'].toString(),
        currentUser?['id']?.toString() ?? '',
      );

      _showSnackBar('${vehicle['plate']} onaylandı', Colors.green);
      _loadSchoolVehicles(_selectedSchool!['id'].toString());
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
      try {
        final currentUser = await _authService.getCurrentUser();
        await _dbService.rejectVehicle(
          vehicle['id'].toString(),
          currentUser?['id']?.toString() ?? '',
          reasonController.text.trim(),
        );

        _showSnackBar('${vehicle['plate']} başvurusu reddedildi', Colors.orange);
        _loadSchoolVehicles(_selectedSchool!['id'].toString());
      } catch (e) {
        _showSnackBar('Reddetme hatası: $e', Colors.red);
      }
    }
  }

  String _getTransportTypeText(String transportType) {
    switch (transportType) {
      case 'private': return 'Özel Taşıma';
      case 'state': return 'Devlet Taşıması';
      default: return transportType;
    }
  }

  void _showSnackBar(String message, [Color color = Colors.blue]) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(message), backgroundColor: color),
    );
  }
}