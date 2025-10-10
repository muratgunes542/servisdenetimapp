// screens/ilce_vehicles_screen.dart
import 'package:flutter/material.dart';
import 'vehicle_approval_screen.dart';
import '/services/database_service.dart';
import '/services/auth_service.dart';
import '/utils/constants.dart';
import 'school_vehicle_form_screen.dart';
import 'vehicle_edit_screen.dart';

class IlceVehiclesScreen extends StatefulWidget {
  @override
  State<IlceVehiclesScreen> createState() => _IlceVehiclesScreenState();
}

class _IlceVehiclesScreenState extends State<IlceVehiclesScreen> {
  final DatabaseService _dbService = DatabaseService();
  final AuthService _authService = AuthService();

  List<Map<String, dynamic>> _vehicles = [];
  List<Map<String, dynamic>> _filteredVehicles = [];
  bool _isLoading = true;
  String _searchQuery = '';
  String _filterStatus = 'all';
  int _pendingCount = 0;

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
        _pendingCount = vehicles.where((v) => v['is_approved'] == false).length;
        _isLoading = false;
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
          return vehicle['is_approved'] == false;
        }
        return true;
      }).toList();
    }

    setState(() {
      _filteredVehicles = filtered;
    });
  }

  void _showApprovalScreen() {
    Navigator.push(
      context,
      MaterialPageRoute(builder: (context) => VehicleApprovalScreen()),
    ).then((_) {
      _loadVehicles(); // Onay ekranından dönünce listeyi yenile
    });
  }

