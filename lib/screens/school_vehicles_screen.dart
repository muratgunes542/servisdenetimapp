//school_vehicles_screen.dart
import 'package:flutter/material.dart';
import '../models/vehicle.dart';
import '/services/database_service.dart';
import '/services/auth_service.dart';
import '/utils/constants.dart';
import 'school_vehicle_form_screen.dart';
import 'vehicle_edit_screen.dart';

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
      final currentUser = await _authService.getCurrentUser();
      final userType = currentUser?['user_type']?.toString() ?? '';

      List<Map<String, dynamic>> vehicles;

      if (userType == 'school') {
        // GEÇİCİ: Okul kullanıcıları için TÜM araçları göster
        print('🔍 Okul kullanıcısı - Tüm araçlar getiriliyor...');
        vehicles = await _dbService.getAllVehicles();
      } else {
        // Normal kullanıcı ise kendi araçlarını getir
        vehicles = await _dbService.getUserVehicles(currentUser?['id'] ?? '');
      }

      setState(() {
        _vehicles = vehicles;
        _filteredVehicles = vehicles;
        _isLoading = false;
      });

      print('✅ ${userType == 'school' ? 'Okul' : 'Kullanıcı'} araçları yüklendi: ${vehicles.length} adet');
    } catch (e) {
      print('Araç yükleme hatası: $e');
      setState(() => _isLoading = false);
    }
  }
