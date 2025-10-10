// screens/school_vehicles_screen.dart
import 'package:flutter/material.dart';
import 'vehicle_edit_screen.dart';
import '/services/database_service.dart';
import '/services/auth_service.dart';
import '/utils/constants.dart';
import 'school_vehicle_form_screen.dart';

class SchoolVehiclesScreen extends StatefulWidget {
  @override
  State<SchoolVehiclesScreen> createState() => _SchoolVehiclesScreenState();
}

class _SchoolVehiclesScreenState extends State<SchoolVehiclesScreen> {
  final DatabaseService _dbService = DatabaseService();
  final AuthService _authService = AuthService();

  List<Map<String, dynamic>> _vehicles = [];
  List<Map<String, dynamic>> _filteredVehicles = [];
  bool _isLoading = true;
  String _searchQuery = '';
  String _filterStatus = 'all';

  @override
  void initState() {
    super.initState();
    _loadVehicles();
  }

  Future<void> _loadVehicles() async {
    try {
      final vehicles = await _dbService.getAllVehicles();
      setState(() {
        _vehicles = vehicles;
        _filteredVehicles = vehicles;
        _isLoading = false;
      });
    } catch (e) {
      print('Araç yükleme hatası: $e');
      setState(() => _isLoading = false);
    }
  }

  // school_vehicles_screen.dart - Okula özel araçları yükle
  Future<void> _loadMyVehicles() async {
    try {
      final currentUser = await _authService.getCurrentUser();
      final userSchool = currentUser?['department'];

      if (userSchool != null) {
        // Okul ID'sini bul
        final schools = await _dbService.getSchools();
        final school = schools.firstWhere(
                (s) => s['name'] == userSchool,
            orElse: () => {}
        );

        if (school.isNotEmpty) {
          final schoolVehicles = await _dbService.getSchoolVehicles(school['id'].toString());
          setState(() {
            _vehicles = schoolVehicles;
            _filteredVehicles = schoolVehicles;
          });
          return;
        }
      }

      // Fallback: tüm araçları getir
      final allVehicles = await _dbService.getAllVehicles();
      setState(() {
        _vehicles = allVehicles;
        _filteredVehicles = allVehicles;
      });

    } catch (e) {
      print('Araç yükleme hatası: $e');
      setState(() => _isLoading = false);
    }
  }

  void _searchVehicles(String query) {
    setState(() {
      _searchQuery = query;
      _applyFilters();
    });
  }

  void _filterByStatus(String status) {
    setState(() {
      _filterStatus = status;
      _applyFilters();
    });
  }

  void _applyFilters() {
    List<Map<String, dynamic>> filtered = _vehicles;

    // Search filter
    if (_searchQuery.isNotEmpty) {
      filtered = filtered.where((vehicle) {
        final plate = vehicle['plate']?.toString().toLowerCase() ?? '';
        final model = vehicle['model']?.toString().toLowerCase() ?? '';
        final driver = vehicle['driver_name']?.toString().toLowerCase() ?? '';
        return plate.contains(_searchQuery.toLowerCase()) ||
            model.contains(_searchQuery.toLowerCase()) ||
            driver.contains(_searchQuery.toLowerCase());
      }).toList();
    }

    // Status filter
    if (_filterStatus != 'all') {
      filtered = filtered.where((vehicle) {
        if (_filterStatus == 'approved') {
          return vehicle['is_approved'] == true;
        } else if (_filterStatus == 'pending') {
          return vehicle['is_approved'] == false;
        }
        return true;
      }).toList();
    }

    setState(() {
      _filteredVehicles = filtered;
    });
  }