// _approveVehicle metodunu güncelle
  void _approveVehicle(Map<String, dynamic> vehicle) async {
    try {
      final currentUser = await _authService.getCurrentUser();
      // vehicle['id'] integer geliyor, string'e çevir
      await _dbService.approveVehicle(vehicle['id'].toString(), currentUser?['id']?.toString() ?? '');
      _showSnackBar('${vehicle['plate']} onaylandı', Colors.green);
      _loadVehicles();
    } catch (e) {
      _showSnackBar('Onay hatası: $e', Colors.red);
    }
  }

  void _showVehicleActions(Map<String, dynamic> vehicle) {
    showModalBottomSheet(
      context: context,
      builder: (context) => Container(
        padding: EdgeInsets.all(16),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            ListTile(
              leading: Icon(Icons.edit),
              title: Text('Düzenle'),
              onTap: () {
                Navigator.pop(context);
                _editVehicle(vehicle);
              },
            ),
            if (vehicle['is_approved'] != true)
              ListTile(
                leading: Icon(Icons.check_circle, color: Colors.green),
                title: Text('Onayla'),
                onTap: () {
                  Navigator.pop(context);
                  _approveVehicle(vehicle);
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
  void _showVehicleDetails(Map<String, dynamic> vehicle) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      builder: (context) => _buildVehicleDetailPopup(vehicle),
    );
  }

  Widget _buildVehicleDetailPopup(Map<String, dynamic> vehicle) {
    final isApproved = vehicle['is_approved'] == true;
    final isPending = !isApproved;
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
                  _buildDetailRow('Durum', isApproved ? 'ONAYLI' : 'ONAY BEKLİYOR'),
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

          // Bağlı Okullar
          FutureBuilder<List<Map<String, dynamic>>>(
            future: _dbService.getVehicleSchools(vehicle['id']),
            builder: (context, snapshot) {
              final schools = snapshot.data ?? [];
              if (schools.isNotEmpty) {
                return Card(
                  child: Padding(
                    padding: EdgeInsets.all(16),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text('Bağlı Okullar', style: TextStyle(fontWeight: FontWeight.bold)),
                        SizedBox(height: 8),
                        ...schools.map((vs) =>
                            Text('• ${vs['schools']['name']} - ${vs['schools']['district']}')
                        ).toList(),
                      ],
                    ),
                  ),
                );
              }
              return SizedBox();
            },
          ),

          SizedBox(height: 20),

          // Aksiyon Butonları
          Row(
            children: [
              if (isPending) ...[
                Expanded(
                  child: ElevatedButton(
                    onPressed: () => _approveVehicle(vehicle),
                    style: ElevatedButton.styleFrom(backgroundColor: Colors.green),
                    child: Text('ONAYLA'),
                  ),
                ),
                SizedBox(width: 8),
                Expanded(
                  child: ElevatedButton(
                    onPressed: () => _rejectVehicle(vehicle),
                    style: ElevatedButton.styleFrom(backgroundColor: Colors.red),
                    child: Text('REDDET'),
                  ),
                ),
              ],
              Expanded(
                child: OutlinedButton(
                  onPressed: () => Navigator.pop(context),
                  child: Text('KAPAT'),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  // Red butonu metodu
  void _rejectVehicle(Map<String, dynamic> vehicle) {
    final reasonController = TextEditingController();

    showDialog(
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
            onPressed: () => Navigator.pop(context),
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
              Navigator.pop(context);
              _performRejection(vehicle, reasonController.text.trim());
            },
            style: ElevatedButton.styleFrom(backgroundColor: Colors.red),
            child: Text('REDDET'),
          ),
        ],
      ),
    );
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
      _loadVehicles();
      Navigator.pop(context); // Popup'ı kapat
    } catch (e) {
      _showSnackBar('Reddetme hatası: $e', Colors.red);
    }
  }

  String _getTransportTypeText(String transportType) {
    switch (transportType) {
      case 'private': return 'Özel Taşıma';
      case 'state': return 'Devlet Taşıması';
      default: return transportType;
    }
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


  Widget _buildDetailRow(String label, String value) {
    return Padding(
      padding: EdgeInsets.symmetric(vertical: 4),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            width: 120, // Container width kullan
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


  void _editVehicle(Map<String, dynamic> vehicle) {
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => VehicleEditScreen(vehicle: vehicle),
      ),
    ).then((success) {
      if (success == true) {
        _loadVehicles();
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
      // vehicle['id'] integer geliyor, string'e çevir
      await _dbService.deleteVehicle(vehicle['id'].toString());
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
        title: Text('İlçe - Araç Yönetimi'),
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
          _buildActionButtons(),
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

  Widget _buildActionButtons() {
    return Padding(
      padding: EdgeInsets.all(16),
      child: Row(
        children: [
          Expanded(
            child: ElevatedButton.icon(
              onPressed: () => Navigator.push(
                context,
                MaterialPageRoute(builder: (context) => SchoolVehicleFormScreen()),
              ),
              icon: Icon(Icons.add),
              label: Text('YENİ ARAÇ EKLE'),
            ),
          ),
          SizedBox(width: 12),
          Expanded(
            child: OutlinedButton.icon(
              onPressed: _showApprovalScreen,
              icon: Icon(Icons.approval),
              label: Text('ONAY BEKLEYEN ($_pendingCount)'),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildSearchAndFilter() {
    return Padding(
      padding: EdgeInsets.symmetric(horizontal: 16),
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
            _searchQuery.isEmpty ? 'Henüz araç kaydı yok' : 'Arama sonucu bulunamadı',
            style: TextStyle(fontSize: 16, color: Colors.grey[600]),
          ),
        ],
      ),
    );
  }

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
              '${vehicle['model']} • ${_getTransportTypeText(vehicle['transport_type'] ?? 'private')}',
              style: TextStyle(fontSize: 12, color: Colors.grey[600]),
            ),
          ],
        ),
        trailing: _buildVehicleTrailing(vehicle, isApproved),
        onTap: () => _showVehicleDetails(vehicle), // TIKLAMA EKLENDİ
        onLongPress: () => _showActionMenu(vehicle),
      ),
    );
  }

  Widget _buildVehicleLeading(Vehicle vehicle, bool isApproved) {
    return Container(
      width: 40,
      height: 40,
      decoration: BoxDecoration(
        color: isApproved ? Colors.green : Colors.orange,
        shape: BoxShape.circle,
      ),
      child: Icon(
        isApproved ? Icons.check : Icons.pending,
        color: Colors.white,
        size: 20,
      ),
    );
  }

  Widget _buildVehicleTrailing(Vehicle vehicle, bool isApproved) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        if (!isApproved)
          IconButton(
            icon: Icon(Icons.check, color: Colors.green),
            onPressed: () {
              // Approve vehicle logic
            },
          ),
        IconButton(
          icon: Icon(Icons.visibility, color: Colors.blue),
          onPressed: () {
            // View vehicle details logic
          },
        ),
      ],
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
            ListTile(
              leading: Icon(Icons.visibility),
              title: Text('Detayları Gör'),
              onTap: () {
                Navigator.pop(context);
                _showVehicleDetails(vehicle);
              },
            ),
            if (isPending) ...[
              ListTile(
                leading: Icon(Icons.check_circle, color: Colors.green),
                title: Text('Onayla'),
                onTap: () {
                  Navigator.pop(context);
                  _approveVehicle(vehicle);
                },
              ),
              ListTile(
                leading: Icon(Icons.cancel, color: Colors.red),
                title: Text('Reddet'),
                onTap: () {
                  Navigator.pop(context);
                  _rejectVehicle(vehicle);
                },
              ),
            ],
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
  void _showSnackBar(String message, [Color color = Colors.blue]) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(message),
        backgroundColor: color,
      ),
    );
  }
}