// Okul ID'sini bulmaya yardımcı metod
  Future<String?> _findSchoolId(Map<String, dynamic>? currentUser) async {
    if (currentUser == null) return null;

    // 1. users tablosunda direkt school_id var mı?
    if (currentUser.containsKey('school_id') && currentUser['school_id'] != null) {
      return currentUser['school_id'].toString();
    }

    // 2. department alanından okul adını çıkar ve schools tablosundan ID bul
    final department = currentUser['department']?.toString() ?? '';
    if (department.isNotEmpty) {
      try {
        final schoolName = department.split(' - ').first;
        final schools = await _dbService.getSchools();
        final school = schools.firstWhere(
              (s) => s['name'] == schoolName,
          orElse: () => {},
        );

        if (school.isNotEmpty) {
          return school['id'].toString();
        }
      } catch (e) {
        print('Okul ID bulma hatası: $e');
      }
    }

    return null;
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

    if (_filterStatus != 'all') {
      filtered = filtered.where((vehicle) {
        if (_filterStatus == 'approved') {
          return vehicle['is_approved'] == true;
        } else if (_filterStatus == 'pending') {
          return vehicle['is_approved'] == false && (vehicle['rejection_reason'] == null || vehicle['rejection_reason'].toString().isEmpty);
        } else if (_filterStatus == 'rejected') {
          return vehicle['rejection_reason'] != null && vehicle['rejection_reason'].toString().isNotEmpty;
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
    final isRejected = vehicle['rejection_reason'] != null && vehicle['rejection_reason'].toString().isNotEmpty;
    final isPending = !isApproved && !isRejected;
    final transportType = vehicle['transport_type']?.toString() ?? 'private';

    return SingleChildScrollView(
      child: Container(
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
                Icon(Icons.directions_bus,
                    color: isApproved ? Colors.green :
                    isRejected ? Colors.red : Colors.orange,
                    size: 24),
                SizedBox(width: 8),
                Text(
                  'Araç Detayları',
                  style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
                ),
              ],
            ),
            SizedBox(height: 16),

            // Durum Bilgisi
            if (isRejected)
              Card(
                color: Colors.red[50],
                child: Padding(
                  padding: EdgeInsets.all(16),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          Icon(Icons.cancel, color: Colors.red),
                          SizedBox(width: 8),
                          Text('REDDEDİLDİ',
                              style: TextStyle(fontWeight: FontWeight.bold, color: Colors.red)),
                        ],
                      ),
                      SizedBox(height: 8),
                      Text('Red Sebebi: ${vehicle['rejection_reason']?.toString() ?? 'Belirtilmemiş'}'),
                    ],
                  ),
                ),
              ),

            // Temel Bilgiler
            Card(
              child: Padding(
                padding: EdgeInsets.all(16),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text('Temel Bilgiler', style: TextStyle(fontWeight: FontWeight.bold)),
                    SizedBox(height: 12),
                    _buildDetailRow('Plaka', vehicle['plate']?.toString() ?? 'Belirtilmemiş'),
                    _buildDetailRow('Model', vehicle['model']?.toString() ?? 'Belirtilmemiş'),
                    _buildDetailRow('Model Yılı', vehicle['model_year']?.toString() ?? 'Belirtilmemiş'),
                    _buildDetailRow('Kapasite', vehicle['capacity']?.toString() ?? 'Belirtilmemiş'),
                    _buildDetailRow('Taşıma Türü', _getTransportTypeText(transportType)),
                    _buildDetailRow('Durum',
                        isApproved ? 'ONAYLI' :
                        isRejected ? 'REDDEDİLDİ' : 'ONAY BEKLİYOR'),
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
                    _buildDetailRow('Ad Soyad', vehicle['driver_name']?.toString() ?? 'Belirtilmemiş'),
                    _buildDetailRow('Telefon', vehicle['driver_phone']?.toString() ?? 'Belirtilmemiş'),
                    _buildDetailRow('Ehliyet', _formatDate(vehicle['driver_license_expiry']?.toString())),
                    _buildDetailRow('SRC Belge', _formatDate(vehicle['src_certificate_expiry']?.toString())),
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
                    _buildDetailRow('Sigorta', _formatDate(vehicle['insurance_expiry']?.toString())),
                    _buildDetailRow('Muayene', _formatDate(vehicle['inspection_expiry']?.toString())),
                    if (vehicle['route_permit_expiry'] != null)
                      _buildDetailRow('Güzergah İzni', _formatDate(vehicle['route_permit_expiry']?.toString())),
                    if (vehicle['g_certificate_expiry'] != null)
                      _buildDetailRow('G Belgesi', _formatDate(vehicle['g_certificate_expiry']?.toString())),
                  ],
                ),
              ),
            ),

            // Bağlı Okullar
            FutureBuilder<List<Map<String, dynamic>>>(
              future: _dbService.getVehicleSchools(vehicle['id'] ?? 0), // int değer gönder
              builder: (context, snapshot) {
                if (snapshot.connectionState == ConnectionState.waiting) {
                  return Card(
                    child: Padding(
                      padding: EdgeInsets.all(16),
                      child: Center(child: CircularProgressIndicator()),
                    ),
                  );
                }

                if (snapshot.hasError) {
                  return Card(
                    child: Padding(
                      padding: EdgeInsets.all(16),
                      child: Text('Okul bilgileri yüklenirken hata oluştu'),
                    ),
                  );
                }

                final vehicleSchools = snapshot.data ?? [];

                return Card(
                  child: Padding(
                    padding: EdgeInsets.all(16),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'Bağlı Okullar',
                          style: TextStyle(
                            fontWeight: FontWeight.bold,
                            fontSize: 16,
                          ),
                        ),
                        SizedBox(height: 8),
                        if (vehicleSchools.isEmpty)
                          Text(
                            'Bu aracın bağlı olduğu okul bulunmuyor',
                            style: TextStyle(color: Colors.grey),
                          )
                        else
                          Column(
                            children: vehicleSchools.map((vs) {
                              final school = vs['schools'] ?? {};
                              return ListTile(
                                leading: Icon(Icons.school, color: Colors.blue),
                                title: Text(school['name'] ?? 'Bilinmeyen Okul'),
                                subtitle: Text(school['district'] ?? ''),
                                dense: true,
                                contentPadding: EdgeInsets.zero,
                              );
                            }).toList(),
                          ),
                      ],
                    ),
                  ),
                );
              },
            ),

            SizedBox(height: 20),

            // AKSiYON BUTONLARI - Tüm durumlar için
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: [
                // DÜZENLE butonu - TÜM durumlar için
                SizedBox(
                  width: double.infinity,
                  child: ElevatedButton.icon(
                    onPressed: () {
                      Navigator.pop(context);
                      _editVehicle(vehicle);
                    },
                    icon: Icon(Icons.edit),
                    label: Text('DÜZENLE'),
                    style: ElevatedButton.styleFrom(backgroundColor: Colors.blue),
                  ),
                ),

                // ONAYA GÖNDER butonu - Sadece onaylı veya reddedilmiş araçlar için
                if (isApproved || isRejected)
                  SizedBox(
                    width: double.infinity,
                    child: ElevatedButton.icon(
                      onPressed: () {
                        Navigator.pop(context);
                        _sendForApproval(vehicle);
                      },
                      icon: Icon(Icons.send),
                      label: Text('TEKRAR ONAYA GÖNDER'),
                      style: ElevatedButton.styleFrom(backgroundColor: Colors.orange),
                    ),
                  ),

                // SİL butonu - TÜM durumlar için
                SizedBox(
                  width: double.infinity,
                  child: ElevatedButton.icon(
                    onPressed: () {
                      Navigator.pop(context);
                      _deleteVehicle(vehicle);
                    },
                    icon: Icon(Icons.delete),
                    label: Text('SİL'),
                    style: ElevatedButton.styleFrom(backgroundColor: Colors.red),
                  ),
                ),

                // KAPAT butonu
                SizedBox(
                  width: double.infinity,
                  child: OutlinedButton(
                    onPressed: () => Navigator.pop(context),
                    child: Text('KAPAT'),
                  ),
                ),
              ],
            ),

            SizedBox(height: 10),
          ],
        ),
      ),
    );
  }

  // Yardımcı metodlar
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

  String _formatDate(String? dateString) {
    if (dateString == null || dateString.isEmpty) return 'Belirtilmemiş';
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

  // Onaya gönderme metodu
  void _sendForApproval(Map<String, dynamic> vehicle) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: Text('Onaya Gönder'),
        content: Text('${vehicle['plate']} plakalı aracı tekrar onay için göndermek istediğinizden emin misiniz?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: Text('İptal'),
          ),
          ElevatedButton(
            onPressed: () async {
              Navigator.pop(context);
              await _performSendForApproval(vehicle);
            },
            style: ElevatedButton.styleFrom(backgroundColor: Colors.orange),
            child: Text('ONAYA GÖNDER'),
          ),
        ],
      ),
    );
  }

  // Onaya gönderme işlemi
  Future<void> _performSendForApproval(Map<String, dynamic> vehicle) async {
    try {
      await _dbService.sendVehicleForApproval(vehicle['id'].toString());
      _showSnackBar('${vehicle['plate']} onay için gönderildi', Colors.orange);
      _loadVehicles();
    } catch (e) {
      _showSnackBar('Onaya gönderme hatası: $e', Colors.red);
    }
  }

  // Diğer metodlar (edit, delete, vs.) aynı kalacak
  void _editVehicle(Map<String, dynamic> vehicle) {
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => VehicleEditScreen(
          vehicle: vehicle,
        ),
      ),
    ).then((refresh) {
      if (refresh == true) {
        _loadVehicles();
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Araç bilgileri güncellendi'),
            backgroundColor: Colors.green,
          ),
        );
      }
    });
  }

  void _deleteVehicle(Map<String, dynamic> vehicle) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: Text('Aracı Sil'),
        content: Text('${vehicle['plate']} plakalı aracı silmek istediğinizden emin misiniz? Bu işlem geri alınamaz.'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: Text('İptal'),
          ),
          ElevatedButton(
            onPressed: () async {
              Navigator.pop(context);
              await _performDelete(vehicle);
            },
            style: ElevatedButton.styleFrom(backgroundColor: Colors.red),
            child: Text('SİL'),
          ),
        ],
      ),
    );
  }

  Future<void> _performDelete(Map<String, dynamic> vehicle) async {
    try {
      await _dbService.deleteVehicle(vehicle['id'].toString());
      _showSnackBar('${vehicle['plate']} aracı silindi', Colors.green);
      _loadVehicles();
    } catch (e) {
      _showSnackBar('Silme hatası: $e', Colors.red);
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

  // Diğer widget metodları (build, _buildVehicleCard, vs.) aynı kalacak
  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.grey[50],
      appBar: AppBar(
        title: Text('Araçlarım'),
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
          TextField(
            onChanged: _searchVehicles,
            decoration: InputDecoration(
              hintText: 'Plaka, model veya sürücü ara...',
              prefixIcon: Icon(Icons.search),
              border: OutlineInputBorder(),
            ),
          ),
          SizedBox(height: 12),
          Row(
            children: [
              _buildFilterChip('Tümü', 'all'),
              SizedBox(width: 8),
              _buildFilterChip('Onaylı', 'approved'),
              SizedBox(width: 8),
              _buildFilterChip('Bekleyen', 'pending'),
              SizedBox(width: 8),
              _buildFilterChip('Reddedilen', 'rejected'),
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
    final pending = _vehicles.where((v) => v['is_approved'] == false && (v['rejection_reason'] == null || v['rejection_reason'].toString().isEmpty)).length;
    final rejected = _vehicles.where((v) => v['rejection_reason'] != null && v['rejection_reason'].toString().isNotEmpty).length;

    return Container(
      padding: EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceAround,
        children: [
          _buildStatItem('Toplam', total.toString(), Colors.blue),
          _buildStatItem('Onaylı', approved.toString(), Colors.green),
          _buildStatItem('Bekleyen', pending.toString(), Colors.orange),
          _buildStatItem('Reddedilen', rejected.toString(), Colors.red),
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
            _searchQuery.isEmpty ? 'Henüz araç kaydı yok' : 'Arama sonucu bulunamadı',
            style: TextStyle(fontSize: 16, color: Colors.grey[600]),
          ),
        ],
      ),
    );
  }

  Widget _buildVehicleCard(Map<String, dynamic> vehicle) {
    final isApproved = vehicle['is_approved'] == true;
    final isRejected = vehicle['rejection_reason'] != null && vehicle['rejection_reason'].toString().isNotEmpty;
    final isPending = !isApproved && !isRejected;

    Color statusColor = isApproved ? Colors.green : isRejected ? Colors.red : Colors.orange;
    IconData statusIcon = isApproved ? Icons.check_circle : isRejected ? Icons.cancel : Icons.pending;

    return Card(
      margin: EdgeInsets.symmetric(horizontal: 16, vertical: 4),
      elevation: 2,
      child: ListTile(
        leading: Container(
          width: 40,
          height: 40,
          decoration: BoxDecoration(
            color: statusColor,
            shape: BoxShape.circle,
          ),
          child: Icon(statusIcon, color: Colors.white, size: 20),
        ),
        title: Text(
          vehicle['plate'] ?? 'Plaka Yok',
          style: TextStyle(fontWeight: FontWeight.bold),
        ),
        subtitle: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(vehicle['driver_name'] ?? 'Sürücü Yok'),
            Text(
              '${vehicle['model']} • ${_getTransportTypeText(vehicle['transport_type'] ?? 'private')}',
              style: TextStyle(fontSize: 12, color: Colors.grey[600]),
            ),
          ],
        ),
        trailing: IconButton(
          icon: Icon(Icons.visibility, color: Colors.blue),
          onPressed: () => _showVehicleDetails(vehicle),
        ),
        onTap: () => _showVehicleDetails(vehicle),
        onLongPress: () => _showActionMenu(vehicle),
      ),
    );
  }

  void _showActionMenu(Map<String, dynamic> vehicle) {
    final isApproved = vehicle['is_approved'] == true;
    final isRejected = vehicle['rejection_reason'] != null && vehicle['rejection_reason'].toString().isNotEmpty;
    final isPending = !isApproved && !isRejected;

    showModalBottomSheet(
      context: context,
      builder: (context) => Container(
        padding: EdgeInsets.all(16),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            ListTile(
              leading: Icon(Icons.visibility),
              title: Text('Detayları Gör'),
              onTap: () {
                Navigator.pop(context);
                _showVehicleDetails(vehicle);
              },
            ),
            ListTile(
              leading: Icon(Icons.edit, color: Colors.blue),
              title: Text('Düzenle'),
              onTap: () {
                Navigator.pop(context);
                _editVehicle(vehicle);
              },
            ),
            if (isApproved || isRejected)
              ListTile(
                leading: Icon(Icons.send, color: Colors.orange),
                title: Text('Tekrar Onaya Gönder'),
                onTap: () {
                  Navigator.pop(context);
                  _sendForApproval(vehicle);
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
          ],
        ),
      ),
    );
  }
}