  void _showVehicleDetails(Map<String, dynamic> vehicle) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      builder: (context) => _buildVehicleDetailPopup(vehicle),
    );
  }

  Widget _buildVehicleDetailPopup(Map<String, dynamic> vehicle) {
    final isApproved = vehicle['is_approved'] == true;
    final transportType = vehicle['transport_type'] ?? 'private';
    final isPending = !isApproved;

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
    Icon(Icons.directions_bus, color: Color(0xFF2196F3), size: 24),
    SizedBox(width: 8),
    Text(
    'Araç Detayları',
    style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
    ),
    Spacer(),
    Container(
    padding: EdgeInsets.symmetric(horizontal: 12, vertical: 6),
    decoration: BoxDecoration(
    color: isApproved ? Colors.green.withOpacity(0.1) : Colors.orange.withOpacity(0.1),
    borderRadius: BorderRadius.circular(20),
    ),
    child: Text(
    isApproved ? 'ONAYLI' : 'BEKLİYOR',
    style: TextStyle(
    color: isApproved ? Colors.green : Colors.orange,
    fontWeight: FontWeight.bold,
    fontSize: 12,
    ),
    ),
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

    // Red sebebi (eğer reddedilmişse)
    if (vehicle['rejection_reason'] != null)
    Card(
    color: Colors.red[50],
    child: Padding(
    padding: EdgeInsets.all(16),
    child: Column(
    crossAxisAlignment: CrossAxisAlignment.start,
    children: [
    Text('Red Sebebi', style: TextStyle(fontWeight: FontWeight.bold, color: Colors.red)),
    SizedBox(height: 8),
    Text(vehicle['rejection_reason']!, style: TextStyle(color: Colors.red)),
    ],
    ),
    ),
    ),

    SizedBox(height: 20),

          // Aksiyon Butonları - SADECE BEKLEYEN ARAÇLAR İÇİN SİLME
          if (isPending)
            Row(
              children: [
                Expanded(
                  child: ElevatedButton(
                    onPressed: () => _editVehicle(vehicle),
                    style: ElevatedButton.styleFrom(backgroundColor: Colors.blue),
                    child: Text('DÜZENLE'),
                  ),
                ),
                SizedBox(width: 12),
                Expanded(
                  child: ElevatedButton(
                    onPressed: () => _deleteVehicle(vehicle),
                    style: ElevatedButton.styleFrom(backgroundColor: Colors.red),
                    child: Text('SİL'),
                  ),
                ),
              ],
            )
          else
            SizedBox(
              width: double.infinity,
              child: OutlinedButton(
                onPressed: () => Navigator.pop(context),
                child: Text('KAPAT'),
              ),
            ),
        ],
      ),
    );
  }

  void _editVehicle(Map<String, dynamic> vehicle) {
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => VehicleEditScreen(vehicle: vehicle),
      ),
    ).then((success) {
      if (success == true) {
        _loadVehicles(); // Listeyi yenile
      }
    });
  }

  void _deleteVehicle(Map<String, dynamic> vehicle) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: Text('Aracı Sil'),
        content: Text('${vehicle['plate']} plakalı aracı silmek istediğinizden emin misiniz?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: Text('İptal'),
          ),
          TextButton(
            onPressed: () async {
              Navigator.pop(context);
              await _performDelete(vehicle);
            },
            child: Text('Sil', style: TextStyle(color: Colors.red)),
          ),
        ],
      ),
    );
  }

  Future<void> _performDelete(Map<String, dynamic> vehicle) async {
    try {
      // TODO: Implement actual delete
      _showSnackBar('${vehicle['plate']} aracı silindi', Colors.green);
      _loadVehicles();
    } catch (e) {
      _showSnackBar('Silme hatası: $e', Colors.red);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.grey[50],
      appBar: AppBar(
        title: Text('Araç Listem'),
        backgroundColor: Color(0xFFE3F2FD),
        actions: [
          IconButton(
            icon: Icon(Icons.refresh),
            onPressed: _loadVehicles,
          ),
        ],
      ),
      body: Column(
        children: [
          _buildSearchAndFilter(),
          _buildStats(),
          Expanded(
            child: _isLoading ? _buildLoading() : _buildVehiclesList(),
          ),
        ],
      ),
      floatingActionButton: FloatingActionButton(
        onPressed: () => Navigator.push(
          context,
          MaterialPageRoute(builder: (context) => SchoolVehicleFormScreen()),
        ),
        child: Icon(Icons.add),
        backgroundColor: Color(0xFF2196F3),
      ),
    );
  }

  Widget _buildSearchAndFilter() {
    return Padding(
      padding: EdgeInsets.all(16),
      child: Column(
        children: [
          // Arama
          TextField(
            onChanged: _searchVehicles,
            decoration: InputDecoration(
              hintText: 'Plaka, model veya sürücü ara...',
              prefixIcon: Icon(Icons.search),
              border: OutlineInputBorder(),
            ),
          ),
          SizedBox(height: 12),
          // Filtreler
          Row(
            children: [
              _buildFilterChip('Tümü', 'all'),
              SizedBox(width: 8),
              _buildFilterChip('Onaylı', 'approved'),
              SizedBox(width: 8),
              _buildFilterChip('Bekleyen', 'pending'),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildFilterChip(String label, String value) {
    return ChoiceChip(
      label: Text(label),
      selected: _filterStatus == value,
      onSelected: (selected) => _filterByStatus(value),
      selectedColor: Color(0xFF2196F3),
      labelStyle: TextStyle(
        color: _filterStatus == value ? Colors.white : Colors.black,
      ),
    );
  }

  Widget _buildStats() {
    final total = _vehicles.length;
    final approved = _vehicles.where((v) => v['is_approved'] == true).length;
    final pending = _vehicles.where((v) => v['is_approved'] == false).length;

    return Container(
      padding: EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceAround,
        children: [
          _buildStatItem('Toplam', total.toString(), Colors.blue),
          _buildStatItem('Onaylı', approved.toString(), Colors.green),
          _buildStatItem('Bekleyen', pending.toString(), Colors.orange),
        ],
      ),
    );
  }

  Widget _buildStatItem(String title, String value, Color color) {
    return Column(
      children: [
        Text(
          value,
          style: TextStyle(
            fontSize: 18,
            fontWeight: FontWeight.bold,
            color: color,
          ),
        ),
        Text(
          title,
          style: TextStyle(fontSize: 12, color: Colors.grey[600]),
        ),
      ],
    );
  }

  Widget _buildLoading() {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          CircularProgressIndicator(),
          SizedBox(height: 16),
          Text('Araçlar yükleniyor...'),
        ],
      ),
    );
  }

  Widget _buildVehiclesList() {
    if (_filteredVehicles.isEmpty) {
      return _buildEmptyState();
    }

    return ListView.builder(
      itemCount: _filteredVehicles.length,
      itemBuilder: (context, index) {
        final vehicle = _filteredVehicles[index];
        return _buildVehicleCard(vehicle);
      },
    );
  }

  Widget _buildEmptyState() {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(Icons.directions_bus, size: 64, color: Colors.grey[400]),
          SizedBox(height: 16),
          Text(
            _searchQuery.isEmpty ? 'Henüz araç kaydınız yok' : 'Arama sonucu bulunamadı',
            style: TextStyle(fontSize: 16, color: Colors.grey[600]),
          ),
          SizedBox(height: 8),
          if (_searchQuery.isEmpty)
            ElevatedButton(
              onPressed: () => Navigator.push(
                context,
                MaterialPageRoute(builder: (context) => SchoolVehicleFormScreen()),
              ),
              child: Text('İlk Aracınızı Ekleyin'),
            ),
        ],
      ),
    );
  }

  // screens/school_vehicles_screen.dart - Silme yetkisi ekle
  Widget _buildVehicleCard(Map<String, dynamic> vehicle) {
    final isApproved = vehicle['is_approved'] == true;
    final isPending = !isApproved;

    return Card(
      margin: EdgeInsets.symmetric(horizontal: 16, vertical: 4),
      elevation: 2,
      child: ListTile(
        leading: _buildVehicleLeading(vehicle, isApproved),
        title: Text(
          vehicle['plate'] ?? 'Plaka Yok',
          style: TextStyle(fontWeight: FontWeight.bold),
        ),
        subtitle: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(vehicle['driver_name'] ?? 'Sürücü Yok'),
            Text(
              '${vehicle['model']} • ${vehicle['model_year'] ?? ''}',
              style: TextStyle(fontSize: 12, color: Colors.grey[600]),
            ),
            if (vehicle['rejection_reason'] != null)
              Text(
                '❌ Red: ${vehicle['rejection_reason']}',
                style: TextStyle(fontSize: 11, color: Colors.red),
              ),
          ],
        ),
        trailing: _buildVehicleTrailing(vehicle, isApproved),
        onTap: () => _showVehicleDetails(vehicle),
        onLongPress: isPending ? () => _showActionMenu(vehicle) : null, // Sadece bekleyenler için
      ),
    );
  }

  void _showActionMenu(Map<String, dynamic> vehicle) {
    final isPending = vehicle['is_approved'] != true;

    showModalBottomSheet(
      context: context,
      builder: (context) => Container(
        padding: EdgeInsets.all(16),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            if (isPending) ...[
              ListTile(
                leading: Icon(Icons.edit),
                title: Text('Düzenle'),
                onTap: () {
                  Navigator.pop(context);
                  _editVehicle(vehicle);
                },
              ),
              ListTile(
                leading: Icon(Icons.delete, color: Colors.red),
                title: Text('Sil', style: TextStyle(color: Colors.red)),
                onTap: () {
                  Navigator.pop(context);
                  _deleteVehicle(vehicle);
                },
              ),
            ] else ...[
              ListTile(
                leading: Icon(Icons.visibility),
                title: Text('Detayları Görüntüle'),
                onTap: () {
                  Navigator.pop(context);
                  _showVehicleDetails(vehicle);
                },
              ),
            ],
          ],
        ),
      ),
    );
  }

  Widget _buildVehicleLeading(Map<String, dynamic> vehicle, bool isApproved) {
    Color color;
    IconData icon;

    if (isApproved) {
      color = Colors.green;
      icon = Icons.check_circle;
    } else {
      color = Colors.orange;
      icon = Icons.pending;
    }

    return Container(
      width: 40,
      height: 40,
      decoration: BoxDecoration(
        color: color.withOpacity(0.1),
        borderRadius: BorderRadius.circular(8),
      ),
      child: Icon(icon, color: color),
    );
  }

  Widget _buildVehicleTrailing(Map<String, dynamic> vehicle, bool isApproved) {
    return Column(
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        Container(
          padding: EdgeInsets.symmetric(horizontal: 8, vertical: 4),
          decoration: BoxDecoration(
            color: isApproved ? Colors.green.withOpacity(0.1) : Colors.orange.withOpacity(0.1),
            borderRadius: BorderRadius.circular(4),
          ),
          child: Text(
            isApproved ? 'ONAYLI' : 'BEKLİYOR',
            style: TextStyle(
              fontSize: 10,
              fontWeight: FontWeight.bold,
              color: isApproved ? Colors.green : Colors.orange,
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildVehicleDetailSheet(Map<String, dynamic> vehicle) {
    final isApproved = vehicle['is_approved'] == true;
    final expiredDocs = _getExpiredDocuments(vehicle);

    return Container(
      padding: EdgeInsets.all(16),
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
          SizedBox(height: 16),
          Text(
            'Araç Detayları',
            style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
          ),
          SizedBox(height: 16),
          _buildDetailRow('Plaka', vehicle['plate'] ?? 'Belirtilmemiş'),
          _buildDetailRow('Model', vehicle['model'] ?? 'Belirtilmemiş'),
          _buildDetailRow('Kapasite', vehicle['capacity']?.toString() ?? 'Belirtilmemiş'),
          _buildDetailRow('Sürücü', vehicle['driver_name'] ?? 'Belirtilmemiş'),
          _buildDetailRow('Durum', isApproved ? 'ONAYLI' : 'ONAY BEKLİYOR'),

          if (vehicle['insurance_expiry'] != null)
            _buildDetailRow('Sigorta', _formatDate(vehicle['insurance_expiry'])),

          if (vehicle['inspection_expiry'] != null)
            _buildDetailRow('Muayene', _formatDate(vehicle['inspection_expiry'])),

          if (expiredDocs.isNotEmpty) ...[
            SizedBox(height: 16),
            Text(
              '⚠️ Süresi Dolmuş Evraklar:',
              style: TextStyle(color: Colors.red, fontWeight: FontWeight.bold),
            ),
            ...expiredDocs.map((doc) => Text('• $doc', style: TextStyle(color: Colors.red))),
          ],

          SizedBox(height: 20),
          Row(
            children: [
              Expanded(
                child: OutlinedButton(
                  onPressed: () => _editVehicle(vehicle),
                  child: Text('DÜZENLE'),
                ),
              ),
              SizedBox(width: 12),
              Expanded(
                child: ElevatedButton(
                  onPressed: () => Navigator.pop(context),
                  style: ElevatedButton.styleFrom(backgroundColor: Colors.green),
                  child: Text('TAMAM'),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildDetailRow(String label, String value) {
    return Padding(
      padding: EdgeInsets.symmetric(vertical: 4),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text('$label:', style: TextStyle(fontWeight: FontWeight.bold)),
          SizedBox(width: 8),
          Expanded(child: Text(value)),
        ],
      ),
    );
  }



  bool _checkExpiredDocuments(Map<String, dynamic> vehicle) {
    final now = DateTime.now();
    final dates = [
      vehicle['insurance_expiry'],
      vehicle['inspection_expiry'],
      vehicle['driver_license_expiry'],
      vehicle['src_certificate_expiry'],
    ];

    return dates.any((date) => date != null && DateTime.parse(date).isBefore(now));
  }

  List<String> _getExpiredDocuments(Map<String, dynamic> vehicle) {
    final now = DateTime.now();
    final expired = <String>[];

    if (vehicle['insurance_expiry'] != null &&
        DateTime.parse(vehicle['insurance_expiry']).isBefore(now)) {
      expired.add('Sigorta');
    }

    if (vehicle['inspection_expiry'] != null &&
        DateTime.parse(vehicle['inspection_expiry']).isBefore(now)) {
      expired.add('Muayene');
    }

    if (vehicle['driver_license_expiry'] != null &&
        DateTime.parse(vehicle['driver_license_expiry']).isBefore(now)) {
      expired.add('Ehliyet');
    }

    if (vehicle['src_certificate_expiry'] != null &&
        DateTime.parse(vehicle['src_certificate_expiry']).isBefore(now)) {
      expired.add('SRC Belgesi');
    }

    return expired;
  }

  String _formatDate(String dateString) {
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




  void _showSnackBar(String message, [Color color = Colors.blue]) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(message),
        backgroundColor: color,
      ),
    );
  }
}